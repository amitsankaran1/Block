//
//  TestHarness.swift
//  Block
//
//  Edge-case suite that runs on launch when env var BLOCK_RUN_TEST_HARNESS=1.
//
//  Exercises preset CRUD, BlockingActuator side-effects, CooldownManager state
//  machine, SchedulingManager, NFC tag callback, and SharedDefaults persistence.
//
//  Writes a JSON report to <Documents>/test-harness-report.json so the host can
//  read it back via `simctl get_app_container`.
//
//  Compiled out of release builds.
//

#if DEBUG

import Foundation
import FamilyControls
import ManagedSettings

@MainActor
enum TestHarness {

    static var isEnabled: Bool {
        ProcessInfo.processInfo.environment["BLOCK_RUN_TEST_HARNESS"] == "1"
    }

    static var seedDemoState: Bool {
        ProcessInfo.processInfo.environment["BLOCK_SEED_DEMO_STATE"] == "1"
    }

    /// Populates representative state so screenshots cover data-rich UI.
    /// Idempotent (deletes prior demo presets first).
    static func seedDemoStateIfRequested() {
        guard seedDemoState else { return }

        // Wipe runtime + presets
        DebugSimulator.resetAllRuntime()
        for preset in PresetStore.shared.presets {
            PresetStore.shared.delete(id: preset.id)
        }

        // Register a tag so the home-screen action card appears
        AppConfigurationStore.shared.registerTag(identifier: "demo-tag-04A3B2C1")

        // 1. Weekday work-hours preset, manually enabled
        let work = PresetStore.shared.create(name: "Work focus")
        PresetStore.shared.setSchedule(
            id: work.id,
            schedule: BlockingSchedule(startHour: 9, startMinute: 0, endHour: 17, endMinute: 0,
                                        weekdays: [2,3,4,5,6])
        )
        PresetStore.shared.setEnabled(id: work.id, enabled: true)
        PresetStore.shared.setCooldown(id: work.id, minutes: 5)

        // 2. Late-night cross-midnight schedule
        let sleep = PresetStore.shared.create(name: "Sleep")
        PresetStore.shared.setSchedule(
            id: sleep.id,
            schedule: BlockingSchedule(startHour: 22, startMinute: 0, endHour: 6, endMinute: 0,
                                        weekdays: Set(1...7))
        )
        PresetStore.shared.setCooldown(id: sleep.id, minutes: 10)

        // 3. Weekend-only preset, no schedule yet
        let weekend = PresetStore.shared.create(name: "Weekend wind-down")
        PresetStore.shared.setSchedule(
            id: weekend.id,
            schedule: BlockingSchedule(startHour: 18, startMinute: 0, endHour: 23, endMinute: 0,
                                        weekdays: [1,7])
        )

        // 4. Usage-limited preset (no schedule) — caps cumulative use, then locks.
        let doomscroll = PresetStore.shared.create(name: "Doomscroll guard")
        if var d = PresetStore.shared.preset(id: doomscroll.id) {
            d.usageLimitMinutes = 30
            d.usageLockMinutes = 180
            d.cooldownMinutes = 5
            PresetStore.shared.update(d)
        }
        // Also give the work preset a usage limit so the editor shows it populated.
        PresetStore.shared.setUsageLimit(id: work.id, limitMinutes: 60, lockMinutes: 120)

        PresetStore.shared.flush()

        // Mark the work preset as in an active scheduled window so home shows the badge.
        BlockingActuator.start(presetID: work.id)
        // Put the usage-limited preset into an active lockout so home shows the
        // "Usage locked" capsule and we exercise the lock state machine.
        DebugSimulator.fireUsageThreshold(presetID: doomscroll.id)
        SchedulingManager.shared.refresh()
        UsageLimitManager.shared.refresh()

        print("🌱 Seeded demo state: 4 presets, 1 scheduled + 1 usage-locked, tag=demo-tag-04A3B2C1")
    }

    struct CaseResult: Codable {
        let name: String
        let passed: Bool
        let detail: String
    }

    struct Report: Codable {
        let startedAt: Date
        let finishedAt: Date
        let authorizationStatus: String
        let isSimulator: Bool
        let cases: [CaseResult]
        var passed: Int { cases.filter(\.passed).count }
        var failed: Int { cases.filter { !$0.passed }.count }
    }

    static func runIfEnabled() {
        guard isEnabled else { return }
        Task { @MainActor in
            // Tiny delay so app finished its own .task initialization
            try? await Task.sleep(nanoseconds: 300_000_000)
            let report = await runSuite()
            writeReport(report)
            printReport(report)
        }
    }

    // MARK: - Suite

