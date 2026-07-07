# Fuse 线程系统分析报告

## 文档概述

本报告对 Fuse 可视化编程系统中的多线程支持模块进行全面分析。线程系统位于 `addons/fuse/core/threading/`，共 4 个类（合计约 689 行）：`FuseTaskManager`、`ParallelConditionEvaluator`、`FuseThreadSafe`、`FuseThreadingConfig`。该模块为条件并行评估、异步任务执行和共享数据保护提供基础设施，并与 `BaseCondition` 的 `is_thread_safe` 属性协作，实现"按条件安全性自动并行"的核心机制。

**源文件目录:** [addons/fuse/core/threading/](../../../core/threading/)
**总行数:** 689 行（fuse_task_manager.gd 268 + parallel_condition_evaluator.gd 251 + fuse_thread_safe.gd 78 + fuse_threading_config.gd 92）
**基础类:** RefCounted（3 个）/ Resource（1 个）
**依赖:** WorkerThreadPool（Godot 内建）、Semaphore、Mutex、OS.delay_msec、FuseLogger、GlobalVariableManager、ExecutionContext、BaseCondition

---

## 1. 概述

Fuse 线程系统是一个**基础设施层**，向上为条件评估、指令执行、变量访问等场景提供并行能力，向下封装 Godot 的 `WorkerThreadPool`/`Mutex`/`Semaphore` 原语。其设计哲学是：

1. **显式可选** — 所有并行能力默认开启但可关闭（`FuseThreadingConfig.enable_multithreading`），关闭后退化为串行无锁逻辑。
2. **按安全性分级** — 并行评估只对自声明线程安全的条件生效（`BaseCondition.is_thread_safe`），不安全条件自动回退到主线程串行评估。
3. **主线程友好** — 异步任务通过 `WorkerThreadPool.add_task` 在工作线程执行，但任务完成后建议调用方使用 `Callable.CONNECT_DEFERRED` 在主线程接收信号。
4. **统一锁原语封装** — `FuseThreadSafe` 提供 dict/array 的加锁包装，避免业务代码反复手写 lock/unlock 样板。

### 在整体架构中的位置

```
┌─────────────────────────── 应用层 ───────────────────────────┐
│  MultiEventTrigger  ──→ check_conditions_parallel()          │
│  ActionRunner       ──→ _run_parallel() (await 信号, 非池)    │
│  BaseCondition      ──→ is_thread_safe / _compute_thread_safety│
└───────────────────────────┬─────────────────────────────────-┘
                            │ 使用
┌─────────────────── 线程系统 core/threading/ ─────────────────┐
│  ParallelConditionEvaluator  ← 唯一接入运行时的类             │
│  FuseTaskManager             ← 通用任务池封装（运行时未接入） │
│  FuseThreadSafe              ← dict/array 锁封装（运行时未接入）│
│  FuseThreadingConfig         ← 全局配置 Resource（运行时未接入）│
└───────────────────────────┬─────────────────────────────────-┘
                            │ 封装
┌─────────────────── Godot 原语 ──────────────────────────────-─┐
│  WorkerThreadPool.add_task / Semaphore / Mutex / OS.delay_msec│
└───────────────────────────────────────────────────────────────┘
```

**重要现状**：截至本次分析，4 个类中**只有 `ParallelConditionEvaluator` 被运行时代码（`MultiEventTrigger`）实际使用**。`FuseTaskManager` / `FuseThreadSafe` / `FuseThreadingConfig` 目前仅出现在测试脚本和文档中（详见 §5）。这是现状描述的关键事实。

---

## 2. 类清单与职责

| 类名 | 文件 | 行数 | 基类 | 单例 | 运行时接入 |
|------|------|------|------|------|-----------|
| `FuseTaskManager` | [fuse_task_manager.gd](../../../core/threading/fuse_task_manager.gd) | 268 | RefCounted | 静态自初始化单例（L10） | 否（仅测试） |
| `ParallelConditionEvaluator` | [parallel_condition_evaluator.gd](../../../core/threading/parallel_condition_evaluator.gd) | 251 | RefCounted | 否（按 Trigger 实例化） | **是**（MultiEventTrigger） |
| `FuseThreadSafe` | [fuse_thread_safe.gd](../../../core/threading/fuse_thread_safe.gd) | 78 | RefCounted | 全静态方法 | 否（仅文档/示例） |
| `FuseThreadingConfig` | [fuse_threading_config.gd](../../../core/threading/fuse_threading_config.gd) | 92 | Resource | 懒加载单例（L67） | 否（仅文档/示例） |

