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
