# BaseTrigger 分析报告

## 文档概述

本报告对 Fuse 可视化编程系统中的 `BaseTrigger` 核心脚本进行了全面分析。`BaseTrigger` 是触发器系统的抽象基类 (`@abstract class_name BaseTrigger extends Node`)，定义了触发器与事件 / 动作运行时实例协作的统一接口、冷却检查、执行上下文创建、引擎回调转发以及池化重置钩子，为 `Trigger` (单事件) 和 `MultiEventTrigger` (多事件绑定) 两个具体子类提供公共能力。

**源文件:** `addons/fuse/core/base_trigger.gd`
**行数:** 354 行
**基类:** Node
**子类:** `Trigger` (`addons/fuse/core/trigger.gd`)、`MultiEventTrigger` (`addons/fuse/core/multi_event_trigger.gd`)

> **路径说明**: 本类位于 `core/` 顶层（与 `trigger.gd` / `multi_event_trigger.gd` / `runtime_event_instance.gd` / `runtime_action_runner_instance.gd` 同目录）。早期文档曾误写为 `core/base/base_trigger.gd`，该路径不存在。

---

## 1. 类概述和职责

`BaseTrigger` 是一个纯抽象基类：自身不持有任何事件 / 动作运行时实例，仅提供协议（5 个抽象方法）和可复用的工具方法。具体的事件存储、信号连接、ActionRunner 调度由子类完成。

### 核心职责

1. **协议定义**: 通过 5 个 `@abstract` 方法规定子类必须暴露的事件 / 运行时实例访问接口
2. **冷却控制**: 提供 `_check_cooldown()` / `_clear_cooldown_state()`，支持 `CooldownMode` 三档策略
3. **执行上下文工厂**: `_create_execution_context()` 创建 ExecutionContext 并自动同步 RuntimeEventInstance 的事件参数
4. **引擎回调统一转发**: 将 `_process` / `_physics_process` / `_notification` / `_unhandled_input` 转发到所有事件实例的 `on_process` / `on_physics_process` / `handle_process_notification` / `handle_physics_process_notification` / `handle_input`
5. **ActionRunner 信号桥接**: `_connect_action_runner_signals_at()` / `_disconnect_action_runner_signals_at()` 统一连接 / 断开 `execution_completed` / `execution_failed` / `execution_canceled`
6. **池化支持**: `pool_reset()` 委托子类的 `_on_pool_reset()` 完成完整重建
7. **错误与日志**: 统一 FuseError 创建 / 查询接口与本地化日志方法族

### 设计特点

- 使用 `@abstract` 标记抽象类与抽象方法（GDScript 2.0 语法）
- 通过 `@tool` 注解支持编辑器模式运行（与子类一致）
- 编辑器模式下所有引擎回调立即返回，避免副作用
- 5 个抽象方法形成「索引式访问契约」，使基类工具方法可同时服务单事件 (Trigger) 与多事件 (MultiEventTrigger) 两种存储模型

---

## 2. 核心属性

### 枚举

```gdscript
enum CooldownMode {
    NONE,               ## 无冷却，每次都触发
    GLOBAL_COOLDOWN,    ## 全局冷却：触发后所有物体都需要等待
    PER_OBJECT_COOLDOWN ## 每物体独立冷却：每个物体有自己的冷却计时器
}
```

| 值 | 含义 | 冷却状态键 (存于 RuntimeEventInstance.runtime_state) |
|----|------|-----------------------------------------------------|
| `NONE` | 不做冷却检查，`_check_cooldown` 立即返回 true | — |
| `GLOBAL_COOLDOWN` | 触发后所有调用方都需等待 `cooldown_time` 秒 | `last_trigger_time: float` |
| `PER_OBJECT_COOLDOWN` | 按 `context.get_instance_id()` 分别计时 | `object_cooldowns: Dictionary[int, float]` |

### 信号

| 信号 | 签名 | 说明 |
|------|------|------|
| `event_completed` | `(context: Dictionary)` | 事件执行完成（子类可定义自己的完成信号） |
| `event_stopped` | `(reason: String, context: Dictionary)` | 事件停止时发出（含执行失败 / 取消） |

