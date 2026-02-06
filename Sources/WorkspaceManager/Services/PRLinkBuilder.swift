import Foundation

protocol PRLinkBuilding: Sendable {
    func compareURL(remoteURL: String, baseBranch: String, headBranch: String) -> URL?
}

struct PRLinkBuilder: PRLinkBuilding {
    func compareURL(remoteURL: String, baseBranch: String, headBranch: String) -> URL? {
        guard let repositoryPath = normalizedRepositoryPath(from: remoteURL) else {
            return nil
        }
        let comparePath = "https://github.com/\(repositoryPath)/compare/\(baseBranch)...\(headBranch)?expand=1"
        return URL(string: comparePath)
    }

    private func normalizedRepositoryPath(from remoteURL: String) -> String? {
        let trimmed = remoteURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("git@github.com:") {
            let path = String(trimmed.dropFirst("git@github.com:".count))
            return path.replacingOccurrences(of: ".git", with: "")
        }
        if trimmed.hasPrefix("https://github.com/") {
            let path = String(trimmed.dropFirst("https://github.com/".count))
            return path.replacingOccurrences(of: ".git", with: "")
        }
        return nil
    }
}
