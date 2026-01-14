# Workspace Manager - progress.md

## Task Tracking

---

| Progress Todo | Metal Renderer Program | Date: 13 January 2026 | Time: 08:31 PM | Name: Ghost |

### Completed Tasks
    1. ✅ App launches as a bundled .app with working keyboard input.
    2. ✅ Git baseline commit established on main.

### In Progress
    1. Design of a Metal-backed terminal renderer (MTKView + glyph atlas).

### Next Steps
    1. Create a MetalTerminalView skeleton with 120Hz configuration.
    2. Render a static grid using a glyph atlas to validate frame pacing.
    3. Bridge PTY output into the renderer with dirty-rect updates.
    4. Measure CPU/GPU usage in release builds.

---

| Progress Todo | Metal Renderer Program | Date: 13 January 2026 | Time: 10:53 PM | Name: Ghost |

### Completed Tasks
    1. ✅ Attempted Metal renderer integration through multiple iterations.
    2. ✅ Validated persistent glyph rendering failure in release bundle.
    3. ✅ Reverted main branch to CPU-based SwiftTerm renderer.

### Next Steps
    1. Keep main branch stable on CPU renderer.
    2. Only resume Metal renderer debugging after defining atlas/shader validation steps.

---

| Progress Todo | Project Direction Pivot | Date: 14 January 2026 | Time: 09:37 PM | Name: Lyra |

### Completed Tasks
    1. ✅ Researched GPU-accelerated terminal embedding options (Ghostty/libghostty, SwiftTerm Metal, Alacritty, kitty, Wezterm).
    2. ✅ Confirmed no production-ready embeddable GPU terminal library exists for Swift/SwiftUI.
    3. ✅ Identified libghostty and SwiftTerm Metal as future watch items.
    4. ✅ Made strategic decision to abandon custom Metal renderer and focus on orchestration layer.
    5. ✅ Updated ledger with research findings and architectural decision.

### In Progress
    1. None — awaiting next orchestration feature prioritization.

### Next Steps
    1. Define workspace orchestration feature set (session management, workspace switching, layouts).
    2. Design orchestration UX that differentiates from tmux.
    3. Implement terminal session management with CPU renderer.
    4. Monitor libghostty releases for future GPU adoption opportunity.
    5. Monitor SwiftTerm issue #202 for Metal renderer availability.
