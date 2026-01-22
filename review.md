# Workspace Manager - review.md

| Review | workspace-manager dev branch audit | Date: 22 January 2026 | Time: 04:14 AM | Name: Ghost |

## Scope and Snapshot
    1. Scope root: /Users/rahulsawhney/Library/CloudStorage/OneDrive-Personal/Documents/StudyDocuments/Rahul/code/ideas/TUI/workspace-manager
    2. Snapshot command: snap .
    3. Snapshot output:
        1. Snapshot time: 22 January 2026, 04:14 AM
        2. Snapshot path: logs/2026-01-22/workspace-manager_04_14_AM
    4. Branch under review: dev
    5. HEAD commits under review:
        1. 17ea0a7 fix config contract issues from follow-up review
        2. b18c503 refactor: make config.toml the single source of truth
        3. 9458c29 fix critical bugs from code review audit

## Verdict (Harsh Truth)
    1. Lyra’s follow-up claims are mostly accurate this time.
    2. The previously reported config contract breaches are fixed:
        1. appearance.show_sidebar now persists to config via AppState.toggleSidebar and ConfigService.setShowSidebar.
        2. Workspaces now have stable ids stored in config.toml and used to construct Workspace ids.
        3. TOML writing now escapes strings and will not instantly corrupt on quotes/newlines.
        4. expandPath no longer expands invalid "~foo" patterns.
        5. reloadFromConfig now re-syncs showSidebar.
    3. Remaining risks are narrower and mostly edge-case-driven:
        1. Workspace id validation is still weak (non-UUID ids silently degrade stability).
        2. Duplicate ids in config are not detected (manual edits can break remove/update semantics).
        3. Clipboard write safety still relies on undocumented upstream guarantees about null termination.
        4. Supply chain is still brittle for clean clones (GhosttyKit is a local binary dependency ignored by git).

## Verification Strike
### Commands Executed
    1. Git state:
        1. git rev-parse --abbrev-ref HEAD
        2. git log --oneline --decorate -n 10
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

## Ledger Cross-Check (Claims vs Code)
    1. Claim: “show_sidebar now saves to config.toml on every toggle.”
        1. Source: progress.md, “Follow-up Review Fixes”, Date: 21 January 2026, Time: 09:56 PM.
        2. Evidence:
            1. Sources/WorkspaceManager/Models/AppState.swift:100-108 persists showSidebar via ConfigService.setShowSidebar.
            2. Sources/WorkspaceManager/Services/ConfigService.swift:239-242 writes show_sidebar and saves config.
            3. Sources/WorkspaceManager/ContentView.swift:61-66 routes Cmd+B to AppState.toggleSidebar.
            4. Sources/WorkspaceManager/WorkspaceManagerApp.swift:134-141 routes menu shortcut to AppState.toggleSidebar.
        3. Verdict: True.
    2. Claim: “Workspace IDs are stable and stored in config.toml.”
        1. Source: progress.md, “Follow-up Review Fixes”, Date: 21 January 2026, Time: 09:56 PM.
        2. Evidence:
            1. Sources/WorkspaceManager/Models/Config.swift:52-61 adds WorkspaceConfig.id and defaults to UUID().uuidString.
            2. Sources/WorkspaceManager/Services/ConfigService.swift:94-112 generates missing ids and persists them by calling saveConfig.
            3. Sources/WorkspaceManager/Models/AppState.swift:26-32 constructs Workspace(id: stableId, ...) using UUID(uuidString:).
        3. Verdict: True, with one caveat: invalid id strings still degrade stability (see Findings).
    3. Claim: “TOML corruption from quotes is fixed.”
        1. Source: progress.md, “Follow-up Review Fixes”, Date: 21 January 2026, Time: 09:56 PM.
        2. Evidence:
            1. Sources/WorkspaceManager/Services/ConfigService.swift:197-205 escapes backslashes, quotes, and control characters.
            2. Sources/WorkspaceManager/Services/ConfigService.swift:156-185 uses escapeTomlString for all string fields written.
        3. Verdict: True for the covered escape set.

