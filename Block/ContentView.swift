//
//  ContentView.swift
//  Block
//
//  Created by Amit Sankaran on 1/7/26.
//

import SwiftUI
import FamilyControls

struct ContentView: View {
    @StateObject private var configStore = AppConfigurationStore.shared
    @StateObject private var screenTimeManager = ScreenTimeManager.shared
    @StateObject private var nfcManager = NFCManager.shared
    @State private var showSettings = false

    var body: some View {
        NavigationView {
            ZStack {
                // Clean background
                ArtNouveauTheme.background
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Status section - perfectly centered
                    VStack(spacing: 20) {
                        // Icon with status indicator - centered
                        ZStack(alignment: .center) {
                            // Main circle - centered
                            Circle()
                                .fill(ArtNouveauTheme.tertiaryBackground)
                                .frame(width: 80, height: 80)
                                .overlay(
                                    Circle()
                                        .stroke(ArtNouveauTheme.border, lineWidth: 1)
                                )

                            // Lock icon - perfectly centered
                            Image(systemName: configStore.isBlockingEnabled ? "lock.shield.fill" : "lock.open.fill")
                                .font(.system(size: 34, weight: .medium))
                                .foregroundColor(configStore.isBlockingEnabled ? ArtNouveauTheme.error : ArtNouveauTheme.success)
                                .symbolRenderingMode(.hierarchical)
                        }
                        .overlay(alignment: .topTrailing) {
                            // Status dot - positioned outside the main circle
                            Circle()
                                .fill(configStore.isBlockingEnabled ? ArtNouveauTheme.error : ArtNouveauTheme.success)
                                .frame(width: 16, height: 16)
                                .overlay(
                                    Circle()
                                        .stroke(ArtNouveauTheme.background, lineWidth: 2)
                                )
                                .offset(x: 4, y: -4)
                        }
                        .frame(width: 80, height: 80)

                        // Text section - centered
                        VStack(spacing: 8) {
                            Text(configStore.isBlockingEnabled ? "Blocking Active" : "Blocking Inactive")
                                .font(ArtNouveauTheme.titleFont)
                                .foregroundColor(ArtNouveauTheme.label)

                            if configStore.hasSelectedApps {
                                Text("\(configStore.selectedApps.count) app\(configStore.selectedApps.count == 1 ? "" : "s") selected")
                                    .font(ArtNouveauTheme.bodyFont)
                                    .foregroundColor(ArtNouveauTheme.secondaryLabel)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 48)
                    .padding(.bottom, 32)
                    .padding(.horizontal, 24)

                    Spacer(minLength: 0)

                    // Main action area - centered
                    VStack {
                        if configStore.isTagRegistered && configStore.hasSelectedApps {
                            if nfcManager.isScanning {
                                VStack(spacing: 24) {
                                    ProgressView()
                                        .controlSize(.large)
                                        .tint(ArtNouveauTheme.primary)

                                    VStack(spacing: 8) {
                                        Text("Hold iPhone near NFC tag")
                                            .font(.headline)
                                            .foregroundColor(ArtNouveauTheme.label)

                                        Text("Ready to scan")
                                            .font(.subheadline)
                                            .foregroundColor(ArtNouveauTheme.secondaryLabel)
                                    }

                                    Button("Cancel") {
                                        nfcManager.stopScanning()
                                    }
                                    .buttonStyle(ArtNouveauButtonStyle(isProminent: false))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(32)
                                .background(
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(ArtNouveauTheme.secondaryBackground)
                                )
                                .padding(.horizontal, 32)
                            } else {
                                // Scan button
                                Button {
                                    nfcManager.startScanning()
                                } label: {
                                    ArtNouveauCard {
                                        VStack(spacing: 20) {
                                            // Icon in colored circle
                                            Circle()
                                                .fill(ArtNouveauTheme.primary)
                                                .frame(width: 70, height: 70)
                                                .overlay(
                                                    Image(systemName: "sensor.tag.radiowaves.forward.fill")
                                                        .font(.system(size: 32, weight: .medium))
                                                        .foregroundColor(.white)
                                                )

                                            VStack(spacing: 8) {
                                                Text("Scan NFC Tag")
                                                    .font(ArtNouveauTheme.titleFont)
                                                    .foregroundColor(ArtNouveauTheme.label)

                                                Text(configStore.isBlockingEnabled ? "Tap to disable blocking" : "Tap to enable blocking")
                                                    .font(ArtNouveauTheme.bodyFont)
                                                    .foregroundColor(ArtNouveauTheme.secondaryLabel)
                                            }
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                    }
                                }
                                .buttonStyle(ScaleButtonStyle())
                                .padding(.horizontal, 24)
                            }
                        } else {
                            // Setup required card
                            ArtNouveauCard {
                                VStack(spacing: 20) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.system(size: 40, weight: .medium))
                                        .foregroundColor(ArtNouveauTheme.warning)
                                        .symbolRenderingMode(.hierarchical)

                                    VStack(spacing: 8) {
                                        Text("Setup Required")
                                            .font(ArtNouveauTheme.titleFont)
                                            .foregroundColor(ArtNouveauTheme.label)

                                        Text("Configure your settings to get started")
                                            .font(ArtNouveauTheme.bodyFont)
                                            .foregroundColor(ArtNouveauTheme.secondaryLabel)
                                    }

                                    Button {
                                        showSettings = true
                                    } label: {
                                        HStack(spacing: 8) {
                                            Image(systemName: "gear")
                                            Text("Open Settings")
                                        }
                                        .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(ArtNouveauButtonStyle(isProminent: true))
                                    .padding(.top, 8)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .padding(.horizontal, 24)
                        }
                    }
                    .frame(maxWidth: .infinity)

                    Spacer(minLength: 0)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gear")
                            .foregroundColor(ArtNouveauTheme.primary)
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                NavigationView {
                    SettingsView()
                }
            }
            .onAppear {
                screenTimeManager.checkAuthorizationStatus()
                setupNFCHandler()
            }
        }
    }

    private func setupNFCHandler() {
        // Set up handler to register or toggle based on state
        nfcManager.onTagScanned = { [weak configStore, weak screenTimeManager] tagId in
            guard let configStore = configStore,
                  let screenTimeManager = screenTimeManager else { return }

            if let registeredTag = configStore.registeredTagIdentifier {
                // Tag already registered - toggle blocking
                if tagId == registeredTag {
                    print("✅ Matched registered tag - toggling blocking")
                    screenTimeManager.toggleBlocking(for: configStore.selectedApps)
                } else {
                    print("❌ Scanned tag doesn't match registered tag")
                    print("   Scanned: \(tagId)")
                    print("   Registered: \(registeredTag)")
                }
            } else {
                // No tag registered - register this tag
                print("📝 No tag registered - registering tag: \(tagId)")
                configStore.registerTag(identifier: tagId)
            }
        }
    }
}

// Button style that scales down on press to feel more tactile
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

#Preview {
    ContentView()
}
