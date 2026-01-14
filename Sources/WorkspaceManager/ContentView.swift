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
    @State private var showSidebar = true

    var body: some View {
        ZStack {
            // Full-window glass background for coherent blur everywhere
            GlassSidebarBackground()
                .ignoresSafeArea()

            HStack(spacing: 0) {
                // Sidebar - instant toggle, no animation
                if showSidebar {
                    WorkspaceSidebar()
                        .frame(width: 240)
                }

                // Terminal area
                TerminalContainer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                // ⌘B toggle sidebar
                if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "b" {
                    showSidebar.toggle()
                    return nil
                }
                // ⌘T new terminal
                if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "t" {
                    if appState.selectedWorkspaceId != nil {
                        appState.createTerminalInSelectedWorkspace()
                    }
                    return nil
                }
                return event
            }
        }
    }
}
