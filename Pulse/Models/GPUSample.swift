import Foundation

struct GPUSample: Equatable {
    let utilization: Double             // 0…100
    let renderer: Double?
    let tiler: Double?
    let memoryInUse: UInt64?
    let frequencyMHz: Double?
    let temperatureC: Double?
    let powerW: Double?                 // nil unless FeatureFlags.privateGPUMetrics

    init(
        utilization: Double,
        renderer: Double? = nil,
        tiler: Double? = nil,
        memoryInUse: UInt64? = nil,
        frequencyMHz: Double? = nil,
        temperatureC: Double? = nil,
        powerW: Double? = nil
    ) {
        self.utilization = Self.clampPercent(utilization)
        self.renderer = renderer.map(Self.clampPercent)
        self.tiler = tiler.map(Self.clampPercent)
        self.memoryInUse = memoryInUse
        self.frequencyMHz = FeatureFlags.privateGPUMetrics ? frequencyMHz.map(Self.sanitize) : nil
        self.temperatureC = FeatureFlags.privateGPUMetrics ? temperatureC.map(Self.sanitize) : nil
        self.powerW = FeatureFlags.privateGPUMetrics ? powerW.map(Self.sanitize) : nil
    }

    private static func sanitize(_ v: Double) -> Double {
        guard v.isFinite else { return 0 }
        return max(0, v)
    }

    private static func clampPercent(_ v: Double) -> Double {
        guard v.isFinite else { return 0 }
        return min(100, max(0, v))
    }
}
