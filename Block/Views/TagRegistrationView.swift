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
                    .ignoresSafeArea()
                
                VStack(spacing: 32) {
                    if configStore.isTagRegistered {
                        ArtNouveauCard {
                            VStack(spacing: 24) {
                                ZStack {
                                    ArtNouveauOrnament(size: 120)
                                        .opacity(0.15)
                                    
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 64, weight: .medium))
                                        .foregroundStyle(ArtNouveauTheme.primaryGradient)
                                        .shadow(color: ArtNouveauTheme.forestGreen.opacity(0.25), radius: 10, x: 0, y: 5)
                                }
                                .frame(height: 100)
                                
                                VStack(spacing: 12) {
                                    Text("Tag Registered")
                                        .font(ArtNouveauTheme.titleFont)
                                        .foregroundColor(ArtNouveauTheme.forestGreen)
                                    
                                    Text("Your NFC tag is registered and ready to use.")
                                        .font(ArtNouveauTheme.bodyFont)
                                        .foregroundColor(ArtNouveauTheme.oliveGreen.opacity(0.75))
                                        .multilineTextAlignment(.center)
                                }
                                
                                Button(role: .destructive) {
                                    configStore.clearTagRegistration()
                                } label: {
                                    Text("Unregister Tag")
                                }
                                .buttonStyle(ArtNouveauButtonStyle(isProminent: false))
                            }
                        }
                        .padding(.horizontal, 32)
                    } else {
                        ArtNouveauCard {
                            VStack(spacing: 32) {
                                ZStack {
                                    ArtNouveauOrnament(size: 120)
                                        .opacity(0.15)
                                    
                                    Image(systemName: "sensor.tag.radiowaves.forward.fill")
                                        .font(.system(size: 64, weight: .medium))
                                        .foregroundStyle(ArtNouveauTheme.primaryGradient)
                                        .shadow(color: ArtNouveauTheme.forestGreen.opacity(0.25), radius: 10, x: 0, y: 5)
                                }
                                .frame(height: 100)
                                
                                VStack(spacing: 16) {
                                    Text("Register NFC Tag")
                                        .font(ArtNouveauTheme.titleFont)
                                        .foregroundColor(ArtNouveauTheme.forestGreen)
                                    
                                    Text("Hold your iPhone near an NFC tag to register it. Once registered, scanning this tag will toggle app blocking.")
                                        .font(ArtNouveauTheme.bodyFont)
                                        .foregroundColor(ArtNouveauTheme.oliveGreen.opacity(0.75))
                                        .multilineTextAlignment(.center)
                                }
                                
                                if nfcManager.isScanning {
                                    VStack(spacing: 20) {
                                        ProgressView()
                                            .tint(ArtNouveauTheme.forestGreen)
                                            .scaleEffect(1.5)
                                        
                                        Text("Scanning for NFC tag...")
                                            .font(ArtNouveauTheme.bodyFont)
                                            .foregroundColor(ArtNouveauTheme.oliveGreen.opacity(0.75))
                                        
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
                                        .font(ArtNouveauTheme.bodyFont)
                                        .foregroundColor(ArtNouveauTheme.accentRose)
                                        .multilineTextAlignment(.center)
                                        .padding(.top, 8)
                                }
                            }
                        }
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
                    .foregroundColor(ArtNouveauTheme.forestGreen)
                    .font(ArtNouveauTheme.bodyFont)
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
