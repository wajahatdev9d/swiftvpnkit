import Foundation

public enum VPNPersonalProtocolKind: String, Sendable {
    case ipsec
    case ikev2
}

public struct VPNPersonalCredentials: Sendable {
    public var kind: VPNPersonalProtocolKind
    public var password: String
    public var sharedKey: String
    public var serverAddress: String
    public var userName: String
    public var remoteIdentifier: String
    public var localIdentifier: String

    public init(
        kind: VPNPersonalProtocolKind = .ipsec,
        password: String = "",
        sharedKey: String = "",
        serverAddress: String = "",
        userName: String = "",
        remoteIdentifier: String = "",
        localIdentifier: String = ""
    ) {
        self.kind = kind
        self.password = password
        self.sharedKey = sharedKey
        self.serverAddress = serverAddress
        self.userName = userName
        self.remoteIdentifier = remoteIdentifier
        self.localIdentifier = localIdentifier
    }
}
