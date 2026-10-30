import CoreWLAN
import Darwin
import Foundation
import SystemConfiguration

struct RawInterfaceCounters: Equatable {
    let name: String
    let flags: Int32
    let rxBytes: UInt64
    let txBytes: UInt64
    let baudrate: UInt64
}

final class NetworkSampler: Sampler {
    typealias CountersProvider = () -> [RawInterfaceCounters]
    typealias PrimaryInfoProvider = ([RawInterfaceCounters]) -> InterfaceInfo?

    static let excludedPrefixes: [String] = [
        "lo", "awdl", "llw", "utun", "bridge", "gif", "stf", "anpi", "ap"
    ]

    private let countersProvider: CountersProvider
    private let primaryProvider: PrimaryInfoProvider

    private var previousByInterface: [String: (rx: UInt64, tx: UInt64)] = [:]
    private var previousTime: ContinuousClock.Instant?
    private var previousPrimaryName: String?
    private var sessionRx: UInt64 = 0
    private var sessionTx: UInt64 = 0

    init(
        countersProvider: @escaping CountersProvider = NetworkSampler.readInterfaceCounters,
        primaryProvider: @escaping PrimaryInfoProvider = NetworkSampler.resolvePrimaryInterface
    ) {
        self.countersProvider = countersProvider
        self.primaryProvider = primaryProvider
    }

    func reset() {
        previousByInterface.removeAll()
        previousTime = nil
    }

    static func shouldIncludeInterface(name: String, flags: Int32) -> Bool {
        let isUp = (flags & Int32(IFF_UP)) != 0
        let isLoopback = (flags & Int32(IFF_LOOPBACK)) != 0
        guard isUp && !isLoopback else { return false }
        for prefix in excludedPrefixes {
            if name.hasPrefix(prefix) {
                return false
            }
        }
        return true
    }

    func sample(now: ContinuousClock.Instant) -> NetworkSample? {
        let rawList = countersProvider()
        let active = rawList.filter { Self.shouldIncludeInterface(name: $0.name, flags: $0.flags) }
        let primary = primaryProvider(rawList)

        if let prevPrimary = previousPrimaryName,
           let currentPrimary = primary?.bsdName,
           prevPrimary != currentPrimary {
            reset()
        }
        previousPrimaryName = primary?.bsdName

        var currentMap: [String: (rx: UInt64, tx: UInt64)] = [:]
        for item in active {
            currentMap[item.name] = (rx: item.rxBytes, tx: item.txBytes)
        }

        guard let prevTime = previousTime else {
            previousByInterface = currentMap
            previousTime = now
            return nil
        }

        let elapsed = now - prevTime
        let seconds = Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
        if seconds <= 0 || seconds > 5.0 {
            previousByInterface = currentMap
            previousTime = now
            return nil
        }

        var deltaRx: UInt64 = 0
        var deltaTx: UInt64 = 0

        for (name, cur) in currentMap {
            if let prev = previousByInterface[name] {
                if cur.rx >= prev.rx {
                    deltaRx &+= (cur.rx - prev.rx)
                }
                if cur.tx >= prev.tx {
                    deltaTx &+= (cur.tx - prev.tx)
                }
            }
        }

        previousByInterface = currentMap
        previousTime = now

        sessionRx &+= deltaRx
        sessionTx &+= deltaTx

        let rxRate = Double(deltaRx) / seconds
        let txRate = Double(deltaTx) / seconds

        return NetworkSample(
            rxPerSec: rxRate,
            txPerSec: txRate,
            sessionRx: sessionRx,
            sessionTx: sessionTx,
            primary: primary
        )
    }

