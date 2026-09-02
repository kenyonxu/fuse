# Runtime 实例三件套分析报告


> **分析时点**：2026-07-07（经同日全量文档审计逐篇核对代码；此后实现演进以源码为准，近期已核对的机制性结论见 threading / runtime_instance / preset_nested 等篇）
## 文档概述

本报告对 Fuse v2.0 核心架构——**Runtime 实例三件套**——进行专题分析。三件套由三个相互协作的 `RefCounted` 类组成，共同解决一个核心工程问题：**让同一份 `.tres` Resource 定义可被多个 Trigger 共享，而各自的运行时状态互不污染**。

| 类名 | 源文件 | 行数 | 职责 |
|------|--------|------|------|
| `RuntimeEventInstance` | [runtime_event_instance.gd](../../../core/runtime_event_instance.gd) | 289 行 | 包装 `BaseEvent`，持有事件级运行时状态，转发并过滤 triggered 信号 |
| `RuntimeInstructionInstance` | [runtime_instruction_instance.gd](../../../core/runtime_instruction_instance.gd) | 549 行 | 包装 `BaseInstruction`，持有单条指令的执行状态、暂停/恢复/超时控制 |
| `RuntimeActionRunnerInstance` | [runtime_action_runner_instance.gd](../../../core/runtime_action_runner_instance.gd) | 692 行 | 包装 `ActionRunner`，调度指令序列，管理并行/顺序执行、批量信号、对象池集成 |

**共同基类:** `RefCounted`（不进场景树、可被 GC、轻量）
**注解:** `@tool`（编辑器模式可用）

---

## 1. 类概述和职责

### 1.1 为什么需要三件套

在 v1 架构中，事件状态直接存在 `BaseEvent` 资源实例上。当一份 `.tres` 事件资源被两个 Trigger 同时引用（共享）时：

```
Trigger A ──┐
            ├──→ 同一份 OnArea2DEnter.tres（持有 trigger_count = 5）
Trigger B ──┘
```

两个 Trigger 读写同一份 `trigger_count`，导致状态相互覆盖、冷却计时被对方重置、信号广播到错误的目标。v2.0 引入三件套，将 **"Resource 定义（不可变、可共享、可序列化）"** 与 **"运行时状态（可变、实例私有、不序列化）"** 强制分离：

```
Trigger A ──→ RuntimeEventInstance(OnArea2DEnter.tres, A)  [trigger_count=5]
Trigger B ──→ RuntimeEventInstance(OnArea2DEnter.tres, B)  [trigger_count=2]
                       ↑
            两份独立的 runtime_state Dictionary
            共享同一份不可变的 event_definition
```

Resource 只描述"做什么"，三件套记录"做到哪一步了"。

### 1.2 三件套各自职责

| 类 | 角色 | 持有者 | 持有什么 |
|----|------|--------|----------|
| `RuntimeEventInstance` (REI) | 事件级状态容器 + 信号过滤网 | Trigger | 一个 `BaseEvent` 资源 + 该 Trigger 的事件状态 |
| `RuntimeActionRunnerInstance` (RARI) | 指令序列调度器 | Trigger | 一个 `ActionRunner` 资源 + 执行流程状态 + RII 数组 |
| `RuntimeInstructionInstance` (RII) | 单条指令的执行句柄 | RARI | 一条 `BaseInstruction` + 该次执行的暂停/超时/完成状态 |

层级关系：`Trigger → REI / RARI → RII`。其中 REI 与 RARI 是平级（同属 Trigger 直接持有），RII 由 RARI 在执行指令序列时按需创建/池化获取。

---

## 2. 核心属性

### 2.1 RuntimeEventInstance

| 属性 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `event_definition` | `BaseEvent` | — | 事件定义资源（共享、只读语义） |
| `runtime_state` | `Dictionary` | `{}` | 该 Trigger 私有的事件运行时状态 |
| `owner_trigger` | `Node` | — | 拥有此实例的 Trigger 节点（用于信号过滤） |
| `log_level` | `FuseLogger.LogLevel` | `INFO` | 日志级别 |

