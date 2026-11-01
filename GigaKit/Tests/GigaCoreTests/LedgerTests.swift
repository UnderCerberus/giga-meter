import XCTest
import ProbeKit
@testable import GigaCore

final class LedgerTests: XCTestCase {
    private let gb = 1_000_000_000.0
    private let accuracy = 1_000.0
    private var calendar: Calendar!

    override func setUp() {
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
    }

    private func date(_ month: Int, _ day: Int, _ hour: Int = 0, year: Int = 2026) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private func counter(_ bytes: UInt64, name: String = "pdp_ip0") -> InterfaceCounter {
        InterfaceCounter(
            name: name,
            in32: UInt32(truncatingIfNeeded: bytes),
            out32: 0,
            in64: bytes,
            out64: 0
        )
    }

    private func started(boot: Date, at now: Date, bytes: UInt64 = 0) -> Ledger {
        var ledger = Ledger()
        ledger.apply(counters: [counter(bytes)], bootTime: boot, now: now, calendar: calendar)
        return ledger
    }

    // MARK: 初回

    func testFirstReadingAfterBootThisMonthUsesCounter() {
        let ledger = started(boot: date(11, 10), at: date(11, 15), bytes: 5_000_000_000)
        XCTAssertEqual(ledger.total, 5 * gb, accuracy: accuracy)
        XCTAssertEqual(ledger.basis, .sinceBoot)
        XCTAssertEqual(ledger.sinceBootDate, date(11, 10))
    }

    func testFirstReadingAfterBootLastMonthIsEstimated() {
        // 10月20日再起動、11月15日に13GB → 26日中14日分
        let ledger = started(boot: date(10, 20), at: date(11, 15), bytes: 13_000_000_000)
        XCTAssertEqual(ledger.total, 7 * gb, accuracy: accuracy)
        XCTAssertEqual(ledger.basis, .estimate)
        XCTAssertNil(ledger.sinceBootDate)
    }

    func testFirstReadingWithout64BitIsLowerBound() {
        var ledger = Ledger()
        let narrow = InterfaceCounter(name: "pdp_ip0", in32: 100, out32: 0, in64: nil, out64: nil)
        ledger.apply(counters: [narrow], bootTime: date(11, 10), now: date(11, 15), calendar: calendar)
        XCTAssertTrue(ledger.isLowerBound)
        XCTAssertFalse(started(boot: date(11, 10), at: date(11, 15)).isLowerBound)
    }

    func testOnlyCellularInterfacesAreCounted() {
        var ledger = Ledger()
        ledger.apply(
            counters: [counter(1_000_000_000), counter(9_000_000_000, name: "en0")],
            bootTime: date(11, 10),
            now: date(11, 15),
            calendar: calendar
        )
        XCTAssertEqual(ledger.total, 1 * gb, accuracy: accuracy)
    }

    // MARK: 増分

    func testAddsDeltaToToday() {
        let boot = date(11, 1)
        var ledger = started(boot: boot, at: date(11, 15, 9))
        ledger.apply(counters: [counter(500_000_000)], bootTime: boot, now: date(11, 15, 12), calendar: calendar)
        XCTAssertEqual(ledger.total, 0.5 * gb, accuracy: accuracy)
        XCTAssertEqual(ledger.dailyBytes[15]!, 0.5 * gb, accuracy: accuracy)
    }

    func testSumsMultipleInterfaces() {
        let boot = date(11, 1)
        var ledger = Ledger()
        ledger.apply(
            counters: [counter(0), counter(0, name: "pdp_ip2")],
            bootTime: boot,
            now: date(11, 15, 9),
            calendar: calendar
        )
        ledger.apply(
            counters: [counter(100), counter(200, name: "pdp_ip2")],
            bootTime: boot,
            now: date(11, 15, 10),
            calendar: calendar
        )
        XCTAssertEqual(ledger.total, 300, accuracy: 0.01)
    }

    func testRebootKeepsTotalAndFlagsGap() {
        let boot = date(11, 1)
        var ledger = started(boot: boot, at: date(11, 15, 9))
        ledger.apply(counters: [counter(4_000_000_000)], bootTime: boot, now: date(11, 15, 10), calendar: calendar)
        ledger.apply(counters: [counter(300_000_000)], bootTime: date(11, 15, 11), now: date(11, 15, 12), calendar: calendar)
        XCTAssertEqual(ledger.total, 4.3 * gb, accuracy: accuracy)
        XCTAssertTrue(ledger.hasGap)
    }

    func testSmallBootTimeJitterIsNotReboot() {
        let boot = date(11, 1)
        var ledger = started(boot: boot, at: date(11, 15, 9), bytes: 1_000)
        ledger.apply(
            counters: [counter(1_500)],
            bootTime: boot.addingTimeInterval(30),
            now: date(11, 15, 10),
            calendar: calendar
        )
        XCTAssertFalse(ledger.hasGap)
        XCTAssertEqual(ledger.total, 1_500, accuracy: 0.01)
    }

