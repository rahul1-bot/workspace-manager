# Workspace Manager — memory.md

## Engineering Memory

---

| Memory | Worktree Repository Identity Must Use git-common-dir, Not Worktree Root Path Equality | Date: 07 February 2026 | Time: 07:10 AM | Name: Ghost |

    1. Observation:
        1. A repository-level equality check based only on worktree root paths is insufficient for git worktrees because each worktree has a distinct working directory path.
        2. During sibling worktree comparison tests, cross-repository detection produced false positives even when both paths belonged to the same git repository.
    2. Decision:
        1. Repository identity for worktree comparison must be validated using `git rev-parse --git-common-dir` for source, target, and expected root contexts.
        2. Path normalization must include symlink resolution to avoid `/var` versus `/private/var` divergence on macOS.
    3. Implication:
        1. Any future worktree orchestration logic that needs repository membership checks must compare git common directories, not directory names.
        2. This rule prevents correctness regressions when worktrees are placed outside the repository parent folder.

---

| Memory | Worktree Create UI Must Be Overlay-Scoped and Decouple Spinner State from Catalog Refresh | Date: 07 February 2026 | Time: 07:10 AM | Name: Ghost |

    1. Observation:
        1. Rendering the New Worktree flow as a SwiftUI `.sheet` created material inconsistencies versus command palette and commit overlays.
        2. Reusing a global loading flag (`isWorktreeLoading`) for both discovery refresh and create flow made the Create button spinner appear stuck in unrelated scenarios.
    2. Decision:
        1. Worktree creation UI is implemented as an in-window overlay in ContentView, using the same dark glass style as command palette and commit sheet.
        2. Create button spinner is controlled by local create-flow state in ContentView, while catalog refresh keeps a separate global loading state.
    3. Implication:
        1. Overlay consistency and keyboard escape behavior remain deterministic.
        2. UI loading indicators now reflect real operation intent, reducing confusion during long work sessions.

---

| Memory | macOS charactersIgnoringModifiers Preserves Shift for Punctuation Keys | Date: 06 February 2026 | Time: 11:19 PM | Name: Lyra |

    1. Observation:
        1. Apple's NSEvent.charactersIgnoringModifiers strips Command and Option modifiers but preserves Shift. This means Shift+/ delivers "?" not "/", Shift+[ delivers "{", Shift+] delivers "}", Shift+, delivers "<", Shift+. delivers ">". The router's .lowercased() normalization does not affect these characters.
    2. Decision:
        1. All keyboard shortcut routes involving Shift+punctuation must match the shifted character, not the base key character. Examples: Cmd+Shift+/ matches char == "?", Cmd+Shift+[ matches char == "{", Cmd+Shift+] matches char == "}". A regression test exists for each of these.
    3. Implication:
        1. When adding any new shortcut involving Shift+punctuation, determine the actual character macOS delivers and match against that. The keyCode-based approach is an alternative but inconsistent with the existing router pattern.

---

| Memory | SwiftUI Conditional View Builders Destroy NSViewRepresentable State | Date: 06 February 2026 | Time: 10:07 AM | Name: Lyra |

    1. Observation:
        1. A switch or if/else inside a SwiftUI body is a conditional view builder. When the active case changes, the previous case's views are removed from the hierarchy and recreated. For NSViewRepresentable types (terminal emulators, Metal surfaces, PDFView), removal triggers NSView deallocation, killing shell processes and GPU state.
    2. Decision:
        1. Use persistent overlay pattern: keep NSViewRepresentable views always present, control visibility via .opacity(0) and .allowsHitTesting(false). The TerminalContainer's isSelected check includes a view mode guard to prevent hidden terminals from stealing focus.
    3. Implication:
        1. Any SwiftUI view wrapping a stateful NSView must NEVER be placed inside a conditional view builder if its state should survive. This is a fundamental SwiftUI architectural constraint for AppKit-backed views.

---

