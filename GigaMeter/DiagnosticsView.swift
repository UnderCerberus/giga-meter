import ProbeKit
import SwiftUI

struct DiagnosticsView: View {
    let probe: ProbeStore

    @Environment(\.dismiss) private var dismiss
    @State private var counters: [InterfaceCounter] = []
    @State private var sampleCount = 0
    @State private var note = ""
    @State private var csvURL: URL?
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            List {
                Section("端末") {
                    LabeledContent(
                        "起動時刻",
                        value: CounterReader.bootTime().formatted(date: .abbreviated, time: .standard)
                    )
                    LabeledContent("記録数", value: String(sampleCount))
                    if let errorText {
                        Text(errorText).foregroundStyle(.red)
                    }
                }
                Section("現在のカウンタ") {
                    ForEach(counters, id: \.name) { counter in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(counter.name).font(.subheadline.weight(.semibold))
                            Text("32bit 受信 \(gigabytes(UInt64(counter.in32))) 送信 \(gigabytes(UInt64(counter.out32)))")
                            Text("64bit 受信 \(gigabytes(counter.in64)) 送信 \(gigabytes(counter.out64))")
                        }
                        .font(.caption.monospacedDigit())
                    }
                }
                Section("手動記録") {
                    TextField("メモ(例: 機内モードON)", text: $note)
                    Button("今すぐ記録", action: recordNow)
                }
                Section("書き出し") {
                    if let csvURL {
                        ShareLink("CSVを共有", item: csvURL)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("診断")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
        .tint(Theme.accent)
        .preferredColorScheme(.dark)
        .onAppear(perform: reload)
    }

    private func recordNow() {
        do {
            try ProbeRecorder.record(trigger: .manual, note: note.isEmpty ? nil : note, store: probe)
            note = ""
            errorText = nil
        } catch {
            errorText = error.localizedDescription
        }
        reload()
    }

    private func reload() {
        let samples = probe.load()
        sampleCount = samples.count
        counters = CounterReader.readTargets()

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("gigameter-diagnostics.csv")
        do {
            try ProbeCSV.make(samples: samples).write(to: url, atomically: true, encoding: .utf8)
            csvURL = url
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func gigabytes(_ bytes: UInt64?) -> String {
        guard let bytes else { return "取得不可" }
        return String(format: "%.3fGB", Double(bytes) / 1_000_000_000)
    }
}
