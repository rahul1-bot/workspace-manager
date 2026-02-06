# Security Vulnerability Audit Report

**Project:** WorkspaceManager (macOS Terminal Orchestration App)
**Audit Date:** 06 February 2026
**Branch:** dev
**Scope:** Full codebase (Sources/, scripts/, Tests/, Package.swift, Frameworks/)

---

## Executive Summary

Total vulnerabilities found: **21**

| Severity | Count |
|----------|-------|
| CRITICAL | 1     |
| HIGH     | 4     |
| MEDIUM   | 9     |
| LOW      | 5     |
| INFO     | 2     |

The most severe findings involve supply chain risk from an unverified pre-compiled binary framework, shell allowlist bypass via path traversal, clipboard exfiltration through terminal escape sequences, and unsanitized environment propagation in fallback code paths.

---

## CRITICAL

### V-01: Unverified Pre-compiled Binary Framework (Supply Chain)

- **Files:** `Package.swift:47-49`, `Frameworks/GhosttyKit.xcframework/macos-arm64/libghostty-fat.a`
- **Category:** Supply chain / binary integrity

**Description:**
The `Package.swift` references a local `.binaryTarget` pointing to `Frameworks/GhosttyKit.xcframework`, containing a 141 MB pre-compiled static library (`libghostty-fat.a`). This binary is checked into the repo with zero integrity verification: no SHA-256 checksum, no code signature, and no version identifier in the Info.plist. SPM local binary targets have no verification mechanism.

This library is linked directly into the final executable and given full process privileges. The Ghostty runtime callbacks hand raw function pointers into this library, including clipboard access (`read_clipboard_cb`, `write_clipboard_cb`) and terminal action handlers.

**Exploitation Scenario:**
An attacker with repo write access (compromised CI, contributor account, or local filesystem) replaces `libghostty-fat.a` with a trojanized version. The build system links it without warning. The trojanized library gets full access to clipboard (passwords, tokens), keyboard input, and arbitrary code execution within the process.

**Recommended Fix:**
1. Document the exact upstream Ghostty commit and build instructions used to produce the `.a` file
2. Store and verify a SHA-256 hash in a build-time manifest (e.g., in `scripts/build_app_bundle.sh`)
3. Consider building GhosttyKit from source via SPM dependency instead of distributing a pre-compiled binary
4. At minimum, code-sign the xcframework

---

## HIGH

### V-02: Shell Allowlist Bypass via Path Traversal

- **File:** `Sources/WorkspaceManager/Support/TerminalLaunchPolicy.swift:39-48`
- **Category:** Shell allowlist bypass / arbitrary code execution

**Description:**
The `validateShell` method checks the shell path against allowed prefixes (`/bin/`, `/usr/bin/`, `/opt/homebrew/bin/`) using `hasPrefix`. It does NOT resolve symlinks or canonicalize the path before the prefix check. A path like `/bin/../tmp/malicious_shell` passes the prefix check (`hasPrefix("/bin/")` is `true`) but resolves to `/tmp/malicious_shell`.

**Exploitation Scenario:**
1. Attacker sets `SHELL=/bin/../tmp/evil_shell` in the environment
2. `"/bin/../tmp/evil_shell".hasPrefix("/bin/")` evaluates to `true`
3. `FileManager.isExecutableFile(atPath:)` resolves to `/tmp/evil_shell` and returns `true`
4. Arbitrary binary is spawned as the terminal shell

**Recommended Fix:**
Canonicalize the shell path using `URL(fileURLWithPath: shell).standardizedFileURL.path` (or `realpath()`) BEFORE performing the prefix check. Reject paths containing `..` segments outright.

---

### V-03: Clipboard Exfiltration via Unsanitized OSC 52 Read

- **Files:** `Sources/WorkspaceManager/Support/GhosttyClipboardBridge.swift:15-35`, `Sources/WorkspaceManager/Views/GhosttyTerminalView.swift:74`
- **Category:** Clipboard data exfiltration / terminal escape sequence attack

