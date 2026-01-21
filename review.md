# Workspace Manager - review.md

| Review | workspace-manager dev branch audit | Date: 21 January 2026 | Time: 09:38 PM | Name: Ghost |

## Scope and Snapshot
    1. Scope root: /Users/rahulsawhney/Library/CloudStorage/OneDrive-Personal/Documents/StudyDocuments/Rahul/code/ideas/TUI/workspace-manager
    2. Snapshot command: snap .
    3. Snapshot output:
        1. Snapshot time: 21 January 2026, 09:38 PM
        2. Snapshot path: logs/2026-01-21/workspace-manager_09_38_PM
    4. Branch under review: dev
    5. HEAD commits under review:
        1. b18c503 refactor: make config.toml the single source of truth
        2. 9458c29 fix critical bugs from code review audit

## Verdict (Harsh Truth)
    1. The codebase is materially safer and cleaner than the prior audit.
    2. The architecture is still internally inconsistent in two places that matter:
        1. appearance.show_sidebar exists in config but is not persisted back to config when the user toggles the sidebar.
        2. terminal settings in ~/.config/workspace-manager/config.toml do not actually drive the libghostty renderer path; they only affect the SwiftTerm fallback.
    3. Workspaces are now config-driven, but identity and mutation semantics are weak:
        1. Workspace IDs are regenerated each load, breaking selection preservation and making reload logic misleading.
        2. Workspace name is effectively the primary key, but duplicates are not prevented and deletes are ambiguous.
    4. Config writing is fragile:
        1. TOML is constructed via string interpolation without escaping; one quote in a workspace name can corrupt the entire config file.
    5. Supply chain remains brittle:
        1. Package.swift depends on Frameworks/GhosttyKit.xcframework, but Frameworks/ is ignored by git, so clean clones cannot build without manual steps.

## Verification Strike
### Commands Executed
    1. Git state:
        1. git rev-parse --abbrev-ref HEAD
        2. git log --oneline --decorate -n 20
    2. Build verification:
        1. swift build
        2. swift build -c release
        3. scripts/build_app_bundle.sh
    3. Test verification:
        1. swift test

### Observed Results
    1. swift build succeeded.
    2. swift build -c release succeeded.
    3. scripts/build_app_bundle.sh succeeded.
    4. swift test failed with: “error: no tests found; create a target in the 'Tests' directory”.
    5. SwiftTerm checkout warning persists: unhandled README.md resource (SPM warning).

## Ledger Cross-Check (Claims vs Code)
    1. Claim: “config.toml is the ONLY source of truth for workspaces.”
        1. Source: progress.md, “Config-Driven Architecture Refactor”, Date: 21 January 2026, Time: 09:34 PM.
        2. Evidence: Sources/WorkspaceManager/Models/AppState.swift:20-31 loads workspaces from ConfigService.config only.
        3. Counter-evidence: none observed for workspaces.
        4. Verdict: True for workspaces.
    2. Claim: “All settings in ~/.config/workspace-manager/config.toml.”
        1. Source: LYRA.md, “Current Status”, Date: 21 January 2026, Time: 09:23 PM.
        2. Evidence: Sources/WorkspaceManager/Models/AppState.swift:16 uses appearance.show_sidebar as initial value.
        3. Counter-evidence: Sources/WorkspaceManager/ContentView.swift:61-66 toggles showSidebar without persisting to config (ConfigService.saveConfig writes config.appearance.show_sidebar at Sources/WorkspaceManager/Services/ConfigService.swift:132-174).
        4. Verdict: False as stated. appearance.show_sidebar is read-once at startup, not configuration-managed end-to-end.
    3. Claim: “Terminal settings from config: font, font_size, scrollback, cursor_style.”
        1. Source: LYRA.md, “Current Status”, Date: 21 January 2026, Time: 09:23 PM.
        2. Evidence: Sources/WorkspaceManager/Views/TerminalView.swift:44-73 applies these settings for SwiftTerm.
        3. Counter-evidence: Sources/WorkspaceManager/Views/TerminalView.swift:147-173 routes to GhosttyTerminalView when use_gpu_renderer is true, and GhosttyAppManager loads Ghostty’s own default config files at Sources/WorkspaceManager/Views/GhosttyTerminalView.swift:43-47.
        4. Verdict: Misleading. Those settings only apply to the SwiftTerm fallback, not the default GPU path.

