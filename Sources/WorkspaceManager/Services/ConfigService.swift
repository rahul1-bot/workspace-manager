import Foundation
import TOMLKit

/// Service for loading and managing application configuration from TOML
class ConfigService {
    static let shared = ConfigService()

    private(set) var config: AppConfig

    /// Path to the configuration file
    private let configPath: URL

    /// Default workspace uses user's home directory for portability
    private static var defaultWorkspaceRoot: String {
        FileManager.default.homeDirectoryForCurrentUser.path
    }

    private init() {
        // Expand ~ to home directory
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let configDir = homeDir.appendingPathComponent(".config/workspace-manager")
        self.configPath = configDir.appendingPathComponent("config.toml")

        // Load or create default config
        self.config = AppConfig()
        loadConfig()
    }

    /// Expand tilde in paths to full home directory path
    /// Only expands "~" or "~/" - rejects invalid patterns like "~foo"
    func expandPath(_ path: String) -> String {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path

        if path == "~" {
            return homeDir
        }
        if path.hasPrefix("~/") {
            return homeDir + path.dropFirst(1)
        }
        // Reject ~foo patterns - return as-is and let it fail at path validation
        return path
    }

    /// Load configuration from TOML file
    func loadConfig() {
        // Check if config file exists
        guard FileManager.default.fileExists(atPath: configPath.path) else {
            // Create default config only when no config exists
            createDefaultConfig()
            return
        }

        do {
            let tomlString = try String(contentsOf: configPath, encoding: .utf8)
            let tomlTable = try TOMLTable(string: tomlString)

            // Parse terminal config
            var terminalConfig = TerminalConfig()
            if let terminalTable = tomlTable["terminal"] as? TOMLTable {
                if let font = terminalTable["font"] as? String {
                    terminalConfig.font = font
                }
                if let fontSize = terminalTable["font_size"] as? Int {
                    terminalConfig.font_size = fontSize
                }
                if let scrollback = terminalTable["scrollback"] as? Int {
                    terminalConfig.scrollback = scrollback
                }
                if let cursorStyle = terminalTable["cursor_style"] as? String {
                    terminalConfig.cursor_style = cursorStyle
                }
                if let useGpuRenderer = terminalTable["use_gpu_renderer"] as? Bool {
                    terminalConfig.use_gpu_renderer = useGpuRenderer
                }
            }

            // Parse appearance config
            var appearanceConfig = AppearanceConfig()
            if let appearanceTable = tomlTable["appearance"] as? TOMLTable {
                if let showSidebar = appearanceTable["show_sidebar"] as? Bool {
                    appearanceConfig.show_sidebar = showSidebar
                }
            }

            // Parse workspaces array with ID validation and duplicate detection
            var workspaces: [WorkspaceConfig] = []
            var seenIds: Set<String> = []
            var needsSave = false

            if let workspacesArray = tomlTable["workspaces"] as? TOMLArray {
                for item in workspacesArray {
                    if let wsTable = item as? TOMLTable,
                       let name = wsTable["name"] as? String,
                       let path = wsTable["path"] as? String {
                        let expandedPath = expandPath(path)

                        // Validate and normalize the workspace ID
                        var id: String
                        if let existingId = wsTable["id"] as? String,
                           !existingId.isEmpty,
                           UUID(uuidString: existingId) != nil {
                            // Valid UUID string
                            id = existingId
                        } else {
                            // Invalid or missing ID - generate a new valid UUID
                            id = UUID().uuidString
                            needsSave = true
                            if let existingId = wsTable["id"] as? String, !existingId.isEmpty {
                                print("[ConfigService] Warning: Invalid workspace ID '\(existingId)' for '\(name)', regenerating")
                            }
                        }

                        // Check for duplicate IDs and regenerate if needed
                        if seenIds.contains(id) {
                            print("[ConfigService] Warning: Duplicate workspace ID '\(id)' for '\(name)', regenerating")
                            id = UUID().uuidString
                            needsSave = true
                        }
                        seenIds.insert(id)

                        workspaces.append(WorkspaceConfig(id: id, name: name, path: expandedPath))
                    }
                }
            }

            self.config = AppConfig(terminal: terminalConfig, appearance: appearanceConfig, workspaces: workspaces)

            // Save config if we fixed any IDs
            if needsSave {
                saveConfig()
            }

        } catch {
            // IMPORTANT: Do NOT overwrite user config on parse failure
            // Keep existing config in memory and log the error clearly
            print("[ConfigService] ERROR: Failed to parse config.toml: \(error)")
            print("[ConfigService] Using default configuration in memory. User config at \(configPath.path) is preserved.")
            print("[ConfigService] Please fix the TOML syntax and restart the app.")
            // Keep default config in memory but don't overwrite the user's file
            self.config = AppConfig()
        }
    }

