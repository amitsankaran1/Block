//
//  BlockMonitorExtension.swift
//  BlockMonitor
//
//  DeviceActivityMonitor extension. Runs out-of-process when iOS triggers a scheduled interval.
//
//  Required target setup (do in Xcode UI):
//    - Target: BlockMonitor (Device Activity Monitor Extension template)
//    - Embed in host app: Block
//    - Capabilities on this target: Family Controls, App Groups (group.com.amitsankaran.Block)
//    - Target membership for SharedDefaults.swift, BlockingPreset.swift, BlockingSchedule.swift:
//      tick BOTH Block and BlockMonitor.
//

import DeviceActivity
import ManagedSettings
import FamilyControls
import Foundation

class BlockMonitorExtension: DeviceActivityMonitor {

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        guard let presetID = Self.parsePresetID(from: activity) else { return }
        guard let preset = loadPreset(id: presetID) else { return }

        // Per-day weekday filter (DeviceActivitySchedule has no native weekday support).
        if let schedule = preset.schedule {
            let weekday = Calendar.current.component(.weekday, from: Date())
            guard schedule.weekdays.contains(weekday) else {
                return
            }
        }

        let storeName = ManagedSettingsStore.Name(rawValue: "preset.\(presetID.uuidString)")
        let store = ManagedSettingsStore(named: storeName)

        if !preset.selection.applicationTokens.isEmpty {
            store.shield.applications = preset.selection.applicationTokens
        }
        if !preset.selection.categoryTokens.isEmpty {
            store.shield.applicationCategories = .specific(preset.selection.categoryTokens)
        }

        SharedDefaults.suite.set(true, forKey: SharedDefaults.Keys.running(presetID: presetID))
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        guard let presetID = Self.parsePresetID(from: activity) else { return }

        let storeName = ManagedSettingsStore.Name(rawValue: "preset.\(presetID.uuidString)")
        ManagedSettingsStore(named: storeName).clearAllSettings()

        SharedDefaults.suite.removeObject(forKey: SharedDefaults.Keys.running(presetID: presetID))
    }

    // MARK: - Helpers

    /// Activity name format is "preset.<UUID>" or "preset.<UUID>.early" / ".late" for cross-midnight.
    static func parsePresetID(from activity: DeviceActivityName) -> UUID? {
        let raw = activity.rawValue
        guard raw.hasPrefix("preset.") else { return nil }
        let trimmed = raw.dropFirst("preset.".count)
        // Strip trailing .early / .late if present.
        let uuidPart: Substring
        if trimmed.hasSuffix(".early") {
            uuidPart = trimmed.dropLast(".early".count)
        } else if trimmed.hasSuffix(".late") {
            uuidPart = trimmed.dropLast(".late".count)
        } else {
            uuidPart = trimmed
        }
        return UUID(uuidString: String(uuidPart))
    }

    private func loadPreset(id: UUID) -> BlockingPreset? {
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
