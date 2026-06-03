//
//  UsageLimitManager.swift
//  Block
//
//  App-side owner of the usage-timer mechanic. Registers/refreshes the per-preset
//  all-day usage threshold monitors (delegating the DeviceActivity calls to the
//  shared `UsageMonitoring` helper) and publishes which presets are usage-locked
//  so the UI can react.
//
//  This is the usage-timer sibling of `SchedulingManager` (time-of-day blocks).
//

import Foundation
import Combine

@MainActor
class UsageLimitManager: ObservableObject {
    static let shared = UsageLimitManager()

    /// Presets currently inside an active usage lockout (usageLockEnd in the future).
    @Published private(set) var activeUsageLockPresetIDs: Set<UUID> = []

    private var defaults: UserDefaults { SharedDefaults.suite }
    private var refreshTimer: Timer?

    private init() {
        refresh()
        startPeriodicRefresh()
    }

    // MARK: - Public API

    /// Register (or refresh) the all-day usage threshold monitor for a preset.
    ///
    /// - Parameter forceReset: when `true`, restart so iOS's threshold counter
    ///   resets (use on settings change and after a lockout). When `false`
    ///   (launch), leave an already-running monitor untouched so the day's
    ///   accumulated usage isn't wiped just by reopening the app.
    func applyUsageLimit(for preset: BlockingPreset, forceReset: Bool = true) {
        let active = UsageMonitoring.isUsageMonitorActive(for: preset.id)

        // Nothing to monitor (limit off / empty selection): stop if it was running.
        guard UsageMonitoring.usageEvent(for: preset) != nil else {
            if active { UsageMonitoring.stopUsageMonitor(for: preset.id) }
            return
        }

        // Idempotent launch path: preserve the running monitor (and its counter).
        if active && !forceReset { return }
        if active { UsageMonitoring.stopUsageMonitor(for: preset.id) }

        UsageMonitoring.startUsageMonitor(for: preset)
        #if DEBUG
        DebugLog.shared.log(.deviceActivity,
            "applyUsageLimit(\(preset.name)): \(preset.usageLimitMinutes ?? 0)m → lock \(preset.usageLockMinutes)m")
        #endif
    }

    /// Full teardown: stop the counting + lockout windows and clear the lock state.
    /// Only releases the shield if a usage lock was actually holding it (and no
    /// scheduled block or manual enable is keeping it up), so turning the limit
    /// off doesn't punch a hole in a concurrent scheduled block.
    func removeUsageLimit(for preset: BlockingPreset) {
        let wasLocked = lockEnd(for: preset.id) != nil
        UsageMonitoring.stopUsageMonitor(for: preset.id)
        UsageMonitoring.stopLockout(for: preset.id) // also clears the persisted end-time
        if wasLocked {
            let scheduledRunning = defaults.bool(forKey: SharedDefaults.Keys.running(presetID: preset.id))
            if !scheduledRunning && !preset.isEnabled {
                ScreenTimeManager.shared.clearPresetShield(id: preset.id)
            }
        }
        refresh()
        #if DEBUG
        DebugLog.shared.log(.deviceActivity, "removeUsageLimit(\(preset.name))")
        #endif
    }

    /// Re-register all usage monitors. Call once at launch — uses the non-resetting
    /// path so a relaunch doesn't hand back a fresh daily budget.
    func reapplyAllUsageLimits() {
        for preset in PresetStore.shared.presets where preset.usageLimitMinutes != nil {
            applyUsageLimit(for: preset, forceReset: false)
        }
        refresh()
    }

    /// Clear any lockouts whose end-time has already passed (e.g. while the app
    /// was closed and the one-shot lock window didn't fire) and re-arm the budget.
    func reconcileExpiredLocks() {
        let now = Date()
        for preset in PresetStore.shared.presets {
            let key = SharedDefaults.Keys.usageLockEnd(presetID: preset.id)
            guard let endsAt = defaults.object(forKey: key) as? Date, endsAt <= now else { continue }
            UsageMonitoring.stopLockout(for: preset.id) // also clears the persisted end-time
            BlockingActuator.end(presetID: preset.id)
            applyUsageLimit(for: preset, forceReset: true) // fresh budget
            #if DEBUG
            DebugLog.shared.log(.deviceActivity, "reconcile: cleared expired usage lock \(preset.id.uuidString.prefix(8))")
            #endif
        }
        refresh()
    }

    /// Re-arm a preset's budget after an early release / external clear. Stops the
    /// lockout window (if any), then restarts the threshold monitor from zero.
    func rearmAfterRelease(presetID: UUID) {
        UsageMonitoring.stopLockout(for: presetID)
        if let preset = PresetStore.shared.preset(id: presetID) {
            applyUsageLimit(for: preset, forceReset: true)
        }
        refresh()
    }

    /// Recompute `activeUsageLockPresetIDs` from the persisted lock end-times.
    func refresh() {
        let now = Date()
        var ids: Set<UUID> = []
        for preset in PresetStore.shared.presets {
            if let endsAt = defaults.object(forKey: SharedDefaults.Keys.usageLockEnd(presetID: preset.id)) as? Date,
               endsAt > now {
                ids.insert(preset.id)
            }
        }
        if ids != activeUsageLockPresetIDs {
            activeUsageLockPresetIDs = ids
        }
    }

    /// End-time of an active usage lockout for a preset, or nil if not locked.
    func lockEnd(for presetID: UUID) -> Date? {
        guard let endsAt = defaults.object(
            forKey: SharedDefaults.Keys.usageLockEnd(presetID: presetID)) as? Date,
              endsAt > Date() else { return nil }
        return endsAt
    }

    private func startPeriodicRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.refresh() }
        }
    }
}
