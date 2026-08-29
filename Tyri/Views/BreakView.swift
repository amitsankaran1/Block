//
//  BreakView.swift
//  Tyri
//
//  Displayed as a sheet when the user takes their per-activation break from an
//  active schedule/tag block. Starting the sheet starts the break: the shield
//  lifts immediately and re-applies automatically when the countdown ends —
//  closing this screen does NOT end the break (unlike CooldownView's cancel).
//

import SwiftUI

struct BreakView: View {
    let blockID: UUID
    @Binding var isPresented: Bool

    @StateObject private var breakManager = BreakManager.shared
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
            .navigationTitle("Break")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { isPresented = false }
                        .foregroundColor(ArtNouveauTheme.primary)
                }
            }
        }
        .onAppear { startIfNeeded() }
        .onChange(of: breakManager.activeBreak) { active in
            // Break over (auto re-lock or ended early) — nothing left to show.
            if active == nil { isPresented = false }
        }
    }

    private var block: BlockRule? { blockStore.block(id: blockID) }

    private var header: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(ArtNouveauTheme.successLight)
                    .frame(width: 100, height: 100)
                Image(systemName: "cup.and.saucer.fill")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundColor(ArtNouveauTheme.success)
                    .symbolRenderingMode(.hierarchical)
            }
            .shadow(color: ArtNouveauTheme.success.opacity(0.3), radius: 12, x: 0, y: 6)

            VStack(spacing: 8) {
                Text("Break from “\(block?.name ?? "Block")”")
                    .font(.system(.title2, design: .default).weight(.bold))
                    .foregroundColor(ArtNouveauTheme.label)
                    .multilineTextAlignment(.center)
                Text("Your apps are unlocked until the timer runs out.")
                    .font(.system(.subheadline, design: .default))
                    .foregroundColor(ArtNouveauTheme.secondaryLabel)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var countdown: some View {
        let seconds = Int(breakManager.remaining.rounded(.up))
        let minutes = seconds / 60
        let secs = seconds % 60
        return ArtNouveauCard(shadow: ArtNouveauTheme.shadowMedium) {
            VStack(spacing: 12) {
                Text(String(format: "%02d:%02d", minutes, secs))
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .foregroundColor(ArtNouveauTheme.success)
                    .monospacedDigit()
                Text("Break remaining")
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
            Label("The block re-locks automatically when the break ends — even if the app is closed.", systemImage: "lock.fill")
                .font(.system(.caption, design: .default))
                .foregroundColor(ArtNouveauTheme.secondaryLabel)
            Label("Closing this screen doesn't end the break.", systemImage: "info.circle")
                .font(.system(.caption, design: .default))
                .foregroundColor(ArtNouveauTheme.secondaryLabel)
            Label("One break per \(block?.type == .tag ? "tag session" : "blocking window").", systemImage: "cup.and.saucer")
                .font(.system(.caption, design: .default))
                .foregroundColor(ArtNouveauTheme.secondaryLabel)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var actions: some View {
        Button {
            breakManager.endActiveBreak()
            isPresented = false
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "lock.fill")
                Text("End Break & Re-block Now")
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(ArtNouveauButtonStyle(isProminent: true, gradient: ArtNouveauTheme.errorGradient))
    }

    private func startIfNeeded() {
        // Already on this block's break (reopened from the editor/home) — just show it.
        if breakManager.activeBreak?.blockID == blockID { return }
        guard let block = block, breakManager.isBreakAvailable(for: block) else {
            isPresented = false
            return
        }
        breakManager.start(for: block)
        // start() can no-op (e.g. rules changed underneath us) — don't show a dead sheet.
        if breakManager.activeBreak?.blockID != blockID {
            isPresented = false
        }
    }
}
