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
    3. Implement activation policy enforcement and local key event logging in AppDelegate to confirm input delivery.

## Next Steps
    1. Run the app and inspect activation and key event logs for delivery and responder chain status.
    2. Launch as a proper .app bundle via Xcode or packaging and compare keyboard behavior.
    3. If input still fails, add responder-chain tracing in a window accessor and verify key window state on selection changes.

## Paths
    1. Preferred: fix input capture within the existing TUI stack (raw mode and stdin event loop).
    2. Contingency: swap input backend or add macOS-specific handling if the current stack is incompatible.
