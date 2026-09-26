//
//  BlockingSchedule.swift
//  Block
//
//  Add target membership to BOTH Block and BlockMonitor targets.
//

import Foundation
#if canImport(DeviceActivity)
import DeviceActivity
#endif

/// What relaunch should do with a schedule block's named ManagedSettings stores.
enum ScheduleShieldIntent: Equatable {
    case enforce
    case holdRelease
    case clear
}

/// Time-of-day weekly schedule for a blocking preset.
///
/// `weekdays` follows `Calendar.Component.weekday` convention:
/// 1 = Sunday, 2 = Monday, … 7 = Saturday.
struct BlockingSchedule: Codable, Equatable, Hashable {
    var startHour: Int
    var startMinute: Int
    var endHour: Int
    var endMinute: Int
    var weekdays: Set<Int>
    var repeats: Bool

    init(
        startHour: Int = 9,
        startMinute: Int = 0,
        endHour: Int = 17,
        endMinute: Int = 0,
        weekdays: Set<Int> = [2, 3, 4, 5, 6],
        repeats: Bool = true
    ) {
        self.startHour = startHour
        self.startMinute = startMinute
        self.endHour = endHour
        self.endMinute = endMinute
        self.weekdays = weekdays
        self.repeats = repeats
    }

    var startMinutesFromMidnight: Int { startHour * 60 + startMinute }
    var endMinutesFromMidnight: Int { endHour * 60 + endMinute }

    /// True when the schedule wraps past midnight (end is on or before start).
    var crossesMidnight: Bool { endMinutesFromMidnight <= startMinutesFromMidnight }

    /// Short human label like "Mon–Fri 9:00–17:00".
    var summary: String {
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "H:mm"
        let startDate = Calendar.current.date(from: DateComponents(hour: startHour, minute: startMinute)) ?? Date()
        let endDate = Calendar.current.date(from: DateComponents(hour: endHour, minute: endMinute)) ?? Date()
        let timeRange = "\(timeFormatter.string(from: startDate))–\(timeFormatter.string(from: endDate))"
        return "\(weekdaySummary) \(timeRange)"
    }

    /// True when `date` falls inside this schedule.
    ///
    /// The end minute is exclusive (a 09:00–17:00 window contains 16:59 and not 17:00).
    /// A window that crosses midnight attributes the after-midnight portion to the
    /// previous weekday, so Friday 22:00–02:00 still contains Saturday 01:00.
    func contains(_ date: Date, calendar: Calendar = .current) -> Bool {
        guard !weekdays.isEmpty else { return false }
        let weekday = calendar.component(.weekday, from: date)
        let minutes = calendar.component(.hour, from: date) * 60
            + calendar.component(.minute, from: date)
        if crossesMidnight {
            if weekdays.contains(weekday), minutes >= startMinutesFromMidnight {
                return true
            }
            let previousWeekday = weekday == 1 ? 7 : weekday - 1
            return weekdays.contains(previousWeekday) && minutes < endMinutesFromMidnight
        }
        return weekdays.contains(weekday)
            && minutes >= startMinutesFromMidnight
            && minutes < endMinutesFromMidnight
    }

    /// End of the window that contains `date`, or nil when `date` is outside it.
    /// Used to remember a mid-window release (cooldown, emergency) until that window ends.
    func currentWindowEnd(from date: Date, calendar: Calendar = .current) -> Date? {
        guard contains(date, calendar: calendar) else { return nil }
        let minutes = calendar.component(.hour, from: date) * 60
            + calendar.component(.minute, from: date)
        let endIsTomorrow = crossesMidnight && minutes >= startMinutesFromMidnight
        let endDay = endIsTomorrow
            ? (calendar.date(byAdding: .day, value: 1, to: date) ?? date)
            : date
        var parts = calendar.dateComponents([.year, .month, .day], from: endDay)
        parts.hour = endHour
        parts.minute = endMinute
        parts.second = 0
        return calendar.date(from: parts)
    }

    /// What a relaunch should do with this schedule's named shield stores.
    ///
    /// - `enforce`: the window is active and was not explicitly released. Refresh the
    ///   shield from the current lists and mark the block running.
    /// - `holdRelease`: cooldown or emergency already lifted this window. Do not put
    ///   the shield back, and do not leave a store up while the block looks inactive.
    /// - `clear`: outside the window. A named store must not stay shielded.
    func shieldIntent(at date: Date, userReleased: Bool, calendar: Calendar = .current) -> ScheduleShieldIntent {
        guard contains(date, calendar: calendar) else { return .clear }
        return userReleased ? .holdRelease : .enforce
    }

    var weekdaySummary: String {
        if weekdays.count == 7 { return "Every day" }
        if weekdays == [2, 3, 4, 5, 6] { return "Weekdays" }
        if weekdays == [1, 7] { return "Weekends" }
        let symbols = Calendar.current.shortStandaloneWeekdaySymbols
        let ordered = weekdays.sorted()
        return ordered.compactMap { day -> String? in
            let index = day - 1
            return (index >= 0 && index < symbols.count) ? symbols[index] : nil
        }.joined(separator: " ")
    }

#if canImport(DeviceActivity)
    /// Builds a single `DeviceActivitySchedule`. For schedules that cross midnight,
    /// the caller should register two separate activity names with different schedules
    /// (see `SchedulingManager`).
    func deviceActivitySchedule(crossingSegment: CrossingSegment = .full) -> DeviceActivitySchedule {
        switch crossingSegment {
        case .full:
            return DeviceActivitySchedule(
                intervalStart: DateComponents(hour: startHour, minute: startMinute),
                intervalEnd: DateComponents(hour: endHour, minute: endMinute),
                repeats: repeats
            )
        case .early:
            // start → 23:59 (covers from start time to end of day)
            return DeviceActivitySchedule(
                intervalStart: DateComponents(hour: startHour, minute: startMinute),
                intervalEnd: DateComponents(hour: 23, minute: 59),
                repeats: repeats
            )
        case .late:
            // 00:00 → end (covers early morning)
            return DeviceActivitySchedule(
                intervalStart: DateComponents(hour: 0, minute: 0),
                intervalEnd: DateComponents(hour: endHour, minute: endMinute),
                repeats: repeats
            )
        }
    }

    enum CrossingSegment {
        case full
        case early
        case late
    }
#endif
}
