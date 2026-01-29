//
//  ScreenTimeManager.swift
//  Block
//
//  Created by Amit Sankaran on 1/7/26.
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

        let selection = configStore.selectedApps
        let hasAppsToBlock = !selection.applicationTokens.isEmpty || !selection.categoryTokens.isEmpty

        if configStore.isBlockingEnabled && hasAppsToBlock {
            print("✅ Restoring blocking for \(selection.applicationTokens.count) apps, \(selection.categoryTokens.count) categories")
            store.shield.applications = selection.applicationTokens
            store.shield.applicationCategories = selection.categoryTokens
            store.shield.webDomains = selection.webDomainTokens
        } else {
            print("ℹ️ No blocking to restore (enabled: \(configStore.isBlockingEnabled), apps: \(selection.applicationTokens.count), categories: \(selection.categoryTokens.count))")
        }
    }
    
    func checkAuthorizationStatus() {
        let previousStatus = authorizationStatus
        let status = AuthorizationCenter.shared.authorizationStatus
        print("🔐 Authorization status: \(status)")
        authorizationStatus = status

        // If authorization just became approved, reload selection (tokens may
        // only resolve once authorization is active) and restore blocking
        if previousStatus != .approved && status == .approved {
            print("✅ Authorization just approved - reloading selection and restoring")
            configStore.reloadSelectedApps()
            restoreBlockingIfNeeded()
        }
    }

    func requestAuthorization() async throws {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            checkAuthorizationStatus()

            // After authorization, reload saved selection and restore blocking
            configStore.reloadSelectedApps()
            restoreBlockingIfNeeded()
        } catch {
            throw error
        }
    }
    
    func enableBlocking(for selection: FamilyActivitySelection) {
        guard authorizationStatus == .approved else {
            return
        }

        // Apply blocking - setting applications/categories will show default shield
        // Custom shield configuration requires a separate app extension
        // Note: FamilyActivitySelection contains three types of tokens:
        // - applicationTokens: individual apps
        // - categoryTokens: app categories (used when selecting "all apps" or bulk selections)
        // - webDomainTokens: web domains
        store.shield.applications = selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens
        store.shield.webDomains = selection.webDomainTokens

        print("🛡️ Enabled blocking: \(selection.applicationTokens.count) apps, \(selection.categoryTokens.count) categories, \(selection.webDomainTokens.count) domains")

        configStore.setBlockingEnabled(true)
    }

    func disableBlocking() {
        store.clearAllSettings()
        configStore.setBlockingEnabled(false)
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
}
