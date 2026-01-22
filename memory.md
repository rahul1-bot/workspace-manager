# Workspace Manager - memory.md

## Insights and Learnings

---

| Memory | Scroll Deceleration Jank Analysis | Date: 15 January 2026 | Time: 04:19 PM | Name: Lyra |

### Observation
1. libghostty 120hz scrolling is smooth during active scroll motion.
2. Jank appears specifically during scroll deceleration (momentum slowdown).
3. The "landing" phase when scroll velocity approaches zero shows frame timing issues.
4. This is a known difficult problem — low velocity scroll requires precise frame timing.
5. Similar to mobile phone scroll momentum — the physics of "landing" a scroll smoothly is complex.

### Technical Details
1. NSEvent.momentumPhase encodes scroll momentum state: began, changed, ended, cancelled.
2. ghostty_input_scroll_mods_t is a packed bitmask: bit 0 = precision, bits 1-3 = momentum phase.
3. We encode momentum phase correctly but jank persists — issue may be deeper in libghostty.
4. Ghostty's own SurfaceView_AppKit.swift has extensive scroll handling (~100 lines).
5. Release build significantly smoother than debug — always test with release for scroll quality.

### Implication
1. The CVDisplayLink is working correctly for high-velocity scrolling.
2. Scroll momentum physics at low velocities may need tuning at libghostty level.
3. This may require studying Ghostty's internal scroll momentum interpolation.
4. Consider if explicit ghostty_surface_draw() calls needed during momentum phase.
5. This is an advanced optimization — core functionality works well, polish can come later.

---

| Memory | libghostty Integration Pattern | Date: 15 January 2026 | Time: 03:35 PM | Name: Lyra |

### Observation
1. libghostty is a callback-driven embedding API, not a view component.
2. The host app provides an NSView, libghostty creates CAMetalLayer as backing layer.
3. Metal rendering happens entirely inside libghostty — Swift never touches Metal directly.
4. CVDisplayLink (display refresh callback) is managed by libghostty for 120hz rendering.
5. Input events must be translated from NSEvent to ghostty_input_key_s struct.

### Implication
1. Integration requires creating an NSView subclass that routes events to libghostty C API.
2. SwiftUI wrapper (NSViewRepresentable) holds the NSView and ghostty_surface_t handle.
3. App-level state (ghostty_app_t) should be singleton, surfaces are per-terminal.
4. Runtime callbacks must be implemented in Swift for clipboard, window management, close handling.
5. No need to manage Metal pipeline — libghostty handles all GPU work internally.

---

| Memory | Keyboard Focus in Multi-Terminal SwiftUI | Date: 15 January 2026 | Time: 12:19 AM | Name: Lyra |

### Observation
1. When multiple NSViewRepresentable views exist in ZStack, all compete for first responder.
2. Changing visibility (opacity) doesn't automatically change keyboard focus.
3. Must explicitly pass selection state and only request focus for selected view.
4. `updateNSView` is called when SwiftUI state changes — good place to request focus.

### Implication
1. For multi-terminal/multi-view apps, track selection state and pass to each view.
2. Only selected view should call `makeFirstResponder` in updateNSView.
3. Global keyboard shortcuts via NSEvent monitor work well for navigation without menu items.

---

| Memory | Minimal Window Chrome | Date: 15 January 2026 | Time: 12:04 AM | Name: Lyra |

### Observation
1. `.hiddenTitleBar` window style removes title bar area completely.
2. `standardWindowButton(.closeButton)?.isHidden = true` hides traffic lights.
3. `.ignoresSafeArea()` on background view extends blur into titlebar area.
4. Single unified background prevents visual inconsistency.

### Implication
1. For truly minimal UI, combine hiddenTitleBar + ignoresSafeArea.
2. Only one NSVisualEffectView needed for entire window — avoid stacking.

---

| Memory | Zed-Style Sidebar Design | Date: 14 January 2026 | Time: 11:41 PM | Name: Lyra |

### Observation
1. NavigationSplitView provides macOS-standard sidebar but with heavy visual chrome.
2. Simple HStack with conditional rendering gives full control over appearance.
3. NSEvent.addLocalMonitorForEvents enables global keyboard shortcuts without menu items.
4. Using same `.hudWindow` material across all panels creates seamless glass effect.

