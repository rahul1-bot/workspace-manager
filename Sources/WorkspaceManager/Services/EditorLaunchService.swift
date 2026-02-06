import Foundation
import AppKit

enum ExternalEditor: String, CaseIterable, Codable, Sendable {
    case zed
    case vsCode
    case finder

    var title: String {
        switch self {
        case .zed:
            return "Zed"
        case .vsCode:
            return "VS Code"
        case .finder:
            return "Finder"
        }
    }
}

enum EditorLaunchMode: Equatable, Sendable {
    case cli
    case app
    case finder
    case unavailable
}

protocol EditorLaunching: Sendable {
    func availableEditors() async -> [ExternalEditor]
    func preferredEditor(for workspaceID: UUID) async -> ExternalEditor?
    func setPreferredEditor(_ editor: ExternalEditor, for workspaceID: UUID) async
    func openWorkspace(at workspaceURL: URL, using editor: ExternalEditor) async
}

actor EditorLaunchService: EditorLaunching {
    nonisolated static let zedBundleIdentifiers = ["dev.zed.Zed", "dev.zed.Zed-Preview"]
    nonisolated static let zedCLIPath = "/usr/local/bin/zed"

    nonisolated static func preferredLaunchMode(
        for editor: ExternalEditor,
        appAvailable: Bool,
        zedCLIAvailable: Bool
    ) -> EditorLaunchMode {
        switch editor {
        case .finder:
            return .finder
        case .zed:
            if zedCLIAvailable {
                return .cli
            }
            return appAvailable ? .app : .unavailable
        case .vsCode:
            return appAvailable ? .app : .unavailable
        }
    }

    private let userDefaultsKey = "workspace_manager.preferred_editor_by_workspace"

    func availableEditors() async -> [ExternalEditor] {
        var editors: [ExternalEditor] = []

        for editor in [ExternalEditor.zed, ExternalEditor.vsCode] {
            let appAvailable = await resolvedApplicationURL(bundleIdentifiers: bundleIdentifiers(for: editor)) != nil
            let launchMode = Self.preferredLaunchMode(
                for: editor,
                appAvailable: appAvailable,
                zedCLIAvailable: Self.isZedCLIAvailable()
            )
            if launchMode != .unavailable {
                editors.append(editor)
            }
        }

        editors.append(.finder)
        return editors
    }

    func preferredEditor(for workspaceID: UUID) async -> ExternalEditor? {
        let map = preferenceMap()
        guard let rawValue = map[workspaceID.uuidString] else { return nil }
        return ExternalEditor(rawValue: rawValue)
    }

    func setPreferredEditor(_ editor: ExternalEditor, for workspaceID: UUID) async {
        var map = preferenceMap()
        map[workspaceID.uuidString] = editor.rawValue
        UserDefaults.standard.set(map, forKey: userDefaultsKey)
    }

    func openWorkspace(at workspaceURL: URL, using editor: ExternalEditor) async {
        switch editor {
        case .finder:
            _ = await MainActor.run {
                NSWorkspace.shared.open(workspaceURL)
            }
        case .zed:
            if Self.isZedCLIAvailable(), Self.launchZedCLI(at: workspaceURL) {
                return
            }
            fallthrough
        case .vsCode:
            let applicationURL = await resolvedApplicationURL(bundleIdentifiers: bundleIdentifiers(for: editor))
            await MainActor.run {
                guard let applicationURL else {
                    NSWorkspace.shared.open(workspaceURL)
                    return
                }
                let configuration = NSWorkspace.OpenConfiguration()
                NSWorkspace.shared.open(
                    [workspaceURL],
                    withApplicationAt: applicationURL,
                    configuration: configuration
                )
            }
        }
    }

    private func preferenceMap() -> [String: String] {
        return UserDefaults.standard.dictionary(forKey: userDefaultsKey) as? [String: String] ?? [:]
    }

    private func bundleIdentifiers(for editor: ExternalEditor) -> [String] {
        switch editor {
        case .zed:
            return Self.zedBundleIdentifiers
        case .vsCode:
            return ["com.microsoft.VSCode"]
        case .finder:
            return []
        }
    }

    private func resolvedApplicationURL(bundleIdentifiers: [String]) async -> URL? {
        guard !bundleIdentifiers.isEmpty else { return nil }
        return await MainActor.run {
            for bundleIdentifier in bundleIdentifiers {
                if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
                    return appURL
                }
            }
            return nil
        }
    }

    nonisolated private static func isZedCLIAvailable() -> Bool {
        FileManager.default.isExecutableFile(atPath: zedCLIPath)
    }

    @discardableResult
    nonisolated private static func launchZedCLI(at workspaceURL: URL) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: zedCLIPath)
        process.arguments = [workspaceURL.path]
        do {
            try process.run()
            return true
        } catch {
            return false
        }
    }
}
