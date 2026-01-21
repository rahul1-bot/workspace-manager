import Foundation

// MARK: - Configuration Models

struct AppConfig: Codable {
    var terminal: TerminalConfig
    var appearance: AppearanceConfig
    var workspaces: [WorkspaceConfig]

    init(
        terminal: TerminalConfig = TerminalConfig(),
        appearance: AppearanceConfig = AppearanceConfig(),
        workspaces: [WorkspaceConfig] = []
    ) {
        self.terminal = terminal
        self.appearance = appearance
        self.workspaces = workspaces
    }
}

struct TerminalConfig: Codable {
    var font: String
    var font_size: Int
    var scrollback: Int
    var cursor_style: String
    var use_gpu_renderer: Bool

    init(
        font: String = "Cascadia Code",
        font_size: Int = 14,
        scrollback: Int = 1_000_000,
        cursor_style: String = "bar",
        use_gpu_renderer: Bool = true
    ) {
        self.font = font
        self.font_size = font_size
        self.scrollback = scrollback
        self.cursor_style = cursor_style
        self.use_gpu_renderer = use_gpu_renderer
    }
}

struct AppearanceConfig: Codable {
    var show_sidebar: Bool

    init(show_sidebar: Bool = true) {
        self.show_sidebar = show_sidebar
    }
}

/// Workspace configuration from TOML
struct WorkspaceConfig: Codable {
    var id: String
    var name: String
    var path: String

    init(id: String = UUID().uuidString, name: String, path: String) {
        self.id = id
        self.name = name
        self.path = path
    }
}
