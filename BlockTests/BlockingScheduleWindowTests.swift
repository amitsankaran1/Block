//
//  BlockingScheduleWindowTests.swift
//  BlockTests
//
//  Pure clock math for the schedule relaunch fix. No Family Controls tokens.
//

import XCTest
@testable import Block

@MainActor
final class BlockingScheduleWindowTests: XCTestCase {

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    /// 2026-09-26 is a Saturday. Monday is the 21st, Friday the 25th.
    private func date(year: Int, month: Int, day: Int, hour: Int, minute: Int) -> Date {
        let parts = DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)
        return calendar.date(from: parts)!
    }

    private func weekdaySchedule() -> BlockingSchedule {
        BlockingSchedule(
            startHour: 9, startMinute: 0,
            endHour: 17, endMinute: 0,
            weekdays: [2, 3, 4, 5, 6]
        )
    }

    func testKnownWeekdays() {
        XCTAssertEqual(calendar.component(.weekday, from: date(year: 2026, month: 9, day: 21, hour: 12, minute: 0)), 2)
        XCTAssertEqual(calendar.component(.weekday, from: date(year: 2026, month: 9, day: 25, hour: 12, minute: 0)), 6)
        XCTAssertEqual(calendar.component(.weekday, from: date(year: 2026, month: 9, day: 26, hour: 12, minute: 0)), 7)
    }

    func testWeekdayWindowBoundaries() {
        let schedule = weekdaySchedule()
        let mondayMorning = date(year: 2026, month: 9, day: 21, hour: 8, minute: 59)
        let mondayStart = date(year: 2026, month: 9, day: 21, hour: 9, minute: 0)
        let mondayAfternoon = date(year: 2026, month: 9, day: 21, hour: 16, minute: 59)
        let mondayEnd = date(year: 2026, month: 9, day: 21, hour: 17, minute: 0)
        let saturday = date(year: 2026, month: 9, day: 26, hour: 12, minute: 0)

        XCTAssertFalse(schedule.contains(mondayMorning, calendar: calendar))
        XCTAssertTrue(schedule.contains(mondayStart, calendar: calendar))
        XCTAssertTrue(schedule.contains(mondayAfternoon, calendar: calendar))
        XCTAssertFalse(schedule.contains(mondayEnd, calendar: calendar))
        XCTAssertFalse(schedule.contains(saturday, calendar: calendar))
    }

    func testCrossMidnightBelongsToPreviousWeekday() {
        let schedule = BlockingSchedule(
            startHour: 22, startMinute: 0,
            endHour: 2, endMinute: 0,
            weekdays: [6]
        )
        let fridayBefore = date(year: 2026, month: 9, day: 25, hour: 21, minute: 59)
        let fridayStart = date(year: 2026, month: 9, day: 25, hour: 22, minute: 0)
        let fridayLate = date(year: 2026, month: 9, day: 25, hour: 23, minute: 30)
        let saturdayEarly = date(year: 2026, month: 9, day: 26, hour: 1, minute: 0)
        let saturdayEnd = date(year: 2026, month: 9, day: 26, hour: 2, minute: 0)
        let saturdayNight = date(year: 2026, month: 9, day: 26, hour: 23, minute: 0)

        XCTAssertFalse(schedule.contains(fridayBefore, calendar: calendar))
        XCTAssertTrue(schedule.contains(fridayStart, calendar: calendar))
        XCTAssertTrue(schedule.contains(fridayLate, calendar: calendar))
        XCTAssertTrue(schedule.contains(saturdayEarly, calendar: calendar))
        XCTAssertFalse(schedule.contains(saturdayEnd, calendar: calendar))
        XCTAssertFalse(schedule.contains(saturdayNight, calendar: calendar))
    }

    func testCurrentWindowEnd() {
        let weekday = weekdaySchedule()
        let mondayNoon = date(year: 2026, month: 9, day: 21, hour: 12, minute: 0)
        let end = weekday.currentWindowEnd(from: mondayNoon, calendar: calendar)
        XCTAssertEqual(end, date(year: 2026, month: 9, day: 21, hour: 17, minute: 0))
        XCTAssertNil(weekday.currentWindowEnd(from: date(year: 2026, month: 9, day: 21, hour: 17, minute: 0), calendar: calendar))

        let overnight = BlockingSchedule(
            startHour: 22, startMinute: 0,
            endHour: 2, endMinute: 0,
            weekdays: [6]
        )
        let fridayNight = date(year: 2026, month: 9, day: 25, hour: 23, minute: 0)
        XCTAssertEqual(
            overnight.currentWindowEnd(from: fridayNight, calendar: calendar),
            date(year: 2026, month: 9, day: 26, hour: 2, minute: 0)
        )
        let saturdayEarly = date(year: 2026, month: 9, day: 26, hour: 1, minute: 0)
        XCTAssertEqual(
            overnight.currentWindowEnd(from: saturdayEarly, calendar: calendar),
            date(year: 2026, month: 9, day: 26, hour: 2, minute: 0)
        )
    }

    func testShieldIntent() {
        let schedule = weekdaySchedule()
        let during = date(year: 2026, month: 9, day: 21, hour: 12, minute: 0)
        let after = date(year: 2026, month: 9, day: 21, hour: 18, minute: 0)

        XCTAssertEqual(schedule.shieldIntent(at: during, userReleased: false, calendar: calendar), .enforce)
        XCTAssertEqual(schedule.shieldIntent(at: during, userReleased: true, calendar: calendar), .holdRelease)
        XCTAssertEqual(schedule.shieldIntent(at: after, userReleased: false, calendar: calendar), .clear)
        XCTAssertEqual(schedule.shieldIntent(at: after, userReleased: true, calendar: calendar), .clear)
    }
}
