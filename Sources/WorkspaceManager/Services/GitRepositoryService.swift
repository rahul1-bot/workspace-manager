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

protocol GitRepositoryServicing: Sendable {
    func status(at workspaceURL: URL) async -> GitRepositoryStatus
    func initializeRepository(at workspaceURL: URL) async throws
    func diff(at workspaceURL: URL, mode: DiffPanelMode) async throws -> GitDiffSnapshot
}

enum GitRepositoryServiceError: Error, Sendable, Equatable {
    case commandFailed(String)
    case noHistory
    case missingBaseBranch
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
        }
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

        let standardOutputPipe = Pipe()
        let standardErrorPipe = Pipe()
        process.standardOutput = standardOutputPipe
        process.standardError = standardErrorPipe

        try process.run()
        process.waitUntilExit()

        let standardOutputData = standardOutputPipe.fileHandleForReading.readDataToEndOfFile()
        let standardErrorData = standardErrorPipe.fileHandleForReading.readDataToEndOfFile()

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
        let candidates = ["origin/main", "main", "origin/master", "master"]
        for candidate in candidates {
            let result = try? runGitAllowFailure(arguments: ["rev-parse", "--verify", candidate], workspaceURL: workspaceURL)
            if result?.exitCode == 0 {
                return candidate
            }
        }
        return nil
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
