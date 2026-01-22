import SwiftUI
import AppKit
import GhosttyKit

// MARK: - Ghostty App Singleton
/// Manages the global ghostty_app_t instance
class GhosttyAppManager {
    static let shared = GhosttyAppManager()

    private(set) var app: ghostty_app_t?
    private(set) var config: ghostty_config_t?
    private var initialized = false

    private init() {}

    /// Initialize libghostty - call once at app startup
    func initialize() {
        guard !initialized else {
            NSLog("[GhosttyAppManager] Already initialized")
            return
        }
        initialized = true
        NSLog("[GhosttyAppManager] Starting initialization...")

        // Initialize the library
        NSLog("[GhosttyAppManager] Calling ghostty_init...")
        let result = ghostty_init(0, nil)
        guard result == 0 else {
            NSLog("[GhosttyAppManager] ghostty_init failed with code: \(result)")
            return
        }
        NSLog("[GhosttyAppManager] ghostty_init succeeded")

        // Create configuration
        NSLog("[GhosttyAppManager] Creating config...")
        guard let cfg = ghostty_config_new() else {
            NSLog("[GhosttyAppManager] ghostty_config_new failed")
            return
        }
        self.config = cfg
        NSLog("[GhosttyAppManager] Config created")

        // Load default config files
        NSLog("[GhosttyAppManager] Loading config files...")
        ghostty_config_load_default_files(cfg)
        ghostty_config_finalize(cfg)
        NSLog("[GhosttyAppManager] Config finalized")

        // Create runtime config with callbacks
        var runtimeConfig = ghostty_runtime_config_s()
        runtimeConfig.userdata = Unmanaged.passUnretained(self).toOpaque()
        runtimeConfig.supports_selection_clipboard = true
        runtimeConfig.wakeup_cb = { userdata in
            DispatchQueue.main.async {
                GhosttyAppManager.shared.tick()
            }
        }
        runtimeConfig.action_cb = { app, target, action in
            // Handle actions (title changes, notifications, etc.)
            return true
        }
        runtimeConfig.read_clipboard_cb = { userdata, location, state in
            // Read clipboard
            guard let state = state else { return }
            let content = NSPasteboard.general.string(forType: .string) ?? ""
            content.withCString { cstr in
                ghostty_surface_complete_clipboard_request(state, cstr, nil, false)
            }
        }
        runtimeConfig.confirm_read_clipboard_cb = nil
        runtimeConfig.write_clipboard_cb = { (userdata: UnsafeMutableRawPointer?, location: ghostty_clipboard_e, content: UnsafePointer<ghostty_clipboard_content_s>?, len: Int, confirm: Bool) in
            // Write clipboard - content is an array of ghostty_clipboard_content_s
            guard let content = content, len > 0 else { return }

            // Process the first content item with bounded null-terminated string handling
            let contentItem = content.pointee
            guard let dataPtr = contentItem.data else { return }

            // Use bounded scan for null terminator to prevent buffer overruns
            // This is safer than unbounded String(cString:)
            let maxLen = 10_000_000  // 10MB safety limit
            var actualLen = 0
            while actualLen < maxLen && dataPtr[actualLen] != 0 {
                actualLen += 1
            }

            guard actualLen < maxLen else {
                NSLog("[GhosttyAppManager] Clipboard content exceeded safety limit")
                return
            }

            let data = Data(bytes: dataPtr, count: actualLen)
            if let str = String(data: data, encoding: .utf8) {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(str, forType: .string)
            }
        }
        runtimeConfig.close_surface_cb = { userdata, processAlive in
            // Handle surface close
        }

        // Create the app
        NSLog("[GhosttyAppManager] Creating ghostty app...")
        guard let app = ghostty_app_new(&runtimeConfig, cfg) else {
            NSLog("[GhosttyAppManager] ghostty_app_new failed")
            return
        }
        self.app = app

        NSLog("[GhosttyAppManager] Initialized successfully! App is ready.")
    }

