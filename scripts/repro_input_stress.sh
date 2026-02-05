#!/usr/bin/env bash
set -euo pipefail

cat <<'EOF'
Workspace Manager Input Stress Checklist
=======================================

Preconditions
1. Launch app with diagnostics enabled:
   WM_DIAGNOSTICS=1 scripts/run.sh
2. Ensure at least 2 workspaces and 2 terminals per workspace.
3. Start a long-running command in one terminal (example: yes >/dev/null).

Manual Stress Matrix
1. Press Cmd+C repeatedly in terminal (copy / interrupt path).
2. Press Cmd+V repeatedly in terminal and text-input contexts.
3. Hold Command for 1+ second to validate external whisper popup behavior.
4. Run rapid sequence 50x:
   Cmd+P, Cmd+., Cmd+R, Shift+Cmd+R, Cmd+W (cancel close), Cmd+[ / Cmd+]
5. Switch workspaces/terminals rapidly while process is running.

Expected
1. No app crash, freeze, or unresponsive state.
2. Keymaps still trigger expected behavior.
3. No visible random glyph insertion from modifier-only events.

Post-check
1. Capture diagnostics snapshot from debugger:
   po InputEventRecorder.shared.snapshot()
EOF
