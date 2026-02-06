import SwiftUI

struct DiffCodeRowView: View {
    let line: DiffRenderableLine
    let fileExtension: String?
    let minimumRowWidth: CGFloat
    let syntaxService: DiffSyntaxHighlightingService

    @State private var tokens: [DiffToken] = []

    var body: some View {
        Group {
            if line.showsLineNumbers {
                codeRow
            } else {
                metadataRow
            }
        }
        .font(.system(size: 12, weight: .medium, design: .monospaced))
        .padding(.horizontal, 8)
        .padding(.vertical, 1)
        .frame(minWidth: max(minimumRowWidth, 1), alignment: .leading)
        .background(backgroundColor)
        .task(id: taskIdentity) {
            await loadTokens()
        }
    }

    private var codeRow: some View {
        HStack(spacing: 0) {
            Text(markerText)
                .foregroundColor(markerColor)
                .frame(width: 16, alignment: .center)

            lineNumberText(line.oldLineNumber)
                .frame(width: 54, alignment: .trailing)

            lineNumberText(line.newLineNumber)
                .frame(width: 54, alignment: .trailing)

            renderedCodeText
                .fixedSize(horizontal: true, vertical: false)
        }
    }

    private var metadataRow: some View {
        HStack(spacing: 8) {
            Text(markerText)
                .foregroundColor(markerColor)
                .frame(width: 16, alignment: .center)

            Text(verbatim: line.rawText)
                .foregroundColor(nonCodeForegroundColor)
                .fixedSize(horizontal: true, vertical: false)
        }
    }

    private var taskIdentity: String {
        "\(line.id)-\(fileExtension ?? "none")-\(line.codeText)"
    }

    private func lineNumberText(_ value: Int?) -> Text {
        guard line.showsLineNumbers, let value else {
            return Text(verbatim: "")
                .foregroundColor(.white.opacity(0.2))
        }

        return Text(verbatim: String(value))
            .foregroundColor(.white.opacity(0.38))
    }

    private var renderedCodeText: Text {
        let activeTokens = tokens.isEmpty
            ? [DiffToken(text: line.codeText, tokenClass: .plain, start: 0, end: line.codeText.count)]
            : tokens

        return activeTokens.reduce(Text("")) { partial, token in
            var fragment = Text(verbatim: token.text)
                .foregroundColor(tokenColor(for: token.tokenClass))

            if hasEmphasis(start: token.start, end: token.end) {
                fragment = fragment.underline(true, color: emphasisColor)
            }

            return partial + fragment
        }
    }

    private var markerText: String {
        switch line.kind {
        case .addition:
            return "+"
        case .deletion:
            return "-"
        case .context:
            return " "
        case .hunkHeader:
            return "@"
        case .oldFilePath:
            return "-"
        case .newFilePath:
            return "+"
        case .noNewlineMarker:
            return "\\"
        case .fileHeader:
            return "ƒ"
        case .fileMeta:
            return "·"
        }
    }

    private var markerColor: Color {
        switch line.kind {
        case .addition, .newFilePath:
            return Color.green.opacity(0.9)
        case .deletion, .oldFilePath:
            return Color.red.opacity(0.9)
        case .hunkHeader:
            return Color.orange.opacity(0.9)
        case .fileHeader:
            return Color.white.opacity(0.85)
        case .fileMeta, .noNewlineMarker:
            return Color.white.opacity(0.55)
        case .context:
            return Color.white.opacity(0.35)
        }
    }

    private var nonCodeForegroundColor: Color {
        switch line.kind {
        case .fileHeader:
            return Color.white.opacity(0.95)
        case .oldFilePath:
            return Color.cyan.opacity(0.88)
        case .newFilePath:
            return Color.cyan.opacity(0.95)
        case .hunkHeader:
            return Color.orange.opacity(0.95)
        case .fileMeta, .noNewlineMarker:
            return Color.white.opacity(0.65)
        case .context, .addition, .deletion:
            return Color.white.opacity(0.9)
        }
    }

    private var backgroundColor: Color {
        switch line.kind {
        case .addition:
            return Color.green.opacity(0.16)
        case .deletion:
            return Color.red.opacity(0.16)
        case .context:
            return Color.white.opacity(0.01)
        case .hunkHeader:
            return Color.orange.opacity(0.18)
        case .fileHeader:
            return Color.white.opacity(0.08)
        case .oldFilePath, .newFilePath:
            return Color.cyan.opacity(0.14)
        case .fileMeta:
            return Color.white.opacity(0.03)
        case .noNewlineMarker:
            return Color.white.opacity(0.04)
        }
    }

    private var emphasisColor: Color {
        switch line.kind {
        case .addition:
            return Color.green.opacity(0.95)
        case .deletion:
            return Color.red.opacity(0.95)
        default:
            return Color.yellow.opacity(0.9)
        }
    }

    private func hasEmphasis(start: Int, end: Int) -> Bool {
        line.emphasisSpans.contains { $0.overlaps(start: start, end: end) }
    }

    private func tokenColor(for tokenClass: DiffTokenClass) -> Color {
        switch tokenClass {
        case .keyword:
            return Color.purple.opacity(0.95)
        case .string:
            return Color.orange.opacity(0.95)
        case .number:
            return Color.mint.opacity(0.95)
        case .comment:
            return Color.gray.opacity(0.92)
        case .punctuation:
            return Color.white.opacity(0.88)
        case .heading:
            return Color.yellow.opacity(0.95)
        case .codeSpan:
            return Color.teal.opacity(0.95)
        case .plain:
            if line.kind == .addition {
                return Color.green.opacity(0.95)
            }
            if line.kind == .deletion {
                return Color.red.opacity(0.95)
            }
            return Color(red: 0.86, green: 0.89, blue: 0.94)
        }
    }

    private func loadTokens() async {
        guard line.showsLineNumbers else {
            await MainActor.run {
                tokens = []
            }
            return
        }

        let generated = await syntaxService.tokens(for: line, fileExtension: fileExtension)
        await MainActor.run {
            tokens = generated
        }
    }
}
