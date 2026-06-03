//
//  BlockingActuator.swift
//  Block
//
//  Shared shielding logic for a preset. Used by:
//    - BlockMonitorExtension (real device, on schedule)
//    - DebugSimulator (in-process, for simulator/dev testing)
//
//  Add target membership to BOTH Block and BlockMonitor.
//

import Foundation
import ManagedSettings
import FamilyControls

enum BlockingActuator {

    /// Apply the preset's shield to its named store.
    /// Mirrors `BlockMonitorExtension.intervalDidStart` so simulator and device
    /// behavior stay in lockstep.
    ///
    /// - Parameter setRunningFlag: when `true` (scheduled blocks), marks the
    ///   `running` flag that drives the home "Scheduled blocks" display. The
    ///   usage-lock path passes `false` — usage locks are tracked separately via
    ///   `usageLockEnd`, so they must not masquerade as scheduled blocks.
    @discardableResult
    static func start(presetID: UUID, bypassWeekday: Bool = false, setRunningFlag: Bool = true) -> Bool {
        guard let preset = loadPreset(id: presetID) else { return false }

        if !bypassWeekday, let schedule = preset.schedule {
            let weekday = Calendar.current.component(.weekday, from: Date())
            guard schedule.weekdays.contains(weekday) else { return false }
        }

        apply(
            selection: preset.selection,
            appsStore: ManagedSettingsStore(named: appsStoreName(for: presetID)),
            categoriesStore: ManagedSettingsStore(named: categoriesStoreName(for: presetID))
        )

        if setRunningFlag {
            SharedDefaults.suite.set(true, forKey: SharedDefaults.Keys.running(presetID: presetID))
        }
        return true
    }

    /// Clear the preset's shield and running flag. Mirrors `intervalDidEnd`.
    static func end(presetID: UUID) {
        ManagedSettingsStore(named: appsStoreName(for: presetID)).clearAllSettings()
        ManagedSettingsStore(named: categoriesStoreName(for: presetID)).clearAllSettings()
        SharedDefaults.suite.removeObject(forKey: SharedDefaults.Keys.running(presetID: presetID))
    }

    /// Apply a selection across two physical stores. iOS unions shields across stores;
    /// setting `shield.applications` and `shield.applicationCategories = .specific(...)` on
    /// the *same* store has been observed to drop the individual-apps shield, so we keep
    /// them on separate stores. Each property is written unconditionally (nil when empty)
    /// to clear stale state left by the prior single-store layout.
    static func apply(
        selection: FamilyActivitySelection,
        appsStore: ManagedSettingsStore,
        categoriesStore: ManagedSettingsStore
    ) {
        appsStore.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        appsStore.shield.applicationCategories = nil
        appsStore.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens

        categoriesStore.shield.applications = nil
        categoriesStore.shield.applicationCategories = selection.categoryTokens.isEmpty
            ? nil
            : .specific(selection.categoryTokens)
    }

    // MARK: - Helpers

    /// Backed by `preset.<UUID>` for backward compatibility — holds `shield.applications`.
    static func appsStoreName(for presetID: UUID) -> ManagedSettingsStore.Name {
        ManagedSettingsStore.Name(rawValue: "preset.\(presetID.uuidString)")
    }

    /// Companion store holding `shield.applicationCategories`.
    static func categoriesStoreName(for presetID: UUID) -> ManagedSettingsStore.Name {
        ManagedSettingsStore.Name(rawValue: "preset.\(presetID.uuidString).cats")
    }

    /// Decode a single preset from the shared App Group store. Used by the
    /// actuator and the usage-monitoring helpers in both app and extension.
    static func loadPreset(id: UUID) -> BlockingPreset? {
        guard let data = SharedDefaults.suite.data(forKey: SharedDefaults.Keys.presets) else {
            return nil
        }
        do {
            let presets = try JSONDecoder().decode([BlockingPreset].self, from: data)
            return presets.first(where: { $0.id == id })
        } catch {
            return nil
        }
    }
}
