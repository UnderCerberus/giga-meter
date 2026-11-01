import GigaCore
import SwiftUI

struct CarrierSheet: View {
    enum Mode {
        case onboarding, correction

        var title: String {
            switch self {
            case .onboarding: "今月の使用量を入力"
            case .correction: "キャリアの数字に合わせる"
            }
        }

        var message: String {
            switch self {
            case .onboarding:
                "iPhoneは過去の通信履歴をアプリに教えてくれない。My docomoやMy auなどに出ている今月の使用量を入れると、そこから正確に数え始める。"
            case .correction:
                "My docomoやMy auなどに出ている今月の使用量を入力する。以後はこの値に足していく。"
            }
        }
    }

    let mode: Mode

    @Environment(MeterModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: Bool
    @State private var text = ""
    @State private var showsError = false
    @State private var savedCount = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(mode.title)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
                .padding(.top, 8)
                .reveal(delay: 0.05)

            Text(mode.message)
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .reveal(delay: 0.1)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                TextField("0.0", text: $text)
                    .keyboardType(.decimalPad)
                    .focused($focused)
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                    .tint(Theme.accent)
                    .monospacedDigit()
                Text("GB")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(.vertical, 4)
            .reveal(delay: 0.15)

            if showsError {
                Text("数字を入力してほしい(例: 12.4)")
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            Button(action: save) {
                Text("この値で始める")
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(Theme.background)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(Theme.accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(PressableStyle())
            .reveal(delay: 0.2)

            Button(mode == .onboarding ? "あとで入力する" : "キャンセル") {
                if mode == .onboarding { model.finishOnboarding() }
                dismiss()
            }
            .font(.subheadline)
            .foregroundStyle(Theme.textSecondary)
            .frame(maxWidth: .infinity)

            Spacer(minLength: 0)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.background)
        .preferredColorScheme(.dark)
        .sensoryFeedback(.success, trigger: savedCount)
        .onChange(of: text) { _, _ in showsError = false }
        .onAppear { focused = true }
        .onDisappear {
            if mode == .onboarding { model.finishOnboarding() }
        }
    }

    private func save() {
        guard let bytes = GBFormat.bytes(from: text) else {
            withAnimation(.smooth) { showsError = true }
            return
        }
        model.setCarrierValue(bytes: bytes)
        savedCount += 1
        dismiss()
    }
}
