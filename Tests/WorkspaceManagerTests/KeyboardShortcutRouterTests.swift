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

    func testCreateWorktreeSheetConsumesEscape() {
        let visibleContext = makeContext(showCreateWorktreeSheet: true)
        let escapeRoute = router.route(
            keyCode: 53,
            modifierFlags: [],
            charactersIgnoringModifiers: "",
            isRepeat: false,
            context: visibleContext
        )
        assertConsume(escapeRoute, expected: .closeCreateWorktreeSheet)
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

    func testToggleViewModeWorksOutsideGraphMode() {
        let route = router.route(
            keyCode: 5,
            modifierFlags: [.command],
            charactersIgnoringModifiers: "g",
            isRepeat: false,
            context: makeContext(isGraphMode: false)
        )
        assertConsume(route, expected: .toggleViewMode)
    }

    func testToggleViewModeWorksInsideGraphMode() {
        let route = router.route(
            keyCode: 5,
            modifierFlags: [.command],
            charactersIgnoringModifiers: "g",
            isRepeat: false,
            context: makeContext(isGraphMode: true)
        )
        assertConsume(route, expected: .toggleViewMode)
    }

    func testGraphModeZoomIn() {
        let route = router.route(
            keyCode: 24,
            modifierFlags: [.command],
            charactersIgnoringModifiers: "=",
            isRepeat: false,
            context: makeContext(isGraphMode: true)
        )
        assertConsume(route, expected: .graphZoomIn)
    }

    func testGraphModeZoomInWithPlusVariant() {
        let route = router.route(
            keyCode: 24,
            modifierFlags: [.command],
            charactersIgnoringModifiers: "+",
            isRepeat: false,
            context: makeContext(isGraphMode: true)
        )
        assertConsume(route, expected: .graphZoomIn)
    }

    func testGraphModeZoomOut() {
        let route = router.route(
            keyCode: 27,
            modifierFlags: [.command],
            charactersIgnoringModifiers: "-",
            isRepeat: false,
            context: makeContext(isGraphMode: true)
        )
        assertConsume(route, expected: .graphZoomOut)
    }

    func testGraphModeZoomToFit() {
        let route = router.route(
            keyCode: 29,
            modifierFlags: [.command],
            charactersIgnoringModifiers: "0",
            isRepeat: false,
            context: makeContext(isGraphMode: true)
        )
        assertConsume(route, expected: .graphZoomToFit)
    }

    func testGraphModeRerunLayout() {
        let route = router.route(
            keyCode: 37,
            modifierFlags: [.command],
            charactersIgnoringModifiers: "l",
            isRepeat: false,
            context: makeContext(isGraphMode: true)
        )
        assertConsume(route, expected: .graphRerunLayout)
    }

    func testGraphModeEnterFocusesSelectedNode() {
        let route = router.route(
            keyCode: 36,
            modifierFlags: [],
            charactersIgnoringModifiers: "",
            isRepeat: false,
            context: makeContext(isGraphMode: true, hasSelectedGraphNode: true)
        )
        assertConsume(route, expected: .focusSelectedGraphNode)
    }

    func testGraphModeEnterWithoutSelectionPassesThrough() {
        let route = router.route(
            keyCode: 36,
            modifierFlags: [],
            charactersIgnoringModifiers: "",
            isRepeat: false,
            context: makeContext(isGraphMode: true, hasSelectedGraphNode: false)
        )
        assertPassthrough(route)
    }

    func testGraphModeEscapeUnfocusesNode() {
        let route = router.route(
            keyCode: 53,
            modifierFlags: [],
            charactersIgnoringModifiers: "",
            isRepeat: false,
            context: makeContext(isGraphMode: true, hasFocusedGraphNode: true)
        )
        assertConsume(route, expected: .unfocusGraphNode)
    }

    func testGraphModeCmdLOverridesFocusTerminal() {
        let normalRoute = router.route(
            keyCode: 37,
            modifierFlags: [.command],
            charactersIgnoringModifiers: "l",
            isRepeat: false,
            context: makeContext(isGraphMode: false)
        )
        assertConsume(normalRoute, expected: .focusTerminal)

        let graphRoute = router.route(
            keyCode: 37,
            modifierFlags: [.command],
            charactersIgnoringModifiers: "l",
            isRepeat: false,
            context: makeContext(isGraphMode: true)
        )
        assertConsume(graphRoute, expected: .graphRerunLayout)
    }

    func testShiftCmdWTriggersNewWorktree() {
        let route = router.route(
            keyCode: 13,
            modifierFlags: [.command, .shift],
            charactersIgnoringModifiers: "w",
            isRepeat: false,
            context: makeContext(showPDFPanel: false)
        )
        assertConsume(route, expected: .newWorktree)
    }

    func testShiftCmdFTriggersRefreshWorktrees() {
        let route = router.route(
            keyCode: 3,
            modifierFlags: [.command, .shift],
            charactersIgnoringModifiers: "f",
            isRepeat: false,
            context: makeContext()
        )
        assertConsume(route, expected: .refreshWorktrees)
    }

    func testShiftCmdDTriggersOpenWorktreeDiff() {
        let route = router.route(
            keyCode: 2,
            modifierFlags: [.command, .shift],
            charactersIgnoringModifiers: "d",
            isRepeat: false,
            context: makeContext()
        )
        assertConsume(route, expected: .openWorktreeDiff)
    }

    func testOptionCmdBracketRoutesWorktreeSwitching() {
        let previousRoute = router.route(
            keyCode: 33,
            modifierFlags: [.command, .option],
            charactersIgnoringModifiers: "[",
            isRepeat: false,
            context: makeContext()
        )
        assertConsume(previousRoute, expected: .previousWorktree)

        let nextRoute = router.route(
            keyCode: 30,
            modifierFlags: [.command, .option],
            charactersIgnoringModifiers: "]",
            isRepeat: false,
            context: makeContext()
        )
        assertConsume(nextRoute, expected: .nextWorktree)
    }

    func testGraphZoomShortcutsIgnoredOutsideGraphMode() {
        let zoomInRoute = router.route(
            keyCode: 24,
            modifierFlags: [.command],
            charactersIgnoringModifiers: "=",
            isRepeat: false,
            context: makeContext(isGraphMode: false)
        )
        assertPassthrough(zoomInRoute)

        let zoomOutRoute = router.route(
            keyCode: 27,
            modifierFlags: [.command],
            charactersIgnoringModifiers: "-",
            isRepeat: false,
            context: makeContext(isGraphMode: false)
        )
        assertPassthrough(zoomOutRoute)

        let zoomToFitRoute = router.route(
            keyCode: 29,
            modifierFlags: [.command],
            charactersIgnoringModifiers: "0",
            isRepeat: false,
            context: makeContext(isGraphMode: false)
        )
        assertPassthrough(zoomToFitRoute)
    }

    func testEscapePriorityPDFPanelOverGraphNode() {
        let route = router.route(
            keyCode: 53,
            modifierFlags: [],
            charactersIgnoringModifiers: "",
            isRepeat: false,
            context: makeContext(showPDFPanel: true, isGraphMode: true, hasFocusedGraphNode: true)
        )
        assertConsume(route, expected: .closePDFPanel)
    }

    func testShiftCmdSlashOpensShortcutsHelp() {
        let route = router.route(
            keyCode: 44,
            modifierFlags: [.command, .shift],
            charactersIgnoringModifiers: "?",
            isRepeat: false,
            context: makeContext()
        )
        assertConsume(route, expected: .toggleShortcutsHelp)
    }

    func testEscapeUnfocusGraphNodeOverSidebar() {
        let route = router.route(
            keyCode: 53,
            modifierFlags: [],
            charactersIgnoringModifiers: "",
            isRepeat: false,
            context: makeContext(sidebarFocused: true, isGraphMode: true, hasFocusedGraphNode: true)
        )
        assertConsume(route, expected: .unfocusGraphNode)
    }

    func testEscapeRenamePriorityOverDiffPanel() {
        let route = router.route(
            keyCode: 53,
            modifierFlags: [],
            charactersIgnoringModifiers: "",
            isRepeat: false,
            context: makeContext(showDiffPanel: true, sidebarFocused: true, isRenaming: true)
        )
        assertConsume(route, expected: .sidebarCancelRename)
    }

    func testEscapeCreateWorktreePriorityOverDiffPanel() {
        let route = router.route(
            keyCode: 53,
            modifierFlags: [],
            charactersIgnoringModifiers: "",
            isRepeat: false,
            context: makeContext(showCreateWorktreeSheet: true, showDiffPanel: true)
        )
        assertConsume(route, expected: .closeCreateWorktreeSheet)
    }

    private func makeContext(
        appIsActive: Bool = true,
        showCommandPalette: Bool = false,
        showShortcutsHelp: Bool = false,
        showCreateWorktreeSheet: Bool = false,
        showCommitSheet: Bool = false,
        showDiffPanel: Bool = false,
        showPDFPanel: Bool = false,
        sidebarFocused: Bool = false,
        isRenaming: Bool = false,
        selectedTerminalExists: Bool = true,
        isGraphMode: Bool = false,
        hasFocusedGraphNode: Bool = false,
        hasSelectedGraphNode: Bool = false
    ) -> ShortcutContext {
        ShortcutContext(
            appIsActive: appIsActive,
            showCommandPalette: showCommandPalette,
            showShortcutsHelp: showShortcutsHelp,
            showCreateWorktreeSheet: showCreateWorktreeSheet,
            showCommitSheet: showCommitSheet,
            showDiffPanel: showDiffPanel,
            showPDFPanel: showPDFPanel,
            sidebarFocused: sidebarFocused,
            isRenaming: isRenaming,
            selectedTerminalExists: selectedTerminalExists,
            isGraphMode: isGraphMode,
            hasFocusedGraphNode: hasFocusedGraphNode,
            hasSelectedGraphNode: hasSelectedGraphNode
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
