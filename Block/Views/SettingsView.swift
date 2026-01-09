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
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            ArtNouveauBackground()
                .ignoresSafeArea()
            
            Form {
                // NFC Tag Section
                Section {
                    // Status display (not a button)
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                Text("NFC Tag")
                                    .font(ArtNouveauTheme.headlineFont)
                                    .foregroundColor(ArtNouveauTheme.forestGreen)
                                
                                // Status badge
                                HStack(spacing: 4) {
                                    Image(systemName: configStore.isTagRegistered ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 12, weight: .semibold))
                                    Text(configStore.isTagRegistered ? "Registered" : "Not Registered")
                                        .font(.caption)
                                }
                                .foregroundColor(configStore.isTagRegistered ? ArtNouveauTheme.forestGreen : ArtNouveauTheme.oliveGreen.opacity(0.6))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(configStore.isTagRegistered ? ArtNouveauTheme.forestGreen.opacity(0.15) : ArtNouveauTheme.oliveGreen.opacity(0.1))
                                )
                            }
                            
                            Text("Register an NFC tag to toggle blocking on and off.")
                                .font(.caption)
                                .foregroundColor(ArtNouveauTheme.oliveGreen.opacity(0.7))
                        }
                        Spacer()
                        
                        if configStore.isTagRegistered {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(ArtNouveauTheme.primaryGradient)
                                .font(.system(size: 28))
                        } else {
                            Image(systemName: "exclamationmark.circle")
                                .foregroundColor(ArtNouveauTheme.oliveGreen.opacity(0.5))
                                .font(.system(size: 28))
                        }
                    }
                    .padding(.vertical, 8)
                    
                    // Action buttons
                    if configStore.isTagRegistered {
                        Button(role: .destructive) {
                            configStore.clearTagRegistration()
                        } label: {
                            HStack {
                                Image(systemName: "xmark.circle")
                                Text("Unregister Tag")
                            }
                            .font(ArtNouveauTheme.bodyFont)
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(ArtNouveauButtonStyle(isProminent: false))
                    } else {
                        NavigationLink {
                            TagRegistrationView()
                        } label: {
                            HStack {
                                Image(systemName: "sensor.tag.radiowaves.forward")
                                Text("Register NFC Tag")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(ArtNouveauTheme.oliveGreen.opacity(0.5))
                            }
                            .font(ArtNouveauTheme.bodyFont)
                            .foregroundColor(ArtNouveauTheme.forestGreen)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(ArtNouveauTheme.warmIvory)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(ArtNouveauTheme.oliveGreen.opacity(0.3), lineWidth: 1.5)
                                    )
                            )
                        }
                    }
                } header: {
                    Text("NFC Tag")
                        .font(ArtNouveauTheme.headlineFont)
                        .foregroundColor(ArtNouveauTheme.forestGreen)
                }
                .listRowBackground(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(ArtNouveauTheme.warmIvory)
                        .padding(.vertical, 2)
                )

                // App Selection Section
                Section {
                    if screenTimeManager.authorizationStatus != .approved {
                        // Status display
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Text("Apps to Block")
                                    .font(ArtNouveauTheme.headlineFont)
                                    .foregroundColor(ArtNouveauTheme.forestGreen)
                                
                                HStack(spacing: 4) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.system(size: 10, weight: .semibold))
                                    Text("Authorization Required")
                                        .font(.caption)
                                }
                                .foregroundColor(ArtNouveauTheme.mutedGold)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(ArtNouveauTheme.mutedGold.opacity(0.2))
                                )
                            }
                            
                            Text("Grant Screen Time permission to select apps to block.")
                                .font(.caption)
                                .foregroundColor(ArtNouveauTheme.oliveGreen.opacity(0.7))
                        }
                        .padding(.vertical, 8)

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
                            HStack {
                                Image(systemName: "lock.open")
                                Text("Request Authorization")
                            }
                            .font(ArtNouveauTheme.bodyFont)
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(ArtNouveauButtonStyle(isProminent: true))
                    } else {
                        // Status display (not a button)
                        HStack {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 8) {
                                    Text("Apps to Block")
                                        .font(ArtNouveauTheme.headlineFont)
                                        .foregroundColor(ArtNouveauTheme.forestGreen)
                                    
                                    // Status badge
                                    if !configStore.selectedApps.isEmpty {
                                        HStack(spacing: 4) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.system(size: 12, weight: .semibold))
                                            Text("\(configStore.selectedApps.count) selected")
                                                .font(.caption)
                                        }
                                        .foregroundColor(ArtNouveauTheme.forestGreen)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(
                                            Capsule()
                                                .fill(ArtNouveauTheme.forestGreen.opacity(0.15))
                                        )
                                    } else {
                                        HStack(spacing: 4) {
                                            Image(systemName: "circle")
                                                .font(.system(size: 12, weight: .semibold))
                                            Text("None selected")
                                                .font(.caption)
                                        }
                                        .foregroundColor(ArtNouveauTheme.oliveGreen.opacity(0.6))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(
                                            Capsule()
                                                .fill(ArtNouveauTheme.oliveGreen.opacity(0.1))
                                        )
                                    }
                                }
                                
                                Text("Select the apps you want to block when you scan your NFC tag.")
                                    .font(.caption)
                                    .foregroundColor(ArtNouveauTheme.oliveGreen.opacity(0.7))
                            }
                            Spacer()
                            
                            if !configStore.selectedApps.isEmpty {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(ArtNouveauTheme.primaryGradient)
                                    .font(.system(size: 28))
                            } else {
                                Image(systemName: "app.badge")
                                    .foregroundColor(ArtNouveauTheme.oliveGreen.opacity(0.5))
                                    .font(.system(size: 28))
                            }
                        }
                        .padding(.vertical, 8)

                        // Action button
                        Button {
                            showPicker = true
                        } label: {
                            HStack {
                                Image(systemName: "square.grid.2x2")
                                Text("Select Apps to Block")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(ArtNouveauTheme.oliveGreen.opacity(0.5))
                            }
                            .font(ArtNouveauTheme.bodyFont)
                            .foregroundColor(ArtNouveauTheme.forestGreen)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(ArtNouveauTheme.warmIvory)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(ArtNouveauTheme.oliveGreen.opacity(0.3), lineWidth: 1.5)
                                    )
                            )
                        }

                        if !configStore.selectedApps.isEmpty {
                            Button(role: .destructive) {
                                configStore.selectedApps.removeAll()
                                screenTimeManager.disableBlocking()
                            } label: {
                                HStack {
                                    Image(systemName: "trash")
                                    Text("Clear Selection")
                                }
                                .font(ArtNouveauTheme.bodyFont)
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(ArtNouveauButtonStyle(isProminent: false))
                        }
                    }
                } header: {
                    Text("Apps to Block")
                        .font(ArtNouveauTheme.headlineFont)
                        .foregroundColor(ArtNouveauTheme.forestGreen)
                } footer: {
                    if screenTimeManager.authorizationStatus == .approved {
                        Text("Tap 'Done' in the app selector to confirm your selection.")
                            .font(.caption)
                            .foregroundColor(ArtNouveauTheme.oliveGreen.opacity(0.7))
                    }
                }
                .listRowBackground(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(ArtNouveauTheme.warmIvory)
                        .padding(.vertical, 2)
                )
            }
            .scrollContentBackground(.hidden)
            .background(Color.clear)
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark")
                        Text("Done")
                    }
                    .font(ArtNouveauTheme.bodyFont)
                    .foregroundColor(ArtNouveauTheme.forestGreen)
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
    }
}

#Preview {
    SettingsView()
}
