> 🌐 中文 | [**English**](../../../en_US/system_docs/analysis/multi_event_trigger_analysis.md)

# MultiEventTrigger 分析


> **分析时点**：2026-07-07（经同日全量文档审计逐篇核对代码；此后实现演进以源码为准，近期已核对的机制性结论见 threading / runtime_instance / preset_nested 等篇）
## 概述

`MultiEventTrigger` 是 Fuse 系统中用于将多个 Trigger 功能合并到单个节点的组件。它继承自 `BaseTrigger`，通过 `EventBinding` 数组管理多个事件-动作绑定，减少场景中的节点数量并提升性能。

- **文件**: `addons/fuse/core/multi_event_trigger.gd` (481 行)
- **类名**: `MultiEventTrigger`
- **继承**: `class_name MultiEventTrigger extends BaseTrigger`（multi_event_trigger.gd:4）
- **图标**: `res://addons/fuse/icons/builtin/Signal.svg`

## 核心职责

1. 管理多个 `EventBinding`（事件 + ActionRunner + 条件 + 冷却配置）
2. 为每个绑定创建和管理 `RuntimeEventInstance` / `RuntimeActionRunnerInstance`
3. 支持并行条件评估（`ParallelConditionEvaluator`）
4. 提供动态绑定控制（启用/禁用、手动触发、重置）

## 核心属性

### 导出属性

| 属性 | 类型 | 说明 |
|------|------|------|
| `event_bindings` | `Array[EventBinding]` | 事件绑定列表，每个包含 event、action_runner、conditions、冷却配置 |
| `use_parallel_condition_evaluation` | `bool` | 是否启用并行条件评估（默认 true） |

### 内部状态数组

每个数组与 `event_bindings` 一一对应：

| 数组 | 说明 |
|------|------|
| `_runtime_event_instances` | 运行时事件实例 |
| `_runtime_action_instances` | 运行时 ActionRunner 实例 |
| `_has_triggered` | 是否已触发（用于 trigger_once 模式） |
| `_signal_connected` | 信号是否已连接 |
| `_action_signals_connected` | ActionRunner 信号是否已连接 |
| `_initialized` | 是否已初始化 |

## 生命周期

### 初始化 (_on_trigger_ready)

```
1. _initialize_parallel_evaluator()   # 创建 ParallelConditionEvaluator
   # 设置 evaluation_mode = EvaluationMode.PARALLEL_SAFE（:108）
2. _initialize_runtime_instances()  # 为每个绑定创建 Runtime*Instance
   # 内部先调 _cleanup_runtime_instances()（:113），保证幂等
3. _start_all_events()               # 启动所有事件监听
```

### 清理 (_on_trigger_exit_tree)

```
1. _stop_all_events()               # 终止所有事件
2. _cleanup_runtime_instances()      # 断开信号、清理实例
3. _condition_evaluator = null       # 清理并行评估器
```

### 池化重置 (_on_pool_reset)

```
1. _disable_processing()
2. _stop_all_events()
3. _initialize_runtime_instances()   # 重新创建实例
4. _start_all_events()
5. _enable_processing()
```

## EventBinding 数据结构

每个 EventBinding 包含：

| 字段 | 说明 |
|------|------|
| `event` | `BaseEvent` 资源 - 触发的事件 |
| `action_runner` | `ActionRunner` 资源 - 触发后执行的指令序列 |
| `use_conditions` | `bool`（@export，event_binding.gd:53）- 是否启用条件检查；控制 `conditions` 在编辑器中的动态可见性（通过 `_get_property_list()` 实现） |
| `conditions` | `Array[BaseCondition]` - 条件列表（**普通 var 非 @export**，event_binding.gd:61；可见性由 `use_conditions` 决定） |
| `enabled` | `bool` - 是否启用 |
| `trigger_once` | `bool` - 是否只触发一次 |
| `cooldown_mode` | `CooldownMode` - 冷却模式 |
| `cooldown_time` | `float` - 冷却时间（秒） |

## 条件评估

### 并行评估 (check_conditions_parallel)

使用 `ParallelConditionEvaluator` 在 WorkerThreadPool 中并行检查所有条件：

```gdscript
var results: Array[bool] = _condition_evaluator.evaluate_parallel(context, conditions)
```

### 串行评估 (check_conditions_serial)

回退方案，在主线程上逐一检查：

```gdscript
for condition in binding.conditions:
    if not condition.check(context):
        return false
return true
```

## 冷却系统

支持两种冷却模式：

| 模式 | 说明 |
|------|------|
| `GLOBAL_COOLDOWN` | 全局冷却，上次触发后等待指定时间 |
| `PER_OBJECT_COOLDOWN` | 按物体冷却，使用 `context.get_instance_id()` 区分不同触发源 |

冷却时间存储在 `RuntimeEventInstance.runtime_state` 中，重置时自动清除。

## 信号

MultiEventTrigger 在 ActionRunner 回调中**同时发射两个信号**（multi_event_trigger.gd:380–381）：基类兼容版本（无 index）+ 本类带 index 版本。