> 子类 `MultiEventTrigger` 额外定义 `event_completed_with_index(binding_index, context)` 与 `event_stopped_with_index(binding_index, reason, context)`，并在回调中同时发射基类与带索引两个信号以保持兼容（见 `multi_event_trigger.gd:380-403`）。

### @export 属性

| 属性 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `pool_mode` | bool | false | 池化模式：首次 `_ready()` 跳过初始化，等待显式 `pool_reset()` |
| `log_level` | FuseLogger.LogLevel | NONE | 日志输出级别控制 |

### 内部状态

| 属性 | 类型 | 说明 |
|------|------|------|
| `_fuse_error` | FuseError | 错误实例，统一错误处理（`reset()` 中清除） |

> 注意：BaseTrigger 自身**不**持有 `_runtime_event_instance` / `_runtime_action_runner_instance` / `event_definition` 等成员。这些都在子类中定义，并通过抽象方法暴露给基类。

---

## 3. 抽象方法（子类必须实现）

5 个 `@abstract` 方法构成「索引式访问契约」。基类的所有工具方法（冷却检查、上下文创建、引擎回调转发、信号桥接）都通过这些方法访问子类数据，从而同时支持单事件和多事件两种模型。

### 3.1 事件访问

#### `get_event_count() -> int`

返回当前触发器持有的事件数量。`Trigger` 返回 0 或 1（取决于 `event_definition` 是否为 null）；`MultiEventTrigger` 返回 `event_bindings.size()`。

#### `get_event_at(index: int) -> BaseEvent`

返回指定索引的 BaseEvent 资源。越界时子类返回 null。`Trigger` 仅在 `index == 0` 时返回 `event_definition`。

### 3.2 运行时实例访问

#### `get_runtime_event_instance_at(index: int) -> RuntimeEventInstance`

返回指定索引的 RuntimeEventInstance。这是冷却状态读取 / 写入、事件参数同步的唯一来源。

#### `get_action_runner_instance_at(index: int) -> RuntimeActionRunnerInstance`

返回指定索引的 RuntimeActionRunnerInstance。基类的 ActionRunner 信号桥接方法通过此方法定位实例。

### 3.3 池化重置

#### `_on_pool_reset() -> void`

池化场景下对象被复用时的完整重置逻辑。子类必须实现，负责：

1. 调用 `reset()` 清理自身状态
2. 调用 `_disable_processing()` 暂停引擎回调
3. 终止旧事件监听（在设置正确的 `_runtime_instance_ref` 后调用 `event.terminate(self)`）
4. 清理旧的 RuntimeEventInstance / RuntimeActionRunnerInstance
5. 创建新的 RuntimeEventInstance 并调用 `event.initialize_with_runtime_instance()`
6. 创建新的 RuntimeActionRunnerInstance（若有 action_runner）
7. 重新连接 triggered 信号
8. 调用 `_enable_processing()` 恢复引擎回调

详见 `trigger.gd:52-86` 与 `multi_event_trigger.gd:78-87` 的具体实现。

---

## 4. 关键方法

### 4.1 生命周期

#### `_ready() -> void`

```
执行流程:
  1. 编辑器模式 → 输出本地化调试日志并返回
  2. pool_mode == true → 跳过首次初始化，等待 pool_reset()
  3. 调用 _on_trigger_ready()（子类钩子）
```

#### `_exit_tree() -> void`

委托 `_on_trigger_exit_tree()` 子类钩子。`Trigger` 在此断开信号、清理 RuntimeEventInstance / RuntimeActionRunnerInstance；`MultiEventTrigger` 额外将 `_condition_evaluator` 置 null。

#### 可覆盖钩子

