import Foundation
import PartoutRuntime

public struct VPNConnectionObserver: Sendable {
    private let tunnel: Tunnel

    public init(tunnel: Tunnel) {
        self.tunnel = tunnel
    }

    public var currentStatus: TunnelStatus {
        get async { await tunnel.status }
    }

    public func snapshotsStream() -> AsyncStream<[Profile.ID: TunnelSnapshot]> {
        tunnel.snapshotsStream
    }

    public func connect(_ profile: Profile) async throws {
        try await tunnel.install(profile, connect: true)
    }

    public func disconnect(_ profileId: Profile.ID) async throws {
        try await tunnel.disconnect(from: profileId)
    }
}
