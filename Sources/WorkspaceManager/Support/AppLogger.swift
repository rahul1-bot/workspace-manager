import Foundation
import OSLog

enum AppLogger {
    static let app = Logger(subsystem: "WorkspaceManager", category: "app")
    static let input = Logger(subsystem: "WorkspaceManager", category: "input")
    static let ghostty = Logger(subsystem: "WorkspaceManager", category: "ghostty")
    static let config = Logger(subsystem: "WorkspaceManager", category: "config")
    static let terminal = Logger(subsystem: "WorkspaceManager", category: "terminal")
    static let graph = Logger(subsystem: "WorkspaceManager", category: "graph")
    static let worktree = Logger(subsystem: "WorkspaceManager", category: "worktree")
}
