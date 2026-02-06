import Foundation
import AppKit

protocol URLOpening: Sendable {
    func open(_ url: URL) async
}

struct WorkspaceURLOpener: URLOpening {
    func open(_ url: URL) async {
        _ = await MainActor.run {
            NSWorkspace.shared.open(url)
        }
    }
}
