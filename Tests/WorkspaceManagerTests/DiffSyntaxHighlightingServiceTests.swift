import XCTest
@testable import WorkspaceManager

final class DiffSyntaxHighlightingServiceTests: XCTestCase {
    func testSwiftTokenizationFindsKeywordStringAndComment() async {
        let service = DiffSyntaxHighlightingService()
        let line = DiffRenderableLine(
            id: "line-1",
            kind: .addition,
            rawText: "+let value = \"hi\" // note",
            codeText: "let value = \"hi\" // note",
            oldLineNumber: nil,
            newLineNumber: 1,
            isNoNewlineMarker: false
        )

        let tokens = await service.tokens(for: line, fileExtension: "swift")

        XCTAssertTrue(tokens.contains(where: { $0.tokenClass == .keyword && $0.text == "let" }))
        XCTAssertTrue(tokens.contains(where: { $0.tokenClass == .string && $0.text.contains("\"hi\"") }))
        XCTAssertTrue(tokens.contains(where: { $0.tokenClass == .comment && $0.text.contains("// note") }))
    }

    func testPythonTokenizationFindsKeywordAndHashComment() async {
        let service = DiffSyntaxHighlightingService()
        let line = DiffRenderableLine(
            id: "line-2",
            kind: .context,
            rawText: "for value in items: # loop",
            codeText: "for value in items: # loop",
            oldLineNumber: 1,
            newLineNumber: 1,
            isNoNewlineMarker: false
        )

        let tokens = await service.tokens(for: line, fileExtension: "py")

        XCTAssertTrue(tokens.contains(where: { $0.tokenClass == .keyword && $0.text == "for" }))
        XCTAssertTrue(tokens.contains(where: { $0.tokenClass == .comment && $0.text.contains("# loop") }))
    }

    func testMarkdownTokenizationHandlesCodeSpan() async {
        let service = DiffSyntaxHighlightingService()
        let line = DiffRenderableLine(
            id: "line-3",
            kind: .context,
            rawText: "Use `code` block",
            codeText: "Use `code` block",
            oldLineNumber: 1,
            newLineNumber: 1,
            isNoNewlineMarker: false
        )

        let tokens = await service.tokens(for: line, fileExtension: "md")

        XCTAssertTrue(tokens.contains(where: { $0.tokenClass == .codeSpan && $0.text == "`code`" }))
    }

    func testUnknownExtensionFallsBackToPlainTokens() async {
        let service = DiffSyntaxHighlightingService()
        let line = DiffRenderableLine(
            id: "line-4",
            kind: .context,
            rawText: "alpha beta",
            codeText: "alpha beta",
            oldLineNumber: 1,
            newLineNumber: 1,
            isNoNewlineMarker: false
        )

        let tokens = await service.tokens(for: line, fileExtension: "unknown")

        XCTAssertFalse(tokens.isEmpty)
        XCTAssertFalse(tokens.contains(where: { $0.tokenClass == .keyword }))
    }

    func testNonCodeLineReturnsSinglePlainToken() async {
        let service = DiffSyntaxHighlightingService()
        let line = DiffRenderableLine(
            id: "line-5",
            kind: .fileMeta,
            rawText: "index abc..def",
            codeText: "index abc..def",
            oldLineNumber: nil,
            newLineNumber: nil,
            isNoNewlineMarker: false
        )

        let tokens = await service.tokens(for: line, fileExtension: "swift")

        XCTAssertEqual(tokens.count, 1)
        XCTAssertEqual(tokens.first?.tokenClass, .plain)
    }

    func testCachedTokenizationReturnsStableOutput() async {
        let service = DiffSyntaxHighlightingService()
        let line = DiffRenderableLine(
            id: "line-6",
            kind: .deletion,
            rawText: "-const value = 42",
            codeText: "const value = 42",
            oldLineNumber: 8,
            newLineNumber: nil,
            isNoNewlineMarker: false
        )

        let first = await service.tokens(for: line, fileExtension: "ts")
        let second = await service.tokens(for: line, fileExtension: "ts")

        XCTAssertEqual(first, second)
    }
}
