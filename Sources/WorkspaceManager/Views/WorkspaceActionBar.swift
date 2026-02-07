import SwiftUI

struct WorkspaceActionBar: View {
    @EnvironmentObject var appState: AppState
    let workspaceID: UUID?
    let terminalID: UUID

    private var openDisabled: Bool {
        appState.actionTargetURL(for: terminalID) == nil || appState.availableEditors.isEmpty
    }

    private var commitDisabled: Bool {
        appState.commitSheetState.disabledReason != nil
    }

    private var diffDisabled: Bool {
        appState.gitPanelState.disabledReason != nil
    }

    private var worktreeDisabled: Bool {
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
                        appState.handleOpenActionPlaceholder(editor: editor, workspaceID: workspaceID, terminalID: terminalID)
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
                WorkspaceActionPill(icon: "point.topleft.down.curvedto.point.bottomright.up", title: "Commit", showsChevron: false, isDisabled: commitDisabled)
            }
            .buttonStyle(.plain)
            .disabled(commitDisabled)
            .help(appState.commitSheetState.disabledReason?.title ?? "Commit changes")

            Button {
                appState.toggleDiffPanelPlaceholder()
            } label: {
                WorkspaceActionPill(icon: "line.3.horizontal.decrease.circle", title: "Toggle diff panel", showsChevron: false, isDisabled: diffDisabled)
            }
            .buttonStyle(.plain)
            .disabled(diffDisabled)
            .help(appState.gitPanelState.disabledReason?.title ?? "Toggle diff panel")

            Menu {
                Button("Refresh worktrees") {
                    appState.refreshWorktreeCatalogForSelection()
                }
                Button("New worktree") {
                    appState.presentCreateWorktreeSheet()
                }
                Button("Compare current worktree") {
                    appState.openWorktreeComparisonPanel()
                }
                .disabled(appState.currentWorktreeDescriptor() == nil)

                if let catalog = appState.worktreeCatalog, !catalog.siblingDescriptors.isEmpty {
                    Divider()
                    ForEach(catalog.siblingDescriptors) { descriptor in
                        Button("Compare vs \(descriptor.branchName)") {
                            appState.compareAgainstWorktree(descriptor)
                        }
                    }
                }
            } label: {
                WorkspaceActionPill(icon: "point.3.connected.trianglepath.dotted", title: "Worktrees", showsChevron: true, isDisabled: worktreeDisabled)
            }
            .menuStyle(.borderlessButton)
            .disabled(worktreeDisabled)
            .help(appState.gitPanelState.disabledReason?.title ?? "Worktree actions")

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