    static func readInterfaceCounters() -> [RawInterfaceCounters] {
        var mib: [Int32] = [CTL_NET, PF_ROUTE, 0, 0, NET_RT_IFLIST2, 0]
        var len: Int = 0
        guard sysctl(&mib, 6, nil, &len, nil, 0) == 0, len > 0 else { return [] }

        var buffer = [UInt8](repeating: 0, count: len)
        guard sysctl(&mib, 6, &buffer, &len, nil, 0) == 0 else { return [] }

        var results: [RawInterfaceCounters] = []
        var offset = 0
        while offset + MemoryLayout<if_msghdr>.size <= len {
            let hdrBounds = buffer.withUnsafeBytes { rawPtr -> (Int, Int32) in
                let hdr = rawPtr.loadUnaligned(fromByteOffset: offset, as: if_msghdr.self)
                return (Int(hdr.ifm_msglen), Int32(hdr.ifm_type))
            }
            let msgLen = hdrBounds.0
            let msgType = hdrBounds.1
            guard msgLen > 0, offset + msgLen <= len else { break }

            if msgType == RTM_IFINFO2 {
                buffer.withUnsafeBytes { rawPtr in
                    let hdr2 = rawPtr.loadUnaligned(fromByteOffset: offset, as: if_msghdr2.self)
                    let sdlOffset = offset + MemoryLayout<if_msghdr2>.size
                    if sdlOffset + MemoryLayout<sockaddr_dl>.size <= offset + msgLen {
                        let sdl = rawPtr.loadUnaligned(fromByteOffset: sdlOffset, as: sockaddr_dl.self)
                        let nameLen = Int(sdl.sdl_nlen)
                        let dataOffset = sdlOffset + 8 // offset of sdl_data in sockaddr_dl
                        if nameLen > 0, dataOffset + nameLen <= offset + msgLen {
                            let slice = rawPtr[dataOffset..<(dataOffset + nameLen)]
                            if let name = String(bytes: slice, encoding: .utf8) {
                                results.append(
                                    RawInterfaceCounters(
                                        name: name,
                                        flags: hdr2.ifm_flags,
                                        rxBytes: hdr2.ifm_data.ifi_ibytes,
                                        txBytes: hdr2.ifm_data.ifi_obytes,
                                        baudrate: hdr2.ifm_data.ifi_baudrate
                                    )
                                )
                            }
                        }
                    }
                }
            }
            offset += msgLen
        }

        return results
    }

    static func resolvePrimaryInterface(from counters: [RawInterfaceCounters]) -> InterfaceInfo? {
        let primaryName = defaultRouteInterfaceName()
            ?? counters.first(where: { shouldIncludeInterface(name: $0.name, flags: $0.flags) })?.name
        guard let bsdName = primaryName else { return nil }

        let wifiClient = CWWiFiClient.shared()
        let wifiInterface = wifiClient.interface(withName: bsdName)
        let isWiFi = wifiInterface != nil || (wifiClient.interfaceNames()?.contains(bsdName) ?? false)

        let kind: InterfaceKind
        if isWiFi {
            kind = .wifi
        } else if bsdName.hasPrefix("en") {
            kind = .ethernet
        } else {
            kind = .other
        }

        let ssid = wifiInterface?.ssid()
        let ipv4 = ipv4Address(for: bsdName)

        let linkSpeed: Int?
        if let txRate = wifiInterface?.transmitRate(), txRate > 0 {
            linkSpeed = Int(txRate.rounded())
        } else if let counter = counters.first(where: { $0.name == bsdName }), counter.baudrate >= 1_000_000 {
            linkSpeed = Int(counter.baudrate / 1_000_000)
        } else {
            linkSpeed = nil
        }

        return InterfaceInfo(
            bsdName: bsdName,
            kind: kind,
            ssid: (ssid?.isEmpty == false) ? ssid : nil,
            localIPv4: ipv4,
            linkSpeedMbps: linkSpeed
        )
    }

    private static func defaultRouteInterfaceName() -> String? {
        guard let store = SCDynamicStoreCreate(nil, "Pulse" as CFString, nil, nil),
              let dict = SCDynamicStoreCopyValue(store, "State:/Network/Global/IPv4" as CFString) as? [String: Any],
              let primary = dict["PrimaryInterface"] as? String, !primary.isEmpty else {
            return nil
        }
        return primary
    }

    private static func ipv4Address(for interfaceName: String) -> String? {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return nil }
        defer { freeifaddrs(first) }

        var ptr: UnsafeMutablePointer<ifaddrs>? = first
        while let current = ptr {
            defer { ptr = current.pointee.ifa_next }
            let name = String(cString: current.pointee.ifa_name)
            guard name == interfaceName,
                  let addr = current.pointee.ifa_addr,
                  addr.pointee.sa_family == UInt8(AF_INET) else {
                continue
            }
            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            if getnameinfo(
                addr,
                socklen_t(addr.pointee.sa_len),
                &hostname,
                socklen_t(hostname.count),
                nil,
                0,
                NI_NUMERICHOST
            ) == 0 {
                return String(cString: hostname)
            }
        }
        return nil
    }
}
