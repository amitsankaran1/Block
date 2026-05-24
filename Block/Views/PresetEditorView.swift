//
//  PresetEditorView.swift
//  Block
//

import SwiftUI
import FamilyControls

struct PresetEditorView: View {
    let presetID: UUID

    @StateObject private var presetStore = PresetStore.shared
    @StateObject private var schedulingManager = SchedulingManager.shared
    @StateObject private var screenTimeManager = ScreenTimeManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var selection: FamilyActivitySelection = FamilyActivitySelection()
    @State private var schedule: BlockingSchedule?
    @State private var cooldownMinutes: Int = 5
    @State private var isEnabled: Bool = false

    // Snapshot of the loaded preset for change detection / discard.
    @State private var originalName: String = ""
    @State private var originalSelection: FamilyActivitySelection = FamilyActivitySelection()
    @State private var originalSchedule: BlockingSchedule?
    @State private var originalCooldownMinutes: Int = 5
    @State private var originalIsEnabled: Bool = false

    @State private var showPicker = false
    @State private var showCooldown = false
    @State private var showDeleteConfirm = false
    @State private var hasLoaded = false

    var body: some View {
        Form {
            Section("Name") {
                TextField("Preset name", text: $name)
                    .textInputAutocapitalization(.words)
            }

            Section("Apps") {
                Button {
                    showPicker = true
                } label: {
                    HStack {
                        Image(systemName: "square.grid.2x2")
                            .foregroundColor(ArtNouveauTheme.primary)
                        Text(appsLabel)
                            .foregroundColor(ArtNouveauTheme.label)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(ArtNouveauTheme.tertiaryLabel)
                    }
                }
            }

            Section("Schedule") {
                NavigationLink {
                    ScheduleEditorView(schedule: $schedule)
                } label: {
                    HStack {
                        Image(systemName: "clock")
                            .foregroundColor(ArtNouveauTheme.primary)
                        Text(schedule?.summary ?? "No schedule")
                            .foregroundColor(ArtNouveauTheme.label)
                    }
                }

                if schedule != nil {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Cooldown")
                            .foregroundColor(ArtNouveauTheme.label)
                        Text(cooldownSubtitle)
                            .font(.system(.caption, design: .default))
                            .foregroundColor(ArtNouveauTheme.secondaryLabel)
                        Picker("Cooldown", selection: $cooldownMinutes) {
                            ForEach(Self.cooldownOptions, id: \.self) { minutes in
                                Text(Self.cooldownLabel(minutes)).tag(minutes)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)
                        .frame(height: 120)
                    }
                }
            }

            if schedule == nil {
                Section("Manual block") {
                    Toggle("Block apps now", isOn: $isEnabled)
                        .tint(ArtNouveauTheme.primary)
                }
            }

            if isScheduledActive {
                Section {
                    Button {
                        showCooldown = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: cooldownMinutes == 0 ? "lock.open" : "hourglass")
                            Text(cooldownMinutes == 0 ? "Disable now" : "Disable now (cooldown)")
                        }
                        .foregroundColor(ArtNouveauTheme.warning)
                    }
                } footer: {
                    Text(cooldownMinutes == 0
                         ? "This preset is currently inside its scheduled window. Disabling stops the block immediately."
                         : "This preset is currently inside its scheduled window. Disabling early requires a \(cooldownMinutes)-minute wait.")
                }
            }

            Section {
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "trash")
                        Text("Delete Preset")
                    }
                }
            }
        }
        .navigationTitle("Edit Preset")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") { save() }
                    .fontWeight(.semibold)
                    .disabled(!hasChanges)
            }
        }
        .familyActivityPicker(isPresented: $showPicker, selection: $selection)
        .sheet(isPresented: $showCooldown) {
            CooldownView(presetID: presetID, isPresented: $showCooldown)
        }
        .alert("Delete preset?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) { deletePreset() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This removes the preset and clears any active block.")
        }
        .onAppear { loadIfNeeded() }
    }

    // MARK: - Helpers

    static let cooldownOptions: [Int] = [0, 1, 2, 3, 5, 10, 15, 20, 30, 45, 60]

    static func cooldownLabel(_ minutes: Int) -> String {
        minutes == 0 ? "None" : "\(minutes) min"
    }

    private var cooldownSubtitle: String {
        cooldownMinutes == 0
            ? "No wait — can disable any time"
            : "\(cooldownMinutes) min wait to disable early"
    }

    private var appsLabel: String {
        let appCount = selection.applicationTokens.count
        let categoryCount = selection.categoryTokens.count
        if appCount == 0 && categoryCount == 0 { return "Select apps" }
        var parts: [String] = []
        if appCount > 0 { parts.append("\(appCount) app\(appCount == 1 ? "" : "s")") }
        if categoryCount > 0 { parts.append("\(categoryCount) categor\(categoryCount == 1 ? "y" : "ies")") }
        return parts.joined(separator: ", ")
    }

    private var isScheduledActive: Bool {
        schedulingManager.activeScheduledPresetIDs.contains(presetID)
    }

    private var hasChanges: Bool {
        guard hasLoaded else { return false }
        return name != originalName
            || selection.applicationTokens != originalSelection.applicationTokens
            || selection.categoryTokens != originalSelection.categoryTokens
            || selection.webDomainTokens != originalSelection.webDomainTokens
            || schedule != originalSchedule
            || cooldownMinutes != originalCooldownMinutes
            || isEnabled != originalIsEnabled
    }

    private func loadIfNeeded() {
        guard !hasLoaded, let preset = presetStore.preset(id: presetID) else { return }
        name = preset.name
        selection = preset.selection
        schedule = preset.schedule
        cooldownMinutes = Self.cooldownOptions.min(by: {
            abs($0 - preset.cooldownMinutes) < abs($1 - preset.cooldownMinutes)
        }) ?? preset.cooldownMinutes
        isEnabled = preset.isEnabled

        originalName = name
        originalSelection = selection
        originalSchedule = schedule
        originalCooldownMinutes = cooldownMinutes
        originalIsEnabled = isEnabled

        hasLoaded = true
    }

    private func save() {
        guard hasLoaded, var preset = presetStore.preset(id: presetID) else { return }
        let prevSchedule = preset.schedule
        let prevEnabled = preset.isEnabled

        preset.name = name.isEmpty ? "Untitled" : name
        preset.selection = selection
        preset.schedule = schedule
        preset.cooldownMinutes = cooldownMinutes
        preset.isEnabled = isEnabled
        presetStore.update(preset)

        if prevSchedule != schedule {
            schedulingManager.applySchedule(for: preset)
        }

        // Manual-block side effects only matter when there's no schedule.
        if schedule == nil {
            if isEnabled && !prevEnabled {
                screenTimeManager.applyPresetShield(preset)
            } else if !isEnabled && prevEnabled {
                screenTimeManager.clearPresetShield(id: presetID)
            } else if isEnabled {
                // Selection or other fields may have changed while enabled.
                screenTimeManager.updatePresetShieldIfActive(preset)
            }
        } else if isScheduledActive {
            // Selection changed mid-window — refresh the live shield.
            screenTimeManager.updatePresetShieldIfActive(preset)
        }

        dismiss()
    }

    private func deletePreset() {
        if let p = presetStore.preset(id: presetID) {
            schedulingManager.removeSchedule(for: p)
        }
        screenTimeManager.clearPresetShield(id: presetID)
        presetStore.delete(id: presetID)
        dismiss()
    }
}
