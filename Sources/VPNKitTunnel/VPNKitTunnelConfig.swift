import Foundation
import PartoutRuntime

enum VPNKitTunnelConfig {
    static let appGroupIdentifier: String? = {
        Bundle.main.object(
            forInfoDictionaryKey: "PartoutAppGroupIdentifier"
        ) as? String
    }()

    static var logURL: URL? {
        guard let appGroupIdentifier else { return nil }
        let url = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        )
        return url?.appending(components: "Library", "Caches", "tunnel.log")
    }
}

extension NEProtocolDecoder where Self == ProviderNEProtocolCoder {
    static var shared: Self {
        let bundleIdentifier = Bundle.main.bundleIdentifier
            ?? (Bundle.main.object(
                forInfoDictionaryKey: "PartoutTunnelBundleIdentifier"
            ) as? String)
            ?? ""
        return ProviderNEProtocolCoder(
            .global,
            tunnelBundleIdentifier: bundleIdentifier,
            coder: BasicProfileCoder(),
            uid: 1000
        )
    }
}
