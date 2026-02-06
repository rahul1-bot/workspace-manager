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
        1. ✅ Integrate ForceSimulation to replace static grid layout with force-directed spatial positioning.
        2. Phase 1C interaction features: user-drawn edge creation, improved focus and unfocus flow.

---

| Progress Todo | Phase 1D and 1C — Force Layout, Cluster Drag, Zoom Controls, Minimap | Date: 06 February 2026 | Time: 07:05 AM | Name: Lyra |

    1. Delivered and compiling:
        1. ✅ Custom force-directed layout engine (ForceLayoutEngine.swift). Implements velocity Verlet integration with four composable forces: ManyBody repulsion (O(n^2), strength -600), Link attraction (stiffness 0.15, rest length 200), Center force (strength 0.05), and Collide force (radius 90). Uses SIMD2<Double> for all vector math. Supports pinned nodes excluded from force calculation. Alpha decay convergence with configurable alphaMin threshold.
        2. ✅ Animated force layout in AppState. Task-based 60fps tick loop runs ForceLayoutEngine incrementally, reading positions each frame and updating graphDocument.nodes for smooth animated node spreading. Auto-triggers when entering graph mode via toggleViewMode. Stops on node drag to prevent simulation fighting user input. Maximum 300 ticks before auto-stop.
        3. ✅ Re-run force layout (Cmd+L). Unpins all nodes and restarts the force simulation, causing the graph to reorganize from its current positions.
        4. ✅ Cluster drag. Dragging on a workspace cluster boundary (not on an individual node) moves all terminal nodes in that workspace as a group. Hit-tests cluster bounding boxes in canvas coordinate space. All moved nodes pinned after drag ends. Stops force layout during drag.
        5. ✅ Keyboard zoom (Cmd+Plus zoom in, Cmd+Minus zoom out). Step zoom at 1.25x factor per press. Routed through ShortcutCommand and NotificationCenter to GraphCanvasView.
        6. ✅ Zoom-to-fit (Cmd+0). Computes bounding box of all nodes with 80pt padding, calculates scale to fit within viewport, and centers the view. Accessible via keyboard shortcut.
        7. ✅ Minimap overlay in bottom-right corner. 160x100pt Canvas renders all nodes as white dots, edges as thin lines, and the current viewport as a white rectangle outline. Dark semi-transparent background with rounded corners and subtle border.
        8. ✅ Pan and zoom sensitivity dampening. Pan at 55% sensitivity, zoom at 30% dampening for smooth controllable navigation.
        9. ✅ ShortcutContext extended with isGraphMode flag. Graph-specific shortcuts (zoom, layout) only fire in graph mode.
        10. ✅ swift build passes, swift test passes (41 tests, 0 failures).
    2. Architecture note on Grape ForceSimulation:
        1. Grape v1.1.0 ForceSimulation module exposes Kinetics.position as package-level access, making it inaccessible from external packages. Rather than forking Grape, a custom force simulation engine was written (approximately 155 lines) using SIMD2<Double> vector math. At 14 nodes this runs in microseconds per tick. The Grape SPM dependency remains in Package.swift for potential future use if the access level issue is resolved upstream.
    3. Remaining for next session:
        1. Phase 1C interaction features: user-drawn edge creation, improved focus and unfocus flow.
        2. Performance validation at 50+ nodes.
        3. Scroll wheel zoom (Cmd+scroll for zoom, currently only pinch and keyboard zoom supported).

---

| Progress Todo | UI Polish — Header Alignment, Diff Panel Resize, Action Bar Cleanup | Date: 06 February 2026 | Time: 08:16 AM | Name: Lyra |

    1. Delivered and compiling:
        1. ✅ Terminal header button vertical alignment. Reduced TerminalHeader top padding from 6pt to 14pt combined with .ignoresSafeArea(.container, edges: .top) on sidebarModeContent to push content into the hidden title bar area. Iteratively tested values 0, 2, 4, 14pt across multiple builds to find the visual sweet spot.
        2. ✅ Action buttons hidden when diff panel is open. Wrapped WorkspaceActionBar in conditional check for gitPanelState.isPresented. The Open, Commit, and Toggle diff panel buttons no longer bleed through behind the diff panel during resize operations.
        3. ✅ Diff panel resize handle restructured. Replaced nested overlay layout (overlay on overlay) with sibling HStack layout (handle and DiffPanelView side by side in a ZStack). Added .padding(.horizontal, 5) for a 16pt total hit area. Drag gesture now fires reliably.
        4. ✅ Diff panel resize math simplified. Removed stepping quantization (resizeStepRatio, steppedRatio, rounded()), dead zone guard, and 90fps rate limiter. Now uses direct continuous ratio calculation clamped to bounds. Eliminated lastDiffResizeUpdateTime and resizeStepRatio state.
        5. ✅ Removed vertical divider line between Commit and Toggle diff panel buttons in WorkspaceActionBar.
        6. ✅ swift build passes, swift test passes (54 tests, 0 failures).
    2. Remaining for next session:
        1. ✅ Investigate and fix diff panel scroll stuttering during content viewing.
        2. Visual improvements to diff panel rendering quality.

