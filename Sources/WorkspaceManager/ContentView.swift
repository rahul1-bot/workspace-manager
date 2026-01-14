import SwiftUI
import AppKit

// Glass background for sidebar
struct GlassSidebarBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .sidebar
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var sidebarWidth: CGFloat = 280

    var body: some View {
        NavigationSplitView {
            WorkspaceSidebar()
                .navigationSplitViewColumnWidth(min: 200, ideal: 280, max: 400)
                .background(GlassSidebarBackground())
        } detail: {
            TerminalContainer()
        }
        .navigationTitle("")
        .simultaneousGesture(TapGesture().onEnded {
            NSApp.activate(ignoringOtherApps: true)
        })
        .toolbar {
            // Note: NavigationSplitView provides its own sidebar toggle, so we don't add another one

            ToolbarItemGroup(placement: .primaryAction) {
                if appState.selectedWorkspaceId != nil {
                    Button(action: {
                        appState.createTerminalInSelectedWorkspace()
                    }) {
                        Image(systemName: "plus")
                    }
                    .help("New Terminal (⌘T)")
                }

                if appState.selectedTerminalId != nil,
                   let workspaceId = appState.selectedWorkspaceId {
                    Button(action: {
                        appState.removeTerminal(id: appState.selectedTerminalId!, from: workspaceId)
                    }) {
                        Image(systemName: "trash")
                    }
                    .help("Delete Terminal")
                }
            }
        }
    }
}
