> 🌐 [**中文版**](../../../zh_CN/system_docs/analysis/base_condition_analysis.md) | English

# BaseCondition Analysis Report


> **Analysis as of**: 2026-07-07 (code verified article-by-article during the same-day full documentation audit; implementation evolution since then defers to the source code; for recently verified mechanical conclusions see the threading / runtime_instance / preset_nested articles)
## Document Overview

This report describes the current state of the `BaseCondition` core script in the Fuse visual programming system. `BaseCondition` is the abstract base class of the condition system (`@abstract class_name BaseCondition extends Resource`), defining the condition-check lifecycle interface, the cache system, the dependency graph, thread safety, the batch-operation family, and the serialization/cloning framework, providing a unified condition abstraction for upper-layer modules such as Trigger / ActionRunner / ParallelConditionEvaluator.

**Source file:** [base_condition.gd](../../../../core/base/base_condition.gd)
**Line count:** 942 lines
**Base class:** Resource (`@tool` + `@abstract`, serializable as .tres)
**Companion parallel evaluator:** [parallel_condition_evaluator.gd](../../../../core/threading/parallel_condition_evaluator.gd) (251 lines)
**Subclass scale:** 66 `extends BaseCondition` implementations, distributed across the physics / node / input / animation / composite / variable / time / string / dictionaries / arrays / scope / distance / navigation / system / rendering / scene / ui / math and other directories

> ⚠️ **Clarification**: `BaseCondition` **declares no signal at all** (grep `^signal\s` has no match in the source file). Condition check results are conveyed through the `check()` return value; `on_condition_met(context)` and `on_condition_failed(context)` are plain instance methods (lines 497–512) invoked proactively by the caller as hooks for subclasses to respond to results. Earlier documents calling these "condition met/failed signals" were misstatements.

---

## 1. Class Overview and Responsibilities

`BaseCondition` is the base class of all concrete conditions (such as `CheckAll` / `CheckAny` / `CheckVariable` / `CheckOnFloor`, etc.). It exists as a `Resource`: it can be serialized, held by Triggers, nested by composite conditions, and pooled onto worker threads for evaluation by the ParallelConditionEvaluator.

### Core Responsibilities

1. **Condition evaluation entry point**: `check(context)` is the unified entry, handling disable/cache/counting/negation and ultimately calling the subclass `_evaluate_condition()`
2. **Cache system**: result cache based on timestamp + context hash, invalidatable by the dependent variable set
3. **Dependency graph**: `get_dependencies()` declares variable dependencies; `get_dependency_graph()` outputs a visualizable structure
4. **Thread safety flag**: the `is_thread_safe` property + the `_compute_thread_safety()` subclass hook, used by the parallel evaluator for filtering
5. **Batch operations**: 6 `*_batch` methods covering check / optimized check / validation / status info / dependency check / dependency status
6. **Serialization and cloning**: `serialize()` / `deserialize()` / `clone()`
7. **Metadata interface**: the static `_get_condition_metadata()` provides ConditionMetadata (name/category/description/keywords/icon)
8. **Unified errors and logging**: the `FuseError` instance field + the graded `_log_*` method family delegated to `FuseLogger`

### Design Characteristics

- `@abstract` marks three methods that must be subclassed: `_evaluate_condition()`, `_compute_dependencies()`, `_update_resource_name()`
- `@tool` supports in-editor execution (for property panel preview and resource name sync)
- Built-in state fields (`check_count` / `last_check_time` / `last_result`) are stored directly on the Resource instance; state separation for high-frequency shared/pooled scenarios is handled by the upper-layer Runtime instance system (isomorphic to BaseEvent)
- `_set()` intercepts `resource_name`, automatically calling `_update_resource_name()` for re-translation when the editor language changes

---

## 2. Core Properties

### 2.1 Condition Configuration (@export_group)

| Property | Type | Default | Description |
|------|------|--------|------|
| `enabled` | bool | true | Whether the condition is enabled; the setter triggers a debug log |
| `log_level` | FuseLogger.LogLevel | INFO | Log output level |
| `negate_result` | bool | false | Negates the evaluation result (applied at the end of `check()`) |

