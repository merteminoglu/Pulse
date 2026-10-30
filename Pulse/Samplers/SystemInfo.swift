import Darwin
import Foundation
import IOKit

enum SystemInfo {
    static let chipName: String = {
        if let brand = sysctlString("machdep.cpu.brand_string"), !brand.isEmpty {
            return brand
        }
        return "Apple Silicon"
    }()

    static let coreLayout: CoreLayout = {
        let perf = sysctlInt("hw.perflevel0.logicalcpu") ?? 0
        let eff = sysctlInt("hw.perflevel1.logicalcpu") ?? 0
        if perf + eff > 0 {
            return CoreLayout(performance: perf, efficiency: eff)
        }
        let total = sysctlInt("hw.logicalcpu") ?? ProcessInfo.processInfo.activeProcessorCount
        return CoreLayout(performance: total, efficiency: 0)
    }()

    static let gpuCoreCount: Int? = {
        let matching = IOServiceMatching("IOAccelerator")
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else {
            return nil
        }
        defer { IOObjectRelease(iterator) }

        var service = IOIteratorNext(iterator)
        while service != 0 {
            defer {
                IOObjectRelease(service)
                service = IOIteratorNext(iterator)
            }
            if let prop = IORegistryEntryCreateCFProperty(
                service,
                "gpu-core-count" as CFString,
                kCFAllocatorDefault,
                0
            )?.takeRetainedValue() as? NSNumber {
                let count = prop.intValue
                if count > 0 { return count }
            }
        }
        return nil
    }()

    static let physicalMemory: UInt64 = {
        var size: UInt64 = 0
        var len = MemoryLayout<UInt64>.size
        if sysctlbyname("hw.memsize", &size, &len, nil, 0) == 0, size > 0 {
            return size
        }
        return ProcessInfo.processInfo.physicalMemory
    }()

    static var bootTime: Date {
        var tv = timeval()
        var len = MemoryLayout<timeval>.size
        var mib: [Int32] = [CTL_KERN, KERN_BOOTTIME]
        if sysctl(&mib, 2, &tv, &len, nil, 0) == 0, tv.tv_sec > 0 {
            return Date(timeIntervalSince1970: TimeInterval(tv.tv_sec) + TimeInterval(tv.tv_usec) / 1_000_000.0)
        }
        return Date(timeIntervalSinceNow: -ProcessInfo.processInfo.systemUptime)
    }

    static var uptimeSeconds: TimeInterval {
        max(0, Date().timeIntervalSince(bootTime))
    }

    private static func sysctlString(_ name: String) -> String? {
        var len: Int = 0
        guard sysctlbyname(name, nil, &len, nil, 0) == 0, len > 0 else { return nil }
        var buf = [CChar](repeating: 0, count: len)
        guard sysctlbyname(name, &buf, &len, nil, 0) == 0 else { return nil }
        return String(cString: buf).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func sysctlInt(_ name: String) -> Int? {
        var val: Int32 = 0
        var len = MemoryLayout<Int32>.size
        guard sysctlbyname(name, &val, &len, nil, 0) == 0 else { return nil }
        return Int(val)
    }
}
