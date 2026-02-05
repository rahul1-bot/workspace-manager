import XCTest
@testable import WorkspaceManager

final class TerminalLaunchPolicyTests: XCTestCase {
    func testBuildPlanAcceptsSafeShellAndDirectory() throws {
        let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
        try FileManager.default.createDirectory(atPath: tempDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: tempDirectory) }

        let plan = try TerminalLaunchPolicy.buildPlan(shellFromEnvironment: "/bin/zsh", workingDirectory: tempDirectory)

        XCTAssertEqual(plan.executable, "/bin/zsh")
        XCTAssertEqual(plan.args.first, "-lc")
        XCTAssertTrue(plan.environment.contains(where: { $0 == "PWD=\(tempDirectory)" }))
    }

    func testBuildPlanRejectsNonAbsoluteShell() {
        let tempDirectory = FileManager.default.temporaryDirectory.path

        XCTAssertThrowsError(
            try TerminalLaunchPolicy.buildPlan(shellFromEnvironment: "zsh", workingDirectory: tempDirectory)
        ) { error in
            guard case TerminalLaunchError.invalidShellPath = error else {
                XCTFail("expected invalidShellPath, got \(error)")
                return
            }
        }
    }

    func testBuildPlanRejectsNonExecutableShell() {
        let tempDirectory = FileManager.default.temporaryDirectory.path

        XCTAssertThrowsError(
            try TerminalLaunchPolicy.buildPlan(shellFromEnvironment: "/bin/does-not-exist", workingDirectory: tempDirectory)
        ) { error in
            guard case TerminalLaunchError.nonExecutableShell = error else {
                XCTFail("expected nonExecutableShell, got \(error)")
                return
            }
        }
    }

    func testBuildPlanRejectsInvalidWorkingDirectory() {
        XCTAssertThrowsError(
            try TerminalLaunchPolicy.buildPlan(shellFromEnvironment: "/bin/zsh", workingDirectory: "/path/that/does/not/exist")
        ) { error in
            guard case TerminalLaunchError.unsafeWorkingDirectory = error else {
                XCTFail("expected unsafeWorkingDirectory, got \(error)")
                return
            }
        }
    }
}