**信号:** `triggered(context: Node)` — 转发后的、独立的事件触发信号。

### 2.2 RuntimeInstructionInstance

| 属性 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `instruction` | `BaseInstruction` | — | 指令定义资源 |
| `runtime_state` | `Dictionary` | `{}` | 该次执行的运行时状态（含 timer/elapsed_time/is_paused 等） |
| `execution_context` | `ExecutionContext` | — | 执行上下文 |
| `owner_runner` | `RuntimeActionRunnerInstance` | — | 反向引用，便于指令回写状态 |
| `log_level` | `FuseLogger.LogLevel` | `INFO` | 从指令同步 |
| `execution_timeout` | `float` | `0.0` | 执行超时（0=不限） |
| `_is_executing` / `_is_completed` / `_is_paused` / `_has_error` | `bool` | `false` | 内部执行状态机标志 |
| `_error_message` | `String` | `""` | 错误信息 |
| `_timeout_timer` | `SceneTreeTimer` | `null` | 超时计时器 |
| `_paused_time` / `_pause_start_time` | `float` | `0.0` | 暂停累计时间 |
| `_connected_timer_callbacks` | `Array[Callable]` | `[]` | 已连接的 timer 信号（用于清理） |

**信号（5 个）:** `finished()`, `error_occurred(message: String)`, `paused()`, `resumed()`, `timeout()`。

### 2.3 RuntimeActionRunnerInstance

| 属性 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `action_runner` | `ActionRunner` | — | ActionRunner 定义资源 |
| `runtime_state` | `Dictionary` | `{}` | 序列级执行状态（is_running/current_instruction_index 等） |
| `owner_trigger` | `Node` | — | 拥有此实例的 Trigger |
| `log_level` | `FuseLogger.LogLevel` | `INFO` | 从 ActionRunner 同步 |
| `_instruction_instances` | `Array[RuntimeInstructionInstance]` | `[]` | 当前持有的 RII 列表（用于 cleanup 时归还池） |
| `_instructions_validated` / `_validated_instruction_count` | `bool` / `int` | `false` / `-1` | 验证缓存（Phase 2.5） |
| `_batch_signals` / `_pending_started_instructions` / `_pending_completed_instructions` | `bool` / `Array` | `false` / `[]` | 批量信号模式（Phase 2.5） |
| `_is_running_cached` / `_is_canceling_cached` / `_context_cached` | `bool`/`bool`/`ExecutionContext` | `false`/`false`/`null` | 性能缓存变量（Phase 1），避免热路径字典访问 |
| `use_instruction_pool` | `bool` | `true` | 是否启用对象池 |
| `_shared_instruction_pool`（static） | `RefCounted` | `null` | 全局共享 `InstructionInstancePool` 实例 |

**信号（6 个）:** `execution_completed(total_time: float)`, `execution_failed(error_message: String)`, `execution_canceled(reason: String)`, `instruction_started(instruction)`, `instruction_completed(instruction)`, `all_instructions_completed()`。

### 2.4 三类 runtime_state 默认内容

| 实例 | 初始化处 | 关键键 |
|------|----------|--------|
| REI | `_initialize_runtime_state()` 调用 `event.get_default_runtime_state()` 自声明；`_ensure_base_states()` 兜底 | `initialized`, `trigger_count`, `last_trigger_time` + 各 Event 子类追加项（如 `object_cooldowns`, `entered_bodies`） |
| RII | `_initialize_runtime_state()` 调用 `instruction.get_default_runtime_state()` 自声明；`_ensure_base_states()` 兜底 | `initialized`, `execution_status`(=PENDING) + `timer`, `elapsed_time`, `is_running` |
| RARI | `_initialize_runtime_state()` 硬编码 | `is_running`, `is_canceling`, `cancellation_reason`, `current_context`, `current_instruction_index`, `execution_start_time`, `execution_end_time`, `has_triggered`, `fuse_error` |

---

## 3. 关键方法

### 3.1 RuntimeEventInstance

#### `_init(definition: BaseEvent, trigger: Node)` — 构造

