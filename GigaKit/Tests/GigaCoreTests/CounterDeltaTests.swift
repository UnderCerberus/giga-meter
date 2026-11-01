import XCTest
@testable import GigaCore

final class CounterDeltaTests: XCTestCase {
    private let wrap: UInt64 = 1 << 32

    func testPlainIncrease() {
        XCTAssertEqual(CounterDelta.delta(previous32: 10, current32: 15, previous64: 10, current64: 15), 5)
    }

    func test64BitSeesPastA32BitWrap() {
        let previous: UInt64 = wrap - 100
        let current: UInt64 = wrap + 400
        let delta = CounterDelta.delta(
            previous32: UInt32(truncatingIfNeeded: previous),
            current32: UInt32(truncatingIfNeeded: current),
            previous64: previous,
            current64: current
        )
        XCTAssertEqual(delta, 500)
    }

    func test64BitCountsWholeWrapsThat32BitMisses() {
        let previous: UInt64 = 1_000
        let current: UInt64 = 1_000 + wrap + 500
        let delta = CounterDelta.delta(
            previous32: UInt32(truncatingIfNeeded: previous),
            current32: UInt32(truncatingIfNeeded: current),
            previous64: previous,
            current64: current
        )
        XCTAssertEqual(delta, wrap + 500)
    }

    func testDisagreeing64BitValueIsIgnored() {
        let delta = CounterDelta.delta(previous32: 1_000, current32: 2_000, previous64: 1_000, current64: 900_000_000)
        XCTAssertEqual(delta, 1_000)
    }

    func test64BitDecreaseIsAReset() {
        let delta = CounterDelta.delta(previous32: 4_000_000_000, current32: 200, previous64: 4_000_000_000, current64: 200)
        XCTAssertEqual(delta, 200)
    }

    func testMissing64BitFallsBackTo32Bit() {
        XCTAssertEqual(CounterDelta.delta(previous32: 10, current32: 15, previous64: nil, current64: nil), 5)
    }

    func test32BitDecreaseFromLargeValueIsAWrap() {
        let previous = UInt32.max - 99
        XCTAssertEqual(CounterDelta.delta32(previous: previous, current: 400), 500)
    }

    func test32BitDecreaseFromSmallValueIsAReset() {
        XCTAssertEqual(CounterDelta.delta32(previous: 5_000, current: 400), 400)
    }
}
