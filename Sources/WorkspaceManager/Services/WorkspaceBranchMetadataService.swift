import Foundation

private struct BranchCommandOutput {
    let standardOutput: String
    let standardError: String
    let exitCode: Int32
}

private enum WorkspaceBranchMetadataServiceError: Error {
    case commandTimedOut(String)
}

actor WorkspaceBranchMetadataService {
    private let commandTimeoutSeconds: TimeInterval = 4

    func metadata(for path: String) async -> WorkspaceBranchMetadata? {
        let workspaceURL = URL(fileURLWithPath: path).standardizedFileURL
        guard FileManager.default.fileExists(atPath: workspaceURL.path) else {
            return nil
        }

        let repositoryCheck = try? runGitAllowFailure(
            arguments: ["rev-parse", "--is-inside-work-tree"],
            workingPath: workspaceURL.path
        )
        guard repositoryCheck?.exitCode == 0 else {
            return nil
        }

        let symbolicRef = try? runGitAllowFailure(
            arguments: ["symbolic-ref", "--short", "HEAD"],
            workingPath: workspaceURL.path
        )
        let detachedFallback = try? runGitAllowFailure(
            arguments: ["rev-parse", "--short", "HEAD"],
            workingPath: workspaceURL.path
        )
        let dirtyOutput = try? runGitAllowFailure(
            arguments: ["status", "--porcelain", "--untracked-files=no"],
            workingPath: workspaceURL.path
        )

        let branchName: String
        if let symbolicRef, symbolicRef.exitCode == 0 {
            let value = symbolicRef.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines)
            if !value.isEmpty {
                branchName = value
            } else {
                branchName = "HEAD"
            }
        } else if let detachedFallback, detachedFallback.exitCode == 0 {
            let value = detachedFallback.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines)
            branchName = value.isEmpty ? "HEAD" : "detached@\(value)"
        } else {
            branchName = "HEAD"
        }

        let isDirty: Bool
        if let dirtyOutput, dirtyOutput.exitCode == 0 {
            isDirty = !dirtyOutput.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        } else {
            isDirty = false
        }

        return WorkspaceBranchMetadata(branchName: branchName, isDirty: isDirty)
    }

    private func runGitAllowFailure(arguments: [String], workingPath: String) throws -> BranchCommandOutput {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["git", "-C", workingPath] + arguments
        let commandDescription = (["git", "-C", workingPath] + arguments).joined(separator: " ")

        let temporaryDirectory = FileManager.default.temporaryDirectory
        let standardOutputURL = temporaryDirectory.appendingPathComponent("wm_branch_stdout_\(UUID().uuidString)")
        let standardErrorURL = temporaryDirectory.appendingPathComponent("wm_branch_stderr_\(UUID().uuidString)")
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

        let terminationSemaphore = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in
            terminationSemaphore.signal()
        }

        try process.run()
        let waitResult = terminationSemaphore.wait(timeout: .now() + commandTimeoutSeconds)
        if waitResult == .timedOut {
            process.terminate()
            _ = terminationSemaphore.wait(timeout: .now() + 1)
            throw WorkspaceBranchMetadataServiceError.commandTimedOut(commandDescription)
        }

        let standardOutputData = (try? Data(contentsOf: standardOutputURL)) ?? Data()
        let standardErrorData = (try? Data(contentsOf: standardErrorURL)) ?? Data()

        return BranchCommandOutput(
            standardOutput: String(data: standardOutputData, encoding: .utf8) ?? "",
            standardError: String(data: standardErrorData, encoding: .utf8) ?? "",
            exitCode: process.terminationStatus
        )
    }
}