| 方法 | 默认行为 |
|------|----------|
| `_on_trigger_ready()` | 空实现（子类初始化事件 / 运行时实例 / 信号） |
| `_on_trigger_exit_tree()` | 空实现（子类清理） |
| `reset()` | 清除 `_fuse_error`（子类追加：清 has_triggered、冷却状态、event.reset()） |
| `validate() -> Array[String]` | 返回空数组（子类追加配置校验） |
| `trigger_manually(context: Node = null)` | 空实现（子类转发到 `_on_event_fired`） |
| `get_description() -> String` | 返回 "BaseTrigger"（子类覆盖为事件描述 + 冷却信息） |

### 4.2 冷却检查

#### `_check_cooldown(index, context, cooldown_mode, cooldown_time) -> bool`

参数顺序: `index: int, context: Node, cooldown_mode: CooldownMode, cooldown_time: float`。返回 true 表示可以触发。

```
执行流程:
  1. cooldown_mode == NONE 或 cooldown_time <= 0 → 返回 true
  2. event_instance = get_runtime_event_instance_at(index)
     若为 null → 返回 true（无实例可记）
  3. current_time = Time.get_ticks_msec() / 1000.0
  4. match cooldown_mode:
       GLOBAL_COOLDOWN:
         last_time = runtime_state.get("last_trigger_time", 0.0)
         若 current_time - last_time < cooldown_time → 输出 info 日志、返回 false
         否则写入 runtime_state["last_trigger_time"] = current_time
       PER_OBJECT_COOLDOWN:
         object_cooldowns = runtime_state.get("object_cooldowns", {})
         object_id = context.get_instance_id() (context 为 null 时为 0)
         若 object_id != 0 且 object_cooldowns.has(object_id):
           若 current_time - object_cooldowns[object_id] < cooldown_time
             → 输出含物体名 / ID 的 info 日志、返回 false
         写入 object_cooldowns[object_id] = current_time
  5. 返回 true
```

> 冷却状态全部存于 RuntimeEventInstance.runtime_state 字典，而非 Trigger 自身字段。这样多个池化对象共享同一 Event 资源时，每个对象有独立的 RuntimeEventInstance，冷却互不干扰。

#### `_clear_cooldown_state(index: int) -> void`

擦除指定索引对应 RuntimeEventInstance 的 `last_trigger_time` 与 `object_cooldowns` 键。`Trigger.reset()` 与 `MultiEventTrigger.reset()` 都会调用此方法。

### 4.3 执行上下文工厂

#### `_create_execution_context(target: Node, index: int = 0) -> RefCounted`

```
执行流程:
  1. context = ExecutionContext.new(target, self)
  2. 写入 context 变量: event_source = self, triggered_node = target
  3. context.log_level = log_level
  4. 若 target 有 meta "delta_time" → 同步到 context.delta_time（轮询事件用）
  5. _sync_event_args_to_context(context, index)
  6. 返回 context
```

#### `_sync_event_args_to_context(context, index) -> void`

将 RuntimeEventInstance 的事件参数同步到 ExecutionContext 变量命名空间：

1. 读取 `runtime_state["last_event_args"]`（Dictionary），为每个键写入变量 `event_<key>`
2. 遍历 runtime_state 中所有 `event_` 前缀的键（除 `event_source`），写入 context

> Trigger 与 MultiEventTrigger 都依赖此机制把事件参数（input_vector、键位、碰撞物体等）暴露给 ActionRunner 中的指令。

### 4.4 ActionRunner 信号桥接

#### `_connect_action_runner_signals_at(index, callbacks) -> bool`

`callbacks` 字典格式: `{"completed": Callable, "failed": Callable, "canceled": Callable}`。

按索引定位 RuntimeActionRunnerInstance，对 `execution_completed` / `execution_failed` / `execution_canceled` 三个信号（若存在且未连接）逐个 `connect`。返回 true 表示至少连接了一个。

#### `_disconnect_action_runner_signals_at(index, callbacks) -> void`

对称断开。子类用 `_action_runner_signals_connected` 标志位防止重复连接 / 断开。

> 子类回调签名: `Trigger` 用 `_on_action_runner_completed(total_time)` / `_on_action_runner_failed(error_message)` / `_on_action_runner_canceled(reason)`；`MultiEventTrigger` 用 `.bind(index)` 携带绑定索引。

