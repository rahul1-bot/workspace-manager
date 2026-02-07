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
