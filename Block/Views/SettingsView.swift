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
    @State private var showTypingChallenge = false
    @State private var isRequestingAuthorization = false
    @Environment(\.dismiss) private var dismiss

    private var selectionSummary: String {
        let appCount = configStore.selectedApps.applicationTokens.count
        let categoryCount = configStore.selectedApps.categoryTokens.count

        var parts: [String] = []
        if appCount > 0 {
            parts.append("\(appCount) app\(appCount == 1 ? "" : "s")")
        }
        if categoryCount > 0 {
            parts.append("\(categoryCount) categor\(categoryCount == 1 ? "y" : "ies")")
        }

        if parts.isEmpty {
            return "Selection ready to block."
        }
        return "\(parts.joined(separator: ", ")) ready to block."
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // NFC Tag Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Blocking Tag")
                        .font(.system(.headline, design: .default).weight(.bold))
                        .foregroundColor(ArtNouveauTheme.label)
                        .padding(.horizontal, 24)
                    
                    ArtNouveauCard(shadow: ArtNouveauTheme.shadowMedium) {
                        VStack(spacing: 16) {
                            // Status display
                            HStack(spacing: 16) {
                                ZStack {
                                    Circle()
                                        .fill(
                                            configStore.isTagRegistered 
                                                ? ArtNouveauTheme.successLight 
                                                : ArtNouveauTheme.warningLight
                                        )
                                        .frame(width: 56, height: 56)
                                    
                                    Image(systemName: configStore.isTagRegistered ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                        .foregroundColor(configStore.isTagRegistered ? ArtNouveauTheme.success : ArtNouveauTheme.warning)
                                        .font(.system(size: 28, weight: .semibold))
                                        .symbolRenderingMode(.hierarchical)
                                }
                                
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(configStore.isTagRegistered ? "Tag Connected" : "No Tag Connected")
                                        .font(.system(.headline, design: .default).weight(.bold))
                                        .foregroundColor(ArtNouveauTheme.label)

                                    Text("Connect a tag to start and stop blocking with a simple tap.")
                                        .font(.system(.subheadline, design: .default))
                                        .foregroundColor(ArtNouveauTheme.secondaryLabel)
                                }
                                
                                Spacer()
                            }
                            
                            Divider()
                            
                            // Action buttons
                            if configStore.isTagRegistered {
                                Button {
                                    configStore.clearTagRegistration()
                                } label: {
                                    HStack(spacing: 10) {
                                        Image(systemName: "xmark.circle")
                                        Text("Disconnect Tag")
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(ArtNouveauButtonStyle(isProminent: false))
                            } else {
                                NavigationLink {
                                    TagRegistrationView()
                                } label: {
                                    HStack(spacing: 10) {
                                        Image(systemName: "sensor.tag.radiowaves.forward")
                                        Text("Connect Your Tag")
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(ArtNouveauButtonStyle(isProminent: true))
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                }

                // App Selection Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Apps to Block")
                        .font(.system(.headline, design: .default).weight(.bold))
                        .foregroundColor(ArtNouveauTheme.label)
                        .padding(.horizontal, 24)
                    
                    ArtNouveauCard(shadow: ArtNouveauTheme.shadowMedium) {
                        VStack(spacing: 16) {
                            if screenTimeManager.authorizationStatus != .approved {
                                // Status display
                                HStack(spacing: 16) {
                                    ZStack {
                                        Circle()
                                            .fill(ArtNouveauTheme.warningLight)
                                            .frame(width: 56, height: 56)
                                        
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundColor(ArtNouveauTheme.warning)
                                            .font(.system(size: 28, weight: .semibold))
                                            .symbolRenderingMode(.hierarchical)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("Authorization Required")
                                            .font(.system(.headline, design: .default).weight(.bold))
                                            .foregroundColor(ArtNouveauTheme.label)

                                        Text("Grant Screen Time permission to select apps to block.")
                                            .font(.system(.subheadline, design: .default))
                                            .foregroundColor(ArtNouveauTheme.secondaryLabel)
                                    }
                                    
                                    Spacer()
                                }

                                Divider()

                                // Action button
                                Button {
                                    Task {
                                        isRequestingAuthorization = true
                                        do {
                                            try await screenTimeManager.requestAuthorization()
                                        } catch {
                                            // Authorization error handled silently
                                        }
                                        isRequestingAuthorization = false
                                    }
                                } label: {
                                    HStack(spacing: 10) {
                                        if isRequestingAuthorization {
                                            ProgressView()
                                                .controlSize(.small)
                                                .tint(.white)
                                        } else {
                                            Image(systemName: "lock.open")
                                        }
                                        Text(isRequestingAuthorization ? "Requesting..." : "Request Authorization")
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(ArtNouveauButtonStyle(isProminent: true))
                                .disabled(isRequestingAuthorization)
                            } else {
                                // Status display
                                HStack(spacing: 16) {
                                    ZStack {
                                        Circle()
                                            .fill(
                                                configStore.hasSelectedApps
                                                    ? ArtNouveauTheme.successLight
                                                    : ArtNouveauTheme.warningLight
                                            )
                                            .frame(width: 56, height: 56)

                                        Image(systemName: configStore.hasSelectedApps ? "checkmark.circle.fill" : "app.badge")
                                            .foregroundColor(configStore.hasSelectedApps ? ArtNouveauTheme.success : ArtNouveauTheme.warning)
                                            .font(.system(size: 28, weight: .semibold))
                                            .symbolRenderingMode(.hierarchical)
                                    }

                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(configStore.hasSelectedApps ? "Apps Selected" : "No Apps Selected")
                                            .font(.system(.headline, design: .default).weight(.bold))
                                            .foregroundColor(ArtNouveauTheme.label)

                                        if configStore.hasSelectedApps && configStore.selectedApps.applicationTokens.isEmpty && configStore.selectedApps.categoryTokens.isEmpty {
                                            Text("Tap the button below to confirm your app selection.")
                                                .font(.system(.subheadline, design: .default))
                                                .foregroundColor(ArtNouveauTheme.warning)
                                        } else if configStore.hasSelectedApps {
                                            Text(selectionSummary)
                                                .font(.system(.subheadline, design: .default))
                                                .foregroundColor(ArtNouveauTheme.secondaryLabel)
                                        } else {
                                            Text("Select the apps you want to block when you tap your tag.")
                                                .font(.system(.subheadline, design: .default))
                                                .foregroundColor(ArtNouveauTheme.secondaryLabel)
                                        }
                                    }

                                    Spacer()
                                }

                                // Show warning if blocking is active
                                if configStore.isBlockingEnabled {
                                    HStack(spacing: 12) {
                                        Image(systemName: "lock.shield.fill")
                                            .font(.system(size: 20, weight: .semibold))
                                            .foregroundColor(ArtNouveauTheme.primary)
                                            .symbolRenderingMode(.hierarchical)

                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Blocking Active")
                                                .font(.system(.subheadline, design: .default).weight(.bold))
                                                .foregroundColor(ArtNouveauTheme.primary)

                                            Text("Tap your tag to stop blocking before modifying app selection.")
                                                .font(.system(.caption, design: .default))
                                                .foregroundColor(ArtNouveauTheme.secondaryLabel)
                                                .fixedSize(horizontal: false, vertical: true)
                                        }
                                    }
                                    .padding(14)
                                    .background(ArtNouveauTheme.primaryLight)
                                    .cornerRadius(14)
                                } else {
                                    Divider()
                                    
                                    // Action button - only enabled when blocking is inactive
                                    Button {
                                        showPicker = true
                                    } label: {
                                        HStack(spacing: 10) {
                                            Image(systemName: "square.grid.2x2")
                                            if configStore.hasSelectedApps && configStore.selectedApps.applicationTokens.isEmpty {
                                                Text("Confirm App Selection")
                                            } else if configStore.hasSelectedApps {
                                                Text("Edit App Selection")
                                            } else {
                                                Text("Select Apps to Block")
                                            }
                                        }
                                        .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(ArtNouveauButtonStyle(isProminent: true))

                                    if configStore.hasSelectedApps {
                                        Button {
                                            configStore.clearSelectedApps()
                                            screenTimeManager.disableBlocking()
                                        } label: {
                                            HStack(spacing: 10) {
                                                Image(systemName: "trash")
                                                Text("Clear Selection")
                                            }
                                            .frame(maxWidth: .infinity)
                                        }
                                        .buttonStyle(ArtNouveauButtonStyle(isProminent: false))
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    if screenTimeManager.authorizationStatus == .approved {
                        Text("Tap 'Done' in the app selector to confirm your selection.")
                            .font(.system(.caption, design: .default))
                            .foregroundColor(ArtNouveauTheme.secondaryLabel)
                            .padding(.horizontal, 24)
                    }
                }

                // Blocking Presets Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Blocking Presets")
                        .font(.system(.headline, design: .default).weight(.bold))
                        .foregroundColor(ArtNouveauTheme.label)
                        .padding(.horizontal, 24)

                    ArtNouveauCard(shadow: ArtNouveauTheme.shadowMedium) {
                        PresetListView()
                    }
                    .padding(.horizontal, 24)

                    Text("Each preset blocks its own apps independently. Schedules run in the background and override the tag.")
                        .font(.system(.caption, design: .default))
                        .foregroundColor(ArtNouveauTheme.secondaryLabel)
                        .padding(.horizontal, 24)
                }

                // Emergency Override Section
                if configStore.isBlockingEnabled {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Emergency Access")
                            .font(.system(.headline, design: .default).weight(.bold))
                            .foregroundColor(ArtNouveauTheme.label)
                            .padding(.horizontal, 24)
                        
                        ArtNouveauCard(shadow: ArtNouveauTheme.shadowMedium) {
                            VStack(spacing: 16) {
                                HStack(spacing: 16) {
                                    ZStack {
                                        Circle()
                                            .fill(ArtNouveauTheme.warningLight)
                                            .frame(width: 56, height: 56)
                                        
                                        Image(systemName: "keyboard")
                                            .foregroundColor(ArtNouveauTheme.warning)
                                            .font(.system(size: 28, weight: .semibold))
                                            .symbolRenderingMode(.hierarchical)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("Emergency Override")
                                            .font(.system(.headline, design: .default).weight(.bold))
                                            .foregroundColor(ArtNouveauTheme.warning)

                                        Text("Type a passage to disable blocking without your tag.")
                                            .font(.system(.subheadline, design: .default))
                                            .foregroundColor(ArtNouveauTheme.secondaryLabel)
                                    }
                                    
                                    Spacer()
                                }
                                
                                Divider()
                                
                                Button {
                                    showTypingChallenge = true
                                } label: {
                                    HStack(spacing: 10) {
                                        Image(systemName: "keyboard")
                                        Text("Start Typing Challenge")
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(ArtNouveauButtonStyle(isProminent: true, gradient: ArtNouveauTheme.goldGradient))
                            }
                        }
                        .padding(.horizontal, 24)
                        
                        Text("Use this only when you don't have access to your tag.")
                            .font(.system(.caption, design: .default))
                            .foregroundColor(ArtNouveauTheme.secondaryLabel)
                            .padding(.horizontal, 24)
                    }
                }
            }
            .padding(.vertical, 20)
        }
        .background(
            LinearGradient(
                colors: [
                    ArtNouveauTheme.background,
                    ArtNouveauTheme.secondaryBackground.opacity(0.3)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
        .familyActivityPicker(isPresented: $showPicker, selection: $configStore.selectedApps)
        .onChange(of: configStore.selectedApps) { newValue in
            // Immediately persist the selection (don't rely solely on debounce)
            configStore.saveSelectedApps(newValue)
            // Update blocking if currently enabled
            if configStore.isBlockingEnabled {
                screenTimeManager.updateBlocking(for: newValue)
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
