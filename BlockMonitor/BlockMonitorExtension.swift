//
//  BlockMonitorExtension.swift
//  BlockMonitor
//
//  DeviceActivityMonitor extension. Runs out-of-process when iOS triggers a scheduled
//  interval or a usage threshold.
//
//  Activity names (see SchedulingManager / UsageMonitoring):
//    - "preset.<UUID>" / ".early" / ".late"  → time-of-day scheduled block
//    - "usage.<UUID>"                         → all-day usage counting window
//    - "lock.<UUID>"                          → one-shot usage lockout window
//
//  Required target setup (do in Xcode UI):
//    - Target: BlockMonitor (Device Activity Monitor Extension template)
//    - Embed in host app: Block
//    - Capabilities on this target: Family Controls, App Groups (group.com.amitsankaran.Block)
//    - Target membership for SharedDefaults.swift, BlockingPreset.swift, BlockingSchedule.swift,
//      BlockingActuator.swift, UsageMonitoring.swift: tick BOTH Block and BlockMonitor.
//

import DeviceActivity
import Foundation

class BlockMonitorExtension: DeviceActivityMonitor {

    private enum ActivityKind {
        case schedule   // preset.<UUID> (and .early/.late) — time-of-day block
        case usage      // usage.<UUID> — cumulative counting window
        case lock       // lock.<UUID> — one-shot usage lockout window
    }

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        guard let (kind, presetID) = Self.parse(activity) else { return }
        switch kind {
        case .schedule:
            BlockingActuator.start(presetID: presetID)
        case .lock:
            // Lockout window began — ensure the shield is up (idempotent; the
            // threshold handler already applied it).
            BlockingActuator.start(presetID: presetID, bypassWeekday: true, setRunningFlag: false)
        case .usage:
            break // counting window only — never shields on its own.
        }
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        guard let (kind, presetID) = Self.parse(activity) else { return }
        switch kind {
        case .schedule:
            BlockingActuator.end(presetID: presetID)
        case .lock:
            // Lockout elapsed — release the shield, clear the lock state, and
            // re-arm the usage budget from zero.
            BlockingActuator.end(presetID: presetID)
            UsageMonitoring.stopLockout(for: presetID)
            if let preset = BlockingActuator.loadPreset(id: presetID) {
                UsageMonitoring.startUsageMonitor(for: preset)
            }
        case .usage:
            break // all-day window auto-restarts (repeats: true); counter resets.
        }
    }

    /// Cumulative usage crossed the preset's budget — lock the whole preset.
    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
        guard let (kind, presetID) = Self.parse(activity), kind == .usage else { return }

        // Shield immediately, then register the timed lockout so it auto-releases.
        BlockingActuator.start(presetID: presetID, bypassWeekday: true, setRunningFlag: false)
        let lockMinutes = BlockingActuator.loadPreset(id: presetID)?.usageLockMinutes ?? 180
        UsageMonitoring.startLockout(presetID: presetID, minutes: lockMinutes)
    }

    // MARK: - Parsing

    /// Map an activity name to its kind + preset UUID. Returns nil for anything
    /// unrecognized.
    private static func parse(_ activity: DeviceActivityName) -> (ActivityKind, UUID)? {
        let raw = activity.rawValue
        let kind: ActivityKind
        let rest: Substring
        if raw.hasPrefix("preset.") {
            kind = .schedule
            rest = raw.dropFirst("preset.".count)
        } else if raw.hasPrefix("usage.") {
            kind = .usage
            rest = raw.dropFirst("usage.".count)
        } else if raw.hasPrefix("lock.") {
            kind = .lock
            rest = raw.dropFirst("lock.".count)
        } else {
            return nil
        }

        // Strip the cross-midnight segment suffix used by scheduled blocks.
        var uuidPart = rest
        if uuidPart.hasSuffix(".early") {
            uuidPart = uuidPart.dropLast(".early".count)
        } else if uuidPart.hasSuffix(".late") {
            uuidPart = uuidPart.dropLast(".late".count)
        }
        guard let id = UUID(uuidString: String(uuidPart)) else { return nil }
        return (kind, id)
    }
}
