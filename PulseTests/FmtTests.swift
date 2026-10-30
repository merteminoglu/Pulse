import XCTest
@testable import Pulse

final class FmtTests: XCTestCase {
    func testRateFormatting() {
        XCTAssertEqual(Fmt.rate(0), "0 B/s")
        XCTAssertEqual(Fmt.rate(999), "999 B/s")
        XCTAssertEqual(Fmt.rate(1_000), "1.0 KB/s")
        XCTAssertEqual(Fmt.rate(99_900), "99.9 KB/s")
        XCTAssertEqual(Fmt.rate(100_000), "100 KB/s")
        XCTAssertEqual(Fmt.rate(402_000), "402 KB/s")
        XCTAssertEqual(Fmt.rate(1_000_000), "1.0 MB/s")
        XCTAssertEqual(Fmt.rate(100_000_000), "100 MB/s")
    }

    func testUptimeFormatting() {
        XCTAssertEqual(Fmt.uptime(0), "0d 0h 0m")
        XCTAssertEqual(Fmt.uptime(59), "0d 0h 0m")
        XCTAssertEqual(Fmt.uptime(86_400), "1d 0h 0m")
        XCTAssertEqual(Fmt.uptime(3 * 86_400 + 4 * 3_600 + 12 * 60), "3d 4h 12m")
    }

    func testPercentBytesLoadAndPlaceholder() {
        XCTAssertEqual(Fmt.placeholder, "—")
        XCTAssertEqual(Fmt.percent(28.2), "28%")
        XCTAssertEqual(Fmt.percent1(29.5), "29.5%")
        XCTAssertEqual(Fmt.bytes(2_350_000_000), "2.35 GB")
        XCTAssertEqual(Fmt.bytes(423_700_000), "423.7 MB")
        XCTAssertEqual(Fmt.load(LoadAverage(one: 3.25, five: 2.86, fifteen: 2.47)), "3.25, 2.86, 2.47")
    }
}
