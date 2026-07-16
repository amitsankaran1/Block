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
        apply(tokens: tokens, blockID: blockID)

        if setRunningFlag {
            SharedDefaults.suite.set(true, forKey: SharedDefaults.Keys.running(blockID: blockID))
        }
        return true
    }

    /// Clear the block's shield and running flag. Mirrors `intervalDidEnd`.
    static func end(blockID: UUID) {
        clearShields(blockID: blockID)
        SharedDefaults.suite.removeObject(forKey: SharedDefaults.Keys.running(blockID: blockID))
    }

    /// `shield.applications` (and `shield.webDomains`) silently fails — the whole
    /// property is dropped — when given more than 50 tokens, so each chunk store
    /// holds at most 50. iOS unions shields across stores.
    static let tokensPerStore = 50
    /// Bound on chunk stores per block (400 apps + 400 domains). Apple caps an app
    /// and its extensions at 50 stores total, so blocks can't grow stores unbounded.
    static let maxChunksPerBlock = 8

    /// Apply token sets across the block's physical stores. iOS unions shields across
    /// stores; setting `shield.applications` and `shield.applicationCategories =
    /// .specific(...)` on the *same* store has been observed to drop the
    /// individual-apps shield, so categories live in their own store. Apps and web
    /// domains are chunked across `tokensPerStore`-sized stores. Every property is
    /// written unconditionally (nil when empty), and stores from a previous, larger
    /// apply are cleared so re-applying a shrunken selection leaves no stale shields.
    static func apply(tokens: BlockResolution.Tokens, blockID: UUID) {
        var appChunks = chunks(tokens.apps, size: tokensPerStore)
        var webChunks = chunks(tokens.webDomains, size: tokensPerStore)
        if appChunks.count > maxChunksPerBlock || webChunks.count > maxChunksPerBlock {
            print("⚠️ BlockingActuator: selection exceeds \(maxChunksPerBlock * tokensPerStore) tokens; truncating (\(tokens.apps.count) apps, \(tokens.webDomains.count) domains)")
            appChunks = Array(appChunks.prefix(maxChunksPerBlock))
            webChunks = Array(webChunks.prefix(maxChunksPerBlock))
        }
        let newCount = max(1, appChunks.count, webChunks.count)

        for i in 0..<newCount {
            let store = ManagedSettingsStore(named: appsStoreName(for: blockID, chunk: i))
            store.shield.applications = i < appChunks.count ? appChunks[i] : nil
            store.shield.applicationCategories = nil
            store.shield.webDomains = i < webChunks.count ? webChunks[i] : nil
        }
        let oldCount = max(1, SharedDefaults.suite.integer(forKey: SharedDefaults.Keys.shieldChunkCount(blockID: blockID)))
        for i in newCount..<max(newCount, oldCount) {
            ManagedSettingsStore(named: appsStoreName(for: blockID, chunk: i)).clearAllSettings()
        }
        SharedDefaults.suite.set(newCount, forKey: SharedDefaults.Keys.shieldChunkCount(blockID: blockID))

        let categoriesStore = ManagedSettingsStore(named: categoriesStoreName(for: blockID))
        categoriesStore.shield.applications = nil
        categoriesStore.shield.applicationCategories = tokens.categories.isEmpty
            ? nil
            : .specific(tokens.categories)
    }

    /// Clear every store the block's shield occupies (all app/webDomain chunks plus
    /// the categories store). A missing chunk count means at most the legacy single
    /// apps store was written, so chunk 0 + cats is exactly the right set.
    static func clearShields(blockID: UUID) {
        let count = max(1, SharedDefaults.suite.integer(forKey: SharedDefaults.Keys.shieldChunkCount(blockID: blockID)))
        for i in 0..<count {
            ManagedSettingsStore(named: appsStoreName(for: blockID, chunk: i)).clearAllSettings()
        }
        ManagedSettingsStore(named: categoriesStoreName(for: blockID)).clearAllSettings()
        SharedDefaults.suite.removeObject(forKey: SharedDefaults.Keys.shieldChunkCount(blockID: blockID))
    }

    // MARK: - Helpers

    /// Slice a token set into `size`-sized sets. Order is arbitrary; only membership
    /// matters since every apply rewrites all chunks.
    static func chunks<T: Hashable>(_ set: Set<T>, size: Int) -> [Set<T>] {
        guard !set.isEmpty else { return [] }
        let elements = Array(set)
        return stride(from: 0, to: elements.count, by: size).map {
            Set(elements[$0..<min($0 + size, elements.count)])
        }
    }

    /// Chunk `i` of the stores holding `shield.applications` + `shield.webDomains`.
    /// Chunk 0 keeps the legacy `block.<UUID>` name so shields that were active
    /// before chunking shipped stay attached to the same store across an update.
    static func appsStoreName(for blockID: UUID, chunk: Int = 0) -> ManagedSettingsStore.Name {
        chunk == 0
            ? ManagedSettingsStore.Name(rawValue: "block.\(blockID.uuidString)")
            : ManagedSettingsStore.Name(rawValue: "block.\(blockID.uuidString).apps.\(chunk)")
    }

    /// Companion store holding `shield.applicationCategories`.
    static func categoriesStoreName(for blockID: UUID) -> ManagedSettingsStore.Name {
        ManagedSettingsStore.Name(rawValue: "block.\(blockID.uuidString).cats")
    }
}