    /// Process pending work - call regularly
    func tick() {
        guard let app = app else { return }
        ghostty_app_tick(app)
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
    private var surface: ghostty_surface_t?

    let workingDirectory: String

    // MARK: - Custom Momentum Physics (CVDisplayLink-synced)
    private var scrollVelocityY: Double = 0
    private var scrollVelocityX: Double = 0
    private var displayLink: CADisplayLink?
    private var lastFrameTimestamp: CFTimeInterval = 0

    // Momentum physics parameters (tunable)
    private let decayFactor: Double = 0.94        // How quickly velocity decays (0.9-0.98) - lower = faster stop, less stutter
    private let velocityThreshold: Double = 3.5   // Stop when velocity below this (balance between glide and stutter)
    private let targetFrameRate: Double = 120.0   // Target frame rate for decay calculation

    init(workingDirectory: String) {
        self.workingDirectory = workingDirectory
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
        NSLog("[GhosttySurfaceNSView] setupSurface called")
        guard let app = GhosttyAppManager.shared.app else {
            NSLog("[GhosttySurfaceNSView] No app available - GhosttyAppManager not initialized?")
            return
        }
        NSLog("[GhosttySurfaceNSView] Got app, creating surface...")

        // Create surface using closure to ensure C string lifetime safety
        let createdSurface: ghostty_surface_t? = createSurfaceWithConfig(app: app)

        guard let surface = createdSurface else {
            NSLog("[GhosttySurfaceNSView] ghostty_surface_new failed!")
            return
        }
        self.surface = surface
        NSLog("[GhosttySurfaceNSView] Surface created successfully!")

        // Set initial size
        updateSurfaceSize()
        NSLog("[GhosttySurfaceNSView] Size updated, surface is ready for rendering")
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

        surfaceConfig.scale_factor = Double(NSScreen.main?.backingScaleFactor ?? 2.0)
        surfaceConfig.font_size = 0  // Use default from config
        surfaceConfig.context = GHOSTTY_SURFACE_CONTEXT_WINDOW

        // Create surface with working directory - C string must remain valid until ghostty_surface_new returns
        if !workingDirectory.isEmpty {
            return workingDirectory.withCString { cstr in
                surfaceConfig.working_directory = cstr
                NSLog("[GhosttySurfaceNSView] Calling ghostty_surface_new with working_directory...")
                return ghostty_surface_new(app, &surfaceConfig)
            }
        } else {
            NSLog("[GhosttySurfaceNSView] Calling ghostty_surface_new without working_directory...")
            return ghostty_surface_new(app, &surfaceConfig)
        }
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

    // MARK: - Keyboard Input

    override func keyDown(with event: NSEvent) {
        guard let surface = surface else {
            super.keyDown(with: event)
            return
        }

        var keyEvent = ghostty_input_key_s()
        keyEvent.action = GHOSTTY_ACTION_PRESS
        keyEvent.mods = translateModifiers(event.modifierFlags)
        keyEvent.keycode = UInt32(event.keyCode)

        if let chars = event.characters, !chars.isEmpty {
            chars.withCString { cstr in
                keyEvent.text = cstr
                _ = ghostty_surface_key(surface, keyEvent)
            }
        } else {
            _ = ghostty_surface_key(surface, keyEvent)
        }
    }

    override func keyUp(with event: NSEvent) {
        guard let surface = surface else {
            super.keyUp(with: event)
            return
        }

        var keyEvent = ghostty_input_key_s()
        keyEvent.action = GHOSTTY_ACTION_RELEASE
        keyEvent.mods = translateModifiers(event.modifierFlags)
        keyEvent.keycode = UInt32(event.keyCode)

        _ = ghostty_surface_key(surface, keyEvent)
    }

    override func flagsChanged(with event: NSEvent) {
        guard let surface = surface else {
            super.flagsChanged(with: event)
            return
        }

        var keyEvent = ghostty_input_key_s()
        keyEvent.action = GHOSTTY_ACTION_PRESS
        keyEvent.mods = translateModifiers(event.modifierFlags)
        keyEvent.keycode = UInt32(event.keyCode)

        _ = ghostty_surface_key(surface, keyEvent)
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

    // MARK: - Mouse Input

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        guard let surface = surface else { return }

        let point = convert(event.locationInWindow, from: nil)
        let scale = window?.backingScaleFactor ?? 2.0
        ghostty_surface_mouse_pos(surface, point.x * scale, (bounds.height - point.y) * scale, translateModifiers(event.modifierFlags))
        _ = ghostty_surface_mouse_button(surface, GHOSTTY_MOUSE_PRESS, GHOSTTY_MOUSE_LEFT, translateModifiers(event.modifierFlags))
    }

    override func mouseUp(with event: NSEvent) {
        guard let surface = surface else { return }
        _ = ghostty_surface_mouse_button(surface, GHOSTTY_MOUSE_RELEASE, GHOSTTY_MOUSE_LEFT, translateModifiers(event.modifierFlags))
    }

    override func mouseDragged(with event: NSEvent) {
        guard let surface = surface else { return }
        let point = convert(event.locationInWindow, from: nil)
        let scale = window?.backingScaleFactor ?? 2.0
        ghostty_surface_mouse_pos(surface, point.x * scale, (bounds.height - point.y) * scale, translateModifiers(event.modifierFlags))
    }

    override func scrollWheel(with event: NSEvent) {
        guard let surface = surface else { return }

        // Handle user's active scrolling (finger on trackpad)
        if event.phase == .changed || event.phase == .began {
            stopDisplayLink()

            // Accumulate velocity from user input
            scrollVelocityY = event.scrollingDeltaY
            scrollVelocityX = event.scrollingDeltaX

            // Pass directly to libghostty during active scroll
            var scrollMods: ghostty_input_scroll_mods_t = 0
            if event.hasPreciseScrollingDeltas {
                scrollMods |= 1
            }
            ghostty_surface_mouse_scroll(surface, event.scrollingDeltaX, event.scrollingDeltaY, scrollMods)
            return
        }

        // User lifted finger - start our own momentum
        if event.phase == .ended {
            startDisplayLink()
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
        }
    }

    // MARK: - Display-Synced Momentum (CADisplayLink)

    private func startDisplayLink() {
        stopDisplayLink()

        // Only start if we have meaningful velocity
        guard abs(scrollVelocityY) > velocityThreshold || abs(scrollVelocityX) > velocityThreshold else {
            return
        }

        // Use macOS 14+ CADisplayLink from NSView - fires exactly at vsync
        displayLink = self.displayLink(target: self, selector: #selector(displayLinkTick(_:)))

        // Explicitly request 120Hz on ProMotion displays
        if #available(macOS 14.0, *) {
            displayLink?.preferredFrameRateRange = CAFrameRateRange(minimum: 80, maximum: 120, preferred: 120)
        }

        displayLink?.add(to: .current, forMode: .common)
        lastFrameTimestamp = 0  // Reset timestamp
    }

    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func displayLinkTick(_ link: CADisplayLink) {
        guard let surface = surface else {
            stopDisplayLink()
            return
        }

        // Calculate delta time from actual frame timestamps
        let currentTimestamp = link.targetTimestamp
        let deltaTime: Double
        if lastFrameTimestamp == 0 {
            // First frame - use expected frame duration
            deltaTime = 1.0 / targetFrameRate
        } else {
            deltaTime = currentTimestamp - lastFrameTimestamp
        }
        lastFrameTimestamp = currentTimestamp

        // Apply frame-rate-independent exponential decay
        // decayFactor is tuned for 120Hz, so we adjust for actual frame time
        let normalizedDecay = pow(decayFactor, deltaTime * targetFrameRate)
        scrollVelocityY *= normalizedDecay
        scrollVelocityX *= normalizedDecay

        // Stop when velocity is negligible
        if abs(scrollVelocityY) < velocityThreshold && abs(scrollVelocityX) < velocityThreshold {
            scrollVelocityY = 0
            scrollVelocityX = 0
            stopDisplayLink()
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
        stopDisplayLink()
        if let surface = surface {
            ghostty_surface_free(surface)
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
        let view = GhosttySurfaceNSView(workingDirectory: workingDirectory)
        return view
    }

    func updateNSView(_ nsView: GhosttySurfaceNSView, context: Context) {
        if isSelected && nsView.window?.firstResponder !== nsView {
            DispatchQueue.main.async {
                nsView.window?.makeFirstResponder(nsView)
            }
        }
    }
}