```
执行流程（runtime_event_instance.gd:20-32）:
  1. 保存 event_definition 与 owner_trigger
  2. _initialize_runtime_state()  // 拷贝/初始化 runtime_state
  3. event_definition.triggered.connect(_on_event_triggered)
     // 在构造时就挂上转发回调，是中转过滤网的关键
```

#### `_on_event_triggered(context: Node)` — 信号过滤转发

```
执行流程（runtime_event_instance.gd:104-115）:
  1. 检查 context.get_meta("trigger") 是否等于 owner_trigger
  2. 不等 → 静默 return（不是本实例的事件）
  3. 相等 → triggered.emit(context) 转发给 Trigger
```

这是共享 Event 资源时状态隔离的核心机制：BaseEvent 通过 `_emit_triggered()` 在 context 上写入 "trigger" meta 标识来源，REI 据此过滤，确保信号只送达归属的 Trigger。

#### `start_listening()` / `stop_listening()` — 代理方法

供 MultiEventTrigger 调用：
- `start_listening()` → `event_definition.initialize_with_runtime_instance(owner_trigger, self)`
- `stop_listening()` → `event_definition.terminate(owner_trigger)`

#### 状态读写 API

`get_runtime_state(key)`, `set_runtime_state(key, value)`, `has_runtime_state(key)`, `remove_runtime_state(key)`, `get_all_runtime_states()` (返回副本), `reset_runtime_state()` (清空并重新初始化), `update_trigger_stats()` (累加 trigger_count 并刷新 last_trigger_time)。

#### `cleanup()` — 清理

断开 `event_definition.triggered` 信号连接、清空 runtime_state、置空引用。

### 3.2 RuntimeInstructionInstance

#### `_init(inst, context, runner)` — 构造

同步指令的 `log_level`，调用 `_initialize_runtime_state()`。

#### `execute_sync() -> bool` — 执行入口

返回 `true` 表示同步完成，`false` 表示需要 await 异步。

```
执行流程（runtime_instruction_instance.gd:102-163）:
  1. 重入保护：_is_executing 或 _is_completed 已为 true → 直接 return true
  2. 重置状态机标志
  3. runtime_state["execution_status"] = RUNNING
  4. _start_timeout_timer()  // 若 execution_timeout > 0
  5. 分支:
     a. instruction.has_method("execute_with_runtime_instance"):
        - 连接 instruction.finished → _on_instruction_finished
        - 调用 instruction.execute_with_runtime_instance(self)
        - 若同步完成且未触发信号 → 手动 _complete_execution()
     b. 否则 _execute_legacy_mode()（兼容旧指令）
  6. 返回同步完成标志
```

#### `_complete_execution()` / `_handle_execution_error(msg)` — 终态迁移

含 `_is_completed` 多次触发保护。错误路径将 `execution_status` 置为 `ERROR`，emit `error_occurred` 和 `finished`。

#### `pause()` / `resume()` — 暂停恢复

修改 `_is_paused`、累计 `_paused_time`，并通过指令的 `on_runtime_pause(runtime_instance)` / `on_runtime_resume(runtime_instance)` 钩子通知子类（BaseInstruction 默认空实现）。

#### `cancel()` — 取消

置 `execution_status = CANCELLED`，调用 `_cleanup_runtime_resources()` 清理 timer/信号连接。

#### `_start_timeout_timer()` / `_on_execution_timeout()` — 超时

基于 `SceneTree.create_timer()`。注意 `SceneTreeTimer` 无法主动取消，只能断开信号连接（`_stop_timeout_timer()` 注释明确说明）。

#### 池化支持方法（Phase 2）

- `reinitialize(inst, context, runner)` — 从池取出后重置全部状态并重新 `_initialize_runtime_state()`。
- `reset_for_pool()` — 归还前清理（断开信号、清状态、置空引用、清回调追踪）。
- `register_timer_callback(cb)` / `unregister_timer_callback(cb)` — 追踪外部连接到 timer 的回调，便于清理。

### 3.3 RuntimeActionRunnerInstance

#### `_init(definition, trigger)` — 构造

同步 ActionRunner 的 `log_level`，调用 `_initialize_runtime_state()`。

