//
//  SettingsView.swift
//  Block
//
//  Created by Amit Sankaran on 1/7/26.
//

import SwiftUI
import FamilyControls

struct SettingsView: View {
    @StateObject private var configStore = AppConfigurationStore.shared
    @StateObject private var screenTimeManager = ScreenTimeManager.shared
    @State private var showPicker = false
    @State private var selectedTokenSet = FamilyActivitySelection()
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    if screenTimeManager.authorizationStatus != .approved {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Screen Time authorization required")
                                .font(.headline)
                            Text("Please grant Screen Time permission in Settings to use app blocking features.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Button("Request Authorization") {
                                Task {
                                    do {
                                        try await screenTimeManager.requestAuthorization()
                                    } catch {
                                        print("Authorization error: \(error)")
                                    }
                                }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding(.vertical, 8)
                    } else {
                        Button {
                            showPicker = true
                        } label: {
                            HStack {
                                Text("Select Apps to Block")
                                Spacer()
                                if !configStore.selectedApps.isEmpty {
                                    Text("\(configStore.selectedApps.count) selected")
                                        .foregroundColor(.secondary)
                                }
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                        }
                        
                        if !configStore.selectedApps.isEmpty {
                            Button(role: .destructive) {
                                configStore.selectedApps.removeAll()
                                screenTimeManager.disableBlocking()
                            } label: {
                                Text("Clear Selection")
                            }
                        }
                    }
                } header: {
                    Text("App Selection")
                } footer: {
                    if screenTimeManager.authorizationStatus == .approved {
                        Text("Select the apps you want to block when the NFC tag is scanned.")
                    }
                }
            }
            .navigationTitle("Settings")
            .familyActivityPicker(isPresented: $showPicker, selection: $selectedTokenSet)
            .onChange(of: selectedTokenSet) { newValue in
                // Update selected apps when picker selection changes
                configStore.selectedApps = Set(newValue.applicationTokens)
                
                // Update blocking if currently enabled
                if configStore.isBlockingEnabled {
                    screenTimeManager.updateBlocking(for: configStore.selectedApps)
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}
