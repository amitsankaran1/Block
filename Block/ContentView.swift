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
    @State private var showSettings = false
    @State private var showTagRegistration = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                // Status Section
                VStack(spacing: 16) {
                    Image(systemName: configStore.isBlockingEnabled ? "lock.shield.fill" : "lock.shield")
                        .font(.system(size: 80))
                        .foregroundColor(configStore.isBlockingEnabled ? .red : .gray)
                    
                    Text(configStore.isBlockingEnabled ? "Blocking Active" : "Blocking Inactive")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text(configStore.isBlockingEnabled ? "Selected apps are blocked" : "Scan your NFC tag to enable blocking")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)
                
                // Setup Status
                VStack(spacing: 12) {
                    StatusRow(
                        icon: screenTimeManager.authorizationStatus == .approved ? "checkmark.circle.fill" : "xmark.circle.fill",
                        title: "Screen Time",
                        status: screenTimeManager.authorizationStatus == .approved ? "Authorized" : "Not Authorized",
                        isComplete: screenTimeManager.authorizationStatus == .approved
                    )
                    
                    StatusRow(
                        icon: configStore.hasSelectedApps ? "checkmark.circle.fill" : "xmark.circle.fill",
                        title: "Apps Selected",
                        status: configStore.hasSelectedApps ? "\(configStore.selectedApps.count) apps" : "No apps selected",
                        isComplete: configStore.hasSelectedApps
                    )
                    
                    StatusRow(
                        icon: configStore.isTagRegistered ? "checkmark.circle.fill" : "xmark.circle.fill",
                        title: "NFC Tag",
                        status: configStore.isTagRegistered ? "Registered" : "Not Registered",
                        isComplete: configStore.isTagRegistered
                    )
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Action Buttons
                VStack(spacing: 12) {
                    Button {
                        showSettings = true
                    } label: {
                        Label("Settings", systemImage: "gear")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    
                    Button {
                        showTagRegistration = true
                    } label: {
                        Label("Manage NFC Tag", systemImage: "sensor.tag.radiowaves.forward")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .navigationTitle("Tyri")
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showTagRegistration) {
                TagRegistrationView()
            }
            .onAppear {
                screenTimeManager.checkAuthorizationStatus()
            }
        }
    }
}

struct StatusRow: View {
    let icon: String
    let title: String
    let status: String
    let isComplete: Bool
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(isComplete ? .green : .red)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(status)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

#Preview {
    ContentView()
}
