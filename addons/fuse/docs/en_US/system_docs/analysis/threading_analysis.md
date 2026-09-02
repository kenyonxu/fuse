> 🌐 [**中文版**](../../../zh_CN/system_docs/analysis/threading_analysis.md) | English

# Fuse Threading System Analysis Report


## Document Overview

This report presents a comprehensive analysis of the multithreading support module in the Fuse visual programming system. The threading system lives under `addons/fuse/core/threading/` and contains 4 classes (689 lines in total): `FuseTaskManager`, `ParallelConditionEvaluator`, `FuseThreadSafe`, `FuseThreadingConfig`. The module provides the infrastructure for parallel condition evaluation, asynchronous task execution, and shared-data protection, and cooperates with the `is_thread_safe` property of `BaseCondition` to implement the core mechanism of "automatic per-condition-safety parallelism".

**Source directory:** [addons/fuse/core/threading/](../../../../core/threading/)
**Total lines:** 689 (fuse_task_manager.gd 268 + parallel_condition_evaluator.gd 251 + fuse_thread_safe.gd 78 + fuse_threading_config.gd 92)
**Base classes:** RefCounted (3) / Resource (1)
**Dependencies:** WorkerThreadPool (Godot built-in), Semaphore, Mutex, OS.delay_msec, FuseLogger, GlobalVariableManager, ExecutionContext, BaseCondition

---

## 1. Overview

The Fuse threading system is an **infrastructure layer** that provides parallelism upward for condition evaluation, instruction execution, and variable access, while wrapping Godot's `WorkerThreadPool`/`Mutex`/`Semaphore` primitives underneath. Its design philosophy:

1. **Explicit and optional** — all parallel capabilities are on by default but can be turned off (`FuseThreadingConfig.enable_multithreading`); when disabled, the logic degrades to serial, lock-free code.
2. **Tiered by safety** — parallel evaluation applies only to conditions that self-declare thread safety (`BaseCondition.is_thread_safe`); unsafe conditions automatically fall back to serial evaluation on the main thread.
3. **Main-thread friendly** — async tasks execute on worker threads via `WorkerThreadPool.add_task`, but after a task completes, callers are advised to receive the signal on the main thread using `Callable.CONNECT_DEFERRED`.
4. **Unified lock-primitive wrapper** — `FuseThreadSafe` provides locked wrappers for dicts/arrays, sparing business code from repeatedly hand-writing lock/unlock boilerplate.

### Position in the Overall Architecture

```
┌─────────────────────────── Application layer ───────────────────────────┐
│  MultiEventTrigger  ──→ check_conditions_parallel()          │
│  ActionRunner       ──→ _run_parallel() (awaits signals, non-pooled)    │
│  BaseCondition      ──→ is_thread_safe / _compute_thread_safety│
└───────────────────────────┬─────────────────────────────────-┘
                            │ uses
┌─────────────────── Threading system core/threading/ ─────────────────┐
│  ParallelConditionEvaluator  ← the only class wired into the runtime             │
│  FuseTaskManager             ← general task pool wrapper (not wired into the runtime) │
│  FuseThreadSafe              ← dict/array lock wrappers (not wired into the runtime)│
│  FuseThreadingConfig         ← global config Resource (not wired into the runtime)│
└───────────────────────────┬─────────────────────────────────-┘
                            │ wraps
┌─────────────────── Godot primitives ──────────────────────────────-─┐
│  WorkerThreadPool.add_task / Semaphore / Mutex / OS.delay_msec│
└───────────────────────────────────────────────────────────────┘
```

**Important current state**: as of this analysis, of the 4 classes **only `ParallelConditionEvaluator` is actually used by runtime code (`MultiEventTrigger`)**. `FuseTaskManager` / `FuseThreadSafe` / `FuseThreadingConfig` currently appear only in test scripts and documentation (see §5). This is the key fact about the current state.

---

## 2. Class Inventory and Responsibilities

