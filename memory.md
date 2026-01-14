# Workspace Manager - memory.md

## Insights and Learnings

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
