import Foundation

struct TerminalLaunchPlan {
    let executable: String
    let args: [String]
    let environment: [String]
}

enum TerminalLaunchPolicy {
    private static let allowedShellPrefixes: [String] = [
        "/bin/",
        "/usr/bin/",
        "/opt/homebrew/bin/"
    ]
    private static let allowedEnvironmentKeys: Set<String> = [
        "HOME", "PATH", "LANG", "LC_ALL", "LC_CTYPE", "TERM", "TMPDIR",
        "USER", "LOGNAME", "SSH_AUTH_SOCK", "SHELL"
    ]

    static func buildPlan(shellFromEnvironment: String?, workingDirectory: String, fallbackShell: String = "/bin/zsh") throws -> TerminalLaunchPlan {
        let rawShell = shellFromEnvironment ?? fallbackShell
        let shell = try canonicalizedShell(rawShell)
        try validateWorkingDirectory(workingDirectory)

        var environment = sanitizedEnvironment(from: ProcessInfo.processInfo.environment)
        environment["PWD"] = workingDirectory
        environment["WM_START_CWD"] = workingDirectory
        environment["WM_EXEC_SHELL"] = shell

        let launchCommand = "cd -- \"$WM_START_CWD\" && exec \"$WM_EXEC_SHELL\" -l"
        return TerminalLaunchPlan(
            executable: shell,
            args: ["-lc", launchCommand],
            environment: environment.map { "\($0.key)=\($0.value)" }
        )
    }

    private static func canonicalizedShell(_ shell: String) throws -> String {
        guard shell.hasPrefix("/") else {
            throw TerminalLaunchError.invalidShellPath(shell)
        }
        guard !shell.contains("..") else {
            throw TerminalLaunchError.invalidShellPath(shell)
        }
        let resolved = URL(fileURLWithPath: shell).standardizedFileURL.path
        guard allowedShellPrefixes.contains(where: { resolved.hasPrefix($0) }) else {
            throw TerminalLaunchError.invalidShellPath(resolved)
        }
        guard FileManager.default.isExecutableFile(atPath: resolved) else {
            throw TerminalLaunchError.nonExecutableShell(resolved)
        }
        return resolved
    }

    private static func validateWorkingDirectory(_ path: String) throws {
        guard !path.isEmpty, !path.contains("\0") else {
            throw TerminalLaunchError.unsafeWorkingDirectory(path)
        }
        let standardized = URL(fileURLWithPath: path).standardizedFileURL.path
        guard FileManager.default.fileExists(atPath: standardized) else {
            throw TerminalLaunchError.unsafeWorkingDirectory(path)
        }
    }

    private static func sanitizedEnvironment(from source: [String: String]) -> [String: String] {
        var sanitized: [String: String] = [:]
        for key in allowedEnvironmentKeys {
            if let value = source[key] {
                sanitized[key] = value
            }
        }
        return sanitized
    }
}
