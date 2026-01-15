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

---

| Progress Todo | Keyboard Navigation | Date: 15 January 2026 | Time: 12:19 AM | Name: Lyra |

### Problem
1. Terminal switching required mouse clicks on sidebar.
2. No way to navigate terminals without showing sidebar.
3. When switching terminals via keyboard, focus didn't follow — keystrokes went to old terminal.

### Solution
1. Added ⌘I (previous) and ⌘K (next) for quick terminal cycling — works even with sidebar hidden.
2. Added ⌘J to focus sidebar (shows if hidden) with arrow key navigation.
3. Added ⌘L to return focus to terminal.
4. Added `isSelected` parameter to TerminalView — only selected terminal requests first responder.
5. Added `selectPreviousTerminal()` and `selectNextTerminal()` to AppState with cycling logic.
6. Commit: `7398580` — keyboard navigation for terminal switching.

### Keymaps Summary
1. ⌘B — Toggle sidebar visibility (focus stays on terminal).
2. ⌘I — Previous terminal (cycles).
3. ⌘K — Next terminal (cycles).
4. ⌘J — Focus sidebar (show if hidden).
5. ⌘L — Focus terminal.
6. ⌘T — New terminal.
7. ↑/↓ — Navigate when sidebar focused.
8. Enter — Select and focus terminal.

### Next Steps
1. **libghostty integration** — Replace SwiftTerm with Ghostty's Metal renderer for 120hz.
2. Hot-reload config without app restart (optional enhancement).
3. Config validation with helpful error messages.
4. Additional terminal settings (colors, themes).

---

| Progress Todo | Future Research: libghostty | Date: 15 January 2026 | Time: 02:41 AM | Name: Lyra |

### Research Summary
1. Ghostty's macOS app is Swift/SwiftUI consuming libghostty via C API.
2. libghostty provides Metal rendering, font shaping, PTY handling — 120fps possible.
3. Architecture: Zig core → C static library (.a) → Swift bridging header → SwiftUI app.
4. libghostty-vt (VT parser) released September 2025, but full rendering API not yet stable.

### Integration Plan (Weekend Project)
1. Clone Ghostty repo: `git clone https://github.com/ghostty-org/ghostty`
2. Study `/macos` folder — see how Swift integrates with libghostty.
3. Build libghostty as static lib (requires Zig toolchain).
4. Create Swift bridging header to expose C API.
5. Replace SwiftTerm view with libghostty surface calls.
6. Each terminal = one libghostty surface.

### Resources
1. GitHub: https://github.com/ghostty-org/ghostty
2. libghostty announcement: https://mitchellh.com/writing/libghostty-is-coming
3. Ghostty docs: https://ghostty.org/docs/about

### Status
1. ✅ Research completed — full codebase reconnaissance done.
2. Ready for Phase 2: Build and Integration.

---

| Progress Todo | libghostty Deep Reconnaissance | Date: 15 January 2026 | Time: 03:32 PM | Name: Lyra |

### Objective
1. Understand Ghostty's architecture for 120hz Metal terminal rendering integration.
2. This is an engineering skills test — problem decomposition, cross-language integration, build system mastery.

### Environment Setup
1. ✅ Installed Zig 0.15.2 via Homebrew.
2. ✅ Verified Xcode 26.2 (required for Ghostty main branch).
3. ✅ Cloned Ghostty repo to `../ghostty-research/`.

### Agent-1 Findings: macOS Swift Architecture
1. Swift imports `GhosttyKit` module (XCFramework).
2. libghostty manages ALL Metal rendering internally — Swift does not touch Metal directly.
3. Swift passes `NSView*` pointer via `config.platform.macos.nsview`.
4. libghostty creates `CAMetalLayer` as backing layer automatically.
5. `CVDisplayLink` triggers rendering at display refresh rate (120hz on ProMotion).
6. Key file: `SurfaceView_AppKit.swift` (98KB) — handles all input event routing.
7. Bridging header only imports `VibrantLayer.h` (minimal).

### Agent-2 Findings: C API Surface
1. Opaque types: `ghostty_app_t`, `ghostty_config_t`, `ghostty_surface_t`.
2. Initialization: `ghostty_init()` → `ghostty_config_new()` → `ghostty_app_new()` → `ghostty_surface_new()`.
3. Rendering: `ghostty_app_tick()` (process work) + `ghostty_surface_draw()` (render frame).
4. Input: `ghostty_surface_key()`, `ghostty_surface_mouse_button()`, `ghostty_surface_text()`.
5. Size: `ghostty_surface_set_size()`, `ghostty_surface_set_content_scale()`.
6. Callback-driven architecture via `ghostty_runtime_config_s` struct.
7. Platform config takes `NSView*` directly in `ghostty_surface_config_s.platform.macos.nsview`.

### Agent-3 Findings: Build System
1. Build command for XCFramework:
    ```
    zig build -Dapp-runtime=none -Demit-xcframework=true -Dxcframework-target=native -Doptimize=ReleaseFast
    ```
2. Output location: `macos/GhosttyKit.xcframework/macos-arm64_x86_64/libghostty.a`.
3. Metal shaders are EMBEDDED in the static library (no separate .metallib files).
4. All dependencies bundled into single fat static library via `libtool -static`.
5. Key flags: `-Dapp-runtime=none` (library mode), `-Dxcframework-target=native` (faster iteration).

### Integration Architecture
1. Add `GhosttyKit.xcframework` to workspace-manager Xcode project.
2. Create `GhosttyTerminalView` (NSViewRepresentable) replacing SwiftTerm's `LocalProcessTerminalView`.
3. Initialize libghostty once at app launch via `ghostty_init()`.
4. Create shared `ghostty_app_t` instance managed by AppState.
5. Each terminal = one `ghostty_surface_t` attached to its NSView.
6. Route keyboard/mouse events from SwiftUI through C API.
7. Implement runtime callbacks for clipboard, window actions, close handling.

### Next Actions
1. Build GhosttyKit.xcframework from source.
2. Create minimal Swift wrapper for libghostty C API.
3. Replace SwiftTerm with libghostty in single terminal test.
4. Verify 120hz rendering on ProMotion display.
5. Port full multi-terminal architecture.
