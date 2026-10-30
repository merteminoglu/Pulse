import XCTest
@testable import Pulse

final class RingBufferTests: XCTestCase {
    func testEmptyBuffer() {
        let buf = RingBuffer<Int>(capacity: 4)
        XCTAssertNil(buf.last)
        XCTAssertTrue(buf.elements.isEmpty)
        XCTAssertFalse(buf.isFull)
    }

    func testOrderAfterWrap() {
        var buf = RingBuffer<Int>(capacity: 3)
        buf.append(10)
        buf.append(20)
        XCTAssertFalse(buf.isFull)
        XCTAssertEqual(buf.elements, [10, 20])
        XCTAssertEqual(buf.last, 20)

        buf.append(30)
        XCTAssertTrue(buf.isFull)
        XCTAssertEqual(buf.elements, [10, 20, 30])
        XCTAssertEqual(buf.last, 30)

        buf.append(40)
        XCTAssertTrue(buf.isFull)
        XCTAssertEqual(buf.elements, [20, 30, 40])
        XCTAssertEqual(buf.last, 40)

        buf.append(50)
        XCTAssertEqual(buf.elements, [30, 40, 50])
        XCTAssertEqual(buf.last, 50)
    }

    func testCapacityOne() {
        var buf = RingBuffer<String>(capacity: 1)
        XCTAssertNil(buf.last)
        buf.append("a")
        XCTAssertTrue(buf.isFull)
        XCTAssertEqual(buf.elements, ["a"])
        XCTAssertEqual(buf.last, "a")

        buf.append("b")
        XCTAssertTrue(buf.isFull)
        XCTAssertEqual(buf.elements, ["b"])
        XCTAssertEqual(buf.last, "b")
    }
}
