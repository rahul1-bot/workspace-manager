import XCTest
import TOMLKit

/// Diagnostic test to verify TOMLKit `as?` casts vs `.string`/`.table`/`.array` property accessors.
final class TOMLParsingDiagnosticTests: XCTestCase {

    private let sampleTOML = """
    [terminal]
    font = "Cascadia Code"
    font_size = 14

    [[workspaces]]
    id = "AAAA-BBBB"
    name = "Root"
    path = "~/some/path"
    terminals = ["Exercise-1", "model-training"]

    [[workspaces]]
    id = "CCCC-DDDD"
    name = "AI-2 Project"
    path = "~/some/other/path"
    terminals = ["code", "course-ledger", "report"]
    """

    // MARK: - Proof that `as?` casts FAIL

    func testAsCastStringFails() throws {
        let table = try TOMLTable(string: sampleTOML)
        let terminalTable = table["terminal"]

        // This is what our code currently does — verify it returns nil
        let fontViaCast = terminalTable as? String
        XCTAssertNil(fontViaCast, "as? String on TOMLValueConvertible should be nil")

        // Even accessing through subscript and casting:
        let fontValueViaCast = table["terminal"]?["font"] as? String
        // The above uses TOMLValueConvertible subscript, which returns TOMLValue?
        // TOMLValue is NOT String, so as? String should fail
        XCTAssertNil(fontValueViaCast, "table[\"terminal\"]?[\"font\"] as? String should be nil")
    }

    func testAsCastTOMLTableFails() throws {
        let table = try TOMLTable(string: sampleTOML)

        // This is what parseTerminalConfig does:
        let terminalViaCast = table["terminal"] as? TOMLTable
        // table["terminal"] returns TOMLValue, not TOMLTable
        XCTAssertNil(terminalViaCast, "as? TOMLTable on TOMLValue should be nil")
    }

    func testAsCastTOMLArrayFails() throws {
        let table = try TOMLTable(string: sampleTOML)
        let workspacesViaCast = table["workspaces"] as? TOMLArray
        XCTAssertNil(workspacesViaCast, "as? TOMLArray on TOMLValue should be nil")
    }

    // MARK: - Proof that property accessors WORK

    func testPropertyAccessorStringWorks() throws {
        let table = try TOMLTable(string: sampleTOML)
        let terminalTable = table["terminal"]?.table
        XCTAssertNotNil(terminalTable, ".table accessor should return TOMLTable")

        let font = terminalTable?["font"]?.string
        XCTAssertEqual(font, "Cascadia Code", ".string accessor should return the value")

        let fontSize = terminalTable?["font_size"]?.int
        XCTAssertEqual(fontSize, 14, ".int accessor should return the value")
    }

    func testPropertyAccessorWorkspacesWork() throws {
        let table = try TOMLTable(string: sampleTOML)
        let workspacesArray = table["workspaces"]?.array
        XCTAssertNotNil(workspacesArray, ".array accessor should return TOMLArray")
        XCTAssertEqual(workspacesArray?.count, 2, "Should have 2 workspaces")
    }

    func testPropertyAccessorWorkspaceFieldsWork() throws {
        let table = try TOMLTable(string: sampleTOML)
        guard let workspacesArray = table["workspaces"]?.array else {
            XCTFail("workspaces array should exist")
            return
        }

        let firstWs = workspacesArray[0].table
        XCTAssertNotNil(firstWs, "First workspace should be a table")

        let name = firstWs?["name"]?.string
        XCTAssertEqual(name, "Root")

        let path = firstWs?["path"]?.string
        XCTAssertEqual(path, "~/some/path")

        let id = firstWs?["id"]?.string
        XCTAssertEqual(id, "AAAA-BBBB")
    }

    func testPropertyAccessorTerminalNamesWork() throws {
        let table = try TOMLTable(string: sampleTOML)
        guard let workspacesArray = table["workspaces"]?.array else {
            XCTFail("workspaces array should exist")
            return
        }

        let firstWs = workspacesArray[0].table
        let terminalsArray = firstWs?["terminals"]?.array
        XCTAssertNotNil(terminalsArray, "terminals array should exist")
        XCTAssertEqual(terminalsArray?.count, 2)

        let names = terminalsArray?.compactMap { $0.string } ?? []
        XCTAssertEqual(names, ["Exercise-1", "model-training"])

        // Second workspace
        let secondWs = workspacesArray[1].table
        let names2 = secondWs?["terminals"]?.array?.compactMap { $0.string } ?? []
        XCTAssertEqual(names2, ["code", "course-ledger", "report"])
    }
}