### 4.5 引擎回调统一转发

BaseTrigger 把 Godot 节点的四个引擎回调统一转发到所有事件实例（编辑器模式跳过）：

| BaseTrigger 方法 | 转发目标 (事件实例方法) | 说明 |
|------------------|------------------------|------|
| `_process(delta)` | `event.on_process(delta, event_instance)` | 每帧轮询（如 OnInterval、OnAnimationMarker） |
| `_physics_process(delta)` | `event.on_physics_process(delta, event_instance)` | 物理帧轮询（如 OnBodyEntered 持续检测） |
| `_notification(NOTIFICATION_PROCESS)` | `event.handle_process_notification()` | 进程通知 |
| `_notification(NOTIFICATION_PHYSICS_PROCESS)` | `event.handle_physics_process_notification()` | 物理进程通知 |
| `_unhandled_input(event)` | `event.handle_input(event)` | 输入事件（如 OnInputKey、OnMouseButton） |

转发前均以 `event.has_method(...)` 守卫，缺失方法的事件静默跳过。事件通过 `get_event_at(i)` 取得，配套的 RuntimeEventInstance 通过 `get_runtime_event_instance_at(i)` 取得（`on_process` / `on_physics_process` 需要传入实例供事件读写状态）。

### 4.6 池化支持

#### `pool_reset() -> void`

公开入口，委托 `_on_pool_reset()`（抽象）。配合 `pool_mode` 属性实现对象池复用。

#### `_disable_processing() / _enable_processing() -> void`

切换 `set_physics_process` / `set_process` 开关。子类在 `_on_pool_reset()` 起止处调用，避免重建期间触发引擎回调转发到已失效的事件实例。

### 4.7 错误处理

| 方法 | 说明 |
|------|------|
| `_create_fuse_error(message, error_type, context)` | 创建 FuseError 实例存入 `_fuse_error`，自动在 context 中追加 `trigger_name = name` |
| `_create_fuse_error_localized(message_key, error_type, context, args)` | 用 `FuseLocalization.translate_format(message_key, args)` 翻译后再创建 |
| `get_fuse_error() -> FuseError` | 返回当前错误 |
| `has_fuse_error() -> bool` | 是否有错误 |

`FuseError.ErrorType` 常用值: `RUNTIME_ERROR`、`CONFIGURATION_ERROR`（子类在 `validate()` / `_on_trigger_ready()` 缺配置时使用）。

### 4.8 日志方法

本地化与非本地化两组，全部委托 `FuseLogger`：

| 非本地化 | 本地化（接受翻译键 + args） |
|----------|----------------------------|
| `_log_debug(message)` | `_log_debug_localized(message_key, args = {})` |
| `_log_info(message)` | `_log_info_localized(message_key, args = {})` |
| `_log_warning(message)` | `_log_warning_localized(message_key, args = {})` |
| `_log_error(message)` | `_log_error_localized(message_key, args = {})` |

所有调用统一以 `"Trigger"` 为分类，传入 `log_level` 与节点 `name`。本地化键示例: `FUSE_LOG_TRIGGER_INITIALIZED`、`FUSE_ERROR_TRIGGER_NO_ACTION_RUNNER`、`FUSE_LOG_TRIGGER_POOL_RESET` 等。

---

## 5. 与 RuntimeEventInstance 的协作

`RuntimeEventInstance`（`addons/fuse/core/runtime_event_instance.gd`，288 行，`extends RefCounted`）是 BaseTrigger 体系运行时状态的唯一载体。

### 集成架构

