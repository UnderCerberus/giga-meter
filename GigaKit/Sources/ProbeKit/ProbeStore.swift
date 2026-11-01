import Foundation

public final class ProbeStore {
    private let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public static func standard() -> ProbeStore {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return ProbeStore(fileURL: documents.appendingPathComponent("samples.jsonl"))
    }

    public func append(_ sample: ProbeSample) throws {
        var line = try JSONEncoder().encode(sample)
        line.append(0x0A)

        if !FileManager.default.fileExists(atPath: fileURL.path) {
            FileManager.default.createFile(atPath: fileURL.path, contents: nil)
        }
        let handle = try FileHandle(forWritingTo: fileURL)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: line)
    }

    public func load() -> [ProbeSample] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        let decoder = JSONDecoder()
        return data
            .split(separator: 0x0A)
            .compactMap { try? decoder.decode(ProbeSample.self, from: Data($0)) }
    }

    public func removeIfLarger(thanBytes limit: Int) {
        let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path)
        guard let size = attributes?[.size] as? Int, size > limit else { return }
        try? FileManager.default.removeItem(at: fileURL)
    }
}

public enum ProbeRecorder {
    @discardableResult
    public static func record(trigger: ProbeTrigger, note: String?, store: ProbeStore) throws -> ProbeSample {
        let sample = ProbeSample(
            date: Date(),
            trigger: trigger,
            bootTime: CounterReader.bootTime(),
            interfaces: CounterReader.readTargets(),
            note: note
        )
        try store.append(sample)
        return sample
    }
}
