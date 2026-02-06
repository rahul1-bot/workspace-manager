# Spatial Graph View — memory.md

## Engineering Memory

---

| Memory | Terminal Rendering Strategy for Graph Nodes | Date: 06 February 2026 | Time: 05:15 AM | Name: Lyra |

    1. Observation:
        1. libghostty renders Metal surfaces at fixed window positions. Metal surfaces cannot be arbitrarily scaled with pinch gestures. Rendering live terminals inside zoomable canvas nodes requires solving the scale mismatch between GPU-rendered surfaces and canvas zoom levels.
    2. Decision:
        1. Collapsed nodes display a name label, type icon, and status indicator. Focused nodes render the live libghostty Metal surface at full native resolution. No render-to-texture or arbitrary-scale terminal rendering in Phase 1.
    3. Implication:
        1. Terminal focus transition becomes the primary interaction pattern: graph canvas (spatial navigation) to focused terminal (full live surface) to escape (back to graph).

---

| Memory | SwiftUI Canvas Is GPU-Accelerated on Apple Silicon | Date: 06 February 2026 | Time: 05:15 AM | Name: Lyra |

    1. Observation:
        1. SwiftUI Canvas API renders through Core Graphics which runs on Metal under the hood on Apple Silicon. The GPU is utilized regardless of whether code is raw Metal or SwiftUI Canvas. Raw Metal requires building text rendering, hit testing, gesture handling, layout, and event routing from scratch.
    2. Decision:
        1. Use SwiftUI Canvas for graph background (grid, edges) and SwiftUI Views for interactive nodes. Reserve raw Metal migration for a future phase if profiling at 100+ nodes reveals a performance bottleneck.
    3. Implication:
        1. Development velocity is preserved for a 1-hour-per-day cadence. Interaction features (drag, click, context menu) come free from SwiftUI. The rendering layer abstraction permits future Metal migration without rewriting state or interaction logic.

---

| Memory | Graph State and App Config Are Separate Persistence Concerns | Date: 06 February 2026 | Time: 05:15 AM | Name: Lyra |

    1. Observation:
        1. config.toml stores user preferences that change infrequently and intentionally. Graph state (node positions, zoom, pan, edges) changes continuously through drag interactions. Mixing them creates noisy diffs and risks accidental config corruption.
    2. Decision:
        1. Graph state persists to ~/.config/workspace-manager/graph-state.json. Workspace and terminal UUIDs link graph-state entries to config.toml entities.
    3. Implication:
        1. config.toml remains clean and human-editable. Graph state handles high-frequency updates independently.

---

| Memory | Grape Library Solves Force-Directed Layout | Date: 06 February 2026 | Time: 05:30 AM | Name: Lyra |

    1. Observation:
        1. Grape (github.com/li3zhen1/Grape, also SwiftGraphs/Grape) is an actively maintained SwiftUI force-directed graph visualization library. Last updated January 2026, approximately 365 stars. It provides a two-module architecture: ForceSimulation (pure physics engine with SIMD acceleration and Barnes-Hut KDTree optimization) and Grape (SwiftUI Canvas-based rendering with drag and tap gestures). It handles 77 nodes and 254 edges in approximately 5 milliseconds on M1 Max. Forces include Link, ManyBody, Center, Collide, Position, and Radial, composed via velocity Verlet integration identical to d3-force.
    2. Decision:
        1. Evaluate Grape as a dependency for force-directed layout computation. The ForceSimulation module can be used standalone without the Grape rendering layer, allowing us to build our own rendering and interaction system while leveraging a proven simulation engine. The alternative is porting the algorithm ourselves, which would require significant effort for equivalent performance.
    3. Implication:
        1. Writing Fruchterman-Reingold from scratch is unnecessary. Grape provides SIMD-optimized, Barnes-Hut-accelerated force simulation that exceeds what a manual implementation would achieve at 1-hour-per-day cadence. The two-module separation means we can import only ForceSimulation and discard their rendering if our needs diverge.

---

| Memory | Canvas-Only Rendering Outperforms Per-Node SwiftUI Views | Date: 06 February 2026 | Time: 05:30 AM | Name: Lyra |

    1. Observation:
        1. Web research and multiple SwiftUI graph implementations reveal that rendering individual SwiftUI views per graph node creates massive view hierarchy overhead at scale. SwiftUI Canvas draws everything in a single immediate-mode pass via GraphicsContext. Canvas does not support per-element gestures or hit testing, requiring manual point-in-node detection, but the performance difference is significant at 50+ nodes.
    2. Decision:
        1. Revise the rendering approach from the original plan. Use SwiftUI Canvas for all graph rendering (nodes, edges, grid, labels) instead of SwiftUI Views for nodes. Implement manual hit-testing via distance checks against node positions transformed by the viewport. Node interaction (drag, select, context menu) is handled through gesture recognizers on the Canvas view with coordinate-space conversion to identify the target node.
    3. Implication:
        1. The rendering layer becomes a single Canvas draw call per frame rather than N SwiftUI view updates. Hit-testing is a simple loop over node positions with distance thresholds. The tradeoff is losing free SwiftUI gestures per node, but the performance gain is substantial and the manual hit-testing code is trivial (approximately 10-20 lines).

