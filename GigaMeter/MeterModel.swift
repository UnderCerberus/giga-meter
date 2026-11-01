import Foundation
import GigaCore
import Observation
import ProbeKit

@MainActor
@Observable
final class MeterModel {
    static let shared = MeterModel()

    private static let onboardedKey = "didFinishOnboarding"
    private static let probeSizeLimit = 5_000_000

    private(set) var snapshot: UsageSnapshot
    private(set) var wasReset: Bool
    var showsOnboarding: Bool
    var showsCarrierSheet = false

    private var ledger: Ledger
    private let calendar = Calendar.current
    private let store = LedgerStore.standard()
    private let probe = ProbeStore.standard()
    private let isDemo: Bool

    private init() {
        switch LaunchMode.current {
        case .live:
            let loaded = store.load()
            ledger = loaded.ledger
            wasReset = loaded.wasReset
            isDemo = false
            showsOnboarding = !UserDefaults.standard.bool(forKey: Self.onboardedKey)
            snapshot = loaded.ledger.snapshot(now: Date(), calendar: calendar)
            probe.removeIfLarger(thanBytes: Self.probeSizeLimit)
        case .demo(let showsCarrierSheet):
            let now = LaunchMode.demoDate(calendar: calendar)
            ledger = Ledger.demo(now: now, calendar: calendar)
            wasReset = false
            isDemo = true
            showsOnboarding = false
            self.showsCarrierSheet = showsCarrierSheet
            snapshot = ledger.snapshot(now: now, calendar: calendar)
        }
    }

    func measure(trigger: ProbeTrigger) {
        guard !isDemo else { return }
        let now = Date()
        ledger.apply(
            counters: CounterReader.readTargets(),
            bootTime: CounterReader.bootTime(),
            now: now,
            calendar: calendar
        )
        persist(now: now)
        if trigger != .manual {
            try? ProbeRecorder.record(trigger: trigger, note: nil, store: probe)
        }
    }

    // 表示中の定期更新。診断ログは増やさない
    func refreshLive() {
        guard !isDemo else { return }
        let now = Date()
        ledger.apply(
            counters: CounterReader.readTargets(),
            bootTime: CounterReader.bootTime(),
            now: now,
            calendar: calendar
        )
        persist(now: now)
    }

    func setCarrierValue(bytes: Double) {
        ledger.setCarrierValue(bytes: bytes)
        persist(now: isDemo ? LaunchMode.demoDate(calendar: calendar) : Date())
        finishOnboarding()
    }

    func finishOnboarding() {
        showsOnboarding = false
        UserDefaults.standard.set(true, forKey: Self.onboardedKey)
    }

    func dismissResetNotice() {
        wasReset = false
    }

    var probeStore: ProbeStore { probe }

    private func persist(now: Date) {
        if !isDemo { try? store.save(ledger) }
        snapshot = ledger.snapshot(now: now, calendar: calendar)
    }
}
