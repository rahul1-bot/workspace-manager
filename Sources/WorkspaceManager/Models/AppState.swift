import AppKit
import Foundation
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class AppState: ObservableObject {
    @Published var workspaces: [Workspace] = []
    @Published var selectedWorkspaceId: UUID?
    @Published var selectedTerminalId: UUID?
    @Published var showSidebar: Bool
    @Published var focusMode: Bool
    @Published var showNewWorkspaceSheet: Bool = false
    @Published var showNewTerminalSheet: Bool = false
    @Published var renamingWorkspaceId: UUID?
    @Published var renamingTerminalId: UUID?
    @Published var gitPanelState: GitPanelState = GitPanelState()
    @Published var commitSheetState: CommitSheetState = CommitSheetState()
    @Published var pdfPanelState: PDFPanelState = PDFPanelState()
    @Published var availableEditors: [ExternalEditor] = []
    @Published var currentViewMode: ViewMode = .sidebar
    @Published var graphDocument: GraphStateDocument = GraphStateDocument()
    @Published var focusedGraphNodeId: UUID?
    @Published var selectedGraphNodeId: UUID?
    @Published var graphViewport: ViewportTransform = .identity
    @Published var worktreeCatalog: WorktreeCatalog?
    @Published var worktreeErrorText: String?
    @Published var isWorktreeLoading: Bool = false
    @Published var showCreateWorktreeSheet: Bool = false
    @Published var worktreeAutoManagedWorkspaceIDs: Set<UUID> = []
    @Published var workspaceBranchMetadataByWorkspaceID: [UUID: WorkspaceBranchMetadata] = [:]

    private let configService: ConfigService
    private let graphStateService: GraphStateService = GraphStateService()
    private let forceLayoutEngine: ForceLayoutEngine = ForceLayoutEngine()
    private let gitRepositoryService: any GitRepositoryServicing
    private let editorLaunchService: any EditorLaunching
    private let prLinkBuilder: any PRLinkBuilding
    private let urlOpener: any URLOpening
    private let worktreeService: any WorktreeServicing
    private let workspaceBranchMetadataService: WorkspaceBranchMetadataService = WorkspaceBranchMetadataService()
    let worktreeStateService: WorktreeStateService = WorktreeStateService()
    private let fallbackTerminalName = "Terminal"
    private var diffLoadTask: Task<Void, Never>?
    private var commitTask: Task<Void, Never>?
    private var forceLayoutTask: Task<Void, Never>?
    private var graphLoadTask: Task<Void, Never>?
    private var gitStatusTask: Task<Void, Never>?
    private var commitSummaryTask: Task<Void, Never>?
    private var runtimePathObserver: NSObjectProtocol?
    private var terminalRuntimePaths: [UUID: String] = [:]
    private var worktreeCatalogTask: Task<Void, Never>?
    private var workspaceBranchMetadataTask: Task<Void, Never>?

    init(
        configService: ConfigService = ConfigService.shared,
        gitRepositoryService: any GitRepositoryServicing = GitRepositoryService(),
        editorLaunchService: any EditorLaunching = EditorLaunchService(),
        prLinkBuilder: any PRLinkBuilding = PRLinkBuilder(),
        urlOpener: any URLOpening = WorkspaceURLOpener(),
        worktreeService: any WorktreeServicing = WorktreeService()
    ) {
        self.configService = configService
        self.gitRepositoryService = gitRepositoryService
        self.editorLaunchService = editorLaunchService
        self.prLinkBuilder = prLinkBuilder
        self.urlOpener = urlOpener
        self.worktreeService = worktreeService
        self.showSidebar = configService.config.appearance.show_sidebar
        self.focusMode = configService.config.appearance.focus_mode
        loadWorkspacesFromConfig()
        installRuntimePathObserver()

        // Ensure every workspace has the default terminal pair.
        bootstrapDefaultTerminals()

        // Auto-select first workspace and create a terminal on startup
        if let firstWorkspace = workspaces.first {
            selectedWorkspaceId = firstWorkspace.id
            if let firstTerminal = workspaces[0].terminals.first {
                selectTerminal(id: firstTerminal.id, in: firstWorkspace.id)
            }
        }

        Task { @MainActor [weak self] in
            guard let self else { return }
            await self.refreshWorktreeAutoManagedWorkspaceIDs()
        }
        refreshWorkspaceBranchMetadata()
    }

    deinit {
        if let runtimePathObserver {
            NotificationCenter.default.removeObserver(runtimePathObserver)
        }
        worktreeCatalogTask?.cancel()
        workspaceBranchMetadataTask?.cancel()
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
        let configWorkspaces = configService.config.workspaces
        var didCreate = false
        for index in workspaces.indices where workspaces[index].terminals.isEmpty {
            let configTerminals = configWorkspaces.first(where: {
                UUID(uuidString: $0.id) == workspaces[index].id
            })?.terminals ?? []
            // Use terminal names from config; only fall back to a single generic terminal
            // if config defines none (e.g. brand-new workspace added via UI).
            let names = configTerminals.isEmpty ? [fallbackTerminalName] : configTerminals
            for name in names {
                _ = workspaces[index].addTerminal(name: name)
            }
            didCreate = true
        }
        // Persist all bootstrapped terminal names back to config so they survive restart.
        if didCreate {
            for workspace in workspaces {
                let names = workspace.terminals.map(\.name)
                configService.syncTerminalNamesInMemory(
                    workspaceId: workspace.id.uuidString, terminalNames: names
                )
            }
            configService.saveConfig()
        }
    }

    private func installRuntimePathObserver() {
        runtimePathObserver = NotificationCenter.default.addObserver(
            forName: .wmTerminalRuntimePathDidChange,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            guard let terminalID = notification.userInfo?[TerminalRuntimeNotificationKey.terminalID] as? UUID else { return }
            guard let path = notification.userInfo?[TerminalRuntimeNotificationKey.path] as? String else { return }
            Task { @MainActor in
                self.updateTerminalRuntimePath(for: terminalID, path: path)
            }
        }
    }

    func reloadFromConfig() {
        configService.reloadConfig()
        let previousSelectedWorkspace = selectedWorkspaceId
        let previousSelectedTerminal = selectedTerminalId

        // Merge-style reload: preserve existing terminals while updating workspace metadata
        mergeWorkspacesFromConfig()
        Task { @MainActor [weak self] in
            guard let self else { return }
            await self.refreshWorktreeAutoManagedWorkspaceIDs()
        }
        refreshWorkspaceBranchMetadata()

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
                let names = wsConfig.terminals.isEmpty ? [fallbackTerminalName] : wsConfig.terminals
                for name in names {
                    _ = workspace.addTerminal(name: name)
                }
                workspaces.append(workspace)
            }
        }
        pruneTerminalRuntimePaths()
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
            _ = workspaces[index].addTerminal(name: fallbackTerminalName)
        }

        configService.addWorkspace(id: stableId.uuidString, name: trimmedName, path: path)
        refreshWorkspaceBranchMetadata()
        return true
    }

    func removeWorkspace(id: UUID) {
        if let workspace = workspaces.first(where: { $0.id == id }) {
            for terminal in workspace.terminals {
                terminalRuntimePaths.removeValue(forKey: terminal.id)
            }
        }
        workspaces.removeAll { $0.id == id }
        if selectedWorkspaceId == id {
            selectedWorkspaceId = nil
            selectedTerminalId = nil
            refreshGitUIState()
        }

        configService.removeWorkspace(id: id.uuidString)
        pruneTerminalRuntimePaths()
        worktreeAutoManagedWorkspaceIDs.remove(id)
        workspaceBranchMetadataByWorkspaceID.removeValue(forKey: id)
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
                persistTerminalNames(for: workspaces[wsIndex].id)
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

    // MARK: - Terminal Name Persistence

    /// Persist the current terminal names for a workspace back to config.toml.
    private func persistTerminalNames(for workspaceId: UUID) {
        guard let workspace = workspaces.first(where: { $0.id == workspaceId }) else { return }
        let names = workspace.terminals.map(\.name)
        configService.syncTerminalNames(workspaceId: workspaceId.uuidString, terminalNames: names)
    }

    // MARK: - Terminal Operations

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
        persistTerminalNames(for: workspaceId)
        selectTerminal(id: terminal.id, in: workspaceId)
    }

    func addTerminal(to workspaceId: UUID, name: String) {
        guard let index = workspaces.firstIndex(where: { $0.id == workspaceId }) else { return }

        let terminal = workspaces[index].addTerminal(name: name)
        persistTerminalNames(for: workspaceId)
        selectTerminal(id: terminal.id, in: workspaceId)
    }

    func removeTerminal(id: UUID, from workspaceId: UUID) {
        guard let index = workspaces.firstIndex(where: { $0.id == workspaceId }) else { return }

        workspaces[index].removeTerminal(id: id)
        terminalRuntimePaths.removeValue(forKey: id)
        persistTerminalNames(for: workspaceId)
        if selectedTerminalId == id {
            selectedTerminalId = nil
            refreshGitUIState()
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
        terminalRuntimePaths.removeValue(forKey: tId)
        persistTerminalNames(for: wsId)

        if workspaces[wsIndex].terminals.isEmpty {
            selectedTerminalId = nil
            refreshGitUIState()
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
        refreshGitUIState()
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

    var sidebarWorkspaces: [Workspace] {
        workspaces.filter { workspace in
            if selectedWorkspaceId == workspace.id {
                return true
            }
            return !isWorkspaceAutoManaged(workspace)
        }
    }

    func refreshWorkspaceBranchMetadata() {
        let workspaceSnapshot = workspaces.map { (id: $0.id, path: $0.path) }
        workspaceBranchMetadataTask?.cancel()
        workspaceBranchMetadataTask = Task { [weak self] in
            guard let self else { return }
            var metadataByWorkspaceID: [UUID: WorkspaceBranchMetadata] = [:]

            await withTaskGroup(of: (UUID, WorkspaceBranchMetadata?).self) { group in
                for workspace in workspaceSnapshot {
                    let service = self.workspaceBranchMetadataService
                    group.addTask {
                        let metadata = await service.metadata(for: workspace.path)
                        return (workspace.id, metadata)
                    }
                }

                for await (workspaceID, metadata) in group {
                    if let metadata {
                        metadataByWorkspaceID[workspaceID] = metadata
                    }
                }
            }

            if Task.isCancelled {
                return
            }

            await MainActor.run { [weak self] in
                guard let self else { return }
                let currentWorkspaceIDs = Set(self.workspaces.map(\.id))
                self.workspaceBranchMetadataByWorkspaceID = metadataByWorkspaceID.filter { entry in
                    currentWorkspaceIDs.contains(entry.key)
                }
            }
        }
    }

    func updateTerminalRuntimePath(for terminalID: UUID, path: String) {
        guard let resolvedPath = normalizedDirectoryPath(path) else {
            clearTerminalRuntimePath(for: terminalID)
            return
        }

        let previousPath = terminalRuntimePaths[terminalID]
        terminalRuntimePaths[terminalID] = resolvedPath

        if selectedTerminalId == terminalID, previousPath != resolvedPath {
            refreshGitUIState()
        }
    }

    func clearTerminalRuntimePath(for terminalID: UUID) {
        let removed = terminalRuntimePaths.removeValue(forKey: terminalID)
        if selectedTerminalId == terminalID, removed != nil {
            refreshGitUIState()
        }
    }

    func actionTargetURL(for terminalID: UUID?) -> URL? {
        guard let terminalID,
              let terminal = terminal(with: terminalID) else {
            return nil
        }

        if let runtimePath = terminalRuntimePaths[terminalID],
           let resolvedRuntimePath = normalizedDirectoryPath(runtimePath) {
            return URL(fileURLWithPath: resolvedRuntimePath)
        }

        if let launchPath = normalizedDirectoryPath(terminal.workingDirectory) {
            return URL(fileURLWithPath: launchPath)
        }

        return nil
    }

    private var selectedActionTargetURL: URL? {
        actionTargetURL(for: selectedTerminalId)
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
            if let firstTerminal = prevWorkspace.terminals.first {
                selectTerminal(id: firstTerminal.id, in: prevWorkspace.id)
            } else {
                selectedTerminalId = nil
                refreshGitUIState()
            }
        } else {
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
            if let firstTerminal = nextWorkspace.terminals.first {
                selectTerminal(id: firstTerminal.id, in: nextWorkspace.id)
            } else {
                selectedTerminalId = nil
                refreshGitUIState()
            }
        } else {
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
        if gitPanelState.isPresented {
            dismissPDFPanel()
            loadDiffPanel()
        } else {
            diffLoadTask?.cancel()
        }
    }

    func dismissDiffPanelPlaceholder() {
        gitPanelState.isPresented = false
        diffLoadTask?.cancel()
    }

    func setDiffPanelModePlaceholder(_ mode: DiffPanelMode) {
        gitPanelState.mode = mode
        if mode != .worktreeComparison {
            gitPanelState.worktreeDiffRequest = nil
            gitPanelState.baselineLabel = nil
        }
        if gitPanelState.isPresented {
            if mode == .worktreeComparison {
                setWorktreeDiffBaseline(.mergeBaseWithDefault)
            } else {
                loadDiffPanel()
            }
        }
    }

    func togglePDFPanel() {
        if pdfPanelState.isPresented {
            dismissPDFPanel()
            return
        }

        dismissDiffPanelPlaceholder()
        if pdfPanelState.activeTabId == nil {
            pdfPanelState.activeTabId = pdfPanelState.tabs.first?.id
        }
        pdfPanelState.isPresented = true
    }

    func dismissPDFPanel() {
        pdfPanelState.isPresented = false
    }

    func openPDFFile(_ url: URL) {
        dismissDiffPanelPlaceholder()

        if let existingIndex = pdfPanelState.tabs.firstIndex(where: { $0.fileURL == url }) {
            pdfPanelState.activeTabId = pdfPanelState.tabs[existingIndex].id
            pdfPanelState.isPresented = true
            return
        }

        let tab = PDFTab(fileURL: url)
        pdfPanelState.tabs.append(tab)
        pdfPanelState.activeTabId = tab.id
        pdfPanelState.errorText = nil
        pdfPanelState.isLoading = false
        pdfPanelState.isPresented = true
    }

    func closePDFTab(id: UUID) {
        pdfPanelState.tabs.removeAll { $0.id == id }

        guard !pdfPanelState.tabs.isEmpty else {
            pdfPanelState.activeTabId = nil
            pdfPanelState.isPresented = false
            return
        }

        if pdfPanelState.activeTabId == id {
            pdfPanelState.activeTabId = pdfPanelState.tabs.first?.id
        }
    }

    func selectPDFTab(id: UUID) {
        guard pdfPanelState.tabs.contains(where: { $0.id == id }) else { return }
        pdfPanelState.activeTabId = id
    }

    func selectNextPDFTab() {
        guard let currentIndex = pdfPanelState.activeTabIndex else { return }
        let nextIndex = (currentIndex + 1) % pdfPanelState.tabs.count
        pdfPanelState.activeTabId = pdfPanelState.tabs[nextIndex].id
    }

    func selectPreviousPDFTab() {
        guard let currentIndex = pdfPanelState.activeTabIndex else { return }
        let prevIndex = (currentIndex - 1 + pdfPanelState.tabs.count) % pdfPanelState.tabs.count
        pdfPanelState.activeTabId = pdfPanelState.tabs[prevIndex].id
    }

    func updatePDFPageIndex(_ index: Int) {
        guard let activeTabId = pdfPanelState.activeTabId,
              let tabIndex = pdfPanelState.tabs.firstIndex(where: { $0.id == activeTabId }) else {
            return
        }
        pdfPanelState.tabs[tabIndex].currentPageIndex = index
    }

    func updatePDFTotalPages(_ count: Int) {
        guard let activeTabId = pdfPanelState.activeTabId,
              let tabIndex = pdfPanelState.tabs.firstIndex(where: { $0.id == activeTabId }) else {
            return
        }
        pdfPanelState.tabs[tabIndex].totalPages = count
    }

    func presentPDFFilePicker() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.pdf]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.message = "Select a PDF file to open"

        guard panel.runModal() == .OK, let selectedURL = panel.url else {
            return
        }

        openPDFFile(selectedURL)
    }

    func presentCommitSheetPlaceholder() {
        guard commitSheetState.disabledReason == nil else { return }
        commitSheetState.isLoading = false
        commitSheetState.errorText = nil
        commitSheetState.isPresented = true
        loadCommitSummary()
    }

    func dismissCommitSheetPlaceholder() {
        commitSheetState.isPresented = false
        commitTask?.cancel()
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
        guard let actionTargetURL = selectedActionTargetURL else { return }
        commitSheetState.errorText = nil
        commitSheetState.isLoading = true

        let stagePolicy: CommitStagePolicy = commitSheetState.includeUnstaged ? .includeUnstaged : .stagedOnly
        let nextStep = commitSheetState.nextStep
        let enteredMessage = commitSheetState.message.trimmingCharacters(in: .whitespacesAndNewlines)
        let workspaceID = selectedWorkspaceId

        commitTask?.cancel()
        commitTask = Task {
            do {
                let message = try await resolveCommitMessage(enteredMessage: enteredMessage, workspaceURL: actionTargetURL)
                let result = try await gitRepositoryService.executeCommit(
                    at: actionTargetURL,
                    stagePolicy: stagePolicy,
                    message: message,
                    nextStep: nextStep
                )

                await MainActor.run {
                    guard selectedWorkspaceId == workspaceID else { return }
                    commitSheetState.isLoading = false
                    commitSheetState.isPresented = false
                    commitSheetState.message = ""
                }

                if nextStep == .commitAndCreatePR,
                   let remoteURL = result.remoteURL,
                   let compareURL = prLinkBuilder.compareURL(
                       remoteURL: remoteURL,
                       baseBranch: result.baseBranch,
                       headBranch: result.branchName
                   ) {
                    await urlOpener.open(compareURL)
                }

                await MainActor.run {
                    refreshGitUIState()
                }
            } catch {
                if Task.isCancelled {
                    return
                }
                await MainActor.run {
                    guard selectedWorkspaceId == workspaceID else { return }
                    commitSheetState.isLoading = false
                    commitSheetState.errorText = commitErrorText(error)
                }
            }
        }
    }

    func handleOpenActionPlaceholder(editor: ExternalEditor, workspaceID: UUID?, terminalID: UUID?) {
        guard selectedWorkspace != nil,
              let workspaceID = workspaceID,
              actionTargetURL(for: terminalID) != nil else {
            return
        }

        guard let targetURL = actionTargetURL(for: terminalID) else {
            return
        }
        Task {
            await editorLaunchService.setPreferredEditor(editor, for: workspaceID)
            await editorLaunchService.openWorkspace(at: targetURL, using: editor)
            refreshGitUIState()
        }
    }

    func initializeGitRepositoryPlaceholder() {
        guard let targetURL = selectedActionTargetURL else { return }
        Task {
            do {
                try await gitRepositoryService.initializeRepository(at: targetURL)
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
            resetWorktreeStateForUnavailableContext()
            return
        }

        guard let terminalID = selectedTerminalId else {
            availableEditors = []
            gitPanelState.disabledReason = .noTerminalSelection
            gitPanelState.summary = GitChangeSummary()
            gitPanelState.isPresented = false
            commitSheetState.disabledReason = .noTerminalSelection
            commitSheetState.summary = GitChangeSummary()
            commitSheetState.isPresented = false
            resetWorktreeStateForUnavailableContext()
            return
        }

        guard let actionTargetURL = actionTargetURL(for: terminalID) else {
            availableEditors = []
            gitPanelState.disabledReason = .noTerminalSelection
            gitPanelState.summary = GitChangeSummary()
            gitPanelState.isPresented = false
            commitSheetState.disabledReason = .noTerminalSelection
            commitSheetState.summary = GitChangeSummary()
            commitSheetState.isPresented = false
            resetWorktreeStateForUnavailableContext()
            return
        }

        let workspaceID = workspace.id
        gitStatusTask?.cancel()
        gitStatusTask = Task { [weak self] in
            guard let self else { return }
            let status = await gitRepositoryService.status(at: actionTargetURL)
            guard !Task.isCancelled else { return }
            let editors = await editorLaunchService.availableEditors()
            guard !Task.isCancelled else { return }
            let preferred = await editorLaunchService.preferredEditor(for: workspaceID)
            guard !Task.isCancelled else { return }
            let orderedEditors = orderEditors(editors, preferred: preferred)

            await MainActor.run { [weak self] in
                guard let self else { return }
                guard self.selectedWorkspaceId == workspaceID else { return }
                self.availableEditors = orderedEditors

                self.gitPanelState.summary = GitChangeSummary(branchName: status.branchName)
                self.gitPanelState.errorText = nil
                self.gitPanelState.isLoading = false
                self.gitPanelState.patchText = ""
                if status.isRepository {
                    self.gitPanelState.disabledReason = nil
                    self.commitSheetState.disabledReason = nil
                    self.refreshWorktreeCatalogForSelection()
                    if self.gitPanelState.isPresented {
                        self.loadDiffPanel()
                    }
                } else {
                    self.gitPanelState.disabledReason = .notGitRepository
                    self.commitSheetState.disabledReason = .notGitRepository
                    self.gitPanelState.isPresented = false
                    self.diffLoadTask?.cancel()
                    self.commitSheetState.isPresented = false
                    self.resetWorktreeStateForUnavailableContext()
                }
                self.commitSheetState.summary = GitChangeSummary(branchName: status.branchName)
            }
        }
    }

    private func orderEditors(_ editors: [ExternalEditor], preferred: ExternalEditor?) -> [ExternalEditor] {
        guard let preferred else { return editors }
        guard editors.contains(preferred) else { return editors }
        var ordered = editors.filter { $0 != preferred }
        ordered.insert(preferred, at: 0)
        return ordered
    }

    private func loadDiffPanel() {
        if gitPanelState.mode == .worktreeComparison {
            loadWorktreeDiffPanel()
            return
        }

        guard let workspace = selectedWorkspace else { return }
        guard gitPanelState.disabledReason == nil else { return }
        guard let actionTargetURL = selectedActionTargetURL else {
            gitPanelState.isLoading = false
            gitPanelState.patchText = ""
            gitPanelState.errorText = "No terminal path available for diff."
            return
        }

        diffLoadTask?.cancel()
        gitPanelState.isLoading = true
        gitPanelState.errorText = nil
        gitPanelState.patchText = ""
        let fallbackBranchName = gitPanelState.summary.branchName

        let workspaceID = workspace.id
        let mode = gitPanelState.mode

        diffLoadTask = Task {
            do {
                let snapshot = try await gitRepositoryService.diff(at: actionTargetURL, mode: mode)
                await MainActor.run {
                    guard selectedWorkspaceId == workspaceID else { return }
                    guard gitPanelState.mode == mode else { return }
                    gitPanelState.summary = snapshot.summary
                    gitPanelState.patchText = snapshot.patchText
                    gitPanelState.isLoading = false
                }
            } catch {
                if Task.isCancelled {
                    return
                }
                await MainActor.run {
                    guard selectedWorkspaceId == workspaceID else { return }
                    guard gitPanelState.mode == mode else { return }
                    gitPanelState.summary = GitChangeSummary(branchName: fallbackBranchName)
                    gitPanelState.patchText = ""
                    gitPanelState.isLoading = false
                    gitPanelState.errorText = diffErrorText(error)
                }
            }
        }
    }

    private func diffErrorText(_ error: Error) -> String {
        if let gitError = error as? GitRepositoryServiceError {
            switch gitError {
            case .noHistory:
                return "No commit history available for last turn changes."
            case .missingBaseBranch:
                return "Cannot resolve a base branch for this repository."
            case .noChangesToCommit:
                return "No changes to diff."
            case .invalidWorktreeBaseline:
                return "Select a valid worktree comparison baseline."
            case .targetWorktreeNotFound:
                return "Target worktree could not be found."
            case .crossRepositoryComparisonUnsupported:
                return "Worktree comparison only supports paths in the same repository."
            case .worktreeCommandFailed(let message):
                return message.trimmingCharacters(in: .whitespacesAndNewlines)
            case .commandFailed(let message):
                return message.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return String(describing: error)
    }

    private func commitErrorText(_ error: Error) -> String {
        if let gitError = error as? GitRepositoryServiceError {
            switch gitError {
            case .noChangesToCommit:
                return "No staged changes to commit."
            case .noHistory:
                return "Repository has no commit history yet."
            case .missingBaseBranch:
                return "Cannot resolve a base branch for this repository."
            case .invalidWorktreeBaseline:
                return "Select a valid worktree comparison baseline."
            case .targetWorktreeNotFound:
                return "Target worktree could not be found."
            case .crossRepositoryComparisonUnsupported:
                return "Worktree comparison only supports paths in the same repository."
            case .worktreeCommandFailed(let message):
                return message.trimmingCharacters(in: .whitespacesAndNewlines)
            case .commandFailed(let message):
                return message.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return String(describing: error)
    }

    private func resolveCommitMessage(enteredMessage: String, workspaceURL: URL) async throws -> String {
        if !enteredMessage.isEmpty {
            return enteredMessage
        }
        return try await gitRepositoryService.autoCommitMessage(at: workspaceURL)
    }

    private func loadCommitSummary() {
        guard let workspace = selectedWorkspace else { return }
        guard commitSheetState.disabledReason == nil else { return }
        let workspaceID = workspace.id
        guard let actionTargetURL = selectedActionTargetURL else {
            commitSheetState.summary = GitChangeSummary(branchName: commitSheetState.summary.branchName)
            return
        }
        let fallbackBranchName = commitSheetState.summary.branchName

        commitSummaryTask?.cancel()
        commitSummaryTask = Task { [weak self] in
            guard let self else { return }
            do {
                let snapshot = try await gitRepositoryService.diff(at: actionTargetURL, mode: .uncommitted)
                guard !Task.isCancelled else { return }
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    guard self.selectedWorkspaceId == workspaceID else { return }
                    self.commitSheetState.summary = snapshot.summary
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    guard self.selectedWorkspaceId == workspaceID else { return }
                    self.commitSheetState.summary = GitChangeSummary(branchName: fallbackBranchName)
                }
            }
        }
    }

    func refreshWorktreeCatalogForSelection() {
        guard let actionTargetURL = selectedActionTargetURL else {
            isWorktreeLoading = false
            worktreeCatalog = nil
            worktreeErrorText = nil
            gitPanelState.worktreeDiffRequest = nil
            gitPanelState.baselineLabel = nil
            return
        }

        isWorktreeLoading = true
        worktreeErrorText = nil
        let workspaceID = selectedWorkspaceId
        worktreeCatalogTask?.cancel()
        worktreeCatalogTask = Task { [weak self] in
            guard let self else { return }
            do {
                let catalog = try await worktreeService.catalog(for: actionTargetURL)
                if Task.isCancelled {
                    await MainActor.run {
                        self.isWorktreeLoading = false
                    }
                    return
                }
                await MainActor.run {
                    self.isWorktreeLoading = false
                    guard self.selectedWorkspaceId == workspaceID else { return }
                    self.worktreeCatalog = catalog
                }
                await self.syncCatalogToWorkspaces()

                await MainActor.run {
                    guard self.selectedWorkspaceId == workspaceID else { return }
                    if self.gitPanelState.mode == .worktreeComparison {
                        self.setWorktreeDiffBaseline(.mergeBaseWithDefault)
                    }
                }
            } catch {
                if Task.isCancelled {
                    await MainActor.run {
                        self.isWorktreeLoading = false
                    }
                    return
                }
                await MainActor.run {
                    self.isWorktreeLoading = false
                    guard self.selectedWorkspaceId == workspaceID else { return }
                    self.worktreeCatalog = nil
                    self.worktreeErrorText = String(describing: error)
                    self.gitPanelState.worktreeDiffRequest = nil
                    self.gitPanelState.baselineLabel = nil
                }
            }
        }
    }

    func presentCreateWorktreeSheet() {
        showCreateWorktreeSheet = true
        worktreeErrorText = nil
        refreshWorktreeCatalogForSelection()
    }

    func resolveWorktreeRepositoryRootForSelection() async throws -> String {
        if let catalog = worktreeCatalog {
            return catalog.repositoryRootPath
        }

        guard let actionTargetURL = selectedActionTargetURL else {
            throw WorktreeServiceError.invalidRequest("No terminal path available for worktree creation.")
        }

        isWorktreeLoading = true
        do {
            let catalog = try await worktreeService.catalog(for: actionTargetURL)
            worktreeCatalog = catalog
            worktreeErrorText = nil
            isWorktreeLoading = false
            await syncCatalogToWorkspaces()
            return catalog.repositoryRootPath
        } catch {
            isWorktreeLoading = false
            worktreeCatalog = nil
            worktreeErrorText = String(describing: error)
            throw error
        }
    }

    func syncCatalogToWorkspaces() async {
        guard let catalog = worktreeCatalog else { return }
        let existingStateDocument = await worktreeStateService.load()

        let syncPlan = worktreeService.workspaceSyncPlan(catalog: catalog, existingWorkspaces: workspaces)

        for update in syncPlan.updates {
            let workspaceKey = update.workspaceID.uuidString
            let normalizedPath = URL(fileURLWithPath: update.descriptor.worktreePath).standardizedFileURL.path
            let existingLink = existingStateDocument.linksByWorkspaceID[workspaceKey]
                ?? existingStateDocument.linksByWorktreePath[normalizedPath]
            let inferredAutoManaged = workspaces.first(where: { $0.id == update.workspaceID }).map(isLikelyAutoManagedWorkspace) ?? false
            let autoManaged = existingLink?.isAutoManaged ?? inferredAutoManaged
            await worktreeStateService.linkWorkspace(
                workspaceID: update.workspaceID,
                worktreePath: update.descriptor.worktreePath,
                repoRootPath: update.descriptor.repositoryRootPath,
                isAutoManaged: autoManaged
            )
        }

        for descriptor in syncPlan.additions {
            let name = uniqueAutoManagedWorkspaceName(for: descriptor)
            let added = addWorkspace(name: name, path: descriptor.worktreePath)
            guard added else { continue }
            guard let workspaceID = workspaces.first(where: {
                URL(fileURLWithPath: $0.path).standardizedFileURL.path == descriptor.worktreePath
            })?.id else {
                continue
            }
            await worktreeStateService.linkWorkspace(
                workspaceID: workspaceID,
                worktreePath: descriptor.worktreePath,
                repoRootPath: descriptor.repositoryRootPath,
                isAutoManaged: true
            )
        }

        let stateDocument = await worktreeStateService.load()
        let activePaths = Set(catalog.descriptors.map(\.worktreePath))
        let stalePaths = stateDocument.linksByWorktreePath.keys.filter { !activePaths.contains($0) }
        await worktreeStateService.setStaleWorktreePaths(stalePaths)
        await refreshWorktreeAutoManagedWorkspaceIDs()
        refreshWorkspaceBranchMetadata()
    }

    @discardableResult
    func switchToWorktree(path: String) -> Bool {
        let normalizedPath = URL(fileURLWithPath: path).standardizedFileURL.path
        guard let workspace = workspaces.first(where: {
            URL(fileURLWithPath: $0.path).standardizedFileURL.path == normalizedPath
        }) else {
            return false
        }

        selectedWorkspaceId = workspace.id
        if let firstTerminal = workspace.terminals.first {
            selectTerminal(id: firstTerminal.id, in: workspace.id)
        } else {
            selectedTerminalId = nil
            refreshGitUIState()
        }
        return true
    }

    func createWorktreeFromSelection(request: WorktreeCreateRequest) async throws {
        isWorktreeLoading = true
        worktreeErrorText = nil
        defer {
            isWorktreeLoading = false
        }

        do {
            let descriptor = try await worktreeService.createWorktree(request)
            worktreeErrorText = nil
            showCreateWorktreeSheet = false

            let normalizedPath = URL(fileURLWithPath: descriptor.worktreePath).standardizedFileURL.path
            let workspaceID: UUID
            if let existingWorkspaceID = workspaces.first(where: {
                URL(fileURLWithPath: $0.path).standardizedFileURL.path == normalizedPath
            })?.id {
                workspaceID = existingWorkspaceID
            } else {
                let name = uniqueAutoManagedWorkspaceName(for: descriptor)
                guard addWorkspace(name: name, path: descriptor.worktreePath),
                      let addedWorkspaceID = workspaces.first(where: {
                          URL(fileURLWithPath: $0.path).standardizedFileURL.path == normalizedPath
                      })?.id else {
                    throw WorktreeServiceError.invalidRequest("Failed to register created worktree as a workspace.")
                }
                workspaceID = addedWorkspaceID
            }

            await worktreeStateService.linkWorkspace(
                workspaceID: workspaceID,
                worktreePath: descriptor.worktreePath,
                repoRootPath: descriptor.repositoryRootPath,
                isAutoManaged: true
            )
            await refreshWorktreeAutoManagedWorkspaceIDs()

            if let purpose = request.purpose?.trimmingCharacters(in: .whitespacesAndNewlines),
               !purpose.isEmpty {
                await worktreeStateService.upsertPurpose(workspaceID: workspaceID, purpose: purpose)
            }

            _ = switchToWorktree(path: descriptor.worktreePath)
            setWorktreeDiffBaseline(.mergeBaseWithDefault)
            refreshWorktreeCatalogForSelection()
            refreshWorkspaceBranchMetadata()
        } catch {
            worktreeErrorText = String(describing: error)
            throw error
        }
    }

    func setWorktreeDiffBaseline(_ baseline: WorktreeComparisonBaseline) {
        guard let request = makeWorktreeDiffRequest(baseline: baseline) else { return }
        gitPanelState.worktreeDiffRequest = request
        gitPanelState.baselineLabel = baseline.title
        if gitPanelState.isPresented, gitPanelState.mode == .worktreeComparison {
            loadWorktreeDiffPanel()
        }
    }

    func openWorktreeComparisonPanel() {
        guard gitPanelState.disabledReason == nil else { return }
        dismissPDFPanel()
        gitPanelState.mode = .worktreeComparison
        gitPanelState.isPresented = true
        setWorktreeDiffBaseline(.mergeBaseWithDefault)
    }

    func compareAgainstWorktree(_ descriptor: WorktreeDescriptor) {
        guard gitPanelState.disabledReason == nil else { return }
        dismissPDFPanel()
        gitPanelState.mode = .worktreeComparison
        gitPanelState.isPresented = true
        setWorktreeDiffBaseline(.siblingWorktree(path: descriptor.worktreePath, branchName: descriptor.branchName))
    }

    func switchToNextWorktree() {
        guard let catalog = worktreeCatalog, !catalog.descriptors.isEmpty else { return }
        let currentPath = currentWorktreeDescriptor()?.worktreePath
        guard let currentPath,
              let currentIndex = catalog.descriptors.firstIndex(where: { $0.worktreePath == currentPath }) else {
            _ = switchToWorktree(path: catalog.descriptors[0].worktreePath)
            return
        }
        let nextIndex = (currentIndex + 1) % catalog.descriptors.count
        _ = switchToWorktree(path: catalog.descriptors[nextIndex].worktreePath)
    }

    func switchToPreviousWorktree() {
        guard let catalog = worktreeCatalog, !catalog.descriptors.isEmpty else { return }
        let currentPath = currentWorktreeDescriptor()?.worktreePath
        guard let currentPath,
              let currentIndex = catalog.descriptors.firstIndex(where: { $0.worktreePath == currentPath }) else {
            _ = switchToWorktree(path: catalog.descriptors[0].worktreePath)
            return
        }
        let previousIndex = (currentIndex - 1 + catalog.descriptors.count) % catalog.descriptors.count
        _ = switchToWorktree(path: catalog.descriptors[previousIndex].worktreePath)
    }

    var availableWorktreeBaselines: [WorktreeComparisonBaseline] {
        guard let catalog = worktreeCatalog else {
            return [.mergeBaseWithDefault]
        }

        var baselines: [WorktreeComparisonBaseline] = [.mergeBaseWithDefault]
        for descriptor in catalog.siblingDescriptors {
            baselines.append(
                .siblingWorktree(path: descriptor.worktreePath, branchName: descriptor.branchName)
            )
        }
        return baselines
    }

    func suggestedWorktreeDestinationPath(for branchName: String) -> String? {
        guard let repositoryRootPath = worktreeCatalog?.repositoryRootPath else { return nil }
        return suggestedWorktreeDestinationPath(for: branchName, repositoryRootPath: repositoryRootPath)
    }

    func suggestedWorktreeDestinationPath(for branchName: String, repositoryRootPath: String) -> String? {
        let repositoryURL = URL(fileURLWithPath: repositoryRootPath).resolvingSymlinksInPath().standardizedFileURL
        let parentURL = repositoryURL.deletingLastPathComponent()
        let wtRootURL = parentURL.appendingPathComponent(".wt", isDirectory: true)
        let repoBucketURL = wtRootURL.appendingPathComponent(repositoryURL.lastPathComponent, isDirectory: true)
        let slug = sluggedBranchName(branchName)
        guard !slug.isEmpty else { return nil }
        let destinationURL = repoBucketURL.appendingPathComponent(slug, isDirectory: true)
        return destinationURL.path
    }

    func currentWorktreeDescriptor() -> WorktreeDescriptor? {
        guard let catalog = worktreeCatalog,
              let actionTargetURL = selectedActionTargetURL else {
            return nil
        }

        let actionPath = actionTargetURL.standardizedFileURL.path
        let matches = catalog.descriptors.filter { descriptor in
            actionPath == descriptor.worktreePath || actionPath.hasPrefix(descriptor.worktreePath + "/")
        }

        return matches.max(by: { lhs, rhs in
            lhs.worktreePath.count < rhs.worktreePath.count
        })
    }

    private func makeWorktreeDiffRequest(baseline: WorktreeComparisonBaseline) -> WorktreeDiffRequest? {
        guard let catalog = worktreeCatalog,
              let descriptor = currentWorktreeDescriptor() else {
            return nil
        }

        return WorktreeDiffRequest(
            repositoryRootPath: catalog.repositoryRootPath,
            sourceWorktreePath: descriptor.worktreePath,
            sourceBranchName: descriptor.branchName,
            baseline: baseline
        )
    }

    private func loadWorktreeDiffPanel() {
        guard let workspace = selectedWorkspace else { return }
        guard gitPanelState.disabledReason == nil else { return }

        if gitPanelState.worktreeDiffRequest == nil {
            setWorktreeDiffBaseline(.mergeBaseWithDefault)
        }

        guard let request = gitPanelState.worktreeDiffRequest else {
            gitPanelState.isLoading = false
            gitPanelState.patchText = ""
            gitPanelState.errorText = "No worktree baseline is selected."
            return
        }

        let workspaceID = workspace.id
        let fallbackBranchName = gitPanelState.summary.branchName

        diffLoadTask?.cancel()
        gitPanelState.isLoading = true
        gitPanelState.errorText = nil
        gitPanelState.patchText = ""

        diffLoadTask = Task {
            do {
                let snapshot = try await gitRepositoryService.diffWorktreeComparison(request: request)
                await MainActor.run {
                    guard selectedWorkspaceId == workspaceID else { return }
                    guard gitPanelState.mode == .worktreeComparison else { return }
                    gitPanelState.summary = snapshot.summary
                    gitPanelState.patchText = snapshot.patchText
                    gitPanelState.isLoading = false
                }
            } catch {
                if Task.isCancelled {
                    return
                }
                await MainActor.run {
                    guard selectedWorkspaceId == workspaceID else { return }
                    guard gitPanelState.mode == .worktreeComparison else { return }
                    gitPanelState.summary = GitChangeSummary(branchName: fallbackBranchName)
                    gitPanelState.patchText = ""
                    gitPanelState.isLoading = false
                    gitPanelState.errorText = diffErrorText(error)
                }
            }
        }
    }

    private func resetWorktreeStateForUnavailableContext() {
        worktreeCatalogTask?.cancel()
        isWorktreeLoading = false
        worktreeCatalog = nil
        worktreeErrorText = nil
        showCreateWorktreeSheet = false
        gitPanelState.worktreeDiffRequest = nil
        gitPanelState.baselineLabel = nil
    }

    private func refreshWorktreeAutoManagedWorkspaceIDs() async {
        let stateDocument = await worktreeStateService.load()
        let knownWorkspaceIDs = Set(workspaces.map(\.id))
        let autoManagedIDs: Set<UUID> = Set(
            stateDocument.linksByWorkspaceID.compactMap { _, link in
                guard link.isAutoManaged else { return nil }
                return UUID(uuidString: link.workspaceID)
            }.filter { knownWorkspaceIDs.contains($0) }
        )
        let inferredAutoManagedIDs = Set(workspaces.filter(isLikelyAutoManagedWorkspace).map(\.id))
        worktreeAutoManagedWorkspaceIDs = autoManagedIDs.union(inferredAutoManagedIDs)
    }

    private func isWorkspaceAutoManaged(_ workspace: Workspace) -> Bool {
        worktreeAutoManagedWorkspaceIDs.contains(workspace.id) || isLikelyAutoManagedWorkspace(workspace)
    }

    private func isLikelyAutoManagedWorkspace(_ workspace: Workspace) -> Bool {
        let trimmedName = workspace.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if trimmedName.hasPrefix("wt ") || trimmedName.hasPrefix("wt/") || trimmedName.hasPrefix("wt-") {
            return true
        }

        let normalizedPath = URL(fileURLWithPath: workspace.path).standardizedFileURL.path.lowercased()
        return normalizedPath.contains("/.wt/")
    }

    private func uniqueAutoManagedWorkspaceName(for descriptor: WorktreeDescriptor) -> String {
        let base = descriptor.isDetachedHead ? descriptor.pathLeaf : descriptor.branchName
        let trimmedBase = base.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback = trimmedBase.isEmpty ? descriptor.pathLeaf : trimmedBase
        let seed = "wt " + fallback

        if !workspaces.contains(where: { $0.name == seed }) {
            return seed
        }

        var suffix = 2
        while workspaces.contains(where: { $0.name == "\(seed) \(suffix)" }) {
            suffix += 1
        }
        return "\(seed) \(suffix)"
    }

    private func sluggedBranchName(_ branchName: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let lowered = branchName.lowercased()
        var slug = ""
        for scalar in lowered.unicodeScalars {
            if allowed.contains(scalar) {
                slug.unicodeScalars.append(scalar)
            } else {
                slug.append("-")
            }
        }
        while slug.contains("--") {
            slug = slug.replacingOccurrences(of: "--", with: "-")
        }
        return slug.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }

    private func terminal(with terminalID: UUID) -> Terminal? {
        for workspace in workspaces {
            if let terminal = workspace.terminals.first(where: { $0.id == terminalID }) {
                return terminal
            }
        }
        return nil
    }

    private func normalizedDirectoryPath(_ path: String) -> String? {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let standardizedPath = URL(fileURLWithPath: trimmed).standardizedFileURL.path
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: standardizedPath, isDirectory: &isDirectory)
        guard exists && isDirectory.boolValue else { return nil }
        return standardizedPath
    }

    private func pruneTerminalRuntimePaths() {
        let validTerminalIDs = Set(workspaces.flatMap { $0.terminals.map(\.id) })
        terminalRuntimePaths = terminalRuntimePaths.filter { validTerminalIDs.contains($0.key) }
    }

    func loadGraphState() {
        graphLoadTask?.cancel()
        graphLoadTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let document: GraphStateDocument = await graphStateService.load()
            guard !Task.isCancelled else { return }
            graphDocument = document
            graphViewport = ViewportTransform(from: document.viewport)
            syncGraphFromWorkspaces()
            graphLoadTask = nil
        }
    }

    func saveGraphState() {
        graphDocument.viewport = graphViewport.toViewportState()
        Task {
            await graphStateService.save(graphDocument)
        }
    }

    func syncGraphFromWorkspaces() {
        let existingNodeTerminalIds: Set<UUID> = Set(graphDocument.nodes.compactMap(\.terminalId))
        var updatedNodes: [GraphNode] = graphDocument.nodes
        var updatedEdges: [GraphEdge] = graphDocument.edges

        // Sync names of existing nodes from current workspace/terminal data
        let terminalNameById: [UUID: String] = workspaces.reduce(into: [:]) { result, workspace in
            for terminal in workspace.terminals {
                result[terminal.id] = terminal.name
            }
        }
        for index in updatedNodes.indices {
            if let terminalId = updatedNodes[index].terminalId,
               let currentName = terminalNameById[terminalId],
               updatedNodes[index].name != currentName {
                updatedNodes[index].name = currentName
            }
        }

        for (workspaceIndex, workspace) in workspaces.enumerated() {
            for (terminalIndex, terminal) in workspace.terminals.enumerated() {
                guard !existingNodeTerminalIds.contains(terminal.id) else { continue }

                let xOffset: Double = Double(terminalIndex) * 180.0
                let yOffset: Double = Double(workspaceIndex) * 120.0

                let node: GraphNode = GraphNode(
                    name: terminal.name,
                    nodeType: .terminal,
                    positionX: xOffset,
                    positionY: yOffset,
                    workspaceId: workspace.id,
                    terminalId: terminal.id
                )
                updatedNodes.append(node)
            }
        }

        let allTerminalIds: Set<UUID> = Set(workspaces.flatMap { $0.terminals.map(\.id) })
        updatedNodes.removeAll { node in
            guard let terminalId = node.terminalId else { return false }
            return !allTerminalIds.contains(terminalId)
        }

        let validNodeIds: Set<UUID> = Set(updatedNodes.map(\.id))
        updatedEdges.removeAll { edge in
            !validNodeIds.contains(edge.sourceNodeId) || !validNodeIds.contains(edge.targetNodeId)
        }

        let existingContainmentPairs: Set<String> = Set(
            updatedEdges
                .filter { $0.edgeType == .containment }
                .map { "\($0.sourceNodeId)-\($0.targetNodeId)" }
        )

        for workspace in workspaces {
            let workspaceNodes: [GraphNode] = updatedNodes.filter { $0.workspaceId == workspace.id }
            guard workspaceNodes.count > 1 else { continue }

            for i in 0..<(workspaceNodes.count - 1) {
                let sourceId: UUID = workspaceNodes[i].id
                let targetId: UUID = workspaceNodes[i + 1].id
                let forwardKey: String = "\(sourceId)-\(targetId)"
                let reverseKey: String = "\(targetId)-\(sourceId)"

                guard !existingContainmentPairs.contains(forwardKey),
                      !existingContainmentPairs.contains(reverseKey) else { continue }

                let edge: GraphEdge = GraphEdge(
                    sourceNodeId: sourceId,
                    targetNodeId: targetId,
                    edgeType: .containment
                )
                updatedEdges.append(edge)
            }
        }

        graphDocument.nodes = updatedNodes
        graphDocument.edges = updatedEdges
    }

    func toggleViewMode() {
        graphLoadTask?.cancel()
        graphLoadTask = nil
        switch currentViewMode {
        case .sidebar:
            currentViewMode = .graph
            syncGraphFromWorkspaces()
            startForceLayout()
        case .graph:
            stopForceLayout()
            currentViewMode = .sidebar
        }
    }

    func focusGraphNode(_ nodeId: UUID) {
        stopForceLayout()
        guard let node = graphDocument.nodes.first(where: { $0.id == nodeId }) else { return }
        guard let terminalId = node.terminalId else { return }

        let matchingWorkspace: Workspace? = workspaces.first { workspace in
            workspace.terminals.contains { $0.id == terminalId }
        }

        guard let workspace = matchingWorkspace else { return }
        selectTerminal(id: terminalId, in: workspace.id)
        focusedGraphNodeId = nodeId
        currentViewMode = .sidebar
    }

    func unfocusGraphNode() {
        focusedGraphNodeId = nil
        currentViewMode = .graph
        syncGraphFromWorkspaces()
    }

    func focusSelectedGraphNode() {
        guard let nodeId = selectedGraphNodeId else { return }
        focusGraphNode(nodeId)
    }

    func updateGraphNodePosition(_ nodeId: UUID, to position: CGPoint) {
        guard let index = graphDocument.nodes.firstIndex(where: { $0.id == nodeId }) else { return }
        graphDocument.nodes[index].position = position
    }

    func pinGraphNode(_ nodeId: UUID) {
        guard let index = graphDocument.nodes.firstIndex(where: { $0.id == nodeId }) else { return }
        graphDocument.nodes[index].isPinned = true
    }

    func addGraphEdge(from sourceId: UUID, to targetId: UUID, edgeType: EdgeType) {
        let alreadyExists: Bool = graphDocument.edges.contains { edge in
            (edge.sourceNodeId == sourceId && edge.targetNodeId == targetId)
                || (edge.sourceNodeId == targetId && edge.targetNodeId == sourceId)
        }
        guard !alreadyExists else { return }
        let edge: GraphEdge = GraphEdge(sourceNodeId: sourceId, targetNodeId: targetId, edgeType: edgeType)
        graphDocument.edges.append(edge)
        saveGraphState()
    }

    func removeGraphEdge(_ edgeId: UUID) {
        graphDocument.edges.removeAll { $0.id == edgeId }
        saveGraphState()
    }

    func startForceLayout() {
        stopForceLayout()
        forceLayoutEngine.configure(
            graphNodes: graphDocument.nodes,
            graphEdges: graphDocument.edges
        )

        forceLayoutTask = Task { @MainActor [weak self] in
            guard let self else { return }
            var tickCount: Int = 0
            let maxTicks: Int = 300

            while tickCount < maxTicks && !Task.isCancelled {
                let isActive: Bool = forceLayoutEngine.tick()
                let updatedPositions: [UUID: CGPoint] = forceLayoutEngine.positions()

                for (nodeId, position) in updatedPositions {
                    guard let index = graphDocument.nodes.firstIndex(where: { $0.id == nodeId }) else { continue }
                    graphDocument.nodes[index].position = position
                }

                if !isActive { break }

                tickCount += 1
                try? await Task.sleep(for: .milliseconds(16))
            }

            saveGraphState()
            AppLogger.graph.debug("force layout converged after \(tickCount) ticks")
        }
    }

    func stopForceLayout() {
        forceLayoutTask?.cancel()
        forceLayoutTask = nil
        forceLayoutEngine.invalidate()
    }

    func rerunForceLayout() {
        for i in graphDocument.nodes.indices {
            graphDocument.nodes[i].isPinned = false
        }
        startForceLayout()
    }
}
