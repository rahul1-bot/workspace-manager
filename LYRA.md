# Workspace Manager - LYRA.md

## Project Overview
| Field | Value |
|-------|-------|
| Project Name | Workspace Manager |
| Type | Native macOS Application |
| Purpose | Terminal workspace management with embedded GPU-accelerated terminals |
| Tech Stack | Swift, SwiftUI, SwiftTerm, Metal (via SwiftTerm) |
| Target | macOS 14+ with Apple Silicon optimization |

---

## Architecture Decision Record

| ADR | Decision | Date: 13 January 2026 | Time: 05:49 PM | Name: Lyra |

### Context
Rahul needed a terminal workspace manager that:
1. Organizes terminals by course/project (workspaces)
2. Provides 120Hz buttery smooth scrolling (ProMotion support)
3. Embeds actual terminals in the UI (not separate windows)
4. Runs on Apple Silicon with GPU acceleration

### Decision Journey
1. Initial Attempt: Python TUI with Textual library
    1. Problem: TUI runs inside terminal, cannot embed native Warp terminal
    2. Opening Warp just created separate windows, not embedded terminals
    3. Abandoned this approach

2. Final Decision: Native macOS app with SwiftUI + SwiftTerm
    1. SwiftTerm provides terminal emulation with GPU rendering
    2. SwiftUI provides native macOS sidebar and navigation
    3. Direct Metal rendering path for 120Hz smoothness
    4. No middle layer like tmux (which causes lag due to escape code rendering)

### Why Not tmux/Warp Embedding
1. tmux renders via escape codes on CPU, causes 50-200ms latency per frame
2. Warp is closed-source, cannot embed its views
3. Native SwiftTerm gives direct PTY to GPU pipeline (~8ms latency)

---

## Current Project Structure

```
workspace-manager/
├── Package.swift                           # Swift Package with SwiftTerm dependency
├── LYRA.md                                 # This file - decisions and architecture
├── memory.md                               # Learnings and insights
├── progress.md                             # Task tracking
├── Sources/WorkspaceManager/
│   ├── WorkspaceManagerApp.swift           # App entry point with keyboard shortcuts
│   ├── ContentView.swift                   # Main NavigationSplitView layout
│   ├── Models/
│   │   ├── AppState.swift                  # ObservableObject state management
│   │   ├── Workspace.swift                 # Workspace model (id, name, path, terminals)
│   │   └── Terminal.swift                  # Terminal model (id, name, workingDirectory)
│   └── Views/
│       ├── WorkspaceSidebar.swift          # Left sidebar with workspace tree
│       └── TerminalView.swift              # NSViewRepresentable wrapping SwiftTerm
└── .build/                                 # Build artifacts
```

---

## Current Status

| Status | Critical Blocker | Date: 13 January 2026 | Time: 06:02 PM | Name: Lyra |

### What WORKS
1. App launches successfully
2. UI renders correctly (sidebar, terminal area, modals)
3. Mouse clicking works (buttons, sidebar items, navigation)
4. Terminal view renders and shows shell prompt
5. Shell process starts (can see zsh prompt)
6. Window appears and can be moved/resized
7. App appears in Dock

### What DOES NOT WORK
1. NO keyboard input anywhere in the app
2. Cannot type in SwiftUI TextField (in modal dialogs)
3. Cannot type in terminal view
4. Keyboard shortcuts don't work
5. This is an APP-LEVEL issue, not terminal-specific

### Critical Discovery
The keyboard issue affects ALL input in the app, including native SwiftUI TextField components. This means the problem is NOT with SwiftTerm or our NSViewRepresentable wrapper - it's something fundamental about how the app receives keyboard events.

---

## Attempted Solutions (All Failed)

| Attempts | Keyboard Fix Attempts | Date: 13 January 2026 | Time: 06:02 PM | Name: Lyra |

### Attempt 1: makeFirstResponder in makeNSView
1. Used `window?.makeFirstResponder(terminalView)` in DispatchQueue.main.async
2. Result: Did not work

### Attempt 2: FocusableTerminalContainer wrapper
1. Created container NSView that forwards focus to terminal
2. Implemented mouseDown to focus on click
3. Result: Did not work

### Attempt 3: Subclassing LocalProcessTerminalView
1. Tried to override acceptsFirstResponder and mouseDown
2. Result: Build error - class methods are not `open`, cannot override

### Attempt 4: TerminalWrapperView with hitTest
1. Created wrapper with proper hitTest to pass events to terminal
2. Used NSApplication.shared.mainWindow?.makeFirstResponder()
3. Implemented viewDidMoveToWindow auto-focus
4. Result: Did not work

### Attempt 5: SwiftUI @FocusState
1. Added @FocusState to TerminalContainer
2. Added .focusable() and .focused() modifiers
3. Added onAppear and onTapGesture to trigger focus
4. Result: Did not work

### Attempt 6: NSApp.activate and AppDelegate
1. Added NSApplicationDelegateAdaptor with AppDelegate
2. Called NSApp.activate(ignoringOtherApps: true) on launch
3. Called makeKeyAndOrderFront on window
4. Result: Did not work - even TextField still broken

---

## Root Cause Hypotheses

| Analysis | Possible Root Causes | Date: 13 January 2026 | Time: 06:02 PM | Name: Lyra |

### Hypothesis 1: Swift Package Executable Limitation
Swift Package executables are not proper .app bundles. They lack:
1. Info.plist with application type settings
2. Proper bundle structure
3. Entitlements file
4. LSUIElement and other required keys

### Hypothesis 2: Missing Info.plist
macOS apps typically need Info.plist with:
1. NSHighResolutionCapable
2. LSApplicationCategoryType
3. Proper bundle identifier
4. Application is foreground app settings

### Hypothesis 3: Sandbox/Security
1. App might be running with restrictions
2. Keyboard input might require specific entitlements
3. Accessibility permissions might be needed

### Hypothesis 4: Window/App Activation
1. The app might not be properly becoming "active"
2. Window might not be becoming "key window"
3. Some macOS security feature blocking keyboard

### Hypothesis 5: Need Proper Xcode Project
1. Swift Package executable might fundamentally not support GUI apps with keyboard
2. Might need proper .xcodeproj with all settings
3. Might need code signing

---

## Next Steps (Discussion Needed)

1. Should we create a proper Xcode project instead of Swift Package?
2. Should we add Info.plist manually to the executable?
3. Should we test if a minimal SwiftUI app (no SwiftTerm) has same issue?
4. Should we research Swift Package GUI app keyboard issues specifically?

---

## Keyboard Shortcuts (Implemented)

| Shortcut | Action |
|----------|--------|
| ⌘T | New Terminal in selected workspace |
| ⌘⇧N | New Workspace |
| ⌘⌃S | Toggle Sidebar |

---

## Future Enhancements (Planned)
1. Terminal tab bar for multiple terminals in same workspace
2. Split pane support (horizontal/vertical)
3. Theme customization (colors, fonts)
4. Session persistence (restore terminals on app launch)
5. Search within terminal output
