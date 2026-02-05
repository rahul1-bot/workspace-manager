# Ghost Operational Ledger — Workspace Manager

## Mission
    1. Deliver a workspace orchestrator with an embedded terminal.
    2. Provide verification-first AI agent orchestration across multiple workspaces (folders).
    3. Keep configuration as the single source of truth for structure and core UI behavior.
    4. Preserve a stable terminal experience with a GPU renderer by default and a CPU fallback when needed.

## Architecture
    1. SwiftUI app with AppState models for workspaces and terminals.
    2. Config pipeline: ConfigService loads and persists ~/.config/workspace-manager/config.toml.
    3. Terminal pipeline:
        1. Default: libghostty (GhosttyKit) Metal renderer (use_gpu_renderer = true).
        2. Fallback: SwiftTerm (LocalProcessTerminalView) CPU renderer (use_gpu_renderer = false).
    4. Product model (v1 target):
        1. Workspaces: folders on disk.
        2. Agents: persistent terminal slots inside a workspace.
        3. Tasks: labels attached to agents (not runnable jobs).
        4. Pairing: optional Worker/Reviewer mapping per workspace for Claude↔Codex workflows.

## Decisions
    1. config.toml is the single source of truth for workspaces.
    2. Workspaces have stable ids persisted in config.toml to preserve identity across restarts.
    3. Sidebar visibility is persisted to config.toml (appearance.show_sidebar).
    4. Terminal renderer selection is controlled by config.toml (terminal.use_gpu_renderer).
    5. Tasks are labels only; no task/job execution engine is introduced in v1.
    6. “Handoff” is UI-level navigation (focus switch and optional label copy), not automation.
    7. Preferred root is the study workspace root when it exists; otherwise home. A Study workspace is ensured and prioritized on load.
    8. Ghostty keyboard input must not forward macOS function-key Unicode (U+F700-U+F8FF) as text; these keys are handled via keycode/modifiers only.
    9. scripts/run.sh is the single entrypoint for build-and-open in debug or release; user shell aliases may wrap it.
    10. Ghostty renderer appearance (including font size) remains controlled by ~/.config/ghostty/config and is not persisted in this repo.
    11. Default workspace roster is auto-bootstrapped for this machine: Root plus selected course folders are added to config.toml when present on disk.
    12. Rename is inline only (no dialogs): double click or Cmd+R enters rename mode; Enter commits; Escape cancels; Shift+Cmd+R is reserved for hot reload.
    13. Terminal header resolves names by stable IDs from AppState to guarantee rename propagation across all surfaces.
    14. Sidebar terminal icon renders as original PNG (no template tinting).
    15. Keymaps are keyboard-first and additive; destructive actions remain unbound until guarded by explicit confirmation design.
    16. Each workspace bootstraps a default two-terminal pair ("Ghost", "Lyra") at runtime on app start and on workspace creation.
    17. Non-selected libghostty terminal surfaces must be explicitly occluded to prevent rendering and wakeup overhead from scaling with terminal count.
    18. Agents/Tasks pairing keymaps are deferred until the Agents/Tasks config schema exists; only schema-free keymaps are implemented immediately.
    19. Focus Mode is a first-class appearance setting persisted in config.toml (appearance.focus_mode) and is toggleable via keyboard.
    20. Command palette is introduced as the scalable navigation primitive once workspace and terminal counts exceed single-digit muscle memory ranges.
    21. Hardening rollout is branch-stacked and phase-gated: p0 diagnostics, p1 crash/input fixes, p2 security hardening, p3 shortcut routing compatibility, p4 architecture refactor, p5 quality gates.
    22. Input diagnostics must be redacted and bounded by default; raw keystroke and clipboard payload logging is prohibited even in debug mode.
    23. Ghostty clipboard callbacks must use explicit lifetime-safe buffers managed by a dedicated bridge object.
    24. Keyboard routing is centralized in KeyboardShortcutRouter and standard edit shortcuts (Cmd+C/V/X/Z/A) are passthrough to preserve responder-chain behavior.
    25. Terminal launch uses TerminalLaunchPolicy with shell-path allowlisting and sanitized environment projection.
    26. Core models and state adopt stricter concurrency posture: AppState is @MainActor and config/workspace/terminal models conform to Sendable.
    27. Quality gates are now explicit artifacts in-repo: test target, regression matrix, CI workflow, and local ci.sh script.

## Next Steps
    1. Implement Workspaces/Agents/Tasks labeling UX without adding clutter.
    2. Add explicit Worker/Reviewer pairing and keyboard-first navigation for Claude↔Codex loops.
    3. Keep all orchestration actions verifiable by focusing the relevant terminal surfaces.
    4. Maintain docs/product.md as the authoritative v1 product spec.
    5. Upgrade the command palette to support arrow-key selection navigation and action groups without stealing input from terminals when closed.
    6. (Vacation) Implement Spatial Graph View per docs/spatial-graph-view.md — toggle between sidebar and graph canvas, generic nodes (terminal/markdown), force-directed layout, edge relationships.
    7. Run the manual keyboard and whisper validation matrix on live app sessions with WM_DIAGNOSTICS=1 and archive failure snapshots.
    8. Verify stacked-branch merge order into dev and attach per-phase verification summaries in merge notes.
    9. Evaluate remaining singleton surfaces (ConfigService.shared and GhosttyAppManager.shared) for future dependency-injection hardening without destabilizing runtime behavior.
    10. Resolve unresolved whisper hold-command integration bug: sidebar rename field allows blue bubble trigger, but main terminal focus still blocks it.

## Paths
    1. Primary: Config-driven app with libghostty Metal renderer.
    2. Fallback: SwiftTerm CPU renderer when GPU renderer is disabled.
    3. Product spec: docs/product.md.
    4. Spatial graph view spec: docs/spatial-graph-view.md.
    5. Research: Ghostty renderer tuning (input/scroll/clipboard) and performance profiling.
