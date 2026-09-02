> 🌐 [**中文版**](../../../zh_CN/user_docs/Introductions/16-AI协作与毕业交接.md) | English

# AI Collaboration and Graduation Handoff: From "Prototype Proven in Fuse" to "Engineering Code Born off the Bridge"

The previous 15 chapters all covered the "hand-building" leg: how to drag bricks, how to tune variables, how to debug and review. This chapter covers the other leg—also where Fuse pulls ahead of other visual programming plugins: **AI can directly generate Fuse's logic configurations, and stabilized systems can "graduate" into Fuse-independent engineering code—all non-destructive and rollback-safe.** If you have been reading with the worry "will I get locked in by a visual tool", this chapter is the answer.

## 1. Why "Being Able to Graduate" Matters More Than "Being Able to Build"

The reason teams most often refuse to adopt visual scripting systems is not lack of expressiveness—it is "lock-in anxiety": once logic enters the plugin, you can't get out—optimizations wait on plugin updates, handing over to engineers means rewriting from scratch, and migrating a large project is a nightmare.

Fuse answers this on two layers. **The entry layer**: AI-generated logic configurations are schema-carrying JSON, not black boxes—machine-readable, statically validatable, version-controllable. **The exit layer**: any stabilized system can be exported as structured handoff artifacts (system partitioning, behavior specs, component contracts), handed to an engineering-side AI agent to directly write code decoupled from the Fuse runtime. Validation on the way in, artifacts on the way out—this bridge is safe in both directions.

## 2. The Preset AI Generation Loop: Letting AI Write the Logic

Chapter 15 covered how presets let logic move across projects like building blocks. Here we add the AI link: Fuse dumps the "user manuals" of all 310 components into three JSONs under `addons/fuse/preset_ai_context/`—

- **components.json**: the component inventory (type name, category, keywords for each Event / Instruction / Condition);
- **schemas.json**: parameter structures, including condition-registered dynamic parameters and their `requires` gating (picking a certain enum value unlocks the next parameter level, nested level by level);
- **enums.json**: all enum values.

The hands-on flow is very short. Feed these three JSONs to your AI agent and state what you want—for example, "generate a hit-invulnerability-frames preset: driven by an `OnCooldownFinished` event, setting the `invincible` variable back to false". The AI produces a JSON per the schema; then run the offline validator as the gatekeeper:

```bash
Godot --headless --path . res://addons/fuse/editor/preset_ai/validate_preset.tscn -- <preset.json>
# Exit codes: 0 = no errors; 1 = error findings
```

The validator runs four layers of rule checks (structure, component references, parameter types, semantic constraints); any error means a non-zero exit code—which means it can plug straight into CI or scripts as a gate. Once validation passes, import and it's ready to use; fine-tune parameters by hand in the Inspector. **AI builds the structure, humans build the feel**—a clean division of labor.

## 3. Topology Export: Turning the Scene into Structured Facts

The first step of graduation is turning "which logic units actually exist in the scene, and how are they related" into machine-readable facts. This is the CLI version of the chapter 14 Topology main screen:

```bash
Godot --headless --path . res://addons/fuse/editor/topology/export_topology.tscn -- --scene res://<你的场景>.tscn
```

The output is a topology JSON (file name = scene file name): all Trigger / MultiEventTrigger / Runner units in the scene, plus cross-unit relationships—event references, RunRunner call chains, variable reads/writes, signal sends/receives—as well as race warnings and source-scene provenance fields. The arrows and lines you saw on the panel in chapter 14 all land here as structured data.

## 4. System Artifacts: From Topology to System Partitioning

With the topology in hand, the next step is slicing it into "systems" that are friendly to hand off. The derive CLI derives System drafts per Trigger / MultiEventTrigger unit:

```bash
# Derive drafts (the draft directory stays out of git by default)
Godot --headless --path . res://addons/fuse/editor/graduation/derive_systems.tscn -- --scene res://<你的场景>.tscn

# After human review of the draft (fill in description, acknowledge the warning list), validate offline
Godot --headless --path . res://addons/fuse/editor/graduation/validate_system.tscn -- <system.json>
```

The derivation also writes a `_derive_report.json` (skipped items / component inventory / per-unit warnings); human review means working through each issue in that report. validate has built-in `topology_digest` drift detection—if the scene changed and the artifact wasn't updated, validation fails directly with an error, preventing code written against stale specs.

## 5. One-Click Handoff Packaging: the handoff bundle

At this point you hold the topology JSON, the System JSONs, and preset JSONs—but to actually hand them to an AI agent for coding, you still have to answer its string of questions: what is the semantics of these components? How do we verify the code is written correctly? Where does the infrastructure (event bus, global state, object pools) come from? **The fuse-handoff-packer skill** packages all of this in one go:

It ships with the plugin (`addons/fuse/agent_skills/fuse-handoff-packer/SKILL.md`) and is tool-neutral—any AI agent that can read files can execute it. After interacting with you to confirm "which system graduates and which templates are needed", it produces a self-contained handoff bundle at `fuse_generated/handoff/<系统名>/` with eight artifacts:

| Artifact | What it does |
|------|--------|
| `system.json` | Finalized system partitioning (with the acknowledged warning list) |
| `topology.json` | Scene topology snapshot |
| `presets/` | Behavior specs—the presets this system involves |
| `semantics.md` | Semantic contract—behavior conventions for the involved components |
| `README-for-agent.md` | Onboarding for the receiving AI agent |
| `acceptance.md` | Acceptance checklist—how to prove the code is correct once written |
| `components.json` | Schema excerpts for the involved components |
| `templates/` | Infrastructure templates: event bus / global state / object pool |

The repo contains a golden sample you can walk through: `fuse_generated/handoff/game_flow/`—a complete handoff bundle for a game main-flow system, all eight artifacts present; feed it to any AI agent and work can start immediately.

## 6. Exit Boundaries: Mainline and Experimental

The graduation tooling has two exits with different positioning: **derive / validate + handoff packaging is the mainline**—Fuse supplies structured facts, and the engineering code is written by your AI agent, fully decoupled from the Fuse runtime. The other one, the `export_system` CLI, can generate GDScript directly (a hybrid mode of native translation for whitelisted instructions and delegated execution for the rest), but it is currently an **experimental feature**—the generated code still depends on the Fuse runtime, kept only as a reference implementation, not the recommended exit.

## 7. The Non-Destructive Promise

Finally, the full statement of this leg's safety guarantees: the moment the handoff bundle is produced, **nothing on the Fuse side has changed**—the source Triggers stay in place and keep running; colleagues who don't write code remain in the runtime tuning parameters; the engineering code grows elsewhere, gets proven working, and only replaces the runtime once it's live—the bridge stays standing the whole time; and if you ever want to roll back, delete the generated code and return to the pure Fuse runtime, at zero migration cost. Graduation is not farewell—it is more options.

## Series Finale

Sixteen chapters complete: three to get you started, eight core foundations, three moat deep-dives, and this finale. Fuse's full story is one chain: **the brick model handles expression, variables and expressions handle data, flow control and data structures handle logic, animation, physics and UI handle presentation, debugging and Topology handle quality, the engineering quartet handles production, the preset loop handles AI collaboration, and handoff artifacts handle graduation**. From "a designer drags out the first Hello World" to "an engineering team's AI agent takes over the entire system", there is no breakpoint in between—that is the full meaning of the "non-destructive bridge".