---

| Memory | Viewport Transform Order Is Critical for Zoom Behavior | Date: 06 February 2026 | Time: 05:30 AM | Name: Lyra |

    1. Observation:
        1. Multiple infinite canvas implementations (SwiftUI-Infinite-Grid, Zoomable, and blog references) consistently apply translations before scaling. The scaling anchor must be at the cursor or pinch point, not the canvas origin, to produce natural zoom-to-point behavior. Reversing this order causes the viewport to jump during zoom gestures.
    2. Decision:
        1. Viewport transform pipeline must apply translation first, then scaling, with the scale anchor computed relative to the gesture location in canvas coordinate space.
    3. Implication:
        1. The coordinate system conversion between screen space and canvas space must account for both translation offset and scale factor. All hit-testing, node positioning, and edge rendering must use canvas coordinates, not screen coordinates.

---

| Memory | Research Reference Library for Implementation | Date: 06 February 2026 | Time: 05:30 AM | Name: Lyra |

    1. Observation:
        1. Comprehensive web research identified the following reference implementations ranked by relevance to our use case.
    2. Primary references (high relevance):
        1. Grape (github.com/li3zhen1/Grape): Force-directed simulation engine and SwiftUI Canvas rendering. SIMD-accelerated Barnes-Hut optimization. Actively maintained as of January 2026.
        2. SwiftUI Canvas API (Apple): Immediate-mode GPU-accelerated 2D drawing. Requires manual hit-testing. Use resolve() for pre-computing text labels and drawingGroup() for Metal-backed rendering at high node counts.
        3. SwiftNodeEditor (github.com/schwa/SwiftNodeEditor): Protocol-based node graph editor demonstrating anchor points and edge routing patterns.
    3. Supporting references (medium relevance):
        1. SwiftUI-Infinite-Grid (github.com/benjaminRoberts01375/SwiftUI-Infinite-Grid): Zoom-to-cursor, multi-input pan and zoom, coordinate space management.
        2. Zoomable (github.com/ryohey/Zoomable): Gesture modifier patterns for macOS pinch-zoom and drag-pan.
        3. Kodeco Mind-Map Tutorial: Three-model architecture (Mesh, Node, Edge) with SelectionHandler and EdgeProxy patterns.
        4. objc.io Visual Node Editor Series: macOS-specific focus, selection, and keyboard shortcut patterns for node graph interaction.
    4. Algorithm references (lower relevance for Phase 1):
        1. swift-graphs (github.com/tevelee/swift-graphs): Comprehensive graph algorithms including community detection and centrality. Useful if graph analysis is needed in Phase 2+.
    5. Concept validation:
        1. VoiceTree (github.com/voicetreelab/voicetree): Electron and React implementation of spatial IDE for agent orchestration. No code reuse possible but validates the UX pattern of nodes as files, links as wikilinks, and configurable radius for context injection.

---

| Memory | Grape ForceSimulation Integrated as SPM Dependency | Date: 06 February 2026 | Time: 05:40 AM | Name: Lyra |

    1. Observation:
        1. Grape v1.1.0 provides two separate library products: ForceSimulation (pure physics engine with SIMD acceleration, no UI dependency) and Grape (SwiftUI Canvas rendering layer that depends on ForceSimulation). For our use case, only ForceSimulation is needed because we build our own Canvas rendering with custom node shapes, workspace clustering, and AppState integration.
    2. Decision:
        1. Added Grape as an SPM dependency in Package.swift. The WorkspaceManager target depends on the ForceSimulation product only. The Grape rendering module is not imported. Grape v1.1.0 resolved and full project build passes.
    3. Implication:
        1. We have access to SIMD-accelerated force simulation with Barnes-Hut KDTree, velocity Verlet integration, and composable force types (ManyBody, Link, Center, Collide, Position, Radial) without writing any physics code. The rendering, gesture handling, hit-testing, and viewport transform layers are our responsibility to implement with full control over the visual and interaction design.

---

