//
//  AppGroupEditorView.swift
//  Block
//
//  Create/edit an app group: a name + a FamilyActivityPicker selection + typed-in
//  blocked website domains. While any referencing block is active, the list can
//  only be strengthened (apps/domains added, never removed).
//

import SwiftUI
import FamilyControls

struct AppGroupEditorView: View {
    let groupID: UUID

    @StateObject private var groupStore = AppGroupStore.shared
    @StateObject private var blockStore = BlockStore.shared
    @StateObject private var schedulingManager = SchedulingManager.shared
    @StateObject private var usageLimitManager = UsageLimitManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var selection = FamilyActivitySelection()
    @State private var blockedDomains: [String] = []
    @State private var newDomain: String = ""
    @State private var showPicker = false
    @State private var showDeleteConfirm = false
    @State private var showActiveDeleteAlert = false
    @State private var showRemovalBlockedAlert = false
    @State private var hasLoaded = false

    private var usedByCount: Int {
        groupStore.blockCount(for: groupID, in: blockStore.blocks)
    }

    /// Blocks that reference this list and are currently enforcing a shield.
    /// While non-empty, removals from this list are locked (additions stay allowed).
    private var activeReferencingBlocks: [BlockRule] {
        blockStore.blocks.filter {
            $0.appGroupIDs.contains(groupID) && ScreenTimeManager.shared.isBlockActive($0)
        }
    }

    var body: some View {
        Form {
            Section("Name") {
                TextField("List name", text: $name)
                    .textInputAutocapitalization(.words)
            }

            Section {
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
            } header: {
                Text("Apps")
            } footer: {
                if !activeReferencingBlocks.isEmpty {
                    Text("In use by an active block — you can add apps and websites, but not remove them until the block ends or is disabled.")
                }
            }

            Section {
                ForEach(blockedDomains, id: \.self) { domain in
                    HStack {
                        Image(systemName: "globe").foregroundColor(ArtNouveauTheme.primary)
                        Text(domain).foregroundColor(ArtNouveauTheme.label)
                    }
                }
                .onDelete { blockedDomains.remove(atOffsets: $0) }
                HStack {
                    TextField("Add website (e.g. goodreads.com)", text: $newDomain)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .onSubmit(addDomain)
                    Button(action: addDomain) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(newDomain.isEmpty ? ArtNouveauTheme.tertiaryLabel : ArtNouveauTheme.primary)
                    }
                    .buttonStyle(.plain)
                    .disabled(newDomain.isEmpty)
                }
            } header: {
                Text("Websites")
            } footer: {
                Text("Blocked in Safari — including private browsing — with no “allow anyway” option.")
            }

            Section {
                Button(role: .destructive) {
                    if activeReferencingBlocks.isEmpty {
                        showDeleteConfirm = true
                    } else {
                        showActiveDeleteAlert = true
                    }
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
        .alert("List is in use", isPresented: $showActiveDeleteAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("This list is used by an active block. Disable the block first, then delete the list.")
        }
        .alert("Can't remove while blocked", isPresented: $showRemovalBlockedAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("This list is used by an active block, so apps and websites can be added but not removed. Disable the block first.")
        }
        .onAppear {
            loadIfNeeded()
            // Close the periodic-refresh staleness window so the active check is current.
            schedulingManager.refresh()
            usageLimitManager.refresh()
        }
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

    private func addDomain() {
        guard let domain = Self.normalizeDomain(newDomain) else { return }
        if !blockedDomains.contains(domain) {
            blockedDomains.append(domain)
        }
        newDomain = ""
    }

    /// "https://www.GoodReads.com/en/book" → "goodreads.com"; nil when the input
    /// doesn't look like a domain.
    static func normalizeDomain(_ raw: String) -> String? {
        var s = raw.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        for scheme in ["https://", "http://"] where s.hasPrefix(scheme) {
            s = String(s.dropFirst(scheme.count))
        }
        if s.hasPrefix("www.") { s = String(s.dropFirst(4)) }
        if let slash = s.firstIndex(of: "/") { s = String(s[..<slash]) }
        guard s.contains("."), !s.contains(" "), !s.hasPrefix("."), !s.hasSuffix(".") else { return nil }
        return s
    }

    private func loadIfNeeded() {
        guard !hasLoaded, let group = groupStore.group(id: groupID) else { return }
        name = group.name
        selection = group.selection
        blockedDomains = group.blockedWebDomains
        hasLoaded = true
    }

    private func save() {
        guard hasLoaded, var group = groupStore.group(id: groupID) else { dismiss(); return }

        // While a referencing block is active, only additive changes may land —
        // compare against the *stored* group so stale editor state can't sneak a
        // removal through.
        if !activeReferencingBlocks.isEmpty {
            let selectionAdditive = selection.isSuperset(of: group.selection)
            let domainsAdditive = Set(blockedDomains).isSuperset(of: Set(group.blockedWebDomains))
            guard selectionAdditive && domainsAdditive else {
                showRemovalBlockedAlert = true
                return
            }
        }

        let selectionChanged = group.selection.applicationTokens != selection.applicationTokens
            || group.selection.categoryTokens != selection.categoryTokens
            || group.selection.webDomainTokens != selection.webDomainTokens

        group.name = name.isEmpty ? "Untitled" : name
        group.selection = selection
        group.blockedWebDomains = blockedDomains
        groupStore.update(group)
        // Re-apply any active block shields that reference this group, since their
        // resolved tokens/domains may have changed.
        for block in blockStore.blocks where block.appGroupIDs.contains(groupID) {
            ScreenTimeManager.shared.updateBlockShieldIfActive(block)
            // Restart the usage monitor only when the monitored tokens actually
            // changed — an unconditional reset handed back a fresh daily budget on
            // every save. (Typed domains aren't usage-counted, so they don't matter
            // here.)
            if block.type == .timer && selectionChanged {
                UsageLimitManager.shared.applyUsageLimit(for: block, forceReset: true)
            }
        }
        dismiss()
    }

    private func deleteGroup() {
        // Backstop for the UI gate: detaching this list from an active block would
        // weaken it.
        guard activeReferencingBlocks.isEmpty else {
            showActiveDeleteAlert = true
            return
        }
        // Detach from blocks first.
        for var block in blockStore.blocks where block.appGroupIDs.contains(groupID) {
            block.appGroupIDs.removeAll { $0 == groupID }
            blockStore.update(block)
        }
        groupStore.delete(id: groupID)
        dismiss()
    }
}
