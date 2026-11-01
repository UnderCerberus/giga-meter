import BackgroundTasks
import ProbeKit
import SwiftUI

private let refreshTaskId = "com.undercerberus.gigaprobe.refresh"

private func scheduleRefresh() {
    let request = BGAppRefreshTaskRequest(identifier: refreshTaskId)
    request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
    try? BGTaskScheduler.shared.submit(request)
}

@main
struct ProbeApp: App {
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { scheduleRefresh() }
        }
        .backgroundTask(.appRefresh(refreshTaskId)) {
            try? ProbeRecorder.record(trigger: .background, note: nil, store: ProbeStore.shared())
            scheduleRefresh()
        }
    }
}
