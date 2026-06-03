//
//  PresetStore.swift
//  Block
//
//  Persists `[BlockingPreset]` to the App Group suite. Host-only.
//

import Foundation
import FamilyControls
import Combine

@MainActor
class PresetStore: ObservableObject {
    static let shared = PresetStore()

    @Published private(set) var presets: [BlockingPreset] = []

    private let presetsKey = SharedDefaults.Keys.presets
    private var defaults: UserDefaults { SharedDefaults.suite }
    private var saveTask: Task<Void, Never>?

    private init() {
        load()
    }

    // MARK: - Public API

    func preset(id: UUID) -> BlockingPreset? {
        presets.first(where: { $0.id == id })
    }

    @discardableResult
    func create(name: String) -> BlockingPreset {
        let preset = BlockingPreset(name: name)
        presets.append(preset)
        save()
        return preset
    }

    func update(_ preset: BlockingPreset) {
        guard let idx = presets.firstIndex(where: { $0.id == preset.id }) else { return }
        presets[idx] = preset
        save()
    }

    func delete(id: UUID) {
        presets.removeAll(where: { $0.id == id })
        save()
        // Clean up associated flags
        defaults.removeObject(forKey: SharedDefaults.Keys.running(presetID: id))
        defaults.removeObject(forKey: SharedDefaults.Keys.cooldownEnd(presetID: id))
    }

    func setSelection(id: UUID, selection: FamilyActivitySelection) {
        guard var p = preset(id: id) else { return }
        p.selection = selection
        update(p)
    }

    func setSchedule(id: UUID, schedule: BlockingSchedule?) {
        guard var p = preset(id: id) else { return }
        p.schedule = schedule
        update(p)
    }

    func setEnabled(id: UUID, enabled: Bool) {
        guard var p = preset(id: id) else { return }
        p.isEnabled = enabled
        update(p)
    }

    func setName(id: UUID, name: String) {
        guard var p = preset(id: id) else { return }
        p.name = name
        update(p)
    }

    func setCooldown(id: UUID, minutes: Int) {
        guard var p = preset(id: id) else { return }
        p.cooldownMinutes = max(0, min(minutes, 60))
        update(p)
    }

    /// Set (or clear, with `limitMinutes: nil`) the usage budget and lockout duration.
    func setUsageLimit(id: UUID, limitMinutes: Int?, lockMinutes: Int) {
        guard var p = preset(id: id) else { return }
        p.usageLimitMinutes = limitMinutes
        p.usageLockMinutes = max(1, lockMinutes)
        update(p)
    }

    /// IDs of presets currently inside an active scheduled window
    /// (set by the BlockMonitor extension).
    var activeScheduledPresetIDs: Set<UUID> {
        var ids: Set<UUID> = []
        for preset in presets {
            let key = SharedDefaults.Keys.running(presetID: preset.id)
            if defaults.bool(forKey: key) {
                ids.insert(preset.id)
            }
        }
        return ids
    }

    // MARK: - Persistence

    private func save() {
        saveTask?.cancel()
        saveTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s debounce
            if !Task.isCancelled {
                self.persistNow()
            }
        }
    }

    /// Cancel pending debounced save and flush to disk synchronously.
    /// The in-process actuator path needs this so cross-process readers
    /// (and the extension) see fresh state immediately after a create/update.
    func flush() {
        saveTask?.cancel()
        persistNow()
    }

    private func persistNow() {
        do {
            let data = try JSONEncoder().encode(presets)
            defaults.set(data, forKey: presetsKey)
            print("💾 Saved \(presets.count) presets")
        } catch {
            print("❌ Failed to encode presets: \(error)")
        }
    }

    private func load() {
        guard let data = defaults.data(forKey: presetsKey) else {
            presets = []
            return
        }
        do {
            presets = try JSONDecoder().decode([BlockingPreset].self, from: data)
            print("✅ Loaded \(presets.count) presets")
        } catch {
            print("❌ Failed to decode presets: \(error)")
            presets = []
        }
    }
}
