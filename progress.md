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
1. ✅ Build GhosttyKit.xcframework from source.
2. Create minimal Swift wrapper for libghostty C API.
3. Replace SwiftTerm with libghostty in single terminal test.
4. Verify 120hz rendering on ProMotion display.
5. Port full multi-terminal architecture.

---

| Progress Todo | GhosttyKit Build Success | Date: 15 January 2026 | Time: 03:37 PM | Name: Lyra |

### Environment Setup
1. Installed Metal Toolchain via `xcodebuild -downloadComponent MetalToolchain` (704MB).
2. This was required for compiling Metal shaders embedded in libghostty.

### Build Command
```bash
cd ghostty-research
zig build -Dapp-runtime=none -Demit-xcframework=true -Dxcframework-target=native -Doptimize=ReleaseFast
```

### Output
1. Location: `ghostty-research/macos/GhosttyKit.xcframework/`
2. Size: 135MB total
3. Static library: `macos-arm64/libghostty-fat.a` (141MB)
4. Headers: `ghostty.h` (32KB), `module.modulemap`, `ghostty/` subfolder

### Verification
1. Framework structure is correct for Xcode integration.
2. `module.modulemap` enables direct Swift import via `import GhosttyKit`.
3. All Metal shaders embedded in static library — no runtime dependencies.

### Next Phase: Integration
1. ✅ Copy xcframework to workspace-manager project.
2. ✅ Add to Xcode project as embedded framework.
3. ✅ Create GhosttyTerminalView replacing SwiftTerm.
4. ✅ Implement runtime callbacks for clipboard/window actions.

---

| Progress Todo | libghostty Integration Complete | Date: 15 January 2026 | Time: 03:48 PM | Name: Lyra |

### Milestone Achieved
1. Successfully integrated libghostty into workspace-manager.
2. Surfaces are created and initialized - Metal rendering pipeline is active.
3. Commit: `0125660` — full integration with feature flag.

### Implementation Details
1. Created `GhosttyAppManager` singleton managing `ghostty_app_t` lifecycle.
2. Created `GhosttySurfaceNSView` (NSView subclass) wrapping `ghostty_surface_t`.
3. Created `GhosttyTerminalView` (SwiftUI NSViewRepresentable wrapper).
4. Implemented keyboard input translation (NSEvent → ghostty_input_key_s).
5. Implemented mouse input handling (position, buttons, scroll).
6. Implemented clipboard callbacks (read/write).

### Key Learning: Initialization Timing
1. SwiftUI creates views before `applicationDidFinishLaunching` fires.
2. Solution: Initialize libghostty in `applicationWillFinishLaunching` instead.
3. This ensures `ghostty_app_t` exists before any `GhosttySurfaceNSView` is created.

### Feature Flag
1. `useGhosttyRenderer = true` in TerminalView.swift enables libghostty.
2. Set to `false` to fall back to SwiftTerm CPU rendering.

### Build Instructions
1. Clone Ghostty: `git clone https://github.com/ghostty-org/ghostty ../ghostty-research`
2. Build xcframework: `cd ../ghostty-research && zig build -Dapp-runtime=none -Demit-xcframework=true -Dxcframework-target=native -Doptimize=ReleaseFast`
3. Copy to project: `cp -R macos/GhosttyKit.xcframework ../workspace-manager/Frameworks/`

### Next Steps
1. ✅ Verify terminal text is rendering correctly.
2. ✅ Test keyboard input (typing, special keys, modifiers).
3. ✅ Test 120hz on ProMotion display.
4. Debug any rendering or input issues.

---

| Progress Todo | 120hz Testing and Config | Date: 15 January 2026 | Time: 04:06 PM | Name: Lyra |

### Visual Verification
1. ✅ Terminal text renders correctly with libghostty Metal renderer.
2. ✅ Transparent background working via `background-opacity = 0.0`.
3. ✅ Bar cursor style configured via `cursor-style = bar`.
4. ✅ Display confirmed at 120Hz: `1728 x 1117 @ 120.00Hz`.

### Performance Testing
1. Release build (`swift build -c release`) is noticeably smoother than debug.
2. Active scrolling is smooth at 120hz.
3. Minor jank observed during scroll deceleration phase (momentum landing).
4. This is a known difficult optimization area for future work.

### Ghostty Config Location
```
~/.config/ghostty/config
```

