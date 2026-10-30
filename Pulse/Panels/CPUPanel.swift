import AppKit
import SwiftUI

struct CPUPanel: View {
    let store: MetricsStore

    var body: some View {
        let sample = store.cpu
        let layout = SystemInfo.coreLayout
        let history = store.cpuHistory.elements

        VStack(alignment: .leading, spacing: 0) {
            PanelHeader(
                tile: "CPU",
                tint: .blue,
                title: "Processor",
                subtitle: "\(SystemInfo.chipName) · \(layout.total) cores"
            ) {
                if let sample {
                    Text(Fmt.percent(sample.total))
                        .font(.system(size: 26, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(Thresholds.panelColor(sample.total))
                        .animation(.easeInOut(duration: Tokens.Motion.color), value: Thresholds.panelColor(sample.total))
                } else {
                    Text(Fmt.placeholder)
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }

            AreaGraph(
                up: [
                    AreaSeries(values: history.map(\.total), max: 100, color: .blue),
                    AreaSeries(values: history.map(\.system), max: 100, color: .red)
                ]
            )

            VStack(spacing: 0) {
                LegendRow(
                    dot: .blue,
                    label: "User",
                    value: sample.map { Fmt.percent1($0.user) } ?? Fmt.placeholder
                )
                LegendRow(
                    dot: .red,
                    label: "System",
                    value: sample.map { Fmt.percent1($0.system) } ?? Fmt.placeholder
                )
                LegendRow(
                    dot: .primary.opacity(0.22),
                    label: "Idle",
                    value: sample.map { Fmt.percent1($0.idle) } ?? Fmt.placeholder
                )
            }
            .padding(.top, 10)

            PanelSection(
                title: "Cores",
                detail: layout.efficiency > 0
                    ? "\(layout.performance) Performance · \(layout.efficiency) Efficiency"
                    : "\(layout.performance) Cores"
            ) {
                CoreBars(values: sample?.perCore ?? [], layout: layout)
            }

            PanelSection(title: "Top Processes") {
                let top = ProcessSampler.topByCPU(store.processes, limit: Tokens.Panel.topN)
                ProcessList(items: top.map { ($0, Fmt.percent1($0.cpuPercent)) })
            }

            PanelSection {
                LegendRow(
                    label: "Load Average",
                    value: sample.map { Fmt.load($0.load) } ?? Fmt.placeholder
                )
                LegendRow(
                    label: "Uptime",
                    value: Fmt.uptime(SystemInfo.uptimeSeconds)
                )
            }

            PanelFooter(
                primary: ("Activity Monitor", PanelFooter.openActivityMonitor),
                onOptions: { OptionsMenu.shared.popUpAtMouse() }
            )
        }
    }
}
