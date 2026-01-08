//
//  ContentView.swift
//  Block
//
//  Created by Amit Sankaran on 1/7/26.
//

import SwiftUI
import FamilyControls

struct ContentView: View {
    @EnvironmentObject private var configStore: AppConfigurationStore
    @EnvironmentObject private var screenTimeManager: ScreenTimeManager
    @EnvironmentObject private var nfcManager: NFCManager
    @State private var showSettings = false
    @State private var showTagRegistration = false

    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                // Status Section
                BlockingStatusSection(isBlockingEnabled: configStore.isBlockingEnabled)
                    .padding(.top, 40)

                // Setup Status
                SetupStatusSection(
                    authorizationStatus: screenTimeManager.authorizationStatus,
                    hasSelectedApps: configStore.hasSelectedApps,
                    selectedAppsCount: configStore.selectedApps.count,
                    isTagRegistered: configStore.isTagRegistered
                )
                .padding(.horizontal)

                Spacer()

                // Action Buttons
                ActionButtonsSection(
                    showSettings: $showSettings,
                    showTagRegistration: $showTagRegistration
                )
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
                Task {
                    await screenTimeManager.checkAuthorizationStatus()
                }
            }
        }
    }
}

// MARK: - Subviews to minimize re-renders

struct BlockingStatusSection: View {
    let isBlockingEnabled: Bool

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: isBlockingEnabled ? "lock.shield.fill" : "lock.shield")
                .font(.system(size: 80))
                .foregroundColor(isBlockingEnabled ? .red : .gray)

            Text(isBlockingEnabled ? "Blocking Active" : "Blocking Inactive")
                .font(.title)
                .fontWeight(.bold)

            Text(isBlockingEnabled ? "Selected apps are blocked" : "Scan your NFC tag to enable blocking")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}

struct SetupStatusSection: View {
    let authorizationStatus: AuthorizationStatus
    let hasSelectedApps: Bool
    let selectedAppsCount: Int
    let isTagRegistered: Bool

    var body: some View {
        VStack(spacing: 12) {
            StatusRow(
                icon: authorizationStatus == .approved ? "checkmark.circle.fill" : "xmark.circle.fill",
                title: "Screen Time",
                status: authorizationStatus == .approved ? "Authorized" : "Not Authorized",
                isComplete: authorizationStatus == .approved
            )

            StatusRow(
                icon: hasSelectedApps ? "checkmark.circle.fill" : "xmark.circle.fill",
                title: "Apps Selected",
                status: hasSelectedApps ? "\(selectedAppsCount) apps" : "No apps selected",
                isComplete: hasSelectedApps
            )

            StatusRow(
                icon: isTagRegistered ? "checkmark.circle.fill" : "xmark.circle.fill",
                title: "NFC Tag",
                status: isTagRegistered ? "Registered" : "Not Registered",
                isComplete: isTagRegistered
            )
        }
    }
}

struct ActionButtonsSection: View {
    @Binding var showSettings: Bool
    @Binding var showTagRegistration: Bool

    var body: some View {
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
        .environmentObject(AppConfigurationStore.shared)
        .environmentObject(ScreenTimeManager.shared)
        .environmentObject(NFCManager.shared)
}
