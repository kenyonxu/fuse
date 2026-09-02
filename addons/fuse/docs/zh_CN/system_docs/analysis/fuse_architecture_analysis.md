# Fuse 可视化编程系统架构分析报告


> **分析时点**：2026-07-07（经同日全量文档审计逐篇核对代码；此后实现演进以源码为准，近期已核对的机制性结论见 threading / runtime_instance / preset_nested 等篇）
> 本文档基于 `addons/fuse/core/` 实际代码（2026-07-07 快照）整理。所有 API / 类名 / 文件路径均经核查，无臆造。原 v1.0 主体（描述单层 Resource 直持状态）已废弃，本稿全面重写 §1–10，保留质量较好的 §11 演进章节。

## 概述

Fuse 是为 Godot 4.7 设计的可视化编程插件，提供「事件 → 触发器 → 动作」的事件驱动编程框架。开发者通过编辑器拖拽配置 Resource（事件 / 指令 / 条件 / 触发器），由运行时层（Runtime 实例 + 对象池 + 线程系统）负责实际执行。

核心架构特征（v2.0 起）：
1. **资源定义 + 运行时编排 双层架构**：Resource 只描述「做什么」，运行时由 `RuntimeEventInstance` / `RuntimeInstructionInstance` / `RuntimeActionRunnerInstance` 三件套承担状态
2. **触发器四兄弟**：`BaseTrigger`(@abstract) ← `Trigger` / `MultiEventTrigger`；外加场景级 `Runner`
3. **三层变量作用域**：LOCAL（EC） / SCOPE（`ScopeVariableContainer` 节点链） / GLOBAL（`GlobalVariableAssistant`/`GlobalVariableManager`）
4. **对象池 + 多线程基础设施**：`core/pooling/` 5 类 + `core/threading/` 4 类
5. **全局 Node 基础设施**：`FuseEventBus`（事件总线）、`FuseRuntimeBridge`（运行时变量 TCP 桥），均 Autoload 单例

## 1. 系统整体架构

### 1.1 架构概览

Fuse `core/` 实际目录与职责分层如下（路径均为 `addons/fuse/core/` 相对）：

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  顶层 Node / Autoload 层（场景级）                                          │
│  ┌──────────────────┐ ┌──────────────────┐ ┌──────────────────┐            │
│  │ fuse_event_bus   │ │ fuse_runtime_    │ │ global_variable_ │            │
│  │ .gd (Autoload)   │ │ bridge.gd        │ │ assistant.gd     │            │
│  │ 全局事件总线      │ │ (Autoload)变量桥 │ │ (场景 Node)      │            │
│  └──────────────────┘ └──────────────────┘ └──────────────────┘            │
├─────────────────────────────────────────────────────────────────────────────┤
│  Trigger / Runner 层（场景 Node，编排入口）                                  │
│  ┌──────────────────┐ ┌──────────────────┐ ┌──────────────────┐            │
│  │ base_trigger.gd  │ │ trigger.gd       │ │ multi_event_     │            │
│  │ @abstract Node   │ │ 单事件触发器     │ │ trigger.gd       │            │
│  │ (4 抽象方法)     │ │ extends BaseTrig │ │ 多事件绑定       │            │
│  └──────────────────┘ └──────────────────┘ └──────────────────┘            │
│  ┌──────────────────┐                                                       │
│  │ runner.gd        │  信号 → ActionRunner 自动绑定执行入口                 │
│  │ Node (无 Trigger)│                                                       │
│  └──────────────────┘                                                       │
├─────────────────────────────────────────────────────────────────────────────┤
│  Runtime 实例层（RefCounted，状态隔离）                                      │
│  ┌────────────────────┐ ┌──────────────────────┐ ┌─────────────────────┐   │
│  │ runtime_event_     │ │ runtime_instruction_ │ │ runtime_action_     │   │
│  │ instance.gd        │ │ instance.gd          │ │ runner_instance.gd  │   │
│  │ 事件运行时状态      │ │ 指令超时/暂停/取消   │ │ 指令序列编排         │   │
│  └────────────────────┘ └──────────────────────┘ └─────────────────────┘   │
├─────────────────────────────────────────────────────────────────────────────┤
│  base/ 定义层（Resource / RefCounted 抽象基类）                              │
│  ┌────────────┐ ┌────────────┐ ┌────────────┐ ┌────────────┐ ┌───────────┐ │
│  │base_event  │ │base_       │ │base_       │ │base_       │ │execution_ │ │
│  │.gd         │ │instruction │ │condition   │ │variable    │ │context.gd │ │
│  │            │ │.gd         │ │.gd         │ │.gd         │ │(门面)     │ │
│  └────────────┘ └────────────┘ └────────────┘ └────────────┘ └───────────┘ │
│  ┌────────────────────┐ ┌────────────────────┐ ┌──────────────────────────┐│
│  │action_runner.gd    │ │variable_context.gd │ │execution_diagnostics.gd  ││
│  │ Resource 指令序列  │ │ EC 变量子系统      │ │ EC 诊断子系统            ││
│  └────────────────────┘ └────────────────────┘ └──────────────────────────┘│
│  ┌──────────────────────────┐ ┌──────────────────────────────────────────┐ │
│  │scope_variable_container │ │variable_container.gd (@deprecated)        │ │
│  │.gd (Node 作用域容器)    │ │                                          │ │
│  └──────────────────────────┘ └──────────────────────────────────────────┘ │
├─────────────────────────────────────────────────────────────────────────────┤
│  专项子系统                                                                  │
│  ┌──────────── pooling/ (5 类) ───────────┐ ┌── threading/ (4 类) ────────┐│
│  │ fuse_object_pool  场景对象池            │ │ fuse_task_manager 任务管理 ││
│  │ fuse_pool_item    池项包装             │ │ parallel_condition_        ││
│  │ fuse_pool_manager 全局池管理(单例)     │ │   evaluator 并行条件评估   ││
│  │ fuse_recycle_timer 回收定时器(Node)    │ │ fuse_thread_safe 工具      ││
│  │ instruction_instance_pool              │ │ fuse_threading_config 配置 ││
│  │   RuntimeInstructionInstance 池         │ │                            ││
│  └────────────────────────────────────────┘ └────────────────────────────┘│
│  ┌── execution/ ──────────┐ ┌── serialization/ ──────┐ ┌── audio/ ───────┐ │
│  │ compiled_instruction_ │ │ instruction_serializer │ │ fuse_audio_     │ │
│  │   sequence.gd 编译缓存│ │   .gd 序列化器         │ │   container.gd  │ │
│  └───────────────────────┘ └────────────────────────┘ └─────────────────┘ │
│  ┌── logging/ ───────────┐ ┌── resources/ ──────────┐ ┌── utils/ ────────┐ │
│  │ fuse_logger.gd        │ │ fuse_preset.gd         │ │ expression_      │ │
│  │ fuse_error.gd         │ │ fuse_icon_library.gd   │ │   helper.gd      │ │
│  └───────────────────────┘ └────────────────────────┘ │ fuse_icon_       │ │
│  ┌── 顶层 RefCounted ────┐ ┌── 顶层单例/Service ────┐ │   manager.gd     │ │
│  │ global_variable_      │ │ global_variable_       │ │ variable_        │ │
│  │   resource.gd         │ │   manager.gd(单例)     │ │   operations.gd  │ │
│  │ global_variable_      │ │ scope_variable_        │ │ variable_scope_  │ │
│  │   service.gd          │ │   manager.gd(Node 单例)│ │   utils.gd       │ │
│  └───────────────────────┘ └────────────────────────┘ └─────────────────┘ │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 1.2 核心设计原则

