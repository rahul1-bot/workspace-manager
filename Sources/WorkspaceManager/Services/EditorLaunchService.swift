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

protocol EditorLaunching: Sendable {
    func availableEditors() async -> [ExternalEditor]
    func preferredEditor(for workspaceID: UUID) async -> ExternalEditor?
    func setPreferredEditor(_ editor: ExternalEditor, for workspaceID: UUID) async
    func openWorkspace(at workspaceURL: URL, using editor: ExternalEditor) async
}

actor EditorLaunchService: EditorLaunching {
    private let userDefaultsKey = "workspace_manager.preferred_editor_by_workspace"
    private let editorBundleIdentifierMap: [ExternalEditor: String] = [
        .zed: "dev.zed.Zed",
        .vsCode: "com.microsoft.VSCode"
    ]

    func availableEditors() async -> [ExternalEditor] {
        return await MainActor.run {
            var editors: [ExternalEditor] = []
            for editor in [ExternalEditor.zed, ExternalEditor.vsCode] {
                guard let bundleIdentifier = editorBundleIdentifierMap[editor] else { continue }
                if NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) != nil {
                    editors.append(editor)
                }
            }
            editors.append(.finder)
            return editors
        }
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
        await MainActor.run {
            switch editor {
            case .finder:
                NSWorkspace.shared.open(workspaceURL)
            case .zed, .vsCode:
                guard let bundleIdentifier = editorBundleIdentifierMap[editor],
                      let applicationURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
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
}
