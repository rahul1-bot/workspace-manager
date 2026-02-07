# Workspace Manager

A spatial workspace for research engineers who solve complex problems across code, papers, and experiments. Built from the ground up on Apple Silicon.

## The Problem

Research engineers — people working on AI papers, running ML experiments across multiple git worktrees, implementing cutting-edge architectures — face a bottleneck that no terminal emulator solves: **cognitive fragmentation from constant context-switching**.

The daily reality:
- 6 terminals across 3 git worktrees, each on a different experiment branch. `git worktree list`, `cd` between directories, mentally track which branch is where.
- A research paper open in Preview that you're implementing in PyTorch. Alt-Tab to read an equation, Alt-Tab back to code, hold the math in working memory across the switch.
- Diffs scattered across `git diff` output and GitHub PRs. No structured view of what changed and why.
- Everything is cluttered. The more complex the problem, the more tools fight each other for your attention.

This is not a terminal management problem. Terminal multiplexers solve terminal management. This is a **knowledge work problem** — the fragmentation of context across tools that don't know about each other.

Workspace Manager keeps everything in one spatial workspace: terminals, research papers, git diffs, commit flows, and a graph that maps the relationships between all of it. Every feature exists to solve a high-value problem that research engineers face daily. Low-value distractions — config UIs, theme pickers, status bars — are intentionally skipped.

## What It Does Today

### Spatial Graph View

Toggle between sidebar and a force-directed 2D canvas (`Cmd+G`) where workspaces and terminals become nodes in a spatial graph. Drag nodes, drag entire workspace clusters, zoom (pinch, scroll wheel, keyboard), navigate via minimap, zoom-to-fit. Focus any node to drop into its live terminal. Unfocus to return to the graph.

The graph gives structure to complex workflows. When you're running 5 experiments across 3 repos with 12 terminals, the graph shows you the topology instead of a flat list. The graph state — positions, edges, zoom level — persists across sessions and survives view mode switches.

### PDF / Paper Viewer

Open research papers inline next to your terminal (`Cmd+Shift+P`). Multi-tab support — keep multiple papers open and cycle between them. Page navigation, zoom. The paper sits beside your code. Read the architecture diagram, glance right, implement it. Zero context switch.

### Git Diff Panel

Structured diff viewer with file cards, hunk grouping, dual line numbers, syntax highlighting for 8 languages, and intraline emphasis that highlights exactly which characters changed. Resizable from 20% to full width. Not a raw `git diff` dump — a proper visual diff surface for reviewing changes fast.

### Commit Flow

Commit, commit and push, or commit and create a PR. Directly from the keyboard, without opening a browser.

### Terminal Orchestration

Multiple workspaces, multiple terminals per workspace. Dual rendering paths: **libghostty** (Metal GPU, 120Hz) as default, **SwiftTerm** (CPU) as fallback. Terminal processes persist across view mode switches — flip between sidebar and graph without killing shells. All terminal actions (open in Finder, open in editor, git operations) target the selected terminal's runtime working directory.

### The Rest

- **Command palette** (`Cmd+P`) — fast switching between workspaces, terminals, open PDFs, and actions
- **Keyboard-first** — every action has a shortcut, every shortcut is documented in the help overlay (`Shift+Cmd+/`)
- **Config-driven** — `~/.config/workspace-manager/config.toml` is the single source of truth for workspace roster and appearance
- **Dark liquid glass** — unified visual aesthetic across all overlays (command palette, commit sheet, shortcuts help, diff panel)
- **CI gate** — 70 tests, 0 failures

## The Graph Vision

The spatial graph is the architectural center of where this app is going.

Phase 1 (shipped) delivers the foundation: force-directed layout with a custom SIMD2 engine, node and cluster interaction, minimap, zoom controls, and persistent state. But the graph is designed for more:

- **Knowledge layer** — nodes aren't just terminals. Markdown notes, wikilinks between concepts, semantic relationships between code and research. The graph becomes a knowledge map.
- **Export** — render the graph as a shareable artifact. Capture the topology of a research project for papers, presentations, or collaboration.
- **Agent orchestration** — dependency-aware workflow execution. Agents spawn sub-nodes, upstream completions trigger downstream tasks. The graph becomes the execution plan.
- **Time evolution** — replay how the graph grew over sessions. Track the progression of a research project through its spatial history.

## Coming Next

