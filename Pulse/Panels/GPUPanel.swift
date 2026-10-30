import AppKit
import SwiftUI

struct GPUPanel: View {
    let store: MetricsStore

    var body: some View {
        let sample = store.gpu
        let history = store.gpuHistory.elements
        let subtitle: String = {
            if let cores = SystemInfo.gpuCoreCount {
                return "\(SystemInfo.chipName) · \(cores)-core GPU"
            }
            return SystemInfo.chipName
        }()

        VStack(alignment: .leading, spacing: 0) {
            PanelHeader(
                tile: "GPU",
                tint: .purple,
                title: "Graphics",
                subtitle: subtitle
            ) {
                if let sample {
                    Text(Fmt.percent(sample.utilization))
                        .font(.system(size: 26, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(Thresholds.panelColor(sample.utilization))
                        .animation(.easeInOut(duration: Tokens.Motion.color), value: Thresholds.panelColor(sample.utilization))
                } else {
                    Text(Fmt.placeholder)
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }

            let tilerValues = history.compactMap(\.tiler)
            let series: [AreaSeries] = {
                var list = [AreaSeries(values: history.map(\.utilization), max: 100, color: .purple)]
                if !tilerValues.isEmpty {
                    list.append(AreaSeries(values: tilerValues, max: 100, color: .cyan))
                }
                return list
            }()

            AreaGraph(up: series)

            if sample?.renderer != nil || sample?.tiler != nil {
                VStack(spacing: 0) {
                    if let renderer = sample?.renderer {
                        LegendRow(dot: .purple, label: "Renderer", value: Fmt.percent1(renderer))
                    }
                    if let tiler = sample?.tiler {
                        LegendRow(dot: .cyan, label: "Tiler", value: Fmt.percent1(tiler))
                    }
                }
                .padding(.top, 10)
            }

            if sample?.memoryInUse != nil
                || sample?.frequencyMHz != nil
                || sample?.temperatureC != nil
                || sample?.powerW != nil {
                PanelSection {
                    if let mem = sample?.memoryInUse {
                        LegendRow(label: "Memory In Use", value: Fmt.bytes(mem))
                    }
                    if let freq = sample?.frequencyMHz {
                        LegendRow(label: "Frequency", value: "\(Int(freq.rounded())) MHz")
                    }
                    if let temp = sample?.temperatureC {
                        LegendRow(label: "Temperature", value: "\(Int(temp.rounded())) °C")
                    }
                    if let power = sample?.powerW {
                        LegendRow(label: "Power", value: String(format: "%.1f W", power))
                    }
                }
            }

            PanelFooter(
                primary: ("Activity Monitor", PanelFooter.openActivityMonitor),
                onOptions: { OptionsMenu.shared.popUpAtMouse() }
            )
        }
    }
}
