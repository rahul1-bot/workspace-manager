import XCTest
@testable import WorkspaceManager

actor MockGitRepositoryService: GitRepositoryServicing {
    func status(at workspaceURL: URL) async -> GitRepositoryStatus {
        return GitRepositoryStatus(isRepository: true, branchName: "dev", disabledReason: nil)
    }

    func initializeRepository(at workspaceURL: URL) async throws {
        _ = workspaceURL
    }
}

actor MockNonGitRepositoryService: GitRepositoryServicing {
    func status(at workspaceURL: URL) async -> GitRepositoryStatus {
        _ = workspaceURL
        return GitRepositoryStatus(isRepository: false, branchName: "-", disabledReason: .notGitRepository)
    }

    func initializeRepository(at workspaceURL: URL) async throws {
        _ = workspaceURL
    }
}

actor MockEditorLaunchService: EditorLaunching {
    func availableEditors() async -> [ExternalEditor] {
        return [.zed, .vsCode, .finder]
    }

    func preferredEditor(for workspaceID: UUID) async -> ExternalEditor? {
        return .zed
    }

    func setPreferredEditor(_ editor: ExternalEditor, for workspaceID: UUID) async {
        _ = editor
        _ = workspaceID
    }

    func openWorkspace(at workspaceURL: URL, using editor: ExternalEditor) async {
        _ = workspaceURL
        _ = editor
    }
}

struct MockPRLinkBuilder: PRLinkBuilding {
    func compareURL(remoteURL: String, baseBranch: String, headBranch: String) -> URL? {
        _ = baseBranch
        _ = headBranch
        return URL(string: remoteURL)
    }
}

final class GitUIStateTests: XCTestCase {
    @MainActor
    func testAppStateSupportsInjectedBoundaries() {
        let appState = AppState(
            configService: ConfigService.shared,
            gitRepositoryService: MockGitRepositoryService(),
            editorLaunchService: MockEditorLaunchService(),
            prLinkBuilder: MockPRLinkBuilder()
        )

        XCTAssertNotNil(appState)
    }

    @MainActor
    func testNonGitStateDisablesCommitAndDiff() async {
        let appState = AppState(
            configService: ConfigService.shared,
            gitRepositoryService: MockNonGitRepositoryService(),
            editorLaunchService: MockEditorLaunchService(),
            prLinkBuilder: MockPRLinkBuilder()
        )

        appState.refreshGitUIState()
        try? await Task.sleep(nanoseconds: 120_000_000)

        XCTAssertEqual(appState.commitSheetState.disabledReason, .notGitRepository)
        XCTAssertEqual(appState.gitPanelState.disabledReason, .notGitRepository)
    }

    @MainActor
    func testDiffPanelPlaceholderTransitions() {
        let appState = AppState(
            configService: ConfigService.shared,
            gitRepositoryService: MockGitRepositoryService(),
            editorLaunchService: MockEditorLaunchService(),
            prLinkBuilder: MockPRLinkBuilder()
        )

        appState.gitPanelState.disabledReason = nil
        XCTAssertFalse(appState.gitPanelState.isPresented)

        appState.toggleDiffPanelPlaceholder()
        XCTAssertTrue(appState.gitPanelState.isPresented)

        appState.setDiffPanelModePlaceholder(.allBranchChanges)
        XCTAssertEqual(appState.gitPanelState.mode, .allBranchChanges)

        appState.dismissDiffPanelPlaceholder()
        XCTAssertFalse(appState.gitPanelState.isPresented)
    }

    @MainActor
    func testCommitSheetPlaceholderTransitions() {
        let appState = AppState(
            configService: ConfigService.shared,
            gitRepositoryService: MockGitRepositoryService(),
            editorLaunchService: MockEditorLaunchService(),
            prLinkBuilder: MockPRLinkBuilder()
        )

        appState.commitSheetState.disabledReason = nil
        XCTAssertFalse(appState.commitSheetState.isPresented)

        appState.presentCommitSheetPlaceholder()
        XCTAssertTrue(appState.commitSheetState.isPresented)

        appState.setIncludeUnstagedPlaceholder(false)
        appState.setCommitMessagePlaceholder("test")
        appState.setCommitNextStepPlaceholder(.commitAndPush)

        XCTAssertFalse(appState.commitSheetState.includeUnstaged)
        XCTAssertEqual(appState.commitSheetState.message, "test")
        XCTAssertEqual(appState.commitSheetState.nextStep, .commitAndPush)

        appState.continueCommitFlowPlaceholder()
        XCTAssertEqual(appState.commitSheetState.errorText, GitControlDisabledReason.unavailableInPhase.title)

        appState.dismissCommitSheetPlaceholder()
        XCTAssertFalse(appState.commitSheetState.isPresented)
    }

    func testDiffPanelModeTitles() {
        XCTAssertEqual(DiffPanelMode.uncommitted.title, "Uncommitted changes")
        XCTAssertEqual(DiffPanelMode.allBranchChanges.title, "All branch changes")
        XCTAssertEqual(DiffPanelMode.lastTurnChanges.title, "Last turn changes")
    }
}