| Memory | Dark Liquid Glass Pattern for All Overlays | Date: 06 February 2026 | Time: 09:52 AM | Name: Lyra |

    1. Observation:
        1. Using .withinWindow blending mode produces inconsistent brightness depending on window content behind the overlay. Different overlays appeared visually mismatched despite using the same material.
    2. Decision:
        1. Standardized background stack: ZStack of VisualEffectBackground(.hudWindow, .behindWindow) plus Color.black.opacity(0.45). Chrome opacities: 0.12 for outer strokes, 0.08 for dividers, 0.04-0.06 for fills. Esc badge: caption2 font, white.opacity(0.55), 0.08 background, 6pt corner radius. Applied to command palette, commit sheet, shortcuts help, and diff panel.
    3. Implication:
        1. Any new overlay must use this exact background stack. The .behindWindow mode composites against the desktop wallpaper for consistent darkness regardless of window content.

---

| Memory | NSView deinit Runs on Arbitrary Threads — GPU Resources Need Main-Thread Dispatch | Date: 06 February 2026 | Time: 11:24 PM | Name: Lyra |

    1. Observation:
        1. NSView deinit can execute on any thread when the last strong reference is released from a background context (autorelease pool drains, Task captures, NotificationCenter observer removal). For NSViews wrapping GPU resources (Metal surfaces, libghostty), background-thread deallocation corrupts pipeline state.
    2. Decision:
        1. Two-layer cleanup: primary path via dismantleNSView (SwiftUI-guaranteed main thread) calls releaseSurface() which nils and frees. Safety-net in deinit captures pointers by value into DispatchQueue.main.async if not on main thread.
    3. Implication:
        1. Any NSViewRepresentable holding GPU resources, file handles, or thread-sensitive C library objects must implement dismantleNSView. Relying solely on deinit is unsafe.

---

| Memory | ghostty_surface_complete_clipboard_request Parameter Order | Date: 06 February 2026 | Time: 12:10 PM | Name: Lyra |

    1. Observation:
        1. Cmd+V crashed the app because ghostty_surface_complete_clipboard_request was called with wrong parameter order. The function signature is (surface, text, state, confirmed). Surface-specific callbacks in libghostty receive surfaceConfig.userdata (the NSView pointer), not the runtime config userdata (the app manager pointer).
    2. Decision:
        1. surfaceConfig.userdata set to Unmanaged.passRetained(self).toOpaque() per surface with balanced release in releaseSurface(). read_clipboard_cb extracts NSView from userdata, gets surface pointer, calls completion synchronously with correct parameter order. CommandGroup(replacing: .pasteboard) {} added as defense-in-depth.
    3. Implication:
        1. Any future libghostty callback needing the surface pointer must extract it from userdata following this pattern. The official Ghostty app calls clipboard completion synchronously without re-entrance issues.

---

| Memory | Lifting View State to AppState Survives View Lifecycle Events | Date: 06 February 2026 | Time: 10:20 PM | Name: Lyra |

    1. Observation:
        1. Local @State in GraphCanvasView was lost on view mode toggle because the view is inside a conditional builder. Viewport zoom, pan, and selection all reset.
    2. Decision:
        1. Moved to @Published on AppState (graphViewport, selectedGraphNodeId). Added ViewportTransform serialization bridge for persistence through graph-state.json.
    3. Implication:
        1. Any interactive state that must survive conditional view toggling should be lifted to a parent ObservableObject. Local @State is only safe for state that can be reset.

---

| Memory | buttonStyle(.plain) Requires contentShape for Transparent Hit Areas | Date: 06 February 2026 | Time: 09:44 AM | Name: Lyra |

    1. Observation:
        1. Plain button style only registers hit testing on opaque pixels. Transparent Circle fills made radio buttons nearly untappable.
    2. Decision:
        1. Added .contentShape(Rectangle()) on the Button label HStack plus Spacer() for full-width rows.
    3. Implication:
        1. Any Button with .buttonStyle(.plain) containing transparent content MUST include .contentShape(Rectangle()).

---

| Memory | Graph State and App Config Are Separate Persistence Concerns | Date: 06 February 2026 | Time: 05:15 AM | Name: Lyra |

    1. Observation:
        1. config.toml stores user preferences that change infrequently. Graph state (positions, zoom, edges) changes continuously through drag interactions. Mixing them creates noisy diffs and risks config corruption.
    2. Decision:
        1. Graph state persists to graph-state.json. Workspace and terminal UUIDs link entries to config.toml entities.
    3. Implication:
        1. config.toml remains clean and human-editable. Graph state handles high-frequency updates independently.

---

