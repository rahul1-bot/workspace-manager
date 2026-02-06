import SwiftUI
import AppKit
import GhosttyKit
import Darwin
import os

// MARK: - Ghostty App Singleton
/// Manages the global ghostty_app_t instance
class GhosttyAppManager {
    static let shared = GhosttyAppManager()

    private(set) var app: ghostty_app_t?
    private(set) var config: ghostty_config_t?
    private var initialized = false
    private struct TickState {
        var scheduled: Bool = false
        var needsAnotherTick: Bool = false
    }
    private struct SurfaceRegistryState {
        var terminalIDBySurfaceKey: [UInt: UUID] = [:]
    }
    private let tickState = OSAllocatedUnfairLock(initialState: TickState())
    private let surfaceRegistry = OSAllocatedUnfairLock(initialState: SurfaceRegistryState())

    private init() {}

    /// Initialize libghostty - call once at app startup
    func initialize() {
        guard !initialized else {
            AppLogger.ghostty.debug("app manager already initialized")
            return
        }
        initialized = true
        AppLogger.ghostty.info("starting ghostty initialization")

        // Initialize the library
        let result = ghostty_init(0, nil)
        guard result == 0 else {
            AppLogger.ghostty.error("ghostty_init failed code=\(result, privacy: .public)")
            return
        }
        AppLogger.ghostty.debug("ghostty_init succeeded")

        // Create configuration
        guard let cfg = ghostty_config_new() else {
            AppLogger.ghostty.error("ghostty_config_new failed")
            return
        }
        self.config = cfg
        AppLogger.ghostty.debug("ghostty config created")

        // Load default config files
        ghostty_config_load_default_files(cfg)
        ghostty_config_finalize(cfg)
        AppLogger.ghostty.debug("ghostty config finalized")

        // Create runtime config with callbacks
        var runtimeConfig = ghostty_runtime_config_s()
        runtimeConfig.userdata = Unmanaged.passUnretained(self).toOpaque()
        runtimeConfig.supports_selection_clipboard = true
        runtimeConfig.wakeup_cb = { userdata in
            InputEventRecorder.shared.record(
                kind: .ghosttyCallback,
                keyCode: nil,
                modifierFlags: 0,
                details: "wakeup_cb"
            )
            GhosttyAppManager.shared.requestTick()
        }
        runtimeConfig.action_cb = { _, target, action in
            GhosttyAppManager.shared.handleAction(action, target: target)
            return true
        }
        runtimeConfig.read_clipboard_cb = { userdata, location, state in
            guard let userdata = userdata, let state = state else { return }
            let nsView = Unmanaged<GhosttySurfaceNSView>.fromOpaque(userdata).takeUnretainedValue()
            guard let surface = nsView.surface else { return }
            GhosttyClipboardBridge.shared.completeReadRequest(surface: surface, state: state, location: location)
        }
        runtimeConfig.confirm_read_clipboard_cb = nil
        runtimeConfig.write_clipboard_cb = { (userdata: UnsafeMutableRawPointer?, location: ghostty_clipboard_e, content: UnsafePointer<ghostty_clipboard_content_s>?, len: Int, confirm: Bool) in
            guard let content = content, len > 0 else { return }
            GhosttyClipboardBridge.shared.writeClipboard(contents: content, count: len, location: location, confirm: confirm)
        }
        runtimeConfig.close_surface_cb = { userdata, processAlive in
            // Handle surface close
        }

        // Create the app
        guard let app = ghostty_app_new(&runtimeConfig, cfg) else {
            AppLogger.ghostty.error("ghostty_app_new failed")
            return
        }
        self.app = app

        AppLogger.ghostty.info("ghostty initialized")
    }

    /// Process pending work - call regularly
    func tick() {
        guard let app = app else { return }
        ghostty_app_tick(app)
    }

    /// Coalesce wakeups so multiple surfaces don't spam the main thread.
    func requestTick() {
        let shouldSchedule = tickState.withLock { state in
            if state.scheduled {
                state.needsAnotherTick = true
                return false
            }
            state.scheduled = true
            return true
        }

        guard shouldSchedule else { return }
        DispatchQueue.main.async { [weak self] in
            self?.runTick()
        }
    }

