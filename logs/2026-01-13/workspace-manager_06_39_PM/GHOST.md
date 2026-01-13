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
    2. Treat the issue as an app-activation/key-window failure because keyboard input is broken across SwiftUI TextField, shortcuts, and terminal.

## Next Steps
    1. Force regular activation policy on launch and log activation state (isActive, keyWindow, mainWindow).
    2. Run the app as a proper .app bundle (Xcode target or packaged app) to validate keyboard input.
    3. If input still fails, add a local keyDown monitor and responder-chain logging to identify where events are dropped.

## Paths
    1. Preferred: fix input capture within the existing TUI stack (raw mode and stdin event loop).
    2. Contingency: swap input backend or add macOS-specific handling if the current stack is incompatible.
