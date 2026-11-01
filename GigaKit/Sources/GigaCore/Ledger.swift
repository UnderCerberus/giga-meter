import Foundation
import ProbeKit

public enum UsageBasis: String, Codable, Sendable {
    case measured, sinceBoot, estimate, carrier
}

public struct MonthKey: Codable, Hashable, Comparable, Sendable {
    public let year: Int
    public let month: Int

    public init(year: Int, month: Int) {
        self.year = year
        self.month = month
    }

    public init(date: Date, calendar: Calendar) {
        let parts = calendar.dateComponents([.year, .month], from: date)
        self.init(year: parts.year ?? 0, month: parts.month ?? 1)
    }

    public var next: MonthKey {
        month == 12 ? MonthKey(year: year + 1, month: 1) : MonthKey(year: year, month: month + 1)
    }

    public static func < (lhs: MonthKey, rhs: MonthKey) -> Bool {
        (lhs.year, lhs.month) < (rhs.year, rhs.month)
    }

    func startDate(calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: 1)) ?? .distantPast
    }

    func dayCount(calendar: Calendar) -> Int {
        calendar.range(of: .day, in: .month, for: startDate(calendar: calendar))?.count ?? 30
    }
}

public struct MonthTotal: Codable, Equatable, Sendable {
    public let month: MonthKey
    public let bytes: Double

    public init(month: MonthKey, bytes: Double) {
        self.month = month
        self.bytes = bytes
    }
}

public struct CounterState: Codable, Equatable, Sendable {
    public let in32: UInt32
    public let out32: UInt32
    public let in64: UInt64?
    public let out64: UInt64?

    var total: UInt64 {
        (in64 ?? UInt64(in32)) + (out64 ?? UInt64(out32))
    }
}

public struct LastReading: Codable, Equatable, Sendable {
    public var date: Date
    public var bootTime: Date
    public var counters: [String: CounterState]
}

public struct Ledger: Codable, Equatable, Sendable {
    private static let bootTolerance: TimeInterval = 60
    private static let longInterval: TimeInterval = 24 * 60 * 60
    private static let historyLimit = 24

    public var month: MonthKey?
    public var baseBytes: Double = 0
    public var adjustment: Double = 0
    public var dailyBytes: [Int: Double] = [:]
    public var estimatedDays: Set<Int> = []
    public var history: [MonthTotal] = []
    public var last: LastReading?
    public var basis: UsageBasis = .measured
    public var sinceBootDate: Date?
    public var hasGap = false
    public var isLowerBound = false

    public init() {}

    public var total: Double {
        max(0, baseBytes + dailyBytes.values.reduce(0, +) + adjustment)
    }

    public mutating func apply(counters: [InterfaceCounter], bootTime: Date, now: Date, calendar: Calendar) {
        let current = Dictionary(
            counters
                .filter { $0.name.hasPrefix("pdp_ip") }
                .map { ($0.name, CounterState(in32: $0.in32, out32: $0.out32, in64: $0.in64, out64: $0.out64)) },
            uniquingKeysWith: { first, _ in first }
        )

        guard let last else {
            startFirstMonth(current: current, bootTime: bootTime, now: now, calendar: calendar)
            return
        }

        let rebooted = abs(bootTime.timeIntervalSince(last.bootTime)) > Self.bootTolerance
        let bytes = current.reduce(UInt64(0)) { sum, entry in
            guard !rebooted, let previous = last.counters[entry.key] else { return sum + entry.value.total }
            return sum + Self.delta(from: previous, to: entry.value)
        }

        allocate(Double(bytes), from: last.date, to: now, calendar: calendar)
        rollForward(to: MonthKey(date: now, calendar: calendar))
        if rebooted { hasGap = true }

        // 同じ起動中に消えた回線は、再び現れたときに二重計上しないよう前回値を残す
        let kept = rebooted ? [:] : last.counters
        self.last = LastReading(
            date: now,
            bootTime: bootTime,
            counters: kept.merging(current) { _, new in new }
        )
    }

    public mutating func setCarrierValue(bytes: Double) {
        adjustment = bytes - baseBytes - dailyBytes.values.reduce(0, +)
        basis = .carrier
        hasGap = false
        isLowerBound = false
        sinceBootDate = nil
    }

    private static func delta(from previous: CounterState, to current: CounterState) -> UInt64 {
        CounterDelta.delta(
            previous32: previous.in32,
            current32: current.in32,
            previous64: previous.in64,
            current64: current.in64
        ) + CounterDelta.delta(
            previous32: previous.out32,
            current32: current.out32,
            previous64: previous.out64,
            current64: current.out64
        )
    }

    private mutating func startFirstMonth(
        current: [String: CounterState],
        bootTime: Date,
        now: Date,
        calendar: Calendar
    ) {
        let key = MonthKey(date: now, calendar: calendar)
        let monthStart = key.startDate(calendar: calendar)
        let counted = Double(current.values.reduce(UInt64(0)) { $0 + $1.total })

        month = key
        isLowerBound = current.values.contains { $0.in64 == nil || $0.out64 == nil }
        if bootTime >= monthStart {
            baseBytes = counted
            basis = .sinceBoot
            sinceBootDate = bootTime
        } else {
            let sinceBoot = now.timeIntervalSince(bootTime)
            baseBytes = sinceBoot > 0 ? counted * now.timeIntervalSince(monthStart) / sinceBoot : 0
            basis = .estimate
        }
        last = LastReading(date: now, bootTime: bootTime, counters: current)
    }

    private mutating func allocate(_ bytes: Double, from start: Date, to end: Date, calendar: Calendar) {
        guard bytes > 0 else { return }
        guard end > start else {
            add(bytes, at: start, estimated: false, calendar: calendar)
            return
        }

        let duration = end.timeIntervalSince(start)
        let estimated = duration > Self.longInterval
        var cursor = start
        while cursor < end {
            let dayStart = calendar.startOfDay(for: cursor)
            let nextDay = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? end
            let segmentEnd = min(max(nextDay, cursor.addingTimeInterval(1)), end)
            let share = bytes * segmentEnd.timeIntervalSince(cursor) / duration
            add(share, at: cursor, estimated: estimated, calendar: calendar)
            cursor = segmentEnd
        }
    }

    private mutating func add(_ bytes: Double, at date: Date, estimated: Bool, calendar: Calendar) {
        let key = MonthKey(date: date, calendar: calendar)
        rollForward(to: key)
        // 時計が過去へ戻された場合は今月の初日に計上する
        let day = key == month ? calendar.component(.day, from: date) : 1
        dailyBytes[day, default: 0] += bytes
        if estimated { estimatedDays.insert(day) }
    }

    private mutating func rollForward(to key: MonthKey) {
        while let current = month, current < key {
            history.append(MonthTotal(month: current, bytes: total))
            if history.count > Self.historyLimit { history.removeFirst() }
            month = current.next
            baseBytes = 0
            adjustment = 0
            dailyBytes = [:]
            estimatedDays = []
            basis = .measured
            sinceBootDate = nil
            hasGap = false
            isLowerBound = false
        }
    }
}
