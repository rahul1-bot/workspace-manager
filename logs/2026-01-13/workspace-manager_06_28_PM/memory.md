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