1. **事件驱动架构**：基于「事件 → 触发器 → 动作」范式
2. **资源 + 运行时双层分离**：Resource 只描述配置，运行时状态由独立 RefCounted 实例承载，避免多触发器共享 Resource 时状态污染
3. **类型安全**：GDScript 2.0 强类型注解，运行时验证
4. **三层作用域变量**：LOCAL / SCOPE / GLOBAL 显式分层
5. **统一基础设施**：`FuseLogger` + `FuseError` + `FuseLocalization` 三件套贯穿全栈
6. **可扩展性**：插件化抽象基类（`@abstract` 方法），子类实现具体行为

## 2. 核心组件分析

### 2.1 BaseInstruction - 指令基类（base/base_instruction.gd）

`BaseInstruction extends Resource`，所有指令的抽象基类。关键点：

- **`execute()` 为 `@abstract`**（base_instruction.gd:379）——子类必须实现，无默认实现。早期文档称「默认实现直接调 `_on_execution_completed()`」为误。
- **三种执行模式**：`ExecutionMode = { AUTO_DETECT, FORCE_ASYNC, FORCE_SYNC }`，`AUTO_DETECT` 通过 `_detect_sync_capability()` 静态分析判定
- **生命周期状态机**：`ExecutionStatus = { PENDING, RUNNING, COMPLETED, CANCELLED, ERROR }`
- **超时机制**：`set_timeout()` / `_setup_timeout_timer()` 使用 `SceneTreeTimer`，避免长指令阻塞
- **集成 RuntimeInstructionInstance**：运行期状态（超时/暂停/取消）由 `RuntimeInstructionInstance` 承担，BaseInstruction 自身保持 Resource 的纯数据/配置属性
- **静态分析钩子**：`_get_variable_accesses()` 等方法供 `InstructionAnalyzer.analyze_problems` 调用
- **i18n 资源名**：通过 `FuseLocalization` 同步本地化的指令名/描述
- **图标四级回退**：metadata icon → category icon → 类型默认 → builtin 占位
- **统一日志/错误**：`_log_debug/_log_info/_log_warning/_log_error` + `_log_*_localized` 全部委托 `FuseLogger`；`_create_fuse_error()` / `_create_fuse_error_localized()` 创建 `FuseError` 实例存入 `_fuse_error`

### 2.2 ExecutionContext - 执行上下文（base/execution_context.gd）

`ExecutionContext extends RefCounted`。**v2.0 已重构为门面（Facade）**，原状态拆分到两个子系统：

| 子系统 | 类 | 承担职责 |
|--------|-----|---------|
| 变量子系统 | `VariableContext extends RefCounted` | 局部/作用域/全局变量 CRUD、变量名 LRU 缓存、索引访问优化、循环控制标志（break/continue/nested stack） |
| 诊断子系统 | `ExecutionDiagnostics extends RefCounted` | 执行状态机、执行历史、状态变化监听器、进度跟踪、状态统计、依赖关系图 |

EC 字段（execution_context.gd）：

```gdscript
var target: Node = null              ## 目标节点（指令操作对象）
var trigger = null                   ## 触发器节点
var owner: Node = null               ## 拥有者节点
var tree: SceneTree = null
var local_variables: Dictionary = {} ## 兼容引用，指向 _variable_context.local_variables
var global_variables = null          ## 兼容引用
var _global_variable_assistant: GlobalVariableAssistant = null
var _variable_context: VariableContext = null
var _diagnostics: ExecutionDiagnostics = null
var custom_data: Dictionary = {}
var execution_start_time: float
var execution_id: String
var log_level: FuseLogger.LogLevel
var action_runner = null
var delta_time: float
var _target_weakref: WeakRef
var _trigger_weakref: WeakRef
var _fuse_error: FuseError
```

EC 公共 API（如 `set_variable` / `get_variable` / `set_break_loop` / `precompile_variable_access` / `get_all_local_variables_snapshot` 等）均委托 `_variable_context` 或 `_diagnostics` 实现。早期文档描述的 `_execution_state` / `_execution_history` / `_break_loop_flag` 等字段已迁移到这两个子系统。

### 2.3 ActionRunner - 资源定义 + Runtime 编排双层（base/action_runner.gd）

ActionRunner 系统采用「Resource 定义 + RefCounted 运行时编排」双层：

**资源层 — `ActionRunner extends Resource`（base/action_runner.gd）**：
- `@export var instructions: Array[BaseInstruction]` —— 指令序列（数据载体）
- `@export var execution_mode: ExecutionMode = SEQUENTIAL` —— `SEQUENTIAL` / `PARALLEL`
- `@export var stop_on_error: bool = true`
- `@export var enable_instruction_timeout: bool` / `instruction_timeout: float`
- 静态 `ExecutionMode` 枚举
- `is_running` / `is_canceling` / `cancellation_reason` / `current_context` —— 兼容字段
- 内置 `_SignalAggregator`（不同于 Runtime 层的 `_ParallelSignalAggregator`）
- 预加载 `CompiledInstructionSequenceClass`（编译缓存）

**运行时层 — `RuntimeActionRunnerInstance extends RefCounted`（runtime_action_runner_instance.gd）**：

```gdscript
class_name RuntimeActionRunnerInstance extends RefCounted

signal execution_completed(total_time: float)
signal execution_failed(error_message: String)
signal execution_canceled(reason: String)
signal instruction_started(instruction: BaseInstruction)
signal instruction_completed(instruction: BaseInstruction)
signal all_instructions_completed()

var action_runner: ActionRunner
var runtime_state: Dictionary = {}
var owner_trigger: Node
var _instruction_instances: Array[RuntimeInstructionInstance]
```

关键性能优化（Phase 1/2/2.5）：