| Class | File | Lines | Base class | Singleton | Wired into runtime |
|------|------|------|------|------|-----------|
| `FuseTaskManager` | [fuse_task_manager.gd](../../../../core/threading/fuse_task_manager.gd) | 268 | RefCounted | Statically self-initializing singleton (L10) | No (tests only) |
| `ParallelConditionEvaluator` | [parallel_condition_evaluator.gd](../../../../core/threading/parallel_condition_evaluator.gd) | 251 | RefCounted | No (instantiated per Trigger) | **Yes** (MultiEventTrigger) |
| `FuseThreadSafe` | [fuse_thread_safe.gd](../../../../core/threading/fuse_thread_safe.gd) | 78 | RefCounted | All-static methods | No (docs/examples only) |
| `FuseThreadingConfig` | [fuse_threading_config.gd](../../../../core/threading/fuse_threading_config.gd) | 92 | Resource | Lazy-loaded singleton (L67) | No (docs/examples only) |

### 2.1 FuseTaskManager — Task Manager

**Responsibility**: wraps Godot's `WorkerThreadPool`, providing a unified interface for submitting, tracking, canceling, and awaiting async tasks.

**Key design points**:
- The static field `_instance: FuseTaskManager` is `new()`-ed at class load time (L10), avoiding race conditions caused by lazy loading.
- Internally maintains `_tasks: Dictionary` (task_id → `TaskInfo`); all reads and writes are protected by `_task_mutex`.
- On task completion the notification is pushed into the `_pending_completions` queue (protected by `_completion_mutex`), and the signal is emitted directly (GDScript signal emission is itself thread-safe, but receivers should use `CONNECT_DEFERRED`).
- Cancellation is **cooperative**: `cancel_task()` only sets the status to `CANCELED`; the worker thread checks that flag before and after execution (L84, L111) — an already-running Callable cannot be truly interrupted.

### 2.2 ParallelConditionEvaluator — Parallel Condition Evaluator

**Responsibility**: evaluates a set of `BaseCondition` in parallel, choosing a strategy by mode (the `EvaluationMode` enum); parallelism is enabled only for conditions marked `is_thread_safe`.

**Key design points**:
- **Three-mode enum** (L8-12): `SEQUENTIAL` (pure serial, safest) / `PARALLEL_SAFE` (default; parallelizes only safe conditions) / `PARALLEL_ALL` (forces parallelism for all; dangerous, for testing only).
- **Context snapshot mechanism**: before parallel evaluation, `_create_context_snapshot()` copies `local_variables` and takes a global-variable snapshot via `GlobalVariableManager.get_all_variables_snapshot()` (L129-146), preventing worker threads from reading/writing main-thread data directly.
- **Semaphore synchronization**: a `Semaphore` + `Mutex` + counter synchronize all parallel tasks; the last task to finish `post()`s the semaphore (L190-191).
- **Timeout protection**: the wait loop uses `try_wait()` + an overall timeout (`max(n * timeout_per_condition, 5.0)` seconds, L196-209), preventing an abnormal worker thread from blocking the main thread forever.
- **Unified statistics lock**: `_stats_mutex` protects the `total_conditions_evaluated` accumulation on both the parallel and serial paths (L65-67, L110-112, L183-185), preventing races during mode switches.

### 2.3 FuseThreadSafe — Thread-Safety Utilities

**Responsibility**: provides locked wrappers for dicts/arrays, all as `static func`; the caller passes in an optional `Mutex` instance.

**API surface** (all `static`):
- dict family: `dict_get_safe` / `dict_set_safe` / `dict_erase_safe` / `dict_has_safe` / `dict_duplicate_safe`
- array family: `array_append_safe` / `array_get_safe` / `array_size_safe`

**Key constraints** (L5-6 comments):
- Suitable only for simple lock management; complex scenarios should use Godot's `Mutex` directly.
- Godot's `Mutex` **does not support `try_lock`**; scenarios needing a non-blocking lock require a different design.

### 2.4 FuseThreadingConfig — Global Configuration

**Responsibility**: the global threading configuration exposed to the editor Inspector as a `Resource`; a lazy-loaded singleton providing switches and thresholds.

**Configuration groups** (@export_group):
- `General`: `enable_multithreading` (default true)
- `Condition Evaluation`: `parallel_condition_evaluation` (true), `max_parallel_conditions` (1–16, default 8), `timeout_per_condition` (0.01–1.0s, default 0.1)
- `Variable Access`: `thread_safe_variables` (true)
- `Async Saving`: `use_thread_pool_for_saving` (true), `auto_save_delay` (0.1–10s, default 1)
- `Resource Preloading`: `enable_resource_preload` (true), `preload_timeout` (1–30s, default 5)

Every setter calls `_notify_config_changed(key)` to emit the `config_changed` signal.