### Implication
1. For minimal UI, avoid NavigationSplitView — use HStack + manual sidebar toggle.
2. Keyboard shortcuts via NSEvent monitor are instant and don't require toolbar buttons.
3. Consistent material across all views is key to cohesive glass aesthetic.

---

| Memory | Terminal State Persistence in SwiftUI | Date: 14 January 2026 | Time: 11:28 PM | Name: Lyra |

### Observation
1. SwiftUI destroys NSViewRepresentable views when conditionally rendered out of the view hierarchy.
2. Using `.id(someValue)` modifier forces view recreation when the value changes.
3. Terminal apps like Warp/iTerm keep all tab processes alive — they hide views, not destroy them.
4. ZStack with opacity toggle preserves view instances while controlling visibility.

### Implication
1. For stateful views (terminals, video players, etc.), use ZStack + opacity instead of conditional if/else.
2. Use `allowsHitTesting(false)` on hidden views to prevent accidental interaction.
3. Memory tradeoff: more views alive = more RAM, but state preservation is worth it for terminal apps.

---

| Memory | Config-Driven Architecture | Date: 14 January 2026 | Time: 11:10 PM | Name: Lyra |

### Observation
1. Developer tools work best with config files — no UI buttons, no settings sheets.
2. TOMLKit provides clean TOML parsing for Swift.
3. Config file at `~/.config/workspace-manager/config.toml` follows XDG conventions.
4. ConfigService singleton pattern provides global access to configuration.

### Implication
1. Adding features = adding config options, not UI elements.
2. Users can version control their config in dotfiles repos.

---

| Memory | SwiftTerm Configuration | Date: 14 January 2026 | Time: 10:29 PM | Name: Lyra |

### Observation
1. SwiftTerm does not support custom line height/spacing.
2. Cursor style must be set using `terminal.setCursorStyle()` method.
3. Transparent background requires: `wantsLayer = true`, `layer?.backgroundColor = .clear`.

### Implication
1. Line height customization would require forking SwiftTerm.
2. Always use setter methods for terminal options.

---

| Memory | Glass UI Implementation | Date: 14 January 2026 | Time: 10:29 PM | Name: Lyra |

### Observation
1. NSVisualEffectView with `.hudWindow` material creates glass effect.
2. Window needs: `isOpaque = false`, `backgroundColor = .clear`, `titlebarAppearsTransparent = true`.
3. NavigationSplitView provides its own sidebar toggle.

### Implication
1. Check what SwiftUI provides before adding custom toolbar items.

---

| Memory | Swift-C Interop Pointer Lifetime | Date: 21 January 2026 | Time: 09:23 PM | Name: Lyra |

### Observation
1. Swift's withCString closure provides a C string pointer valid ONLY within the closure body.
2. Storing the pointer to a struct field and using it after closure exits is undefined behavior (use-after-free).
3. This is a common trap when interfacing with C APIs that take configuration structs.

### Pattern
1. WRONG: Store pointer in closure, use after closure exits.
    ```swift
    if !path.isEmpty {
        path.withCString { cstr in
            config.working_directory = cstr  // Pointer stored
        }
    }
    let result = c_api_call(&config)  // DANGLING POINTER
    ```
2. CORRECT: Make C API call inside the closure.
    ```swift
    let result: SomeType?
    if !path.isEmpty {
        result = path.withCString { cstr in
            config.working_directory = cstr
            return c_api_call(&config)  // Called while pointer valid
        }
    } else {
        result = c_api_call(&config)
    }
    ```

### Implication
1. Always call C APIs that consume temporary pointers inside the closure that provides them.
2. If the C API needs the pointer to remain valid after the call, allocate persistent memory (strdup pattern).
3. Review all withCString/withUnsafeBytes patterns for lifetime correctness.

---

| Memory | SwiftUI Event Monitor Lifecycle | Date: 21 January 2026 | Time: 09:23 PM | Name: Lyra |

### Observation
1. NSEvent.addLocalMonitorForEvents returns an opaque monitor token.
2. Not storing and removing the token causes duplicate monitors on view recreation.
3. SwiftUI views can be recreated multiple times (previews, state resets, window recreation).