```
BaseTrigger (Node, 抽象)
    │
    ├── 通过 get_event_at(i) → BaseEvent (Resource, 可被多 Trigger 共享)
    │
    ├── 通过 get_runtime_event_instance_at(i) → RuntimeEventInstance (RefCounted, 每 Trigger 独立)
    │        │
    │        ├── event_definition: BaseEvent       (事件资源引用)
    │        ├── owner_trigger: Node               (所属触发器)
    │        ├── runtime_state: Dictionary         (冷却键 / 事件参数 / 自声明状态)
    │        └── signal triggered(context: Node)   (转发自 BaseEvent.triggered)
    │
    └── 通过 get_action_runner_instance_at(i) → RuntimeActionRunnerInstance (RefCounted)
             │
             ├── definition: ActionRunner
             ├── signal execution_completed(total_time)
             ├── signal execution_failed(error_message)
             └── signal execution_canceled(reason)
```

### 信号转发链（关键）

`BaseEvent` 资源是可被多 Trigger 共享的 Resource。RuntimeEventInstance 在构造时连接 `event_definition.triggered` 到自己的 `_on_event_triggered` 回调，转发前检查 `context.get_meta("trigger") == owner_trigger`，只转发属于自己触发器的事件（见 `runtime_event_instance.gd:104-115`）：

```
BaseEvent.triggered.emit(context_with_trigger_meta)
    └──→ RuntimeEventInstance._on_event_triggered(context)
          ├── 若 context.trigger meta != owner_trigger → 丢弃
          └── RuntimeEventInstance.triggered.emit(context)
                └──→ Trigger._on_event_fired(context)  [子类连接]
```

这一层中转解决了"同一 Event 资源被多个池化 Trigger 共享时的信号串扰"。

### 冷却状态存储

冷却状态全部存于 `runtime_state`，键名约定:

| CooldownMode | 键 | 类型 |
|--------------|----|----|
| GLOBAL_COOLDOWN | `last_trigger_time` | float (秒) |
| PER_OBJECT_COOLDOWN | `object_cooldowns` | Dictionary[int, float] (instance_id → 上次触发时间) |

由基类 `_check_cooldown()` / `_clear_cooldown_state()` 直接读写。子类无需关心冷却细节，只需在导出属性中暴露 `cooldown_mode` / `cooldown_time` 并把参数传给基类。

### 池化重置中的关键修复

`Trigger._on_pool_reset()` 与 `MultiEventTrigger._stop_all_events()` 在调用 `event.terminate(self)` 之前**显式设置** `event._runtime_instance_ref = _runtime_event_instance`（trigger.gd:63、multi_event_trigger.gd:215）。原因是 Event 子类的 `terminate()` 内部通过 `get_runtime_state()` 访问状态，而该方法会优先使用传入参数、回退到 `_runtime_instance_ref`。预先设置正确引用可确保 terminate 操作正确的运行时实例，避免多池化对象共享 Event 资源时的状态覆盖。

---

## 6. 子类实现模式

### 6.1 Trigger (单事件触发器, `trigger.gd`, 335 行)

存储模型: 单组字段。

| 字段 | 类型 | 说明 |
|------|------|------|
| `event_definition` | BaseEvent (@export) | 监听的事件资源 |
| `action_runner` | ActionRunner (@export) | 触发时执行的动作 |
| `trigger_once` | bool (@export) | 是否只触发一次 |
| `cooldown_mode` | CooldownMode (@export) | 冷却模式 |
| `cooldown_time` | float (@export_range 0.0-60.0) | 冷却秒数 |
| `has_triggered` | bool | trigger_once 状态 |
| `_runtime_event_instance` | RuntimeEventInstance | 运行时事件实例 |
| `_runtime_action_runner_instance` | RuntimeActionRunnerInstance | 运行时动作实例 |

抽象方法实现:

```gdscript
func get_event_count() -> int:
    return 1 if event_definition != null else 0
func get_event_at(index: int) -> BaseEvent:
    return event_definition if index == 0 else null
func get_runtime_event_instance_at(index: int) -> RuntimeEventInstance:
    return _runtime_event_instance if index == 0 else null
func get_action_runner_instance_at(index: int) -> RuntimeActionRunnerInstance:
    return _runtime_action_runner_instance if index == 0 else null
```

