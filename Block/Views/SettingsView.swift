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
        Form {
            // NFC Tag Section
            Section {
                if configStore.isTagRegistered {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("NFC Tag")
                                .font(.headline)
                            Text("Registered")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }

                    Button(role: .destructive) {
                        configStore.clearTagRegistration()
                    } label: {
                        Text("Unregister Tag")
                    }
                } else {
                    NavigationLink {
                        TagRegistrationView()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("NFC Tag")
                                    .font(.headline)
                                Text("Not Registered")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "sensor.tag.radiowaves.forward")
                                .foregroundColor(.blue)
                        }
                    }
                }
            } header: {
                Text("NFC Tag")
            } footer: {
                Text("Register an NFC tag to toggle blocking on and off.")
            }

            // App Selection Section
            Section {
                if screenTimeManager.authorizationStatus != .approved {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Screen Time authorization required")
                            .font(.headline)
                        Text("Grant Screen Time permission to select apps to block.")
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
                        .buttonStyle(BorderedProminentButtonStyle())
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
                Text("Apps to Block")
            } footer: {
                if screenTimeManager.authorizationStatus == .approved {
                    Text("Select the apps you want to block when you scan your NFC tag.")
                }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
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

#Preview {
    SettingsView()
}