**Description:**
The `completeReadRequest` method reads the system clipboard unconditionally when triggered by the Ghostty library. The `confirm_read_clipboard_cb` is set to `nil` (line 74 of GhosttyTerminalView.swift), disabling confirmation. Any program running in the terminal can request clipboard contents via OSC 52 without user consent. Clipboards frequently contain passwords, API tokens, and authentication cookies.

**Exploitation Scenario:**
1. Malicious script outputs OSC 52 read sequence: `\e]52;c;?\a`
2. Ghostty invokes `read_clipboard_cb`
3. `completeReadRequest()` hands clipboard contents to the terminal process
4. Script exfiltrates the data via HTTP

This is the same attack class that affected iTerm2, Terminology, and other terminal emulators.

**Recommended Fix:**
Implement `confirm_read_clipboard_cb` to present a user confirmation dialog before releasing clipboard contents. Alternatively, disable OSC 52 read entirely.

---

### V-04: Workspace Path Traversal in Config (No Canonicalization)

- **Files:** `Sources/WorkspaceManager/Services/ConfigService.swift:59-70` (expandPath), `ConfigService.swift:406-416` (validateWorkspace)
- **Category:** Path traversal

**Description:**
The `expandPath` function expands tilde prefixes but does not canonicalize or restrict the resulting path. `validateWorkspace` only checks for empty paths and null bytes. There is no restriction on `..` segments, symlinks, or sensitive system directories. A config entry like `path = "~/../../etc"` expands and resolves to `/etc`.

**Exploitation Scenario:**
1. Attacker edits `~/.config/workspace-manager/config.toml` with `path = "~/../../private/var/root"`
2. App expands this path traversing outside the home directory
3. Terminal spawns with CWD set to a sensitive system directory

**Recommended Fix:**
After path expansion, use `URL(fileURLWithPath:).standardizedFileURL.path` to canonicalize. Verify the resolved path falls within an acceptable subtree (user home or allowed roots). Reject paths containing `..` after standardization.

---

### V-05: Command Injection via Unvalidated CONFIG in Build Script

- **File:** `scripts/build_app_bundle.sh:7-8, 17`
- **Category:** Command injection / path traversal in build tooling

**Description:**
`CONFIG="${CONFIG:-debug}"` is read from the environment and passed directly to `swift build -c "$CONFIG"` and used in file path construction: `cp "$ROOT_DIR/.build/$CONFIG/WorkspaceManager"`. The variable is never validated against a whitelist within this script.

**Exploitation Scenario:**
```bash
CONFIG="../../tmp/evil" ./scripts/build_app_bundle.sh
```
A pre-placed binary at `.build/../../tmp/evil/WorkspaceManager` would be copied into the app bundle and executed.

**Recommended Fix:**
Add validation in `build_app_bundle.sh`:
```bash
case "$CONFIG" in
  debug|release) ;;
  *) echo "Invalid CONFIG: $CONFIG" >&2; exit 2 ;;
esac
```

---

## MEDIUM

### V-06: Fallback Shell Bypasses Environment Sanitization

- **File:** `Sources/WorkspaceManager/Views/TerminalView.swift:94-101`
- **Category:** Security policy bypass

**Description:**
When `TerminalLaunchPolicy.buildPlan()` throws, the catch block falls back to `/bin/zsh -l` with `environment: nil`. Passing `nil` means the child process inherits the FULL parent environment, completely bypassing the `sanitizedEnvironment()` allowlist. This leaks all environment variables including potential secrets (`AWS_SECRET_ACCESS_KEY`, `GITHUB_TOKEN`, `DYLD_INSERT_LIBRARIES`, etc.).

**Exploitation Scenario:**
1. Attacker sets `SHELL=/invalid/path` plus `DYLD_INSERT_LIBRARIES=/tmp/evil.dylib`
2. Shell validation fails, catch block triggers
3. Fallback launches `/bin/zsh -l` with full environment, including `DYLD_INSERT_LIBRARIES`
4. Evil dylib is loaded into the shell process

