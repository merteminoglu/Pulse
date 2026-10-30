import AppKit
import ServiceManagement

/// Right-click menu on any Pulse item (and the panels' "Options…" button):
/// show/hide each metric, open at login, quit.
@MainActor
final class OptionsMenu: NSObject {
    static let shared = OptionsMenu()

    /// Set by the app delegate once the status items exist.
    var items: [StatusItemController] = []
    var store: MetricsStore?
    var onVisibilityChange: (() -> Void)?

    func popUp(below view: NSView) {
        buildMenu().popUp(positioning: nil, at: NSPoint(x: 0, y: view.bounds.height + 4), in: view)
    }

    func popUpAtMouse() {
        buildMenu().popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false

        menu.addItem(.sectionHeader(title: "Show in Menu Bar"))
        let visibleCount = items.filter(\.isVisible).count
        for controller in items {
            let entry = NSMenuItem(title: Self.title(for: controller.metric),
                                   action: #selector(toggleVisibility(_:)), keyEquivalent: "")
            entry.target = self
            entry.representedObject = controller.metric.rawValue
            entry.state = controller.isVisible ? .on : .off
            // Keep at least one item, or there'd be no way back into Pulse.
            entry.isEnabled = !(controller.isVisible && visibleCount == 1)
            menu.addItem(entry)
        }

        let tip = NSMenuItem(title: "Hold ⌘ and drag an item to move it", action: nil, keyEquivalent: "")
        tip.isEnabled = false
        menu.addItem(tip)

        menu.addItem(.separator())

        if let store {
            let refresh = NSMenuItem(title: "Update Every", action: nil, keyEquivalent: "")
            let submenu = NSMenu()
            for seconds in MetricsStore.refreshChoices {
                let choice = NSMenuItem(title: seconds == 1 ? "1 second" : "\(seconds) seconds",
                                        action: #selector(setRefresh(_:)), keyEquivalent: "")
                choice.target = self
                choice.tag = seconds
                choice.state = store.refreshSeconds == seconds ? .on : .off
                submenu.addItem(choice)
            }
            refresh.submenu = submenu
            menu.addItem(refresh)
        }

        let login = NSMenuItem(title: "Open at Login", action: #selector(toggleLaunchAtLogin(_:)), keyEquivalent: "")
        login.target = self
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit Pulse", action: #selector(quit(_:)), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        return menu
    }

    private static func title(for metric: Metric) -> String {
        switch metric {
        case .cpu: return "CPU"
        case .gpu: return "GPU"
        case .memory: return "Memory"
        case .network: return "Network"
        }
    }

    @objc
    private func toggleVisibility(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let controller = items.first(where: { $0.metric.rawValue == raw }) else { return }
        controller.isVisible.toggle()
        onVisibilityChange?()
    }

    @objc
    private func setRefresh(_ sender: NSMenuItem) {
        store?.setRefreshSeconds(sender.tag)
    }

    @objc
    private func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled {
                try service.unregister()
            } else {
                try service.register()
            }
        } catch {
            let alert = NSAlert()
            alert.messageText = "Couldn't change Open at Login"
            alert.informativeText = error.localizedDescription
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
        }
        // macOS may hold the request until it's allowed in Login Items settings.
        if service.status == .requiresApproval {
            SMAppService.openSystemSettingsLoginItems()
        }
    }

    @objc
    private func quit(_ sender: NSMenuItem) {
        NSApp.terminate(nil)
    }
}
