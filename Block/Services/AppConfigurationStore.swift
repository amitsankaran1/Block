//
//  AppConfigurationStore.swift
//  Block
//
//  Created by Amit Sankaran on 1/7/26.
//

import Foundation
import FamilyControls
import ManagedSettings
import Combine

class AppConfigurationStore: ObservableObject {
    static let shared = AppConfigurationStore()
    
    @Published var selectedApps: Set<ApplicationToken> = []
    @Published var registeredTagIdentifier: String? = nil
    @Published var isBlockingEnabled: Bool = false
    
    private let selectedAppsKey = "selectedApps"
    private let registeredTagKey = "registeredTagIdentifier"
    private let blockingEnabledKey = "isBlockingEnabled"
    
    private init() {
        loadConfiguration()
    }
    
    func saveSelectedApps(_ apps: Set<ApplicationToken>) {
        selectedApps = apps
        // ApplicationToken is not directly Codable, so we store the selection
        // The actual tokens are managed by FamilyActivityPicker
        UserDefaults.standard.set(true, forKey: selectedAppsKey)
    }
    
    func registerTag(identifier: String) {
        registeredTagIdentifier = identifier
        UserDefaults.standard.set(identifier, forKey: registeredTagKey)
    }
    
    func clearTagRegistration() {
        registeredTagIdentifier = nil
        UserDefaults.standard.removeObject(forKey: registeredTagKey)
    }
    
    func setBlockingEnabled(_ enabled: Bool) {
        isBlockingEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: blockingEnabledKey)
    }
    
    func toggleBlocking() {
        setBlockingEnabled(!isBlockingEnabled)
    }
    
    private func loadConfiguration() {
        registeredTagIdentifier = UserDefaults.standard.string(forKey: registeredTagKey)
        isBlockingEnabled = UserDefaults.standard.bool(forKey: blockingEnabledKey)
        // Note: ApplicationToken selection is managed by FamilyActivityPicker
        // and persisted automatically by the system
    }
    
    var hasSelectedApps: Bool {
        !selectedApps.isEmpty
    }
    
    var isTagRegistered: Bool {
        registeredTagIdentifier != nil
    }
}