### Pattern
1. Store monitor token in @State.
2. Remove monitor in onDisappear.
3. Guard against double-registration in onAppear.
    ```swift
    @State private var eventMonitor: Any?

    .onAppear {
        guard eventMonitor == nil else { return }
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { ... }
    }
    .onDisappear {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
    ```

### Implication
1. Any global resource acquired in onAppear must be released in onDisappear.
2. SwiftUI lifecycle is not 1:1 with object lifecycle - views can appear/disappear multiple times.

---

| Memory | Product Direction: Workspaces Agents Tasks (Labels) | Date: 22 January 2026 | Time: 04:14 AM | Name: Ghost |

### Observation
1. AI agent orchestration is primarily a navigation and verification problem, not a task management problem.
2. Users want to switch quickly across:
    1. Workspaces (projects/folders).
    2. Agents (persistent terminal slots inside a workspace).
3. Users do not want UI clutter or implementation plumbing in the primary surface; they want intent.
4. The Claude↔Codex workflow loop is common:
    1. Claude acts as an implementation worker.
    2. Codex acts as a strict reviewer.
    3. The user remains responsible for verification and direction changes.

### Implication
1. “Handoff” should be UI-level (focus switch and optional label copy), not an automation engine competing with CLI hooks.
2. Tasks should be labels attached to agents, not runnable jobs in v1.
3. A Focus Mode vs Squad Mode toggle can support both user archetypes:
    1. Single-thread deep work.
    2. Parallel multi-agent orchestration.
4. The product spec must remain centralized and auditable to prevent scope bloat and reinvention:
    1. docs/product.md

---

| Memory | Velocity Threshold Tuning for Low-Velocity Stutter | Date: 22 January 2026 | Time: 08:31 AM | Name: Lyra |

### Observation
1. Scroll stuttering was occurring specifically during slow scrolling and momentum deceleration phase.
2. Fast scrolling was smooth; the stutter only appeared when velocity dropped to low values.
3. Root cause identified: Timer-based momentum at low velocities creates visible jitter.
4. At low velocity (0.05-0.5), the Timer's timing imprecision (not synced to vsync) becomes perceptible.
5. Small scroll deltas combined with inconsistent frame timing creates visible stutter.

### Technical Analysis
1. Original velocityThreshold was 0.05 — momentum continued until near-zero velocity.
2. At velocities like 0.1, 0.08, 0.06, the scroll movements are so tiny that Timer jitter dominates.
3. Timer fires at approximate intervals (not exact 8.33ms), causing uneven frame delivery.
4. At high velocity, this jitter is negligible relative to movement size.
5. At low velocity, the jitter becomes the dominant visual signal — hence stuttering.

### Solution
1. Increased velocityThreshold from 0.05 to 5.5 (110x increase).
2. This stops momentum earlier while velocity is still high enough for smooth rendering.
3. The trade-off: slightly shorter glide, but completely eliminates low-velocity stutter.
4. Sweet spot found through iterative testing: 0.05 → 0.4 → 0.6 → 1.0 → 1.5 → 2.3 → 4.0 → 10.0 → 6.0 → 5.5.

### Implication
1. For Timer-based animation, stopping before velocity gets too low is critical.
2. The proper fix is CVDisplayLink (display-synced timing), but velocity threshold is an effective workaround.
3. This is a general principle: Timer-based animation degrades at low velocities due to timing jitter.
4. For truly butter-smooth scrolling like Warp, need: GPU rendering + CVDisplayLink + proper delta time.

### Research Context: Why Warp Terminal is So Smooth
1. Warp uses Rust + Metal with custom UI framework built from scratch.
2. Renders only 3 primitives: rectangles, glyphs, images (~200 lines of shader code).
3. Uses display-synchronized rendering (CVDisplayLink/CAMetalDisplayLink on macOS).
4. Average screen redraw time: 1.9ms, achieving >144 FPS even with large terminal output.
5. Partnered with Nathan Sobo (Atom editor co-founder) to build their Rust UI framework.
6. GPU rendering alone is NOT sufficient — display-synchronized timing is what makes it FEEL smooth.
