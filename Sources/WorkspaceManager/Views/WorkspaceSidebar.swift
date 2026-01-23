import SwiftUI
import AppKit

enum RenameField: Hashable {
    case workspace(UUID)
    case terminal(UUID)
}

struct WorkspaceSidebar: View {
    @EnvironmentObject var appState: AppState
    @State private var newWorkspaceName: String = ""
    @State private var newWorkspacePath: String = ""
    @State private var newWorkspaceError: String?
    @State private var newTerminalName: String = ""
    @State private var workspaceForNewTerminal: Workspace?
    @State private var renameText: String = ""
    @State private var renameError: String?
    @FocusState private var renameFocus: RenameField?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("WORKSPACES")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)

                Spacer()

                Button(action: { appState.showNewWorkspaceSheet = true }) {
                    Image(systemName: "plus")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            // Workspace list
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(appState.workspaces) { workspace in
                        WorkspaceRow(
                            workspace: workspace,
                            isSelected: appState.selectedWorkspaceId == workspace.id,
                            renamingWorkspaceId: appState.renamingWorkspaceId,
                            renamingTerminalId: appState.renamingTerminalId,
                            renameText: $renameText,
                            renameError: $renameError,
                            renameFocus: $renameFocus,
                            onToggleExpand: {
                                appState.toggleWorkspaceExpanded(id: workspace.id)
                            },
                            onSelect: {
                                appState.selectedWorkspaceId = workspace.id
                            },
                            onBeginRenameWorkspace: {
                                appState.beginRenameWorkspace(id: workspace.id)
                            },
                            onCommitRenameWorkspace: {
                                let success = appState.renameWorkspace(id: workspace.id, newName: renameText)
                                if success {
                                    renameError = nil
                                    appState.cancelRenaming()
                                } else {
                                    renameError = "Workspace name must be unique and non-empty"
                                }
                            },
                            onCancelRename: {
                                renameError = nil
                                appState.cancelRenaming()
                            },
                            onNewTerminal: {
                                workspaceForNewTerminal = workspace
                                appState.showNewTerminalSheet = true
                            },
                            onSelectTerminal: { terminal in
                                appState.selectTerminal(id: terminal.id, in: workspace.id)
                            },
                            onBeginRenameTerminal: { terminal in
                                appState.selectTerminal(id: terminal.id, in: workspace.id)
                                appState.beginRenameTerminal(id: terminal.id)
                            },
                            onCommitRenameTerminal: { terminal in
                                let success = appState.renameTerminal(id: terminal.id, newName: renameText)
                                if success {
                                    renameError = nil
                                    appState.cancelRenaming()
                                } else {
                                    renameError = "Terminal name cannot be empty"
                                }
                            },
                            selectedTerminalId: appState.selectedTerminalId
                        )
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .onAppear {
            syncRenameStateFromApp()
        }
        .onChange(of: appState.renamingWorkspaceId) {
            syncRenameStateFromApp()
        }
        .onChange(of: appState.renamingTerminalId) {
            syncRenameStateFromApp()
        }
        .sheet(isPresented: $appState.showNewWorkspaceSheet) {
            NewWorkspaceSheet(
                name: $newWorkspaceName,
                path: $newWorkspacePath,
                errorMessage: $newWorkspaceError,
                onCancel: {
                    appState.showNewWorkspaceSheet = false
                    newWorkspaceName = ""
                    newWorkspacePath = ""
                    newWorkspaceError = nil
                },
                onCreate: {
                    let trimmedName = newWorkspaceName.trimmingCharacters(in: .whitespaces)

                    // Validate name
                    if trimmedName.isEmpty {
                        newWorkspaceError = "Workspace name cannot be empty"
                        return
                    }

                    // Check for duplicate name
                    if appState.workspaces.contains(where: { $0.name == trimmedName }) {
                        newWorkspaceError = "A workspace with this name already exists"
                        return
                    }

                    // Use first workspace path from config as default, or home directory
                    let defaultPath = ConfigService.preferredWorkspaceRoot
                    let path = newWorkspacePath.isEmpty ? defaultPath : newWorkspacePath

                    // Try to add workspace
                    let success = appState.addWorkspace(name: trimmedName, path: path)
                    if success {
                        appState.showNewWorkspaceSheet = false
                        newWorkspaceName = ""
                        newWorkspacePath = ""
                        newWorkspaceError = nil
                    } else {
                        newWorkspaceError = "Failed to create workspace"
                    }
                }
            )
        }
        .sheet(isPresented: $appState.showNewTerminalSheet) {
            NewTerminalSheet(
                name: $newTerminalName,
                workspaceName: workspaceForNewTerminal?.name ?? "",
                onCancel: {
                    appState.showNewTerminalSheet = false
                    newTerminalName = ""
                },
                onCreate: {
                    if let workspace = workspaceForNewTerminal {
                        let name = newTerminalName.isEmpty ? "Terminal" : newTerminalName
                        appState.addTerminal(to: workspace.id, name: name)
                    }
                    appState.showNewTerminalSheet = false
                    newTerminalName = ""
                }
            )
        }
    }

    private func syncRenameStateFromApp() {
        if let wsId = appState.renamingWorkspaceId,
           let ws = appState.workspaces.first(where: { $0.id == wsId }) {
            renameText = ws.name
            renameError = nil
            renameFocus = .workspace(wsId)
            return
        }

        if let tId = appState.renamingTerminalId,
           let ws = appState.workspaces.first(where: { $0.terminals.contains(where: { $0.id == tId }) }),
           let terminal = ws.terminals.first(where: { $0.id == tId }) {
            renameText = terminal.name
            renameError = nil
            renameFocus = .terminal(tId)
            return
        }

        renameFocus = nil
    }
}

