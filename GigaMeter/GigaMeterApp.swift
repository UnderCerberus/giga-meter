import BackgroundTasks
import SwiftUI

private let refreshTaskId = "com.undercerberus.gigameter.refresh"

private func scheduleRefresh() {
    let request = BGAppRefreshTaskRequest(identifier: refreshTaskId)
    request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
    try? BGTaskScheduler.shared.submit(request)
}

@main
struct GigaMeterApp: App {
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            MainView()
                .environment(MeterModel.shared)
                .preferredColorScheme(.dark)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { scheduleRefresh() }
        }
        .backgroundTask(.appRefresh(refreshTaskId)) {
            await MeterModel.shared.measure(trigger: .background)
            scheduleRefresh()
        }
    }
}
