import Foundation

struct DiffPatchParser {
    func parse(_ patchText: String) -> DiffDocument {
        guard !patchText.isEmpty else {
            return .empty
        }

        let lines = patchText.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard lines.contains(where: { $0.hasPrefix("diff --git ") }) else {
            return fallbackDocument(from: lines)
        }

        var fileSections: [DiffFileSection] = []
        var cursor = 0
        var fileIndex = 0

        while cursor < lines.count {
            guard lines[cursor].hasPrefix("diff --git ") else {
                cursor += 1
                continue
            }

            let sectionStart = cursor
            cursor += 1
            while cursor < lines.count, !lines[cursor].hasPrefix("diff --git ") {
                cursor += 1
            }

            let sectionLines = Array(lines[sectionStart..<cursor])
            let section = parseFileSection(lines: sectionLines, fileIndex: fileIndex)
            fileSections.append(section)
            fileIndex += 1
        }

        if fileSections.isEmpty {
            return fallbackDocument(from: lines)
        }

        return DiffDocument(fileSections: fileSections)
    }

    private func parseFileSection(lines: [String], fileIndex: Int) -> DiffFileSection {
        guard let firstLine = lines.first else {
            return DiffFileSection(
                id: "diff-file-\(fileIndex)",
                oldPath: "",
                newPath: "",
                status: .unknown,
                additions: 0,
                deletions: 0,
                metadataLines: [],
                hunks: []
            )
        }

        let diffPaths = parseDiffHeaderPaths(firstLine)
        var oldPath = diffPaths.oldPath
        var newPath = diffPaths.newPath

        var metadataLines: [DiffRenderableLine] = [
            DiffRenderableLine(
                id: "diff-file-\(fileIndex)-meta-0",
                kind: .fileHeader,
                rawText: firstLine,
                codeText: firstLine,
                oldLineNumber: nil,
                newLineNumber: nil,
                isNoNewlineMarker: false
            )
        ]

        var hunks: [DiffHunk] = []
        var cursor = 1
        var metadataIndex = 1
        var hunkIndex = 0

        while cursor < lines.count {
            let line = lines[cursor]

            if line.hasPrefix("@@") {
                let parsedHunk = parseHunk(lines: lines, startIndex: cursor, fileIndex: fileIndex, hunkIndex: hunkIndex)
                hunks.append(parsedHunk.hunk)
                cursor = parsedHunk.nextIndex
                hunkIndex += 1
                continue
            }

            let lineKind = classifyMetadataKind(for: line)
            if lineKind == .oldFilePath {
                oldPath = normalizePathMarker(line, marker: "--- ")
            }
            if lineKind == .newFilePath {
                newPath = normalizePathMarker(line, marker: "+++ ")
            }

            metadataLines.append(
                DiffRenderableLine(
                    id: "diff-file-\(fileIndex)-meta-\(metadataIndex)",
                    kind: lineKind,
                    rawText: line,
                    codeText: line,
                    oldLineNumber: nil,
                    newLineNumber: nil,
                    isNoNewlineMarker: line.hasPrefix("\\ No newline at end of file")
                )
            )
            metadataIndex += 1
            cursor += 1
        }

        let status = determineStatus(
            metadataLines: metadataLines,
            oldPath: oldPath,
            newPath: newPath,
            hunks: hunks
        )
        let additions = hunks.reduce(0) { total, hunk in
            total + hunk.lines.filter { $0.kind == .addition }.count
        }
        let deletions = hunks.reduce(0) { total, hunk in
            total + hunk.lines.filter { $0.kind == .deletion }.count
        }
        let safeOldPath = oldPath.isEmpty ? diffPaths.oldPath : oldPath
        let safeNewPath = newPath.isEmpty ? diffPaths.newPath : newPath

        return DiffFileSection(
            id: "diff-file-\(fileIndex)-\(safeOldPath)-\(safeNewPath)",
            oldPath: safeOldPath,
            newPath: safeNewPath,
            status: status,
            additions: additions,
            deletions: deletions,
            metadataLines: metadataLines,
            hunks: hunks
        )
    }