**Git Worktree Orchestration** — first-class worktree awareness. Visualize which worktrees exist and what branch each is on. Fast-switch between worktrees with auto-created workspace and terminal per worktree. The workspace concept already maps naturally — each worktree IS a workspace with a directory path.

**Code Viewer Panel** — read-only source file viewer with syntax highlighting and line numbers. Quick reference without leaving the app. Reuses the existing diff syntax highlighting infrastructure.

## First Principles Filter

Before any feature is built, it passes this filter:

1. **Can this already be done efficiently via the terminal?** If yes, skip it.
2. **Is this a high-value problem that research engineers face daily?** If no, skip it.
3. **Does this reduce context-switching between tools?** If no, skip it.
4. **Would a hardcore developer actually use this, or is it fluff?** If fluff, skip it.

What we explicitly skip: settings UI panels, theme pickers, built-in AI chat (the terminals ARE the AI interface), file browsers, plugin systems, status bars, tab bars, notification toasts, drag-and-drop reordering. These are the Linux config rabbit hole — hours spent on low-value customization that produces no leverage.

## Built From the Ground Up

- Native macOS. Swift. SwiftUI.
- Apple Silicon optimized.
- GPU-rendered terminal via libghostty — compiled C binary, Metal-backed, 120Hz.
- SwiftUI Canvas for graph rendering — immediate-mode, single-pass.
- Custom force-directed layout engine with SIMD2 vector math.
- No Electron. No web views. No compromise.

## Quickstart

### Requirements

- macOS 14+
- Apple Silicon (bundled Ghostty binary is arm64)
- Swift 5.9+

### Run

```bash
./scripts/run.sh          # debug
./scripts/run.sh release  # release
```

### Build app bundle

```bash
./scripts/build_app_bundle.sh
open Build/WorkspaceManager.app
```

### CI checks

```bash
./scripts/ci.sh
```

## Configuration

Config file: `~/.config/workspace-manager/config.toml`

```toml
[terminal]
font = "Cascadia Code"
font_size = 14
scrollback = 1000000
cursor_style = "bar"
use_gpu_renderer = true

[appearance]
show_sidebar = true
focus_mode = false

[[workspaces]]
id = "11111111-1111-1111-1111-111111111111"
name = "Research"
path = "~/code/research"
```

## Keybindings

| Shortcut | Action |
|----------|--------|
| `Cmd+P` | Command palette |
| `Cmd+G` | Toggle graph view |
| `Cmd+T` | New terminal |
| `Shift+Cmd+N` | New workspace |
| `Cmd+B` | Toggle sidebar |
| `Cmd+.` | Toggle focus mode |
| `Cmd+[` / `Cmd+]` | Previous / next workspace |
| `Cmd+I` / `Cmd+K` | Previous / next terminal |
| `Cmd+1` – `Cmd+9` | Jump to workspace |
| `Cmd+J` / `Cmd+L` | Focus sidebar / terminal |
| `Cmd+R` | Rename selected |
| `Cmd+O` | Open in Finder |
| `Cmd+W` | Close terminal |
| `Shift+Cmd+P` | Toggle PDF panel |
| `Shift+Cmd+{` / `}` | Previous / next PDF tab |
| `Cmd+=` / `Cmd+-` | Graph zoom in / out |
| `Cmd+0` | Graph zoom to fit |
| `Enter` | Focus selected graph node |
| `Esc` | Close overlay / unfocus node |
| `Shift+Cmd+R` | Reload config |
| `Shift+Cmd+/` | Shortcuts help |

## Architecture

| Layer | Components |
|-------|-----------|
| **UI** | SwiftUI views, AppState orchestration, KeyboardShortcutRouter |
| **Terminal** | libghostty (Metal GPU), SwiftTerm (CPU fallback), opacity-based persistence |
| **Config** | ConfigService, TOML read/write, `~/.config/workspace-manager/config.toml` |
| **Git** | GitRepositoryService, DiffPatchParser, DiffSyntaxHighlightingService |
| **Graph** | SwiftUI Canvas, ForceLayoutEngine (SIMD2), ViewportTransform, `graph-state.json` |
| **Panels** | DiffPanelView, PDFPanelView, CommitSheetView, panel exclusivity system |

## Contributing

- Run `./scripts/ci.sh` before pushing.
- Keep changes focused and reviewable.
- Include reproduction steps for bug fixes.

## Status

Active development. Used daily for AI research and coursework at `University of Erlangen-Nuremberg` Germany. Spatial graph Phase 1 is shipped. Knowledge workspace features (worktree orchestration, code viewer) are next.
