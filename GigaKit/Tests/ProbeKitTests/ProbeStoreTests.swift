import XCTest
@testable import ProbeKit

final class ProbeStoreTests: XCTestCase {
    private var url: URL!
    private var store: ProbeStore!

    override func setUp() {
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("jsonl")
        store = ProbeStore(fileURL: url)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: url)
    }

    private func sample(_ seconds: TimeInterval, note: String? = nil) -> ProbeSample {
        ProbeSample(
            date: Date(timeIntervalSince1970: seconds),
            trigger: .app,
            bootTime: Date(timeIntervalSince1970: 0),
            interfaces: [InterfaceCounter(name: "pdp_ip0", in32: 10, out32: 20, in64: 30, out64: nil)],
            note: note
        )
    }

    func testLoadReturnsEmptyWhenFileIsMissing() {
        XCTAssertEqual(store.load(), [])
    }

    func testAppendKeepsOrder() throws {
        try store.append(sample(1))
        try store.append(sample(2))
        XCTAssertEqual(store.load(), [sample(1), sample(2)])
    }

    func testLoadSkipsBrokenLine() throws {
        try store.append(sample(1))
        let handle = try FileHandle(forWritingTo: url)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data("broken\n".utf8))
        try handle.close()
        try store.append(sample(2))
        XCTAssertEqual(store.load(), [sample(1), sample(2)])
    }

    func testRecordStoresOnlyTargetInterfaces() throws {
        let recorded = try ProbeRecorder.record(trigger: .manual, note: "メモ", store: store)
        XCTAssertEqual(recorded.trigger, .manual)
        XCTAssertEqual(recorded.note, "メモ")
        XCTAssertTrue(recorded.interfaces.allSatisfy { CounterReader.isTarget(name: $0.name) })
        XCTAssertEqual(store.load(), [recorded])
    }

    func testRemoveIfLargerKeepsSmallFilesAndDeletesLargeOnes() throws {
        try store.append(sample(1))
        store.removeIfLarger(thanBytes: 1_000_000)
        XCTAssertEqual(store.load().count, 1)
        store.removeIfLarger(thanBytes: 1)
        XCTAssertEqual(store.load(), [])
    }

    func testCSVHasOneRowPerInterfaceAndEscapesNote() {
        let csv = ProbeCSV.make(samples: [sample(0, note: "a,\"b\"")])
        XCTAssertEqual(
            csv,
            "date,trigger,boot_time,interface,in32,out32,in64,out64,note\n"
                + "1970-01-01T00:00:00Z,app,1970-01-01T00:00:00Z,pdp_ip0,10,20,30,,\"a,\"\"b\"\"\"\n"
        )
    }
}