`_on_event_fired(context)` 流程: trigger_once 检查 → ActionRunner 运行中检查 → `_check_cooldown(0, ...)` → `_create_execution_context` → 同步 input_vector 等额外参数 → `_runtime_action_runner_instance.run(context)`。

### 6.2 MultiEventTrigger (多事件触发器, `multi_event_trigger.gd`, 481 行)

存储模型: 与 `event_bindings: Array[EventBinding]` 一一对应的并行数组。

| 字段 | 类型 | 说明 |
|------|------|------|
| `event_bindings` | Array[EventBinding] (@export) | 事件-动作绑定列表 |
| `_runtime_event_instances` | Array[RuntimeEventInstance] | 一一对应 |
| `_runtime_action_instances` | Array[RuntimeActionRunnerInstance] | 一一对应 |
| `_has_triggered` / `_signal_connected` / `_action_signals_connected` / `_initialized` | Array[bool] | 状态标志一一对应 |
| `use_parallel_condition_evaluation` | bool (@export, 默认 true) | 启用 WorkerThreadPool 并行条件评估 |
| `_condition_evaluator` | ParallelConditionEvaluator | 并行评估器实例 |

抽象方法实现以 `event_bindings.size()` 为上界做索引访问。`_on_event_fired(context, index)` 通过 `.bind(index)` 携带绑定索引，流程类似 Trigger 但条件检查可走并行路径（`check_conditions_parallel`）或串行回退（`check_conditions_serial`）。

特有方法:

| 方法 | 说明 |
|------|------|
| `trigger_binding(index, context = null)` | 手动触发指定绑定 |
| `set_binding_enabled(index, enabled)` | 动态启用 / 禁用绑定（调用 `event_instance.start_listening()` / `stop_listening()`） |
| `event_completed_with_index` / `event_stopped_with_index` 信号 | 携带 binding_index，与基类信号同时发射 |

### 6.3 EventBinding (绑定资源, `event_binding.gd`)

`class_name EventBinding extends Resource`，每个绑定封装:

| 字段 | 类型 | 默认值 |
|------|------|--------|
| `event` | BaseEvent (@export) | — |
| `action_runner` | ActionRunner (@export) | — |
| `enabled` | bool (@export) | true |
| `trigger_once` | bool (@export) | false |
| `cooldown_mode` | BaseTrigger.CooldownMode (@export) | NONE |
| `cooldown_time` | float (@export_range 0.0-60.0) | 0.0 |
| `use_conditions` | bool (@export) | false (控制 conditions 动态可见性) |
| `conditions` | Array[BaseCondition] | [] |

---

## 7. 与 ActionRunner 体系的关系

BaseTrigger 通过 RuntimeActionRunnerInstance 间接驱动 ActionRunner：

1. **运行时实例化**: 子类在 `_on_trigger_ready()` 中调用 `RuntimeActionRunnerInstance.new(action_runner, self)`，并把 `set_batch_signal_mode(true)` 打开（Phase 2.5 优化，减少高频触发的信号开销）
2. **信号连接**: 子类用基类 `_connect_action_runner_signals_at()` 注册 completed / failed / canceled 三个回调
3. **执行触发**: 子类在 `_on_event_fired()` 中调用 `_runtime_action_runner_instance.run(execution_context)`
4. **回调分发**: RuntimeActionRunnerInstance 发出 `execution_completed(total_time)` / `execution_failed(error_message)` / `execution_canceled(reason)`，子类回调转换为 `event_completed` / `event_stopped` 信号（MultiEventTrigger 额外发带索引版本）
5. **清理**: `_on_trigger_exit_tree()` 与 `_on_pool_reset()` 中调用 `action_instance.cleanup()`

RuntimeActionRunnerInstance 自身提供: `is_running()`、`cancel_execution(reason)`、`set_stop_execution(stop, reason)`、`validate_instructions()`、`invalidate_validation_cache()`、`get_runtime_state(key)` / `set_runtime_state(key, value)` 等接口（见 `runtime_action_runner_instance.gd`）。

---

## 8. 性能考虑

### 设计层面的优化