| Memory | Initial Node Positioning Must Be Viewport-Centered | Date: 06 February 2026 | Time: 05:54 AM | Name: Lyra |

    1. Observation:
        1. First visual test of GraphCanvasView showed all nodes stacked in the top-left corner of the screen. syncGraphFromWorkspaces assigned positions starting at canvas origin (0,0), which maps directly to screen origin (0,0) under identity viewport transform. Ghost terminal nodes at x=0 were half-clipped because the 140pt-wide node extends 70pt to the left of center.
    2. Decision:
        1. Initial node positions must be offset to the center of the canvas viewport, not relative to canvas origin. The sync method should compute positions as offsets from the viewport center (canvasWidth/2, canvasHeight/2). Alternatively, the viewport transform should initialize with a translation that centers the node cluster.
    3. Implication:
        1. Either the sync method needs access to the current viewport size, or the viewport transform initializes with a translation computed from the bounding box of all nodes. The viewport-centering approach is more robust because it works regardless of initial node count or position spread.

---

| Memory | Glass Background NSVisualEffectView Occludes Canvas Grid | Date: 06 February 2026 | Time: 05:54 AM | Name: Lyra |

    1. Observation:
        1. The dot grid rendered at 0.08 opacity in the Canvas was not visible in the first test run. The GlassSidebarBackground NSVisualEffectView renders a full-window blur behind all content, which likely obscures the subtle grid dots.
    2. Decision:
        1. In graph mode, either disable the glass background or increase grid opacity significantly. The graph canvas needs its own solid dark background that does not compete with the NSVisualEffectView blur layer.
    3. Implication:
        1. The ContentView should conditionally apply the glass background only in sidebar mode, or the GraphCanvasView should render its own opaque background layer above the glass.

---

| Memory | syncGraphFromWorkspaces Must Auto-Generate Containment Edges | Date: 06 February 2026 | Time: 05:54 AM | Name: Lyra |

    1. Observation:
        1. First visual test showed no edges between nodes because syncGraphFromWorkspaces only creates GraphNode entries for terminals but does not create GraphEdge entries for workspace-to-terminal containment relationships.
    2. Decision:
        1. syncGraphFromWorkspaces must generate containment edges between nodes that belong to the same workspace. For each workspace with multiple terminal nodes, create containment edges linking them to represent the workspace grouping.
    3. Implication:
        1. Edge auto-generation must be idempotent and avoid duplicating existing edges. The sync method should check for existing containment edges before creating new ones.

---

| Memory | Chain-Topology Containment Edges and Edge Visibility Tuning | Date: 06 February 2026 | Time: 06:30 AM | Name: Lyra |

    1. Observation:
        1. Containment edges were implemented using chain topology: for each workspace with N terminals, N-1 edges connect consecutive terminals (A→B→C→D). This creates a linear chain within the cluster. Initial edge rendering at 1.0 lineWidth and 0.15 opacity was nearly invisible against the dark background. Two iterations of opacity and lineWidth tuning were needed before edges became clearly visible.
    2. Decision:
        1. Final edge parameters: containment edges at 3.0 lineWidth and 0.7 opacity, dependency edges at 3.5 lineWidth and 0.8 opacity. These values produce clearly visible bezier curves that connect terminals within workspace clusters without dominating the visual hierarchy.
    3. Implication:
        1. Edge visibility on dark backgrounds requires significantly higher opacity than initial estimates. The 0.15 starting opacity was insufficient. Production values should start at 0.5 minimum for dark theme canvases.

---

| Memory | Workspace Name Labels on Cluster Boundaries | Date: 06 February 2026 | Time: 06:30 AM | Name: Lyra |

    1. Observation:
        1. Cluster boundaries group terminal nodes by workspace but provide no indication of which workspace they represent. All clusters look identical. The workspace name needs to appear on the cluster boundary to provide spatial context.
    2. Decision:
        1. Render workspace name at the top-left corner of each cluster boundary using 11pt semibold monospaced font at 0.5 opacity. Add 24pt extra top padding to the cluster bounding box to create space for the label above the topmost node. Also changed cluster boundaries to render for single-node workspaces, not just multi-node clusters, so every workspace is labeled.
    3. Implication:
        1. The cluster boundary calculation now includes label space in the bounding box, preventing label overlap with node content. The workspace name lookup uses appState.workspaces to resolve workspaceId to a display name.

---