**Derived method**: `get_evaluation_mode()` (L79-82) decides between `SEQUENTIAL` and `PARALLEL_SAFE` based on the switches (it never returns `PARALLEL_ALL`, which is for testing only).

---

## 3. Core API

### 3.1 FuseTaskManager

| Method | Signature | Line | Description |
|------|------|------|------|
| `get_instance` | `static -> FuseTaskManager` | 45 | Returns the static singleton |
| `has_instance` | `static -> bool` | 49 | Always true after static initialization |
| `submit_task` | `(callable: Callable, high_priority: bool = false) -> int` | 54 | Submits a task, returns task_id |
| `submit_batch` | `(callables: Array[Callable], high_priority: bool = false) -> Array[int]` | 231 | Batch submission |
| `await_task` | `(task_id: int, timeout: float = 5.0) -> Variant` | 172 | **Blocks** waiting for the result; ⚠️ must not be called on the main thread |
| `wait_for_task` | `(task_id: int, timeout: float = 5.0) -> Variant` | 203 | Alias of `await_task` |
| `await_all` | `(task_ids: Array[int], timeout: float = 30.0) -> Dictionary` | 239 | Waits for all, returns `{task_id: {result/error}}` |
| `cancel_task` | `(task_id: int) -> bool` | 209 | Cooperative cancel, only marks the status |
| `get_task_status` | `(task_id: int) -> Variant` | 161 | Returns `TaskStatus` or null |
| `get_pending_task_count` | `() -> int` | 254 | Number of currently unfinished tasks |
| `process_completions` | `() -> void` | 147 | Drains the main-thread completion queue (optional) |
| `clear_all_tasks` | `() -> void` | 261 | Clears all tasks (use with care) |

**Signals**: `task_completed(task_id, result)`, `task_failed(task_id, error)`.

**Enum `TaskStatus`** (L13-19): `PENDING` / `RUNNING` / `COMPLETED` / `FAILED` / `CANCELED`.

**Inner class `TaskInfo`** (L22-29): `id` / `status` / `callable` / `start_time` / `end_time` / `result` / `error`.

### 3.2 ParallelConditionEvaluator

| Method | Signature | Line | Description |
|------|------|------|------|
| `evaluate_parallel` | `(context: ExecutionContext, conditions: Array[BaseCondition]) -> Array[bool]` | 32 | Entry point; dispatches by `evaluation_mode` |
| `_evaluate_sequential` | `(context, conditions) -> Array[bool]` | 54 | Serial fallback (also takes `_stats_mutex`) |
| `_evaluate_parallel_safe` | `(context, conditions) -> Array[bool]` | 72 | Safe parallel: splits safe/unsafe indices |
| `_evaluate_parallel_all` | `(context, conditions) -> Array[bool]` | 117 | Dangerous mode (forces full parallelism) |
| `_create_context_snapshot` | `(context) -> Dictionary` | 129 | Copies local/global variables |
| `_create_temp_context_from_snapshot` | `(snapshot) -> ExecutionContext` | 228 | Builds a temporary context for each worker thread |
| `_evaluate_safe_conditions_parallel` | `(snapshot, conditions, indices) -> Array[bool]` | 151 | Core Semaphore-synchronized implementation |
| `get_statistics` | `() -> Dictionary` | 239 | Includes `last_evaluation_time` / `total_conditions_evaluated` / `evaluation_mode` |
| `reset_statistics` | `() -> void` | 247 | Resets statistics under lock |

**Signal**: `evaluation_completed(results: Array[bool], total_time: float)`.

**Enum `EvaluationMode`** (L8-12): `SEQUENTIAL` / `PARALLEL_SAFE` (default) / `PARALLEL_ALL`.

**Configurable fields**: `evaluation_mode` (L15, default `PARALLEL_SAFE`), `timeout_per_condition` (L16, default 0.1s).

### 3.3 FuseThreadSafe

All `static func`; the third parameter `mutex: Mutex = null` is optional:

| Method | Signature | Line |
|------|------|------|
| `dict_get_safe` | `(dict, key, default=null, mutex=null) -> Variant` | 11 |
| `dict_set_safe` | `(dict, key, value, mutex=null) -> void` | 20 |
| `dict_erase_safe` | `(dict, key, mutex=null) -> bool` | 28 |
| `dict_has_safe` | `(dict, key, mutex=null) -> bool` | 37 |
| `dict_duplicate_safe` | `(dict, deep=false, mutex=null) -> Dictionary` | 46 |
| `array_append_safe` | `(arr, value, mutex=null) -> void` | 55 |
| `array_get_safe` | `(arr, index, default_value=null, mutex=null) -> Variant` | 63 |
| `array_size_safe` | `(arr, mutex=null) -> int` | 72 |

