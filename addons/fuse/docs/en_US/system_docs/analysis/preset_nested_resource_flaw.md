> 🌐 [**中文版**](../../../zh_CN/system_docs/analysis/preset_nested_resource_flaw.md) | English

# Preset Deserialization Nested Resource Flaw Analysis and Fix Plan

> **Discovered on**: 2026-08-10
> **Triggering scenario**: B2 conditional-branch preset design (see `demos/fuse/fuse_adventure/B2条件分支技术约束.md`)
> **Severity**: Medium (limits the expressive power of preset JSON, but does not break existing functionality)
> **Status**: Fixed

---

## 1. Summary

The Fuse preset deserialization pipeline **does not support recursive construction of nested sub-resources (BaseCondition / BaseInstruction / BaseEvent)**. Components with nested fields — container instructions (`IfElse`/`IfThen`/`ForLoop`/`ForEach`/`WhileLoop`/`RunConditionCheck`), composite conditions (`CheckAll`/`CheckAny`/`CheckNot`), and the conditional event (`OnInterval`), **10 sites** in total — cannot be restored inline from pure preset JSON; they depend on `.tscn` embedded resource pointers (`SubResource` / `ExtResource`), and an AI cannot invent such pointers out of thin air when generating JSON.

**Consequence**: AI-generated preset JSON (via `/fuse-instruction-generator`, `/fuse-preset-generator`) cannot contain working IfElse / loop bodies / composite conditions / conditional events. For now, conditional dispatch can only be worked around through L4 `EventBinding.conditions`, and even L4 supports only flat leaf conditions — composite conditions (`CheckAll` etc.) are unavailable at L4 too (see §4.2).

**Fix outcome**: a generic core-layer codec, `PresetValueCodec`, was introduced, recursively converting Dictionaries/Arrays into nested resources via property-list type awareness. All serialization/deserialization entry points now call this codec uniformly, fixing deserialization and serialization symmetry for all 10 nested sites.

---

## 2. Defect Symptoms

### 2.1 Reproduction path

Suppose we want to express a conditional IfElse in L2 preset JSON:

```json
{
  "type": "IfElse",
  "condition": {
    "type": "CheckScopeVariable",
    "scope_source": 1,
    "custom_scope_id": "level_scope",
    "variable_name": "current_level",
    "operator": 0,
    "compare_value": 1
  },
  "true_instructions": [
    { "type": "ChangeScene", "scene_path": "res://demos/.../level_02.tscn" }
  ],
  "false_instructions": []
}
```

### 2.2 Actual behavior

