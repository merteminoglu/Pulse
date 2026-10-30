import AppKit
import SwiftUI

enum LoadBand: Equatable {
    case cruising
    case working
    case busy
    case pegged
}

enum Thresholds {
    static func band(_ percent: Double) -> LoadBand {
        let clamped = clampPercent(percent)
        if clamped < 25.0 {
            return .cruising
        } else if clamped < 50.0 {
            return .working
        } else if clamped < 75.0 {
            return .busy
        } else {
            return .pegged
        }
    }

    static func panelColor(_ percent: Double) -> Color {
        switch band(percent) {
        case .cruising: return .green
        case .working: return .blue
        case .busy: return .orange
        case .pegged: return .red
        }
    }

    static func menuBarColor(_ percent: Double) -> Color {
        let clamped = clampPercent(percent)
        if clamped < 50.0 {
            return Color(nsColor: .labelColor)
        } else if clamped < 75.0 {
            return .orange
        } else {
            return .red
        }
    }

    static func pressureColor(_ p: MemoryPressure) -> Color {
        switch p {
        case .normal: return .green
        case .warning: return .yellow
        case .critical: return .red
        }
    }

    static func pressureLabel(_ p: MemoryPressure) -> String {
        switch p {
        case .normal: return "Normal"
        case .warning: return "Elevated"
        case .critical: return "Critical"
        }
    }

    private static func clampPercent(_ v: Double) -> Double {
        guard v.isFinite else { return 0 }
        return min(100.0, max(0.0, v))
    }
}
