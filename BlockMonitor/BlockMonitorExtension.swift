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
//    - Target membership for SharedDefaults.swift, BlockingPreset.swift, BlockingSchedule.swift,
//      BlockingActuator.swift: tick BOTH Block and BlockMonitor.
//

import DeviceActivity
import Foundation

class BlockMonitorExtension: DeviceActivityMonitor {

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        guard let presetID = Self.parsePresetID(from: activity) else { return }
        BlockingActuator.start(presetID: presetID)
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        guard let presetID = Self.parsePresetID(from: activity) else { return }
        BlockingActuator.end(presetID: presetID)
    }

    /// Activity name format is "preset.<UUID>" or "preset.<UUID>.early" / ".late" for cross-midnight.
    static func parsePresetID(from activity: DeviceActivityName) -> UUID? {
        let raw = activity.rawValue
        guard raw.hasPrefix("preset.") else { return nil }
        let trimmed = raw.dropFirst("preset.".count)
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
}