### 2.1 FuseTaskManager — 任务管理器

**职责**：封装 Godot `WorkerThreadPool`，提供异步任务提交、跟踪、取消、等待的统一接口。

**关键设计**：
- 静态字段 `_instance: FuseTaskManager` 在类加载时即 `new()`（L10），避免懒加载引发的竞态条件。
- 内部维护 `_tasks: Dictionary`（task_id → `TaskInfo`），所有读写经 `_task_mutex` 保护。
- 任务完成后将通知推入 `_pending_completions` 队列（`_completion_mutex` 保护），并直接 `emit` 信号（GDScript 信号发射本身线程安全，但接收方应用 `CONNECT_DEFERRED`）。
- 取消机制是**协作式**：`cancel_task()` 仅将状态置为 `CANCELED`，工作线程在执行前后检查该标志位（L84、L111），无法真正中断已运行的 Callable。

### 2.2 ParallelConditionEvaluator — 并行条件评估器

**职责**：并行评估一组 `BaseCondition`，根据模式（`EvaluationMode` 枚举）选择策略；仅对标记为 `is_thread_safe` 的条件启用并行。

**关键设计**：
- **三模式枚举**（L8-12）：`SEQUENTIAL`（纯串行，最安全）/ `PARALLEL_SAFE`（默认，仅并行安全条件）/ `PARALLEL_ALL`（强制并行全部，危险，仅供测试）。
- **上下文快照机制**：并行评估前调用 `_create_context_snapshot()` 复制 `local_variables` 并通过 `GlobalVariableManager.get_all_variables_snapshot()` 取全局变量快照（L129-146），避免工作线程直接读写主线程数据。
- **Semaphore 同步**：用 `Semaphore` + `Mutex` + 计数器同步所有并行任务，最后一个完成的任务 `post()` 信号量（L190-191）。
- **超时保护**：等待循环使用 `try_wait()` + 总超时（`max(n * timeout_per_condition, 5.0)` 秒，L196-209），避免工作线程异常导致主线程永久阻塞。
- **统一统计锁**：`_stats_mutex` 同时保护并行和串行路径下的 `total_conditions_evaluated` 累计（L65-67、L110-112、L183-185），防止模式切换时的竞态。

### 2.3 FuseThreadSafe — 线程安全工具

**职责**：提供 dict/array 的加锁包装，全部为 `static func`，调用方传入可选的 `Mutex` 实例。

**API 表面**（全部 `static`）：
- dict 系列：`dict_get_safe` / `dict_set_safe` / `dict_erase_safe` / `dict_has_safe` / `dict_duplicate_safe`
- array 系列：`array_append_safe` / `array_get_safe` / `array_size_safe`

**关键约束**（L5-6 注释）：
- 仅适合简单锁管理；复杂场景应直接用 Godot `Mutex`。
- Godot `Mutex` **不支持 `try_lock`**，需要非阻塞锁的场景应另寻设计。

### 2.4 FuseThreadingConfig — 全局配置

**职责**：作为 `Resource` 暴露给编辑器 Inspector 的全局线程配置，懒加载单例，提供开关与阈值。

**配置分组**（@export_group）：
- `General`：`enable_multithreading`（默认 true）
- `Condition Evaluation`：`parallel_condition_evaluation`（true）、`max_parallel_conditions`（1–16，默认 8）、`timeout_per_condition`（0.01–1.0s，默认 0.1）
- `Variable Access`：`thread_safe_variables`（true）
- `Async Saving`：`use_thread_pool_for_saving`（true）、`auto_save_delay`（0.1–10s，默认 1）
- `Resource Preloading`：`enable_resource_preload`（true）、`preload_timeout`（1–30s，默认 5）

每个 setter 内调用 `_notify_config_changed(key)` 发射 `config_changed` 信号。

