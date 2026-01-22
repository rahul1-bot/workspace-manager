# Ghost Operational Ledger — Workspace Manager

## Mission
    1. Deliver a workspace orchestrator with an embedded terminal.
    2. Keep configuration as the single source of truth for workspaces and core UI behavior.
    3. Preserve a stable terminal experience with a GPU renderer by default and a CPU fallback when needed.

## Architecture
    1. SwiftUI app with AppState models for workspaces and terminals.
    2. Config pipeline: ConfigService loads and persists ~/.config/workspace-manager/config.toml.
    3. Terminal pipeline:
        1. Default: libghostty (GhosttyKit) Metal renderer (use_gpu_renderer = true).
        2. Fallback: SwiftTerm (LocalProcessTerminalView) CPU renderer (use_gpu_renderer = false).

## Decisions
    1. config.toml is the single source of truth for workspaces.
    2. Workspaces have stable ids persisted in config.toml to preserve identity across restarts.
    3. Sidebar visibility is persisted to config.toml (appearance.show_sidebar).
    4. Terminal renderer selection is controlled by config.toml (terminal.use_gpu_renderer).

## Next Steps
    1. Validate workspace ids on load (reject or repair invalid ids) and detect duplicate ids.
    2. Improve UX for failed workspace creation (duplicate/empty names should not silently dismiss the sheet).
    3. Optional: add hot reload for config.toml with stable selection preservation.

## Paths
    1. Primary: Config-driven app with libghostty Metal renderer.
    2. Fallback: SwiftTerm CPU renderer when GPU renderer is disabled.
    3. Research: Ghostty renderer tuning (input/scroll/clipboard) and performance profiling.
