//
//  CooldownManager.swift
//  Block
//
//  Tracks an active cooldown countdown when the user requests an early disable
//  on a scheduled-active preset. Persists the end-time so killing the app
//  doesn't bypass the wait.
//

import Foundation
import Combine

@MainActor
class CooldownManager: ObservableObject {
    static let shared = CooldownManager()

    struct ActiveCooldown: Equatable {
        let presetID: UUID
        let endsAt: Date
    }

    @Published private(set) var activeCooldown: ActiveCooldown?

    private var tickTimer: Timer?
    private var defaults: UserDefaults { SharedDefaults.suite }

    private init() {}

    /// Restore unfinished cooldowns from disk.
    /// If the cooldown end-time has already passed, completes it now.
    func restoreActiveCooldownsIfAny() {
        // Look across all presets — only one cooldown is active at a time
        // but we don't track which one is "active" so we scan.
        let now = Date()
        for preset in PresetStore.shared.presets {
            let key = SharedDefaults.Keys.cooldownEnd(presetID: preset.id)
            guard let endsAt = defaults.object(forKey: key) as? Date else { continue }
            if endsAt > now {
                activeCooldown = ActiveCooldown(presetID: preset.id, endsAt: endsAt)
                startTickTimer()
                return
            } else {
                // Cooldown already expired while app was closed — release.
                completeImmediately(presetID: preset.id)
                defaults.removeObject(forKey: key)
            }
        }
    }

    /// Start a new cooldown. If one is already active for a different preset, it's cancelled.
    func start(for presetID: UUID, minutes: Int) {
        cancel()
        let endsAt = Date().addingTimeInterval(TimeInterval(max(0, minutes) * 60))
        let cooldown = ActiveCooldown(presetID: presetID, endsAt: endsAt)
        activeCooldown = cooldown
        defaults.set(endsAt, forKey: SharedDefaults.Keys.cooldownEnd(presetID: presetID))
        startTickTimer()
        #if DEBUG
        DebugLog.shared.log(.cooldown, "start(\(minutes)m) preset=\(presetID.uuidString.prefix(8)) ends=\(endsAt)")
        #endif

        // Edge case: zero-minute cooldown completes immediately.
        if endsAt <= Date() {
            complete()
        }
    }

    func cancel() {
        guard let active = activeCooldown else { return }
        defaults.removeObject(forKey: SharedDefaults.Keys.cooldownEnd(presetID: active.presetID))
        activeCooldown = nil
        tickTimer?.invalidate()
        tickTimer = nil
    }

    /// Time remaining for the active cooldown, or 0 if none.
    var remaining: TimeInterval {
        guard let active = activeCooldown else { return 0 }
        return max(0, active.endsAt.timeIntervalSinceNow)
    }

    var isComplete: Bool {
        guard let active = activeCooldown else { return false }
        return active.endsAt <= Date()
    }

    /// Releases the preset's shield once the cooldown ends.
    /// The schedule remains registered — the next interval will re-shield.
    func complete() {
        guard let active = activeCooldown else { return }
        completeImmediately(presetID: active.presetID)
        defaults.removeObject(forKey: SharedDefaults.Keys.cooldownEnd(presetID: active.presetID))
        activeCooldown = nil
        tickTimer?.invalidate()
        tickTimer = nil
    }

    private func completeImmediately(presetID: UUID) {
        // Clear the named store and the running flag.
        ScreenTimeManager.shared.clearPresetShield(id: presetID)
        defaults.removeObject(forKey: SharedDefaults.Keys.running(presetID: presetID))
        // Also turn off manual enable so the editor reflects the change.
        if let preset = PresetStore.shared.preset(id: presetID), preset.isEnabled {
            PresetStore.shared.setEnabled(id: presetID, enabled: false)
        }
        SchedulingManager.shared.refresh()
    }

    private func startTickTimer() {
        tickTimer?.invalidate()
        tickTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let active = self.activeCooldown else { return }
                // Force a publisher update so the view recomputes `remaining`.
                self.objectWillChange.send()
                if active.endsAt <= Date() {
                    self.complete()
                }
            }
        }
    }
}