    func testInterfaceThatDisappearsAndReturnsIsNotDoubleCounted() {
        let boot = date(11, 1)
        var ledger = started(boot: boot, at: date(11, 15, 9), bytes: 1_000)
        ledger.apply(counters: [], bootTime: boot, now: date(11, 15, 10), calendar: calendar)
        ledger.apply(counters: [counter(1_200)], bootTime: boot, now: date(11, 15, 11), calendar: calendar)
        XCTAssertEqual(ledger.total, 1_200, accuracy: 0.01)
    }

    // MARK: 配分

    func testDeltaAcrossMidnightIsSplitByTime() {
        let boot = date(11, 1)
        var ledger = started(boot: boot, at: date(11, 15, 18))
        ledger.apply(counters: [counter(1_200_000_000)], bootTime: boot, now: date(11, 16, 6), calendar: calendar)
        XCTAssertEqual(ledger.dailyBytes[15]!, 0.6 * gb, accuracy: accuracy)
        XCTAssertEqual(ledger.dailyBytes[16]!, 0.6 * gb, accuracy: accuracy)
        XCTAssertTrue(ledger.estimatedDays.isEmpty)
    }

    func testMonthRolloverSplitsDeltaAndResets() {
        let boot = date(11, 1)
        var ledger = started(boot: boot, at: date(11, 30, 18))
        ledger.setCarrierValue(bytes: 10 * gb)
        ledger.apply(counters: [counter(1_200_000_000)], bootTime: boot, now: date(12, 1, 6), calendar: calendar)

        XCTAssertEqual(ledger.month, MonthKey(year: 2026, month: 12))
        XCTAssertEqual(ledger.total, 0.6 * gb, accuracy: accuracy)
        XCTAssertEqual(ledger.history.last?.month, MonthKey(year: 2026, month: 11))
        XCTAssertEqual(ledger.history.last!.bytes, 10.6 * gb, accuracy: accuracy)
        XCTAssertEqual(ledger.adjustment, 0)
        XCTAssertEqual(ledger.basis, .measured)
    }

    func testRolloverHappensEvenWithoutTraffic() {
        let boot = date(11, 1)
        var ledger = started(boot: boot, at: date(11, 30, 18), bytes: 1_000)
        ledger.apply(counters: [counter(1_000)], bootTime: boot, now: date(12, 1, 6), calendar: calendar)
        XCTAssertEqual(ledger.month, MonthKey(year: 2026, month: 12))
        XCTAssertEqual(ledger.total, 0)
    }

    func testLongGapAcrossMonthsIsSpreadAndMarkedEstimated() {
        let boot = date(10, 1)
        var ledger = started(boot: boot, at: date(10, 31))
        // 10月31日0時 → 12月2日0時 = 32日間
        ledger.apply(counters: [counter(32_000_000_000)], bootTime: boot, now: date(12, 2), calendar: calendar)

        XCTAssertEqual(ledger.month, MonthKey(year: 2026, month: 12))
        XCTAssertEqual(ledger.history.map(\.month), [MonthKey(year: 2026, month: 10), MonthKey(year: 2026, month: 11)])
        XCTAssertEqual(ledger.history[0].bytes, 1 * gb, accuracy: accuracy)
        XCTAssertEqual(ledger.history[1].bytes, 30 * gb, accuracy: accuracy)
        XCTAssertEqual(ledger.total, 1 * gb, accuracy: accuracy)
        XCTAssertEqual(ledger.estimatedDays, [1])
    }

    func testClockMovedBackwardNeverSubtracts() {
        let boot = date(11, 1)
        var ledger = started(boot: boot, at: date(11, 15, 12))
        ledger.apply(counters: [counter(1_000)], bootTime: boot, now: date(11, 15, 9), calendar: calendar)
        XCTAssertEqual(ledger.total, 1_000, accuracy: 0.01)
        XCTAssertEqual(ledger.dailyBytes[15]!, 1_000, accuracy: 0.01)
    }

    // MARK: キャリア値

    func testCarrierValueReplacesTotalAndKeepsCounting() {
        let boot = date(11, 1)
        var ledger = started(boot: boot, at: date(11, 15, 9), bytes: 2_000_000_000)
        ledger.apply(counters: [counter(3_000_000_000)], bootTime: boot, now: date(11, 15, 10), calendar: calendar)

        ledger.setCarrierValue(bytes: 8 * gb)
        XCTAssertEqual(ledger.total, 8 * gb, accuracy: accuracy)
        XCTAssertEqual(ledger.basis, .carrier)

        ledger.apply(counters: [counter(4_000_000_000)], bootTime: boot, now: date(11, 15, 11), calendar: calendar)
        XCTAssertEqual(ledger.total, 9 * gb, accuracy: accuracy)

        ledger.setCarrierValue(bytes: 5 * gb)
        XCTAssertEqual(ledger.total, 5 * gb, accuracy: accuracy)
    }

