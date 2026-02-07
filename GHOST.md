# Ghost Operational Ledger - Workspace Manager

## Mission
    1. Deliver a native macOS terminal workspace manager with fast keyboard-first control.
    2. Keep configuration and runtime state deterministic and auditable.
    3. Preserve production reliability for terminal I/O, git workflows, and UI interactions.

## Architecture
    1. UI stack:
        1. SwiftUI views with AppState as the orchestration center.
        2. KeyboardShortcutRouter as the single routing layer for global key behavior.
        3. Dark liquid glass pattern standardized across all overlays (command palette, commit sheet, shortcuts help, diff panel).
    2. Terminal stack:
        1. Default renderer: libghostty Metal surface integration.
        2. Fallback renderer: SwiftTerm CPU view when GPU renderer is disabled.
        3. Terminal processes persist across view mode switches via opacity-based hiding (not conditional view builders).
    3. Config stack:
        1. ConfigService reads and writes ~/.config/workspace-manager/config.toml.
        2. Workspaces are config-backed; terminals are runtime processes.
    4. Git/UI stack:
        1. GitRepositoryService executes git operations for status, diff, commit, and init.
        2. DiffPanelView and CommitSheetView are state-driven via AppState.
        3. DiffPatchParser builds structured render models from unified diff text.
        4. DiffSyntaxHighlightingService provides internal token highlighting with actor-local cache.
        5. DiffFileCardView and DiffCodeRowView render grouped file and hunk surfaces with dual line numbers.
    5. Graph stack:
        1. SwiftUI Canvas renders nodes, edges, grid, and cluster boundaries in a single immediate-mode pass.
        2. Custom force-directed layout engine (ForceLayoutEngine.swift) with SIMD2 vector math.
        3. Graph state persists to ~/.config/workspace-manager/graph-state.json, separate from config.toml.
        4. ViewportTransform handles canvas-to-screen coordinate conversion with translation-before-scaling order.
        5. Hit-testing is manual (point-in-bounding-box) in canvas coordinate space.

## Decisions
    1. Config file is the single source of truth for workspace roster and appearance flags.
    2. AppState is main-actor isolated and owns UI mutation paths.
    3. Keyboard routing is centralized and standard edit shortcuts remain responder-chain passthrough.
    4. Terminal action context is selected terminal runtime CWD first, launch CWD fallback second.
    5. Git command output capture is file-backed to avoid pipe deadlock under large output.
    6. Diff panel is first-class: default 50 percent width, resizable from 20 to 100 percent, auto-close below 20 percent.
    7. Diff panel open and close is instant; no transition animation.
    8. Commit sheet dismissal must be keyboard reliable through router-level Esc handling.
    9. libghostty occlusion remains disabled due severe input lag during multi-surface transitions.
    10. Diff viewer remains unified mode and is upgraded through file-card composition instead of side-by-side split in this phase.
    11. No external syntax highlighting dependency is introduced; internal tokenization is used for Swift, Python, JavaScript, TypeScript, JSON, Markdown, shell, and YAML.
    12. Diff chrome is translucent and aligned with app glass surfaces while near-black backgrounds are restricted to file code containers only.
    13. Intraline emphasis uses bounded character-level comparison for adjacent deletion and addition runs to prevent large-patch performance regression.

## Current State
    1. Open action correctly targets selected terminal runtime path.
    2. Commit flow executes reliably and no longer hangs.
    3. Diff flow executes reliably and supports richer line-type color treatment.
    4. Diff viewer renders structured file sections, hunk grouping, dual line numbers, token highlighting, and intraline emphasis.
    5. All overlay panels use unified dark liquid glass visual pattern.
    6. CI gate is active and passing locally (70 tests, 0 failures).
    7. PDF/Paper Viewer panel with multi-PDF tab support renders research papers inline.
    8. Panel exclusivity enforced between diff and PDF panels.
    9. Spatial graph view (Phase 1) operational: force-directed layout, cluster drag, node focus/unfocus, minimap, zoom controls.
    10. Terminal processes survive view mode switches between sidebar and graph mode.
    11. Graph state persists across sessions via graph-state.json.
    12. Phase 1 cleanup complete: 4 bugs fixed (shortcut routing, cluster hit-test, ghostty threading, graph load race), 1 false positive closed.
    13. Phase 2 cleanup complete: 5 bugs fixed (magnify zoom compounding, focus/unfocus lifecycle, edge dedup, clipboard userdata retain).
    14. Phase 3 cleanup complete: 4 bugs fixed (git refresh redundancy, git task cancellation, shell teardown, Escape rename priority), 1 false positive closed (NotificationCenter threading).

## Active Risks
    1. Whisper hold-command behavior remains asymmetric (sidebar path works, main terminal path unresolved).
    2. Precompiled ghostty static artifact trust remains a supply-chain governance concern.

## Next Steps
    1. Design and implement Git Worktree Orchestration (second knowledge workspace feature).
    3. Design and implement Read-only Code Viewer panel (third knowledge workspace feature).
    4. Resolve whisper hold-command integration gap for terminal focus path.

## File Tracking Policy
    1. Ledger files (GHOST.md, LYRA.md, memory.md, progress.md) are ALWAYS tracked in git and merge across branches.
    2. docs/, logs/, review.md, problems.md are gitignored and stay local.
    3. Full policy documented at docs/local-files-policy.md.

## Paths
    1. Product spec: docs/product.md.
    2. Spatial graph spec: docs/spatial-graph-view.md.
    3. Knowledge workspace roadmap: docs/knowledge-workspace-roadmap.md.
    4. PDF viewer design spec: docs/pdf-viewer-design.md.
    5. CI gate: scripts/ci.sh.