**派生方法**：`get_evaluation_mode()`（L79-82）根据开关在 `SEQUENTIAL` 与 `PARALLEL_SAFE` 之间决策（永不返回 `PARALLEL_ALL`，那仅供测试）。

---

## 3. 核心 API

### 3.1 FuseTaskManager

| 方法 | 签名 | 行号 | 说明 |
|------|------|------|------|
| `get_instance` | `static -> FuseTaskManager` | 45 | 返回静态单例 |
| `has_instance` | `static -> bool` | 49 | 静态初始化后恒为 true |
| `submit_task` | `(callable: Callable, high_priority: bool = false) -> int` | 54 | 提交任务，返回 task_id |
| `submit_batch` | `(callables: Array[Callable], high_priority: bool = false) -> Array[int]` | 231 | 批量提交 |
| `await_task` | `(task_id: int, timeout: float = 5.0) -> Variant` | 172 | **阻塞**等待结果；⚠️ 禁止在主线程调用 |
| `wait_for_task` | `(task_id: int, timeout: float = 5.0) -> Variant` | 203 | `await_task` 别名 |
| `await_all` | `(task_ids: Array[int], timeout: float = 30.0) -> Dictionary` | 239 | 等待全部，返回 `{task_id: {result/error}}` |
| `cancel_task` | `(task_id: int) -> bool` | 209 | 协作式取消，仅标记状态 |
| `get_task_status` | `(task_id: int) -> Variant` | 161 | 返回 `TaskStatus` 或 null |
| `get_pending_task_count` | `() -> int` | 254 | 当前未完成任务数 |
| `process_completions` | `() -> void` | 147 | 处理主线程完成队列（可选） |
| `clear_all_tasks` | `() -> void` | 261 | 清空所有任务（慎用） |

**信号**：`task_completed(task_id, result)`、`task_failed(task_id, error)`。

**枚举 `TaskStatus`**（L13-19）：`PENDING` / `RUNNING` / `COMPLETED` / `FAILED` / `CANCELED`。

**内部类 `TaskInfo`**（L22-29）：`id` / `status` / `callable` / `start_time` / `end_time` / `result` / `error`。

### 3.2 ParallelConditionEvaluator

| 方法 | 签名 | 行号 | 说明 |
|------|------|------|------|
| `evaluate_parallel` | `(context: ExecutionContext, conditions: Array[BaseCondition]) -> Array[bool]` | 32 | 入口，按 `evaluation_mode` 分发 |
| `_evaluate_sequential` | `(context, conditions) -> Array[bool]` | 54 | 串行回退（同样加 `_stats_mutex`） |
| `_evaluate_parallel_safe` | `(context, conditions) -> Array[bool]` | 72 | 安全并行：拆分 safe/unsafe 索引 |
| `_evaluate_parallel_all` | `(context, conditions) -> Array[bool]` | 117 | 危险模式（强制全并行） |
| `_create_context_snapshot` | `(context) -> Dictionary` | 129 | 复制 local/global 变量 |
| `_create_temp_context_from_snapshot` | `(snapshot) -> ExecutionContext` | 228 | 为每个工作线程构造临时上下文 |
| `_evaluate_safe_conditions_parallel` | `(snapshot, conditions, indices) -> Array[bool]` | 151 | Semaphore 同步核心实现 |
| `get_statistics` | `() -> Dictionary` | 239 | 含 `last_evaluation_time` / `total_conditions_evaluated` / `evaluation_mode` |
| `reset_statistics` | `() -> void` | 247 | 加锁重置统计 |

**信号**：`evaluation_completed(results: Array[bool], total_time: float)`。

**枚举 `EvaluationMode`**（L8-12）：`SEQUENTIAL` / `PARALLEL_SAFE`（默认）/ `PARALLEL_ALL`。

**可配置字段**：`evaluation_mode`（L15，默认 `PARALLEL_SAFE`）、`timeout_per_condition`（L16，默认 0.1s）。

### 3.3 FuseThreadSafe

全部 `static func`，第三参数 `mutex: Mutex = null` 可选：

| 方法 | 签名 | 行号 |
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

