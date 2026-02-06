import SwiftUI

struct DiffFileCardView: View {
    let section: DiffFileSection
    let viewportWidth: CGFloat
    let isCollapsed: Bool
    let onToggleCollapsed: () -> Void
    let syntaxService: DiffSyntaxHighlightingService

    private enum CardChromeStyle {
        static let cardFillOpacity: Double = 0.012
        static let cardStrokeOpacity: Double = 0.06
        static let headerFillOpacity: Double = 0.014
    }

    var body: some View {
        VStack(spacing: 0) {
            headerView

            if !isCollapsed {
                contentView
            }
        }
        .background(Color.white.opacity(CardChromeStyle.cardFillOpacity))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.white.opacity(CardChromeStyle.cardStrokeOpacity), lineWidth: 1)
        )
        .frame(minWidth: max(viewportWidth, 1), alignment: .leading)
    }

    private var headerView: some View {
        Button(action: onToggleCollapsed) {
            HStack(spacing: 8) {
                Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.85))

                Text(section.displayPath)
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.95))
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer(minLength: 8)

                Text("+\(section.additions)")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(Color.green.opacity(0.92))

                Text("-\(section.deletions)")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(Color.red.opacity(0.92))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.white.opacity(CardChromeStyle.headerFillOpacity))
        }
        .buttonStyle(.plain)
    }

    private var contentView: some View {
        VStack(spacing: 8) {
            if !section.metadataLines.isEmpty {
                metadataBlock
            }

            ForEach(section.hunks) { hunk in
                hunkBlock(for: hunk)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
    }

    private var metadataBlock: some View {
        ScrollView(.horizontal) {
            VStack(spacing: 0) {
                ForEach(section.metadataLines) { line in
                    DiffCodeRowView(
                        line: line,
                        fileExtension: section.fileExtension,
                        minimumRowWidth: max(viewportWidth - 32, 1),
                        syntaxService: syntaxService
                    )
                }
            }
        }
        .background(Color.black.opacity(0.76))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private func hunkBlock(for hunk: DiffHunk) -> some View {
        ScrollView(.horizontal) {
            VStack(spacing: 0) {
                DiffCodeRowView(
                    line: hunkHeaderLine(for: hunk),
                    fileExtension: section.fileExtension,
                    minimumRowWidth: max(viewportWidth - 32, 1),
                    syntaxService: syntaxService
                )

                ForEach(hunk.lines) { line in
                    DiffCodeRowView(
                        line: line,
                        fileExtension: section.fileExtension,
                        minimumRowWidth: max(viewportWidth - 32, 1),
                        syntaxService: syntaxService
                    )
                }
            }
        }
        .background(Color.black.opacity(0.82))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }

    private func hunkHeaderLine(for hunk: DiffHunk) -> DiffRenderableLine {
        DiffRenderableLine(
            id: "\(hunk.id)-header",
            kind: .hunkHeader,
            rawText: hunk.headerText,
            codeText: hunk.headerText,
            oldLineNumber: nil,
            newLineNumber: nil,
            isNoNewlineMarker: false
        )
    }
}
