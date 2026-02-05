import Foundation

protocol PRLinkBuilding: Sendable {
    func compareURL(remoteURL: String, baseBranch: String, headBranch: String) -> URL?
}

struct PRLinkBuilder: PRLinkBuilding {
    func compareURL(remoteURL: String, baseBranch: String, headBranch: String) -> URL? {
        _ = baseBranch
        _ = headBranch
        return URL(string: remoteURL)
    }
}