struct WorkspaceRow: View {
    let workspace: Workspace
    let isSelected: Bool
    let renamingWorkspaceId: UUID?
    let renamingTerminalId: UUID?
    @Binding var renameText: String
    @Binding var renameError: String?
    let renameFocus: FocusState<RenameField?>.Binding
    let onToggleExpand: () -> Void
    let onSelect: () -> Void
    let onBeginRenameWorkspace: () -> Void
    let onCommitRenameWorkspace: () -> Void
    let onCancelRename: () -> Void
    let onNewTerminal: () -> Void
    let onSelectTerminal: (Terminal) -> Void
    let onBeginRenameTerminal: (Terminal) -> Void
    let onCommitRenameTerminal: (Terminal) -> Void
    let selectedTerminalId: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Workspace header
            HStack(spacing: 4) {
                Button(action: onToggleExpand) {
                    Image(systemName: workspace.isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption2)
                        .frame(width: 12)
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)

                Image(systemName: "folder.fill")
                    .font(.caption)
                    .foregroundColor(.blue)

                if isRenamingWorkspace {
                    TextField("", text: $renameText)
                        .textFieldStyle(.plain)
                        .font(.system(.body, design: .default))
                        .focused(renameFocus, equals: .workspace(workspace.id))
                        .onSubmit { onCommitRenameWorkspace() }
                        .onExitCommand { onCancelRename() }
                        .onChange(of: renameText) {
                            renameError = nil
                        }
                } else {
                    Text(displayName)
                        .font(.system(.body, design: .default))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer()

                Button(action: onNewTerminal) {
                    Image(systemName: "plus.circle")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                .opacity(isSelected ? 1 : 0)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
            .cornerRadius(4)
            .contentShape(Rectangle())
            .highPriorityGesture(
                TapGesture(count: 2).onEnded {
                    onBeginRenameWorkspace()
                }
            )
            .onTapGesture {
                onSelect()
            }

            // Terminals
            if workspace.isExpanded {
                ForEach(workspace.terminals) { terminal in
                    TerminalRow(
                        terminal: terminal,
                        isSelected: selectedTerminalId == terminal.id,
                        isRenaming: renamingTerminalId == terminal.id,
                        renameText: $renameText,
                        renameError: $renameError,
                        renameFocus: renameFocus,
                        onSelect: { onSelectTerminal(terminal) },
                        onBeginRename: { onBeginRenameTerminal(terminal) },
                        onCommitRename: { onCommitRenameTerminal(terminal) },
                        onCancelRename: { onCancelRename() }
                    )
                }
            }

            if isRenamingWorkspace, let error = renameError {
                Text(error)
                    .font(.caption2)
                    .foregroundColor(.red)
                    .padding(.leading, 28)
                    .padding(.top, 2)
            }
        }
        .padding(.horizontal, 4)
    }

    private var isRenamingWorkspace: Bool {
        renamingWorkspaceId == workspace.id
    }

    var displayName: String {
        let name = workspace.name
        if name.count > 35 {
            return String(name.prefix(32)) + "..."
        }
        return name
    }
}

struct TerminalRow: View {
    let terminal: Terminal
    let isSelected: Bool
    let isRenaming: Bool
    @Binding var renameText: String
    @Binding var renameError: String?
    let renameFocus: FocusState<RenameField?>.Binding
    let onSelect: () -> Void
    let onBeginRename: () -> Void
    let onCommitRename: () -> Void
    let onCancelRename: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Circle()
                    .fill(terminal.isActive ? Color.green : Color.gray.opacity(0.5))
                    .frame(width: 8, height: 8)

