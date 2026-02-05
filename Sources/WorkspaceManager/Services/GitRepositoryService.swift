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
}

actor GitRepositoryService: GitRepositoryServicing {
    func status(at workspaceURL: URL) async -> GitRepositoryStatus {
        _ = workspaceURL
        return GitRepositoryStatus()
    }
}
