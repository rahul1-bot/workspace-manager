import XCTest
@testable import WorkspaceManager

actor MockGitRepositoryService: GitRepositoryServicing {
    private(set) var recordedMessages: [String] = []

    func status(at workspaceURL: URL) async -> GitRepositoryStatus {
        _ = workspaceURL
        return GitRepositoryStatus(isRepository: true, branchName: "dev", disabledReason: nil)
    }

    func initializeRepository(at workspaceURL: URL) async throws {
        _ = workspaceURL
    }

    func diff(at workspaceURL: URL, mode: DiffPanelMode) async throws -> GitDiffSnapshot {
        _ = workspaceURL
        return GitDiffSnapshot(
            summary: GitChangeSummary(branchName: "dev", filesChanged: 1, additions: 1, deletions: 0),
            patchText: mode.rawValue
        )
    }

    func executeCommit(
        at workspaceURL: URL,
        stagePolicy: CommitStagePolicy,
        message: String,
        nextStep: CommitNextStep
    ) async throws -> GitCommitResult {
        _ = workspaceURL
        _ = stagePolicy
        _ = nextStep
        recordedMessages.append(message)
        return GitCommitResult(branchName: "dev", remoteURL: "https://github.com/example/workspace-manager.git", baseBranch: "main")
    }

    func autoCommitMessage(at workspaceURL: URL) async throws -> String {
        _ = workspaceURL
        return "chore: update 1 files in workspace"
    }

    func lastRecordedMessage() async -> String? {
        recordedMessages.last
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

    func diff(at workspaceURL: URL, mode: DiffPanelMode) async throws -> GitDiffSnapshot {
        _ = workspaceURL
        _ = mode
        throw GitRepositoryServiceError.commandFailed("not repository")
    }

    func executeCommit(
        at workspaceURL: URL,
        stagePolicy: CommitStagePolicy,
        message: String,
        nextStep: CommitNextStep
    ) async throws -> GitCommitResult {
        _ = workspaceURL
        _ = stagePolicy
        _ = message
        _ = nextStep
        throw GitRepositoryServiceError.commandFailed("not repository")
    }

    func autoCommitMessage(at workspaceURL: URL) async throws -> String {
        _ = workspaceURL
        return "chore: update 1 files in workspace"
    }
}

actor MockSlowDiffRepositoryService: GitRepositoryServicing {
    func status(at workspaceURL: URL) async -> GitRepositoryStatus {
        _ = workspaceURL
        return GitRepositoryStatus(isRepository: true, branchName: "dev", disabledReason: nil)
    }

    func initializeRepository(at workspaceURL: URL) async throws {
        _ = workspaceURL
    }

    func diff(at workspaceURL: URL, mode: DiffPanelMode) async throws -> GitDiffSnapshot {
        _ = workspaceURL
        if mode == .allBranchChanges {
            try await Task.sleep(nanoseconds: 200_000_000)
        } else {
            try await Task.sleep(nanoseconds: 40_000_000)
        }
        return GitDiffSnapshot(
            summary: GitChangeSummary(branchName: "dev", filesChanged: 1, additions: 2, deletions: 1),
            patchText: mode.rawValue
        )
    }

    func executeCommit(
        at workspaceURL: URL,
        stagePolicy: CommitStagePolicy,
        message: String,
        nextStep: CommitNextStep
    ) async throws -> GitCommitResult {
        _ = workspaceURL
        _ = stagePolicy
        _ = message
        _ = nextStep
        return GitCommitResult(branchName: "dev", remoteURL: nil, baseBranch: "main")
    }

    func autoCommitMessage(at workspaceURL: URL) async throws -> String {
        _ = workspaceURL
        return "chore: update 1 files in workspace"
    }
}

actor MockEditorLaunchService: EditorLaunching {
    func availableEditors() async -> [ExternalEditor] {
        [.zed, .vsCode, .finder]
    }

    func preferredEditor(for workspaceID: UUID) async -> ExternalEditor? {
        _ = workspaceID
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

actor MockURLOpener: URLOpening {
    private(set) var openedURLs: [URL] = []

    func open(_ url: URL) async {
        openedURLs.append(url)
    }

    func lastOpenedURL() async -> URL? {
        openedURLs.last
    }
}

final class GitUIStateTests: XCTestCase {
    @MainActor
    func testAppStateSupportsInjectedBoundaries() {
        let appState = AppState(
            configService: ConfigService.shared,
            gitRepositoryService: MockGitRepositoryService(),
            editorLaunchService: MockEditorLaunchService(),
            prLinkBuilder: MockPRLinkBuilder(),
            urlOpener: MockURLOpener()
        )

        XCTAssertNotNil(appState)
    }

    @MainActor
    func testNonGitStateDisablesCommitAndDiff() async {
        let appState = AppState(
            configService: ConfigService.shared,
            gitRepositoryService: MockNonGitRepositoryService(),
            editorLaunchService: MockEditorLaunchService(),
            prLinkBuilder: MockPRLinkBuilder(),
            urlOpener: MockURLOpener()
        )

        appState.refreshGitUIState()
        try? await Task.sleep(nanoseconds: 120_000_000)

        XCTAssertEqual(appState.commitSheetState.disabledReason, .notGitRepository)
        XCTAssertEqual(appState.gitPanelState.disabledReason, .notGitRepository)
    }

    @MainActor
    func testModeSwitchKeepsLatestDiffResult() async {
        let appState = AppState(
            configService: ConfigService.shared,
            gitRepositoryService: MockSlowDiffRepositoryService(),
            editorLaunchService: MockEditorLaunchService(),
            prLinkBuilder: MockPRLinkBuilder(),
            urlOpener: MockURLOpener()
        )

        appState.refreshGitUIState()
        try? await Task.sleep(nanoseconds: 120_000_000)

        appState.toggleDiffPanelPlaceholder()
        appState.setDiffPanelModePlaceholder(.allBranchChanges)
        appState.setDiffPanelModePlaceholder(.lastTurnChanges)

        try? await Task.sleep(nanoseconds: 320_000_000)

        XCTAssertEqual(appState.gitPanelState.mode, .lastTurnChanges)
        XCTAssertEqual(appState.gitPanelState.patchText, DiffPanelMode.lastTurnChanges.rawValue)
    }

    @MainActor
    func testDiffPanelPlaceholderTransitions() {
        let appState = AppState(
            configService: ConfigService.shared,
            gitRepositoryService: MockGitRepositoryService(),
            editorLaunchService: MockEditorLaunchService(),
            prLinkBuilder: MockPRLinkBuilder(),
            urlOpener: MockURLOpener()
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
    func testCommitFlowUsesAutoGeneratedMessageWhenBlank() async {
        let gitService = MockGitRepositoryService()
        let appState = AppState(
            configService: ConfigService.shared,
            gitRepositoryService: gitService,
            editorLaunchService: MockEditorLaunchService(),
            prLinkBuilder: MockPRLinkBuilder(),
            urlOpener: MockURLOpener()
        )

        appState.commitSheetState.disabledReason = nil
        appState.presentCommitSheetPlaceholder()
        appState.setCommitMessagePlaceholder("")
        appState.setCommitNextStepPlaceholder(.commit)
        appState.continueCommitFlowPlaceholder()

        try? await Task.sleep(nanoseconds: 160_000_000)

        let message = await gitService.lastRecordedMessage()
        XCTAssertEqual(message, "chore: update 1 files in workspace")
        XCTAssertFalse(appState.commitSheetState.isPresented)
    }

    @MainActor
    func testCommitAndCreatePROpensCompareURL() async {
        let urlOpener = MockURLOpener()
        let appState = AppState(
            configService: ConfigService.shared,
            gitRepositoryService: MockGitRepositoryService(),
            editorLaunchService: MockEditorLaunchService(),
            prLinkBuilder: MockPRLinkBuilder(),
            urlOpener: urlOpener
        )

        appState.commitSheetState.disabledReason = nil
        appState.presentCommitSheetPlaceholder()
        appState.setCommitMessagePlaceholder("feat: test")
        appState.setCommitNextStepPlaceholder(.commitAndCreatePR)
        appState.continueCommitFlowPlaceholder()

        try? await Task.sleep(nanoseconds: 200_000_000)

        let openedURL = await urlOpener.lastOpenedURL()
        XCTAssertNotNil(openedURL)
    }

    func testDiffPanelModeTitles() {
        XCTAssertEqual(DiffPanelMode.uncommitted.title, "Uncommitted changes")
        XCTAssertEqual(DiffPanelMode.allBranchChanges.title, "All branch changes")
        XCTAssertEqual(DiffPanelMode.lastTurnChanges.title, "Last turn changes")
    }
}
