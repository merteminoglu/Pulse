import Darwin
import Foundation

struct RawMemoryStats: Equatable {
    let totalBytes: UInt64
    let pageSize: UInt64
    let internalPages: UInt64
    let purgeablePages: UInt64
    let wiredPages: UInt64
    let compressorPages: UInt64
    let swapUsedBytes: UInt64
    let kernelPressureLevel: Int32
    let memoryStatusLevel: Int32        // kern.memorystatus_level (free/available level 0...100)
}

final class MemorySampler: Sampler {
    typealias StatsProvider = () -> RawMemoryStats?

    private let provider: StatsProvider

    init(provider: @escaping StatsProvider = MemorySampler.readSystemStats) {
        self.provider = provider
    }

    func reset() {}

    func sample(now: ContinuousClock.Instant) -> MemorySample? {
        guard let raw = provider() else { return nil }
        return Self.computeSample(from: raw)
    }

    static func computeSample(from raw: RawMemoryStats) -> MemorySample {
        let appPages = raw.internalPages > raw.purgeablePages
            ? (raw.internalPages - raw.purgeablePages)
            : 0
        let appBytes = appPages &* raw.pageSize
        let wiredBytes = raw.wiredPages &* raw.pageSize
        let compressedBytes = raw.compressorPages &* raw.pageSize

        let pressure = MemoryPressure.fromKernelLevel(raw.kernelPressureLevel)
        let pressurePercent = Double(100 - min(100, max(0, Int(raw.memoryStatusLevel))))

        return MemorySample(
            total: raw.totalBytes,
            app: appBytes,
            wired: wiredBytes,
            compressed: compressedBytes,
            swapUsed: raw.swapUsedBytes,
            pressure: pressure,
            pressurePercent: pressurePercent
        )
    }

    static func readSystemStats() -> RawMemoryStats? {
        var vmStats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        let kr = withUnsafeMutablePointer(to: &vmStats) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, intPtr, &count)
            }
        }
        guard kr == KERN_SUCCESS else { return nil }

        let pageSize = UInt64(vm_kernel_page_size)
        let total = SystemInfo.physicalMemory

        var swap = xsw_usage()
        var swapLen = MemoryLayout<xsw_usage>.size
        let swapUsed: UInt64
        if sysctlbyname("vm.swapusage", &swap, &swapLen, nil, 0) == 0 {
            swapUsed = swap.xsu_used
        } else {
            swapUsed = 0
        }

        var pressureLevel: Int32 = 1
        var pLen = MemoryLayout<Int32>.size
        _ = sysctlbyname("kern.memorystatus_vm_pressure_level", &pressureLevel, &pLen, nil, 0)

        var statusLevel: Int32 = 80
        var sLen = MemoryLayout<Int32>.size
        if sysctlbyname("kern.memorystatus_level", &statusLevel, &sLen, nil, 0) != 0 {
            let usedPages = (vmStats.internal_page_count > vmStats.purgeable_count
                ? vmStats.internal_page_count - vmStats.purgeable_count : 0)
                + vmStats.wire_count + vmStats.compressor_page_count
            let usedRatio = total > 0 ? Double(UInt64(usedPages) * pageSize) / Double(total) : 0
            statusLevel = Int32(clamping: Int((1.0 - usedRatio) * 100.0))
        }

        return RawMemoryStats(
            totalBytes: total,
            pageSize: pageSize,
            internalPages: UInt64(vmStats.internal_page_count),
            purgeablePages: UInt64(vmStats.purgeable_count),
            wiredPages: UInt64(vmStats.wire_count),
            compressorPages: UInt64(vmStats.compressor_page_count),
            swapUsedBytes: swapUsed,
            kernelPressureLevel: pressureLevel,
            memoryStatusLevel: statusLevel
        )
    }
}
