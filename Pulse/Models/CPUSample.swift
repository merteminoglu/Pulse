import Foundation

struct LoadAverage: Equatable {
    let one: Double
    let five: Double
    let fifteen: Double
}

struct CoreLayout: Equatable {
    let performance: Int
    let efficiency: Int

    var total: Int { performance + efficiency }
}

struct CPUSample: Equatable {
    let user: Double            // 0…100
    let system: Double          // 0…100
    let perCore: [Double]       // 0…100, count == layout.performance + layout.efficiency
    let load: LoadAverage

    init(user: Double, system: Double, perCore: [Double], load: LoadAverage) {
        self.user = Self.clampPercent(user)
        self.system = Self.clampPercent(system)
        self.perCore = perCore.map(Self.clampPercent)
        self.load = LoadAverage(
            one: Self.sanitize(load.one),
            five: Self.sanitize(load.five),
            fifteen: Self.sanitize(load.fifteen)
        )
    }

    var total: Double {
        Self.clampPercent(user + system)
    }

    var idle: Double {
        Self.clampPercent(100.0 - total)
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
