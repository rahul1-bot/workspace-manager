# Workspace Manager (WorkspaceManager)

## Purpose
Workspace Manager is a keyboard-first macOS app for orchestrating terminal-based AI coding agents across multiple workspaces (folders). It optimizes for verification: every agent runs in a visible terminal that the user can focus, inspect, and interact with at any time.

This is not a task manager. This is a terminal orchestration surface designed for the Claude↔Codex workflow loop:
    1. Claude behaves as the fast implementer (worker).
    2. Codex behaves as the strict reviewer (verifier).
    3. The user remains the commander: switching, inspecting, and correcting.

## Core Concepts
    1. Workspace
        1. A workspace is a folder path on disk.
        2. Workspaces are the top-level navigation unit.
    2. Agent
        1. An agent is a persistent terminal slot within a workspace.
        2. An agent terminal is never “virtual”; it is always a real visible terminal surface.
        3. The user can rename agents to match intent, not implementation details.
    3. Task (Label)
        1. A task is a short label attached to an agent that answers: “What is this agent working on?”
        2. Tasks are labels, not runnable jobs.
        3. Task labels must remain minimal and human-readable (Pythonic naming, no shouting).
    4. Pairing (Claude↔Codex)
        1. A workspace can define a Worker agent and a Reviewer agent.
        2. The “handoff” interaction is UI-level, not automation-level:
            1. Focus switch to the reviewer terminal.
            2. Optional: update the reviewer task label based on the worker task label.
        3. Automation remains the responsibility of the CLI tools and their hooks (Claude Code hooks, Codex CLI workflows, etc.).

## Design Principles (Non-Negotiable)
    1. Verification-first
        1. Any action that “sends work to an agent” must be observable in a terminal.
        2. The user must be able to click/focus the terminal and watch the agent live.
        3. The app must not run hidden background work that cannot be inspected.
    2. Low clutter
        1. The UI should show intent (agent + task), not plumbing (exec/args/cwd) by default.
        2. Deep hierarchies and “sub-workspaces” are avoided in v1.
    3. Keyboard-first
        1. Two-layer navigation is the mental model:
            1. Switch workspaces.
            2. Switch agents within the active workspace.
    4. Config-first
        1. The configuration file is the single source of truth for structure and preferences.
        2. UI edits must persist back to config to avoid drift.
        3. Auto-spawn vs lazy-spawn is controlled by config.

## v1 Scope (Dead Simple)
### Must Have
    1. Workspaces
        1. Add, remove, rename workspaces (rename is display name, not folder name).
        2. Stable workspace ids persisted in config.
    2. Agents (within a workspace)
        1. Create and remove agents manually by default (lazy spawn).
        2. Rename agents.
        3. Optional config flag per agent: autospawn = true/false.
    3. Task labels
        1. Each agent has a task label (string).
        2. User can edit the task label quickly via keyboard.
        3. Task label persistence is controlled by config (default: persist).
    4. Claude↔Codex pairing
        1. Pairing is defined per workspace (worker_agent_id, reviewer_agent_id).
        2. Keybinds support instant switching between worker and reviewer.
        3. “Handoff” is defined as a focus switch (with optional label copy).
    5. Keymaps
        1. Workspace switching keymaps.
        2. Agent switching keymaps within workspace.
        3. Worker/Reviewer jump and handoff keymaps.

### Explicit Non-Goals (v1)
    1. No kanban boards, “in-progress/completed” columns, or completion workflows.
    2. No runnable task/job engine in config (tasks are labels only).
    3. No automation framework competing with CLI tools.
    4. No nested workspaces / recursive trees.

## Keymaps (Proposed Defaults)
The intent is “Pythonic”: quiet, consistent, and minimal.

### Workspace navigation (global within the app)
    1. Cmd+Shift+I: previous workspace
    2. Cmd+Shift+K: next workspace
    3. Cmd+P: command palette (search workspaces, agents)

### Agent navigation (within active workspace)
    1. Cmd+I: previous agent
    2. Cmd+K: next agent
    3. Cmd+L: focus terminal
    4. Cmd+J: focus roster/sidebar (if visible)

### Claude↔Codex pairing
    1. Cmd+[: jump to worker agent
    2. Cmd+]: jump to reviewer agent
    3. Cmd+Shift+]: handoff (focus reviewer; optional label update)

### Task label editing
    1. Cmd+;: set task label for current agent
    2. Cmd+Shift+;: clear task label

### Focus Mode (anti-clutter)
    1. Cmd+.: toggle Focus Mode
        1. Focus Mode shows only the current terminal with a minimal overlay/palette for switching.
        2. Squad Mode shows the full roster.

## Configuration (TOML) – Proposed v1 Schema
This is the target structure. The app should treat config.toml as authoritative and persist UI changes back into it.

```toml
[appearance]
show_sidebar = true
focus_mode = false
persist_task_labels = true

[terminal]
use_gpu_renderer = true

[[workspaces]]
id = "550e8400-e29b-41d4-a716-446655440000"
name = "AI-2-Project"
path = "~/code/ai2"

# Optional: pairing for Claude↔Codex loop
worker_agent_id = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"
reviewer_agent_id = "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"

  [[workspaces.agents]]
  id = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"
  name = "claude-worker"
  role = "worker"
  task = "training pipeline"
  autospawn = false

  [[workspaces.agents]]
  id = "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"
  name = "codex-review"
  role = "reviewer"
  task = "review: training pipeline"
  autospawn = false
```

## UX Rules (To Prevent Clutter)
    1. Default header content for a terminal should be:
        1. agent name
        2. task label
    2. Implementation details (exec/args/cwd) must be hidden by default and only accessible via an explicit “details” action.
    3. If an action changes focus, it must feel instantaneous.

## Feature Ideas (v2+)
These are intentionally deferred until v1 is stable.

| Feature | Description |
|---------|-------------|
| Agent grouping | Group agents under tags like paper/slides/training without creating nested workspaces. |
| Config hot reload | Reload config.toml and preserve selection using stable ids. |
| Lightweight history | Track task label changes per agent with timestamps (for audit, not for task management). |
| External tool integration | Optional helpers to copy/paste review prompts, without executing hidden jobs. |

## Naming Notes
    1. Working name remains Workspace Manager / WorkspaceManager.
    2. Naming can be revisited after v1 scope lands and the product identity is validated.

