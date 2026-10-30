import AppKit
import SwiftUI

struct MemoryPanel: View {
    let store: MetricsStore

    var body: some View {
        let sample = store.memory
        let history = store.memoryHistory.elements
        let pressureColor = Thresholds.pressureColor(sample?.pressure ?? .normal)

        VStack(alignment: .leading, spacing: 0) {
            PanelHeader(
                tile: "MEM",
                tint: .green,
                title: "Memory",
                subtitle: "\(Fmt.gb(SystemInfo.physicalMemory, decimals: 0)) Unified Memory"
            ) {
                if let sample {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(Fmt.gbNumber(sample.used, decimals: 1))
                            .font(.system(size: 26, weight: .semibold))
                            .monospacedDigit()
                            .foregroundStyle(.primary)
                        Text("GB")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text(Fmt.placeholder)
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }

            AreaGraph(
                up: [
                    AreaSeries(
                        values: history.map(\.pressurePercent),
                        max: 100,
                        color: pressureColor
                    )
                ],
                topLabel: "Pressure"
            )

            HStack(alignment: .center, spacing: 16) {
                let total = Double(max(1, sample?.total ?? SystemInfo.physicalMemory))
                let segments: [DonutSegment] = {
                    guard let s = sample else { return [] }
                    return [
                        DonutSegment(fraction: Double(s.app) / total, color: .yellow),
                        DonutSegment(fraction: Double(s.wired) / total, color: .red),
                        DonutSegment(fraction: Double(s.compressed) / total, color: .blue)
                    ]
                }()

                Donut(
                    segments: segments,
                    value: sample.map { Fmt.percent($0.usedPercent) } ?? Fmt.placeholder,
                    caption: "used"
                )

                VStack(spacing: 0) {
                    LegendRow(
                        dot: .yellow,
                        label: "App",
                        value: sample.map { Fmt.gb($0.app, decimals: 1) } ?? Fmt.placeholder
                    )
                    LegendRow(
                        dot: .red,
                        label: "Wired",
                        value: sample.map { Fmt.gb($0.wired, decimals: 1) } ?? Fmt.placeholder
                    )
                    LegendRow(
                        dot: .blue,
                        label: "Compressed",
                        value: sample.map { Fmt.gb($0.compressed, decimals: 1) } ?? Fmt.placeholder
                    )
                    LegendRow(
                        dot: .primary.opacity(0.22),
                        label: "Free",
                        value: sample.map { Fmt.gb($0.free, decimals: 1) } ?? Fmt.placeholder
                    )
                }
            }
            .padding(.top, 12)

            PanelSection {
                LegendRow(
                    label: "Pressure",
                    value: sample.map {
                        "\(Fmt.percent($0.pressurePercent)) · \(Thresholds.pressureLabel($0.pressure))"
                    } ?? Fmt.placeholder
                )

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(Color.primary.opacity(0.07))
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(pressureColor)
                            .frame(width: geo.size.width * CGFloat((sample?.pressurePercent ?? 0) / 100.0))
                            .animation(.easeOut(duration: Tokens.Motion.bars), value: sample?.pressurePercent ?? 0)
                    }
                }
                .frame(height: 6)
                .padding(.top, 4)
                .padding(.bottom, 2)

                LegendRow(
                    label: "Swap Used",
                    value: sample.map { Fmt.bytes($0.swapUsed) } ?? Fmt.placeholder
                )
            }

            PanelSection(title: "Top Processes") {
                let top = ProcessSampler.topByMemory(store.processes, limit: Tokens.Panel.topN)
                ProcessList(items: top.map { ($0, Fmt.bytes($0.memoryBytes)) })
            }

            PanelFooter(
                primary: ("Activity Monitor", PanelFooter.openActivityMonitor),
                onOptions: { OptionsMenu.shared.popUpAtMouse() }
            )
        }
    }
}