| 优化 | 实现 |
|------|------|
| 状态缓存变量 | `_is_running_cached` / `_is_canceling_cached` / `_context_cached` 替代字典访问 |
| 验证缓存 | `_instructions_validated` / `_validated_instruction_count` 避免每帧重验 |
| 信号批量模式 | `set_batch_signal_mode(true)` 缓冲 `instruction_started/completed` 信号到执行末批量发射（Trigger 默认启用） |
| 共享对象池 | `static var _shared_instruction_pool` → `InstructionInstancePool.new(32, 128)`，所有实例共享 |
| 编译缓存 | 集成 `CompiledInstructionSequence`（core/execution/） |

执行流程：`run(context)` → 验证 → 通过 `InstructionInstancePool.acquire()` 获取 `RuntimeInstructionInstance` → `_execute_instruction()` → 同步/异步分支 → `_SignalAggregator`/`_ParallelSignalAggregator` 收尾。

### 2.4 Trigger - 触发器四兄弟 + 双 Runtime 实例

Trigger 体系是事件与动作之间的桥梁，由四个类组成：

| 类 | 继承 | 路径 | 角色 |
|----|------|------|------|
| `BaseTrigger` | `@abstract extends Node` | `core/base_trigger.gd` | 抽象基类，5 个抽象方法 + 冷却检查 + 信号管理 + 引擎回调转发 |
| `Trigger` | `extends BaseTrigger` | `core/trigger.gd` | 单事件触发器，最常用 |
| `MultiEventTrigger` | `extends BaseTrigger` | `core/multi_event_trigger.gd` | 多事件绑定（`Array[EventBinding]`），合并节点 |
| `Runner` | `extends Node`（不继承 BaseTrigger） | `core/runner.gd` | 信号自动绑定执行入口（无事件层） |

> ⚠️ 路径修正：`BaseTrigger` 在 `core/base_trigger.gd`（不是 `core/base/base_trigger.gd`）。

#### 2.4.1 BaseTrigger 抽象方法（base_trigger.gd:51-63）

```gdscript
@abstract func get_event_count() -> int
@abstract func get_event_at(index: int) -> BaseEvent
@abstract func get_runtime_event_instance_at(index: int) -> RuntimeEventInstance
@abstract func get_action_runner_instance_at(index: int) -> RuntimeActionRunnerInstance
@abstract func _on_pool_reset() -> void
```

BaseTrigger 提供的公共能力：
- **`CooldownMode` 枚举**：`NONE` / `GLOBAL_COOLDOWN` / `PER_OBJECT_COOLDOWN`
- **冷却检查**：`_check_cooldown(index, context, cooldown_mode, cooldown_time)`，状态写入 `RuntimeEventInstance.runtime_state`
- **执行上下文创建**：`_create_execution_context(target, index)` 同步事件参数到 EC
- **ActionRunner 信号管理**：`_connect_action_runner_signals_at` / `_disconnect_action_runner_signals_at`（统一连接 `execution_completed/failed/canceled`）
- **引擎回调转发**：`_process` / `_physics_process` / `_unhandled_input` / `_notification` 转发到所有 Event 的 `on_process` / `on_physics_process` / `handle_input` 等
- **池化支持**：`pool_mode: bool` + `pool_reset()` 钩子

#### 2.4.2 Trigger - 单事件触发器（trigger.gd）

```gdscript
@export var event_definition: BaseEvent
@export var action_runner: ActionRunner
@export var trigger_once: bool = false
@export var cooldown_mode: CooldownMode
@export var cooldown_time: float

var _runtime_event_instance: RuntimeEventInstance = null
var _runtime_action_runner_instance: RuntimeActionRunnerInstance = null
```

**双 Runtime 实例**：每个 Trigger 持有 `_runtime_event_instance` + `_runtime_action_runner_instance`。生命周期：

1. `_on_trigger_ready()`：创建 `RuntimeEventInstance.new(event_definition, self)` → `event_definition.initialize_with_runtime_instance(self, instance)` → 创建 `RuntimeActionRunnerInstance.new(action_runner, self)` → `set_batch_signal_mode(true)` → 连接信号
2. `_on_event_fired(context)`：冷却检查 → `_create_execution_context(context, 0)` → `_runtime_action_runner_instance.run(ec)`
3. `_on_trigger_exit_tree()`：终止事件、断开信号、`cleanup()` 两个 Runtime 实例

#### 2.4.3 MultiEventTrigger - 多事件触发器（multi_event_trigger.gd）

```gdscript
@export var event_bindings: Array[EventBinding]  ## 每个 EventBinding = (event, action_runner, conditions, ...)

signal event_completed_with_index(binding_index: int, context: Dictionary)
signal event_stopped_with_index(binding_index: int, reason: String, context: Dictionary)
```

每个 binding 独立维护一对 `RuntimeEventInstance` + `RuntimeActionRunnerInstance`，并支持 `use_conditions`（在 `EventBinding` 中控制 conditions 字段的动态可见性）。`trigger_binding(index, context=null)` 手动触发指定 binding。`_initialize_runtime_instances()` 内部先调 `_cleanup_runtime_instances()`。

支持并行条件评估：`check_conditions_parallel(binding_index, context)` 委托 `ParallelConditionEvaluator`。

#### 2.4.4 Runner - 信号自动绑定执行入口（runner.gd）

`Runner extends Node`（非 BaseTrigger），用于「外部信号 → ActionRunner」的直接执行（无需 Event 层）：

```gdscript
@export_storage var action_runner: ActionRunner
@export_storage var target_node: NodePath
@export_storage var signal_name: String
@export_storage var log_level: FuseLogger.LogLevel
var current_execution_context: ExecutionContext  ## 运行时设置（变量监视器读取）
var _runtime_instance: RuntimeActionRunnerInstance
```

特性：
- **编辑器集成**：`@tool`，`_editor_refresh_signals()` 通过 `SignalManager.get_node_signals(target)` 收集可用信号 → `signal_name` 下拉框；图标 `ViewportSpeed.png`
- **运行时信号发现**：`SignalManager.has_signal_named(node, name)` 校验（不是早期文档的 `get_signal_list()`）
- **`@export_storage` 语义**：字段持久化到场景文件，避免 Resource 引用循环
- 公共 API：`run(context_node=null)` / `cancel(reason)` / `stop()` / `is_running()` / `is_canceling()` / `wait_completed()` / `get_execution_status()`

## 3. 条件系统（base/base_condition.gd）

`BaseCondition extends Resource`。关键特性：