#### `run(context: ExecutionContext)` — 执行入口

```
执行流程（runtime_action_runner_instance.gd:102-134）:
  1. _is_running_cached 检查 → 已运行则发本地化错误并 return
  2. validate_instructions() → 失败则 emit execution_failed 并 return
  3. 设置缓存变量 _is_running_cached / _is_canceling_cached / _context_cached
  4. 同步到 runtime_state（用于持久化）
  5. context.set_action_runner(self)  // 供条件检查指令使用
  6. _execute_instructions(context)  // 按 execution_mode 分发
```

#### `cancel_execution(reason)` / `set_stop_execution(stop, reason)`

后者为 API 兼容性方法，内部转发到前者。`set_stop_execution(true, reason)` 等价于 `cancel_execution(reason)`。

#### `validate_instructions()` — 带缓存的验证

```
执行流程（runtime_action_runner_instance.gd:174-196）:
  - 缓存命中（_instructions_validated && 数量未变）→ 跳过
  - 否则完整遍历检查，成功后更新缓存
  - invalidate_validation_cache() 在指令数组变化时手动调用
```

#### `_execute_instructions_sequential()` — 顺序执行

按索引迭代：
1. 每轮检查 `_is_running_cached`（缓存变量，热路径性能优化）
2. `_acquire_instruction_instance()` 从池中获取 RII
3. `_emit_instruction_started()`（带批量模式支持）
4. `runtime_instruction.execute_sync()`
5. 同步完成 → 检查错误（`stop_on_error` 控制）→ `_emit_instruction_completed()` → continue
6. 异步 → `await runtime_instruction.finished` → 错误检查

#### `_execute_instructions_parallel()` + `_wait_for_all_parallel_tasks()` — 并行执行

启动所有指令（不 await），然后用 RefCounted 包装的计数器（`_counter.set_meta("remaining", n)`）等待全部完成。计数器用 meta 是为了规避 GDScript 闭包无法修改捕获的基本类型变量。

#### `_acquire_instruction_instance()` / `_cleanup_instruction_instances()` — 池化集成

```
池化模式:
  pool.acquire(instruction, context, self)         // 复用或新建
  pool.release(runtime_instruction)                 // 归还（内部调用 reset_for_pool）
非池化模式:
  RuntimeInstructionInstance.new(...)
  instance.cleanup()
```

#### 批量信号模式（Phase 2.5）

`set_batch_signal_mode(true)` 启用后，`instruction_started/completed` 信号缓存在 `_pending_started/completed_instructions` 中，在 `_complete_execution()` 时由 `_flush_pending_signals()` 统一发射，减少高频触发场景下的 per-instruction 信号开销。MultiEventTrigger 默认开启此模式。

#### `_get_or_create_compiled_cache()` — Phase 3 编译缓存

从 ActionRunner 取共享 `CompiledInstructionSequence`，按需重编译，缓存 `get_description()` 等结果。

#### `cleanup()` — 清理

调用 `cancel_execution()`、`_cleanup_instruction_instances()`（归还所有 RII 到池）、清空 pending 信号、重置验证缓存、清空 runtime_state、置空引用。

---

## 4. 架构关系

### 4.1 整体协作链路

