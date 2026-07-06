# Runner Node 设计文档

> **STATUS: ✅ 已实现** (2026-06-26 归档) — 实现见 [runner.gd](../../../core/runner.gd)(432 行),完整落地 run/stop/cancel/wait_completed/is_running/信号绑定 全部 API。

## 概述

`Runner` 是一个可以直接通过方法调用和信号绑定驱动 ActionRunner 的 Node。它本质上是 `Trigger` 移除事件驱动部分后的轻量级版本。

## 动机

当前 Fuse 系统中，`Trigger` 是唯一驱动 `ActionRunner` 执行的方式，但它必须绑定 `BaseEvent` 资源。某些场景下，用户只需要：

1. **代码直接调用** - 在 GDScript 中直接调用 `run()` 执行动作序列
2. **信号响应** - 绑定到任意节点的信号，信号触发时执行

这些场景不需要复杂的事件系统（如碰撞检测、输入事件等），`Runner` 就是为了满足这些需求而设计。

## 与 Trigger 的对比

| 特性 | Trigger | Runner |
|------|---------|--------|
| **驱动方式** | Event 驱动 | 方法调用 / 信号绑定 |
| **Event 相关** | ✅ BaseEvent, RuntimeEventInstance | ❌ 无 |
| **ActionRunner** | ✅ 支持 | ✅ 支持 |
| **RuntimeActionRunnerInstance** | ✅ 独立实例 | ✅ 独立实例 |
| **ExecutionContext target** | 事件触发节点 | self |
| **冷却系统** | ✅ 支持 | ❌ 无 |
| **trigger_once** | ✅ 支持 | ❌ 无 |
| **信号绑定** | ❌ 无 | ✅ target_node + signal_name |
| **代码调用** | trigger_manually() | run() |

## 类设计

### 类结构

```gdscript
@tool
@icon("res://addons/fuse/icons/runner.svg")
class_name Runner extends Node
```

### 导出属性

```gdscript
@export_group("Action Runner")
## 要执行的 ActionRunner 资源
@export var action_runner: ActionRunner

@export_group("Signal Binding")
## 自动绑定信号的目标节点
@export var target_node: NodePath = NodePath("")

## 要绑定的信号名称
@export var signal_name: String = ""

@export_group("Configuration")
## 日志级别
@export var log_level: FuseLogger.LogLevel = FuseLogger.LogLevel.INFO

@export_group("Execution")
## 是否覆盖 ActionRunner 的执行模式
@export var override_execution_mode: bool = false

## 执行模式（当 override_execution_mode 为 true 时生效）
@export var execution_mode: ActionRunner.ExecutionMode = ActionRunner.ExecutionMode.SEQUENTIAL
```

### 信号

```gdscript
## 执行完成信号
signal execution_completed(total_time: float)

## 执行失败信号
signal execution_failed(error_message: String)

## 执行取消信号
signal execution_canceled(reason: String)
```

### 公共方法

```gdscript
## 执行 ActionRunner
func run() -> void

## 停止当前执行
func stop() -> void

## 取消执行（带原因）
func cancel(reason: String = "") -> void

## 是否正在执行
func is_running() -> bool

## 是否正在取消
func is_canceling() -> bool

## 获取执行状态详情
func get_execution_status() -> Dictionary

## 重置状态
func reset() -> void

## 等待执行完成（awaitable）
func wait_completed() -> void
```

### 内部状态

```gdscript
## RuntimeActionRunnerInstance 实例
var _runtime_instance: RuntimeActionRunnerInstance = null

## 信号绑定的目标节点
var _bound_node: Node = null

## 信号是否已连接
var _signal_connected: bool = false

## RuntimeActionRunnerInstance 信号是否已连接
var _runtime_signals_connected: bool = false
```

## 实现细节

### 生命周期

```gdscript
func _ready() -> void:
    if Engine.is_editor_hint():
        return

    # 创建 RuntimeActionRunnerInstance
    if action_runner:
        _runtime_instance = RuntimeActionRunnerInstance.new(action_runner, self)
        _connect_runtime_signals()

    # 自动绑定信号
    _setup_signal_binding()

func _exit_tree() -> void:
    _disconnect_signal_binding()
    _disconnect_runtime_signals()

    if _runtime_instance:
        _runtime_instance.cleanup()
        _runtime_instance = null
```