## Findings (Hostile Audit)
### High Severity
    1. Workspace id validation is inconsistent (String in config, UUID in model).
        1. Triggering condition:
            1. User manually edits config.toml and sets [[workspaces]].id to a non-UUID string.
        2. Failure mode:
            1. ConfigService accepts any non-empty id string without validation.
            2. AppState tries UUID(uuidString:) and silently falls back to a fresh UUID when parsing fails.
        3. Downstream consequence:
            1. Workspace identity becomes unstable again; remove/update by id will no longer match what AppState generated.
        4. Evidence:
            1. Sources/WorkspaceManager/Services/ConfigService.swift:95-102 accepts any non-empty id.
            2. Sources/WorkspaceManager/Models/AppState.swift:28-31 falls back to UUID() on parse failure.
        5. Required correction:
            1. Validate ids are UUIDs on load and either:
                1. Fail fast with a clear error, or
                2. Auto-rewrite invalid ids to a new UUID and persist immediately.
    2. Duplicate workspace ids are not detected.
        1. Triggering condition:
            1. Two [[workspaces]] entries share the same id (manual edit or merge conflict).
        2. Failure mode:
            1. removeWorkspace(id:) and updateWorkspace(id:) operate by id and will affect multiple entries or the wrong entry.
        3. Downstream consequence:
            1. Config mutations become destructive and non-deterministic.
        4. Evidence:
            1. Sources/WorkspaceManager/Services/ConfigService.swift:225-235 has no duplicate-id guard.
        5. Required correction:
            1. Enforce id uniqueness at load and before mutations; refuse to proceed if duplicates exist.

### Medium Severity
    1. UI ignores addWorkspace failure, hiding errors from the user.
        1. Triggering condition:
            1. User tries to add a workspace with an empty/duplicate name.
        2. Failure mode:
            1. AppState.addWorkspace returns false, but WorkspaceSidebar closes the sheet anyway and clears input.
        3. Downstream consequence:
            1. User experiences “nothing happened” with no explanation; creates repeated attempts and config churn.
        4. Evidence:
            1. Sources/WorkspaceManager/Models/AppState.swift:55-80 returns Bool.
            2. Sources/WorkspaceManager/Views/WorkspaceSidebar.swift:69-78 ignores return value.
        5. Required correction:
            1. Keep the sheet open on failure and show an inline error label.
    2. Clipboard safety still relies on upstream C-string guarantees.
        1. Triggering condition:
            1. libghostty provides clipboard content that is not null-terminated or is not safe to scan.
        2. Failure mode:
            1. Code scans until a null terminator with a 10MB cap; this still assumes readable memory and termination.
        3. Downstream consequence:
            1. Potential crash during clipboard operations if upstream contract differs.
        4. Evidence:
            1. Sources/WorkspaceManager/Views/GhosttyTerminalView.swift:71-97.
        5. Required correction:
            1. Confirm upstream contract and lock it into the ledger; otherwise restrict handling to known-safe text forms only.

### Low Severity
    1. Supply chain remains non-reproducible in git.
        1. Evidence:
            1. Package.swift:40-43 depends on Frameworks/GhosttyKit.xcframework.
            2. .gitignore:7 ignores Frameworks/.
        2. Consequence:
            1. Clean clones cannot build without side-loading GhosttyKit.xcframework.
    2. Swift test target still does not exist.
        1. Evidence:
            1. swift test reports “no tests found”.

## Feature Candidates (Optional)
| Feature | Hot reload config.toml | Date: 22 January 2026 | Time: 04:14 AM | Name: Ghost |
    1. Add a keyboard shortcut (example: Cmd+R) to call AppState.reloadFromConfig().
    2. Preserve selected workspace and terminal where possible using stable workspace ids.
    3. Acceptance criteria:
        1. Editing config.toml and hitting Cmd+R updates the sidebar without restarting.

| Feature | Workspace error feedback | Date: 22 January 2026 | Time: 04:14 AM | Name: Ghost |
    1. Keep the “New Workspace” sheet open if addWorkspace fails.
    2. Display a short inline error message (duplicate name, empty name, invalid path).
    3. Acceptance criteria:
        1. User can correct input without losing typed values.
