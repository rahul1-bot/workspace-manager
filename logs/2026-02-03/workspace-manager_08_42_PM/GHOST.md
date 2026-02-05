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

## Next Steps
    1. Implement Workspaces/Agents/Tasks labeling UX without adding clutter.
    2. Add explicit Worker/Reviewer pairing and keyboard-first navigation for Claude↔Codex loops.
    3. Keep all orchestration actions verifiable by focusing the relevant terminal surfaces.
    4. Maintain docs/product.md as the authoritative v1 product spec.

## Paths
    1. Primary: Config-driven app with libghostty Metal renderer.
    2. Fallback: SwiftTerm CPU renderer when GPU renderer is disabled.
    3. Product spec: docs/product.md.
    4. Research: Ghostty renderer tuning (input/scroll/clipboard) and performance profiling.
