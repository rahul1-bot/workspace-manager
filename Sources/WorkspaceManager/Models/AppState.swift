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
        let previousSelectedTerminal = selectedTerminalId

        // Merge-style reload: preserve existing terminals while updating workspace metadata
        mergeWorkspacesFromConfig()

        // Sync appearance settings from config
        showSidebar = configService.config.appearance.show_sidebar

        // Restore selection if still valid
        if let prevWsId = previousSelectedWorkspace,
           workspaces.contains(where: { $0.id == prevWsId }) {
            selectedWorkspaceId = prevWsId
            // Also restore terminal selection if still valid
            if let prevTermId = previousSelectedTerminal,
               let ws = workspaces.first(where: { $0.id == prevWsId }),
               ws.terminals.contains(where: { $0.id == prevTermId }) {
                selectedTerminalId = prevTermId
            }
        }
    }

    /// Merge config changes while preserving running terminals
    private func mergeWorkspacesFromConfig() {
        let workspaceConfigs = configService.config.workspaces
        let configIds = Set(workspaceConfigs.compactMap { UUID(uuidString: $0.id) })

        // Remove workspaces that no longer exist in config
        workspaces.removeAll { !configIds.contains($0.id) }

        // Update existing workspaces and add new ones
        for wsConfig in workspaceConfigs {
            guard let stableId = UUID(uuidString: wsConfig.id) else { continue }
            let expandedPath = configService.expandPath(wsConfig.path)

            if let existingIndex = workspaces.firstIndex(where: { $0.id == stableId }) {
                // Update existing workspace metadata (preserve terminals!)
                workspaces[existingIndex].name = wsConfig.name
                workspaces[existingIndex].path = expandedPath
            } else {
                // Add new workspace from config
                let workspace = Workspace(id: stableId, name: wsConfig.name, path: expandedPath)
                workspaces.append(workspace)
            }
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

    // MARK: - Terminal Navigation (Within Selected Workspace)

    /// Get terminals in the currently selected workspace only
    var currentWorkspaceTerminals: [Terminal] {
        guard let wsId = selectedWorkspaceId,
              let workspace = workspaces.first(where: { $0.id == wsId }) else {
            return []
        }
        return workspace.terminals
    }

    func selectPreviousTerminal() {
        guard let wsId = selectedWorkspaceId else { return }
        let terminals = currentWorkspaceTerminals
        guard !terminals.isEmpty else { return }

        if let currentId = selectedTerminalId,
           let currentIndex = terminals.firstIndex(where: { $0.id == currentId }) {
            let previousIndex = currentIndex == 0 ? terminals.count - 1 : currentIndex - 1
            selectTerminal(id: terminals[previousIndex].id, in: wsId)
        } else {
            // No terminal selected, select last in workspace
            selectTerminal(id: terminals[terminals.count - 1].id, in: wsId)
        }
    }

    func selectNextTerminal() {
        guard let wsId = selectedWorkspaceId else { return }
        let terminals = currentWorkspaceTerminals
        guard !terminals.isEmpty else { return }

        if let currentId = selectedTerminalId,
           let currentIndex = terminals.firstIndex(where: { $0.id == currentId }) {
            let nextIndex = (currentIndex + 1) % terminals.count
            selectTerminal(id: terminals[nextIndex].id, in: wsId)
        } else {
            // No terminal selected, select first in workspace
            selectTerminal(id: terminals[0].id, in: wsId)
        }
    }

    // MARK: - Workspace Navigation

    func selectPreviousWorkspace() {
        guard !workspaces.isEmpty else { return }

        if let currentId = selectedWorkspaceId,
           let currentIndex = workspaces.firstIndex(where: { $0.id == currentId }) {
            let previousIndex = currentIndex == 0 ? workspaces.count - 1 : currentIndex - 1
            let prevWorkspace = workspaces[previousIndex]
            selectedWorkspaceId = prevWorkspace.id
            // Auto-select first terminal in new workspace if any exist
            if let firstTerminal = prevWorkspace.terminals.first {
                selectTerminal(id: firstTerminal.id, in: prevWorkspace.id)
            } else {
                selectedTerminalId = nil
            }
        } else {
            // No workspace selected, select last
            if let last = workspaces.last {
                selectedWorkspaceId = last.id
                if let firstTerminal = last.terminals.first {
                    selectTerminal(id: firstTerminal.id, in: last.id)
                }
            }
        }
    }

    func selectNextWorkspace() {
        guard !workspaces.isEmpty else { return }

        if let currentId = selectedWorkspaceId,
           let currentIndex = workspaces.firstIndex(where: { $0.id == currentId }) {
            let nextIndex = (currentIndex + 1) % workspaces.count
            let nextWorkspace = workspaces[nextIndex]
            selectedWorkspaceId = nextWorkspace.id
            // Auto-select first terminal in new workspace if any exist
            if let firstTerminal = nextWorkspace.terminals.first {
                selectTerminal(id: firstTerminal.id, in: nextWorkspace.id)
            } else {
                selectedTerminalId = nil
            }
        } else {
            // No workspace selected, select first
            if let first = workspaces.first {
                selectedWorkspaceId = first.id
                if let firstTerminal = first.terminals.first {
                    selectTerminal(id: firstTerminal.id, in: first.id)
                }
            }
        }
    }
}
