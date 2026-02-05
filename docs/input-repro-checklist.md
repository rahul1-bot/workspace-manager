# Input Reproduction Checklist

## Purpose
This checklist provides a deterministic, repeatable stress flow for keyboard-input instability, especially around command-modifier handling, copy/paste, and rapid shortcut bursts.

## Setup
1. Launch with diagnostics:
   `WM_DIAGNOSTICS=1 scripts/run.sh`
2. Confirm at least two workspaces are present.
3. Confirm each workspace has at least two terminals.
4. In one terminal, run a long-lived process to verify stability while switching contexts.

## Stress Cases
1. Repeat `Cmd+C` in terminal context for 100 cycles.
2. Repeat `Cmd+V` in terminal context for 100 cycles.
3. Hold `Command` for one second and check external speech-to-text trigger behavior.
4. Run 50 cycles of: `Cmd+P`, `Cmd+.`, `Cmd+R`, `Shift+Cmd+R`, `Cmd+W` (cancel), `Cmd+[`, `Cmd+]`.
5. Switch terminal and workspace rapidly during active process execution.

## Expected Result
1. App remains alive and responsive.
2. No random terminal glyph insertion from modifier-only actions.
3. No stuck modifier state.
4. Existing navigation shortcuts still behave as documented.

## Diagnostics Capture
When reproducing any fault, capture a ring-buffer snapshot in LLDB:
`po InputEventRecorder.shared.snapshot()`
