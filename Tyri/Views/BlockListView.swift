//
//  BlockListView.swift
//  Tyri
//
//  "Blocks" tab — manage blocking rules, grouped by how they're applied
//  (Schedule / Timer / NFC tag).
//

import SwiftUI

struct BlockListView: View {
    @StateObject private var blockStore = BlockStore.shared
    @StateObject private var groupStore = AppGroupStore.shared
    @StateObject private var schedulingManager = SchedulingManager.shared
    @StateObject private var usageLimitManager = UsageLimitManager.shared
    @State private var editingBlockID: UUID?

    private let order: [BlockType] = [.schedule, .timer, .tag]

    var body: some View {
        NavigationView {
            List {
                if blockStore.blocks.isEmpty {
                    Text("No blocks yet. Add one and point it at an app list.")
                        .font(.system(.subheadline, design: .default))
                        .foregroundColor(ArtNouveauTheme.secondaryLabel)
                        .padding(.vertical, 8)
                } else {
                    ForEach(order, id: \.self) { type in
                        let items = blockStore.blocks(ofType: type)
                        if !items.isEmpty {
                            Section(BlockTypeStyle.title(type)) {
                                ForEach(items) { block in
                                    Button { editingBlockID = block.id } label: { row(for: block) }
                                        .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Blocks")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        ForEach(order, id: \.self) { type in
                            Button {
                                let b = blockStore.create(name: defaultName(type), type: type)
                                editingBlockID = b.id
                            } label: {
                                Label(BlockTypeStyle.title(type), systemImage: BlockTypeStyle.icon(type))
                            }
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(item: Binding(
                get: { editingBlockID.map { IdentifiedID(id: $0) } },
                set: { editingBlockID = $0?.id }
            )) { wrapper in
                NavigationView { BlockEditorView(blockID: wrapper.id) }
            }
        }
    }

    private func row(for block: BlockRule) -> some View {
        let active = isActive(block)
        return HStack(spacing: 14) {
            Image(systemName: BlockTypeStyle.icon(block.type))
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(BlockTypeStyle.color(block.type))
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 3) {
                Text(block.name)
                    .font(.system(.headline, design: .default).weight(.semibold))
                    .foregroundColor(ArtNouveauTheme.label)
                Text(subtitle(for: block))
                    .font(.system(.caption, design: .default))
                    .foregroundColor(ArtNouveauTheme.secondaryLabel)
            }
            Spacer()
            if active {
                Text("ACTIVE")
                    .font(.system(.caption2, design: .default).weight(.bold)).tracking(0.8)
                    .foregroundColor(ArtNouveauTheme.error)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Capsule().fill(ArtNouveauTheme.errorLight))
            }
            Image(systemName: "chevron.right").font(.caption).foregroundColor(ArtNouveauTheme.tertiaryLabel)
        }
        .padding(.vertical, 4)
    }

    private func isActive(_ block: BlockRule) -> Bool {
        // schedulingManager/usageLimitManager stay observed above so their
        // published sets invalidate this view when active state changes.
        ScreenTimeManager.shared.isBlockActive(block)
    }

    private func subtitle(for block: BlockRule) -> String {
        let names = groupStore.groups(ids: block.appGroupIDs).map { $0.name }
        let groupPart = names.isEmpty ? "No lists" : names.joined(separator: ", ")
        let detail: String
        switch block.type {
        case .schedule: detail = block.schedule?.summary ?? "No schedule"
        case .timer:    detail = block.usageLimitMinutes.map { "\($0)m → lock \(block.usageLockMinutes)m" } ?? "No limit"
        case .tag:      detail = "Toggled by tag"
        }
        return "\(groupPart) · \(detail)"
    }

    private func defaultName(_ type: BlockType) -> String {
        let n = blockStore.blocks(ofType: type).count + 1
        return "\(BlockTypeStyle.title(type)) \(n)"
    }
}

/// Per-type icon / color / label used across the Blocks UI.
enum BlockTypeStyle {
    static func title(_ type: BlockType) -> String {
        switch type {
        case .schedule: return "Schedule"
        case .timer:    return "Timer"
        case .tag:      return "Tag"
        }
    }
    static func icon(_ type: BlockType) -> String {
        switch type {
        case .schedule: return "clock.fill"
        case .timer:    return "hourglass"
        case .tag:      return "sensor.tag.radiowaves.forward.fill"
        }
    }
    static func color(_ type: BlockType) -> Color {
        switch type {
        case .schedule: return ArtNouveauTheme.error
        case .timer:    return ArtNouveauTheme.warning
        case .tag:      return ArtNouveauTheme.primary
        }
    }
}