### 2.2 Cache Configuration (@export_group)

| Property | Type | Default | Description |
|------|------|--------|------|
| `enable_cache` | bool | false | Whether result caching is enabled |
| `cache_duration` | float | 1.0 | Cache validity period (seconds); the setter enforces a minimum of 0.1 |
| `cache_context_changes` | bool | true | Whether to invalidate the cache on context change (participates in hashing) |
| `hash_all_variables` | bool | false | Whether hashing includes all local variables (by default only dependency variables) |

### 2.3 Cache State Fields

| Field | Type | Description |
|------|------|------|
| `_cached_result` | bool | The last cached result |
| `_cache_timestamp` | float | Time of the last cache write (`Time.get_ticks_msec()/1000.0`) |
| `_cache_context_hash` | int | Context hash at the time of the last cache write |
| `_cached_dependencies` | Array[String] | Internal cache of `get_dependencies()`, avoiding recomputation |

### 2.4 Runtime State Fields

| Field | Type | Description |
|------|------|------|
| `last_check_time` | float | Timestamp of the most recent `check()` |
| `check_count` | int | Cumulative `check()` count |
| `last_result` | bool | Result of the most recent `check()` |
| `_fuse_error` | FuseError | Unified error instance (`null` means no error) |
| `_description` | String | Description cache (not populated by the base class) |
| `_last_locale` | String | Locale code at the time of the last resource_name update |

### 2.5 Thread Safety Cache Fields

| Field | Type | Description |
|------|------|------|
| `_thread_safety_cached` | bool | Cached thread-safety evaluation result |
| `_thread_safety_computed` | bool | Whether thread-safety evaluation has been completed |

### 2.6 Static Fields and Constants

| Name | Type | Description |
|------|------|------|
| `_fuse_localization_class` | RefCounted | Cached FuseLocalization class reference, avoiding repeated `load()` |
| `DEFAULT_CHECK_INTERVAL` | float = 0.1 | Default re-check interval constant (not used directly by the base class; a reference for subclasses/callers) |

### 2.7 Preloaded Constants

`FuseLocalization`, `VariableOperations`, `VariableScopeUtils`, `FuseNodeUtils`.

### 2.8 Derived Properties

| Property | Type | Description |
|------|------|------|
| `is_thread_safe` | bool (getter only) | Computed via `_compute_thread_safety()`, result cached in `_thread_safety_cached` |

---

## 3. Key Methods

### 3.1 Condition Evaluation Main Entry

#### `check(context: ExecutionContext) -> bool` — Evaluation entry (lines 168–202)

The central method that uniformly handles disabling, cache hits, counting, negation, and cache writing.

```
Execution flow:
  1. context == null → log error + create FuseError + return false
  2. enabled == false → debug log + return false
  3. enable_cache and _is_cache_valid(context) → cache hit, return _cached_result
  4. check_count += 1; record last_check_time
  5. result = _evaluate_condition(context)         # subclass must implement (@abstract)
  6. negate_result is true → result = not result
  7. last_result = result
  8. enable_cache is true → _update_cache(result, context)
  9. return result
```

#### `_evaluate_condition(context: ExecutionContext) -> bool` — Abstract evaluation (lines 207–208)

An `@abstract` method with no default implementation. Subclasses write the actual judgment logic here. Example: `CheckAll` iterates child conditions here with short-circuit evaluation; `CheckVariable` reads and compares the variable here.

### 3.2 Abstract Method List

| Method | Lines | Description |
|------|------|------|
| `_evaluate_condition(context) -> bool` | 207–208 | Main body of condition evaluation |
| `_compute_dependencies() -> Array[String]` | 365–366 | Declares the list of variable names this condition depends on |
| `_update_resource_name()` | 76–77 | Generates a localized resource_name based on the property and the current language |

### 3.3 Validation and Description Methods

