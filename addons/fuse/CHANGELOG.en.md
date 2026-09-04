# Changelog

All notable changes to the Fuse addon will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

> 🌐 [中文](CHANGELOG.md) · English (this page)

## [Unreleased]

### Added
- **Variable watcher runtime editing**: scalar local/scope/global variables can be double-click edited in the watcher and written straight into the running game (bridge reverse `set_var` channel; fire-and-forget with 0.5s push echo; JSON floats narrowed to the target type, non-scalar slot gate, short-write disconnect self-healing)
- **Trigger/MultiEventTrigger last execution context**: BaseTrigger/Runner uniformly keep `current_execution_context(_at_ms)` — local variables of all three core component kinds are visible to the watcher (final values + freshness)
- **Variable watcher v3 host-direct reporting** (bridge protocol v3): pushes report three blocks — `containers`/`units`/`global` — with ScopeVariableContainer direct scanning (declared defaults visible before any trigger), a single root-tree classification pass, the `scene` current-scene-name field (scene grouping), the `__complex` read-only encoding for non-scalars, and constant pushing; write-back dispatches on `target` (container/unit/global)
- **Variable watcher UI rebuild**: native Godot Tree with a three-level hierarchy (scene → host → variable, GLOBAL as a peer root, current/extra suffixes), incremental in-place updates (no flicker/rebuild), collapse state persisted across refreshes, case-insensitive search, a draggable history graph that expands on selection (✕/Esc to close), a double-click edit overlay positioned exactly over the value cell, and full editor-theme adaptation (live light/dark switching, zero hardcoded colors)

### Changed
- Bridge push protocol v2 → v3 (the `runners[]` structure is retired; both sides run the same plugin version, no cross-version compatibility); `get_cached_vars()` returns `{scene, containers, units}`
- `variable_watcher.gd` slimmed from 789 to ~460 lines with the display layer split into `variable_watcher_tree.gd` (data-layer pure functions and edit dispatch semantics unchanged)
- The Global section's runtime data source switches on bridge connectivity (live game snapshot ↔ editor-side definitions); `_write_back_global` changes the value first and preserves variable metadata
- Status bar, scene suffixes and the empty-state hint are localized (3 new keys)

### Removed
- The watcher's static-declaration section (edit-time view) and the variable snapshot dump feature
- 12 unreferenced CSV keys retired; the scope "name+value" dedupe logic and all hand-rolled UI factory code

### Fixed
- Crash when writing back into an Object slot at runtime (game-side non-scalar gate + container type-safe comparison)
- Shared-container variables displayed once per reporting Runner (rooted out by v3 container scanning)
- Untyped early-return arrays spamming a type error every 0.5s
- Double-click edit overlay coordinate mismatch (viewport coordinates assigned to a local position, dropping the input box outside the panel)

## [1.0.0] - 2026-09-03

### Added
- CharacterBody2D movement control system
  - OnInputActionComposite event: multi-directional input listening (up/down/left/right)
  - MoveCharacterBody2DComposite instruction: three movement modes (DIRECT/SMOOTH/ACCELERATION)
  - Full user and developer documentation
  - Integration tests and sample scene
- **Stage 7: Variable Watcher V2 + static declaration fusion**
  - 7a: double-click to edit variable values (global variables writable anytime, local/scope require the scene to be running; type conversion for int/float/bool/String)
  - 7b: 60s history line chart for numeric variables (HistoryGraph custom `_draw`, 120 points / 0.5s sampling, shown on the selected variable row)
  - 7c: static variable declaration injection from instruction chains (`InstructionAnalyzer.build_topology` data source, a dedicated "instruction references (static)" partition, 5s refresh throttle)
  - 7d: `get_snapshot()` completes runners/local/scope snapshots (extracted `_collect_runtime_variables` reusing `_refresh` and the snapshot)
- **FuseRuntimeBridge TCP variable bridge** (option C, see local archive `addons/fuse/docs/archive/roadmap/2026-06-27-runtime-variable-tcp-bridge-plan.md`)
  - Dual-mode Autoload: the editor runs a TCPServer listening on 127.0.0.1:24563, the running game pushes JSON lines as a TCP client
  - JSON line protocol (`\n`-separated): `{"t":"vars","runners":[{"name":"...","local":{...},"scope":{...}}]}`
  - TCP read buffer handles sticky/half packets; cache cleared automatically on disconnect
  - The running game collects local/scope variable snapshots of Runners every 0.5s and pushes them
  - V1 is read-only (local/scope editing needs a reverse channel, future task)
- **Variable Watcher local/scope runtime visibility**: reads variables of the running game instance via the FuseRuntimeBridge cache
  - replaced `EditorInterface.get_edited_scene_root()` Runner scanning with bridge `get_cached_vars()`

### Changed
- Improved the input system architecture to support composite input events
- Added 37 new localization keys for the movement system (9 events + 8 instructions + 20 others)
- `variable_watcher.gd`: value column Label → `_make_value_panel` (double-click LineEdit editing, commit on Enter/focus loss)
- `variable_watcher.gd`: `_render_static_declarations` partition aggregating global/local/scope variables referenced by Trigger instruction chains
- `variable_watcher.gd`: `get_snapshot()` adds a runners array (with per-Runner local/scope snapshots)
- `variable_watcher.gd`: `_collect_runtime_variables` now reads `FuseRuntimeBridge.get_cached_vars()` (replacing EditorInterface scene Runner scanning; V1 local/scope context passed as null, read-only)
- `variable_watcher.gd`: `_make_row_data` adds a `runner` field identifying the variable source
- `fuse_runtime_bootstrap.gd`: added `_register_runtime_bridge()/_unregister_runtime_bridge()` to register/unregister the FuseRuntimeBridge Autoload on plugin start/stop
- `fuse_error.gd`: context output switched to a flat `key=value` format that filters out internal fields (message_key/message_args/component/timestamp) instead of str()-ing the whole dict

### Fixed
- Errors/warnings previously showed only a hardcoded placeholder in the Errors dock: `push_error`/`push_warning` now carry the full structured plain-text message, with the originating call site appended for ERROR level as `(at res://...:line)` (Fuse-internal frames skipped, omitted when no debugger is attached); info/debug keep `print_rich` rich text, and error/warning are no longer printed twice
- `fuse_error.gd`: `create_with_context` logged every error twice (`_init` already logged it, then it logged again manually)
- `fuse_logger.gd`: format-string typo wrapping `[/color]` in an extra pair of brackets (leaving a stray `]` after rendering)
