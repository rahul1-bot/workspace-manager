import SwiftUI
import AppKit

struct FocusModeOverlay: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(appState.selectedTerminal?.name ?? "Terminal")
                    .font(.system(.callout, design: .monospaced))
                    .fontWeight(.semibold)
                    .foregroundColor(.white)

                Text(appState.selectedWorkspace?.name ?? "")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.75))
            }

            Divider()
                .frame(height: 24)
                .overlay(Color.white.opacity(0.15))

            Text("⌘P palette  •  ⌘. exit")
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            VisualEffectBackground(material: .hudWindow, blendingMode: .withinWindow)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
}

struct CommandPaletteOverlay: View {
    @Binding var isPresented: Bool
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.25)
                .ignoresSafeArea()
                .onTapGesture {
                    isPresented = false
                    onDismiss()
                }

            CommandPaletteView(isPresented: $isPresented, onDismiss: onDismiss)
                .frame(width: 560)
        }
        .transition(.opacity)
    }
}

private enum PaletteEntryKind: Hashable {
    case workspace(UUID)
    case terminal(workspaceId: UUID, terminalId: UUID)
    case pdfTab(UUID)
    case action(PaletteAction)
}

private enum PaletteAction: String, CaseIterable, Hashable {
    case newTerminal
    case newWorkspace
    case toggleSidebar
    case toggleFocusMode
    case openPDF
    case revealConfig

    var title: String {
        switch self {
        case .newTerminal:
            return "New terminal"
        case .newWorkspace:
            return "New workspace"
        case .toggleSidebar:
            return "Toggle sidebar"
        case .toggleFocusMode:
            return "Toggle Focus Mode"
        case .openPDF:
            return "Open PDF"
        case .revealConfig:
            return "Reveal config.toml"
        }
    }

    var subtitle: String {
        switch self {
        case .newTerminal:
            return "Create a terminal in the selected workspace"
        case .newWorkspace:
            return "Open the New Workspace sheet"
        case .toggleSidebar:
            return "Show or hide the workspace sidebar"
        case .toggleFocusMode:
            return "Hide chrome and focus on one terminal"
        case .openPDF:
            return "Open a PDF file in the viewer panel (⇧⌘P)"
        case .revealConfig:
            return "Open ~/.config/workspace-manager/config.toml in Finder"
        }
    }
}

private struct PaletteEntry: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String?
    let kind: PaletteEntryKind
}

private struct CommandPaletteView: View {
    @EnvironmentObject var appState: AppState
    @Binding var isPresented: Bool
    let onDismiss: () -> Void

    @State private var query: String = ""
    @State private var selectedIndex: Int = 0
    @State private var paletteEventMonitor: Any?
    @FocusState private var queryFocused: Bool

