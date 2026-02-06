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
}
