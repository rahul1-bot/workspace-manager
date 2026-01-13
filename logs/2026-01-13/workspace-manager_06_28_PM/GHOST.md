# Ghost Operational Ledger — Workspace Manager

## Mission
    1. Maintain a reliable TUI workspace manager that captures keyboard input on macOS terminals.
    2. Diagnose and resolve the current keyboard input loss in the app.
    3. Keep scope-level documentation aligned with code and runtime behavior.

## Architecture
    1. Language: Swift Package Manager (Package.swift).
    2. Interface: terminal-based TUI with an input/render loop.
    3. Runtime: macOS terminal; input via stdin raw mode (to be confirmed in code).

## Decisions
    1. Start by auditing input handling and terminal mode initialization before UI logic.

## Next Steps
    1. Read scope ledgers and code to map input flow.
    2. Reproduce and trace the input path; identify where events are dropped.
    3. Propose a fix and add a minimal input test or debug harness.

## Paths
    1. Preferred: fix input capture within the existing TUI stack (raw mode and stdin event loop).
    2. Contingency: swap input backend or add macOS-specific handling if the current stack is incompatible.
