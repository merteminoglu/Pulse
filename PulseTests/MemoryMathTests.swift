import XCTest
@testable import Pulse

final class MemoryMathTests: XCTestCase {
    func testSixteenKBPageSizeMath() {
        let pageSize: UInt64 = 16_384 // 16 KB on Apple Silicon
        let total: UInt64 = 36 * 1_073_741_824

        let raw = RawMemoryStats(
            totalBytes: total,
            pageSize: pageSize,
            internalPages: 1_000_000,
            purgeablePages: 100_000,
            wiredPages: 200_000,
            compressorPages: 100_000,
            swapUsedBytes: 512 * 1_048_576,
            kernelPressureLevel: 1,
            memoryStatusLevel: 72
        )

        let sample = MemorySampler.computeSample(from: raw)
        XCTAssertEqual(sample.app, 900_000 * pageSize)
        XCTAssertEqual(sample.wired, 200_000 * pageSize)
        XCTAssertEqual(sample.compressed, 100_000 * pageSize)
        XCTAssertEqual(sample.used, 1_200_000 * pageSize)
        XCTAssertEqual(sample.free, total - sample.used)
        XCTAssertEqual(sample.pressure, .normal)
        XCTAssertEqual(sample.pressurePercent, 28.0, accuracy: 0.001)
    }

    func testFreeNeverNegative() {
        let pageSize: UInt64 = 16_384
        let raw = RawMemoryStats(
            totalBytes: 1_000_000,
            pageSize: pageSize,
            internalPages: 500,
            purgeablePages: 0,
            wiredPages: 500,
            compressorPages: 500,
            swapUsedBytes: 0,
            kernelPressureLevel: 4,
            memoryStatusLevel: 5
        )
        let sample = MemorySampler.computeSample(from: raw)
        XCTAssertGreaterThan(sample.used, sample.total)
        XCTAssertEqual(sample.free, 0)
        XCTAssertEqual(sample.usedPercent, 100.0, accuracy: 0.001)
    }

    func testPressureLevelMapping() {
        XCTAssertEqual(MemoryPressure.fromKernelLevel(1), .normal)
        XCTAssertEqual(MemoryPressure.fromKernelLevel(2), .warning)
        XCTAssertEqual(MemoryPressure.fromKernelLevel(4), .critical)
        XCTAssertEqual(MemoryPressure.fromKernelLevel(0), .normal)
        XCTAssertEqual(MemoryPressure.fromKernelLevel(99), .normal)
    }
}
