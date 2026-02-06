import XCTest
@testable import WorkspaceManager

final class PRLinkBuilderTests: XCTestCase {
    func testCompareURLFromHTTPSRemote() {
        let builder = PRLinkBuilder()
        let url = builder.compareURL(
            remoteURL: "https://github.com/example/workspace-manager.git",
            baseBranch: "main",
            headBranch: "feature/test"
        )

        XCTAssertEqual(
            url?.absoluteString,
            "https://github.com/example/workspace-manager/compare/main...feature/test?expand=1"
        )
    }

    func testCompareURLFromSSHRemote() {
        let builder = PRLinkBuilder()
        let url = builder.compareURL(
            remoteURL: "git@github.com:example/workspace-manager.git",
            baseBranch: "master",
            headBranch: "feature/test"
        )

        XCTAssertEqual(
            url?.absoluteString,
            "https://github.com/example/workspace-manager/compare/master...feature/test?expand=1"
        )
    }

    func testCompareURLReturnsNilForUnsupportedRemote() {
        let builder = PRLinkBuilder()
        let url = builder.compareURL(
            remoteURL: "https://gitlab.com/example/workspace-manager.git",
            baseBranch: "main",
            headBranch: "feature/test"
        )

        XCTAssertNil(url)
    }
}
