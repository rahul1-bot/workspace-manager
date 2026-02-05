import SwiftUI
import AppKit

// Glass background for sidebar - same as terminal for symmetry
struct GlassSidebarBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow  // Same as terminal area
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var sidebarFocused = false
    @State private var eventMonitor: Any?
    @State private var showCommandPalette = false
    @State private var showShortcutsHelp = false
    @State private var showCloseTerminalConfirm = false
    @State private var shortcutThrottle: [String: TimeInterval] = [:]

    var body: some View {
        ZStack {
            // Full-window glass background for coherent blur everywhere
            GlassSidebarBackground()
                .ignoresSafeArea()

            HStack(spacing: 0) {
                // Sidebar - instant toggle, no animation
                // Uses appState.showSidebar as single source of truth
                if appState.showSidebar && !appState.focusMode {
                    WorkspaceSidebar()
                        .frame(width: 240)
                        .overlay(
                            // Visual indicator when sidebar is focused
                            RoundedRectangle(cornerRadius: 0)
                                .stroke(sidebarFocused ? Color.accentColor.opacity(0.5) : Color.clear, lineWidth: 2)
                        )
                }

                // Terminal area
                TerminalContainer(showHeader: !appState.focusMode)
                    .overlay(alignment: .topLeading) {
                        if appState.focusMode {
                            FocusModeOverlay()
                                .padding(.leading, 12)
                                .padding(.top, 10)
                        }
                    }
            }

            if showCommandPalette {
                CommandPaletteOverlay(isPresented: $showCommandPalette) {
                    sidebarFocused = false
                }
            }

            if showShortcutsHelp {
                ShortcutsHelpOverlay(isPresented: $showShortcutsHelp)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            setupKeyboardMonitor()
        }
        .onDisappear {
            removeKeyboardMonitor()
        }
        .alert("Close Terminal?", isPresented: $showCloseTerminalConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Close", role: .destructive) {
                appState.closeSelectedTerminal()
            }
        } message: {
            Text("This will terminate the running shell session in the selected terminal.")
        }
    }

    private func setupKeyboardMonitor() {
        guard eventMonitor == nil else { return }

        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [self] event in
            guard NSApp.isActive else { return event }
            let cmd = event.modifierFlags.contains(.command)
            let shift = event.modifierFlags.contains(.shift)
            let char = (event.charactersIgnoringModifiers ?? "").lowercased()

            InputEventRecorder.shared.record(
                kind: .keyMonitor,
                keyCode: event.keyCode,
                modifierFlags: event.modifierFlags.rawValue,
                details: "char=\(Redaction.maskCharacters(char)) cmd=\(cmd) shift=\(shift)"
            )

            if showShortcutsHelp {
                if event.keyCode == 53 {
                    showShortcutsHelp = false
                    return nil
                }
                return nil
            }

            if showCommandPalette {
                if event.keyCode == 53 {
                    showCommandPalette = false
                    return nil
                }
                return event
            }

            let repeatFriendly: Set<String> = ["i", "k", "[", "]"]
            if cmd && event.isARepeat && !repeatFriendly.contains(char) {
                return nil
            }

            // ⌘B toggle sidebar visibility (focus stays on terminal)
            if cmd && char == "b" {
                guard shouldExecuteShortcut("toggleSidebar") else { return nil }
                if appState.focusMode {
                    appState.setFocusMode(false)
                }
                appState.toggleSidebar()
                if !appState.showSidebar { sidebarFocused = false }
                return nil
            }

            // ⌘T new terminal
            if cmd && char == "t" {
                guard shouldExecuteShortcut("newTerminal") else { return nil }
                appState.createTerminalViaShortcut()
                return nil
            }

            // ⇧⌘N new workspace (sheet)
            if cmd && shift && char == "n" {
                guard shouldExecuteShortcut("newWorkspace") else { return nil }
                if appState.focusMode {
                    appState.setFocusMode(false)
                }
                appState.setSidebar(visible: true)
                sidebarFocused = true
                appState.showNewWorkspaceSheet = true
                return nil
            }

            // ⇧⌘I - previous workspace
            if cmd && shift && char == "i" {
                appState.selectPreviousWorkspace()
                return nil
            }

            // ⇧⌘K - next workspace
            if cmd && shift && char == "k" {
                appState.selectNextWorkspace()
                return nil
            }

            // ⌘I - previous terminal (cycles)
            if cmd && char == "i" {
                appState.selectPreviousTerminal()
                return nil
            }

            // ⌘K - next terminal (cycles)
            if cmd && char == "k" {
                appState.selectNextTerminal()
                return nil
            }

            // ⌘J - focus sidebar (show if hidden)
            if cmd && char == "j" {
                guard shouldExecuteShortcut("focusSidebar") else { return nil }
                if appState.focusMode {
                    appState.setFocusMode(false)
                }
                appState.setSidebar(visible: true)
                sidebarFocused = true
                return nil
            }

            // ⌘L - focus terminal
            if cmd && char == "l" {
                guard shouldExecuteShortcut("focusTerminal") else { return nil }
                sidebarFocused = false
                return nil
            }

            // ⌘E - toggle workspace expand/collapse
            if cmd && char == "e" {
                guard shouldExecuteShortcut("toggleExpand") else { return nil }
                if appState.focusMode {
                    appState.setFocusMode(false)
                }
                if let wsId = appState.selectedWorkspaceId {
                    appState.toggleWorkspaceExpanded(id: wsId)
                }
                appState.setSidebar(visible: true)
                sidebarFocused = true
                return nil
            }

            // ⌘O - open workspace in Finder
            if cmd && char == "o" {
                guard shouldExecuteShortcut("openFinder") else { return nil }
                if let ws = appState.selectedWorkspace {
                    NSWorkspace.shared.open(URL(fileURLWithPath: ws.path))
                }
                return nil
            }

            // ⌥⌘C - copy workspace path
            if cmd && char == "c" && event.modifierFlags.contains(.option) {
                if let ws = appState.selectedWorkspace {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(ws.path, forType: .string)
                }
                return nil
            }

            // ⌘, - reveal config.toml in Finder
            if cmd && char == "," {
                guard shouldExecuteShortcut("revealConfig") else { return nil }
                NSWorkspace.shared.activateFileViewerSelecting([ConfigService.shared.configFileURL])
                return nil
            }

            // ⌘. - toggle Focus Mode
            if cmd && char == "." {
                guard shouldExecuteShortcut("toggleFocusMode") else { return nil }
                appState.toggleFocusMode()
                sidebarFocused = false
                return nil
            }

            // ⌘P - command palette
            if cmd && char == "p" {
                guard shouldExecuteShortcut("togglePalette") else { return nil }
                showCommandPalette.toggle()
                sidebarFocused = false
                return nil
            }

            // ⇧⌘/ - shortcuts help
            if cmd && shift && char == "/" {
                guard shouldExecuteShortcut("toggleHelp") else { return nil }
                showShortcutsHelp.toggle()
                return nil
            }

            // ⌘W - close selected terminal (confirm)
            if cmd && char == "w" {
                guard shouldExecuteShortcut("closeTerminalPrompt") else { return nil }
                if appState.selectedTerminalId != nil {
                    showCloseTerminalConfirm = true
                    return nil
                }
                return event
            }

            func numberKeyFromKeyCode(_ keyCode: UInt16) -> Int? {
                switch keyCode {
                case 18: return 1
                case 19: return 2
                case 20: return 3
                case 21: return 4
                case 23: return 5
                case 22: return 6
                case 26: return 7
                case 28: return 8
                case 25: return 9
                case 29: return 0
                default: return nil
                }
            }

            // ⌥⌘1..⌥⌘9 - jump to terminal index within workspace
            if cmd && event.modifierFlags.contains(.option),
               let digit = numberKeyFromKeyCode(event.keyCode),
               digit >= 1 {
                let index = digit - 1
                appState.selectTerminalByIndex(index: index)
                return nil
            }

            // ⌘1..⌘9 - jump to workspace index
            if cmd, let digit = numberKeyFromKeyCode(event.keyCode), digit >= 1 {
                let index = digit - 1
                if appState.workspaces.indices.contains(index) {
                    let ws = appState.workspaces[index]
                    appState.selectedWorkspaceId = ws.id
                    if let firstTerminal = ws.terminals.first {
                        appState.selectTerminal(id: firstTerminal.id, in: ws.id)
                    } else {
                        appState.selectedTerminalId = nil
                    }
                }
                return nil
            }

            // ⌘R - rename (inline)
            if cmd && char == "r" && !event.modifierFlags.contains(.shift) {
                guard shouldExecuteShortcut("rename") else { return nil }
                if appState.focusMode {
                    appState.setFocusMode(false)
                }
                appState.setSidebar(visible: true)
                sidebarFocused = true
                appState.beginRenameSelectedItem()
                return nil
            }

            // ⇧⌘R - hot reload config.toml
            if cmd && char == "r" && event.modifierFlags.contains(.shift) {
                guard shouldExecuteShortcut("reloadConfig") else { return nil }
                appState.reloadFromConfig()
                AppLogger.app.debug("config reloaded via Shift+Cmd+R")
                return nil
            }

            // ⌘[ - previous workspace
            if cmd && char == "[" {
                appState.selectPreviousWorkspace()
                return nil
            }

            // ⌘] - next workspace
            if cmd && char == "]" {
                appState.selectNextWorkspace()
                return nil
            }

            // Arrow keys when sidebar is focused
            if sidebarFocused {
                // Escape - cancel rename
                if event.keyCode == 53 {
                    appState.cancelRenaming()
                    return nil
                }

                // Up arrow - previous terminal
                if event.keyCode == 126 {
                    appState.selectPreviousTerminal()
                    return nil
                }
                // Down arrow - next terminal
                if event.keyCode == 125 {
                    appState.selectNextTerminal()
                    return nil
                }
                // Enter/Return - focus terminal
                if event.keyCode == 36 {
                    sidebarFocused = false
                    return nil
                }
            }

            return event
        }
    }

    private func shouldExecuteShortcut(_ id: String, cooldown: TimeInterval = 0.08) -> Bool {
        let now = CFAbsoluteTimeGetCurrent()
        let last = shortcutThrottle[id] ?? 0
        guard now - last >= cooldown else { return false }
        shortcutThrottle[id] = now
        return true
    }

    private func removeKeyboardMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
}
