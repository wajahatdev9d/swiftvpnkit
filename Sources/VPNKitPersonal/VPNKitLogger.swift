import Foundation

public enum VPNKitLogLevel: Sendable {
    case info
    case error
}

public enum VPNKitLogger {
    /// Optional hook for host app logging (e.g. os_log, Firebase, custom file).
    public static var handler: (@Sendable (VPNKitLogLevel, String) -> Void)?

    static func info(_ message: String) {
        handler?(.info, message)
    }

    static func error(_ message: String) {
        handler?(.error, message)
    }
}
