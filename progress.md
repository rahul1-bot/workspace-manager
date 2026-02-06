# Spatial Graph View — progress.md

## Implementation Progress

---

| Progress Todo | Phase 1 — Spatial Graph Foundation | Date: 06 February 2026 | Time: 05:15 AM | Name: Lyra |

    1. Research (prerequisite before coding):
        1. ✅ Search for existing Swift graph visualization libraries on GitHub (force-directed layout, SwiftUI graph, interactive canvas).
        2. ✅ Evaluate any open-source SwiftUI-based spatial canvas implementations for architectural reference.
        3. ✅ Study SwiftUI Canvas API performance characteristics at 50-100 node scale.
        4. ✅ Study Fruchterman-Reingold and ForceAtlas2 algorithm implementations in Swift or portable languages.
        5. ✅ Study Voicetree repository architecture for UX and interaction design patterns.
        6. ✅ Determine SwiftUI gesture composition strategy for simultaneous pan, zoom, and node drag.
    2. Research outcomes (06 February 2026):
        1. Grape (github.com/li3zhen1/Grape) identified as the primary force simulation engine candidate. SIMD-accelerated, Barnes-Hut KDTree, velocity Verlet integration, actively maintained. Handles 77 nodes and 254 edges in 5 milliseconds on M1 Max.
        2. Rendering approach revised: SwiftUI Canvas for all graph elements (nodes, edges, grid, labels) in a single immediate-mode draw pass. Manual hit-testing replaces per-node SwiftUI Views. This eliminates view hierarchy overhead at scale.
        3. Viewport transform must apply translation before scaling, with scale anchor at cursor or pinch point.
        4. Reference implementations catalogued: SwiftUI-Infinite-Grid (zoom-to-cursor patterns), Zoomable (gesture modifiers), Kodeco Mind-Map Tutorial (Mesh/Node/Edge architecture), objc.io Node Editor (macOS focus and keyboard patterns).
        5. VoiceTree validated the spatial IDE concept but provides no reusable code (Electron/React/Python stack).
        6. No native Swift Fruchterman-Reingold implementation exists. Grape's ForceSimulation module is the closest equivalent and exceeds what a manual port would achieve.
    3. Phase 1A — Data Model and Persistence:
        1. Define GraphNode struct (id, name, nodeType, position, workspaceId, terminalId) with Codable conformance.
        2. Define GraphEdge struct (id, from, to, edgeType) with Codable conformance.
        3. Define GraphStateDocument struct as the root Codable container for graph-state.json.
        4. Implement GraphStateService for reading and writing graph-state.json with debounced saves.
        5. Extend AppState with currentView (sidebar or graph), graphNodes, and graphEdges.
        6. Implement graph state sync: adding a terminal in config creates a graph node, deleting a workspace removes its cluster and nodes.
    4. Phase 1B — Canvas and Node Rendering:
        1. Implement GraphCanvasView with SwiftUI Canvas for all graph rendering (nodes, edges, grid, labels) in a single immediate-mode pass.
        2. Implement node rendering in Canvas draw call: collapsed nodes as rounded rectangles with name label, type icon, and status indicator.
        3. Implement edge rendering as bezier curves between connected node positions.
        4. Implement workspace cluster visual grouping (rounded boundary region around workspace node positions).
        5. Design visual style consistent with existing glass and dark aesthetic.
        6. Use Canvas resolve() to pre-compute text labels for rendering performance.
        7. Add drawingGroup() modifier if profiling reveals need for Metal-backed rendering.
    5. Phase 1C — Interaction Layer:
        1. Implement viewport transform (translation plus scale) with translation-before-scaling order.
        2. Implement pan gesture on canvas background (updates viewport translation).
        3. Implement zoom gesture on canvas (updates viewport scale with anchor at gesture point).
        4. Implement manual hit-testing: point-in-node distance check against node positions in canvas coordinate space.
        5. Implement node drag gesture (reposition with coordinate-space conversion and persistence).
        6. Implement node selection (single click highlights via hit-test, shows details).
        7. Implement node focus (double-click or Enter expands to live libghostty terminal).
        8. Implement unfocus (Escape returns to graph canvas).
        9. Implement user-drawn edge creation (drag from node handle to another node).
        10. Implement context menu on nodes via hit-test location.
    6. Phase 1D — Layout Engine:
        1. Evaluate Grape ForceSimulation module as a dependency versus writing a custom implementation.
        2. Integrate or implement force-directed layout with Link, ManyBody, and Center forces.
        3. Run layout computation on background thread.
        4. Apply computed positions to graphNodes on MainActor.
        5. Support pinned nodes (user-repositioned) excluded from force calculation.
        6. Trigger layout on node add, node remove, or manual reset.
    7. Phase 1E — Integration:
        1. Implement view toggle between sidebar mode and graph mode in ContentView.
        2. Extend KeyboardShortcutRouter with graph-specific shortcuts.
        3. Ensure all existing overlays (diff panel, commit sheet, command palette) work in graph mode.
        4. Performance validation at 50 nodes with bezier edge rendering.
        5. Verify terminal lifecycle: terminals remain alive across view mode switches.

---

