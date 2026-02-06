import Carbon.HIToolbox
import Foundation
import GhosttyKit

final class SecureInputController {
    static let shared = SecureInputController()

    private let lock = NSLock()
    private var secureInputBalance: Int = 0

    private init() {}

    func applyGhosttyAction(_ action: ghostty_action_secure_input_e) {
        lock.lock()
        defer { lock.unlock() }

        switch action {
        case GHOSTTY_SECURE_INPUT_ON:
            enableSecureInput()
        case GHOSTTY_SECURE_INPUT_OFF:
            disableSecureInput()
        case GHOSTTY_SECURE_INPUT_TOGGLE:
            if isSecureInputEnabled() {
                disableSecureInput()
            } else {
                enableSecureInput()
            }
        default:
            break
        }
    }

    func isSecureInputEnabled() -> Bool {
        IsSecureEventInputEnabled()
    }

    private func enableSecureInput() {
        guard secureInputBalance < Int.max else { return }
        let status = EnableSecureEventInput()
        if status == noErr {
            secureInputBalance += 1
            AppLogger.input.debug("secure input enabled balance=\(self.secureInputBalance, privacy: .public)")
        } else {
            AppLogger.input.error("EnableSecureEventInput failed status=\(status, privacy: .public)")
        }
    }

    func disableAllSecureInput() {
        lock.lock()
        defer { lock.unlock() }
        while secureInputBalance > 0 {
            let status = DisableSecureEventInput()
            if status == noErr {
                secureInputBalance -= 1
            } else {
                break
            }
        }
    }

    private func disableSecureInput() {
        guard secureInputBalance > 0 else { return }
        let status = DisableSecureEventInput()
        if status == noErr {
            secureInputBalance -= 1
            AppLogger.input.debug("secure input disabled balance=\(self.secureInputBalance, privacy: .public)")
        } else {
            AppLogger.input.error("DisableSecureEventInput failed status=\(status, privacy: .public)")
        }
    }
}