### 执行上下文创建

```gdscript
func _create_execution_context() -> ExecutionContext:
    var context = ExecutionContext.new(self, self)
    context.log_level = log_level
    return context
```

ExecutionContext 的 `target` 和 `source` 都是 `self`（Runner 节点本身）。

### 信号绑定

```gdscript
func _setup_signal_binding() -> void:
    if target_node.is_empty() or signal_name.is_empty():
        return

    _bound_node = get_node_or_null(target_node)
    if not _bound_node:
        _log_warning("Target node not found: %s" % target_node)
        return

    # 检查信号是否存在
    var signal_list = _bound_node.get_signal_list()
    var has_signal = false
    for sig in signal_list:
        if sig["name"] == signal_name:
            has_signal = true
            break

    if not has_signal:
        _log_warning("Signal '%s' not found on node '%s'" % [signal_name, _bound_node.name])
        return

    # 连接信号
    if not _bound_node.is_connected(signal_name, _on_bound_signal):
        _bound_node.connect(signal_name, _on_bound_signal)
        _signal_connected = true

func _on_bound_signal() -> void:
    run()

func _disconnect_signal_binding() -> void:
    if _signal_connected and _bound_node and is_instance_valid(_bound_node):
        if _bound_node.is_connected(signal_name, _on_bound_signal):
            _bound_node.disconnect(signal_name, _on_bound_signal)
    _signal_connected = false
    _bound_node = null
```

### 核心执行

```gdscript
func run() -> void:
    if not action_runner:
        _log_warning("No ActionRunner assigned")
        return

    if not _runtime_instance:
        _runtime_instance = RuntimeActionRunnerInstance.new(action_runner, self)
        _connect_runtime_signals()

    if _runtime_instance.is_running():
        _log_warning("Runner is already running")
        return

    var context = _create_execution_context()

    # 应用执行模式覆盖
    if override_execution_mode:
        # 临时覆盖执行模式
        var original_mode = action_runner.execution_mode
        action_runner.execution_mode = execution_mode
        _runtime_instance.run(context)
        action_runner.execution_mode = original_mode
    else:
        _runtime_instance.run(context)
```

## 使用示例

### 示例 1：代码直接调用

```gdscript
# 在场景中添加 Runner 节点，配置 ActionRunner
@onready var runner: Runner = $Runner

func _on_enemy_died():
    runner.run()

func _on_combo_complete():
    if not runner.is_running():
        runner.run()
    else:
        runner.cancel("Combo interrupted")
```

### 示例 2：信号绑定

```gdscript
# 在编辑器中配置：
# - target_node: ^Button
# - signal_name: "pressed"
# - action_runner: PlaySoundAction

# 当按钮按下时，自动执行 PlaySoundAction
```

### 示例 3：等待执行完成

```gdscript
func play_cutscene():
    runner.run()
    await runner.wait_completed()
    # 或者
    await runner.execution_completed
    print("Cutscene finished")
```

## 与 Trigger 的选择指南

**使用 Trigger 当：**
- 需要基于游戏事件触发（碰撞、输入、生命周期等）
- 需要冷却系统控制触发频率
- 需要 trigger_once 行为
- 事件触发节点需要作为 ExecutionContext 的 target

**使用 Runner 当：**
- 需要代码直接调用执行动作序列
- 需要绑定到简单信号（如按钮点击）
- 不需要复杂的事件系统
- 希望以 Runner 节点自身作为 target

## 文件位置

```
addons/fuse/core/runner.gd
```

## 实现清单

- [x] 创建 `runner.gd` 文件
- [x] 实现核心属性和信号
- [x] 实现 `_ready()` 和 `_exit_tree()` 生命周期
- [x] 实现信号绑定机制
- [x] 实现 `run()`、`stop()`、`cancel()` 方法
- [x] 实现状态查询方法
- [x] 添加日志支持
- [x] 创建 Runner 图标（使用 Play.svg）
- [x] 添加本地化翻译键
- [x] 编写测试用例

## 状态

- **创建日期**: 2026-03-09
- **完成日期**: 2026-03-09
- **状态**: 已实现
- **作者**: Claude
