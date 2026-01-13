import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var sidebarWidth: CGFloat = 280

    var body: some View {
        NavigationSplitView {
            WorkspaceSidebar()
                .navigationSplitViewColumnWidth(min: 200, ideal: 280, max: 400)
        } detail: {
            TerminalContainer()
        }
        .navigationTitle("")
        .simultaneousGesture(TapGesture().onEnded {
            NSApp.activate(ignoringOtherApps: true)
        })
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Button(action: {
                    withAnimation {
                        appState.showSidebar.toggle()
                    }
                }) {
                    Image(systemName: "sidebar.left")
                }
                .help("Toggle Sidebar")
            }

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
