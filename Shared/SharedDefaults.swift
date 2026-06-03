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
        static let presets = "presets.v1"
        static let selectedApps = "selectedApps"
        static let hasSelectedApps = "hasSelectedApps"
        static let registeredTag = "registeredTagIdentifier"
        static let blockingEnabled = "isBlockingEnabled"

        static func cooldownEnd(presetID: UUID) -> String { "cooldown.\(presetID.uuidString)" }
        static func running(presetID: UUID) -> String { "running.\(presetID.uuidString)" }
        /// `Date` when the current usage-limit lockout auto-expires. Presence of a
        /// future date is the source of truth for "this preset is usage-locked".
        static func usageLockEnd(presetID: UUID) -> String { "usagelock.\(presetID.uuidString)" }
    }
}
