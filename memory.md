# Workspace Manager - memory.md

## Insights and Learnings

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
