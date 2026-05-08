//
//  ContentView.swift
//  Block
//
//  Created by Amit Sankaran on 1/7/26.
//

import SwiftUI
import UIKit
import FamilyControls

struct ContentView: View {
    @StateObject private var configStore = AppConfigurationStore.shared
    @StateObject private var screenTimeManager = ScreenTimeManager.shared
    @StateObject private var nfcManager = NFCManager.shared
    @StateObject private var schedulingManager = SchedulingManager.shared
    @StateObject private var presetStore = PresetStore.shared
    @State private var showSettings = false

    private var anyShieldActive: Bool {
        configStore.isBlockingEnabled || !schedulingManager.activeScheduledPresetIDs.isEmpty
    }

    private var activeScheduledPresets: [BlockingPreset] {
        let ids = schedulingManager.activeScheduledPresetIDs
        return presetStore.presets.filter { ids.contains($0.id) }
    }

    var body: some View {
        NavigationView {
            ZStack {
                // Modern gradient background with depth
                LinearGradient(
                    colors: [
                        ArtNouveauTheme.background,
                        ArtNouveauTheme.secondaryBackground.opacity(0.3)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Status section - prominent and modern
                    VStack(spacing: 24) {
                        // Large status indicator with gradient and glow
                        ZStack {
                            // Glow effect
                            Circle()
                                .fill(
                                    anyShieldActive
                                        ? ArtNouveauTheme.errorGradient
                                        : ArtNouveauTheme.successGradient
                                )
                                .frame(width: 140, height: 140)
                                .blur(radius: 20)
                                .opacity(0.4)

                            // Main status circle with gradient
                            Circle()
                                .fill(
                                    anyShieldActive
                                        ? ArtNouveauTheme.errorGradient
                                        : ArtNouveauTheme.successGradient
                                )
                                .frame(width: 120, height: 120)
                                .shadow(
                                    color: (anyShieldActive ? ArtNouveauTheme.error : ArtNouveauTheme.success).opacity(0.4),
                                    radius: 16,
                                    x: 0,
                                    y: 8
                                )

                            // Inner circle for depth
                            Circle()
                                .fill(
                                    anyShieldActive
                                        ? ArtNouveauTheme.errorLight
                                        : ArtNouveauTheme.successLight
                                )
                                .frame(width: 100, height: 100)

                            // Lock icon - large and prominent
                            Image(systemName: anyShieldActive ? "lock.shield.fill" : "lock.open.fill")
                                .font(.system(size: 48, weight: .bold))
                                .foregroundColor(.white)
                                .symbolRenderingMode(.hierarchical)
                                .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                        }
                        .scaleEffect(anyShieldActive ? 1.0 : 0.95)
                        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: anyShieldActive)

                        // Status badge with background
                        VStack(spacing: 12) {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(anyShieldActive ? ArtNouveauTheme.error : ArtNouveauTheme.success)
                                    .frame(width: 10, height: 10)
                                    .shadow(color: (anyShieldActive ? ArtNouveauTheme.error : ArtNouveauTheme.success).opacity(0.6), radius: 4, x: 0, y: 2)

                                Text(anyShieldActive ? "BLOCKING ACTIVE" : "BLOCKING INACTIVE")
                                    .font(.system(.subheadline, design: .default).weight(.bold))
                                    .foregroundColor(anyShieldActive ? ArtNouveauTheme.error : ArtNouveauTheme.success)
                                    .tracking(1.2)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .fill(
                                        (anyShieldActive ? ArtNouveauTheme.errorLight : ArtNouveauTheme.successLight)
                                    )
                            )

                            if configStore.hasSelectedApps {
                                Text("\(configStore.selectedApps.applicationTokens.count) app\(configStore.selectedApps.applicationTokens.count == 1 ? "" : "s") selected")
                                    .font(.system(.body, design: .default).weight(.medium))
                                    .foregroundColor(ArtNouveauTheme.secondaryLabel)
                            }

                            if !activeScheduledPresets.isEmpty {
                                VStack(spacing: 6) {
                                    Text("Scheduled blocks")
                                        .font(.system(.caption2, design: .default).weight(.bold))
                                        .tracking(1.0)
                                        .textCase(.uppercase)
                                        .foregroundColor(ArtNouveauTheme.secondaryLabel)
                                    HStack(spacing: 6) {
                                        ForEach(activeScheduledPresets) { preset in
                                            HStack(spacing: 4) {
                                                Circle()
                                                    .fill(ArtNouveauTheme.error)
                                                    .frame(width: 6, height: 6)
                                                Text(preset.name)
                                                    .font(.system(.caption, design: .default).weight(.semibold))
                                                    .foregroundColor(ArtNouveauTheme.error)
                                            }
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 5)
                                            .background(Capsule().fill(ArtNouveauTheme.errorLight))
                                        }
                                    }
                                }
                                .padding(.top, 4)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                    .padding(.bottom, 40)
                    .padding(.horizontal, 24)

                    Spacer(minLength: 0)

                    // Main action area - centered
                    VStack {
                        if configStore.isTagRegistered && configStore.hasSelectedApps {
                            if nfcManager.isScanning {
                                ArtNouveauCard(shadow: ArtNouveauTheme.shadowLarge) {
                                    VStack(spacing: 28) {
                                        ZStack {
                                            Circle()
                                                .fill(ArtNouveauTheme.primaryLight)
                                                .frame(width: 100, height: 100)
                                            
                                            ProgressView()
                                                .controlSize(.large)
                                                .tint(ArtNouveauTheme.primary)
                                                .scaleEffect(1.2)
                                        }

                                        VStack(spacing: 10) {
                                            Text("Hold iPhone near your tag")
                                                .font(.system(.headline, design: .default).weight(.bold))
                                                .foregroundColor(ArtNouveauTheme.label)

                                            Text("Ready to connect")
                                                .font(.system(.subheadline, design: .default).weight(.medium))
                                                .foregroundColor(ArtNouveauTheme.secondaryLabel)
                                        }

                                        Button("Cancel") {
                                            nfcManager.stopScanning()
                                        }
                                        .buttonStyle(ArtNouveauButtonStyle(isProminent: false))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 20)
                                }
                                .padding(.horizontal, 24)
                            } else {
                                // Scan button - modern and prominent
                                Button {
                                    nfcManager.startScanning()
                                } label: {
                                    ArtNouveauCard(shadow: ArtNouveauTheme.shadowLarge) {
                                        VStack(spacing: 24) {
                                            // Icon with gradient background
                                            ZStack {
                                                Circle()
                                                    .fill(ArtNouveauTheme.primaryGradient)
                                                    .frame(width: 80, height: 80)
                                                    .shadow(color: ArtNouveauTheme.primary.opacity(0.4), radius: 12, x: 0, y: 6)
                                                
                                                Image(systemName: "sensor.tag.radiowaves.forward.fill")
                                                    .font(.system(size: 36, weight: .semibold))
                                                    .foregroundColor(.white)
                                                    .symbolRenderingMode(.hierarchical)
                                            }

                                            VStack(spacing: 10) {
                                                Text(configStore.isBlockingEnabled ? "Stop Blocking" : "Start Blocking")
                                                    .font(.system(.title2, design: .default).weight(.bold))
                                                    .foregroundColor(ArtNouveauTheme.label)

                                                Text("Tap your tag to \(configStore.isBlockingEnabled ? "disable" : "enable") blocking")
                                                    .font(.system(.body, design: .default).weight(.medium))
                                                    .foregroundColor(ArtNouveauTheme.secondaryLabel)
                                            }
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 20)
                                    }
                                }
                                .buttonStyle(ScaleButtonStyle())
                                .padding(.horizontal, 24)
                            }
                        } else {
                            // Setup required card - modern design
                            ArtNouveauCard(shadow: ArtNouveauTheme.shadowLarge) {
                                VStack(spacing: 24) {
                                    ZStack {
                                        Circle()
                                            .fill(ArtNouveauTheme.warningLight)
                                            .frame(width: 80, height: 80)
                                        
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .font(.system(size: 40, weight: .semibold))
                                            .foregroundColor(ArtNouveauTheme.warning)
                                            .symbolRenderingMode(.hierarchical)
                                    }

                                    VStack(spacing: 10) {
                                        Text("Setup Required")
                                            .font(.system(.title2, design: .default).weight(.bold))
                                            .foregroundColor(ArtNouveauTheme.label)

                                        Text("Configure your settings to get started")
                                            .font(.system(.body, design: .default).weight(.medium))
                                            .foregroundColor(ArtNouveauTheme.secondaryLabel)
                                            .multilineTextAlignment(.center)
                                    }

                                    Button {
                                        showSettings = true
                                    } label: {
                                        HStack(spacing: 10) {
                                            Image(systemName: "gear")
                                                .font(.system(size: 16, weight: .semibold))
                                            Text("Open Settings")
                                        }
                                        .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(ArtNouveauButtonStyle(isProminent: true))
                                    .padding(.top, 4)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
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
                screenTimeManager.restoreBlockingIfNeeded()
                schedulingManager.refresh()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                schedulingManager.refresh()
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
