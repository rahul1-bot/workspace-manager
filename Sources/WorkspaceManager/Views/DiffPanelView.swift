import SwiftUI

struct DiffPanelView: View {
    let state: GitPanelState
    let isResizing: Bool
    let worktreeBaselines: [WorktreeComparisonBaseline]
    let onClose: () -> Void
    let onModeSelected: (DiffPanelMode) -> Void
    let onWorktreeBaselineSelected: (WorktreeComparisonBaseline) -> Void

    @State private var document: DiffDocument = .empty
    @State private var collapsedSectionIDs: Set<String> = []

    private static let syntaxService = DiffSyntaxHighlightingService()

    private enum DiffChromeStyle {
        static let outerStrokeOpacity: Double = 0.12
        static let dividerOpacity: Double = 0.08
        static let darkOverlayOpacity: Double = 0.45
        static let headerFillOpacity: Double = 0.04
        static let summaryFillOpacity: Double = 0.06
        static let contentStrokeOpacity: Double = 0.08
        static let resizingFillOpacity: Double = 0.45
    }

    var body: some View {
        VStack(spacing: 0) {
            headerView

            Divider()
                .overlay(Color.white.opacity(DiffChromeStyle.dividerOpacity))

            VStack(alignment: .leading, spacing: 10) {
                summaryView
                contentView
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .frame(maxHeight: .infinity)
        .background(panelBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 0, style: .continuous)
                .stroke(Color.white.opacity(DiffChromeStyle.outerStrokeOpacity), lineWidth: 1)
        )
        .task(id: state.patchText) {
            await rebuildDocument(from: state.patchText)
        }
    }

    private var panelBackground: some View {
        ZStack {
            if isResizing {
                Color.black.opacity(DiffChromeStyle.resizingFillOpacity)
            } else {
                VisualEffectBackground(material: .hudWindow, blendingMode: .behindWindow)
                Color.black.opacity(DiffChromeStyle.darkOverlayOpacity)
            }
        }
    }

    private var headerView: some View {
        HStack {
            Menu {
                ForEach(DiffPanelMode.allCases, id: \.self) { mode in
                    Button(mode.title) {
                        onModeSelected(mode)
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(state.mode.title)
                        .font(.system(.headline, design: .default))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundColor(.white.opacity(0.95))
            }
            .menuStyle(.borderlessButton)

            if state.mode == .worktreeComparison {
                Menu {
                    ForEach(worktreeBaselines, id: \.self) { baseline in
                        Button(baseline.title) {
                            onWorktreeBaselineSelected(baseline)
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(state.baselineLabel ?? "Select baseline")
                            .font(.system(.subheadline, design: .default))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(.white.opacity(0.8))
                }
                .menuStyle(.borderlessButton)
            }

            Spacer()

            Button(action: onClose) {
                Text("Esc")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.55))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.white.opacity(DiffChromeStyle.headerFillOpacity))
    }

    private var summaryView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Text("\(state.summary.filesChanged) files")
                    .foregroundColor(.white.opacity(0.75))
                Text("+\(state.summary.additions)")
                    .foregroundColor(.green)
                Text("-\(state.summary.deletions)")
                    .foregroundColor(.red)
            }
            if state.mode == .worktreeComparison, let baselineLabel = state.baselineLabel {
                Text(baselineLabel)
                    .foregroundColor(.white.opacity(0.62))
            }
        }
        .font(.system(.caption, design: .monospaced))
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.white.opacity(DiffChromeStyle.summaryFillOpacity))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    @ViewBuilder
    private var contentView: some View {
        if let errorText = state.errorText {
            Text(errorText)
                .font(.system(.callout, design: .default))
                .foregroundColor(.red.opacity(0.85))
        } else if state.isLoading {
            ProgressView("Loading diff…")
                .tint(.white)
                .foregroundColor(.white.opacity(0.7))
        } else if state.patchText.isEmpty || document.fileSections.isEmpty {
            Text("No changes for the selected mode.")
                .font(.system(.callout, design: .default))
                .foregroundColor(.white.opacity(0.7))
        } else if isResizing {
            resizingPlaceholderView
        } else {
            patchContentView
        }
    }

    private var patchContentView: some View {
        GeometryReader { geometry in
            let viewportWidth = max(geometry.size.width, 1)

            ScrollView(.vertical) {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(document.fileSections) { section in
                        DiffFileCardView(
                            section: section,
                            viewportWidth: viewportWidth - 4,
                            isCollapsed: collapsedSectionIDs.contains(section.id),
                            onToggleCollapsed: {
                                toggleCollapsedSection(section.id)
                            },
                            syntaxService: Self.syntaxService
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 2)
                .padding(.vertical, 2)
            }
        }
        .textSelection(.enabled)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.white.opacity(DiffChromeStyle.contentStrokeOpacity), lineWidth: 1)
        )
    }

    private var resizingPlaceholderView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Resizing diff panel", systemImage: "arrow.left.and.right")
                .font(.system(.footnote, design: .monospaced))
                .foregroundColor(.white.opacity(0.72))

            ForEach(0..<4, id: \.self) { index in
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.white.opacity(0.06))
                    .frame(height: index == 0 ? 24 : 18)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.25))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private func toggleCollapsedSection(_ sectionID: String) {
        if collapsedSectionIDs.contains(sectionID) {
            collapsedSectionIDs.remove(sectionID)
        } else {
            collapsedSectionIDs.insert(sectionID)
        }
    }

    private func rebuildDocument(from patchText: String) async {
        let parsed = await Task.detached(priority: .userInitiated) {
            DiffPatchParser().parse(patchText)
        }.value

        await MainActor.run {
            document = parsed
            let validIDs = Set(parsed.fileSections.map(\.id))
            collapsedSectionIDs = collapsedSectionIDs.intersection(validIDs)
        }
    }
}