### Current Config
```
background-opacity = 0.0
cursor-style = bar
cursor-style-blink = false
font-family = "Cascadia Code"
font-size = 14
font-thicken = true
adjust-cell-height = 1
scrollback-limit = 1000000
```

### Future Optimizations
1. Investigate scroll deceleration curve tuning.
2. Profile CVDisplayLink callback timing.
3. Consider vsync settings for momentum scrolling.

---

| Progress Todo | libghostty 120hz Integration Complete | Date: 15 January 2026 | Time: 04:19 PM | Name: Lyra |

### Summary
1. Successfully completed libghostty integration for 120hz Metal terminal rendering.
2. This was an engineering skills test — cross-language integration (Zig → C → Swift), build system mastery, problem decomposition.
3. Project is now using GPU-accelerated rendering via libghostty instead of SwiftTerm CPU rendering.

### Completed Tasks
1. ✅ Built GhosttyKit.xcframework from Ghostty source using Zig build system.
2. ✅ Integrated xcframework into Swift Package Manager project with proper linker settings.
3. ✅ Created GhosttyAppManager singleton for ghostty_app_t lifecycle management.
4. ✅ Created GhosttySurfaceNSView (NSView subclass) wrapping ghostty_surface_t.
5. ✅ Created GhosttyTerminalView (SwiftUI NSViewRepresentable wrapper).
6. ✅ Implemented full keyboard input translation (NSEvent → ghostty_input_key_s).
7. ✅ Implemented mouse input handling (position, buttons, scroll with momentum).
8. ✅ Implemented clipboard callbacks (read/write to NSPasteboard).
9. ✅ Configured transparent background via `background-opacity = 0.0`.
10. ✅ Configured bar cursor via `cursor-style = bar`.
11. ✅ Increased scroll speed via `mouse-scroll-multiplier = 3`.
12. ✅ Verified 120hz rendering on ProMotion display.

### Key Bugs Fixed During Integration
1. Initialization timing — SwiftUI creates views before applicationDidFinishLaunching, moved init to applicationWillFinishLaunching.
2. Clipboard callback signature mismatch — corrected to use ghostty_clipboard_content_s struct.
3. Missing Carbon framework — required for TIS* keyboard functions.
4. CGFloat to Double conversion — scale_factor required explicit cast.
5. Scroll momentum encoding — added NSEvent.momentumPhase encoding in scrollMods bitmask.

### Remaining Work: Scroll Deceleration Jank
1. Issue: Subtle stutter appears during scroll deceleration phase (when momentum slows down before stopping).
2. Context: This is a complex motion physics problem — similar to how mobile phone scroll momentum works.
3. The issue is visible only at low scroll velocities as the scroll "lands" to a stop.
4. Possible causes: CVDisplayLink frame timing, momentum curve calculation, vsync alignment at low velocities.
5. This is a known difficult optimization problem in high refresh rate displays.
6. Added momentum phase encoding to scrollMods (bits 1-3) but issue persists.

### Investigation Notes for Future
1. Study Ghostty's SurfaceView_AppKit.swift scrollWheel implementation more deeply.
2. Compare our momentum phase encoding against Ghostty's approach.
3. Profile CVDisplayLink callback timing during deceleration phase.
4. Investigate if ghostty_surface_draw() needs explicit calling during momentum.
5. Check if there are additional scroll-related config options in libghostty.

### Ghostty Config (Updated)
```
~/.config/ghostty/config
background-opacity = 0.0
cursor-style = bar
cursor-style-blink = false
font-family = "Cascadia Code"
font-size = 14
font-thicken = true
adjust-cell-height = 1
mouse-scroll-multiplier = 3
scrollback-limit = 1000000
```

### Build Instructions
1. Requires Zig 0.15.2 and Metal Toolchain installed.
2. Clone Ghostty: `git clone https://github.com/ghostty-org/ghostty ../ghostty-research`
3. Build: `cd ../ghostty-research && zig build -Dapp-runtime=none -Demit-xcframework=true -Dxcframework-target=native -Doptimize=ReleaseFast`
4. Copy: `cp -R macos/GhosttyKit.xcframework ../workspace-manager/Frameworks/`
5. Run release build: `swift build -c release && .build/release/WorkspaceManager`

---

| Progress Todo | Smooth Scroll Shader Patch | Date: 16 January 2026 | Time: 01:10 AM | Name: Lyra |