| Method | Returns | Description |
|------|------|------|
| `validate() -> Array[String]` | Error list | The base class checks `enabled`; when disabled it appends an error and creates a FuseError |
| `is_valid(context) -> bool` | bool | Calls `validate()` and logs each error; with a null context it still performs the basic validation and creates a FuseError |
| `get_description() -> String` | String | The base class returns "Base Condition"; subclasses generally return localized text |
| `get_detailed_info() -> Dictionary` | Dictionary | Contains type/description/enabled/negate_result/check_count/last_check_time/last_result, plus `_fuse_error` details |
| `get_status_info() -> Dictionary` | Dictionary | enabled/check_count/last_check_time/last_result/needs_recheck/is_valid |
| `get_condition_type() -> String` | String | The base class returns "base" |
| `get_condition_category() -> String` | String | The base class returns "general" |
| `get_priority() -> int` | int | The base class returns 0; lower values mean higher priority |
| `get_parameters() / set_parameters(p)` | Dictionary / void | Parameter read/write; set internally tries a `set_<key>` method or assigns directly |
| `needs_recheck(context) -> bool` | bool | The base class returns true by default (re-check every time); returns true with a warning when context is null |
| `get_history() / clear_history()` | Array[Dictionary] / void | History hooks; empty implementations in the base class, optional for subclasses |
| `get_performance_metrics() -> Dictionary` | Dictionary | Contains check_count/last_check_time/average_check_time (0.0 in the base class) |
| `get_debug_info() -> String` | String | Single-line debug string |

### 3.4 Icon Retrieval (Four-Level Fallback)

#### `get_condition_icon() -> Texture2D` (lines 277–305)

```
Fallback order (consistent with BaseInstruction.get_icon()):
  1. metadata.builtin_icon  → FuseIconManager.get_builtin_icon()
  2. metadata.custom_icon   → FuseIconManager.get_custom_icon()
  3. metadata.icon_name     → FuseIconManager (custom first, then builtin)
  4. metadata.icon          → return the Texture2D directly
  5. fall back to res://addons/fuse/icons/condition.svg; warning + null if missing
```

`get_icon()` is a compatibility alias of `get_condition_icon()` (lines 309–310).

### 3.5 Cache System Methods

#### `_is_cache_valid(context) -> bool` (lines 615–633)

```
Validity determination:
  1. _cache_timestamp == 0.0 → false (never cached)
  2. (now - _cache_timestamp) > cache_duration → false (expired)
  3. _generate_context_hash(context) != _cache_context_hash → false (context changed)
  4. otherwise → true
```

#### `_update_cache(result, context)` (lines 638–642)

Writes `_cached_result` / `_cache_timestamp` / `_cache_context_hash`.

#### `_generate_context_hash(context) -> int` (lines 647–665)

```
Hash composition:
  - Base: context.execution_id.hash()
  - when cache_context_changes is true:
      * iterate over each variable value of get_dependencies() → hash_value ^= (hash<<5) + str(value).hash()
      * when hash_all_variables is true, additionally include all variables of context.local_variables
  - context == null → return 0
```

#### Cache Clearing Methods

| Method | Description |
|------|------|
| `clear_result_cache()` | Clears the result-cache trio |
| `clear_context_cache(context)` | Clears only when the passed-in context hash matches |
| `clear_cache()` | Clears all caches (equivalent to clear_result_cache, under a more generic name) |
| `clear_dependencies_cache()` | Clears `_cached_dependencies`; the next `get_dependencies()` recomputes |
| `get_cache_info() -> Dictionary` | Returns enabled/duration/cached_result/cache_timestamp/cache_age/context_hash/is_valid |

### 3.6 Dependency Graph Methods

#### `get_dependencies() -> Array[String]` (lines 357–361)

Cached: when empty on first call, `_compute_dependencies()` fills `_cached_dependencies`; subsequent calls return the cache directly.

#### Dependency Relationship Family

| Method | Lines | Description |
|------|------|------|
| `add_dependencies(depends_on)` | 716–718 | Hook method; the base class only logs; subclasses may override it to maintain structured dependencies |
| `remove_dependencies(depends_on)` | 722–724 | Same as above, for removal |
| `get_dependency_graph() -> Dictionary` | 728–776 | Outputs a `{nodes, edges, condition_info}` graph structure; dependency-type edges point from variable to condition, affected-type edges point from condition to variable |
| `check_dependencies(context) -> bool` | 781–793 | Checks whether each variable in `get_dependencies()` exists in the context |
| `get_dependency_status(context) -> Dictionary` | 798–822 | Returns `{total_dependencies, satisfied_dependencies, missing_dependencies, dependency_details}` |
| `get_dependency_visualization_data() -> Dictionary` | 852–873 | Aggregates condition meta info + dependencies + affected_variables + dependency_graph, with fuse_error attached (if any) |
| `get_affected_variables() -> Array[String]` | 391–393 | The base class returns an empty array; subclasses may override it to declare affected variables |

