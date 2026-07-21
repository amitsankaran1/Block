//
//  HomeView.swift
//  Block
//
//  Blocking status home tab: shows the overall shield state, which blocks are
//  active (by type), and the NFC tag action when a tag block is configured.
//

import SwiftUI

struct HomeView: View {
    @StateObject private var blockStore = BlockStore.shared
    @StateObject private var groupStore = AppGroupStore.shared
    @StateObject private var screenTimeManager = ScreenTimeManager.shared
    @StateObject private var nfcManager = NFCManager.shared
    @StateObject private var schedulingManager = SchedulingManager.shared
    @StateObject private var usageLimitManager = UsageLimitManager.shared
    @StateObject private var configStore = AppConfigurationStore.shared
    @StateObject private var breakManager = BreakManager.shared
    @State private var showSettings = false

    /// Blocks whose shield is lifted for a break right now. They stay out of the
    /// "active" groups below — the shield really is down — but get their own
    /// "On break" group so the state is never invisible.
    private var onBreakBlocks: [BlockRule] {
        blockStore.blocks.filter { breakManager.isOnBreak(blockID: $0.id) }
    }
    private var activeScheduledBlocks: [BlockRule] {
        blockStore.blocks.filter {
            schedulingManager.activeScheduledBlockIDs.contains($0.id) && !breakManager.isOnBreak(blockID: $0.id)
        }
    }
    private var activeUsageLockBlocks: [BlockRule] {
        blockStore.blocks.filter { usageLimitManager.activeUsageLockBlockIDs.contains($0.id) }
    }
    /// Tag blocks toggled on — drives the NFC action button (a tag block on break
    /// is still "on"; the next tap turns it off).
    private var enabledTagBlocks: [BlockRule] {
        blockStore.blocks.filter { $0.type == .tag && $0.isEnabled }
    }
    private var activeTagBlocks: [BlockRule] {
        enabledTagBlocks.filter { !breakManager.isOnBreak(blockID: $0.id) }
    }
    private var anyShieldActive: Bool {
        !activeScheduledBlocks.isEmpty || !activeUsageLockBlocks.isEmpty || !activeTagBlocks.isEmpty
    }
    private var hasTagBlock: Bool { blockStore.blocks.contains { $0.type == .tag } }

    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    colors: [ArtNouveauTheme.background, ArtNouveauTheme.secondaryBackground.opacity(0.3)],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    statusSection
                        .frame(maxWidth: .infinity)
                        .padding(.top, 48)
                        .padding(.bottom, 32)
                        .padding(.horizontal, 24)

                    Spacer(minLength: 0)

                    actionArea
                        .frame(maxWidth: .infinity)

