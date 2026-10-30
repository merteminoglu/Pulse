import Darwin
import XCTest
@testable import Pulse

final class NetworkDeltaTests: XCTestCase {
    private let upNonLoopbackFlags = Int32(IFF_UP)

    func testExcludedPrefixes() {
        XCTAssertTrue(NetworkSampler.shouldIncludeInterface(name: "en0", flags: upNonLoopbackFlags))
        XCTAssertTrue(NetworkSampler.shouldIncludeInterface(name: "en1", flags: upNonLoopbackFlags))

        for prefix in ["lo0", "awdl0", "llw0", "utun0", "bridge0", "gif0", "stf0", "anpi0", "ap1"] {
            XCTAssertFalse(
                NetworkSampler.shouldIncludeInterface(name: prefix, flags: upNonLoopbackFlags),
                "Expected \(prefix) to be excluded"
            )
        }

        XCTAssertFalse(NetworkSampler.shouldIncludeInterface(name: "en0", flags: 0))
        XCTAssertFalse(NetworkSampler.shouldIncludeInterface(name: "en0", flags: Int32(IFF_UP | IFF_LOOPBACK)))
    }

    func testCounterResetProducesZeroDeltaAndRebaselines() {
        var counters = [
            RawInterfaceCounters(name: "en0", flags: upNonLoopbackFlags, rxBytes: 10_000, txBytes: 5_000, baudrate: 0)
        ]
        let sampler = NetworkSampler(
            countersProvider: { counters },
            primaryProvider: { _ in
                InterfaceInfo(bsdName: "en0", kind: .wifi, ssid: nil, localIPv4: "192.168.1.2", linkSpeedMbps: 1200)
            }
        )

        let t0 = ContinuousClock.now
        XCTAssertNil(sampler.sample(now: t0))

        // Counter decreased (interface reset) -> delta 0, rebaseline
        counters = [
            RawInterfaceCounters(name: "en0", flags: upNonLoopbackFlags, rxBytes: 2_000, txBytes: 1_000, baudrate: 0)
        ]
        let s1 = sampler.sample(now: t0.advanced(by: .seconds(1)))
        XCTAssertNotNil(s1)
        XCTAssertEqual(s1?.rxPerSec ?? -1, 0, accuracy: 0.001)
        XCTAssertEqual(s1?.txPerSec ?? -1, 0, accuracy: 0.001)

        // Subsequent normal increment uses new baseline (2_000 -> 3_500 = 1_500 B/s)
        counters = [
            RawInterfaceCounters(name: "en0", flags: upNonLoopbackFlags, rxBytes: 3_500, txBytes: 1_500, baudrate: 0)
        ]
        let s2 = sampler.sample(now: t0.advanced(by: .seconds(2)))
        XCTAssertEqual(s2?.rxPerSec ?? 0, 1_500, accuracy: 0.001)
        XCTAssertEqual(s2?.txPerSec ?? 0, 500, accuracy: 0.001)
    }

    func testGapGreaterThanFiveSecondsDiscardsSample() {
        var counters = [
            RawInterfaceCounters(name: "en0", flags: upNonLoopbackFlags, rxBytes: 1_000, txBytes: 1_000, baudrate: 0)
        ]
        let sampler = NetworkSampler(
            countersProvider: { counters },
            primaryProvider: { _ in nil }
        )

        let t0 = ContinuousClock.now
        XCTAssertNil(sampler.sample(now: t0))

        counters = [
            RawInterfaceCounters(name: "en0", flags: upNonLoopbackFlags, rxBytes: 50_000, txBytes: 20_000, baudrate: 0)
        ]
        // 6 seconds elapsed -> discarded, returns nil, rebaselines
        XCTAssertNil(sampler.sample(now: t0.advanced(by: .seconds(6))))

        counters = [
            RawInterfaceCounters(name: "en0", flags: upNonLoopbackFlags, rxBytes: 52_000, txBytes: 21_000, baudrate: 0)
        ]
        let valid = sampler.sample(now: t0.advanced(by: .seconds(7)))
        XCTAssertNotNil(valid)
        XCTAssertEqual(valid?.rxPerSec ?? 0, 2_000, accuracy: 0.001)
        XCTAssertEqual(valid?.txPerSec ?? 0, 1_000, accuracy: 0.001)
    }
}
