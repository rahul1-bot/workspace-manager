import XCTest
@testable import WorkspaceManager

final class DiffPatchParserTests: XCTestCase {
    func testParseStandardUnifiedDiffCreatesSectionsAndHunks() {
        let patch = """
        diff --git a/Sources/A.swift b/Sources/A.swift
        index 1111111..2222222 100644
        --- a/Sources/A.swift
        +++ b/Sources/A.swift
        @@ -1,3 +1,3 @@
         import Foundation
        -let value = 1
        +let value = 2
         print(value)
        diff --git a/README.md b/README.md
        index 3333333..4444444 100644
        --- a/README.md
        +++ b/README.md
        @@ -1,1 +1,2 @@
         # Title
        +More
        """

        let document = DiffPatchParser().parse(patch)

        XCTAssertEqual(document.fileSections.count, 2)

        let first = document.fileSections[0]
        XCTAssertEqual(first.oldPath, "Sources/A.swift")
        XCTAssertEqual(first.newPath, "Sources/A.swift")
        XCTAssertEqual(first.status, .modified)
        XCTAssertEqual(first.additions, 1)
        XCTAssertEqual(first.deletions, 1)
        XCTAssertEqual(first.hunks.count, 1)

        let second = document.fileSections[1]
        XCTAssertEqual(second.newPath, "README.md")
        XCTAssertEqual(second.additions, 1)
        XCTAssertEqual(second.deletions, 0)
    }

    func testParseRecognizesSpecialStatuses() {
        let addedPatch = """
        diff --git a/Sources/New.swift b/Sources/New.swift
        new file mode 100644
        index 0000000..1111111
        --- /dev/null
        +++ b/Sources/New.swift
        @@ -0,0 +1,1 @@
        +let created = true
        """

        let deletedPatch = """
        diff --git a/Sources/Old.swift b/Sources/Old.swift
        deleted file mode 100644
        index 1111111..0000000
        --- a/Sources/Old.swift
        +++ /dev/null
        @@ -1,1 +0,0 @@
        -let removed = true
        """

        let renamedPatch = """
        diff --git a/Sources/OldName.swift b/Sources/NewName.swift
        similarity index 100%
        rename from Sources/OldName.swift
        rename to Sources/NewName.swift
        """

        let binaryPatch = """
        diff --git a/Images/icon.png b/Images/icon.png
        index abcdef0..1234567 100644
        Binary files a/Images/icon.png and b/Images/icon.png differ
        """

        XCTAssertEqual(DiffPatchParser().parse(addedPatch).fileSections.first?.status, .added)
        XCTAssertEqual(DiffPatchParser().parse(deletedPatch).fileSections.first?.status, .deleted)
        XCTAssertEqual(DiffPatchParser().parse(renamedPatch).fileSections.first?.status, .renamed)
        XCTAssertEqual(DiffPatchParser().parse(binaryPatch).fileSections.first?.status, .binary)
    }

    func testParseNoNewlineMarkerCreatesDedicatedLineKind() {
        let patch = """
        diff --git a/a.txt b/a.txt
        index 1234567..89abcde 100644
        --- a/a.txt
        +++ b/a.txt
        @@ -1,1 +1,1 @@
        -value
        +value2
        \\ No newline at end of file
        """

        let document = DiffPatchParser().parse(patch)
        let hunkLines = document.fileSections.first?.hunks.first?.lines ?? []

        XCTAssertEqual(hunkLines.last?.kind, .noNewlineMarker)
        XCTAssertTrue(hunkLines.last?.isNoNewlineMarker ?? false)
    }

    func testIntralineSpansAreDisabledForCleanerRendering() {
        let patch = """
        diff --git a/Sources/A.swift b/Sources/A.swift
        index 1111111..2222222 100644
        --- a/Sources/A.swift
        +++ b/Sources/A.swift
        @@ -1,1 +1,1 @@
        -let value = 100
        +let value = 200
        """

        let document = DiffPatchParser().parse(patch)
        guard let lines = document.fileSections.first?.hunks.first?.lines else {
            XCTFail("Missing parsed lines")
            return
        }

        let deletion = lines.first(where: { $0.kind == .deletion })
        let addition = lines.first(where: { $0.kind == .addition })

        XCTAssertTrue(deletion?.emphasisSpans.isEmpty ?? false)
        XCTAssertTrue(addition?.emphasisSpans.isEmpty ?? false)
    }

    func testFallbackDocumentWhenPatchIsNotUnifiedDiff() {
        let patch = """
        plain line
        -removed
        +added
        """

        let document = DiffPatchParser().parse(patch)

        XCTAssertEqual(document.fileSections.count, 1)
        XCTAssertEqual(document.fileSections.first?.id, "fallback-file-0")
        XCTAssertEqual(document.fileSections.first?.hunks.first?.lines.count, 3)
    }
}
