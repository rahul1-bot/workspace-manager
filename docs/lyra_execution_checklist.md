# Lyra Execution Checklist

Objective: close blockers first, then stabilize behavior, then harden security, then repair documentation truth.

## Phase 0: Stop-the-bleed (must finish before any PR)
1. Fix test compile break in `Tests/WorkspaceManagerTests/KeyboardShortcutRouterTests.swift` by adding missing `ShortcutContext` fields (`hasFocusedGraphNode`, `hasSelectedGraphNode`) in `makeContext`.
2. Run and capture outputs:
   - `swift test -Xswiftc -warnings-as-errors`
   - `./scripts/ci.sh`
3. Exit criteria:
   - tests compile and pass
   - CI script returns 0

## Phase 1: Graph correctness
1. Persist viewport changes from pan/zoom:
   - add debounced save trigger when `graphViewport` changes from graph interactions
   - ensure save occurs on graph-mode exit as safety net
2. Keep graph node labels synced with terminal rename:
   - in `syncGraphFromWorkspaces`, update existing node metadata for matching `terminalId`
3. Add regression tests:
   - viewport roundtrip save/load
   - rename terminal updates graph node name
4. Exit criteria:
   - manual relaunch preserves viewport after pan/zoom-only session
   - tests validate rename sync behavior

## Phase 2: Security hardening (high leverage)
1. Canonical shell path before allowlist checks in `TerminalLaunchPolicy`.
2. Enforce directory-only CWD validation using `isDirectory` check.
3. Pin git executable path (remove `/usr/bin/env git` resolution ambiguity).
4. Add clipboard read confirmation policy (`confirm_read_clipboard_cb`) with safe default.
5. Harden temp output handling in `GitRepositoryService` (exclusive temp files or private temp dir).
6. Exit criteria:
   - targeted unit tests for launch policy validations
   - manual probe for `/bin/../tmp/<exec>` is rejected
   - clipboard read path requires explicit policy outcome

## Phase 3: Documentation truth repair
1. Update `GHOST.md` CI status line to reflect current verified state.
2. Update `progress.md` claims that currently state passing test counts and missing Cmd+scroll zoom.
3. Update `docs/pdf-viewer-design.md` to reflect shipped multi-tab PDF behavior.
4. Update `docs/spatial-graph-view.md` status from planned-only to current implementation state.
5. Mark stale statements in `SECURITY_AUDIT.md` as superseded or replace with latest report.
6. Exit criteria:
   - no doc claim contradicts current code/tests

## Guardrails Lyra must follow during execution
1. Do not bundle all fixes in one commit. Use one focused commit per finding cluster.
2. After each commit, rerun at least relevant tests; after final commit, rerun full CI script.
3. If any behavior change is uncertain, add test first, then patch.
4. Keep ledger updates evidence-based (command output backed), not aspirational.

## Suggested commit sequence
1. `test: align shortcut router tests with context fields`
2. `fix(graph): persist viewport state on pan and zoom interactions`
3. `fix(graph): sync node labels with terminal renames`
4. `fix(security): canonicalize shell path and require directory cwd`
5. `fix(security): pin git binary and harden temp output capture`
6. `fix(security): gate clipboard reads behind confirmation policy`
7. `docs: reconcile ledger and design docs with current implementation`
