import GigaCore
import SwiftUI

struct MainView: View {
    private static let liveInterval: Duration = .seconds(15)

    @Environment(MeterModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase
    @State private var showsDiagnostics = false
    @State private var refreshCount = 0

    private var snapshot: UsageSnapshot { model.snapshot }

    var body: some View {
        @Bindable var model = model

        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 22) {
                    header.reveal(delay: 0)
                    if model.wasReset { resetNotice }
                    GaugeView(
                        scale: GaugeScale(
                            total: snapshot.total,
                            forecast: snapshot.forecast,
                            lastMonth: snapshot.lastMonth
                        ),
                        total: snapshot.total,
                        status: snapshot.statusText
                    )
                    StatCards(snapshot: snapshot)
                    DailyBars(snapshot: snapshot).reveal(delay: 0.5)
                    footer.reveal(delay: 0.7)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .refreshable {
                model.measure(trigger: .app)
                refreshCount += 1
            }
        }
        .sensoryFeedback(.success, trigger: refreshCount)
        .onChange(of: scenePhase, initial: true) { _, phase in
            if phase == .active { model.measure(trigger: .app) }
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.liveInterval)
                if scenePhase == .active { model.refreshLive() }
            }
        }
        .sheet(isPresented: $model.showsCarrierSheet) {
            CarrierSheet(mode: .correction)
        }
        .sheet(isPresented: $model.showsOnboarding) {
            CarrierSheet(mode: .onboarding)
        }
        .sheet(isPresented: $showsDiagnostics) {
            DiagnosticsView(probe: model.probeStore)
        }
    }

    private var header: some View {
        HStack {
            Text("\(snapshot.month)月の使用量")
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            Button {
                showsDiagnostics = true
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.body.weight(.medium))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 40, height: 40)
                    .background(Theme.surface, in: Circle())
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel("診断")
        }
    }

    private var resetNotice: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle")
            Text("記録を読み込めなかったため、リセットした")
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("閉じる") { model.dismissResetNotice() }
        }
        .font(.footnote)
        .foregroundStyle(Theme.textPrimary)
        .padding(14)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var footer: some View {
        VStack(spacing: 14) {
            Button {
                model.showsCarrierSheet = true
            } label: {
                Text("キャリアの数字に合わせる")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(PressableStyle())

            if let recorded = snapshot.lastRecorded {
                Text("最終記録 \(recorded.formatted(date: .omitted, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .contentTransition(.numericText())
            }
        }
    }
}
