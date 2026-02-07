import Foundation

struct WorktreeWorkspaceLink: Codable, Equatable, Sendable {
    var workspaceID: String
    var worktreePath: String
    var repositoryRootPath: String
    var purpose: WorktreePurposeRecord?
    var isAutoManaged: Bool
    var isStale: Bool
    var updatedAt: Date
}

struct WorktreeStateDocument: Codable, Equatable, Sendable {
    var schemaVersion: Int = 1
    var linksByWorkspaceID: [String: WorktreeWorkspaceLink] = [:]
    var linksByWorktreePath: [String: WorktreeWorkspaceLink] = [:]

    mutating func upsertLink(_ link: WorktreeWorkspaceLink) {
        linksByWorkspaceID[link.workspaceID] = link
        linksByWorktreePath[link.worktreePath] = link
    }
}

