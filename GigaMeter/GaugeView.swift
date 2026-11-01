import GigaCore
import SwiftUI

struct GaugeView: View {
    private static let size: CGFloat = 264
    private static let lineWidth: CGFloat = 18

    let scale: GaugeScale
    let total: Double
    let status: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drawn: Double = 0
    @State private var projected: Double = 0

    private var radius: CGFloat { (Self.size - Self.lineWidth) / 2 }
    private var usedFraction: Double { scale.used * drawn }
    private var arcStyle: StrokeStyle { StrokeStyle(lineWidth: Self.lineWidth, lineCap: .round) }

    var body: some View {
        ZStack {
            RadialGradient(
                colors: [Theme.accent.opacity(0.10), .clear],
                center: .center,
                startRadius: 40,
                endRadius: Self.size * 0.72
            )
            .frame(width: Self.size * 1.4, height: Self.size * 1.4)
            .opacity(drawn)

            Circle()
                .stroke(Theme.track, lineWidth: Self.lineWidth)

            Circle()
                .trim(from: 0, to: scale.forecast * projected)
                .stroke(Theme.accent.opacity(0.22), style: arcStyle)
                .rotationEffect(.degrees(-90))

            if let lastMonth = scale.lastMonth {
                lastMonthTick(at: lastMonth)
            }

            Circle()
                .trim(from: 0, to: usedFraction)
                .stroke(
                    AngularGradient(
                        colors: [Theme.accentDeep, Theme.accent],
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(360 * max(scale.used, 0.01))
                    ),
                    style: arcStyle
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: Theme.accent.opacity(0.45), radius: 12)

            if scale.used > 0 {
                head
            }

            VStack(spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    CountingNumber(bytes: total * drawn)
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                    Text("GB")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.textSecondary)
                }
                Text(status)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.accent)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: Self.size - 70)
            }
        }
        .frame(width: Self.size, height: Self.size)
        .padding(.vertical, 6)
        .animation(.smooth(duration: 0.8), value: scale)
        .animation(.smooth(duration: 0.8), value: total)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("今月の使用量 \(GBFormat.string(bytes: total))ギガバイト、\(status)")
        .onAppear(perform: playIntro)
    }

    private var head: some View {
        Circle()
            .fill(Theme.textPrimary)
            .frame(width: 8, height: 8)
            .phaseAnimator(reduceMotion ? [false] : [false, true]) { dot, bright in
                dot
                    .scaleEffect(bright ? 1.25 : 0.9)
                    .opacity(bright ? 1 : 0.7)
            } animation: { _ in
                .easeInOut(duration: 1.4)
            }
            .offset(y: -radius)
            .rotationEffect(.degrees(360 * usedFraction))
            .opacity(drawn)
    }

    private func lastMonthTick(at fraction: Double) -> some View {
        Capsule()
            .fill(Theme.textPrimary.opacity(0.85))
            .frame(width: 3, height: Self.lineWidth + 8)
            .offset(y: -radius)
            .rotationEffect(.degrees(360 * fraction))
            .opacity(projected)
    }

    private func playIntro() {
        guard !reduceMotion else {
            drawn = 1
            projected = 1
            return
        }
        withAnimation(.timingCurve(0.16, 0.84, 0.24, 1, duration: 1.4).delay(0.1)) {
            drawn = 1
        }
        withAnimation(.timingCurve(0.3, 0.7, 0.2, 1, duration: 1.1).delay(0.75)) {
            projected = 1
        }
    }
}

private struct CountingNumber: View, Animatable {
    var bytes: Double

    var animatableData: Double {
        get { bytes }
        set { bytes = newValue }
    }

    var body: some View {
        Text(GBFormat.string(bytes: bytes))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.6)
    }
}
