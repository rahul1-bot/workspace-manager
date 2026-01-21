# Workspace Manager - LYRA.md

## Problem Statement

A simple terminal orchestration app for macOS. The goal is to provide a better workspace management experience than tmux — with a native UI, multiple terminal sessions organized by workspaces, and a clean minimalistic config-driven experience.

---

## Project Overview

| Field | Value |
|-------|-------|
| Project Name | Workspace Manager |
| Type | Native macOS Application |
| Purpose | Terminal orchestration with workspace management |
| Tech Stack | Swift, SwiftUI, SwiftTerm (CPU renderer), TOMLKit |
| Target | macOS 14+ on Apple Silicon |
| Config | `~/.config/workspace-manager/config.toml` |

---

## Current Status

| Status | Focus | Date: 21 January 2026 | Time: 09:23 PM | Name: Lyra |

### What WORKS
1. Native macOS app with SwiftUI interface.
2. Embedded terminal using SwiftTerm with full PTY support (fallback) or libghostty Metal renderer (default).
3. Glass/transparent UI with blur effect (NSVisualEffectView).
4. Workspace sidebar with expandable workspace trees.
5. Multiple terminal sessions per workspace.
6. **Config-driven**: All settings in `~/.config/workspace-manager/config.toml`
7. Terminal settings from config: font, font_size, scrollback, cursor_style.
8. Workspaces from config: name + path pairs.
9. **Terminal state persistence**: Switching tabs preserves shell state (ZStack + opacity approach).
10. **Zed-style sidebar**: Seamless glass panel with ⌘B toggle, no NavigationSplitView chrome.
11. **Minimal window**: No title bar, no traffic lights, unified glass background everywhere.
12. **Keyboard navigation**: ⌘I/K for terminal cycling, ⌘J/L for sidebar/terminal focus, arrow keys in sidebar.
13. **120Hz Metal rendering**: libghostty integration with custom momentum physics for butter-smooth scrolling.

### Recent Fixes (21 January 2026)
1. Fixed use-after-free bug in C-interop for working_directory pointer lifetime.
2. Unified sidebar state to single source of truth (AppState.showSidebar).
3. Fixed event monitor lifecycle leak in ContentView (proper cleanup on disappear).
4. Hardened SwiftTerm shell command path to prevent injection via quote escaping.
5. Fixed config parse error handling - no longer destroys user config on failure.
6. Added scroll wheel support for non-trackpad devices (phase == .none handling).
7. Fixed clipboard callback with bounded buffer handling for safety.
8. Fixed terminal active-state indicator sync when creating new terminals.
9. Added workspace path validation and tilde expansion.
10. Made default config portable (uses home directory, not hardcoded paths).

### Config File Location
```
~/.config/workspace-manager/config.toml
```

### Config Structure
```toml
[terminal]
font = "Cascadia Code"
font_size = 14
scrollback = 1000000
cursor_style = "bar"

[[workspaces]]
name = "Root"
path = "~/path/to/workspace"
```

---

## Architecture

### Files
- `Sources/WorkspaceManager/Models/Config.swift` — Config data structures
- `Sources/WorkspaceManager/Services/ConfigService.swift` — TOML loading/parsing
- `Sources/WorkspaceManager/Models/AppState.swift` — Loads workspaces from config
- `Sources/WorkspaceManager/Views/TerminalView.swift` — Reads terminal settings from config

### Data Flow
```
App Launch → ConfigService.loadConfig() → Parse TOML → AppState initializes with workspaces
```

---

## Future Watch Items
1. libghostty Swift framework release (monitor Ghostty releases).
2. SwiftTerm Metal renderer (monitor issue #202).