---

| Progress Todo | Diff Panel Scroll Stutter Fix | Date: 06 February 2026 | Time: 08:31 AM | Name: Lyra |

    1. Delivered and compiling:
        1. ✅ Removed nested horizontal ScrollViews from DiffFileCardView.swift. Each metadataBlock and hunkBlock(for:) previously wrapped content in its own ScrollView(.horizontal), creating approximately 60 nested scroll containers for a typical multi-file diff. Removed all per-block horizontal ScrollViews and added a single ScrollView(.horizontal, showsIndicators: false) wrapping the entire contentView. This reduces scroll container count from O(files * hunks) to O(files).
        2. ✅ Cached keyword sets in DiffSyntaxHighlightingService.swift. Replaced the keywordSet(for:) switch statement that allocated a new Set<String> with 30-50 items on every tokenize() call with a private static let keywordSets dictionary. All keyword sets are now computed once at static initialization time. TypeScript given its own explicit dictionary entry rather than relying on combined switch case.
        3. ✅ DiffCodeRowView.swift confirmed already optimized from prior session. renderedCodeText uses AttributedString concatenation (not Text.reduce). taskIdentity uses only line.id and fileExtension (not codeText).
        4. ✅ swift build passes, swift test passes (54 tests, 0 failures).
    2. Remaining for next session:
        1. ✅ Manual verification of scroll smoothness with large diffs.
        2. ✅ Visual improvements to diff panel rendering quality.

---

| Progress Todo | Diff Panel Text Wrapping and Alignment Fix | Date: 06 February 2026 | Time: 09:05 AM | Name: Lyra |

    1. Delivered and compiling:
        1. ✅ Removed .fixedSize(horizontal: true, vertical: false) from renderedCodeText in codeRow and from raw text in metadataRow in DiffCodeRowView.swift. Code and metadata text now wraps within the available panel width instead of extending infinitely to the right. Long lines wrap to the next visual line while the line number stays at the top of the row.
        2. ✅ Changed HStack alignment from default .center to .top in both codeRow and metadataRow in DiffCodeRowView.swift. Line numbers and markers now align to the top of multi-line wrapped content instead of vertically centering against wrapped text.
        3. ✅ Removed horizontal ScrollView from contentView in DiffFileCardView.swift. Content wraps within the panel width rather than scrolling horizontally. The per-block horizontal ScrollViews were already removed in the prior fix.
        4. ✅ Added maxWidth: .infinity to DiffCodeRowView body frame and DiffFileCardView card body frame. All rows and cards now fill the full available width consistently, preventing variable-width rows from causing alignment shifts.
        5. ✅ Changed all VStack alignment to .leading in DiffFileCardView.swift: card body VStack, contentView VStack, metadataBlock VStack, and hunkBlock VStack. All content is now left-aligned, ensuring line numbers remain in a fixed column regardless of content width variations.
        6. ✅ swift build passes. Visually verified by Rahul: line numbers are properly aligned in a fixed column, code text wraps correctly within the panel, no staircase displacement pattern.

---