    private var normalizedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var entries: [PaletteEntry] {
        let q = normalizedQuery
        var results: [PaletteEntry] = []

        let selectedWsId = appState.selectedWorkspaceId
        let selectedTermId = appState.selectedTerminalId

        func match(_ haystack: String) -> Bool {
            if q.isEmpty { return true }
            return haystack.lowercased().contains(q)
        }

        for ws in appState.workspaces {
            if match(ws.name) || match(ws.path) {
                let isSelected = ws.id == selectedWsId
                results.append(
                    PaletteEntry(
                        id: "ws:\(ws.id.uuidString)",
                        title: ws.name,
                        subtitle: ws.path,
                        kind: .workspace(ws.id)
                    )
                )
                if isSelected {
                    // Keep selected workspace near the top for empty queries.
                }
            }

            for terminal in ws.terminals {
                let composite = "\(terminal.name) \(ws.name) \(ws.path)"
                if match(composite) {
                    results.append(
                        PaletteEntry(
                            id: "t:\(ws.id.uuidString):\(terminal.id.uuidString)",
                            title: terminal.name,
                            subtitle: ws.name,
                            kind: .terminal(workspaceId: ws.id, terminalId: terminal.id)
                        )
                    )
                }
            }
        }

        for tab in appState.pdfPanelState.tabs {
            if match(tab.fileName) {
                results.append(
                    PaletteEntry(
                        id: "pdf:\(tab.id.uuidString)",
                        title: tab.fileName,
                        subtitle: "Open PDF tab",
                        kind: .pdfTab(tab.id)
                    )
                )
            }
        }

        if !q.isEmpty {
            for action in PaletteAction.allCases {
                if match(action.title) || match(action.subtitle) {
                    results.append(
                        PaletteEntry(
                            id: "a:\(action.rawValue)",
                            title: action.title,
                            subtitle: action.subtitle,
                            kind: .action(action)
                        )
                    )
                }
            }
        }

        func score(_ entry: PaletteEntry) -> Int {
            switch entry.kind {
            case .terminal(let wsId, let termId):
                if wsId == selectedWsId && termId == selectedTermId { return 0 }
                if wsId == selectedWsId { return 1 }
                return 3
            case .workspace(let wsId):
                if wsId == selectedWsId { return 2 }
                return 4
            case .pdfTab(let tabId):
                if tabId == appState.pdfPanelState.activeTabId { return 5 }
                return 6
            case .action:
                return 10
            }
        }

        if q.isEmpty {
            return results.sorted { (a, b) in
                let sa = score(a)
                let sb = score(b)
                if sa != sb { return sa < sb }
                return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
            }
        }

        return results.sorted { a, b in
            let aTitle = a.title.lowercased()
            let bTitle = b.title.lowercased()
            let aPrefix = aTitle.hasPrefix(q)
            let bPrefix = bTitle.hasPrefix(q)
            if aPrefix != bPrefix { return aPrefix && !bPrefix }
            return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.white.opacity(0.7))

                TextField("Search workspaces and terminals", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(.body, design: .default))
                    .foregroundColor(.white)
                    .focused($queryFocused)

                Spacer()

                Text("Esc")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.55))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            Divider()
                .overlay(Color.white.opacity(0.08))

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        if entries.isEmpty {
                            Text("No matches")
                                .foregroundColor(.white.opacity(0.7))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                        } else {
                            ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                                Button {
                                    activate(entry)
                                } label: {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(entry.title)
                                            .foregroundColor(.white)
                                            .lineLimit(1)

                                        if let subtitle = entry.subtitle, !subtitle.isEmpty {
                                            Text(subtitle)
                                                .font(.caption)
                                                .foregroundColor(.white.opacity(0.65))
                                                .lineLimit(1)
                                                .truncationMode(.middle)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .background(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(index == selectedIndex ? Color.white.opacity(0.10) : Color.clear)
                                        .padding(.horizontal, 4)
                                )
                                .id(entry.id)
                            }
                        }
                    }
                }
                .frame(maxHeight: 320)
                .onChange(of: selectedIndex) { _, newIndex in
                    if entries.indices.contains(newIndex) {
                        proxy.scrollTo(entries[newIndex].id, anchor: .center)
                    }
                }
            }

            Divider()
                .overlay(Color.white.opacity(0.08))

            HStack {
                Text("↑↓ navigate  ⏎ select")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .background(
            ZStack {
                VisualEffectBackground(material: .hudWindow, blendingMode: .behindWindow)
                Color.black.opacity(0.45)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .onAppear {
            queryFocused = true
            selectedIndex = 0
            setupPaletteKeyMonitor()
        }
        .onDisappear {
            removePaletteKeyMonitor()
        }
        .onChange(of: query) { _, _ in
            selectedIndex = 0
        }
    }

    private func setupPaletteKeyMonitor() {
        paletteEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [self] event in
            switch event.keyCode {
            case 125: // down arrow
                let count = entries.count
                if count > 0 {
                    selectedIndex = min(selectedIndex + 1, count - 1)
                }
                return nil
            case 126: // up arrow
                selectedIndex = max(selectedIndex - 1, 0)
                return nil
            case 36: // return/enter
                let items = entries
                if items.indices.contains(selectedIndex) {
                    activate(items[selectedIndex])
                }
                return nil
            default:
                return event
            }
        }
    }

    private func removePaletteKeyMonitor() {
        if let monitor = paletteEventMonitor {
            NSEvent.removeMonitor(monitor)
            paletteEventMonitor = nil
        }
    }

    private func activate(_ entry: PaletteEntry) {
        switch entry.kind {
        case .workspace(let wsId):
            appState.selectedWorkspaceId = wsId
            if let ws = appState.workspaces.first(where: { $0.id == wsId }),
               let first = ws.terminals.first {
                appState.selectTerminal(id: first.id, in: wsId)
            } else {
                appState.selectedTerminalId = nil
            }
        case .terminal(let wsId, let termId):
            appState.selectTerminal(id: termId, in: wsId)
        case .pdfTab(let tabId):
            appState.selectPDFTab(id: tabId)
            appState.pdfPanelState.isPresented = true
        case .action(let action):
            switch action {
            case .newTerminal:
                appState.createTerminalViaShortcut()
            case .newWorkspace:
                if appState.focusMode {
                    appState.setFocusMode(false)
                }
                appState.setSidebar(visible: true)
                appState.showNewWorkspaceSheet = true
            case .toggleSidebar:
                if appState.focusMode {
                    appState.setFocusMode(false)
                }
                appState.toggleSidebar()
            case .toggleFocusMode:
                appState.toggleFocusMode()
            case .openPDF:
                appState.togglePDFPanel()
            case .revealConfig:
                NSWorkspace.shared.activateFileViewerSelecting([ConfigService.shared.configFileURL])
            }
        }

        isPresented = false
        onDismiss()
    }
}

