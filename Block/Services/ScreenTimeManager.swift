//
//  ScreenTimeManager.swift
//  Block
//
//  Created by Amit Sankaran on 1/7/26.
//
//  The unnamed default `ManagedSettingsStore` belongs to the NFC tag flow.
//  Per-preset blocking uses `ManagedSettingsStore(named:)` instances keyed by preset UUID,
//  so a tag tap (which only touches the unnamed store) cannot clear a scheduled preset's shield.
//

import Foundation
import FamilyControls
import ManagedSettings
import Combine

@MainActor
class ScreenTimeManager: ObservableObject {
    static let shared = ScreenTimeManager()

    @Published var authorizationStatus: AuthorizationStatus = .notDetermined

    private let store = ManagedSettingsStore()
    private let configStore = AppConfigurationStore.shared
    private var presetStores: [UUID: ManagedSettingsStore] = [:]

    private init() {
        // Check authorization status multiple times to ensure we catch it when iOS is ready
        checkAuthorizationStatus()

        // Delay restoration to ensure AppConfigurationStore has finished loading
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
            checkAuthorizationStatus()
            restoreBlockingIfNeeded()

            // Check again after a longer delay in case iOS needs more time
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second
            checkAuthorizationStatus()
        }
    }

    func restoreBlockingIfNeeded() {
        // If blocking was enabled when app was closed, reapply it on startup
        guard authorizationStatus == .approved else {
            print("⚠️ Cannot restore blocking: authorization not approved")
            return
        }

        if configStore.isBlockingEnabled && !configStore.selectedApps.applicationTokens.isEmpty {
            print("✅ Restoring blocking for \(configStore.selectedApps.applicationTokens.count) apps")
            store.shield.applications = configStore.selectedApps.applicationTokens
        } else {
            print("ℹ️ No blocking to restore (enabled: \(configStore.isBlockingEnabled), apps: \(configStore.selectedApps.applicationTokens.count))")
        }

        // Restore manually-enabled preset shields
        for preset in PresetStore.shared.presets where preset.isEnabled {
            applyPresetShield(preset)
        }
    }

    func checkAuthorizationStatus() {
        let previousStatus = authorizationStatus
        let status = AuthorizationCenter.shared.authorizationStatus
        print("🔐 Authorization status: \(status)")
        authorizationStatus = status

        // If authorization just became approved and we have saved apps, restore blocking if needed
        if previousStatus != .approved && status == .approved {
            print("✅ Authorization just approved - checking if we need to restore")
            restoreBlockingIfNeeded()
        }
    }

    func requestAuthorization() async throws {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            checkAuthorizationStatus()

            // After authorization, ensure blocking is restored if it was previously enabled
            restoreBlockingIfNeeded()
        } catch {
            throw error
        }
    }

    // MARK: - Tag flow (unnamed default store)

    func enableBlocking(for selection: FamilyActivitySelection) {
        guard authorizationStatus == .approved else {
            #if DEBUG
            DebugLog.shared.log(.screenTime, "enableBlocking skipped — auth not approved")
            #endif
            return
        }

        // Apply blocking - setting applications will show default shield
        // Custom shield configuration requires a separate app extension
        store.shield.applications = selection.applicationTokens

        configStore.setBlockingEnabled(true)
        #if DEBUG
        DebugLog.shared.log(.screenTime, "enableBlocking applied (\(selection.applicationTokens.count) apps) on default store")
        #endif
    }

    func disableBlocking() {
        store.clearAllSettings()
        configStore.setBlockingEnabled(false)
        #if DEBUG
        DebugLog.shared.log(.screenTime, "disableBlocking cleared default store")
        #endif
    }

    func toggleBlocking(for selection: FamilyActivitySelection) {
        if configStore.isBlockingEnabled {
            disableBlocking()
        } else {
            enableBlocking(for: selection)
        }
    }

    func updateBlocking(for selection: FamilyActivitySelection) {
        if configStore.isBlockingEnabled {
            enableBlocking(for: selection)
        }
    }

    // MARK: - Preset flow (named stores)

    private func presetStore(for id: UUID) -> ManagedSettingsStore {
        if let existing = presetStores[id] { return existing }
        let storeName = ManagedSettingsStore.Name(rawValue: "preset.\(id.uuidString)")
        let store = ManagedSettingsStore(named: storeName)
        presetStores[id] = store
        return store
    }

    /// Apply a preset's shield to its named store. Safe to call when authorization is pending —
    /// it will be restored later via `restoreBlockingIfNeeded`.
    func applyPresetShield(_ preset: BlockingPreset) {
        guard authorizationStatus == .approved else {
            #if DEBUG
            DebugLog.shared.log(.screenTime, "applyPresetShield(\(preset.name)) skipped — auth not approved")
            #endif
            return
        }
        let store = presetStore(for: preset.id)
        store.shield.applications = preset.selection.applicationTokens.isEmpty
            ? nil
            : preset.selection.applicationTokens
        if !preset.selection.categoryTokens.isEmpty {
            store.shield.applicationCategories = .specific(preset.selection.categoryTokens)
        } else {
            store.shield.applicationCategories = nil
        }
        #if DEBUG
        DebugLog.shared.log(.screenTime, "applyPresetShield(\(preset.name)): \(preset.selection.applicationTokens.count) apps, \(preset.selection.categoryTokens.count) categories")
        #endif
    }

    /// Clear a preset's shield (cooldown completion or manual disable).
    func clearPresetShield(id: UUID) {
        let store = presetStore(for: id)
        store.clearAllSettings()
        #if DEBUG
        DebugLog.shared.log(.screenTime, "clearPresetShield for \(id.uuidString.prefix(8))")
        #endif
    }

    /// Convenience used by the editor: re-apply if currently shielded (manual or scheduled).
    func updatePresetShieldIfActive(_ preset: BlockingPreset) {
        let scheduledActive = SharedDefaults.suite.bool(forKey: SharedDefaults.Keys.running(presetID: preset.id))
        if preset.isEnabled || scheduledActive {
            applyPresetShield(preset)
        }
    }
}
