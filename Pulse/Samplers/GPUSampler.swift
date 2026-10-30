import Foundation
import IOKit

final class GPUSampler: Sampler {
    init?() {
        guard Self.readSample() != nil else {
            return nil
        }
    }

    func reset() {}

    func sample(now: ContinuousClock.Instant) -> GPUSample? {
        Self.readSample()
    }

    private struct Candidate {
        let isBuiltIn: Bool
        let sample: GPUSample
    }

    private static func readSample() -> GPUSample? {
        let matching = IOServiceMatching("IOAccelerator")
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else {
            return nil
        }
        defer { IOObjectRelease(iterator) }

        var candidates: [Candidate] = []
        var service = IOIteratorNext(iterator)
        while service != 0 {
            defer {
                IOObjectRelease(service)
                service = IOIteratorNext(iterator)
            }

            guard let stats = IORegistryEntryCreateCFProperty(
                service,
                "PerformanceStatistics" as CFString,
                kCFAllocatorDefault,
                0
            )?.takeRetainedValue() as? [String: Any], !stats.isEmpty else {
                continue
            }

            var classNameBuf = [CChar](repeating: 0, count: 128)
            IOObjectGetClass(service, &classNameBuf)
            let className = String(cString: classNameBuf)
            let ioClass = (IORegistryEntryCreateCFProperty(
                service,
                "IOClass" as CFString,
                kCFAllocatorDefault,
                0
            )?.takeRetainedValue() as? String) ?? ""

            let isBuiltIn = className.contains("AGXAccelerator") || ioClass.contains("AGXAccelerator")

            let utilization = number(in: stats, keys: [
                "Device Utilization %",
                "GPU Activity(%)",
                "GPU Core Utilization"
            ])

            let renderer = number(in: stats, keys: [
                "Renderer Utilization %",
                "SplitSceneCount" // fallback only if utilization present
            ].prefix(1).map { $0 })

            let tiler = number(in: stats, keys: [
                "Tiler Utilization %"
            ])

            let memBytes = uint64Value(in: stats, keys: [
                "In use system memory",
                "Alloc system memory",
                "vramUsedBytes"
            ])

            guard let util = utilization ?? renderer else {
                continue
            }

            let sample = GPUSample(
                utilization: util,
                renderer: renderer,
                tiler: tiler,
                memoryInUse: memBytes,
                frequencyMHz: nil,
                temperatureC: nil,
                powerW: nil
            )
            candidates.append(Candidate(isBuiltIn: isBuiltIn, sample: sample))
        }

        if let builtIn = candidates.first(where: { $0.isBuiltIn }) {
            return builtIn.sample
        }
        return candidates.max(by: { $0.sample.utilization < $1.sample.utilization })?.sample
    }

    private static func number(in dict: [String: Any], keys: [String]) -> Double? {
        for key in keys {
            if let num = dict[key] as? NSNumber {
                var val = num.doubleValue
                if key == "GPU Core Utilization" && val > 100.0 {
                    val = val / 10_000_000.0
                }
                return val
            }
        }
        return nil
    }

    private static func uint64Value(in dict: [String: Any], keys: [String]) -> UInt64? {
        for key in keys {
            if let num = dict[key] as? NSNumber {
                let v = num.int64Value
                if v >= 0 {
                    return UInt64(v)
                }
            }
        }
        return nil
    }
}