| 方法 | 签名 | 行号 | 说明 |
|------|------|------|------|
| `get_instance` | `static -> FuseThreadingConfig` | 67 | 懒加载单例 |
| `has_instance` | `static -> bool` | 72 | |
| `get_evaluation_mode` | `() -> int` | 79 | 返回 `EvaluationMode` 序数值 |
| `get_debug_info` | `() -> Dictionary` | 85 | 调试信息 |

**信号**：`config_changed(key: String, new_value: Variant)`。

---

## 4. 架构关系

### 4.1 与 BaseCondition 的协作（核心机制）

线程系统与 `BaseCondition` 通过两个钩子紧耦合（见 [base_condition.gd](../../../core/base/base_condition.gd)）：

- **`is_thread_safe` 属性**（L60-62）：getter 委托给 `_compute_thread_safety()`。
- **`_compute_thread_safety()`**（L374-381）：默认返回 `false`，带缓存（`_thread_safety_cached` / `_thread_safety_computed`），子类重写以声明线程安全。
- **`reset_thread_safety_cache()`**（L385-387）：清除缓存；在 `reset()` 中被自动调用（L403），确保配置变更后重新计算。

`ParallelConditionEvaluator._evaluate_parallel_safe()` 通过 `condition.is_thread_safe` 把条件分流到 safe/unsafe 两个索引列表（L82-85）。这套机制实现了"**安全条件并行、不安全条件串行，由条件自身决定**"的声明式策略。

### 4.2 与 MultiEventTrigger 的接入（唯一运行时消费者）

`MultiEventTrigger` 是当前唯一接入线程系统的运行时类（见 [multi_event_trigger.gd](../../../core/multi_event_trigger.gd)）：

- **持有实例**：`_condition_evaluator: ParallelConditionEvaluator`（L55）。
- **生命周期**：在 `_on_trigger_ready()` 中调用 `_initialize_parallel_evaluator()`（L92）创建实例并设为 `PARALLEL_SAFE`（L107-108）；在 `_on_trigger_exit_tree()` 中置为 null（L100）。
- **触发开关**：`@export var use_parallel_condition_evaluation: bool = true`（L52）。
- **调用入口**：`check_conditions_parallel(binding_index, context)`（L330-357）收集启用条件，调用 `evaluate_parallel()`，对结果做逻辑 AND；当评估器为 null 时回退到 `check_conditions_serial()`（L363-368）。

### 4.3 与 ActionRunner 并行模式的关系（独立体系，不复用线程系统）

`ActionRunner._run_parallel()`（[action_runner.gd](../../../core/base/action_runner.gd) L330-390）是**另一套独立的并行机制**：

- 不通过 `WorkerThreadPool`，而是**不 await** 地调用 `instruction.execute(context)` 让指令在后台运行（L364），随后用 `_wait_for_all_tasks()`（L893-918）+ `_wait_for_any_signal()`（L922）通过 `instruction.finished` 信号数组 `await` 全部完成。
- 即 ActionRunner 的"并行"是**异步并发**（信号驱动），工作线程由指令自身决定（部分指令可能内部用 `WorkerThreadPool`，但 ActionRunner 本身不调度线程）。
- `ExecutionMode` 枚举（L67-70）：`SEQUENTIAL` / `PARALLEL`，默认 `SEQUENTIAL`（L18）。

**结论**：`ActionRunner` 的并行与 `core/threading/` 模块**没有直接代码依赖**，二者是平行的两种并发模型。

### 4.4 线程系统内部依赖

```
ParallelConditionEvaluator
    ├── 使用 GlobalVariableManager.get_all_variables_snapshot()（L144）
    ├── 使用 WorkerThreadPool.add_task（L170）
    ├── 使用 Semaphore + Mutex（L160-161）
    └── 使用 OS.delay_msec(1) 防忙等（L223）

FuseTaskManager
    └── 使用 WorkerThreadPool.add_task（L68）

FuseThreadSafe    （纯工具，无依赖）
FuseThreadingConfig
    └── 引用 ParallelConditionEvaluator.EvaluationMode（L81-82）
```

---

## 5. 使用模式

### 5.1 模式 A：触发器内置并行条件评估（已接入）

当前生产环境中唯一在用的模式。无需手写线程代码：

