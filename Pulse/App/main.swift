import AppKit

// Plain AppKit entry point. Pulse has no windows of its own besides the
// panel, so a SwiftUI App (and the Settings scene it needs) only added a
// main menu and scene machinery nobody sees.
MainActor.assumeIsolated {
    let delegate = AppDelegate()
    NSApplication.shared.delegate = delegate
    NSApplication.shared.run()
    withExtendedLifetime(delegate) {}
}
