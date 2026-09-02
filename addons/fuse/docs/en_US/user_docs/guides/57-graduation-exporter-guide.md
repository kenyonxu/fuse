> 🌐 [**中文版**](../../../zh_CN/user_docs/guides/57-graduation-exporter-guide.md) | English

# Graduation Exporter User Guide (Experimental Feature)

> **Direction revision (2026-09-01)**: Fuse's main exit path is now the **AI handoff artifact** — topology + System decomposition + presets feed **the user's own AI agent** to write code free of Fuse; Fuse no longer writes code on your behalf (`derive_systems` / `validate_system` CLIs remain mainline components). The **GDScript generation (`export_system`) described in this guide has been demoted to an experimental feature**: the generated code still depends on the Fuse runtime (FuseDelegation + component classes + autoload) and is not a "free of Fuse" export; it is kept as a reference implementation and material for semantic-equivalence research. For the mainline workflow see [README](../../../../../../README.md), "从原型到工程代码".

The graduation exporter provides an **experimental export path from Fuse prototypes to GDScript**: it derives System artifacts from scene topology and generates readable, verifiable GDScript that coexists with the Fuse runtime, one System at a time. It is "non-destructive" — the exporter only produces new files, never touching the scene or the source Triggers; rollback is simply the reverse operation.

> When to use it: a piece of game logic has been tuned to stability in Fuse (attack timing, UI breathing, level flow) and needs to be handed over to a programmer or maintained outside the visual layer — use the graduation exporter to "graduate" it into GDScript. Logic still being tuned frequently is better left on the Fuse side — the Inspector slider feedback loop is shorter.

---

## Core Concepts

| Concept | Description |
|------|------|
| **System artifact** | A reviewable JSON IR (`fuse_generated/systems/<name>.json`): what this system does (description), which units it contains (units), where its boundaries are (externals: outgoing events/variables), and acknowledged race warnings. A human (or AI) can edit it on top of the derived draft |
| **Bridge pattern** | The generated GDScript coexists with the Fuse runtime through `FuseDelegation` (`core/graduation/`): variables go through the three-layer variable service, events go through the FuseEventBus, and non-whitelisted instructions are embedded as data and executed by runtime delegation |
| **Mixed instruction delegation** | Common instructions (Wait/Print/SendEvent/variable read-write/MathOperation/UI text & visibility/global variable save-load) are translated natively into readable code; all other instructions are serialized as embedded JSON and rebuilt at runtime — graduation is a gradient, not a gate, and coverage will rise as the whitelist expands |
| **Non-destructive** | Source Trigger nodes stay as they are (merely disabled); the generated script's header comment carries full adoption and rollback steps; and after the code copy leaves the bridge, the bridge remains |

## Workflow (Four Steps)

```bash
# ① Derive drafts — one per Trigger/MultiEventTrigger unit (Runner units and nested scene units are not derived yet)
Godot --headless --path . res://addons/fuse/editor/graduation/derive_systems.tscn -- \
  --scene res://demos/fuse/fuse_adventure/scenes/fuse_demo_level_01.tscn
# Output: fuse_generated/systems/drafts/<name>.json + _derive_report.json (with the race-warning quadruple list)

# ② Manual confirmation — copy the units you want from drafts/ into a formal System (fuse_generated/systems/<name>.json),
#    fill in description, and copy the warnings_by_unit entries from _derive_report.json wholesale into acknowledged_warnings

# ③ Validate — unit existence, level consistency, resolvable externals, races acknowledged, topology_digest un-drifted
Godot --headless --path . res://addons/fuse/editor/graduation/validate_system.tscn -- <system.json>
# Exit codes: 0 = pass; 1 = error findings; 2 = argument/IO error

# ④ Generate — runs validation internally first (refuses to generate on failure), producing scripts + readiness report
Godot --headless --path . res://addons/fuse/editor/graduation/export_system.tscn -- <system.json>
# Output: fuse_generated/scripts/<name>.gd + <name>.report.md (coverage / delegation list / risk notes)
```

