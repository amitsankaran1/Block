//
//  DebugMenuView.swift
//  Block
//
//  Test affordances for simulator development. Compiled out of release.
//

#if DEBUG

import SwiftUI
import Combine
import FamilyControls

struct DebugMenuView: View {
    @StateObject private var presetStore = PresetStore.shared
    @StateObject private var schedulingManager = SchedulingManager.shared
    @StateObject private var configStore = AppConfigurationStore.shared
    @StateObject private var screenTimeManager = ScreenTimeManager.shared
    @StateObject private var cooldownManager = CooldownManager.shared
    @StateObject private var debugLog = DebugLog.shared

    @State private var refreshTick = 0
    private let timer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()

    private var snapshot: DebugSimulator.GlobalSnapshot {
        // refreshTick is read so SwiftUI re-evaluates on the timer
        _ = refreshTick
        return DebugSimulator.snapshot()
    }

    var body: some View {
        List {
            globalStateSection
            tagFlowSection
            presetsSection
            logSection
            dangerZoneSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Debug Menu")
        .navigationBarTitleDisplayMode(.inline)
        .onReceive(timer) { _ in
            refreshTick &+= 1
        }
    }

    // MARK: - Global state

    private var globalStateSection: some View {
        Section("Global State") {
            row("Screen Time auth", value: authString(snapshot.authorizationStatus))
            row("Tag-flow blocking", value: snapshot.isTagFlowBlocking ? "ON" : "off")
            row("Selected apps", value: "\(snapshot.selectedAppCount)")
            row("Active scheduled presets", value: "\(snapshot.activeScheduledIDs.count)")
            if let id = snapshot.activeCooldownPresetID {
                row("Active cooldown",
                    value: shortID(id) + " (\(Int(cooldownManager.remaining))s)")
            }
        }
    }

    // MARK: - Tag flow

    private var tagFlowSection: some View {
        Section("NFC Tag Flow") {
            if let tag = snapshot.registeredTag {
                row("Registered tag", value: tag)
            } else {
                Text("No tag registered").foregroundStyle(.secondary)
            }

            Button("Simulate registered tag scan (toggle)") {
                DebugSimulator.simulateRegisteredTagScan()
            }
            .disabled(snapshot.registeredTag == nil)

            Button("Simulate unknown tag scan") {
                DebugSimulator.simulateUnknownTagScan()
            }

            Button("Register fake tag") {
                DebugSimulator.registerFakeTag()
            }
            .disabled(snapshot.registeredTag != nil)

            if snapshot.registeredTag != nil {
                Button("Clear tag registration", role: .destructive) {
                    configStore.clearTagRegistration()
                    DebugLog.shared.log(.nfc, "cleared tag registration")
                }
            }
        }
    }

    // MARK: - Presets

    @ViewBuilder
    private var presetsSection: some View {
        if snapshot.presets.isEmpty {
            Section("Presets") {
                Text("No presets — create one from Settings.")
                    .foregroundStyle(.secondary)
            }
        } else {
            ForEach(snapshot.presets) { preset in
                Section(preset.name) {
                    presetRows(preset)
                }
            }
        }
    }

    @ViewBuilder
    private func presetRows(_ preset: DebugSimulator.PresetSnapshot) -> some View {
        row("ID", value: shortID(preset.id))
        row("Apps / Categories", value: "\(preset.appCount) / \(preset.categoryCount)")
        row("Schedule", value: preset.scheduleSummary ?? "—")
        row("Manual enabled", value: preset.isEnabled ? "ON" : "off")
        row("Scheduled running flag", value: preset.isScheduledRunning ? "ON" : "off")
        row("Cooldown minutes", value: "\(preset.cooldownMinutes)")
        if let endsAt = preset.cooldownEndsAt {
            let secs = Int(endsAt.timeIntervalSinceNow)
            row("Cooldown ends in", value: secs > 0 ? "\(secs)s" : "expired")
        }

        Button("Fire interval start now") {
            DebugSimulator.fireScheduleStart(presetID: preset.id)
        }
        Button("Fire interval end now") {
            DebugSimulator.fireScheduleEnd(presetID: preset.id)
        }
        Button("Start 10s cooldown") {
            DebugSimulator.startShortCooldown(presetID: preset.id, seconds: 10)
        }
        if cooldownManager.activeCooldown?.presetID == preset.id {
            Button("Fast-forward cooldown") {
                DebugSimulator.expireCooldown()
            }
        }
    }

    // MARK: - Log

    private var logSection: some View {
        Section {
            if debugLog.entries.isEmpty {
                Text("No events yet").foregroundStyle(.secondary)
            } else {
                ForEach(debugLog.entries.suffix(40).reversed()) { entry in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(entry.channel.emoji)
                            Text(entry.channel.rawValue)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(entry.timestamp, format: .dateTime.hour().minute().second())
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        Text(entry.message)
                            .font(.caption.monospaced())
                    }
                    .padding(.vertical, 2)
                }
            }
        } header: {
            HStack {
                Text("Event Log")
                Spacer()
                Button("Clear") { debugLog.clear() }
                    .font(.caption)
            }
        }
    }

    // MARK: - Danger zone

    private var dangerZoneSection: some View {
        Section("Danger Zone") {
            Button("Reset runtime state (keep presets)", role: .destructive) {
                DebugSimulator.resetAllRuntime()
            }
        }
    }

    // MARK: - Helpers

    private func row(_ label: String, value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.callout.monospacedDigit())
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    private func shortID(_ id: UUID) -> String {
        String(id.uuidString.prefix(8))
    }

    private func authString(_ status: AuthorizationStatus) -> String {
        switch status {
        case .notDetermined: return "notDetermined"
        case .denied:        return "denied"
        case .approved:      return "approved"
        @unknown default:    return "unknown"
        }
    }
}

#endif
