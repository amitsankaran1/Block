//
//  SchedulingManager.swift
//  Block
//
//  Wraps `DeviceActivityCenter` to register/unregister scheduled monitoring per preset.
//  The actual shield application happens in the BlockMonitor extension's
//  `intervalDidStart`/`intervalDidEnd` callbacks.
//

import Foundation
import DeviceActivity
import Combine

@MainActor
class SchedulingManager: ObservableObject {
    static let shared = SchedulingManager()

    @Published private(set) var activeScheduledPresetIDs: Set<UUID> = []
    @Published var lastError: String?

    private let center = DeviceActivityCenter()
    private var refreshTimer: Timer?

    private init() {
        refresh()
        startPeriodicRefresh()
    }

    // MARK: - Activity name helpers

    static func activityName(for presetID: UUID, segment: BlockingSchedule.CrossingSegment = .full) -> DeviceActivityName {
        switch segment {
        case .full:  return DeviceActivityName(rawValue: "preset.\(presetID.uuidString)")
        case .early: return DeviceActivityName(rawValue: "preset.\(presetID.uuidString).early")
        case .late:  return DeviceActivityName(rawValue: "preset.\(presetID.uuidString).late")
        }
    }

    // MARK: - Public API

    /// Register or update monitoring for a preset's schedule.
    /// If the preset has no schedule, this is equivalent to `removeSchedule`.
    func applySchedule(for preset: BlockingPreset) {
        // Always stop any prior monitoring first to avoid stacking.
        removeSchedule(for: preset)

        guard let schedule = preset.schedule else { return }

        do {
            if schedule.crossesMidnight {
                try center.startMonitoring(
                    Self.activityName(for: preset.id, segment: .early),
                    during: schedule.deviceActivitySchedule(crossingSegment: .early)
                )
                try center.startMonitoring(
                    Self.activityName(for: preset.id, segment: .late),
                    during: schedule.deviceActivitySchedule(crossingSegment: .late)
                )
            } else {
                try center.startMonitoring(
                    Self.activityName(for: preset.id, segment: .full),
                    during: schedule.deviceActivitySchedule(crossingSegment: .full)
                )
            }
            lastError = nil
        } catch {
            print("❌ startMonitoring failed for preset \(preset.id): \(error)")
            lastError = "Couldn't start schedule: \(error.localizedDescription)"
        }
    }

    func removeSchedule(for preset: BlockingPreset) {
        let names = [
            Self.activityName(for: preset.id, segment: .full),
            Self.activityName(for: preset.id, segment: .early),
            Self.activityName(for: preset.id, segment: .late)
        ]
        center.stopMonitoring(names)
        // Also clear the running flag — if the schedule is removed mid-window,
        // the extension won't fire intervalDidEnd, so we must clean up.
        SharedDefaults.suite.removeObject(forKey: SharedDefaults.Keys.running(presetID: preset.id))
    }

    /// Re-register all preset schedules. Call once at launch — `startMonitoring` is
    /// idempotent for the same name + schedule.
    func reapplyAllSchedules() {
        for preset in PresetStore.shared.presets where preset.schedule != nil {
            applySchedule(for: preset)
        }
        refresh()
    }

    /// Refresh `activeScheduledPresetIDs` from the App Group running flags.
    func refresh() {
        var ids: Set<UUID> = []
        let suite = SharedDefaults.suite
        for preset in PresetStore.shared.presets {
            if suite.bool(forKey: SharedDefaults.Keys.running(presetID: preset.id)) {
                ids.insert(preset.id)
            }
        }
        if ids != activeScheduledPresetIDs {
            activeScheduledPresetIDs = ids
        }
    }

    private func startPeriodicRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }
}
