//
//  SettingsView.swift
//  Block
//
//  Created by Amit Sankaran on 1/7/26.
//

import SwiftUI
import FamilyControls

struct SettingsView: View {
    @EnvironmentObject private var configStore: AppConfigurationStore
    @EnvironmentObject private var screenTimeManager: ScreenTimeManager
    @State private var showPicker = false
    @State private var selectedTokenSet = FamilyActivitySelection()
    @State private var authTask: Task<Void, Never>?
    @State private var updateTask: Task<Void, Never>?

    var body: some View {
        NavigationView {
            Form {
                Section {
                    if screenTimeManager.authorizationStatus != .approved {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Screen Time authorization required")
                                .font(.headline)
                            Text("Please grant Screen Time permission in Settings to use app blocking features.")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Button("Request Authorization") {
                                authTask = Task {
                                    do {
                                        try await screenTimeManager.requestAuthorization()
                                    } catch {
                                        print("Authorization error: \(error)")
                                    }
                                }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding(.vertical, 8)
                    } else {
                        Button {
                            showPicker = true
                        } label: {
                            HStack {
                                Text("Select Apps to Block")
                                Spacer()
                                if !configStore.selectedApps.isEmpty {
                                    Text("\(configStore.selectedApps.count) selected")
                                        .foregroundColor(.secondary)
                                }
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                        }

                        if !configStore.selectedApps.isEmpty {
                            Button(role: .destructive) {
                                Task {
                                    await configStore.selectedApps.removeAll()
                                    await screenTimeManager.disableBlocking()
                                }
                            } label: {
                                Text("Clear Selection")
                            }
                        }
                    }
                } header: {
                    Text("App Selection")
                } footer: {
                    if screenTimeManager.authorizationStatus == .approved {
                        Text("Select the apps you want to block when the NFC tag is scanned.")
                    }
                }
            }
            .navigationTitle("Settings")
            .familyActivityPicker(isPresented: $showPicker, selection: $selectedTokenSet)
            .onChange(of: selectedTokenSet) { newValue in
                // Update selected apps immediately
                Task {
                    await configStore.selectedApps = Set(newValue.applicationTokens)
                }

                // Debounce blocking updates to avoid excessive API calls
                updateTask?.cancel()
                updateTask = Task {
                    try? await Task.sleep(nanoseconds: 500_000_000) // 500ms debounce

                    guard !Task.isCancelled else { return }

                    if await configStore.isBlockingEnabled {
                        await screenTimeManager.updateBlocking(for: configStore.selectedApps)
                    }
                }
            }
            .onDisappear {
                // Cancel any pending tasks when view disappears
                authTask?.cancel()
                updateTask?.cancel()
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppConfigurationStore.shared)
        .environmentObject(ScreenTimeManager.shared)
}