```
                    ┌──────────────────────── Trigger (Node) ────────────────────────┐
                    │                                                                │
                    │  持有并创建：                                                   │
                    │    _runtime_event_instances[i]   → RuntimeEventInstance        │
                    │    _runtime_action_instances[i]  → RuntimeActionRunnerInstance │
                    │                                                                │
                    │  信号连接：                                                     │
                    │    REI.triggered      → Trigger._on_event_fired                │
                    │    RARI.execution_*  → Trigger._on_action_*                    │
                    │                                                                │
                    └────────────────────────────────────────────────────────────────┘
网上游 (Resource 定义，可共享)               下游 (运行时实例，私有)
       │                                              │
       ▼                                              ▼
┌──────────────┐    _emit_triggered         ┌──────────────────────┐
│  BaseEvent   │ ─────triggered─────────→   │ RuntimeEventInstance │
│  (.tres)     │    (设置 trigger meta)     │  - runtime_state     │
└──────────────┘                            │  - owner_trigger     │
                                            │  - 按 meta 过滤转发   │
                                            └──────────┬───────────┘
                                                       │ triggered (已过滤)
                                                       ▼
                                            Trigger._on_event_fired()
                                                       │
                                                       │ 创建 ExecutionContext
                                                       │ 条件检查
                                                       ▼
┌──────────────┐    run(context)            ┌──────────────────────────┐
│ ActionRunner │ ◀──────────────────────   │ RuntimeActionRunnerInst  │
│  (.tres)     │                            │  - runtime_state         │
│  instructions│                            │  - _instruction_instances│
└──────┬───────┘                            │  - 池化/批量/缓存        │
       │                                    └────────────┬─────────────┘
       │ execute_sync                                    │ _acquire_instruction_instance
       ▼                                                 ▼ (池化)
┌─────────────────┐    execute_with_runtime   ┌─────────────────────────┐
│ BaseInstruction │ ◀─────────────────────── │ RuntimeInstructionInst  │
│   (.tres)       │                           │  - runtime_state        │
│  get_default_   │                           │  - 暂停/超时/取消       │
│  runtime_state  │                           │  - finished 信号        │
└─────────────────┘                           └─────────────────────────┘
```

### 4.2 共享场景下的状态隔离

当两个 Trigger 共享同一份 Event 资源时：

```
Trigger A、B 都引用 OnTimer.tres（同一份资源）

Trigger A._ready():
  REI_A = RuntimeEventInstance.new(OnTimer.tres, A)
    - runtime_state = {trigger_count:0, last_trigger_time:0, ...}  ← A 私有
    - OnTimer.tres.triggered.connect(_on_event_triggered)

Trigger B._ready():
  REI_B = RuntimeEventInstance.new(OnTimer.tres, B)
    - runtime_state = {...}  ← B 私有（与 A 互不可见）
    - OnTimer.tres.triggered.connect(_on_event_triggered)
```

`OnTimer.tres.triggered` 信号有 **两个** 订阅者（REI_A 和 REI_B）。当事件触发时，BaseEvent 通过 `_emit_triggered(context, owner_node)` 在 context 上写 `trigger = owner_node` meta，两个 REI 各自检查 meta：

- `REI_A._on_event_triggered`: `context.trigger == A` → 转发
- `REI_B._on_event_triggered`: `context.trigger != B` → 静默丢弃

这样信号精确送达归属的 Trigger，状态字典完全隔离。

### 4.3 与 BaseTrigger 的关系

`BaseTrigger`（[base_trigger.gd:57-60](../../../core/base_trigger.gd)）通过两个抽象方法把三件套的访问权下放给子类：

```gdscript
@abstract func get_runtime_event_instance_at(index: int) -> RuntimeEventInstance
@abstract func get_action_runner_instance_at(index: int) -> RuntimeActionRunnerInstance
```

具体子类的实现：

- **Trigger**（单事件）：持有单个 `_runtime_event_instance` 和 `_runtime_action_runner_instance`，`get_*_at(0)` 直接返回。
- **MultiEventTrigger**（多事件绑定）：持有两个数组 `_runtime_event_instances[]` 和 `_runtime_action_instances[]`，按 index 返回。

`BaseTrigger` 自身的 `_check_cooldown()`、`_clear_cooldown_state()`、`_sync_event_args_to_context()` 等方法直接通过 `get_runtime_event_instance_at()` 读写 REI 的 `runtime_state`（如 `last_trigger_time`、`object_cooldowns`），这正是把状态从 Resource 抽离到 Runtime 实例带来的收益——冷却计数器现在是 per-Trigger 私有的。

---

## 5. 协作模式

### 5.1 完整触发执行链路

以 MultiEventTrigger 中一次完整触发为例（含行号）：

