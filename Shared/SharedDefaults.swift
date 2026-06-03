//
//  SharedDefaults.swift
//  Block
//
//  Shared between the host app and the BlockMonitor extension via App Group.
//  Add this file's target membership to BOTH the Block and BlockMonitor targets.
//

import Foundation

enum SharedDefaults {
    static let appGroupID = "group.com.amitsankaran.Block"

    static let suite: UserDefaults = {
        guard let suite = UserDefaults(suiteName: appGroupID) else {
            assertionFailure("App Group \(appGroupID) is not configured. Add it to both target entitlements.")
            return .standard
        }
        return suite
    }()

    enum Keys {
        /// Legacy v1 presets — read once by the migration, then superseded by `blocks`/`groups`.
        static let presets = "presets.v1"
        /// Reusable app lists ([AppGroup]) and blocking rules ([BlockRule]).
        static let groups = "groups.v1"
        static let blocks = "blocks.v2"
        /// Set once the one-time presets.v1 → groups+blocks migration has run.
        static let migratedToBlocksV2 = "migratedToBlocksV2"

        static let selectedApps = "selectedApps"
        static let hasSelectedApps = "hasSelectedApps"
        static let registeredTag = "registeredTagIdentifier"
        static let blockingEnabled = "isBlockingEnabled"

        static func cooldownEnd(blockID: UUID) -> String { "cooldown.\(blockID.uuidString)" }
        static func running(blockID: UUID) -> String { "running.\(blockID.uuidString)" }
        /// `Date` when the current usage-limit lockout auto-expires. Presence of a
        /// future date is the source of truth for "this block is usage-locked".
        static func usageLockEnd(blockID: UUID) -> String { "usagelock.\(blockID.uuidString)" }
    }
}
