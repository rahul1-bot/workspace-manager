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
    @State private var scrollMonitor: Any?
    @State private var showCommandPalette = false
    @State private var showShortcutsHelp = false
    @State private var showCloseTerminalConfirm = false
    @State private var shortcutThrottle: [String: TimeInterval] = [:]
    @State private var diffPanelWidthRatio: CGFloat = 0.5
    @State private var diffPanelDragStartRatio: CGFloat?
    @State private var isDiffResizeHandleHovering = false
    @State private var isDiffPanelResizing = false
    @State private var pdfPanelWidthRatio: CGFloat = 0.5
    @State private var pdfPanelDragStartRatio: CGFloat?
    @State private var isPDFResizeHandleHovering = false
    @State private var isPDFPanelResizing = false
    private let shortcutRouter = KeyboardShortcutRouter()
    private let minPanelWidthRatio: CGFloat = 0.2
    private let maxPanelWidthRatio: CGFloat = 1.0
    private let defaultPanelWidthRatio: CGFloat = 0.5

    var body: some View {
        ZStack {
            // Full-window glass background for coherent blur everywhere
            GlassSidebarBackground()
                .ignoresSafeArea()

            // Always keep sidebarModeContent alive so terminal processes survive
            // view mode switches. Hiding via opacity preserves the NSView hierarchy.
            sidebarModeContent
                .opacity(appState.currentViewMode == .sidebar ? 1 : 0)
                .allowsHitTesting(appState.currentViewMode == .sidebar)

            if appState.currentViewMode == .graph {
                GraphCanvasView()
            }

            if showCommandPalette {
                CommandPaletteOverlay(isPresented: $showCommandPalette) {
                    sidebarFocused = false
                }
            }

            if showShortcutsHelp {
                ShortcutsHelpOverlay(isPresented: $showShortcutsHelp)
            }

            if appState.commitSheetState.isPresented {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .onTapGesture {
                        appState.dismissCommitSheetPlaceholder()
                    }

                CommitSheetView(
                    state: appState.commitSheetState,
                    onMessageChanged: { message in
                        appState.setCommitMessagePlaceholder(message)
                    },
                    onIncludeUnstagedChanged: { includeUnstaged in
                        appState.setIncludeUnstagedPlaceholder(includeUnstaged)
                    },
                    onNextStepChanged: { nextStep in
                        appState.setCommitNextStepPlaceholder(nextStep)
                    },
                    onContinue: {
                        appState.continueCommitFlowPlaceholder()
                    }
                )
                .onExitCommand {
                    appState.dismissCommitSheetPlaceholder()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            setupKeyboardMonitor()
            setupScrollWheelMonitor()
            appState.loadGraphState()
        }
        .onDisappear {
            removeKeyboardMonitor()
            removeScrollWheelMonitor()
        }
        .onReceive(NotificationCenter.default.publisher(for: .wmToggleCommandPalette)) { _ in
            showCommandPalette.toggle()
            sidebarFocused = false
        }
        .onChange(of: appState.gitPanelState.isPresented) { _, isPresented in
            if !isPresented {
                diffPanelDragStartRatio = nil
                isDiffPanelResizing = false
            }
        }
        .onChange(of: appState.pdfPanelState.isPresented) { _, isPresented in
            if !isPresented {
                pdfPanelDragStartRatio = nil
                isPDFPanelResizing = false
            }
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

    private var sidebarModeContent: some View {
        HStack(spacing: 0) {
            if appState.showSidebar && !appState.focusMode {
                WorkspaceSidebar()
                    .frame(width: 240)
                    .overlay(
                        RoundedRectangle(cornerRadius: 0)
                            .stroke(sidebarFocused ? Color.accentColor.opacity(0.5) : Color.clear, lineWidth: 2)
                    )
            }

            GeometryReader { terminalGeometry in
                let terminalWidth = max(terminalGeometry.size.width, 1)

                ZStack(alignment: .trailing) {
                    TerminalContainer(showHeader: !appState.focusMode)
                        .overlay(alignment: .topLeading) {
                            if appState.focusMode {
                                FocusModeOverlay()
                                    .padding(.leading, 12)
                                    .padding(.top, 10)
                            }
                        }

                    if appState.gitPanelState.isPresented {
                        HStack(spacing: 0) {
                            diffResizeHandle(terminalWidth: terminalWidth)
                            DiffPanelView(
                                state: appState.gitPanelState,
                                isResizing: isDiffPanelResizing,
                                onClose: {
                                    appState.dismissDiffPanelPlaceholder()
                                },
                                onModeSelected: { mode in
                                    appState.setDiffPanelModePlaceholder(mode)
                                }
                            )
                        }
                        .frame(width: terminalWidth * diffPanelWidthRatio)
                    }

                    if appState.pdfPanelState.isPresented {
                        HStack(spacing: 0) {
                            pdfResizeHandle(terminalWidth: terminalWidth)
                            PDFPanelView(
                                state: appState.pdfPanelState,
                                isResizing: isPDFPanelResizing,
                                onClose: {
                                    appState.dismissPDFPanel()
                                },
                                onPageChanged: { pageIndex in
                                    appState.updatePDFPageIndex(pageIndex)
                                },
                                onTotalPagesChanged: { count in
                                    appState.updatePDFTotalPages(count)
                                },
                                onTabSelected: { tabId in
                                    appState.selectPDFTab(id: tabId)
                                },
                                onTabClosed: { tabId in
                                    appState.closePDFTab(id: tabId)
                                },
                                onAddTab: {
                                    appState.presentPDFFilePicker()
                                }
                            )
                        }
                        .frame(width: terminalWidth * pdfPanelWidthRatio)
                    }
                }
            }
        }
        .ignoresSafeArea(.container, edges: .top)
    }

    private func setupKeyboardMonitor() {
        guard eventMonitor == nil else { return }

        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [self] event in
            InputEventRecorder.shared.record(
                kind: .keyMonitor,
                keyCode: event.keyCode,
                modifierFlags: event.modifierFlags.rawValue,
                details: "charsIgnoring=\(Redaction.maskCharacters(event.charactersIgnoringModifiers))"
            )

            let context = ShortcutContext(
                appIsActive: NSApp.isActive,
                showCommandPalette: showCommandPalette,
                showShortcutsHelp: showShortcutsHelp,
                showCommitSheet: appState.commitSheetState.isPresented,
                showDiffPanel: appState.gitPanelState.isPresented,
                showPDFPanel: appState.pdfPanelState.isPresented,
                sidebarFocused: sidebarFocused,
                isRenaming: appState.renamingWorkspaceId != nil || appState.renamingTerminalId != nil,
                selectedTerminalExists: appState.selectedTerminalId != nil,
                isGraphMode: appState.currentViewMode == .graph,
                hasFocusedGraphNode: appState.focusedGraphNodeId != nil,
                hasSelectedGraphNode: appState.selectedGraphNodeId != nil
            )

            switch shortcutRouter.route(event: event, context: context) {
            case .passthrough:
                return event
            case .consume(let command):
                executeShortcut(command)
                return nil
            }
        }
    }

    private func executeShortcut(_ command: ShortcutCommand) {
        switch command {
        case .closeShortcutsHelp:
            showShortcutsHelp = false
        case .closeCommandPalette:
            showCommandPalette = false
        case .closeCommitSheet:
            appState.dismissCommitSheetPlaceholder()
        case .closeDiffPanel:
            appState.dismissDiffPanelPlaceholder()
        case .togglePDFPanel:
            guard shouldExecuteShortcut("togglePDFPanel") else { return }
            appState.togglePDFPanel()
        case .closePDFPanel:
            appState.dismissPDFPanel()
        case .nextPDFTab:
            appState.selectNextPDFTab()
        case .previousPDFTab:
            appState.selectPreviousPDFTab()
        case .closePDFTab:
            guard let activeTabId = appState.pdfPanelState.activeTabId else { break }
            appState.closePDFTab(id: activeTabId)
        case .toggleSidebar:
            guard shouldExecuteShortcut("toggleSidebar") else { return }
            if appState.focusMode {
                appState.setFocusMode(false)
            }
            appState.toggleSidebar()
            if !appState.showSidebar { sidebarFocused = false }
        case .newTerminal:
            guard shouldExecuteShortcut("newTerminal") else { return }
            appState.createTerminalViaShortcut()
        case .newWorkspace:
            guard shouldExecuteShortcut("newWorkspace") else { return }
            if appState.focusMode {
                appState.setFocusMode(false)
            }
            appState.setSidebar(visible: true)
            sidebarFocused = true
            appState.showNewWorkspaceSheet = true
        case .previousWorkspace:
            appState.selectPreviousWorkspace()
        case .nextWorkspace:
            appState.selectNextWorkspace()
        case .previousTerminal:
            appState.selectPreviousTerminal()
        case .nextTerminal:
            appState.selectNextTerminal()
        case .focusSidebar:
            guard shouldExecuteShortcut("focusSidebar") else { return }
            if appState.focusMode {
                appState.setFocusMode(false)
            }
            appState.setSidebar(visible: true)
            sidebarFocused = true
        case .focusTerminal:
            guard shouldExecuteShortcut("focusTerminal") else { return }
            sidebarFocused = false
        case .toggleWorkspaceExpanded:
            guard shouldExecuteShortcut("toggleExpand") else { return }
            if appState.focusMode {
                appState.setFocusMode(false)
            }
            if let wsId = appState.selectedWorkspaceId {
                appState.toggleWorkspaceExpanded(id: wsId)
            }
            appState.setSidebar(visible: true)
            sidebarFocused = true
        case .openWorkspaceInFinder:
            guard shouldExecuteShortcut("openFinder") else { return }
            if let ws = appState.selectedWorkspace {
                NSWorkspace.shared.open(URL(fileURLWithPath: ws.path))
            }
        case .copyWorkspacePath:
            if let ws = appState.selectedWorkspace {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(ws.path, forType: .string)
            }
        case .revealConfig:
            guard shouldExecuteShortcut("revealConfig") else { return }
            NSWorkspace.shared.activateFileViewerSelecting([ConfigService.shared.configFileURL])
        case .toggleFocusMode:
            guard shouldExecuteShortcut("toggleFocusMode") else { return }
            appState.toggleFocusMode()
            sidebarFocused = false
        case .toggleCommandPalette:
            guard shouldExecuteShortcut("togglePalette") else { return }
            showCommandPalette.toggle()
            sidebarFocused = false
        case .toggleShortcutsHelp:
            guard shouldExecuteShortcut("toggleHelp") else { return }
            showShortcutsHelp.toggle()
        case .closeTerminalPrompt:
            guard shouldExecuteShortcut("closeTerminalPrompt") else { return }
            showCloseTerminalConfirm = true
        case .jumpTerminal(let index):
            appState.selectTerminalByIndex(index: index)
        case .jumpWorkspace(let index):
            if appState.workspaces.indices.contains(index) {
                let ws = appState.workspaces[index]
                appState.selectedWorkspaceId = ws.id
                if let firstTerminal = ws.terminals.first {
                    appState.selectTerminal(id: firstTerminal.id, in: ws.id)
                } else {
                    appState.selectedTerminalId = nil
                }
            }
        case .renameSelected:
            guard shouldExecuteShortcut("rename") else { return }
            if appState.focusMode {
                appState.setFocusMode(false)
            }
            appState.setSidebar(visible: true)
            sidebarFocused = true
            appState.beginRenameSelectedItem()
        case .reloadConfig:
            guard shouldExecuteShortcut("reloadConfig") else { return }
            appState.reloadFromConfig()
            AppLogger.app.debug("config reloaded via Shift+Cmd+R")
        case .sidebarCancelRename:
            appState.cancelRenaming()
        case .sidebarPrevTerminal:
            appState.selectPreviousTerminal()
        case .sidebarNextTerminal:
            appState.selectNextTerminal()
        case .sidebarReturnToTerminal:
            sidebarFocused = false
        case .toggleViewMode:
            guard shouldExecuteShortcut("toggleViewMode") else { return }
            appState.toggleViewMode()
            sidebarFocused = false
        case .unfocusGraphNode:
            appState.unfocusGraphNode()
        case .graphZoomIn:
            NotificationCenter.default.post(name: .wmGraphZoomIn, object: nil)
        case .graphZoomOut:
            NotificationCenter.default.post(name: .wmGraphZoomOut, object: nil)
        case .graphZoomToFit:
            NotificationCenter.default.post(name: .wmGraphZoomToFit, object: nil)
        case .graphRerunLayout:
            appState.rerunForceLayout()
        case .focusSelectedGraphNode:
            appState.focusSelectedGraphNode()
        case .swallow:
            break
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

    private func setupScrollWheelMonitor() {
        guard scrollMonitor == nil else { return }

        scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [self] event in
            guard appState.currentViewMode == .graph else { return event }
            guard event.modifierFlags.contains(.command) else { return event }

            let scrollDelta: CGFloat = event.scrollingDeltaY
            guard abs(scrollDelta) > 0.1 else { return event }

            let zoomFactor: Double = 1.0 + scrollDelta * 0.01
            let currentScale: Double = appState.graphViewport.scale
            let newScale: Double = max(0.1, min(currentScale * zoomFactor, 5.0))
            appState.graphViewport = ViewportTransform(
                translation: appState.graphViewport.translation,
                scale: newScale
            )
            return nil
        }
    }

    private func removeScrollWheelMonitor() {
        if let monitor = scrollMonitor {
            NSEvent.removeMonitor(monitor)
            scrollMonitor = nil
        }
    }

    private func diffResizeHandle(terminalWidth: CGFloat) -> some View {
        Rectangle()
            .fill(Color.white.opacity(isDiffResizeHandleHovering ? 0.22 : 0.10))
            .frame(width: 6)
            .padding(.horizontal, 5)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if diffPanelDragStartRatio == nil {
                            diffPanelDragStartRatio = diffPanelWidthRatio
                            isDiffPanelResizing = true
                        }
                        let startRatio = diffPanelDragStartRatio ?? diffPanelWidthRatio
                        let deltaRatio = -value.translation.width / max(terminalWidth, 1)
                        let newRatio = min(maxPanelWidthRatio, max(0, startRatio + deltaRatio))
                        var transaction = Transaction()
                        transaction.disablesAnimations = true
                        withTransaction(transaction) {
                            diffPanelWidthRatio = newRatio
                        }
                    }
                    .onEnded { _ in
                        if diffPanelWidthRatio < minPanelWidthRatio {
                            appState.dismissDiffPanelPlaceholder()
                            diffPanelWidthRatio = defaultPanelWidthRatio
                        } else {
                            diffPanelWidthRatio = min(maxPanelWidthRatio, max(minPanelWidthRatio, diffPanelWidthRatio))
                        }
                        diffPanelDragStartRatio = nil
                        isDiffPanelResizing = false
                    }
            )
            .onHover { hovering in
                guard hovering != isDiffResizeHandleHovering else { return }
                isDiffResizeHandleHovering = hovering
                if hovering {
                    NSCursor.resizeLeftRight.push()
                } else {
                    NSCursor.pop()
                }
            }
            .onDisappear {
                if isDiffResizeHandleHovering {
                    NSCursor.pop()
                    isDiffResizeHandleHovering = false
                }
                isDiffPanelResizing = false
            }
    }

    private func pdfResizeHandle(terminalWidth: CGFloat) -> some View {
        Rectangle()
            .fill(Color.white.opacity(isPDFResizeHandleHovering ? 0.22 : 0.10))
            .frame(width: 6)
            .padding(.horizontal, 5)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if pdfPanelDragStartRatio == nil {
                            pdfPanelDragStartRatio = pdfPanelWidthRatio
                            isPDFPanelResizing = true
                        }
                        let startRatio = pdfPanelDragStartRatio ?? pdfPanelWidthRatio
                        let deltaRatio = -value.translation.width / max(terminalWidth, 1)
                        let newRatio = min(maxPanelWidthRatio, max(0, startRatio + deltaRatio))
                        var transaction = Transaction()
                        transaction.disablesAnimations = true
                        withTransaction(transaction) {
                            pdfPanelWidthRatio = newRatio
                        }
                    }
                    .onEnded { _ in
                        if pdfPanelWidthRatio < minPanelWidthRatio {
                            appState.dismissPDFPanel()
                            pdfPanelWidthRatio = defaultPanelWidthRatio
                        } else {
                            pdfPanelWidthRatio = min(maxPanelWidthRatio, max(minPanelWidthRatio, pdfPanelWidthRatio))
                        }
                        pdfPanelDragStartRatio = nil
                        isPDFPanelResizing = false
                    }
            )
            .onHover { hovering in
                guard hovering != isPDFResizeHandleHovering else { return }
                isPDFResizeHandleHovering = hovering
                if hovering {
                    NSCursor.resizeLeftRight.push()
                } else {
                    NSCursor.pop()
                }
            }
            .onDisappear {
                if isPDFResizeHandleHovering {
                    NSCursor.pop()
                    isPDFResizeHandleHovering = false
                }
                isPDFPanelResizing = false
            }
    }
}
