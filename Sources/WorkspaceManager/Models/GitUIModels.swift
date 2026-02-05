import Foundation

enum DiffPanelMode: String, CaseIterable, Codable, Sendable {
    case uncommitted
    case allBranchChanges
    case lastTurnChanges

    var title: String {
        switch self {
        case .uncommitted:
            return "Uncommitted changes"
        case .allBranchChanges:
            return "All branch changes"
        case .lastTurnChanges:
            return "Last turn changes"
        }
    }
}

enum CommitNextStep: String, CaseIterable, Codable, Sendable {
    case commit
    case commitAndPush
    case commitAndCreatePR

    var title: String {
        switch self {
        case .commit:
            return "Commit"
        case .commitAndPush:
            return "Commit and push"
        case .commitAndCreatePR:
            return "Commit and create PR"
        }
    }
}

enum GitControlDisabledReason: String, Codable, Sendable {
    case noWorkspace
    case notGitRepository
    case unavailableInPhase

    var title: String {
        switch self {
        case .noWorkspace:
            return "No workspace selected"
        case .notGitRepository:
            return "Not a git repository"
        case .unavailableInPhase:
            return "Available in next phase"
        }
    }
}

struct GitChangeSummary: Codable, Equatable, Sendable {
    var branchName: String
    var filesChanged: Int
    var additions: Int
    var deletions: Int

    init(branchName: String = "-", filesChanged: Int = 0, additions: Int = 0, deletions: Int = 0) {
        self.branchName = branchName
        self.filesChanged = filesChanged
        self.additions = additions
        self.deletions = deletions
    }
}

struct GitPanelState: Codable, Equatable, Sendable {
    var isPresented: Bool
    var mode: DiffPanelMode
    var summary: GitChangeSummary
    var patchText: String
    var isLoading: Bool
    var errorText: String?
    var disabledReason: GitControlDisabledReason?

    init(
        isPresented: Bool = false,
        mode: DiffPanelMode = .lastTurnChanges,
        summary: GitChangeSummary = GitChangeSummary(),
        patchText: String = "",
        isLoading: Bool = false,
        errorText: String? = nil,
        disabledReason: GitControlDisabledReason? = .unavailableInPhase
    ) {
        self.isPresented = isPresented
        self.mode = mode
        self.summary = summary
        self.patchText = patchText
        self.isLoading = isLoading
        self.errorText = errorText
        self.disabledReason = disabledReason
    }
}

struct CommitSheetState: Codable, Equatable, Sendable {
    var isPresented: Bool
    var includeUnstaged: Bool
    var message: String
    var nextStep: CommitNextStep
    var summary: GitChangeSummary
    var errorText: String?
    var disabledReason: GitControlDisabledReason?

    init(
        isPresented: Bool = false,
        includeUnstaged: Bool = true,
        message: String = "",
        nextStep: CommitNextStep = .commit,
        summary: GitChangeSummary = GitChangeSummary(),
        errorText: String? = nil,
        disabledReason: GitControlDisabledReason? = .unavailableInPhase
    ) {
        self.isPresented = isPresented
        self.includeUnstaged = includeUnstaged
        self.message = message
        self.nextStep = nextStep
        self.summary = summary
        self.errorText = errorText
        self.disabledReason = disabledReason
    }
}
