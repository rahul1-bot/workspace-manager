import Foundation

struct GitRepositoryStatus: Equatable, Sendable {
    var isRepository: Bool
    var branchName: String
    var disabledReason: GitControlDisabledReason?

    init(isRepository: Bool = false, branchName: String = "-", disabledReason: GitControlDisabledReason? = .unavailableInPhase) {
        self.isRepository = isRepository
        self.branchName = branchName
        self.disabledReason = disabledReason
    }
}

struct GitDiffSnapshot: Equatable, Sendable {
    let summary: GitChangeSummary
    let patchText: String
}

struct GitCommitResult: Equatable, Sendable {
    let branchName: String
    let remoteURL: String?
    let baseBranch: String
}

protocol GitRepositoryServicing: Sendable {
    func status(at workspaceURL: URL) async -> GitRepositoryStatus
    func initializeRepository(at workspaceURL: URL) async throws
    func diff(at workspaceURL: URL, mode: DiffPanelMode) async throws -> GitDiffSnapshot
    func diffWorktreeComparison(request: WorktreeDiffRequest) async throws -> GitDiffSnapshot
    func executeCommit(
        at workspaceURL: URL,
        stagePolicy: CommitStagePolicy,
        message: String,
        nextStep: CommitNextStep
    ) async throws -> GitCommitResult
    func autoCommitMessage(at workspaceURL: URL) async throws -> String
}

enum GitRepositoryServiceError: Error, Sendable, Equatable {
    case commandFailed(String)
    case noHistory
    case missingBaseBranch
    case noChangesToCommit
    case invalidWorktreeBaseline
    case targetWorktreeNotFound
    case crossRepositoryComparisonUnsupported
    case worktreeCommandFailed(String)
}

private struct GitCommandOutput {
    let standardOutput: String
    let standardError: String
    let exitCode: Int32
}