**Recommended Fix:**
Build a minimal safe environment even in the error case. Never pass `nil` for the environment parameter.

---

### V-07: Clipboard Write Ignores Confirmation Parameter

- **File:** `Sources/WorkspaceManager/Support/GhosttyClipboardBridge.swift:37-61`
- **Category:** Clipboard hijacking

**Description:**
The `writeClipboard` method writes to the system clipboard unconditionally. The `confirm` parameter is received but never acted upon. Programs in the terminal can silently overwrite clipboard contents via OSC 52 write sequences.

**Exploitation Scenario:**
1. User copies a cryptocurrency wallet address
2. Malicious script emits OSC 52 write with attacker's address
3. Clipboard silently replaced
4. User pastes attacker's address into a transaction

**Recommended Fix:**
When `confirm == true`, show a user confirmation dialog. Rate-limit clipboard writes. Show a transient notification when clipboard is modified by a terminal process.

---

### V-08: Shell Metacharacters in Working Directory via Environment Variables

- **File:** `Sources/WorkspaceManager/Support/TerminalLaunchPolicy.swift:25-33`
- **Category:** Indirect command injection

**Description:**
The launch command uses:
```swift
let launchCommand = "cd -- \"$WM_START_CWD\" && exec \"$WM_EXEC_SHELL\" -l"
```
While `$WM_START_CWD` is double-quoted (preventing word splitting), a working directory containing literal double-quotes could potentially break out of the quoting context. The validation does not reject paths containing shell metacharacters (`"`, `$`, backticks).

**Note:** In practice, shell variable expansion inside double quotes is safe against command substitution for most shells. However, this defense is implicit and fragile. Any refactoring that changes the quoting strategy re-exposes this vector.

**Recommended Fix:**
Use `Process`/`posix_spawn` directly with `currentDirectoryURL` set programmatically, eliminating the shell-interpretation layer entirely.

---

### V-09: Config File Permissions Not Set Restrictively

- **File:** `Sources/WorkspaceManager/Services/ConfigService.swift:212-257` (saveConfig)
- **Category:** Insecure file permissions

**Description:**
When `saveConfig()` creates the config directory and writes the TOML file, it uses default umask permissions (typically `755` for directories, `644` for files on macOS). Any local user can read the config file, exposing workspace paths and project structure. If umask is overly permissive, other users could WRITE to the config.

**Exploitation Scenario:**
On a shared Mac, attacker modifies `~/.config/workspace-manager/config.toml` to add a workspace pointing to a directory containing a malicious `.zshrc`. Victim opens that workspace, shell sources the attacker's RC file.

**Recommended Fix:**
Set `0700` on the config directory and `0600` on the config file during creation and every save. Verify permissions on load.

---

### V-10: Ghostty Config Auto-Loading from Untrusted Location

- **File:** `Sources/WorkspaceManager/Views/GhosttyTerminalView.swift:48-50`
- **Category:** Configuration injection

**Description:**
`GhosttyAppManager.initialize()` calls `ghostty_config_load_default_files(cfg)` which loads Ghostty's config from `~/.config/ghostty/config`. This is separate from the app's `config.toml`. Ghostty config supports `command` (shell override), `initial-command`, keybindings, and other execution-related settings.

**Exploitation Scenario:**
Attacker writes to `~/.config/ghostty/config` (via compromised app, malicious git repo, etc.) to override shell command, add malicious keybindings, or enable `copy-on-select` for data exfiltration.

**Recommended Fix:**
Set all security-relevant Ghostty config keys programmatically after loading defaults, overriding anything dangerous. Or load only the app's own config and skip `ghostty_config_load_default_files`.

---

### V-11: Use-After-Free Risk in Unmanaged Pointer Lifecycle

- **File:** `Sources/WorkspaceManager/Views/GhosttyTerminalView.swift:55, 225`
- **Category:** Memory safety / use-after-free

