import SwiftUI

struct CoreBars: View {
    let values: [Double]
    let layout: CoreLayout

    var body: some View {
        let total = max(1, layout.performance + layout.efficiency)
        HStack(spacing: 3) {
            ForEach(0..<total, id: \.self) { index in
                let isEfficiency = index >= layout.performance
                let pct = index < values.count ? min(100, max(0, values[index])) : 0
                GeometryReader { geo in
                    ZStack(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(Color.primary.opacity(0.07))

                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(isEfficiency ? Color.cyan : Color.blue)
                            .frame(height: geo.size.height * CGFloat(pct / 100.0))
                            .animation(.easeOut(duration: Tokens.Motion.bars), value: pct)
                    }
                }
            }
        }
        .frame(height: Tokens.Panel.coreBarsHeight)
    }
}
