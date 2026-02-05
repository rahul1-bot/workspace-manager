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

---

| Memory | CADisplayLink vs Timer for Animation | Date: 22 January 2026 | Time: 08:51 AM | Name: Lyra |

### Observation
1. Timer-based animation has inherent timing jitter — fires at approximate intervals, not synced to display.
2. CADisplayLink fires exactly at vsync, eliminating timing jitter completely.
3. macOS 14+ provides `NSView.displayLink(target:selector:)` — simpler than old CVDisplayLink API.
4. Must explicitly request 120Hz with `preferredFrameRateRange` on ProMotion displays.

### Implementation Pattern
1. Create display link from NSView: `self.displayLink(target:selector:)`
2. Set frame rate range: `displayLink?.preferredFrameRateRange = CAFrameRateRange(minimum: 80, maximum: 120, preferred: 120)`
3. Add to run loop: `displayLink?.add(to: .current, forMode: .common)`
4. Use `link.targetTimestamp` (not `timestamp`) for frame timing calculations.
5. Invalidate when done: `displayLink?.invalidate()`

### Frame-Rate Independent Decay
1. Store last timestamp and calculate actual delta time each frame.
2. Normalize decay factor to actual frame duration: `pow(decayFactor, deltaTime * targetFrameRate)`
3. This ensures consistent animation speed regardless of actual frame rate.

### Implication
1. CADisplayLink is theoretically the proper way to do display-synchronized animation on macOS.
2. However, in practice, Timer + high velocity threshold felt smoother in our testing.
3. The fundamental limitation remains: libghostty scrolls line-by-line, not pixel-by-pixel.
4. For truly Warp-level smoothness, would need custom renderer with sub-pixel scrolling support.

---

| Memory | Timer vs CADisplayLink Comparison Results | Date: 22 January 2026 | Time: 08:55 AM | Name: Lyra |

### Observation
1. We tested both Timer-based and CADisplayLink-based momentum implementations.
2. Surprisingly, the simpler Timer + high velocity threshold approach felt smoother in practice.
3. CADisplayLink added complexity but did not provide noticeable improvement.

### Comparison Results
1. Timer + velocityThreshold=5.5: Smooth, simple, works well.
2. CADisplayLink + velocityThreshold=3.5: More complex, similar or slightly worse feel.

### Analysis
1. The velocity threshold is the key factor in eliminating low-velocity stutter.
2. At velocities above 5.5, even Timer's timing jitter is not perceptible.
3. CADisplayLink's precision is only beneficial at very low velocities — which we skip entirely.
4. The extra complexity of CADisplayLink (frame timestamps, decay normalization) adds overhead without benefit.

### Decision
1. Stick with Timer-based momentum + high velocity threshold (5.5).
2. This is the simpler, more maintainable solution that works well in practice.
3. CADisplayLink implementation preserved in git history (commit 1b9935e) for future reference.

### Implication
1. Sometimes simpler solutions outperform theoretically "correct" approaches.
2. The key insight: eliminating problematic low-velocity region is more effective than precise timing.
3. Practical testing > theoretical optimization.

---

| Memory | libghostty working_directory Lifetime Safety | Date: 22 January 2026 | Time: 12:03 PM | Name: Ghost |

    1. Problem:
        1. The working directory string passed to libghostty is provided via a C pointer in ghostty_surface_config_s.
        2. Without an explicit contract that libghostty copies the string immediately, passing a temporary pointer risks undefined behavior.
    2. Decision:
        1. Allocate a stable C string with strdup and keep it alive for the lifetime of the terminal surface view.
        2. Free the buffer on view deinitialization.
    3. Implication:
        1. This removes pointer lifetime ambiguity and stabilizes working directory behavior across releases/build modes.

---

| Memory | macOS Arrow Keys Produce Function-Key Unicode | Date: 22 January 2026 | Time: 12:03 PM | Name: Ghost |

    1. Observation:
        1. NSEvent.characters for arrow keys can contain Unicode scalars in the function-key private range (U+F700-U+F8FF).
        2. If these scalars are forwarded as text to the terminal engine, they can render as literal glyphs instead of behaving as navigation keys.
    2. Decision:
        1. Do not pass text to libghostty when characters contain U+F700-U+F8FF scalars.
        2. Forward only the keycode and modifiers for these keys.
    3. Implication:
        1. Arrow keys behave correctly for shell navigation (history, cursor movement) and no longer insert glyphs into the terminal buffer.

---

