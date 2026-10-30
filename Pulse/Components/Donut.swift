import SwiftUI

struct DonutSegment {
    let fraction: Double
    let color: Color
}

struct Donut: View {
    let segments: [DonutSegment]
    let value: String
    let caption: String

    var body: some View {
        ZStack {
            Canvas { context, size in
                let ring = Tokens.Panel.donutRing
                let rect = CGRect(origin: .zero, size: size).insetBy(dx: ring / 2, dy: ring / 2)
                let center = CGPoint(x: rect.midX, y: rect.midY)
                let radius = min(rect.width, rect.height) / 2

                // Background track
                var track = Path()
                track.addArc(
                    center: center,
                    radius: radius,
                    startAngle: .degrees(0),
                    endAngle: .degrees(360),
                    clockwise: false
                )
                context.stroke(track, with: .color(.primary.opacity(0.12)), lineWidth: ring)

                var startDeg: Double = -90.0
                for seg in segments {
                    let clamped = min(1.0, max(0.0, seg.fraction))
                    guard clamped > 0 else { continue }
                    let sweep = clamped * 360.0
                    let endDeg = min(270.0, startDeg + sweep)
                    var arc = Path()
                    arc.addArc(
                        center: center,
                        radius: radius,
                        startAngle: .degrees(startDeg),
                        endAngle: .degrees(endDeg),
                        clockwise: false
                    )
                    context.stroke(arc, with: .color(seg.color), lineWidth: ring)
                    startDeg = endDeg
                }
            }

            VStack(spacing: 1) {
                Text(value)
                    .font(.system(size: 15, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                Text(caption)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)
        }
        .frame(width: Tokens.Panel.donutSize, height: Tokens.Panel.donutSize)
    }
}
