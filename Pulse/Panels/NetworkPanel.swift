import AppKit
import SwiftUI

struct NetworkPanel: View {
    let store: MetricsStore

    var body: some View {
        let sample = store.network
        let history = store.networkHistory.elements

        let rxHistory = history.map(\.rxPerSec)
        let txHistory = history.map(\.txPerSec)
        let maxDn = max(1000.0, (rxHistory.max() ?? 0) * 1.1)
        let maxUp = max(1000.0, (txHistory.max() ?? 0) * 1.1)

        VStack(alignment: .leading, spacing: 0) {
            PanelHeader(
                tile: "NET",
                tint: .orange,
                title: "Network",
                subtitle: subtitle(for: sample?.primary)
            ) {
                VStack(alignment: .trailing, spacing: 1) {
                    Text(sample.map { "↓ \(Fmt.rate($0.rxPerSec))" } ?? "↓ \(Fmt.placeholder)")
                        .font(.system(size: 12.5, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(.blue)
                    Text(sample.map { "↑ \(Fmt.rate($0.txPerSec))" } ?? "↑ \(Fmt.placeholder)")
                        .font(.system(size: 12.5, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(.orange)
                }
            }

            AreaGraph(
                up: [AreaSeries(values: rxHistory, max: maxDn, color: .blue)],
                down: [AreaSeries(values: txHistory, max: maxUp, color: .orange)],
                midline: 0.58,
                topLabel: "↓ \(Fmt.rate(maxDn))",
                bottomLabel: "↑ \(Fmt.rate(maxUp))"
            )

            VStack(spacing: 0) {
                LegendRow(
                    dot: .blue,
                    label: "Downloaded",
                    value: sample.map { Fmt.bytes($0.sessionRx) } ?? Fmt.placeholder
                )
                LegendRow(
                    dot: .orange,
                    label: "Uploaded",
                    value: sample.map { Fmt.bytes($0.sessionTx) } ?? Fmt.placeholder
                )
            }
            .padding(.top, 10)

            PanelSection {
                LegendRow(
                    label: "Local IP",
                    value: sample?.primary?.localIPv4 ?? Fmt.placeholder
                )
                if FeatureFlags.networkProbes {
                    LegendRow(label: "Public IP", value: Fmt.placeholder)
                }
                if let speed = sample?.primary?.linkSpeedMbps {
                    LegendRow(label: "Link Speed", value: "\(speed) Mbps")
                }
                if FeatureFlags.networkProbes {
                    LegendRow(label: "Ping", value: Fmt.placeholder)
                }
            }

            if FeatureFlags.perProcessNetwork {
                PanelSection(title: "Top Apps") {
                    ProcessList(items: [])
                }
            }

            PanelFooter(
                primary: ("Network Settings…", PanelFooter.openNetworkSettings),
                onOptions: { OptionsMenu.shared.popUpAtMouse() }
            )
        }
    }

    private func subtitle(for info: InterfaceInfo?) -> String {
        guard let info else { return Fmt.placeholder }
        switch info.kind {
        case .wifi:
            if let ssid = info.ssid, !ssid.isEmpty {
                return "Wi-Fi · \(ssid)"
            }
            return "Wi-Fi"
        case .ethernet:
            return "Ethernet · \(info.bsdName)"
        case .other:
            return info.bsdName
        }
    }
}