```
[1] Event 子类检测到条件满足
    └─ BaseEvent._emit_triggered(context, owner_node)
       └─ context.set_meta("trigger", owner_node)       # base_event.gd
       └─ triggered.emit(context)

[2] RuntimeEventInstance._on_event_triggered(context)   # runtime_event_instance.gd:104
    └─ if context.get_meta("trigger") != owner_trigger: return
    └─ triggered.emit(context)                          # 转发

[3] MultiEventTrigger._on_event_fired(context, index)   # multi_event_trigger.gd:242
    └─ trigger_once / is_running / 冷却 / 条件 检查
    └─ action_instance.run(execution_context)            # multi_event_trigger.gd:286

[4] RuntimeActionRunnerInstance.run(context)             # runtime_action_runner_instance.gd:102
    └─ validate_instructions()
    └─ _execute_instructions(context)
       └─ _execute_instructions_sequential / _parallel

[5] RARI._execute_instructions_sequential
    └─ for i in instructions:
       ├─ runtime_instruction = _acquire_instruction_instance(...)  # 池化获取 RII
       ├─ _emit_instruction_started(instruction)                   # 批量模式：缓存
       ├─ runtime_instruction.execute_sync()
       │  └─ instruction.execute_with_runtime_instance(self)
       │     └─ 实际工作（修改 runtime_instruction.runtime_state）
       ├─ 同步完成 → _emit_instruction_completed(instruction)
       └─ 异步 → await runtime_instruction.finished

[6] 全部完成 → _complete_execution()
    └─ _flush_pending_signals()       # 批量发射缓存的 started/completed
    └─ execution_completed.emit(total_time)
    └─ all_instructions_completed.emit()

[7] Trigger._on_action_completed() 接收
```

### 5.2 池化协作

`RuntimeActionRunnerInstance` 持有静态共享池（`get_shared_pool()` 首次调用时 `InstructionInstancePool.new(32, 128)`）。所有 RARI 实例共用此池：

```
RARI_A 执行指令序列:
  acquire() → 池空 → RuntimeInstructionInstance.new()  [创建]
  ...
  release(rii) → rii.reset_for_pool() → 放入池         [归还]

RARI_B 稍后执行:
  acquire() → 池非空 → rii.reinitialize(...)            [复用，省去 new 开销]
```

池统计（`get_statistics()`）暴露 `pool_size`、`total_created`、`total_reused`、`peak_usage`、`reuse_ratio`、`efficiency_score`，可用于调优。

### 5.3 生命周期

| 阶段 | Trigger 行为 | 三件套行为 |
|------|--------------|------------|
| **创建** | `_initialize_runtime_instances()` 中 `RuntimeEventInstance.new(event, self)` 与 `RuntimeActionRunnerInstance.new(action_runner, self)` | 构造函数初始化 runtime_state、连接转发信号（仅 REI） |
| **启动** | `_start_all_events()` → `event_instance.start_listening()` | REI 代理到 `event.initialize_with_runtime_instance()` |
| **执行期** | 信号回调 `_on_event_fired` → `action_instance.run()` | RARI 调度 → 池化获取 RII → RII 执行 |
| **重置（池化）** | `_on_pool_reset()` | REI/RARI 的 runtime_state 各自重新初始化 |
| **停止** | `_stop_all_events()` → 设置 `_runtime_instance_ref` → `event.terminate()` | REI 停止监听 |
| **清理** | `_cleanup_runtime_instances()` | REI/RARI 各自 `cleanup()`；RARI 内部把所有 RII 归还池 |

**关键细节（multi_event_trigger.gd:209-216）：** 在调用 `event.terminate()` 之前，MultiEventTrigger 会显式把 `binding.event._runtime_instance_ref = event_instance`，**修复**了多个池化对象共享同一 Event 资源时 terminate 内部读取错误 runtime_state 的 bug。

---

## 6. 自声明状态模式（Self-declaring State Pattern）

三件套采用统一的状态声明约定：

### 6.1 模式规则

1. **Resource 子类**（`BaseEvent` / `BaseInstruction`）重写 `get_default_runtime_state() -> Dictionary`，声明自己需要哪些状态键及默认值。
2. **Runtime 实例** 在构造时调用 `event/instruction.get_default_runtime_state()` 并 `duplicate(true)` 深拷贝，写入自己的 `runtime_state`。
3. **`_ensure_base_states()`** 兜底确保通用基础键存在（如 `initialized`、`trigger_count`、`execution_status`）。
4. **运行时读写** 全部走 `runtime_instance.set_runtime_state(key, value)` / `get_runtime_state(key)`，不再触碰 Resource 自身。

