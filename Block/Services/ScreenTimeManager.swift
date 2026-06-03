//
//  ScreenTimeManager.swift
//  Block
//
//  Created by Amit Sankaran on 1/7/26.
//
//  Every block — scheduled, timer, or NFC tag — applies through its own
//  `ManagedSettingsStore(named: "block.<UUID>")` pair (apps + categories). iOS
//  unions shields across stores, so blocks never clobber each other.
//

import Foundation
import FamilyControls
import ManagedSettings
import Combine

@MainActor
class ScreenTimeManager: ObservableObject {
    static let shared = ScreenTimeManager()

    @Published var authorizationStatus: AuthorizationStatus = .notDetermined

    private var blockStores: [UUID: (apps: ManagedSettingsStore, categories: ManagedSettingsStore)] = [:]

    private init() {
        checkAuthorizationStatus()
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 100_000_000)
            checkAuthorizationStatus()
            restoreBlockingIfNeeded()
            try? await Task.sleep(nanoseconds: 500_000_000)
            checkAuthorizationStatus()
        }
    }

    /// Reapply shields for blocks that should be on across launches: manually
    /// force-enabled blocks and toggled-on tag blocks. (Scheduled/usage shields
    /// persist in their named stores and are managed by the extension.)
    func restoreBlockingIfNeeded() {
        guard authorizationStatus == .approved else {
            print("⚠️ Cannot restore blocking: authorization not approved")
            return
        }
        for block in BlockStore.shared.blocks where block.isEnabled {
            applyBlockShield(block)
        }
    }

    func checkAuthorizationStatus() {
        let previousStatus = authorizationStatus
        let status = AuthorizationCenter.shared.authorizationStatus
        authorizationStatus = status
        if previousStatus != .approved && status == .approved {
            restoreBlockingIfNeeded()
        }
    }

    func requestAuthorization() async throws {
        try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
        checkAuthorizationStatus()
        restoreBlockingIfNeeded()
    }

    // MARK: - Per-block named stores

    private func stores(for id: UUID) -> (apps: ManagedSettingsStore, categories: ManagedSettingsStore) {
        if let existing = blockStores[id] { return existing }
        let pair = (
            apps: ManagedSettingsStore(named: BlockingActuator.appsStoreName(for: id)),
            categories: ManagedSettingsStore(named: BlockingActuator.categoriesStoreName(for: id))
        )
        blockStores[id] = pair
        return pair
    }

    /// Apply a block's shield (union of its groups' tokens) to its named stores.
    func applyBlockShield(_ block: BlockRule) {
        guard authorizationStatus == .approved else {
            #if DEBUG
            DebugLog.shared.log(.screenTime, "applyBlockShield(\(block.name)) skipped — auth not approved")
            #endif
            return
        }
        let pair = stores(for: block.id)
        let tokens = BlockResolution.tokens(for: block, groups: AppGroupStore.shared.groups)
        BlockingActuator.apply(tokens: tokens, appsStore: pair.apps, categoriesStore: pair.categories)
        #if DEBUG
        DebugLog.shared.log(.screenTime, "applyBlockShield(\(block.name)): \(tokens.apps.count) apps, \(tokens.categories.count) categories")
        #endif
    }

    /// Clear a block's shield (cooldown completion, manual disable, tag toggle-off).
    func clearBlockShield(id: UUID) {
        let pair = stores(for: id)
        pair.apps.clearAllSettings()
        pair.categories.clearAllSettings()
        #if DEBUG
        DebugLog.shared.log(.screenTime, "clearBlockShield for \(id.uuidString.prefix(8))")
        #endif
    }

    /// Emergency override: clear every block's shield and turn off manual/tag
    /// state. Scheduled/timer blocks may re-apply at their next interval.
    func disableAllBlocks() {
        for block in BlockStore.shared.blocks {
            clearBlockShield(id: block.id)
            UsageMonitoring.stopLockout(for: block.id)
            SharedDefaults.suite.removeObject(forKey: SharedDefaults.Keys.running(blockID: block.id))
            if block.isEnabled {
                BlockStore.shared.setEnabled(id: block.id, enabled: false)
            }
        }
        CooldownManager.shared.cancel()
        SchedulingManager.shared.refresh()
        UsageLimitManager.shared.refresh()
    }

    /// Re-apply if currently shielded (manual, scheduled-running, or usage-locked).
    func updateBlockShieldIfActive(_ block: BlockRule) {
        let suite = SharedDefaults.suite
        let scheduledActive = suite.bool(forKey: SharedDefaults.Keys.running(blockID: block.id))
        let usageLocked = (suite.object(forKey: SharedDefaults.Keys.usageLockEnd(blockID: block.id)) as? Date).map { $0 > Date() } ?? false
        if block.isEnabled || scheduledActive || usageLocked {
            applyBlockShield(block)
        }
    }
}
