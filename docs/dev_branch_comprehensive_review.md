# Dev Branch Comprehensive Review

Date: 06 February 2026  
Scope: `dev` branch working tree (`/Users/rahulsawhney/Library/CloudStorage/OneDrive-Personal/Documents/StudyDocuments/Rahul/code/ideas/TUI/workspace-manager`)  
Snapshot anchor: `Friday, 06 February 2026, 09:36 PM (Europe/Berlin)` from `snap .`

## 1. Verdict (No Sugarcoating)
The branch is **not PR-ready**.

The blocker is simple: test suite does not compile. On top of that, graph-state behavior is partially wired (viewport persistence is incomplete), security hardening has known holes in launch policy and clipboard permissions, and documentation/ledger drift is now large enough to mislead execution.

If this is merged as-is, Lyra will implement against stale assumptions and waste cycles fixing regressions that should have been prevented by CI.

## 2. Verification Strike

### 2.1 Commands executed and outcomes
1. `git status --short --branch`  
   Result: branch `dev`, with local modifications in:
   - `Sources/WorkspaceManager/ContentView.swift`
   - `Sources/WorkspaceManager/Models/AppState.swift`
   - `Sources/WorkspaceManager/Models/ViewportTransform.swift`
   - `Sources/WorkspaceManager/Support/KeyboardShortcutRouter.swift`
   - `Sources/WorkspaceManager/Views/GraphCanvasView.swift`
2. `./scripts/ci.sh`  
   Result: failed (release build was interrupted once by file mutation during build).
3. `swift build -c release -Xswiftc -warnings-as-errors`  
   Result: passed.
4. `swift test -Xswiftc -warnings-as-errors`  
   Result: failed at compile stage with missing initializer args in `KeyboardShortcutRouterTests`.
5. Shell probe (disputed claim check): variable value command substitution inside double quotes.
   - Command used: `zsh -lc 'x='"'$(echo SHOULD_NOT_EXECUTE)'"'; echo "value:$x"; ...'`
   - Result: `value:SHOULD_NOT_EXECUTE` (literal preserved, no command execution).
6. Shell probe (allowlist bypass check):
   - Created executable in `/tmp`, checked candidate path `/bin/../tmp/<name>`.
   - Result: `prefix-check-passes` and `executable-check-passes`.
7. `rg -n "saveGraphState\(" Sources/WorkspaceManager/Views/GraphCanvasView.swift Sources/WorkspaceManager/Models/AppState.swift`  
   Result: graph save calls occur on node/cluster drag and layout completion, not on pan/zoom updates.

### 2.2 Assumptions, dependencies, missing data

#### Assumptions currently embedded in code/docs
1. "CI gate is passing locally" (`GHOST.md:48`) is no longer true for current state.
2. "54 tests pass" repeatedly asserted in progress ledger (`progress.md:18`, `progress.md:42`, `progress.md:182`, `progress.md:232`, etc.) is false under current code.
3. PDF design doc still states multi-PDF is out-of-scope (`docs/pdf-viewer-design.md:248`), but implementation uses tabbed multi-PDF state (`Sources/WorkspaceManager/Models/PDFUIModels.swift:24-53`).

#### Hard dependencies that materially affect security/correctness
1. Local binary dependency: `Frameworks/GhosttyKit.xcframework` (`Package.swift:49-52`).
2. Runtime shell path comes from environment with prefix allowlist (`Sources/WorkspaceManager/Support/TerminalLaunchPolicy.swift:20-48`).
3. Git command execution resolves `git` via environment PATH (`Sources/WorkspaceManager/Services/GitRepositoryService.swift:211-213`).
4. Clipboard read callback has no confirmation hook (`Sources/WorkspaceManager/Views/GhosttyTerminalView.swift:74-83`).

#### Missing data that blocks high-confidence closure
1. Whether uncommitted graph changes are intentionally in-review scope or parallel WIP.
2. Expected security posture for clipboard reads (always allow vs prompt vs deny-by-default).
3. Required provenance policy for `GhosttyKit.xcframework` (signature/hash process not defined in repo docs).

## 3. Findings (ordered by severity)

### B-001 (Blocker) Test suite compile failure
- Type: Correctness / Quality gate
- Evidence:
  - `swift test -Xswiftc -warnings-as-errors` fails.
  - Error references `Tests/WorkspaceManagerTests/KeyboardShortcutRouterTests.swift:149`.
  - `ShortcutContext` now requires `hasFocusedGraphNode` and `hasSelectedGraphNode` (`Sources/WorkspaceManager/Support/KeyboardShortcutRouter.swift:4-16`), but test helper `makeContext` does not provide them (`Tests/WorkspaceManagerTests/KeyboardShortcutRouterTests.swift:138-159`).