## Findings (Hostile Audit)
### Blocker Severity
    1. appearance.show_sidebar is not actually config-driven.
        1. Triggering condition:
            1. User toggles the sidebar (Cmd+B in ContentView, Cmd+Ctrl+S via app commands).
        2. Failure mode:
            1. UI mutates AppState.showSidebar, but ConfigService.config.appearance.show_sidebar is never updated and ConfigService.saveConfig is never called for this preference.
        3. Downstream consequence:
            1. Config claims a setting it does not control. On next launch, sidebar visibility reverts to whatever the file says, not what the user last used.
        4. Evidence:
            1. Sources/WorkspaceManager/ContentView.swift:61-66 toggles AppState.showSidebar.
            2. Sources/WorkspaceManager/WorkspaceManagerApp.swift:134-141 toggles AppState.showSidebar.
            3. Sources/WorkspaceManager/Models/AppState.swift:16 reads show_sidebar only during init.
            4. Sources/WorkspaceManager/Services/ConfigService.swift:136-148 writes show_sidebar from ConfigService.config only.
        5. Required correction:
            1. Either:
                1. Persist showSidebar changes to config (add ConfigService.setShowSidebar and call it whenever toggled), or
                2. Remove appearance.show_sidebar from config entirely and treat it as runtime-only UI state.

### High Severity
    1. Workspace identity is unstable; reload logic is misleading and selection cannot be preserved.
        1. Triggering condition:
            1. Any future use of reloadFromConfig (or any desire to preserve selection across reload/restart).
        2. Failure mode:
            1. Workspaces are re-created with fresh UUIDs each load; previousSelectedWorkspaceId can never match.
        3. Downstream consequence:
            1. Selection is always lost on reload, and any feature built on stable workspace identity will become a pile of lies.
        4. Evidence:
            1. Sources/WorkspaceManager/Models/AppState.swift:22-31 constructs Workspace(name:path) each load.
            2. Sources/WorkspaceManager/Models/AppState.swift:33-46 attempts to preserve selectedWorkspaceId by UUID.
            3. Sources/WorkspaceManager/Models/Workspace.swift:10 default id = UUID() creates new identity each time.
        5. Required correction:
            1. Store a stable workspace id in config.toml (recommended), or enforce name uniqueness and use name as the stable identifier everywhere (then delete UUID-based preservation logic).
    2. Workspace delete/update semantics are ambiguous because name is the key and duplicates are allowed.
        1. Triggering condition:
            1. Two workspaces share the same name.
        2. Failure mode:
            1. removeWorkspace(name:) deletes all matching entries; updateWorkspace(oldName:...) targets the first match only.
        3. Downstream consequence:
            1. User can delete the wrong workspace(s) and corrupt config unintentionally.
        4. Evidence:
            1. Sources/WorkspaceManager/Services/ConfigService.swift:183-199.
            2. Sources/WorkspaceManager/Models/AppState.swift:63-73 deletes by workspace.name.
        5. Required correction:
            1. Enforce unique names at insertion, or switch mutations to operate on a stable id.
    3. TOML writing is not escaped; config corruption is one input away.
        1. Triggering condition:
            1. Workspace name or path contains a double quote, backslash sequence, or newline.
        2. Failure mode:
            1. saveConfig interpolates strings directly into quoted TOML values without escaping.
        3. Downstream consequence:
            1. The config file becomes invalid; on next launch ConfigService falls back to defaults in memory, effectively “losing” the user’s setup until manually repaired.
        4. Evidence:
            1. Sources/WorkspaceManager/Services/ConfigService.swift:136-165.
        5. Required correction:
            1. Use TOMLKit to serialize strings safely, or implement correct TOML escaping for string fields before writing.
    4. terminal settings in config.toml do not drive libghostty behavior.
        1. Triggering condition:
            1. terminal.use_gpu_renderer = true (default).
        2. Failure mode:
            1. TerminalContainer routes to GhosttyTerminalView; GhosttyAppManager loads Ghostty’s default config files, not workspace-manager’s terminal config.
        3. Downstream consequence:
            1. The config is lying to the user: changes to font_size, cursor_style, scrollback may appear to do nothing when GPU renderer is enabled.
        4. Evidence:
            1. Sources/WorkspaceManager/Views/TerminalView.swift:147-173.
            2. Sources/WorkspaceManager/Views/GhosttyTerminalView.swift:43-47.
        5. Required correction:
            1. Either:
                1. Map workspace-manager terminal settings into ghostty_config_t programmatically (preferred), or
                2. Remove those fields when use_gpu_renderer is true and document that Ghostty is configured via ~/.config/ghostty/config.

