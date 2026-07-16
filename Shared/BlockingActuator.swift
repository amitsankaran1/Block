//
//  BlockingActuator.swift
//  Block
//
//  Shared shielding logic for a block. Used by:
//    - BlockMonitorExtension (real device, on schedule / threshold)
//    - DebugSimulator (in-process, for simulator/dev testing)
//
//  A block's shield = the union of its referenced AppGroups' tokens
//  (see BlockResolution). Add target membership to BOTH Block and BlockMonitor.
//

import Foundation
import ManagedSettings
import FamilyControls

enum BlockingActuator {

    /// Apply the block's shield to its named store.
    /// Mirrors `BlockMonitorExtension.intervalDidStart` so simulator and device
    /// behavior stay in lockstep.
    ///
    /// - Parameter setRunningFlag: when `true` (scheduled blocks), marks the
    ///   `running` flag that drives the home "Scheduled" display. The usage-lock
    ///   path passes `false` — usage locks are tracked separately via
    ///   `usageLockEnd`, so they must not masquerade as scheduled blocks.
    @discardableResult
    static func start(blockID: UUID, bypassWeekday: Bool = false, setRunningFlag: Bool = true) -> Bool {
        guard let block = BlockResolution.loadBlock(id: blockID) else { return false }

        if !bypassWeekday, block.type == .schedule, let schedule = block.schedule {
            let weekday = Calendar.current.component(.weekday, from: Date())
            guard schedule.weekdays.contains(weekday) else { return false }
        }

        let tokens = BlockResolution.tokens(for: block, groups: BlockResolution.loadGroups())
        apply(
            tokens: tokens,
            appsStore: ManagedSettingsStore(named: appsStoreName(for: blockID)),
            categoriesStore: ManagedSettingsStore(named: categoriesStoreName(for: blockID))
        )

        if setRunningFlag {
            SharedDefaults.suite.set(true, forKey: SharedDefaults.Keys.running(blockID: blockID))
        }
        return true
    }

    /// Clear the block's shield and running flag. Mirrors `intervalDidEnd`.
    static func end(blockID: UUID) {
        ManagedSettingsStore(named: appsStoreName(for: blockID)).clearAllSettings()
        ManagedSettingsStore(named: categoriesStoreName(for: blockID)).clearAllSettings()
        SharedDefaults.suite.removeObject(forKey: SharedDefaults.Keys.running(blockID: blockID))
    }

    /// Apply token sets across two physical stores. iOS unions shields across stores;
    /// setting `shield.applications` and `shield.applicationCategories = .specific(...)` on
    /// the *same* store has been observed to drop the individual-apps shield, so we keep
    /// them on separate stores. Each property is written unconditionally (nil when empty).
    static func apply(
        tokens: BlockResolution.Tokens,
        appsStore: ManagedSettingsStore,
        categoriesStore: ManagedSettingsStore
    ) {
        appsStore.shield.applications = tokens.apps.isEmpty ? nil : tokens.apps
        appsStore.shield.applicationCategories = nil
        appsStore.shield.webDomains = tokens.webDomains.isEmpty ? nil : tokens.webDomains
        // Typed-in domains have no picker token; the content filter blocks them in
        // Safari (incl. private browsing) with no "allow anyway" escape.
        appsStore.webContent.blockedByFilter = tokens.domains.isEmpty
            ? nil
            : .specific(Set(tokens.domains.map { WebDomain(domain: $0) }))

        categoriesStore.shield.applications = nil
        categoriesStore.shield.applicationCategories = tokens.categories.isEmpty
            ? nil
            : .specific(tokens.categories)
    }

    // MARK: - Helpers

    /// Backed by `block.<UUID>` — holds `shield.applications` + `shield.webDomains`.
    static func appsStoreName(for blockID: UUID) -> ManagedSettingsStore.Name {
        ManagedSettingsStore.Name(rawValue: "block.\(blockID.uuidString)")
    }

    /// Companion store holding `shield.applicationCategories`.
    static func categoriesStoreName(for blockID: UUID) -> ManagedSettingsStore.Name {
        ManagedSettingsStore.Name(rawValue: "block.\(blockID.uuidString).cats")
    }
}
