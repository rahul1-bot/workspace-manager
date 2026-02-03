import SwiftUI
import SwiftTerm
import AppKit

// MARK: - Visual Effect Background for Glass Effect
struct VisualEffectBackground: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    init(material: NSVisualEffectView.Material = .hudWindow, blendingMode: NSVisualEffectView.BlendingMode = .behindWindow) {
        self.material = material
        self.blendingMode = blendingMode
    }

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        view.isEmphasized = true
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

/// SwiftUI wrapper for SwiftTerm's LocalProcessTerminalView
struct TerminalView: NSViewRepresentable {
    let workingDirectory: String
    let terminalId: UUID
    let isSelected: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> LocalProcessTerminalView {
        let terminalView = LocalProcessTerminalView(frame: .zero)
        context.coordinator.terminalView = terminalView

        // Get terminal config from ConfigService
        let terminalConfig = ConfigService.shared.config.terminal

        // Configure terminal with transparent background for glass effect
        terminalView.wantsLayer = true
        terminalView.layer?.backgroundColor = NSColor.clear.cgColor
        terminalView.nativeBackgroundColor = NSColor(white: 0.0, alpha: 0.0)  // Fully transparent
        terminalView.nativeForegroundColor = NSColor.white

        // Set font from config
        let fontSize: CGFloat = CGFloat(terminalConfig.font_size)
        let font = NSFont(name: terminalConfig.font, size: fontSize)
            ?? NSFont(name: "Cascadia Mono", size: fontSize)
            ?? NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        terminalView.font = font

        // Note: SwiftTerm does not support custom line height/spacing

        // Configure terminal options from config
        let terminal = terminalView.getTerminal()
        terminal.options.scrollback = terminalConfig.scrollback
        terminal.options.enableSixelReported = false

        // Set cursor style from config
        let cursorStyle = parseCursorStyle(terminalConfig.cursor_style)
        terminal.setCursorStyle(cursorStyle)

        // Set caret/cursor color for visibility on transparent background
        terminalView.caretColor = NSColor.white

        // Start the shell process
        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        let preferredRoot = ConfigService.preferredWorkspaceRoot

        // Use working directory, fall back to preferred root, then home.
        let cwdCandidates = [workingDirectory, preferredRoot, homeDir]
        let cwd = cwdCandidates.first(where: { !$0.isEmpty && FileManager.default.fileExists(atPath: $0) }) ?? homeDir

        // Set environment with working directory
        var env = ProcessInfo.processInfo.environment
        env["PWD"] = cwd

        // Escape the working directory path to prevent shell injection
        // Replace single quotes with '\'' (end quote, escaped quote, start quote)
        let escapedCwd = cwd.replacingOccurrences(of: "'", with: "'\\''")

        terminalView.startProcess(
            executable: shell,
            args: ["-c", "cd '\(escapedCwd)' && exec \(shell)"],
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
        // Avoid unnecessary drawing work for non-selected terminals.
        nsView.isHidden = !isSelected

        // Only request focus if this terminal is selected
        if isSelected && nsView.window?.firstResponder !== nsView {
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

    /// Parse cursor style string from config to SwiftTerm CursorStyle
    private func parseCursorStyle(_ style: String) -> CursorStyle {
        switch style.lowercased() {
        case "bar", "steady_bar", "steadybar":
            return .steadyBar
        case "blink_bar", "blinkbar", "blinking_bar":
            return .blinkBar
        case "block", "steady_block", "steadyblock":
            return .steadyBlock
        case "blink_block", "blinkblock", "blinking_block":
            return .blinkBlock
        case "underline", "steady_underline", "steadyunderline":
            return .steadyUnderline
        case "blink_underline", "blinkunderline", "blinking_underline":
            return .blinkUnderline
        default:
            return .steadyBar
        }
    }
}

struct TerminalContainer: View {
    @EnvironmentObject var appState: AppState

    private var useGpuRenderer: Bool {
        ConfigService.shared.config.terminal.use_gpu_renderer
    }

    var body: some View {
        ZStack {
            ForEach(appState.workspaces) { workspace in
                ForEach(workspace.terminals) { terminal in
                    let isSelected = terminal.id == appState.selectedTerminal?.id

                    VStack(spacing: 0) {
                        TerminalHeader(terminalId: terminal.id, workspaceId: workspace.id)

                        if useGpuRenderer {
                            GhosttyTerminalView(
                                workingDirectory: terminal.workingDirectory,
                                terminalId: terminal.id,
                                isSelected: isSelected
                            )
                        } else {
                            TerminalView(
                                workingDirectory: terminal.workingDirectory,
                                terminalId: terminal.id,
                                isSelected: isSelected
                            )
                        }
                    }
                    .opacity(isSelected ? 1 : 0)
                    .allowsHitTesting(isSelected)
                }
            }

            if appState.selectedTerminal == nil {
                EmptyTerminalView()
            }
        }
    }
}

struct TerminalHeader: View {
    @EnvironmentObject var appState: AppState
    let terminalId: UUID
    let workspaceId: UUID

    private var workspace: Workspace? {
        appState.workspaces.first(where: { $0.id == workspaceId })
    }

    private var terminal: Terminal? {
        workspace?.terminals.first(where: { $0.id == terminalId })
    }

    var body: some View {
        HStack {
            Circle()
                .fill(Color.green)
                .frame(width: 8, height: 8)

            Text(terminal?.name ?? "Terminal")
                .font(.system(.body, design: .monospaced))
                .fontWeight(.medium)
                .foregroundColor(.white)

            Text("—")
                .foregroundColor(.white.opacity(0.6))

            Text(workspace?.name ?? "")
                .font(.system(.callout, design: .default))
                .foregroundColor(.white.opacity(0.8))
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            Text(shortenedPath(workspace?.path ?? ""))
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.white.opacity(0.6))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.clear)
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
                .foregroundColor(.white.opacity(0.5))

            Text("No Terminal Selected")
                .font(.title2)
                .foregroundColor(.white.opacity(0.7))

            Text("Select a terminal from the sidebar or create a new one")
                .font(.callout)
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)

            HStack(spacing: 8) {
                Text("⌘T")
                    .font(.system(.caption, design: .monospaced))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.15))
                    .cornerRadius(4)
                    .foregroundColor(.white.opacity(0.8))

                Text("New Terminal")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
