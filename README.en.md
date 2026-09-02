# Fuse — Godot Visual Logic Plugin: A Non-Destructive Bridge from AI Prototype to Production Code

[![爱发电](https://img.shields.io/badge/Sponsor-爱发电-ff69b4?style=flat-square)](https://afdian.com/a/kai2045)
[![PayPal](https://img.shields.io/badge/Donate-PayPal-00457C?style=flat-square&logo=paypal)](https://www.paypal.com/paypalme/kai2045)

📖 [中文](README.md) | English

Fuse is a Godot 4.7 visual programming / event system plugin. On the prototype side, three kinds of bricks — Event / Instruction / Condition — are assembled and tuned in the Inspector to build game logic, and AI can generate schema-compliant preset JSON directly. On the exit side, topology and presets are turned into structured handoff artifacts (System partitioning + behavior specs) for **your own AI agent** to write production code free of Fuse — non-coders stay on the Fuse runtime to keep tuning, source Triggers are never touched, and everything can roll back at any time.

**Up and running in 5 minutes**: follow the [Quick Start Guide](addons/fuse/docs/en_US/user_docs/quick_start.md) to build your first Fuse unit.

## Who It's For

- **Non-coding creators**: build logic and tune parameters with Inspector sliders — attack pacing, UI breathing animations. "Tuning" beats "typing".
- **AI-assisted developers**: AI generates preset JSON (schema-constrained + offline validation); humans only review and tweak.
- **Engineering teams**: once a prototype is proven in Fuse, handoff artifacts go to your AI agent to produce production code that no longer depends on Fuse.

## Why a "Bridge"

The most common reason visual scripting systems get rejected is not lack of expressiveness — it's fear of vendor lock-in. Fuse's answer is a bridge that is safe in both directions:

- **Prototype side (outbound)**: AI generates preset JSON (schema-constrained, offline-validatable) → import and it just works; every parameter stays tunable in the Inspector long-term — attack pacing and UI breathing animations, the "tune more than you write" work, respond to slider drags instantly
- **Exit side (return)**: scene topology derives System artifacts (reviewable system-partition JSON IR) → handed to your AI agent together with presets (behavior specs) to write production code **free of Fuse** — Fuse supplies structured facts and never writes the code for you; non-coders stay on the Fuse runtime
- **Non-destructive**: adopt incrementally at the plugin level (optional autoloads, direct apply to existing nodes, no project refactor needed); once a code copy leaves the bridge, the bridge is still there

## Core Features

- **310 ready-to-use components**: 70 events (input, collision, animation, signals, lifecycle…) × 185 instructions (variables, flow, animation, physics, UI, navigation…) × 55 conditions (composite conditions and expression evaluation) — full catalog in `addons/fuse/preset_ai_context/components.json`
- **Variable system**: global / local / scope three-layer variables with runtime watching and editing
- **Preset AI generation loop**: schema-backed component catalog (310 components + condition parameter gating) + offline validator (four rule layers, exit-code gate) + eval regression baseline — every AI-generated preset is statically verifiable
- **Scene topology panel**: a main-screen tab visualizing all Fuse units in the scene (Trigger / MultiEventTrigger / Runner) and cross-unit relations (events, RunRunner calls, variable reads/writes, race warnings), with search/filter and JSON export
- **AI handoff artifacts**: topology export + System partitioning (JSON IR) to feed your own AI agent for writing Fuse-free code (see the next section)
- **Experimental code exporter**: topology → System artifacts → GDScript (a hybrid delegation mode coexisting with the Fuse runtime)
- **Auto component registration**: drop `.gd` files into `instructions/` / `events/` / `conditions/` and they are scanned and registered automatically
- **Localization**: based on Godot TranslationDomain, ships with zh_CN / en_US
- **Multithreading**: the ExecutionContext facade, safe across threads
- **Runtime debugging**: Variable Watcher V2 (history line charts + static declaration analysis) + TCP variable bridge

## From Prototype to Production Code (AI Handoff)

Fuse doesn't write code for you — it produces structured artifacts describing "what the system does, which components it contains, what the behavior specs are", and hands them to your own AI agent to write Fuse-free production code:

```bash
# 1. Export the scene topology (full relations + source scene tracing)
Godot --headless --path . res://addons/fuse/editor/topology/export_topology.tscn -- --scene res://<your_scene>.tscn

# 2. Derive System drafts — one per Trigger/MultiEventTrigger unit (with external event/variable/race warning lists)
Godot --headless --path . res://addons/fuse/editor/graduation/derive_systems.tscn -- --scene res://<your_scene>.tscn

# 3. Review drafts manually (fill in descriptions, acknowledge warnings), then validate
Godot --headless --path . res://addons/fuse/editor/graduation/validate_system.tscn -- <system.json>
```

Hand the topology JSON + System JSON + relevant presets to your AI agent and start writing Fuse-free code; the source Triggers on the Fuse side stay untouched and can roll back anytime. One-click handoff bundling is done by the **fuse-handoff-packer skill** shipped with the plugin (`addons/fuse/agent_skills/fuse-handoff-packer/SKILL.md`, tool-neutral, executable by any AI agent): it confirms systems and templates with you, then produces a self-contained handoff bundle under `fuse_generated/handoff/<system_name>/` (system partitioning / topology / presets / semantic contract / acceptance checklist / component schemas / infrastructure templates). See `fuse_generated/handoff/game_flow/` for a sample.

> **Experimental**: the graduation exporter (`export_system` CLI) can generate GDScript that coexists with the Fuse runtime — whitelisted instructions are translated natively, the rest delegate at runtime. It is not the recommended exit (generated code still depends on the Fuse runtime) and is kept as a reference implementation; see the [Graduation Exporter Guide](addons/fuse/docs/en_US/user_docs/guides/57-graduation-exporter-guide.md).

## Architecture

```
Event (when) ──▶ Instruction (what) ──▶ Condition (whether)
                        │
                        ▼
                ExecutionContext (runtime context)
                        │
                        ▼
                  ActionRunner (executor)

Scene topology ──▶ System artifacts (JSON IR) ──▶ Your AI agent ──▶ Fuse-free production code
                    └──(experimental)──▶ GDScript generator ──▶ bridged runtime (FuseDelegation)
```

**Key base classes:**
- `BaseEvent` — event base class
- `BaseInstruction` — instruction base class
- `BaseCondition` — condition base class
- `ExecutionContext` — execution context (three-layer facade)
- `ActionRunner` — action runner

See [addons/fuse/docs/](addons/fuse/docs/) for details.

## Installation

1. Copy `addons/fuse/` into your Godot 4.7 project's `addons/` directory
2. Project Settings → Plugins → enable "Fuse Visual Programming"
3. (Optional) enable autoloads: `FuseEventBus`, `FuseRuntimeBridge`
4. (Graduation handoff) your AI agent needs to read `addons/fuse/agent_skills/fuse-handoff-packer/SKILL.md` — adding a pointer line in your project's AGENTS.md / CLAUDE.md is recommended

## Requirements

- Godot 4.7+
- Compatible with 2D / 3D projects

## Documentation

- [Quick Start (5 minutes)](addons/fuse/docs/en_US/user_docs/quick_start.md)
- [System Docs](addons/fuse/docs/en_US/system_docs/)
- [User Docs](addons/fuse/docs/en_US/user_docs/)
- [Developer Docs](addons/fuse/docs/en_US/dev_docs/)
- [Multithreading Guide](addons/fuse/docs/en_US/dev_docs/guides/multithreading-developer-guide.md)

## License

MIT License — see [LICENSE](LICENSE)

## Links

- GitHub repository: https://github.com/kenyonxu/fuse
- Issue tracker: https://github.com/kenyonxu/fuse/issues
- Changelog: [CHANGELOG.en.md](addons/fuse/CHANGELOG.en.md) · [中文](addons/fuse/CHANGELOG.md)
- Support: [爱发电 (afdian)](https://afdian.com/a/kai2045) · [PayPal](https://www.paypal.com/paypalme/kai2045)