| Progress Todo | Phase 1A and 1B Delivery — First Visual Test | Date: 06 February 2026 | Time: 05:54 AM | Name: Lyra |

    1. Delivered and compiling:
        1. ✅ GraphNode, GraphEdge, GraphStateDocument, ViewportState, ViewMode, LayoutAlgorithm model structs with Codable and Sendable conformance.
        2. ✅ GraphStateService (actor-isolated) with debounced save (500ms) and immediate save for graph-state.json.
        3. ✅ GraphStateError error domain added to AppErrors.
        4. ✅ AppLogger.graph category added.
        5. ✅ ViewportTransform struct with apply and invert coordinate conversion.
        6. ✅ GraphCanvasView with SwiftUI Canvas rendering: dot grid, workspace cluster boundaries, bezier edges, rounded-rect nodes with status dots and type icons.
        7. ✅ Node overlay layer with drag gestures and context menus.
        8. ✅ Pan gesture (drag on background), zoom gesture (pinch), node drag gesture.
        9. ✅ Hit-testing via bounding-box check in canvas coordinate space.
        10. ✅ Single-tap selection, double-tap focus (switches to terminal in sidebar mode).
        11. ✅ AppState extended with currentViewMode, graphDocument, focusedGraphNodeId, and graph sync/persist methods.
        12. ✅ ContentView switches between sidebarModeContent and GraphCanvasView based on currentViewMode.
        13. ✅ Cmd+G shortcut added for toggleViewMode.
        14. ✅ Grape ForceSimulation v1.1.0 integrated as SPM dependency.
        15. ✅ swift build passes, swift test passes (41 tests, 0 failures).
    2. Visual bugs observed in first test run:
        1. Node positions start at (0,0) canvas origin which maps to top-left screen corner. Nodes should be centered on the canvas viewport.
        2. Ghost terminal nodes positioned at x=0 are clipped because half of the 140pt-wide node extends off-screen to the left. Initial x offset for the first terminal in each workspace should account for node width.
        3. Vertical stacking looks like a flat list because nodes are positioned using a simple grid (terminalIndex * 180, workspaceIndex * 120) without force-directed layout. This is expected without Phase 1D layout engine.
        4. Dot grid is not visible. Either the 0.08 opacity is too low against the glass background, or the glass background NSVisualEffectView renders on top of the Canvas grid layer.
        5. No edges rendered between nodes because syncGraphFromWorkspaces does not auto-generate containment edges for workspace-to-terminal relationships.
    3. Fixes required for next session:
        1. ✅ Center initial node positions relative to canvas viewport center, not canvas origin.
        2. ✅ Auto-generate containment edges in syncGraphFromWorkspaces when creating nodes for workspace terminals.
        3. ✅ Increase grid dot opacity or disable the glass background NSVisualEffectView in graph mode.
        4. Integrate ForceSimulation to spread nodes spatially instead of the static grid layout.

---

| Progress Todo | Phase 1 Visual Polish — Edges, Grid, Centering, Workspace Labels | Date: 06 February 2026 | Time: 06:30 AM | Name: Lyra |

    1. Delivered and compiling:
        1. ✅ Auto-generated containment edges in syncGraphFromWorkspaces. Chain-topology edges connect consecutive terminals within each workspace. Idempotent generation checks for existing containment pairs before creating new edges to avoid duplicates.
        2. ✅ Viewport auto-centering on first appear. GraphCanvasView computes the centroid of all graph nodes on appear and translates the viewport so the node cluster is centered on screen. Only triggers when viewport is at identity transform to avoid overriding user manual panning.
        3. ✅ Grid dot opacity increased from 0.08 to 0.15 for improved visibility against the dark background.
        4. ✅ Containment edge line width increased from 1.0 to 3.0 and opacity from 0.15 to 0.7 for clear visual connections between terminals.
        5. ✅ Workspace name labels rendered on cluster boundaries. Each cluster boundary now displays the workspace name at the top-left corner using 11pt semibold monospaced font at 0.5 opacity. Cluster boundaries also now render for single-node workspaces, not just multi-node clusters. Extra top padding of 24pt added to the cluster boundary to accommodate the label without overlapping nodes.
        6. ✅ swift build passes, swift test passes (41 tests, 0 failures).
    2. Remaining for next session:
        1. Integrate ForceSimulation to replace static grid layout with force-directed spatial positioning.
        2. Phase 1C interaction features: user-drawn edge creation, improved focus and unfocus flow.

---

| Progress Todo | Phase 2 — Knowledge Layer (Future) | Date: 06 February 2026 | Time: 05:15 AM | Name: Lyra |

    1. Planned scope (not started):
        1. Markdown node type with native SwiftUI editor.
        2. Wikilink parsing in markdown nodes creates reference edges automatically.
        3. Context injection: spawning an agent terminal injects content from nearby graph nodes.
        4. Semantic search across all markdown nodes via command palette.

---

| Progress Todo | Phase 3 — Agent Orchestration (Future) | Date: 06 February 2026 | Time: 05:15 AM | Name: Lyra |

    1. Planned scope (not started):
        1. Agents spawn sub-agent nodes on the graph.
        2. Recursive task decomposition into sub-nodes.
        3. Agent status visualization (active, idle, completed) on node appearance.
        4. Dependency graph execution: agents auto-start when upstream dependencies complete.

---

| Progress Todo | Phase 4 — Advanced Features (Future) | Date: 06 February 2026 | Time: 05:15 AM | Name: Lyra |

    1. Planned scope (not started):
        1. Voice input to create nodes.
        2. Embedding-based relationships via vector store.
        3. Time evolution: replay graph growth using git history.
        4. Shared memory graph between human and agents.
