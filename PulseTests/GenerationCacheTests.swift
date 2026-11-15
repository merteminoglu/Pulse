import XCTest
@testable import Pulse

final class GenerationCacheTests: XCTestCase {
    func testHitDoesNotRebuild() {
        var cache = GenerationCache<String, Int>(generationSize: 4)
        var builds = 0
        XCTAssertEqual(cache.value(for: "a") { builds += 1; return 1 }, 1)
        XCTAssertEqual(cache.value(for: "a") { builds += 1; return 2 }, 1)
        XCTAssertEqual(builds, 1)
    }

    func testCountIsBounded() {
        var cache = GenerationCache<Int, Int>(generationSize: 4)
        for key in 0..<40 {
            _ = cache.value(for: key) { key }
            XCTAssertLessThanOrEqual(cache.count, 8)
        }
    }

    func testRecentlyUsedKeySurvivesRotation() {
        var cache = GenerationCache<String, Int>(generationSize: 4)
        var buildsOfA = 0
        for key in 0..<40 {
            _ = cache.value(for: "a") { buildsOfA += 1; return 0 }
            _ = cache.value(for: "k\(key)") { key }
        }
        XCTAssertEqual(buildsOfA, 1)
    }
}
