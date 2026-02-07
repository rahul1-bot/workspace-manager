import Foundation

protocol WorktreeServicing: Sendable {
    func catalog(for path: URL) async throws -> WorktreeCatalog
    func createWorktree(_ request: WorktreeCreateRequest) async throws -> WorktreeDescriptor
    func workspaceSyncPlan(catalog: WorktreeCatalog, existingWorkspaces: [Workspace]) -> WorktreeWorkspaceSyncPlan
}

enum WorktreeServiceError: Error, LocalizedError, Sendable {
    case notGitRepository(String)
    case invalidRequest(String)
    case commandFailed(String)
    case parseFailed(String)
    case descriptorNotFound(String)

    var errorDescription: String? {
        switch self {
        case .notGitRepository(let path):
            return "Path is not inside a git repository: \(path)"
        case .invalidRequest(let message):
            return message
        case .commandFailed(let message):
            return message
        case .parseFailed(let message):
            return message
        case .descriptorNotFound(let path):
            return "Created worktree was not discovered at path: \(path)"
        }
    }
}

private struct WorktreeCommandOutput {
    let standardOutput: String
    let standardError: String
    let exitCode: Int32
}

private struct WorktreePorcelainRecord {
    var worktreePath: String = ""
    var head: String = ""
    var branchReference: String?
    var isDetached: Bool = false
}

