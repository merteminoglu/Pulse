import Foundation

enum Metric: String, CaseIterable, Identifiable {
    case cpu
    case gpu
    case memory
    case network

    var id: String { rawValue }

    var menuBarLabel: String {
        switch self {
        case .cpu: return "CPU"
        case .gpu: return "GPU"
        case .memory: return "MEM"
        case .network: return "NET"
        }
    }
}
