//
//  SettingsView.swift
//  Tyri
//
//  Created by Amit Sankaran on 1/7/26.
//

import SwiftUI
import FamilyControls

struct SettingsView: View {
    @StateObject private var configStore = AppConfigurationStore.shared
    @StateObject private var screenTimeManager = ScreenTimeManager.shared
    @State private var showTypingChallenge = false
    @State private var isRequestingAuthorization = false
    #if DEBUG
    @State private var debugMenuActive = false
    #endif
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                authorizationSection
                tagSection
                #if DEBUG
                developerSection
                #endif
                emergencySection
            }
            .padding(.vertical, 20)
        }
        .background(
            LinearGradient(
                colors: [ArtNouveauTheme.background, ArtNouveauTheme.secondaryBackground.opacity(0.3)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
        .sheet(isPresented: $showTypingChallenge) {
            TypingChallengeView(isPresented: $showTypingChallenge)
        }
        #if DEBUG
        .fullScreenCover(isPresented: $debugMenuActive) {
            NavigationView {
                DebugMenuView()
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Close") { debugMenuActive = false }
                        }
                    }
            }
        }
        .onAppear {
            if ProcessInfo.processInfo.environment["BLOCK_OPEN_DEBUG_MENU"] == "1" {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { debugMenuActive = true }
            }
        }
        #endif
    }

    // MARK: - Sections

    @ViewBuilder
    private var authorizationSection: some View {
        if screenTimeManager.authorizationStatus != .approved {
            section("Screen Time") {
                ArtNouveauCard(shadow: ArtNouveauTheme.shadowMedium) {
                    VStack(spacing: 16) {
                        statusRow(icon: "exclamationmark.triangle.fill", tint: ArtNouveauTheme.warning,
                                  title: "Authorization Required",
                                  subtitle: "Grant Screen Time permission so Tyri can shield apps.")
                        Divider()
                        Button {
                            Task {
                                isRequestingAuthorization = true
                                try? await screenTimeManager.requestAuthorization()
                                isRequestingAuthorization = false
                            }
                        } label: {
                            HStack(spacing: 10) {
                                if isRequestingAuthorization {
                                    ProgressView().controlSize(.small).tint(.white)
                                } else {
                                    Image(systemName: "lock.open")
                                }
                                Text(isRequestingAuthorization ? "Requesting…" : "Request Authorization")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(ArtNouveauButtonStyle(isProminent: true))
                        .disabled(isRequestingAuthorization)
                    }
                }
                .padding(.horizontal, 24)
            }
        }
    }

    private var tagSection: some View {
        section("Blocking Tag") {
            ArtNouveauCard(shadow: ArtNouveauTheme.shadowMedium) {
                VStack(spacing: 16) {
                    statusRow(
                        icon: configStore.isTagRegistered ? "checkmark.circle.fill" : "exclamationmark.circle.fill",
                        tint: configStore.isTagRegistered ? ArtNouveauTheme.success : ArtNouveauTheme.warning,
                        title: configStore.isTagRegistered ? "Tag Connected" : "No Tag Connected",
                        subtitle: "Tapping your tag toggles every Tag-type block on or off."
                    )
                    Divider()
                    if configStore.isTagRegistered {
                        Button { configStore.clearTagRegistration() } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "xmark.circle")
                                Text("Disconnect Tag")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(ArtNouveauButtonStyle(isProminent: false))
                    } else {
                        NavigationLink { TagRegistrationView() } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "sensor.tag.radiowaves.forward")
                                Text("Connect Your Tag")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(ArtNouveauButtonStyle(isProminent: true))
                    }
                }
            }
            .padding(.horizontal, 24)
        }
    }

    #if DEBUG
    private var developerSection: some View {
        section("Developer") {
            ArtNouveauCard(shadow: ArtNouveauTheme.shadowMedium) {
                NavigationLink { DebugMenuView() } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "ladybug.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(ArtNouveauTheme.warning)
                        Text("Debug Menu")
                            .font(.system(.headline, design: .default).weight(.semibold))
                            .foregroundColor(ArtNouveauTheme.label)
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption)
                            .foregroundColor(ArtNouveauTheme.secondaryLabel)
                    }
                }
            }
            .padding(.horizontal, 24)
        }
    }
    #endif

    @ViewBuilder
    private var emergencySection: some View {
        if screenTimeManager.authorizationStatus == .approved {
            section("Emergency Access") {
                ArtNouveauCard(shadow: ArtNouveauTheme.shadowMedium) {
                    VStack(spacing: 16) {
                        statusRow(icon: "keyboard", tint: ArtNouveauTheme.warning,
                                  title: "Emergency Override",
                                  subtitle: "Type a passage to clear every active block without your tag.")
                        Divider()
                        Button { showTypingChallenge = true } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "keyboard")
                                Text("Start Typing Challenge")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(ArtNouveauButtonStyle(isProminent: true, gradient: ArtNouveauTheme.goldGradient))
                    }
                }
                .padding(.horizontal, 24)
            }
        }
    }

    // MARK: - Building blocks

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.system(.headline, design: .default).weight(.bold))
                .foregroundColor(ArtNouveauTheme.label)
                .padding(.horizontal, 24)
            content()
        }
    }

    private func statusRow(icon: String, tint: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().fill(tint.opacity(0.15)).frame(width: 56, height: 56)
                Image(systemName: icon)
                    .foregroundColor(tint)
                    .font(.system(size: 28, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(.headline, design: .default).weight(.bold))
                    .foregroundColor(ArtNouveauTheme.label)
                Text(subtitle)
                    .font(.system(.subheadline, design: .default))
                    .foregroundColor(ArtNouveauTheme.secondaryLabel)
            }
            Spacer()
        }
    }
}