### 3.7 Thread Safety Methods

#### `is_thread_safe` (getter, lines 60–62)

Returns `_compute_thread_safety()`, with the result cached.

#### `_compute_thread_safety() -> bool` (lines 374–381)

Base class default: on first access sets `_thread_safety_cached = false` and `_thread_safety_computed = true`, and returns false. Subclasses override it to reflect whether their own implementation can run on a worker thread (typical criteria: no node property access, pure math/variable comparison only, snapshot data used).

#### `reset_thread_safety_cache()` (lines 385–387)

Clears `_thread_safety_computed` and `_thread_safety_cached`; call it when configuration changes to trigger recomputation.

> **Design contract**: `_compute_thread_safety()` should be self-contained and free of side effects. Composite conditions (such as `CheckAll`) determine their own safety by recursively querying child conditions' `is_thread_safe` — see §6 on subclass patterns.

### 3.8 Result Callback Methods (Not Signals)

#### `on_condition_met(context)` (lines 497–503)

A plain instance method. Base class implementation: warns when context is null; otherwise logs the description at debug level. Subclasses may override it to react to the "met" event.

#### `on_condition_failed(context)` (lines 505–512)

Same as above, corresponding to the "not met" event.

> ⚠️ **Clarified again**: these two methods are plain methods — the caller must proactively call `condition.on_condition_met(ctx)` to trigger them; there is no signal, so `.connect()` cannot be used. Earlier documents describing them as "condition met/failed signals" were wrong.

### 3.9 Batch Operation Family (6 `*_batch` Methods)

| Method | Lines | Input | Returns | Description |
|------|------|------|------|------|
| `check_batch(contexts)` | 551–564 | Array[ExecutionContext] | Array[bool] | Calls `check()` sequentially, tallying total/average elapsed time |
| `optimized_check_batch(contexts)` | 569–582 | same as above | Array[bool] | Calls `optimized_check()` (the base class defaults to `check()`; subclasses may override it with an optimized path) |
| `validate_batch(contexts)` | 587–595 | same as above | Array[bool] | `is_valid()` one by one |
| `get_status_info_batch(contexts)` | 600–608 | same as above | Array[Dictionary] | `get_status_info()` one by one (note: the current implementation ignores the context input) |
| `check_dependencies_batch(contexts)` | 827–835 | same as above | Array[bool] | `check_dependencies()` one by one |
| `get_dependency_status_batch(contexts)` | 840–848 | same as above | Array[Dictionary] | `get_dependency_status()` one by one |

> **Design status**: the batch methods loop serially on this Resource instance and **do not directly invoke the parallel evaluator**. Parallel dispatch is performed by `ParallelConditionEvaluator` across multiple *condition objects*, which is a different dimension from the *multiple contexts* batch processing here.

### 3.10 Optimized Check

#### `optimized_check(context) -> bool` (lines 526–534)

Base class default: null context → error log + return false; otherwise the standard `check()` runs. Subclasses may override it to provide an optimized path (e.g. precomputation, short-circuiting).

### 3.11 Serialization and Cloning

#### `serialize() -> Dictionary` (lines 436–442)

```gdscript
{
    "type": get_condition_type(),
    "enabled": enabled,
    "negate_result": negate_result,
    "parameters": get_parameters()
}
```

#### `deserialize(data)` (lines 446–454)

Restores `enabled` / `negate_result` / `parameters` (via `set_parameters()`) by key.

#### `clone() -> BaseCondition` (lines 458–468)

After `duplicate()` copies, calls `reset()` on the clone to clear runtime state; warns if the clone has no `reset` method.

### 3.12 Lifecycle and State Reset

