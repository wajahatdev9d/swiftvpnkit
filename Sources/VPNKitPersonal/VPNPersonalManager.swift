import Foundation
import NetworkExtension

public protocol VPNPersonalDelegate: AnyObject {
    func vpnPersonalConnecting()
    func vpnPersonalDisconnecting()
    func vpnPersonalConnected()
    func vpnPersonalDisconnected()
    func vpnPersonalInvalidConfig()
    func vpnPersonalReasserting()
}

public final class VPNPersonalManager: @unchecked Sendable {
    nonisolated(unsafe) public static let shared = VPNPersonalManager()

    public let vpnManager = NEVPNManager.shared()
    public weak var delegate: VPNPersonalDelegate?

    public var credentials = VPNPersonalCredentials()
    public var displayName = "VPN"
    public var ikev2PasswordKeychainTag = "com.example.vpn.ikev2.password"

    private var keychain: VPNPersonalKeychain {
        VPNPersonalKeychain(ikev2PasswordTag: ikev2PasswordKeychainTag)
    }

    private var lastReportedStatus: NEVPNStatus?
    private var pendingDisconnectWorkItem: DispatchWorkItem?

    private init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didChangeStatus(_:)),
            name: .NEVPNStatusDidChange,
            object: vpnManager.connection
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        pendingDisconnectWorkItem?.cancel()
    }

    public func disconnect() {
        pendingDisconnectWorkItem?.cancel()
        lastReportedStatus = .disconnecting
        vpnManager.connection.stopVPNTunnel()
    }

    public func resetStatusTracking() {
        pendingDisconnectWorkItem?.cancel()
        lastReportedStatus = nil
    }

    public func connect(completion: @escaping (_ success: Bool) -> Void) {
        connect(attempt: 1, completion: completion)
    }

    public func getStatus(_ completion: @escaping (NEVPNStatus?) -> Void) {
        if vpnManager.protocolConfiguration == nil {
            vpnManager.loadFromPreferences { _ in
                completion(self.vpnManager.connection.status)
            }
        } else {
            completion(vpnManager.connection.status)
        }
    }

    public func handleStatus(_ status: NEVPNStatus) {
        applyStatus(status)
    }

    private func connect(attempt: Int, completion: @escaping (_ success: Bool) -> Void) {
        if let validationError = validateBeforeConnect() {
            VPNKitLogger.error("VPNPersonal preflight failed: \(validationError)")
            completion(false)
            return
        }
        guard let protocolConfiguration = activeProtocolConfiguration() else {
            completion(false)
            return
        }

        vpnManager.loadFromPreferences { [weak self] error in
            guard let self else {
                completion(false)
                return
            }
            if let error {
                VPNKitLogger.error("VPNPersonal loadPreferences failed: \(error.localizedDescription)")
                completion(false)
                return
            }

            let hadProfile = self.vpnManager.protocolConfiguration != nil
            self.vpnManager.protocolConfiguration = protocolConfiguration
            self.vpnManager.localizedDescription = self.displayName
            self.vpnManager.isEnabled = true
            self.vpnManager.isOnDemandEnabled = false
            self.vpnManager.saveToPreferences { [weak self] error in
                guard let self else {
                    completion(false)
                    return
                }
                if let error {
                    VPNKitLogger.error("VPNPersonal saveToPreferences failed: \(error.localizedDescription)")
                    completion(false)
                    return
                }

                let settleDelay: TimeInterval = hadProfile ? 0.15 : 0.75
                DispatchQueue.main.asyncAfter(deadline: .now() + settleDelay) {
                    self.reloadAndStartTunnel(attempt: attempt, completion: completion)
                }
            }
        }
    }

    private func reloadAndStartTunnel(attempt: Int, completion: @escaping (_ success: Bool) -> Void) {
        vpnManager.loadFromPreferences { [weak self] error in
            guard let self else {
                completion(false)
                return
            }
            if let error {
                VPNKitLogger.error("VPNPersonal reloadPreferences failed: \(error.localizedDescription)")
                self.retryConnectIfNeeded(attempt: attempt, completion: completion)
                return
            }
            self.startVPNTunnel(attempt: attempt, completion: completion)
        }
    }

    private func startVPNTunnel(attempt: Int, completion: @escaping (_ success: Bool) -> Void) {
        guard vpnManager.protocolConfiguration != nil else {
            VPNKitLogger.error("VPNPersonal start blocked — protocolConfiguration nil attempt=\(attempt)")
            retryConnectIfNeeded(attempt: attempt, completion: completion)
            return
        }
        resetStatusTracking()
        do {
            try vpnManager.connection.startVPNTunnel()
            VPNKitLogger.info(
                "VPNPersonal startVPNTunnel OK attempt=\(attempt) kind=\(credentials.kind) " +
                "server=\(credentials.serverAddress)"
            )
            completion(true)
        } catch {
            VPNKitLogger.error("VPNPersonal startVPNTunnel failed attempt=\(attempt): \(error.localizedDescription)")
            retryConnectIfNeeded(attempt: attempt, completion: completion)
        }
    }

    private func retryConnectIfNeeded(attempt: Int, completion: @escaping (_ success: Bool) -> Void) {
        guard attempt < 3 else {
            completion(false)
            return
        }
        VPNKitLogger.info("VPNPersonal retry connect attempt=\(attempt + 1)")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6 * Double(attempt)) { [weak self] in
            self?.connect(attempt: attempt + 1, completion: completion)
        }
    }

    private func validateBeforeConnect() -> String? {
        switch credentials.kind {
        case .ikev2:
            if credentials.password.isEmpty { return "IKEv2 password missing" }
            if credentials.userName.isEmpty { return "IKEv2 username missing" }
            if credentials.serverAddress.isEmpty { return "IKEv2 server missing" }
            if credentials.remoteIdentifier.isEmpty { return "IKEv2 remote ID missing" }
        case .ipsec:
            if credentials.sharedKey.isEmpty { return "IPSec shared secret missing" }
            if credentials.password.isEmpty { return "IPSec password missing" }
            if credentials.serverAddress.isEmpty { return "IPSec server missing" }
        }
        return nil
    }

    private func activeProtocolConfiguration() -> NEVPNProtocol? {
        switch credentials.kind {
        case .ikev2:
            return ikev2Configuration()
        case .ipsec:
            return ipsecConfiguration()
        }
    }

    private func ipsecConfiguration() -> NEVPNProtocolIPSec? {
        guard !credentials.sharedKey.isEmpty else {
            VPNKitLogger.error("VPNPersonal IPSec missing shared secret")
            return nil
        }

        let configuration = NEVPNProtocolIPSec()
        configuration.username = credentials.userName
        configuration.serverAddress = credentials.serverAddress
        configuration.authenticationMethod = .sharedSecret
        guard
            let sharedRef = keychain.save(key: VPNPersonalKeychain.sharedKey, value: credentials.sharedKey),
            let passwordRef = keychain.save(key: VPNPersonalKeychain.passwordKey, value: credentials.password)
        else {
            VPNKitLogger.error("VPNPersonal IPSec keychain refs missing for \(credentials.serverAddress)")
            return nil
        }
        configuration.sharedSecretReference = sharedRef
        configuration.passwordReference = passwordRef
        configuration.useExtendedAuthentication = true
        configuration.disconnectOnSleep = false
        return configuration
    }

    private func ikev2Configuration() -> NEVPNProtocolIKEv2? {
        guard
            !credentials.serverAddress.isEmpty,
            !credentials.remoteIdentifier.isEmpty,
            !credentials.userName.isEmpty,
            !credentials.password.isEmpty
        else {
            VPNKitLogger.error("VPNPersonal IKEv2 missing server, remoteId, username, or password")
            return nil
        }

        let configuration = NEVPNProtocolIKEv2()
        configuration.serverAddress = credentials.serverAddress
        configuration.remoteIdentifier = credentials.remoteIdentifier
        configuration.username = credentials.userName
        guard let passwordRef = keychain.saveIKEv2Password(credentials.password) else {
            VPNKitLogger.error("VPNPersonal IKEv2 password ref missing for \(credentials.serverAddress)")
            return nil
        }
        configuration.passwordReference = passwordRef
        configuration.authenticationMethod = .none
        configuration.useExtendedAuthentication = true
        configuration.disconnectOnSleep = false
        return configuration
    }

    private func applyStatus(_ status: NEVPNStatus) {
        guard status != lastReportedStatus else { return }

        VPNKitLogger.info(
            "VPNPersonal status=\(status) kind=\(credentials.kind) server=\(credentials.serverAddress)"
        )

        if status == .disconnected, lastReportedStatus == .connected || lastReportedStatus == .connecting {
            pendingDisconnectWorkItem?.cancel()
            let work = DispatchWorkItem { [weak self] in
                guard let self else { return }
                guard self.vpnManager.connection.status == .disconnected else { return }
                guard self.lastReportedStatus != .disconnected else { return }
                self.lastReportedStatus = .disconnected
                self.delegate?.vpnPersonalDisconnected()
            }
            pendingDisconnectWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
            return
        }

        pendingDisconnectWorkItem?.cancel()
        lastReportedStatus = status

        switch status {
        case .invalid:
            delegate?.vpnPersonalInvalidConfig()
        case .disconnected:
            delegate?.vpnPersonalDisconnected()
        case .connecting:
            delegate?.vpnPersonalConnecting()
        case .connected:
            delegate?.vpnPersonalConnected()
        case .reasserting:
            delegate?.vpnPersonalReasserting()
        case .disconnecting:
            delegate?.vpnPersonalDisconnecting()
        @unknown default:
            break
        }
    }

    @objc private func didChangeStatus(_ notification: Notification) {
        guard let connection = notification.object as? NEVPNConnection else { return }
        guard connection === vpnManager.connection else { return }
        applyStatus(connection.status)
    }
}
