> 🌐 [**中文版**](../../../zh_CN/system_docs/analysis/serialization_analysis.md) | English

# Serialization and Compiled Cache Analysis Report


> **Analyzed as of**: 2026-07-07 (each article verified against code during the same-day full documentation audit; implementation evolution after this point defers to the source code; for recently verified mechanical conclusions see the threading / runtime_instance / preset_nested articles)
## Document Overview

This report analyzes two pieces of low-level infrastructure in the Fuse visual programming system:

- `InstructionSerializer` (the instruction serializer) — reflective serialization/deserialization of instruction objects
- `CompiledInstructionSequence` (the compiled instruction-sequence cache) — the precompiled cache from the Phase 3 performance optimization

The two belong to different subsystems (persistence vs. runtime performance optimization), but on Fuse's "ActionRunner → RuntimeActionRunnerInstance" execution chain they respectively carry the "state preservation" and "hot-path acceleration" duties — two gaps the analysis series had not previously covered individually.

**Source files:**
- [instruction_serializer.gd](../../../../core/serialization/instruction_serializer.gd) (135 lines)
- [compiled_instruction_sequence.gd](../../../../core/execution/compiled_instruction_sequence.gd) (142 lines)

**Base classes:** both `extends RefCounted` (not Resource; pure logic components)

---

## 1. InstructionSerializer

### 1.1 Class Overview and Responsibilities

`InstructionSerializer` (`core/serialization/instruction_serializer.gd:1-3`) is a `@tool extends RefCounted` utility class responsible for converting instruction objects (`BaseInstruction` subclasses) into plain dictionary data, and rebuilding instruction instances in reverse.

**Design intent (stated in the script header comment):**
> Provides instruction serialization and deserialization, independent of the editor tooling. Ensures core runtime code does not depend on editor modules.

That is: decoupling the "runtime core" from the "editor reflection tooling", so `core/` can dictionary-ize instructions even outside the editor runtime.

### 1.2 Serialization Format

The serialization output is a **flat dictionary**:

```
{
    "type": "<class_name string>",   # type information; required key
    "<property_name1>": <value>,      # every property whose usage includes PROPERTY_USAGE_STORAGE
    "<property_name2>": <value>,
    ...
}
```

Format characteristics:
- No version field, no metadata field; type routing relies solely on the `"type"` key
- Property values are taken as-is from `instruction.get(name)` (no deep copy / type conversion); complex sub-resources (nested Resources) go straight into the dictionary
- The batch API (`serialize_instructions_batch`) produces `Array[Dictionary]` with no outer wrapper structure

### 1.3 API (all static)

| Method | Signature (:line) | Behavior |
|------|--------------|------|
| `serialize_instruction` | `(instruction: BaseInstruction) -> Dictionary` (:16) | Reflects over `PROPERTY_USAGE_STORAGE` properties and writes them into the dictionary; appends `"type"` at the end. An empty instruction returns `{}`. The property list is statically cached by `class_name` (see 1.5) |
| `deserialize_instruction` | `(data: Dictionary) -> BaseInstruction` (:46) | Reads `data["type"]` → `ClassDB.instantiate(type)` creates the instance → iterates the remaining dictionary keys calling `set(name, value)`. Returns `null` if there is no `"type"` key or the type does not exist |
| `serialize_instructions_batch` | `(instructions: Array[BaseInstruction]) -> Array[Dictionary]` (:76) | Calls `serialize_instruction` on every instruction that `is BaseInstruction` |
| `deserialize_instructions_batch` | `(data_array: Array[Dictionary]) -> Array[BaseInstruction]` (:86) | Calls `deserialize_instruction` on every entry, skipping items that return `null` |
| `validate_serialized_data` | `(data: Dictionary) -> bool` (:97) | `data and data.has("type") and ClassDB.class_exists(data["type"])` |
| `get_instruction_description` | `(instruction: BaseInstruction) -> String` (:103) | Hard-coded `match` over a few built-in instruction types (PlaySound/PlayAnimation/ScreenShake/Print/Wait/Count), concatenating a readable description; default returns `class_name` |
| `_create_instruction` | `(type: String) -> BaseInstruction` (:66, private) | `ClassDB.class_exists(type)` ? `ClassDB.instantiate(type)` : `push_error` + return `null` |