### 6.2 BaseEvent 默认状态（base_event.gd）

```gdscript
func get_default_runtime_state() -> Dictionary:
    return {
        "initialized": true,
        "trigger_count": 0,
        "last_trigger_time": 0.0
    }
```

子类通过 `super.get_default_runtime_state()` 继承并追加。

### 6.3 BaseInstruction 默认状态（base_instruction.gd:1247）

```gdscript
func get_default_runtime_state() -> Dictionary:
    return {
        "initialized": true,
        "execution_status": ExecutionStatus.PENDING,
        "timer": null,
        "elapsed_time": 0.0,
        "is_running": false
    }
```

### 6.4 向后兼容遗留模式

`RuntimeEventInstance._initialize_runtime_state()` 检测 `event.has_method("get_default_runtime_state")`：

- 存在 → 走自声明模式
- 不存在 → 走 `_initialize_runtime_state_legacy()` 的 match 分支（按 event_type 字符串分派，如 `"timer"`、`"input"`、`"area"` 等）

`RuntimeInstructionInstance` 类似：未实现自声明的指令回退到默认 `{timer, elapsed_time, is_running}`。

---

## 7. 信号转发机制

### 7.1 RuntimeEventInstance 的过滤转发

REI 是 BaseEvent 与 Trigger 之间的中转层，目的有二：

1. **隔离信号源**：BaseEvent 是共享 Resource，其 `triggered` 信号被所有 REI 订阅；REI 提供独立的 `triggered` 信号给 Trigger，使每个 Trigger 只接收归属自己的事件。
2. **过滤干扰**：通过 `context.trigger` meta 校验，丢弃非本实例的事件。

```
BaseEvent.triggered ──┬──→ REI_A._on_event_triggered ──→ (meta != A) 丢弃
                      │
                      └──→ REI_B._on_event_triggered ──→ (meta == B) → REI_B.triggered.emit
                                                                │
                                                                ▼
                                                       Trigger_B._on_event_fired
```

### 7.2 RuntimeInstructionInstance 的 finished 信号

RII 的 `finished` 信号在以下情况发射：

- `_complete_execution()` — 正常完成
- `_handle_execution_error()` — 执行错误
- `_on_execution_timeout()` — 超时

RARI 的顺序执行通过 `await runtime_instruction.finished` 等待异步指令；并行执行用计数器追踪全部完成。多次触发保护由 `_is_completed` 标志实现。

### 7.3 RuntimeActionRunnerInstance 的批量信号

| 信号 | 触发处 | 用途 |
|------|--------|------|
| `execution_completed(total_time)` | `_complete_execution()` | 整个序列完成 |
| `execution_failed(error_message)` | 验证失败 / 指令错误（stop_on_error） | 序列失败 |
| `execution_canceled(reason)` | `cancel_execution` 在执行循环中触发的退出 | 取消 |
| `instruction_started(instruction)` | `_emit_instruction_started()` | 单指令开始（可批量） |
| `instruction_completed(instruction)` | `_emit_instruction_completed()` | 单指令完成（可批量） |
| `all_instructions_completed()` | `_complete_execution()` | 与 execution_completed 同时发射 |

批量模式下 `instruction_started/completed` 缓存到 `_pending_*_instructions`，在 `_flush_pending_signals()` 时统一发射，减少高频触发场景下 per-instruction 的信号开销。

---

## 8. 性能优化

三件套是 Fuse 性能优化的主要载体，承载了 Phase 1/2/2.5/3 多轮优化：

