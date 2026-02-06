import AppKit
import XCTest
@testable import WorkspaceManager

final class KeyboardShortcutRouterTests: XCTestCase {
    private let router = KeyboardShortcutRouter()

    func testCopyShortcutPassesThrough() {
        let route = router.route(
            keyCode: 8,
            modifierFlags: [.command],
            charactersIgnoringModifiers: "c",
            isRepeat: false,
            context: makeContext()
        )
        assertPassthrough(route)
    }

    func testToggleSidebarConsumesCommand() {
        let route = router.route(
            keyCode: 11,
            modifierFlags: [.command],
            charactersIgnoringModifiers: "b",
            isRepeat: false,
            context: makeContext()
        )
        assertConsume(route, expected: .toggleSidebar)
    }

    func testShortcutHelpConsumesEscapeAndSwallowsOthers() {
        let visibleContext = makeContext(showShortcutsHelp: true)
        let escapeRoute = router.route(
            keyCode: 53,
            modifierFlags: [],
            charactersIgnoringModifiers: "",
            isRepeat: false,
            context: visibleContext
        )
        assertConsume(escapeRoute, expected: .closeShortcutsHelp)

        let otherRoute = router.route(
            keyCode: 12,
            modifierFlags: [],
            charactersIgnoringModifiers: "q",
            isRepeat: false,
            context: visibleContext
        )
        assertConsume(otherRoute, expected: .swallow)
    }

    func testPalettePassesTypingButConsumesEscape() {
        let visibleContext = makeContext(showCommandPalette: true)
        let typingRoute = router.route(
            keyCode: 15,
            modifierFlags: [],
            charactersIgnoringModifiers: "r",
            isRepeat: false,
            context: visibleContext
        )
        assertPassthrough(typingRoute)

        let escapeRoute = router.route(
            keyCode: 53,
            modifierFlags: [],
            charactersIgnoringModifiers: "",
            isRepeat: false,
            context: visibleContext
        )
        assertConsume(escapeRoute, expected: .closeCommandPalette)
    }

    func testCommitSheetConsumesEscape() {
        let visibleContext = makeContext(showCommitSheet: true)
        let escapeRoute = router.route(
            keyCode: 53,
            modifierFlags: [],
            charactersIgnoringModifiers: "",
            isRepeat: false,
            context: visibleContext
        )
        assertConsume(escapeRoute, expected: .closeCommitSheet)
    }

    func testDiffPanelConsumesEscape() {
        let visibleContext = makeContext(showDiffPanel: true)
        let escapeRoute = router.route(
            keyCode: 53,
            modifierFlags: [],
            charactersIgnoringModifiers: "",
            isRepeat: false,
            context: visibleContext
        )
        assertConsume(escapeRoute, expected: .closeDiffPanel)
    }

    func testSidebarArrowRouting() {
        let route = router.route(
            keyCode: 126,
            modifierFlags: [],
            charactersIgnoringModifiers: "",
            isRepeat: false,
            context: makeContext(sidebarFocused: true)
        )
        assertConsume(route, expected: .sidebarPrevTerminal)
    }

    func testDigitShortcutsMapToWorkspaceAndTerminalJump() {
        let workspaceRoute = router.route(
            keyCode: 18,
            modifierFlags: [.command],
            charactersIgnoringModifiers: "1",
            isRepeat: false,
            context: makeContext()
        )
        assertConsume(workspaceRoute, expected: .jumpWorkspace(index: 0))

        let terminalRoute = router.route(
            keyCode: 19,
            modifierFlags: [.command, .option],
            charactersIgnoringModifiers: "2",
            isRepeat: false,
            context: makeContext()
        )
        assertConsume(terminalRoute, expected: .jumpTerminal(index: 1))
    }

    func testInactiveAppAlwaysPassthrough() {
        let route = router.route(
            keyCode: 11,
            modifierFlags: [.command],
            charactersIgnoringModifiers: "b",
            isRepeat: false,
            context: makeContext(appIsActive: false)
        )
        assertPassthrough(route)
    }

    private func makeContext(
        appIsActive: Bool = true,
        showCommandPalette: Bool = false,
        showShortcutsHelp: Bool = false,
        showCommitSheet: Bool = false,
        showDiffPanel: Bool = false,
        showPDFPanel: Bool = false,
        sidebarFocused: Bool = false,
        selectedTerminalExists: Bool = true,
        isGraphMode: Bool = false
    ) -> ShortcutContext {
        ShortcutContext(
            appIsActive: appIsActive,
            showCommandPalette: showCommandPalette,
            showShortcutsHelp: showShortcutsHelp,
            showCommitSheet: showCommitSheet,
            showDiffPanel: showDiffPanel,
            showPDFPanel: showPDFPanel,
            sidebarFocused: sidebarFocused,
            selectedTerminalExists: selectedTerminalExists,
            isGraphMode: isGraphMode
        )
    }

    private func assertPassthrough(_ route: ShortcutRoute, file: StaticString = #filePath, line: UInt = #line) {
        guard case .passthrough = route else {
            XCTFail("expected passthrough, got \(route)", file: file, line: line)
            return
        }
    }

    private func assertConsume(_ route: ShortcutRoute, expected: ShortcutCommand, file: StaticString = #filePath, line: UInt = #line) {
        guard case .consume(let command) = route else {
            XCTFail("expected consume(\(expected)), got \(route)", file: file, line: line)
            return
        }
        XCTAssertEqual(command, expected, file: file, line: line)
    }
}
