import Foundation
import PartoutRuntime

public struct VPNServerInput: Sendable {
    public var title: String
    public var openvpnConfig: Data?
    public var wireguardConfig: Data?
    public var credentials: OpenVPN.Credentials?

    public init(
        title: String,
        openvpnConfig: Data? = nil,
        wireguardConfig: Data? = nil,
        credentials: OpenVPN.Credentials? = nil
    ) {
        self.title = title
        self.openvpnConfig = openvpnConfig
        self.wireguardConfig = wireguardConfig
        self.credentials = credentials
    }

    public var kind: VPNProtocolKind {
        if wireguardConfig != nil { return .wireguard }
        return .openvpn
    }
}

public enum VPNError: Error, Sendable {
    case missingConfiguration
    case badConfiguration
    case missingAppGroup
    case unsupportedProtocol
}

public enum VPNProfileBuilder {
    public static func makeProfile(
        id: UUID = UUID(),
        name: String,
        input: VPNServerInput,
        dnsServers: [String] = ["1.1.1.1"]
    ) throws -> Profile {
        var builder = Profile.Builder(id: id)
        builder.name = name

        switch input.kind {
        case .openvpn:
            var module: OpenVPNModule = try importModule(
                input.openvpnConfig,
                fileExtension: "ovpn"
            )
            if let credentials = input.credentials {
                var moduleBuilder = module.builder()
                moduleBuilder.credentials = credentials
                module = try moduleBuilder.build()
            }
            builder.modules.append(module)

        case .wireguard:
            let module: WireGuardModule = try importModule(
                input.wireguardConfig,
                fileExtension: "wg"
            )
            builder.modules.append(module)

        case .ikev2:
            throw VPNError.unsupportedProtocol
        }

        var dns = DNSModule.Builder()
        dns.protocolType = .cleartext
        dns.servers = dnsServers
        builder.modules.append(try dns.build())

        var ip = IPModule.Builder()
        ip.ipv4 = IPSettings(subnet: nil)
            .including(routes: [.init(defaultWithGateway: nil)])
        builder.modules.append(ip.build())

        if let vpnModule = builder.modules.first(where: {
            $0 is OpenVPNModule || $0 is WireGuardModule
        }) {
            builder.activeModulesIds.insert(vpnModule.id)
        }
        if let dnsModule = builder.modules.first(where: { $0 is DNSModule }) {
            builder.activeModulesIds.insert(dnsModule.id)
        }

        return try builder.build()
    }

    private static func importModule<M: Decodable>(
        _ data: Data?,
        fileExtension: String
    ) throws -> M {
        guard let data else { throw VPNError.missingConfiguration }
        let importer = PartoutImporter()
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(fileExtension)
        try data.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        guard let module = try importer.importModule(M.self, url: url) else {
            throw VPNError.badConfiguration
        }
        return module
    }
}

extension OpenVPN.Credentials {
    public init(username: String, password: String) {
        var builder = OpenVPN.Credentials.Builder()
        builder.username = username
        builder.password = password
        self = builder.build()
    }
}
