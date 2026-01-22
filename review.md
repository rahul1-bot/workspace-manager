# Workspace Manager - review.md

| Review | workspace-manager dev branch audit | Date: 22 January 2026 | Time: 09:05 AM | Name: Ghost |

## Scope and Snapshot
    1. Scope root: /Users/rahulsawhney/Library/CloudStorage/OneDrive-Personal/Documents/StudyDocuments/Rahul/code/ideas/TUI/workspace-manager
    2. Snapshot command: snap .
    3. Snapshot output:
        1. Snapshot time: 22 January 2026, 09:05 AM
        2. Snapshot path: logs/2026-01-22/workspace-manager_09_05_AM
    4. Branch under review: dev
    5. HEAD commit under review: 8eaf373

## Verdict (Harsh Truth)
    1. The config pipeline is now materially hardened:
        1. Workspace IDs are validated as UUIDs and duplicates are auto-regenerated (ConfigService).
        2. String escaping prevents easy TOML corruption (ConfigService).
        3. New workspace creation errors are visible and no longer silently dismissed (WorkspaceSidebar).
    2. The current biggest risk is self-inflicted:
        1. Cmd+R hot reload likely destroys running terminal sessions because reloadFromConfig rebuilds workspaces and drops runtime terminals.
        2. This is unacceptable for “persistent agents until user says done”.
    3. Momentum/velocity tuning is treated as final for now:
        1. Timer-based momentum with high velocityThreshold is locked (no further changes requested).

## Verification Strike
### Commands Executed
    1. Git state:
        1. git rev-parse --abbrev-ref HEAD
        2. git log --oneline --decorate -n 8
    2. Build verification:
        1. swift build
        2. swift build -c release
        3. scripts/build_app_bundle.sh
    3. Test verification:
        1. swift test

### Observed Results
    1. swift build succeeded with existing libghostty-fat.a symbol warnings (ImGui-related).
    2. swift build -c release succeeded.
    3. scripts/build_app_bundle.sh succeeded.
    4. swift test failed with: “error: no tests found; create a target in the 'Tests' directory”.

## Ledger Cross-Check (Claims vs Code)
    1. Claim: “Workspace ID validation strengthened and duplicate IDs are handled.”
        1. Source: progress.md, “Final Review Fixes and Features”, Date: 22 January 2026, Time: 06:02 AM.
        2. Evidence:
            1. Sources/WorkspaceManager/Services/ConfigService.swift:97-121 validates UUID ids and regenerates duplicates.
            2. Sources/WorkspaceManager/Services/ConfigService.swift:239-243 rejects duplicate ids during insertion.
        3. Verdict: True.
    2. Claim: “Workspace creation error feedback implemented.”
        1. Source: progress.md, “Final Review Fixes and Features”, Date: 22 January 2026, Time: 06:02 AM.
        2. Evidence:
            1. Sources/WorkspaceManager/Views/WorkspaceSidebar.swift:72-102 keeps the sheet open and sets error message.
            2. Sources/WorkspaceManager/Views/WorkspaceSidebar.swift:252-256 renders the error message.
        3. Verdict: True.
    3. Claim: “Hot reload config.toml (Cmd+R).”
        1. Source: progress.md, “Final Review Fixes and Features”, Date: 22 January 2026, Time: 06:02 AM.
        2. Evidence:
            1. Sources/WorkspaceManager/ContentView.swift:101-106 dispatches Cmd+R to AppState.reloadFromConfig.
        3. Verdict: True, but dangerously incomplete (see Findings).

## Findings (Hostile Audit)
### High Severity
    1. Cmd+R hot reload is destructive to running terminals.
        1. Triggering condition:
            1. User presses Cmd+R while any terminal sessions are running.
        2. Failure mode:
            1. reloadFromConfig calls loadWorkspacesFromConfig, which clears workspaces and reconstructs them from config without preserving runtime terminals.
        3. Downstream consequence:
            1. Terminals (agents) are destroyed, processes can die, and verification context is lost.
        4. Evidence:
            1. Sources/WorkspaceManager/ContentView.swift:101-106 triggers reload.
            2. Sources/WorkspaceManager/Models/AppState.swift:35-51 rebuilds workspaces from config.
            3. Sources/WorkspaceManager/Models/AppState.swift:22-32 creates Workspace instances without terminals.
        5. Required correction:
            1. Either:
                1. Remove or guard Cmd+R until terminals can be preserved, or
                2. Implement merge-style reload keyed by workspace id to preserve existing terminals per workspace.
    2. Terminal switching is not aligned with the v1 product model.
        1. Triggering condition:
            1. Using Cmd+I/Cmd+K navigation today.
        2. Failure mode:
            1. Cmd+I/Cmd+K cycles a flat list of terminals across all workspaces, not within the selected workspace.
        3. Downstream consequence:
            1. This breaks the intended two-layer navigation model required for Workspaces/Agents/Tasks orchestration.
        4. Evidence:
            1. Sources/WorkspaceManager/ContentView.swift:76-86 binds Cmd+I/Cmd+K.
            2. Sources/WorkspaceManager/Models/AppState.swift:173-214 cycles across allTerminals (all workspaces).
        5. Required correction:
            1. Introduce explicit workspace switching keymaps and restrict agent navigation to the active workspace.

### Medium Severity
    1. Clipboard write safety still relies on upstream null-termination guarantees.
        1. Triggering condition:
            1. libghostty provides clipboard content that is not safe to scan for a null terminator.
        2. Failure mode:
            1. Code scans memory until a null terminator with a 10MB cap.
        3. Downstream consequence:
            1. Potential crash during clipboard operations if upstream contract differs.
        4. Evidence:
            1. Sources/WorkspaceManager/Views/GhosttyTerminalView.swift:71-97.
        5. Required correction:
            1. Confirm and document the upstream contract for clipboard content, or reduce handling to known-safe text paths.

### Low Severity
    1. Supply chain remains non-reproducible in git.
        1. Evidence:
            1. Package.swift:40-43 depends on Frameworks/GhosttyKit.xcframework.
            2. .gitignore:7 ignores Frameworks/.
        2. Consequence:
            1. Clean clones cannot build without side-loading GhosttyKit.xcframework.
    2. No test target exists.
        1. Evidence:
            1. swift test reports “no tests found”.

## Feature Candidates (Optional)
| Feature | Workspaces Agents Tasks (Labels) | Date: 22 January 2026 | Time: 09:05 AM | Name: Ghost |
    1. Add a first-class Agent model (rename Terminal to Agent) and attach a Task label string.
    2. Persist agent names and task labels in config.toml without executing jobs.
    3. Keep the primary UI surface minimal: agent name + task label only.

| Feature | Claude Codex Pairing (UI-level) | Date: 22 January 2026 | Time: 09:05 AM | Name: Ghost |
    1. Allow a workspace to define worker_agent_id and reviewer_agent_id.
    2. Keymaps:
        1. Jump to worker agent.
        2. Jump to reviewer agent.
        3. Handoff: focus reviewer and optionally copy/derive label.