| Progress Todo | Commit Sheet Redesign and Command Palette Keyboard Navigation | Date: 06 February 2026 | Time: 09:44 AM | Name: Lyra |

    1. Delivered and compiling:
        1. ✅ Redesigned CommitSheetView to match command palette dark glass aesthetic. Replaced bright white glass with dark translucent glass using VisualEffectBackground(.hudWindow, .behindWindow) plus Color.black.opacity(0.45) dark backing layer. Reduced corner radius from 16 to 12, border opacity from 0.14 to 0.12, matching command palette visual constants.
        2. ✅ Restructured commit sheet layout from flat VStack with padding to sectioned VStack(spacing: 0) with explicit Divider().overlay(Color.white.opacity(0.08)) between logical sections (header, info, message, next steps, footer). All sections use .padding(.horizontal, 14) and .padding(.vertical, 10-12) matching command palette spacing.
        3. ✅ Added Esc key badge to commit sheet header, identical to command palette (caption2 font, 0.55 opacity, 0.08 background, 6pt corner radius).
        4. ✅ Replaced bright white Continue button with dark translucent pill. Background changed from solid white to Color.white.opacity(0.10) with 0.15 border stroke. Text changed from black to white at 0.9 opacity.
        5. ✅ Replaced system Picker with custom radio buttons for Next Steps section. Each option is a Button with .plain style containing a Circle indicator (10x10pt, filled when selected, stroked when not) and Text label. Added Spacer() for full-width rows, .padding(.vertical, 4) for larger tap targets, and .contentShape(Rectangle()) to ensure the entire row is clickable regardless of transparent areas.
        6. ✅ Darkened commit message text field from Color.white.opacity(0.06) to Color.black.opacity(0.25) with reduced border opacity (0.08) for recessed appearance.
        7. ✅ Added parent VStack alignment: .leading to fix centered Next Steps section. All content now left-aligns consistently.
        8. ✅ Darkened command palette glass to match commit sheet. Changed CommandPaletteView background from .withinWindow to .behindWindow blending mode and added Color.black.opacity(0.45) dark backing layer in a ZStack, identical to commit sheet.
        9. ✅ Implemented keyboard navigation in command palette. Added @State selectedIndex tracking, NSEvent.addLocalMonitorForEvents intercepting down arrow (keyCode 125), up arrow (keyCode 126), and Enter (keyCode 36). Down arrow moves selection down clamped to last item, up arrow moves up clamped to first item, Enter activates highlighted item. All other keys pass through to the search TextField.
        10. ✅ Added visual selection highlight. Selected row gets RoundedRectangle fill at Color.white.opacity(0.10) with 6pt corner radius and 4pt horizontal padding. Unselected rows have transparent background.
        11. ✅ Added ScrollViewReader with auto-scroll. When selectedIndex changes, proxy.scrollTo scrolls to the selected entry ID with .center anchor, keeping the highlighted item visible during keyboard navigation.
        12. ✅ Selection resets to index 0 when search query changes via .onChange(of: query).
        13. ✅ Event monitor lifecycle managed: setupPaletteKeyMonitor on .onAppear, removePaletteKeyMonitor on .onDisappear.
        14. ✅ Updated footer text from "Enter selects first match" to "↑↓ navigate  ⏎ select".
        15. ✅ Added .contentShape(Rectangle()) on command palette row labels for proper hit testing.
        16. ✅ swift build passes, swift test passes (54 tests, 0 failures).
    2. Files modified:
        1. Sources/WorkspaceManager/Views/CommitSheetView.swift — complete visual redesign
        2. Sources/WorkspaceManager/Views/Overlays.swift — CommandPaletteView dark glass and keyboard navigation

---

| Progress Todo | Diff Viewer Dark Glass Visual Upgrade | Date: 06 February 2026 | Time: 09:52 AM | Name: Lyra |

    1. Delivered and compiling:
        1. ✅ Applied dark glass background to DiffPanelView. Replaced subtle LinearGradient overlay (0.035 to 0.018 opacity) with Color.black.opacity(0.45) matching the commit sheet and command palette dark glass pattern. The VisualEffectBackground(.hudWindow, .behindWindow) base layer is retained for frosted glass texture.
        2. ✅ Updated DiffChromeStyle constants for visual consistency. Outer stroke increased from 0.07 to 0.12, divider from 0.05 to 0.08, header fill from 0.01 to 0.04, summary fill from 0.01 to 0.06, content stroke from 0.06 to 0.08. All values now match the visual language established by the commit sheet and command palette.
        3. ✅ Updated DiffFileCardView CardChromeStyle constants. Card fill increased from 0.012 to 0.04, card stroke from 0.06 to 0.10, header fill from 0.014 to 0.06. Cards are now visually distinct against the darker panel background.
        4. ✅ Darkened resizing state. Resizing fill increased from 0.14 to 0.45. Placeholder skeleton bars reduced from 0.08 to 0.06 opacity with background from 0.35 to 0.25 for better contrast in the darker context.
        5. ✅ swift build passes, swift test passes (54 tests, 0 failures).
    2. Files modified:
        1. Sources/WorkspaceManager/Views/DiffPanelView.swift — dark glass background and DiffChromeStyle update
        2. Sources/WorkspaceManager/Views/DiffFileCardView.swift — CardChromeStyle update

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
