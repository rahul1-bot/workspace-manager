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
}
