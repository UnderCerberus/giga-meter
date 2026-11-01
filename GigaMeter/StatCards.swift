import GigaCore
import SwiftUI

struct StatCards: View {
    let snapshot: UsageSnapshot

    var body: some View {
        HStack(spacing: 10) {
            card(
                title: "月末予測",
                value: snapshot.forecast.map { GBFormat.string(bytes: $0) },
                placeholder: "明日から"
            )
            .reveal(delay: 0.25)
            card(title: "今日", value: GBFormat.string(bytes: snapshot.today), placeholder: "")
                .reveal(delay: 0.33)
            card(
                title: "先月",
                value: snapshot.lastMonth.map { GBFormat.string(bytes: $0) },
                placeholder: "記録なし"
            )
            .reveal(delay: 0.41)
        }
    }

    private func card(title: String, value: String?, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.textSecondary)
            if let value {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(value)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Theme.textPrimary)
                        .contentTransition(.numericText())
                    Text("GB")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.textSecondary)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            } else {
                Text(placeholder)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(height: 27, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .animation(.smooth, value: value)
        .accessibilityElement(children: .combine)
    }
}