| Memory | Cluster Drag Requires Hit-Test Priority Over Pan | Date: 06 February 2026 | Time: 07:05 AM | Name: Lyra |

    1. Observation:
        1. Three drag targets with priority: node drag (overlay gesture, highest), cluster drag (canvas gesture with hitTestCluster), viewport pan (canvas gesture fallback).
    2. Decision:
        1. Node overlays sit above canvas in ZStack so their gesture fires first. Canvas-level DragGesture checks hitTestCluster on start to differentiate cluster drag from pan. Force layout stops during cluster drag.
    3. Implication:
        1. Gesture priority is enforced by view layering and hit-test checks within the canvas gesture handler.

---

| Memory | Avoid didSet for Expensive Side Effects — Use Explicit Call Sites | Date: 07 February 2026 | Time: 12:52 AM | Name: Lyra |

    1. Observation:
        1. @Published properties with didSet observers that trigger expensive operations (subprocess spawning, network calls) multiply when multiple properties are set in sequence. selectTerminal() setting two properties with didSet spawned 2 concurrent git subprocess chains per call. Workspace navigation added a third.
    2. Decision:
        1. Removed didSet observers from selectedWorkspaceId and selectedTerminalId. Added a single explicit refreshGitUIState() call at the end of selectTerminal() and in all paths that nil out selection (removeWorkspace, removeTerminal, closeSelectedTerminal, workspace navigation empty cases). Added Task cancellation tracking to prevent overlapping calls.
    3. Implication:
        1. Any @Published property whose didSet triggers an expensive operation should instead use explicit call sites at the end of the mutation method. This prevents N-way multiplication when multiple properties change in sequence. Combine this with cancellation tracking (cancel-before-launch pattern) to handle rapid invocations.

---

| Memory | Command Palette Keyboard Navigation via NSEvent Local Monitor | Date: 06 February 2026 | Time: 09:44 AM | Name: Lyra |

    1. Observation:
        1. SwiftUI has no built-in keyboard navigation for custom list views with a focused TextField.
    2. Decision:
        1. NSEvent.addLocalMonitorForEvents intercepts arrow keys (125, 126) and Enter (36). Registered on onAppear, removed on onDisappear. LIFO order means it receives events before ContentView's global monitor.
    3. Implication:
        1. The monitor consumes only arrow keys and Enter (returning nil). All other keys propagate to TextField and shortcut router. Escape handling remains in ContentView's router.

---

| Memory | Worktree Destination Must Be Policy-Driven, Not Manually Typed | Date: 07 February 2026 | Time: 07:30 AM | Name: Ghost |

    1. Observation:
        1. The first worktree-create overlay required manual destination path input. This made the flow cognitively expensive and error-prone because users had to leave the task to construct long filesystem paths repeatedly.
    2. Decision:
        1. Destination input was removed from the overlay. The path is now always computed from branch name using a deterministic policy at .wt/<repo>/<branch-slug> under the repository parent. The create service also ensures parent folders exist before running git worktree add.
    3. Implication:
        1. Worktree creation now has fewer variables, faster operator throughput, and consistent filesystem layout across sessions and collaborators on the same repository structure.

---

| Memory | Worktree Create Must Not Depend on Preloaded Catalog State | Date: 07 February 2026 | Time: 07:45 AM | Name: Ghost |

    1. Observation:
        1. The create sheet could be opened before worktree discovery completed, leaving worktreeCatalog nil at submit time. This generated a false-negative error even when terminal context was valid and git-backed.
    2. Decision:
        1. Worktree create now resolves repository context lazily at submit time through worktreeService.catalog(for: selectedActionTargetURL) when catalog is missing. New-worktree actions across shortcut, action bar, sidebar, and command palette were unified through a single AppState present method that triggers immediate refresh.
    3. Implication:
        1. Create flow no longer relies on timing luck between UI open and async catalog refresh. This removes a high-friction failure mode during rapid branch/worktree orchestration sessions.

---

