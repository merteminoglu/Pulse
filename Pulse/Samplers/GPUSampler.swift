import Foundation
import IOKit

final class GPUSampler: Sampler {
    /// An IOAccelerator that publishes PerformanceStatistics. Looked up once:
    /// walking the IORegistry every tick costs more than reading the stats.
    private struct Accelerator {
        let service: io_service_t
        let isBuiltIn: Bool
    }

    private var accelerators: [Accelerator]

    init?() {
        accelerators = Self.findAccelerators()
        guard sample(now: .now) != nil else {
            release()
            return nil
        }
    }

    deinit {
        release()
    }

    func reset() {}

    func sample(now: ContinuousClock.Instant) -> GPUSample? {
        if let sample = readSample() {
            return sample
        }
        // A GPU went away (eGPU unplugged, driver restart): look again once.
        release()
        accelerators = Self.findAccelerators()
        return readSample()
    }

    private func release() {
        accelerators.forEach { IOObjectRelease($0.service) }
        accelerators = []
    }

    private static func findAccelerators() -> [Accelerator] {
        let matching = IOServiceMatching("IOAccelerator")
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else {
            return []
        }
        defer { IOObjectRelease(iterator) }

        var found: [Accelerator] = []
        var service = IOIteratorNext(iterator)
        while service != 0 {
            let next = IOIteratorNext(iterator)
            if statistics(of: service) != nil {
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
                found.append(Accelerator(service: service, isBuiltIn: isBuiltIn))   // keeps the reference
            } else {
                IOObjectRelease(service)
            }
            service = next
        }
        return found
    }

    private static func statistics(of service: io_service_t) -> [String: Any]? {
        guard let stats = IORegistryEntryCreateCFProperty(
            service,
            "PerformanceStatistics" as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() as? [String: Any], !stats.isEmpty else {
            return nil
        }
        return stats
    }

    private func readSample() -> GPUSample? {
        var best: GPUSample?
        for accelerator in accelerators {
            guard let stats = Self.statistics(of: accelerator.service),
                  let sample = Self.makeSample(from: stats) else {
                continue
            }
            if accelerator.isBuiltIn {
                return sample
            }
            if best == nil || sample.utilization > best!.utilization {
                best = sample
            }
        }
        return best
    }

    private static func makeSample(from stats: [String: Any]) -> GPUSample? {
        let utilization = number(in: stats, keys: [
            "Device Utilization %",
            "GPU Activity(%)",
            "GPU Core Utilization"
        ])

        let renderer = number(in: stats, keys: [
            "Renderer Utilization %"
        ])

        let tiler = number(in: stats, keys: [
            "Tiler Utilization %"
        ])

        let memBytes = uint64Value(in: stats, keys: [
            "In use system memory",
            "Alloc system memory",
            "vramUsedBytes"
        ])

        guard let util = utilization ?? renderer else {
            return nil
        }

        return GPUSample(
            utilization: util,
            renderer: renderer,
            tiler: tiler,
            memoryInUse: memBytes,
            frequencyMHz: nil,
            temperatureC: nil,
            powerW: nil
        )
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
