import AppKit
import SwiftUI
import XCTest
@testable import Pulse

final class ThresholdsTests: XCTestCase {
    func testBandBoundaries() {
        XCTAssertEqual(Thresholds.band(0.0), .cruising)
        XCTAssertEqual(Thresholds.band(24.9), .cruising)
        XCTAssertEqual(Thresholds.band(25.0), .working)
        XCTAssertEqual(Thresholds.band(49.9), .working)
        XCTAssertEqual(Thresholds.band(50.0), .busy)
        XCTAssertEqual(Thresholds.band(74.9), .busy)
        XCTAssertEqual(Thresholds.band(75.0), .pegged)
        XCTAssertEqual(Thresholds.band(100.0), .pegged)
    }

    func testPanelColorBoundaries() {
        XCTAssertEqual(Thresholds.panelColor(24.9), .green)
        XCTAssertEqual(Thresholds.panelColor(25.0), .blue)
        XCTAssertEqual(Thresholds.panelColor(49.9), .blue)
        XCTAssertEqual(Thresholds.panelColor(50.0), .orange)
        XCTAssertEqual(Thresholds.panelColor(74.9), .orange)
        XCTAssertEqual(Thresholds.panelColor(75.0), .red)
    }

    func testMenuBarColorVsPanelColor() {
        let labelColor = Color(nsColor: .labelColor)
        XCTAssertEqual(Thresholds.menuBarColor(0.0), labelColor)
        XCTAssertEqual(Thresholds.menuBarColor(24.9), labelColor)
        XCTAssertEqual(Thresholds.menuBarColor(25.0), labelColor)
        XCTAssertEqual(Thresholds.menuBarColor(49.9), labelColor)
        XCTAssertEqual(Thresholds.menuBarColor(50.0), .orange)
        XCTAssertEqual(Thresholds.menuBarColor(74.9), .orange)
        XCTAssertEqual(Thresholds.menuBarColor(75.0), .red)
    }

    func testPressureColorAndLabel() {
        XCTAssertEqual(Thresholds.pressureColor(.normal), .green)
        XCTAssertEqual(Thresholds.pressureColor(.warning), .yellow)
        XCTAssertEqual(Thresholds.pressureColor(.critical), .red)

        XCTAssertEqual(Thresholds.pressureLabel(.normal), "Normal")
        XCTAssertEqual(Thresholds.pressureLabel(.warning), "Elevated")
        XCTAssertEqual(Thresholds.pressureLabel(.critical), "Critical")
    }
}
