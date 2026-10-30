import Foundation

enum MemoryPressure: Equatable {
    case normal
    case warning
    case critical

    static func fromKernelLevel(_ rawLevel: Int32) -> MemoryPressure {
        switch rawLevel {
        case 1: return .normal
        case 2: return .warning
        case 4: return .critical
        default: return .normal
        }
    }
}

struct MemorySample: Equatable {
    let total: UInt64           // bytes
    let app: UInt64             // bytes
    let wired: UInt64           // bytes
    let compressed: UInt64      // bytes
    let swapUsed: UInt64
    let pressure: MemoryPressure
    let pressurePercent: Double // 100 − kern.memorystatus_level

    init(
        total: UInt64,
        app: UInt64,
        wired: UInt64,
        compressed: UInt64,
        swapUsed: UInt64,
        pressure: MemoryPressure,
        pressurePercent: Double
    ) {
        self.total = total
        self.app = app
        self.wired = wired
        self.compressed = compressed
        self.swapUsed = swapUsed
        self.pressure = pressure
        self.pressurePercent = Self.clampPercent(pressurePercent)
    }

    var used: UInt64 {
        app &+ wired &+ compressed
    }

    var free: UInt64 {
        total > used ? (total - used) : 0
    }

    var usedPercent: Double {
        guard total > 0 else { return 0 }
        return Self.clampPercent((Double(used) / Double(total)) * 100.0)
    }

    private static func clampPercent(_ v: Double) -> Double {
        guard v.isFinite else { return 0 }
        return min(100, max(0, v))
    }
}