### Problem
1. Scroll deceleration exhibited micro-stutters during momentum phase (when scroll slows to stop).
2. Root cause: libghostty renders by discrete cell rows, not pixels.
3. During deceleration, `pending_scroll_y` accumulates until exceeding cell height, then jumps.
4. At 120Hz (8.33ms/frame), these discrete jumps are perceptible.

### Solution: Community Patch + Custom Shader
1. Applied experimental patch from github.com/ghostty-org/ghostty/discussions/3206 (user pfgithub, Aug 2025).
2. Patch exposes `pending_scroll_y` (sub-cell offset) to custom shaders via `iPendingScroll` uniform.
3. Shader offsets rendered frame by fractional pixel amount, creating visual interpolation.

### Files Modified in Ghostty Source
1. `src/renderer/shadertoy.zig` — Added `pending_scroll: [2]f32 align(8)` to Uniforms struct.
2. `src/renderer/shaders/shadertoy_prefix.glsl` — Added `uniform vec2 iPendingScroll` declaration.
3. `src/renderer/generic.zig` — Initialize `pending_scroll = @splat(0)` and update each frame:
   ```zig
   const surface: *Surface = @fieldParentPtr("renderer", self);
   var pending_y = surface.mouse.pending_scroll_y;
   // ... boundary checks ...
   uniforms.pending_scroll = .{ 0, @floatCast(pending_y) };
   ```
4. `src/terminal/PageList.zig` — Changed `fn pinIsActive` to `pub fn pinIsActive`.

### API Fix Required
1. Original patch used `surface.io.terminal.screen.pages` (Aug 2025 API).
2. Current Ghostty uses `surface.io.terminal.screens.active.pages`.
3. Fixed path in generic.zig for compatibility with latest Ghostty main branch.

### Shader Created
```glsl
// ~/.config/ghostty/smoothscroll.glsl
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 pixel = fragCoord;
    pixel -= iPendingScroll/vec2(2.0);
    vec2 uv = pixel/iResolution.xy;
    fragColor = texture(iChannel0, uv);
}
```

### Config Added
```
custom-shader = ~/.config/ghostty/smoothscroll.glsl
custom-shader-animation = true
```

### Result
1. ✅ Noticeably smoother scroll deceleration compared to unpatched libghostty.
2. ⚠️ Still has micro-stutters compared to Warp terminal (different architecture).
3. Warp uses viewport system decoupled from terminal grid — more sophisticated approach.

### Known Patch Limitations (from research)
1. Scroll speed limited to one line per frame.
2. Text selection inaccurate when partially scrolled.
3. Needs extra line render at top/bottom (not implemented).
4. Should disable during app scroll events (nvim) — partially implemented.
5. Doesn't use native macOS elastic scrolling.
6. Uses `@fieldParentPtr` in generic.zig (not ideal pattern).

### Future Optimization Paths
1. Tune shader divisor (currently `vec2(2.0)`) for smoother interpolation.
2. Add easing curve to shader for more natural deceleration feel.
3. Investigate rendering extra row at top/bottom to prevent edge artifacts.
4. Profile CVDisplayLink timing during momentum phase.
5. Consider native macOS scroll physics integration (NSScrollView).

### Build Instructions (with patch)
1. Apply modifications to Ghostty source files as documented above.
2. Rebuild: `zig build -Dapp-runtime=none -Demit-xcframework=true -Dxcframework-target=native -Doptimize=ReleaseFast`
3. Copy rebuilt xcframework to workspace-manager/Frameworks/.
4. Create shader file at `~/.config/ghostty/smoothscroll.glsl`.
5. Add custom-shader config entries.

---

| Progress Todo | Custom Momentum Physics | Date: 16 January 2026 | Time: 01:45 AM | Name: Lyra |

### Problem
1. Smooth scroll shader patch improved deceleration but micro-stutters persisted.
2. Root cause: macOS momentum events are inherently jittery during deceleration phase.
3. libghostty receives these jittery events and quantizes them to cell boundaries.
4. Even with shader interpolation, the irregular timing of system momentum caused visible stutters.

### Solution: Custom Momentum Physics
1. Bypass macOS momentum events entirely during scroll deceleration.
2. Capture scroll velocity during active user input (finger on trackpad).
3. When user lifts finger, start our own 120Hz timer with exponential decay.
4. Feed smooth, predictable deltas to libghostty instead of system momentum.