    /// Create default configuration file
    private func createDefaultConfig() {
        // Build default workspaces using portable paths
        var workspaces: [WorkspaceConfig] = []

        // Add home directory as default workspace
        workspaces.append(WorkspaceConfig(name: "Home", path: Self.defaultWorkspaceRoot))

        // Add common directories if they exist
        let commonDirs = ["Projects", "Developer", "Code", "Documents"]
        for dirName in commonDirs {
            let dirPath = "\(Self.defaultWorkspaceRoot)/\(dirName)"
            if FileManager.default.fileExists(atPath: dirPath) {
                workspaces.append(WorkspaceConfig(name: dirName, path: dirPath))
            }
        }

        // Create default config object
        self.config = AppConfig(
            terminal: TerminalConfig(),
            workspaces: workspaces
        )

        // Write TOML file
        saveConfig()
    }

    func saveConfig() {
        let configDir = configPath.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)

        var toml = """
        # Workspace Manager Configuration

        [terminal]
        font = \(escapeTomlString(config.terminal.font))
        font_size = \(config.terminal.font_size)
        scrollback = \(config.terminal.scrollback)
        cursor_style = \(escapeTomlString(config.terminal.cursor_style))
        use_gpu_renderer = \(config.terminal.use_gpu_renderer)

        [appearance]
        show_sidebar = \(config.appearance.show_sidebar)

        # Workspaces - each needs id, name and path
        # Use ~ for home directory

        """

        for workspace in config.workspaces {
            let displayPath = workspace.path.replacingOccurrences(
                of: FileManager.default.homeDirectoryForCurrentUser.path,
                with: "~"
            )
            toml += """

            [[workspaces]]
            id = \(escapeTomlString(workspace.id))
            name = \(escapeTomlString(workspace.name))
            path = \(escapeTomlString(displayPath))
            """
        }

        toml += "\n"

        do {
            try toml.write(to: configPath, atomically: true, encoding: .utf8)
        } catch {
            print("[ConfigService] Failed to save config.toml: \(error)")
        }
    }

    private func escapeTomlString(_ value: String) -> String {
        var escaped = value
        escaped = escaped.replacingOccurrences(of: "\\", with: "\\\\")
        escaped = escaped.replacingOccurrences(of: "\"", with: "\\\"")
        escaped = escaped.replacingOccurrences(of: "\n", with: "\\n")
        escaped = escaped.replacingOccurrences(of: "\r", with: "\\r")
        escaped = escaped.replacingOccurrences(of: "\t", with: "\\t")
        return "\"\(escaped)\""
    }

    /// Reload configuration from disk
    func reloadConfig() {
        loadConfig()
    }

    // MARK: - Workspace Mutations

    func addWorkspace(id: String, name: String, path: String) {
        // Enforce unique names
        guard !config.workspaces.contains(where: { $0.name == name }) else {
            print("[ConfigService] Error: Workspace with name '\(name)' already exists")
            return
        }
        // Enforce unique IDs
        guard !config.workspaces.contains(where: { $0.id == id }) else {
            print("[ConfigService] Error: Workspace with ID '\(id)' already exists")
            return
        }
        let newWorkspace = WorkspaceConfig(id: id, name: name, path: path)
        config.workspaces.append(newWorkspace)
        saveConfig()
    }

    func removeWorkspace(id: String) {
        config.workspaces.removeAll { $0.id == id }
        saveConfig()
    }

    func updateWorkspace(id: String, newName: String, newPath: String) {
        if let index = config.workspaces.firstIndex(where: { $0.id == id }) {
            config.workspaces[index] = WorkspaceConfig(id: id, name: newName, path: newPath)
            saveConfig()
        }
    }

    // MARK: - Appearance Mutations

    func setShowSidebar(_ show: Bool) {
        config.appearance.show_sidebar = show
        saveConfig()
    }
}
