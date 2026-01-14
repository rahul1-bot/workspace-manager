# Phase 1: Config-Driven Workspace Manager

## Objective
Convert the app from hardcoded workspaces to a TOML config-driven approach.

---

## Task Decomposition

### Agent-1: Add TOML Dependency & Config Models
**Scope**: Package.swift, new Config.swift file
**Tasks**:
1. Add TOMLKit dependency to Package.swift
2. Create `Sources/WorkspaceManager/Models/Config.swift` with:
   - `AppConfig` struct (terminal config + workspaces array)
   - `TerminalConfig` struct (font, fontSize, scrollback, cursorStyle)
   - `WorkspaceConfig` struct (name, path)
**Output**: Package builds with new dependency and models

---

### Agent-2: Create ConfigService
**Scope**: New ConfigService.swift file
**Tasks**:
1. Create `Sources/WorkspaceManager/Services/ConfigService.swift`
2. Implement `loadConfig()` function:
   - Read from `~/.config/workspace-manager/config.toml`
   - Parse TOML into AppConfig
   - Expand `~` to home directory in paths
   - Validate paths exist (warn if not, don't crash)
3. Implement `createDefaultConfig()`:
   - Create default config file if none exists
   - Include our workspaces (Root + courses)
   - Include default terminal settings
**Output**: ConfigService can load and create TOML configs

---

### Agent-3: Update AppState to Use Config
**Scope**: AppState.swift
**Tasks**:
1. Remove hardcoded `defaultWorkspaces` array
2. Remove hardcoded `defaultRoot` path
3. Add call to `ConfigService.loadConfig()` in init
4. Convert `WorkspaceConfig` array to `Workspace` objects
5. Keep JSON persistence for runtime state (terminals, expansion)
**Output**: AppState loads workspaces from TOML config

---

### Agent-4: Update TerminalView to Use Config
**Scope**: TerminalView.swift
**Tasks**:
1. Read terminal config from ConfigService (font, fontSize, cursorStyle)
2. Apply settings dynamically instead of hardcoded values
3. Handle missing config gracefully (use defaults)
**Output**: Terminal respects config file settings

---

## Execution Order
1. Agent-1 first (dependency + models needed by others)
2. Agent-2 second (ConfigService needed by AppState)
3. Agent-3 third (AppState integration)
4. Agent-4 fourth (TerminalView integration)

---

## Default Config Content

```toml
# Workspace Manager Configuration
# Location: ~/.config/workspace-manager/config.toml

[terminal]
font = "Cascadia Code"
font_size = 14
scrollback = 1000000
cursor_style = "bar"

[[workspaces]]
name = "Root"
path = "~/Library/CloudStorage/OneDrive-Personal/Documents/StudyDocuments/Rahul"

[[workspaces]]
name = "AI-2 Project"
path = "~/Library/CloudStorage/OneDrive-Personal/Documents/StudyDocuments/Rahul/10) AI-2 Project (Majors-2)(10 ETCS)(Coding Project)"

[[workspaces]]
name = "Computational Imaging"
path = "~/Library/CloudStorage/OneDrive-Personal/Documents/StudyDocuments/Rahul/38) Computational Imaging Project (Applications-12)(10 ETCS)(Coding Project)"

[[workspaces]]
name = "Representation Learning"
path = "~/Library/CloudStorage/OneDrive-Personal/Documents/StudyDocuments/Rahul/19) Project-Representation-Learning (Minor-5)(10 ETCS)(Coding Project)"

[[workspaces]]
name = "Research Movement Analysis"
path = "~/Library/CloudStorage/OneDrive-Personal/Documents/StudyDocuments/Rahul/39) Research Movement Analysis (Seminar-3)(5 ETCS)(Report-Presentation)"

[[workspaces]]
name = "ML in MRI"
path = "~/Library/CloudStorage/OneDrive-Personal/Documents/StudyDocuments/Rahul/16) ML in MRI (Majors-3 OR Seminar-1)(5 ETCS)(Presentation-Exam)"
```

---

## Verification
1. `swift build` succeeds
2. App launches and reads config from `~/.config/workspace-manager/config.toml`
3. Sidebar shows workspaces defined in config
4. Terminal uses font/size/cursor from config
5. Edit config → restart → changes apply
