//
//  DebugSimulator.swift
//  Block
//
//  Test affordances exposed in DebugMenuView. All compiled out of release.
//
//  Provides:
//    - Schedule "fire interval start/end now" for any preset (in-process,
//      bypassing the BlockMonitor extension)
//    - NFC `simulateTagScan` shortcuts (registered tag toggle, fake tag,
//      registration without hardware)
//    - Cooldown fast-forward (jumps the persisted cooldown end-time to now)
//    - SharedDefaults snapshot for the live state inspector
//    - "Reset all" to clear shields, running flags, cooldowns
//

#if DEBUG

import Foundation
import FamilyControls
import ManagedSettings

@MainActor
enum DebugSimulator {

    // MARK: - Schedule simulation

    /// Run the same code path the BlockMonitor extension would on `intervalDidStart`.
    static func fireScheduleStart(presetID: UUID) {
        // Flush pending preset writes — actuator reads from disk like the extension does.
        PresetStore.shared.flush()
        let applied = BlockingActuator.start(presetID: presetID)
        DebugLog.shared.log(.actuator, applied
            ? "fireScheduleStart applied for preset \(presetID.uuidString.prefix(8))"
            : "fireScheduleStart skipped (preset missing or weekday filtered) \(presetID.uuidString.prefix(8))")
        SchedulingManager.shared.refresh()
    }

    /// Run the same code path the BlockMonitor extension would on `intervalDidEnd`.
    static func fireScheduleEnd(presetID: UUID) {
        BlockingActuator.end(presetID: presetID)
        DebugLog.shared.log(.actuator, "fireScheduleEnd cleared preset \(presetID.uuidString.prefix(8))")
        SchedulingManager.shared.refresh()
    }

    // MARK: - NFC simulation

    /// Simulate a tap with the registered tag (toggles tag-flow blocking).
    static func simulateRegisteredTagScan() {
        guard let id = AppConfigurationStore.shared.registeredTagIdentifier else {
            DebugLog.shared.log(.nfc, "no tag registered — use 'Register fake tag' first")
            return
        }
        DebugLog.shared.log(.nfc, "simulating registered tag scan: \(id)")
        NFCManager.shared.simulateTagScan(withId: id)
    }

    /// Simulate a tap with an unknown tag id — should be ignored by the callback.
    static func simulateUnknownTagScan() {
        let fake = "deadbeef\(Int.random(in: 1000...9999))"
        DebugLog.shared.log(.nfc, "simulating unknown tag scan: \(fake)")
        NFCManager.shared.simulateTagScan(withId: fake)
    }

    /// Register a fake tag id (when no tag is registered, the callback registers it).
    static func registerFakeTag() {
        if AppConfigurationStore.shared.registeredTagIdentifier != nil {
            DebugLog.shared.log(.nfc, "tag already registered — clear first")
            return
        }
        let fake = "simtag\(Int.random(in: 100000...999999))"
        DebugLog.shared.log(.nfc, "registering fake tag: \(fake)")
        NFCManager.shared.simulateTagScan(withId: fake)
    }

    // MARK: - Cooldown fast-forward

    /// Jump the persisted cooldown end-time to now so the timer fires on the next tick.
    static func expireCooldown() {
        guard let active = CooldownManager.shared.activeCooldown else {
            DebugLog.shared.log(.cooldown, "no active cooldown to fast-forward")
            return
        }
        SharedDefaults.suite.set(Date(),
                                 forKey: SharedDefaults.Keys.cooldownEnd(presetID: active.presetID))
        DebugLog.shared.log(.cooldown, "fast-forwarded cooldown for preset \(active.presetID.uuidString.prefix(8))")
        // Force the manager to re-evaluate immediately.
        CooldownManager.shared.complete()
    }

    /// Start a 10-second cooldown for testing the gating UI without waiting minutes.
    static func startShortCooldown(presetID: UUID, seconds: Int = 10) {
        let endsAt = Date().addingTimeInterval(TimeInterval(seconds))
        SharedDefaults.suite.set(endsAt,
                                 forKey: SharedDefaults.Keys.cooldownEnd(presetID: presetID))
        // Easiest restoration path: have the manager pick it up.
        CooldownManager.shared.restoreActiveCooldownsIfAny()
        DebugLog.shared.log(.cooldown, "started \(seconds)s cooldown for preset \(presetID.uuidString.prefix(8))")
    }

    // MARK: - Reset

    /// Clear every preset shield + running flag + cooldown. Doesn't delete presets themselves.
    static func resetAllRuntime() {
        let suite = SharedDefaults.suite
        for preset in PresetStore.shared.presets {
            ManagedSettingsStore(named: BlockingActuator.storeName(for: preset.id)).clearAllSettings()
            suite.removeObject(forKey: SharedDefaults.Keys.running(presetID: preset.id))
            suite.removeObject(forKey: SharedDefaults.Keys.cooldownEnd(presetID: preset.id))
            if preset.isEnabled {
                PresetStore.shared.setEnabled(id: preset.id, enabled: false)
            }
        }
        ScreenTimeManager.shared.disableBlocking()
        CooldownManager.shared.cancel()
        SchedulingManager.shared.refresh()
        DebugLog.shared.log(.state, "reset all runtime state (presets preserved)")
    }

    // MARK: - State snapshot

    struct PresetSnapshot: Identifiable {
        let id: UUID
        let name: String
        let appCount: Int
        let categoryCount: Int
        let scheduleSummary: String?
        let isEnabled: Bool
        let isScheduledRunning: Bool
        let cooldownEndsAt: Date?
        let cooldownMinutes: Int
    }

    struct GlobalSnapshot {
        let authorizationStatus: AuthorizationStatus
        let registeredTag: String?
        let isTagFlowBlocking: Bool
        let hasSelectedApps: Bool
        let selectedAppCount: Int
        let activeScheduledIDs: Set<UUID>
        let presets: [PresetSnapshot]
        let activeCooldownPresetID: UUID?
    }

    static func snapshot() -> GlobalSnapshot {
        let suite = SharedDefaults.suite
        let configStore = AppConfigurationStore.shared

        let presetSnapshots: [PresetSnapshot] = PresetStore.shared.presets.map { preset in
            let runningKey = SharedDefaults.Keys.running(presetID: preset.id)
            let cooldownKey = SharedDefaults.Keys.cooldownEnd(presetID: preset.id)
            return PresetSnapshot(
                id: preset.id,
                name: preset.name,
                appCount: preset.selection.applicationTokens.count,
                categoryCount: preset.selection.categoryTokens.count,
                scheduleSummary: preset.schedule?.summary,
                isEnabled: preset.isEnabled,
                isScheduledRunning: suite.bool(forKey: runningKey),
                cooldownEndsAt: suite.object(forKey: cooldownKey) as? Date,
                cooldownMinutes: preset.cooldownMinutes
            )
        }

        return GlobalSnapshot(
            authorizationStatus: ScreenTimeManager.shared.authorizationStatus,
            registeredTag: configStore.registeredTagIdentifier,
            isTagFlowBlocking: configStore.isBlockingEnabled,
            hasSelectedApps: configStore.hasSelectedApps,
            selectedAppCount: configStore.selectedApps.applicationTokens.count,
            activeScheduledIDs: SchedulingManager.shared.activeScheduledPresetIDs,
            presets: presetSnapshots,
            activeCooldownPresetID: CooldownManager.shared.activeCooldown?.presetID
        )
    }
}

#endif
