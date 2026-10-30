import SwiftUI

struct LegendRow: View {
    let dot: Color?
    let label: String
    let value: String

    init(dot: Color? = nil, label: String, value: String) {
        self.dot = dot
        self.label = label
        self.value = value
    }

    var body: some View {
        HStack(spacing: 8) {
            if let dot {
                Circle()
                    .fill(dot)
                    .frame(width: 8, height: 8)
            }
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.primary)
            Spacer(minLength: 8)
            Text(value)
                .font(.system(size: 12))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2.5)
    }
}