    static func runSuite() async -> Report {
        let started = Date()
        var cases: [CaseResult] = []

        // Try requesting Screen Time auth — on iOS 16+ simulator this often
        // auto-resolves to approved, which lets later cases verify the
        // shielding-active code path.
        do {
            try await ScreenTimeManager.shared.requestAuthorization()
        } catch {
            print("⚠️ requestAuthorization threw: \(error)")
        }

        // Wipe runtime state so the harness is reproducible.
        DebugSimulator.resetAllRuntime()
        // Also delete all presets to start clean.
        for preset in PresetStore.shared.presets {
            PresetStore.shared.delete(id: preset.id)
        }

        cases.append(case_presetCRUD())
        cases.append(case_presetSelection())
        cases.append(case_blockingActuatorStartEnd())
        cases.append(case_blockingActuatorWithoutPreset())
        cases.append(case_blockingActuatorWeekdayFilterPasses())
        cases.append(case_blockingActuatorWeekdayFilterBlocks())
        cases.append(case_cooldownStartCancelComplete())
        cases.append(case_cooldownFastForward())
        cases.append(case_cooldownZeroMinutes())
        cases.append(case_nfcRegistration())
        cases.append(case_nfcRegisteredToggle())
        cases.append(case_nfcUnknownIgnored())
        cases.append(case_scheduleCrossesMidnightDetection())
        cases.append(case_scheduleSummaryStrings())
        cases.append(case_presetPersistenceRoundtrip())
        cases.append(case_resetAllRuntime())
        cases.append(case_snapshotShape())
        cases.append(case_schedulingManagerApply())
        cases.append(case_screenTimeCallsAreSafeWithoutAuth())
        cases.append(case_appConfigStoreToggleBlockingFlag())
        cases.append(case_presetLastErrorPropagation())
        cases.append(case_concurrentTagScans())

        return Report(
            startedAt: started,
            finishedAt: Date(),
            authorizationStatus: authString(ScreenTimeManager.shared.authorizationStatus),
            isSimulator: isSimulator,
            cases: cases
        )
    }

    // MARK: - Cases

    static func case_presetCRUD() -> CaseResult {
        let store = PresetStore.shared
        let beforeCount = store.presets.count
        let p = createAndFlush(name:"Harness CRUD")
        let after = store.presets.count
        let renamed = "Harness CRUD Renamed"
        store.setName(id: p.id, name: renamed)
        let nameOK = store.preset(id: p.id)?.name == renamed
        store.delete(id: p.id)
        let removedOK = store.preset(id: p.id) == nil
        let pass = (after == beforeCount + 1) && nameOK && removedOK
        return result("preset CRUD (create/rename/delete)", pass, "before=\(beforeCount) after=\(after) renamed=\(nameOK) removed=\(removedOK)")
    }

    static func case_presetSelection() -> CaseResult {
        let store = PresetStore.shared
        let p = createAndFlush(name:"Selection target")
        // Empty selection by default — set a fresh empty selection just to exercise the call.
        let selection = FamilyActivitySelection()
        store.setSelection(id: p.id, selection: selection)
        let appCount = store.preset(id: p.id)?.selection.applicationTokens.count ?? -1
        store.delete(id: p.id)
        return result("setSelection routes through update", appCount == 0, "appCount=\(appCount)")
    }

    static func case_blockingActuatorStartEnd() -> CaseResult {
        let store = PresetStore.shared
        let p = createAndFlush(name:"Actuator subject")
        let suite = SharedDefaults.suite
        let key = SharedDefaults.Keys.running(presetID: p.id)
        BlockingActuator.start(presetID: p.id)
        let runningAfterStart = suite.bool(forKey: key)
        BlockingActuator.end(presetID: p.id)
        let runningAfterEnd = suite.bool(forKey: key)
        store.delete(id: p.id)
        let pass = runningAfterStart && !runningAfterEnd
        return result("BlockingActuator.start/end toggles running flag", pass,
                      "afterStart=\(runningAfterStart) afterEnd=\(runningAfterEnd)")
    }

    static func case_blockingActuatorWithoutPreset() -> CaseResult {
        let phantom = UUID()
        let started = BlockingActuator.start(presetID: phantom)
        return result("Actuator.start returns false for missing preset", !started, "started=\(started)")
    }

    static func case_blockingActuatorWeekdayFilterPasses() -> CaseResult {
        let store = PresetStore.shared
        let p = createAndFlush(name:"Weekday all")
        var schedule = BlockingSchedule()
        schedule.weekdays = Set(1...7) // every weekday
        store.setSchedule(id: p.id, schedule: schedule)
        store.flush()
        let started = BlockingActuator.start(presetID: p.id)
        BlockingActuator.end(presetID: p.id)
        store.delete(id: p.id)
        return result("Actuator passes weekday filter when 'every day'", started, "started=\(started)")
    }

