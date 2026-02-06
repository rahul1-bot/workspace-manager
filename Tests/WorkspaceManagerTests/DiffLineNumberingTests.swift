import XCTest
@testable import WorkspaceManager

final class DiffLineNumberingTests: XCTestCase {
    func testLineNumbersAdvanceAcrossContextAddDelete() {
        let patch = """
        diff --git a/Sources/File.swift b/Sources/File.swift
        index 1111111..2222222 100644
        --- a/Sources/File.swift
        +++ b/Sources/File.swift
        @@ -10,4 +20,5 @@
         alpha
        -beta
        +betaNew
        +gamma
         delta
        """

        let document = DiffPatchParser().parse(patch)
        guard let lines = document.fileSections.first?.hunks.first?.lines else {
            XCTFail("Missing hunk lines")
            return
        }

        XCTAssertEqual(lines[0].kind, .context)
        XCTAssertEqual(lines[0].oldLineNumber, 10)
        XCTAssertEqual(lines[0].newLineNumber, 20)

        XCTAssertEqual(lines[1].kind, .deletion)
        XCTAssertEqual(lines[1].oldLineNumber, 11)
        XCTAssertNil(lines[1].newLineNumber)

        XCTAssertEqual(lines[2].kind, .addition)
        XCTAssertNil(lines[2].oldLineNumber)
        XCTAssertEqual(lines[2].newLineNumber, 21)

        XCTAssertEqual(lines[3].kind, .addition)
        XCTAssertNil(lines[3].oldLineNumber)
        XCTAssertEqual(lines[3].newLineNumber, 22)

        XCTAssertEqual(lines[4].kind, .context)
        XCTAssertEqual(lines[4].oldLineNumber, 12)
        XCTAssertEqual(lines[4].newLineNumber, 23)
    }

    func testNewFileLineNumbersStartAtOneOnNewSide() {
        let patch = """
        diff --git a/Sources/New.swift b/Sources/New.swift
        new file mode 100644
        index 0000000..1111111
        --- /dev/null
        +++ b/Sources/New.swift
        @@ -0,0 +1,2 @@
        +let a = 1
        +let b = 2
        """

        let document = DiffPatchParser().parse(patch)
        guard let lines = document.fileSections.first?.hunks.first?.lines else {
            XCTFail("Missing hunk lines")
            return
        }

        XCTAssertEqual(lines.count, 2)
        XCTAssertEqual(lines[0].kind, .addition)
        XCTAssertEqual(lines[0].newLineNumber, 1)
        XCTAssertNil(lines[0].oldLineNumber)
        XCTAssertEqual(lines[1].newLineNumber, 2)
    }
}
