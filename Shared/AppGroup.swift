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
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        selection: FamilyActivitySelection = FamilyActivitySelection(),
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.selection = selection
        self.createdAt = createdAt
    }

    static func == (lhs: AppGroup, rhs: AppGroup) -> Bool {
        let scalarsEqual = lhs.id == rhs.id
            && lhs.name == rhs.name
            && lhs.createdAt == rhs.createdAt
        let appsEqual: Bool = lhs.selection.applicationTokens == rhs.selection.applicationTokens
        let catsEqual: Bool = lhs.selection.categoryTokens == rhs.selection.categoryTokens
        let webEqual: Bool = lhs.selection.webDomainTokens == rhs.selection.webDomainTokens
        return scalarsEqual && appsEqual && catsEqual && webEqual
    }

    /// Encoding routes `selection` through nested `Data` to insulate from changes
    /// in `FamilyActivitySelection`'s codable representation (mirrors BlockRule).
    enum CodingKeys: String, CodingKey {
        case id, name, selectionData, createdAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
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
        try c.encode(createdAt, forKey: .createdAt)
        let selectionData = try JSONEncoder().encode(selection)
        try c.encode(selectionData, forKey: .selectionData)
    }
}
