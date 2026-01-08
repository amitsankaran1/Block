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
    // Initialize singleton instances once for the entire app lifecycle
    @StateObject private var configStore = AppConfigurationStore.shared
    @StateObject private var screenTimeManager = ScreenTimeManager.shared
    @StateObject private var nfcManager = NFCManager.shared

    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(configStore)
                .environmentObject(screenTimeManager)
                .environmentObject(nfcManager)
                .onContinueUserActivity("com.apple.developer.nfc.readersession.formats.NDEF") { userActivity in
                    handleBackgroundNFC(userActivity: userActivity)
                }
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                // Handle any pending NFC scans when app becomes active
                handleSceneActivation()
            }
        }
    }

    private func handleBackgroundNFC(userActivity: NSUserActivity) {
        // When an NFC tag is scanned in the background, iOS launches the app with this user activity
        // Start scanning immediately when the scene becomes active
        Task { @MainActor in
            await nfcManager.startScanning()
        }
    }

    private func handleSceneActivation() {
        // No hardcoded delays - handle scene activation cleanly
        // The NFC manager will handle scanning when appropriate
    }
}
