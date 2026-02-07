# Security Best Practices Report

Date: 06 February 2026  
Project: WorkspaceManager (`dev` working state)  
Scope: Swift macOS app + shell scripts

## Executive Summary
Security posture is mixed: core process-launching hardening exists, but key bypasses remain. Highest-priority risks are shell-path allowlist bypass via non-canonical paths and silent clipboard read behavior. Git command execution and temp output capture are functional but not hardened to best-practice standards.

Important context: the `security-best-practices` skill references in this environment contain guidance for Python/JavaScript/Go stacks only. No Swift-specific reference file exists, so this report uses secure-by-default principles applied directly to current code.

## Findings

## Critical
None confirmed.

## High

### SBP-001: Shell allowlist bypass through non-canonical path
- Severity: High
- File: `Sources/WorkspaceManager/Support/TerminalLaunchPolicy.swift`
- Lines: 10-14, 42-45
- Problem:
  - Allowed shell check is prefix-based on raw path string.
  - Non-canonical path like `/bin/../tmp/malicious_shell` passes `/bin/` prefix and executable checks.
- Verification:
  - Probe output confirmed: `prefix-check-passes`, `executable-check-passes`.
- Failure mode:
  - Launch policy accepts executable outside intended trusted directories.
- Remediation:
  1. Canonicalize with standardized/real path before allowlist evaluation.
  2. Compare canonical path against explicit trusted directories.
  3. Reject traversal segments (`..`) after normalization.

### SBP-002: Clipboard read confirmation callback disabled
- Severity: High
- File: `Sources/WorkspaceManager/Views/GhosttyTerminalView.swift`
- Lines: 74-83
- Related file: `Sources/WorkspaceManager/Support/GhosttyClipboardBridge.swift:12-20`
- Problem:
  - `confirm_read_clipboard_cb` is unset (`nil`), while read callback returns clipboard text synchronously when requested.
- Failure mode:
  - Terminal-side request can read clipboard without explicit user confirmation.
- Remediation:
  1. Implement confirmation callback and default-deny in ambiguous contexts.
  2. Add a user-visible policy setting (ask/allow/deny) with safe default.

## Medium

### SBP-003: Working directory validation allows file paths
- Severity: Medium
- File: `Sources/WorkspaceManager/Support/TerminalLaunchPolicy.swift`
- Lines: 50-57
- Problem:
  - Validation checks existence but not directory-ness.
- Failure mode:
  - File path passes validation; `cd` in launch command fails and terminal session exits.
- Remediation:
  1. Use `fileExists(atPath:isDirectory:)` and require `isDirectory == true`.
  2. Add unit test for file-path rejection.

### SBP-004: Git binary resolved through inherited PATH
- Severity: Medium
- File: `Sources/WorkspaceManager/Services/GitRepositoryService.swift`
- Lines: 211-213
- Problem:
  - Uses `/usr/bin/env git`, allowing PATH-based resolution.
- Failure mode:
  - If PATH is manipulated, malicious `git` can be executed.
- Remediation:
  1. Use absolute binary path (`/usr/bin/git`) or resolve once and pin.
  2. Optionally set a minimal controlled PATH for Process invocations.

### SBP-005: Temp file output capture is race-prone in shared temp directory
- Severity: Medium
- File: `Sources/WorkspaceManager/Services/GitRepositoryService.swift`
- Lines: 214-236
- Problem:
  - Stdout/stderr files are created in temp dir via predictable pattern and then opened.
- Failure mode:
  - Same-user local process can race or interfere with temp file targets.
- Remediation:
  1. Use secure temp file creation (`mkstemp`/exclusive create) or private temp directory.
  2. Prefer in-memory `Pipe()` where deadlock risk is controlled.

## Low

### SBP-006: External editor CLI trust is implicit
- Severity: Low
- File: `Sources/WorkspaceManager/Services/EditorLaunchService.swift`
- Lines: 145-159
- Problem:
  - Executes `/usr/local/bin/zed` if present without provenance checks.
- Failure mode:
  - Replaced local binary can execute arbitrary code in user context.
- Remediation:
  1. Prefer app bundle launch via `NSWorkspace`.
  2. If CLI path is used, verify owner/permissions/signature before execution.

### SBP-007: Supply-chain trust for local binary framework is undocumented
- Severity: Low
- File: `Package.swift`
- Lines: 49-52
- Problem:
  - Binary target `GhosttyKit.xcframework` is local and trusted implicitly.
- Failure mode:
  - Tampered artifact can inject compromised runtime code.
- Remediation:
  1. Document provenance and build process.
  2. Add hash/signature verification step in CI.

## Reviewed and rejected (to avoid false positives)

### RB-001: Claimed command substitution from variable content inside quoted shell expansion
- Status: Rejected for this specific launch string
- Verification:
  - Probe with `x='$(echo SHOULD_NOT_EXECUTE)'` produced literal output; command substitution was not executed from variable content.
- Decision:
  - Do not report as confirmed vulnerability without an `eval`/re-parse path.

## Shell script assessment
Reviewed `scripts/*.sh` for command injection and quoting issues. No high-impact shell injection issue confirmed in current scripts.

## Uncertainties / static-analysis limits
1. Runtime launch environment constraints (actual PATH and shell env in deployed context).
2. Provenance/signing guarantees for `GhosttyKit.xcframework`.
3. Threat model decision for clipboard reads (trusted-only workflows vs hostile-terminal assumption).

## Recommended implementation order
1. `SBP-001` shell-path canonicalization
2. `SBP-002` clipboard confirmation policy
3. `SBP-003` directory-only working-dir validation
4. `SBP-004` absolute git binary pinning
5. `SBP-005` secure temp output handling
