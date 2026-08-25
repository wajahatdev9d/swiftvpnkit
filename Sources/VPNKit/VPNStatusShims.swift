import Foundation

public enum VPNStatus: Sendable, Equatable {
    case disconnected
    case connecting
    case connected
    case disconnecting
}

public enum VPNNotification {
    public static let didChangeStatus = Notification.Name(
        "VPNKit.didChangeStatus"
    )
    public static let didFail = Notification.Name("VPNKit.didFail")
}

extension Notification {
    public var vpnStatus: VPNStatus {
        userInfo?[VPNNotification.statusKey] as? VPNStatus ?? .disconnected
    }

    public var vpnError: Error {
        userInfo?[VPNNotification.errorKey] as? NSError ?? NSError(
            domain: "VPNKit",
            code: 0
        )
    }
}

extension VPNNotification {
    public static let statusKey = "VPNKitStatus"
    public static let errorKey = "VPNKitError"

    @discardableResult
    public static func postStatus(_ status: VPNStatus) -> Notification {
        let notification = Notification(
            name: didChangeStatus,
            object: nil,
            userInfo: [statusKey: status]
        )
        postOnMain { NotificationCenter.default.post(notification) }
        return notification
    }

    @discardableResult
    public static func postError(_ error: Error) -> Notification {
        let notification = Notification(
            name: didFail,
            object: nil,
            userInfo: [errorKey: error as NSError]
        )
        postOnMain { NotificationCenter.default.post(notification) }
        return notification
    }

    private static func postOnMain(_ block: @escaping () -> Void) {
        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.async(execute: block)
        }
    }
}