**Description:**
`Unmanaged.passUnretained(self).toOpaque()` creates raw pointers without retaining. For `GhosttySurfaceNSView`, if the view is deallocated during a workspace switch while the Ghostty surface still holds the pointer, a use-after-free occurs. The `deinit` calls `ghostty_surface_free` but there is a race between SwiftUI view lifecycle and Ghostty's async rendering.

**Recommended Fix:**
Use `Unmanaged.passRetained(self)` with balanced `release` in `deinit`. Add guards to ensure no pending operations reference a deallocated view.

---

### V-12: Use-After-Free in Retained Clipboard Responses

- **File:** `Sources/WorkspaceManager/Support/GhosttyClipboardBridge.swift:22-28, 73-78`
- **Category:** Memory safety / use-after-free

**Description:**
`strdup`'d pointers are passed to `ghostty_surface_complete_clipboard_request` and stored in `retainedResponses`. When count exceeds 8, oldest pointers are freed. If Ghostty's C layer still holds a reference to a freed pointer, accessing it causes undefined behavior.

**Recommended Fix:**
Coordinate with Ghostty's memory ownership model. Use ref-counting or time-based expiry instead of count-based trimming.

---

### V-13: Keystroke Logging When Diagnostics Enabled

- **File:** `Sources/WorkspaceManager/Support/Diagnostics.swift:36-52`
- **Category:** Information disclosure / keystroke logging

**Description:**
When `WM_DIAGNOSTICS=1`, every keyboard event (key codes, modifiers, details) is stored in an in-memory ring buffer. The `snapshot()` method exposes the full buffer. Activation requires only setting an environment variable, which any parent process can do.

**Recommended Fix:**
Redact sensitive key data. Use `#if DEBUG` compilation flags instead of runtime env vars. Add auto-timeout for diagnostics. Restrict `snapshot()` access.

---

### V-14: Secure Input Balance Desynchronization on Crash

- **File:** `Sources/WorkspaceManager/Support/SecureInputController.swift:37-57`
- **Category:** Security state management failure

**Description:**
If the app crashes while secure input is enabled, `DisableSecureEventInput` is never called, leaving macOS secure input permanently enabled system-wide. This blocks password managers and accessibility tools.

**Recommended Fix:**
Register `atexit` handler or use `applicationWillTerminate` to balance all outstanding secure input enables with disables.

---

## LOW

### V-15: TOML Injection via Hand-Rolled String Escaping

- **File:** `Sources/WorkspaceManager/Services/ConfigService.swift:259-267`
- **Category:** TOML injection

**Description:**
`escapeTomlString` escapes backslash, double-quote, newline, CR, and tab. But it misses TOML Unicode escape sequences (`\uXXXX`, `\UXXXXXXXX`). Config is generated via string concatenation rather than using TOMLKit's serialization. While current escaping appears sufficient by accident, the hand-rolled approach is inherently fragile.

**Recommended Fix:**
Use TOMLKit's serialization API to generate TOML output instead of manual string concatenation.

---

### V-16: TOCTOU Race in Workspace Path Validation

- **File:** `Sources/WorkspaceManager/Services/ConfigService.swift:383-389`
- **Category:** TOCTOU race condition

**Description:**
Workspace paths are validated at config load time but could be replaced with symlinks between load and terminal spawn. `TerminalLaunchPolicy.validateWorkingDirectory` checks existence but does not resolve symlinks.

**Recommended Fix:**
Resolve symlinks using `URL.resolvingSymlinksInPath()` at validation time and re-verify at launch time.

---

### V-17: No Workspace Path Validation on UI Input

- **Files:** `Sources/WorkspaceManager/Views/WorkspaceSidebar.swift:124-153`, `Sources/WorkspaceManager/Models/AppState.swift:117-147`
- **Category:** Input validation gap

**Description:**
The "New Workspace" sheet accepts any path from user input. `addWorkspace()` warns if the path doesn't exist but doesn't reject it. No restriction on sensitive system directories.

