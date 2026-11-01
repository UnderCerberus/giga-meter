import GigaCore
import SwiftUI

struct DailyBars: View {
    private static let chartHeight: CGFloat = 92
    private static let minimumBar: CGFloat = 3
    // わずかな通信で棒が満タンに見えないよう、目盛りの上限は最低1GBにする
    private static let minimumPeak = 1_000_000_000.0

    let snapshot: UsageSnapshot

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var grown = false
    @State private var selectedDay: Int?

    private var peak: Double {
        max(snapshot.bars.map(\.bytes).max() ?? 0, snapshot.dailyPace, Self.minimumPeak)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            caption
            chart
            HStack {
                Text("1日")
                Spacer()
                Text("\(snapshot.bars.count)日")
            }
            .font(.caption2)
            .foregroundStyle(Theme.textSecondary)
        }
        .padding(16)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onAppear { grown = true }
        .sensoryFeedback(.selection, trigger: selectedDay)
    }

    private var caption: some View {
        Group {
            if let day = selectedDay, let bar = snapshot.bars.first(where: { $0.day == day }) {
                Text("\(snapshot.month)月\(day)日  \(bar.isFuture ? "—" : GBFormat.string(bytes: bar.bytes) + "GB")\(bar.isEstimated ? "  推定配分" : "")")
                    .foregroundStyle(Theme.accent)
            } else {
                Text("日別")
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .font(.system(size: 13, weight: .semibold, design: .rounded))
        .monospacedDigit()
    }

    private var chart: some View {
        GeometryReader { proxy in
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(snapshot.bars) { bar in
                    barView(bar)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .bottom)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let ratio = value.location.x / max(proxy.size.width, 1)
                        let index = min(max(Int(ratio * CGFloat(snapshot.bars.count)), 0), snapshot.bars.count - 1)
                        selectedDay = snapshot.bars[index].day
                    }
                    .onEnded { _ in selectedDay = nil }
            )
        }
        .frame(height: Self.chartHeight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("日別の使用量グラフ。今日は\(GBFormat.string(bytes: snapshot.today))ギガバイト")
    }

    private func barView(_ bar: DayBar) -> some View {
        let value = bar.isFuture ? snapshot.dailyPace : bar.bytes
        let height = max(Self.minimumBar, Self.chartHeight * value / peak)
        let dimmed = selectedDay != nil && selectedDay != bar.day

        return RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(bar.isFuture ? Theme.track : Theme.accent)
            .opacity((bar.isEstimated ? 0.55 : 1) * (dimmed ? 0.35 : 1))
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .modifier(TodayPulse(active: bar.isToday && !reduceMotion))
            .scaleEffect(y: grown || reduceMotion ? 1 : 0.02, anchor: .bottom)
            .animation(
                .spring(response: 0.55, dampingFraction: 0.72).delay(0.45 + Double(bar.day) * 0.016),
                value: grown
            )
            .animation(.smooth(duration: 0.5), value: height)
            .animation(.easeOut(duration: 0.15), value: dimmed)
    }
}

private struct TodayPulse: ViewModifier {
    let active: Bool

    func body(content: Content) -> some View {
        if active {
            content.phaseAnimator([false, true]) { view, faded in
                view.opacity(faded ? 0.55 : 1)
            } animation: { _ in
                .easeInOut(duration: 1.3)
            }
        } else {
            content
        }
    }
}