actor GitRepositoryService: GitRepositoryServicing {
    func status(at workspaceURL: URL) async -> GitRepositoryStatus {
        do {
            _ = try runGit(arguments: ["rev-parse", "--is-inside-work-tree"], workspaceURL: workspaceURL)
            let branchName = branchNameOrHead(workspaceURL: workspaceURL)
            return GitRepositoryStatus(
                isRepository: true,
                branchName: branchName.isEmpty ? "HEAD" : branchName,
                disabledReason: nil
            )
        } catch {
            return GitRepositoryStatus(
                isRepository: false,
                branchName: "-",
                disabledReason: .notGitRepository
            )
        }
    }

    func initializeRepository(at workspaceURL: URL) async throws {
        _ = try runGit(arguments: ["init"], workspaceURL: workspaceURL)
    }

    func diff(at workspaceURL: URL, mode: DiffPanelMode) async throws -> GitDiffSnapshot {
        let branchName = branchNameOrHead(workspaceURL: workspaceURL)

        switch mode {
        case .uncommitted:
            let patch = try runGit(arguments: ["diff", "--no-ext-diff", "--minimal"], workspaceURL: workspaceURL)
            let stats = try runGit(arguments: ["diff", "--numstat"], workspaceURL: workspaceURL)
            let summary = parseSummary(fromNumstat: stats.standardOutput, branchName: branchName)
            return GitDiffSnapshot(summary: summary, patchText: patch.standardOutput)

        case .allBranchChanges:
            guard let baseReference = resolveBaseReference(workspaceURL: workspaceURL) else {
                throw GitRepositoryServiceError.missingBaseBranch
            }
            let mergeBase = try runGit(arguments: ["merge-base", "HEAD", baseReference], workspaceURL: workspaceURL)
                .standardOutput
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let patch = try runGit(
                arguments: ["diff", "--no-ext-diff", "--minimal", "\(mergeBase)..HEAD"],
                workspaceURL: workspaceURL
            )
            let stats = try runGit(arguments: ["diff", "--numstat", "\(mergeBase)..HEAD"], workspaceURL: workspaceURL)
            let summary = parseSummary(fromNumstat: stats.standardOutput, branchName: branchName)
            return GitDiffSnapshot(summary: summary, patchText: patch.standardOutput)

        case .lastTurnChanges:
            let hasParent = try runGitAllowFailure(arguments: ["rev-parse", "--verify", "HEAD~1"], workspaceURL: workspaceURL)
            guard hasParent.exitCode == 0 else {
                throw GitRepositoryServiceError.noHistory
            }
            let patch = try runGit(arguments: ["diff", "--no-ext-diff", "--minimal", "HEAD~1..HEAD"], workspaceURL: workspaceURL)
            let stats = try runGit(arguments: ["diff", "--numstat", "HEAD~1..HEAD"], workspaceURL: workspaceURL)
            let summary = parseSummary(fromNumstat: stats.standardOutput, branchName: branchName)
            return GitDiffSnapshot(summary: summary, patchText: patch.standardOutput)
        case .worktreeComparison:
            throw GitRepositoryServiceError.invalidWorktreeBaseline
        }
    }

    func diffWorktreeComparison(request: WorktreeDiffRequest) async throws -> GitDiffSnapshot {
        do {
            let sourceURL = URL(fileURLWithPath: request.sourceWorktreePath)
            let normalizedSource = normalizedPath(sourceURL.path)
            let requestedRootURL = URL(fileURLWithPath: request.repositoryRootPath)
            let expectedCommonDirectory = try gitCommonDirectoryPath(at: requestedRootURL)
            let sourceCommonDirectory = try gitCommonDirectoryPath(at: sourceURL)
            guard sourceCommonDirectory == expectedCommonDirectory else {
                throw GitRepositoryServiceError.crossRepositoryComparisonUnsupported
            }

            let sourceBranchName = request.sourceBranchName
            switch request.baseline {
            case .mergeBaseWithDefault:
                guard let baseReference = resolveBaseReference(workspaceURL: sourceURL) else {
                    throw GitRepositoryServiceError.missingBaseBranch
                }
                let mergeBase = try runGit(arguments: ["merge-base", "HEAD", baseReference], workspaceURL: sourceURL)
                    .standardOutput
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let patch = try runGit(
                    arguments: ["diff", "--no-ext-diff", "--minimal", "\(mergeBase)..HEAD"],
                    workspaceURL: sourceURL
                )
                let stats = try runGit(arguments: ["diff", "--numstat", "\(mergeBase)..HEAD"], workspaceURL: sourceURL)
                let summary = parseSummary(fromNumstat: stats.standardOutput, branchName: sourceBranchName)
                return GitDiffSnapshot(summary: summary, patchText: patch.standardOutput)

            case .siblingWorktree(let targetPath, _):
                let targetURL = URL(fileURLWithPath: targetPath)
                let normalizedTargetPath = normalizedPath(targetURL.path)
                guard normalizedTargetPath != normalizedSource else {
                    throw GitRepositoryServiceError.invalidWorktreeBaseline
                }
                let targetExists = FileManager.default.fileExists(atPath: normalizedTargetPath)
                guard targetExists else {
                    throw GitRepositoryServiceError.targetWorktreeNotFound
                }

                let targetCommonDirectory: String
                do {
                    targetCommonDirectory = try gitCommonDirectoryPath(at: targetURL)
                } catch {
                    throw GitRepositoryServiceError.targetWorktreeNotFound
                }
                guard targetCommonDirectory == expectedCommonDirectory else {
                    throw GitRepositoryServiceError.crossRepositoryComparisonUnsupported
                }

                let sourceHead = try runGit(arguments: ["rev-parse", "HEAD"], workspaceURL: sourceURL)
                    .standardOutput
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let targetHead = try runGit(arguments: ["rev-parse", "HEAD"], workspaceURL: targetURL)
                    .standardOutput
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                let mergeBase = try runGit(arguments: ["merge-base", sourceHead, targetHead], workspaceURL: sourceURL)
                    .standardOutput
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let patch = try runGit(
                    arguments: ["diff", "--no-ext-diff", "--minimal", "\(mergeBase)..\(sourceHead)"],
                    workspaceURL: sourceURL
                )
                let stats = try runGit(
                    arguments: ["diff", "--numstat", "\(mergeBase)..\(sourceHead)"],
                    workspaceURL: sourceURL
                )
                let summary = parseSummary(fromNumstat: stats.standardOutput, branchName: sourceBranchName)
                return GitDiffSnapshot(summary: summary, patchText: patch.standardOutput)
            }
        } catch let error as GitRepositoryServiceError {
            throw error
        } catch {
            throw GitRepositoryServiceError.worktreeCommandFailed(String(describing: error))
        }
    }

    func executeCommit(
        at workspaceURL: URL,
        stagePolicy: CommitStagePolicy,
        message: String,
        nextStep: CommitNextStep
    ) async throws -> GitCommitResult {
        switch stagePolicy {
        case .includeUnstaged:
            _ = try runGit(arguments: ["add", "-A"], workspaceURL: workspaceURL)
        case .stagedOnly:
            break
        }

        let stagedChanges = try runGitAllowFailure(arguments: ["diff", "--cached", "--quiet"], workspaceURL: workspaceURL)
        if stagedChanges.exitCode == 0 {
            throw GitRepositoryServiceError.noChangesToCommit
        }

        _ = try runGit(arguments: ["commit", "-m", message], workspaceURL: workspaceURL)

        let branchName = branchNameOrHead(workspaceURL: workspaceURL)
        let remoteURL = remoteURLForOrigin(workspaceURL: workspaceURL)
        let baseBranch = preferredBaseBranch(workspaceURL: workspaceURL)

        switch nextStep {
        case .commit:
            break
        case .commitAndPush, .commitAndCreatePR:
            _ = try runGit(arguments: ["push"], workspaceURL: workspaceURL)
        }

        return GitCommitResult(
            branchName: branchName,
            remoteURL: remoteURL,
            baseBranch: baseBranch
        )
    }

    func autoCommitMessage(at workspaceURL: URL) async throws -> String {
        let statusOutput = try runGit(arguments: ["status", "--porcelain"], workspaceURL: workspaceURL).standardOutput
        let entries = statusOutput
            .split(separator: "\n")
            .map(String.init)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        let paths = entries.compactMap { entry -> String? in
            guard entry.count >= 4 else { return nil }
            return String(entry.dropFirst(3))
        }
        let uniquePaths = Array(Set(paths))
        let scopeNames = uniquePaths
            .map { path in
                let first = path.split(separator: "/").first.map(String.init) ?? path
                return first
            }
            .sorted()
        let displayedScopes = Array(scopeNames.prefix(2))
        let scopeText = displayedScopes.isEmpty ? "workspace" : displayedScopes.joined(separator: ", ")

        let prefix: String
        if uniquePaths.allSatisfy({ $0.hasPrefix("docs/") || $0.hasSuffix(".md") }) {
            prefix = "docs"
        } else if uniquePaths.allSatisfy({ $0.contains("Test") || $0.contains("Tests/") }) {
            prefix = "test"
        } else {
            prefix = "chore"
        }

        return "\(prefix): update \(uniquePaths.count) files in \(scopeText)"
    }

    private func branchNameOrHead(workspaceURL: URL) -> String {
        if let branch = try? runGit(arguments: ["symbolic-ref", "--short", "HEAD"], workspaceURL: workspaceURL)
            .standardOutput
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !branch.isEmpty {
            return branch
        }

        if let branch = try? runGit(arguments: ["rev-parse", "--abbrev-ref", "HEAD"], workspaceURL: workspaceURL)
            .standardOutput
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !branch.isEmpty {
            return branch
        }

        return "HEAD"
    }

    private func runGit(arguments: [String], workspaceURL: URL) throws -> GitCommandOutput {
        let output = try runGitAllowFailure(arguments: arguments, workspaceURL: workspaceURL)
        if output.exitCode != 0 {
            throw GitRepositoryServiceError.commandFailed(output.standardError)
        }
        return output
    }

    private func runGitAllowFailure(arguments: [String], workspaceURL: URL) throws -> GitCommandOutput {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["git", "-C", workspaceURL.path] + arguments

        let temporaryDirectory = FileManager.default.temporaryDirectory
        let standardOutputURL = temporaryDirectory.appendingPathComponent("wm_git_stdout_\(UUID().uuidString)")
        let standardErrorURL = temporaryDirectory.appendingPathComponent("wm_git_stderr_\(UUID().uuidString)")
        FileManager.default.createFile(atPath: standardOutputURL.path, contents: nil)
        FileManager.default.createFile(atPath: standardErrorURL.path, contents: nil)

        let standardOutputHandle = try FileHandle(forWritingTo: standardOutputURL)
        let standardErrorHandle = try FileHandle(forWritingTo: standardErrorURL)
        defer {
            try? standardOutputHandle.close()
            try? standardErrorHandle.close()
            try? FileManager.default.removeItem(at: standardOutputURL)
            try? FileManager.default.removeItem(at: standardErrorURL)
        }

        process.standardOutput = standardOutputHandle
        process.standardError = standardErrorHandle

        try process.run()
        process.waitUntilExit()
        let standardOutputData = (try? Data(contentsOf: standardOutputURL)) ?? Data()
        let standardErrorData = (try? Data(contentsOf: standardErrorURL)) ?? Data()

        let standardOutput = String(data: standardOutputData, encoding: .utf8) ?? ""
        let standardError = String(data: standardErrorData, encoding: .utf8) ?? ""

        let output = GitCommandOutput(
            standardOutput: standardOutput,
            standardError: standardError,
            exitCode: process.terminationStatus
        )
        return output
    }

    private func resolveBaseReference(workspaceURL: URL) -> String? {
        if let upstream = resolveUpstreamReference(workspaceURL: workspaceURL) {
            return upstream
        }
        if let originHead = resolveOriginHeadReference(workspaceURL: workspaceURL) {
            return originHead
        }

        let candidates = ["origin/main", "main", "origin/master", "master"]
        for candidate in candidates {
            let result = try? runGitAllowFailure(arguments: ["rev-parse", "--verify", candidate], workspaceURL: workspaceURL)
            if result?.exitCode == 0 {
                return candidate
            }
        }
        return nil
    }

    private func preferredBaseBranch(workspaceURL: URL) -> String {
        if let ref = resolveBaseReference(workspaceURL: workspaceURL) {
            return normalizedBranchName(from: ref, workspaceURL: workspaceURL)
        }
        return "main"
    }

    private func resolveUpstreamReference(workspaceURL: URL) -> String? {
        let output = try? runGitAllowFailure(
            arguments: ["rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{upstream}"],
            workspaceURL: workspaceURL
        )
        guard let output, output.exitCode == 0 else { return nil }
        let ref = output.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !ref.isEmpty else { return nil }
        let verified = try? runGitAllowFailure(arguments: ["rev-parse", "--verify", ref], workspaceURL: workspaceURL)
        guard verified?.exitCode == 0 else { return nil }
        return ref
    }

    private func resolveOriginHeadReference(workspaceURL: URL) -> String? {
        let output = try? runGitAllowFailure(
            arguments: ["symbolic-ref", "--quiet", "--short", "refs/remotes/origin/HEAD"],
            workspaceURL: workspaceURL
        )
        guard let output, output.exitCode == 0 else { return nil }
        let ref = output.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !ref.isEmpty else { return nil }
        let verified = try? runGitAllowFailure(arguments: ["rev-parse", "--verify", ref], workspaceURL: workspaceURL)
        guard verified?.exitCode == 0 else { return nil }
        return ref
    }

    private func normalizedBranchName(from reference: String, workspaceURL: URL) -> String {
        let ref = reference.trimmingCharacters(in: .whitespacesAndNewlines)
        if ref.hasPrefix("refs/remotes/") {
            let suffix = String(ref.dropFirst("refs/remotes/".count))
            if let slashIndex = suffix.firstIndex(of: "/") {
                return String(suffix[suffix.index(after: slashIndex)...])
            }
            return suffix
        }

        let verifyRemote = try? runGitAllowFailure(
            arguments: ["show-ref", "--verify", "--quiet", "refs/remotes/\(ref)"],
            workspaceURL: workspaceURL
        )
        if verifyRemote?.exitCode == 0, let slashIndex = ref.firstIndex(of: "/") {
            return String(ref[ref.index(after: slashIndex)...])
        }
        return ref
    }

    private func remoteURLForOrigin(workspaceURL: URL) -> String? {
        if let output = try? runGit(arguments: ["remote", "get-url", "origin"], workspaceURL: workspaceURL).standardOutput {
            let value = output.trimmingCharacters(in: .whitespacesAndNewlines)
            return value.isEmpty ? nil : value
        }
        return nil
    }

    private func repositoryRootPath(at workspaceURL: URL) throws -> String {
        let output = try runGit(arguments: ["rev-parse", "--show-toplevel"], workspaceURL: workspaceURL)
        let root = output.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !root.isEmpty else {
            throw GitRepositoryServiceError.commandFailed("Unable to resolve repository root path.")
        }
        return normalizedPath(root)
    }

    private func normalizedPath(_ path: String) -> String {
        URL(fileURLWithPath: path).resolvingSymlinksInPath().standardizedFileURL.path
    }

    private func gitCommonDirectoryPath(at workspaceURL: URL) throws -> String {
        let output = try runGit(arguments: ["rev-parse", "--git-common-dir"], workspaceURL: workspaceURL)
        let rawPath = output.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawPath.isEmpty else {
            throw GitRepositoryServiceError.commandFailed("Unable to resolve git common directory.")
        }

        if rawPath.hasPrefix("/") {
            return normalizedPath(rawPath)
        }

        let resolved = workspaceURL.appendingPathComponent(rawPath).path
        return normalizedPath(resolved)
    }

    private func parseSummary(fromNumstat output: String, branchName: String) -> GitChangeSummary {
        let lines = output
            .split(separator: "\n")
            .map(String.init)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        var additions = 0
        var deletions = 0

        for line in lines {
            let parts = line.split(separator: "\t", omittingEmptySubsequences: false)
            guard parts.count >= 3 else { continue }
            if let add = Int(parts[0]) {
                additions += add
            }
            if let del = Int(parts[1]) {
                deletions += del
            }
        }

        return GitChangeSummary(
            branchName: branchName,
            filesChanged: lines.count,
            additions: additions,
            deletions: deletions
        )
    }
}
