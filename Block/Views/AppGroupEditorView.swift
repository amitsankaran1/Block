//
//  AppGroupEditorView.swift
//  Block
//
//  Create/edit an app group: a name + a FamilyActivityPicker selection.
//

import SwiftUI
import FamilyControls

struct AppGroupEditorView: View {
    let groupID: UUID

    @StateObject private var groupStore = AppGroupStore.shared
    @StateObject private var blockStore = BlockStore.shared
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var selection = FamilyActivitySelection()
    @State private var showPicker = false
    @State private var showDeleteConfirm = false
    @State private var hasLoaded = false

    private var usedByCount: Int {
        groupStore.blockCount(for: groupID, in: blockStore.blocks)
    }

    var body: some View {
        Form {
            Section("Name") {
                TextField("List name", text: $name)
                    .textInputAutocapitalization(.words)
            }

            Section("Apps") {
                Button {
                    showPicker = true
                } label: {
                    HStack {
                        Image(systemName: "square.grid.2x2").foregroundColor(ArtNouveauTheme.primary)
                        Text(appsLabel).foregroundColor(ArtNouveauTheme.label)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(ArtNouveauTheme.tertiaryLabel)
                    }
                }
            }

            Section {
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "trash")
                        Text("Delete List")
                    }
                }
            } footer: {
                if usedByCount > 0 {
                    Text("Used by \(usedByCount) block\(usedByCount == 1 ? "" : "s"). Deleting it removes it from them.")
                }
            }
        }
        .navigationTitle("Edit List")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") { save() }.fontWeight(.semibold)
            }
        }
        .familyActivityPicker(isPresented: $showPicker, selection: $selection)
        .alert("Delete list?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) { deleteGroup() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This removes the list and detaches it from any blocks.")
        }
        .onAppear(perform: loadIfNeeded)
    }

    private var appsLabel: String {
        let apps = selection.applicationTokens.count
        let cats = selection.categoryTokens.count
        if apps == 0 && cats == 0 { return "Select apps" }
        var parts: [String] = []
        if apps > 0 { parts.append("\(apps) app\(apps == 1 ? "" : "s")") }
        if cats > 0 { parts.append("\(cats) categor\(cats == 1 ? "y" : "ies")") }
        return parts.joined(separator: ", ")
    }

    private func loadIfNeeded() {
        guard !hasLoaded, let group = groupStore.group(id: groupID) else { return }
        name = group.name
        selection = group.selection
        hasLoaded = true
    }

    private func save() {
        guard hasLoaded, var group = groupStore.group(id: groupID) else { dismiss(); return }
        group.name = name.isEmpty ? "Untitled" : name
        group.selection = selection
        groupStore.update(group)
        // Re-apply any active block shields that reference this group, since their
        // resolved tokens may have changed.
        for block in blockStore.blocks where block.appGroupIDs.contains(groupID) {
            ScreenTimeManager.shared.updateBlockShieldIfActive(block)
            if block.type == .timer { UsageLimitManager.shared.applyUsageLimit(for: block, forceReset: true) }
        }
        dismiss()
    }

    private func deleteGroup() {
        // Detach from blocks first.
        for var block in blockStore.blocks where block.appGroupIDs.contains(groupID) {
            block.appGroupIDs.removeAll { $0 == groupID }
            blockStore.update(block)
        }
        groupStore.delete(id: groupID)
        dismiss()
    }
}
