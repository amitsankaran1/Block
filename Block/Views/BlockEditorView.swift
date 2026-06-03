//
//  BlockEditorView.swift
//  Block
//
//  Create/edit a block: choose its type, the app lists it targets, and the
//  type-specific config (schedule / usage limit / tag), plus cooldown friction.
//

import SwiftUI

struct BlockEditorView: View {
    let blockID: UUID

    @StateObject private var blockStore = BlockStore.shared
    @StateObject private var groupStore = AppGroupStore.shared
    @StateObject private var schedulingManager = SchedulingManager.shared
    @StateObject private var usageLimitManager = UsageLimitManager.shared
    @StateObject private var screenTimeManager = ScreenTimeManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var type: BlockType = .schedule
    @State private var groupIDs: Set<UUID> = []
    @State private var schedule: BlockingSchedule?
    @State private var cooldownMinutes = 5
    @State private var usageLimitMinutes = 30
    @State private var usageLockMinutes = 180
    @State private var isEnabled = false

    @State private var showCooldown = false
    @State private var showDeleteConfirm = false
    @State private var hasLoaded = false

    static let cooldownOptions: [Int] = [0, 1, 2, 3, 5, 10, 15, 20, 30, 45, 60]
    static let usageLimitOptions: [Int] = [15, 30, 45, 60, 90, 120]
    static let usageLockOptions: [Int] = [30, 60, 120, 180, 240, 360]

