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

    @State private var showPicker = false
    @State private var showCooldown = false
    @State private var showDeleteConfirm = false
    @State private var hasLoaded = false

    var body: some View {
        Form {
            Section("Name") {
                TextField("Preset name", text: $name)
                    .textInputAutocapitalization(.words)
                    .onChange(of: name) { _ in commit() }
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
                    ScheduleEditorView(schedule: Binding(
                        get: { schedule },
                        set: { newValue in
                            schedule = newValue
                            commit()
                        }
                    ))
                } label: {
                    HStack {
                        Image(systemName: "clock")
                            .foregroundColor(ArtNouveauTheme.primary)
                        Text(schedule?.summary ?? "No schedule")
                            .foregroundColor(ArtNouveauTheme.label)
                    }
                }

                if schedule != nil {
                    Stepper(value: $cooldownMinutes, in: 0...60, step: 1) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Cooldown")
                                .foregroundColor(ArtNouveauTheme.label)
                            Text("\(cooldownMinutes) min wait to disable early")
                                .font(.system(.caption, design: .default))
                                .foregroundColor(ArtNouveauTheme.secondaryLabel)
                        }
                    }
                    .onChange(of: cooldownMinutes) { _ in commit() }
                }
            }

            if schedule == nil {
                Section("Manual block") {
                    Toggle("Block apps now", isOn: $isEnabled)
                        .tint(ArtNouveauTheme.primary)
                        .onChange(of: isEnabled) { newValue in
                            commit()
                            if newValue {
                                if let p = presetStore.preset(id: presetID) {
                                    screenTimeManager.applyPresetShield(p)
                                }
                            } else {
                                screenTimeManager.clearPresetShield(id: presetID)
                            }
                        }
                }
            }

            if isScheduledActive {
                Section {
                    Button {
                        showCooldown = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "hourglass")
                            Text("Disable now (cooldown)")
                        }
                        .foregroundColor(ArtNouveauTheme.warning)
                    }
                } footer: {
                    Text("This preset is currently inside its scheduled window. Disabling early requires a \(cooldownMinutes)-minute wait.")
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
        .familyActivityPicker(isPresented: $showPicker, selection: $selection)
        .onChange(of: selection) { _ in
            commit()
            if let p = presetStore.preset(id: presetID) {
                screenTimeManager.updatePresetShieldIfActive(p)
            }
        }
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

    private func loadIfNeeded() {
        guard !hasLoaded, let preset = presetStore.preset(id: presetID) else { return }
        name = preset.name
        selection = preset.selection
        schedule = preset.schedule
        cooldownMinutes = preset.cooldownMinutes
        isEnabled = preset.isEnabled
        hasLoaded = true
    }

    private func commit() {
        guard hasLoaded, var preset = presetStore.preset(id: presetID) else { return }
        let prevSchedule = preset.schedule
        preset.name = name.isEmpty ? "Untitled" : name
        preset.selection = selection
        preset.schedule = schedule
        preset.cooldownMinutes = cooldownMinutes
        preset.isEnabled = isEnabled
        presetStore.update(preset)

        if prevSchedule != schedule {
            schedulingManager.applySchedule(for: preset)
        }
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