```gdscript
# MultiEventTrigger._on_trigger_ready()
_initialize_parallel_evaluator()  # 自动创建评估器，模式 PARALLEL_SAFE

# 评估时
var ok: bool = check_conditions_parallel(binding_index, context)
```

条件子类按需重写 `_compute_thread_safety()` 返回 `true` 即可自动并行：

```gdscript
# 纯计算型条件示例
func _compute_thread_safety() -> bool:
    return true  # 不访问节点、仅做变量比较
```

### 5.2 模式 B：通用异步任务（API 已就绪，运行时未接入）

```gdscript
var tm := FuseTaskManager.get_instance()
var task_id := tm.submit_task(_heavy_work.bind(arg))
# 接收方使用 DEFERRED 在主线程回调
tm.task_completed.connect(_on_done, Callable.CONNECT_DEFERRED)

func _heavy_work(arg):
    return result
```

⚠️ 现状：截至本次分析，`FuseTaskManager` 仅在 `addons/fuse/tests/threading/` 中被调用，运行时代码（events/instructions/conditions/triggers）未直接使用。`FuseThreadingConfig.use_thread_pool_for_saving` / `enable_resource_preload` 等开关在核心代码中**找不到消费者**。

### 5.3 模式 C：手动加锁保护共享数据（API 已就绪，运行时未接入）

```gdscript
var _mutex := Mutex.new()
var _data := {}

FuseThreadSafe.dict_set_safe(_data, "key", value, _mutex)
var v = FuseThreadSafe.dict_get_safe(_data, "key", null, _mutex)
```

⚠️ 现状：`FuseThreadSafe` 在 `addons/fuse/` 源代码（非测试、非文档）中**无任何调用点**。运行时的共享数据保护由各模块自管 Mutex（如 `FuseTaskManager._task_mutex`、`ParallelConditionEvaluator._stats_mutex`）。

### 5.4 模式 D：ActionRunner 异步并行（独立体系，不复用线程系统）

```gdscript
action_runner.execution_mode = ActionRunner.ExecutionMode.PARALLEL
action_runner.execute(context)  # 内部不 await，靠 finished 信号汇合
```

---

## 6. 线程安全设计要点

### 6.1 锁的粒度与分布

线程系统采用**多锁分域**而非单一全局锁：

| 锁 | 所属 | 保护对象 |
|----|------|---------|
| `_task_mutex` | FuseTaskManager | `_tasks` 字典、`_task_counter` |
| `_completion_mutex` | FuseTaskManager | `_pending_completions` 队列 |
| `_stats_mutex` | ParallelConditionEvaluator | `total_conditions_evaluated`（**跨串/并行模式统一**） |
| `completion_mutex` | ParallelConditionEvaluator（局部） | `results` 数组、`completed_count` |
| 用户传入 mutex | FuseThreadSafe 参数 | 调用方自管的 dict/array |

### 6.2 信号发射的线程安全契约

`FuseTaskManager` 文件头注释（L5-6）明确：GDScript 的 `signal.emit()` 本身线程安全，但**接收方必须用 `Callable.CONNECT_DEFERRED` 连接**才能保证回调在主线程执行。这是工作线程→主线程通信的既定模式。

### 6.3 协作式取消

`FuseTaskManager.cancel_task()` 不能真正中断运行中的 Callable —— 它仅置位 `CANCELED` 状态，工作线程在执行前后两处检查点（L84、L111）发现该状态即提前返回。这意味着长任务必须**主动周期性检查**才能及时响应取消（当前 API 未暴露检查接口给 Callable 内部，是设计上的缺口）。

### 6.4 上下文快照隔离

`ParallelConditionEvaluator` 在并行评估前**深拷贝** `local_variables`（`duplicate(true)`，L140）并取全局变量快照（L143-144），每个工作线程从快照重建独立 `ExecutionContext`（`_create_temp_context_from_snapshot`，L228-236）。这避免了多线程同时读写 `ExecutionContext` 引发的数据竞争，代价是**条件评估期间对变量的修改不会回写到主上下文**。

