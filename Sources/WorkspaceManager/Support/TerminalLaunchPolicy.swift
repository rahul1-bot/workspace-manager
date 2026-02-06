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
        let resolvedCwd = try resolvedWorkingDirectory(workingDirectory)

        var environment = sanitizedEnvironment(from: ProcessInfo.processInfo.environment)
        environment["PWD"] = resolvedCwd
        environment["WM_START_CWD"] = resolvedCwd
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

    private static func resolvedWorkingDirectory(_ path: String) throws -> String {
        guard !path.isEmpty, !path.contains("\0") else {
            throw TerminalLaunchError.unsafeWorkingDirectory(path)
        }
        let resolved = URL(fileURLWithPath: path).resolvingSymlinksInPath().path
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: resolved, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw TerminalLaunchError.unsafeWorkingDirectory(path)
        }
        return resolved
    }

    static func fallbackEnvironment() -> [String] {
        sanitizedEnvironment(from: ProcessInfo.processInfo.environment)
            .map { "\($0.key)=\($0.value)" }
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
