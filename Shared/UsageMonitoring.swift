//
//  UsageMonitoring.swift
//  Block
//
//  Shared DeviceActivity registration for the usage-timer mechanic. Used by:
//    - UsageLimitManager (app side: registers monitors, observable state)
//    - BlockMonitorExtension (re-arms the budget when a lockout ends)
//
//  Keeping registration here — rather than duplicated in app + extension —
//  mirrors `BlockingActuator`, so both sides build identical monitors.
//
//  Add target membership to BOTH Block and BlockMonitor targets.
//

import Foundation
import DeviceActivity
import FamilyControls

enum UsageMonitoring {

    // MARK: - Names

    /// All-day counting window carrying the cumulative-usage threshold event.
    static func usageActivityName(for presetID: UUID) -> DeviceActivityName {
        DeviceActivityName(rawValue: "usage.\(presetID.uuidString)")
    }

    /// One-shot lockout window registered once the threshold is reached.
    static func lockActivityName(for presetID: UUID) -> DeviceActivityName {
        DeviceActivityName(rawValue: "lock.\(presetID.uuidString)")
    }

    static let usageEventName = DeviceActivityEvent.Name(rawValue: "limit")

    // MARK: - Schedules / events

    /// Repeating all-day window; iOS resets the threshold counter at the interval
    /// boundary (≈midnight), giving the daily reset for free.
    static var allDaySchedule: DeviceActivitySchedule {
        DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true
        )
    }

    /// The threshold event for a preset, or nil if the limit is off / selection empty.
    static func usageEvent(for preset: BlockingPreset) -> DeviceActivityEvent? {
        guard let limit = preset.usageLimitMinutes, limit > 0 else { return nil }
        let selection = preset.selection
        guard !selection.applicationTokens.isEmpty
                || !selection.categoryTokens.isEmpty
                || !selection.webDomainTokens.isEmpty else { return nil }
        return DeviceActivityEvent(
            applications: selection.applicationTokens,
            categories: selection.categoryTokens,
            webDomains: selection.webDomainTokens,
            threshold: DateComponents(minute: limit)
        )
    }

    // MARK: - Register / tear down

    /// Start the all-day usage threshold monitor for a preset. Returns false when
    /// there's nothing to monitor or registration fails.
    @discardableResult
    static func startUsageMonitor(for preset: BlockingPreset) -> Bool {
        guard let event = usageEvent(for: preset) else { return false }
        do {
            try DeviceActivityCenter().startMonitoring(
                usageActivityName(for: preset.id),
                during: allDaySchedule,
                events: [usageEventName: event]
            )
            return true
        } catch {
            print("❌ startUsageMonitor failed for \(preset.id): \(error)")
            return false
        }
    }

    static func stopUsageMonitor(for presetID: UUID) {
        DeviceActivityCenter().stopMonitoring([usageActivityName(for: presetID)])
    }

    /// True if the all-day usage monitor is currently registered for this preset.
    static func isUsageMonitorActive(for presetID: UUID) -> Bool {
        DeviceActivityCenter().activities.contains(usageActivityName(for: presetID))
    }

    /// Register a one-shot lockout window from now until now + `minutes`, and
    /// persist the end-time. The extension's `intervalDidEnd` for this activity
    /// clears the shield and re-arms the budget; `reconcileExpiredLocks` is the
    /// backstop if the one-shot window doesn't fire (e.g. very short lockouts).
    static func startLockout(presetID: UUID, minutes: Int) {
        let now = Date()
        let end = now.addingTimeInterval(TimeInterval(max(1, minutes) * 60))
        SharedDefaults.suite.set(end, forKey: SharedDefaults.Keys.usageLockEnd(presetID: presetID))

        let cal = Calendar.current
        let schedule = DeviceActivitySchedule(
            intervalStart: cal.dateComponents([.hour, .minute, .second], from: now),
            intervalEnd: cal.dateComponents([.hour, .minute, .second], from: end),
            repeats: false
        )
        do {
            try DeviceActivityCenter().startMonitoring(lockActivityName(for: presetID), during: schedule)
        } catch {
            print("❌ startLockout failed for \(presetID): \(error)")
        }
    }

    /// Stop the lockout window and clear its persisted end-time.
    static func stopLockout(for presetID: UUID) {
        DeviceActivityCenter().stopMonitoring([lockActivityName(for: presetID)])
        SharedDefaults.suite.removeObject(forKey: SharedDefaults.Keys.usageLockEnd(presetID: presetID))
    }
}