    private func runTick() {
        tick()

        let shouldReschedule = tickState.withLock { state in
            if state.needsAnotherTick {
                state.needsAnotherTick = false
                return true
            }
            state.scheduled = false
            return false
        }

        if shouldReschedule {
            DispatchQueue.main.async { [weak self] in
                self?.runTick()
            }
        }
    }

    func registerSurface(_ surface: ghostty_surface_t, terminalID: UUID) {
        let key = surfaceKey(surface)
        surfaceRegistry.withLock { state in
            state.terminalIDBySurfaceKey[key] = terminalID
        }
    }

    func unregisterSurface(_ surface: ghostty_surface_t) {
        let key = surfaceKey(surface)
        _ = surfaceRegistry.withLock { state in
            state.terminalIDBySurfaceKey.removeValue(forKey: key)
        }
    }

    private func handleAction(_ action: ghostty_action_s, target: ghostty_target_s) {
        if action.tag == GHOSTTY_ACTION_SECURE_INPUT {
            let secureAction = action.action.secure_input
            SecureInputController.shared.applyGhosttyAction(secureAction)
            InputEventRecorder.shared.record(
                kind: .ghosttyCallback,
                keyCode: nil,
                modifierFlags: 0,
                details: "action_cb secure_input=\(secureAction.rawValue) enabled=\(SecureInputController.shared.isSecureInputEnabled())"
            )
            AppLogger.input.debug("ghostty action secure_input=\(secureAction.rawValue, privacy: .public) enabled=\(SecureInputController.shared.isSecureInputEnabled(), privacy: .public)")
            return
        }

        if action.tag == GHOSTTY_ACTION_PWD,
           target.tag == GHOSTTY_TARGET_SURFACE,
           let pwdCString = action.action.pwd.pwd {
            let key = surfaceKey(target.target.surface)
            let terminalID = surfaceRegistry.withLock { state in
                state.terminalIDBySurfaceKey[key]
            }
            guard let terminalID else { return }
            let runtimePath = String(cString: pwdCString)
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: .wmTerminalRuntimePathDidChange,
                    object: nil,
                    userInfo: [
                        TerminalRuntimeNotificationKey.terminalID: terminalID,
                        TerminalRuntimeNotificationKey.path: runtimePath
                    ]
                )
            }
        }
    }

    private func surfaceKey(_ surface: ghostty_surface_t) -> UInt {
        UInt(bitPattern: surface)
    }

    deinit {
        if let app = app {
            ghostty_app_free(app)
        }
        if let config = config {
            ghostty_config_free(config)
        }
    }
}

// MARK: - Ghostty Surface View (NSView)
/// NSView subclass that hosts a libghostty terminal surface
class GhosttySurfaceNSView: NSView {
    private(set) var surface: ghostty_surface_t?

    let terminalID: UUID
    let workingDirectory: String
    private var workingDirectoryCString: UnsafeMutablePointer<CChar>?
    private var isCurrentlySelected: Bool = false
    private var previousModifierFlags: NSEvent.ModifierFlags = []

    // MARK: - Custom Momentum Physics
    private var scrollVelocityY: Double = 0
    private var scrollVelocityX: Double = 0
    private var momentumTimer: Timer?

    // Momentum physics parameters (tunable)
    private let decayFactor: Double = 0.96        // How quickly velocity decays (0.9-0.98) - higher = longer glide
    private let velocityThreshold: Double = 5.5   // Stop when velocity below this (higher = stops earlier, avoids low-velocity stutter)
    private let momentumInterval: Double = 1.0 / 120.0  // 120Hz updates

    init(workingDirectory: String, terminalID: UUID) {
        self.terminalID = terminalID
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        let preferredRoot = ConfigService.preferredWorkspaceRoot
        let cwdCandidates = [workingDirectory, preferredRoot, homeDir]
        self.workingDirectory = cwdCandidates.first(where: { !$0.isEmpty && FileManager.default.fileExists(atPath: $0) }) ?? homeDir
        super.init(frame: NSRect(x: 0, y: 0, width: 800, height: 600))

        // Make layer-backed for Metal
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        setupSurface()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not supported")
    }

