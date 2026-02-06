import Foundation
import OSLog

actor GraphStateService {
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private var pendingSave: Task<Void, Never>?

    init() {
        let homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
        let configDirectory: URL = homeDirectory
            .appendingPathComponent(".config")
            .appendingPathComponent("workspace-manager")
        self.fileURL = configDirectory.appendingPathComponent("graph-state.json")
        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.decoder = JSONDecoder()
    }

    func load() -> GraphStateDocument {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            AppLogger.graph.info("No graph state file found at \(self.fileURL.path, privacy: .public), returning empty state")
            return GraphStateDocument()
        }
        do {
            let data: Data = try Data(contentsOf: fileURL)
            let document: GraphStateDocument = try decoder.decode(GraphStateDocument.self, from: data)
            AppLogger.graph.info("Loaded graph state with \(document.nodes.count) nodes and \(document.edges.count) edges")
            return document
        } catch {
            AppLogger.graph.error("Failed to load graph state: \(error.localizedDescription, privacy: .public)")
            return GraphStateDocument()
        }
    }

    func save(_ document: GraphStateDocument) {
        pendingSave?.cancel()
        pendingSave = Task { [fileURL, encoder] in
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }

            do {
                let directory: URL = fileURL.deletingLastPathComponent()
                if !FileManager.default.fileExists(atPath: directory.path) {
                    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                }
                let data: Data = try encoder.encode(document)
                try data.write(to: fileURL, options: .atomic)
                AppLogger.graph.debug("Saved graph state with \(document.nodes.count) nodes and \(document.edges.count) edges")
            } catch {
                AppLogger.graph.error("Failed to save graph state: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    func saveImmediately(_ document: GraphStateDocument) throws {
        let directory: URL = fileURL.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        do {
            let data: Data = try encoder.encode(document)
            try data.write(to: fileURL, options: .atomic)
            AppLogger.graph.info("Immediately saved graph state with \(document.nodes.count) nodes and \(document.edges.count) edges")
        } catch let encodeError as EncodingError {
            throw GraphStateError.encodingFailed(encodeError.localizedDescription)
        } catch {
            throw GraphStateError.saveFailed(fileURL, error.localizedDescription)
        }
    }
}
