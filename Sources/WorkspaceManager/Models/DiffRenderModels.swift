import Foundation

enum DiffFileStatus: String, Sendable, Equatable {
    case modified
    case added
    case deleted
    case renamed
    case copied
    case binary
    case unknown
}

enum DiffLineKind: String, Sendable, Equatable {
    case fileHeader
    case fileMeta
    case oldFilePath
    case newFilePath
    case hunkHeader
    case context
    case addition
    case deletion
    case noNewlineMarker
}

struct DiffTextSpan: Sendable, Equatable {
    let start: Int
    let end: Int

    init(start: Int, end: Int) {
        self.start = max(0, start)
        self.end = max(self.start, end)
    }

    func overlaps(start otherStart: Int, end otherEnd: Int) -> Bool {
        start < otherEnd && otherStart < end
    }
}

struct DiffRenderableLine: Identifiable, Sendable, Equatable {
    let id: String
    let kind: DiffLineKind
    let rawText: String
    let codeText: String
    let oldLineNumber: Int?
    let newLineNumber: Int?
    let isNoNewlineMarker: Bool
    let emphasisSpans: [DiffTextSpan]

    init(
        id: String,
        kind: DiffLineKind,
        rawText: String,
        codeText: String,
        oldLineNumber: Int?,
        newLineNumber: Int?,
        isNoNewlineMarker: Bool,
        emphasisSpans: [DiffTextSpan] = []
    ) {
        self.id = id
        self.kind = kind
        self.rawText = rawText
        self.codeText = codeText
        self.oldLineNumber = oldLineNumber
        self.newLineNumber = newLineNumber
        self.isNoNewlineMarker = isNoNewlineMarker
        self.emphasisSpans = emphasisSpans
    }

    func withEmphasisSpans(_ spans: [DiffTextSpan]) -> DiffRenderableLine {
        DiffRenderableLine(
            id: id,
            kind: kind,
            rawText: rawText,
            codeText: codeText,
            oldLineNumber: oldLineNumber,
            newLineNumber: newLineNumber,
            isNoNewlineMarker: isNoNewlineMarker,
            emphasisSpans: spans
        )
    }

    var showsLineNumbers: Bool {
        switch kind {
        case .context, .addition, .deletion:
            return true
        default:
            return false
        }
    }
}

struct DiffHunk: Identifiable, Sendable, Equatable {
    let id: String
    let headerText: String
    let oldStart: Int
    let oldCount: Int
    let newStart: Int
    let newCount: Int
    let lines: [DiffRenderableLine]
}

struct DiffFileSection: Identifiable, Sendable, Equatable {
    let id: String
    let oldPath: String
    let newPath: String
    let status: DiffFileStatus
    let additions: Int
    let deletions: Int
    let metadataLines: [DiffRenderableLine]
    let hunks: [DiffHunk]

    var displayPath: String {
        switch status {
        case .added:
            return newPath
        case .deleted:
            return oldPath
        default:
            if oldPath == newPath || oldPath.isEmpty {
                return newPath
            }
            if newPath.isEmpty {
                return oldPath
            }
            return "\(oldPath) -> \(newPath)"
        }
    }

    var fileExtension: String? {
        let candidate = newPath.isEmpty || newPath == "/dev/null" ? oldPath : newPath
        guard !candidate.isEmpty else { return nil }
        let ext = URL(fileURLWithPath: candidate).pathExtension.lowercased()
        return ext.isEmpty ? nil : ext
    }

    var hasCode: Bool {
        hunks.contains { !$0.lines.isEmpty }
    }
}

struct DiffDocument: Sendable, Equatable {
    let fileSections: [DiffFileSection]

    static let empty = DiffDocument(fileSections: [])
}

enum DiffTokenClass: String, Sendable, Equatable {
    case plain
    case keyword
    case string
    case number
    case comment
    case punctuation
    case heading
    case codeSpan
}

struct DiffToken: Sendable, Equatable {
    let text: String
    let tokenClass: DiffTokenClass
    let start: Int
    let end: Int
}
