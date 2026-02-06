import SwiftUI

struct DiffPanelView: View {
    let state: GitPanelState
    let onClose: () -> Void
    let onModeSelected: (DiffPanelMode) -> Void

    @State private var document: DiffDocument = .empty
    @State private var collapsedSectionIDs: Set<String> = []

    private static let syntaxService = DiffSyntaxHighlightingService()

    var body: some View {
        VStack(spacing: 0) {
            headerView

            Divider()
                .overlay(Color.white.opacity(0.08))

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
                .stroke(Color.white.opacity(0.16), lineWidth: 1)
        )
        .task(id: state.patchText) {
            await rebuildDocument(from: state.patchText)
        }
    }

    private var panelBackground: some View {
        ZStack {
            VisualEffectBackground(material: .hudWindow, blendingMode: .behindWindow)
            LinearGradient(
                colors: [
                    Color.black.opacity(0.28),
                    Color.black.opacity(0.18)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
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

            Spacer()

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.85))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.03))
    }

    private var summaryView: some View {
        HStack(spacing: 10) {
            Text("\(state.summary.filesChanged) files")
                .foregroundColor(.white.opacity(0.75))
            Text("+\(state.summary.additions)")
                .foregroundColor(.green)
            Text("-\(state.summary.deletions)")
                .foregroundColor(.red)
        }
        .font(.system(.caption, design: .monospaced))
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.03))
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
        } else {
            patchContentView
        }
    }

    private var patchContentView: some View {
        ScrollView([.vertical, .horizontal]) {
            LazyVStack(alignment: .leading, spacing: 10) {
                ForEach(document.fileSections) { section in
                    DiffFileCardView(
                        section: section,
                        isCollapsed: collapsedSectionIDs.contains(section.id),
                        onToggleCollapsed: {
                            toggleCollapsedSection(section.id)
                        },
                        syntaxService: Self.syntaxService
                    )
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 2)
        }
        .textSelection(.enabled)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
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
