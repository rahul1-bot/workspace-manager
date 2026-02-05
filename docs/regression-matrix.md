# Regression Matrix

## Mandatory Keyboard and Stability Matrix
1. Context: Terminal focused.
   Expected: `Cmd+C` copy or interrupt path does not terminate the app.
2. Context: Terminal and text-field input.
   Expected: `Cmd+V` paste path does not freeze or kill the app.
3. Context: App focused, command key held for one second.
   Expected: External speech-to-text trigger behavior remains functional.
4. Context: Rapid sequence stress.
   Sequence: `Cmd+P`, `Cmd+.`, `Cmd+R`, `Shift+Cmd+R`, `Cmd+W` (cancel), `Cmd+[`, `Cmd+]`.
   Expected: No deadlock, no stuck modifier state, no process kill.
5. Context: Multi-terminal active process workload.
   Expected: Workspace and terminal switching remain responsive with long-running process.

## Clipboard Matrix
1. ASCII text payload.
2. Unicode payload with multi-byte characters.
3. Large payload near guard limit.
4. Empty payload.

Expected for all: no crash, no undefined render behavior, no raw clipboard data logs.

## Config Matrix
1. Valid config parse.
2. Malformed TOML parse.
3. Duplicate workspace IDs.
4. Invalid workspace ID format.

Expected: non-destructive fallback behavior, explicit typed error logging, preserved app usability.

## Renderer Matrix
1. `use_gpu_renderer = true`
2. `use_gpu_renderer = false`

Expected: keyboard routing and shortcut behavior remain stable in both modes.
