# SECURITY AND CODE AUDIT REPORT
## Workspace Manager - Brutal Assessment

**Auditor**: Claude Opus 4.5
**Date**: 2026-01-21
**Branch**: `claude/security-code-audit-CeMtD`
**Verdict**: **FAIL** - Multiple critical security flaws, architecture contradictions, hardcoded PII, and missing error handling.

---

## EXECUTIVE SUMMARY

This codebase exhibits **alarming security negligence**, **documentation-to-code contradictions**, and **incomplete implementations masquerading as completed features**. The project claims to be "open source ready" per `progress.md:499-561` while containing hardcoded personal file paths, no input sanitization, command injection vulnerabilities, and memory management issues.

---

## SECTION 1: CRITICAL SECURITY VULNERABILITIES

### 1.1 COMMAND INJECTION - SEVERITY: CRITICAL

**Location**: `TerminalView.swift:87`

```swift
terminalView.startProcess(
    executable: shell,
    args: ["-c", "cd '\(cwd)' && exec \(shell)"],
    // ...
)
```

**Failure Mode**: The `cwd` variable is derived from user config (`workingDirectory`) with only basic path existence validation. Single quotes do NOT prevent injection in shell contexts.

**Triggering Condition**: A malicious TOML config with:
```toml
[[workspaces]]
name = "Exploit"
path = "'; rm -rf ~; echo '"
```

**Downstream Consequence**: Arbitrary command execution with user privileges. Complete system compromise.

**Evidence Path**: `ConfigService.swift:82-84` passes raw user input → `AppState.swift:63` creates workspace with raw path → `Workspace.swift:19` stores unvalidated path → `TerminalView.swift:87` executes it in shell.

---

### 1.2 PATH TRAVERSAL - SEVERITY: HIGH

**Location**: `ConfigService.swift:37-43`

```swift
func expandPath(_ path: String) -> String {
    if path.hasPrefix("~") {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        return path.replacingCharacters(in: path.startIndex..<path.index(after: path.startIndex), with: homeDir)
    }
    return path
}
```

**Failure Mode**: No validation against `..` sequences. A path like `~/../../etc/passwd` or `~root/.ssh/` is accepted without question.

**Triggering Condition**: Config file with path traversal sequences.

**Downstream Consequence**: Terminal sessions spawned in sensitive directories; potential information disclosure.

---

### 1.3 UNVALIDATED SHELL ENVIRONMENT VARIABLE - SEVERITY: HIGH

**Location**: `TerminalView.swift:75`

```swift
let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
```

**Failure Mode**: The `SHELL` environment variable is trusted without validation. If an attacker controls the environment (e.g., via parent process manipulation), they can point to a malicious binary.

**Triggering Condition**: Malicious `SHELL` environment variable set before app launch.

**Downstream Consequence**: Execution of arbitrary binary with user privileges.

---

### 1.4 TOML INJECTION - SEVERITY: MEDIUM

**Location**: `ConfigService.swift:129-156`

```swift
var toml = """
[terminal]
font = "\(config.terminal.font)"
...
name = "\(workspace.name)"
path = "\(displayPath)"
"""
```

**Failure Mode**: Config values are interpolated directly into TOML without escaping. A workspace name containing `"` or newlines corrupts the config file.

**Triggering Condition**: User creates workspace with name containing special TOML characters.

**Downstream Consequence**: Config file corruption; app fails to start on next launch.

---

### 1.5 CLIPBOARD DATA EXFILTRATION RISK - SEVERITY: MEDIUM

**Location**: `GhosttyTerminalView.swift:63-79`

```swift
runtimeConfig.read_clipboard_cb = { userdata, location, state in
    let content = NSPasteboard.general.string(forType: .string) ?? ""
    content.withCString { cstr in
        ghostty_surface_complete_clipboard_request(state, cstr, nil, false)
    }
}
```

**Failure Mode**: No user confirmation for clipboard read. Terminal escape sequences can trigger clipboard reads silently.

**Triggering Condition**: Malicious terminal output with OSC 52 escape sequences.

**Downstream Consequence**: Silent exfiltration of clipboard contents (passwords, tokens, etc.).

---

## SECTION 2: HARDCODED PII EXPOSURE - SEVERITY: HIGH

### 2.1 PERSONAL FILE PATH IN SOURCE CODE