| Memory | UI Loading Indicators Must Be Bound to Awaited Completion Paths | Date: 07 February 2026 | Time: 07:55 AM | Name: Ghost |

    1. Observation:
        1. The worktree create spinner could remain active because the UI started loading before calling an AppState method that internally spawned its own Task and returned immediately. The view could not reliably infer completion from that fire-and-forget boundary.
    2. Decision:
        1. Converted createWorktreeFromSelection to async throws and made the overlay submit path await it directly on MainActor. Spinner reset is now explicit in both success and failure branches in the same control flow.
    3. Implication:
        1. Long-running create operations remain visible, but terminal states are deterministic. Stuck loading indicators caused by hidden async boundaries are prevented for this flow.

---

| Memory | Full Worktree Catalog Rebuild Is Too Expensive for Create Critical Path | Date: 07 February 2026 | Time: 08:09 AM | Name: Ghost |

    1. Observation:
        1. Terminal-native git worktree add completes in under a second, but the app create flow remained slow or appeared stuck because it performed a full worktree catalog rebuild (including per-worktree status/divergence probes) before returning control to the sheet.
    2. Decision:
        1. Reworked create path to return immediately after successful git worktree add plus descriptor extraction for only the new worktree. Workspace registration and linking for the created path remain in the critical path; full catalog refresh moved to post-switch asynchronous refresh.
    3. Implication:
        1. Create latency now tracks real git worktree add cost instead of cross-worktree metadata fanout cost. This aligns UX with terminal expectations for fast branch/worktree operations.

---

| Memory | Auto-Managed Worktree Nodes Must Not Pollute Primary Workspace Navigation | Date: 07 February 2026 | Time: 08:17 AM | Name: Ghost |

    1. Observation:
        1. The main WORKSPACES sidebar accumulated many wt-prefixed nodes as users switched branches and created worktrees. This duplicated navigation because the same entities are already represented in WORKTREES (CURRENT REPO), degrading clarity and making the sidebar look corrupted.
    2. Decision:
        1. Added explicit auto-managed workspace tracking based on worktree-state.json links and filtered auto-managed entries from the primary workspace list. Selected auto-managed workspace remains visible to avoid context loss during active interaction.
    3. Implication:
        1. Sidebar now preserves a clean separation: manual workspace topology in WORKSPACES and git worktree topology in WORKTREES. This avoids runaway node growth without losing orchestration capability.

---

| Memory | Legacy Worktree Metadata Requires Heuristic Backstop for Stable UI | Date: 07 February 2026 | Time: 05:18 PM | Name: Ghost |

    1. Observation:
        1. Historical runs produced workspace entries with auto-managed semantics (`wt ...` names and `.wt/` paths) but missing or incorrect `isAutoManaged` flags in persisted worktree-state metadata. ID-only filtering therefore leaked these entries into the primary WORKSPACES list.
    2. Decision:
        1. Added heuristic classification backstop for workspace filtering and reconciliation. A workspace is treated as auto-managed if metadata marks it so, or if its name/path matches worktree-generation conventions (`wt` prefix or `.wt/` location).
    3. Implication:
        1. UI stability no longer depends on perfect historical metadata. Legacy repositories can converge toward clean sidebar behavior without manual state cleanup.

---

| Memory | Reference-Driven Design Must Stay Non-Copy and Decision-Oriented | Date: 07 February 2026 | Time: 05:18 PM | Name: Ghost |

    1. Observation:
        1. Lyra branch contains useful patterns (task-scoped create sheet state, branch metadata overlay, lightweight worktree metadata service) but follows a different architecture than this branch.
    2. Decision:
        1. Used Lyra implementation as comparative reference only. Adopted principles (fast path, explicit state ownership, minimal critical path) without transplanting code verbatim. Wrote local problem framing doc to lock assumptions and acceptance criteria for iterative work.
    3. Implication:
        1. We preserve codebase coherence while still learning from parallel branch experiments. This reduces architectural drift and prevents copy-paste debt.

---

| Memory | Branch Context Should Be Workspace-Scoped and Rendered at Terminal Touchpoints | Date: 07 February 2026 | Time: 06:12 PM | Name: Ghost |

    1. Observation:
        1. The branch metadata service already resolves repository branch and dirty status from workspace paths, but no UI consumed this state. Operators therefore could not see branch context while scanning terminal rows, despite this being a core need for multi-branch sessions.
    2. Decision:
        1. Treat branch context as workspace-scoped metadata and surface it in the two highest-frequency terminal touchpoints: sidebar terminal rows and active terminal header.
        2. Render branch as compact `<branch-name>` text with `*` dirty marker so signal remains high without widening list layout.
    3. Implication:
        1. Branch awareness is now immediate during terminal selection and active work, reducing branch confusion in long-running orchestration sessions.

