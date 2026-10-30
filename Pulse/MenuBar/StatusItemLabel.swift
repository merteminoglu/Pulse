import AppKit
import SwiftUI

/// What a status item shows, already formatted.
enum StatusItemContent: Equatable {
    case stat(label: String, value: String)
    case network(up: String, down: String)

    @MainActor
    init(metric: Metric, store: MetricsStore) {
        switch metric {
        case .cpu:
            self = .stat(label: "CPU", value: store.cpu.map { Fmt.percent($0.total) } ?? Fmt.placeholder)
        case .gpu:
            self = .stat(label: "GPU", value: store.gpu.map { Fmt.percent($0.utilization) } ?? Fmt.placeholder)
        case .memory:
            self = .stat(label: "MEM", value: store.memory.map { Fmt.percent($0.usedPercent) } ?? Fmt.placeholder)
        case .network:
            self = .network(
                up: store.network.map { Fmt.rate($0.txPerSec) } ?? Fmt.placeholder,
                down: store.network.map { Fmt.rate($0.rxPerSec) } ?? Fmt.placeholder
            )
        }
    }
}

/// Rendered into a template image, so it is drawn in solid black: the menu bar
/// only uses the alpha, and tints it for light/dark, inactive screens and clicks.
struct StatusItemLabel: View {
    let content: StatusItemContent

    var body: some View {
        Group {
            switch content {
            case let .stat(label, value):
                stackedStat(label: label, value: value)
            case let .network(up, down):
                networkStat(up: up, down: down)
            }
        }
        .foregroundStyle(.black)
        .frame(height: Tokens.MenuBar.itemHeight)
    }

    private func stackedStat(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label)
                .font(.system(size: Tokens.MenuBar.labelSize, weight: .medium))
                .tracking(0.18)
                .frame(height: 9, alignment: .leading)

            Text(value)
                .font(Self.numberFont(size: Tokens.MenuBar.valueSize))
                .tracking(-0.14)
                .frame(height: 13, alignment: .leading)
        }
        .frame(minWidth: Tokens.MenuBar.statMinWidth, alignment: .leading)
        .fixedSize()
    }

    // Arrow column, then right-aligned rates, so short values don't leave a gap.
    private func networkStat(up: String, down: String) -> some View {
        HStack(spacing: 3) {
            VStack(spacing: 0) {
                netText("↑")
                netText("↓")
            }
            VStack(alignment: .trailing, spacing: 0) {
                netText(up)
                netText(down)
            }
            .frame(minWidth: Tokens.MenuBar.netWidth, alignment: .trailing)
        }
        .fixedSize()
    }

    private func netText(_ string: String) -> some View {
        Text(string)
            .font(Self.numberFont(size: Tokens.MenuBar.netSize))
            .frame(height: 10.5)
    }

    /// System font with monospaced digits at an in-between weight. The named
    /// weights snap (regular 400, medium 510), so set SF's variable weight axis.
    private static func numberFont(size: CGFloat) -> Font {
        let base = NSFont.monospacedDigitSystemFont(ofSize: size, weight: .regular)
        let weightAxis = 0x7767_6874 // 'wght'
        let descriptor = base.fontDescriptor.addingAttributes([
            NSFontDescriptor.AttributeName(rawValue: kCTFontVariationAttribute as String):
                [weightAxis: Tokens.MenuBar.numberWeight]
        ])
        return Font(NSFont(descriptor: descriptor, size: size) ?? base)
    }
}
