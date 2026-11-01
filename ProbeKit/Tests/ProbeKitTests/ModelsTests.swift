import XCTest
@testable import ProbeKit

final class ModelsTests: XCTestCase {
    func testSampleRoundTripsThroughJSON() throws {
        let sample = ProbeSample(
            date: Date(timeIntervalSince1970: 1000),
            trigger: .widget,
            bootTime: Date(timeIntervalSince1970: 500),
            interfaces: [
                InterfaceCounter(name: "pdp_ip0", in32: 1, out32: 2, in64: 3, out64: nil),
            ],
            note: "機内モードON"
        )
        let data = try JSONEncoder().encode(sample)
        XCTAssertEqual(try JSONDecoder().decode(ProbeSample.self, from: data), sample)
    }
}