    private func setupSurface() {
        guard let app = GhosttyAppManager.shared.app else {
            AppLogger.ghostty.error("surface setup failed: app not initialized")
            return
        }

        // Create surface using closure to ensure C string lifetime safety
        let createdSurface: ghostty_surface_t? = createSurfaceWithConfig(app: app)

        guard let surface = createdSurface else {
            AppLogger.ghostty.error("ghostty_surface_new failed")
            return
        }
        self.surface = surface
        GhosttyAppManager.shared.registerSurface(surface, terminalID: terminalID)

        // Set initial size
        updateSurfaceSize()
    }

    private func createSurfaceWithConfig(app: ghostty_app_t) -> ghostty_surface_t? {
        var surfaceConfig = ghostty_surface_config_new()
        surfaceConfig.platform_tag = GHOSTTY_PLATFORM_MACOS

        // Set the NSView pointer - this is the key part!
        // libghostty will create a CAMetalLayer on this view
        withUnsafeMutablePointer(to: &surfaceConfig.platform) { platformPtr in
            let macosPtr = UnsafeMutableRawPointer(platformPtr).assumingMemoryBound(to: ghostty_platform_macos_s.self)
            macosPtr.pointee.nsview = Unmanaged.passUnretained(self).toOpaque()
        }

        // Surface userdata lets runtime callbacks (read_clipboard_cb etc.) locate
        // the originating NSView and its surface pointer.
        surfaceConfig.userdata = Unmanaged.passUnretained(self).toOpaque()

        surfaceConfig.scale_factor = Double(NSScreen.main?.backingScaleFactor ?? 2.0)
        surfaceConfig.font_size = 0  // Use default from config
        surfaceConfig.context = GHOSTTY_SURFACE_CONTEXT_WINDOW

        // Create surface with working directory.
        // Keep a stable C string pointer for the lifetime of the surface view in case libghostty
        // defers usage beyond ghostty_surface_new.
        if !workingDirectory.isEmpty {
            let cstr = strdup(workingDirectory)
            guard let cstr else {
                AppLogger.ghostty.error("working_directory strdup failed")
                return ghostty_surface_new(app, &surfaceConfig)
            }
            workingDirectoryCString = cstr
            surfaceConfig.working_directory = UnsafePointer(cstr)
            let created = ghostty_surface_new(app, &surfaceConfig)
            if created == nil {
                free(cstr)
                workingDirectoryCString = nil
            }
            return created
        }

        return ghostty_surface_new(app, &surfaceConfig)
    }

    private func updateSurfaceSize() {
        guard let surface = surface else { return }
        let scale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2.0
        let width = UInt32(bounds.width * scale)
        let height = UInt32(bounds.height * scale)

        if width > 0 && height > 0 {
            ghostty_surface_set_size(surface, width, height)
            ghostty_surface_set_content_scale(surface, scale, scale)
        }
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        updateSurfaceSize()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateSurfaceSize()

        // If we are not attached to a window, we are not displayable. Occlude immediately.
        // When reattached, reapply the last known selection/visibility state.
        if window == nil {
            applyVisibility(selected: false)
            return
        } else {
            applyVisibility(selected: isCurrentlySelected)
        }

        // Set display ID for Metal
        if let screen = window?.screen, let surface = surface {
            let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID ?? 0
            ghostty_surface_set_display_id(surface, displayID)
        }
    }

    override var acceptsFirstResponder: Bool { true }

    override func becomeFirstResponder() -> Bool {
        if let surface = surface {
            ghostty_surface_set_focus(surface, true)
        }
        return super.becomeFirstResponder()
    }

    override func resignFirstResponder() -> Bool {
        if let surface = surface {
            ghostty_surface_set_focus(surface, false)
        }
        return super.resignFirstResponder()
    }

    func applyVisibility(selected: Bool) {
        let wasSelected = isCurrentlySelected
        isCurrentlySelected = selected
        guard let surface = surface else { return }

        // Focus routes input behavior.
        ghostty_surface_set_focus(surface, selected)

        // NOTE: ghostty_surface_set_occlusion is intentionally NOT used.
        // Testing revealed that enabling occlusion causes severe input lag (40-50 seconds)
        // even for the selected/visible terminal. The occlusion state appears to interfere
        // with libghostty's internal rendering pipeline in ways that prevent timely
        // Metal layer updates. Until this is resolved upstream or a workaround is found,
        // all surfaces remain non-occluded and rely on SwiftUI opacity for visibility control.

        // If we are becoming visible again, force a refresh
        if selected && !wasSelected {
            ghostty_surface_refresh(surface)
            GhosttyAppManager.shared.tick()
        }

        // If we are being hidden while momentum scrolling is active, stop the timer
        if !selected && wasSelected {
            stopMomentumTimer()
        }
    }

