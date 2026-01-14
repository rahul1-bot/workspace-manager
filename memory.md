# Workspace Manager - memory.md

## Insights and Learnings

---

| Memory | Embedded 120Hz Requires Metal Renderer | Date: 13 January 2026 | Time: 08:31 PM | Name: Ghost |

### Observation
    1. SwiftTerm’s macOS renderer is CPU-bound and cannot sustain 120Hz during heavy output.
    2. Warp is closed-source and does not expose an embeddable terminal view for SwiftUI.

### Implication
    1. True 120Hz inside the app requires a Metal-backed terminal renderer.

---

| Memory | App Bundle Activation Fix | Date: 13 January 2026 | Time: 08:31 PM | Name: Ghost |

### Observation
    1. Running as a proper .app bundle resolves the global keyboard input issue.
    2. Focus issues were mitigated by direct first-responder assignment to the terminal view.

### Implication
    1. All performance testing must use the bundled app, not raw SwiftPM execution.

---

| Memory | Performance Guardrails | Date: 13 January 2026 | Time: 08:31 PM | Name: Ghost |

### Observation
    1. Reducing scrollback, disabling blink, and turning off optional features lowers CPU churn.
    2. These optimizations do not replace GPU rendering.

### Implication
    1. These are short-term stabilizers; the Metal renderer is the long-term solution.

---

| Memory | Metal Renderer Attempt Rolled Back | Date: 13 January 2026 | Time: 10:53 PM | Name: Ghost |

### Observation
    1. Multiple Metal renderer iterations produced a full-grid block fill instead of correct glyphs.
    2. Release bundle testing confirmed the issue persisted after alpha mask and blending fixes.
    3. Stability and usability were restored by returning to the CPU-based SwiftTerm view on main.

### Implication
    1. GPU renderer work must proceed only after a rigorous atlas/shader debugging plan is defined.
    2. Main branch remains CPU-based until Metal rendering is verified correct.

---

| Memory | GPU Terminal Embedding Landscape Research | Date: 14 January 2026 | Time: 09:37 PM | Name: Lyra |

### Observation
    1. No production-ready GPU-accelerated embeddable terminal library exists for Swift/SwiftUI as of January 2026.
    2. Ghostty by Mitchell Hashimoto includes libghostty, a C-compatible library with Metal rendering. The macOS Ghostty app is itself a SwiftUI application using libghostty. However, libghostty is not released for external consumption; the API is unstable with no official versioned release.
    3. Mitchell Hashimoto announced plans for libghostty-vt (terminal parsing) and future libraries including Swift frameworks for terminal views, but no timeline provided.
    4. SwiftTerm has open issue #202 tracking Metal renderer support. Miguel de Icaza confirmed active development as of August 2025, with a fresh implementation underway after the original metal-backend proved too complex.
    5. All other GPU-accelerated terminals (Alacritty, kitty, Wezterm) are standalone applications written in Rust/C/Python with no embeddable library offering.

### Implication
    1. Building a custom Metal terminal renderer is a significant graphics engineering undertaking with no reference implementation available.
    2. The pragmatic path is to use SwiftTerm CPU renderer and monitor libghostty and SwiftTerm Metal for future adoption.
    3. For a workspace orchestrator, terminal rendering performance is secondary to orchestration UX.

---

| Memory | Metal Renderer Root Cause Analysis | Date: 14 January 2026 | Time: 09:37 PM | Name: Lyra |

### Observation
    1. The full-grid block fill symptom indicates all character cells rendered as solid white rectangles instead of glyph shapes.
    2. Likely root causes identified but not verified: (a) glyph atlas texture not generating correct alpha values, (b) UV coordinate calculation errors due to CGContext/Metal coordinate system mismatch, (c) double-flip from CGContext bottom-left origin combined with shader flipVertical flag.
    3. Debugging was attempted through iterative fixes rather than systematic isolation (dumping atlas to PNG, testing single character, logging UV coordinates).

### Implication
    1. Shotgun debugging without systematic validation leads to wasted effort.
    2. If Metal renderer is revisited, debugging plan must include: export atlas texture to file for visual verification, test single hardcoded character before full grid, log UV coordinates for known ASCII values.
