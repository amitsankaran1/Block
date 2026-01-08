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
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onContinueUserActivity("com.apple.developer.nfc.readersession.formats.NDEF") { userActivity in
                    handleBackgroundNFC(userActivity: userActivity)
                }
        }
    }
    
    private func handleBackgroundNFC(userActivity: NSUserActivity) {
        // When an NFC tag is scanned in the background, iOS launches the app with this user activity
        // The NDEF message data should be available, but we need to start a new NFC session
        // to read it properly, or extract it from the user activity if available
        
        // For iOS 13+, background NFC tag reading launches the app
        // We'll start a new NFC session to read the tag when the app becomes active
        // This ensures we can properly read the NDEF message
        Task { @MainActor in
            // Small delay to ensure app is fully active
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            nfcManager.startScanning()
        }
    }
}