| 信号 | 参数 | 说明 |
|------|------|------|
| `event_completed_with_index` | `binding_index: int, context: Dictionary` | 某个绑定执行完成 |
| `event_stopped_with_index` | `binding_index: int, reason: String, context: Dictionary` | 某个绑定停止 |

继承自 BaseTrigger 的信号（每次触发时一并发射，保持向后兼容）：
- `event_completed(context: Dictionary)` - 任意绑定完成
- `event_stopped(reason: String, context: Dictionary)` - 任意绑定停止

> 同时，`binding_index` 会被注入到 `ExecutionContext`（multi_event_trigger.gd:267），供下游指令通过 `context.get_variable("binding_index")` 读取。

## 公共 API

| 方法 | 说明 |
|------|------|
| `get_event_count()` | 获取绑定总数 |
| `get_event_at(index)` | 获取指定位置的事件 |
| `get_description()` | 获取描述（N 个绑定，M 个启用） |
| `validate()` | 验证所有绑定配置，返回错误列表 |
| `reset()` | 重置所有触发状态和冷却 |
| `trigger_binding(index, context=null)` | 手动触发指定绑定（第二参数为可选触发源节点，multi_event_trigger.gd:458） |
| `set_binding_enabled(index, enabled)` | 动态启用/禁用绑定 |

## 性能优化

1. **批量信号模式**: RuntimeActionRunnerInstance 启用 `set_batch_signal_mode(true)` 减少高频触发的信号开销
2. **并行条件评估**: WorkerThreadPool 并行检查条件
3. **运行时检查**: 跳过已触发的 trigger_once 绑定、正在运行的 ActionRunner、冷却中的绑定
4. **状态数组预分配**: 所有状态数组与 event_bindings 一一对应，避免运行时查找

## 设计决策

- **一一对应原则**: 所有内部状态数组与 `event_bindings` 通过索引一一对应，简化数据管理
- **共享 Event 资源**: 多个绑定可以引用同一个 Event 资源，各自拥有独立的 RuntimeEventInstance
- **池化支持**: `_on_pool_reset()` 实现完整的池化生命周期

## 编辑器上下文菜单

MultiEventTrigger 提供了两个编辑器工具，通过场景树右键菜单访问：

### TriggerMerger - 合并多个 Trigger

- **文件**: `addons/fuse/editor/context_menu/trigger_merger.gd`
- **类名**: `TriggerMerger extends RefCounted`
- **功能**: 将多个 Trigger 节点合并为一个 MultiEventTrigger

#### 合并条件 (`can_merge`)

| 条件 | 说明 |
|------|------|
| 节点数 >= 2 | 至少需要 2 个 Trigger |
| 全部为 Trigger 类型 | 非 Trigger 节点会被拒绝 |
| 相同父节点 | 所有 Trigger 必须在同一父节点下 |

#### 合并流程 (`merge`)

```
1. 按场景树索引排序节点
2. 创建 MultiEventTrigger 节点
3. 为每个 Trigger 创建 EventBinding（深拷贝 event_definition + action_runner）
4. 验证绑定数据完整性
5. 注册 UndoRedo 操作
6. 删除原始 Trigger，添加 MultiEventTrigger
```

#### 属性映射

| Trigger 属性 | → EventBinding 属性 |
|-------------|-------------------|
| `event_definition` | `event` |
| `action_runner` | `action_runner` |
| `trigger_once` | `trigger_once` |
| `cooldown_mode` | `cooldown_mode` |
| `cooldown_time` | `cooldown_time` |
| — | `enabled = true`（默认启用） |

### TriggerSplitter - 拆分 MultiEventTrigger

- **文件**: `addons/fuse/editor/context_menu/trigger_splitter.gd`
- **类名**: `TriggerSplitter extends RefCounted`
- **功能**: 将 MultiEventTrigger 拆分为多个独立 Trigger

#### 拆分条件 (`can_split`)

| 条件 | 说明 |
|------|------|
| 类型为 MultiEventTrigger | 非 MultiEventTrigger 节点会被拒绝 |
| event_bindings >= 2 | 只有 1 个绑定时无法拆分 |

#### 拆分流程 (`split`)

```
1. 为每个 EventBinding 创建 Trigger 节点
2. 深拷贝 event + action_runner 到新 Trigger
3. 使用事件类名自动命名 Trigger（如 OnInputKey、OnSceneReady）
4. 重名时自动添加序号后缀（OnInputKey_2）
5. 注册 UndoRedo 操作
6. 删除 MultiEventTrigger，添加多个 Trigger
```

### UndoRedo 支持

| 操作 | Undo | Redo |
|------|------|------|
| 合并 (Merge) | 恢复所有原始 Trigger（含属性和位置） | 重新合并为 MultiEventTrigger |
| 拆分 (Split) | 恢复 MultiEventTrigger（含所有绑定） | 重新拆分为多个 Trigger |

### 上下文菜单入口

- **文件**: `addons/fuse/editor/context_menu/fuse_context_menu_plugin.gd`
- 菜单选项：
  - 选中多个 Trigger → "合并为 MultiEventTrigger"
  - 选中 MultiEventTrigger → "拆分为多个 Trigger"
  - 另有"生成指令"选项（配合 InstructionGenerator 使用）
