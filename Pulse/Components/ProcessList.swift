import AppKit
import SwiftUI

struct ProcessList: View {
    let items: [(ProcessUsage, String)]

    private static let rowHeight = Tokens.Panel.processIcon + 6

    var body: some View {
        VStack(spacing: 0) {
            if items.isEmpty {
                HStack {
                    Text(Fmt.placeholder)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.vertical, 3)
                // Processes are only sampled while a panel is open, so the list
                // starts empty for a moment; hold its space so the panel doesn't jump.
                .frame(minHeight: Self.rowHeight * CGFloat(Tokens.Panel.topN), alignment: .top)
            } else {
                ForEach(items, id: \.0.id) { process, formattedValue in
                    HStack(spacing: 8) {
                        ProcessIconView(pid: process.id, name: process.name)
                            .frame(width: Tokens.Panel.processIcon, height: Tokens.Panel.processIcon)

                        Text(process.name)
                            .font(.system(size: 12))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .truncationMode(.tail)

                        Spacer(minLength: 8)

                        Text(formattedValue)
                            .font(.system(size: 12))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 3)
                }
            }
        }
    }
}

private struct ProcessIconView: View {
    let pid: pid_t
    let name: String

    var body: some View {
        Image(nsImage: ProcessIconCache.icon(pid: pid, name: name))
            .resizable()
            .interpolation(.high)
            .clipShape(RoundedRectangle(cornerRadius: 4.5, style: .continuous))
    }
}

/// The rows redraw every sample; looking each icon up through LaunchServices
/// every time would cost more than the sampling itself.
@MainActor
enum ProcessIconCache {
    private struct Key: Hashable {
        let pid: pid_t
        let name: String
    }

    private static var icons: [Key: NSImage] = [:]
    private static let generic = NSWorkspace.shared.icon(for: .unixExecutable)

    static func icon(pid: pid_t, name: String) -> NSImage {
        let key = Key(pid: pid, name: name)
        if let cached = icons[key] { return cached }
        if icons.count >= 64 { icons.removeAll() }
        let icon = NSRunningApplication(processIdentifier: pid)?.icon ?? generic
        icons[key] = icon
        return icon
    }

    /// Called when the panel closes: the icons are cheap to look up again.
    static func removeAll() {
        icons.removeAll()
    }
}
