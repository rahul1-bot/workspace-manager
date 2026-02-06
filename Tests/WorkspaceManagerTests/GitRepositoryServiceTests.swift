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
}
