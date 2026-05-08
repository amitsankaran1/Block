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

    /// Apply the preset's shield to its named store and mark the running flag.
    /// Mirrors `BlockMonitorExtension.intervalDidStart` so simulator and device
    /// behavior stay in lockstep.
    @discardableResult
    static func start(presetID: UUID) -> Bool {
        guard let preset = loadPreset(id: presetID) else { return false }

        if let schedule = preset.schedule {
            let weekday = Calendar.current.component(.weekday, from: Date())
            guard schedule.weekdays.contains(weekday) else { return false }
        }

        let store = ManagedSettingsStore(named: storeName(for: presetID))

        if !preset.selection.applicationTokens.isEmpty {
            store.shield.applications = preset.selection.applicationTokens
        }
        if !preset.selection.categoryTokens.isEmpty {
            store.shield.applicationCategories = .specific(preset.selection.categoryTokens)
        }

        SharedDefaults.suite.set(true, forKey: SharedDefaults.Keys.running(presetID: presetID))
        return true
    }

    /// Clear the preset's shield and running flag. Mirrors `intervalDidEnd`.
    static func end(presetID: UUID) {
        ManagedSettingsStore(named: storeName(for: presetID)).clearAllSettings()
        SharedDefaults.suite.removeObject(forKey: SharedDefaults.Keys.running(presetID: presetID))
    }

    // MARK: - Helpers

    static func storeName(for presetID: UUID) -> ManagedSettingsStore.Name {
        ManagedSettingsStore.Name(rawValue: "preset.\(presetID.uuidString)")
    }

    private static func loadPreset(id: UUID) -> BlockingPreset? {
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
