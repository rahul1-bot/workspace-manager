import SwiftUI

struct WorkspaceSidebar: View {
    @EnvironmentObject var appState: AppState
    @State private var newWorkspaceName: String = ""
    @State private var newWorkspacePath: String = ""
    @State private var newWorkspaceError: String?
    @State private var newTerminalName: String = ""
    @State private var workspaceForNewTerminal: Workspace?

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
                            onToggleExpand: {
                                appState.toggleWorkspaceExpanded(id: workspace.id)
                            },
                            onSelect: {
                                appState.selectedWorkspaceId = workspace.id
                            },
                            onNewTerminal: {
                                workspaceForNewTerminal = workspace
                                appState.showNewTerminalSheet = true
                            },
                            onSelectTerminal: { terminal in
                                appState.selectTerminal(id: terminal.id, in: workspace.id)
                            },
                            selectedTerminalId: appState.selectedTerminalId
                        )
                    }
                }
                .padding(.vertical, 4)
            }
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
                    let defaultPath = ConfigService.shared.config.workspaces.first?.path
                        ?? FileManager.default.homeDirectoryForCurrentUser.path
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
}

struct WorkspaceRow: View {
    let workspace: Workspace
    let isSelected: Bool
    let onToggleExpand: () -> Void
    let onSelect: () -> Void
    let onNewTerminal: () -> Void
    let onSelectTerminal: (Terminal) -> Void
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

                Text(displayName)
                    .font(.system(.body, design: .default))
                    .lineLimit(1)
                    .truncationMode(.middle)

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
            .onTapGesture {
                onSelect()
            }

            // Terminals
            if workspace.isExpanded {
                ForEach(workspace.terminals) { terminal in
                    TerminalRow(
                        terminal: terminal,
                        isSelected: selectedTerminalId == terminal.id,
                        onSelect: { onSelectTerminal(terminal) }
                    )
                }
            }
        }
        .padding(.horizontal, 4)
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
    let onSelect: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(terminal.isActive ? Color.green : Color.gray.opacity(0.5))
                .frame(width: 8, height: 8)

            Image(systemName: "terminal")
                .font(.caption2)
                .foregroundColor(.secondary)

            Text(terminal.name)
                .font(.system(.callout, design: .default))
                .lineLimit(1)

            Spacer()
        }
        .padding(.leading, 28)
        .padding(.trailing, 8)
        .padding(.vertical, 4)
        .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        .cornerRadius(4)
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
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
