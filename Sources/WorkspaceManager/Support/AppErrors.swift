import Foundation

enum ConfigValidationError: Error, LocalizedError, Sendable {
    case emptyWorkspaceName
    case duplicateWorkspaceName(String)
    case invalidWorkspacePath(String)
    case invalidWorkspaceIdentifier(String)

    var errorDescription: String? {
        switch self {
        case .emptyWorkspaceName:
            return "Workspace name must be non-empty."
        case .duplicateWorkspaceName(let name):
            return "Workspace name '\(name)' must be unique."
        case .invalidWorkspacePath(let path):
            return "Workspace path '\(path)' is invalid."
        case .invalidWorkspaceIdentifier(let id):
            return "Workspace id '\(id)' is invalid."
        }
    }
}

enum ConfigLoadError: Error, LocalizedError, Sendable {
    case fileReadFailed(URL, String)
    case parseFailed(URL, String)
    case saveFailed(URL, String)

    var errorDescription: String? {
        switch self {
        case .fileReadFailed(let url, let detail):
            return "Failed to read config at \(url.path): \(detail)"
        case .parseFailed(let url, let detail):
            return "Failed to parse config at \(url.path): \(detail)"
        case .saveFailed(let url, let detail):
            return "Failed to save config at \(url.path): \(detail)"
        }
    }
}

enum TerminalLaunchError: Error, LocalizedError, Sendable {
    case invalidShellPath(String)
    case nonExecutableShell(String)
    case unsafeWorkingDirectory(String)

    var errorDescription: String? {
        switch self {
        case .invalidShellPath(let shell):
            return "Shell path '\(shell)' is not allowed."
        case .nonExecutableShell(let shell):
            return "Shell path '\(shell)' is not executable."
        case .unsafeWorkingDirectory(let cwd):
            return "Working directory '\(cwd)' is unsafe."
        }
    }
}

enum InputRoutingError: Error, LocalizedError, Sendable {
    case unsupportedShortcut(String)
    case inactiveApplication

    var errorDescription: String? {
        switch self {
        case .unsupportedShortcut(let shortcut):
            return "Shortcut '\(shortcut)' is unsupported in current context."
        case .inactiveApplication:
            return "Input routing rejected because app is not active."
        }
    }
}