### 3.4 FuseThreadingConfig

| Method | Signature | Line | Description |
|------|------|------|------|
| `get_instance` | `static -> FuseThreadingConfig` | 67 | Lazy-loaded singleton |
| `has_instance` | `static -> bool` | 72 | |
| `get_evaluation_mode` | `() -> int` | 79 | Returns the `EvaluationMode` ordinal |
| `get_debug_info` | `() -> Dictionary` | 85 | Debug info |

**Signal**: `config_changed(key: String, new_value: Variant)`.

---

## 4. Architectural Relationships

### 4.1 Cooperation with BaseCondition (core mechanism)

The threading system is tightly coupled with `BaseCondition` through two hooks (see [base_condition.gd](../../../../core/base/base_condition.gd)):

- **The `is_thread_safe` property** (L60-62): the getter delegates to `_compute_thread_safety()`.
- **`_compute_thread_safety()`** (L374-381): returns `false` by default, with caching (`_thread_safety_cached` / `_thread_safety_computed`); subclasses override it to declare thread safety.
- **`reset_thread_safety_cache()`** (L385-387): clears the cache; invoked automatically inside `reset()` (L403), ensuring recomputation after configuration changes.

`ParallelConditionEvaluator._evaluate_parallel_safe()` splits conditions into safe/unsafe index lists via `condition.is_thread_safe` (L82-85). This mechanism implements the declarative policy of "**safe conditions run in parallel, unsafe conditions run serially — decided by each condition itself**".

### 4.2 Integration with MultiEventTrigger (the only runtime consumer)

`MultiEventTrigger` is currently the only runtime class wired into the threading system (see [multi_event_trigger.gd](../../../../core/multi_event_trigger.gd)):

- **Holds an instance**: `_condition_evaluator: ParallelConditionEvaluator` (L55).
- **Lifecycle**: `_on_trigger_ready()` calls `_initialize_parallel_evaluator()` (L92) to create the instance and set it to `PARALLEL_SAFE` (L107-108); `_on_trigger_exit_tree()` nulls it (L100).
- **Toggle**: `@export var use_parallel_condition_evaluation: bool = true` (L52).
- **Call entry**: `check_conditions_parallel(binding_index, context)` (L330-357) collects the enabled conditions, calls `evaluate_parallel()`, and logically ANDs the results; when the evaluator is null it falls back to `check_conditions_serial()` (L363-368).

### 4.3 Relationship with ActionRunner's Parallel Mode (independent system; does not reuse the threading system)

`ActionRunner._run_parallel()` ([action_runner.gd](../../../../core/base/action_runner.gd) L330-390) is **another, independent parallel mechanism**:

- It does not go through `WorkerThreadPool`; instead it calls `instruction.execute(context)` **without awaiting**, letting instructions run in the background (L364), then uses `_wait_for_all_tasks()` (L893-918) + `_wait_for_any_signal()` (L922) to `await` the completion of all via the array of `instruction.finished` signals.
- In other words, ActionRunner's "parallel" is **asynchronous concurrency** (signal-driven); worker threads are decided by the instructions themselves (some instructions may internally use `WorkerThreadPool`, but ActionRunner itself does not schedule threads).
- The `ExecutionMode` enum (L67-70): `SEQUENTIAL` / `PARALLEL`, default `SEQUENTIAL` (L18).

**Conclusion**: `ActionRunner`'s parallelism has **no direct code dependency** on the `core/threading/` module; the two are parallel concurrency models.

### 4.4 Threading System Internal Dependencies

```
ParallelConditionEvaluator
    ├── uses GlobalVariableManager.get_all_variables_snapshot() (L144)
    ├── uses WorkerThreadPool.add_task (L170)
    ├── uses Semaphore + Mutex (L160-161)
    └── uses OS.delay_msec(1) to prevent busy-waiting (L223)

FuseTaskManager
    └── uses WorkerThreadPool.add_task (L68)

FuseThreadSafe    (pure utility, no dependencies)
FuseThreadingConfig
    └── references ParallelConditionEvaluator.EvaluationMode (L81-82)
```

---

