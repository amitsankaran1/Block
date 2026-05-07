//
//  PresetListView.swift
//  Block
//
//  Embedded inside `SettingsView` as the "Blocking Presets" section.
//

import SwiftUI

struct PresetListView: View {
    @StateObject private var presetStore = PresetStore.shared
    @StateObject private var schedulingManager = SchedulingManager.shared

    @State private var presetToEdit: BlockingPreset?
    @State private var showCreate = false

    var body: some View {
        VStack(spacing: 12) {
            if presetStore.presets.isEmpty {
                emptyState
            } else {
                ForEach(presetStore.presets) { preset in
                    PresetRow(
                        preset: preset,
                        isRunning: schedulingManager.activeScheduledPresetIDs.contains(preset.id)
                    ) {
                        presetToEdit = preset
                    }
                }
            }

            Button {
                let new = presetStore.create(name: defaultName())
                presetToEdit = new
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Preset")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(ArtNouveauButtonStyle(isProminent: presetStore.presets.isEmpty))
        }
        .sheet(item: $presetToEdit) { preset in
            NavigationView {
                PresetEditorView(presetID: preset.id)
            }
        }
        .onAppear { schedulingManager.refresh() }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("No presets yet")
                .font(.system(.subheadline, design: .default).weight(.semibold))
                .foregroundColor(ArtNouveauTheme.label)
            Text("Create a preset to block a specific group of apps on a schedule.")
                .font(.system(.caption, design: .default))
                .foregroundColor(ArtNouveauTheme.secondaryLabel)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
    }

    private func defaultName() -> String {
        let count = presetStore.presets.count + 1
        return "Preset \(count)"
    }
}

private struct PresetRow: View {
    let preset: BlockingPreset
    let isRunning: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(badgeColor.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: badgeIcon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(badgeColor)
                        .symbolRenderingMode(.hierarchical)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(preset.name)
                            .font(.system(.body, design: .default).weight(.semibold))
                            .foregroundColor(ArtNouveauTheme.label)
                        if isRunning {
                            Text("BLOCKING")
                                .font(.system(.caption2, design: .default).weight(.bold))
                                .tracking(0.8)
                                .foregroundColor(ArtNouveauTheme.error)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(ArtNouveauTheme.errorLight)
                                .cornerRadius(4)
                        } else if preset.isEnabled {
                            Text("ON")
                                .font(.system(.caption2, design: .default).weight(.bold))
                                .tracking(0.8)
                                .foregroundColor(ArtNouveauTheme.primary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(ArtNouveauTheme.primaryLight)
                                .cornerRadius(4)
                        }
                    }
                    Text(subtitle)
                        .font(.system(.caption, design: .default))
                        .foregroundColor(ArtNouveauTheme.secondaryLabel)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(ArtNouveauTheme.tertiaryLabel)
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var subtitle: String {
        let appCount = preset.selection.applicationTokens.count
        let categoryCount = preset.selection.categoryTokens.count
        var parts: [String] = []
        if appCount > 0 { parts.append("\(appCount) app\(appCount == 1 ? "" : "s")") }
        if categoryCount > 0 { parts.append("\(categoryCount) categor\(categoryCount == 1 ? "y" : "ies")") }
        if parts.isEmpty { parts.append("No apps selected") }
        if let summary = preset.schedule?.summary {
            parts.append(summary)
        }
        return parts.joined(separator: " · ")
    }

    private var badgeIcon: String {
        if isRunning { return "lock.shield.fill" }
        if preset.isEnabled { return "lock.fill" }
        return "lock.open"
    }

    private var badgeColor: Color {
        if isRunning { return ArtNouveauTheme.error }
        if preset.isEnabled { return ArtNouveauTheme.primary }
        return ArtNouveauTheme.secondaryLabel
    }
}