### Medium Severity
    1. Clipboard “safety” fix still relies on assumptions that are not guaranteed by the C API contract.
        1. Triggering condition:
            1. libghostty provides clipboard content that is not null-terminated, or points to a buffer not safely readable until a terminator.
        2. Failure mode:
            1. Code scans for a null terminator up to a 10MB limit; if memory is not readable, it can still crash before reaching the limit.
        3. Downstream consequence:
            1. Intermittent crashes during clipboard writes depending on libghostty behavior.
        4. Evidence:
            1. Sources/WorkspaceManager/Views/GhosttyTerminalView.swift:71-97.
            2. Frameworks/GhosttyKit.xcframework/macos-arm64/Headers/ghostty.h:48-51 defines ghostty_clipboard_content_s without a length field.
        5. Required correction:
            1. Confirm (by documentation or upstream code) that content.data is always a valid null-terminated C string for text, or adjust the integration to only accept formats with explicit termination guarantees.
    2. Config reload does not refresh appearance.show_sidebar.
        1. Triggering condition:
            1. Calling AppState.reloadFromConfig in the future (or adding hot reload).
        2. Failure mode:
            1. reloadFromConfig reloads ConfigService and workspaces but does not re-sync showSidebar from config.appearance.show_sidebar.
        3. Downstream consequence:
            1. Reloaded config changes do not apply consistently, creating non-deterministic UI state.
        4. Evidence:
            1. Sources/WorkspaceManager/Models/AppState.swift:33-46 does not touch showSidebar.
        5. Required correction:
            1. Update showSidebar from config after reload, or delete reloadFromConfig until stable identity is solved.
    3. ConfigService.expandPath expands any string starting with "~", including "~foo" which is not a valid home expansion.
        1. Triggering condition:
            1. User types a malformed path beginning with "~" but not "~/", such as "~Documents".
        2. Failure mode:
            1. expandPath replaces the first character only, producing an invalid path.
        3. Evidence:
            1. Sources/WorkspaceManager/Services/ConfigService.swift:30-36.
        4. Required correction:
            1. Expand only "~" or "~/", and reject other "~*" patterns explicitly.

### Low Severity
    1. GHOST.md is materially out of date for dev branch behavior.
        1. Evidence:
            1. GHOST.md claims CPU renderer is primary and metal work is isolated to another branch, but dev defaults to libghostty and includes config use_gpu_renderer toggles.
        2. Consequence:
            1. Ledger drift increases coordination errors.
    2. Swift test target still does not exist.
        1. Evidence:
            1. swift test reports “no tests found”.
        2. Consequence:
            1. Regressions will be caught by eyeballs only.
    3. Binary dependency is still non-reproducible in git.
        1. Evidence:
            1. Package.swift:40-43 depends on Frameworks/GhosttyKit.xcframework.
            2. .gitignore:7 ignores Frameworks/.
        2. Consequence:
            1. Clean clones cannot build without side-loading the binary.

## Corrected Plan (Priority Order)
    1. Fix the config contract breach for appearance.show_sidebar.
        1. Decision required: persist it to config or remove it from config.
    2. Fix workspace identity and mutation semantics.
        1. Recommended: add a stable id field to each [[workspaces]] entry and use it for add/remove/update.
    3. Make config writing safe.
        1. Stop manual string interpolation without escaping for TOML.
    4. Decide what “terminal config” means with Ghostty enabled.
        1. Either map these settings into ghostty_config_t or explicitly declare Ghostty as externally configured.

## Open Questions (No Guessing)
    1. Should appearance.show_sidebar be:
        1. A persisted preference in config.toml, or
        2. Runtime-only UI state?
    2. Are workspace names required to be unique?
    3. Do you want stable workspace identity across restarts (id in config), or is “names as identity” acceptable?
    4. For GPU renderer mode, should workspace-manager own the terminal appearance settings, or should Ghostty remain configured via ~/.config/ghostty/config?
