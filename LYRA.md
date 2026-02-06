# Workspace Manager - LYRA.md

## Scope

Native macOS terminal workspace manager focused on fast context switching, deterministic git workflows, and clean config-driven behavior.

---

## Current Product Snapshot

| Field | Value |
|-------|-------|
| Project | WorkspaceManager |
| Platform | macOS 14+ |
| UI | SwiftUI + NSViewRepresentable bridges |
| Terminal renderers | libghostty (default), SwiftTerm (fallback) |
| Config file | ~/.config/workspace-manager/config.toml |
| Primary branch for active feature work | feat/graph-phase1-cleanup |

---

## Source of Truth

1. Workspaces and appearance flags come from config.toml.
2. Terminals are runtime-only sessions attached to workspaces.
3. Keyboard behavior is routed centrally in KeyboardShortcutRouter.
4. Git and editor actions target selected terminal runtime CWD first.

---

## Live Capabilities

1. Workspace and terminal management with keyboard-first flows.
2. Open action supports Finder, VS Code, and Zed/Zed Preview.
3. Commit sheet supports commit, commit+push, commit+create-PR flows.
4. Diff panel supports mode switching and dynamic resize (20 to 100 percent).
5. Diff panel renders structured line classes (headers, hunks, additions, deletions).
6. Commit and diff execution paths are stabilized against subprocess output deadlocks.
7. PDF/Paper Viewer panel with multi-PDF tab support, page navigation, and tab cycling (Cmd+Shift+{/}).
8. Panel exclusivity enforced: only one right-side panel (diff or PDF) can be open at a time.
9. Spatial graph view (Cmd+G): force-directed 2D canvas with node drag, cluster drag, zoom (pinch/scroll/keyboard), minimap, zoom-to-fit.
10. Terminal processes persist across sidebar/graph view mode switches.
11. All overlays use unified dark liquid glass visual pattern.

---

## Key Technical Notes

1. libghostty is embedded via GhosttyKit and receives translated input events.
2. Runtime terminal CWD updates are propagated from ghostty action callbacks.
3. Git command capture uses temporary file output to avoid blocking pipes.
4. Diff panel open/close is intentionally instant for workflow speed.

---

## Known Gaps

1. Whisper hold-command behavior is still inconsistent in main terminal focus path.
2. Diff syntax highlighting is line-class based, not full language tokenization.
3. Supply-chain hardening for precompiled ghostty artifact should remain a tracked concern.

---

## Knowledge Workspace Direction

| Decision Record | Knowledge Workspace Roadmap | Date: 06 February 2026 | Time: 06:57 PM | Name: Lyra |

    1. Strategic pivot:
        1. Identified that the app should solve the knowledge work bottleneck for research engineers who juggle multiple git worktrees, read research papers while coding, and constantly switch between different AIML/PyTorch projects.
        2. Established a first principles filter: every feature must pass four tests (cannot be done via terminal, high-value daily problem, reduces context-switching, hardcore developer would use it).
    2. Three high-value features agreed upon and ordered by priority:
        1. PDF/Paper Viewer Panel (implemented, branch feat/ui-ux-improvements).
        2. Git Worktree Orchestration (planned, highest complexity).
        3. Read-only Code Viewer Panel (planned, reuses DiffSyntaxHighlightingService).
    3. Documentation:
        1. Full roadmap at docs/knowledge-workspace-roadmap.md.
        2. PDF viewer design spec at docs/pdf-viewer-design.md.
        3. README.md updated with Knowledge Workspace roadmap section.

---

## Spatial Graph View — Status

| Decision Record | Spatial Graph View — Phase 1 Complete, Phase 2 Cleanup Active | Date: 07 February 2026 | Time: 12:08 AM | Name: Lyra |

    1. Phase 1 delivered:
        1. Full canvas takeover with SwiftUI Canvas rendering (nodes, edges, grid, cluster boundaries, minimap).
        2. Custom force-directed layout engine (SIMD2 vector math, velocity Verlet integration).
        3. Viewport transform with pan, pinch zoom, scroll wheel zoom, keyboard zoom, zoom-to-fit.
        4. Node drag, cluster drag, node selection, node focus (live terminal), unfocus (return to graph).
        5. Graph state persists to graph-state.json. Viewport state survives view mode toggles via AppState.
        6. Terminal processes survive sidebar/graph switches via opacity-based hiding pattern.
        7. Phase 1 cleanup: 4 bugs fixed, 1 false positive closed, all independently verified.
    2. Phase 2 cleanup active:
        1. 5 medium-severity bugs identified for resolution (magnify zoom, focus/unfocus lifecycle, edge dedup, clipboard userdata).
    3. Design documents:
        1. Full specification at docs/spatial-graph-view.md.
        2. Design decisions at docs/spatial-graph-view-design-decisions.md.

---

## File Anchors

1. Sources/WorkspaceManager/Models/AppState.swift
2. Sources/WorkspaceManager/Services/GitRepositoryService.swift
3. Sources/WorkspaceManager/Views/DiffPanelView.swift
4. Sources/WorkspaceManager/Support/KeyboardShortcutRouter.swift
5. Sources/WorkspaceManager/Views/GraphCanvasView.swift
6. Sources/WorkspaceManager/Views/GhosttyTerminalView.swift
7. Sources/WorkspaceManager/Views/Overlays.swift
8. Sources/WorkspaceManager/Models/ForceLayoutEngine.swift
9. Sources/WorkspaceManager/Models/ViewportTransform.swift
10. docs/spatial-graph-view.md
11. docs/spatial-graph-view-design-decisions.md
12. docs/knowledge-workspace-roadmap.md
