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
    @State private var showTypingChallenge = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        Form {
                // NFC Tag Section
                Section {
                    // Status display
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(configStore.isTagRegistered ? "Tag Registered" : "No Tag Registered")
                                .font(.headline)

                            Text("Register an NFC tag to toggle blocking on and off.")
                                .font(.caption)
                                .foregroundColor(ArtNouveauTheme.secondaryLabel)
                        }
                        Spacer()

                        Image(systemName: configStore.isTagRegistered ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                            .foregroundColor(configStore.isTagRegistered ? ArtNouveauTheme.success : ArtNouveauTheme.warning)
                            .font(.title2)
                            .symbolRenderingMode(.hierarchical)
                    }
                    
                    // Action buttons
                    if configStore.isTagRegistered {
                        Button(role: .destructive) {
                            configStore.clearTagRegistration()
                        } label: {
                            Label("Unregister Tag", systemImage: "xmark.circle")
                        }
                    } else {
                        NavigationLink {
                            TagRegistrationView()
                        } label: {
                            Label("Register NFC Tag", systemImage: "sensor.tag.radiowaves.forward")
                        }
                    }
                } header: {
                    Text("NFC Tag")
                }

                // App Selection Section
                Section {
                    if screenTimeManager.authorizationStatus != .approved {
                        // Status display
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Authorization Required")
                                    .font(.headline)

                                Text("Grant Screen Time permission to select apps to block.")
                                    .font(.caption)
                                    .foregroundColor(ArtNouveauTheme.secondaryLabel)
                            }
                            Spacer()

                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(ArtNouveauTheme.warning)
                                .font(.title2)
                                .symbolRenderingMode(.hierarchical)
                        }

                        // Action button
                        Button {
                            Task {
                                do {
                                    try await screenTimeManager.requestAuthorization()
                                } catch {
                                    print("Authorization error: \(error)")
                                }
                            }
                        } label: {
                            Label("Request Authorization", systemImage: "lock.open")
                        }
                        .buttonStyle(ArtNouveauButtonStyle(isProminent: true))
                    } else {
                        // Status display
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(configStore.selectedApps.isEmpty ? "No Apps Selected" : "\(configStore.selectedApps.count) App\(configStore.selectedApps.count == 1 ? "" : "s") Selected")
                                    .font(.headline)

                                Text("Select the apps you want to block when you scan your NFC tag.")
                                    .font(.caption)
                                    .foregroundColor(ArtNouveauTheme.secondaryLabel)
                            }
                            Spacer()

                            Image(systemName: configStore.selectedApps.isEmpty ? "app.badge" : "checkmark.circle.fill")
                                .foregroundColor(configStore.selectedApps.isEmpty ? ArtNouveauTheme.warning : ArtNouveauTheme.success)
                                .font(.title2)
                                .symbolRenderingMode(.hierarchical)
                        }

                        // Show warning if blocking is active
                        if configStore.isBlockingEnabled {
                            HStack(spacing: 12) {
                                Image(systemName: "lock.shield.fill")
                                    .font(.title2)
                                    .foregroundColor(ArtNouveauTheme.primary)
                                    .symbolRenderingMode(.hierarchical)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Blocking Active")
                                        .font(.headline)

                                    Text("Scan your NFC tag to disable blocking before modifying app selection.")
                                        .font(.caption)
                                        .foregroundColor(ArtNouveauTheme.secondaryLabel)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .padding(12)
                            .background(ArtNouveauTheme.primary.opacity(0.1))
                            .cornerRadius(12)
                        } else {
                            // Action button - only enabled when blocking is inactive
                            Button {
                                showPicker = true
                            } label: {
                                Label(configStore.selectedApps.isEmpty ? "Select Apps to Block" : "Edit App Selection", systemImage: "square.grid.2x2")
                            }

                            if !configStore.selectedApps.isEmpty {
                                Button(role: .destructive) {
                                    configStore.selectedApps.removeAll()
                                    screenTimeManager.disableBlocking()
                                } label: {
                                    Label("Clear Selection", systemImage: "trash")
                                }
                            }
                        }
                    }
                } header: {
                    Text("Apps to Block")
                } footer: {
                    if screenTimeManager.authorizationStatus == .approved {
                        Text("Tap 'Done' in the app selector to confirm your selection.")
                    }
                }

                // Emergency Override Section
                if configStore.isBlockingEnabled {
                    Section {
                        Button {
                            showTypingChallenge = true
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Emergency Override")
                                        .font(.headline)
                                        .foregroundColor(ArtNouveauTheme.warning)

                                    Text("Type a passage to disable blocking without your NFC tag.")
                                        .font(.caption)
                                        .foregroundColor(ArtNouveauTheme.secondaryLabel)
                                }
                                Spacer()
                                Image(systemName: "keyboard")
                                    .foregroundColor(ArtNouveauTheme.warning)
                                    .font(.title2)
                            }
                            .padding(.vertical, 4)
                        }
                    } header: {
                        Text("Emergency Access")
                    } footer: {
                        Text("Use this only when you don't have access to your NFC tag.")
                    }
                }
            }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
        .familyActivityPicker(isPresented: $showPicker, selection: $selectedTokenSet)
        .onChange(of: selectedTokenSet) { newValue in
            // Update selected apps when picker selection changes
            configStore.selectedApps = Set(newValue.applicationTokens)

            // Update blocking if currently enabled
            if configStore.isBlockingEnabled {
                screenTimeManager.updateBlocking(for: configStore.selectedApps)
            }
        }
        .sheet(isPresented: $showTypingChallenge) {
            TypingChallengeView(isPresented: $showTypingChallenge)
        }
    }
}

#Preview {
    SettingsView()
}