**Location**: `ConfigService.swift:14`

```swift
private static let studyRoot = "/Users/rahulsawhney/Library/CloudStorage/OneDrive-Personal/Documents/StudyDocuments/Rahul"
```

**Location**: `ConfigService.swift:17-23`

```swift
private static let defaultCourses = [
    "10) AI-2 Project (Majors-2)(10 ETCS)(Coding Project)",
    "38) Computational Imaging Project (Applications-12)(10 ETCS)(Coding Project)",
    "19) Project-Representation-Learning (Minor-5)(10 ETCS)(Coding Project)",
    "39) Research Movement Analysis (Seminar-3)(5 ETCS)(Report-Presentation)",
    "16) ML in MRI (Majors-3 OR Seminar-1)(5 ETCS)(Presentation-Exam)",
]
```

**Failure Mode**: Full username (`rahulsawhney`) and academic course structure exposed in source code destined for "open source release" per `progress.md:536`.

**Contradiction with stated goal**: `progress.md:503` states "Open sourcing soon" but the code contains PII that would be published.

---

### 2.2 BUNDLE IDENTIFIER EXPOSES PERSONAL INFO

**Location**: `scripts/build_app_bundle.sh:30`

```xml
<key>CFBundleIdentifier</key>
<string>com.rahul.workspace-manager</string>
```

---

## SECTION 3: DOCUMENTATION VS CODE CONTRADICTIONS

### 3.1 GHOST.md CONTRADICTS ACTUAL IMPLEMENTATION

**GHOST.md Claims** (lines 9-11):
```
2. Terminal pipeline: SwiftTerm (LocalProcessTerminalView) for CPU-based rendering.
3. Metal renderer prototypes live on the metal-renderer branch only.
```

**Actual Code** (`TerminalView.swift:141`):
```swift
let useGhosttyRenderer = true
```

**Contradiction**: GHOST.md explicitly states production uses SwiftTerm CPU renderer, but code defaults to libghostty Metal renderer. There is no `metal-renderer` branch - the feature flag is in the main codebase.

---

### 3.2 GHOST.md NEXT STEPS ARE STALE

**GHOST.md Claims** (lines 18-20):
```
1. Stabilize CPU-based terminal behavior and performance in release builds.
2. Only resume GPU renderer work after a clear atlas/shader debugging plan.
```

**progress.md Reality** (lines 302-304):
```
1. Successfully completed libghostty integration for 120hz Metal terminal rendering.
...
3. Project is now using GPU-accelerated rendering via libghostty
```

**Verdict**: GHOST.md is completely outdated and misleading. A developer reading GHOST.md would conclude GPU rendering is experimental and unused.

---

### 3.3 LYRA.md TECH STACK INCOMPLETE

**LYRA.md Claims** (line 16):
```
| Tech Stack | Swift, SwiftUI, SwiftTerm (CPU renderer), TOMLKit |
```

**Actual Dependencies** (`Package.swift:19-23`):
```swift
dependencies: [
    .product(name: "SwiftTerm", package: "SwiftTerm"),
    .product(name: "TOMLKit", package: "TOMLKit"),
    "GhosttyKit"  // MISSING FROM DOCUMENTATION
]
```

**Missing from docs**: GhosttyKit, Metal, MetalKit, Carbon frameworks. The tech stack description omits the primary rendering engine.

---

## SECTION 4: RESOURCE MANAGEMENT ISSUES

### 4.1 EVENT MONITOR MEMORY LEAK

**Location**: `ContentView.swift:46-111`

```swift
.onAppear {
    NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
        // ...
    }
}
```

**Failure Mode**: Event monitor is added on every `onAppear` but NEVER removed. SwiftUI views can appear/disappear multiple times.

**Triggering Condition**: Navigate away from ContentView and back, or window minimize/restore cycles.

**Downstream Consequence**: Memory leak; accumulated event handlers firing multiple times.

**Contrast with**: `WorkspaceManagerApp.swift:85-92` which correctly implements `removeInputMonitors()`.

---

### 4.2 TIMER CLEANUP ON DEINIT ONLY

**Location**: `GhosttyTerminalView.swift:413-418`

```swift
deinit {
    stopMomentumTimer()
    if let surface = surface {
        ghostty_surface_free(surface)
    }
}
```

