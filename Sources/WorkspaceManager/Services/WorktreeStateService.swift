import Foundation

actor WorktreeStateService {
    private let stateFileURL: URL

    init(baseDirectoryURL: URL? = nil) {
        if let baseDirectoryURL {
            self.stateFileURL = baseDirectoryURL.appendingPathComponent("worktree-state.json")
        } else {
            let configDirectory = ConfigService.shared.configFileURL.deletingLastPathComponent()
            self.stateFileURL = configDirectory.appendingPathComponent("worktree-state.json")
        }
    }

    func load() -> WorktreeStateDocument {
        guard FileManager.default.fileExists(atPath: stateFileURL.path) else {
            return WorktreeStateDocument()
        }

        do {
            let data = try Data(contentsOf: stateFileURL)
            return try JSONDecoder().decode(WorktreeStateDocument.self, from: data)
        } catch {
            AppLogger.worktree.error("failed to load worktree-state.json: \(String(describing: error), privacy: .public)")
            return WorktreeStateDocument()
        }
    }

    func save(_ document: WorktreeStateDocument) {
        do {
            try FileManager.default.createDirectory(
                at: stateFileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(document)
            try data.write(to: stateFileURL, options: .atomic)
        } catch {
            AppLogger.worktree.error("failed to save worktree-state.json: \(String(describing: error), privacy: .public)")
        }
    }

    func upsertPurpose(workspaceID: UUID, purpose: String) {
        var document = load()
        let workspaceKey = workspaceID.uuidString
        guard var link = document.linksByWorkspaceID[workspaceKey] else {
            return
        }

        link.purpose = WorktreePurposeRecord(purpose: purpose, updatedAt: Date())
        link.updatedAt = Date()
        document.upsertLink(link)
        save(document)
    }

    func linkWorkspace(workspaceID: UUID, worktreePath: String, repoRootPath: String, isAutoManaged: Bool) {
        var document = load()
        let normalizedPath = URL(fileURLWithPath: worktreePath).standardizedFileURL.path
        let workspaceKey = workspaceID.uuidString

        var link = document.linksByWorkspaceID[workspaceKey] ?? WorktreeWorkspaceLink(
            workspaceID: workspaceKey,
            worktreePath: normalizedPath,
            repositoryRootPath: repoRootPath,
            purpose: nil,
            isAutoManaged: isAutoManaged,
            isStale: false,
            updatedAt: Date()
        )
        link.worktreePath = normalizedPath
        link.repositoryRootPath = repoRootPath
        link.isAutoManaged = isAutoManaged
        link.isStale = false
        link.updatedAt = Date()

        document.upsertLink(link)
        save(document)
    }

    func setStaleWorktreePaths(_ staleWorktreePaths: [String]) {
        var document = load()
        let staleSet = Set(staleWorktreePaths.map { URL(fileURLWithPath: $0).standardizedFileURL.path })
        var newByWorkspaceID: [String: WorktreeWorkspaceLink] = [:]
        var newByWorktreePath: [String: WorktreeWorkspaceLink] = [:]

        for (_, var link) in document.linksByWorkspaceID {
            link.isStale = staleSet.contains(link.worktreePath)
            link.updatedAt = Date()
            newByWorkspaceID[link.workspaceID] = link
            newByWorktreePath[link.worktreePath] = link
        }

        document.linksByWorkspaceID = newByWorkspaceID
        document.linksByWorktreePath = newByWorktreePath
        save(document)
    }
}

