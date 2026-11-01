import Foundation

extension Ledger {
    // 画面確認用の見本。11月15日時点で12.4GB、先月21.3GB
    public static func demo(now: Date, calendar: Calendar) -> Ledger {
        var ledger = Ledger()
        let key = MonthKey(date: now, calendar: calendar)
        let gigabytes = [0.6, 0.9, 1.2, 0.4, 0.7, 1.1, 0.8, 0.5, 1.3, 0.6, 0.9, 0.7, 1.0, 0.8, 0.9]
        ledger.month = key
        ledger.dailyBytes = Dictionary(
            uniqueKeysWithValues: gigabytes.enumerated().map { ($0.offset + 1, $0.element * 1_000_000_000) }
        )
        let previous = key.month == 1
            ? MonthKey(year: key.year - 1, month: 12)
            : MonthKey(year: key.year, month: key.month - 1)
        ledger.history = [MonthTotal(month: previous, bytes: 21_300_000_000)]
        ledger.last = LastReading(date: now, bootTime: now, counters: [:])
        return ledger
    }
}
