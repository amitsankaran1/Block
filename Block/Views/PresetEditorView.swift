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
    @StateObject private var usageLimitManager = UsageLimitManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var selection: FamilyActivitySelection = FamilyActivitySelection()
    @State private var schedule: BlockingSchedule?
    @State private var cooldownMinutes: Int = 5
    @State private var isEnabled: Bool = false
    @State private var usageLimitEnabled: Bool = false
    @State private var usageLimitMinutes: Int = 30
    @State private var usageLockMinutes: Int = 180

    // Snapshot of the loaded preset for change detection / discard.
    @State private var originalName: String = ""
    @State private var originalSelection: FamilyActivitySelection = FamilyActivitySelection()
    @State private var originalSchedule: BlockingSchedule?
    @State private var originalCooldownMinutes: Int = 5
    @State private var originalIsEnabled: Bool = false
    @State private var originalUsageLimitEnabled: Bool = false
    @State private var originalUsageLimitMinutes: Int = 30
    @State private var originalUsageLockMinutes: Int = 180

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

            Section {
                Toggle("Limit daily usage", isOn: $usageLimitEnabled)
                    .tint(ArtNouveauTheme.primary)

                if usageLimitEnabled {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Time limit")
                            .foregroundColor(ArtNouveauTheme.label)
                        Text("Lock these apps after \(Self.minutesLabel(usageLimitMinutes)) of use")
                            .font(.system(.caption, design: .default))
                            .foregroundColor(ArtNouveauTheme.secondaryLabel)
                        Picker("Time limit", selection: $usageLimitMinutes) {
                            ForEach(Self.usageLimitOptions, id: \.self) { minutes in
                                Text(Self.minutesLabel(minutes)).tag(minutes)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)
                        .frame(height: 120)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Lockout duration")
                            .foregroundColor(ArtNouveauTheme.label)
                        Text("Stays locked for \(Self.durationLabel(usageLockMinutes))")
                            .font(.system(.caption, design: .default))
                            .foregroundColor(ArtNouveauTheme.secondaryLabel)
                        Picker("Lockout duration", selection: $usageLockMinutes) {
                            ForEach(Self.usageLockOptions, id: \.self) { minutes in
                                Text(Self.durationLabel(minutes)).tag(minutes)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)
                        .frame(height: 120)
                    }
                }
            } header: {
                Text("Usage limit")
            } footer: {
                Text(usageLimitEnabled
                     ? "Using these apps for \(Self.minutesLabel(usageLimitMinutes)) total locks them for \(Self.durationLabel(usageLockMinutes)). You can release early after the cooldown. Resets after each lockout and daily."
                     : "Cap cumulative time across these apps, then auto-lock them — even outside a schedule.")
            }

            if schedule == nil {
                Section("Manual block") {
                    Toggle("Block apps now", isOn: $isEnabled)
                        .tint(ArtNouveauTheme.primary)
                }
            }

            if isScheduledActive || isUsageLocked {
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
                    Text(disableNowFooter)
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
    static let usageLimitOptions: [Int] = [15, 30, 45, 60, 90, 120]
    static let usageLockOptions: [Int] = [30, 60, 120, 180, 240, 360]

    static func cooldownLabel(_ minutes: Int) -> String {
        minutes == 0 ? "None" : "\(minutes) min"
    }

    /// "45 min" / "1 hr" / "1 hr 30 min" for usage budgets.
    static func minutesLabel(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes) min" }
        let h = minutes / 60, m = minutes % 60
        return m == 0 ? "\(h) hr" : "\(h) hr \(m) min"
    }

    /// Lockout durations read more naturally as hours past 60 min.
    static func durationLabel(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes) min" }
        let h = minutes / 60, m = minutes % 60
        if m == 0 { return "\(h) hour\(h == 1 ? "" : "s")" }
        return "\(h) hr \(m) min"
    }

    private var isUsageLocked: Bool {
        usageLimitManager.activeUsageLockPresetIDs.contains(presetID)
    }

    private var disableNowFooter: String {
        if isUsageLocked {
            return cooldownMinutes == 0
                ? "These apps are usage-locked. Disabling releases the lock immediately and resets the budget."
                : "These apps are usage-locked. Releasing early requires a \(cooldownMinutes)-minute wait, then the budget resets."
        }
        return cooldownMinutes == 0
            ? "This preset is currently inside its scheduled window. Disabling stops the block immediately."
            : "This preset is currently inside its scheduled window. Disabling early requires a \(cooldownMinutes)-minute wait."
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
            || usageLimitEnabled != originalUsageLimitEnabled
            || usageLimitMinutes != originalUsageLimitMinutes
            || usageLockMinutes != originalUsageLockMinutes
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

        usageLimitEnabled = preset.usageLimitMinutes != nil
        if let limit = preset.usageLimitMinutes {
            usageLimitMinutes = Self.usageLimitOptions.min(by: {
                abs($0 - limit) < abs($1 - limit)
            }) ?? limit
        }
        usageLockMinutes = Self.usageLockOptions.min(by: {
            abs($0 - preset.usageLockMinutes) < abs($1 - preset.usageLockMinutes)
        }) ?? preset.usageLockMinutes

        originalName = name
        originalSelection = selection
        originalSchedule = schedule
        originalCooldownMinutes = cooldownMinutes
        originalIsEnabled = isEnabled
        originalUsageLimitEnabled = usageLimitEnabled
        originalUsageLimitMinutes = usageLimitMinutes
        originalUsageLockMinutes = usageLockMinutes

        hasLoaded = true
    }

    private func save() {
        guard hasLoaded, var preset = presetStore.preset(id: presetID) else { return }
        let prevSchedule = preset.schedule
        let prevEnabled = preset.isEnabled
        let prevUsageLimit = preset.usageLimitMinutes
        let prevUsageLock = preset.usageLockMinutes
        let prevSelectionApps = preset.selection.applicationTokens
        let prevSelectionCats = preset.selection.categoryTokens
        let prevSelectionWeb = preset.selection.webDomainTokens

        preset.name = name.isEmpty ? "Untitled" : name
        preset.selection = selection
        preset.schedule = schedule
        preset.cooldownMinutes = cooldownMinutes
        preset.isEnabled = isEnabled
        let newUsageLimit = usageLimitEnabled ? usageLimitMinutes : nil
        preset.usageLimitMinutes = newUsageLimit
        preset.usageLockMinutes = usageLockMinutes
        presetStore.update(preset)

        if prevSchedule != schedule {
            schedulingManager.applySchedule(for: preset)
        }

        // Re-register usage monitoring if the limit, lockout, or the monitored
        // selection changed.
        let selectionChanged = prevSelectionApps != selection.applicationTokens
            || prevSelectionCats != selection.categoryTokens
            || prevSelectionWeb != selection.webDomainTokens
        if newUsageLimit != prevUsageLimit || usageLockMinutes != prevUsageLock || selectionChanged {
            if newUsageLimit == nil {
                usageLimitManager.removeUsageLimit(for: preset)
            } else {
                usageLimitManager.applyUsageLimit(for: preset, forceReset: true)
            }
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
            usageLimitManager.removeUsageLimit(for: p)
        }
        screenTimeManager.clearPresetShield(id: presetID)
        presetStore.delete(id: presetID)
        dismiss()
    }
}
