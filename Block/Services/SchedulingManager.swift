//
//  SchedulingManager.swift
//  Block
//
//  Wraps `DeviceActivityCenter` to register/unregister scheduled monitoring per
//  `.schedule` block. The extension applies the shield at `intervalDidStart` /
//  `intervalDidEnd`. Relaunch reconciles the named stores itself: stopping the
//  monitor does not deliver `intervalDidEnd`, so a stop that only clears the
//  running flag leaves the shield up while the block looks inactive.
//

import Foundation
import DeviceActivity
import Combine

@MainActor
class SchedulingManager: ObservableObject {
    static let shared = SchedulingManager()

    @Published private(set) var activeScheduledBlockIDs: Set<UUID> = []
    @Published var lastError: String?

    private let center = DeviceActivityCenter()
    private var refreshTimer: Timer?

    private init() {
        refresh()
        startPeriodicRefresh()
    }

    // MARK: - Activity name helpers

    static func activityName(for blockID: UUID, segment: BlockingSchedule.CrossingSegment = .full) -> DeviceActivityName {
        switch segment {
        case .full:  return DeviceActivityName(rawValue: "block.\(blockID.uuidString)")
        case .early: return DeviceActivityName(rawValue: "block.\(blockID.uuidString).early")
        case .late:  return DeviceActivityName(rawValue: "block.\(blockID.uuidString).late")
        }
    }

    // MARK: - Public API

    /// Register or update monitoring for a block's schedule, and make the named
    /// stores match whether the window is active right now.
    ///
    /// Inside the window, relaunch does not stop the monitor. `stopMonitoring` does
    /// not deliver `intervalDidEnd`, and a fresh `startMonitoring` can, so tearing
    /// the monitor down on every launch cleared the running flag and left the shield up.
    ///
    /// `restartMonitoring` is for an edited schedule, which has to replace the
    /// registered interval. Relaunch leaves it false.
    func applySchedule(for block: BlockRule, now: Date = Date(), restartMonitoring: Bool = false) {
        guard block.type == .schedule, let schedule = block.schedule else {
            removeSchedule(for: block, now: now)
            return
        }

        let intent = schedule.shieldIntent(at: now, userReleased: isScheduleReleased(block.id, now: now))
        if restartMonitoring {
            center.stopMonitoring(Self.activityNames(for: block.id))
        }
        switch intent {
        case .enforce:
            ensureMonitoring(block: block, schedule: schedule)
            SharedDefaults.suite.set(true, forKey: SharedDefaults.Keys.running(blockID: block.id))
            if BreakMonitoring.isOnBreak(blockID: block.id) {
                // The break lifted the shield on purpose. clearBlockShield would cancel it.
                BlockingActuator.clearShields(blockID: block.id)
            } else {
                ScreenTimeManager.shared.applyBlockShield(block)
            }
        case .holdRelease:
            // Cooldown or emergency already ended this window. Relaunch leaves the
            // monitor alone so a start inside the interval cannot put the shield
            // back. A store that is still up would be active while the block looks off.
            if restartMonitoring {
                ensureMonitoring(block: block, schedule: schedule)
            }
            SharedDefaults.suite.removeObject(forKey: SharedDefaults.Keys.running(blockID: block.id))
            clearUnheldShield(for: block, now: now)
        case .clear:
            removeSchedule(for: block, now: now)
            ensureMonitoring(block: block, schedule: schedule)
        }
        #if DEBUG
        DebugLog.shared.log(.deviceActivity, "applySchedule(\(block.name)): \(intent) \(schedule.summary)")
        #endif
    }

    /// Remember that this schedule window was lifted early, until the window ends.
    func suppressScheduleShieldUntilWindowEnd(for block: BlockRule, now: Date = Date()) {
        guard block.type == .schedule, let schedule = block.schedule,
              let end = schedule.currentWindowEnd(from: now) else { return }
        SharedDefaults.suite.set(end, forKey: SharedDefaults.Keys.scheduleReleasedUntil(blockID: block.id))
    }

