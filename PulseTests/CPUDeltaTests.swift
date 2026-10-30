import XCTest
@testable import Pulse

final class CPUDeltaTests: XCTestCase {
    func testFirstSampleReturnsNil() {
        let ticks = [CPUTicks(user: 100, system: 50, idle: 850, nice: 0)]
        let sampler = CPUSampler(layout: CoreLayout(performance: 1, efficiency: 0)) {
            (ticks: ticks, load: LoadAverage(one: 1.0, five: 1.0, fifteen: 1.0))
        }
        let now = ContinuousClock.now
        XCTAssertNil(sampler.sample(now: now))
    }

    func testUInt32WrapSubtraction() {
        var current = [CPUTicks(user: UInt32.max - 9, system: UInt32.max - 4, idle: UInt32.max - 79, nice: 0)]
        let sampler = CPUSampler(layout: CoreLayout(performance: 1, efficiency: 0)) {
            (ticks: current, load: LoadAverage(one: 2.0, five: 1.5, fifteen: 1.2))
        }

        let t0 = ContinuousClock.now
        XCTAssertNil(sampler.sample(now: t0))

        // Wrap around UInt32.max: user delta = 20, system delta = 10, idle delta = 170 (total = 200)
        current = [CPUTicks(user: 10, system: 5, idle: 90, nice: 0)]
        let sample = sampler.sample(now: t0.advanced(by: .seconds(1)))
        XCTAssertNotNil(sample)
        XCTAssertEqual(sample?.user ?? 0, 10.0, accuracy: 0.001)
        XCTAssertEqual(sample?.system ?? 0, 5.0, accuracy: 0.001)
        XCTAssertEqual(sample?.total ?? 0, 15.0, accuracy: 0.001)
        XCTAssertEqual(sample?.idle ?? 0, 85.0, accuracy: 0.001)
    }

    func testZeroDeltaReusesPreviousSample() {
        var current = [CPUTicks(user: 100, system: 50, idle: 850, nice: 0)]
        let sampler = CPUSampler(layout: CoreLayout(performance: 1, efficiency: 0)) {
            (ticks: current, load: LoadAverage(one: 1.0, five: 1.0, fifteen: 1.0))
        }

        let t0 = ContinuousClock.now
        XCTAssertNil(sampler.sample(now: t0))

        current = [CPUTicks(user: 120, system: 60, idle: 920, nice: 0)]
        let first = sampler.sample(now: t0.advanced(by: .seconds(1)))
        XCTAssertNotNil(first)
        XCTAssertEqual(first?.total ?? 0, 30.0, accuracy: 0.001)

        // Identical ticks -> zero delta -> returns previous sample
        let second = sampler.sample(now: t0.advanced(by: .seconds(2)))
        XCTAssertEqual(second, first)
    }
}