**Key constraint of deserialization**: it depends on `ClassDB`. This means every serializable instruction must be declared as `class_name XxxInstruction extends BaseInstruction` and registered with ClassDB via plugin registration (see [plugin.gd:113](../../../../plugin.gd), [fuse_type_registrar.gd:21](../../../../editor/bootstrap/fuse_type_registrar.gd)); otherwise `ClassDB.class_exists()` fails and returns `null`.

### 1.4 Relationship with BaseInstruction

**Key clarification**: `BaseInstruction` (`core/base/base_instruction.gd`) **does not define** `serialize()` or `deserialize()` methods. Verified via `Grep`: the base class only has business methods such as `get_description()`; there is no protocol-style serialization interface.

`InstructionSerializer` is therefore a **purely reflective serializer**:
- Write: scans `instruction.get_property_list()`, filtering properties with `property.usage & PROPERTY_USAGE_STORAGE` (Godot's built-in "will be persisted by ResourceSaver" flag)
- Read: `instruction.set(name, value)`
- It relies not at all on instruction subclasses defining any serialization protocol

The costs and benefits of this design are covered in §3.

### 1.5 Property List Cache

```gdscript
static var _property_cache: Dictionary = {}   # :11
```

- Key: the instruction's `class_name` (obtained via `instruction.get_script().get_class_name()`)
- Value: `Array<StringName>`, containing only `PROPERTY_USAGE_STORAGE` property names
- The first encounter with a type runs full reflection (iterating `get_property_list()`); subsequent hits reuse the cache directly

> Note: `_property_cache` is a process-level static dictionary with no invalidation mechanism. Since GDScript class structure does not change at runtime, this is usually safe; but if scripts are hot-reloaded during development, stale cache entries may remain.

### 1.6 Integration in ActionRunner

`ActionRunner.serialize()` / `deserialize(data)` ([action_runner.gd:608-643](../../../../core/base/action_runner.gd)) uses `InstructionSerializer` to serialize its own configuration:

```
ActionRunner.serialize() → Dictionary
{
    "execution_mode": int,
    "stop_on_error": bool,
    "instructions": [InstructionSerializer.serialize_instruction(i), ...]   # :622
}

ActionRunner.deserialize(data):
    execution_mode = data["execution_mode"]
    stop_on_error = data["stop_on_error"]
    for d in data["instructions"]:
        instructions.append(InstructionSerializer.deserialize_instruction(d))   # :639
```

### 1.7 preload and Global Class Resolution (important clarification)

**Current factual state (verified line by line):**

| File | Line | Content | Status |
|------|------|------|------|
| `action_runner.gd` | :6 | `# const InstructionSerializer = preload(...)` | **Commented out** |
| `action_runner.gd` | :622, :639 | `InstructionSerializer.serialize_instruction(...)` / `deserialize_instruction(...)` | **Active calls** |
| `instruction_serializer.gd` | :3 | `class_name InstructionSerializer` | **Global class** |
| `runtime_action_runner_instance.gd` | :9 | `# const CompiledInstructionSequenceClass = preload(...)` | **Commented out** |
| `action_runner.gd` | :9 | `const CompiledInstructionSequenceClass = preload(...)` | **Active** |

The preload of `InstructionSerializer` at `action_runner.gd:6` is commented out, but thanks to `class_name InstructionSerializer` the symbol is resolved through the global class table (ClassDB) and can still be referenced directly at :622/:639. **The early comment is a historical leftover; the current call chain is fully valid**. [AUDIT_REPORT_2026-07-07.md (Chinese)](../../../zh_CN/system_docs/analysis/AUDIT_REPORT_2026-07-07.md) has already clarified this ("the three directories and the CompiledInstructionSequence/InstructionInstancePool/InstructionSerializer classes all really exist and their references are valid").

### 1.8 The Actual Persistence Path (important)

Although `ActionRunner` itself has the `serialize()/deserialize()` API, **Fuse's mainstream persistence path does not go through it**:

| Persistence target | Mechanism | Uses InstructionSerializer |
|------------|------|------------------------------|
| **Trigger → ActionRunner → instructions in runtime scenes** (saved as `.tscn`/`.tres`) | Godot native Resource serialization (based on `@export` + `PROPERTY_USAGE_STORAGE`) | **No** — done by the Godot engine itself |
| `ActionRunner.serialize()` → Dictionary | Dictionary-izing a "logical snapshot" (for programmatic transfer/cloning) | **Yes** (:622, :639) |
| Preset export/import (`.tres` + `.json` dual write) | `ResourceSaver.save(preset, tres_path)` + `to_json()` | No (goes through `editor/serialization/fuse_preset_serializer.gd`, a separate system) |

In other words, `InstructionSerializer` is not a "save to disk" tool — it is only a tool for "turning instructions into a form that fits in a Dictionary". It is the declaration `@export var instructions: Array[BaseInstruction]` ([action_runner.gd:12](../../../../core/base/action_runner.gd)) that is the real carrier of `.tres` persistence.

---

## 2. CompiledInstructionSequence

### 2.1 Class Overview and Responsibilities

`CompiledInstructionSequence` (`core/execution/compiled_instruction_sequence.gd:1-2`) is the **precompiled instruction-sequence cache** introduced by the Phase 3 performance optimization. The script header comment states the intent:

> Phase 3 performance optimization: precompile the descriptions and method bindings of the instruction sequence, reducing repeated computation overhead during RuntimeActionRunnerInstance execution.
> - Pre-cache description strings (avoiding repeated `get_description()` calls every frame)
> - Pre-bind execution methods (avoiding runtime method lookups)
> - Instruction count change detection (fast cache invalidation)

### 2.2 Cached Data Structures

| Field | Type (:line) | Purpose |
|------|-------------|------|
| `_descriptions` | `PackedStringArray` (:17) | Pre-cached description strings, indexed to match the instructions |
| `_execution_callables` | `Array[Callable]` (:20) | Pre-bound `instruction.execute`, **reserved for Phase 3.2** (not consumed by the hot path currently) |
| `_instruction_count` | `int` (:23) | Instruction count at compile time, for fast invalidation checks |
| `_is_valid` | `bool` (:26) | Overall validity flag of the cache |

### 2.3 API (instance methods)

| Method | Signature (:line) | Behavior |
|------|-------------|------|
| `compile` | `(action_runner: ActionRunner) -> bool` (:40) | Clears both arrays → iterates `action_runner.instructions`: appends `instruction.get_description()` (empty string if null); appends `instruction.execute` if `has_method("execute")`, else `Callable()`. Records `_instruction_count`, sets `_is_valid = true`. If `action_runner == null`, marks invalid and returns `false` directly |
| `is_valid_for` | `(action_runner: ActionRunner) -> bool` (:71) | `_is_valid and action_runner != null and _instruction_count == action_runner.instructions.size()` |
| `get_cached_description` | `(index: int) -> String` (:83) | Returns `_descriptions[index]` after a bounds check; returns `""` when out of range |
| `get_cached_callable` | `(index: int) -> Callable` (:95) | Same, returns `_execution_callables[index]`; returns `Callable()` when out of range |
| `get_instruction_count` | `() -> int` (:106) | Returns `_instruction_count` |
| `is_valid` | `() -> bool` (:113) | Returns `_is_valid` (note: does not compare actual counts; a pure flag query) |
| `invalidate` | `() -> void` (:119) | `_is_valid = false`, clears both arrays, `_instruction_count = 0` |
| `get_cache_stats` | `() -> Dictionary` (:129) | Debug aid; returns a 4-entry status dictionary |
| `get_all_descriptions` | `() -> PackedStringArray` (:141) | Returns a copy of `_descriptions` |

### 2.4 Cache Invalidation Conditions

**The only invalidation check is the "instruction count"** (`is_valid_for`, :74):

```
invalid ⟺  ¬_is_valid  ∨  action_runner == null  ∨  _instruction_count ≠ instructions.size()
```

> **Design trade-off**: only the count is compared quickly; **changes to instruction contents are not detected**. This means:
> - Safe scenario: only "adding/removing instructions" invalidates the cache (the typical editing flow)
> - Risky scenario: modifying only a property value of some instruction (count unchanged) → **the cache does not invalidate and the description stays stale**
>
> Because the setter of `ActionRunner.instructions` ([action_runner.gd:12-16](../../../../core/base/action_runner.gd)) only clears `_validation_cache` and not `_compiled_cache`, "editing instruction properties in place" leaves the description cache stale. In current actual use, descriptions are mainly for debug display (see 2.5), so the impact is limited, but it is a known design gap.

### 2.5 ActionRunner / RuntimeActionRunnerInstance Integration

**Storage location (shared semantics):**

```
ActionRunner (Resource)                       ← definition layer, shareable by multiple Triggers
  └── _compiled_cache: RefCounted = null      # :64, type annotation says CompiledInstructionSequence
                                                ↑ shared as a single instance by all RuntimeActionRunnerInstances
```

**Lazy-load and invalidation detection chain** ([runtime_action_runner_instance.gd:259-288](../../../../core/runtime_action_runner_instance.gd)):

```
RuntimeActionRunnerInstance._get_cached_description(index)    # :284 hot-path entry
  └── _get_or_create_compiled_cache()                          # :259
        ├── cache = action_runner._compiled_cache              # :264 fetch the shared instance
        ├── if cache == null:
        │     cache = CompiledInstructionSequence.new()        # :266 first lazy creation
        │     action_runner._compiled_cache = cache            # :267 write back to the ActionRunner
        └── if not cache.is_valid_for(action_runner):          # :270
              cache.compile(action_runner)                     # :271 recompile if invalid
  └── cache.get_cached_description(index)                      # :287 hit
```

**Consumption point**: only `_get_cached_description(index)` calls it directly, mainly for logging/debug output of instruction descriptions, avoiding repeatedly calling each instruction's `get_description()` (which may involve localization lookups and string concatenation) when `is_running` fires at high frequency.

**Unconsumed reservation**: `_execution_callables` and `get_cached_callable()` currently have **no callers at all** (the script comment marks them "reserved for Phase 3.2"); they are a placeholder for a future "lightweight execution context bypassing method lookups".

### 2.6 Optimization Intent vs. Actual Effect

| Optimization | Implementation status | Current consumption |
|--------|----------|--------------|
| Description string pre-caching | ✅ implemented (`compile`) | ✅ consumed by `_get_cached_description` (hot path) |
| Execution Callable pre-binding | ✅ implemented (`instruction.execute` in `compile`) | ❌ no callers (Phase 3.2 placeholder) |
| Count-based invalidation check | ✅ implemented (`is_valid_for`) | ✅ used by `_get_or_create_compiled_cache` |
| Content-level invalidation detection | ❌ not implemented | — (known gap) |

---

## 3. Comparison and Cooperation of the Two

| Dimension | InstructionSerializer | CompiledInstructionSequence |
|------|----------------------|------------------------------|
| **Subsystem** | `core/serialization/` (persistence layer) | `core/execution/` (runtime execution layer) |
| **Responsibility** | state preservation (dictionary-ization) | performance optimization (precompiled cache) |
| **Base class** | `RefCounted` | `RefCounted` |
| **API style** | all `static` methods | instance methods (stateful) |
| **Trigger timing** | explicit calls (`ActionRunner.serialize/deserialize`) | lazy loading + invalidate-and-recompile |
| **Lifecycle** | stateless (except the static `_property_cache`) | same lifetime as ActionRunner (held by the `_compiled_cache` field) |
| **Sharing scope** | none (each call independent) | all RuntimeActionRunnerInstances of one ActionRunner share it |
| **Invalidation mechanism** | not applicable | count change (`is_valid_for`) + manual `invalidate()` |

The two have no direct call relationship: the serializer does not know the cache exists, and the cache never calls the serializer. They independently serve different facets of ActionRunner.

---

## 4. Overall Assessment

### 4.1 Strengths

1. **Clear responsibilities**: the serializer focuses on "dictionary-ization", the compiled cache on "pre-computation"; the boundary is sharp
2. **Sound decoupling**: `InstructionSerializer` strips the reflection logic out of the `ActionRunner` body, and `CompiledInstructionSequence` strips the caching policy out of the `RuntimeActionRunnerInstance` body — single responsibility
3. **Zero-dependency design**: both `extends RefCounted`, no node references, no signals; safe to use in any context (including `@tool` editor mode)
4. **Effective reflection cache**: `_property_cache` avoids the `get_property_list()` cost on every serialization (the optimization recorded in `archive/proposals/internal_optimization_plan.md` in the archive has landed)
5. **Correct shared-cache semantics**: `_compiled_cache` lives on ActionRunner rather than RuntimeActionRunnerInstance, avoiding a recompile on every Trigger firing

### 4.2 Weaknesses

1. **The serialization format has no version number**: `InstructionSerializer` output has only the `"type"` key and no schema version field; future instruction field changes will face deserialization compatibility problems
2. **`get_instruction_description` is hard-coded** (:103-135): a `match` enumerating 6 built-in instruction types; adding instructions requires changing serializer code — this conflicts with `BaseInstruction.get_description()`'s multilingual localization capability (this hard-concatenates English literals)
3. **The compiled cache lacks content-level invalidation** (see 2.4): descriptions go stale when instruction properties are edited in place
4. **The Phase 3.2 reservation never landed**: `_execution_callables`/`get_cached_callable` still have no consumers — potential dead code
5. **`InstructionSerializer` preload comment leftover** (action_runner.gd:6): relying on global class resolution works, but the comment coexisting with active calls misleads readers; recommend cleanup
6. **The serializer does no deep copy**: complex sub-resource properties go into the dictionary as-is, and after deserialization may share references with the original object (unless the caller intends exactly that)

### 4.3 Suggested Improvements

1. Add a `"schema_version"` field to the `serialize_instruction` output to reserve a migration path
2. Change `get_instruction_description`'s hard-coded `match` to delegate to `instruction.get_description()`, reusing the localization capability
3. Give `CompiledInstructionSequence.is_valid_for` a lightweight content fingerprint (e.g. a hash of the concatenated instruction descriptions) to cover the "property change" scenario
4. If Phase 3.2 is not planned, remove the `_execution_callables` dead code, or document it explicitly as an "API reservation"
5. Clean up the commented preload at `action_runner.gd:6`, or restore the preload to remove the implicit dependency on the global class table

---

## 5. Relationship to the Existing Analysis Docs

| Existing document | Relationship to this article |
|---------|----------|
| [action_runner_analysis.md](action_runner_analysis.md) | That article's §8 briefly describes `CompiledInstructionSequence`; this article expands it into a full API and invalidation-mechanism analysis |
| [fuse_architecture_analysis.md](fuse_architecture_analysis.md) | That article's §11.5.1 mentions `CompiledInstructionSequence`, and its §("Serialization and Deserialization" section) mentions `InstructionSerializer`; this article fills in API details, the preload status clarification, and the distinction of the actual persistence path |
| [AUDIT_REPORT_2026-07-07.md (Chinese)](../../../zh_CN/system_docs/analysis/AUDIT_REPORT_2026-07-07.md) | That article has clarified that "the three directories and the serialization/cache classes all really exist"; this article provides in-depth corroboration |
| [fuse_core_analysis_report.md](fuse_core_analysis_report.md) | That article's §"CompiledInstructionSequence" gives a brief summary; this article is the authoritative expansion |

---

**Maintained by**: Fuse development team
**Last updated**: 2026-07-07
**Version**: 1.0.0
