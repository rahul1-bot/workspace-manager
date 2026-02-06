import SwiftUI
import AppKit

// App delegate to handle activation
class AppDelegate: NSObject, NSApplicationDelegate {
    private var keyMonitor: Any?
    private var flagsMonitor: Any?

    func applicationWillFinishLaunching(_ notification: Notification) {
        // Initialize libghostty FIRST - before any views are created
        GhosttyAppManager.shared.initialize()

        // Ensure the app runs as a regular foreground app
        NSApp.setActivationPolicy(.regular)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {

        // Force the app to become active and accept keyboard input
        NSApp.activate(ignoringOtherApps: true)

        // Make the main window key and configure for transparency
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.makeKeyWindow()
            self?.configureWindowForGlassEffect()
            self?.logActivationState(context: "didFinishLaunching")
        }

        removeSystemHelpMenu()
        installInputMonitors()
    }

    private func configureWindowForGlassEffect() {
        guard let window = NSApp.mainWindow ?? NSApp.windows.first else { return }
        window.isOpaque = false
        window.backgroundColor = NSColor.clear
        window.titlebarAppearsTransparent = true
        window.styleMask.insert(.fullSizeContentView)

        // Hide title and traffic lights for minimal UI
        window.titleVisibility = .hidden
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        // Ensure window is key when app becomes active
        makeKeyWindow()
        logActivationState(context: "didBecomeActive")
    }

    func applicationDidResignActive(_ notification: Notification) {
        logActivationState(context: "didResignActive")
    }

    func applicationWillTerminate(_ notification: Notification) {
        removeInputMonitors()
    }

    private func makeKeyWindow() {
        let window = NSApp.mainWindow ?? NSApp.windows.first
        window?.makeKeyAndOrderFront(nil)
    }

    private func logActivationState(context: String) {
        guard DiagnosticMode.isEnabled else { return }
        let keyWindow = String(describing: NSApp.keyWindow)
        let mainWindow = String(describing: NSApp.mainWindow)
        let firstResponder = String(describing: NSApp.keyWindow?.firstResponder)
        AppLogger.app.debug("activation context=\(context, privacy: .public) active=\(NSApp.isActive, privacy: .public) policy=\(String(describing: NSApp.activationPolicy()), privacy: .public) key=\(keyWindow, privacy: .private(mask: .hash)) main=\(mainWindow, privacy: .private(mask: .hash)) responder=\(firstResponder, privacy: .private(mask: .hash))")
    }

    private func removeSystemHelpMenu() {
        guard let mainMenu = NSApp.mainMenu else { return }
        for item in mainMenu.items where item.title == "Help" {
            mainMenu.removeItem(item)
        }
    }

    private func installInputMonitors() {
#if DEBUG
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.logKeyEvent(event, label: "keyDown")
            return event
        }
        flagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.logKeyEvent(event, label: "flagsChanged")
            return event
        }
#endif
    }

    private func removeInputMonitors() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
        }
        if let flagsMonitor {
            NSEvent.removeMonitor(flagsMonitor)
        }
    }

    private func logKeyEvent(_ event: NSEvent, label: String) {
        guard DiagnosticMode.isEnabled else { return }
        InputEventRecorder.shared.record(
            kind: label == "flagsChanged" ? .flagsChanged : .keyMonitor,
            keyCode: event.keyCode,
            modifierFlags: event.modifierFlags.rawValue,
            details: "chars=\(Redaction.maskCharacters(event.characters)) charsIgnoring=\(Redaction.maskCharacters(event.charactersIgnoringModifiers))"
        )
        AppLogger.input.debug("event label=\(label, privacy: .public) keyCode=\(event.keyCode, privacy: .public) flags=\(event.modifierFlags.rawValue, privacy: .public)")
    }
}

@main
struct WorkspaceManagerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .frame(minWidth: 900, minHeight: 600)
                .onAppear {
                    // Activate app when content appears
                    NSApp.activate(ignoringOtherApps: true)
                }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1200, height: 800)
        .commands {
            // Remove the default Edit menu's Cut/Copy/Paste items.
            // SwiftUI's default pasteboard commands can intercept Cmd+V/C/X
            // at the Scene level before the NSEvent monitor or
            // performKeyEquivalent: can handle them, causing the window
            // to close on macOS 26 with .hiddenTitleBar.
            // Text fields (commit sheet, command palette) still handle
            // Cmd+V through NSTextView's built-in key equivalent handling.
            // The terminal handles paste through libghostty's keybindings.
            CommandGroup(replacing: .pasteboard) { }
            CommandGroup(replacing: .help) { }

            // Custom keyboard commands
            CommandGroup(after: .newItem) {
                Button("New Terminal") {
                    appState.createTerminalViaShortcut()
                }
                .keyboardShortcut("t", modifiers: .command)

                Button("New Workspace") {
                    appState.showNewWorkspaceSheet = true
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])

                Button("Command Palette") {
                    NotificationCenter.default.post(name: .wmToggleCommandPalette, object: nil)
                }
                .keyboardShortcut("p", modifiers: .command)
            }

            CommandGroup(after: .sidebar) {
                Button("Toggle Sidebar") {
                    withAnimation {
                        appState.toggleSidebar()
                    }
                }
                .keyboardShortcut("s", modifiers: [.command, .control])
            }
        }
    }
}

extension Notification.Name {
    static let wmToggleCommandPalette = Notification.Name("wmToggleCommandPalette")
    static let wmGraphZoomIn = Notification.Name("wmGraphZoomIn")
    static let wmGraphZoomOut = Notification.Name("wmGraphZoomOut")
    static let wmGraphZoomToFit = Notification.Name("wmGraphZoomToFit")
}
