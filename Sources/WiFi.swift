import CoreWLAN
import Foundation
import SystemConfiguration

enum WiFi {
    enum Check {
        case healthy, failed, outsideNetwork
    }

    static func check(_ interface: CWInterface, network: String) throws -> Check {
        guard interface.powerOn() else { return .outsideNetwork }
        let current = interface.ssid()
        if let current, current != network {
            return .outsideNetwork
        }

        let name = interface.interfaceName
        if current == nil {
            let candidates = try interface.scanForNetworks(withName: network)
            guard candidates.contains(where: { $0.ssid == network }) else {
                return .outsideNetwork
            }
            if let current = interface.ssid(), current != network { return .outsideNetwork }
            if interface.ssid() == nil { return .failed }
        }

        guard let name else { return .failed }
        if let router = gateway(for: name), try responds(router, on: name) { return .healthy }
        return try responds("1.1.1.1", on: name) ? .healthy : .failed
    }

    private static func responds(_ host: String, on interface: String) throws -> Bool {
        let ping = Process()
        ping.executableURL = URL(fileURLWithPath: "/sbin/ping")
        ping.arguments = ["-n", "-q", "-b", interface, "-c", "3", "-t", "5", host]
        ping.standardOutput = FileHandle.nullDevice
        ping.standardError = FileHandle.nullDevice
        try ping.run()
        ping.waitUntilExit()
        return ping.terminationStatus == 0
    }

    private static func gateway(for interface: String) -> String? {
        let primary = SCDynamicStoreCopyValue(nil, "State:/Network/Global/IPv4" as CFString) as? [String: Any]
        if primary?["PrimaryInterface"] as? String == interface, let router = primary?["Router"] as? String {
            return router
        }
        let pattern = "State:/Network/Service/[^/]+/IPv4" as CFString
        let states = SCDynamicStoreCopyMultiple(nil, nil, [pattern] as CFArray) as? [String: [String: Any]]
        return states?.values.first { $0["InterfaceName"] as? String == interface && $0["Router"] is String }?["Router"] as? String
    }
}