struct ShortcutsHelpOverlay: View {
    @Binding var isPresented: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.25)
                .ignoresSafeArea()
                .onTapGesture {
                    isPresented = false
                }

            ShortcutsHelpCard(isPresented: $isPresented)
                .frame(width: 640)
        }
        .transition(.opacity)
    }
}

private struct ShortcutsHelpCard: View {
    @EnvironmentObject var appState: AppState
    @Binding var isPresented: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Keyboard Shortcuts")
                    .font(.headline)
                    .foregroundColor(.white)

                Spacer()

                Button("Close") {
                    isPresented = false
                }
                .buttonStyle(.plain)
                .foregroundColor(.white.opacity(0.75))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            Divider()
                .overlay(Color.white.opacity(0.08))

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ShortcutSection(
                        title: "Navigation",
                        rows: [
                            ("⌘B", "Toggle sidebar (exits Focus Mode)"),
                            ("⌘J", "Focus sidebar (exits Focus Mode)"),
                            ("⌘L", "Focus terminal"),
                            ("⌘[ / ⌘]", "Previous/next workspace"),
                            ("⇧⌘I / ⇧⌘K", "Previous/next workspace (alternate)"),
                            ("⌘I / ⌘K", "Previous/next terminal (within workspace)"),
                            ("⌘1..⌘9", "Jump to workspace by index"),
                            ("⌥⌘1..⌥⌘9", "Jump to terminal by index (within workspace)")
                        ]
                    )

                    ShortcutSection(
                        title: "Actions",
                        rows: [
                            ("⌘T", "New terminal"),
                            ("⇧⌘N", "New workspace"),
                            ("⌘R", "Rename selected workspace/terminal"),
                            ("⇧⌘R", "Reload config.toml"),
                            ("⌘W", "Close selected terminal (confirm)"),
                            ("⌘O", "Open selected workspace in Finder"),
                            ("⌥⌘C", "Copy selected workspace path"),
                            ("⌘,", "Reveal config.toml in Finder"),
                            ("⌘P", "Command palette"),
                            ("⇧⌘P", "Open PDF file"),
                            ("⌘.", "Toggle Focus Mode"),
                            ("⇧⌘/", "Show this help")
                        ]
                    )

                    ShortcutSection(
                        title: "PDF Viewer (when open)",
                        rows: [
                            ("⇧⌘{ / ⇧⌘}", "Previous/next PDF tab"),
                            ("⇧⌘W", "Close active PDF tab"),
                            ("Esc", "Close PDF panel")
                        ]
                    )

                    ShortcutSection(
                        title: "Sidebar (when focused)",
                        rows: [
                            ("↑ / ↓", "Cycle terminals"),
                            ("Enter", "Return focus to terminal"),
                            ("Esc", "Cancel rename")
                        ]
                    )

                    Text("Note: Worker/Reviewer pairing and task-label shortcuts are intentionally deferred until the Agents/Tasks model ships.")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.top, 4)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
        }
        .background(
            VisualEffectBackground(material: .hudWindow, blendingMode: .withinWindow)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
}

private struct ShortcutSection: View {
    let title: String
    let rows: [(keys: String, action: String)]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.white.opacity(0.75))

            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(alignment: .firstTextBaseline) {
                    Text(row.keys)
                        .font(.system(.callout, design: .monospaced))
                        .foregroundColor(.white)
                        .frame(width: 150, alignment: .leading)

                    Text(row.action)
                        .font(.callout)
                        .foregroundColor(.white.opacity(0.75))

                    Spacer()
                }
            }
        }
    }
}
