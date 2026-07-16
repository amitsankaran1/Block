//
//  DebugSimulator.swift
//  Block
//
//  Test affordances exposed in DebugMenuView. All compiled out of release.
//
//  Provides in-process stand-ins for the BlockMonitor extension (which doesn't
//  run on Simulator): fire a schedule interval, fire a usage threshold, expire a
//  lockout, fast-forward a cooldown — plus NFC simulation and a state snapshot.
//

#if DEBUG

import Foundation
import FamilyControls

@MainActor
enum DebugSimulator {

    // MARK: - Schedule simulation

    static func fireScheduleStart(blockID: UUID) {
        BlockStore.shared.flush()
        AppGroupStore.shared.flush()
        let applied = BlockingActuator.start(blockID: blockID, bypassWeekday: true)
        DebugLog.shared.log(.actuator, applied
            ? "fireScheduleStart applied for block \(blockID.uuidString.prefix(8))"
            : "fireScheduleStart skipped (block missing) \(blockID.uuidString.prefix(8))")
        SchedulingManager.shared.refresh()
    }

    static func fireScheduleEnd(blockID: UUID) {
        BlockingActuator.end(blockID: blockID)
        DebugLog.shared.log(.actuator, "fireScheduleEnd cleared block \(blockID.uuidString.prefix(8))")
        SchedulingManager.shared.refresh()
    }

    // MARK: - NFC simulation

    static func simulateRegisteredTagScan() {
        guard let id = AppConfigurationStore.shared.registeredTagIdentifier else {
            DebugLog.shared.log(.nfc, "no tag registered — use 'Register fake tag' first")
            return
        }
        DebugLog.shared.log(.nfc, "simulating registered tag scan: \(id)")
        NFCManager.shared.simulateTagScan(withId: id)
    }

    static func simulateUnknownTagScan() {
        let fake = "deadbeef\(Int.random(in: 1000...9999))"
        DebugLog.shared.log(.nfc, "simulating unknown tag scan: \(fake)")
        NFCManager.shared.simulateTagScan(withId: fake)
    }

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

    static func expireCooldown() {
        guard let active = CooldownManager.shared.activeCooldown else {
            DebugLog.shared.log(.cooldown, "no active cooldown to fast-forward")
            return
        }
        SharedDefaults.suite.set(Date(), forKey: SharedDefaults.Keys.cooldownEnd(blockID: active.blockID))
        DebugLog.shared.log(.cooldown, "fast-forwarded cooldown for block \(active.blockID.uuidString.prefix(8))")
        CooldownManager.shared.complete()
    }

    static func startShortCooldown(blockID: UUID, seconds: Int = 10) {
        let endsAt = Date().addingTimeInterval(TimeInterval(seconds))
        SharedDefaults.suite.set(endsAt, forKey: SharedDefaults.Keys.cooldownEnd(blockID: blockID))
        CooldownManager.shared.restoreActiveCooldownsIfAny()
        DebugLog.shared.log(.cooldown, "started \(seconds)s cooldown for block \(blockID.uuidString.prefix(8))")
    }

    // MARK: - Usage-limit simulation

    static func fireUsageThreshold(blockID: UUID) {
        BlockStore.shared.flush()
        AppGroupStore.shared.flush()
        let applied = BlockingActuator.start(blockID: blockID, bypassWeekday: true, setRunningFlag: false)
        let lockMinutes = BlockStore.shared.block(id: blockID)?.usageLockMinutes ?? 180
        UsageMonitoring.startLockout(blockID: blockID, minutes: lockMinutes)
        UsageLimitManager.shared.refresh()
        DebugLog.shared.log(.actuator, applied
            ? "fireUsageThreshold: locked \(blockID.uuidString.prefix(8)) for \(lockMinutes)m"
            : "fireUsageThreshold skipped (block missing) \(blockID.uuidString.prefix(8))")
    }

    static func expireUsageLock(blockID: UUID) {
        SharedDefaults.suite.set(Date(), forKey: SharedDefaults.Keys.usageLockEnd(blockID: blockID))
        UsageLimitManager.shared.reconcileExpiredLocks()
        DebugLog.shared.log(.actuator, "expired usage lock for \(blockID.uuidString.prefix(8))")
    }

    // MARK: - Reset

    /// Clear every block shield + running flag + cooldown + usage lock.
    /// Doesn't delete blocks/groups themselves.
    static func resetAllRuntime() {
        let suite = SharedDefaults.suite
        for block in BlockStore.shared.blocks {
            BlockingActuator.clearShields(blockID: block.id)
            suite.removeObject(forKey: SharedDefaults.Keys.running(blockID: block.id))
            suite.removeObject(forKey: SharedDefaults.Keys.cooldownEnd(blockID: block.id))
            UsageMonitoring.stopLockout(for: block.id)
            if block.isEnabled { BlockStore.shared.setEnabled(id: block.id, enabled: false) }
        }
        CooldownManager.shared.cancel()
        SchedulingManager.shared.refresh()
        UsageLimitManager.shared.refresh()
        DebugLog.shared.log(.state, "reset all runtime state (blocks + groups preserved)")
    }

    // MARK: - State snapshot

    struct BlockSnapshot: Identifiable {
        let id: UUID
        let name: String
        let type: BlockType
        let groupNames: [String]
        let appCount: Int
        let categoryCount: Int
        let scheduleSummary: String?
        let isEnabled: Bool
        let isScheduledRunning: Bool
        let cooldownEndsAt: Date?
        let cooldownMinutes: Int
        let usageLimitMinutes: Int?
        let usageLockMinutes: Int
        let usageLockEndsAt: Date?
    }

    struct GlobalSnapshot {
        let authorizationStatus: AuthorizationStatus
        let registeredTag: String?
        let groupCount: Int
        let activeScheduledIDs: Set<UUID>
        let blocks: [BlockSnapshot]
        let activeCooldownBlockID: UUID?
    }

    static func snapshot() -> GlobalSnapshot {
        let suite = SharedDefaults.suite
        let groups = AppGroupStore.shared.groups

        let blockSnapshots: [BlockSnapshot] = BlockStore.shared.blocks.map { block in
            let tokens = BlockResolution.tokens(for: block, groups: groups)
            return BlockSnapshot(
                id: block.id,
                name: block.name,
                type: block.type,
                groupNames: groups.filter { block.appGroupIDs.contains($0.id) }.map { $0.name },
                appCount: tokens.apps.count,
                categoryCount: tokens.categories.count,
                scheduleSummary: block.schedule?.summary,
                isEnabled: block.isEnabled,
                isScheduledRunning: suite.bool(forKey: SharedDefaults.Keys.running(blockID: block.id)),
                cooldownEndsAt: suite.object(forKey: SharedDefaults.Keys.cooldownEnd(blockID: block.id)) as? Date,
                cooldownMinutes: block.cooldownMinutes,
                usageLimitMinutes: block.usageLimitMinutes,
                usageLockMinutes: block.usageLockMinutes,
                usageLockEndsAt: suite.object(forKey: SharedDefaults.Keys.usageLockEnd(blockID: block.id)) as? Date
            )
        }

        return GlobalSnapshot(
            authorizationStatus: ScreenTimeManager.shared.authorizationStatus,
            registeredTag: AppConfigurationStore.shared.registeredTagIdentifier,
            groupCount: groups.count,
            activeScheduledIDs: SchedulingManager.shared.activeScheduledBlockIDs,
            blocks: blockSnapshots,
            activeCooldownBlockID: CooldownManager.shared.activeCooldown?.blockID
        )
    }
}

#endif
