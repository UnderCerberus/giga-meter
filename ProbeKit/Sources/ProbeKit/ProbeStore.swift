import Foundation

public final class ProbeStore {
    public static let appGroupId = "group.com.undercerberus.gigaprobe"

    public let isShared: Bool
    private let fileURL: URL

    public init(fileURL: URL, isShared: Bool) {
        self.fileURL = fileURL
        self.isShared = isShared
    }

    // App Groupが使えない環境でも動かし、isSharedで結果を画面に出す
    public static func shared() -> ProbeStore {
        let manager = FileManager.default
        // 再署名でグループ名が変わる場合に備え、署名プロファイルのグループも試す
        for group in [appGroupId] + ProvisioningProfile.currentAppGroups() {
            if let container = manager.containerURL(forSecurityApplicationGroupIdentifier: group) {
                return ProbeStore(fileURL: container.appendingPathComponent("samples.jsonl"), isShared: true)
            }
        }
        let documents = manager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return ProbeStore(fileURL: documents.appendingPathComponent("samples.jsonl"), isShared: false)
    }

    public func append(_ sample: ProbeSample) throws {
        var line = try JSONEncoder().encode(sample)
        line.append(0x0A)

        var coordinationError: NSError?
        var writeError: Error?
        NSFileCoordinator().coordinate(writingItemAt: fileURL, options: .forMerging, error: &coordinationError) { url in
            do {
                if !FileManager.default.fileExists(atPath: url.path) {
                    FileManager.default.createFile(atPath: url.path, contents: nil)
                }
                let handle = try FileHandle(forWritingTo: url)
                defer { try? handle.close() }
                try handle.seekToEnd()
                try handle.write(contentsOf: line)
            } catch {
                writeError = error
            }
        }
        if let error = coordinationError ?? writeError { throw error }
    }

    public func load() -> [ProbeSample] {
        var data: Data?
        var coordinationError: NSError?
        NSFileCoordinator().coordinate(readingItemAt: fileURL, options: [], error: &coordinationError) { url in
            data = try? Data(contentsOf: url)
        }
        guard let data else { return [] }
        let decoder = JSONDecoder()
        return data
            .split(separator: 0x0A)
            .compactMap { try? decoder.decode(ProbeSample.self, from: Data($0)) }
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
