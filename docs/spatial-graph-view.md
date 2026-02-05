# Feature Specification: Spatial Graph View

## Authors
**Lyra and Rahul** — Equal partners, equal contribution, forever.

## Date
05 February 2026

## Status
**Planned** — Implementation deferred to vacation period. This document captures the vision and design decisions for future reference.

## Inspiration
[Voicetree](https://github.com/voicetreelab/voicetree) — An interactive graph-view where nodes are markdown notes or terminal-based agents. Described as "Obsidian meets Claude Code." Their architecture uses Electron/React/Python with Cytoscape for graph rendering and xterm.js for terminals. We port the core concepts into our native Swift/Metal stack.

---

## 1. Problem Statement

### What Breaks at Scale

Workspace Manager currently renders workspaces and terminals as a flat sidebar tree. This works at small scale (3-5 workspaces, 2-3 terminals each). At larger scale, the sidebar becomes a scrollable list with no spatial meaning:

1. **Cognitive overload**: With 10+ workspaces and 20+ terminals, the sidebar becomes a wall of text. Users lose track of what is where and what relates to what.
2. **No relationship visibility**: The sidebar shows containment (workspace contains terminals) but not semantic relationships (this agent's output feeds that agent's review, this markdown file describes that terminal's task).
3. **No spatial memory**: Humans remember WHERE things are on a surface, not their position in a list. A sidebar list forces sequential scanning. A spatial layout enables positional recall.
4. **No progress visibility**: There is no way to see how work evolved over time. The sidebar is a snapshot of current state with no history dimension.
5. **Multi-agent orchestration complexity**: When running 4-10 AI agents across workspaces, the user needs a bird's-eye view of the entire operation — which agents are active, what they are working on, and how their tasks relate to each other.

### Why Spatial

Voicetree's core insight: "Location-based memory is the most efficient way to remember things." A spatial graph view transforms terminal orchestration from a list-scanning problem into a spatial navigation problem. The user builds a mental map of their workspace topology and navigates by position, not by name.

Research supports this. Context rot studies (Chroma Research, July 2025) show 30-60% performance degradation when agents receive unfocused context dumps versus targeted context. A graph structure enables precise context selection by proximity, not by dumping entire conversation histories.

---

## 2. Vision

**Workspace Manager becomes a spatial IDE for recursive multi-agent orchestration.**

It is an Obsidian graph-view that you work directly inside of. Workspaces, terminals, and markdown files are nodes on an interactive graph. Their relationships are edges. The user navigates, spawns agents, edits notes, and orchestrates work on a 2D spatial canvas.

The spatial graph view does not replace the sidebar — it is an alternative view of the same data. The user toggles between:
1. **Sidebar View** (current): Tree-based list navigation. Fast, minimal, keyboard-first.
2. **Graph View** (new): Spatial canvas navigation. Visual, relationship-aware, mouse+keyboard.

Same app. Same config. Same terminals. Different visualization.

---

## 3. Core Concepts

### 3.1 Node

A node is the fundamental unit on the graph. A node is a generic container that can be opened in one of two modes:

1. **Terminal mode**: The node becomes a live terminal surface (libghostty Metal renderer). The user interacts with a shell, runs agents, executes commands — identical to current terminal behavior.
2. **Markdown mode**: The node becomes a rich markdown editor. The user writes notes, documents plans, records context, describes tasks.

The node itself is type-agnostic until the user opens it. This means:
- A node can start as a markdown plan and later spawn a terminal to execute that plan.
- A node can start as a terminal and later be annotated with markdown notes.
- The mode is a runtime choice, not a permanent property.

### 3.2 Edge

An edge is a relationship between two nodes. Edge types include:

1. **Containment**: Workspace contains terminal/markdown nodes. (Maps to current workspace → terminal hierarchy.)
2. **Reference**: A markdown node references another node via wikilink syntax (`[[node-name]]`).
3. **Dependency**: Node A's output feeds Node B's input. (Maps to Worker → Reviewer pairing.)
4. **User-defined**: The user draws an edge between any two nodes to express a custom relationship.

### 3.3 Graph

The graph is the complete set of nodes and edges. It IS the workspace structure, visualized spatially. Our existing data model already contains graph structure:

```
Current sidebar model          →  Graph model
─────────────────────────────     ──────────────────────────
Workspace "AI-2 Project"       →  Cluster node (container)
  ├─ Terminal "Ghost"          →  Node (terminal type)
  ├─ Terminal "Lyra"           →  Node (terminal type)
  └─ (implicit files)         →  Node (markdown type)
Workspace "Research"           →  Cluster node (container)
  ├─ Terminal "Claude"         →  Node (terminal type)
  └─ Terminal "Codex"          →  Node (terminal type)
Worker → Reviewer pairing      →  Directed edge (dependency)
```

The graph view does not add new data — it reveals the structure that already exists in our config and runtime state.

### 3.4 Canvas

The canvas is the 2D surface on which the graph is rendered. It supports:
- **Pan**: Drag to move the viewport.
- **Zoom**: Pinch/scroll to zoom in/out.
- **Select**: Click a node to select it.
- **Open**: Double-click a node to open it (terminal or markdown).
- **Drag**: Move nodes to reposition them on the canvas.
- **Draw edge**: Drag from one node to another to create a relationship.

---

## 4. Node Types (Detailed)

### 4.1 Terminal Node

When a node is opened as a terminal:
1. A libghostty Metal surface is created (identical to current terminal implementation).
2. The terminal renders inside the node's bounding box on the canvas, or expands to a focused view.
3. Full keyboard input is routed to the terminal when focused.
4. The terminal process persists even when the node is collapsed/unfocused (same ZStack+opacity approach as current implementation).

### 4.2 Markdown Node

When a node is opened as a markdown editor:
1. A native text editor view renders inside the node's bounding box.
2. Supports standard markdown syntax (headers, lists, code blocks, links).
3. Wikilinks (`[[node-name]]`) create edges to referenced nodes.
4. Content is persisted as `.md` files in a configurable directory (e.g., `~/.config/workspace-manager/notes/` or within the workspace path).
5. The markdown editor must be native SwiftUI (no WebView) for consistency with the rest of the app.

### 4.3 Future Node Types (Out of Scope for v1)
- **Image node**: Display images/diagrams on the canvas.
- **Web node**: Embed a web view for documentation reference.
- **Agent status node**: Auto-generated node showing agent metrics.

---

## 5. View Architecture

### 5.1 Toggle Mechanism

The app provides a view toggle (keyboard shortcut and/or UI button):

```
┌─────────────────────────────────────────────┐
│  Sidebar View  ←──── toggle ────→  Graph View  │
│  (current)                         (new)       │
└─────────────────────────────────────────────┘
```

- The toggle preserves all state (terminals stay alive, selection preserved).
- In Graph View, the sidebar is hidden. Navigation happens on the canvas.
- In Sidebar View, the graph positions are preserved in memory for when the user toggles back.

### 5.2 Graph View Layout

```
┌──────────────────────────────────────────────────────┐
│ ┌─ toolbar ──────────────────────────────────────┐   │
│ │  [Sidebar] [Graph]  |  zoom  |  layout  |  +  │   │
│ └────────────────────────────────────────────────┘   │
│                                                      │
│   ┌──────────┐          ┌──────────┐                │
│   │ Terminal  │──edge──→│ Markdown │                │
│   │ "Ghost"   │          │ "Plan"   │                │
│   └──────────┘          └──────────┘                │
│         │                                            │
│         │ (containment)                              │
│         ▼                                            │
│   ┌──────────┐          ┌──────────┐                │
│   │ Terminal  │──edge──→│ Terminal  │                │
│   │ "Lyra"    │          │ "Codex"   │                │
│   └──────────┘          └──────────┘                │
│                                                      │
│                    [canvas: pan, zoom, drag]          │
└──────────────────────────────────────────────────────┘
```

### 5.3 Node Interaction States

1. **Collapsed**: Shows node name, type icon, and status indicator. Small footprint on canvas.
2. **Preview (hover)**: Shows a preview of content (first few lines of markdown, or terminal snapshot).
3. **Expanded (click)**: Opens the full terminal or markdown editor inline on the canvas.
4. **Focused (double-click or enter)**: The node takes over the main view area (like current terminal full-screen). Other nodes fade. Escape returns to graph.

---

## 6. Data Model Changes

### 6.1 Config Extensions

New fields needed in `config.toml`:

```toml
[appearance]
show_sidebar = true
focus_mode = false
default_view = "sidebar"  # "sidebar" | "graph"

[graph]
layout_algorithm = "force-directed"  # "force-directed" | "hierarchical" | "manual"
auto_layout = true  # re-layout on node add/remove
persist_positions = true  # save node positions across restarts

[[workspaces]]
id = "..."
name = "AI-2 Project"
path = "~/code/ai2"

  [[workspaces.nodes]]
  id = "node-uuid"
  name = "Implementation Plan"
  type = "markdown"  # "terminal" | "markdown"
  x = 250.0  # canvas position
  y = 100.0
  file = "plan.md"  # for markdown nodes

  [[workspaces.nodes]]
  id = "node-uuid-2"
  name = "Ghost"
  type = "terminal"
  x = 450.0
  y = 100.0

  [[workspaces.edges]]
  from = "node-uuid"
  to = "node-uuid-2"
  type = "dependency"  # "containment" | "reference" | "dependency" | "custom"
```

### 6.2 AppState Extensions

```swift
// New model types
struct GraphNode: Identifiable {
    let id: UUID
    var name: String
    var nodeType: NodeType  // .terminal | .markdown
    var position: CGPoint   // canvas position
    var file: String?       // for markdown nodes
}

enum NodeType {
    case terminal
    case markdown
}

struct GraphEdge: Identifiable {
    let id: UUID
    var from: UUID  // source node id
    var to: UUID    // target node id
    var edgeType: EdgeType
}

enum EdgeType {
    case containment
    case reference
    case dependency
    case custom
}

// AppState additions
class AppState {
    // ... existing fields ...
    var currentView: ViewMode = .sidebar  // .sidebar | .graph
    var graphNodes: [UUID: GraphNode] = [:]
    var graphEdges: [GraphEdge] = []
}
```

---

## 7. Graph Rendering

### 7.1 Technology Options (To Evaluate)

| Option | Pros | Cons |
|--------|------|------|
| **SwiftUI Canvas** | Native, simple API, hardware-accelerated | Limited interactivity, no built-in hit testing |
| **SpriteKit** | Built for 2D, physics engine included, Apple-native | Game framework feel, may be overkill |
| **Core Animation (CALayer)** | Low-level control, smooth animations, native | Manual hit testing, more boilerplate |
| **Custom Metal renderer** | Maximum performance, matches libghostty approach | Significant engineering effort |
| **SceneKit (2D mode)** | 3D engine in 2D, good for future 3D graph | Heavy for 2D use case |

**Recommended approach**: Start with **SwiftUI Canvas** for the graph background (edges, grid) and standard **SwiftUI views** for nodes (draggable, clickable). This gives us the simplest path to a working prototype. Optimize to SpriteKit or Metal later if performance requires it.

### 7.2 Layout Algorithms

Force-directed layout (Fruchterman-Reingold or similar) is the standard for graph visualization:

1. Nodes repel each other (like charged particles).
2. Edges attract connected nodes (like springs).
3. The system reaches equilibrium where connected nodes are close and unconnected nodes are spread apart.

**Research TODO**: Search GitHub for Swift/Metal force-directed graph layout implementations. Libraries to evaluate:
- Any Swift graph visualization libraries (search: "swift graph visualization", "swift force directed layout", "swiftui graph")
- Academic implementations of Fruchterman-Reingold in Swift
- Metal compute shader implementations for parallel force calculation (for large graphs)

### 7.3 Rendering Pipeline

```
Graph State (AppState)
    ↓
Layout Engine (force-directed → positions)
    ↓
Canvas Layer (edges as bezier curves, grid)
    ↓
Node Layer (SwiftUI views positioned on canvas)
    ↓
Interaction Layer (pan, zoom, drag, select)
    ↓
Terminal/Markdown Layer (opened nodes render content)
```

---

## 8. Interaction Design

### 8.1 Canvas Interactions

| Action | Input | Result |
|--------|-------|--------|
| Pan | Two-finger drag / middle-click drag | Move viewport |
| Zoom | Pinch / scroll wheel | Scale canvas |
| Select node | Single click | Highlight node, show details |
| Open node | Double click | Open as terminal or markdown (user choice) |
| Focus node | Enter (when selected) | Expand node to full view |
| Unfocus | Escape | Return to graph view |
| Move node | Drag node | Reposition on canvas |
| Create edge | Drag from node edge to another node | Create relationship |
| Delete edge | Select edge + Delete key | Remove relationship |
| Create node | Right-click canvas / shortcut | Add new node at position |
| Context menu | Right-click node | Options: open as terminal, open as markdown, rename, delete |

### 8.2 Keyboard Shortcuts (Graph View)

| Shortcut | Action |
|----------|--------|
| Tab | Cycle through nodes |
| Enter | Open/focus selected node |
| Escape | Unfocus node / close graph view |
| Space | Toggle node expand/collapse |
| Cmd+= / Cmd+- | Zoom in/out |
| Cmd+0 | Fit graph to viewport |
| Cmd+N | Create new node at center |
| Delete/Backspace | Delete selected node (with confirmation) |

---

## 9. Relationship to Existing Features

### 9.1 Mapping Current Concepts to Graph

| Current Concept | Graph Equivalent |
|-----------------|-----------------|
| Workspace | Cluster (group of nodes) or a region on canvas |
| Terminal | Terminal node |
| Sidebar tree | Containment edges (workspace → terminals) |
| Worker/Reviewer pairing | Dependency edge between two terminal nodes |
| Task label | Node annotation / subtitle |
| Focus Mode | Single-node expanded view |
| Command Palette | Still works — searches nodes instead of sidebar items |

### 9.2 Migration Path

The graph view is additive, not destructive:
1. Existing sidebar view remains fully functional.
2. Graph view reads the same config.toml and AppState.
3. Workspaces auto-generate cluster layouts in graph view.
4. Terminals within a workspace become nodes within that cluster.
5. Users can manually reposition nodes; positions persist to config.
6. No existing feature is removed or broken.

---

## 10. Voicetree-Inspired Features (Phased)

### Phase 1: Spatial Graph Foundation (Vacation Project)
- Graph canvas with pan, zoom, drag.
- Nodes for terminals and markdown files.
- Edges for relationships.
- Force-directed auto-layout.
- Toggle between sidebar view and graph view.
- Node positions persist to config.

### Phase 2: Knowledge Layer
- Wikilink parsing in markdown nodes creates reference edges automatically.
- Context injection: when spawning an agent terminal, inject content from nearby nodes (configurable radius).
- Semantic search across all markdown nodes via command palette.

### Phase 3: Agent Orchestration
- Agents can spawn sub-agent nodes on the graph.
- Recursive task decomposition: an agent breaks its task into sub-nodes.
- Agent status visualization (active, idle, completed) on node appearance.
- Dependency graph execution: agents auto-start when upstream dependencies complete.

### Phase 4: Advanced Features
- Voice input to create nodes (speech-to-graph, following voicetree's approach).
- Embedding-based relationships (ChromaDB or similar vector store).
- Time evolution: replay graph growth over time using git history as the time dimension.
- Shared memory graph between human and agents (voicetree's core insight).

---

## 11. Time Evolution (Open Question)

Rahul's insight: git already tracks all changes. Every commit is a snapshot. The graph's evolution over time could be reconstructed from git history:

1. Each commit that modifies config.toml captures a graph state snapshot.
2. A timeline slider could replay graph growth: nodes appearing, edges forming, positions changing.
3. This avoids building a custom history system — git IS the history system.

**Open questions:**
- How granular should snapshots be? Every commit? Daily? Manual checkpoints?
- Should node content (markdown, terminal output) be versioned separately from graph structure?
- How to handle terminal nodes in time evolution (terminals are ephemeral, their output is not currently persisted)?
- Would a git graph visualization (commit DAG) be a useful alternative or complement?

**Decision: Deferred.** Time evolution is a Phase 4+ feature. The foundation (Phase 1) should be built first. This section exists to capture the idea for future discussion.

---

## 12. Non-Goals (v1 of Graph View)

1. **No voice input.** Speech-to-graph is a Phase 4 feature.
2. **No embeddings or vector search.** Semantic relationships are Phase 2+.
3. **No LLM-driven graph building.** The human builds the graph manually in v1.
4. **No 3D visualization.** The canvas is 2D.
5. **No cross-machine sync.** Graph state is local (config.toml + git).
6. **No real-time collaboration.** Single-user only.
7. **No plugin system.** Node types are hardcoded (terminal, markdown) in v1.

---

## 13. Research TODOs

Before implementation begins, the following research must be completed:

1. **Swift graph visualization libraries**: Search GitHub for existing force-directed layout implementations in Swift. Evaluate maturity, performance, and API fit.
2. **SwiftUI Canvas performance**: Benchmark SwiftUI Canvas with 50-100 nodes and 100+ edges. Determine if Canvas is sufficient or if SpriteKit/Metal is needed.
3. **Markdown editor in SwiftUI**: Evaluate native Swift markdown editors. Options include building on top of NSTextView, using a SwiftUI TextEditor with custom parsing, or integrating an existing library.
4. **Node embedding in canvas**: Study how to render a libghostty Metal surface inside a movable, zoomable canvas node. This is the key technical risk — the terminal must render correctly at arbitrary positions and scales.
5. **Force-directed layout algorithms**: Study Fruchterman-Reingold, ForceAtlas2, and d3-force algorithms. Determine which is best suited for our node count range (10-100 nodes).
6. **Voicetree deep dive**: Study voicetree's Cytoscape configuration, layout algorithms, and interaction handlers for UX inspiration.

---

## 14. Open Questions

1. Should workspaces be visible as container nodes on the graph, or should the graph be workspace-scoped (one graph per workspace)?
2. How should the graph view interact with Focus Mode? Is Focus Mode just "expand one node to full screen"?
3. Should edges have labels/weights, or are they purely structural?
4. How to handle the glass/transparent aesthetic on the graph canvas? Should nodes have the same blur material?
5. What is the maximum practical node count before performance degrades? This determines whether we need Metal compute for layout.
6. Should the command palette in graph view search by node name, content, or both?

---

## 15. References

1. [Voicetree](https://github.com/voicetreelab/voicetree) — Primary inspiration. Electron/React/Python spatial IDE for agent orchestration.
2. [Obsidian Graph View](https://obsidian.md) — Knowledge graph visualization for markdown notes.
3. [Chroma Research: Context Rot](https://research.trychroma.com/context-rot) — 30-60% LLM performance degradation from unfocused context.
4. [Fruchterman-Reingold Algorithm](https://en.wikipedia.org/wiki/Force-directed_graph_drawing) — Standard force-directed graph layout.
5. Workspace Manager [product.md](product.md) — Current v1 product specification.
6. Workspace Manager [LYRA.md](../LYRA.md) — Current architecture and status.