    private func parseHunk(lines: [String], startIndex: Int, fileIndex: Int, hunkIndex: Int) -> (hunk: DiffHunk, nextIndex: Int) {
        let headerText = lines[startIndex]
        let header = parseHunkHeader(headerText)

        var oldLine = header.oldStart
        var newLine = header.newStart
        var cursor = startIndex + 1
        var lineIndex = 0
        var renderableLines: [DiffRenderableLine] = []

        while cursor < lines.count {
            let line = lines[cursor]
            if line.hasPrefix("@@") {
                break
            }

            let itemId = "diff-file-\(fileIndex)-hunk-\(hunkIndex)-line-\(lineIndex)"

            if line.hasPrefix("+"), !line.hasPrefix("+++") {
                let code = String(line.dropFirst())
                renderableLines.append(
                    DiffRenderableLine(
                        id: itemId,
                        kind: .addition,
                        rawText: line,
                        codeText: code,
                        oldLineNumber: nil,
                        newLineNumber: newLine,
                        isNoNewlineMarker: false
                    )
                )
                newLine += 1
            } else if line.hasPrefix("-"), !line.hasPrefix("---") {
                let code = String(line.dropFirst())
                renderableLines.append(
                    DiffRenderableLine(
                        id: itemId,
                        kind: .deletion,
                        rawText: line,
                        codeText: code,
                        oldLineNumber: oldLine,
                        newLineNumber: nil,
                        isNoNewlineMarker: false
                    )
                )
                oldLine += 1
            } else if line.hasPrefix(" ") {
                let code = String(line.dropFirst())
                renderableLines.append(
                    DiffRenderableLine(
                        id: itemId,
                        kind: .context,
                        rawText: line,
                        codeText: code,
                        oldLineNumber: oldLine,
                        newLineNumber: newLine,
                        isNoNewlineMarker: false
                    )
                )
                oldLine += 1
                newLine += 1
            } else if line.hasPrefix("\\ No newline at end of file") {
                renderableLines.append(
                    DiffRenderableLine(
                        id: itemId,
                        kind: .noNewlineMarker,
                        rawText: line,
                        codeText: line,
                        oldLineNumber: nil,
                        newLineNumber: nil,
                        isNoNewlineMarker: true
                    )
                )
            } else {
                renderableLines.append(
                    DiffRenderableLine(
                        id: itemId,
                        kind: .fileMeta,
                        rawText: line,
                        codeText: line,
                        oldLineNumber: nil,
                        newLineNumber: nil,
                        isNoNewlineMarker: false
                    )
                )
            }

            cursor += 1
            lineIndex += 1
        }

        let hunk = DiffHunk(
            id: "diff-file-\(fileIndex)-hunk-\(hunkIndex)",
            headerText: headerText,
            oldStart: header.oldStart,
            oldCount: header.oldCount,
            newStart: header.newStart,
            newCount: header.newCount,
            lines: renderableLines
        )

        return (hunk: hunk, nextIndex: cursor)
    }

    private func fallbackDocument(from lines: [String]) -> DiffDocument {
        guard !lines.isEmpty else {
            return .empty
        }

        let renderLines = lines.enumerated().map { index, line in
            DiffRenderableLine(
                id: "fallback-line-\(index)",
                kind: fallbackLineKind(for: line),
                rawText: line,
                codeText: fallbackCodeText(for: line),
                oldLineNumber: nil,
                newLineNumber: nil,
                isNoNewlineMarker: line.hasPrefix("\\ No newline at end of file")
            )
        }

        let hunk = DiffHunk(
            id: "fallback-hunk-0",
            headerText: "@@ -0,0 +0,0 @@",
            oldStart: 0,
            oldCount: 0,
            newStart: 0,
            newCount: 0,
            lines: renderLines
        )

        let section = DiffFileSection(
            id: "fallback-file-0",
            oldPath: "Patch",
            newPath: "Patch",
            status: .unknown,
            additions: renderLines.filter { $0.kind == .addition }.count,
            deletions: renderLines.filter { $0.kind == .deletion }.count,
            metadataLines: [],
            hunks: [hunk]
        )

        return DiffDocument(fileSections: [section])
    }

