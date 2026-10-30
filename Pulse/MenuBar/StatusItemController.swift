import AppKit
import Observation
import SwiftUI

/// One menu bar item per metric, so each can be ⌘-dragged among other apps'
/// items. The autosave name makes macOS remember position and visibility.
/// Left click toggles the metric's panel; right or control click opens Options.
///
/// The readout is drawn as a template image rather than a live view: that way
/// macOS tints it like every other item (dimmed on an inactive display,
/// inverted on light/dark menu bars, highlighted while its panel is open).
@MainActor
final class StatusItemController: NSObject {
    let metric: Metric
    private let store: MetricsStore
    private let panels: PanelController
    private let options: OptionsMenu
    private var statusItem: NSStatusItem?
    private var lastContent: StatusItemContent?

    init(metric: Metric, store: MetricsStore, panels: PanelController, options: OptionsMenu) {
        self.metric = metric
        self.store = store
        self.panels = panels
        self.options = options
        super.init()

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.autosaveName = "Pulse.\(metric.rawValue)"
        self.statusItem = item

        if let button = item.button {
            button.target = self
            button.action = #selector(handleClick(_:))
            button.sendAction(on: [.leftMouseDown, .rightMouseUp])
            button.imagePosition = .imageOnly
            button.imageScaling = .scaleNone
        }
        update()
    }

    var isVisible: Bool {
        get { statusItem?.isVisible ?? false }
        set { statusItem?.isVisible = newValue }
    }

    /// Redraws from the store, then re-arms on the next change it read.
    private func update() {
        let (content, isOpen) = withObservationTracking {
            (StatusItemContent(metric: metric, store: store), store.openPanel == metric)
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in self?.update() }
        }

        guard let item = statusItem, let button = item.button else { return }
        if content != lastContent {
            lastContent = content
            if let image = Self.render(content, scale: button.window?.backingScaleFactor ?? 2) {
                button.image = image
                item.length = image.size.width + Tokens.MenuBar.itemPadX * 2
            }
        }
        button.highlight(isOpen)
    }

    private static func render(_ content: StatusItemContent, scale: CGFloat) -> NSImage? {
        let renderer = ImageRenderer(content: StatusItemLabel(content: content))
        renderer.scale = scale
        guard let image = renderer.nsImage else { return nil }
        image.isTemplate = true
        return image
    }

    @objc
    private func handleClick(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        let wantsMenu = event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true
        if wantsMenu {
            panels.close()
            options.popUp(below: sender)
        } else {
            panels.toggle(metric, anchor: sender)
        }
        // The click itself toggles the button's highlight; restore ours.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.statusItem?.button?.highlight(self.store.openPanel == self.metric)
        }
    }

    func remove() {
        if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
            statusItem = nil
        }
    }
}
