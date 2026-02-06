import Foundation

actor DiffSyntaxHighlightingService {
    private enum SyntaxLanguage: String {
        case swift
        case python
        case javascript
        case typescript
        case json
        case markdown
        case shell
        case yaml
        case plain
    }

    private enum CommentStyle {
        case slashSlash
        case hash
        case none
    }

    private var cache: [String: [DiffToken]] = [:]

    func tokens(for line: DiffRenderableLine, fileExtension: String?) -> [DiffToken] {
        guard line.kind == .context || line.kind == .addition || line.kind == .deletion else {
            return [DiffToken(text: line.codeText, tokenClass: .plain, start: 0, end: line.codeText.count)]
        }

        let language = language(for: fileExtension)
        let cacheKey = "\(language.rawValue)|\(line.kind.rawValue)|\(line.codeText)"

        if let cached = cache[cacheKey] {
            return cached
        }

        let generated = tokenize(line.codeText, language: language)
        cache[cacheKey] = generated
        return generated
    }

    private func language(for fileExtension: String?) -> SyntaxLanguage {
        guard let ext = fileExtension?.lowercased() else {
            return .plain
        }

        switch ext {
        case "swift":
            return .swift
        case "py":
            return .python
        case "js":
            return .javascript
        case "ts", "tsx":
            return .typescript
        case "json":
            return .json
        case "md", "markdown":
            return .markdown
        case "sh", "bash", "zsh":
            return .shell
        case "yml", "yaml":
            return .yaml
        default:
            return .plain
        }
    }

    private func commentStyle(for language: SyntaxLanguage) -> CommentStyle {
        switch language {
        case .swift, .javascript, .typescript:
            return .slashSlash
        case .python, .shell, .yaml:
            return .hash
        default:
            return .none
        }
    }

    private func tokenize(_ text: String, language: SyntaxLanguage) -> [DiffToken] {
        let characters = Array(text)
        if characters.isEmpty {
            return []
        }

        if language == .markdown, characters.first == "#" {
            return [DiffToken(text: text, tokenClass: .heading, start: 0, end: characters.count)]
        }

        let keywords = keywordSet(for: language)
        let comment = commentStyle(for: language)

        var tokens: [DiffToken] = []
        var cursor = 0

        while cursor < characters.count {
            let current = characters[cursor]

            if current.isWhitespace {
                let start = cursor
                while cursor < characters.count, characters[cursor].isWhitespace {
                    cursor += 1
                }
                let value = String(characters[start..<cursor])
                tokens.append(DiffToken(text: value, tokenClass: .plain, start: start, end: cursor))
                continue
            }

            if comment == .slashSlash,
               current == "/",
               cursor + 1 < characters.count,
               characters[cursor + 1] == "/" {
                let value = String(characters[cursor..<characters.count])
                tokens.append(DiffToken(text: value, tokenClass: .comment, start: cursor, end: characters.count))
                break
            }

            if comment == .hash,
               current == "#" {
                let value = String(characters[cursor..<characters.count])
                tokens.append(DiffToken(text: value, tokenClass: .comment, start: cursor, end: characters.count))
                break
            }

            if current == "\"" || current == "'" {
                let quote = current
                let start = cursor
                cursor += 1
                var escaped = false
                while cursor < characters.count {
                    let value = characters[cursor]
                    if escaped {
                        escaped = false
                    } else if value == "\\" {
                        escaped = true
                    } else if value == quote {
                        cursor += 1
                        break
                    }
                    cursor += 1
                }
                let value = String(characters[start..<min(cursor, characters.count)])
                tokens.append(DiffToken(text: value, tokenClass: .string, start: start, end: min(cursor, characters.count)))
                continue
            }

            if language == .markdown,
               current == "`" {
                let start = cursor
                cursor += 1
                while cursor < characters.count, characters[cursor] != "`" {
                    cursor += 1
                }
                if cursor < characters.count {
                    cursor += 1
                }
                let value = String(characters[start..<cursor])
                tokens.append(DiffToken(text: value, tokenClass: .codeSpan, start: start, end: cursor))
                continue
            }

            if current.isNumber {
                let start = cursor
                var sawDecimal = false
                while cursor < characters.count {
                    let value = characters[cursor]
                    if value == ".", !sawDecimal {
                        sawDecimal = true
                        cursor += 1
                        continue
                    }
                    if !value.isNumber {
                        break
                    }
                    cursor += 1
                }
                let value = String(characters[start..<cursor])
                tokens.append(DiffToken(text: value, tokenClass: .number, start: start, end: cursor))
                continue
            }

            if current.isLetter || current == "_" {
                let start = cursor
                while cursor < characters.count {
                    let value = characters[cursor]
                    if !(value.isLetter || value.isNumber || value == "_") {
                        break
                    }
                    cursor += 1
                }
                let value = String(characters[start..<cursor])
                let tokenClass: DiffTokenClass = keywords.contains(value) ? .keyword : .plain
                tokens.append(DiffToken(text: value, tokenClass: tokenClass, start: start, end: cursor))
                continue
            }

            let start = cursor
            cursor += 1
            let value = String(characters[start..<cursor])
            tokens.append(DiffToken(text: value, tokenClass: .punctuation, start: start, end: cursor))
        }

        return tokens
    }

    private static let keywordSets: [SyntaxLanguage: Set<String>] = [
        .swift: [
            "actor", "as", "async", "await", "break", "case", "catch", "class", "continue", "default", "defer", "do",
            "else", "enum", "extension", "fallthrough", "false", "for", "func", "guard", "if", "import", "in", "init",
            "internal", "let", "mutating", "nil", "private", "protocol", "public", "return", "self", "static", "struct",
            "switch", "throw", "throws", "true", "try", "var", "where", "while"
        ],
        .python: [
            "and", "as", "assert", "async", "await", "break", "class", "continue", "def", "del", "elif", "else",
            "except", "False", "finally", "for", "from", "if", "import", "in", "is", "lambda", "None", "nonlocal",
            "not", "or", "pass", "raise", "return", "True", "try", "while", "with", "yield"
        ],
        .javascript: [
            "async", "await", "break", "case", "catch", "class", "const", "continue", "default", "delete", "else",
            "enum", "export", "extends", "false", "finally", "for", "from", "function", "if", "import", "in", "instanceof",
            "interface", "let", "new", "null", "return", "switch", "this", "throw", "true", "try", "type", "typeof",
            "undefined", "var", "void", "while"
        ],
        .typescript: [
            "async", "await", "break", "case", "catch", "class", "const", "continue", "default", "delete", "else",
            "enum", "export", "extends", "false", "finally", "for", "from", "function", "if", "import", "in", "instanceof",
            "interface", "let", "new", "null", "return", "switch", "this", "throw", "true", "try", "type", "typeof",
            "undefined", "var", "void", "while"
        ],
        .json: ["true", "false", "null"],
        .shell: ["case", "do", "done", "elif", "else", "esac", "fi", "for", "function", "if", "in", "then", "until", "while"],
        .yaml: ["true", "false", "null", "yes", "no", "on", "off"],
        .markdown: [],
        .plain: []
    ]

    private func keywordSet(for language: SyntaxLanguage) -> Set<String> {
        Self.keywordSets[language] ?? []
    }
}
