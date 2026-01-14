# Workspace Manager - progress.md

## Task Tracking

---

| Progress Todo | Config-Driven Implementation | Date: 14 January 2026 | Time: 11:10 PM | Name: Lyra |

### Completed Tasks
1. ✅ Native macOS app with SwiftUI interface.
2. ✅ Embedded terminal using SwiftTerm with full PTY support.
3. ✅ Glass/transparent UI with blur effect.
4. ✅ Workspace sidebar with expandable workspace trees.
5. ✅ Multiple terminal sessions per workspace.
6. ✅ Bar cursor, configurable font/size, 1M line scrollback.
7. ✅ Removed duplicate sidebar toggle button.
8. ✅ **Config-driven workspaces** — TOML config at `~/.config/workspace-manager/config.toml`
9. ✅ ConfigService for loading/parsing TOML configuration.
10. ✅ Terminal settings from config (font, font_size, scrollback, cursor_style).
11. ✅ Workspaces from config (name + path pairs).
12. ✅ Default config generation on first launch.
13. ✅ **Terminal state persistence** — Terminals stay alive when switching tabs.

---

| Progress Todo | Terminal Persistence | Date: 14 January 2026 | Time: 11:28 PM | Name: Lyra |

### Problem
1. Switching between terminals caused state loss — shell history, running processes, all wiped.
2. Root cause: SwiftUI destroyed TerminalView on selection change due to `.id(terminal.id)` modifier.
3. Each switch spawned a fresh shell process instead of preserving existing one.

### Solution
1. Changed TerminalContainer from conditional rendering to ZStack with all terminals.
2. All terminals render simultaneously, visibility controlled by `opacity` (1 or 0).
3. Non-selected terminals use `allowsHitTesting(false)` to prevent interaction.
4. Shell processes stay alive in background, just hidden from view.
5. Commit: `60a82ad` — persist terminal state across tab switches.

---

| Progress Todo | Zed-Style Sidebar Redesign | Date: 14 January 2026 | Time: 11:41 PM | Name: Lyra |

### Problem
1. NavigationSplitView gave standard macOS sidebar look with heavy divider and chrome.
2. Wanted cleaner, Zed-style integrated panel that feels part of the window.
3. Sidebar had opaque background breaking the glass aesthetic.

### Solution
1. Replaced NavigationSplitView with simple HStack layout.
2. Added ⌘B keyboard shortcut for instant sidebar toggle (no animation).
3. Changed sidebar material from `.sidebar` to `.hudWindow` for matching glass effect.
4. Removed all dividers and opaque backgrounds (including terminal header).
5. Added ⌘T shortcut for new terminal creation.
6. Commit: `e276498` — zed-style sidebar with seamless glass UI.

---

| Progress Todo | Minimal Window Chrome | Date: 15 January 2026 | Time: 12:04 AM | Name: Lyra |

### Problem
1. Window had visible title bar with "WorkspaceManager" text and traffic lights.
2. After hiding traffic lights, grey titlebar strip remained.
3. Glass background wasn't unified — some areas had blur, others were transparent.

### Solution
1. Used `.hiddenTitleBar` window style to remove all window chrome.
2. Hidden traffic lights via `standardWindowButton().isHidden = true`.
3. Created single full-window glass background in ContentView with `.ignoresSafeArea()`.
4. Removed duplicate backgrounds from sidebar and terminal container.
5. Commit: `3ccc55c` — minimal window with unified glass background.

### Next Steps
1. Keyboard navigation for terminal switching (⌘I/⌘K for up/down, ⌘J/⌘L for focus).
2. Hot-reload config without app restart (optional enhancement).
3. Config validation with helpful error messages.
