import ProbeKit
import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var samples: [ProbeSample] = []
    @State private var current: [InterfaceCounter] = []
    @State private var bootTime = Date()
    @State private var note = ""
    @State private var errorText: String?
    @State private var csvURL: URL?

    private let store = ProbeStore.shared()

    var body: some View {
        NavigationStack {
            List {
                Section("状態") {
                    LabeledContent("App Group", value: store.isShared ? "OK" : "NG")
                    LabeledContent("バンドルID", value: Bundle.main.bundleIdentifier ?? "不明")
                    LabeledContent("許可グループ", value: allowedGroups)
                    LabeledContent("起動時刻", value: bootTime.formatted(date: .abbreviated, time: .standard))
                    LabeledContent("記録数", value: String(samples.count))
                    if let errorText {
                        Text(errorText).foregroundStyle(.red)
                    }
                }
                Section("現在のカウンタ") {
                    ForEach(current, id: \.name) { counter in
                        VStack(alignment: .leading) {
                            Text(counter.name).font(.headline)
                            Text("32bit 受信 \(gb(UInt64(counter.in32))) 送信 \(gb(UInt64(counter.out32)))")
                            Text("64bit 受信 \(gb(counter.in64)) 送信 \(gb(counter.out64))")
                        }
                        .font(.footnote.monospacedDigit())
                    }
                }
                Section("手動記録") {
                    TextField("メモ(例: 機内モードON)", text: $note)
                    Button("今すぐ記録") {
                        record(.manual, note: note.isEmpty ? nil : note)
                        note = ""
                    }
                }
                Section("書き出し") {
                    if let csvURL {
                        ShareLink("CSVを共有", item: csvURL)
                    }
                }
                Section("履歴(新しい順に50件)") {
                    ForEach(Array(samples.suffix(50).reversed().enumerated()), id: \.offset) { _, sample in
                        VStack(alignment: .leading) {
                            Text("\(sample.date.formatted(date: .numeric, time: .standard)) \(sample.trigger.rawValue)")
                            if let note = sample.note {
                                Text(note).foregroundStyle(.secondary)
                            }
                        }
                        .font(.footnote)
                    }
                }
            }
            .navigationTitle("GigaProbe")
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            if phase == .active { record(.app, note: nil) }
        }
    }

    private var allowedGroups: String {
        let groups = ProvisioningProfile.currentAppGroups()
        return groups.isEmpty ? "なし" : groups.joined(separator: ", ")
    }

    private func record(_ trigger: ProbeTrigger, note: String?) {
        do {
            try ProbeRecorder.record(trigger: trigger, note: note, store: store)
            errorText = nil
        } catch {
            errorText = error.localizedDescription
        }
        samples = store.load()
        current = CounterReader.readTargets()
        bootTime = CounterReader.bootTime()
        writeCSV()
    }

    private func writeCSV() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("gigaprobe.csv")
        do {
            try ProbeCSV.make(samples: samples).write(to: url, atomically: true, encoding: .utf8)
            csvURL = url
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func gb(_ bytes: UInt64?) -> String {
        guard let bytes else { return "取得不可" }
        return String(format: "%.3fGB", Double(bytes) / 1_000_000_000)
    }
}
