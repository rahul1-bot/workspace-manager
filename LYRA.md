# Workspace Manager - LYRA.md

## Project Overview
| Field | Value |
|-------|-------|
| Project Name | Workspace Manager |
| Type | Native macOS Application |
| Purpose | Embedded GPU-accelerated terminal inside a workspace orchestrator |
| Tech Stack | Swift, SwiftUI, Metal (MTKView), SwiftTerm core (PTY + parser) |
| Target | macOS 14+ with Apple Silicon and 120Hz rendering |

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

## Current Status

| Status | Focus | Date: 13 January 2026 | Time: 08:31 PM | Name: Lyra |

### What WORKS
1. App launches as a bundle and receives keyboard input.
2. Workspace orchestration UI is stable.

### What DOES NOT WORK
1. Terminal rendering is still CPU-bound and cannot hit 120Hz.

### Immediate Objective
1. Implement MetalTerminalView and integrate it into the terminal container.
