import SwiftUI
import SwiftTerm
import AppKit

/// SwiftUI wrapper for SwiftTerm's LocalProcessTerminalView
struct TerminalView: NSViewRepresentable {
    let workingDirectory: String
    let terminalId: UUID

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> LocalProcessTerminalView {
        let terminalView = LocalProcessTerminalView(frame: .zero)
        context.coordinator.terminalView = terminalView

        // Configure terminal appearance
        terminalView.configureNativeColors()

        // Set font - using a nice monospace font
        let fontSize: CGFloat = 14
        let font = NSFont(name: "MesloLGS NF", size: fontSize)
            ?? NSFont(name: "SF Mono", size: fontSize)
            ?? NSFont(name: "Menlo", size: fontSize)
            ?? NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        terminalView.font = font

        // Configure terminal options (performance tuned)
        let terminal = terminalView.getTerminal()
        terminal.options.scrollback = 2000
        terminal.options.cursorStyle = .steadyBlock
        terminal.options.enableSixelReported = false

        // Start the shell process
        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path

        // Use working directory or fall back to home
        let cwd = FileManager.default.fileExists(atPath: workingDirectory) ? workingDirectory : homeDir

        // Set environment with working directory
        var env = ProcessInfo.processInfo.environment
        env["PWD"] = cwd

        terminalView.startProcess(
            executable: shell,
            args: ["-c", "cd '\(cwd)' && exec \(shell)"],
            environment: Array(env.map { "\($0.key)=\($0.value)" }),
            execName: nil
        )

        let click = NSClickGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.focusTerminal))
        terminalView.addGestureRecognizer(click)

        DispatchQueue.main.async {
            terminalView.window?.makeFirstResponder(terminalView)
        }

        return terminalView
    }

    func updateNSView(_ nsView: LocalProcessTerminalView, context: Context) {
        if nsView.window?.firstResponder !== nsView {
            DispatchQueue.main.async {
                nsView.window?.makeFirstResponder(nsView)
            }
        }
    }

    class Coordinator: NSObject {
        weak var terminalView: LocalProcessTerminalView?

        @objc func focusTerminal() {
            terminalView?.window?.makeFirstResponder(terminalView)
        }
    }
}

/// A container view that manages multiple terminal instances
struct TerminalContainer: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            if let terminal = appState.selectedTerminal,
               let workspace = appState.selectedWorkspace {
                VStack(spacing: 0) {
                    // Terminal header
                    TerminalHeader(terminal: terminal, workspace: workspace)

                    // Terminal view with focus management
                    TerminalView(
                        workingDirectory: terminal.workingDirectory,
                        terminalId: terminal.id
                    )
                    .id(terminal.id)
                }
            } else {
                EmptyTerminalView()
            }
        }
    }
}

struct TerminalHeader: View {
    let terminal: Terminal
    let workspace: Workspace

    var body: some View {
        HStack {
            Circle()
                .fill(Color.green)
                .frame(width: 8, height: 8)

            Text(terminal.name)
                .font(.system(.body, design: .monospaced))
                .fontWeight(.medium)

            Text("—")
                .foregroundColor(.secondary)

            Text(workspace.name)
                .font(.system(.callout, design: .default))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            Text(shortenedPath(workspace.path))
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor))
    }

    func shortenedPath(_ path: String) -> String {
        let components = path.split(separator: "/")
        if components.count > 4 {
            return "~/.../" + components.suffix(2).joined(separator: "/")
        }
        return path.replacingOccurrences(of: FileManager.default.homeDirectoryForCurrentUser.path, with: "~")
    }
}

struct EmptyTerminalView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "terminal")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No Terminal Selected")
                .font(.title2)
                .foregroundColor(.secondary)

            Text("Select a terminal from the sidebar or create a new one")
                .font(.callout)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 8) {
                Text("⌘T")
                    .font(.system(.caption, design: .monospaced))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.2))
                    .cornerRadius(4)

                Text("New Terminal")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.textBackgroundColor))
    }
}
