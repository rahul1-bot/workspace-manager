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
            let char = event.charactersIgnoringModifiers ?? ""

            // ⌘B toggle sidebar visibility (focus stays on terminal)
            if cmd && char == "b" {
                appState.showSidebar.toggle()
                if !appState.showSidebar { sidebarFocused = false }
                return nil
            }

            // ⌘T new terminal
            if cmd && char == "t" {
                if appState.selectedWorkspaceId != nil {
                    appState.createTerminalInSelectedWorkspace()
                }
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
                appState.showSidebar = true
                sidebarFocused = true
                return nil
            }

            // ⌘L - focus terminal
            if cmd && char == "l" {
                sidebarFocused = false
                return nil
            }

            // Arrow keys when sidebar is focused
            if sidebarFocused {
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