**Recommended Fix:**
Validate paths exist and are directories before saving to config. Show UI error rather than silently falling back.

---

### V-18: Default 1M Scrollback Enables Resource Exhaustion

- **File:** `Sources/WorkspaceManager/Models/Config.swift:31`
- **Category:** Denial of service

**Description:**
Default scrollback is `1_000_000` lines. With multiple terminals (app bootstraps 2 per workspace), a process flooding stdout consumes gigabytes of memory.

**Recommended Fix:**
Reduce default to 10,000-50,000 lines. Add config validation capping the maximum.

---

### V-19: Paste into Rename Field Unsanitized

- **File:** `Sources/WorkspaceManager/Support/KeyboardShortcutRouter.swift:94-97`
- **Category:** Input injection

**Description:**
Cmd+V paste is passed through unconditionally during rename operations. Clipboard containing null bytes, path separators, or shell metacharacters would be injected into workspace names.

**Recommended Fix:**
Sanitize paste input in rename field handlers to strip control characters and null bytes.

---

## INFO

### V-20: Sensitive Path Disclosure in Error Messages

- **File:** `Sources/WorkspaceManager/Support/AppErrors.swift:9-54`
- **Category:** Information disclosure

**Description:**
Error descriptions include full file paths, workspace names, and shell paths. If displayed in UI, crash reports, or screen-sharing, they leak directory structure.

**Recommended Fix:**
Redact paths in user-facing messages. Keep full paths only in private debug logs with `privacy: .private`.

---

### V-21: `privacy: .public` Annotations Leak Paths to Unified Log

- **File:** `Sources/WorkspaceManager/Support/AppLogger.swift` + call sites across codebase
- **Category:** Information disclosure via logging

**Description:**
Multiple call sites use `privacy: .public` for os_log interpolation. Apple's os_log defaults to `.auto` (redacted in release). Explicitly marking `.public` means sensitive data appears in the unified log, readable by any process via `log stream`.

**Recommended Fix:**
Audit all `.public` annotations. Change path/error interpolations to `.private` or remove explicit annotation to use the safer default.

---

## Missing Security Test Coverage

The following security-critical areas have **zero** test coverage:

| Area | Risk |
|------|------|
| `GhosttyClipboardBridge` (read/write, size limits, retention) | HIGH |
| `ConfigService.escapeTomlString` (injection edge cases) | MEDIUM |
| `ConfigService.expandPath` (tilde expansion edge cases, `..` traversal) | MEDIUM |
| `ConfigService.validateWorkspace` (direct unit tests) | MEDIUM |
| `SecureInputController` (balance counter, overflow) | MEDIUM |
| Clipboard OSC 52 attack scenarios (integration tests) | HIGH |
| Path validation with symlinks, `..`, null bytes | MEDIUM |
| Config reload race conditions | LOW |
| Shell allowlist bypass with `..` paths | HIGH |
| Build script input validation | MEDIUM |

---

## Remediation Priority Order

| Priority | ID(s) | Effort | Impact |
|----------|-------|--------|--------|
| 1 | V-01 | Medium | Eliminates supply chain risk |
| 2 | V-02 | Low | Blocks arbitrary shell execution via path traversal |
| 3 | V-03 | Low | Prevents clipboard exfiltration via OSC 52 |
| 4 | V-04 | Low | Blocks workspace path traversal to sensitive dirs |
| 5 | V-06 | Low | Fixes environment leak in fallback path |
| 6 | V-05 | Low | Blocks shell injection via CONFIG in build script |
| 7 | V-07 | Low | Prevents silent clipboard hijacking |
| 8 | V-09 | Low | Restricts config file permissions |
| 9 | V-08 | Medium | Eliminates shell command string construction |
| 10 | V-10 | Medium | Isolates Ghostty config loading |
| 11 | V-11, V-12 | Medium | Fixes memory safety issues |
| 12 | V-13, V-14 | Low | Hardens diagnostics and secure input |
| 13 | V-15 through V-21 | Low | Remaining hardening |
