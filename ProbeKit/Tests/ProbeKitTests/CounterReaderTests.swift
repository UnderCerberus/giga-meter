import XCTest
@testable import ProbeKit

final class CounterReaderTests: XCTestCase {
    func testIsTargetAcceptsCellularAndWifiOnly() {
        XCTAssertTrue(CounterReader.isTarget(name: "pdp_ip0"))
        XCTAssertTrue(CounterReader.isTarget(name: "pdp_ip3"))
        XCTAssertTrue(CounterReader.isTarget(name: "en0"))
        XCTAssertFalse(CounterReader.isTarget(name: "en1"))
        XCTAssertFalse(CounterReader.isTarget(name: "lo0"))
    }

    func testReadAllIncludesLoopback() {
        XCTAssertTrue(CounterReader.readAll().contains { $0.name == "lo0" })
    }

    // 生バイト列のオフセットが正しいことを、32ビット値との一致で確かめる
    func test64BitLowWordMatches32BitCounter() throws {
        let counters = CounterReader.readAll().filter { $0.in64 != nil && $0.out64 != nil }
        XCTAssertFalse(counters.isEmpty)
        XCTAssertTrue(counters.contains { ($0.in64 ?? 0) > 0 })
        for c in counters {
            let inDiff = UInt32(truncatingIfNeeded: try XCTUnwrap(c.in64)) &- c.in32
            let outDiff = UInt32(truncatingIfNeeded: try XCTUnwrap(c.out64)) &- c.out32
            XCTAssertLessThan(min(inDiff, 0 &- inDiff), 10_000_000, c.name)
            XCTAssertLessThan(min(outDiff, 0 &- outDiff), 10_000_000, c.name)
        }
    }

    func testBootTimeIsInThePast() {
        let boot = CounterReader.bootTime()
        XCTAssertLessThan(boot, Date())
        XCTAssertGreaterThan(boot, Date(timeIntervalSince1970: 946_684_800))
    }
}
