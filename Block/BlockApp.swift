//
//  BlockApp.swift
//  Block
//
//  Created by Amit Sankaran on 1/7/26.
//

import SwiftUI
import CoreNFC

@main
struct BlockApp: App {
    @StateObject private var nfcManager = NFCManager.shared

    init() {
        AppConfigurationStore.migrateLegacyDefaults()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    _ = PresetStore.shared
                    SchedulingManager.shared.reapplyAllSchedules()
                    UsageLimitManager.shared.reapplyAllUsageLimits()
                    UsageLimitManager.shared.reconcileExpiredLocks()
                    CooldownManager.shared.restoreActiveCooldownsIfAny()
                    #if DEBUG
                    TestHarness.seedDemoStateIfRequested()
                    TestHarness.runIfEnabled()
                    #endif
                }
        }
    }
}
