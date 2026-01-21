import Foundation
import SwiftUI

class AppState: ObservableObject {
    @Published var workspaces: [Workspace] = []
    @Published var selectedWorkspaceId: UUID?
    @Published var selectedTerminalId: UUID?
    @Published var showSidebar: Bool
    @Published var showNewWorkspaceSheet: Bool = false
    @Published var showNewTerminalSheet: Bool = false

    private let configService: ConfigService

    init(configService: ConfigService = ConfigService.shared) {
        self.configService = configService
        self.showSidebar = configService.config.appearance.show_sidebar
        loadWorkspacesFromConfig()
    }

    // MARK: - Config-Driven Loading

    func loadWorkspacesFromConfig() {
        workspaces = []
        let workspaceConfigs = configService.config.workspaces

        for wsConfig in workspaceConfigs {
            let expandedPath = configService.expandPath(wsConfig.path)
            // Use stable ID from config, converting from string to UUID
            let stableId = UUID(uuidString: wsConfig.id) ?? UUID()
            let workspace = Workspace(id: stableId, name: wsConfig.name, path: expandedPath)
            workspaces.append(workspace)
        }
    }

    func reloadFromConfig() {
        configService.reloadConfig()
        let previousSelectedWorkspace = selectedWorkspaceId

        loadWorkspacesFromConfig()

        // Sync appearance settings from config
        showSidebar = configService.config.appearance.show_sidebar

        selectedWorkspaceId = nil
        selectedTerminalId = nil

        if let prevWsId = previousSelectedWorkspace,
           workspaces.contains(where: { $0.id == prevWsId }) {
            selectedWorkspaceId = prevWsId
        }
    }

    // MARK: - Workspace Operations

    @discardableResult
    func addWorkspace(name: String, path: String) -> Bool {
        // Enforce unique workspace names
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else {
            print("[AppState] Error: Workspace name cannot be empty")
            return false
        }
        guard !workspaces.contains(where: { $0.name == trimmedName }) else {
            print("[AppState] Error: Workspace with name '\(trimmedName)' already exists")
            return false
        }

        let expandedPath = configService.expandPath(path)
        if !FileManager.default.fileExists(atPath: expandedPath) {
            print("[AppState] Warning: Workspace path does not exist: \(expandedPath)")
        }

        // Generate stable ID that will be saved to config
        let stableId = UUID()
        let workspace = Workspace(id: stableId, name: trimmedName, path: expandedPath)
        workspaces.append(workspace)

        configService.addWorkspace(id: stableId.uuidString, name: trimmedName, path: path)
        return true
    }

    func removeWorkspace(id: UUID) {
        workspaces.removeAll { $0.id == id }
        if selectedWorkspaceId == id {
            selectedWorkspaceId = nil
            selectedTerminalId = nil
        }

        configService.removeWorkspace(id: id.uuidString)
    }

    func toggleWorkspaceExpanded(id: UUID) {
        if let index = workspaces.firstIndex(where: { $0.id == id }) {
            workspaces[index].isExpanded.toggle()
        }
    }

    // MARK: - Sidebar Operations (Persisted to Config)

    func toggleSidebar() {
        showSidebar.toggle()
        configService.setShowSidebar(showSidebar)
    }

    func setSidebar(visible: Bool) {
        showSidebar = visible
        configService.setShowSidebar(showSidebar)
    }

    // MARK: - Terminal Operations (Runtime Only)

    func createTerminalInSelectedWorkspace() {
        guard let workspaceId = selectedWorkspaceId,
              let index = workspaces.firstIndex(where: { $0.id == workspaceId }) else {
            return
        }

        let terminalCount = workspaces[index].terminals.count + 1
        let terminal = workspaces[index].addTerminal(name: "Terminal \(terminalCount)")
        selectTerminal(id: terminal.id, in: workspaceId)
    }

    func addTerminal(to workspaceId: UUID, name: String) {
        guard let index = workspaces.firstIndex(where: { $0.id == workspaceId }) else { return }

        let terminal = workspaces[index].addTerminal(name: name)
        selectTerminal(id: terminal.id, in: workspaceId)
    }

    func removeTerminal(id: UUID, from workspaceId: UUID) {
        guard let index = workspaces.firstIndex(where: { $0.id == workspaceId }) else { return }

        workspaces[index].removeTerminal(id: id)
        if selectedTerminalId == id {
            selectedTerminalId = nil
        }
    }

    func selectTerminal(id: UUID, in workspaceId: UUID) {
        for i in workspaces.indices {
            for j in workspaces[i].terminals.indices {
                workspaces[i].terminals[j].isActive = false
            }
        }

        if let wsIndex = workspaces.firstIndex(where: { $0.id == workspaceId }),
           let tIndex = workspaces[wsIndex].terminals.firstIndex(where: { $0.id == id }) {
            workspaces[wsIndex].terminals[tIndex].isActive = true
        }

        selectedWorkspaceId = workspaceId
        selectedTerminalId = id
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

    // MARK: - Terminal Navigation

    var allTerminals: [(workspaceId: UUID, terminal: Terminal)] {
        var result: [(UUID, Terminal)] = []
        for workspace in workspaces {
            for terminal in workspace.terminals {
                result.append((workspace.id, terminal))
            }
        }
        return result
    }

    func selectPreviousTerminal() {
        let terminals = allTerminals
        guard !terminals.isEmpty else { return }

        if let currentId = selectedTerminalId,
           let currentIndex = terminals.firstIndex(where: { $0.terminal.id == currentId }) {
            let previousIndex = currentIndex == 0 ? terminals.count - 1 : currentIndex - 1
            let prev = terminals[previousIndex]
            selectTerminal(id: prev.terminal.id, in: prev.workspaceId)
        } else {
            if let last = terminals.last {
                selectTerminal(id: last.terminal.id, in: last.workspaceId)
            }
        }
    }

    func selectNextTerminal() {
        let terminals = allTerminals
        guard !terminals.isEmpty else { return }

        if let currentId = selectedTerminalId,
           let currentIndex = terminals.firstIndex(where: { $0.terminal.id == currentId }) {
            let nextIndex = (currentIndex + 1) % terminals.count
            let next = terminals[nextIndex]
            selectTerminal(id: next.terminal.id, in: next.workspaceId)
        } else {
            if let first = terminals.first {
                selectTerminal(id: first.terminal.id, in: first.workspaceId)
            }
        }
    }
}
