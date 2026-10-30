import CoreGraphics

enum Tokens {
    enum MenuBar {
        static let itemHeight: CGFloat = 22   // standard menu bar thickness
        static let itemPadX: CGFloat = 0   // macOS already spaces status items apart
        static let labelSize: CGFloat = 8
        static let valueSize: CGFloat = 12
        static let netSize: CGFloat = 9
        static let numberWeight: CGFloat = 480  // SF weight axis: between regular (400) and medium (510)
        static let statMinWidth: CGFloat = 27   // fits "88%" at valueSize; "100%" widens the item
        static let netWidth: CGFloat = 44       // rate column; fits "88.8 KB/s" at netSize
    }

    enum Panel {
        static let width: CGFloat = 320
        static let padding: CGFloat = 14
        static let radius: CGFloat = 16
        static let gapBelowMenuBar: CGFloat = 6
        static let screenInset: CGFloat = 8
        static let graphHeight: CGFloat = 86
        static let graphRadius: CGFloat = 10
        static let sectionGap: CGFloat = 11
        static let coreBarsHeight: CGFloat = 38
        static let donutSize: CGFloat = 86
        static let donutRing: CGFloat = 13
        static let processIcon: CGFloat = 16
        static let topN: Int = 5
    }

    enum Motion {
        static let open: Double = 0.16
        static let color: Double = 0.4
        static let bars: Double = 0.6
        static let slide: CGFloat = 6
        static let scale: CGFloat = 0.985
    }

    static let historyLength: Int = 60
}
