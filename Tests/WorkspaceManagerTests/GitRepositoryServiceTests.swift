import XCTest
@testable import WorkspaceManager

final class GitRepositoryServiceTests: XCTestCase {
    func testStatusReturnsNotRepositoryForPlainDirectory() async throws {
        let service = GitRepositoryService()
        let temporaryURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: temporaryURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryURL) }

        let status = await service.status(at: temporaryURL)
        XCTAssertFalse(status.isRepository)
        XCTAssertEqual(status.disabledReason, .notGitRepository)
    }

    func testInitializeRepositoryCreatesGitRepository() async throws {
        let service = GitRepositoryService()
        let temporaryURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: temporaryURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryURL) }

        try await service.initializeRepository(at: temporaryURL)
        let status = await service.status(at: temporaryURL)

        XCTAssertTrue(status.isRepository)
        XCTAssertNil(status.disabledReason)
    }

    func testDiffUncommittedReturnsPatchAndStats() async throws {
        let service = GitRepositoryService()
        let temporaryURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: temporaryURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryURL) }

        try await service.initializeRepository(at: temporaryURL)
        try runGit(arguments: ["config", "user.email", "test@example.com"], workspaceURL: temporaryURL)
        try runGit(arguments: ["config", "user.name", "Tester"], workspaceURL: temporaryURL)
        let fileURL = temporaryURL.appendingPathComponent("sample.txt")
        try "line-1\n".write(to: fileURL, atomically: true, encoding: .utf8)
        try runGit(arguments: ["add", "."], workspaceURL: temporaryURL)
        try runGit(arguments: ["commit", "-m", "init"], workspaceURL: temporaryURL)
        try "line-1\nline-2\n".write(to: fileURL, atomically: true, encoding: .utf8)

        let snapshot = try await service.diff(at: temporaryURL, mode: .uncommitted)
        XCTAssertGreaterThan(snapshot.summary.filesChanged, 0)
        XCTAssertTrue(snapshot.patchText.contains("diff --git"))
    }

    func testDiffLastTurnThrowsNoHistoryWithoutParentCommit() async throws {
        let service = GitRepositoryService()
        let temporaryURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: temporaryURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryURL) }

        try await service.initializeRepository(at: temporaryURL)
        let fileURL = temporaryURL.appendingPathComponent("sample.txt")
        try "line-1\n".write(to: fileURL, atomically: true, encoding: .utf8)

        do {
            _ = try await service.diff(at: temporaryURL, mode: .lastTurnChanges)
            XCTFail("Expected noHistory error")
        } catch let error as GitRepositoryServiceError {
            XCTAssertEqual(error, .noHistory)
        }
    }

    func testDiffAllBranchChangesFallsBackToMain() async throws {
        let service = GitRepositoryService()
        let temporaryURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: temporaryURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryURL) }

        try await service.initializeRepository(at: temporaryURL)
        try runGit(arguments: ["config", "user.email", "test@example.com"], workspaceURL: temporaryURL)
        try runGit(arguments: ["config", "user.name", "Tester"], workspaceURL: temporaryURL)
        try runGit(arguments: ["branch", "-M", "main"], workspaceURL: temporaryURL)

        let fileURL = temporaryURL.appendingPathComponent("sample.txt")
        try "line-1\n".write(to: fileURL, atomically: true, encoding: .utf8)
        try runGit(arguments: ["add", "."], workspaceURL: temporaryURL)
        try runGit(arguments: ["commit", "-m", "init"], workspaceURL: temporaryURL)
        try runGit(arguments: ["checkout", "-b", "feature/diff"], workspaceURL: temporaryURL)
        try "line-1\nline-2\n".write(to: fileURL, atomically: true, encoding: .utf8)
        try runGit(arguments: ["add", "."], workspaceURL: temporaryURL)
        try runGit(arguments: ["commit", "-m", "feature"], workspaceURL: temporaryURL)

        let snapshot = try await service.diff(at: temporaryURL, mode: .allBranchChanges)
        XCTAssertGreaterThan(snapshot.summary.filesChanged, 0)
    }

    func testAutoCommitMessageUsesDocsPrefixForMarkdownOnly() async throws {
        let service = GitRepositoryService()
        let temporaryURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: temporaryURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryURL) }

        try await service.initializeRepository(at: temporaryURL)
        let docsURL = temporaryURL.appendingPathComponent("docs")
        try FileManager.default.createDirectory(at: docsURL, withIntermediateDirectories: true)
        let fileURL = docsURL.appendingPathComponent("notes.md")
        try "hello\n".write(to: fileURL, atomically: true, encoding: .utf8)

        let message = try await service.autoCommitMessage(at: temporaryURL)
        XCTAssertTrue(message.hasPrefix("docs:"))
    }

    func testExecuteCommitOnlyCreatesCommit() async throws {
        let service = GitRepositoryService()
        let temporaryURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: temporaryURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryURL) }

        try await service.initializeRepository(at: temporaryURL)
        try runGit(arguments: ["config", "user.email", "test@example.com"], workspaceURL: temporaryURL)
        try runGit(arguments: ["config", "user.name", "Tester"], workspaceURL: temporaryURL)
        let fileURL = temporaryURL.appendingPathComponent("sample.txt")
        try "first\n".write(to: fileURL, atomically: true, encoding: .utf8)

        _ = try await service.executeCommit(
            at: temporaryURL,
            stagePolicy: .includeUnstaged,
            message: "feat: initial",
            nextStep: .commit
        )

        let logOutput = try runGitOutput(arguments: ["log", "--oneline"], workspaceURL: temporaryURL)
        XCTAssertTrue(logOutput.contains("feat: initial"))
    }

    func testExecuteCommitWithoutChangesThrows() async throws {
        let service = GitRepositoryService()
        let temporaryURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: temporaryURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryURL) }

        try await service.initializeRepository(at: temporaryURL)
        try runGit(arguments: ["config", "user.email", "test@example.com"], workspaceURL: temporaryURL)
        try runGit(arguments: ["config", "user.name", "Tester"], workspaceURL: temporaryURL)

        do {
            _ = try await service.executeCommit(
                at: temporaryURL,
                stagePolicy: .includeUnstaged,
                message: "chore: no changes",
                nextStep: .commit
            )
            XCTFail("Expected noChangesToCommit")
        } catch let error as GitRepositoryServiceError {
            XCTAssertEqual(error, .noChangesToCommit)
        }
    }

    func testExecuteCommitUsesUpstreamBaseWhenMainMasterMissing() async throws {
        let service = GitRepositoryService()
        let temporaryURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let remoteURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).git")
        try FileManager.default.createDirectory(at: temporaryURL, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: temporaryURL)
            try? FileManager.default.removeItem(at: remoteURL)
        }

        try runGit(arguments: ["init", "--bare", remoteURL.path], workspaceURL: temporaryURL)
        try await service.initializeRepository(at: temporaryURL)
        try runGit(arguments: ["config", "user.email", "test@example.com"], workspaceURL: temporaryURL)
        try runGit(arguments: ["config", "user.name", "Tester"], workspaceURL: temporaryURL)
        try runGit(arguments: ["branch", "-M", "trunk"], workspaceURL: temporaryURL)

        let fileURL = temporaryURL.appendingPathComponent("sample.txt")
        try "line-1\n".write(to: fileURL, atomically: true, encoding: .utf8)
        try runGit(arguments: ["add", "."], workspaceURL: temporaryURL)
        try runGit(arguments: ["commit", "-m", "init"], workspaceURL: temporaryURL)
        try runGit(arguments: ["remote", "add", "origin", remoteURL.path], workspaceURL: temporaryURL)
        try runGit(arguments: ["push", "-u", "origin", "trunk"], workspaceURL: temporaryURL)

        try runGit(arguments: ["checkout", "-b", "feature/upstream"], workspaceURL: temporaryURL)
        try runGit(arguments: ["branch", "--set-upstream-to=origin/trunk"], workspaceURL: temporaryURL)
        try "line-1\nline-2\n".write(to: fileURL, atomically: true, encoding: .utf8)

        let result = try await service.executeCommit(
            at: temporaryURL,
            stagePolicy: .includeUnstaged,
            message: "feat: upstream base",
            nextStep: .commit
        )
        XCTAssertEqual(result.baseBranch, "trunk")
    }

    func testExecuteCommitUsesOriginHeadFallbackWhenUpstreamMissing() async throws {
        let service = GitRepositoryService()
        let temporaryURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let remoteURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).git")
        try FileManager.default.createDirectory(at: temporaryURL, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: temporaryURL)
            try? FileManager.default.removeItem(at: remoteURL)
        }

        try runGit(arguments: ["init", "--bare", remoteURL.path], workspaceURL: temporaryURL)
        try await service.initializeRepository(at: temporaryURL)
        try runGit(arguments: ["config", "user.email", "test@example.com"], workspaceURL: temporaryURL)
        try runGit(arguments: ["config", "user.name", "Tester"], workspaceURL: temporaryURL)
        try runGit(arguments: ["branch", "-M", "trunk"], workspaceURL: temporaryURL)

        let fileURL = temporaryURL.appendingPathComponent("sample.txt")
        try "line-1\n".write(to: fileURL, atomically: true, encoding: .utf8)
        try runGit(arguments: ["add", "."], workspaceURL: temporaryURL)
        try runGit(arguments: ["commit", "-m", "init"], workspaceURL: temporaryURL)
        try runGit(arguments: ["remote", "add", "origin", remoteURL.path], workspaceURL: temporaryURL)
        try runGit(arguments: ["push", "-u", "origin", "trunk"], workspaceURL: temporaryURL)
        try runGit(arguments: ["remote", "set-head", "origin", "trunk"], workspaceURL: temporaryURL)

        try runGit(arguments: ["checkout", "-b", "feature/origin-head"], workspaceURL: temporaryURL)
        try "line-1\nline-2\n".write(to: fileURL, atomically: true, encoding: .utf8)

        let result = try await service.executeCommit(
            at: temporaryURL,
            stagePolicy: .includeUnstaged,
            message: "feat: origin head base",
            nextStep: .commit
        )
        XCTAssertEqual(result.baseBranch, "trunk")
    }

    func testDiffWorktreeComparisonDefaultBaselineSuccess() async throws {
        let service = GitRepositoryService()
        let repositoryURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let siblingURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: repositoryURL, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: repositoryURL)
            try? FileManager.default.removeItem(at: siblingURL)
        }

        try await service.initializeRepository(at: repositoryURL)
        try runGit(arguments: ["config", "user.email", "test@example.com"], workspaceURL: repositoryURL)
        try runGit(arguments: ["config", "user.name", "Tester"], workspaceURL: repositoryURL)
        try runGit(arguments: ["branch", "-M", "main"], workspaceURL: repositoryURL)

        let fileURL = repositoryURL.appendingPathComponent("sample.txt")
        try "line-1\n".write(to: fileURL, atomically: true, encoding: .utf8)
        try runGit(arguments: ["add", "."], workspaceURL: repositoryURL)
        try runGit(arguments: ["commit", "-m", "init"], workspaceURL: repositoryURL)

        try runGit(arguments: ["checkout", "-b", "feature/source"], workspaceURL: repositoryURL)
        try "line-1\nline-2\n".write(to: fileURL, atomically: true, encoding: .utf8)
        try runGit(arguments: ["add", "."], workspaceURL: repositoryURL)
        try runGit(arguments: ["commit", "-m", "feature change"], workspaceURL: repositoryURL)

        try runGit(arguments: ["worktree", "add", "-b", "feature/sibling", siblingURL.path, "main"], workspaceURL: repositoryURL)

        let request = WorktreeDiffRequest(
            repositoryRootPath: repositoryURL.path,
            sourceWorktreePath: repositoryURL.path,
            sourceBranchName: "feature/source",
            baseline: .mergeBaseWithDefault
        )
        let snapshot = try await service.diffWorktreeComparison(request: request)
        XCTAssertGreaterThan(snapshot.summary.filesChanged, 0)
        XCTAssertTrue(snapshot.patchText.contains("diff --git"))
    }

    func testDiffWorktreeComparisonSiblingBaselineSuccess() async throws {
        let service = GitRepositoryService()
        let repositoryURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let siblingURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: repositoryURL, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: repositoryURL)
            try? FileManager.default.removeItem(at: siblingURL)
        }

        try await service.initializeRepository(at: repositoryURL)
        try runGit(arguments: ["config", "user.email", "test@example.com"], workspaceURL: repositoryURL)
        try runGit(arguments: ["config", "user.name", "Tester"], workspaceURL: repositoryURL)
        try runGit(arguments: ["branch", "-M", "main"], workspaceURL: repositoryURL)

        let fileURL = repositoryURL.appendingPathComponent("sample.txt")
        try "line-1\n".write(to: fileURL, atomically: true, encoding: .utf8)
        try runGit(arguments: ["add", "."], workspaceURL: repositoryURL)
        try runGit(arguments: ["commit", "-m", "init"], workspaceURL: repositoryURL)

        try runGit(arguments: ["checkout", "-b", "feature/source"], workspaceURL: repositoryURL)
        try "line-1\nline-2\n".write(to: fileURL, atomically: true, encoding: .utf8)
        try runGit(arguments: ["add", "."], workspaceURL: repositoryURL)
        try runGit(arguments: ["commit", "-m", "feature change"], workspaceURL: repositoryURL)

        try runGit(arguments: ["worktree", "add", "-b", "feature/sibling", siblingURL.path, "main"], workspaceURL: repositoryURL)

        let request = WorktreeDiffRequest(
            repositoryRootPath: repositoryURL.path,
            sourceWorktreePath: repositoryURL.path,
            sourceBranchName: "feature/source",
            baseline: .siblingWorktree(path: siblingURL.path, branchName: "feature/sibling")
        )
        let snapshot = try await service.diffWorktreeComparison(request: request)
        XCTAssertGreaterThan(snapshot.summary.filesChanged, 0)
        XCTAssertTrue(snapshot.patchText.contains("diff --git"))
    }

    func testDiffWorktreeComparisonTargetNotFoundError() async throws {
        let service = GitRepositoryService()
        let repositoryURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: repositoryURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: repositoryURL) }

        try await service.initializeRepository(at: repositoryURL)
        try runGit(arguments: ["config", "user.email", "test@example.com"], workspaceURL: repositoryURL)
        try runGit(arguments: ["config", "user.name", "Tester"], workspaceURL: repositoryURL)
        try runGit(arguments: ["branch", "-M", "main"], workspaceURL: repositoryURL)

        let fileURL = repositoryURL.appendingPathComponent("sample.txt")
        try "line-1\n".write(to: fileURL, atomically: true, encoding: .utf8)
        try runGit(arguments: ["add", "."], workspaceURL: repositoryURL)
        try runGit(arguments: ["commit", "-m", "init"], workspaceURL: repositoryURL)

        let missingPath = repositoryURL.appendingPathComponent("does-not-exist")
        let request = WorktreeDiffRequest(
            repositoryRootPath: repositoryURL.path,
            sourceWorktreePath: repositoryURL.path,
            sourceBranchName: "main",
            baseline: .siblingWorktree(path: missingPath.path, branchName: "missing")
        )

        do {
            _ = try await service.diffWorktreeComparison(request: request)
            XCTFail("Expected targetWorktreeNotFound error")
        } catch let error as GitRepositoryServiceError {
            XCTAssertEqual(error, .targetWorktreeNotFound)
        }
    }

    func testDiffWorktreeComparisonCrossRepositoryError() async throws {
        let service = GitRepositoryService()
        let repositoryURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let otherRepositoryURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: repositoryURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: otherRepositoryURL, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: repositoryURL)
            try? FileManager.default.removeItem(at: otherRepositoryURL)
        }

        try await service.initializeRepository(at: repositoryURL)
        try await service.initializeRepository(at: otherRepositoryURL)
        try runGit(arguments: ["config", "user.email", "test@example.com"], workspaceURL: repositoryURL)
        try runGit(arguments: ["config", "user.name", "Tester"], workspaceURL: repositoryURL)
        try runGit(arguments: ["branch", "-M", "main"], workspaceURL: repositoryURL)

        let fileURL = repositoryURL.appendingPathComponent("sample.txt")
        try "line-1\n".write(to: fileURL, atomically: true, encoding: .utf8)
        try runGit(arguments: ["add", "."], workspaceURL: repositoryURL)
        try runGit(arguments: ["commit", "-m", "init"], workspaceURL: repositoryURL)

        let request = WorktreeDiffRequest(
            repositoryRootPath: repositoryURL.path,
            sourceWorktreePath: repositoryURL.path,
            sourceBranchName: "main",
            baseline: .siblingWorktree(path: otherRepositoryURL.path, branchName: "other")
        )

        do {
            _ = try await service.diffWorktreeComparison(request: request)
            XCTFail("Expected crossRepositoryComparisonUnsupported error")
        } catch let error as GitRepositoryServiceError {
            XCTAssertEqual(error, .crossRepositoryComparisonUnsupported)
        }
    }

    private func runGit(arguments: [String], workspaceURL: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["git", "-C", workspaceURL.path] + arguments
        let stdErr = Pipe()
        process.standardError = stdErr
        try process.run()
        process.waitUntilExit()
        if process.terminationStatus != 0 {
            let data = stdErr.fileHandleForReading.readDataToEndOfFile()
            let message = String(data: data, encoding: .utf8) ?? "git command failed"
            XCTFail(message)
        }
    }

    private func runGitOutput(arguments: [String], workspaceURL: URL) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["git", "-C", workspaceURL.path] + arguments
        let stdOut = Pipe()
        let stdErr = Pipe()
        process.standardOutput = stdOut
        process.standardError = stdErr
        try process.run()
        process.waitUntilExit()
        if process.terminationStatus != 0 {
            let data = stdErr.fileHandleForReading.readDataToEndOfFile()
            let message = String(data: data, encoding: .utf8) ?? "git command failed"
            XCTFail(message)
        }
        let outputData = stdOut.fileHandleForReading.readDataToEndOfFile()
        return String(data: outputData, encoding: .utf8) ?? ""
    }
}
