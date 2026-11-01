import XCTest
@testable import GigaCore

final class GaugeScaleTests: XCTestCase {
    func testScaleUsesForecastAsTop() {
        let scale = GaugeScale(total: 12, forecast: 24, lastMonth: 18)
        XCTAssertEqual(scale.used, 0.5)
        XCTAssertEqual(scale.forecast, 1)
        XCTAssertEqual(scale.lastMonth, 0.75)
    }

    func testScaleUsesLastMonthWhenItIsLargest() {
        let scale = GaugeScale(total: 10, forecast: 20, lastMonth: 40)
        XCTAssertEqual(scale.used, 0.25)
        XCTAssertEqual(scale.forecast, 0.5)
        XCTAssertEqual(scale.lastMonth, 1)
    }

    func testScaleWithNothingToCompareStaysEmpty() {
        let scale = GaugeScale(total: 10, forecast: nil, lastMonth: nil)
        XCTAssertEqual(scale.used, 0)
        XCTAssertEqual(scale.forecast, 0)
        XCTAssertNil(scale.lastMonth)
    }

    func testScaleWithoutForecastComparesToLastMonth() {
        let scale = GaugeScale(total: 10, forecast: nil, lastMonth: 20)
        XCTAssertEqual(scale.used, 0.5)
        XCTAssertEqual(scale.lastMonth, 1)
    }

    func testScaleAtZeroDoesNotDivideByZero() {
        let scale = GaugeScale(total: 0, forecast: nil, lastMonth: nil)
        XCTAssertEqual(scale.used, 0)
        XCTAssertEqual(scale.forecast, 0)
    }
}

final class GBFormatTests: XCTestCase {
    func testFormatsSmallValuesWithTwoDecimals() {
        XCTAssertEqual(GBFormat.string(bytes: 40_000_000), "0.04")
        XCTAssertEqual(GBFormat.string(bytes: 900_000_000), "0.90")
    }

    func testFormatsLargeValuesWithOneDecimal() {
        XCTAssertEqual(GBFormat.string(bytes: 12_400_000_000), "12.4")
    }

    func testNegativeShowsZero() {
        XCTAssertEqual(GBFormat.string(bytes: -5), "0.00")
    }

    func testParsesInput() {
        XCTAssertEqual(GBFormat.bytes(from: "12.4"), 12_400_000_000)
        XCTAssertEqual(GBFormat.bytes(from: " 3,5 "), 3_500_000_000)
        XCTAssertEqual(GBFormat.bytes(from: "0"), 0)
    }

    func testRejectsInvalidInput() {
        XCTAssertNil(GBFormat.bytes(from: ""))
        XCTAssertNil(GBFormat.bytes(from: "abc"))
        XCTAssertNil(GBFormat.bytes(from: "-1"))
        XCTAssertNil(GBFormat.bytes(from: "inf"))
    }
}

final class LedgerStoreTests: XCTestCase {
    private var url: URL!

    override func setUp() {
        url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: url)
        try? FileManager.default.removeItem(at: url.appendingPathExtension("broken"))
    }

    func testMissingFileStartsEmpty() {
        let result = LedgerStore(fileURL: url).load()
        XCTAssertEqual(result.ledger, Ledger())
        XCTAssertFalse(result.wasReset)
    }

    func testSaveAndLoadRoundTrip() throws {
        var ledger = Ledger()
        ledger.month = MonthKey(year: 2026, month: 11)
        ledger.dailyBytes = [3: 100]
        ledger.estimatedDays = [3]
        ledger.basis = .carrier
        let store = LedgerStore(fileURL: url)
        try store.save(ledger)
        XCTAssertEqual(store.load().ledger, ledger)
    }

    func testBrokenFileIsMovedAsideAndFlagged() throws {
        try Data("broken".utf8).write(to: url)
        let result = LedgerStore(fileURL: url).load()
        XCTAssertEqual(result.ledger, Ledger())
        XCTAssertTrue(result.wasReset)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.appendingPathExtension("broken").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }
}