#### `reset()` (lines 396–404)

Zeroes `check_count` / `last_check_time` / `last_result`; nulls `_fuse_error`; calls `clear_cache()` / `clear_dependencies_cache()` / `reset_thread_safety_cache()` in turn.

#### `set_enabled(value)` (lines 412–414)

Sets enabled and logs (an imperative entry equivalent to the @export setter).

### 3.13 Metadata Interface

#### `static _get_condition_metadata() -> ConditionMetadata` (lines 941–942)

The base class returns `null`. Subclasses implement it to provide ConditionMetadata (name_key / category_key / description_key / keywords / builtin_icon / custom_icon / icon_name / icon), used by the condition picker and `get_condition_icon()`.

### 3.14 FuseError Integration

| Method | Lines | Description |
|------|------|------|
| `_create_fuse_error(message, error_type, context)` | 879–884 | Creates a FuseError and stores it in `_fuse_error`; automatically attaches condition_type / condition_description context |
| `_create_fuse_error_localized(message_key, error_type, args, context)` | 893–925 | Translates message_key via FuseLocalization (translate_format when args are present, otherwise translate); falls back to manual `{key}` replacement when the translation system is unavailable; attaches message_key/message_args context |
| `get_fuse_error() -> FuseError` | 929–930 | Returns `_fuse_error` (null when there is no error) |
| `has_fuse_error() -> bool` | 934–935 | Whether an error exists |

### 3.15 Logging Methods (Delegating to FuseLogger)

| Method | Delegates to |
|------|------|
| `_log_debug(msg)` | `FuseLogger.log_debug("BaseCondition", log_level, msg)` |
| `_log_info(msg)` | `FuseLogger.log_info("BaseCondition", log_level, msg)` |
| `_log_warning(msg)` | `FuseLogger.log_warning("BaseCondition", log_level, msg)` |
| `_log_error(msg)` | `FuseLogger.log_error("BaseCondition", log_level, msg)` |

### 3.16 Resource Name Localization Interception

#### `_set(property, value) -> bool` (lines 145–163)

Intercepts `resource_name` assignment: initializes FuseLocalization; if the current language differs from `_last_locale` (or on first assignment), updates `_last_locale` and calls `_update_resource_name()` to re-translate; returns false so Godot uses the updated value. Other properties return false directly for default handling.

### 3.17 Node Path Display Name Resolution

#### `_get_node_display_name(path: NodePath) -> String` (lines 95–110)

Used by `_update_resource_name()` and `get_description()` to display the target node.

```
Resolution strategy:
  1. empty path → ""
  2. explicit node name at the tail (not pure .. or .) → extract get_file() directly
  3. editor mode → FuseNodeUtils.resolve_node_name_for_display()
  4. resolution failure → _get_parent_level_display() smart fallback
  5. non-editor → return the original path string
```

#### `static _get_parent_level_display(path_str) -> String` (lines 113–127)

Converts pure `..` paths into readable level descriptions: 1 level → "[上级]", n levels → "[n层上级]". Refresh after restart is handled by the EditorPlugin.scene_changed signal (see the method comments).

---

## 4. Cache System Architecture

### 4.1 Cache Write and Read

```
check(context)
  │
  ├── enable_cache && _is_cache_valid(context)
  │       └── hit → return _cached_result
  │
  ├── result = _evaluate_condition(context)
  │
  └── enable_cache
          └── _update_cache(result, context)
                  ├── _cached_result = result
                  ├── _cache_timestamp = now
                  └── _cache_context_hash = _generate_context_hash(context)
```

### 4.2 Context Hash Composition

```
_generate_context_hash(context):
  base = context.execution_id.hash()
  if cache_context_changes:
      for dep in get_dependencies():       # dependent variables only
          base ^= (base << 5) + str(value).hash()
      if hash_all_variables:               # optional: all local variables
          for k,v in context.local_variables:
              base ^= (base << 3) + str(v).hash()
  return base
```

### 4.3 Invalidation Policy

