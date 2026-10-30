import Dispatch
import Foundation

final class SampleScheduler {
    private let interval: Duration
    private let tolerance: Duration
    private let queue: DispatchQueue
    private let onTick: () -> Void
    private var timer: DispatchSourceTimer?
    private let lock = NSLock()

    init(
        interval: Duration = .seconds(1),
        tolerance: Duration = .milliseconds(200),
        queue: DispatchQueue = .global(qos: .utility),
        onTick: @escaping () -> Void
    ) {
        self.interval = interval
        self.tolerance = tolerance
        self.queue = queue
        self.onTick = onTick
    }

    func start() {
        lock.lock()
        defer { lock.unlock() }
        guard timer == nil else { return }

        let source = DispatchSource.makeTimerSource(queue: queue)
        let intervalNs = Self.nanoseconds(from: interval)
        let leewayNs = Self.nanoseconds(from: tolerance)
        // First tick one interval out: callers take a baseline sample on start,
        // and an immediate tick would compute rates over a ~0 s window.
        source.schedule(
            deadline: .now() + .nanoseconds(intervalNs),
            repeating: .nanoseconds(intervalNs),
            leeway: .nanoseconds(leewayNs)
        )
        source.setEventHandler { [weak self] in
            self?.onTick()
        }
        timer = source
        source.resume()
    }

    func stop() {
        lock.lock()
        defer { lock.unlock() }
        timer?.cancel()
        timer = nil
    }

    deinit {
        stop()
    }

    private static func nanoseconds(from duration: Duration) -> Int {
        let (seconds, attoseconds) = duration.components
        let secNs = seconds.multipliedReportingOverflow(by: 1_000_000_000)
        let attoNs = attoseconds / 1_000_000_000
        if secNs.overflow {
            return Int.max
        }
        return Int(clamping: secNs.partialValue + attoNs)
    }
}
