# Workspace Manager - LYRA.md

## Project Overview
| Field | Value |
|-------|-------|
| Project Name | Workspace Manager |
| Type | Native macOS Application |
| Purpose | Embedded terminal inside a workspace orchestrator |
| Tech Stack | Swift, SwiftUI, SwiftTerm (CPU renderer) |
| Target | macOS 14+ on Apple Silicon |

---

## Architecture Decision Record

| ADR | Decision | Date: 13 January 2026 | Time: 08:31 PM | Name: Lyra |

### Context
1. The app must embed the terminal inside its own UI; external terminals are not acceptable.
2. SwiftTerm’s macOS renderer is CPU-bound and cannot reach 120Hz.
3. Warp is closed-source and does not provide an embeddable terminal view.

### Decision
1. Build a Metal-backed terminal renderer using MTKView.
2. Use SwiftTerm core (PTY + parser) as the data source, replacing only the rendering layer.

### Consequences
1. Requires a glyph atlas, GPU text rendering, and dirty-rect updates.
2. Adds complexity but enables true in-app 120Hz rendering on Apple Silicon.

---

| ADR | Decision | Date: 13 January 2026 | Time: 10:53 PM | Name: Lyra |

### Context
1. Multiple Metal renderer prototypes rendered incorrect glyphs (full-grid block fill).
2. Release bundle validation confirmed the issue persisted.

### Decision
1. Pause Metal renderer development on main.
2. Return to SwiftTerm CPU renderer for stability.
3. Preserve GPU work on the metal-renderer branch for future debugging.

### Consequences
1. Main branch regains a functional terminal.
2. 120Hz GPU rendering is deferred until atlas/shader issues are resolved.

---

| ADR | Decision | Date: 14 January 2026 | Time: 09:37 PM | Name: Lyra |

### Context
1. Custom Metal renderer attempt failed due to glyph atlas/shader issues (full-grid block fill symptom).
2. Research conducted on existing GPU-accelerated terminal solutions for embedding.
3. The core goal is workspace orchestration, not terminal rendering innovation.

### Research Findings
1. No drop-in GPU-accelerated embeddable terminal library exists for Swift/SwiftUI as of January 2026.
2. Ghostty (by Mitchell Hashimoto) has libghostty — a C-compatible library with Metal rendering. The macOS Ghostty app is a SwiftUI app using libghostty internally. However, libghostty is NOT production-ready for external embedding; API is unstable with no official release yet. Future plans include Swift frameworks for terminal views.
3. SwiftTerm has an open issue (#202) for Metal renderer support. Miguel de Icaza is actively working on it as of August 2025, starting a fresh implementation after the original metal-backend branch proved too complex with poor performance.
4. All other GPU-accelerated terminals (Alacritty, kitty, Wezterm) are standalone applications, not embeddable libraries.

### Decision
1. Abandon custom Metal renderer development indefinitely.
2. Continue with SwiftTerm CPU renderer for terminal embedding.
3. Focus engineering effort on workspace orchestration UX — the actual value proposition.
4. Monitor libghostty and SwiftTerm Metal renderer progress for future adoption when stable.

### Consequences
1. Terminal rendering capped at ~60Hz CPU-bound performance, which is adequate for command-line workflows.
2. Engineering time redirected to orchestration features that differentiate the product.
3. Future GPU acceleration possible by adopting libghostty Swift framework or SwiftTerm Metal when available.

### Sources
1. Ghostty GitHub: https://github.com/ghostty-org/ghostty
2. libghostty announcement: https://mitchellh.com/writing/libghostty-is-coming
3. SwiftTerm Metal issue: https://github.com/migueldeicaza/SwiftTerm/issues/202

---

## Current Status

| Status | Focus | Date: 14 January 2026 | Time: 09:37 PM | Name: Lyra |

### What WORKS
1. App launches as a bundle and receives keyboard input.
2. Workspace orchestration UI is stable.
3. CPU-based terminal rendering functions reliably at 60Hz.

### What DOES NOT WORK
1. Metal renderer abandoned — glyph atlas issues unresolved, preserved on metal-renderer branch.

### Immediate Objective
1. Focus on workspace orchestration layer improvements.
2. Design and implement terminal session management, workspace switching, and layout features.

### Future Watch Items
1. libghostty Swift framework release (monitor Ghostty releases).
2. SwiftTerm Metal renderer stabilization (monitor issue #202).
