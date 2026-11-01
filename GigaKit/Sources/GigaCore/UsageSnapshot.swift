import Foundation

public struct DayBar: Equatable, Identifiable, Sendable {
    public let day: Int
    public let bytes: Double
    public let isToday: Bool
    public let isFuture: Bool
    public let isEstimated: Bool

    public var id: Int { day }
}

public struct UsageSnapshot: Equatable, Sendable {
    public let month: Int
    public let total: Double
    public let today: Double
    public let lastMonth: Double?
    public let forecast: Double?
    public let dailyPace: Double
    public let bars: [DayBar]
    public let basis: UsageBasis
    public let hasGap: Bool
    public let isLowerBound: Bool
    public let lastRecorded: Date?
}

public struct GaugeScale: Equatable, Sendable {
    public let used: Double
    public let forecast: Double
    public let lastMonth: Double?

    public init(total: Double, forecast: Double?, lastMonth: Double?) {
        // 比べる値が無い間は満タンに見せない
        let projected = forecast ?? total
        let top = max(total, projected, lastMonth ?? 0)
        guard top > 0, forecast != nil || lastMonth != nil else {
            used = 0
            self.forecast = 0
            self.lastMonth = nil
            return
        }
        used = total / top
        self.forecast = projected / top
        self.lastMonth = lastMonth.map { $0 / top }
    }
}

extension UsageSnapshot {
    public var statusText: String {
        var parts: [String] = []
        switch basis {
        case .measured: parts.append("実測")
        case .sinceBoot: parts.append("再起動以降の実測")
        case .estimate: parts.append("推定")
        case .carrier: parts.append("キャリア値で補正済み")
        }
        if isLowerBound { parts.append("最低でもこの量") }
        if hasGap { parts.append("未計測あり") }
        return parts.joined(separator: "・")
    }
}

extension Ledger {
    private static let secondsPerDay: TimeInterval = 24 * 60 * 60

    public func snapshot(now: Date, calendar: Calendar) -> UsageSnapshot {
        let key = month ?? MonthKey(date: now, calendar: calendar)
        let dayCount = key.dayCount(calendar: calendar)
        let isCurrentMonth = key == MonthKey(date: now, calendar: calendar)
        let todayNumber = isCurrentMonth ? calendar.component(.day, from: now) : dayCount
        let total = self.total

        let periodStart = sinceBootDate ?? key.startDate(calendar: calendar)
        let elapsedDays = now.timeIntervalSince(periodStart) / Self.secondsPerDay
        let pace = elapsedDays >= 1 ? total / elapsedDays : nil

        let bars = (1...dayCount).map { day in
            DayBar(
                day: day,
                bytes: dailyBytes[day] ?? 0,
                isToday: day == todayNumber,
                isFuture: day > todayNumber,
                isEstimated: estimatedDays.contains(day)
            )
        }

        return UsageSnapshot(
            month: key.month,
            total: total,
            today: isCurrentMonth ? dailyBytes[todayNumber] ?? 0 : 0,
            lastMonth: history.last(where: { $0.month.next == key })?.bytes,
            forecast: pace.map { max(total, $0 * Double(dayCount)) },
            dailyPace: pace ?? 0,
            bars: bars,
            basis: basis,
            hasGap: hasGap,
            isLowerBound: isLowerBound,
            lastRecorded: last?.date
        )
    }
}
