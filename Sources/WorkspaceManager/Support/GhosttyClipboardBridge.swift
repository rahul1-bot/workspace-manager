import AppKit
import Foundation
import GhosttyKit

final class GhosttyClipboardBridge {
    static let shared = GhosttyClipboardBridge()

    private let lock = NSLock()
    private var retainedResponses: [UnsafeMutablePointer<CChar>] = []
    private let maxRetainedResponses = 8
    private let maxIncomingBytes = 10_000_000

    private init() {}

    func completeReadRequest(state: UnsafeMutableRawPointer, location: ghostty_clipboard_e) {
        let clipboardText = NSPasteboard.general.string(forType: .string) ?? ""
        guard let copied = strdup(clipboardText) else {
            AppLogger.ghostty.error("clipboard read strdup failed")
            ghostty_surface_complete_clipboard_request(state, "", nil, false)
            return
        }

        lock.lock()
        retainedResponses.append(copied)
        trimRetainedResponsesIfNeeded()
        lock.unlock()

        ghostty_surface_complete_clipboard_request(state, UnsafePointer(copied), nil, false)
        InputEventRecorder.shared.record(
            kind: .ghosttyCallback,
            keyCode: nil,
            modifierFlags: 0,
            details: "read_clipboard_cb location=\(location.rawValue) bytes=\(clipboardText.utf8.count)"
        )
    }

    func writeClipboard(contents: UnsafePointer<ghostty_clipboard_content_s>, count: Int, location: ghostty_clipboard_e, confirm: Bool) {
        guard count > 0 else { return }
        let buffer = UnsafeBufferPointer(start: contents, count: count)

        for item in buffer {
            guard let dataPtr = item.data else { continue }
            let byteCount = strnlen(dataPtr, maxIncomingBytes)
            guard byteCount < maxIncomingBytes else {
                AppLogger.ghostty.error("clipboard write exceeded maxIncomingBytes")
                continue
            }

            let data = Data(bytes: dataPtr, count: byteCount)
            guard let decoded = String(data: data, encoding: .utf8) else { continue }
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(decoded, forType: .string)

            InputEventRecorder.shared.record(
                kind: .ghosttyCallback,
                keyCode: nil,
                modifierFlags: 0,
                details: "write_clipboard_cb location=\(location.rawValue) entries=\(count) confirm=\(confirm) bytes=\(byteCount)"
            )
            return
        }
    }

    func cleanupRetainedResponses() {
        lock.lock()
        defer { lock.unlock() }
        for pointer in retainedResponses {
            free(pointer)
        }
        retainedResponses.removeAll()
    }

    private func trimRetainedResponsesIfNeeded() {
        while retainedResponses.count > maxRetainedResponses {
            let oldest = retainedResponses.removeFirst()
            free(oldest)
        }
    }
}