    static func case_blockingActuatorWeekdayFilterBlocks() -> CaseResult {
        let store = PresetStore.shared
        let p = createAndFlush(name:"Weekday none")
        var schedule = BlockingSchedule()
        schedule.weekdays = []
        store.setSchedule(id: p.id, schedule: schedule)
        store.flush()
        let started = BlockingActuator.start(presetID: p.id)
        BlockingActuator.end(presetID: p.id)
        store.delete(id: p.id)
        return result("Actuator blocked by empty weekday filter", !started, "started=\(started)")
    }

    static func case_cooldownStartCancelComplete() -> CaseResult {
        let store = PresetStore.shared
        let p = createAndFlush(name:"Cooldown subject")
        let mgr = CooldownManager.shared
        mgr.cancel()

        mgr.start(for: p.id, minutes: 5)
        let activeMatch = mgr.activeCooldown?.presetID == p.id
        mgr.cancel()
        let clearedAfterCancel = mgr.activeCooldown == nil

        // start, then complete (this also clears the per-preset shield + running flag)
        BlockingActuator.start(presetID: p.id) // pretend a schedule started shielding
        mgr.start(for: p.id, minutes: 5)
        mgr.complete()
        let clearedAfterComplete = mgr.activeCooldown == nil
        let runningCleared = !SharedDefaults.suite.bool(forKey: SharedDefaults.Keys.running(presetID: p.id))

        store.delete(id: p.id)
        let pass = activeMatch && clearedAfterCancel && clearedAfterComplete && runningCleared
        return result("Cooldown start/cancel/complete clears state", pass,
                      "active=\(activeMatch) cancel=\(clearedAfterCancel) complete=\(clearedAfterComplete) runningCleared=\(runningCleared)")
    }

    static func case_cooldownFastForward() -> CaseResult {
        let store = PresetStore.shared
        let p = createAndFlush(name:"Fast-fwd subject")
        let mgr = CooldownManager.shared
        mgr.cancel()
        mgr.start(for: p.id, minutes: 30)
        let beforeRemaining = mgr.remaining
        DebugSimulator.expireCooldown()
        let afterActive = mgr.activeCooldown
        store.delete(id: p.id)
        let pass = beforeRemaining > 0 && afterActive == nil
        return result("expireCooldown completes active cooldown", pass,
                      "before=\(Int(beforeRemaining))s afterActive=\(afterActive == nil ? "nil" : "set")")
    }

    static func case_cooldownZeroMinutes() -> CaseResult {
        let store = PresetStore.shared
        let p = createAndFlush(name:"Zero cooldown")
        let mgr = CooldownManager.shared
        mgr.cancel()
        mgr.start(for: p.id, minutes: 0)
        let active = mgr.activeCooldown
        store.delete(id: p.id)
        return result("0-minute cooldown completes immediately", active == nil,
                      "active=\(active == nil ? "nil" : "set")")
    }

    static func case_nfcRegistration() -> CaseResult {
        let cfg = AppConfigurationStore.shared
        cfg.clearTagRegistration()
        NFCManager.shared.simulateTagScan(withId: "harness-tag-A")
        let registered = cfg.registeredTagIdentifier == "harness-tag-A"
        cfg.clearTagRegistration()
        return result("simulateTagScan registers tag when none registered", registered,
                      "registered=\(registered)")
    }

    static func case_nfcRegisteredToggle() -> CaseResult {
        let cfg = AppConfigurationStore.shared
        let stm = ScreenTimeManager.shared
        cfg.clearTagRegistration()
        cfg.registerTag(identifier: "harness-tag-B")
        let beforeBlocking = cfg.isBlockingEnabled

        // First scan: should toggle blocking. NB: enableBlocking guards on auth.approved,
        // so on simulator without auth, isBlockingEnabled WON'T flip. We assert based on auth.
        NFCManager.shared.simulateTagScan(withId: "harness-tag-B")
        let afterFirstScan = cfg.isBlockingEnabled

        // Second scan toggles back (or stays off if auth wasn't granted).
        NFCManager.shared.simulateTagScan(withId: "harness-tag-B")
        let afterSecondScan = cfg.isBlockingEnabled

        cfg.clearTagRegistration()

        let detail = "before=\(beforeBlocking) afterFirst=\(afterFirstScan) afterSecond=\(afterSecondScan) auth=\(authString(stm.authorizationStatus))"

        // The robust invariant: scanning the registered tag triggers a toggle attempt.
        // Verify: if auth approved, blocking flipped; otherwise it remained false.
        let pass: Bool
        if stm.authorizationStatus == .approved {
            pass = afterFirstScan != beforeBlocking && afterSecondScan == beforeBlocking
        } else {
            pass = afterFirstScan == false && afterSecondScan == false
        }
        return result("Registered tag scan dispatches toggle (auth-gated)", pass, detail)
    }

