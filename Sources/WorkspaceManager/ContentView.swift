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

    var body: some View {
        ZStack {
            // Full-window glass background for coherent blur everywhere
            GlassSidebarBackground()
                .ignoresSafeArea()

            HStack(spacing: 0) {
                // Sidebar - instant toggle, no animation
                // Uses appState.showSidebar as single source of truth
                if appState.showSidebar {
                    WorkspaceSidebar()
                        .frame(width: 240)
                        .overlay(
                            // Visual indicator when sidebar is focused
                            RoundedRectangle(cornerRadius: 0)
                                .stroke(sidebarFocused ? Color.accentColor.opacity(0.5) : Color.clear, lineWidth: 2)
                        )
                }

                // Terminal area
                TerminalContainer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            setupKeyboardMonitor()
        }
        .onDisappear {
            removeKeyboardMonitor()
        }
    }

    private func setupKeyboardMonitor() {
        guard eventMonitor == nil else { return }

        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [self] event in
            let cmd = event.modifierFlags.contains(.command)
            let char = (event.charactersIgnoringModifiers ?? "").lowercased()

            // ⌘B toggle sidebar visibility (focus stays on terminal)
            if cmd && char == "b" {
                appState.toggleSidebar()
                if !appState.showSidebar { sidebarFocused = false }
                return nil
            }

            // ⌘T new terminal
            if cmd && char == "t" {
                appState.createTerminalViaShortcut()
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
                appState.setSidebar(visible: true)
                sidebarFocused = true
                return nil
            }

            // ⌘L - focus terminal
            if cmd && char == "l" {
                sidebarFocused = false
                return nil
            }

            // ⌘E - toggle workspace expand/collapse
            if cmd && char == "e" {
                if let wsId = appState.selectedWorkspaceId {
                    appState.toggleWorkspaceExpanded(id: wsId)
                }
                appState.setSidebar(visible: true)
                sidebarFocused = true
                return nil
            }

            // ⌘O - open workspace in Finder
            if cmd && char == "o" {
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

            // ⌘1..⌘9 - jump to workspace index
            if cmd, let digit = Int(char), digit >= 1 {
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
                appState.setSidebar(visible: true)
                sidebarFocused = true
                appState.beginRenameSelectedItem()
                return nil
            }

            // ⇧⌘R - hot reload config.toml
            if cmd && char == "r" && event.modifierFlags.contains(.shift) {
                appState.reloadFromConfig()
                print("[ContentView] Config reloaded via Shift+Cmd+R")
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

    private func removeKeyboardMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
}