- **`_evaluate_condition()` 为 `@abstract`**：子类必须实现具体评估逻辑
- **`is_thread_safe: bool` + `_compute_thread_safety()`**：声明线程安全性，配合 `ParallelConditionEvaluator` 决定是否并行
- **缓存机制**：`enable_cache` / `cache_duration` + `_cached_result` / `_cache_timestamp` / `_cache_context_hash`，`_is_cache_valid()` 同时检查时间过期与上下文哈希变化
- **依赖关系图**：`get_dependencies()` / `_compute_dependencies()` / `get_affected_variables()` / `get_dependency_graph()`
- **批量操作**：`check_batch()` / `optimized_check_batch()`
- **性能监控**：`get_performance_metrics()` / `get_cache_info()`
- **统一日志/错误**：同 BaseInstruction，集成 `FuseError` + `FuseLogger`
- ⚠️ **无任何 signal**：早期文档称「条件满足/失败信号」为误，`on_condition_met` / `on_condition_failed` 是普通方法

## 4. 事件驱动架构

### 4.1 BaseEvent - 事件基类（base/base_event.gd）

```gdscript
signal triggered(context: Node)
```

BaseEvent 关键接口：
- `initialize(owner_node: Node)` / `terminate(owner_node: Node)`
- **`initialize_with_runtime_instance(trigger, runtime_instance)`**：v2.0 接口，将 `_runtime_instance_ref` 绑定到 Event，所有状态访问通过 `get_runtime_state()` 转发到对应 `RuntimeEventInstance`
- `handle_input(event)` / `on_process(delta, instance)` / `on_physics_process(delta, instance)` —— 引擎回调（由 BaseTrigger 转发）
- `get_event_type()` / `get_description()` / `get_event_icon()` / `get_detailed_info()` / `_get_node_display_name()`

### 4.2 信号流向（v2.0 三层中转）

```
Event 子类内部触发
  → event_definition.triggered.emit(context)
    → RuntimeEventInstance._on_event_triggered(context)
      → runtime_event_instance.triggered.emit(context)   # 实例级独立信号
        → Trigger._on_event_fired(context)
          → _check_cooldown → _create_execution_context
            → _runtime_action_runner_instance.run(ec)
```

`RuntimeEventInstance` 在 `_init()` 中连接 `event_definition.triggered` 并转发，确保多触发器共享同一 Event Resource 时各自收到独立信号（按 trigger meta 过滤）。

### 4.3 具体事件示例

`OnInputKey`：`@export_enum("按下:0", "释放:1", "持续按下:2") var key_event_type`，通过 `_validate_property()` 实现 `held_initial_delay` / `held_repeat_interval` 仅在「持续按下」模式下可编辑。

## 5. 变量系统（7 类，三层作用域）

变量系统是 Fuse v2.0 重构最深的子系统。完整类清单：

| # | 类 | 类型 | 路径 | 职责 |
|---|----|------|------|------|
| 1 | `BaseVariable` | `extends Resource` | `base/base_variable.gd` | 变量基类，定义 `VariableScope` 枚举与值变化信号 |
| 2 | `VariableContext` | `extends RefCounted` | `base/variable_context.gd` | EC 变量子系统，三层作用域 CRUD + LRU 缓存 + 循环标志 |
| 3 | `VariableContainer` | `extends Resource` **@deprecated** | `base/variable_container.gd` | 旧统一存储，已废弃（迁移到 EC.local_variables + GlobalVariableAssistant） |
| 4 | `ScopeVariableContainer` | `extends Node` | `base/scope_variable_container.gd` | 作用域容器，挂载到节点，为子树提供 SCOPE 变量 |
| 5 | `GlobalVariableManager` | `extends RefCounted` | `core/global_variable_manager.gd` | **非 Node 单例**，`static var _instance`，Mutex 线程安全，变量 CRUD + 资源持久化 |
| 6 | `GlobalVariableAssistant` | `extends Node` | `core/global_variable_assistant.gd` | 场景代理节点，桥接 Manager 与场景树，自动保存延迟计时器 |
| 7 | `GlobalVariableResource` | `extends Resource` | `core/global_variable_resource.gd` | 全局变量数据载体，标准化 + 深拷贝序列化 |
| - | `GlobalVariableService` | `extends RefCounted` | `core/global_variable_service.gd` | 纯逻辑服务层，无场景时替代 Assistant 兜底 |
| - | `ScopeVariableManager` | `extends Node` | `core/scope_variable_manager.gd` | 单例 Node，注册表管理所有 `ScopeVariableContainer` |

### 5.1 VariableScope 三层作用域（base_variable.gd:41-45）

```gdscript
enum VariableScope {
    LOCAL = 0,      ## 局部变量（ExecutionContext 生命周期）
    SCOPE = 1,      ## 作用域变量（ScopeVariableContainer 生命周期）
    GLOBAL = 2      ## 全局变量（GlobalVariableAssistant 生命周期）
}
```

> ⚠️ 修正：早期文档称仅有 `LOCAL/GLOBAL` 两值为误。

### 5.2 BaseVariable 关键点（base/base_variable.gd）

- `value: Variant` setter 直接赋值（**无类型校验**，早期文档称 `_validate_value()` 为臆造），触发 `value_changed(old, new)` 信号
- `variable_name` / `description` / `scope` / `log_level`
- 工厂方法 `static func create(name, val, scope=LOCAL) -> BaseVariable`
- `set_value(new_value) -> bool` / `get_value() -> Variant` / `reset()` / `get_type_name() -> String`
- ⚠️ 早期文档称「类型验证不严」是基于不存在的 `_validate_value()`；实际语义为 Variant 自由赋值，类型安全由消费方（如 set_variable 指令）按需校验

### 5.3 VariableContext - 三层分发（base/variable_context.gd:59-69）

```gdscript
func set_variable(name: String, value: Variant, scope: String = "local") -> bool:
    match scope:
        "scope":  return _set_scope_variable(name, value)
        "global": return _set_global_variable(name, value)
        "local":  return _set_local_variable(name, value)
```

- **LOCAL**：直接写入 `local_variables` Dictionary
- **SCOPE**：通过 `ScopeVariableManager.find_nearest_scope(node)` 找到容器后写入
- **GLOBAL**：通过 `_global_variable_assistant` 或 `global_variables` 引用委托
- **fallback 链**：`get_variable("local")` 找不到时回退查询 global

### 5.4 GlobalVariableManager - RefCounted 单例（global_variable_manager.gd）

```gdscript
class_name GlobalVariableManager extends RefCounted
static var _instance: GlobalVariableManager = GlobalVariableManager.new()  ## 静态初始化，避免竞态

signal variable_added(name, variable)
signal variable_removed(name)
signal variable_changed(name, old_value, new_value)
```

> ⚠️ 修正：早期文档称「单例 Node」为误，实为 `extends RefCounted`，静态 `_instance` 通过 `get_instance()` 访问。所有 CRUD 操作受 `_mutex: Mutex` 保护。

API：`add_variable` / `get_variable` / `has_variable` / `remove_variable` / `save_to_resource` / `load_from_resource` / `save_persistent_to_resource` / `get_all_variables_snapshot`。

### 5.5 变量操作工具

