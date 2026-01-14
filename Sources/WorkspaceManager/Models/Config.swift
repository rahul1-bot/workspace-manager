import Foundation

// MARK: - Configuration Models

/// Root configuration structure matching config.toml format
struct AppConfig: Codable {
    var terminal: TerminalConfig
    var workspaces: [WorkspaceConfig]

    init(terminal: TerminalConfig = TerminalConfig(), workspaces: [WorkspaceConfig] = []) {
        self.terminal = terminal
        self.workspaces = workspaces
    }
}

/// Terminal appearance and behavior configuration
struct TerminalConfig: Codable {
    var font: String
    var font_size: Int
    var scrollback: Int
    var cursor_style: String

    init(font: String = "Cascadia Code", font_size: Int = 14, scrollback: Int = 1_000_000, cursor_style: String = "bar") {
        self.font = font
        self.font_size = font_size
        self.scrollback = scrollback
        self.cursor_style = cursor_style
    }
}

/// Workspace configuration from TOML
struct WorkspaceConfig: Codable {
    var name: String
    var path: String

    init(name: String, path: String) {
        self.name = name
        self.path = path
    }
}
