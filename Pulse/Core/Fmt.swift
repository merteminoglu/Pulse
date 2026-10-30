import Foundation

enum Fmt {
    static let placeholder = "—"

    static func percent(_ v: Double) -> String {
        let clamped = clampPercent(v)
        return String(format: "%.0f%%", locale: Locale.posix, clamped.rounded())
    }

    static func percent1(_ v: Double) -> String {
        let clamped = clampPercent(v)
        return String(format: "%.1f%%", locale: Locale.posix, clamped)
    }

    static func rate(_ bytesPerSec: Double) -> String {
        let v = sanitize(bytesPerSec)
        if v >= 1_000_000 {
            let mb = v / 1_000_000.0
            if mb >= 99.95 {
                return String(format: "%.0f MB/s", locale: Locale.posix, mb.rounded())
            }
            return String(format: "%.1f MB/s", locale: Locale.posix, mb)
        } else if v >= 1_000 {
            let kb = v / 1_000.0
            if kb >= 99.95 {
                return String(format: "%.0f KB/s", locale: Locale.posix, kb.rounded())
            }
            return String(format: "%.1f KB/s", locale: Locale.posix, kb)
        } else {
            return String(format: "%.0f B/s", locale: Locale.posix, v.rounded())
        }
    }

    static func bytes(_ b: UInt64) -> String {
        let v = Double(b)
        if v >= 1_000_000_000 {
            return String(format: "%.2f GB", locale: Locale.posix, v / 1_000_000_000.0)
        } else if v >= 1_000_000 {
            return String(format: "%.1f MB", locale: Locale.posix, v / 1_000_000.0)
        } else {
            return String(format: "%.0f KB", locale: Locale.posix, (v / 1_000.0).rounded())
        }
    }

    static func gb(_ b: UInt64, decimals: Int = 1) -> String {
        let gbVal = Double(b) / 1_073_741_824.0
        let d = max(0, decimals)
        return String(format: "%.*f GB", locale: Locale.posix, d, gbVal)
    }

    static func gbNumber(_ b: UInt64, decimals: Int = 1) -> String {
        let gbVal = Double(b) / 1_073_741_824.0
        let d = max(0, decimals)
        return String(format: "%.*f", locale: Locale.posix, d, gbVal)
    }

    static func uptime(_ seconds: TimeInterval) -> String {
        let totalSeconds = Int(max(0, seconds.isFinite ? seconds : 0))
        let days = totalSeconds / 86_400
        let hours = (totalSeconds % 86_400) / 3_600
        let minutes = (totalSeconds % 3_600) / 60
        return "\(days)d \(hours)h \(minutes)m"
    }

    static func load(_ l: LoadAverage) -> String {
        let one = sanitize(l.one)
        let five = sanitize(l.five)
        let fifteen = sanitize(l.fifteen)
        return String(format: "%.2f, %.2f, %.2f", locale: Locale.posix, one, five, fifteen)
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

private extension Locale {
    static let posix = Locale(identifier: "en_US_POSIX")
}