- **`VariableOperations`**（utils/variable_operations.gd）：静态方法 `get_variable()` / `set_variable()` / `check_variable()`，屏蔽 LOCAL/SCOPE/GLOBAL 访问差异
- **`VariableScopeUtils`**（utils/variable_scope_utils.gd）：枚举/字符串互转、`ScopeSource` 处理、`validate_scope_source_property()` 用于 `_validate_property()` 回调

## 6. 编辑器工具系统

### 6.1 指令注册表与元数据

每个指令通过静态方法提供元数据（`_get_instruction_metadata()`），由编辑器侧注册表收集（位于 `editor/`，不在本文范围）。

### 6.2 条件化属性显示

`_validate_property(property: Dictionary)` 是 Godot 标准钩子，用于动态控制属性可见性。典型用法（OnInputKey）：

```gdscript
func _validate_property(property: Dictionary) -> void:
    if key_event_type != 2:  # 非持续按下
        if property.name == "held_initial_delay" or property.name == "held_repeat_interval":
            property.usage = PROPERTY_USAGE_READ_ONLY
```

`VariableScopeUtils.validate_scope_source_property()` 亦是此模式。

## 7. 序列化和持久化（serialization/instruction_serializer.gd）

`InstructionSerializer` 提供指令序列化/反序列化：

- **静态属性缓存** `_property_cache: Dictionary`：按类型缓存 `PROPERTY_USAGE_STORAGE` 属性列表，避免每次反射
- **`serialize_instruction(instruction) -> Dictionary`**：使用缓存属性列表序列化
- **`deserialize_instruction(data) -> Dictionary`**：按 `type` 字段 `_create_instruction()` 后逐属性 `set`

全局变量持久化由 `GlobalVariableManager.save_to_resource()` / `GlobalVariableResource._to_dict()` / `from_dict()` 承担。

## 8. 日志系统与错误处理（logging/）

### 8.1 FuseLogger（logging/fuse_logger.gd）

统一分级日志：

```gdscript
enum LogLevel { NONE, INFO, WARNING, ERROR, DEBUG }
```

- **双层级别控制**：`component_level`（组件配置）+ `message_level`（单条消息），仅 `message_level <= component_level` 才输出
- **富文本**：`print_rich` 输出带颜色（红=error/黄=warning/绿=info/青=debug）
- **本地化**：`log_debug_localized()` / `log_info_localized()` 等，支持翻译键 + 参数
- **性能**：缓存 `FuseLocalization` 类引用避免重复 `load()`

### 8.2 FuseError（logging/fuse_error.gd）

```gdscript
enum ErrorType { VALIDATION_ERROR, EXECUTION_ERROR, CONFIGURATION_ERROR, RUNTIME_ERROR, TIMEOUT_ERROR }
```

- **`context: Dictionary`**：附加任意上下文
- **自动日志**：构造时 `_log_to_fuse_logger()` 写入日志
- **本地化**：`create_*_localized()` 系列静态方法

所有核心组件（BaseInstruction / BaseCondition / BaseTrigger / RuntimeEventInstance / RuntimeActionRunnerInstance 等）均集成 `_fuse_error` 实例变量与 `_create_fuse_error()` / `_create_fuse_error_localized()` 方法。

## 9. 性能优化与内存管理

### 9.1 智能缓存

| 缓存 | 位置 | 说明 |
|------|------|------|
| 属性缓存 | `InstructionSerializer._property_cache` | 序列化属性列表反射缓存 |
| 变量名 LRU 缓存 | `VariableContext._variable_name_cache` | StringName 缓存，`_cache_max_size=1000` |
| 索引访问 | `VariableContext._variable_index_map` + `_variable_array` | `precompile_variable_access()` 预编译 |
| 条件结果缓存 | `BaseCondition._cached_result` + 上下文哈希 | 时间过期 + 上下文变化双校验 |
| 验证缓存 | `RuntimeActionRunnerInstance._instructions_validated` | 避免每帧重验指令数组 |
| 编译缓存 | `CompiledInstructionSequence._descriptions` | 预缓存描述字符串，指令数变化时失效 |
| 反射缓存 | `ReflectionCache`（由 FuseEventBus 自动清理） | 节点删除时 `clear_node()` |

### 9.2 内存优化

- **WeakRef**：EC 的 `_target_weakref` / `_trigger_weakref` 避免节点循环引用
- **Runtime 实例隔离**：RefCounted 轻量生命周期，避免 Resource 复制
- **对象池复用**：见 §11

### 9.3 同步/异步执行优化

```gdscript
func can_execute_sync() -> bool:
    match execution_mode:
        ExecutionMode.FORCE_SYNC:  return true
        ExecutionMode.FORCE_ASYNC: return false
        ExecutionMode.AUTO_DETECT: return _detect_sync_capability()
```

`RuntimeActionRunnerInstance._execute_instruction()` 对同步指令走快速路径，避免 await 开销。

## 10. 设计模式分析

### 10.1 模板方法模式
BaseInstruction / BaseCondition / BaseTrigger / BaseEvent 通过 `@abstract` 方法定义骨架，子类填具体逻辑。

### 10.2 策略模式
- `ActionRunner.ExecutionMode = { SEQUENTIAL, PARALLEL }`
- `BaseInstruction.ExecutionMode = { AUTO_DETECT, FORCE_ASYNC, FORCE_SYNC }`
- `ParallelConditionEvaluator.EvaluationMode = { SEQUENTIAL, PARALLEL_SAFE, PARALLEL_ALL }`
- `BaseTrigger.CooldownMode = { NONE, GLOBAL_COOLDOWN, PER_OBJECT_COOLDOWN }`

### 10.3 观察者模式
- BaseEvent `signal triggered(context)`
- RuntimeEventInstance / RuntimeActionRunnerInstance 各自独立信号
- BaseVariable `signal value_changed(old, new)`
- GlobalVariableManager `signal variable_added/removed/changed`
- FuseEventBus 全局事件总线（见 §11.8）

### 10.4 工厂模式
`BaseVariable.create(name, val, scope)`、`RuntimeActionRunnerInstance.get_shared_pool()`。

### 10.5 单例模式（RefCounted 静态 _instance）
- `GlobalVariableManager._instance`（RefCounted）
- `FuseTaskManager._instance`（RefCounted）
- `FusePoolManager._instance`（RefCounted）
- `RuntimeActionRunnerInstance._shared_instruction_pool`（RefCounted）

> 注：`GlobalVariableManager` 不是 Node 单例，是 RefCounted 静态实例。

### 10.6 门面模式（Facade）
`ExecutionContext` 门面委托 `VariableContext` + `ExecutionDiagnostics`。

