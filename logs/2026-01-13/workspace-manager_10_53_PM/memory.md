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