    // MARK: - Keyboard Input

    override func keyDown(with event: NSEvent) {
        guard let surface = surface else {
            super.keyDown(with: event)
            return
        }

        InputEventRecorder.shared.record(
            kind: .keyDown,
            keyCode: event.keyCode,
            modifierFlags: event.modifierFlags.rawValue,
            details: "ghostty keyDown chars=\(Redaction.maskCharacters(event.characters))"
        )

        var keyEvent = ghostty_input_key_s()
        keyEvent.action = event.isARepeat ? GHOSTTY_ACTION_REPEAT : GHOSTTY_ACTION_PRESS
        keyEvent.mods = translateModifiers(event.modifierFlags)
        keyEvent.consumed_mods = consumedMods(event.modifierFlags)
        keyEvent.keycode = UInt32(event.keyCode)
        keyEvent.unshifted_codepoint = unshiftedCodepoint(for: event)
        keyEvent.text = nil
        keyEvent.composing = false

        // Arrow keys must never be forwarded as text (they can appear as PUA glyphs).
        // Always route via keycode/modifiers only.
        if event.keyCode == 123 || event.keyCode == 124 || event.keyCode == 125 || event.keyCode == 126 {
            _ = ghostty_surface_key(surface, keyEvent)
            GhosttyAppManager.shared.tick()
            return
        }

        if let chars = ghosttyCharacters(for: event),
           !chars.isEmpty,
           let firstByte = chars.utf8.first,
           firstByte >= 0x20 {
            chars.withCString { cstr in
                keyEvent.text = cstr
                _ = ghostty_surface_key(surface, keyEvent)
            }
        } else {
            _ = ghostty_surface_key(surface, keyEvent)
        }

        // CRITICAL: Call tick() SYNCHRONOUSLY after input to ensure immediate processing.
        // The coalesced requestTick() via DispatchQueue.main.async can introduce delays.
        GhosttyAppManager.shared.tick()
    }

    override func keyUp(with event: NSEvent) {
        guard let surface = surface else {
            super.keyUp(with: event)
            return
        }

        var keyEvent = ghostty_input_key_s()
        keyEvent.action = GHOSTTY_ACTION_RELEASE
        keyEvent.mods = translateModifiers(event.modifierFlags)
        keyEvent.consumed_mods = consumedMods(event.modifierFlags)
        keyEvent.keycode = UInt32(event.keyCode)
        keyEvent.unshifted_codepoint = unshiftedCodepoint(for: event)
        keyEvent.text = nil
        keyEvent.composing = false

        _ = ghostty_surface_key(surface, keyEvent)
        GhosttyAppManager.shared.tick()
    }

    override func flagsChanged(with event: NSEvent) {
        guard let surface = surface else {
            super.flagsChanged(with: event)
            return
        }

        InputEventRecorder.shared.record(
            kind: .flagsChanged,
            keyCode: event.keyCode,
            modifierFlags: event.modifierFlags.rawValue,
            details: "ghostty flagsChanged"
        )

        var keyEvent = ghostty_input_key_s()
        let current = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let changedFlag = modifierFlag(for: event.keyCode)
        if changedFlag == .command && hasNoModifierButCommand(current) {
            previousModifierFlags = current
            super.flagsChanged(with: event)
            return
        }

        if let changedFlag {
            keyEvent.action = current.contains(changedFlag) ? GHOSTTY_ACTION_PRESS : GHOSTTY_ACTION_RELEASE
        } else {
            let previous = previousModifierFlags.intersection(.deviceIndependentFlagsMask)
            keyEvent.action = current.rawValue >= previous.rawValue ? GHOSTTY_ACTION_PRESS : GHOSTTY_ACTION_RELEASE
        }
        keyEvent.mods = translateModifiers(event.modifierFlags)
        keyEvent.consumed_mods = consumedMods(event.modifierFlags)
        keyEvent.keycode = UInt32(event.keyCode)
        keyEvent.unshifted_codepoint = unshiftedCodepoint(for: event)
        keyEvent.text = nil
        keyEvent.composing = false

        _ = ghostty_surface_key(surface, keyEvent)
        previousModifierFlags = current
        GhosttyAppManager.shared.tick()
    }

