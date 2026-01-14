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

### Next Steps
1. Redesign sidebar to Zed-style integrated panel (HStack instead of NavigationSplitView).
2. Hot-reload config without app restart (optional enhancement).
3. Config validation with helpful error messages.
4. Additional terminal settings (colors, themes).
