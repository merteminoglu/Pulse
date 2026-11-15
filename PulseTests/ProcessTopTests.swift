import XCTest
@testable import Pulse

/// Pins the ordering of the top-N selection against a full sort (the
/// original implementation): value descending, ties by name ascending.
final class ProcessTopTests: XCTestCase {
    private func referenceByCPU(_ list: [ProcessUsage], limit: Int) -> [ProcessUsage] {
        Array(list.sorted {
            if $0.cpuPercent != $1.cpuPercent { return $0.cpuPercent > $1.cpuPercent }
            return $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }.prefix(limit))
    }

    private func referenceByMemory(_ list: [ProcessUsage], limit: Int) -> [ProcessUsage] {
        Array(list.sorted {
            if $0.memoryBytes != $1.memoryBytes { return $0.memoryBytes > $1.memoryBytes }
            return $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }.prefix(limit))
    }

    /// Twelve entries, six at 0% CPU, distinct names, some memory ties.
    private let fixture: [ProcessUsage] = {
        let rows: [(String, Double, UInt64)] = [
            ("Safari", 12.5, 900), ("kernel_task", 0, 2_000), ("Mail", 3.0, 400),
            ("WindowServer", 25.0, 1_200), ("bird", 0, 50), ("Finder", 0.4, 300),
            ("cloudd", 0, 400), ("Xcode", 3.0, 3_000), ("app10", 0, 100),
            ("app2", 0, 100), ("Pulse", 0.9, 30), ("zsh", 0, 10),
        ]
        return rows.enumerated().map { i, row in
            ProcessUsage(id: pid_t(100 + i), name: row.0, bundleID: nil, cpuPercent: row.1, memoryBytes: row.2)
        }
    }()

    func testTopByCPUMatchesFullSort() {
        XCTAssertEqual(ProcessSampler.topByCPU(fixture, limit: 5), referenceByCPU(fixture, limit: 5))
    }

    func testTopByMemoryMatchesFullSort() {
        XCTAssertEqual(ProcessSampler.topByMemory(fixture, limit: 5), referenceByMemory(fixture, limit: 5))
    }

    func testLimitLargerThanList() {
        let top = ProcessSampler.topByCPU(fixture, limit: 50)
        XCTAssertEqual(top.count, 12)
        XCTAssertEqual(top, referenceByCPU(fixture, limit: 50))
        XCTAssertEqual(ProcessSampler.topByMemory(fixture, limit: 50), referenceByMemory(fixture, limit: 50))
    }

    func testEmptyList() {
        XCTAssertEqual(ProcessSampler.topByCPU([], limit: 5), [])
        XCTAssertEqual(ProcessSampler.topByMemory([], limit: 5), [])
    }

    func testAllTiedOrdersByName() {
        let tied = fixture.map {
            ProcessUsage(id: $0.id, name: $0.name, bundleID: nil, cpuPercent: 0, memoryBytes: 1)
        }
        XCTAssertEqual(ProcessSampler.topByCPU(tied, limit: 3), referenceByCPU(tied, limit: 3))
        XCTAssertEqual(ProcessSampler.topByMemory(tied, limit: 3), referenceByMemory(tied, limit: 3))
    }
}
