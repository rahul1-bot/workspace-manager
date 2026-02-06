import SwiftUI

struct WorkspaceActionBar: View {
    @EnvironmentObject var appState: AppState
    let workspaceID: UUID?
    let workspaceURL: URL?

    private var openDisabled: Bool {
        workspaceURL == nil || appState.availableEditors.isEmpty
    }

    private var commitDisabled: Bool {
        appState.commitSheetState.disabledReason != nil
    }

    private var diffDisabled: Bool {
        appState.gitPanelState.disabledReason != nil
    }

    private var isNonGitRepository: Bool {
        appState.gitPanelState.disabledReason == .notGitRepository
    }

    var body: some View {
        HStack(spacing: 8) {
            Menu {
                ForEach(appState.availableEditors, id: \.self) { editor in
                    Button(editor.title) {
                        appState.handleOpenActionPlaceholder(editor: editor, workspaceID: workspaceID)
                    }
                    .disabled(openDisabled)
                }
            } label: {
                WorkspaceActionPill(icon: "rectangle.3.offgrid", title: "Open", showsChevron: true, isDisabled: openDisabled)
            }
            .menuStyle(.borderlessButton)
            .disabled(openDisabled)

            Button {
                appState.presentCommitSheetPlaceholder()
            } label: {
                WorkspaceActionPill(icon: "point.topleft.down.curvedto.point.bottomright.up", title: "Commit", showsChevron: true, isDisabled: commitDisabled)
            }
            .buttonStyle(.plain)
            .disabled(commitDisabled)
            .help(appState.commitSheetState.disabledReason?.title ?? "Commit changes")

            Divider()
                .frame(height: 22)
                .overlay(Color.white.opacity(0.15))

            Button {
                appState.toggleDiffPanelPlaceholder()
            } label: {
                WorkspaceActionPill(icon: "line.3.horizontal.decrease.circle", title: "Toggle diff panel", showsChevron: false, isDisabled: diffDisabled)
            }
            .buttonStyle(.plain)
            .disabled(diffDisabled)
            .help(appState.gitPanelState.disabledReason?.title ?? "Toggle diff panel")

            if isNonGitRepository {
                Button {
                    appState.initializeGitRepositoryPlaceholder()
                } label: {
                    WorkspaceActionPill(icon: "plus.circle", title: "Initialize git", showsChevron: false, isDisabled: false)
                }
                .buttonStyle(.plain)
                .help("Initialize git repository")
            }
        }
    }
}

private struct WorkspaceActionPill: View {
    let icon: String
    let title: String
    let showsChevron: Bool
    let isDisabled: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
            Text(title)
                .font(.system(size: 14, weight: .semibold, design: .default))
            if showsChevron {
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
            }
        }
        .foregroundColor(isDisabled ? Color.white.opacity(0.35) : Color.white.opacity(0.9))
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            Capsule(style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(Color.white.opacity(isDisabled ? 0.09 : 0.16), lineWidth: 1)
        )
    }
}
