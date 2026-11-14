import AppKit

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

/// Draws the readout into a template image, in solid black: the menu bar only
/// uses the alpha, and tints it for light/dark, inactive screens and clicks.
///
/// Plain Core Text rather than SwiftUI's ImageRenderer, which spun up a render
/// pass (and a Metal device) on every value change. Each string is laid out
/// once and kept (percentages repeat constantly), so most updates only draw
/// glyphs. The image draws lazily, so it is sharp at each display's scale.
///
/// Layout: stats are a label row (9 pt) over a value row (13 pt); network is
/// an arrow column, then right-aligned rates so short values don't leave a gap.
@MainActor
enum StatusItemImage {
    @MainActor private enum Style: Hashable {
        case label, value, net

        var font: NSFont {
            switch self {
            case .label: return StatusItemImage.labelFont
            case .value: return StatusItemImage.valueFont
            case .net: return StatusItemImage.netFont
            }
        }

        var tracking: CGFloat {
            switch self {
            case .label: return 0.18
            case .value: return -0.14
            case .net: return 0
            }
        }
    }

    private static let labelFont = NSFont.systemFont(ofSize: Tokens.MenuBar.labelSize, weight: .medium)
    private static let valueFont = numberFont(size: Tokens.MenuBar.valueSize)
    private static let netFont = numberFont(size: Tokens.MenuBar.netSize)

    /// A typeset string. Laying text out is the expensive part (Core Text
    /// rebuilds the variable-weight font each time), drawing a line is not.
    @MainActor private final class Line {
        let ctLine: CTLine
        let width: CGFloat
        let height: CGFloat     // what NSAttributedString.size() reports
        let ascent: CGFloat

        init(_ string: String, style: Style) {
            var attributes: [NSAttributedString.Key: Any] = [
                .font: style.font,
                NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(gray: 0, alpha: 1)
            ]
            if style.tracking != 0 { attributes[.tracking] = style.tracking }
            ctLine = CTLineCreateWithAttributedString(NSAttributedString(string: string, attributes: attributes))
            var ascent: CGFloat = 0, descent: CGFloat = 0, leading: CGFloat = 0
            width = CGFloat(CTLineGetTypographicBounds(ctLine, &ascent, &descent, &leading))
            height = (ascent + descent).rounded(.up)
            self.ascent = ascent
        }

        /// Vertically centred in a row of `height` and snapped to device
        /// pixels. The rounding rule per item is what reproduces the old
        /// SwiftUI rendering pixel for pixel at both 1x and 2x.
        func draw(in context: CGContext, x: CGFloat, rowY: CGFloat, rowHeight: CGFloat,
                  scale: CGFloat, rounding: FloatingPointRoundingRule) {
            let top = ((rowY + (rowHeight - height) / 2) * scale).rounded(rounding) / scale
            context.textPosition = CGPoint(x: (x * scale).rounded() / scale, y: top + ascent)
            CTLineDraw(ctLine, context)
        }
    }

    private struct LineKey: Hashable {
        let string: String
        let style: Style
    }

    /// Labels and percentages: bounded by construction (three labels, the
    /// placeholder and 0–100%), so kept for good.
    private static var lines: [LineKey: Line] = [:]
    /// Network rates rarely repeat; keep only the ones in recent use.
    private static var netLines = GenerationCache<String, Line>(generationSize: 64)

    private static func line(_ string: String, _ style: Style) -> Line {
        if style == .net {
            return netLines.value(for: string) { Line(string, style: .net) }
        }
        let key = LineKey(string: string, style: style)
        if let cached = lines[key] { return cached }
        let line = Line(string, style: style)
        lines[key] = line
        return line
    }

    static func make(_ content: StatusItemContent) -> NSImage {
        let height = Tokens.MenuBar.itemHeight
        let width: CGFloat
        let draw: (CGContext, CGFloat) -> Void

        switch content {
        case let .stat(label, value):
            let top = line(label, .label)
            let bottom = line(value, .value)
            width = max(Tokens.MenuBar.statMinWidth, top.width, bottom.width)
            let y = (height - 22) / 2   // 9 + 13 rows
            draw = { context, scale in
                top.draw(in: context, x: 0, rowY: y, rowHeight: 9, scale: scale, rounding: .up)
                bottom.draw(in: context, x: 0, rowY: y + 9, rowHeight: 13, scale: scale, rounding: .up)
            }

        case let .network(up, down):
            let arrows = [line("↑", .net), line("↓", .net)]
            let rates = [line(up, .net), line(down, .net)]
            let arrowWidth = arrows.map(\.width).max() ?? 0
            let rateWidth = max(Tokens.MenuBar.netWidth, rates.map(\.width).max() ?? 0)
            let rateX = arrowWidth + 3
            width = rateX + rateWidth
            let row: CGFloat = 10.5
            let y = (height - row * 2) / 2
            draw = { context, scale in
                for i in 0..<2 {
                    let rowY = y + row * CGFloat(i)
                    arrows[i].draw(in: context, x: (arrowWidth - arrows[i].width) / 2, rowY: rowY, rowHeight: row,
                                   scale: scale, rounding: .toNearestOrAwayFromZero)
                    rates[i].draw(in: context, x: rateX + rateWidth - rates[i].width, rowY: rowY, rowHeight: row,
                                  scale: scale, rounding: .toNearestOrAwayFromZero)
                }
            }
        }

        let image = NSImage(size: NSSize(width: retinaCeil(width), height: height), flipped: true) { _ in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            let scale = max(1, abs(context.userSpaceToDeviceSpaceTransform.a))
            context.saveGState()
            context.textMatrix = CGAffineTransform(scaleX: 1, y: -1)   // flipped image
            draw(context, scale)
            context.restoreGState()
            return true
        }
        image.isTemplate = true
        return image
    }

    /// Item widths land on the 2x pixel grid, as SwiftUI sized them at 2x.
    private static func retinaCeil(_ value: CGFloat) -> CGFloat {
        (value * 2).rounded(.up) / 2
    }

    /// System font with monospaced digits at an in-between weight. The named
    /// weights snap (regular 400, medium 510), so set SF's variable weight axis.
    private static func numberFont(size: CGFloat) -> NSFont {
        let base = NSFont.monospacedDigitSystemFont(ofSize: size, weight: .regular)
        let weightAxis = 0x7767_6874 // 'wght'
        let descriptor = base.fontDescriptor.addingAttributes([
            NSFontDescriptor.AttributeName(rawValue: kCTFontVariationAttribute as String):
                [weightAxis: Tokens.MenuBar.numberWeight]
        ])
        return NSFont(descriptor: descriptor, size: size) ?? base
    }
}