| Trigger | Behavior |
|------|------|
| `cache_duration` expiry | `_is_cache_valid()` returns false; the next `check()` recomputes |
| Context hash change (dependent variable values changed) | Same as above |
| Manual `clear_cache()` / `clear_result_cache()` / `clear_context_cache(ctx)` | Immediate invalidation |
| `reset()` | Clears the cache, dependency cache, and thread-safety cache together |
| Child condition config change (typical scenario) | The composite condition calls `clear_dependencies_cache()` in its setter to trigger recomputation (see CheckAll) |

---

## 5. Dependency Graph and Visualization

### 5.1 Dependency Declaration Chain

```
BaseCondition.get_dependencies()              # cached
        │
        └── _compute_dependencies()           # @abstract, implemented by subclasses
                │
                └── Typical: scan the condition's own fields such as variable_name
                          Composite conditions: aggregate get_dependencies() of all child conditions
```

### 5.2 get_dependency_graph() Output Structure

```gdscript
{
    "nodes": [
        {"id": "condition_<instance_id>", "label": <description>, "type": "condition"},
        {"id": "<var_name>", "label": "<var_name>", "type": "dependency"},   # one per dep
        {"id": "<var_name>", "label": "<var_name>", "type": "affected"}      # one per affected
    ],
    "edges": [
        {"from": "<dep_var>", "to": "condition_<id>", "type": "dependency"},
        {"from": "condition_<id>", "to": "<affected_var>", "type": "affects"}
    ],
    "condition_info": {
        "type": <condition_type>,
        "description": <description>,
        "enabled": <bool>,
        "priority": <int>
    }
}
```

### 5.3 Visualization Data Aggregation

`get_dependency_visualization_data()` additionally wraps condition meta info and `fuse_error` (if any) on top of the graph above; it is the upper-level entry point for editor/debug tooling.

---

## 6. Thread Safety and ParallelConditionEvaluator

### 6.1 Thread Safety Flag Chain

```
BaseCondition.is_thread_safe  (getter)
        │
        └── _compute_thread_safety()         # cached (_thread_safety_computed)
                │
                └── base class default: false
                    subclass override: returns true/false depending on whether the implementation accesses node properties / is pure computation
                    composite conditions (CheckAll): true only when all child conditions' is_thread_safe is true

reset_thread_safety_cache()  # clears the cache on config change to trigger recomputation
```

### 6.2 ParallelConditionEvaluator Cooperation

`ParallelConditionEvaluator` (`core/threading/parallel_condition_evaluator.gd`) uses `WorkerThreadPool` to evaluate multiple condition objects in parallel, filtering the parallelizable set by `condition.is_thread_safe`.

```
evaluate_parallel(context, conditions)
  │
  ├── SEQUENTIAL     → _evaluate_sequential()      # serial fallback
  ├── PARALLEL_SAFE  → _evaluate_parallel_safe()   # parallelizes only conditions with is_thread_safe=true
  └── PARALLEL_ALL   → _evaluate_parallel_all()    # force-parallelizes everything (dangerous, testing only)
```

**Internal flow of PARALLEL_SAFE**:

1. Classification: `is_thread_safe=true` → safe_indices; the rest → unsafe_indices
2. Calls `_create_context_snapshot(context)`: copies local_variables + a global variable snapshot + trigger/target/execution_id
3. safe_indices go through `_evaluate_safe_conditions_parallel()`: each task is a `WorkerThreadPool.add_task`, internally calling `condition.check(temp_context)` with a temporary context; the result array and counter are protected by a Mutex, synchronized by a Semaphore
4. unsafe_indices run `condition.check(context)` serially
5. Timeout protection: total timeout = max(target_count × timeout_per_condition, 5.0); on timeout it exits with a warning

**Statistics**: `total_conditions_evaluated` is protected by `_stats_mutex` (locked in both serial and parallel modes; a comment marks this as a race-condition fix).

### 6.3 Relationship with FuseThreadSafe

`FuseThreadSafe` (`core/threading/fuse_thread_safe.gd`) is a pure utility class providing `dict_get_safe` / `dict_set_safe` / `array_append_safe` and other dictionary/array operation wrappers with optional Mutex parameters. `BaseCondition` **neither inherits nor directly uses** `FuseThreadSafe` — the latter serves scenarios that need thread-safe container operations on demand. `ParallelConditionEvaluator` internally uses Godot's native `Mutex` / `Semaphore` directly.

