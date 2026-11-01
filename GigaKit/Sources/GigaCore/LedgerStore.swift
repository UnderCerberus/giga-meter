import Foundation

public final class LedgerStore {
    private let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public static func standard() -> LedgerStore {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return LedgerStore(fileURL: documents.appendingPathComponent("ledger.json"))
    }

    public func load() -> (ledger: Ledger, wasReset: Bool) {
        guard let data = try? Data(contentsOf: fileURL) else { return (Ledger(), false) }
        if let ledger = try? JSONDecoder().decode(Ledger.self, from: data) { return (ledger, false) }

        let backup = fileURL.appendingPathExtension("broken")
        try? FileManager.default.removeItem(at: backup)
        try? FileManager.default.moveItem(at: fileURL, to: backup)
        return (Ledger(), true)
    }

    public func save(_ ledger: Ledger) throws {
        try JSONEncoder().encode(ledger).write(to: fileURL, options: .atomic)
    }
}
