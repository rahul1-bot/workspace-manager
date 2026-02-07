import Foundation

struct WorkspaceBranchMetadata: Equatable, Sendable {
    var branchName: String
    var isDirty: Bool
}
