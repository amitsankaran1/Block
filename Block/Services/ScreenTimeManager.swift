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
        checkAuthorizationStatus()
    }
    
    func checkAuthorizationStatus() {
        authorizationStatus = AuthorizationCenter.shared.authorizationStatus
    }
    
    func requestAuthorization() async throws {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            checkAuthorizationStatus()
        } catch {
            throw error
        }
    }
    
    func enableBlocking(for apps: Set<ApplicationToken>) {
        guard authorizationStatus == .approved else {
            print("Authorization not granted")
            return
        }
        
        // Apply blocking - setting applications will show default shield
        // Custom shield configuration requires a separate app extension
        store.shield.applications = apps
        
        configStore.setBlockingEnabled(true)
    }
    
    func disableBlocking() {
        store.clearAllSettings()
        configStore.setBlockingEnabled(false)
    }
    
    func toggleBlocking(for apps: Set<ApplicationToken>) {
        if configStore.isBlockingEnabled {
            disableBlocking()
        } else {
            enableBlocking(for: apps)
        }
    }
    
    func updateBlocking(for apps: Set<ApplicationToken>) {
        if configStore.isBlockingEnabled {
            enableBlocking(for: apps)
        }
    }
}
