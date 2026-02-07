import Foundation

struct WorktreeDescriptor: Identifiable, Codable, Equatable, Sendable {
    let repositoryRootPath: String
    let worktreePath: String
    let branchName: String
    let headShortSHA: String
    let isDetachedHead: Bool
    let isCurrent: Bool
    let isDirty: Bool
    let aheadCount: Int
    let behindCount: Int

    var id: String {
        worktreePath
    }

    var pathLeaf: String {
        URL(fileURLWithPath: worktreePath).lastPathComponent
    }
}

struct WorktreeCatalog: Codable, Equatable, Sendable {
    let repositoryRootPath: String
    let currentWorktreePath: String
    let descriptors: [WorktreeDescriptor]

    var siblingDescriptors: [WorktreeDescriptor] {
        descriptors.filter { !$0.isCurrent }
    }
}

struct WorktreeCreateRequest: Sendable {
    let repositoryRootPath: String
    let branchName: String
    let baseReference: String
    let destinationPath: String
    let purpose: String?
}

struct WorktreePurposeRecord: Codable, Equatable, Sendable {
    let purpose: String
    let updatedAt: Date
}

enum WorktreeComparisonBaseline: Codable, Equatable, Hashable, Sendable {
    case mergeBaseWithDefault
    case siblingWorktree(path: String, branchName: String)

    var title: String {
        switch self {
        case .mergeBaseWithDefault:
            return "Merge-base vs trunk/upstream"
        case .siblingWorktree(_, let branchName):
            return "Compare vs \(branchName)"
        }
    }
}

struct WorktreeDiffRequest: Codable, Equatable, Sendable {
    let repositoryRootPath: String
    let sourceWorktreePath: String
    let sourceBranchName: String
    let baseline: WorktreeComparisonBaseline
}

struct WorktreeWorkspaceUpdate: Equatable, Sendable {
    let workspaceID: UUID
    let descriptor: WorktreeDescriptor
}

struct WorktreeWorkspaceSyncPlan: Equatable, Sendable {
    let additions: [WorktreeDescriptor]
    let updates: [WorktreeWorkspaceUpdate]
}
