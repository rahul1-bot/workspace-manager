# Workspace Manager - memory.md

## Insights and Learnings

---

| Memory | SwiftTerm Configuration | Date: 14 January 2026 | Time: 10:29 PM | Name: Lyra |

### Observation
1. SwiftTerm does not support custom line height/spacing — cell dimensions are computed from font metrics.
2. Cursor style must be set using `terminal.setCursorStyle()` method, not by directly setting `terminal.options.cursorStyle`.
3. Transparent terminal background requires: `wantsLayer = true`, `layer?.backgroundColor = .clear`, and `nativeBackgroundColor` with alpha 0.

### Implication
1. Line height customization would require forking SwiftTerm.
2. Always use the setter methods for terminal options to ensure UI updates.

---

| Memory | Glass UI Implementation | Date: 14 January 2026 | Time: 10:29 PM | Name: Lyra |

### Observation
1. NSVisualEffectView with `.hudWindow` material and `.behindWindow` blending creates the glass effect.
2. Window must be configured with: `isOpaque = false`, `backgroundColor = .clear`, `titlebarAppearsTransparent = true`.
3. NavigationSplitView automatically provides a sidebar toggle button — adding another creates duplicates.

### Implication
1. Always check what SwiftUI components provide automatically before adding custom toolbar items.

---

| Memory | GPU Terminal Landscape | Date: 14 January 2026 | Time: 09:37 PM | Name: Lyra |

### Observation
1. No production-ready GPU-accelerated embeddable terminal library exists for Swift/SwiftUI.
2. libghostty (Ghostty) plans to release Swift frameworks but timeline unknown.
3. SwiftTerm Metal renderer in active development (issue #202).

### Implication
1. Use SwiftTerm CPU renderer now; monitor libghostty and SwiftTerm Metal for future adoption.
