import SwiftUI

struct AreaSeries {
    let values: [Double]
    let max: Double
    let color: Color
}

struct AreaGraph: View {
    let up: [AreaSeries]
    let down: [AreaSeries]
    let midline: Double     // 0…1, 1 = no down half
    let topLabel: String?
    let bottomLabel: String?

    init(
        up: [AreaSeries],
        down: [AreaSeries] = [],
        midline: Double = 1.0,
        topLabel: String? = nil,
        bottomLabel: String? = nil
    ) {
        self.up = up
        self.down = down
        self.midline = min(1.0, max(0.0, midline))
        self.topLabel = topLabel
        self.bottomLabel = bottomLabel
    }

    var body: some View {
        ZStack {
            Canvas { context, size in
                let w = size.width
                let h = size.height
                guard w > 0, h > 0 else { return }

                if down.isEmpty && midline >= 1.0 {
                    drawGrid(context: &context, width: w, height: h, lines: 3)
                }

                let midY = round(h * midline)

                for series in up {
                    drawArea(
                        context: &context,
                        width: w,
                        height: h,
                        series: series,
                        baseY: midY,
                        direction: -1
                    )
                }

                for series in down {
                    drawArea(
                        context: &context,
                        width: w,
                        height: h,
                        series: series,
                        baseY: midY,
                        direction: 1
                    )
                }

                if !down.isEmpty || midline < 1.0 {
                    let divider = Path(CGRect(x: 0, y: midY, width: w, height: 1))
                    context.fill(divider, with: .color(.primary.opacity(0.15)))
                }
            }

            if let topLabel {
                Text(topLabel)
                    .font(.system(size: 9.5))
                    .monospacedDigit()
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(.top, 5)
                    .padding(.trailing, 8)
            }

            if let bottomLabel {
                Text(bottomLabel)
                    .font(.system(size: 9.5))
                    .monospacedDigit()
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(.bottom, 5)
                    .padding(.trailing, 8)
            }
        }
        .frame(height: Tokens.Panel.graphHeight)
        .background(Color.black.opacity(0.24))
        .clipShape(RoundedRectangle(cornerRadius: Tokens.Panel.graphRadius, style: .continuous))
    }

    private func drawGrid(context: inout GraphicsContext, width: CGFloat, height: CGFloat, lines: Int) {
        var path = Path()
        for i in 1...lines {
            let y = round(height * CGFloat(i) / CGFloat(lines + 1)) + 0.5
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: width, y: y))
        }
        context.stroke(path, with: .color(.primary.opacity(0.06)), lineWidth: 1)
    }

    private func drawArea(
        context: inout GraphicsContext,
        width: CGFloat,
        height: CGFloat,
        series: AreaSeries,
        baseY: CGFloat,
        direction: CGFloat
    ) {
        let count = series.values.count
        guard count > 0 else { return }

        let cap = max(2, Tokens.historyLength)
        let dx = width / CGFloat(cap - 1)
        let startIndex = cap - count
        let maxVal = max(series.max, 0.0001)
        let span = direction < 0 ? max(0, baseY - 4) : max(0, height - baseY - 4)

        func pointY(_ val: Double) -> CGFloat {
            let norm = min(1.0, max(0.0, val / maxVal))
            return baseY + direction * CGFloat(norm) * span
        }

        var linePath = Path()
        var areaPath = Path()

        let firstX = CGFloat(startIndex) * dx
        areaPath.move(to: CGPoint(x: firstX, y: baseY))

        for (i, val) in series.values.enumerated() {
            let x = CGFloat(startIndex + i) * dx
            let y = pointY(val)
            let pt = CGPoint(x: x, y: y)
            if i == 0 {
                linePath.move(to: pt)
            } else {
                linePath.addLine(to: pt)
            }
            areaPath.addLine(to: pt)
        }

        let lastX = CGFloat(startIndex + count - 1) * dx
        areaPath.addLine(to: CGPoint(x: lastX, y: baseY))
        areaPath.closeSubpath()

        let gradientStart = CGPoint(x: 0, y: baseY + direction * span)
        let gradientEnd = CGPoint(x: 0, y: baseY)
        let gradient = Gradient(colors: [
            series.color.opacity(0.55),
            series.color.opacity(0.06)
        ])

        context.fill(
            areaPath,
            with: .linearGradient(gradient, startPoint: gradientStart, endPoint: gradientEnd)
        )
        context.stroke(
            linePath,
            with: .color(series.color),
            style: StrokeStyle(lineWidth: 1.4, lineJoin: .round)
        )
    }
}