Golden samples: `fuse_generated/scripts/game_flow.gd` (L4 multi-event) and `hint_breath.gd` (L2 timer).

## Adoption and Rollback

The generated script's header comment carries the operating instructions, expanded below:

**Adoption (moving the logic from Fuse to code):**
1. **Disable** the source Trigger/MultiEventTrigger node in the scene (the toggle at the top of the Inspector; do not delete it)
2. Attach the generated script to the **same-path node** (the delegated instructions' relative NodePaths are anchored to the attachment point; changing nodes breaks them)
3. Run the scene to verify behavior, checking the `.report.md` coverage and risk notes

**Rollback:**
1. Re-enable the source Trigger node
2. Remove the generated script (or disable it first and observe)

## How to Read the Readiness Report

`.report.md` contains:

- **Coverage**: natively translated instructions / total instructions (including nested). The golden sample game_flow is 1/28 — many instructions carry LOCAL variable passing, so the whole binding is delegated wholesale for fidelity (see item 5 under "Known semantic deviations" below)
- **Delegation list**: which instructions went through runtime delegation
- **Risk notes** (shown as needed): input event timing differences / CheckAnyInput stop-condition probing window / failed conditions do not enter cooldown / RESTART degradation / LOCAL wholesale delegation

## Known Semantic Deviations (Read Before Adopting)

The generated code and the Fuse runtime differ in the following documented ways; check them against your own system before adopting:

1. **RESTART re-trigger policy degraded to SKIP**: if the source binding configured RESTART (cancel current run and restart), the generated code behaves as SKIP (ignore new triggers while running) — the validator emits a `W_RESTART_DEGRADED` warning. Confirm manually that by the time this binding re-triggers, the previous run has usually finished
2. **Input event timing**: the generated code uses the `Input` singleton inside `_unhandled_input` (isomorphic with Fuse), but the intra-frame ordering relative to engine input processing may differ
3. **CheckAnyInput stop condition**: Fuse's 2×interval probing-window semantics are not fully reproduced; the generated code probes instantly every tick
4. **Failed conditions do not enter cooldown**: Fuse starts cooling once the cooldown check passes (failed conditions also enter cooldown); the generated code does not consume cooldown on failure, so retries are more aggressive
5. **LOCAL variables and wholesale delegation**: if any instruction in a binding (including nested ones) reads or writes a LOCAL variable, the entire binding goes through runtime delegation to guarantee variable continuity — lower coverage is the price, semantic fidelity the goal
6. **Unsupported events/configurations**: event types beyond the whitelisted four (OnReady/OnInputAction/OnInterval/OnReceiveEvent), L3 Runner units, PARALLEL mixed native-line batching, and similar cases are refused with an itemized list

## Future Direction

The main exit path has shifted to **AI handoff artifacts** (handoff bundle: System + topology + presets + component schemas + semantic contracts, packaged for the user's AI agent to write Fuse-free code). The semantic conclusions this exporter validated — the busy guard clause reproducing SKIP re-triggering, LOCAL variables needing continuity through a single ctx, the two-phase gate of "only consume trigger_once when conditions pass" — will be distilled into the handoff artifact's **semantic contracts**, guiding the AI agent to write behaviorally equivalent code. Original phase-two items such as multi-unit materialization and whitelist expansion are no longer pursued under the shifted mainline.

**The main exit path has landed**: `addons/fuse/agent_skills/fuse-handoff-packer/` — an interactive handoff-packing skill producing the self-contained bundle needed to code without Fuse (sample at `fuse_generated/handoff/game_flow/`). This exporter's (experimental GDScript generation) semantic conclusions have been distilled into the bundle's semantic contracts.

## Related Docs

- Mainline exit walkthrough (user-facing): [16-AI协作与毕业交接](../Introductions/16-ai-collaboration-and-graduation-handoff.md)
- Scene topology panel: [00-editor-panels-overview.md](00-editor-panels-overview.md)
- Preset system (outbound trip): [55-preset-system-guide.md](55-preset-system-guide.md)
