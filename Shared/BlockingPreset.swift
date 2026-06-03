//
//  BlockingPreset.swift
//  Block
//
//  Add target membership to BOTH Block and BlockMonitor targets.
//

import Foundation
import FamilyControls

/// A named group of apps with optional schedule and cooldown friction.
///
/// Each preset uses its own `ManagedSettingsStore(named: "preset.<UUID>")` so multiple
/// presets shield apps independently. The NFC tag continues to operate on the unnamed
/// default store; iOS unions all stores' shields, so a scheduled preset's shield is
/// unaffected by tapping the tag.
struct BlockingPreset: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var selection: FamilyActivitySelection
    var isEnabled: Bool
    var schedule: BlockingSchedule?
    var cooldownMinutes: Int
    /// Cumulative daily usage budget across this preset's apps, in minutes.
    /// `nil` means the usage-limit mechanic is off. When exceeded, the preset
    /// locks for `usageLockMinutes`. Resets after each lockout and at midnight.
    var usageLimitMinutes: Int?
    /// How long the preset stays locked once the usage budget is hit, in minutes.
    var usageLockMinutes: Int
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        selection: FamilyActivitySelection = FamilyActivitySelection(),
        isEnabled: Bool = false,
        schedule: BlockingSchedule? = nil,
        cooldownMinutes: Int = 5,
        usageLimitMinutes: Int? = nil,
        usageLockMinutes: Int = 180,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.selection = selection
        self.isEnabled = isEnabled
        self.schedule = schedule
        self.cooldownMinutes = cooldownMinutes
        self.usageLimitMinutes = usageLimitMinutes
        self.usageLockMinutes = usageLockMinutes
        self.createdAt = createdAt
    }

    static func == (lhs: BlockingPreset, rhs: BlockingPreset) -> Bool {
        let scalarsEqual = lhs.id == rhs.id
            && lhs.name == rhs.name
            && lhs.isEnabled == rhs.isEnabled
            && lhs.schedule == rhs.schedule
            && lhs.cooldownMinutes == rhs.cooldownMinutes
            && lhs.usageLimitMinutes == rhs.usageLimitMinutes
            && lhs.usageLockMinutes == rhs.usageLockMinutes
            && lhs.createdAt == rhs.createdAt
        let selectionEqual = lhs.selection.applicationTokens == rhs.selection.applicationTokens
            && lhs.selection.categoryTokens == rhs.selection.categoryTokens
        return scalarsEqual && selectionEqual
    }

    /// Encoding routes `selection` through nested `Data` to mirror the existing
    /// `AppConfigurationStore.saveSelectedAppsToUserDefaults` pattern. This insulates
    /// us from changes in `FamilyActivitySelection`'s codable representation.
    enum CodingKeys: String, CodingKey {
        case id, name, selectionData, isEnabled, schedule, cooldownMinutes
        case usageLimitMinutes, usageLockMinutes, createdAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        isEnabled = try c.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? false
        schedule = try c.decodeIfPresent(BlockingSchedule.self, forKey: .schedule)
        cooldownMinutes = try c.decodeIfPresent(Int.self, forKey: .cooldownMinutes) ?? 5
        usageLimitMinutes = try c.decodeIfPresent(Int.self, forKey: .usageLimitMinutes)
        usageLockMinutes = try c.decodeIfPresent(Int.self, forKey: .usageLockMinutes) ?? 180
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        if let data = try c.decodeIfPresent(Data.self, forKey: .selectionData) {
            selection = (try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)) ?? FamilyActivitySelection()
        } else {
            selection = FamilyActivitySelection()
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(isEnabled, forKey: .isEnabled)
        try c.encodeIfPresent(schedule, forKey: .schedule)
        try c.encode(cooldownMinutes, forKey: .cooldownMinutes)
        try c.encodeIfPresent(usageLimitMinutes, forKey: .usageLimitMinutes)
        try c.encode(usageLockMinutes, forKey: .usageLockMinutes)
        try c.encode(createdAt, forKey: .createdAt)
        let selectionData = try JSONEncoder().encode(selection)
        try c.encode(selectionData, forKey: .selectionData)
    }
}