After import, `IfElse.condition` is assigned a **Dictionary** (not a `CheckScopeVariable` instance). At runtime, execution reaches [if_else.gd:153](../../../../instructions/flow_control/if_else.gd#L153):

```gdscript
var condition_result: bool = condition.check(context)   # ← Dictionary has no check() method → crash
```

The same applies to `true_instructions` / `false_instructions` — they become `Array[Dictionary]`, and child instructions crash on `execute()`.

---

## 3. Root Cause Analysis

### 3.1 Deserialization call chain (L2 path)

```
FusePreset.from_json()                              # fuse_preset.gd:114
  └─ _deserialize_instructions()                    # fuse_preset.gd:128, 154
       └─ for each entry:
            inst = script.new()
            for key in entry:
                _set_property_value(inst, key, entry[key])   # ← defect site
```

### 3.2 The defect site: flat assignment in `_set_property_value`

[fuse_preset_deserializer.gd:245-251](../../../../editor/serialization/fuse_preset_deserializer.gd#L245-L251):

```gdscript
static func _set_property_value(obj: Object, key: String, val) -> void:
    if val is String and (val.begins_with("uid://") or val.begins_with("res://")):
        var res = load(val)        # only recognizes resource reference strings
        if res != null:
            obj.set(key, res)
            return
    obj.set(key, val)              # everything else is a bare set — Dictionaries are stuffed in as-is
```

The function **does not check the expected type of the target property `obj.key`**. When `val` is a Dictionary, it should consult `obj`'s property list to decide whether it should be interpreted as a BaseCondition / BaseInstruction / BaseEvent instance and recursively deserialized; in reality it plainly does `obj.set(key, val)`.

### 3.3 `InstructionSerializer` shares the same flaw

`deserialize_instruction` in [instruction_serializer.gd:46-61](../../../../core/serialization/instruction_serializer.gd#L46-L61) likewise does a flat `instruction.set(property, data[property])`, with no recursion.

On the serialization side, [instruction_serializer.gd:34-36](../../../../core/serialization/instruction_serializer.gd#L34-L36) also only does `data[name] = instruction.get(name)` — if `condition` is a BaseCondition object, the value written into the dictionary cannot be handled correctly by `JSON.stringify` (the object reference is lost). This explains why `condition` in existing JSON (e.g. game_flow.json) always takes the `.tscn::Resource_xxx` pointer form.

### 3.4 The only "correct implementation": L4 EventBinding.conditions

[fuse_preset_deserializer.gd:168-174](../../../../editor/serialization/fuse_preset_deserializer.gd#L168-L174):

```gdscript
if data.has("conditions"):
    var conds: Array[BaseCondition] = []
    for cdata in data["conditions"]:
        var cond := _deserialize_condition(cdata)   # ← explicit recursion
        if cond:
            conds.append(cond)
    binding.conditions = conds
```

`_deserialize_binding` **explicitly** knows the semantics of the conditions field and calls `_deserialize_condition` to convert dictionaries into instances ([fuse_preset_deserializer.gd:140-151](../../../../editor/serialization/fuse_preset_deserializer.gd#L140-L151)). This is the **only** path in the entire pipeline that supports deserializing condition dictionaries.

> The generic `_set_property_value` lacks this path → the nested fields of container instructions all fail.

---

## 4. Impact Scope

> Verified and expanded on 2026-08-10: the defect is **systemic**, not limited to IfElse. A full grep over `instructions/`, `conditions/`, and `events/` for components declaring properties of type `Base(Condition|Instruction|Event)` confirms that all **10 sites** are currently affected.

### 4.1 Currently affected components (verified list)

| Category | Component | Nested fields | File |
|------|------|---------|------|
| Container instruction | `IfElse` | `condition` + `true_instructions` + `false_instructions` | `instructions/flow_control/if_else.gd:25,32,37` |
| Container instruction | `IfThen` | `condition` + `instructions` | `instructions/flow_control/if_then.gd:25,32` |
| Container instruction | `ForLoop` | `loop_instructions` | `instructions/flow_control/for_loop.gd:110` |
| Container instruction | `ForEach` | `loop_instructions` | `instructions/flow_control/for_each.gd:153` |
| Container instruction | `WhileLoop` | `loop_instructions` | `instructions/flow_control/while_loop.gd:79` |
| Container instruction | `RunConditionCheck` | `condition` | `instructions/flow_control/run_condition_check.gd:18` |
| Composite condition | `CheckAll` | `conditions: Array[BaseCondition]` | `conditions/composite/check_all.gd:12` |
| Composite condition | `CheckAny` | `conditions: Array[BaseCondition]` | `conditions/composite/check_any.gd:12` |
| Composite condition | `CheckNot` | `inner_condition` | `conditions/composite/check_not.gd:12` |
| Event | `OnInterval` | `stop_condition` | `events/lifecycle/on_interval.gd:66` |

**Note 1**: `WhileLoop` expresses its loop condition with a `condition_variable` + `condition_check` enum (not a BaseCondition; see `while_loop.gd:73,120`), but its `loop_instructions` is still `Array[BaseInstruction]` → the loop body cannot be constructed, so WhileLoop remains unusable.

**Note 2**: `OnInterval.stop_condition` is a condition embedded in an event — event deserialization goes through `_deserialize_event` → `_set_property_value`, so it is hit covertly.

### 4.2 Key finding: the L4 "workaround" is also incomplete

L4's `EventBinding.conditions` uses `_deserialize_condition` to construct each top-level condition, but internally `_deserialize_condition` still goes through `_set_property_value` to set fields. So if a composite condition built from **`CheckAll`/`CheckAny`/`CheckNot`** is used at L4 (e.g. `current_level==1 AND has_key`), the child condition array likewise cannot be constructed → crash.

**In practice L4 only supports a "flat list of leaf conditions", not nested composite conditions.** B2 assumed that upgrading to L4 would suffice — an overestimate.

### 4.3 Future extensions fall into the same trap

Any newly added container instruction / composite condition / conditional event — anything with properties of type BaseCondition / BaseInstruction / BaseEvent — falls into the same defect (e.g. a hypothetical `SwitchCase` or `TryCatch`). Fixing Option A in one place prevents them all.

### 4.3 Not affected

- Top-level `action_runner.instructions`: handled explicitly by `_deserialize_instructions` (no nesting at the top level)
- L4 `EventBinding.conditions`: explicit recursion
- `action_runner.instructions` of each L4 binding: same as above
- Ordinary flat instructions (GetNode / ChangeScene / ShowHideUI etc.): no nested fields, fine

---

## 5. Existing Workarounds and Their Limitations

### 5.1 Workaround: upgrade to L4 MultiEventTrigger

Use multiple EventBindings, each with its own `conditions`, to express conditional dispatch instead of IfElse:

```
binding 1: OnButtonPressed(NextLevel) + [CheckScopeVariable(current_level==1)] → ChangeScene(level_02)
binding 2: OnButtonPressed(NextLevel) + [CheckScopeVariable(current_level==2)] → ChangeScene(level_01)
```

✅ Expressible in pure JSON, usable right after import.

### 5.2 Limitations

1. **The `IfElse` instruction itself is unusable at any Level** — L4 merely works around it, not revive it at L4. If a user writes IfElse inside an L4 binding's instructions, it still crashes.
2. **Composite conditions crash at L4 too** — the child condition arrays of `CheckAll`/`CheckAny`/`CheckNot` also go through the flat `_set_property_value` (see §4.2). L4 in practice supports only flat leaf conditions and cannot do AND/OR/NOT combinations.
3. **All other container instructions are unusable** — `ForEach`/`ForLoop`/`WhileLoop`/`IfThen`/`RunConditionCheck` share the same disease; neither loop bodies nor child instructions can be constructed.
4. **Semantic mismatch**: expressing "the same event dispatched by state" via "multiple bindings + conditions" costs more to teach than a single IfElse. Expressive power is insufficient for complex branching (nested ifs, multi-level else).
5. **Gap in the teaching system**: the "conditional branch" that B2 wants to teach is forced to become "multiple event bindings + conditions" — a conceptual drift.

---

## 6. Fix Options

### Option A: add type-aware recursion to `_set_property_value` (recommended)

**Idea**: make the generic assignment function automatically restore Dictionaries/Arrays into the corresponding sub-resource instances recursively, based on the expected type of the target property. One fix cures all container instructions.

**Key implementation**: obtain the target property's `hint_string` via `obj.get_property_list()` (dynamically declared BaseCondition/BaseInstruction properties all carry `PROPERTY_HINT_RESOURCE_TYPE` plus `hint_string="BaseCondition"` etc.; see [if_else.gd:69-99](../../../../instructions/flow_control/if_else.gd#L69-L99)).

**Pseudocode** (replacing [fuse_preset_deserializer.gd:245-251](../../../../editor/serialization/fuse_preset_deserializer.gd#L245-L251)):

```gdscript
static func _set_property_value(obj: Object, key: String, val) -> void:
    # 1. Resource reference strings (keep original logic)
    if val is String and (val.begins_with("uid://") or val.begins_with("res://")):
        var res = load(val)
        if res != null:
            obj.set(key, res)
            return

    # 2. Nested sub-resources: recurse according to the target property's expected type
    var expected := _get_property_type_hint(obj, key)   # returns {"kind": "object"|"array", "class": "BaseCondition"|...}
    if expected.kind == "object" and val is Dictionary:
        match expected.class:
            "BaseCondition":      val = _deserialize_condition(val)
            "BaseInstruction":    val = _deserialize_instruction(val)
            "BaseEvent":          val = _deserialize_event(val)
            _:                    # other resource types: set as-is (for compatibility)
                pass
    elif expected.kind == "array" and val is Array and expected.class != "":
        val = _deserialize_typed_array(val, expected.class)

    obj.set(key, val)


static func _get_property_type_hint(obj: Object, key: String) -> Dictionary:
    for prop in obj.get_property_list():
        if prop.name == key:
            if prop.type == TYPE_OBJECT and prop.hint == PROPERTY_HINT_RESOURCE_TYPE:
                return {"kind": "object", "class": prop.hint_string}
            if prop.type == TYPE_ARRAY and prop.hint == PROPERTY_HINT_RESOURCE_TYPE:
                return {"kind": "array", "class": prop.hint_string}
            break
    return {"kind": "", "class": ""}


static func _deserialize_typed_array(raw: Array, element_class: String) -> Array:
    var result: Array = []
    for item in raw:
        if item is Dictionary:
            match element_class:
                "BaseInstruction": result.append(_deserialize_instruction(item))
                "BaseCondition":   result.append(_deserialize_condition(item))
                "BaseEvent":       result.append(_deserialize_event(item))
                _:                result.append(item)
        else:
            result.append(item)
    return result
```

**Pros**:
- One fix, and all container instructions (including future extensions) benefit automatically
- Does not break the existing flat-instruction path
- Semantics consistent with the explicit recursion of L4 EventBinding.conditions (just sunk into the generic layer)

**Risks**:
- Regression testing of existing preset imports is required (make sure flat fields are not misjudged)
- Mind the timing of `_get_property_list()` under `@tool` (see the editor thread-safety entry in CLAUDE.md)

**Implementation detail (Array element type detection must handle both hints)**:

The two property declaration styles carry different hints, and `_get_property_type_hint` must recognize both, otherwise you end up "fixing IfElse but missing CheckAll":

| Declaration style | Example | hint | hint_string |
|---------|------|------|-------------|
| dynamic `_get_property_list` | IfElse/ForEach instructions | `PROPERTY_HINT_RESOURCE_TYPE` | `"BaseInstruction"` |
| `@export var` | CheckAll/Any conditions | `PROPERTY_HINT_ARRAY_TYPE` | `"BaseCondition"` or `"Array[BaseCondition]"` |

`GET_PROPERTY_LIST` surfaces both; the branch logic just has to cover both hints plus both formats of hint_string (bare class name / `Array[...]` wrapper).

### Option B: matching fix in `InstructionSerializer`

Option A only fixes deserialization. The serialization side of `InstructionSerializer` (`serialize_instruction`) needs a symmetric fix too — when it encounters BaseCondition/BaseInstruction property values it must serialize them recursively into nested dictionaries, otherwise exported JSON still cannot be inlined.

**Pseudocode** (reworking [instruction_serializer.gd:34-36](../../../../core/serialization/instruction_serializer.gd#L34-L36)):

```gdscript
for property_name in properties:
    var value = instruction.get(property_name)
    data[property_name] = _serialize_value(value)


static func _serialize_value(value: Variant) -> Variant:
    if value is BaseCondition:
        return _serialize_condition(value)        # reuse the inverse of deserialize_condition
    if value is BaseInstruction:
        return serialize_instruction(value)       # already exists, recurse
    if value is BaseEvent:
        return _serialize_event(value)
    if value is Array:
        var arr: Array = []
        for item in value:
            arr.append(_serialize_value(item))
        return arr
    return value
```

> We also recommend merging the **duplicated** `_deserialize_instructions` copies in `fuse_preset.gd` and `fuse_preset_deserializer.gd`, to avoid fixing one and missing the other (see §8 on code quality).

### Option C: no code change, add documentation constraints

Hard-code the constraint in the `/fuse-preset-generator` skill and the B2 document:

> The nested fields of container instructions (`IfElse` etc.) **must not** be inlined in preset JSON. Conditional dispatch must always go through L4 `EventBinding.conditions`.

**Pros**: zero code changes, zero regression risk.
**Cons**: the defect persists forever; all future container instructions suffer; the teaching system is forced to bypass IfElse.

---

## 7. Recommended Implementation Steps (Options A + B)

1. **Extract a shared utility** `preset_value_codec.gd` (or add static methods to the existing utils): `_get_property_type_hint` / `_deserialize_typed_array` / `_serialize_value`, shared by the deserializer and the serializer.
2. **Rework `_set_property_value`** (Option A), keeping the original uid/res branch.
3. **Rework `InstructionSerializer.serialize_instruction`** (Option B) to keep both sides symmetric.
4. **Merge the duplicated `_deserialize_instructions`** (fuse_preset.gd ↔ deserializer).
5. **Update the `/fuse-preset-generator` skill**: remove the "IfElse not allowed" constraint and add nested JSON examples.
6. **Regression + new tests** (see §8).

Estimated effort: 0.5–1 day (including tests).

---

## 8. Test Verification

### 8.1 New tests (verifying the fix)

Construct the preset JSON `test_ifelse_inline.json`:

```json
{
  "format_version": "2.0",
  "level": "L2",
  "display_name": "test_ifelse_inline",
  "event": { "type": "OnArea2DEnter", "area_node_path": "Area2D", "target_group": "player" },
  "action_runner": {
    "execution_mode": 0,
    "instructions": [
      {
        "type": "IfElse",
        "sequence_mode": 0,
        "condition": {
          "type": "CheckScopeVariable",
          "scope_source": 1,
          "custom_scope_id": "level_scope",
          "variable_name": "current_level",
          "operator": 0,
          "compare_value": 1
        },
        "true_instructions": [
          { "type": "Print", "message": "branch-true" }
        ],
        "false_instructions": [
          { "type": "Print", "message": "branch-false" }
        ]
      }
    ]
  },
  "variables": { "global": [], "local": [], "scope": [] },
  "trigger_config": { "trigger_once": true, "cooldown_mode": 0, "cooldown_time": 1.0 }
}
```

Assertions:
- After import, `IfElse.condition is BaseCondition` (`is CheckScopeVariable`) ✓
- `IfElse.true_instructions[0] is BaseInstruction` (`is Print`) ✓
- After triggering, the log prints the correct `branch-true` / `branch-false` (depending on the current_level value)
- **Serialize then deserialize** (round-trip) yields an equivalent result

### 8.2 Regression tests

- Existing L4 presets (with `binding.conditions`) keep their import behavior
- Existing flat-instruction presets keep their import behavior
- Flat instructions without nested fields (`ChangeScene` / `GetNode` / `ShowHideUI` etc.) work normally

---

## 9. Related Files

| File | Role | Change |
|------|------|------|
| `addons/fuse/core/serialization/preset_value_codec.gd` | Generic codec | New file, owns all nested-resource serde |
| `addons/fuse/editor/serialization/fuse_preset_deserializer.gd` | Deserialization pipeline | Calls the codec; `_set_property_value` goes through `deserialize_value` |
| `addons/fuse/core/serialization/instruction_serializer.gd` | Serializer | Calls the codec, supports recursive serialization |
| `addons/fuse/core/resources/fuse_preset.gd` | Preset resource + from_json | Calls the codec, merges duplicated deserialization logic |
| `addons/fuse/editor/serialization/fuse_preset_serializer.gd` | Serializer | Calls the codec |
| `addons/fuse/instructions/flow_control/if_else.gd` | Container instruction sample | No change needed (beneficiary only) |
| `addons/fuse/core/event_binding.gd` | L4 binding (existing correct implementation) | No change needed (reference example) |
| `~/.claude/skills/fuse-preset-generator/SKILL.md` | preset generation skill | Constraint update |

---

## 10. Appendix: Why L4 Can Work Around It and IfElse Cannot

| Dimension | L4 `EventBinding.conditions` | L2 `IfElse.condition` |
|------|------------------------------|----------------------|
| Deserialization entry | `_deserialize_binding` explicitly iterates the conditions array | Generic `_set_property_value` flat assignment |
| Recursive? | ✅ calls `_deserialize_condition` | ❌ sets the Dictionary directly |
| Expressible in JSON | ✅ inline dictionary | ❌ must be a resource reference |

The essential difference: **L4 applies field-level specialization to conditions, while IfElse goes through the generic pipeline — and the generic pipeline does not understand nesting**. Option A sinks this specialization into the generic layer so that all fields share the same capability.

---

## 11. Fix Status

- **Status**: Fixed
- **Fix commits**: see the introduction of `PresetValueCodec` and the related serializer rework
- **Verification**: `tests/serialization/test_preset_nested_serde.gd` covers round-trips of IfElse, CheckAll, and OnInterval; the existing IfElse / composite condition / OnInterval tests pass.

After the fix:
- L2 preset JSON can inline `IfElse`, `IfThen`, `ForLoop`, `ForEach`, `WhileLoop`, and `RunConditionCheck`.
- The composite conditions `CheckAll` / `CheckAny` / `CheckNot` can inline child conditions.
- `OnInterval.stop_condition` can inline a condition.
- L4 `EventBinding.conditions` also supports composite conditions automatically.

---

## 12. Additional Technical Details Discovered During Implementation

While actually implementing `PresetValueCodec`, several Godot runtime "traps" were encountered; they are handled in the code:

### 12.1 GDScript `class_name` is not necessarily registered in ClassDB under headless / at runtime

`ClassDB.class_exists("CheckScopeVariable")` may be `true` in the editor but `false` under `--headless` or in runtime exports. Therefore `_deserialize_resource` takes a dual path:

1. First try `ClassDB.class_exists` / `ClassDB.instantiate` (native or already-registered classes).
2. On failure, scan the `.gd` files under `addons/fuse/{instructions,events,conditions,integration}/` by `type_name`, match via `script.get_global_name()`, and instantiate.

### 12.2 The hint of `@export var conditions: Array[BaseCondition]` is not `PROPERTY_HINT_ARRAY_TYPE`

Godot reports typed-array properties as `PROPERTY_HINT_TYPE_STRING`, with `hint_string` shaped like `"24/17:BaseCondition"`. Therefore `_property_to_hint` must additionally parse this format:

```gdscript
elif hint == PROPERTY_HINT_TYPE_STRING:
    element_class = _parse_type_string_hint(hint_string)
```

### 12.3 `TYPE_OBJECT` properties without a hint can still be identified via the `class_name` field

Some dynamic properties (e.g. `IfElse.condition`) report `hint == PROPERTY_HINT_NONE` in `get_property_list()`, yet the `class_name` field still carries `"BaseCondition"`. `_property_to_hint` falls back to `class_name_str`:

```gdscript
var target_class := hint_string if hint == PROPERTY_HINT_RESOURCE_TYPE and hint_string != "" else class_name_str
```

### 12.4 Typed-array `set()` fails silently

Godot refuses to assign an untyped `Array` to an `Array[BaseCondition]` property. `_set_property_safely` checks the array length after the first `set`; if it did not take effect, it refills using a typed copy of the property's own array:

```gdscript
var typed: Array = current.duplicate()
typed.clear()
typed.append_array(value)
obj.set(key, typed)
```

### 12.5 `_find_property` may return entries without type information

The same property name may appear multiple times in `get_property_list()` (e.g. script property + built-in property). The implementation prefers entries that carry `hint` or `class_name`, to avoid misjudging an array as untyped.

---

## Decision Recommendation

| Option | Trade-off |
|------|------|
| **A + B (recommended)** | Cures the defect; IfElse fully functional; zero cost for future container instructions. About 0.5–1 day. |
| A only | Fixes deserialization, but exported JSON remains asymmetric (hand-written JSON works, editor export loses data). Incomplete. |
| C (no fix) | Zero risk, but the defect becomes permanent; teaching/extensibility restricted. |

We recommend **A + B**, and after the fix, downgrading B2's "upgrade to L4" decision from "mandatory" to "an optional teaching path".