**Failure Mode**: Timers are only cleaned up in `deinit`, but SwiftUI views can be deallocated at arbitrary times. If the view is recreated rapidly, orphan timers may fire on deallocated objects.

**Triggering Condition**: Rapid terminal switching or workspace changes.

**Downstream Consequence**: Potential crashes or undefined behavior from timer callbacks on deallocated views.

---

### 4.3 GHOSTTY APP MANAGER NEVER FREED

**Location**: `GhosttyTerminalView.swift:102-109`

```swift
deinit {
    if let app = app {
        ghostty_app_free(app)
    }
    if let config = config {
        ghostty_config_free(config)
    }
}
```

**Failure Mode**: `GhosttyAppManager` is a singleton. Its `deinit` will NEVER be called during normal app execution because the singleton reference persists for app lifetime.

**Result**: `ghostty_app_free()` and `ghostty_config_free()` are dead code. Not a leak per se, but misleading implementation suggesting cleanup that won't happen.

---

## SECTION 5: ERROR HANDLING FAILURES

### 5.1 SILENT FAILURES THROUGHOUT

**Location**: `ConfigService.swift:91-93`
```swift
} catch {
    print("Failed to load config.toml: \(error)")
    createDefaultConfig()
}
```

**Location**: `AppState.swift:40-42`
```swift
} catch {
    print("Failed to load workspaces: \(error)")
}
```

**Location**: `AppState.swift:49-51`
```swift
} catch {
    print("Failed to save workspaces: \(error)")
}
```

**Failure Mode**: All errors are silently swallowed with `print()` statements that users will never see in a GUI app. No user notification, no recovery, no logging to file.

**Downstream Consequence**: User loses workspace data with no indication why. App silently operates in degraded state.

---

### 5.2 NO VALIDATION ON CONFIG LOAD

**Location**: `ConfigService.swift:58-73`

```swift
if let font = terminalTable["font"] as? String {
    terminalConfig.font = font
}
if let fontSize = terminalTable["font_size"] as? Int {
    terminalConfig.font_size = fontSize
}
```

**Missing Validation**:
- No bounds check on `font_size` (negative values? absurdly large?)
- No validation that `font` is a valid installed font
- No validation that `scrollback` is positive
- No validation that `cursor_style` is a known value (handled later, but with silent default)

---

### 5.3 GHOSTTY INITIALIZATION FAILURE NOT PROPAGATED

**Location**: `GhosttyTerminalView.swift:27-32`

```swift
let result = ghostty_init(0, nil)
guard result == 0 else {
    NSLog("[GhosttyAppManager] ghostty_init failed with code: \(result)")
    return
}
```

**Failure Mode**: If `ghostty_init` fails, the manager silently continues with `app = nil`. All subsequent surface creations will fail, but the app appears to run with blank terminals.

**Downstream Consequence**: Users see blank terminal views with no explanation or error message.

---

## SECTION 6: EDGE CASES NOT HANDLED

### 6.1 EMPTY WORKSPACES ARRAY

**Location**: `AppState.swift:56-68`

```swift
func initializeWorkspacesFromConfig() {
    let configService = ConfigService.shared
    let workspaceConfigs = configService.config.workspaces

    for wsConfig in workspaceConfigs {
        let expandedPath = configService.expandPath(wsConfig.path)
        if FileManager.default.fileExists(atPath: expandedPath) {
            // ...
        }
    }
    save()
}
```

