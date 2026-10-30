import Foundation

enum InterfaceKind: Equatable {
    case wifi
    case ethernet
    case other
}

struct InterfaceInfo: Equatable {
    let bsdName: String                 // "en0"
    let kind: InterfaceKind
    let ssid: String?                   // nil without Location permission
    let localIPv4: String?
    let linkSpeedMbps: Int?
}

struct NetworkSample: Equatable {
    let rxPerSec: Double                // bytes/s
    let txPerSec: Double                // bytes/s
    let sessionRx: UInt64               // since launch
    let sessionTx: UInt64               // since launch
    let primary: InterfaceInfo?

    init(
        rxPerSec: Double,
        txPerSec: Double,
        sessionRx: UInt64,
        sessionTx: UInt64,
        primary: InterfaceInfo?
    ) {
        self.rxPerSec = Self.sanitize(rxPerSec)
        self.txPerSec = Self.sanitize(txPerSec)
        self.sessionRx = sessionRx
        self.sessionTx = sessionTx
        self.primary = primary
    }

    private static func sanitize(_ v: Double) -> Double {
        guard v.isFinite else { return 0 }
        return max(0, v)
    }
}
