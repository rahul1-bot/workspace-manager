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
        6. WorktreeService discovers and creates git worktrees via porcelain parsing and safe command wrapping.
        7. WorktreeStateService persists worktree-to-workspace links in worktree-state.json, independent from config.toml.
        8. Worktree comparison mode extends diff pipeline with merge-base and sibling baseline variants.
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
    6. CI gate is active and passing locally (98 tests, 0 failures).
    7. PDF/Paper Viewer panel with multi-PDF tab support renders research papers inline.
    8. Panel exclusivity enforced between diff and PDF panels.
    9. Spatial graph view (Phase 1) operational: force-directed layout, cluster drag, node focus/unfocus, minimap, zoom controls.
    10. Terminal processes survive view mode switches between sidebar and graph mode.
    11. Graph state persists across sessions via graph-state.json.
    12. Phase 1 cleanup complete: 4 bugs fixed (shortcut routing, cluster hit-test, ghostty threading, graph load race), 1 false positive closed.
    13. Phase 2 cleanup complete: 5 bugs fixed (magnify zoom compounding, focus/unfocus lifecycle, edge dedup, clipboard userdata retain).
    14. Phase 3 cleanup complete: 4 bugs fixed (git refresh redundancy, git task cancellation, shell teardown, Escape rename priority), 1 false positive closed (NotificationCenter threading).
    15. Git Worktree Orchestration MVP implemented on ghost/worktree-orchestration-foundation:
        1. Worktree discovery, create flow, and workspace auto-sync (add/update only, no auto-delete).
        2. Worktree section integrated into sidebar with switch and compare actions.
        3. Worktree comparison mode added to diff panel with baseline selector.
        4. Worktree actions added to action bar, command palette, and keyboard shortcuts.
        5. Regression coverage added for worktree service, git worktree diff behavior, app state flow, and shortcut routing.
    16. Local branch safety hardening is active:
        1. pre-commit hook blocks commits on dev and main.
        2. pre-push hook blocks pushes on dev and main.
        3. Guardrail documentation added at docs/git-workflow-guardrails.md.
    17. Worktree create flow now uses deterministic auto-destination policy:
        1. Manual destination-path input removed from the create overlay.
        2. Destination path is auto-computed as .wt/<repo>/<branch-slug> under the repository parent directory.
        3. Parent folders are created automatically before git worktree add executes.
    18. Worktree create reliability hardening is active:
        1. Create flow now resolves repository context lazily at submit time when catalog state is stale or not yet loaded.
        2. All New Worktree entry points route through a single present method that refreshes worktree catalog immediately.
        3. Shortcut and action entry points are aligned, reducing race conditions between sheet open and catalog refresh.
    19. Worktree create loading-state lifecycle is now completion-driven:
        1. AppState create method was converted to async throws and no longer spawns an internal detached task.
        2. ContentView create handler now awaits the full create pipeline and always exits spinner state on success or error.
        3. This removes the stuck Create-button spinner failure mode during rapid worktree creation attempts.
    20. Worktree create pipeline is now optimized for low-latency execution:
        1. WorktreeService create path returns descriptor from the new worktree directly instead of forcing full-catalog reconstruction before returning.
        2. AppState create flow now adds and links only the created workspace on the critical path, then refreshes catalog asynchronously after switching.
        3. WorktreeService git execution now uses file-backed stdout/stderr capture with command timeout protection to prevent process-output deadlocks.
    21. Sidebar hierarchy now enforces separation between manual workspaces and auto-managed worktree entries:
        1. Auto-managed worktree-linked workspaces are filtered out of the primary WORKSPACES tree to prevent node explosion during branch/worktree switching.
        2. Worktree-linked context remains visible through WORKTREES (CURRENT REPO), preserving switch and compare workflows without duplicating nodes.
        3. Auto-managed metadata is refreshed from worktree-state.json and used as the authoritative filter source.
    22. Legacy metadata fallback is now active for worktree workspace classification:
        1. Sidebar filtering now also treats `wt`-prefixed workspace names and `.wt/` path roots as auto-managed heuristics when historical metadata is missing or incorrect.
        2. Sync updates preserve existing auto-managed links and infer auto-managed classification for legacy entries during reconciliation.
        3. This addresses screenshot-reproduced cases where old entries remained visible despite dedicated worktree section support.
    23. Problem framing for next iterations is documented in problem_statement.md (git-tracked at repository root):
        1. Includes current-state evidence, comparison with Lyra reference branch, decision constraints, acceptance criteria, and incremental execution plan.
        2. Includes explicit feature requirements for inline terminal branch context and a visible Documents action button.
    24. Workspace branch metadata is now surfaced in terminal-facing UI:
        1. Sidebar terminal rows display `<terminal-name> <branch-name>` with dirty-state marker support.
        2. Active terminal header also surfaces current workspace branch metadata for immediate context.
    25. Documents quick action is now first-class in the action bar:
        1. Added a dedicated `Documents` pill in WorkspaceActionBar that routes to panel visibility toggle behavior.
        2. This removes discoverability dependence on keyboard shortcuts or command palette for paper-reading tasks.
    26. Document workflow intent split is now explicit:
        1. Toggle flow (`Documents` pill and `⇧⌘P`) only shows or hides the PDF panel.
        2. Open-file flow is separate (`command palette: Open PDF` and `⇧⌘O`) and is the only path that opens Finder picker.
    27. PDF toggle keymap hardening is active:
        1. Router now accepts both character and physical-keycode matches for `⇧⌘P` toggle and `⇧⌘O` open-file actions.
        2. Documents action tooltip now advertises `Toggle Documents panel (⇧⌘P)` for in-context discoverability.

## Active Risks
    1. Whisper hold-command behavior remains asymmetric (sidebar path works, main terminal path unresolved).
    2. Precompiled ghostty static artifact trust remains a supply-chain governance concern.

## Next Steps
    1. Stabilize worktree orchestration UX details:
        1. Visual polish pass for worktree rows and comparison labels.
    2. Design and implement Read-only Code Viewer panel (third knowledge workspace feature).
    3. Resolve whisper hold-command integration gap for terminal focus path.

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
    6. Worktree orchestration problem framing: problem_statement.md.