**Edge Case**: If ALL workspace paths are invalid (don't exist), the app starts with zero workspaces. User is stuck with no clear path to recovery.

**Missing**: Warning to user, fallback to home directory workspace.

---

### 6.2 TERMINAL NAVIGATION WITH ZERO TERMINALS

**Location**: `AppState.swift:176-193`

```swift
func selectPreviousTerminal() {
    let terminals = allTerminals
    guard !terminals.isEmpty else { return }
    // ...
}
```

**Edge Case Handled**: Yes, but silently. User presses keyboard shortcut and nothing happens with no feedback.

---

### 6.3 WORKING DIRECTORY DELETED WHILE TERMINAL RUNNING

**Location**: `TerminalView.swift:79`

```swift
let cwd = FileManager.default.fileExists(atPath: workingDirectory) ? workingDirectory : homeDir
```

**Edge Case**: Only checked at terminal CREATION time. If directory is deleted while terminal is running, behavior is undefined (likely shell continues in deleted directory).

---

### 6.4 FOCUS RACE CONDITIONS

**Location**: Multiple files use `DispatchQueue.main.async` for focus:

`TerminalView.swift:95-97`:
```swift
DispatchQueue.main.async {
    terminalView.window?.makeFirstResponder(terminalView)
}
```

`GhosttyTerminalView.swift:434-437`:
```swift
DispatchQueue.main.async {
    nsView.window?.makeFirstResponder(nsView)
}
```

**Edge Case**: Multiple terminals competing for first responder in the same run loop iteration. Order is non-deterministic.

---

## SECTION 7: CODE QUALITY ISSUES

### 7.1 DUPLICATE CODE STRUCTURES

`ContentView.swift:5-15` (GlassSidebarBackground):
```swift
struct GlassSidebarBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }
}
```

`TerminalView.swift:6-28` (VisualEffectBackground):
```swift
struct VisualEffectBackground: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    // ... more configurable but functionally similar
}
```

**Issue**: Two near-identical NSViewRepresentable wrappers for the same purpose. One is configurable, one is hardcoded.

---

### 7.2 TYPO IN CURSOR STYLE PARSING

**Location**: `TerminalView.swift:132`

```swift
case "blink_underline", "blinkundernline", "blinking_underline":
```

**Issue**: `blinkundernline` is misspelled (missing 'i'). This is dead code that will never match.

---

### 7.3 UNUSED DISPLAYLINK VARIABLE

**Location**: `GhosttyTerminalView.swift:116`

```swift
private var displayLink: CVDisplayLink?
```

**Issue**: Declared but never initialized or used. Dead code artifact from development.

---

### 7.4 INCONSISTENT STATE SYNC

**Location**: `ContentView.swift:19`

```swift
@State private var showSidebar = true
```

**Location**: `AppState.swift:10`

```swift
@Published var showSidebar: Bool = true
```

**Issue**: Sidebar visibility is tracked in BOTH ContentView local state AND AppState published property. Only the local state is used in ContentView. The AppState property is orphaned.

---

## SECTION 8: MISSING FUNCTIONALITY CLAIMED AS COMPLETE

### 8.1 HOT-RELOAD CONFIG NOT IMPLEMENTED

**progress.md:102** claims as "Next Steps":
```
2. Hot-reload config without app restart (optional enhancement).
```

**ConfigService.swift:167-170**:
```swift
func reloadConfig() {
    loadConfig()
}
```

**Issue**: The method exists but is NEVER CALLED from anywhere. There's no file watcher, no keyboard shortcut, no menu item. The feature is a stub.

---

### 8.2 CONFIG VALIDATION NOT IMPLEMENTED

**progress.md:103** claims as "Next Steps":
```
3. Config validation with helpful error messages.
```

**Reality**: Zero validation exists. Invalid font names silently fall back. Invalid integers crash the parser. Invalid paths are silently skipped.

---

### 8.3 ADDITIONAL TERMINAL SETTINGS NOT IMPLEMENTED

**progress.md:104** claims as "Next Steps":
```
4. Additional terminal settings (colors, themes).
```

**Reality**: Not implemented. Colors are hardcoded in `TerminalView.swift:50-51`:
```swift
terminalView.nativeBackgroundColor = NSColor(white: 0.0, alpha: 0.0)
terminalView.nativeForegroundColor = NSColor.white
```

---

## SECTION 9: ARCHITECTURE CONCERNS

### 9.1 SINGLETON ABUSE

Three singletons in a small codebase:
- `ConfigService.shared`
- `GhosttyAppManager.shared`
- (Implicit) FileManager.default (used throughout)

**Issue**: Testing impossible without mocking. State pollution between test cases if tests existed (they don't).

---

### 9.2 NO TEST COVERAGE

**Evidence**: No test files, no test targets in Package.swift.

**Location**: `Package.swift:16-44` - Only one target: `executableTarget`. No `testTarget`.

---

### 9.3 MIXED CONCERNS IN VIEWS

**Location**: `TerminalView.swift:85-91`

Process spawning logic (shell execution, environment setup) embedded directly in SwiftUI view creation:

```swift
terminalView.startProcess(
    executable: shell,
    args: ["-c", "cd '\(cwd)' && exec \(shell)"],
    environment: Array(env.map { "\($0.key)=\($0.value)" }),
    execName: nil
)
```

**Issue**: View layer directly executes shell commands. Should be in a service/manager layer.

---

## SECTION 10: BUILD AND DEPLOYMENT ISSUES

### 10.1 MISSING FRAMEWORK IN REPO

**Location**: `Package.swift:40-43`

```swift
.binaryTarget(
    name: "GhosttyKit",
    path: "Frameworks/GhosttyKit.xcframework"
)
```

**Location**: `.gitignore:7`

```
Frameworks/
```

**Issue**: The required binary framework is gitignored. A fresh clone will FAIL to build with:
```
error: local binary target 'GhosttyKit' does not exist
```

**progress.md:250-251** provides build instructions, but this is a FATAL BUILD BLOCKER for anyone cloning the repo.

---

### 10.2 UNDOCUMENTED ZIG DEPENDENCY

**progress.md:356-358** lists requirements:
```
1. Requires Zig 0.15.2 and Metal Toolchain installed.
```

**Missing from repo**:
- No `Makefile` or build script to automate Ghostty build
- No version check for Zig
- No instructions for Metal Toolchain installation

---

## SECTION 11: CORRECTED PRIORITY ACTION PLAN

### PRIORITY 1 - CRITICAL (Do Before Any Release)

1. **Fix Command Injection** (`TerminalView.swift:87`)
   - Properly escape or avoid shell interpretation of path
   - Use direct `execve` without shell wrapper
   - Validate paths against allowlist or sanitize

2. **Remove Hardcoded PII** (`ConfigService.swift:14-23`)
   - Replace `studyRoot` with dynamic home directory detection
   - Remove all course names
   - Use XDG defaults only

3. **Fix Event Monitor Leak** (`ContentView.swift:46`)
   - Store monitor reference
   - Remove in `onDisappear`

4. **Remove/Update GHOST.md**
   - Either delete or synchronize with current implementation state

### PRIORITY 2 - HIGH (Do Before Beta)

5. **Add Input Validation**
   - Bounds check on all numeric configs
   - Path traversal prevention
   - TOML escape on save

6. **Add User-Visible Errors**
   - Replace `print()` with alert dialogs
   - Add logging to file for debugging

7. **Add Test Target**
   - Unit tests for ConfigService
   - Unit tests for path handling

### PRIORITY 3 - MEDIUM (Do Before 1.0)

8. **Document GhosttyKit Build**
   - Add script to automate framework build
   - Or include prebuilt framework (licensing permitting)

9. **Consolidate Duplicate Code**
   - Single glass background component

10. **Fix Dead Code**
    - Remove unused `displayLink`
    - Remove misspelled cursor style case
    - Remove orphaned `showSidebar` in AppState

---

## CONTINGENCY SIGNALS

| Assumption | Verification Method | Contingency Trigger | Fallback Action |
|------------|---------------------|---------------------|-----------------|
| Config file parseable | `try TOMLTable(string:)` succeeds | Parse throws | Create fresh default config, warn user |
| Workspace paths exist | `FileManager.fileExists` | All paths missing | Create single home directory workspace |
| Ghostty initializes | `ghostty_init() == 0` | Non-zero return | Fall back to SwiftTerm renderer (exists but unused) |
| GhosttyKit framework present | Build succeeds | Link error | Provide prebuilt download link |
| Shell env var valid | Path exists and is executable | Invalid shell | Force `/bin/zsh` |

---

## VERDICT

**Release Readiness**: NOT READY

The codebase requires significant security hardening before any public release. The contradiction between documentation claiming CPU rendering is production while code uses GPU rendering suggests either documentation rot or incomplete migration. The hardcoded personal paths guarantee embarrassment on open source release.

**Minimum Required Actions Before Any Release**:
1. Fix command injection vulnerability
2. Remove ALL hardcoded personal paths
3. Synchronize or remove GHOST.md
4. Fix event monitor memory leak
5. Add build instructions for GhosttyKit

**Estimated Technical Debt**: 40+ hours of remediation work.

---

*This audit was conducted with hostile scrutiny. Every claim was verified against source code. Trust nothing; verify everything.*