    func testCarrierValueClearsGapAndUsesMonthStartForForecast() {
        let boot = date(11, 10)
        var ledger = started(boot: boot, at: date(11, 15))
        ledger.hasGap = true
        ledger.setCarrierValue(bytes: 15 * gb)
        XCTAssertFalse(ledger.hasGap)
        XCTAssertNil(ledger.sinceBootDate)
        // 14日で15GB × 30日
        let forecast = ledger.snapshot(now: date(11, 15), calendar: calendar).forecast!
        XCTAssertEqual(forecast, 15 * gb / 14 * 30, accuracy: accuracy)
    }

    // MARK: スナップショット

    func testForecastUsesMonthStartWhenMeasuring() {
        var ledger = Ledger()
        ledger.month = MonthKey(year: 2026, month: 11)
        ledger.dailyBytes = [1: 14 * gb]
        let snapshot = ledger.snapshot(now: date(11, 15), calendar: calendar)
        XCTAssertEqual(snapshot.forecast!, 30 * gb, accuracy: accuracy)
        XCTAssertEqual(snapshot.dailyPace, 1 * gb, accuracy: accuracy)
    }

    func testForecastUsesBootDateWhenOnlySinceBootIsKnown() {
        // 11月10日再起動、5日で5GB → 1GB/日 × 30日
        let ledger = started(boot: date(11, 10), at: date(11, 15), bytes: 5_000_000_000)
        let snapshot = ledger.snapshot(now: date(11, 15), calendar: calendar)
        XCTAssertEqual(snapshot.forecast!, 30 * gb, accuracy: accuracy)
    }

    func testForecastIsHiddenDuringFirst24Hours() {
        var ledger = Ledger()
        ledger.month = MonthKey(year: 2026, month: 11)
        ledger.dailyBytes = [1: 1 * gb]
        XCTAssertNil(ledger.snapshot(now: date(11, 1, 23), calendar: calendar).forecast)
        XCTAssertNotNil(ledger.snapshot(now: date(11, 2), calendar: calendar).forecast)
    }

    func testFebruaryHasCorrectDayCount() {
        var ledger = Ledger()
        ledger.month = MonthKey(year: 2028, month: 2)
        XCTAssertEqual(ledger.snapshot(now: date(2, 10, year: 2028), calendar: calendar).bars.count, 29)
        ledger.month = MonthKey(year: 2027, month: 2)
        XCTAssertEqual(ledger.snapshot(now: date(2, 10, year: 2027), calendar: calendar).bars.count, 28)
    }

    func testSnapshotMarksTodayFutureAndLastMonth() {
        var ledger = Ledger()
        ledger.month = MonthKey(year: 2026, month: 11)
        ledger.dailyBytes = [15: 2 * gb]
        ledger.history = [MonthTotal(month: MonthKey(year: 2026, month: 10), bytes: 21 * gb)]
        let snapshot = ledger.snapshot(now: date(11, 15, 9), calendar: calendar)
        XCTAssertEqual(snapshot.today, 2 * gb, accuracy: accuracy)
        XCTAssertEqual(snapshot.lastMonth!, 21 * gb, accuracy: accuracy)
        XCTAssertEqual(snapshot.bars[14].isToday, true)
        XCTAssertEqual(snapshot.bars[15].isFuture, true)
        XCTAssertEqual(snapshot.bars[13].isFuture, false)
    }

    func testLastMonthIsNilWhenHistoryIsNotAdjacent() {
        var ledger = Ledger()
        ledger.month = MonthKey(year: 2026, month: 11)
        ledger.history = [MonthTotal(month: MonthKey(year: 2026, month: 8), bytes: 1)]
        XCTAssertNil(ledger.snapshot(now: date(11, 15), calendar: calendar).lastMonth)
    }

    func testStatusTextCombinesFlags() {
        var ledger = Ledger()
        ledger.month = MonthKey(year: 2026, month: 11)
        XCTAssertEqual(ledger.snapshot(now: date(11, 15), calendar: calendar).statusText, "実測")
        ledger.basis = .estimate
        ledger.hasGap = true
        XCTAssertEqual(ledger.snapshot(now: date(11, 15), calendar: calendar).statusText, "推定・未計測あり")
    }

    func testDemoLedgerMatchesApprovedDesign() {
        let now = date(11, 15, 23)
        let snapshot = Ledger.demo(now: now, calendar: calendar).snapshot(now: now, calendar: calendar)
        XCTAssertEqual(snapshot.total, 12.4 * gb, accuracy: accuracy)
        XCTAssertEqual(snapshot.today, 0.9 * gb, accuracy: accuracy)
        XCTAssertEqual(snapshot.lastMonth!, 21.3 * gb, accuracy: accuracy)
    }
}
