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
    private var preferredEditors: [UUID: ExternalEditor] = [:]

    func availableEditors() async -> [ExternalEditor] {
        return [.zed, .vsCode, .finder]
    }

    func preferredEditor(for workspaceID: UUID) async -> ExternalEditor? {
        return preferredEditors[workspaceID]
    }

    func setPreferredEditor(_ editor: ExternalEditor, for workspaceID: UUID) async {
        preferredEditors[workspaceID] = editor
    }

    func openWorkspace(at workspaceURL: URL, using editor: ExternalEditor) async {
        _ = editor
        NSWorkspace.shared.open(workspaceURL)
    }
}
