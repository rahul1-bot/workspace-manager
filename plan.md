# Plan: Fix Diff Panel Scroll Stuttering

## Branch: fix/header-button-alignment
## Status: Header/resize fixes COMMITTED (f245e82). Scroll stutter fixes IMPLEMENTED — build + tests pass.

---

## Context

The diff panel scrolling stutters when viewing git diffs. Root cause analysis found 6 bottlenecks. Two were ALREADY fixed in the codebase (AttributedString rendering, taskIdentity). Two critical ones remain.

## Current State of Each File

### DiffCodeRowView.swift (203 lines) — ALREADY OPTIMIZED
- `renderedCodeText` (line 72-84): Already uses `AttributedString` instead of `.reduce()`. No change needed.
- `taskIdentity` (line 58-60): Already uses `line.id` + `fileExtension` only. No change needed.
- `loadTokens()` (line 191-203): Async tokenization with MainActor update. Fine.

### DiffFileCardView.swift (137 lines) — NEEDS FIX
- `metadataBlock` (line 77-96): `ScrollView(.horizontal)` wrapping metadata lines
- `hunkBlock(for:)` (line 98-124): `ScrollView(.horizontal)` wrapping each hunk
- **Problem**: Each hunk and metadata block gets its own nested horizontal ScrollView. For a 10-file diff with 5 hunks each = 60 nested ScrollViews. During vertical scroll in the parent DiffPanelView, SwiftUI recalculates layout for ALL nested scroll containers, causing O(m^2) layout thrashing.

### DiffSyntaxHighlightingService.swift (237 lines) — NEEDS FIX
- `keywordSet(for:)` (line 205-236): Creates a NEW `Set<String>` with 30-50 items on EVERY `tokenize()` call. Should be cached.
- `tokenize()` (line 79-202): Character-by-character scanning. Algorithm is fine but keyword set allocation adds overhead.
- `cache` (line 22): Token cache by content key. Fine.

### DiffPanelView.swift (211 lines) — MINOR
- Parent ScrollView at line 143: `ScrollView(.vertical)` with `LazyVStack`
- Already uses LazyVStack and `.textSelection(.enabled)`
- The `.clipShape(RoundedRectangle(...))` on `patchContentView` (line 163) forces clipping calculations

---

## Fix 1: Remove Nested Horizontal ScrollViews (HIGH IMPACT)

**File**: `DiffFileCardView.swift`

**Current**: Each `metadataBlock` and `hunkBlock(for:)` wraps its content in `ScrollView(.horizontal)`.

**Fix**: Remove the per-block horizontal ScrollViews. Instead, wrap the entire `contentView` in a single `ScrollView(.horizontal)`. This reduces 60 nested scrollviews to 1 per card.

**Before** (metadataBlock, line 77-96):
```swift
private var metadataBlock: some View {
    ScrollView(.horizontal) {           // <-- REMOVE THIS
        VStack(spacing: 0) {
            ForEach(section.metadataLines) { line in
                DiffCodeRowView(...)
            }
        }
    }
    .background(...)
    .clipShape(...)
    .overlay(...)
}
```

**After** (metadataBlock):
```swift
private var metadataBlock: some View {
    VStack(spacing: 0) {
        ForEach(section.metadataLines) { line in
            DiffCodeRowView(...)
        }
    }
    .background(...)
    .clipShape(...)
    .overlay(...)
}
```

Same for `hunkBlock(for:)` — remove the `ScrollView(.horizontal)` wrapper.

Then wrap the whole `contentView` in ONE horizontal scroll:
```swift
private var contentView: some View {
    ScrollView(.horizontal, showsIndicators: false) {
        VStack(spacing: 8) {
            if !section.metadataLines.isEmpty {
                metadataBlock
            }
            ForEach(section.hunks) { hunk in
                hunkBlock(for: hunk)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
    }
}
```

**Note**: The `DiffCodeRowView` already has `.fixedSize(horizontal: true, vertical: false)` on the code text (line 42), so horizontal content will still extend beyond the viewport and be scrollable.

---

## Fix 2: Cache Keyword Sets (MODERATE IMPACT)

**File**: `DiffSyntaxHighlightingService.swift`

**Current** (line 205-236): `keywordSet(for:)` uses a `switch` that creates a new `Set<String>` literal every call.

**Fix**: Store keyword sets in a static dictionary, computed once at actor init:

```swift
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
    .json: ["true", "false", "null"],
    .shell: ["case", "do", "done", "elif", "else", "esac", "fi", "for", "function", "if", "in", "then", "until", "while"],
    .yaml: ["true", "false", "null", "yes", "no", "on", "off"],
    .markdown: [],
    .plain: []
]

private func keywordSet(for language: SyntaxLanguage) -> Set<String> {
    Self.keywordSets[language] ?? []
}
```

**Note**: `.typescript` shares the same keywords as `.javascript`, so add: `.typescript: [same as .javascript]` or use a computed lookup.

---

## Fix 3 (Optional): Reduce clipShape Overhead

**File**: `DiffFileCardView.swift`

Each hunk block and metadata block has:
```swift
.clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
.overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(...))
```

During scroll, these rounded rectangle shapes are recalculated. Consider using `.cornerRadius(8)` instead of `.clipShape(RoundedRectangle(...))` for simpler clipping, or moving the visual decoration to the background instead of overlay+clip.

---

## Verification Steps

1. `swift build` passes
2. `swift test` passes (54 tests, 0 failures)
3. Manual test: open diff panel with a large diff (e.g., `git stash` some changes), scroll rapidly — should be smooth
4. Test horizontal scroll still works for long lines

## Post-Implementation

1. Update memory.md with engineering decisions
2. Update progress.md with completed items
3. Commit on fix/header-button-alignment branch
4. Merge to dev when satisfied
