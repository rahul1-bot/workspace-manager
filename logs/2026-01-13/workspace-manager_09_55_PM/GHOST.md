# Ghost Operational Ledger — Workspace Manager

## Mission
    1. Deliver a workspace orchestrator with an embedded terminal.
    2. Achieve 120Hz rendering via a Metal-backed terminal view on Apple Silicon.
    3. Keep documentation, performance rationale, and technical decisions aligned.

## Architecture
    1. SwiftUI app with AppState models for workspaces and terminals.
    2. Terminal pipeline: PTY + terminal parser + Metal renderer (MTKView).
    3. Current SwiftTerm view remains a temporary fallback only.

## Decisions
    1. Target in-app Metal renderer; external terminals are out of scope.
    2. Reuse SwiftTerm core for parsing if it can be decoupled from its AppKit renderer.
    3. Prioritize frame pacing and GPU utilization over feature breadth.
    4. Maintain a release .app bundle runner for realistic performance testing.
    5. Implement a Metal renderer prototype with a glyph atlas and static grid as the first milestone.
    6. Bridge SwiftTerm core (Terminal + LocalProcess) into the Metal renderer, updating rows via Terminal update ranges.

## Next Steps
    1. Validate live PTY output and input in the Metal view through release bundle runs.
    2. Add cursor rendering and selection visuals in the Metal pipeline.
    3. Profile with Instruments to confirm GPU usage and frame pacing.

## Paths
    1. Primary: SwiftTerm core + custom Metal view.
    2. Contingency: replace SwiftTerm core with libvterm if integration blocks.
    3. Out of scope: Warp embedding or external terminal windows.