    private func parseDiffHeaderPaths(_ line: String) -> (oldPath: String, newPath: String) {
        let parts = line.split(separator: " ", omittingEmptySubsequences: true)
        guard parts.count >= 4 else {
            return (oldPath: "", newPath: "")
        }

        let oldToken = String(parts[2])
        let newToken = String(parts[3])

        return (
            oldPath: normalizedPathToken(oldToken),
            newPath: normalizedPathToken(newToken)
        )
    }

    private func normalizedPathToken(_ token: String) -> String {
        if token.hasPrefix("a/") || token.hasPrefix("b/") {
            return String(token.dropFirst(2))
        }
        return token
    }

    private func normalizePathMarker(_ line: String, marker: String) -> String {
        var value = line
        if value.hasPrefix(marker) {
            value = String(value.dropFirst(marker.count))
        }
        return normalizedPathToken(value)
    }

    private func classifyMetadataKind(for line: String) -> DiffLineKind {
        if line.hasPrefix("--- ") {
            return .oldFilePath
        }
        if line.hasPrefix("+++ ") {
            return .newFilePath
        }
        if line.hasPrefix("diff --git ") {
            return .fileHeader
        }
        return .fileMeta
    }

    private func fallbackLineKind(for line: String) -> DiffLineKind {
        if line.hasPrefix("@@") {
            return .hunkHeader
        }
        if line.hasPrefix("+") {
            return .addition
        }
        if line.hasPrefix("-") {
            return .deletion
        }
        if line.hasPrefix("\\ No newline at end of file") {
            return .noNewlineMarker
        }
        return .context
    }

    private func fallbackCodeText(for line: String) -> String {
        if line.hasPrefix("+") || line.hasPrefix("-") || line.hasPrefix(" ") {
            return String(line.dropFirst())
        }
        return line
    }

    private func parseHunkHeader(_ line: String) -> (oldStart: Int, oldCount: Int, newStart: Int, newCount: Int) {
        guard let regex = try? NSRegularExpression(pattern: "^@@ -(\\d+)(?:,(\\d+))? \\+(\\d+)(?:,(\\d+))? @@") else {
            return (oldStart: 0, oldCount: 0, newStart: 0, newCount: 0)
        }

        let nsLine = line as NSString
        let range = NSRange(location: 0, length: nsLine.length)
        guard let match = regex.firstMatch(in: line, range: range) else {
            return (oldStart: 0, oldCount: 0, newStart: 0, newCount: 0)
        }

        let oldStart = Int(nsLine.substring(with: match.range(at: 1))) ?? 0
        let oldCount = match.range(at: 2).location != NSNotFound ? (Int(nsLine.substring(with: match.range(at: 2))) ?? 1) : 1
        let newStart = Int(nsLine.substring(with: match.range(at: 3))) ?? 0
        let newCount = match.range(at: 4).location != NSNotFound ? (Int(nsLine.substring(with: match.range(at: 4))) ?? 1) : 1

        return (oldStart: oldStart, oldCount: oldCount, newStart: newStart, newCount: newCount)
    }

    private func determineStatus(
        metadataLines: [DiffRenderableLine],
        oldPath: String,
        newPath: String,
        hunks: [DiffHunk]
    ) -> DiffFileStatus {
        let rawMetadata = metadataLines.map(\.rawText)

        if rawMetadata.contains(where: { $0.hasPrefix("Binary files ") }) {
            return .binary
        }
        if rawMetadata.contains(where: { $0.hasPrefix("new file mode") }) || oldPath == "/dev/null" {
            return .added
        }
        if rawMetadata.contains(where: { $0.hasPrefix("deleted file mode") }) || newPath == "/dev/null" {
            return .deleted
        }
        if rawMetadata.contains(where: { $0.hasPrefix("rename from ") }) || rawMetadata.contains(where: { $0.hasPrefix("rename to ") }) {
            return .renamed
        }
        if rawMetadata.contains(where: { $0.hasPrefix("copy from ") }) || rawMetadata.contains(where: { $0.hasPrefix("copy to ") }) {
            return .copied
        }
        if !hunks.isEmpty {
            return .modified
        }
        return .unknown
    }