## 5. Usage Patterns

### 5.1 Pattern A: Built-in parallel condition evaluation in triggers (wired in)

The only pattern currently in production use. No hand-written threading code required:

```gdscript
# MultiEventTrigger._on_trigger_ready()
_initialize_parallel_evaluator()  # automatically creates the evaluator in PARALLEL_SAFE mode

# At evaluation time
var ok: bool = check_conditions_parallel(binding_index, context)
```

A condition subclass simply overrides `_compute_thread_safety()` to return `true` as needed and gets parallelism automatically:

```gdscript
# Example of a pure-computation condition
func _compute_thread_safety() -> bool:
    return true  # does not access nodes, only compares variables
```

### 5.2 Pattern B: General async tasks (API ready, not wired into the runtime)

```gdscript
var tm := FuseTaskManager.get_instance()
var task_id := tm.submit_task(_heavy_work.bind(arg))
# the receiver uses DEFERRED to get the callback on the main thread
tm.task_completed.connect(_on_done, Callable.CONNECT_DEFERRED)

func _heavy_work(arg):
    return result
```

⚠️ Current state: as of this analysis, `FuseTaskManager` is called only in `tests/threading/`; runtime code (events/instructions/conditions/triggers) does not use it directly. Switches such as `FuseThreadingConfig.use_thread_pool_for_saving` / `enable_resource_preload` have **no consumers found** in the core code.

### 5.3 Pattern C: Manually locking shared data (API ready, not wired into the runtime)

```gdscript
var _mutex := Mutex.new()
var _data := {}

FuseThreadSafe.dict_set_safe(_data, "key", value, _mutex)
var v = FuseThreadSafe.dict_get_safe(_data, "key", null, _mutex)
```

⚠️ Current state: `FuseThreadSafe` has **no call sites at all** in `addons/fuse/` source code (excluding tests and docs). Shared-data protection in the runtime is handled by each module's own Mutex (e.g. `FuseTaskManager._task_mutex`, `ParallelConditionEvaluator._stats_mutex`).

### 5.4 Pattern D: ActionRunner async parallelism (independent system; does not reuse the threading system)

```gdscript
action_runner.execution_mode = ActionRunner.ExecutionMode.PARALLEL
action_runner.execute(context)  # does not await internally; joins via the finished signals
```

---

## 6. Thread-Safety Design Points

### 6.1 Lock Granularity and Distribution

The threading system uses **multiple locks over separate domains** rather than a single global lock:

| Lock | Owner | Protects |
|----|------|---------|
| `_task_mutex` | FuseTaskManager | the `_tasks` dictionary, `_task_counter` |
| `_completion_mutex` | FuseTaskManager | the `_pending_completions` queue |
| `_stats_mutex` | ParallelConditionEvaluator | `total_conditions_evaluated` (**unified across serial/parallel modes**) |
| `completion_mutex` | ParallelConditionEvaluator (local) | the `results` array, `completed_count` |
| caller-supplied mutex | FuseThreadSafe parameter | dicts/arrays managed by the caller |

### 6.2 Thread-Safety Contract for Signal Emission

The `FuseTaskManager` file-header comment (L5-6) states it explicitly: GDScript's `signal.emit()` is itself thread-safe, but **receivers must connect with `Callable.CONNECT_DEFERRED`** to guarantee the callback runs on the main thread. This is the established pattern for worker-thread → main-thread communication.

### 6.3 Cooperative Cancellation

`FuseTaskManager.cancel_task()` cannot truly interrupt a running Callable — it only sets the `CANCELED` status, which the worker thread discovers at two checkpoints before/after execution (L84, L111) and returns early. This means long tasks must **proactively check periodically** to respond to cancellation in time (the current API exposes no checking interface to the Callable itself — a design gap).

### 6.4 Context Snapshot Isolation

Before parallel evaluation, `ParallelConditionEvaluator` **deep-copies** `local_variables` (`duplicate(true)`, L140) and takes a global-variable snapshot (L143-144); each worker thread rebuilds an independent `ExecutionContext` from the snapshot (`_create_temp_context_from_snapshot`, L228-236). This avoids the data races caused by multiple threads reading/writing `ExecutionContext` at the same time, at the cost that **modifications to variables during condition evaluation are not written back to the main context**.

