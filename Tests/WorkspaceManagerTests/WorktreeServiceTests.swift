import XCTest
@testable import WorkspaceManager

final class WorktreeServiceTests: XCTestCase {
    func testCatalogIncludesMultipleWorktreesFromPorcelain() async throws {
        let service = WorktreeService()
        let repositoryURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let siblingURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: repositoryURL, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: repositoryURL)
            try? FileManager.default.removeItem(at: siblingURL)
        }

        try runGit(arguments: ["init"], workspaceURL: repositoryURL)
        try runGit(arguments: ["config", "user.email", "test@example.com"], workspaceURL: repositoryURL)
        try runGit(arguments: ["config", "user.name", "Tester"], workspaceURL: repositoryURL)
        try runGit(arguments: ["branch", "-M", "main"], workspaceURL: repositoryURL)

        let fileURL = repositoryURL.appendingPathComponent("sample.txt")
        try "line-1\n".write(to: fileURL, atomically: true, encoding: .utf8)
        try runGit(arguments: ["add", "."], workspaceURL: repositoryURL)
        try runGit(arguments: ["commit", "-m", "init"], workspaceURL: repositoryURL)
        try runGit(arguments: ["worktree", "add", "-b", "feature/sibling", siblingURL.path, "main"], workspaceURL: repositoryURL)

        let catalog = try await service.catalog(for: repositoryURL)
        XCTAssertEqual(catalog.descriptors.count, 2)
        XCTAssertTrue(catalog.descriptors.contains(where: { $0.isCurrent }))
        XCTAssertTrue(catalog.descriptors.contains(where: {
            URL(fileURLWithPath: $0.worktreePath).standardizedFileURL.path == siblingURL.standardizedFileURL.path
        }))
    }

    func testCatalogOnNonGitPathThrows() async throws {
        let service = WorktreeService()
        let directoryURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        do {
            _ = try await service.catalog(for: directoryURL)
            XCTFail("Expected notGitRepository error")
        } catch let error as WorktreeServiceError {
            switch error {
            case .notGitRepository:
                break
            default:
                XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testCreateWorktreeWithNewBranch() async throws {
        let service = WorktreeService()
        let repositoryURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let siblingURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: repositoryURL, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: repositoryURL)
            try? FileManager.default.removeItem(at: siblingURL)
        }

        try runGit(arguments: ["init"], workspaceURL: repositoryURL)
        try runGit(arguments: ["config", "user.email", "test@example.com"], workspaceURL: repositoryURL)
        try runGit(arguments: ["config", "user.name", "Tester"], workspaceURL: repositoryURL)
        try runGit(arguments: ["branch", "-M", "main"], workspaceURL: repositoryURL)
        let fileURL = repositoryURL.appendingPathComponent("sample.txt")
        try "line-1\n".write(to: fileURL, atomically: true, encoding: .utf8)
        try runGit(arguments: ["add", "."], workspaceURL: repositoryURL)
        try runGit(arguments: ["commit", "-m", "init"], workspaceURL: repositoryURL)

        let request = WorktreeCreateRequest(
            repositoryRootPath: repositoryURL.path,
            branchName: "feature/new-branch",
            baseReference: "HEAD",
            destinationPath: siblingURL.path,
            purpose: nil
        )
        let descriptor = try await service.createWorktree(request)
        XCTAssertEqual(descriptor.branchName, "feature/new-branch")
        XCTAssertEqual(
            URL(fileURLWithPath: descriptor.worktreePath).standardizedFileURL.path,
            siblingURL.standardizedFileURL.path
        )
    }

    func testCreateWorktreeWithExistingBranch() async throws {
        let service = WorktreeService()
        let repositoryURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let siblingURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: repositoryURL, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: repositoryURL)
            try? FileManager.default.removeItem(at: siblingURL)
        }

        try runGit(arguments: ["init"], workspaceURL: repositoryURL)
        try runGit(arguments: ["config", "user.email", "test@example.com"], workspaceURL: repositoryURL)
        try runGit(arguments: ["config", "user.name", "Tester"], workspaceURL: repositoryURL)
        try runGit(arguments: ["branch", "-M", "main"], workspaceURL: repositoryURL)
        let fileURL = repositoryURL.appendingPathComponent("sample.txt")
        try "line-1\n".write(to: fileURL, atomically: true, encoding: .utf8)
        try runGit(arguments: ["add", "."], workspaceURL: repositoryURL)
        try runGit(arguments: ["commit", "-m", "init"], workspaceURL: repositoryURL)
        try runGit(arguments: ["branch", "feature/existing"], workspaceURL: repositoryURL)

        let request = WorktreeCreateRequest(
            repositoryRootPath: repositoryURL.path,
            branchName: "feature/existing",
            baseReference: "HEAD",
            destinationPath: siblingURL.path,
            purpose: nil
        )
        let descriptor = try await service.createWorktree(request)
        XCTAssertEqual(descriptor.branchName, "feature/existing")
        XCTAssertEqual(
            URL(fileURLWithPath: descriptor.worktreePath).standardizedFileURL.path,
            siblingURL.standardizedFileURL.path
        )
    }

    func testWorkspaceSyncPlanAddUpdateNoDeleteBehavior() async throws {
        let service = WorktreeService()
        let rootURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let siblingURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: siblingURL, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: rootURL)
            try? FileManager.default.removeItem(at: siblingURL)
        }

        let rootDescriptor = WorktreeDescriptor(
            repositoryRootPath: rootURL.path,
            worktreePath: rootURL.path,
            branchName: "main",
            headShortSHA: "11111111",
            isDetachedHead: false,
            isCurrent: true,
            isDirty: false,
            aheadCount: 0,
            behindCount: 0
        )
        let siblingDescriptor = WorktreeDescriptor(
            repositoryRootPath: rootURL.path,
            worktreePath: siblingURL.path,
            branchName: "feature/sibling",
            headShortSHA: "22222222",
            isDetachedHead: false,
            isCurrent: false,
            isDirty: false,
            aheadCount: 0,
            behindCount: 0
        )
        let catalog = WorktreeCatalog(
            repositoryRootPath: rootURL.path,
            currentWorktreePath: rootURL.path,
            descriptors: [rootDescriptor, siblingDescriptor]
        )

        let existingWorkspace = Workspace(id: UUID(), name: "Root", path: rootURL.path)
        let staleWorkspace = Workspace(id: UUID(), name: "Stale", path: "/tmp/non-existent")

        let plan = service.workspaceSyncPlan(catalog: catalog, existingWorkspaces: [existingWorkspace, staleWorkspace])
        XCTAssertEqual(plan.additions.count, 1)
        XCTAssertEqual(plan.updates.count, 1)
        XCTAssertEqual(plan.updates.first?.workspaceID, existingWorkspace.id)
        XCTAssertEqual(plan.additions.first?.worktreePath, siblingURL.path)
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
