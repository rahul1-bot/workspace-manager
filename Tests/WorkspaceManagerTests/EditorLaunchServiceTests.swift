import XCTest
@testable import WorkspaceManager

final class EditorLaunchServiceTests: XCTestCase {
    func testAvailableEditorsAlwaysContainsFinder() async {
        let service = EditorLaunchService()
        let editors = await service.availableEditors()
        XCTAssertTrue(editors.contains(.finder))
    }

    func testPreferredEditorPersistenceByWorkspaceID() async {
        let service = EditorLaunchService()
        let workspaceID = UUID()

        await service.setPreferredEditor(.finder, for: workspaceID)
        let preferred = await service.preferredEditor(for: workspaceID)

        XCTAssertEqual(preferred, .finder)
    }

    func testZedBundleIdentifiersIncludePreview() {
        XCTAssertTrue(EditorLaunchService.zedBundleIdentifiers.contains("dev.zed.Zed-Preview"))
    }

    func testZedLaunchModePrefersCLIWhenAvailable() {
        let launchMode = EditorLaunchService.preferredLaunchMode(
            for: .zed,
            appAvailable: true,
            zedCLIAvailable: true
        )
        XCTAssertEqual(launchMode, .cli)
    }
}
