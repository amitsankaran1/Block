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
            VStack(spacing: 24) {
                if configStore.isTagRegistered {
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.green)
                        
                        Text("Tag Registered")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Your NFC tag is registered and ready to use.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button(role: .destructive) {
                            configStore.clearTagRegistration()
                        } label: {
                            Text("Unregister Tag")
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                } else {
                    VStack(spacing: 24) {
                        Image(systemName: "sensor.tag.radiowaves.forward.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        
                        Text("Register NFC Tag")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Hold your iPhone near an NFC tag to register it. Once registered, scanning this tag will toggle app blocking.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        if nfcManager.isScanning {
                            ProgressView()
                                .scaleEffect(1.5)
                                .padding()
                            
                            Text("Scanning for NFC tag...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Button("Cancel") {
                                nfcManager.stopScanning()
                            }
                            .buttonStyle(.bordered)
                        } else {
                            Button {
                                startRegistration()
                            } label: {
                                Label("Start Scanning", systemImage: "sensor.tag.radiowaves.forward")
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                        }
                        
                        if let error = nfcManager.errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding(.horizontal)
                        }
                    }
                    .padding()
                }
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