                    Spacer(minLength: 0)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gear").foregroundColor(ArtNouveauTheme.primary)
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                NavigationView { SettingsView() }
            }
            .onAppear {
                screenTimeManager.checkAuthorizationStatus()
                schedulingManager.refresh()
                usageLimitManager.reconcileExpiredLocks()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                schedulingManager.refresh()
                usageLimitManager.reconcileExpiredLocks()
            }
        }
    }

    // MARK: - Status

    private var statusSection: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(anyShieldActive ? ArtNouveauTheme.errorGradient : ArtNouveauTheme.successGradient)
                    .frame(width: 120, height: 120)
                    .shadow(color: (anyShieldActive ? ArtNouveauTheme.error : ArtNouveauTheme.success).opacity(0.4), radius: 16, x: 0, y: 8)
                Image(systemName: anyShieldActive ? "lock.shield.fill" : "lock.open.fill")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.white)
                    .symbolRenderingMode(.hierarchical)
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: anyShieldActive)

            HStack(spacing: 8) {
                Circle().fill(anyShieldActive ? ArtNouveauTheme.error : ArtNouveauTheme.success).frame(width: 10, height: 10)
                Text(anyShieldActive ? "BLOCKING ACTIVE" : "BLOCKING INACTIVE")
                    .font(.system(.subheadline, design: .default).weight(.bold))
                    .tracking(1.2)
                    .foregroundColor(anyShieldActive ? ArtNouveauTheme.error : ArtNouveauTheme.success)
            }
            .padding(.horizontal, 20).padding(.vertical, 10)
            .background(Capsule().fill(anyShieldActive ? ArtNouveauTheme.errorLight : ArtNouveauTheme.successLight))

            activeBlockGroups
        }
    }

    @ViewBuilder
    private var activeBlockGroups: some View {
        VStack(spacing: 14) {
            capsuleGroup("Scheduled", color: ArtNouveauTheme.error, icon: "clock.fill",
                         labels: activeScheduledBlocks.map { $0.name })
            capsuleGroup("Usage locked", color: ArtNouveauTheme.warning, icon: "hourglass",
                         labels: activeUsageLockBlocks.map { usageLockLabel(for: $0) })
            capsuleGroup("Tag on", color: ArtNouveauTheme.primary, icon: "sensor.tag.radiowaves.forward.fill",
                         labels: activeTagBlocks.map { $0.name })
            capsuleGroup("On break", color: ArtNouveauTheme.success, icon: "cup.and.saucer.fill",
                         labels: onBreakBlocks.map { breakLabel(for: $0) })
        }
    }

    @ViewBuilder
    private func capsuleGroup(_ title: String, color: Color, icon: String, labels: [String]) -> some View {
        if !labels.isEmpty {
            VStack(spacing: 6) {
                Text(title.uppercased())
                    .font(.system(.caption2, design: .default).weight(.bold)).tracking(1.0)
                    .foregroundColor(ArtNouveauTheme.secondaryLabel)
                FlowRow(labels) { label in
                    HStack(spacing: 4) {
                        Image(systemName: icon).font(.system(size: 9, weight: .bold)).foregroundColor(color)
                        Text(label).font(.system(.caption, design: .default).weight(.semibold)).foregroundColor(color)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Capsule().fill(color.opacity(0.15)))
                }
            }
        }
    }

    private func usageLockLabel(for block: BlockRule) -> String {
        guard let endsAt = usageLimitManager.lockEnd(for: block.id) else { return block.name }
        let mins = max(0, Int(endsAt.timeIntervalSinceNow / 60))
        let suffix = mins >= 60 ? "\(mins / 60)h \(mins % 60)m" : "\(mins)m"
        return "\(block.name) · \(suffix)"
    }

    private func breakLabel(for block: BlockRule) -> String {
        guard let endsAt = BreakMonitoring.breakEnd(blockID: block.id) else { return block.name }
        let secs = max(0, Int(endsAt.timeIntervalSinceNow))
        return "\(block.name) · \(String(format: "%d:%02d", secs / 60, secs % 60))"
    }

    // MARK: - Action area

    @ViewBuilder
    private var actionArea: some View {
        if hasTagBlock && configStore.isTagRegistered {
            if nfcManager.isScanning {
                ArtNouveauCard(shadow: ArtNouveauTheme.shadowLarge) {
                    VStack(spacing: 20) {
                        ProgressView().controlSize(.large).tint(ArtNouveauTheme.primary)
                        Text("Hold iPhone near your tag")
                            .font(.system(.headline, design: .default).weight(.bold))
                            .foregroundColor(ArtNouveauTheme.label)
                        Button("Cancel") { nfcManager.stopScanning() }
                            .buttonStyle(ArtNouveauButtonStyle(isProminent: false))
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                }
                .padding(.horizontal, 24)
            } else {
                Button { nfcManager.startScanning() } label: {
                    ArtNouveauCard(shadow: ArtNouveauTheme.shadowLarge) {
                        VStack(spacing: 20) {
                            ZStack {
                                Circle().fill(ArtNouveauTheme.primaryGradient).frame(width: 76, height: 76)
                                Image(systemName: "sensor.tag.radiowaves.forward.fill")
                                    .font(.system(size: 34, weight: .semibold)).foregroundColor(.white)
                                    .symbolRenderingMode(.hierarchical)
                            }
                            Text(enabledTagBlocks.isEmpty ? "Start Blocking" : "Stop Blocking")
                                .font(.system(.title2, design: .default).weight(.bold))
                                .foregroundColor(ArtNouveauTheme.label)
                            Text("Tap your tag to \(enabledTagBlocks.isEmpty ? "enable" : "disable") your tag blocks")
                                .font(.system(.subheadline, design: .default).weight(.medium))
                                .foregroundColor(ArtNouveauTheme.secondaryLabel)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 16)
                    }
                }
                .buttonStyle(ScaleButtonStyle())
                .padding(.horizontal, 24)
            }
        } else if blockStore.blocks.isEmpty {
            ArtNouveauCard(shadow: ArtNouveauTheme.shadowLarge) {
                VStack(spacing: 14) {
                    Image(systemName: "square.stack.3d.up")
                        .font(.system(size: 36, weight: .semibold)).foregroundColor(ArtNouveauTheme.primary)
                        .symbolRenderingMode(.hierarchical)
                    Text("No blocks yet")
                        .font(.system(.title3, design: .default).weight(.bold)).foregroundColor(ArtNouveauTheme.label)
                    Text("Create an app list in Lists, then add a block in Blocks to start.")
                        .font(.system(.subheadline, design: .default)).foregroundColor(ArtNouveauTheme.secondaryLabel)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 12)
            }
            .padding(.horizontal, 24)
        }
    }
}

/// Lightweight wrapping row of chips (avoids a hard dependency on iOS 16 Layout).
private struct FlowRow<Item: Hashable, Cell: View>: View {
    let items: [Item]
    let cell: (Item) -> Cell
    init(_ items: [Item], @ViewBuilder cell: @escaping (Item) -> Cell) {
        self.items = items
        self.cell = cell
    }
    var body: some View {
        HStack(spacing: 6) {
            ForEach(items, id: \.self) { cell($0) }
        }
    }
}
