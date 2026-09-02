> 🌐 [**中文版**](../../zh_CN/user_docs/FEATURES.md) | English

# Fuse Feature Summary

Fuse is a visual programming plugin for Godot 4.6: it builds game logic by configuring events, instructions, and conditions in the Inspector, with no code required.

## Core Concept

Place Trigger or Runner nodes in the scene, and configure in the Inspector "when to act" (Event), "what to do" (Instruction), and "under what conditions to act" (Condition); everything executes automatically at runtime.

## Component Counts

| Component | Count | Categories |
|------|------|------|
| Instructions | 182 | 17 categories |
| Events | 70 | 14 categories |
| Conditions | 55 | 14 categories |
| Editor tools | 35 | Inspector / generators / debugging |

## Trigger System

Three ways to trigger instruction execution:

**Trigger** — Event-driven. Place a Trigger, bind an Event (e.g. key press, collision), and the instruction sequence in its ActionRunner executes when triggered.

**MultiEventTrigger** — Multi-event merging. A single node manages multiple EventBindings, with independent cooldowns and parallel condition evaluation. Multiple Triggers can be merged or split from the scene tree context menu.

**Runner** — Signal binding or code calls. Bind any signal of any node, and it executes automatically when the signal fires. Supports `await runner.wait_completed()`.

## Instruction Categories

| Category | Count | Examples |
|------|------|------|
| Node operations | 16 | FindNode, SetPropertyValue, InstantiateScene, ReparentNode |
| Flow control | 14 | IfElse, ForLoop, WhileLoop, Wait, BreakLoop |
| Tween animation | 13 | TweenMoveTo, TweenFadeIn, TweenScaleTo, TweenPulseAnimation |
| Array operations | 18 | ArrayAdd, ArraySort, ArrayShuffle, ArrayRandom |
| Dictionary operations | 16 | DictMerge, DictGetByPath, DictToJson, DictMathOp |
| Transform operations | 7 | SetPosition, MoveBy, RotateBy, LookAt |
| Physics | 5 | ApplyImpulse, ApplyForce, SetVelocity, Raycast |
| Math | 7 | MathExpression, MathOperation, Lerp, VectorOperation |
| Animation | 4 | PlayAnimation, StopAnimation, BlendAnimation |
| Audio | 6 | PlaySound, PlayMusic, CrossfadeToMusic, SetAudioVolume |
| Camera | 4 | CameraFollow, CameraShake, SetCameraZoom, SetCameraLimit |
| UI | 4 | SetUIText, SetUITexture, SetUIProgress, ShowHideUI |
| Scene management | 6 | ChangeScene, ReloadScene, LoadSceneBackground |
| Variables | 7 | SetVariable, CreateVariable, SaveGlobalVariables |

## Event Categories

| Category | Count | Examples |
|------|------|------|
| Input | 13 | OnInputKey, OnMouseButton, OnTouchSwipe, OnGamepadButton |
| Physics | 10 | OnBodyEntered, OnCollision, OnRaycastHit, OnShapeCast |
| Lifecycle | 7 | OnReady, OnEnterTree, OnProcess, OnInterval |
| Animation | 6 | OnAnimationFinished, OnAnimationStarted, OnAnimationLoop |
| Node | 4 | OnTargetSignalEmit, OnPropertyChanged, OnNodeInstance |
| UI | 5 | OnButtonPressed, OnTextChanged, OnValueChanged, OnFocus |
| Scene | 5 | OnSceneLoaded, OnSceneAboutToChange, OnTreeChanged |
| Time | 4 | OnTimer, OnCountdown, OnCooldownFinished, OnRealtime |
| Audio | 4 | OnAudioStarted, OnAudioFinished, OnMusicBeat |
| Variables | 1 | OnVariableChanged |

## Condition Categories

| Category | Count | Examples |
|------|------|------|
| Variables | 5 | CheckVariable, CompareVariable, CheckHealthValue |
| Node | 7 | CheckNodeExists, CheckNodeActive, CheckDirection, CheckGroupCount |
| Physics | 5 | CheckOnFloor, CheckInAir, CheckVelocity, CheckOnWall |
| Input | 4 | CheckInputPressed, CheckInputHeld, CheckInputReleased |
| Animation | 4 | CheckIsPlaying, CheckAnimationFinished, CheckAnimationTreeState |
| Composite | 4 | CheckAll (AND), CheckAny (OR), CheckNot (NOT) |
| Math | 1 | ExpressionCondition |
| Time | 4 | CheckTimeReached, CheckGameTime, CheckCountdownFinished |

