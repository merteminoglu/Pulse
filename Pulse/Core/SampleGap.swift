import Foundation

/// How long a delta sampler waits before it treats the gap since its last
/// reading as a sleep/wake (and starts over), and how much the timer may
/// drift. Both scale with the refresh interval, so long intervals keep
/// their readings even when the system delivers a tick late.
enum SampleGap {
    /// Two intervals plus 3 s: 5 s at 1 s (as before), 23 s at 10 s.
    static func maxGap(forInterval seconds: Int) -> Duration {
        .seconds(2 * seconds + 3)
    }

    /// Timer leeway: 10% of the interval, at least 200 ms.
    static func leeway(forInterval seconds: Int) -> Duration {
        max(.milliseconds(200), .milliseconds(100 * seconds))
    }
}