---

## 7. Serialization and Cloning

### 7.1 serialize() Data Shape

Contains only `type` / `enabled` / `negate_result` / `parameters`. `parameters` comes from `get_parameters()`; subclasses generally return a dictionary form of their own @export fields.

### 7.2 deserialize() Restoration Flow

Restores by key existence: `enabled` → `negate_result` → `set_parameters(parameters)`. Internally `set_parameters()` first tries a `set_<key>` method for each key, otherwise `set(key, value)` directly; it warns when the property does not exist.

### 7.3 clone() Behavior

`duplicate()` → calls the clone's `reset()` (warns if there is no reset method) → returns. Runtime state (counters/caches/errors) is zeroed; @export configuration is preserved.

---

## 8. Subclass Implementation Patterns

Based on a sample of the 66 subclasses (focusing on `CheckAll` and `CheckVariable`), subclasses generally follow these patterns:

### 8.1 Required Methods

| Method | Description |
|------|------|
| `_evaluate_condition(context) -> bool` | The actual judgment logic |
| `_compute_dependencies() -> Array[String]` | Declares dependent variables (composite conditions aggregate child-condition dependencies) |
| `_update_resource_name()` | Generates the localized resource name |
| `static _get_condition_metadata() -> ConditionMetadata` | Provides picker/icon metadata |

### 8.2 Common Overrides

| Method | Override scenario |
|------|----------|
| `get_condition_type() / get_condition_category() / get_description()` | Return type/category/description (usually localized) |
| `validate()` | Append subclass-specific validation after calling `super.validate()` |
| `get_parameters() / set_parameters()` | Serialized field read/write |
| `reset()` | Clean up child structures after calling `super.reset()` (e.g. composite conditions reset all child conditions) |
| `_compute_thread_safety()` | Declare parallelizability (composite conditions recursively query child conditions) |
| `on_condition_met/failed()` | Result hooks (the base class only logs) |
| `optimized_check()` | Optimized path (the base class defaults to `check()`) |

### 8.3 Typical Subclass Structure (CheckAll Example)

```gdscript
@tool
extends BaseCondition
class_name CheckAll

@export var conditions: Array[BaseCondition] = []:
    set(value):
        conditions = value
        clear_dependencies_cache()      # clear the dependency cache on config change
        _update_resource_name()

@export var short_circuit: bool = true

func _evaluate_condition(context: ExecutionContext) -> bool:
    if conditions.is_empty():
        return false
    for i in conditions.size():
        var condition = conditions[i]
        if condition == null:
            _create_fuse_error(..., FuseError.ErrorType.VALIDATION_ERROR)
            return false
        if not condition.check(context):
            return false                # short-circuit
    return true

func _compute_dependencies() -> Array[String]:
    var all_deps: Array[String] = []
    for condition in conditions:
        if condition != null:
            for dep in condition.get_dependencies():
                if not dep in all_deps:
                    all_deps.append(dep)
    return all_deps

func _compute_thread_safety() -> bool:
    if _thread_safety_computed:
        return _thread_safety_cached
    var is_safe := true
    for condition in conditions:
        if condition != null and not condition.is_thread_safe:
            is_safe = false
            break
    _thread_safety_cached = is_safe
    _thread_safety_computed = true
    return _thread_safety_cached

static func _get_condition_metadata() -> ConditionMetadata:
    var metadata = ConditionMetadata.new()
    metadata.name_key = "FUSE_CONDITION_ALL_NAME"
    metadata.category_key = "FUSE_CATEGORY_COMPOSITE"
    metadata.description_key = "FUSE_CONDITION_ALL_DESC"
    metadata.keywords = ["所有", "AND", "且", "全部", "满足", "all", "every", "each"]
    metadata.builtin_icon = "AnimationTrackList"
    return metadata
```

### 8.4 Composite Condition Family

Four logical operators under `conditions/composite/`:

| Class | Type | Description |
|------|------|------|
| `CheckAll` | composite_all | AND, supports short-circuiting |
| `CheckAny` | composite (any) | OR |
| `CheckNot` | composite (not) | NOT negation wrapper |
| `CheckComposite` | composite | Generic composition (by child conditions + operator) |

The composite conditions' `_compute_dependencies` and `_compute_thread_safety` both recursively aggregate child conditions, which is key to the dependency graph and to thread-safety transitivity.

### 8.5 Condition Directory Distribution

Subclass directories by domain (several conditions per directory):

```
conditions/
├── animation/    (check_is_playing, check_animation_tree_parameter, ...)
├── arrays/       (check_array_size, check_array_contains)
├── composite/    (check_all, check_any, check_not, check_composite)
├── dictionaries/ (check_dict_size, check_dict_contains_key)
├── distance/     (check_distance)
├── input/        (check_input_pressed, check_input_held, check_input_released, ...)
├── math/         (expression_condition)
├── navigation/   (check_path_available)
├── node/         (check_node_exists, check_node_active, check_node_property, ...)
├── physics/      (check_on_floor, check_on_wall, check_is_falling, check_velocity, ...)
├── rendering/    (check_is_on_screen)
├── scene/        (check_preload_status)
├── scope/        (check_scope_variable)
├── string/       (check_string_length, check_string_contains)
├── system/       (check_frame_rate, check_platform)
├── time/         (check_time_reached, check_time_range, check_countdown_finished, check_game_time)
├── ui/           (check_ui_visible)
└── variable/     (check_variable, compare_variable, check_health_value, ...)
```

---

## 9. Relationships with Other Systems

### 9.1 Relationship with BaseEvent / Trigger / ActionRunner

Conditions are held by upper layers such as Trigger / Runner / composite conditions, participating in event-trigger decisions and instruction execution gating through `check(context)`. Conditions hold no Trigger references themselves; their state is self-contained.

### 9.2 Relationship with ExecutionContext

`check(context)` is the condition's only external entry; the context provides `execution_id` / `local_variables` / `get_variable()` / `has_variable()` etc., and is the data source for cache hashing and dependency checks.

### 9.3 Relationship with the Runtime Instance System

`BaseCondition` is a Resource with runtime state fields stored directly on the instance. In resource-sharing / pooling scenarios, state isolation is handled by the upper-layer Runtime instance system (the Runtime*Instance pattern, isomorphic to BaseEvent); the condition's own `check_count` / `last_result` etc. are cumulative statistics from a single-instance perspective.

### 9.4 Relationship with FuseLogger / FuseError

- All `_log_*` methods delegate to `FuseLogger`, with the unified log prefix `"BaseCondition"`
- All errors create a `FuseError` via `_create_fuse_error[_localized]` and store it in `_fuse_error`; callers can query it via `get_fuse_error()` / `has_fuse_error()`, and `get_detailed_info()` / `get_dependency_visualization_data()` automatically attach error details

### 9.5 Relationship with FuseLocalization

- The static cache `_fuse_localization_class` avoids repeated `load()`
- `_set()` intercepts `resource_name`, automatically calling `_update_resource_name()` on language switch
- `_create_fuse_error_localized()` translates error keys via translate / translate_format

---

## 10. Current Status Notes

- `get_status_info_batch(contexts)` currently ignores the context input and returns the same status for every context (the base class `get_status_info()` does not use context either). Subclasses needing context-dependent status must override it themselves.
- The batch methods (§3.9) loop serially on a single Resource instance; parallel multi-condition evaluation must go through `ParallelConditionEvaluator` — the two are different dimensions.
- `add_dependencies` / `remove_dependencies` only log in the base class; actual dependency management relies on the static declarations of the subclass `_compute_dependencies()`; dynamic add/remove requires a subclass override.
- `get_history` / `clear_history` / `get_performance_metrics().average_check_time` are placeholder implementations in the base class, to be provided by subclasses as needed.

---

**Maintained by**: Fuse development team
**Last updated**: 2026-07-07
**Version**: 2.0 (rewritten in the current-state description format, based on measured reading of `base_condition.gd` 942 lines + `parallel_condition_evaluator.gd` 251 lines + `fuse_thread_safe.gd` 79 lines)