    var body: some View {
        Form {
            Section("Name") {
                TextField("Block name", text: $name).textInputAutocapitalization(.words)
            }

            Section("How it applies") {
                Picker("Type", selection: $type) {
                    Text("Schedule").tag(BlockType.schedule)
                    Text("Timer").tag(BlockType.timer)
                    Text("Tag").tag(BlockType.tag)
                }
                .pickerStyle(.segmented)
                Text(typeBlurb)
                    .font(.system(.caption, design: .default))
                    .foregroundColor(ArtNouveauTheme.secondaryLabel)
            }

            Section("App lists") {
                if groupStore.groups.isEmpty {
                    Text("No lists yet — create one in the Lists tab first.")
                        .font(.system(.caption, design: .default))
                        .foregroundColor(ArtNouveauTheme.secondaryLabel)
                } else {
                    ForEach(groupStore.groups) { group in
                        Button { toggleGroup(group.id) } label: {
                            HStack {
                                Image(systemName: groupIDs.contains(group.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(groupIDs.contains(group.id) ? ArtNouveauTheme.primary : ArtNouveauTheme.tertiaryLabel)
                                Text(group.name).foregroundColor(ArtNouveauTheme.label)
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            typeConfigSection

            if isActive {
                Section {
                    Button { showCooldown = true } label: {
                        HStack(spacing: 10) {
                            Image(systemName: cooldownMinutes == 0 ? "lock.open" : "hourglass")
                            Text(cooldownMinutes == 0 ? "Disable now" : "Disable now (cooldown)")
                        }
                        .foregroundColor(ArtNouveauTheme.warning)
                    }
                }
            } else {
                Section("Manual") {
                    Toggle("Block now", isOn: $isEnabled).tint(ArtNouveauTheme.primary)
                }
            }

            Section {
                Button(role: .destructive) { showDeleteConfirm = true } label: {
                    HStack(spacing: 10) { Image(systemName: "trash"); Text("Delete Block") }
                }
            }
        }
        .navigationTitle("Edit Block")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .navigationBarTrailing) { Button("Save") { save() }.fontWeight(.semibold) }
        }
        .sheet(isPresented: $showCooldown) {
            CooldownView(blockID: blockID, isPresented: $showCooldown)
        }
        .alert("Delete block?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) { deleteBlock() }
            Button("Cancel", role: .cancel) { }
        }
        .onAppear(perform: loadIfNeeded)
    }

    // MARK: - Type-specific config

    @ViewBuilder
    private var typeConfigSection: some View {
        switch type {
        case .schedule:
            Section("Schedule") {
                NavigationLink {
                    ScheduleEditorView(schedule: $schedule)
                } label: {
                    HStack {
                        Image(systemName: "clock").foregroundColor(ArtNouveauTheme.primary)
                        Text(schedule?.summary ?? "No schedule").foregroundColor(ArtNouveauTheme.label)
                    }
                }
                cooldownPicker
            }
        case .timer:
            Section("Usage limit") {
                wheel("Time limit", "Lock after this much cumulative use",
                      selection: $usageLimitMinutes, options: Self.usageLimitOptions, label: Self.minutesLabel)
                wheel("Lockout duration", "Stays locked for",
                      selection: $usageLockMinutes, options: Self.usageLockOptions, label: Self.durationLabel)
                cooldownPicker
            }
        case .tag:
            Section("Tag") {
                Text("Tapping your registered tag toggles this block on or off, together with your other Tag blocks.")
                    .font(.system(.caption, design: .default))
                    .foregroundColor(ArtNouveauTheme.secondaryLabel)
            }
        }
    }

    private var cooldownPicker: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Cooldown").foregroundColor(ArtNouveauTheme.label)
            Text(cooldownMinutes == 0 ? "No wait — disable any time" : "\(cooldownMinutes) min wait to disable early")
                .font(.system(.caption, design: .default)).foregroundColor(ArtNouveauTheme.secondaryLabel)
            Picker("Cooldown", selection: $cooldownMinutes) {
                ForEach(Self.cooldownOptions, id: \.self) { Text($0 == 0 ? "None" : "\($0) min").tag($0) }
            }
            .pickerStyle(.wheel).frame(maxWidth: .infinity).frame(height: 110)
        }
    }

    private func wheel(_ title: String, _ caption: String, selection: Binding<Int>, options: [Int], label: @escaping (Int) -> String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).foregroundColor(ArtNouveauTheme.label)
            Text("\(caption) \(label(selection.wrappedValue))")
                .font(.system(.caption, design: .default)).foregroundColor(ArtNouveauTheme.secondaryLabel)
            Picker(title, selection: selection) {
                ForEach(options, id: \.self) { Text(label($0)).tag($0) }
            }
            .pickerStyle(.wheel).frame(maxWidth: .infinity).frame(height: 110)
        }
    }

    private var typeBlurb: String {
        switch type {
        case .schedule: return "Blocks the selected lists during a time-of-day window."
        case .timer:    return "Blocks the lists after a cumulative usage budget, for a lockout period."
        case .tag:      return "Blocks the lists while toggled on by tapping your NFC tag."
        }
    }

    private var isActive: Bool {
        schedulingManager.activeScheduledBlockIDs.contains(blockID)
            || usageLimitManager.activeUsageLockBlockIDs.contains(blockID)
    }

    private func toggleGroup(_ id: UUID) {
        if groupIDs.contains(id) { groupIDs.remove(id) } else { groupIDs.insert(id) }
    }

    nonisolated static func minutesLabel(_ m: Int) -> String {
        m < 60 ? "\(m) min" : (m % 60 == 0 ? "\(m / 60) hr" : "\(m / 60) hr \(m % 60) min")
    }
    nonisolated static func durationLabel(_ m: Int) -> String {
        m < 60 ? "\(m) min" : (m % 60 == 0 ? "\(m / 60) hour\(m / 60 == 1 ? "" : "s")" : "\(m / 60) hr \(m % 60) min")
    }

    // MARK: - Load / save

    private func loadIfNeeded() {
        guard !hasLoaded, let block = blockStore.block(id: blockID) else { return }
        name = block.name
        type = block.type
        groupIDs = Set(block.appGroupIDs)
        schedule = block.schedule
        cooldownMinutes = Self.cooldownOptions.min(by: { abs($0 - block.cooldownMinutes) < abs($1 - block.cooldownMinutes) }) ?? block.cooldownMinutes
        if let l = block.usageLimitMinutes {
            usageLimitMinutes = Self.usageLimitOptions.min(by: { abs($0 - l) < abs($1 - l) }) ?? l
        }
        usageLockMinutes = Self.usageLockOptions.min(by: { abs($0 - block.usageLockMinutes) < abs($1 - block.usageLockMinutes) }) ?? block.usageLockMinutes
        isEnabled = block.isEnabled
        hasLoaded = true
    }

    private func save() {
        guard hasLoaded, var block = blockStore.block(id: blockID) else { dismiss(); return }
        let prevType = block.type
        block.name = name.isEmpty ? "Untitled" : name
        block.type = type
        block.appGroupIDs = Array(groupIDs)
        block.cooldownMinutes = cooldownMinutes
        block.isEnabled = isEnabled
        block.schedule = (type == .schedule) ? schedule : nil
        block.usageLimitMinutes = (type == .timer) ? usageLimitMinutes : nil
        block.usageLockMinutes = usageLockMinutes
        blockStore.update(block)
        blockStore.flush()

        // (Re)register monitors for the (possibly changed) type.
        if prevType == .schedule && type != .schedule {
            schedulingManager.removeSchedule(for: block)
        }
        if prevType == .timer && type != .timer {
            usageLimitManager.removeUsageLimit(for: block)
        }
        switch type {
        case .schedule: schedulingManager.applySchedule(for: block)
        case .timer:    usageLimitManager.applyUsageLimit(for: block, forceReset: true)
        case .tag:      break
        }

        // Manual on/off + live-shield refresh.
        if isEnabled {
            screenTimeManager.applyBlockShield(block)
        } else {
            // Only clear if nothing else is keeping it up.
            let running = SharedDefaults.suite.bool(forKey: SharedDefaults.Keys.running(blockID: blockID))
            let locked = usageLimitManager.lockEnd(for: blockID) != nil
            if !running && !locked { screenTimeManager.clearBlockShield(id: blockID) }
            else { screenTimeManager.updateBlockShieldIfActive(block) }
        }
        dismiss()
    }

    private func deleteBlock() {
        if let block = blockStore.block(id: blockID) {
            schedulingManager.removeSchedule(for: block)
            usageLimitManager.removeUsageLimit(for: block)
        }
        screenTimeManager.clearBlockShield(id: blockID)
        blockStore.delete(id: blockID)
        dismiss()
    }
}