    func removeSchedule(for block: BlockRule) {
        removeSchedule(for: block, now: Date())
    }

    /// Stop the schedule monitors. Outside the window, also clear the block's
    /// named stores — the extension will not deliver `intervalDidEnd` after
    /// `stopMonitoring`.
    func removeSchedule(for block: BlockRule, now: Date) {
        center.stopMonitoring(Self.activityNames(for: block.id))
        SharedDefaults.suite.removeObject(forKey: SharedDefaults.Keys.running(blockID: block.id))
        let stillInside = block.type == .schedule && (block.schedule?.contains(now) == true)
        if !stillInside {
            SharedDefaults.suite.removeObject(forKey: SharedDefaults.Keys.scheduleReleasedUntil(blockID: block.id))
            clearUnheldShield(for: block, now: now)
        }
        #if DEBUG
        DebugLog.shared.log(.deviceActivity, "removeSchedule(\(block.name)) inside=\(stillInside)")
        #endif
    }

    /// Re-register every schedule block and reconcile its shield with the clock.
    /// Call once at launch, and again once Screen Time authorization is approved.
    func reapplyAllSchedules(now: Date = Date()) {
        for block in BlockStore.shared.blocks where block.type == .schedule && block.schedule != nil {
            applySchedule(for: block, now: now)
        }
        refresh()
    }

    /// Refresh `activeScheduledBlockIDs` from the App Group running flags.
    func refresh() {
        var ids: Set<UUID> = []
        let suite = SharedDefaults.suite
        for block in BlockStore.shared.blocks where block.type == .schedule {
            if suite.bool(forKey: SharedDefaults.Keys.running(blockID: block.id)) {
                ids.insert(block.id)
            }
        }
        if ids != activeScheduledBlockIDs {
            activeScheduledBlockIDs = ids
        }
    }

    // MARK: - Private

    private static func activityNames(for blockID: UUID) -> [DeviceActivityName] {
        [
            activityName(for: blockID, segment: .full),
            activityName(for: blockID, segment: .early),
            activityName(for: blockID, segment: .late)
        ]
    }

    private func isScheduleReleased(_ blockID: UUID, now: Date) -> Bool {
        guard let until = SharedDefaults.suite.object(
            forKey: SharedDefaults.Keys.scheduleReleasedUntil(blockID: blockID)
        ) as? Date else { return false }
        return now < until
    }

    /// Manual "Block now" or a usage lock can hold the same named stores. Clearing
    /// them here would drop a shield the schedule window is not responsible for.
    private func clearUnheldShield(for block: BlockRule, now: Date) {
        let usageLocked = (SharedDefaults.suite.object(
            forKey: SharedDefaults.Keys.usageLockEnd(blockID: block.id)
        ) as? Date).map { $0 > now } ?? false
        guard !block.isEnabled, !usageLocked else { return }
        ScreenTimeManager.shared.clearBlockShield(id: block.id)
    }

    /// Start any missing segment. Does not stop a monitor that is already
    /// registered: stopping an in-window activity drops the shield without an
    /// `intervalDidEnd`, which is the relaunch bug.
    private func ensureMonitoring(block: BlockRule, schedule: BlockingSchedule) {
        let segments: [BlockingSchedule.CrossingSegment] = schedule.crossesMidnight ? [.early, .late] : [.full]
        do {
            for segment in segments {
                let name = Self.activityName(for: block.id, segment: segment)
                if center.activities.contains(name) { continue }
                try center.startMonitoring(name, during: schedule.deviceActivitySchedule(crossingSegment: segment))
            }
            lastError = nil
        } catch {
            print("❌ startMonitoring failed for block \(block.id): \(error)")
            lastError = "Couldn't start schedule: \(error.localizedDescription)"
            #if DEBUG
            DebugLog.shared.log(.deviceActivity, "ensureMonitoring(\(block.name)) FAILED: \(error.localizedDescription)")
            #endif
        }
    }

    private func startPeriodicRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.refresh() }
        }
    }
}
