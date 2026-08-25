import Foundation
import PartoutRuntime

public final class VPNTunnelFactory: Sendable {
    public let config: VPNKitConfig
    private let store: VPNProfileStore

    public init(config: VPNKitConfig, store: VPNProfileStore = VPNProfileStore()) {
        self.config = config
        self.store = store
    }

    public func neProtocolCoder(tunnelBundleIdentifier: String) -> ProviderNEProtocolCoder {
        ProviderNEProtocolCoder(
            .global,
            tunnelBundleIdentifier: tunnelBundleIdentifier,
            coder: BasicProfileCoder(),
            uid: 1000
        )
    }

    public var tunnelDefaults: UserDefaults? {
        UserDefaults(suiteName: config.appGroupIdentifier)
    }

    public func makeTunnel(tunnelBundleIdentifier: String) async throws -> Tunnel {
        let strategy = NETunnelStrategy(
            .global,
            bundleIdentifier: tunnelBundleIdentifier,
            source: await store.stream(),
            coder: neProtocolCoder(tunnelBundleIdentifier: tunnelBundleIdentifier),
            fingerprint: { profile in profile.id.uuidString }
        )
        let tunnel = Tunnel(.global, strategy: strategy) { profileId in
            NETunnelEnvironment(profileId: profileId) { [weak strategy] pid in
                guard let strategy else { return nil }
                let output = try await strategy.sendMessage(.environment(), to: pid)
                if case .environment(let env) = output {
                    return env
                }
                return nil
            }
        }
        return tunnel
    }

    public func saveProfile(_ profile: Profile) async {
        await store.upsert(profile)
    }

    public func seedProfiles(_ profiles: [Profile]) async {
        await store.seedSnapshot(profiles)
    }
}