### 10.7 自声明状态模式
`BaseEvent.get_default_runtime_state()` 让 Event 自描述运行时状态，替代硬编码 match 分支（`RuntimeEventInstance._initialize_runtime_state()` 优先检查此方法）。

### 10.8 池化模式
`InstructionInstancePool` / `FuseObjectPool` / `FusePoolManager` 复用实例。

## 10.x 总结

Fuse 是一个采用「资源 + 运行时双层」架构的可视化编程系统。其核心工程价值在于：
1. **状态隔离彻底**：Resource 只描述，Runtime 实例承载状态，多触发器共享同一 Resource 无污染
2. **三层作用域清晰**：LOCAL/SCOPE/GLOBAL 显式分层，配合 `ScopeVariableContainer` 节点链实现层次化作用域
3. **统一基础设施**：`FuseLogger` + `FuseError` + `FuseLocalization` 全栈一致
4. **性能工程化**：对象池、编译缓存、状态缓存变量、信号批量模式层层优化
5. **线程安全基础设施完备**：`FuseTaskManager` + `ParallelConditionEvaluator` + `FuseThreadSafe`

---

## 11. 架构演进：2026 年新增系统

本章节记录 Fuse 系统在 2026 年初引入的重大架构扩展。这些新增系统在原有事件驱动、指令执行和条件评估的核心架构之上，引入了运行时实例化、统一变量体系、多线程支持、表达式系统和增强的编辑器工具链，进一步完善了系统的工程化水平。

> 注：§1–10 已回填这些事实到主体描述；本章节作为「演进时间线 + 详细说明」保留。

### 11.1 运行时实例架构（Runtime Instance Pattern）

运行时实例架构是 2026 年最重要的架构演进之一，其核心思想是将**定义资源**（Resource）与**运行时状态**（Runtime State）彻底分离，避免多个触发器共享同一资源时的状态污染问题。

#### 11.1.1 三层运行时实例体系

系统为事件、指令和动作执行器分别提供了对应的运行时实例类，均继承自 `RefCounted` 以实现轻量级生命周期管理：

| 定义资源 | 运行时实例 | 路径 | 核心职责 |
|---------|-----------|------|---------|
| `BaseEvent` | `RuntimeEventInstance` | `core/runtime_event_instance.gd` | 事件运行时状态存储，独立信号转发 |
| `BaseInstruction` | `RuntimeInstructionInstance` | `core/runtime_instruction_instance.gd` | 指令运行时实例，超时/暂停/取消支持 |
| `ActionRunner` | `RuntimeActionRunnerInstance` | `core/runtime_action_runner_instance.gd` | ActionRunner 运行时实例，指令序列编排 |

#### 11.1.2 自声明状态模式（Self-Declared State Pattern）

新架构引入了 `get_default_runtime_state()` 方法，允许事件和指令通过自声明的方式定义其运行时状态，替代了旧的硬编码 match 分支模式：

```gdscript
# 新架构：Event 自声明状态（推荐）
func get_default_runtime_state() -> Dictionary:
    return {
        "timer": null,
        "elapsed_time": 0.0,
        "is_running": false,
        "duration": 1.0
    }
```

`RuntimeEventInstance._initialize_runtime_state()` 优先检查此方法，回退到 `_initialize_runtime_state_legacy()` 以保证向后兼容。

#### 11.1.3 RuntimeInstructionInstance 的关键特性

- **信号多次触发保护**：通过 `_is_completed` 标志防止 `finished` 信号多次触发
- **执行超时机制**：通过 `execution_timeout` 配置超时时间，内部使用 `SceneTreeTimer`
- **暂停/恢复功能**：支持 `pause()` / `resume()` 方法，并通过 `on_runtime_pause` / `on_runtime_resume` 回调通知指令
- **对象池化支持**：提供 `reinitialize()` 和 `reset_for_pool()` 方法，支持实例复用

#### 11.1.4 RuntimeActionRunnerInstance 的性能优化

- **状态缓存变量**：使用 `_is_running_cached` / `_is_canceling_cached` 直接变量替代字典访问，避免热路径中的字典开销
- **信号批量模式**：`set_batch_signal_mode(true)` 可将 `instruction_started` / `instruction_completed` 信号缓存到执行结束后批量发射，减少高频场景的信号开销
- **验证缓存**：`_instructions_validated` 标志避免每帧重复验证相同的指令数组
- **编译缓存集成**：通过 `CompiledInstructionSequence`（`core/execution/`）缓存指令描述等编译结果
- **共享对象池**：`InstructionInstancePool` 静态池化 `RuntimeInstructionInstance`，所有实例共享同一池（`get_shared_pool()`）

> **参考文档：** [runtime-instance-pattern](../../../archive/architecture/runtime-instance-pattern.md)

### 11.2 统一变量系统

2026 年的变量系统经历了重大重构，从单一的 `VariableContainer` 演进为**三层变量体系**（Local / Scope / Global），并提供了统一的操作接口。详见 §5。

#### 11.2.1 全局变量子系统

全局变量子系统由四个核心类组成：

- **`GlobalVariableManager`**（`core/global_variable_manager.gd`）：**RefCounted 静态单例**（不是 Node），使用 `Mutex` 保证线程安全，支持变量增删改查、资源持久化（`save_to_resource` / `load_from_resource` / `save_persistent_to_resource`）、批量操作和变量快照（`get_all_variables_snapshot`）
- **`GlobalVariableResource`**（`core/global_variable_resource.gd`）：继承 `Resource`，作为全局变量的数据载体。支持变量数据的标准化（`_normalize_variable_data`）、深拷贝序列化（`from_dict` / `_to_dict`）和可序列化值验证
- **`GlobalVariableAssistant`**（`core/global_variable_assistant.gd`）：场景节点，作为管理器的场景代理。支持自动保存（含延迟保存计时器）、持久化变量清理、资源加载/保存的桥接
- **`GlobalVariableService`**（`core/global_variable_service.gd`）：纯 RefCounted 服务层，无场景时替代 Assistant 兜底，API 命名与 Assistant 对齐

#### 11.2.2 作用域变量子系统

作用域变量实现了基于场景树的层次化变量管理：

- **`ScopeVariableContainer`**（`base/scope_variable_container.gd`）：作用域容器，挂载到场景节点上，提供作用域级别的变量存储。支持 `InheritanceMode`（继承模式）、`get_parent_scope()` / `get_child_scopes()` / `get_scope_chain()` 形成层次链
- **`ScopeVariableManager`**（`core/scope_variable_manager.gd`）：单例 Node 注册表，管理所有作用域容器的注册/注销。支持按 `scope_id` 查找、按节点向上搜索最近容器（`find_nearest_scope`）、获取节点链（`get_scope_node_chain`）

#### 11.2.3 变量操作工具

