import Foundation
import SwiftUI

// ConfigService is in the same module, no import needed

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

    // MARK: - Terminal Navigation

    /// Get flat list of all terminals with their workspace IDs
    var allTerminals: [(workspaceId: UUID, terminal: Terminal)] {
        var result: [(UUID, Terminal)] = []
        for workspace in workspaces {
            for terminal in workspace.terminals {
                result.append((workspace.id, terminal))
            }
        }
        return result
    }

    /// Navigate to previous terminal (cycles)
    func selectPreviousTerminal() {
        let terminals = allTerminals
        guard !terminals.isEmpty else { return }

        // Find current index
        if let currentId = selectedTerminalId,
           let currentIndex = terminals.firstIndex(where: { $0.terminal.id == currentId }) {
            // Go to previous, wrap around to end if at beginning
            let previousIndex = currentIndex == 0 ? terminals.count - 1 : currentIndex - 1
            let prev = terminals[previousIndex]
            selectTerminal(id: prev.terminal.id, in: prev.workspaceId)
        } else {
            // No selection, select last terminal
            if let last = terminals.last {
                selectTerminal(id: last.terminal.id, in: last.workspaceId)
            }
        }
    }

    /// Navigate to next terminal (cycles)
    func selectNextTerminal() {
        let terminals = allTerminals
        guard !terminals.isEmpty else { return }

        // Find current index
        if let currentId = selectedTerminalId,
           let currentIndex = terminals.firstIndex(where: { $0.terminal.id == currentId }) {
            // Go to next, wrap around to beginning if at end
            let nextIndex = (currentIndex + 1) % terminals.count
            let next = terminals[nextIndex]
            selectTerminal(id: next.terminal.id, in: next.workspaceId)
        } else {
            // No selection, select first terminal
            if let first = terminals.first {
                selectTerminal(id: first.terminal.id, in: first.workspaceId)
            }
        }
    }
}
