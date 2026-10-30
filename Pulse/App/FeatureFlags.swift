import Foundation

enum FeatureFlags {
    static let privateGPUMetrics = false   // IOReport/SMC: freq, temp, power
    static let networkProbes     = false   // public IP, ping
    static let perProcessNetwork = false   // NetworkStatistics.framework
}