    private func annotateIntralineEmphasis(lines: [DiffRenderableLine]) -> [DiffRenderableLine] {
        var output = lines
        var cursor = 0

        while cursor < output.count {
            guard output[cursor].kind == .deletion else {
                cursor += 1
                continue
            }

            let deletionStart = cursor
            while cursor < output.count, output[cursor].kind == .deletion {
                cursor += 1
            }
            let deletionEnd = cursor

            let additionStart = cursor
            while cursor < output.count, output[cursor].kind == .addition {
                cursor += 1
            }
            let additionEnd = cursor

            guard additionStart < additionEnd else {
                continue
            }

            let pairCount = min(deletionEnd - deletionStart, additionEnd - additionStart)
            guard pairCount > 0 else {
                continue
            }

            for offset in 0..<pairCount {
                let deletionIndex = deletionStart + offset
                let additionIndex = additionStart + offset
                let deletionText = output[deletionIndex].codeText
                let additionText = output[additionIndex].codeText

                guard shouldAttemptPairing(left: deletionText, right: additionText) else {
                    continue
                }

                let spans = changedSpans(left: deletionText, right: additionText)
                if !spans.left.isEmpty {
                    output[deletionIndex] = output[deletionIndex].withEmphasisSpans(spans.left)
                }
                if !spans.right.isEmpty {
                    output[additionIndex] = output[additionIndex].withEmphasisSpans(spans.right)
                }
            }
        }

        return output
    }

    private func shouldAttemptPairing(left: String, right: String) -> Bool {
        let leftCount = left.count
        let rightCount = right.count
        guard leftCount > 0, rightCount > 0 else {
            return false
        }
        guard leftCount <= 240, rightCount <= 240 else {
            return false
        }
        guard leftCount * rightCount <= 40_000 else {
            return false
        }
        return true
    }

    private func changedSpans(left: String, right: String) -> (left: [DiffTextSpan], right: [DiffTextSpan]) {
        let lhs = Array(left)
        let rhs = Array(right)
        let n = lhs.count
        let m = rhs.count
        if n == 0 || m == 0 {
            return (
                left: n == 0 ? [] : [DiffTextSpan(start: 0, end: n)],
                right: m == 0 ? [] : [DiffTextSpan(start: 0, end: m)]
            )
        }

        var dp = Array(repeating: Array(repeating: 0, count: m + 1), count: n + 1)
        for i in 1...n {
            for j in 1...m {
                if lhs[i - 1] == rhs[j - 1] {
                    dp[i][j] = dp[i - 1][j - 1] + 1
                } else {
                    dp[i][j] = max(dp[i - 1][j], dp[i][j - 1])
                }
            }
        }

        let lcsLength = dp[n][m]
        let maxLen = max(n, m)
        let similarity = Double(lcsLength) / Double(maxLen)
        guard similarity >= 0.35, lcsLength < maxLen else {
            return (left: [], right: [])
        }

        var lhsCommon = Array(repeating: false, count: n)
        var rhsCommon = Array(repeating: false, count: m)
        var i = n
        var j = m

        while i > 0, j > 0 {
            if lhs[i - 1] == rhs[j - 1] {
                lhsCommon[i - 1] = true
                rhsCommon[j - 1] = true
                i -= 1
                j -= 1
            } else if dp[i - 1][j] >= dp[i][j - 1] {
                i -= 1
            } else {
                j -= 1
            }
        }

        let leftSpans = contiguousSpans(from: lhsCommon)
        let rightSpans = contiguousSpans(from: rhsCommon)
        return (left: leftSpans, right: rightSpans)
    }

    private func contiguousSpans(from commonMask: [Bool]) -> [DiffTextSpan] {
        var spans: [DiffTextSpan] = []
        var cursor = 0

        while cursor < commonMask.count {
            guard !commonMask[cursor] else {
                cursor += 1
                continue
            }

            let start = cursor
            while cursor < commonMask.count, !commonMask[cursor] {
                cursor += 1
            }
            spans.append(DiffTextSpan(start: start, end: cursor))
        }

        return spans
    }
}