---

| Memory | PDF Flow Needs Visible Action-Bar Entry, Not Shortcut-Only Discovery | Date: 07 February 2026 | Time: 06:12 PM | Name: Ghost |

    1. Observation:
        1. PDF panel capability existed behind shortcut and command palette routes, but not as an explicit action-bar control. For paper-reading workflows this increased interaction friction and made discoverability dependent on memorized commands.
    2. Decision:
        1. Added a dedicated `Documents` pill to WorkspaceActionBar and routed it to the existing `togglePDFPanel()` flow instead of introducing new panel state paths.
    3. Implication:
        1. Document access is now visible and one-click from the primary terminal command strip, aligning with the app mission for faster context switching across code and papers.

---

| Memory | Documents Toggle and Open-File Actions Must Stay Decoupled | Date: 07 February 2026 | Time: 06:28 PM | Name: Ghost |

    1. Observation:
        1. Routing the `Documents` action through the file-picker path forced Finder to reopen every time the user reopened the panel, even when PDF tabs were already loaded. This violated expected toggle semantics and added unnecessary interruption to reading workflows.
    2. Decision:
        1. `togglePDFPanel()` now only controls panel visibility and does not open Finder.
        2. Open-file behavior is handled through explicit paths only: command palette `Open PDF` and shortcut `⇧⌘O`.
        3. `⇧⌘P` is reserved for toggle semantics and documented accordingly in the shortcuts overlay.
    3. Implication:
        1. Operators can hide/show PDF context without losing loaded tabs or being forced into picker dialogs.
        2. Shortcut behavior is now clear by intent: one for visibility, one for file acquisition.

---

| Memory | Character-Based Shortcut Matching Needs Keycode Backstop for Layout Robustness | Date: 07 February 2026 | Time: 06:44 PM | Name: Ghost |

    1. Observation:
        1. Shortcut routing is character-driven for most commands. On non-US layouts or IME variation, shifted-character values can drift while physical intent remains the same key position.
    2. Decision:
        1. Added physical-keycode fallback matching for PDF commands: `⇧⌘P` toggle (`keyCode 35`) and `⇧⌘O` open file (`keyCode 31`) in addition to character checks.
        2. Kept `⌘O` Finder mapping guarded with `!shift` to avoid overlap with `⇧⌘O`.
    3. Implication:
        1. PDF keymaps remain stable across keyboard-layout differences while preserving existing Finder and workspace-open behavior.

---

| Memory | Document Sessions Must Be Terminal-Scoped, Not Global | Date: 07 February 2026 | Time: 06:56 PM | Name: Ghost |

    1. Observation:
        1. A single global `pdfPanelState` causes tab bleed across terminals. When users switch from one terminal context to another, unrelated PDFs remain visible, collapsing context boundaries and reducing trust in workspace isolation.
    2. Decision:
        1. Added terminal-scoped session storage for PDF panel state keyed by terminal ID.
        2. Terminal selection flow now persists the previous terminal's PDF state and restores the target terminal's PDF state.
        3. Terminal-removal and empty-selection paths clear or reset PDF state to prevent stale session resurrection.
    3. Implication:
        1. Each terminal now behaves like an independent document workspace with its own tabs, active tab, and visibility lifecycle.
        2. Context switching across terminals preserves reading state without leaking documents into unrelated tasks.

---

| Memory | Batch PDF Intake and README Synchronization Are Core UX Hygiene | Date: 07 February 2026 | Time: 07:05 PM | Name: Ghost |

    1. Observation:
        1. Single-file picker flow forces repetitive open operations when users need multiple assignment/paper PDFs together.
        2. README drifted behind implementation and still described older capability boundaries and keymaps.
    2. Decision:
        1. Enabled multi-selection in PDF picker and routed all selected URLs through a shared batch-open method.
        2. Updated README capability, keybinding, CI-count, and roadmap sections to reflect current shipped behavior.
    3. Implication:
        1. Document setup throughput improves for research workflows where 2-5 PDFs are opened together.
        2. External collaborators now read accurate product behavior and shortcut contracts from repository documentation.
