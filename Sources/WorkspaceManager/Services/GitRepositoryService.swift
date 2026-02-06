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

protocol GitRepositoryServicing: Sendable {
    func status(at workspaceURL: URL) async -> GitRepositoryStatus
    func initializeRepository(at workspaceURL: URL) async throws
}

enum GitRepositoryServiceError: Error, Sendable, Equatable {
    case commandFailed(String)
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

        if output.exitCode != 0 {
            throw GitRepositoryServiceError.commandFailed(output.standardError)
        }

        return output
    }
}
