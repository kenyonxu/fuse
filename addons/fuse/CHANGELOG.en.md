# Changelog

All notable changes to the Fuse addon will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

> 🌐 [中文](CHANGELOG.md) · English (this page)

## [Unreleased]

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
