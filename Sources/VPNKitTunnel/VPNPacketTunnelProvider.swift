import Foundation
import PartoutRuntime

@preconcurrency import NetworkExtension

extension NSObject: @retroactive @unchecked Sendable {}

open class VPNPacketTunnelProvider: NEPacketTunnelProvider, @unchecked Sendable {
    private var runtime: PartoutProviderRuntime?

    public override init() {
        super.init()
    }

    open override func startTunnel(options: [String: NSObject]? = nil) async throws {
        let profile = try Profile(
            withNEProvider: self,
            decoder: .shared
        )
        let defaults: UserDefaults
        if let suite = VPNKitTunnelConfig.appGroupIdentifier,
           let groupDefaults = UserDefaults(suiteName: suite) {
            defaults = groupDefaults
        } else {
            defaults = .standard
        }

        var loggerBuilder = PartoutLogger.Builder()
        loggerBuilder.logsModules = true
        if let logURL = VPNKitTunnelConfig.logURL {
            loggerBuilder.setLocalLogger(
                url: logURL,
                options: .init(
                    maxLevel: .info,
                    maxSize: 10000,
                    maxBufferedLines: 1000
                ),
                mapper: Self.formattedLine
            )
        }
        PartoutLogger.register(loggerBuilder.build())

        let newRuntime = try PartoutProviderRuntime(
            provider: self,
            profile: profile,
            options: .init(
                dnsFallbackServers: [],
                logsSnapshots: false
            ),
            defaults: defaults,
            logsPrivateData: false,
            cacheDir: FileManager.default.temporaryDirectory.path(),
            minDataCountDelta: 0,
            logger: tunnelLogger
        )
        runtime = newRuntime
        try await newRuntime.startTunnel()
    }

    open override func stopTunnel(with reason: NEProviderStopReason) async {
        await runtime?.stopTunnel()
        runtime = nil
    }

    public override func cancelTunnelWithError(_ error: Error?) {
        super.cancelTunnelWithError(error)
    }

    public override func handleAppMessage(_ messageData: Data) async -> Data? {
        await runtime?.handleAppMessage(messageData)
    }

    public override func wake() {
        runtime?.wake()
    }

    public override func sleep() async {
        await runtime?.sleep()
    }
}

private extension VPNPacketTunnelProvider {
    static func formattedLine(_ line: DebugLog.Line) -> String {
        let ts = line.timestamp.formatted(
            .dateTime
                .hour(.twoDigits(amPM: .omitted))
                .minute()
                .second()
        )
        return "\(ts) - \(line.message)"
    }
}

private nonisolated func tunnelLogger(
    _ level: Int32,
    _ message: UnsafePointer<CChar>?
) {
    guard let level = DebugLog.Level(rawValue: Int(level)),
          let message else { return }
    pp_log_g(.abi, level, String(cString: message))
}