1. **索引式访问契约**: 5 个抽象方法让基类工具方法零拷贝服务单 / 多事件两种模型，避免在基类引入"数组 vs 单值"分支
2. **批量信号模式**: 子类为 RuntimeActionRunnerInstance 启用 `set_batch_signal_mode(true)`，将逐指令信号合并发射
3. **并行条件评估**: MultiEventTrigger 默认启用 `use_parallel_condition_evaluation`，用 WorkerThreadPool 并行评估多个 BaseCondition；评估器为 null 时自动回退串行
4. **编辑器模式跳过**: 所有引擎回调与 `_ready()` 在 `Engine.is_editor_hint()` 下立即返回，避免编辑器中误触发
5. **池化支持**: `pool_mode` + `pool_reset()` 允许 Trigger 节点被对象池复用，避免反复实例化 Node

### 潜在性能开销

1. **引擎回调全量转发**: `_process` / `_physics_process` / `_unhandled_input` 每帧遍历所有事件并 `has_method` 守卫——事件数量大时存在迭代开销，但 `has_method` 调用廉价
2. **冷却 Dictionary 操作**: `PER_OBJECT_COOLDOWN` 下 `object_cooldowns` 字典会随物体数量增长；长期运行场景需考虑清理策略（当前仅在 `reset()` 时整体擦除）
3. **信号 `.bind(index)`**: MultiEventTrigger 为每个回调绑定索引生成 Callable，绑定数量随 event_bindings 线性增长

---

## 9. 总体评估

### 优点

1. **抽象边界清晰**: 5 个抽象方法形成极简协议，基类工具方法高度复用，两个子类各自只关心"单 / 多存储模型"差异
2. **运行时状态隔离彻底**: 冷却、事件参数、触发计数全部走 RuntimeEventInstance，Event 资源可安全共享，池化对象互不干扰
3. **冷却三档设计合理**: NONE / GLOBAL / PER_OBJECT 覆盖常见用例，状态键约定清晰
4. **引擎回调统一转发**: 一处实现，所有事件子类（OnInputKey、OnInterval、OnAnimationMarker 等）受益，无需各自实现 _process
5. **池化关键修复到位**: terminate 前预置 `_runtime_instance_ref` 解决了共享 Event 资源的状态覆盖陷阱（注释详尽）
6. **错误 / 日志统一**: FuseError + FuseLocalization + FuseLogger 三套基础设施贯穿，与 BaseEvent / BaseInstruction 一致

### 不足

1. **`event_completed` / `event_stopped` 信号无默认发射**: 基类定义了信号但回调由子类实现，子类若忘记在 `_on_action_runner_completed` 中 `emit` 则信号永不触发（当前两个子类均正确发射，但缺乏基类层面的强制）
2. **冷却 info 日志频率**: GLOBAL_COOLDOWN / PER_OBJECT_COOLDOWN 冷却中时每次触发都输出 `_log_info`，高频事件下可能产生日志噪声（可考虑降级为 debug 或加采样）
3. **PER_OBJECT_COOLDOWN 无自动清理**: `object_cooldowns` 字典只在 `reset()` 时整体擦除，长时间运行且物体频繁进出（如 Area 触发器）会持续累积条目
4. **`trigger_manually` 默认空实现**: 基类提供钩子但不强制，若子类忘记覆盖则手动触发无效果（当前 Trigger 覆盖为转发 `_on_event_fired`，MultiEventTrigger 用 `trigger_binding`）
5. **`_create_execution_context` 返回 RefCounted 而非 ExecutionContext 类型注解**: 类型推断弱，IDE 补全受限（实际返回 ExecutionContext 实例）

---

**文档维护**: Fuse 开发团队
**最后更新**: 2026-07-07
**版本**: 1.0.0 (现状描述体例重写)
**参照源码**: `addons/fuse/core/base_trigger.gd` (354) / `trigger.gd` (335) / `multi_event_trigger.gd` (481) / `runtime_event_instance.gd` (288) / `runtime_action_runner_instance.gd` (691) / `event_binding.gd`
