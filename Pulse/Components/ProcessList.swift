import AppKit
import SwiftUI

struct ProcessList: View {
    let items: [(ProcessUsage, String)]

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
        if let nsImage = NSRunningApplication(processIdentifier: pid)?.icon {
            Image(nsImage: nsImage)
                .resizable()
                .interpolation(.high)
                .clipShape(RoundedRectangle(cornerRadius: 4.5, style: .continuous))
        } else {
            Image(nsImage: NSWorkspace.shared.icon(for: .unixExecutable))
                .resizable()
                .interpolation(.high)
                .clipShape(RoundedRectangle(cornerRadius: 4.5, style: .continuous))
        }
    }
}