- **`VariableOperations`**（`utils/variable_operations.gd`）：统一的三层变量操作接口，提供静态方法 `get_variable()` / `set_variable()` / `check_variable()`，屏蔽了 LOCAL / SCOPE / GLOBAL 的访问差异
- **`VariableScopeUtils`**（`utils/variable_scope_utils.gd`）：作用域工具类，提供枚举与字符串互转、作用域来源（`ScopeSource`）处理、属性可见性验证（`validate_scope_source_property`），用于 `_validate_property()` 回调

#### 11.2.4 变量作用域枚举扩展

`BaseVariable.VariableScope`（base_variable.gd:41-45）形成完整的三级体系：

```gdscript
enum VariableScope {
    LOCAL = 0,   # 局部变量（ExecutionContext 生命周期）
    SCOPE = 1,   # 作用域变量（ScopeVariableContainer 生命周期）
    GLOBAL = 2   # 全局变量（GlobalVariableAssistant 生命周期）
}
```

### 11.3 对象池系统（core/pooling/，5 个类）

对象池体系在早期文档中**完全缺失**，本节为新增。5 个类位于 `core/pooling/`：

| 类 | 继承 | 路径 | 职责 |
|----|------|------|------|
| `FuseObjectPool` | `RefCounted` | `pooling/fuse_object_pool.gd` | 通用场景对象池，支持自动扩容/收缩、性能监控、`warm_up` 预热、`reset_object` 重置 Fuse 组件 |
| `FusePoolItem` | `RefCounted` | `pooling/fuse_pool_item.gd` | 池项包装器，跟踪 `in_use` / `last_used_time` / `usage_count`，提供 `is_expired` / `get_efficiency_score` |
| `FusePoolManager` | `RefCounted` | `pooling/fuse_pool_manager.gd` | 全局池管理器（`get_instance()` 单例），统一管理 `scene_path -> FuseObjectPool` 映射，支持 `instantiate_pooled` / `recycle_pooled` |
| `FuseRecycleTimer` | `Node` | `pooling/fuse_recycle_timer.gd` | 专用回收定时器，`SceneTreeTimer` 驱动，弱引用实例避免循环，`_creation_usage_count` 检测对象复用 |
| `InstructionInstancePool` | `RefCounted` | `pooling/instruction_instance_pool.gd` | `RuntimeInstructionInstance` 专用池，`acquire()` / `release()` / `release_all()`，默认 `_pool_size=32` / `_max_pool_size=128`，由 `RuntimeActionRunnerInstance._shared_instruction_pool` 静态共享 |

设计要点：
- 池化对象通过 `_reset_fuse_components(node)` 重置 Trigger / ActionRunner 状态，`_terminate_fuse_triggers(node)` 清理事件
- `_schedule_safe_remove(obj)` 延迟安全移除，避免帧内删除冲突
- `get_statistics()` / `get_detailed_status()` 提供池效率监控

### 11.4 线程系统（core/threading/，4 个类）

线程系统为 Fuse 提供安全高效的并行处理能力，主要服务于条件评估等计算密集型场景。详见 [多线程开发指南](../../dev_docs/guides/multithreading-developer-guide.md)。

| 类 | 继承 | 路径 | 职责 |
|----|------|------|------|
| `FuseTaskManager` | `RefCounted` | `threading/fuse_task_manager.gd` | 封装 `WorkerThreadPool`，`TaskStatus = {PENDING, RUNNING, COMPLETED, FAILED, CANCELED}`，`submit_task` / `submit_batch` / `await_task` / `await_all` |
| `ParallelConditionEvaluator` | `RefCounted` | `threading/parallel_condition_evaluator.gd` | 并行条件评估，`EvaluationMode = {SEQUENTIAL, PARALLEL_SAFE, PARALLEL_ALL}`，上下文快照避免竞态 |
| `FuseThreadSafe` | `RefCounted` | `threading/fuse_thread_safe.gd` | 线程安全工具，`dict_get_safe` / `dict_set_safe` / `dict_has_safe` / `arr_append_safe` 等静态方法封装 Mutex |
| `FuseThreadingConfig` | `Resource` | `threading/fuse_threading_config.gd` | 多线程配置，`enable_multithreading` / `parallel_condition_evaluation` / `max_parallel_conditions`(1-16) |

#### 11.4.1 FuseTaskManager 任务管理器

`FuseTaskManager` 封装了 Godot 的 `WorkerThreadPool`，提供统一的异步任务接口：

- **任务生命周期**：`PENDING` -> `RUNNING` -> `COMPLETED` / `FAILED` / `CANCELED`
- **提交接口**：`submit_task()` 提交单个任务，`submit_batch()` 批量提交，返回任务 ID 用于跟踪
- **同步等待**：`await_task()` / `await_all()` 支持带超时的阻塞等待（注意：不应在主线程使用）
- **线程安全**：使用 `Mutex` 保护任务状态字典和完成通知队列
- **信号通知**：`task_completed` / `task_failed` 信号线程安全发射，接收方应使用 `CONNECT_DEFERRED`

#### 11.4.2 ParallelConditionEvaluator 并行条件评估器

仅对标记为 `is_thread_safe` 的条件启用并行（`PARALLEL_SAFE` 模式）：

- **上下文快照**：并行评估前创建 `ExecutionContext` 的深拷贝快照（包括局部变量和全局变量），避免竞态条件
- **Semaphore 同步**：使用 `Semaphore.post()` / `try_wait()` 等待所有并行任务完成，配合 `Mutex` 保护结果数组
- **超时保护**：`timeout_per_condition: float = 0.1`，带超时的等待循环

> `MultiEventTrigger.check_conditions_parallel()` 即委托此评估器，缓解了早期文档列出的「条件评估无法并行」劣势。

### 11.5 编译缓存与执行诊断（顶层新增类）

#### 11.5.1 CompiledInstructionSequence（execution/compiled_instruction_sequence.gd）

```gdscript
class_name CompiledInstructionSequence extends RefCounted
```

Phase 3 性能优化：预编译指令序列的描述和方法绑定，减少 `RuntimeActionRunnerInstance` 执行时的重复计算开销。

- `_descriptions: PackedStringArray` —— 预缓存描述字符串
- `_execution_callables: Array[Callable]` —— 预绑定执行方法（Phase 3.2 预留）
- `_instruction_count: int` + `_is_valid: bool` —— 缓存失效检查
- `compile(action_runner) -> bool` / `is_valid_for(action_runner) -> bool` / `invalidate()`

由 `ActionRunner`（base/action_runner.gd）通过 `CompiledInstructionSequenceClass` preload 引用，`RuntimeActionRunnerInstance` 集成使用。

#### 11.5.2 ExecutionDiagnostics（base/execution_diagnostics.gd）

```gdscript
class_name ExecutionDiagnostics extends RefCounted
```

EC 诊断子系统，从早期 ExecutionContext 内联状态拆分而来：

