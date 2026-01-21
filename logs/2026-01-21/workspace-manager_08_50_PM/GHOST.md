# Ghost Operational Ledger — Workspace Manager

## Mission
    1. Deliver a workspace orchestrator with an embedded terminal.
    2. Maintain a stable, responsive CPU-based terminal while GPU rendering is unresolved.
    3. Keep documentation, performance rationale, and technical decisions aligned.

## Architecture
    1. SwiftUI app with AppState models for workspaces and terminals.
    2. Terminal pipeline: SwiftTerm (LocalProcessTerminalView) for CPU-based rendering.
    3. Metal renderer prototypes live on the metal-renderer branch only.

## Decisions
    1. Metal renderer prototyping failed to produce correct glyph output; work is paused.
    2. Production behavior returns to SwiftTerm CPU rendering for stability and usability.
    3. Preserve the metal-renderer branch and stash for future research.

## Next Steps
    1. Stabilize CPU-based terminal behavior and performance in release builds.
    2. Only resume GPU renderer work after a clear atlas/shader debugging plan.

## Paths
    1. Primary: SwiftTerm CPU renderer (current main branch).
    2. Research: Metal renderer experiments on metal-renderer branch.
