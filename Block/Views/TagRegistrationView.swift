//
//  TagRegistrationView.swift
//  Block
//
//  Created by Amit Sankaran on 1/7/26.
//

import SwiftUI

struct TagRegistrationView: View {
    @StateObject private var nfcManager = NFCManager.shared
    @StateObject private var configStore = AppConfigurationStore.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var isRegistering = false
    
    var body: some View {
        NavigationView {
            ZStack {
                ArtNouveauBackground()

                VStack(spacing: 40) {
                    if configStore.isTagRegistered {
                        VStack(spacing: 24) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 60, weight: .medium))
                                .foregroundColor(ArtNouveauTheme.success)
                                .symbolRenderingMode(.hierarchical)

                            VStack(spacing: 8) {
                                Text("Tag Registered")
                                    .font(.title2.bold())

                                Text("Your NFC tag is registered and ready to use.")
                                    .font(.subheadline)
                                    .foregroundColor(ArtNouveauTheme.secondaryLabel)
                                    .multilineTextAlignment(.center)
                            }

                            Button(role: .destructive) {
                                configStore.clearTagRegistration()
                            } label: {
                                Label("Unregister Tag", systemImage: "xmark.circle")
                            }
                            .buttonStyle(ArtNouveauButtonStyle(isProminent: false))
                        }
                        .padding(32)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(ArtNouveauTheme.secondaryBackground)
                        )
                        .padding(.horizontal, 32)
                    } else {
                        VStack(spacing: 32) {
                            Image(systemName: "sensor.tag.radiowaves.forward.fill")
                                .font(.system(size: 60, weight: .medium))
                                .foregroundColor(ArtNouveauTheme.primary)
                                .symbolRenderingMode(.hierarchical)

                            VStack(spacing: 12) {
                                Text("Register NFC Tag")
                                    .font(.title2.bold())

                                Text("Hold your iPhone near an NFC tag to register it. Once registered, scanning this tag will toggle app blocking.")
                                    .font(.subheadline)
                                    .foregroundColor(ArtNouveauTheme.secondaryLabel)
                                    .multilineTextAlignment(.center)
                            }

                            if nfcManager.isScanning {
                                VStack(spacing: 16) {
                                    ProgressView()
                                        .controlSize(.large)

                                    Text("Scanning for NFC tag...")
                                        .font(.subheadline)
                                        .foregroundColor(ArtNouveauTheme.secondaryLabel)

                                    Button("Cancel") {
                                        nfcManager.stopScanning()
                                    }
                                    .buttonStyle(ArtNouveauButtonStyle(isProminent: false))
                                }
                            } else {
                                Button {
                                    startRegistration()
                                } label: {
                                    Label("Start Scanning", systemImage: "sensor.tag.radiowaves.forward")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(ArtNouveauButtonStyle(isProminent: true))
                            }

                            if let error = nfcManager.errorMessage {
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(ArtNouveauTheme.error)
                                    .multilineTextAlignment(.center)
                                    .padding(.top, 8)
                            }
                        }
                        .padding(32)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(ArtNouveauTheme.secondaryBackground)
                        )
                        .padding(.horizontal, 32)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("NFC Tag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            setupTagScanHandler()
        }
        .onDisappear {
            nfcManager.stopScanning()
        }
    }
    
    private func setupTagScanHandler() {
        nfcManager.onTagScanned = { identifier in
            if !configStore.isTagRegistered && !isRegistering {
                isRegistering = true
                configStore.registerTag(identifier: identifier)
                isRegistering = false
            }
        }
    }
    
    private func startRegistration() {
        nfcManager.startScanning()
    }
}

#Preview {
    TagRegistrationView()
}
