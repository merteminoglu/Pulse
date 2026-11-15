import XCTest
@testable import Pulse

final class PauseStateTests: XCTestCase {
    func testFirstPauseStops() {
        var state = PauseState()
        XCTAssertTrue(state.pause(.displaySleep))
        XCTAssertTrue(state.isPaused)
    }

    func testSecondReasonDoesNotStopAgain() {
        var state = PauseState()
        _ = state.pause(.displaySleep)
        XCTAssertFalse(state.pause(.systemSleep))
        XCTAssertTrue(state.isPaused)
    }

    func testResumesOnlyWhenAllReasonsClear() {
        var state = PauseState()
        _ = state.pause(.displaySleep)
        _ = state.pause(.systemSleep)
        XCTAssertFalse(state.resume(.displaySleep))
        XCTAssertTrue(state.isPaused)
        XCTAssertTrue(state.resume(.systemSleep))
        XCTAssertFalse(state.isPaused)
    }

    func testDuplicatePauseIsNoOp() {
        var state = PauseState()
        XCTAssertTrue(state.pause(.displaySleep))
        XCTAssertFalse(state.pause(.displaySleep))
        XCTAssertTrue(state.resume(.displaySleep))
    }

    func testUnmatchedResumeIsNoOp() {
        var state = PauseState()
        XCTAssertFalse(state.resume(.systemSleep))
        XCTAssertFalse(state.isPaused)
    }
}
