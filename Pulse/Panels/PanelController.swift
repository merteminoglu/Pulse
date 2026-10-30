import AppKit
import SwiftUI

private final class FloatingPanelWindow: NSPanel {
    var onEscape: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func cancelOperation(_ sender: Any?) {
        onEscape?()
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Escape
            onEscape?()
        } else {
            super.keyDown(with: event)
        }
    }
}

/// Reports SwiftUI content size changes (process list filling in, GPU rows
/// appearing) so the panel window can grow or shrink to match.
private final class PanelHostingView<Content: View>: NSHostingView<Content> {
    var onContentSizeChange: (() -> Void)?

    override func invalidateIntrinsicContentSize() {
        super.invalidateIntrinsicContentSize()
        onContentSizeChange?()
    }
}

@MainActor
final class PanelController: NSObject, NSWindowDelegate {
    private let store: MetricsStore
    private var panelWindow: FloatingPanelWindow?
    private var globalClickMonitor: Any?
    private var localKeyMonitor: Any?

    // Geometry of the open panel; its top edge stays pinned under the menu bar.
    private var panelTopY: CGFloat = 0
    private var panelX: CGFloat = 0
    private var panelMaxHeight: CGFloat = 0
    private var fitScheduled = false

    init(store: MetricsStore) {
        self.store = store
        super.init()
    }

    func toggle(_ metric: Metric, anchor: NSStatusBarButton) {
        if store.openPanel == metric {
            close()
        } else {
            show(metric, anchor: anchor)
        }
    }

    func close() {
        guard store.openPanel != nil else { return }
        store.openPanel = nil

        if let monitor = globalClickMonitor {
            NSEvent.removeMonitor(monitor)
            globalClickMonitor = nil
        }
        if let monitor = localKeyMonitor {
            NSEvent.removeMonitor(monitor)
            localKeyMonitor = nil
        }

        panelWindow?.orderOut(nil)
    }

    private func show(_ metric: Metric, anchor: NSStatusBarButton) {
        let wasOpen = (store.openPanel != nil)
        store.openPanel = metric

        let window = ensurePanelWindow()
        guard let buttonWindow = anchor.window,
              let screen = buttonWindow.screen ?? NSScreen.main else {
            return
        }

        let maxHeight = max(240, screen.visibleFrame.height - 48)
        let rootView = PanelHostView(metric: metric, store: store, maxHeight: maxHeight)
        let hostingView = PanelHostingView(rootView: rootView)
        hostingView.sizingOptions = [.intrinsicContentSize]

        let width = Tokens.Panel.width
        let buttonFrame = buttonWindow.frame
        let minX = screen.visibleFrame.minX + Tokens.Panel.screenInset
        let maxX = screen.visibleFrame.maxX - width - Tokens.Panel.screenInset
        panelX = min(max(buttonFrame.minX, minX), maxX)
        panelTopY = buttonFrame.minY - Tokens.Panel.gapBelowMenuBar
        panelMaxHeight = maxHeight

        let targetFrame = frameFitting(hostingView)
        window.contentView = hostingView
        hostingView.onContentSizeChange = { [weak self] in
            self?.scheduleFitToContent()
        }

        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        if !wasOpen {
            let startFrame = reduceMotion
                ? targetFrame
                : NSRect(
                    x: targetFrame.origin.x,
                    y: targetFrame.origin.y + Tokens.Panel.gapBelowMenuBar,
                    width: targetFrame.width,
                    height: targetFrame.height
                )
            window.setFrame(startFrame, display: true)
            window.alphaValue = 0
            window.makeKeyAndOrderFront(nil)

            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = Tokens.Motion.open
                ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                window.animator().alphaValue = 1
                if !reduceMotion {
                    window.animator().setFrame(targetFrame, display: true)
                }
            }
        } else {
            window.setFrame(targetFrame, display: true)
            window.alphaValue = 1
            window.makeKeyAndOrderFront(nil)
        }

        installMonitorsIfNeeded()
    }

    private func frameFitting(_ view: NSView) -> NSRect {
        let height = min(panelMaxHeight, max(1, view.fittingSize.height))
        return NSRect(x: panelX, y: panelTopY - height, width: Tokens.Panel.width, height: height)
    }

    /// Coalesces size invalidations into one resize per runloop turn.
    private func scheduleFitToContent() {
        guard !fitScheduled else { return }
        fitScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.fitScheduled = false
            guard self.store.openPanel != nil,
                  let window = self.panelWindow,
                  let content = window.contentView else { return }
            let target = self.frameFitting(content)
            if abs(window.frame.height - target.height) > 0.5 {
                window.setFrame(target, display: true)
            }
        }
    }

    private func ensurePanelWindow() -> FloatingPanelWindow {
        if let existing = panelWindow {
            return existing
        }
        let panel = FloatingPanelWindow(
            contentRect: NSRect(x: 0, y: 0, width: Tokens.Panel.width, height: 360),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.delegate = self
        panel.onEscape = { [weak self] in
            self?.close()
        }
        panelWindow = panel
        return panel
    }

    private func installMonitorsIfNeeded() {
        if globalClickMonitor == nil {
            globalClickMonitor = NSEvent.addGlobalMonitorForEvents(
                matching: [.leftMouseDown, .rightMouseDown]
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.close()
                }
            }
        }

        if localKeyMonitor == nil {
            localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                if event.keyCode == 53 {
                    Task { @MainActor [weak self] in
                        self?.close()
                    }
                    return nil
                }
                return event
            }
        }
    }

    func windowDidResignKey(_ notification: Notification) {
        close()
    }
}

private struct VisualEffectMaterialView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .popover
        view.state = .active
        view.blendingMode = .behindWindow
        view.wantsLayer = true
        view.layer?.cornerRadius = Tokens.Panel.radius
        view.layer?.cornerCurve = .continuous
        view.layer?.masksToBounds = true
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = .popover
        nsView.state = .active
    }
}

private struct PanelHostView: View {
    let metric: Metric
    let store: MetricsStore
    let maxHeight: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        // Natural height when it fits on screen; scroll only when it doesn't.
        ViewThatFits(in: .vertical) {
            panelContent
            ScrollView(.vertical, showsIndicators: false) {
                panelContent
            }
        }
        .frame(width: Tokens.Panel.width)
        .frame(maxHeight: maxHeight)
        .background(VisualEffectMaterialView())
        .clipShape(RoundedRectangle(cornerRadius: Tokens.Panel.radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Tokens.Panel.radius, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.18), lineWidth: 0.5)
        )
        .scaleEffect(appeared || reduceMotion ? 1.0 : Tokens.Motion.scale, anchor: .top)
        .onAppear {
            withAnimation(.easeOut(duration: Tokens.Motion.open)) {
                appeared = true
            }
        }
    }

    private var panelContent: some View {
        Group {
            switch metric {
            case .cpu:
                CPUPanel(store: store)
            case .gpu:
                GPUPanel(store: store)
            case .memory:
                MemoryPanel(store: store)
            case .network:
                NetworkPanel(store: store)
            }
        }
        .padding(Tokens.Panel.padding)
        .frame(width: Tokens.Panel.width)
    }
}
