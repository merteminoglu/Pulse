import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class MetricsStore {
    private(set) var cpu: CPUSample?
    private(set) var cpuHistory = RingBuffer<CPUSample>(capacity: Tokens.historyLength)

    private(set) var gpu: GPUSample?
    private(set) var gpuHistory = RingBuffer<GPUSample>(capacity: Tokens.historyLength)

    private(set) var memory: MemorySample?
    private(set) var memoryHistory = RingBuffer<MemorySample>(capacity: Tokens.historyLength)

    private(set) var network: NetworkSample?
    private(set) var networkHistory = RingBuffer<NetworkSample>(capacity: Tokens.historyLength)

    private(set) var processes: [ProcessUsage] = []

    var openPanel: Metric? {
        didSet {
            if openPanel != oldValue { panelDidChange() }
        }
    }

    let gpuAvailable: Bool

    private let cpuSampler: CPUSampler
    private let gpuSampler: GPUSampler?
    private let memorySampler: MemorySampler
    private let networkSampler: NetworkSampler
    private let processSampler: ProcessSampler
    private var scheduler: SampleScheduler?
    private var pauseObservers: [NSObjectProtocol] = []
    private var pauseState = PauseState()
    private var lastProcessSample: ContinuousClock.Instant?

    init(scheduler: SampleScheduler? = nil) {
        self.cpuSampler = CPUSampler(layout: SystemInfo.coreLayout)
        let gpu = GPUSampler()
        self.gpuSampler = gpu
        self.gpuAvailable = (gpu != nil)
        self.memorySampler = MemorySampler()
        self.networkSampler = NetworkSampler()
        self.processSampler = ProcessSampler(topN: Tokens.Panel.topN)
        self.scheduler = scheduler
        networkSampler.includesInterfaceDetails = false
        applySampleGap()

        setupPauseNotifications()
    }

    /// Seconds between samples. The delta samplers' sleep/wake threshold
    /// scales with the interval (`SampleGap`), so long intervals keep their
    /// readings; idle cost falls in proportion.
    static let refreshChoices = [1, 2, 3, 5, 10]
    private static let refreshKey = "refreshIntervalSeconds"

    private(set) var refreshSeconds: Int = {
        let saved = UserDefaults.standard.integer(forKey: refreshKey)
        return refreshChoices.contains(saved) ? saved : 1
    }()

    func setRefreshSeconds(_ seconds: Int) {
        guard Self.refreshChoices.contains(seconds), seconds != refreshSeconds else { return }
        refreshSeconds = seconds
        UserDefaults.standard.set(seconds, forKey: Self.refreshKey)
        applySampleGap()
        let wasRunning = scheduler != nil
        scheduler?.stop()
        scheduler = nil
        if wasRunning {
            start()
        }
    }

    func start() {
        // Resuming calls start() again; a refresh change while paused waits for it.
        guard !pauseState.isPaused else { return }
        if scheduler == nil {
            // Fires on the main queue: the samplers run there anyway, so a
            // background timer only added a thread wake and a Task per tick.
            scheduler = SampleScheduler(
                interval: .seconds(refreshSeconds),
                tolerance: SampleGap.leeway(forInterval: refreshSeconds),
                queue: .main
            ) { [weak self] in
                MainActor.assumeIsolated {
                    self?.tick()
                }
            }
        }
        // Prime initial baseline so the next tick has a delta
        tick()
        scheduler?.start()
    }

    func stop() {
        scheduler?.stop()
    }

    private func applySampleGap() {
        let gap = SampleGap.maxGap(forInterval: refreshSeconds)
        cpuSampler.maxGap = gap
        networkSampler.maxGap = gap
        processSampler.maxGap = gap
    }

    func handleWake() {
        cpuSampler.reset()
        gpuSampler?.reset()
        memorySampler.reset()
        networkSampler.reset()
        processSampler.reset()
    }

    private func tick() {
        let now = ContinuousClock.now

        if let s = cpuSampler.sample(now: now) {
            cpu = s
            cpuHistory.append(s)
        }

        if let s = gpuSampler?.sample(now: now) {
            gpu = s
            gpuHistory.append(s)
        }

        if let s = memorySampler.sample(now: now) {
            memory = s
            memoryHistory.append(s)
        }

        if let s = networkSampler.sample(now: now) {
            network = s
            networkHistory.append(s)
        }

        if needsProcesses {
            sampleProcesses(now: now)
        }
    }

    // MARK: - Panel-only work

    /// Only the CPU and memory panels list processes. Walking every process
    /// costs more than all the other samplers combined, so it runs only while
    /// one of those panels is open.
    private var needsProcesses: Bool {
        openPanel == .cpu || openPanel == .memory
    }

    private func panelDidChange() {
        networkSampler.includesInterfaceDetails = (openPanel == .network)
        if openPanel == .network, let current = network {
            network = current.replacingPrimary(networkSampler.currentInterface())
        }

        if needsProcesses {
            guard lastProcessSample == nil else { return }   // CPU <-> memory switch: keep going
            // Baseline now, then a short first window so the list fills in
            // right after the panel opens instead of a full interval later.
            sampleProcesses(now: .now)
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.firstProcessWindow) { [weak self] in
                MainActor.assumeIsolated {
                    guard let self, self.needsProcesses else { return }
                    self.sampleProcesses(now: .now)
                }
            }
        } else if lastProcessSample != nil {
            processSampler.reset()
            processes = []
            lastProcessSample = nil
        }
    }

    private static let firstProcessWindow: TimeInterval = 0.35

    private func sampleProcesses(now: ContinuousClock.Instant) {
        // A scheduler tick landing right after the quick first sample would
        // measure CPU over a sliver of time; let it wait for the next one.
        if let last = lastProcessSample, now - last < .milliseconds(300) { return }
        lastProcessSample = now
        if let procs = processSampler.sample(now: now) {
            processes = procs
        }
    }

    /// Nobody can see the readouts while the system or display sleeps or
    /// another user's session is in front, so stop sampling and redrawing.
    private func setupPauseNotifications() {
        let center = NSWorkspace.shared.notificationCenter
        let pairs: [(pause: Notification.Name, resume: Notification.Name, reason: PauseReason)] = [
            (NSWorkspace.willSleepNotification, NSWorkspace.didWakeNotification, .systemSleep),
            (NSWorkspace.screensDidSleepNotification, NSWorkspace.screensDidWakeNotification, .displaySleep),
            (NSWorkspace.sessionDidResignActiveNotification, NSWorkspace.sessionDidBecomeActiveNotification, .sessionInactive),
        ]
        for pair in pairs {
            let reason = pair.reason
            pauseObservers.append(center.addObserver(forName: pair.pause, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.pause(reason) }
            })
            pauseObservers.append(center.addObserver(forName: pair.resume, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.resume(reason) }
            })
        }
    }

    private func pause(_ reason: PauseReason) {
        if pauseState.pause(reason) {
            stop()
        }
    }

    private func resume(_ reason: PauseReason) {
        if pauseState.resume(reason) {
            handleWake()
            start()
        }
    }
}
