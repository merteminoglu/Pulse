import Darwin
import Foundation

struct ProcessUsage: Identifiable, Equatable {
    let id: pid_t
    let name: String
    let bundleID: String?
    let cpuPercent: Double              // may exceed 100 (multi-core), Activity Monitor convention
    let memoryBytes: UInt64             // phys_footprint

    init(
        id: pid_t,
        name: String,
        bundleID: String?,
        cpuPercent: Double,
        memoryBytes: UInt64
    ) {
        self.id = id
        self.name = name
        self.bundleID = bundleID
        self.cpuPercent = cpuPercent.isFinite ? max(0, cpuPercent) : 0
        self.memoryBytes = memoryBytes
    }
}
