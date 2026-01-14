import Foundation
import SwiftUI

class AppState: ObservableObject {
    @Published var workspaces: [Workspace] = []
    @Published var selectedWorkspaceId: UUID?
    @Published var selectedTerminalId: UUID?
    @Published var showSidebar: Bool = true
    @Published var showNewWorkspaceSheet: Bool = false
    @Published var showNewTerminalSheet: Bool = false

    private let saveURL: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("WorkspaceManager", isDirectory: true)

        // Create directory if needed
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)

        self.saveURL = appDir.appendingPathComponent("workspaces.json")
        load()

        // Initialize workspaces from config if empty
        if workspaces.isEmpty {
            initializeWorkspacesFromConfig()
        }
    }

    // MARK: - Persistence

    func load() {
        guard FileManager.default.fileExists(atPath: saveURL.path) else { return }

        do {
            let data = try Data(contentsOf: saveURL)
            workspaces = try JSONDecoder().decode([Workspace].self, from: data)
        } catch {
            print("Failed to load workspaces: \(error)")
        }
    }

    func save() {
        do {
            let data = try JSONEncoder().encode(workspaces)
            try data.write(to: saveURL)
        } catch {
            print("Failed to save workspaces: \(error)")
        }
    }

    // MARK: - Initialization

    func initializeWorkspacesFromConfig() {
        let configService = ConfigService.shared
        let workspaceConfigs = configService.config.workspaces

        for wsConfig in workspaceConfigs {
            let expandedPath = configService.expandPath(wsConfig.path)
            if FileManager.default.fileExists(atPath: expandedPath) {
                let workspace = Workspace(name: wsConfig.name, path: expandedPath)
                workspaces.append(workspace)
            }
        }

        save()
    }

    // MARK: - Workspace Operations

    func addWorkspace(name: String, path: String) {
        let workspace = Workspace(name: name, path: path)
        workspaces.append(workspace)
        save()
    }

    func removeWorkspace(id: UUID) {
        workspaces.removeAll { $0.id == id }
        if selectedWorkspaceId == id {
            selectedWorkspaceId = nil
            selectedTerminalId = nil
        }
        save()
    }

    func toggleWorkspaceExpanded(id: UUID) {
        if let index = workspaces.firstIndex(where: { $0.id == id }) {
            workspaces[index].isExpanded.toggle()
            save()
        }
    }

    // MARK: - Terminal Operations

    func createTerminalInSelectedWorkspace() {
        guard let workspaceId = selectedWorkspaceId,
              let index = workspaces.firstIndex(where: { $0.id == workspaceId }) else {
            return
        }

        let terminalCount = workspaces[index].terminals.count + 1
        let terminal = workspaces[index].addTerminal(name: "Terminal \(terminalCount)")
        selectedTerminalId = terminal.id
        save()
    }

    func addTerminal(to workspaceId: UUID, name: String) {
        guard let index = workspaces.firstIndex(where: { $0.id == workspaceId }) else { return }

        let terminal = workspaces[index].addTerminal(name: name)
        selectedTerminalId = terminal.id
        save()
    }

    func removeTerminal(id: UUID, from workspaceId: UUID) {
        guard let index = workspaces.firstIndex(where: { $0.id == workspaceId }) else { return }

        workspaces[index].removeTerminal(id: id)
        if selectedTerminalId == id {
            selectedTerminalId = nil
        }
        save()
    }

    func selectTerminal(id: UUID, in workspaceId: UUID) {
        // Deactivate all terminals
        for i in workspaces.indices {
            for j in workspaces[i].terminals.indices {
                workspaces[i].terminals[j].isActive = false
            }
        }

        // Activate selected terminal
        if let wsIndex = workspaces.firstIndex(where: { $0.id == workspaceId }),
           let tIndex = workspaces[wsIndex].terminals.firstIndex(where: { $0.id == id }) {
            workspaces[wsIndex].terminals[tIndex].isActive = true
        }

        selectedWorkspaceId = workspaceId
        selectedTerminalId = id
        save()
    }

    // MARK: - Getters

    var selectedWorkspace: Workspace? {
        guard let id = selectedWorkspaceId else { return nil }
        return workspaces.first { $0.id == id }
    }

    var selectedTerminal: Terminal? {
        guard let wsId = selectedWorkspaceId,
              let tId = selectedTerminalId,
              let workspace = workspaces.first(where: { $0.id == wsId }) else {
            return nil
        }
        return workspace.terminals.first { $0.id == tId }
    }
}
