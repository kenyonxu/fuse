> 🌐 [**中文版**](../../../zh_CN/user_docs/best_practices/custom_condition.md) | English

# Custom Condition Creation Best Practices Guide

## Overview

This guide is based on the Condition architecture of the Fuse Visual Programming system and provides complete best practices for creating custom Condition classes. By following these practices, you can create efficient, reliable, and easy-to-maintain custom conditions.

Conditions are the only one of the three brick types with a "read-only" semantic: they answer "should this really happen" and must not change any game state themselves. This positioning shapes most of the practices in this guide — from thread safety to caching to composite propagation.

## Table of Contents

1. [Condition Architecture Basics](#condition-architecture-basics)
2. [Core Method Implementation](#core-method-implementation)
3. [Lifecycle Management](#lifecycle-management)
4. [Error Handling and Logging](#error-handling-and-logging)
5. [Performance Optimization](#performance-optimization)
6. [Common Implementation Patterns](#common-implementation-patterns)
7. [Complete Example](#complete-example)
8. [Testing and Validation](#testing-and-validation)

---

## Condition Architecture Basics

### BaseCondition Core Responsibilities

`BaseCondition` is the base class of all condition classes and provides the following core capabilities:

- **Template method execution**: `check(context)` uniformly handles caching, negation, and logging; subclasses only implement the actual judgment logic
- **Caching**: the `enable_cache` series of options lets high-frequency conditions invalidate the cache by time and context hash
- **Thread safety declaration**: the `is_thread_safe` property drives the multithreaded condition evaluator's choice between parallel evaluation and falling back to the main thread
- **Batch checks**: `check_batch()` / `check_dependencies_batch()` support batch scenarios
- **Metadata**: condition name, category, and keyword information (via the `ConditionMetadata` class)
- **Dependency declaration**: `get_affected_variables()` declares the variables the condition depends on, used by static analysis and race warnings

### Naming Conventions

- **File name**: a `check_` or `compare_` prefix + snake_case (e.g. `check_health_value.gd`, `compare_variable.gd`)
- **Class name**: a `Check` or `Compare` prefix + PascalCase (e.g. `CheckHealthValue`, `CompareVariable`), **without a `Condition` suffix**
- Name what is judged, not how it is judged — `CheckNodeExists` beats `CheckGetNodeOrNull`

### The Read-Only Contract

A condition inside a Trigger's logic may be evaluated every frame, or moved to a worker thread by the parallel evaluator. Therefore:

- `check()` and everything it calls **must not modify** variables, node properties, or any game state
- Side effects belong to Instructions, not Conditions — the separation of judgment and execution is the foundation of the whole model
- If a check is expensive and staleness is acceptable (e.g. raycasts), use the caching mechanism instead of "writing the result into a variable"

---

## Core Method Implementation

### check() Is a Template Method: Do Not Override It

`BaseCondition.check(context)` handles, in order: cache hit check → subclass logic → `negate_result` negation → logging. Custom conditions **override `_evaluate_condition()`**:

```gdscript
extends BaseCondition
class_name CheckManaFull

@export var mana_variable: String = "mana"
@export var max_mana: float = 100.0

func _evaluate_condition(context: ExecutionContext) -> bool:
    var current: float = context.get_local_variable(mana_variable)
    return current >= max_mana
```

Key points:

1. **The return value must be a `bool`** — do not return a Variant or null; handle errors through the error path instead of returning a non-boolean
2. **`negate_result` is handled by the system** — do not negate inside the subclass; a user ticking "negate" in the Inspector turns `CheckA` into "not A", which is exactly the value of "what is judged" naming
3. **Defend against nulls inside the check**: the target node/variable may not exist; return `false` and log it instead of letting a script error interrupt execution

### Metadata: _get_condition_metadata()

The static method returns a `ConditionMetadata` (inheriting all fields of `FuseMetadata`):

```gdscript
static func _get_condition_metadata() -> ConditionMetadata:
    var metadata := ConditionMetadata.new()
    metadata.name_key = "FUSE_CONDITION_CHECK_MANA_FULL_NAME"
    metadata.category_key = "FUSE_CATEGORY_VARIABLES"
    metadata.description_key = "FUSE_CONDITION_CHECK_MANA_FULL_DESC"
    metadata.keywords = ["法力", "满", "mana", "check", "蓝量"]
    metadata.builtin_icon = "ResourcePreloader"
    return metadata
```

Three hard rules:

1. **It must be implemented**, otherwise both component scan registration and the preset AI context dump will **silently skip** your condition
2. Pick `category_key` from the existing category enums (e.g. `FUSE_CATEGORY_VARIABLES` / `FUSE_CATEGORY_PHYSICS`); do not invent new keys — the localized translation of categories is looked up by key
3. For `keywords`, mix Chinese and English and include synonyms users would search for — the instruction/condition selector search and component matching during AI preset generation both rely on it

---

## Lifecycle Management

Conditions are `Resource` objects that outlive Trigger nodes (they get duplicated and reused across projects), so lifecycle practices revolve around being "stateless":

- **Prefer statelessness**: all information comes from `@export` configuration and the `context` passed to `check()`; do not store mutable runtime data on the condition instance
- When runtime state is unavoidable (e.g. cache counters), implement `reset()` and make it safe to call repeatedly
- When a configuration change affects the thread safety verdict, call `reset_thread_safety_cache()` so the verdict is recomputed
- Do not cache Node references inside conditions — use a NodePath resolved through `context` each time (the same rule as on the instruction side) to avoid dangling references after node destruction

---

## Error Handling and Logging

```gdscript
func _evaluate_condition(context: ExecutionContext) -> bool:
    var node := context.get_node_or_null(target_node)
    if node == null:
        push_warning("CheckNodeActive: 目标节点不存在 %s" % target_node)
        return false
    return node.is_active
```

- **Failure = false, not an error**: "the node doesn't exist so the condition fails" is normal business semantics; record it with `push_warning` and reserve `push_error` for genuinely abnormal situations (broken configuration)
- Logging is leveled via `log_level` and follows the condition instance's configuration; do not call `print` directly
- The static analyzer scans conditions for problems (empty paths, undeclared variables) — returning the real list of affected variable names from `get_affected_variables()` lets the Topology panel and race warnings account for your condition

---

## Performance Optimization

### Thread Safety: Unsafe by Default, Declare Explicitly

`BaseCondition._compute_thread_safety()` **returns false by default** — unless you override it, your condition always executes serially on the main thread. This is the conservatively correct default: the parallel evaluator (`ParallelConditionEvaluator`) moves conditions marked safe into worker threads and keeps unsafe ones on the main thread.

Declaring safety requires two preconditions: `_evaluate_condition()` is read-only inside, and it never touches main-thread-only APIs (scene tree traversal, node properties, signal emission, etc.). Pure variable/math checks can safely declare it:

```gdscript
func _compute_thread_safety() -> bool:
    return true  # 只读 context 变量做比较，无场景树访问
```

### Caching: The Relief Valve for High-Frequency Conditions

Enable caching for scenarios that fire every frame and check expensively (raycasts, distance queries):

| Option | Suggested value | Notes |
|--------|--------|------|
| `enable_cache` | As needed | Off by default; do not enable for checks cheaper than 0.1 ms |
| `cache_duration` | 0.1~0.5s | Expiry time; use smaller values for time-critical gameplay |
| `cache_context_changes` | true | Invalidate on any context change to guarantee correctness |
| `hash_all_variables` | false | By default only dependency variables are hashed; precise invalidation requires declaring `get_affected_variables()` |

The cache is managed centrally by the `check()` template method, invisible to subclasses — `get_cache_info()` reports hit status for debugging.

### Propagation Semantics for Composite Conditions

For composite conditions (`CheckAll` / `CheckAny` / `CheckNot`), thread safety is a **propagated verdict**: a composite is safe only when all of its child conditions are safe (`CheckAll._compute_thread_safety()` checks them one by one and short-circuits at the first unsafe one). Therefore:

- Declaring one condition safe grants parallel eligibility to every composite containing it — think it through before declaring
- When writing custom composite conditions, follow the same propagation logic; do not return true on your own initiative

---

## Common Implementation Patterns

### Pattern 1: Variable Comparison

The most common type and the one that most deserves thread safety. Follow `CompareVariable`: parameters use the dual-track variable binding (direct value / variable source) with configurable scope. When writing these conditions, split "what is compared" into clear `@export` properties and expose the enum (EQUAL/GREATER/LESS) to the Inspector.

### Pattern 2: Scene Query

Queries node state (existence, groups, properties). Its hallmark is mandatory scene tree access — **do not declare thread safety**; pair with caching when expensive. Follow `CheckNodeExists` / `CheckNodeProperty`.

### Pattern 3: Composite Logic

Aggregates an array of child conditions. Beyond thread safety propagation, mind the nested editing experience of `@export var conditions: Array[BaseCondition]` in the Inspector — keep child conditions fully decoupled, and leave negation and enable switches to the base class and the user.

### Pattern 4: Expression Delegation

When a single `ExpressionCondition` can replace several basic comparisons, there is no need to write a new condition — first evaluate whether a custom class is really needed. Expression conditions support variable binding themselves, and most "ad-hoc judgments" should not be crystallized into classes.

---

## Complete Example

A complete condition with caching, thread safety, and dependency declaration:

```gdscript
@tool
extends BaseCondition
class_name CheckDistanceLessThan

@export var source_variable: String = "player_pos"
@export var target_variable: String = "boss_pos"
@export var max_distance: float = 200.0

@export_group("Cache")
@export var enable_cache: bool = true:
    set(value):
        enable_cache = value
@export var cache_duration: float = 0.2

func _evaluate_condition(context: ExecutionContext) -> bool:
    var a: Vector2 = context.get_local_variable(source_variable)
    var b: Vector2 = context.get_local_variable(target_variable)
    return a.distance_to(b) < max_distance

func _compute_thread_safety() -> bool:
    return true  # 纯变量数学比较

func get_affected_variables() -> Array[String]:
    return [source_variable, target_variable]

static func _get_condition_metadata() -> ConditionMetadata:
    var metadata := ConditionMetadata.new()
    metadata.name_key = "FUSE_CONDITION_CHECK_DISTANCE_LESS_THAN_NAME"
    metadata.category_key = "FUSE_CATEGORY_DISTANCE"
    metadata.description_key = "FUSE_CONDITION_CHECK_DISTANCE_LESS_THAN_DESC"
    metadata.keywords = ["距离", "distance", "小于", "接近", "near"]
    metadata.builtin_icon = "Node2D"
    return metadata
```

Add the accompanying localization entries to `addons/fuse/localization/translations.csv` (three columns: key, Chinese, English), otherwise the Inspector shows the raw keys.

---

## Testing and Validation

A minimal verification checklist for a custom condition:

1. **True/false/boundary states**: test the condition passing, failing, and the boundary value (exactly at the threshold) once each
2. **Negation combination**: results mirror after ticking `negate_result`
3. **Null path**: returns false instead of a script error when the target variable/node does not exist
4. **Cache behavior** (if enabled): repeated checks with the same context do not recompute, and the cache invalidates when the context changes
5. **Metadata registration**: after restarting the editor, the condition is findable under the right category in the condition selector, and searching the keywords hits it
6. **Localization**: the Inspector name displays correctly in both Chinese and English

Once the checklist passes, do the final alignment against the complete spec in the [condition generation skill](../../../../agent_skills/fuse-condition-generator/SKILL.md) (templates, naming rules, and validation gates) — that skill is the final authority on condition component specs; this guide details the architectural principles behind it.

---

**Related docs:**

- [Custom Event Creation Best Practices](custom_event.md)
- [Custom Instruction Creation Best Practices](custom_instruction.md)
- [Comprehensive Conditions Guide (Chinese)](../../../zh_CN/user_docs/guides/46-comprehensive-conditions-guide.md)
- [Multithreading Optimization Guide (Chinese)](../../../zh_CN/user_docs/guides/52-multithreading-optimization.md)
