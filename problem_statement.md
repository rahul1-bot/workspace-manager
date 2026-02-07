# Problem Statement: Efficient Git Worktree Orchestration for Workspace Manager

## 1. Mission
Design an efficient, reliable Git worktree orchestration flow for users described in `README.md`: research engineers running multiple parallel branches/experiments who need fast context switching and long diff-reading workflows without cognitive fragmentation.

## 2. Core Product Question
How do we provide worktree creation, switching, and comparison in a way that is:
- as fast as native terminal commands for critical actions,
- structurally consistent with the app UX,
- and resistant to state drift across long-lived sessions and multiple collaborators?

## 3. Current Evidence (Observed State)
From current runtime observations and screenshots:
- Worktree create had recurring stuck-spinner behavior in previous iterations.
- Sidebar has shown workspace pollution, where many `wt ...` entries appear in primary `WORKSPACES` list.
- Graph view can become cluttered with auto-generated worktree nodes, reducing readability.
- Worktree metadata has shown legacy drift (`isAutoManaged` not always correct for old entries), causing filtering inconsistencies.
- Branch metadata for workspace repositories is computed but not consistently surfaced inline where terminal selection happens.
- PDF viewing exists, but there is no explicit always-visible action button in the terminal action bar, which slows research-paper workflow.
- Documents-button behavior drifted: trigger path always reopened Finder instead of acting as a panel toggle, even when PDF tabs already existed.

## 4. Why This Matters
The value of this feature is operational speed under complexity:
- If create is slower than terminal, users abandon UI.
- If worktree nodes flood primary navigation, cognitive load increases and the feature backfires.
- If state classification is unstable, users lose trust in orchestration.

## 5. Constraints and Non-Negotiables
- We do not edit code in `main` or `dev`.
- Active branch for this track: `ghost/worktree-orchestration-foundation`.
- We can read Lyra's branch/worktree for reference, but we do not copy implementation blindly.
- We apply independent reasoning and only adopt ideas that fit this codebase architecture.
- Changes must be validated with focused tests and full-suite sanity checks.
- Documentation should be lean and decision-oriented (agile workflow), not bloated.

## 6. Reference Inputs
### 6.1 Our Branch (Ghost)
- Current approach uses dedicated worktree models/services and a worktree section in sidebar.
- Includes auto destination policy under `.wt/<repo>/<branch-slug>`.
- Includes create flow, compare flow, and keyboard/palette integration.
- Recently hardened for timeout-safe git execution and reduced create critical-path latency.

### 6.2 Lyra Branch (Reference Only)
Path: `/Users/rahulsawhney/Library/CloudStorage/OneDrive-Personal/Documents/StudyDocuments/Rahul/code/ideas/TUI/workspace-manager-rahul-lyra/`

Relevant history:
- `b84b41b` docs: design and task plan
- `5f179b3` Phase 1 foundation
- `39720d4` cross-worktree diff target chip
- `fb46e40` create sheet, palette, shortcuts

Notable reference characteristics:
- Treats worktree metadata as an overlay on existing workspaces.
- Uses explicit create sheet state machine and task cancellation around create flow.
- Shows branch metadata inline with terminals rather than multiplying top-level workspace entities.

## 7. Diagnosed Problem Classes
1. Create-path reliability and latency
- Critical path became too heavy when full metadata rebuilds happened before returning control.
- Hidden async boundaries caused UI loading state ambiguity.

2. Classification drift for auto-managed entries
- Legacy entries may exist without correct `isAutoManaged=true`, causing incorrect visibility behavior.

3. Information architecture mismatch
- Worktree entities should not dominate primary workspace navigation.
- Dedicated worktree section should carry worktree topology; primary workspace tree should remain stable and human-curated.

4. Missing branch context in primary terminal list
- Operators need terminal rows to show repository branch context in-place.
- Desired syntax in sidebar rows: `<terminal-name> <branch-name>` (with dirty indicator when present).

5. Missing explicit documents action in top bar
- Paper-reading workflow requires a direct action in the terminal action bar, not only shortcut/palette discovery.

## 8. Design Principles Going Forward
1. Fast-path first
- Create operation should complete near terminal speed, with expensive refreshes deferred.

2. Deterministic state ownership
- Worktree-state metadata is source of truth for orchestration metadata.
- Heuristics may be used as migration safety-net when legacy metadata is incomplete.

3. Separation of concerns in UI
- Primary `WORKSPACES`: manual/stable navigation.
- `WORKTREES (CURRENT REPO)`: dynamic git topology and orchestration actions.

4. Pragmatic test strategy (agile)
- Add targeted regression tests for every bug class fixed.
- Keep tests high-value and scenario-driven; avoid speculative test expansion.

5. Intent-separated document controls
- `Documents` button and `⇧⌘P` should be panel visibility toggles only.
- Opening new files should be explicit (`command palette: Open PDF` or dedicated open-file shortcut), not a side effect of toggle.

## 9. Current Execution Plan (Incremental)
1. Stabilize create path
- Keep create flow completion-bound and timeout-safe.
- Avoid whole-catalog rebuilds on the critical path.

2. Resolve sidebar pollution
- Hide auto-managed/legacy-worktree entries from primary workspace tree.
- Preserve selected context visibility to avoid abrupt disappearance.

3. Reconcile legacy metadata gradually
- Preserve/repair `isAutoManaged` during sync updates.
- Use safe heuristics (`wt` naming and `.wt/` path) where metadata is missing.

4. Re-evaluate graph policy
- Decide whether auto-managed worktree nodes should be hidden or grouped in graph mode for readability.

5. Surface branch context where terminal selection occurs
- Render workspace branch metadata inline for terminal rows and active terminal header.
- Keep lookup asynchronous and non-blocking using lightweight git metadata probes.

6. Add explicit documents quick action
- Add a visible `Documents` action pill in the workspace action bar.
- Route action to panel toggle flow (show/hide existing tabs) without forcing file picker reopen.
- Keep open-file flow separate and explicit via command palette and shortcut mapping.

## 10. Acceptance Criteria
- Create worktree no longer stalls in normal conditions.
- Primary sidebar does not bloat with `wt ...` entries during branch/worktree switching.
- Worktree actions remain available in dedicated section.
- Terminal rows show `<terminal-name> <branch-name>` context for git-backed workspace paths.
- Action bar shows a visible `Documents` button that toggles panel visibility.
- If PDFs are already loaded, reopening the panel does not reopen Finder.
- Keymaps remain explicit and stable: `⇧⌘P` toggles Documents panel, `⇧⌘O` opens PDF file picker.
- Regression tests cover create-path completion behavior and sidebar filtering behavior.
- Full test suite remains green.

## 11. Working Agreement
- Ghost should not wait for spoon-fed micro-steps; apply independent technical judgment.
- Rahul provides strategic direction; Ghost provides execution decisions and validation.
- Every iteration logs assumptions, decisions, and outcomes in ledgers.
