import AppKit
import Foundation

struct ShortcutContext {
    let appIsActive: Bool
    let showCommandPalette: Bool
    let showShortcutsHelp: Bool
    let showCommitSheet: Bool
    let showDiffPanel: Bool
    let showPDFPanel: Bool
    let sidebarFocused: Bool
    let selectedTerminalExists: Bool
    let isGraphMode: Bool
}

enum ShortcutCommand: Hashable {
    case closeShortcutsHelp
    case closeCommandPalette
    case closeCommitSheet
    case closeDiffPanel
    case togglePDFPanel
    case closePDFPanel
    case toggleSidebar
    case newTerminal
    case newWorkspace
    case previousWorkspace
    case nextWorkspace
    case previousTerminal
    case nextTerminal
    case focusSidebar
    case focusTerminal
    case toggleWorkspaceExpanded
    case openWorkspaceInFinder
    case copyWorkspacePath
    case revealConfig
    case toggleFocusMode
    case toggleCommandPalette
    case toggleShortcutsHelp
    case closeTerminalPrompt
    case jumpTerminal(index: Int)
    case jumpWorkspace(index: Int)
    case renameSelected
    case reloadConfig
    case sidebarCancelRename
    case sidebarPrevTerminal
    case sidebarNextTerminal
    case sidebarReturnToTerminal
    case toggleViewMode
    case unfocusGraphNode
    case graphZoomIn
    case graphZoomOut
    case graphZoomToFit
    case graphRerunLayout
    case swallow
}

enum ShortcutRoute {
    case passthrough
    case consume(ShortcutCommand)
}

final class KeyboardShortcutRouter {
    private let numberRowKeyCodeToDigit: [UInt16: Int] = [
        18: 1, 19: 2, 20: 3, 21: 4, 23: 5,
        22: 6, 26: 7, 28: 8, 25: 9, 29: 0
    ]

    func route(event: NSEvent, context: ShortcutContext) -> ShortcutRoute {
        route(
            keyCode: event.keyCode,
            modifierFlags: event.modifierFlags,
            charactersIgnoringModifiers: event.charactersIgnoringModifiers,
            isRepeat: event.isARepeat,
            context: context
        )
    }

    func route(
        keyCode: UInt16,
        modifierFlags: NSEvent.ModifierFlags,
        charactersIgnoringModifiers: String?,
        isRepeat: Bool,
        context: ShortcutContext
    ) -> ShortcutRoute {
        guard context.appIsActive else {
            return .passthrough
        }

        let cmd = modifierFlags.contains(.command)
        let shift = modifierFlags.contains(.shift)
        let option = modifierFlags.contains(.option)
        let char = (charactersIgnoringModifiers ?? "").lowercased()

        if context.showShortcutsHelp {
            if keyCode == 53 {
                return .consume(.closeShortcutsHelp)
            }
            return .consume(.swallow)
        }

        if context.showCommandPalette {
            if keyCode == 53 {
                return .consume(.closeCommandPalette)
            }
            return .passthrough
        }

        if context.showCommitSheet, keyCode == 53 {
            return .consume(.closeCommitSheet)
        }

        if context.showDiffPanel, keyCode == 53 {
            return .consume(.closeDiffPanel)
        }

        if context.showPDFPanel, keyCode == 53 {
            return .consume(.closePDFPanel)
        }

        // Preserve standard edit shortcuts through responder chain.
        if cmd && !shift && !option && ["c", "v", "x", "z", "a"].contains(char) {
            return .passthrough
        }

        if cmd && isRepeat && !["i", "k", "[", "]"].contains(char) {
            return .consume(.swallow)
        }

        if cmd && char == "b" { return .consume(.toggleSidebar) }
        if cmd && char == "t" { return .consume(.newTerminal) }
        if cmd && shift && char == "n" { return .consume(.newWorkspace) }
        if cmd && shift && char == "i" { return .consume(.previousWorkspace) }
        if cmd && shift && char == "k" { return .consume(.nextWorkspace) }
        if cmd && char == "i" { return .consume(.previousTerminal) }
        if cmd && char == "k" { return .consume(.nextTerminal) }
        if cmd && char == "j" { return .consume(.focusSidebar) }
        if cmd && char == "l" { return .consume(.focusTerminal) }
        if cmd && char == "e" { return .consume(.toggleWorkspaceExpanded) }
        if cmd && char == "o" { return .consume(.openWorkspaceInFinder) }
        if cmd && option && char == "c" { return .consume(.copyWorkspacePath) }
        if cmd && char == "," { return .consume(.revealConfig) }
        if cmd && char == "." { return .consume(.toggleFocusMode) }
        if cmd && char == "g" { return .consume(.toggleViewMode) }
        if cmd && shift && char == "p" { return .consume(.togglePDFPanel) }
        if cmd && char == "p" { return .consume(.toggleCommandPalette) }
        if cmd && shift && char == "/" { return .consume(.toggleShortcutsHelp) }
        if cmd && char == "w" && context.selectedTerminalExists { return .consume(.closeTerminalPrompt) }
        if cmd && char == "r" && !shift { return .consume(.renameSelected) }
        if cmd && char == "r" && shift { return .consume(.reloadConfig) }
        if cmd && char == "[" { return .consume(.previousWorkspace) }
        if cmd && char == "]" { return .consume(.nextWorkspace) }

        if context.isGraphMode {
            if cmd && (char == "=" || char == "+") { return .consume(.graphZoomIn) }
            if cmd && char == "-" { return .consume(.graphZoomOut) }
            if cmd && char == "l" { return .consume(.graphRerunLayout) }
        }

        if let digit = numberRowKeyCodeToDigit[keyCode], digit >= 1 {
            if context.isGraphMode && cmd && digit == 0 {
                return .consume(.graphZoomToFit)
            }
            if cmd && option {
                return .consume(.jumpTerminal(index: digit - 1))
            }
            if cmd {
                return .consume(.jumpWorkspace(index: digit - 1))
            }
        }

        if context.isGraphMode && cmd && keyCode == 29 {
            return .consume(.graphZoomToFit)
        }

        if context.sidebarFocused {
            if keyCode == 53 { return .consume(.sidebarCancelRename) }
            if keyCode == 126 { return .consume(.sidebarPrevTerminal) }
            if keyCode == 125 { return .consume(.sidebarNextTerminal) }
            if keyCode == 36 { return .consume(.sidebarReturnToTerminal) }
        }

        return .passthrough
    }
}
