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
    @State private var diffPanelWidthRatio: CGFloat = 0.5
    @State private var diffPanelDragStartRatio: CGFloat?
    @State private var isDiffResizeHandleHovering = false
    @State private var isDiffPanelResizing = false
    @State private var lastDiffResizeUpdateTime: CFAbsoluteTime = 0
    private let shortcutRouter = KeyboardShortcutRouter()
    private let minDiffPanelWidthRatio: CGFloat = 0.2
    private let maxDiffPanelWidthRatio: CGFloat = 1.0
    private let defaultDiffPanelWidthRatio: CGFloat = 0.5
    private let resizeStepRatio: CGFloat = 0.001

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
                GeometryReader { terminalGeometry in
                    let terminalWidth = max(terminalGeometry.size.width, 1)

                    TerminalContainer(showHeader: !appState.focusMode)
                        .overlay(alignment: .topLeading) {
                            if appState.focusMode {
                                FocusModeOverlay()
                                    .padding(.leading, 12)
                                    .padding(.top, 10)
                            }
                        }
                        .overlay(alignment: .trailing) {
                            if appState.gitPanelState.isPresented {
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
                                .frame(width: terminalWidth * diffPanelWidthRatio)
                                .overlay(alignment: .leading) {
                                    diffResizeHandle(terminalWidth: terminalWidth)
                                }
                            }
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
            appState.refreshGitUIState()
        }
        .onDisappear {
            removeKeyboardMonitor()
        }
        .onReceive(NotificationCenter.default.publisher(for: .wmToggleCommandPalette)) { _ in
            showCommandPalette.toggle()
            sidebarFocused = false
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
                sidebarFocused: sidebarFocused,
                selectedTerminalExists: appState.selectedTerminalId != nil
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

    private func diffResizeHandle(terminalWidth: CGFloat) -> some View {
        Rectangle()
            .fill(Color.white.opacity(isDiffResizeHandleHovering ? 0.22 : 0.10))
            .frame(width: 6)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if diffPanelDragStartRatio == nil {
                            diffPanelDragStartRatio = diffPanelWidthRatio
                            isDiffPanelResizing = true
                            lastDiffResizeUpdateTime = CFAbsoluteTimeGetCurrent()
                        }
                        let startRatio = diffPanelDragStartRatio ?? diffPanelWidthRatio
                        let deltaRatio = -value.translation.width / max(terminalWidth, 1)
                        let candidateRatio = startRatio + deltaRatio
                        let rawClampedRatio = min(maxDiffPanelWidthRatio, max(0, candidateRatio))
                        let step = max(resizeStepRatio, 1 / max(terminalWidth, 1))
                        let steppedRatio = (rawClampedRatio / step).rounded() * step
                        let clampedRatio = min(maxDiffPanelWidthRatio, max(0, steppedRatio))
                        guard abs(clampedRatio - diffPanelWidthRatio) >= (step / 2) else { return }
                        let now = CFAbsoluteTimeGetCurrent()
                        let minimumUpdateInterval = 1.0 / 90.0
                        guard now - lastDiffResizeUpdateTime >= minimumUpdateInterval else { return }
                        lastDiffResizeUpdateTime = now
                        var transaction = Transaction()
                        transaction.disablesAnimations = true
                        withTransaction(transaction) {
                            diffPanelWidthRatio = clampedRatio
                        }
                    }
                    .onEnded { _ in
                        if diffPanelWidthRatio < minDiffPanelWidthRatio {
                            appState.dismissDiffPanelPlaceholder()
                            diffPanelWidthRatio = defaultDiffPanelWidthRatio
                        } else {
                            diffPanelWidthRatio = min(maxDiffPanelWidthRatio, max(minDiffPanelWidthRatio, diffPanelWidthRatio))
                        }
                        diffPanelDragStartRatio = nil
                        isDiffPanelResizing = false
                        lastDiffResizeUpdateTime = 0
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
                lastDiffResizeUpdateTime = 0
            }
    }
}
