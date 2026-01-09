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
        }
    }
}