| Memory | Grape ForceSimulation Package Access Limitation | Date: 06 February 2026 | Time: 07:05 AM | Name: Lyra |

    1. Observation:
        1. Grape v1.1.0 ForceSimulation module declares Kinetics.position as package-level access (@usableFromInline package var). This makes node positions inaccessible from external packages. The UnsafeArray backing store has public subscripts, but the position property itself is gated behind package access. There is no public accessor method or alternative API to read computed positions from outside the Grape package.
    2. Decision:
        1. Instead of forking Grape or using unsafe memory access, a custom force simulation engine was written from scratch (ForceLayoutEngine.swift, approximately 155 lines). The engine implements velocity Verlet integration with ManyBody, Link, Center, and Collide forces using SIMD2<Double> vector math. At 14 nodes, each tick completes in microseconds, making O(n^2) ManyBody computation acceptable without Barnes-Hut optimization.
    3. Implication:
        1. The Grape SPM dependency remains in Package.swift but is not actively imported. If the upstream library changes position to public access in a future release, the custom engine can be replaced. For scale beyond 100 nodes, Barnes-Hut KDTree optimization would need to be added to the custom engine or the Grape access issue resolved.

---

| Memory | Diff Panel Resize Handle Must Be a Sibling View Not a Nested Overlay | Date: 06 February 2026 | Time: 08:16 AM | Name: Lyra |

    1. Observation:
        1. The diff panel resize handle was originally implemented as an .overlay(alignment: .leading) on the DiffPanelView, which was itself an .overlay(alignment: .trailing) on the TerminalContainer. This deeply nested overlay structure caused the drag gesture on the resize handle to fail silently. The handle was visually present but the DragGesture never fired, likely due to gesture priority conflicts between nested overlay layers and the underlying ScrollView inside DiffPanelView.
    2. Decision:
        1. Restructured the layout to use a ZStack(alignment: .trailing) containing the TerminalContainer and an HStack of the resize handle plus DiffPanelView as siblings. The resize handle is now a direct sibling of the DiffPanelView in an HStack, not a nested overlay. Added .padding(.horizontal, 5) to the handle for a 16pt total hit area (6pt visible bar plus 5pt padding on each side).
    3. Implication:
        1. Sibling views in an HStack have clear, non-conflicting gesture boundaries. The resize handle's DragGesture fires reliably because it occupies its own view space rather than competing with the DiffPanelView's content for gesture recognition. This pattern should be used for any interactive elements adjacent to scrollable content.

---

| Memory | macOS Hidden Title Bar Safe Area Requires Careful Padding Balance | Date: 06 February 2026 | Time: 08:16 AM | Name: Lyra |

    1. Observation:
        1. The window uses .windowStyle(.hiddenTitleBar) with .fullSizeContentView and all traffic lights hidden. Despite this, macOS reserves approximately 28pt of safe area at the top for the invisible title bar region. The GlassSidebarBackground uses .ignoresSafeArea() to fill behind this area, but the actual content (sidebar and terminal) respects the safe area, creating a visible gap between the menu bar and the header content.
    2. Decision:
        1. Applied .ignoresSafeArea(.container, edges: .top) on the sidebarModeContent HStack to push content into the hidden title bar area. Combined with .padding(.top, 14) on the TerminalHeader to maintain visual balance. Using the full .ignoresSafeArea() on the body ZStack was too aggressive and caused content to clip behind the system menu bar. The .container variant specifically targets the window's container safe area without affecting the system menu bar boundary.
    3. Implication:
        1. The padding value of 14pt was determined through iterative visual testing across multiple builds. Values below 8pt placed content too close to the menu bar edge. Values above 14pt recreated the original gap. The sidebar header uses .padding(.vertical, 8) which aligns visually with the terminal header at 14pt because the WorkspaceActionPill adds 7pt internal vertical padding.

---

| Memory | Cluster Drag Requires Hit-Test Priority Over Pan | Date: 06 February 2026 | Time: 07:05 AM | Name: Lyra |

    1. Observation:
        1. The canvas pan gesture (DragGesture on background) fires whenever the user drags on empty space. Adding cluster drag required differentiating between three drag targets: individual node (handled by node overlay gesture), cluster boundary area (new cluster drag), and empty canvas (viewport pan). The priority order matters: node drag must take precedence over cluster drag, which must take precedence over pan.
    2. Decision:
        1. The pan gesture handler checks the drag start location against cluster bounding boxes on first touch. If the point falls inside a cluster boundary but NOT on a node (hitTestCluster returns a workspaceId only after hitTestNode returns nil), the drag enters cluster mode. All nodes in that workspace are moved by the delta. If not inside any cluster, normal viewport panning occurs. The force layout is stopped when cluster drag begins to prevent simulation interference.
    3. Implication:
        1. Gesture priority is enforced by layering: node overlays sit above the canvas in the ZStack, so their DragGesture fires first. The canvas-level DragGesture only fires if no node overlay captured the gesture. Within the canvas gesture, the cluster hit-test determines pan vs cluster drag mode.
