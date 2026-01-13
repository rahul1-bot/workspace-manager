# Workspace Manager - memory.md

## Insights and Learnings

---

| Memory | Terminal Rendering Pipelines | Date: 13 January 2026 | Time: 05:49 PM | Name: Lyra |

### Why tmux Feels Laggy vs Native Terminals

Understanding gained while researching why Rahul's tmux experience felt "broken" compared to Warp:

1. tmux Rendering Path (High Latency)
    1. Shell output goes to PTY
    2. tmux captures and processes in CPU
    3. tmux renders to escape codes (ANSI sequences)
    4. Host terminal parses escape codes
    5. Host terminal finally renders via GPU
    6. Total latency: 50-200ms per frame, refresh rate ~10-20 FPS

2. Native Terminal Path (Low Latency)
    1. Shell output goes to PTY
    2. Terminal emulator renders directly via Metal/GPU
    3. ProMotion sync at 120Hz
    4. Total latency: ~8ms per frame

3. Key Insight
    1. tmux is not a terminal - it is a text-based application running INSIDE a terminal
    2. tmux draws "fake" windows using Unicode box characters and cursor repositioning
    3. Every scroll in tmux requires full screen redraw via escape sequences
    4. Native terminals keep content in GPU memory, scroll is just a transform

---

| Memory | SwiftUI + NSViewRepresentable Focus Issues | Date: 13 January 2026 | Time: 05:49 PM | Name: Lyra |

### First Responder Challenges in SwiftUI

1. SwiftUI does not automatically manage first responder for embedded AppKit views
2. NSViewRepresentable views need manual focus management
3. The correct approach uses NSApplication.shared.mainWindow?.makeFirstResponder()
4. Timing matters - must use DispatchQueue.main.async or asyncAfter for focus calls
5. Hit testing may need customization to properly route events to embedded views

### Research Sources Used
1. SerialCoder tutorial on focusable text fields in SwiftUI
2. Swift Forums discussion on TextField focus/firstResponder
3. Chris Eidhof's article on UIViewRepresentable patterns
4. SwiftTerm GitHub discussions

---

| Memory | SwiftTerm Library Characteristics | Date: 13 January 2026 | Time: 05:49 PM | Name: Lyra |

### SwiftTerm Overview

1. VT100/Xterm terminal emulator written in Swift
2. Used in commercial apps: Secure Shellfish, La Terminal, CodeEdit
3. Provides LocalProcessTerminalView for macOS (AppKit NSView)
4. Class methods are not `open` - cannot subclass to override behavior
5. Has SwiftTermApp example (iOS/SwiftUI) but marked as not actively maintained

### LocalProcessTerminalView Key Points
1. Requires sandbox to be disabled for full shell access
2. startProcess() launches shell in pseudo-terminal
3. configureNativeColors() sets up proper terminal colors
4. acceptsFirstResponder should return true (need to verify)

---

| Memory | Project Evolution | Date: 13 January 2026 | Time: 05:49 PM | Name: Lyra |

### From TUI to Native App

1. Started with Python Textual TUI approach
2. Realized TUI cannot embed native terminal windows
3. Pivoted to native macOS app with SwiftUI + SwiftTerm
4. Successfully built UI with workspace sidebar and terminal embedding
5. Terminal renders and shell starts correctly
6. Blocked on keyboard input - first responder issue

### What Works
1. App launches and displays correctly
2. Workspaces load from predefined courses
3. Terminal creation and switching works
4. Shell process starts and shows prompt
5. Visual rendering is smooth

### What Doesn't Work
1. Keyboard input not received by terminal
2. Cannot type in the terminal despite it being visible

---

| Memory | App Activation Policy and SwiftPM Executable Behavior | Date: 13 January 2026 | Time: 06:28 PM | Name: Ghost |

### Observation
    1. Keyboard input fails across all views (SwiftUI TextField, shortcuts, terminal), which points to the app not being key/active rather than a SwiftTerm focus issue.
    2. The project is a SwiftPM executable with no Info.plist or app bundle, which can prevent macOS from granting key window status.
    3. SwiftTerm does not appear to install global key event monitors that would swallow app-wide input.

### Implication
    1. The highest-probability fix is to force NSApp activation policy to regular and/or run the app as a proper .app bundle.

---

| Memory | Activation Policy Enforcement and Input Diagnostics | Date: 13 January 2026 | Time: 06:39 PM | Name: Ghost |

### Observation
    1. Added activation policy enforcement during launch to ensure the app can become key and active.
    2. Added activation state logging (active status, activation policy, key window, main window, first responder).
    3. Added local keyDown and flagsChanged event monitors in debug builds to confirm whether input events are delivered.

### Implication
    1. If logs show no key events, the app is still not key/active and must be run as a proper .app bundle.
    2. If logs show key events but UI does not respond, the responder chain or first responder assignment is still incorrect.

---

| Memory | SwiftPM Run Activation Logs | Date: 13 January 2026 | Time: 06:39 PM | Name: Ghost |

### Observation
    1. Running the app via SwiftPM shows the app becomes active and the window becomes key.
    2. Activation policy reports as regular, with key and main window present.
    3. First responder reports as SwiftUI.KeyViewProxy at launch.

### Implication
    1. The app can become key/active under SwiftPM, so the remaining question is whether key events are delivered.
    2. A manual keypress in the running app is required to confirm whether keyDown events are seen by the local monitor.

---

| Memory | Focus Targeting via Window Reference | Date: 13 January 2026 | Time: 06:39 PM | Name: Ghost |

### Observation
    1. Updated the terminal focus code to use the wrapper view’s own window reference instead of NSApplication.shared.mainWindow.
    2. This prevents focus calls from failing when mainWindow is nil or stale.

### Implication
    1. If focus was being routed to a nil or non-key window, this change should improve input capture for the terminal.

---

| Memory | Click Activation and App Bundle Attempt | Date: 13 January 2026 | Time: 07:36 PM | Name: Ghost |

### Observation
    1. Added a root-level tap activation hook to force NSApp activation on any click inside the app.
    2. Created scripts to build and run a minimal .app bundle via Launch Services.
    3. App bundle build is currently blocked by an unaccepted Xcode license.
    4. SwiftPM run is now also blocked by the same license prompt.

### Implication
    1. If the app remains inactive on click, the bundle launch path is still required.
    2. Xcode license acceptance is a hard blocker for the bundle build on this machine.

---

| Memory | Direct Terminal View Focus Strategy | Date: 13 January 2026 | Time: 07:47 PM | Name: Ghost |

### Observation
    1. Removed the wrapper NSView and now return LocalProcessTerminalView directly from NSViewRepresentable.
    2. Added a click gesture recognizer to force the terminal view to become first responder.
    3. Ensured updateNSView reasserts first responder when SwiftUI updates.
    4. Removed SwiftUI FocusState modifiers that could steal keyboard focus.

### Implication
    1. If the terminal still cannot receive input, the responder chain is being reset elsewhere or the view is never first responder.

---

| Memory | App Bundle Relaunch Behavior | Date: 13 January 2026 | Time: 07:47 PM | Name: Ghost |

### Observation
    1. Launch Services refused to open the bundle when a previous instance was still running (RBSRequestErrorDomain Code 5).
    2. Terminating the running app process allowed the bundle to launch successfully.

### Implication
    1. When testing, ensure only one bundle instance is running to avoid false negatives.