    static func case_nfcUnknownIgnored() -> CaseResult {
        let cfg = AppConfigurationStore.shared
        cfg.clearTagRegistration()
        cfg.registerTag(identifier: "harness-tag-known")
        let before = cfg.isBlockingEnabled
        NFCManager.shared.simulateTagScan(withId: "harness-tag-different")
        let after = cfg.isBlockingEnabled
        cfg.clearTagRegistration()
        return result("Unknown tag scan does not toggle", before == after, "before=\(before) after=\(after)")
    }

    static func case_scheduleCrossesMidnightDetection() -> CaseResult {
        let normal = BlockingSchedule(startHour: 9, startMinute: 0, endHour: 17, endMinute: 0)
        let cross = BlockingSchedule(startHour: 22, startMinute: 0, endHour: 6, endMinute: 0)
        let pass = !normal.crossesMidnight && cross.crossesMidnight
        return result("crossesMidnight detection", pass,
                      "normal=\(normal.crossesMidnight) cross=\(cross.crossesMidnight)")
    }

    static func case_scheduleSummaryStrings() -> CaseResult {
        let weekdays = BlockingSchedule(weekdays: [2,3,4,5,6])
        let weekend = BlockingSchedule(weekdays: [1,7])
        let everyday = BlockingSchedule(weekdays: Set(1...7))
        let pass = weekdays.weekdaySummary == "Weekdays"
            && weekend.weekdaySummary == "Weekends"
            && everyday.weekdaySummary == "Every day"
        return result("Schedule weekday summary strings", pass,
                      "wd=\(weekdays.weekdaySummary) we=\(weekend.weekdaySummary) ed=\(everyday.weekdaySummary)")
    }

    static func case_presetPersistenceRoundtrip() -> CaseResult {
        let store = PresetStore.shared
        let p = createAndFlush(name:"Persistence target")
        let id = p.id
        // Force immediate persistence by re-reading after a brief debounce.
        let exp = expectation { store.preset(id: id) != nil }

        // Read raw data back from SharedDefaults.
        let raw = SharedDefaults.suite.data(forKey: SharedDefaults.Keys.presets)
        store.delete(id: id)
        let pass = exp && raw != nil
        return result("Preset write produces SharedDefaults blob", pass, "exp=\(exp) rawBytes=\(raw?.count ?? -1)")
    }

    static func case_resetAllRuntime() -> CaseResult {
        let store = PresetStore.shared
        let p = createAndFlush(name:"Reset target")
        BlockingActuator.start(presetID: p.id)
        let beforeRunning = SharedDefaults.suite.bool(forKey: SharedDefaults.Keys.running(presetID: p.id))
        DebugSimulator.resetAllRuntime()
        let afterRunning = SharedDefaults.suite.bool(forKey: SharedDefaults.Keys.running(presetID: p.id))
        store.delete(id: p.id)
        return result("resetAllRuntime clears running flags", beforeRunning && !afterRunning,
                      "before=\(beforeRunning) after=\(afterRunning)")
    }

    static func case_schedulingManagerApply() -> CaseResult {
        // SchedulingManager wraps DeviceActivityCenter.startMonitoring. On simulator
        // without Screen Time auth, this is expected to fail and surface in lastError.
        let store = PresetStore.shared
        let p = createAndFlush(name: "Sched apply target")
        let schedule = BlockingSchedule(startHour: 9, startMinute: 0,
                                         endHour: 17, endMinute: 0,
                                         weekdays: [2,3,4,5,6])
        store.setSchedule(id: p.id, schedule: schedule)
        store.flush()
        let mgr = SchedulingManager.shared
        mgr.lastError = nil
        mgr.applySchedule(for: store.preset(id: p.id)!)
        let errAfter = mgr.lastError
        mgr.removeSchedule(for: store.preset(id: p.id)!)
        store.delete(id: p.id)
        // Pass either way — we just want the call not to crash. Detail records what happened.
        return result("SchedulingManager.applySchedule does not crash", true,
                      "lastError=\(errAfter ?? "nil")")
    }

