import Darwin
import Foundation

struct CPUTicks: Equatable {
    let user: UInt32
    let system: UInt32
    let idle: UInt32
    let nice: UInt32
}

final class CPUSampler: Sampler {
    typealias TickProvider = () -> (ticks: [CPUTicks], load: LoadAverage)?

    private let layout: CoreLayout
    private let provider: TickProvider
    private var previousTicks: [CPUTicks]?
    private var previousTime: ContinuousClock.Instant?
    private var previousSample: CPUSample?

    init(
        layout: CoreLayout = SystemInfo.coreLayout,
        provider: @escaping TickProvider = CPUSampler.readSystemTicks
    ) {
        self.layout = layout
        self.provider = provider
    }

    func reset() {
        previousTicks = nil
        previousTime = nil
        previousSample = nil
    }

    func sample(now: ContinuousClock.Instant) -> CPUSample? {
        guard let current = provider(), !current.ticks.isEmpty else {
            return nil
        }

        if let prevTime = previousTime, (now - prevTime) > .seconds(5) {
            previousTicks = current.ticks
            previousTime = now
            return nil
        }

        guard let prev = previousTicks, prev.count == current.ticks.count else {
            previousTicks = current.ticks
            previousTime = now
            return nil
        }

        previousTicks = current.ticks
        previousTime = now

        var totalUserDelta: UInt64 = 0
        var totalSysDelta: UInt64 = 0
        var totalIdleDelta: UInt64 = 0
        var perCore: [Double] = []
        perCore.reserveCapacity(current.ticks.count)

        for i in 0..<current.ticks.count {
            let p = prev[i]
            let c = current.ticks[i]

            let uDelta = UInt64(c.user &- p.user) &+ UInt64(c.nice &- p.nice)
            let sDelta = UInt64(c.system &- p.system)
            let iDelta = UInt64(c.idle &- p.idle)
            let coreTotal = uDelta &+ sDelta &+ iDelta

            totalUserDelta &+= uDelta
            totalSysDelta &+= sDelta
            totalIdleDelta &+= iDelta

            if coreTotal > 0 {
                let busy = Double(uDelta &+ sDelta) / Double(coreTotal) * 100.0
                perCore.append(busy)
            } else if let prevCore = previousSample?.perCore, i < prevCore.count {
                perCore.append(prevCore[i])
            } else {
                perCore.append(0)
            }
        }

        let allTotal = totalUserDelta &+ totalSysDelta &+ totalIdleDelta
        guard allTotal > 0 else {
            return previousSample
        }

        let userPct = Double(totalUserDelta) / Double(allTotal) * 100.0
        let sysPct = Double(totalSysDelta) / Double(allTotal) * 100.0

        let sample = CPUSample(
            user: userPct,
            system: sysPct,
            perCore: perCore,
            load: current.load
        )
        previousSample = sample
        return sample
    }

    static func readSystemTicks() -> (ticks: [CPUTicks], load: LoadAverage)? {
        var numCPUs: natural_t = 0
        var cpuInfo: processor_info_array_t?
        var numCPUInfo: mach_msg_type_number_t = 0

        let result = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &numCPUs,
            &cpuInfo,
            &numCPUInfo
        )
        guard result == KERN_SUCCESS, let info = cpuInfo else {
            return nil
        }
        defer {
            let size = vm_size_t(numCPUInfo) * vm_size_t(MemoryLayout<integer_t>.stride)
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info), size)
        }

        let count = Int(numCPUs)
        var ticks: [CPUTicks] = []
        ticks.reserveCapacity(count)

        for i in 0..<count {
            let base = i * Int(CPU_STATE_MAX)
            let user = UInt32(bitPattern: info[base + Int(CPU_STATE_USER)])
            let system = UInt32(bitPattern: info[base + Int(CPU_STATE_SYSTEM)])
            let idle = UInt32(bitPattern: info[base + Int(CPU_STATE_IDLE)])
            let nice = UInt32(bitPattern: info[base + Int(CPU_STATE_NICE)])
            ticks.append(CPUTicks(user: user, system: system, idle: idle, nice: nice))
        }

        var avg = [Double](repeating: 0, count: 3)
        let got = getloadavg(&avg, 3)
        let load: LoadAverage
        if got == 3 {
            load = LoadAverage(one: avg[0], five: avg[1], fifteen: avg[2])
        } else {
            load = LoadAverage(one: 0, five: 0, fifteen: 0)
        }

        return (ticks: ticks, load: load)
    }
}
