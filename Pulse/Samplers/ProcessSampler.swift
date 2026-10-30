import AppKit
import Darwin
import Foundation

final class ProcessSampler: Sampler {
    var topN: Int

    private struct ProcessBaseline {
        let totalTimeNs: UInt64
    }

    private var baselines: [pid_t: ProcessBaseline] = [:]
    private var previousTime: ContinuousClock.Instant?
    private static var machTimebase: mach_timebase_info_data_t = {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        return info
    }()

    init(topN: Int = Tokens.Panel.topN) {
        self.topN = topN
    }

    func reset() {
        baselines.removeAll()
        previousTime = nil
    }

    func sample(now: ContinuousClock.Instant) -> [ProcessUsage]? {
        let pids = Self.allPIDs()
        guard !pids.isEmpty else { return nil }

        let elapsedSeconds: Double?
        if let prev = previousTime {
            let diff = now - prev
            let secs = Double(diff.components.seconds) + Double(diff.components.attoseconds) / 1e18
            if secs > 0 && secs <= 5.0 {
                elapsedSeconds = secs
            } else {
                baselines.removeAll()
                elapsedSeconds = nil
            }
        } else {
            elapsedSeconds = nil
        }
        previousTime = now

        let runningApps = NSWorkspace.shared.runningApplications
        var appByPID: [pid_t: NSRunningApplication] = [:]
        appByPID.reserveCapacity(runningApps.count)
        for app in runningApps {
            appByPID[app.processIdentifier] = app
        }

        var nextBaselines: [pid_t: ProcessBaseline] = [:]
        nextBaselines.reserveCapacity(pids.count)

        var entries: [ProcessUsage] = []
        entries.reserveCapacity(pids.count)

        let numer = UInt64(max(1, Self.machTimebase.numer))
        let denom = UInt64(max(1, Self.machTimebase.denom))

        for pid in pids where pid > 0 {
            var rusage = rusage_info_v4()
            let rc = withUnsafeMutablePointer(to: &rusage) { ptr -> Int32 in
                ptr.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { rusagePtr in
                    proc_pid_rusage(pid, RUSAGE_INFO_V4, rusagePtr)
                }
            }
            guard rc == 0 else { continue }

            let totalMachTicks = rusage.ri_user_time &+ rusage.ri_system_time
            let totalNs = (totalMachTicks / denom) &* numer &+ ((totalMachTicks % denom) &* numer) / denom
            nextBaselines[pid] = ProcessBaseline(totalTimeNs: totalNs)

            let memBytes = rusage.ri_phys_footprint
            var cpuPercent: Double = 0

            if let secs = elapsedSeconds,
               let prev = baselines[pid],
               totalNs >= prev.totalTimeNs {
                let deltaNs = totalNs - prev.totalTimeNs
                let deltaSecs = Double(deltaNs) / 1_000_000_000.0
                cpuPercent = (deltaSecs / secs) * 100.0
            } else if elapsedSeconds == nil {
                // First sample: no CPU delta yet
                cpuPercent = 0
            } else {
                // New PID without previous baseline: skip until 2nd sample for CPU,
                // or include with 0 CPU if memory is present
                continue
            }

            let app = appByPID[pid]
            let name = app?.localizedName?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
                ?? Self.processName(for: pid)
            guard let resolvedName = name else { continue }

            entries.append(
                ProcessUsage(
                    id: pid,
                    name: resolvedName,
                    bundleID: app?.bundleIdentifier,
                    cpuPercent: cpuPercent,
                    memoryBytes: memBytes
                )
            )
        }

        baselines = nextBaselines

        guard elapsedSeconds != nil else {
            return nil
        }

        return entries
    }

    static func topByCPU(_ list: [ProcessUsage], limit: Int = Tokens.Panel.topN) -> [ProcessUsage] {
        list.sorted {
            if $0.cpuPercent != $1.cpuPercent {
                return $0.cpuPercent > $1.cpuPercent
            }
            return $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
        .prefix(limit)
        .map { $0 }
    }

    static func topByMemory(_ list: [ProcessUsage], limit: Int = Tokens.Panel.topN) -> [ProcessUsage] {
        list.sorted {
            if $0.memoryBytes != $1.memoryBytes {
                return $0.memoryBytes > $1.memoryBytes
            }
            return $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
        .prefix(limit)
        .map { $0 }
    }

    private static func allPIDs() -> [pid_t] {
        let byteCount = proc_listpids(UInt32(PROC_ALL_PIDS), 0, nil, 0)
        guard byteCount > 0 else { return [] }
        let count = Int(byteCount) / MemoryLayout<pid_t>.stride + 32
        var pids = [pid_t](repeating: 0, count: count)
        let actualBytes = pids.withUnsafeMutableBufferPointer { buf -> Int32 in
            guard let base = buf.baseAddress else { return 0 }
            return proc_listpids(
                UInt32(PROC_ALL_PIDS),
                0,
                base,
                Int32(buf.count * MemoryLayout<pid_t>.stride)
            )
        }
        guard actualBytes > 0 else { return [] }
        let actualCount = Int(actualBytes) / MemoryLayout<pid_t>.stride
        return Array(pids.prefix(actualCount))
    }

    private static func processName(for pid: pid_t) -> String? {
        var pathBuffer = [CChar](repeating: 0, count: Int(MAXPATHLEN) * 4)
        let pathLen = proc_pidpath(pid, &pathBuffer, UInt32(pathBuffer.count))
        if pathLen > 0 {
            let path = String(cString: pathBuffer)
            let last = (path as NSString).lastPathComponent
            if !last.isEmpty { return last }
        }

        var nameBuffer = [CChar](repeating: 0, count: 256)
        let nameLen = proc_name(pid, &nameBuffer, UInt32(nameBuffer.count))
        if nameLen > 0 {
            let name = String(cString: nameBuffer)
            if !name.isEmpty { return name }
        }
        return nil
    }
}

private extension String {
    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}
