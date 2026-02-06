import Foundation
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published var workspaces: [Workspace] = []
    @Published var selectedWorkspaceId: UUID? {
        didSet {
            refreshGitUIStatePlaceholder()
        }
    }
    @Published var selectedTerminalId: UUID?
    @Published var showSidebar: Bool
    @Published var focusMode: Bool
    @Published var showNewWorkspaceSheet: Bool = false
    @Published var showNewTerminalSheet: Bool = false
    @Published var renamingWorkspaceId: UUID?
    @Published var renamingTerminalId: UUID?
    @Published var gitPanelState: GitPanelState = GitPanelState()
    @Published var commitSheetState: CommitSheetState = CommitSheetState()
    @Published var availableEditors: [ExternalEditor] = []

    private let configService: ConfigService
    private let gitRepositoryService: any GitRepositoryServicing
    private let editorLaunchService: any EditorLaunching
    private let prLinkBuilder: any PRLinkBuilding
    private let defaultTerminalNames = ["Ghost", "Lyra"]

    init(
        configService: ConfigService = ConfigService.shared,
        gitRepositoryService: any GitRepositoryServicing = GitRepositoryService(),
        editorLaunchService: any EditorLaunching = EditorLaunchService(),
        prLinkBuilder: any PRLinkBuilding = PRLinkBuilder()
    ) {
        self.configService = configService
        self.gitRepositoryService = gitRepositoryService
        self.editorLaunchService = editorLaunchService
        self.prLinkBuilder = prLinkBuilder
        self.showSidebar = configService.config.appearance.show_sidebar
        self.focusMode = configService.config.appearance.focus_mode
        loadWorkspacesFromConfig()

        // Ensure every workspace has the default terminal pair.
        bootstrapDefaultTerminals()

        // Auto-select first workspace and create a terminal on startup
        if let firstWorkspace = workspaces.first {
            selectedWorkspaceId = firstWorkspace.id
            if let firstTerminal = workspaces[0].terminals.first {
                selectTerminal(id: firstTerminal.id, in: firstWorkspace.id)
            }
        }

        refreshGitUIStatePlaceholder()
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

    private func bootstrapDefaultTerminals() {
        for index in workspaces.indices where workspaces[index].terminals.isEmpty {
            for name in defaultTerminalNames {
                _ = workspaces[index].addTerminal(name: name)
            }
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
        focusMode = configService.config.appearance.focus_mode

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
                var workspace = Workspace(id: stableId, name: wsConfig.name, path: expandedPath)
                // Default terminal pair for new workspaces added via config reload.
                for name in defaultTerminalNames {
                    _ = workspace.addTerminal(name: name)
                }
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
            AppLogger.app.error("workspace creation rejected: empty name")
            return false
        }
        guard !workspaces.contains(where: { $0.name == trimmedName }) else {
            AppLogger.app.error("workspace creation rejected: duplicate name")
            return false
        }

        let expandedPath = configService.expandPath(path)
        if !FileManager.default.fileExists(atPath: expandedPath) {
            AppLogger.app.warning("workspace path does not exist")
        }

        // Generate stable ID that will be saved to config
        let stableId = UUID()
        let workspace = Workspace(id: stableId, name: trimmedName, path: expandedPath)
        workspaces.append(workspace)

        if let index = workspaces.firstIndex(where: { $0.id == stableId }) {
            for name in defaultTerminalNames {
                _ = workspaces[index].addTerminal(name: name)
            }
        }

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

    // MARK: - Rename Operations

    func beginRenameWorkspace(id: UUID) {
        renamingTerminalId = nil
        renamingWorkspaceId = id
        selectedWorkspaceId = id
        selectedTerminalId = nil
    }

    func beginRenameTerminal(id: UUID) {
        renamingWorkspaceId = nil
        renamingTerminalId = id
    }

    func beginRenameSelectedItem() {
        if let terminalId = selectedTerminalId {
            beginRenameTerminal(id: terminalId)
        } else if let workspaceId = selectedWorkspaceId {
            beginRenameWorkspace(id: workspaceId)
        }
    }

    func cancelRenaming() {
        renamingWorkspaceId = nil
        renamingTerminalId = nil
    }

    @discardableResult
    func renameWorkspace(id: UUID, newName: String) -> Bool {
        let trimmedName = newName.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return false }
        guard !workspaces.contains(where: { $0.name == trimmedName && $0.id != id }) else { return false }
        guard let index = workspaces.firstIndex(where: { $0.id == id }) else { return false }

        workspaces[index].name = trimmedName
        configService.updateWorkspace(id: id.uuidString, newName: trimmedName, newPath: workspaces[index].path)
        return true
    }

    @discardableResult
    func renameTerminal(id: UUID, newName: String) -> Bool {
        let trimmedName = newName.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return false }

        for wsIndex in workspaces.indices {
            if let tIndex = workspaces[wsIndex].terminals.firstIndex(where: { $0.id == id }) {
                workspaces[wsIndex].terminals[tIndex].name = trimmedName
                return true
            }
        }

        return false
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

    // MARK: - Focus Mode (Persisted to Config)

    func toggleFocusMode() {
        focusMode.toggle()
        configService.setFocusMode(focusMode)
    }

    func setFocusMode(_ enabled: Bool) {
        focusMode = enabled
        configService.setFocusMode(focusMode)
    }

    // MARK: - Terminal Operations (Runtime Only)

    /// Create a new terminal, bootstrapping a default workspace if the user has none yet.
    func createTerminalViaShortcut() {
        if workspaces.isEmpty {
            _ = addWorkspace(name: ConfigService.preferredWorkspaceName, path: ConfigService.preferredWorkspaceRoot)
        }

        if selectedWorkspaceId == nil, let first = workspaces.first {
            selectedWorkspaceId = first.id
        }

        if selectedWorkspaceId != nil {
            createTerminalInSelectedWorkspace()
        }
    }

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

    func closeSelectedTerminal() {
        guard let wsId = selectedWorkspaceId,
              let tId = selectedTerminalId,
              let wsIndex = workspaces.firstIndex(where: { $0.id == wsId }),
              let tIndex = workspaces[wsIndex].terminals.firstIndex(where: { $0.id == tId }) else {
            return
        }

        workspaces[wsIndex].removeTerminal(id: tId)

        if workspaces[wsIndex].terminals.isEmpty {
            selectedTerminalId = nil
            return
        }

        let newIndex = min(tIndex, workspaces[wsIndex].terminals.count - 1)
        selectTerminal(id: workspaces[wsIndex].terminals[newIndex].id, in: wsId)
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

    var selectedWorkspaceURL: URL? {
        guard let workspace = selectedWorkspace else { return nil }
        return URL(fileURLWithPath: workspace.path)
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

    func selectTerminalByIndex(index: Int) {
        guard let wsId = selectedWorkspaceId else { return }
        let terminals = currentWorkspaceTerminals
        guard terminals.indices.contains(index) else { return }
        selectTerminal(id: terminals[index].id, in: wsId)
    }

    func toggleDiffPanelPlaceholder() {
        guard gitPanelState.disabledReason == nil else { return }
        gitPanelState.isPresented.toggle()
    }

    func dismissDiffPanelPlaceholder() {
        gitPanelState.isPresented = false
    }

    func setDiffPanelModePlaceholder(_ mode: DiffPanelMode) {
        gitPanelState.mode = mode
    }

    func presentCommitSheetPlaceholder() {
        guard commitSheetState.disabledReason == nil else { return }
        commitSheetState.errorText = nil
        commitSheetState.isPresented = true
    }

    func dismissCommitSheetPlaceholder() {
        commitSheetState.isPresented = false
    }

    func setCommitMessagePlaceholder(_ message: String) {
        commitSheetState.message = message
    }

    func setIncludeUnstagedPlaceholder(_ includeUnstaged: Bool) {
        commitSheetState.includeUnstaged = includeUnstaged
    }

    func setCommitNextStepPlaceholder(_ nextStep: CommitNextStep) {
        commitSheetState.nextStep = nextStep
    }

    func continueCommitFlowPlaceholder() {
        commitSheetState.errorText = GitControlDisabledReason.unavailableInPhase.title
    }

    func handleOpenActionPlaceholder(editor: ExternalEditor, workspaceID: UUID?) {
        guard let workspace = selectedWorkspace,
              let workspaceID = workspaceID else {
            return
        }

        let workspaceURL = URL(fileURLWithPath: workspace.path)
        Task {
            await editorLaunchService.setPreferredEditor(editor, for: workspaceID)
            await editorLaunchService.openWorkspace(at: workspaceURL, using: editor)
            refreshGitUIState()
        }
    }

    func initializeGitRepositoryPlaceholder() {
        guard let workspaceURL = selectedWorkspaceURL else { return }
        Task {
            do {
                try await gitRepositoryService.initializeRepository(at: workspaceURL)
                refreshGitUIState()
            } catch {
                await MainActor.run {
                    let message = String(describing: error)
                    gitPanelState.errorText = message
                    commitSheetState.errorText = message
                }
            }
        }
    }

    func refreshGitUIState() {
        guard let workspace = selectedWorkspace else {
            availableEditors = []
            gitPanelState.disabledReason = .noWorkspace
            gitPanelState.summary = GitChangeSummary()
            gitPanelState.isPresented = false
            commitSheetState.disabledReason = .noWorkspace
            commitSheetState.summary = GitChangeSummary()
            commitSheetState.isPresented = false
            return
        }

        let workspaceID = workspace.id
        let workspaceURL = URL(fileURLWithPath: workspace.path)
        Task {
            let status = await gitRepositoryService.status(at: workspaceURL)
            let editors = await editorLaunchService.availableEditors()
            let preferred = await editorLaunchService.preferredEditor(for: workspaceID)
            let orderedEditors = orderEditors(editors, preferred: preferred)

            await MainActor.run {
                guard selectedWorkspaceId == workspaceID else { return }
                availableEditors = orderedEditors

                gitPanelState.summary = GitChangeSummary(branchName: status.branchName)
                gitPanelState.errorText = nil
                gitPanelState.isLoading = false
                gitPanelState.patchText = ""
                if status.isRepository {
                    gitPanelState.disabledReason = nil
                    commitSheetState.disabledReason = nil
                } else {
                    gitPanelState.disabledReason = .notGitRepository
                    commitSheetState.disabledReason = .notGitRepository
                    gitPanelState.isPresented = false
                    commitSheetState.isPresented = false
                }
                commitSheetState.summary = GitChangeSummary(branchName: status.branchName)
                _ = prLinkBuilder.compareURL(remoteURL: "", baseBranch: "main", headBranch: "dev")
            }
        }
    }

    private func refreshGitUIStatePlaceholder() {
        refreshGitUIState()
    }

    private func orderEditors(_ editors: [ExternalEditor], preferred: ExternalEditor?) -> [ExternalEditor] {
        guard let preferred else { return editors }
        guard editors.contains(preferred) else { return editors }
        var ordered = editors.filter { $0 != preferred }
        ordered.insert(preferred, at: 0)
        return ordered
    }
}
