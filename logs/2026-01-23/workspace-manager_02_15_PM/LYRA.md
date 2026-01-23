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

### Config Structure (Source of Truth)
```toml
[terminal]
font = "Cascadia Code"
font_size = 14
scrollback = 1000000
cursor_style = "bar"
use_gpu_renderer = true  # true = libghostty Metal, false = SwiftTerm CPU

[appearance]
show_sidebar = true

[[workspaces]]
name = "Project Name"
path = "~/path/to/workspace"
```

### Architecture: Config-Driven Design
1. config.toml is the ONLY source of truth for workspaces and app settings
2. No workspaces.json - removed entirely
3. Terminals are runtime-only (shell processes, not persisted)
4. UI adds/removes workspaces directly to config.toml
5. Workspaces have stable UUIDs preserved across restarts
6. Workspace names must be unique

### Terminal Renderer Configuration
1. When `use_gpu_renderer = true` (default):
   - Uses libghostty Metal renderer (120Hz smooth scrolling)
   - Terminal appearance (font, colors) configured via `~/.config/ghostty/config`
   - The `[terminal]` settings in config.toml (font, font_size, etc.) do NOT apply
2. When `use_gpu_renderer = false`:
   - Uses SwiftTerm CPU renderer (fallback)
   - The `[terminal]` settings in config.toml fully apply

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

---

## Status Update

| Status | Focus | Date: 22 January 2026 | Time: 12:03 PM | Name: Ghost |

### Fixes and Verification
1. Verified config bootstrap behavior: the app no longer launches into an empty sidebar when config.toml exists but contains no workspaces.
2. Verified preferred root behavior:
   1. The study workspace root is used as the default landing directory when it exists.
   2. Terminals fall back to the study root before falling back to home.
3. Verified shortcut reliability:
   1. Cmd+T is handled case-insensitively and can create a terminal even when no workspace is selected (bootstraps selection/workspace as needed).
4. Arrow-key glyph issue:
   1. Observed arrow keys rendering as literal glyphs (left/right/up/down) in the terminal.
   2. Fixed by ignoring macOS function-key Unicode scalars (U+F700-U+F8FF) in the text path so those keys are routed via keycode/modifiers only.

---

| Status | Focus | Date: 22 January 2026 | Time: 02:29 PM | Name: Ghost |

### Follow-up Fixes
1. Arrow keys:
   1. Issue persisted in certain interactive UIs, indicating key event encoding needed to more closely match upstream Ghostty macOS behavior.
   2. Updated keyboard event encoding to set consumed_mods and unshifted_codepoint, respect repeat events, and explicitly route arrow keys via keycode/modifiers only.
2. Developer ergonomics:
   1. Added scripts/run.sh as a single build-and-open entrypoint (debug or release).
   2. Added user aliases (wm, wmr) in ~/.zshrc to run the script without manual cd/build/open steps.
3. Readability:
   1. Increased Ghostty font size to 18 via ~/.config/ghostty/config.

---

| Status | Focus | Date: 22 January 2026 | Time: 03:07 PM | Name: Ghost |

### Verified Outcome
1. Confirmed arrow keys now behave correctly (no glyph artifacts) in the running app.
2. Confirmed terminal readability improvement with font-size 18.
3. Confirmed workflow is now one-command:
   1. Repo: scripts/run.sh (debug/release).
   2. Shell: wm/wmr aliases (user-local).

---

| Status | Focus | Date: 23 January 2026 | Time: 01:26 PM | Name: Ghost |

### New Capabilities
1. Workspace roster now matches the study workflow:
   1. Root workspace points to the study root and is persisted as "Root" in config.toml.
   2. Course workspaces are auto-added (AI-2 Project, Computational Imaging, Representation Learning, ML in MRI, Movement Analysis) when their folders exist.
2. Inline rename:
   1. Double click workspace/terminal name to rename inline.
   2. Cmd+R renames the selected workspace/terminal inline (no dialog).
   3. Enter commits, Escape cancels; workspace renames persist to config.toml.
3. Sidebar terminal icon:
   1. Switched terminal row icon to a bundled PNG resource (terminal-icon.png).
   2. Updated app bundling script to include the SwiftPM resource bundle so icons load in Build/WorkspaceManager.app.
4. Keymap adjustments:
   1. Cmd+[ and Cmd+] cycle across workspaces.
   2. Shift+Cmd+R performs config reload (Cmd+R reserved for rename).

---

| Status | Focus | Date: 23 January 2026 | Time: 02:03 PM | Name: Ghost |

### Follow-up Fixes
1. Rename propagation:
   1. Fixed terminal header staying on the pre-rename name by resolving header labels from AppState by ID.
2. Terminal icon rendering:
   1. Switched terminal icon rendering to preserve original PNG colors (removed template tinting).
3. Keymap expansion:
   1. Cmd+E toggles workspace expand/collapse.
   2. Cmd+O opens selected workspace in Finder.
   3. Option+Cmd+C copies selected workspace path.
   4. Cmd+1..Cmd+9 jumps to workspace by index.
