import XCTest
@testable import Pulse

final class SampleGapTests: XCTestCase {
    func testOneSecondKeepsTodaysThreshold() {
        XCTAssertEqual(SampleGap.maxGap(forInterval: 1), .seconds(5))
    }

    func testGapScalesWithInterval() {
        XCTAssertEqual(SampleGap.maxGap(forInterval: 5), .seconds(13))
        XCTAssertEqual(SampleGap.maxGap(forInterval: 10), .seconds(23))
    }

    func testLeeway() {
        XCTAssertEqual(SampleGap.leeway(forInterval: 1), .milliseconds(200))
        XCTAssertEqual(SampleGap.leeway(forInterval: 10), .seconds(1))
    }

    @MainActor
    func testRefreshChoices() {
        XCTAssertEqual(MetricsStore.refreshChoices, [1, 2, 3, 5, 10])
    }
}