- `_execution_state: int` —— `ExecutionContext.ExecutionState` 状态机
- `_execution_history: Array[Dictionary]` —— 历史记录（`_max_history_size=100`）
- `_state_change_listeners: Array[Callable]` —— 状态变化监听器
- `get_dependency_graph()` / `check_dependencies(deps)` / `get_dependency_status()` —— 依赖关系图与可视化数据

### 11.6 统一错误处理

#### 11.6.1 FuseError 类（详见 §8.2）

- **错误类型枚举**：`VALIDATION_ERROR` / `EXECUTION_ERROR` / `CONFIGURATION_ERROR` / `RUNTIME_ERROR` / `TIMEOUT_ERROR`
- **上下文信息**：`context: Dictionary` 存储任意附加上下文数据
- **自动日志记录**：构造函数中自动调用 `_log_to_fuse_logger()` 将错误写入日志
- **本地化支持**：提供 `create_*_localized()` 系列静态方法，支持通过翻译键和参数创建本地化错误消息

#### 11.6.2 统一接口

所有核心组件（`BaseInstruction`、`BaseCondition`、`BaseTrigger`、`RuntimeEventInstance`、`RuntimeActionRunnerInstance` 等）均集成了 `FuseError`，通过 `_create_fuse_error()` 和 `_create_fuse_error_localized()` 方法统一创建错误实例，存储在 `_fuse_error` 实例变量中。

### 11.7 统一日志系统（详见 §8.1）

`FuseLogger` 提供统一分级日志管理，所有 `_log_*` 方法委托它，缓解了早期文档列出的「日志格式不统一」问题。

### 11.8 顶层 Node 基础设施（Autoload 单例）

#### 11.8.1 FuseEventBus（core/fuse_event_bus.gd）

```gdscript
extends Node  # Autoload 单例（project.godot 注册为 FuseEventBus）
```

全局事件总线，允许不同 Trigger 之间通过自定义事件通信（配合 `SendEvent` 指令 + `OnReceiveEvent` 事件）。

API：
- `send_event(event_name, args={})` / `send_event_deferred(event_name, args={})`
- `subscribe(event_name, callback) -> Subscription` / `unsubscribe(subscription)`
- `has_listeners(name)` / `get_listener_count()` / `get_registered_events()`
- `get_event_history()` / `clear_history()` / `clear_all_listeners()`（`MAX_HISTORY_SIZE=100`）
- 内嵌 `class Subscription extends RefCounted`（`event_name` / `callback` / `id`）

副作用：`_ready()` 连接 `get_tree().node_removed` → 自动清理 `ReflectionCache` + `FunctionManager` 的节点缓存。

#### 11.8.2 FuseRuntimeBridge（core/fuse_runtime_bridge.gd）

```gdscript
extends Node  # Autoload 单例（project.godot 注册为 FuseRuntimeBridge）
```

运行时变量 TCP 桥，**双模式 Autoload**：

| 模式 | 角色 | 行为 |
|------|------|------|
| 编辑器侧 | TCPServer | `listen 127.0.0.1:24563`，接受运行游戏推送的变量快照，缓存到 `_cached` |
| 运行游戏侧 | TCP 客户端 | 连接 `127.0.0.1:24563`，每 `PUSH_INTERVAL=0.5s` 收集场景下所有 `Runner` 的 local/scope 变量快照，序列化为 JSON line 推送 |

协议：TCP 流 + JSON line（`\n` 分隔），运行游戏 → 编辑器：`{"t":"vars","runners":[{"name":"Runner1","local":{...},"scope":{...}},...]}`。

编辑器侧 `get_cached_vars() -> Dictionary` 供变量监视器读取；运行游戏侧通过 `Runner.current_execution_context._variable_context.get_all_local_variables_snapshot()` / `get_all_scope_variables_snapshot()` 采集。

### 11.9 表达式系统

表达式系统为 Fuse 提供了运行时动态求值能力，支持变量引用嵌入和丰富的内置函数。

#### 11.9.1 ExpressionHelper 工具类（utils/expression_helper.gd）

- **变量引用语法**：使用 `{local:xxx}` / `{scope:xxx}` / `{global:xxx}` 语法在表达式中引用变量，通过正则匹配（`VAR_PATTERN`）进行替换
- **安全求值**：`evaluate()` 方法封装了 Godot `Expression` 类的解析和执行，失败时通过 `error_text` 参数返回错误信息
- **值转义**：`escape_value()` 用于数学上下文（数值优先），`escape_value_for_string()` 用于字符串上下文（保留字符串类型）
- **GameExprHelper 内部类**：作为 `Expression.execute()` 的 `base_instance` 传入，提供游戏常用函数：

| 类别 | 函数 |
|------|------|
| 向量 | `vec2()`, `vec3()`, `normalize()`, `distance()`, `direction()`, `angle()` |
| 数值 | `remap()`, `inverse_lerp()`, `snap()`, `move_toward_val()`, `is_zero()` |
| 字符串 | `format_num()`, `pad_left()`, `pad_right()` |

#### 11.9.2 表达式指令与条件

基于 `ExpressionHelper` 构建的三个业务组件（位于 `instructions/math/`、`instructions/string/`、`conditions/math/`）：

- **`MathExpression`**：数学表达式指令，支持四则运算、数学函数、向量字面量，输出类型可选 Float / Int / Vector2 / Vector3
- **`StringExpression`**：字符串表达式指令，支持字符串拼接、条件文本、类型转换和字符串工具函数
- **`ExpressionCondition`**：表达式条件，支持比较运算、逻辑运算、三元运算，返回布尔值用于条件分支

三者均支持 `ScopeSource` 枚举，允许在表达式中灵活指定作用域来源（最近容器 / 自定义 ID / 触发器节点 / 目标节点）。

### 11.10 编辑器工具扩展

2026 年大幅扩展了编辑器工具链（位于 `editor/`，不在本文范围），覆盖调试可视化、静态分析和代码生成三个维度。本节仅列概览：

- **调试可视化**：`DebugVisualizer` + `ExecutionTracker`（`editor/debugging/`）—— 执行历史树形展示、性能指标、JSON 导出
- **静态分析**：`InstructionAnalyzer.analyze_problems` + `FuseTopology` 标注 —— local 未声明变量检测，结果在 Topology 主屏就地标注
- **自动生成指令**：`InstructionGenerator` + `PropertyInstructionGenerator` + 辅助模块（`TypeMapper` / `ConflictHandler` / `MethodFilter` / `MethodSelectorDialog`）

---

**最后更新**：2026-07-07 | **基准代码**：`addons/fuse/core/` 实际实现 | **审计依据**：[AUDIT_REPORT_2026-07-07.md](AUDIT_REPORT_2026-07-07.md)
