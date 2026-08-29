//
//  CooldownView.swift
//  Tyri
//
//  Displayed as a sheet when the user requests early disable on a scheduled-active preset.
//  After the countdown, the user can release the named-store shield. Cancel restores it.
//

import SwiftUI

struct CooldownView: View {
    let blockID: UUID
    @Binding var isPresented: Bool

    @StateObject private var cooldown = CooldownManager.shared
    @StateObject private var blockStore = BlockStore.shared

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 28) {
                    header
                    countdown
                    explainer
                    actions
                }
                .padding(.horizontal, 24)
                .padding(.top, 32)
                .padding(.bottom, 32)
            }
            .background(
                LinearGradient(
                    colors: [
                        ArtNouveauTheme.background,
                        ArtNouveauTheme.secondaryBackground.opacity(0.3)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .navigationTitle("Cooldown")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        cooldown.cancel()
                        isPresented = false
                    }
                    .foregroundColor(ArtNouveauTheme.primary)
                }
            }
        }
        .onAppear { startIfNeeded() }
    }

    private var block: BlockRule? { blockStore.block(id: blockID) }

    private var header: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(ArtNouveauTheme.warningLight)
                    .frame(width: 100, height: 100)
                Image(systemName: "hourglass")
                    .font(.system(size: 48, weight: .semibold))
                    .foregroundColor(ArtNouveauTheme.warning)
                    .symbolRenderingMode(.hierarchical)
            }
            .shadow(color: ArtNouveauTheme.warning.opacity(0.3), radius: 12, x: 0, y: 6)

            VStack(spacing: 8) {
                Text("Disable “\(block?.name ?? "Block")”?")
                    .font(.system(.title2, design: .default).weight(.bold))
                    .foregroundColor(ArtNouveauTheme.label)
                    .multilineTextAlignment(.center)
                Text("Wait out the cooldown, then release the block.")
                    .font(.system(.subheadline, design: .default))
                    .foregroundColor(ArtNouveauTheme.secondaryLabel)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var countdown: some View {
        let seconds = Int(cooldown.remaining.rounded(.up))
        let minutes = seconds / 60
        let secs = seconds % 60
        return ArtNouveauCard(shadow: ArtNouveauTheme.shadowMedium) {
            VStack(spacing: 12) {
                Text(String(format: "%02d:%02d", minutes, secs))
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .foregroundColor(cooldown.isComplete ? ArtNouveauTheme.success : ArtNouveauTheme.primary)
                    .monospacedDigit()
                Text(cooldown.isComplete ? "Ready to release" : "Time remaining")
                    .font(.system(.caption, design: .default).weight(.semibold))
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundColor(ArtNouveauTheme.secondaryLabel)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var explainer: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Closing this screen cancels the cooldown.", systemImage: "info.circle")
                .font(.system(.caption, design: .default))
                .foregroundColor(ArtNouveauTheme.secondaryLabel)
            Label(afterReleaseText, systemImage: afterReleaseIcon)
                .font(.system(.caption, design: .default))
                .foregroundColor(ArtNouveauTheme.secondaryLabel)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var afterReleaseText: String {
        switch block?.type {
        case .timer: return "The usage limit stays active — a fresh budget starts after release."
        case .tag:   return "The block stays off until you tap your tag again."
        default:     return "The schedule stays active — the next window will re-block."
        }
    }

    private var afterReleaseIcon: String {
        switch block?.type {
        case .timer: return "hourglass"
        case .tag:   return "sensor.tag.radiowaves.forward"
        default:     return "calendar"
        }
    }

    private var actions: some View {
        VStack(spacing: 12) {
            Button {
                cooldown.complete()
                isPresented = false
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "lock.open.fill")
                    Text("Release Block")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(ArtNouveauButtonStyle(isProminent: true, gradient: ArtNouveauTheme.successGradient))
            .disabled(!cooldown.isComplete)
            .opacity(cooldown.isComplete ? 1 : 0.5)

            Button {
                cooldown.cancel()
                isPresented = false
            } label: {
                Text("Cancel")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(ArtNouveauButtonStyle(isProminent: false))
        }
    }

    private func startIfNeeded() {
        // If a cooldown for this block is already running, leave it alone.
        if cooldown.activeCooldown?.blockID == blockID { return }
        let minutes = block?.cooldownMinutes ?? 5
        // "No cooldown" blocks have no early-disable path at all — this sheet
        // should be unreachable for them; dismiss without releasing anything.
        guard minutes > 0 else {
            isPresented = false
            return
        }
        cooldown.start(for: blockID, minutes: minutes)
    }
}
