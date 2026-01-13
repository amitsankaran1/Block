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
                LinearGradient(
                    colors: [
                        ArtNouveauTheme.background,
                        ArtNouveauTheme.secondaryBackground.opacity(0.3)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 32) {
                        if configStore.isTagRegistered {
                            ArtNouveauCard(shadow: ArtNouveauTheme.shadowLarge) {
                                VStack(spacing: 28) {
                                    ZStack {
                                        Circle()
                                            .fill(ArtNouveauTheme.successLight)
                                            .frame(width: 100, height: 100)
                                        
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 60, weight: .bold))
                                            .foregroundColor(ArtNouveauTheme.success)
                                            .symbolRenderingMode(.hierarchical)
                                    }
                                    .shadow(color: ArtNouveauTheme.success.opacity(0.3), radius: 12, x: 0, y: 6)

                                    VStack(spacing: 12) {
                                        Text("Tag Connected")
                                            .font(.system(.title, design: .default).weight(.bold))
                                            .foregroundColor(ArtNouveauTheme.label)

                                        Text("Your tag is connected and ready to use. Tap it to start or stop blocking.")
                                            .font(.system(.subheadline, design: .default).weight(.medium))
                                            .foregroundColor(ArtNouveauTheme.secondaryLabel)
                                            .multilineTextAlignment(.center)
                                    }

                                    Divider()

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
                                }
                                .padding(.vertical, 8)
                            }
                            .padding(.horizontal, 24)
                            .padding(.top, 40)
                        } else {
                            ArtNouveauCard(shadow: ArtNouveauTheme.shadowLarge) {
                                VStack(spacing: 28) {
                                    ZStack {
                                        Circle()
                                            .fill(ArtNouveauTheme.primaryLight)
                                            .frame(width: 100, height: 100)
                                        
                                        Image(systemName: "sensor.tag.radiowaves.forward.fill")
                                            .font(.system(size: 60, weight: .bold))
                                            .foregroundColor(ArtNouveauTheme.primary)
                                            .symbolRenderingMode(.hierarchical)
                                    }
                                    .shadow(color: ArtNouveauTheme.primary.opacity(0.3), radius: 12, x: 0, y: 6)

                                    VStack(spacing: 12) {
                                        Text("Connect Your Tag")
                                            .font(.system(.title, design: .default).weight(.bold))
                                            .foregroundColor(ArtNouveauTheme.label)

                                        Text("Hold your iPhone near your tag to connect it. Once connected, tapping this tag will start or stop blocking.")
                                            .font(.system(.subheadline, design: .default).weight(.medium))
                                            .foregroundColor(ArtNouveauTheme.secondaryLabel)
                                            .multilineTextAlignment(.center)
                                    }

                                    Divider()

                                    if nfcManager.isScanning {
                                        VStack(spacing: 20) {
                                            ZStack {
                                                Circle()
                                                    .fill(ArtNouveauTheme.primaryLight)
                                                    .frame(width: 80, height: 80)
                                                
                                                ProgressView()
                                                    .controlSize(.large)
                                                    .tint(ArtNouveauTheme.primary)
                                                    .scaleEffect(1.2)
                                            }

                                            Text("Looking for your tag...")
                                                .font(.system(.subheadline, design: .default).weight(.semibold))
                                                .foregroundColor(ArtNouveauTheme.label)

                                            Button("Cancel") {
                                                nfcManager.stopScanning()
                                            }
                                            .buttonStyle(ArtNouveauButtonStyle(isProminent: false))
                                        }
                                    } else {
                                        Button {
                                            startRegistration()
                                        } label: {
                                            HStack(spacing: 10) {
                                                Image(systemName: "sensor.tag.radiowaves.forward")
                                                Text("Connect Tag")
                                            }
                                            .frame(maxWidth: .infinity)
                                        }
                                        .buttonStyle(ArtNouveauButtonStyle(isProminent: true))
                                    }

                                    if let error = nfcManager.errorMessage {
                                        HStack(spacing: 8) {
                                            Image(systemName: "exclamationmark.circle.fill")
                                                .foregroundColor(ArtNouveauTheme.error)
                                                .font(.system(size: 14, weight: .semibold))
                                            Text(error)
                                                .font(.system(.caption, design: .default).weight(.medium))
                                                .foregroundColor(ArtNouveauTheme.error)
                                        }
                                        .padding(12)
                                        .frame(maxWidth: .infinity)
                                        .background(ArtNouveauTheme.errorLight)
                                        .cornerRadius(12)
                                        .padding(.top, 8)
                                    }
                                }
                                .padding(.vertical, 8)
                            }
                            .padding(.horizontal, 24)
                            .padding(.top, 40)
                        }
                    }
                    .padding(.vertical, 32)
                }
            }
            .navigationTitle("Connect Tag")
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
