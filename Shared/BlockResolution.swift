//
//  BlockResolution.swift
//  Block
//
//  Resolves a BlockRule to the enforcement tokens it should shield: the union of
//  its referenced AppGroups' tokens. Shared by the app and the BlockMonitor
//  extension so both compute identical shields (mirrors BlockingActuator).
//
//  We union the readable token Sets directly (rather than reconstruct a
//  FamilyActivitySelection) and feed them straight to ManagedSettingsStore
//  shields and DeviceActivityEvent — both take token sets.
//
//  Add target membership to BOTH Block and BlockMonitor targets.
//

import Foundation
import FamilyControls
import ManagedSettings

enum BlockResolution {

    struct Tokens {
        var apps: Set<ApplicationToken>
        var categories: Set<ActivityCategoryToken>
        var webDomains: Set<WebDomainToken>

        var isEmpty: Bool { apps.isEmpty && categories.isEmpty && webDomains.isEmpty }
    }

    /// Union of the selections of the groups a block references.
    static func tokens(for block: BlockRule, groups: [AppGroup]) -> Tokens {
        var apps: Set<ApplicationToken> = []
        var categories: Set<ActivityCategoryToken> = []
        var webDomains: Set<WebDomainToken> = []
        let referenced = block.appGroupIDs
        for group in groups where referenced.contains(group.id) {
            apps.formUnion(group.selection.applicationTokens)
            categories.formUnion(group.selection.categoryTokens)
            webDomains.formUnion(group.selection.webDomainTokens)
        }
        return Tokens(apps: apps, categories: categories, webDomains: webDomains)
    }

    // MARK: - Shared-store loaders (used by app + extension)

    static func loadGroups() -> [AppGroup] {
        guard let data = SharedDefaults.suite.data(forKey: SharedDefaults.Keys.groups) else { return [] }
        return (try? JSONDecoder().decode([AppGroup].self, from: data)) ?? []
    }

    static func loadBlocks() -> [BlockRule] {
        guard let data = SharedDefaults.suite.data(forKey: SharedDefaults.Keys.blocks) else { return [] }
        return (try? JSONDecoder().decode([BlockRule].self, from: data)) ?? []
    }

    static func loadBlock(id: UUID) -> BlockRule? {
        loadBlocks().first(where: { $0.id == id })
    }

    /// Tokens for a block id, resolved against the persisted groups.
    static func tokens(forBlockID id: UUID) -> Tokens? {
        guard let block = loadBlock(id: id) else { return nil }
        return tokens(for: block, groups: loadGroups())
    }
}