> **The no-side-effect constraint is declared** (CODE_ISSUES B16, commit `42cb339`): the default implementation of `_compute_thread_safety()` and the ParallelConditionEvaluator class comment explicitly require — "conditions whose evaluation has side effects (mutating variables) must not be marked `is_thread_safe`". Condition subclasses should verify they do not mutate variables before overriding to return true.

### 6.5 Timeouts and Deadlock Prevention

- `ParallelConditionEvaluator._evaluate_safe_conditions_parallel()`: overall timeout = `max(n * timeout_per_condition, 5.0)` seconds; the wait loop uses non-blocking `Semaphore.try_wait()` + `OS.delay_msec(1)` to prevent busy-waiting (L196-223); on timeout it logs a warning and returns the current results (indices not yet finished keep the default `false`).
- `FuseTaskManager.await_task()`: polls with `OS.delay_msec(10)` and returns null on timeout.

### 6.6 Caching and Configuration Changes

`BaseCondition`'s thread-safety verdict is cached (`_thread_safety_computed`); `reset()` calls `reset_thread_safety_cache()` to invalidate the cache, ensuring re-evaluation after the condition's configuration changes. `FuseThreadingConfig`'s setters notify listeners via the `config_changed` signal, but currently there are **no runtime listeners**.

---

## 7. Overall Assessment

### Strengths

1. **Clear tiered parallelism strategy** — the three-level `EvaluationMode` enum plus the `is_thread_safe` declaration mechanism delegates the "parallel or not" decision to individual condition subclasses, following the principle of least surprise.
2. **Rigorous isolation** — context snapshot + per-thread independent `ExecutionContext` eliminates, at the data layer, parallel evaluation polluting main-thread state.
3. **Deadlock-proof design** — Semaphore synchronization + overall timeout + non-blocking `try_wait` loop prevent an abnormal worker thread from dragging down the main thread.
4. **Unified statistics lock** — `_stats_mutex` is used on both the serial and parallel paths, preventing the subtle race of "unlocked serial / locked parallel".
5. **Symmetric API design** — `FuseThreadSafe`'s full dict/array method set and `FuseTaskManager`'s submit/await/cancel trio give a complete interface surface.
6. **Configuration as a Resource** — `FuseThreadingConfig` is a `Resource` that can be edited in the Inspector, serialized, and notifies changes via a signal.

### Weaknesses

1. **A large body of code sits "unwired"** — the three classes `FuseTaskManager` / `FuseThreadSafe` / `FuseThreadingConfig` (about 438 lines) have no consumers in runtime code, appearing only in tests and docs. Switches such as `use_thread_pool_for_saving` / `enable_resource_preload` / `thread_safe_variables` lack any implementation-side response.
2. **Incomplete cancellation mechanism** — `cancel_task()` lacks an API for the Callable to check proactively, so long tasks cannot respond to cancellation in time.
3. **Two parallel systems, disconnected** — the `core/threading/` WorkerThreadPool pattern and `ActionRunner`'s signal-await pattern do not reuse each other and are conceptually easy to confuse (the former is true thread parallelism, the latter asynchronous concurrency).
4. **The Godot Mutex limitation is not worked around** — the `FuseThreadSafe` comments admit that `try_lock` semantics cannot be provided; scenarios needing a non-blocking lock still require caller-side design.
5. **The context snapshot has no write-back path (declared constraint)** — modifications to variables during parallel condition evaluation are not written back to the main context (snapshot isolation is by design, protecting main-thread state from pollution). **The constraint "conditions whose evaluation has side effects (mutating variables) must not be marked `is_thread_safe`" is explicitly declared in the `_compute_thread_safety()` default implementation and the ParallelConditionEvaluator class comment** (CODE_ISSUES B16, commit `42cb339`). Condition subclasses should confirm they do not mutate variables before overriding `_compute_thread_safety()` to return true.
6. **Slight race in the config singleton's lazy loading** — the `if _instance == null` check in `FuseThreadingConfig.get_instance()` (L67-70) is unlocked, inconsistent in style with `FuseTaskManager`'s static self-initialization (L10, race-free); very early cross-thread access in the first frames could theoretically create multiple instances.

---

**Maintained by**: Fuse development team
**Last updated**: 2026-07-07
**Version**: 1.0.0
**Reference code**: `addons/fuse/core/threading/` (4 files, 689 lines), `addons/fuse/core/base/base_condition.gd`, `addons/fuse/core/multi_event_trigger.gd`, `addons/fuse/core/base/action_runner.gd`