| 优化项 | 所属实例 | 说明 |
|--------|----------|------|
| 状态缓存变量（`_is_running_cached` 等） | RARI | Phase 1：热路径避免字典访问，`is_running()` 直接返回缓存 |
| 对象池（`InstructionInstancePool`） | RARI + RII | Phase 2：复用 RII，省去 ~25μs `new()` 开销 |
| 池化生命周期方法（`reinitialize`/`reset_for_pool`） | RII | Phase 2：池化获取/归还的标准接口 |
| 验证缓存（`_instructions_validated`） | RARI | Phase 2.5：指令数未变则跳过验证 |
| 批量信号模式（`_batch_signals`） | RARI | Phase 2.5：高频触发时合并 instruction_started/completed |
| 编译缓存（`CompiledInstructionSequence`） | RARI + ActionRunner | Phase 3：缓存 `get_description()` 等结果 |
| 日志级别前置检查（`should_log_debug`） | RARI / RII | 在热路径中避免无谓的日志方法调用 |
| 静态共享池 | RARI | 所有 RARI 共用一个池，最大化复用率 |

### 潜在性能问题

1. **Dictionary 操作开销**：REI/RII 的 `set/get_runtime_state` 涉及 Dictionary 哈希查找，在高频事件中可能成为瓶颈。
2. **批量信号缓存的内存峰值**：长指令序列下 `_pending_started/completed_instructions` 可能堆积大量 BaseInstruction 引用。
3. **SceneTreeTimer 无法取消**：超时计时器只能断开信号连接，timer 对象本身会自然到期（虽然无副作用）。
4. **共享 Event 资源的多 REI 信号订阅**：N 个 Trigger 共享同一 Event，则 BaseEvent.triggered 有 N 个连接，每次触发都要遍历 N 个回调（虽然大部分会被 meta 过滤丢弃）。

---

## 9. 总体评估

### 优点

1. **彻底解决资源共享的状态污染问题** — 这是 v2.0 的核心设计目标，三件套通过 runtime_state 私有化 + trigger meta 过滤的组合方案彻底解决。
2. **统一的"自声明状态"模式** — Event/Instruction 通过同一个 `get_default_runtime_state()` 接口声明状态，三件套统一消费，约定清晰。
3. **职责分明** — REI 管事件状态/信号过滤，RARI 管序列调度/性能优化，RII 管单条指令执行/暂停/超时，无职责越界。
4. **池化、批量、缓存层层叠加** — 性能优化做得系统且有阶段化（Phase 1/2/2.5/3），可观测（`get_statistics()`、`get_info()`）。
5. **向后兼容遗留代码** — 通过 `has_method` 检测和 legacy 分支，老 Event/Instruction 无需立即迁移即可工作。
6. **生命周期清晰** — 各自有 `cleanup()`、`reset_for_pool()`、`reinitialize()` 等明确的回收接口。

### 不足

1. **三件套无统一基类** — 三个类各自重复实现 `runtime_state`、`get/set_runtime_state`、`_log_*`、`_initialize_runtime_state`、`cleanup` 等逻辑，缺少共享的 `RuntimeInstanceBase` 抽象。
2. **RARI 体量过大（692 行）** — 同时承担调度、池化、批量信号、验证缓存、编译缓存、错误处理，违反单一职责。可考虑拆出 `InstructionScheduler` / `SignalBatcher`。
3. **状态双重表示（缓存变量 + runtime_state）** — `_is_running_cached` 与 `runtime_state["is_running"]` 必须手动同步，存在一致性风险（虽然目前都有同步代码）。
4. **legacy 分支维护负担** — `_initialize_runtime_state_legacy()` 中的 match 分支需要随新事件类型手动维护，与自声明模式并存增加心智负担。
5. **RII 错误路径分散** — `_handle_execution_error` / `_on_execution_timeout` / `cancel` 三条终止路径状态迁移逻辑相近但分散，未来易出现不一致。
6. **超时机制对池化不友好** — 超时触发的 RII 在归还到池时需确保 `_timeout_timer` 已断开（`reset_for_pool` 有处理），但 SceneTreeTimer 自然到期仍会唤醒主循环。

---

**文档维护**: Fuse 开发团队
**最后更新**: 2026-07-07
**版本**: 1.0.0
**分析对象**: RuntimeEventInstance (289 行) / RuntimeInstructionInstance (549 行) / RuntimeActionRunnerInstance (692 行)