- Failure mode: CI red; no reliable regression net.
- Trigger: Any test/build run including this test target.
- Consequence: Merge risk increases immediately; shortcut routing changes can ship unverified.

### H-001 Graph viewport persistence is incomplete
- Type: Behavior regression
- Evidence:
  - Viewport is now modeled in AppState (`Sources/WorkspaceManager/Models/AppState.swift:33`, `Sources/WorkspaceManager/Models/AppState.swift:995-1006`).
  - Pan/zoom mutate `appState.graphViewport` in graph view (`Sources/WorkspaceManager/Views/GraphCanvasView.swift:412-443`).
  - Save calls exist only on node/cluster drag and layout completion (`Sources/WorkspaceManager/Views/GraphCanvasView.swift:427`, `Sources/WorkspaceManager/Views/GraphCanvasView.swift:460`, `Sources/WorkspaceManager/Models/AppState.swift:1165`).
- Failure mode: User pans/zooms, quits, relaunches, viewport may revert.
- Trigger: Session with viewport-only interactions (no node drag/layout completion).
- Consequence: "Persisted graph viewport" expectation is violated.

### H-002 Graph node labels drift after terminal rename
- Type: Correctness
- Evidence:
  - Graph sync only appends missing nodes by terminal ID (`Sources/WorkspaceManager/Models/AppState.swift:1010-1031`).
  - Existing nodes are not updated with latest terminal names.
  - Rename updates terminal model only (`Sources/WorkspaceManager/Models/AppState.swift:276-283`).
- Failure mode: Sidebar shows new terminal name; graph node keeps stale name.
- Trigger: Rename terminal after node has been created.
- Consequence: UI inconsistency, broken spatial trust, operator confusion.

### H-003 Security: shell allowlist bypass via non-canonical path checks
- Type: Security
- Evidence:
  - Prefix allowlist uses raw string `hasPrefix` (`Sources/WorkspaceManager/Support/TerminalLaunchPolicy.swift:10-14`, `Sources/WorkspaceManager/Support/TerminalLaunchPolicy.swift:42-43`).
  - Executability check uses raw path (`Sources/WorkspaceManager/Support/TerminalLaunchPolicy.swift:45`).
  - Probe confirmed `/bin/../tmp/<exec>` passes both checks.
- Failure mode: Non-canonical path bypasses intended shell directory restriction.
- Trigger: Crafted executable path with allowed prefix and traversal segments.
- Consequence: Arbitrary local executable can be launched as shell.

### H-004 Security: clipboard reads are allowed without user confirmation
- Type: Security / Data exposure
- Evidence:
  - `confirm_read_clipboard_cb = nil` (`Sources/WorkspaceManager/Views/GhosttyTerminalView.swift:80`).
  - Read callback always returns clipboard text when requested (`Sources/WorkspaceManager/Support/GhosttyClipboardBridge.swift:12-20`).
- Failure mode: Terminal process can request clipboard contents silently.
- Trigger: Untrusted process in terminal issuing clipboard read sequence.
- Consequence: Clipboard secret exposure risk.

### M-001 Working directory validation accepts files (not only directories)
- Type: Correctness + hardening
- Evidence:
  - Validation checks existence only (`Sources/WorkspaceManager/Support/TerminalLaunchPolicy.swift:55-57`).
  - No `isDirectory` check.
- Failure mode: File path passes validation, then `cd -- "$WM_START_CWD"` fails in launch command (`Sources/WorkspaceManager/Support/TerminalLaunchPolicy.swift:30`).
- Trigger: Terminal configured with file path CWD.
- Consequence: Terminal launch failure / immediate shell exit.

### M-002 Git process resolution and temp output handling are weakly hardened
- Type: Security hardening
- Evidence:
  - Uses `/usr/bin/env git` (`Sources/WorkspaceManager/Services/GitRepositoryService.swift:211-213`).
  - Temp stdout/stderr file paths created in shared temp dir with predictable naming pattern (`Sources/WorkspaceManager/Services/GitRepositoryService.swift:214-236`).
- Failure mode: PATH hijack potential + local temp race risk.
- Trigger: Compromised environment or local same-user malicious process.
- Consequence: Integrity risk in command execution and output capture.