    private func hasNoModifierButCommand(_ flags: NSEvent.ModifierFlags) -> Bool {
        let meaningful = flags.intersection([.command, .shift, .option, .control])
        return meaningful == .command || meaningful == []
    }

    private func modifierFlag(for keyCode: UInt16) -> NSEvent.ModifierFlags? {
        switch keyCode {
        case 54, 55:
            return .command
        case 56, 60:
            return .shift
        case 58, 61:
            return .option
        case 59, 62:
            return .control
        case 57:
            return .capsLock
        default:
            return nil
        }
    }

    private func translateModifiers(_ flags: NSEvent.ModifierFlags) -> ghostty_input_mods_e {
        var mods: UInt32 = 0
        if flags.contains(.shift) { mods |= GHOSTTY_MODS_SHIFT.rawValue }
        if flags.contains(.control) { mods |= GHOSTTY_MODS_CTRL.rawValue }
        if flags.contains(.option) { mods |= GHOSTTY_MODS_ALT.rawValue }
        if flags.contains(.command) { mods |= GHOSTTY_MODS_SUPER.rawValue }
        if flags.contains(.capsLock) { mods |= GHOSTTY_MODS_CAPS.rawValue }
        return ghostty_input_mods_e(rawValue: mods)
    }

    private func consumedMods(_ flags: NSEvent.ModifierFlags) -> ghostty_input_mods_e {
        var raw = translateModifiers(flags).rawValue
        raw &= ~(GHOSTTY_MODS_CTRL.rawValue | GHOSTTY_MODS_SUPER.rawValue)
        return ghostty_input_mods_e(rawValue: raw)
    }

    private func unshiftedCodepoint(for event: NSEvent) -> UInt32 {
        if event.type == .keyDown || event.type == .keyUp {
            if let chars = event.characters(byApplyingModifiers: []),
               let codepoint = chars.unicodeScalars.first {
                return codepoint.value
            }
        }
        return 0
    }

    private func ghosttyCharacters(for event: NSEvent) -> String? {
        if event.modifierFlags.contains(.command) || event.modifierFlags.contains(.control) {
            return nil
        }

        guard let characters = event.characters else { return nil }

        if characters.count == 1, let scalar = characters.unicodeScalars.first {
            // Control characters are encoded by Ghostty itself.
            if scalar.value < 0x20 {
                return event.characters(byApplyingModifiers: event.modifierFlags.subtracting(.control))
            }

            // macOS function keys (including arrows) are in the PUA range. Never forward as text.
            if scalar.value >= 0xF700 && scalar.value <= 0xF8FF {
                return nil
            }
        }

        return characters
    }

    // MARK: - Mouse Input

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        guard let surface = surface else { return }