    static func case_screenTimeCallsAreSafeWithoutAuth() -> CaseResult {
        // applyPresetShield + clearPresetShield should be no-ops when auth not approved
        // and must not crash.
        let store = PresetStore.shared
        let p = createAndFlush(name: "Shield call target")
        let preset = store.preset(id: p.id)!
        ScreenTimeManager.shared.applyPresetShield(preset)
        ScreenTimeManager.shared.clearPresetShield(id: p.id)
        store.delete(id: p.id)
        return result("ScreenTimeManager preset calls safe without auth", true, "no crash")
    }

    static func case_appConfigStoreToggleBlockingFlag() -> CaseResult {
        let cfg = AppConfigurationStore.shared
        let initial = cfg.isBlockingEnabled
        cfg.toggleBlocking()
        let after1 = cfg.isBlockingEnabled
        cfg.toggleBlocking()
        let after2 = cfg.isBlockingEnabled
        let pass = after1 != initial && after2 == initial
        return result("AppConfigurationStore.toggleBlocking flips and persists", pass,
                      "initial=\(initial) after1=\(after1) after2=\(after2)")
    }

    static func case_presetLastErrorPropagation() -> CaseResult {
        // Verify scheduling manager publishes error info we can show in UI.
        // Just check the property is settable/readable.
        let mgr = SchedulingManager.shared
        let prior = mgr.lastError
        mgr.lastError = "synthetic-error"
        let read = mgr.lastError
        mgr.lastError = prior
        return result("SchedulingManager.lastError is observable", read == "synthetic-error",
                      "read=\(read ?? "nil")")
    }

    static func case_concurrentTagScans() -> CaseResult {
        // Multiple rapid simulateTagScan calls should not corrupt state.
        let cfg = AppConfigurationStore.shared
        cfg.clearTagRegistration()
        cfg.registerTag(identifier: "concurrent-tag")
        for _ in 0..<10 {
            NFCManager.shared.simulateTagScan(withId: "concurrent-tag")
        }
        // Without auth, blocking remains false. Important: no crash, tag still registered.
        let stillRegistered = cfg.registeredTagIdentifier == "concurrent-tag"
        cfg.clearTagRegistration()
        return result("10 rapid tag scans don't corrupt state", stillRegistered,
                      "stillRegistered=\(stillRegistered)")
    }

    static func case_snapshotShape() -> CaseResult {
        let store = PresetStore.shared
        let p = createAndFlush(name:"Snap target")
        BlockingActuator.start(presetID: p.id)
        let snap = DebugSimulator.snapshot()
        let presetSnap = snap.presets.first(where: { $0.id == p.id })
        let pass = presetSnap?.isScheduledRunning == true
        BlockingActuator.end(presetID: p.id)
        store.delete(id: p.id)
        return result("Snapshot reflects running flag", pass,
                      "running=\(presetSnap?.isScheduledRunning ?? false)")
    }

    // MARK: - Helpers

    private static func result(_ name: String, _ passed: Bool, _ detail: String) -> CaseResult {
        CaseResult(name: name, passed: passed, detail: detail)
    }

    /// Create a preset and flush so cross-process (extension-style) readers see it immediately.
    @discardableResult
    private static func createAndFlush(name: String) -> BlockingPreset {
        let p = PresetStore.shared.create(name: name)
        PresetStore.shared.flush()
        return p
    }

    private static func expectation(timeout: TimeInterval = 1.0, predicate: () -> Bool) -> Bool {
        // Synchronous polling — debounce inside PresetStore is 0.3s; we wait a bit longer.
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if predicate() { return true }
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.05))
        }
        return predicate()
    }

    private static var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }

    private static func authString(_ s: AuthorizationStatus) -> String {
        switch s {
        case .notDetermined: return "notDetermined"
        case .denied: return "denied"
        case .approved: return "approved"
        @unknown default: return "unknown"
        }
    }

    // MARK: - Output

    private static func writeReport(_ report: Report) {
        do {
            let url = try reportURL()
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(report)
            try data.write(to: url)
            print("📝 TestHarness wrote \(data.count) bytes to \(url.path)")
        } catch {
            print("❌ TestHarness failed to write report: \(error)")
        }
    }

    private static func reportURL() throws -> URL {
        let docs = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        return docs.appendingPathComponent("test-harness-report.json")
    }

    private static func printReport(_ report: Report) {
        print("==== TestHarness summary ====")
        print("auth=\(report.authorizationStatus) simulator=\(report.isSimulator)")
        print("passed=\(report.passed) failed=\(report.failed) total=\(report.cases.count)")
        for c in report.cases {
            print("\(c.passed ? "✅" : "❌") \(c.name) — \(c.detail)")
        }
        print("==== End TestHarness ====")
    }
}

#endif
