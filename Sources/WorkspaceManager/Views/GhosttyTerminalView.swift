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
            // Get the first content item's data
            if let data = content.pointee.data {
                let str = String(cString: data)
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
    private var displayLink: CVDisplayLink?

    let workingDirectory: String

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

        // Create surface configuration
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

        // Set working directory
        if !workingDirectory.isEmpty {
            workingDirectory.withCString { cstr in
                surfaceConfig.working_directory = cstr
            }
        }

        surfaceConfig.context = GHOSTTY_SURFACE_CONTEXT_WINDOW

        // Create the surface
        NSLog("[GhosttySurfaceNSView] Calling ghostty_surface_new...")
        guard let surface = ghostty_surface_new(app, &surfaceConfig) else {
            NSLog("[GhosttySurfaceNSView] ghostty_surface_new failed!")
            return
        }
        self.surface = surface
        NSLog("[GhosttySurfaceNSView] Surface created successfully!")

        // Set initial size
        updateSurfaceSize()
        NSLog("[GhosttySurfaceNSView] Size updated, surface is ready for rendering")
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

        // ghostty_input_scroll_mods_t is a bitmask
        var scrollMods: ghostty_input_scroll_mods_t = 0
        if event.hasPreciseScrollingDeltas {
            scrollMods |= 1  // Precision scrolling flag
        }

        ghostty_surface_mouse_scroll(surface, event.scrollingDeltaX, event.scrollingDeltaY, scrollMods)
    }

    // MARK: - Cleanup

    deinit {
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
