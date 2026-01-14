# Workspace Manager - LYRA.md

## Problem Statement

A simple terminal orchestration app for macOS. The goal is to provide a better workspace management experience than tmux — with a native UI, multiple terminal sessions organized by workspaces, and a clean user experience.

---

## Project Overview

| Field | Value |
|-------|-------|
| Project Name | Workspace Manager |
| Type | Native macOS Application |
| Purpose | Terminal orchestration with workspace management |
| Tech Stack | Swift, SwiftUI, SwiftTerm (CPU renderer) |
| Target | macOS 14+ on Apple Silicon |

---

## Architecture Decision Record

| ADR | Decision | Date: 14 January 2026 | Time: 10:29 PM | Name: Lyra |

### Context
1. Evaluated GPU-accelerated terminal rendering (custom Metal, libghostty, SwiftTerm Metal).
2. No production-ready embeddable GPU terminal library exists for Swift/SwiftUI as of January 2026.
3. The core value is workspace orchestration, not terminal rendering performance.

### Decision
1. Use SwiftTerm CPU renderer for terminal embedding — stable and functional.
2. Focus engineering effort on orchestration features (profiles, workspaces, persistence).
3. Monitor libghostty and SwiftTerm Metal for future GPU adoption when stable.

### Consequences
1. Terminal rendering at ~60Hz is adequate for command-line workflows.
2. Development time goes toward features that differentiate the product.

---

## Current Status

| Status | Focus | Date: 14 January 2026 | Time: 10:29 PM | Name: Lyra |

### What WORKS
1. Native macOS app with SwiftUI interface.
2. Embedded terminal using SwiftTerm with full PTY support.
3. Glass/transparent UI with blur effect (NSVisualEffectView).
4. Workspace sidebar with expandable workspace trees.
5. Multiple terminal sessions per workspace.
6. Bar cursor, Cascadia Code font, 1M line scrollback.

### Immediate Objective
1. Implement user profiles system for workspace persistence.
2. Allow users to create, save, and switch between workspace configurations.

---

## Future Watch Items
1. libghostty Swift framework release (monitor Ghostty releases).
2. SwiftTerm Metal renderer (monitor issue #202).