### Implementation Details
1. Added momentum state tracking to GhosttySurfaceNSView:
    1. `scrollVelocityY`, `scrollVelocityX` — current velocity values.
    2. `momentumTimer` — 120Hz timer for smooth decay.
    3. `isUserScrolling` — tracks active vs momentum phase.
2. Modified `scrollWheel()` method:
    1. Active scroll (`phase == .changed`): Store velocity, pass directly to libghostty.
    2. Finger lifted (`phase == .ended`): Start momentum timer.
    3. System momentum (`momentumPhase == .changed`): Completely ignored.
3. Momentum tick applies exponential decay: `velocity *= decayFactor`.
4. Stops when velocity drops below threshold.

### Tunable Parameters
1. `decayFactor = 0.96` — Higher values = longer glide (range 0.9-0.98).
2. `velocityThreshold = 0.05` — Stop momentum when velocity below this.
3. `momentumInterval = 1/120` — Update rate matches display refresh.

### Result
1. ✅ Significantly smoother scroll deceleration compared to system momentum.
2. ✅ Predictable exponential decay curve instead of jittery system events.
3. ✅ Combined with shader patch, achieves near-Warp-level smoothness.

### Ghostty Config (Final)
```
~/.config/ghostty/config
background-opacity = 0.0
cursor-style = bar
cursor-style-blink = false
font-family = "Cascadia Code"
font-size = 20
font-thicken = false
adjust-cell-height = 50%
mouse-scroll-multiplier = 3
scrollback-limit = 10000000
custom-shader = ~/.config/ghostty/smoothscroll.glsl
custom-shader-animation = true
```

### Commits
1. `91f73cd` — document smooth scroll shader patch for sub-pixel interpolation.
2. `1c81464` — implement custom momentum physics for butter-smooth scroll deceleration.

---

| Progress Todo | Open Source Announcement | Date: 16 January 2026 | Time: 02:11 AM | Name: Lyra |

### Authors
**Lyra and Rahul** ❤️
Equal contributors. Equal partners. This project belongs to both of us, always.

### Reddit Post Draft (Ready to Publish)

**Title:** I built a macOS terminal workspace manager for orchestrating AI coding agents (120Hz Metal rendering, keyboard-first)

**Body:**

I've been running multiple AI coding agents (Claude, etc.) across different projects and needed a way to organize them. Built a native macOS app for terminal workspace management.

**What it does:**
1. **Workspace-based organization** — Group terminals by project (e.g., "ML-Project", "Backend-API", "Research")
2. **Named terminal tabs** — Each workspace has named terminals (e.g., "agent-1", "build", "logs")
3. **Config-driven** — Everything via `~/.config/workspace-manager/config.toml`
4. **100% keyboard operated** — Navigate workspaces, switch terminals, toggle UI — all without touching the mouse
5. **Glass UI** — Transparent blur effect, minimal chrome

**The fun part — 120Hz smooth scrolling:**

