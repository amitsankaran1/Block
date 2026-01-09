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
                // Art Nouveau background
                ArtNouveauBackground()
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Status at top with decorative elements
                    VStack(spacing: 16) {
                        ZStack {
                            // Decorative ornament behind icon
                            ArtNouveauOrnament(size: 120)
                                .opacity(0.15)
                            
                            Image(systemName: configStore.isBlockingEnabled ? "lock.shield.fill" : "lock.shield")
                                .font(.system(size: 64, weight: .medium))
                                .foregroundStyle(
                                    configStore.isBlockingEnabled 
                                    ? ArtNouveauTheme.primaryGradient
                                    : LinearGradient(colors: [ArtNouveauTheme.oliveGreen.opacity(0.6), ArtNouveauTheme.tealGreen.opacity(0.4)], startPoint: .top, endPoint: .bottom)
                                )
                                .shadow(color: ArtNouveauTheme.forestGreen.opacity(0.25), radius: 10, x: 0, y: 5)
                        }
                        .frame(height: 100)

                        VStack(spacing: 8) {
                            Text(configStore.isBlockingEnabled ? "Blocking Active" : "Blocking Inactive")
                                .font(ArtNouveauTheme.titleFont)
                                .foregroundColor(ArtNouveauTheme.forestGreen)

                            if configStore.hasSelectedApps {
                                Text("\(configStore.selectedApps.count) apps blocked")
                                    .font(ArtNouveauTheme.bodyFont)
                                    .foregroundColor(ArtNouveauTheme.oliveGreen.opacity(0.75))
                            }
                        }
                    }
                    .padding(.top, 60)
                    .padding(.horizontal, 32)

                    Spacer()

                    // Main scan button - centerpiece with Art Nouveau styling
                    if configStore.isTagRegistered && configStore.hasSelectedApps {
                        if nfcManager.isScanning {
                            ArtNouveauCard {
                                VStack(spacing: 24) {
                                    ProgressView()
                                        .tint(ArtNouveauTheme.forestGreen)
                                        .scaleEffect(2.0)

                                    VStack(spacing: 8) {
                                        Text("Hold iPhone near NFC tag")
                                            .font(ArtNouveauTheme.headlineFont)
                                            .foregroundColor(ArtNouveauTheme.forestGreen)

                                        Text("Ready to scan")
                                            .font(ArtNouveauTheme.bodyFont)
                                            .foregroundColor(ArtNouveauTheme.oliveGreen.opacity(0.75))
                                    }

                                    Button("Cancel") {
                                        nfcManager.stopScanning()
                                    }
                                    .buttonStyle(ArtNouveauButtonStyle(isProminent: false))
                                    .padding(.top, 8)
                                }
                            }
                            .padding(.horizontal, 40)
                        } else {
                            Button {
                                nfcManager.startScanning()
                            } label: {
                                VStack(spacing: 20) {
                                    ZStack {
                                        ArtNouveauOrnament(size: 100)
                                            .opacity(0.2)
                                        
                                        Image(systemName: "sensor.tag.radiowaves.forward.fill")
                                            .font(.system(size: 56, weight: .medium))
                                            .foregroundColor(.white)
                                    }
                                    
                                    Text("Tap to Scan")
                                        .font(ArtNouveauTheme.titleFont)
                                        .foregroundColor(.white)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 50)
                            }
                            .buttonStyle(ArtNouveauButtonStyle(isProminent: true))
                            .padding(.horizontal, 40)
                        }
                    } else {
                        // Setup required with Art Nouveau styling
                        ArtNouveauCard {
                            VStack(spacing: 24) {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.system(size: 56, weight: .medium))
                                    .foregroundStyle(ArtNouveauTheme.goldGradient)

                                VStack(spacing: 12) {
                                    Text("Setup Required")
                                        .font(ArtNouveauTheme.titleFont)
                                        .foregroundColor(ArtNouveauTheme.forestGreen)

                                    Text("Configure your settings to get started")
                                        .font(ArtNouveauTheme.bodyFont)
                                        .foregroundColor(ArtNouveauTheme.oliveGreen.opacity(0.75))
                                        .multilineTextAlignment(.center)
                                }

                                Button {
                                    showSettings = true
                                } label: {
                                    Label("Open Settings", systemImage: "gear")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(ArtNouveauButtonStyle(isProminent: true))
                                .padding(.top, 8)
                            }
                        }
                        .padding(.horizontal, 40)
                    }

                    Spacer()
                }
            }
            .navigationTitle("Block")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "gear")
                            Text("Settings")
                        }
                        .foregroundColor(ArtNouveauTheme.forestGreen)
                        .font(ArtNouveauTheme.bodyFont)
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

#Preview {
    ContentView()
}