        let point = convert(event.locationInWindow, from: nil)
        let scale = window?.backingScaleFactor ?? 2.0
        ghostty_surface_mouse_pos(surface, point.x * scale, (bounds.height - point.y) * scale, translateModifiers(event.modifierFlags))
        _ = ghostty_surface_mouse_button(surface, GHOSTTY_MOUSE_PRESS, GHOSTTY_MOUSE_LEFT, translateModifiers(event.modifierFlags))
        GhosttyAppManager.shared.tick()
    }

    override func mouseUp(with event: NSEvent) {
        guard let surface = surface else { return }
        _ = ghostty_surface_mouse_button(surface, GHOSTTY_MOUSE_RELEASE, GHOSTTY_MOUSE_LEFT, translateModifiers(event.modifierFlags))
        GhosttyAppManager.shared.tick()
    }

    override func mouseDragged(with event: NSEvent) {
        guard let surface = surface else { return }
        let point = convert(event.locationInWindow, from: nil)
        let scale = window?.backingScaleFactor ?? 2.0
        ghostty_surface_mouse_pos(surface, point.x * scale, (bounds.height - point.y) * scale, translateModifiers(event.modifierFlags))
        GhosttyAppManager.shared.tick()
    }

    override func scrollWheel(with event: NSEvent) {
        guard let surface = surface else { return }

        // Handle user's active scrolling (finger on trackpad)
        if event.phase == .changed || event.phase == .began {
            stopMomentumTimer()

            // Accumulate velocity from user input
            scrollVelocityY = event.scrollingDeltaY
            scrollVelocityX = event.scrollingDeltaX

            // Pass directly to libghostty during active scroll
            var scrollMods: ghostty_input_scroll_mods_t = 0
            if event.hasPreciseScrollingDeltas {
                scrollMods |= 1
            }
            ghostty_surface_mouse_scroll(surface, event.scrollingDeltaX, event.scrollingDeltaY, scrollMods)
            GhosttyAppManager.shared.tick()
            return
        }

        // User lifted finger - start our own momentum
        if event.phase == .ended {
            startMomentumTimer()
            return
        }

        // IGNORE macOS momentum events - we handle momentum ourselves
        if event.momentumPhase == .changed || event.momentumPhase == .began {
            // Don't pass to libghostty - we're doing our own smooth deceleration
            return
        }

        // Handle momentum end/cancel from system (cleanup)
        if event.momentumPhase == .ended || event.momentumPhase == .cancelled {
            // System momentum ended - we should already be handling it ourselves
            return
        }

        // Default path for mouse wheel and devices without phase transitions
        // When both phase == .none and momentumPhase == .none, forward deltas directly
        if event.phase == [] && event.momentumPhase == [] {
            var scrollMods: ghostty_input_scroll_mods_t = 0
            if event.hasPreciseScrollingDeltas {
                scrollMods |= 1
            }
            ghostty_surface_mouse_scroll(surface, event.scrollingDeltaX, event.scrollingDeltaY, scrollMods)
            GhosttyAppManager.shared.tick()
        }
    }

    // MARK: - Momentum Timer

    private func startMomentumTimer() {
        stopMomentumTimer()

        // Only start if we have meaningful velocity
        guard abs(scrollVelocityY) > velocityThreshold || abs(scrollVelocityX) > velocityThreshold else {
            return
        }

        momentumTimer = Timer.scheduledTimer(withTimeInterval: momentumInterval, repeats: true) { [weak self] _ in
            self?.momentumTick()
        }
        // Add to common run loop modes for smooth animation during tracking
        if let timer = momentumTimer {
            RunLoop.current.add(timer, forMode: .common)
        }
    }

    private func stopMomentumTimer() {
        momentumTimer?.invalidate()
        momentumTimer = nil
    }

    private func momentumTick() {
        guard let surface = surface else {
            stopMomentumTimer()
            return
        }

        // Apply exponential decay
        scrollVelocityY *= decayFactor
        scrollVelocityX *= decayFactor

        // Stop when velocity is negligible
        if abs(scrollVelocityY) < velocityThreshold && abs(scrollVelocityX) < velocityThreshold {
            scrollVelocityY = 0
            scrollVelocityX = 0
            stopMomentumTimer()
            return
        }

        // Feed smooth delta to libghostty
        var scrollMods: ghostty_input_scroll_mods_t = 1  // precision scrolling
        // Encode momentum phase as "changed" (2) in bits 1-3
        scrollMods |= (2 << 1)

        ghostty_surface_mouse_scroll(surface, scrollVelocityX, scrollVelocityY, scrollMods)
    }

    // MARK: - Cleanup

    deinit {
        stopMomentumTimer()
        if let surface = surface {
            GhosttyAppManager.shared.unregisterSurface(surface)
            ghostty_surface_free(surface)
        }
        if let workingDirectoryCString {
            free(workingDirectoryCString)
            self.workingDirectoryCString = nil
        }
    }
}

// MARK: - SwiftUI Wrapper
/// SwiftUI wrapper for GhosttySurfaceNSView
struct GhosttyTerminalView: NSViewRepresentable {
    let workingDirectory: String
    let terminalId: UUID
    let isSelected: Bool

    func makeNSView(context: Context) -> GhosttySurfaceNSView {
        let view = GhosttySurfaceNSView(workingDirectory: workingDirectory, terminalID: terminalId)
        return view
    }

    func updateNSView(_ nsView: GhosttySurfaceNSView, context: Context) {
        nsView.applyVisibility(selected: isSelected)

        if isSelected && nsView.window?.firstResponder !== nsView {
            DispatchQueue.main.async {
                nsView.window?.makeFirstResponder(nsView)
            }
        }
    }
}
