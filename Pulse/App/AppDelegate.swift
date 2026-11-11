import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var store: MetricsStore?
    private var panelController: PanelController?
    private var statusItems: [StatusItemController] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let metricsStore = MetricsStore()
        let panels = PanelController(store: metricsStore)
        self.store = metricsStore
        self.panelController = panels

        // NSStatusBar inserts items right-to-left, so creating Network -> Memory -> GPU -> CPU
        // gives CPU | GPU | MEM | NET on first launch. After that macOS restores any ⌘-drag order.
        let options = OptionsMenu.shared
        let orderedMetrics: [Metric] = [.network, .memory, .gpu, .cpu]
        for metric in orderedMetrics where metric != .gpu || metricsStore.gpuAvailable {
            statusItems.append(StatusItemController(metric: metric, store: metricsStore, panels: panels, options: options))
        }
        // Menu lists them in reading order.
        options.items = statusItems.reversed()
        options.store = metricsStore
        options.onVisibilityChange = { [weak self, weak panels] in
            panels?.close()
            self?.updateVisibleMetrics()
        }

        // Never come up with everything hidden: there'd be no way to reach Pulse.
        if !statusItems.contains(where: \.isVisible) {
            statusItems.last?.isVisible = true
        }
        updateVisibleMetrics()

        metricsStore.start()
    }

    private func updateVisibleMetrics() {
        store?.setVisibleMetrics(Set(statusItems.filter(\.isVisible).map(\.metric)))
    }

    func applicationWillTerminate(_ notification: Notification) {
        panelController?.close()
        store?.stop()
        statusItems.forEach { $0.remove() }
        statusItems.removeAll()
    }
}
