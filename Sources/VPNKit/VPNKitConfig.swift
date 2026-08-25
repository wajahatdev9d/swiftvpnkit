import Foundation

public struct VPNKitConfig: Sendable {
    public let tunnelBundleIdentifier: String
    public let appGroupIdentifier: String

    public init(
        tunnelBundleIdentifier: String,
        appGroupIdentifier: String
    ) {
        self.tunnelBundleIdentifier = tunnelBundleIdentifier
        self.appGroupIdentifier = appGroupIdentifier
    }
}

public enum VPNProtocolKind: String, CaseIterable, Sendable {
    case openvpn
    case wireguard
    case ikev2
}
