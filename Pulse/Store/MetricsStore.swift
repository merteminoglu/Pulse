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

    var openPanel: Metric?

    let gpuAvailable: Bool

    private let cpuSampler: CPUSampler
    private let gpuSampler: GPUSampler?
    private let memorySampler: MemorySampler
    private let networkSampler: NetworkSampler
    private let processSampler: ProcessSampler
    private var scheduler: SampleScheduler?
    private var sleepObserver: NSObjectProtocol?
    private var wakeObserver: NSObjectProtocol?

    init(scheduler: SampleScheduler? = nil) {
        self.cpuSampler = CPUSampler(layout: SystemInfo.coreLayout)
        let gpu = GPUSampler()
        self.gpuSampler = gpu
        self.gpuAvailable = (gpu != nil)
        self.memorySampler = MemorySampler()
        self.networkSampler = NetworkSampler()
        self.processSampler = ProcessSampler(topN: Tokens.Panel.topN)
        self.scheduler = scheduler

        setupSleepWakeNotifications()
    }

    /// Seconds between samples. Capped at 3: samplers treat a gap over 5 s as
    /// sleep/wake and discard it, so longer intervals would lose most readings.
    static let refreshChoices = [1, 2, 3]
    private static let refreshKey = "refreshIntervalSeconds"

    private(set) var refreshSeconds: Int = {
        let saved = UserDefaults.standard.integer(forKey: refreshKey)
        return refreshChoices.contains(saved) ? saved : 1
    }()

    func setRefreshSeconds(_ seconds: Int) {
        guard Self.refreshChoices.contains(seconds), seconds != refreshSeconds else { return }
        refreshSeconds = seconds
        UserDefaults.standard.set(seconds, forKey: Self.refreshKey)
        let wasRunning = scheduler != nil
        scheduler?.stop()
        scheduler = nil
        if wasRunning {
            start()
        }
    }

    func start() {
        if scheduler == nil {
            scheduler = SampleScheduler(interval: .seconds(refreshSeconds)) { [weak self] in
                Task { @MainActor [weak self] in
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

        // Sampled even while panels are closed (~2 ms per tick) so the top
        // process lists are already filled the moment a panel opens.
        if let procs = processSampler.sample(now: now) {
            processes = procs
        }
    }

    private func setupSleepWakeNotifications() {
        let center = NSWorkspace.shared.notificationCenter
        sleepObserver = center.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.stop()
            }
        }
        wakeObserver = center.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.handleWake()
                self.start()
            }
        }
    }
}