                TerminalIcon()
                    .frame(width: 14, height: 14)

                if isRenaming {
                    TextField("", text: $renameText)
                        .textFieldStyle(.plain)
                        .font(.system(.callout, design: .default))
                        .focused(renameFocus, equals: .terminal(terminal.id))
                        .onSubmit { onCommitRename() }
                        .onExitCommand { onCancelRename() }
                        .onChange(of: renameText) {
                            renameError = nil
                        }
                } else {
                    Text(terminal.name)
                        .font(.system(.callout, design: .default))
                        .lineLimit(1)
                }

                Spacer()
            }
            .padding(.leading, 28)
            .padding(.trailing, 8)
            .padding(.vertical, 4)
            .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
            .cornerRadius(4)
            .contentShape(Rectangle())
            .highPriorityGesture(
                TapGesture(count: 2).onEnded {
                    onBeginRename()
                }
            )
            .onTapGesture {
                onSelect()
            }

            if isRenaming, let error = renameError {
                Text(error)
                    .font(.caption2)
                    .foregroundColor(.red)
                    .padding(.leading, 28)
                    .padding(.top, 2)
            }
        }
    }
}

private struct TerminalIcon: View {
    var body: some View {
        if let image = iconImage {
            Image(nsImage: image)
                .resizable()
                .renderingMode(.original)
                .aspectRatio(contentMode: .fit)
        } else {
            Image(systemName: "terminal")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    private var iconImage: NSImage? {
        guard let url = Bundle.module.url(forResource: "terminal-icon", withExtension: "png") else {
            return nil
        }
        return NSImage(contentsOf: url)
    }
}

struct NewWorkspaceSheet: View {
    @Binding var name: String
    @Binding var path: String
    @Binding var errorMessage: String?
    let onCancel: () -> Void
    let onCreate: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("New Workspace")
                .font(.headline)

            TextField("Workspace name", text: $name)
                .textFieldStyle(.roundedBorder)
                .onChange(of: name) {
                    errorMessage = nil  // Clear error when user types
                }

            TextField("Path (optional)", text: $path)
                .textFieldStyle(.roundedBorder)

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            HStack {
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)

                Button("Create", action: onCreate)
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 350)
    }
}

struct NewTerminalSheet: View {
    @Binding var name: String
    let workspaceName: String
    let onCancel: () -> Void
    let onCreate: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("New Terminal")
                .font(.headline)

            Text("in \(workspaceName)")
                .font(.subheadline)
                .foregroundColor(.secondary)

            TextField("Terminal name (e.g., Main, Git, Server)", text: $name)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)

                Button("Create", action: onCreate)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 350)
    }
}