> **无副作用约束已声明**（CODE_ISSUES B16，commit `42cb339`）：`_compute_thread_safety()` 默认实现与 ParallelConditionEvaluator 类注释明确要求——"评估带副作用（修改变量）的条件不应标记 `is_thread_safe`"。条件子类重写返回 true 前应自检无变量修改。

### 6.5 超时与防死锁

- `ParallelConditionEvaluator._evaluate_safe_conditions_parallel()`：总超时 = `max(n * timeout_per_condition, 5.0)` 秒；等待循环用 `Semaphore.try_wait()` 非阻塞 + `OS.delay_msec(1)` 防忙等（L196-223），超时后记 warning 并返回当前结果（部分未完成的索引保留默认 `false`）。
- `FuseTaskManager.await_task()`：用 `OS.delay_msec(10)` 轮询，超时返回 null。

### 6.6 缓存与配置变更

`BaseCondition` 的线程安全评估结果被缓存（`_thread_safety_computed`），`reset()` 会调用 `reset_thread_safety_cache()` 失效缓存，确保条件配置变更后重新评估。`FuseThreadingConfig` 的 setter 通过 `config_changed` 信号通知监听者，但当前**无运行时监听者**。

---

## 7. 总体评估

### 优点

1. **分级并行策略清晰** — `EvaluationMode` 三档枚举 + `is_thread_safe` 声明机制，把"是否并行"的决定权下放到具体条件子类，符合最小惊讶原则。
2. **隔离严谨** — 上下文快照 + 每线程独立 `ExecutionContext`，从数据层杜绝了并行评估对主线程状态的污染。
3. **防死锁设计** — Semaphore 同步 + 总超时 + `try_wait` 非阻塞循环，避免了工作线程异常拖死主线程。
4. **统一统计锁** — `_stats_mutex` 在串行/并行两条路径上都被使用，防止了"串行不加锁/并行加锁"这种隐蔽竞态。
5. **API 设计对称** — `FuseThreadSafe` 的 dict/array 全套方法、`FuseTaskManager` 的 submit/await/cancel 三件套，接口面完整。
6. **配置即资源** — `FuseThreadingConfig` 作为 `Resource` 可在 Inspector 编辑、序列化，并通过信号通知变更。

### 不足

1. **大量代码处于"未接入"状态** — `FuseTaskManager` / `FuseThreadSafe` / `FuseThreadingConfig` 三个类（约 438 行）在运行时代码中无消费者，仅见于测试和文档。`use_thread_pool_for_saving` / `enable_resource_preload` / `thread_safe_variables` 等开关缺乏实现侧响应。
2. **取消机制不完整** — `cancel_task()` 缺少 Callable 内部主动检查的 API，长任务无法及时响应取消。
3. **两套并行体系割裂** — `core/threading/` 的 WorkerThreadPool 模式与 `ActionRunner` 的信号 await 模式互不复用，概念上易混淆（前者是真线程并行，后者是异步并发）。
4. **Godot Mutex 限制未被绕过** — `FuseThreadSafe` 注释承认无法提供 `try_lock` 语义，需要非阻塞锁的场景仍需调用方自行设计。
5. **上下文快照无回写路径（已声明约束）** — 并行条件评估对变量的修改不回写主上下文（快照隔离是设计，防止污染主线程状态）。**"评估带副作用（修改变量）的条件不应标记 `is_thread_safe`"的约束已在 `_compute_thread_safety()` 默认实现与 ParallelConditionEvaluator 类注释中显式声明**（CODE_ISSUES B16，commit `42cb339`）。条件子类重写 `_compute_thread_safety()` 返回 true 前应确认自身不修改变量。
6. **配置单例懒加载存在轻微竞态** — `FuseThreadingConfig.get_instance()`（L67-70）的 `if _instance == null` 检查未加锁，与 `FuseTaskManager` 的静态自初始化（L10，无竞态）风格不一致；首帧早期跨线程访问理论上可能创建多份实例。

---

**文档维护**: Fuse 开发团队
**最后更新**: 2026-07-07
**版本**: 1.0.0
**参照代码**: `addons/fuse/core/threading/`（4 文件 689 行）、`addons/fuse/core/base/base_condition.gd`、`addons/fuse/core/multi_event_trigger.gd`、`addons/fuse/core/base/action_runner.gd`
