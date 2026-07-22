//
//  AppGroupListView.swift
//  Block
//
//  "Lists" tab — manage reusable app groups (e.g. "Social media", "Games").
//

import SwiftUI
import FamilyControls

struct AppGroupListView: View {
    @StateObject private var groupStore = AppGroupStore.shared
    @StateObject private var blockStore = BlockStore.shared
    @State private var editingGroupID: UUID?

    var body: some View {
        NavigationView {
            List {
                if groupStore.groups.isEmpty {
                    Text("No app lists yet. Add one to group apps you can then block.")
                        .font(.system(.subheadline, design: .default))
                        .foregroundColor(ArtNouveauTheme.secondaryLabel)
                        .padding(.vertical, 8)
                } else {
                    Section {
                        ForEach(groupStore.groups) { group in
                            Button { editingGroupID = group.id } label: {
                                row(for: group)
                            }
                            .buttonStyle(.plain)
                        }
                    } footer: {
                        Text("Lists are snapshots. Choosing a whole category captures the apps installed now — apps added later aren't blocked until you open the list and save it again.")
                    }
                }
            }
            .navigationTitle("Lists")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        let g = groupStore.create(name: defaultName())
                        editingGroupID = g.id
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(item: Binding(
                get: { editingGroupID.map { IdentifiedID(id: $0) } },
                set: { editingGroupID = $0?.id }
            )) { wrapper in
                NavigationView { AppGroupEditorView(groupID: wrapper.id) }
            }
        }
    }

    private func row(for group: AppGroup) -> some View {
        let appCount = group.selection.applicationTokens.count
        let catCount = group.selection.categoryTokens.count
        let used = groupStore.blockCount(for: group.id, in: blockStore.blocks)
        return HStack(spacing: 14) {
            Image(systemName: "square.grid.2x2.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(ArtNouveauTheme.primary)
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 3) {
                Text(group.name)
                    .font(.system(.headline, design: .default).weight(.semibold))
                    .foregroundColor(ArtNouveauTheme.label)
                Text(countSummary(apps: appCount, cats: catCount) + " · used by \(used) block\(used == 1 ? "" : "s")")
                    .font(.system(.caption, design: .default))
                    .foregroundColor(ArtNouveauTheme.secondaryLabel)
                Text("Updated \(group.updatedAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.system(.caption2, design: .default))
                    .foregroundColor(ArtNouveauTheme.tertiaryLabel)
}
            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundColor(ArtNouveauTheme.tertiaryLabel)
        }
        .padding(.vertical, 4)
    }

    private func countSummary(apps: Int, cats: Int) -> String {
        if apps == 0 && cats == 0 { return "No apps yet" }
        var parts: [String] = []
        if apps > 0 { parts.append("\(apps) app\(apps == 1 ? "" : "s")") }
        if cats > 0 { parts.append("\(cats) categor\(cats == 1 ? "y" : "ies")") }
        return parts.joined(separator: ", ")
    }

    private func defaultName() -> String {
        "List \(groupStore.groups.count + 1)"
    }
}

/// Small Identifiable wrapper so a bare UUID can drive `.sheet(item:)`.
struct IdentifiedID: Identifiable { let id: UUID }
