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

@MainActor
class AppConfigurationStore: ObservableObject {
    static let shared = AppConfigurationStore()

    @Published var selectedApps: Set<ApplicationToken> = [] {
        didSet {
            debouncedSave(key: selectedAppsKey, value: !selectedApps.isEmpty)
        }
    }

    @Published var registeredTagIdentifier: String? = nil {
        didSet {
            debouncedSave(key: registeredTagKey, value: registeredTagIdentifier)
        }
    }

    @Published var isBlockingEnabled: Bool = false {
        didSet {
            debouncedSave(key: blockingEnabledKey, value: isBlockingEnabled)
        }
    }

    private let selectedAppsKey = "selectedApps"
    private let registeredTagKey = "registeredTagIdentifier"
    private let blockingEnabledKey = "isBlockingEnabled"

    // Debouncing tasks to prevent excessive UserDefaults writes
    private var persistenceTasks: [String: Task<Void, Never>] = [:]
    private let debounceInterval: UInt64 = 300_000_000 // 300ms

    private init() {
        loadConfiguration()
    }

    func registerTag(identifier: String) {
        registeredTagIdentifier = identifier
    }

    func clearTagRegistration() {
        registeredTagIdentifier = nil
    }

    func setBlockingEnabled(_ enabled: Bool) {
        isBlockingEnabled = enabled
    }

    func toggleBlocking() {
        setBlockingEnabled(!isBlockingEnabled)
    }

    // Debounced save to prevent excessive UserDefaults writes
    private func debouncedSave(key: String, value: Any?) {
        // Cancel existing task for this key
        persistenceTasks[key]?.cancel()

        // Create new debounced save task
        persistenceTasks[key] = Task {
            try? await Task.sleep(nanoseconds: debounceInterval)

            guard !Task.isCancelled else { return }

            // Perform the actual save off the main actor to avoid blocking UI
            await Task.detached(priority: .utility) {
                if let value = value as? String {
                    UserDefaults.standard.set(value, forKey: key)
                } else if let value = value as? Bool {
                    UserDefaults.standard.set(value, forKey: key)
                } else if value == nil {
                    UserDefaults.standard.removeObject(forKey: key)
                }
            }.value
        }
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
