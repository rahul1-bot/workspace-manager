import Foundation

enum DiagnosticMode {
    static var isEnabled: Bool {
#if DEBUG
        let value = ProcessInfo.processInfo.environment["WM_DIAGNOSTICS"]?.lowercased() ?? "0"
        return value == "1" || value == "true" || value == "yes"
#else
        return false
#endif
    }
}

enum InputEventKind: String {
    case keyDown
    case flagsChanged
    case keyMonitor
    case ghosttyCallback
}

struct InputEventSample {
    let timestamp: Date
    let kind: InputEventKind
    let keyCode: UInt16?
    let modifierFlags: UInt
    let details: String
}

final class InputEventRecorder {
    static let shared = InputEventRecorder(capacity: 256)

    private let capacity: Int
    private var ring: [InputEventSample] = []
    private let lock = NSLock()

    init(capacity: Int) {
        self.capacity = max(capacity, 32)
    }

    func record(kind: InputEventKind, keyCode: UInt16?, modifierFlags: UInt, details: String) {
        guard DiagnosticMode.isEnabled else { return }
        lock.lock()
        defer { lock.unlock() }
        ring.append(
            InputEventSample(
                timestamp: Date(),
                kind: kind,
                keyCode: keyCode,
                modifierFlags: modifierFlags,
                details: details
            )
        )
        if ring.count > capacity {
            ring.removeFirst(ring.count - capacity)
        }
    }

    func snapshot() -> [InputEventSample] {
        lock.lock()
        defer { lock.unlock() }
        return ring
    }
}

enum Redaction {
    static func maskCharacters(_ text: String?) -> String {
        guard let text, !text.isEmpty else { return "<empty>" }
        return "<len:\(text.count)>"
    }
}