actor WorktreeService: WorktreeServicing {
    func catalog(for path: URL) async throws -> WorktreeCatalog {
        let normalizedInputPath = path.standardizedFileURL.path
        let repositoryRootPath = try repositoryRootPath(for: normalizedInputPath)
        let porcelain = try runGit(
            arguments: ["worktree", "list", "--porcelain"],
            workingPath: repositoryRootPath
        )
        let records = try parsePorcelainRecords(porcelain.standardOutput)
        guard let currentWorktreePath = resolveCurrentWorktreePath(
            for: normalizedInputPath,
            from: records
        ) else {
            throw WorktreeServiceError.parseFailed("Unable to match input path to a discovered worktree.")
        }
        let descriptors = try records.map { record in
            try descriptor(from: record, repositoryRootPath: repositoryRootPath, currentWorktreePath: currentWorktreePath)
        }
        let sortedDescriptors = descriptors.sorted { lhs, rhs in
            if lhs.isCurrent != rhs.isCurrent {
                return lhs.isCurrent
            }
            return lhs.branchName.localizedCaseInsensitiveCompare(rhs.branchName) == .orderedAscending
        }
        return WorktreeCatalog(
            repositoryRootPath: repositoryRootPath,
            currentWorktreePath: currentWorktreePath,
            descriptors: sortedDescriptors
        )
    }

    func createWorktree(_ request: WorktreeCreateRequest) async throws -> WorktreeDescriptor {
        let branchName = request.branchName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !branchName.isEmpty else {
            throw WorktreeServiceError.invalidRequest("Branch name cannot be empty.")
        }
        let baseReference = request.baseReference.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !baseReference.isEmpty else {
            throw WorktreeServiceError.invalidRequest("Base reference cannot be empty.")
        }

        let repositoryRoot = URL(fileURLWithPath: request.repositoryRootPath).standardizedFileURL.path
        _ = try repositoryRootPath(for: repositoryRoot)

        let destinationPath = URL(fileURLWithPath: request.destinationPath).standardizedFileURL.path
        let destinationParent = URL(fileURLWithPath: destinationPath).deletingLastPathComponent()
        try FileManager.default.createDirectory(at: destinationParent, withIntermediateDirectories: true)
        let branchExistsOutput = try runGitAllowFailure(
            arguments: ["show-ref", "--verify", "--quiet", "refs/heads/\(branchName)"],
            workingPath: repositoryRoot
        )

        if branchExistsOutput.exitCode == 0 {
            _ = try runGit(
                arguments: ["worktree", "add", destinationPath, branchName],
                workingPath: repositoryRoot
            )
        } else {
            _ = try runGit(
                arguments: ["worktree", "add", "-b", branchName, destinationPath, baseReference],
                workingPath: repositoryRoot
            )
        }

        let catalogDocument = try await catalog(for: URL(fileURLWithPath: destinationPath))
        if let descriptor = catalogDocument.descriptors.first(where: {
            URL(fileURLWithPath: $0.worktreePath).standardizedFileURL.path == destinationPath
        }) {
            return descriptor
        }

        throw WorktreeServiceError.descriptorNotFound(destinationPath)
    }

    nonisolated func workspaceSyncPlan(catalog: WorktreeCatalog, existingWorkspaces: [Workspace]) -> WorktreeWorkspaceSyncPlan {
        let workspaceByPath = existingWorkspaces.reduce(into: [String: UUID]()) { result, workspace in
            let normalizedPath = URL(fileURLWithPath: workspace.path).standardizedFileURL.path
            result[normalizedPath] = workspace.id
        }

        var additions: [WorktreeDescriptor] = []
        var updates: [WorktreeWorkspaceUpdate] = []
        for descriptor in catalog.descriptors {
            if let workspaceID = workspaceByPath[descriptor.worktreePath] {
                updates.append(WorktreeWorkspaceUpdate(workspaceID: workspaceID, descriptor: descriptor))
            } else {
                additions.append(descriptor)
            }
        }

        return WorktreeWorkspaceSyncPlan(additions: additions, updates: updates)
    }

    private func descriptor(
        from record: WorktreePorcelainRecord,
        repositoryRootPath: String,
        currentWorktreePath: String
    ) throws -> WorktreeDescriptor {
        guard !record.worktreePath.isEmpty else {
            throw WorktreeServiceError.parseFailed("Missing worktree path in porcelain output.")
        }

        let normalizedWorktreePath = URL(fileURLWithPath: record.worktreePath).standardizedFileURL.path
        let worktreeURL = URL(fileURLWithPath: normalizedWorktreePath)
        let isCurrent = normalizedWorktreePath == currentWorktreePath
        let headShortSHA = try resolveHeadShortSHA(at: normalizedWorktreePath, fallback: record.head)
        let branchName = resolveBranchName(record: record, headShortSHA: headShortSHA)
        let isDirty = try resolveDirtyState(at: normalizedWorktreePath)
        let divergence = try resolveAheadBehindCounts(at: normalizedWorktreePath)

        return WorktreeDescriptor(
            repositoryRootPath: repositoryRootPath,
            worktreePath: worktreeURL.path,
            branchName: branchName,
            headShortSHA: headShortSHA,
            isDetachedHead: record.isDetached,
            isCurrent: isCurrent,
            isDirty: isDirty,
            aheadCount: divergence.ahead,
            behindCount: divergence.behind
        )
    }

    private func repositoryRootPath(for path: String) throws -> String {
        let normalizedPath = URL(fileURLWithPath: path).standardizedFileURL.path
        let output = try runGitAllowFailure(
            arguments: ["rev-parse", "--show-toplevel"],
            workingPath: normalizedPath
        )
        guard output.exitCode == 0 else {
            throw WorktreeServiceError.notGitRepository(normalizedPath)
        }
        let repositoryPath = output.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !repositoryPath.isEmpty else {
            throw WorktreeServiceError.notGitRepository(normalizedPath)
        }
        return URL(fileURLWithPath: repositoryPath).standardizedFileURL.path
    }

    private func resolveCurrentWorktreePath(
        for inputPath: String,
        from records: [WorktreePorcelainRecord]
    ) -> String? {
        let normalizedInputPath = URL(fileURLWithPath: inputPath).standardizedFileURL.path

        let matches = records.compactMap { record -> String? in
            let normalizedPath = URL(fileURLWithPath: record.worktreePath).standardizedFileURL.path
            guard normalizedInputPath == normalizedPath || normalizedInputPath.hasPrefix(normalizedPath + "/") else {
                return nil
            }
            return normalizedPath
        }

        return matches.max(by: { lhs, rhs in lhs.count < rhs.count })
    }

    private func parsePorcelainRecords(_ output: String) throws -> [WorktreePorcelainRecord] {
        var records: [WorktreePorcelainRecord] = []
        var current = WorktreePorcelainRecord()

        func flushCurrentRecord() {
            guard !current.worktreePath.isEmpty else { return }
            records.append(current)
            current = WorktreePorcelainRecord()
        }

        for rawLine in output.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine)
            if line.isEmpty {
                flushCurrentRecord()
                continue
            }

            if line.hasPrefix("worktree ") {
                flushCurrentRecord()
                current.worktreePath = String(line.dropFirst("worktree ".count))
                continue
            }

            if line.hasPrefix("HEAD ") {
                current.head = String(line.dropFirst("HEAD ".count))
                continue
            }

            if line.hasPrefix("branch ") {
                current.branchReference = String(line.dropFirst("branch ".count))
                continue
            }

            if line == "detached" {
                current.isDetached = true
            }
        }

        flushCurrentRecord()

        if records.isEmpty {
            throw WorktreeServiceError.parseFailed("No worktree records found in git worktree porcelain output.")
        }

        return records
    }

    private func resolveBranchName(record: WorktreePorcelainRecord, headShortSHA: String) -> String {
        if let reference = record.branchReference?.trimmingCharacters(in: .whitespacesAndNewlines),
           !reference.isEmpty {
            if reference.hasPrefix("refs/heads/") {
                return String(reference.dropFirst("refs/heads/".count))
            }
            return reference
        }

        if record.isDetached {
            return "detached@\(headShortSHA)"
        }

        return headShortSHA
    }

    private func resolveHeadShortSHA(at workingPath: String, fallback head: String) throws -> String {
        let output = try runGitAllowFailure(
            arguments: ["rev-parse", "--short", "HEAD"],
            workingPath: workingPath
        )
        if output.exitCode == 0 {
            let value = output.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines)
            if !value.isEmpty {
                return value
            }
        }

        if !head.isEmpty {
            return String(head.prefix(8))
        }

        throw WorktreeServiceError.parseFailed("Unable to resolve worktree HEAD SHA for path: \(workingPath)")
    }

    private func resolveDirtyState(at workingPath: String) throws -> Bool {
        let output = try runGitAllowFailure(
            arguments: ["status", "--porcelain"],
            workingPath: workingPath
        )
        guard output.exitCode == 0 else {
            throw WorktreeServiceError.commandFailed(output.standardError)
        }
        return !output.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func resolveAheadBehindCounts(at workingPath: String) throws -> (ahead: Int, behind: Int) {
        let upstreamOutput = try runGitAllowFailure(
            arguments: ["rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{upstream}"],
            workingPath: workingPath
        )
        guard upstreamOutput.exitCode == 0 else {
            return (0, 0)
        }

        let upstreamReference = upstreamOutput.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !upstreamReference.isEmpty else {
            return (0, 0)
        }

        let divergenceOutput = try runGitAllowFailure(
            arguments: ["rev-list", "--left-right", "--count", "\(upstreamReference)...HEAD"],
            workingPath: workingPath
        )
        guard divergenceOutput.exitCode == 0 else {
            return (0, 0)
        }

        let values = divergenceOutput.standardOutput
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: { $0 == "\t" || $0 == " " })
            .compactMap { Int($0) }
        guard values.count == 2 else {
            return (0, 0)
        }

        let behind = values[0]
        let ahead = values[1]
        return (ahead, behind)
    }

    private func runGit(arguments: [String], workingPath: String) throws -> WorktreeCommandOutput {
        let output = try runGitAllowFailure(arguments: arguments, workingPath: workingPath)
        guard output.exitCode == 0 else {
            throw WorktreeServiceError.commandFailed(output.standardError.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return output
    }

    private func runGitAllowFailure(arguments: [String], workingPath: String) throws -> WorktreeCommandOutput {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["git", "-C", workingPath] + arguments

        let standardOutputPipe = Pipe()
        let standardErrorPipe = Pipe()
        process.standardOutput = standardOutputPipe
        process.standardError = standardErrorPipe

        try process.run()
        process.waitUntilExit()

        let standardOutputData = standardOutputPipe.fileHandleForReading.readDataToEndOfFile()
        let standardErrorData = standardErrorPipe.fileHandleForReading.readDataToEndOfFile()

        return WorktreeCommandOutput(
            standardOutput: String(data: standardOutputData, encoding: .utf8) ?? "",
            standardError: String(data: standardErrorData, encoding: .utf8) ?? "",
            exitCode: process.terminationStatus
        )
    }
}
