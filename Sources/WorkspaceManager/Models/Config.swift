import Foundation

// MARK: - Configuration Models

struct AppConfig: Codable, Sendable {
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

struct TerminalConfig: Codable, Sendable {
    var font: String
    var font_size: Int
    var scrollback: Int
    var cursor_style: String
    var use_gpu_renderer: Bool

    private static let maximumScrollback = 100_000

    init(
        font: String = "Cascadia Code",
        font_size: Int = 14,
        scrollback: Int = 50_000,
        cursor_style: String = "bar",
        use_gpu_renderer: Bool = true
    ) {
        self.font = font
        self.font_size = font_size
        self.scrollback = min(max(scrollback, 0), Self.maximumScrollback)
        self.cursor_style = cursor_style
        self.use_gpu_renderer = use_gpu_renderer
    }
}

struct AppearanceConfig: Codable, Sendable {
    var show_sidebar: Bool
    var focus_mode: Bool

    init(show_sidebar: Bool = true, focus_mode: Bool = false) {
        self.show_sidebar = show_sidebar
        self.focus_mode = focus_mode
    }
}

/// Workspace configuration from TOML
struct WorkspaceConfig: Codable, Sendable {
    var id: String
    var name: String
    var path: String

    init(id: String = UUID().uuidString, name: String, path: String) {
        self.id = id
        self.name = name
        self.path = path
    }
}