| Memory | Key Event Encoding Should Match Upstream Ghostty | Date: 22 January 2026 | Time: 02:29 PM | Name: Ghost |

    1. Observation:
        1. libghostty key handling expects a consistent contract: keycode/modifier fields must be set for all keys, and text must be reserved for printable UTF-8.
        2. If text is sent for non-text keys, interactive TUIs can display “random glyphs” because macOS function-key Unicode lives in a private range and patched fonts map those codepoints to icons.
    2. Decision:
        1. Encode keyboard input using the same rules as Ghostty’s macOS SurfaceView implementation:
            1. Use keycode for navigation keys and avoid forwarding them as text.
            2. Do not forward control characters as text; let Ghostty’s encoder handle them.
            3. Populate consumed_mods and unshifted_codepoint for correct downstream behavior.
            4. Use repeat action for event.isARepeat.
    3. Implication:
        1. Arrow keys and other non-text keys behave consistently across shell prompts and full-screen TUIs.

---

| Memory | Verification: Arrow Keys and Readability | Date: 22 January 2026 | Time: 03:07 PM | Name: Ghost |

    1. Observation:
        1. After aligning key event encoding to upstream Ghostty and blocking arrow keys from the text path, the arrow glyph artifact disappeared in practice.
        2. Readability for prolonged sessions improved after setting Ghostty font-size to 18.
    2. Implication:
        1. Input correctness should be validated using full-screen TUIs, not only a plain shell prompt.
        2. Font size is operationally a user preference and should remain a config-level knob rather than hardcoded.

---

| Memory | SwiftPM Resources Require Bundle Copy in App Packaging | Date: 23 January 2026 | Time: 01:26 PM | Name: Ghost |

    1. Observation:
        1. When using SwiftPM resources, Bundle.module resolves assets from a generated *.bundle alongside the executable.
        2. A manually assembled .app that only copies the binary will not include the resource bundle by default, causing resources to silently fail to load.
    2. Decision:
        1. scripts/build_app_bundle.sh now copies WorkspaceManager_WorkspaceManager.bundle into Build/WorkspaceManager.app/Contents/Resources.
    3. Implication:
        1. Resource-backed UI elements (e.g., terminal-icon.png) render correctly in the bundled app, not only when running from the build directory.

---

| Memory | Inline Rename Needs Shared Selection State + Focus Control | Date: 23 January 2026 | Time: 01:26 PM | Name: Ghost |

    1. Observation:
        1. Inline rename without dialogs requires a stable rename target and deterministic focus control.
        2. If rename state lives only in a row view, a Cmd+R global trigger cannot reliably focus the correct TextField.
    2. Decision:
        1. Store rename target IDs in AppState (renamingWorkspaceId / renamingTerminalId) and drive focus using a FocusState in WorkspaceSidebar.
        2. Trigger rename via double click gesture and Cmd+R; commit via Enter; cancel via Escape.
    3. Implication:
        1. Rename is fast, keyboard-first, and does not require modal UI.

---

| Memory | SwiftUI Views Can Display Stale Model Snapshots Without Direct Observation | Date: 23 January 2026 | Time: 02:03 PM | Name: Ghost |

    1. Observation:
        1. Some UI elements (e.g., terminal header) can keep rendering previous model values even when the underlying model changes, depending on how values are passed through view hierarchies.
        2. This is especially visible in multi-view stacks where multiple child views are instantiated and only visibility is toggled.
    2. Decision:
        1. For critical UI labels that must reflect runtime mutations (rename), resolve the label from the single source of truth (AppState) using stable IDs.
        2. Prefer direct observation of AppState in those leaf views rather than relying on propagated struct snapshots.
    3. Implication:
        1. Rename operations become consistent across sidebar and header surfaces.

---

| Memory | Template Rendering Tints PNG Assets | Date: 23 January 2026 | Time: 02:03 PM | Name: Ghost |

    1. Observation:
        1. Treating an NSImage as a template and using SwiftUI .renderingMode(.template) will tint the asset via foregroundColor, overriding the original black/white colors.
    2. Decision:
        1. Render the terminal icon as an original image to preserve the provided black background and white glyphs.
    3. Implication:
        1. Sidebar icon appearance matches the intended design and does not inherit theme tints.

---

| Memory | Default Terminals Are Runtime-Only, Not Config | Date: 23 January 2026 | Time: 02:15 PM | Name: Ghost |

    1. Observation:
        1. Workspaces are config-driven and persisted, but terminals are runtime-only and represent live processes.
        2. Persisting terminal names without persisting process state can create a false expectation of continuity.
    2. Decision:
        1. Bootstrap a default terminal pair ("Ghost", "Lyra") for each workspace at runtime.
        2. Keep terminal persistence out of config.toml until we have a clear contract for process lifecycle and restoration.
    3. Implication:
        1. Startup is deterministic and aligned with the workflow, while avoiding misleading “fake persistence”.