### M-003 Documentation and ledger drift is now operationally dangerous
- Type: Maintainability / process integrity
- Evidence:
  - CI passing claim: `GHOST.md:48` vs actual failing tests.
  - Multiple "swift test passes" claims in `progress.md` (`progress.md:18`, `progress.md:42`, `progress.md:182`, etc.) vs current failure.
  - Progress says Cmd+scroll zoom is missing (`progress.md:170`) while code implements monitor (`Sources/WorkspaceManager/ContentView.swift:402-420`).
  - PDF design says multi-PDF out-of-scope (`docs/pdf-viewer-design.md:248`) while tabs are implemented (`Sources/WorkspaceManager/Models/PDFUIModels.swift:24-53`, `Sources/WorkspaceManager/Views/PDFPanelView.swift:35-185`).
  - Spatial graph doc still marked planned/deferred (`docs/spatial-graph-view.md:10`) while substantial implementation exists.
- Failure mode: Team plans against stale facts.
- Trigger: Any roadmap/review/planning use of docs/ledgers.
- Consequence: Rework, wrong priorities, duplicated effort.

### M-004 Existing `SECURITY_AUDIT.md` contains stale or superseded assertions
- Type: Documentation integrity
- Evidence:
  - Mentions `retainedResponses` flow (`SECURITY_AUDIT.md:244`) no longer present in implementation (`Sources/WorkspaceManager/Support/GhosttyClipboardBridge.swift`).
- Failure mode: Security triage based on outdated claims.
- Trigger: Security planning from that file without code verification.
- Consequence: Time wasted on already-fixed or non-existent code paths.

## 4. Corrected Plan (priority order with proof)

### P0: Restore hard quality gate
1. Fix `ShortcutContext` test helper signature in `Tests/WorkspaceManagerTests/KeyboardShortcutRouterTests.swift`.
2. Re-run:
   - `swift test -Xswiftc -warnings-as-errors`
   - `./scripts/ci.sh`
3. Proof target: zero compile/test failures.

### P1: Close graph-state correctness gaps
1. Persist viewport on pan/zoom/zoom-to-fit/scroll-zoom with debounce.
2. Update `syncGraphFromWorkspaces` to refresh existing node names/workspace mappings by terminal ID.
3. Add tests:
   - viewport save/load roundtrip
   - terminal rename reflects in graph node label
4. Proof target: deterministic tests and manual restart check.

### P2: Security hardening pass (high leverage, low churn)
1. Canonicalize shell path before allowlist check (standardize/resolve symlinks, reject traversal).
2. Require working directory to be an actual directory (`isDirectory == true`).
3. Replace `/usr/bin/env git` with pinned absolute git path.
4. Implement clipboard read confirmation policy (prompt or default-deny with explicit allow).
5. Proof target: focused unit tests + negative probes.

### P3: Repair trust layer (docs/ledger sync)
1. Update `GHOST.md`, `progress.md`, and relevant `docs/*.md` with current status.
2. Mark superseded security findings in `SECURITY_AUDIT.md` or replace with validated report.
3. Proof target: no claim in docs contradicts current code/test outputs.

## 5. Contingency Matrix

1. Trigger: CI remains red after test helper fix.
   - Fallback move: isolate router API churn by adding temporary defaults in `ShortcutContext` init at test boundary only, then remove after full test migration.

2. Trigger: Clipboard confirmation UX causes workflow friction.
   - Fallback move: configurable policy with explicit default (`deny` or `ask`), never implicit allow in unknown contexts.

3. Trigger: Canonical shell-path enforcement blocks legitimate setups.
   - Fallback move: extend allowlist with explicit absolute paths, not prefix patterns.

4. Trigger: Viewport persistence writes too often.
   - Fallback move: debounce at AppState level (single save pipeline), flush on graph-mode exit.

## 6. Explicit disagreements corrected with proof
1. Rejected claim: shell command substitution from variable content inside double quotes as an automatic injection vector in this launch string.
   - Proof: command probe preserved literal value (`SHOULD_NOT_EXECUTE`) and did not execute substitution.
2. Accepted and proven instead: path-prefix allowlist bypass via non-canonical shell path.
   - Proof: `/bin/../tmp/<exec>` passed both prefix and executable checks.

## 7. Final decision
Do not open PR from current state. Land P0 first, then P1/P2 in separate reviewable commits, then refresh docs (P3).
