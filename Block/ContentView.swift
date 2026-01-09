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
            VStack(spacing: 0) {
                // Status at top
                VStack(spacing: 12) {
                    Image(systemName: configStore.isBlockingEnabled ? "lock.shield.fill" : "lock.shield")
                        .font(.system(size: 60))
                        .foregroundColor(configStore.isBlockingEnabled ? .red : .gray)

                    Text(configStore.isBlockingEnabled ? "Blocking Active" : "Blocking Inactive")
                        .font(.title2)
                        .fontWeight(.semibold)

                    if configStore.hasSelectedApps {
                        Text("\(configStore.selectedApps.count) apps blocked")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 60)

                Spacer()

                // Main scan button - centerpiece
                if configStore.isTagRegistered && configStore.hasSelectedApps {
                    if nfcManager.isScanning {
                        VStack(spacing: 20) {
                            ProgressView()
                                .scaleEffect(2.0)

                            Text("Hold iPhone near NFC tag")
                                .font(.headline)
                                .foregroundColor(.primary)

                            Text("Ready to scan")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            Button("Cancel") {
                                nfcManager.stopScanning()
                            }
                            .buttonStyle(BorderedButtonStyle())
                            .controlSize(.large)
                            .padding(.top, 20)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(40)
                    } else {
                        Button {
                            nfcManager.startScanning()
                        } label: {
                            VStack(spacing: 16) {
                                Image(systemName: "sensor.tag.radiowaves.forward.fill")
                                    .font(.system(size: 50))
                                Text("Tap to Scan")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 50)
                        }
                        .buttonStyle(BorderedProminentButtonStyle())
                        .controlSize(.large)
                        .padding(.horizontal, 40)
                    }
                } else {
                    // Setup required
                    VStack(spacing: 20) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 50))
                            .foregroundColor(.orange)

                        Text("Setup Required")
                            .font(.title2)
                            .fontWeight(.semibold)

                        Text("Configure your settings to get started")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)

                        Button {
                            showSettings = true
                        } label: {
                            Label("Open Settings", systemImage: "gear")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(BorderedProminentButtonStyle())
                        .controlSize(.large)
                        .padding(.top, 20)
                    }
                    .padding(.horizontal, 40)
                }

                Spacer()
            }
            .navigationTitle("Block")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gear")
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
