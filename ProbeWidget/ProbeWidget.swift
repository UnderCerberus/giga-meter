import ProbeKit
import SwiftUI
import WidgetKit

struct ProbeEntry: TimelineEntry {
    let date: Date
    let isShared: Bool
    let widgetRecords: Int
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> ProbeEntry {
        ProbeEntry(date: Date(), isShared: true, widgetRecords: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping (ProbeEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ProbeEntry>) -> Void) {
        let store = ProbeStore.shared()
        try? ProbeRecorder.record(trigger: .widget, note: nil, store: store)
        let count = store.load().filter { $0.trigger == .widget }.count
        let entry = ProbeEntry(date: Date(), isShared: store.isShared, widgetRecords: count)
        completion(Timeline(entries: [entry], policy: .after(Date(timeIntervalSinceNow: 15 * 60))))
    }
}

struct ProbeWidgetView: View {
    let entry: ProbeEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("GigaProbe").font(.headline)
            Text("共有: \(entry.isShared ? "OK" : "NG")")
            Text("記録: \(entry.widgetRecords)回")
            Text(entry.date, style: .time)
        }
        .font(.caption)
    }
}

@main
struct ProbeWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ProbeWidget", provider: Provider()) { entry in
            ProbeWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("GigaProbe")
        .description("カウンタの検証用")
        .supportedFamilies([.systemSmall])
    }
}