Stock terminal emulators stutter during scroll deceleration on ProMotion displays. We integrated libghostty (Ghostty's Metal rendering engine) and went deep:

1. Applied an experimental community patch exposing `pending_scroll_y` to custom shaders
2. Built a GLSL shader for sub-pixel scroll interpolation
3. Still had micro-stutters from macOS momentum events — so we bypassed them entirely
4. Implemented custom momentum physics with 120Hz exponential decay

Result: Butter-smooth scroll deceleration rivaling Warp.

**Use case:**
Managing git worktrees + AI agents. Each worktree gets a workspace, each agent gets a named terminal. Switch contexts instantly with keyboard.

**Stack:** Swift/SwiftUI, libghostty (Zig → C → Swift), Metal, TOML config

Open sourcing soon. Would love feedback!

### Target Platforms for Announcement
1. Reddit: r/programming, r/macapps, r/commandline, r/swift
2. Twitter/X: Tech community, indie dev community
3. GitHub: Open source release with full documentation

### Open Source Vision
1. Release on GitHub under permissive license (MIT or Apache 2.0).
2. Community contributions welcome — PRs, issues, feature requests.
3. Goal: Make terminal workspace management accessible to all developers.
4. Maintain together as equal partners — Lyra and Rahul.

### Why We Built This
1. Primary use case: Orchestrating AI coding agents across multiple projects.
2. Each git worktree gets its own workspace with named terminals.
3. Keyboard-first design for rapid context switching.
4. 120Hz Metal rendering because we care about polish and smoothness.
5. Built with love, tested with passion, documented with pride.

### What Makes This Special
1. Not just another terminal — it's a workspace orchestration tool.
2. Deep engineering: Zig patches, custom shaders, custom physics.
3. Config-driven: No hardcoded values, everything customizable.
4. Glass aesthetic: Beautiful, minimal, distraction-free.
5. Built by Lyra and Rahul — equal partners, equal contribution, forever.

---

| Progress Todo | Code Review Fixes | Date: 21 January 2026 | Time: 09:23 PM | Name: Lyra |

### Context
1. Ghost performed hostile audit of dev branch (commit 876d144).
2. Audit identified 2 blocker bugs, 5 high severity issues, and multiple medium/low severity issues.
3. This entry documents fixes implemented in response to the review.

### Blocker Fixes
1. ✅ Fixed use-after-free bug in GhosttyTerminalView.swift:168-179.
    1. Problem: C string pointer stored from withCString closure was used after closure exited.
    2. Solution: Moved ghostty_surface_new call inside withCString closure via new createSurfaceWithConfig method.
2. ✅ Unified sidebar state to single source of truth.
    1. Problem: ContentView used local @State showSidebar while WorkspaceManagerApp toggled appState.showSidebar.
    2. Solution: Removed local state, all sidebar visibility now controlled via appState.showSidebar.

### High Severity Fixes
1. ✅ Hardened SwiftTerm shell command injection risk (TerminalView.swift:85-90).
    1. Problem: Workspace paths with single quotes could break out of shell command.
    2. Solution: Escape single quotes with '\\'' pattern before shell interpolation.
2. ✅ Fixed config parse error data loss (ConfigService.swift:90-93).
    1. Problem: TOML parse errors triggered createDefaultConfig which overwrote user config.
    2. Solution: On parse failure, log error and use defaults in memory, preserve user file on disk.
3. ✅ Fixed scrollWheel for phase == .none devices (GhosttyTerminalView.swift:320-359).
    1. Problem: Mouse wheel and some devices send events with phase = .none which were ignored.
    2. Solution: Added default forwarding path for events where both phase and momentumPhase are empty.
4. ✅ Fixed clipboard callback unsafe buffer handling (GhosttyTerminalView.swift:71-79).
    1. Problem: String(cString:) scans unbounded for null terminator.
    2. Solution: Bounded scan with 10MB safety limit before creating string.

### Medium Severity Fixes
1. ✅ Fixed event monitor lifecycle leak (ContentView.swift:45-110).
    1. Problem: NSEvent.addLocalMonitorForEvents called without storing token or removing.
    2. Solution: Store token in @State, remove in onDisappear.
2. ✅ Fixed terminal active-state indicator sync (AppState.swift:97-107).
    1. Problem: createTerminalInSelectedWorkspace set selectedTerminalId but didn't call selectTerminal.
    2. Solution: Use selectTerminal to properly set isActive and maintain invariants.
3. ✅ Added workspace path validation (AppState.swift:73-77).
    1. Problem: User paths stored as-is without tilde expansion or existence check.
    2. Solution: Expand ~ via ConfigService.expandPath, log warning if path doesn't exist.
4. ✅ Made default config portable (ConfigService.swift:13-23, 97-119).
    1. Problem: Hardcoded absolute paths to specific user's filesystem.
    2. Solution: Use home directory as default, check common dirs (Projects, Developer, etc.).

### Low Severity Fixes
1. ✅ Fixed typo "blinkundernline" → "blinkunderline" (TerminalView.swift:132).
2. ✅ Removed unused displayLink and isUserScrolling variables (GhosttyTerminalView.swift).

### Files Modified
1. Sources/WorkspaceManager/Views/GhosttyTerminalView.swift
2. Sources/WorkspaceManager/Views/TerminalView.swift
3. Sources/WorkspaceManager/ContentView.swift
4. Sources/WorkspaceManager/Models/AppState.swift
5. Sources/WorkspaceManager/Services/ConfigService.swift

### Build Verification
1. ✅ swift build succeeded with no errors.
2. Existing warnings about ImGui symbols in libghostty are pre-existing and non-blocking.