## Architecture Features

**RuntimeInstance separation** — Resource definitions (Resource) and runtime state (Instance) are separated, enabling pooled reuse; the same ActionRunner resource can be executed concurrently by multiple Triggers without interfering with each other.

**Object pool** — A built-in general-purpose object pool system with warmup and automatic recycling. Instruction instances and scene instances can both be pool-managed, reducing runtime GC pressure.

**Multithreading** — Condition evaluation supports WorkerThreadPool parallel computation (ParallelConditionEvaluator), significantly reducing main-thread load when there are many conditions.

**Execution modes** — ActionRunner supports sequential, parallel, and asynchronous execution modes. Instructions get automatic sync/async detection, and async instructions are awaited automatically.

**Variable system** — Three-layer scopes: local variables (inside the ExecutionContext), scope variables (ScopeVariableContainer subtree), and global variables (GlobalVariableManager singleton). Global variables support saving and loading.

**Compilation cache** — An ActionRunner's instruction sequence can be compiled into a CompiledInstructionSequence, skipping repeated type-checking and initialization overhead.

## Editor Tools

- **Instruction selector** — browse, search, and add instructions to an ActionRunner by category
- **Instruction generator** — automatically generate corresponding instructions from a node's public methods
- **Context menu** — merge/split Triggers in one click
- **Input key selector** — visually pick keyboard, mouse, and gamepad keys
- **Debug panel** — DebugVisualizer + ExecutionTracker for a live view of the execution flow
- **Static analysis** — InstructionAnalyzer.analyze_problems detects the following issues at edit time, flagged in place on the FuseTopology main screen (StatusError / StatusWarning theme icons):
  - **Undeclared local variables** — local variables read/written in instruction chains but never declared via `SetVariable`, including declaration tracing inside nested condition branches
  - **Event-provided variable whitelist** — variables injected into the ExecutionContext by certain events (e.g. OnInput) do not count as undeclared
  - **NodePath resolution failures** — a NodePath referenced by an instruction cannot be resolved to an actual node in the current scene
  - **Signal reference checks** — whether the signal names referenced by EmitSignal instructions exist on the target node
  - **Cross-Trigger variable relations** — write-read arrows / race warnings (multiple Triggers writing the same variable) / orphan writes and reads (written but never read / read but never written)
- **Fuse Topology main screen** — the "Fuse" tab at the top of the editor, an overview of the whole scene's Trigger topology:
  - **Auto refresh** — refreshes automatically on scene switch / scene save (Ctrl+S) (0.5s debounce)
  - **Selection persistence** — automatically restores the previously selected Trigger / instruction entries after a refresh
  - **Double-click navigation** — double-click a Trigger → the Inspector jumps to the scene node; double-click an instruction → the Inspector shows the instruction Resource
  - **Issue filter** — a three-position OptionButton: all / errors only / none
  - **Search filter** — live filtering by unit name / instruction type / variable name / signal name
  - **Runner unit coverage** — L3 Runners shown separately (green), with RunRunner call edges included in the relation scan
  - **Topology JSON export** — provenance fields + full relations, the ground truth for handoff artifacts
  - **Theme icons** — uses Godot theme icons, following the editor's light/dark theme
  - **Inspector issue counts** — a badge on the data-flow button shows that Trigger's issue count; expand the card for details by severity
- **AI handoff artifacts (main exit path)** — topology export + System partitioning (reviewable JSON IR), provided for **the user's AI agent** to write project code that is free of Fuse
- **Graduation exporter (experimental feature)** — derive System artifacts from the topology → generate GDScript (the generated code depends on the Fuse runtime; kept as a reference implementation):
  - **Hybrid instruction delegation** — common instructions are translated natively, the rest delegate to the runtime at run time; graduation is a gradient, not a gate
  - **Non-destructive** — source Triggers are untouched, and the generated output ships with adoption/rollback notes
  - **Validation gates** — 11 codes + topology_digest drift detection + race confirmation
  - **Golden samples** — `fuse_generated/scripts/` (one each for L4/L2, verified at the behavior level)

## Localization

Supports Simplified Chinese and English, with 2498+ translation keys. All user-visible strings are managed centrally through FuseLocalization.

## Code Size

- 271 GDScript files
- 219 test files
- 137 documents
