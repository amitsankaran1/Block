//
//  AppGroup.swift
//  Block
//
//  A named, reusable list of apps (e.g. "Social media", "Games"). Blocks
//  reference groups by id; a block's effective shield is the union of its
//  groups' selections (see BlockResolution).
//
//  Add target membership to BOTH Block and BlockMonitor targets.
//

import Foundation
import FamilyControls

struct AppGroup: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var selection: FamilyActivitySelection
    /// Typed-in website domains to block (e.g. "goodreads.com"), enforced via
    /// `webContent.blockedByFilter` — no picker token needed.
    var blockedWebDomains: [String]
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        selection: FamilyActivitySelection = FamilyActivitySelection(),
        blockedWebDomains: [String] = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.selection = selection
        self.blockedWebDomains = blockedWebDomains
        self.createdAt = createdAt
    }

    static func == (lhs: AppGroup, rhs: AppGroup) -> Bool {
        let scalarsEqual = lhs.id == rhs.id
            && lhs.name == rhs.name
            && lhs.createdAt == rhs.createdAt
            && lhs.blockedWebDomains == rhs.blockedWebDomains
        let appsEqual: Bool = lhs.selection.applicationTokens == rhs.selection.applicationTokens
        let catsEqual: Bool = lhs.selection.categoryTokens == rhs.selection.categoryTokens
        let webEqual: Bool = lhs.selection.webDomainTokens == rhs.selection.webDomainTokens
        return scalarsEqual && appsEqual && catsEqual && webEqual
    }

    /// Encoding routes `selection` through nested `Data` to insulate from changes
    /// in `FamilyActivitySelection`'s codable representation (mirrors BlockRule).
    enum CodingKeys: String, CodingKey {
        case id, name, selectionData, blockedWebDomains, createdAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        blockedWebDomains = try c.decodeIfPresent([String].self, forKey: .blockedWebDomains) ?? []
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
        try c.encode(blockedWebDomains, forKey: .blockedWebDomains)
        try c.encode(createdAt, forKey: .createdAt)
        let selectionData = try JSONEncoder().encode(selection)
        try c.encode(selectionData, forKey: .selectionData)
    }
}

extension FamilyActivitySelection {
    /// True when `self` contains every token of `other` (an adds-only change).
    /// `includeEntireCategory` is deliberately ignored — BlockResolution unions
    /// exactly these three token sets.
    func isSuperset(of other: FamilyActivitySelection) -> Bool {
        applicationTokens.isSuperset(of: other.applicationTokens)
            && categoryTokens.isSuperset(of: other.categoryTokens)
            && webDomainTokens.isSuperset(of: other.webDomainTokens)
    }
}
