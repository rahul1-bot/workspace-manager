import Foundation

extension Notification.Name {
    static let wmTerminalRuntimePathDidChange = Notification.Name("wmTerminalRuntimePathDidChange")
}

enum TerminalRuntimeNotificationKey {
    static let terminalID = "terminalID"
    static let path = "path"
}
