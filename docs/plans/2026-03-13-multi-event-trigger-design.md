# MultiEventTrigger 设计文档

## 问题

每颗子弹需要 8 个节点，其中 4 个是 Trigger 子节点：

```
EnemyBullet (Area2D)
├── CollisionShape2D
├── AnimatedSprite2D
└── BulletController (ScopeVariableContainer)
    ├── OnReady (Trigger)
    ├── OnUpdate (Trigger)
    ├── OnArea2dEnter (Trigger)
    └── OnWallHit (Trigger)
```

场景中 100 颗子弹 = 400 个 Trigger 节点，每个都携带：
- `_runtime_event_instance: RuntimeEventInstance`
- `_runtime_action_runner_instance: RuntimeActionRunnerInstance`
- 信号连接、状态管理

## 方案

用一个 `MultiEventTrigger` 节点替代多个 `Trigger` 节点：

```
EnemyBullet (Area2D)
├── CollisionShape2D
├── AnimatedSprite2D
└── BulletController (ScopeVariableContainer)
    └── MultiEventTrigger
```

100 颗子弹 = 100 个 MultiEventTrigger 节点，节点数从 400 降到 100。

## 核心类

### EventBinding

单个 Event + ActionRunner 的配置单元：

```gdscript
@tool
class_name EventBinding extends Resource

## 冷却模式
enum CooldownMode {
    NONE,               ## 无冷却
    GLOBAL_COOLDOWN,    ## 全局冷却
    PER_OBJECT_COOLDOWN ## 每物体独立冷却
}

@export var event: BaseEvent
@export var action_runner: ActionRunner
@export var enabled: bool = true
@export var trigger_once: bool = false
@export var cooldown_mode: CooldownMode = CooldownMode.NONE
@export_range(0.0, 60.0, 0.1) var cooldown_time: float = 0.0
```

### MultiEventTrigger

管理多个 EventBinding 的运行时执行：

```gdscript
@tool
class_name MultiEventTrigger extends Node

@export var event_bindings: Array[EventBinding] = []
@export var pool_mode: bool = false
@export var log_level: BricksLogger.LogLevel = BricksLogger.LogLevel.NONE

# 运行时实例（一一对应 event_bindings）
var _runtime_event_instances: Array[RuntimeEventInstance] = []
var _runtime_action_instances: Array[RuntimeActionRunnerInstance] = []
var _has_triggered: Array[bool] = []
var _signal_connected: Array[bool] = []
```

## 执行流程

```
_ready()
    │
    ├── pool_mode? ──Yes──► 跳过初始化
    │
    No
    │
    ▼
_initialize_runtime_instances()
    │
    ├── 遍历 event_bindings
    │       │
    │       ├── 创建 RuntimeEventInstance
    │       ├── 创建 RuntimeActionRunnerInstance
    │       └── 连接 triggered 信号
    │
    ▼
_start_all_events()
    │
    └── 调用每个 RuntimeEventInstance.start_listening()
```

事件触发时：

```
RuntimeEventInstance.triggered
    │
    ▼
_on_event_fired(context, index)
    │
    ├── trigger_once 检查
    ├── is_running 检查
    ├── cooldown 检查 (支持 GLOBAL/PER_OBJECT 模式)
    │
    ▼
RuntimeActionRunnerInstance.run(execution_context)
```

## 引擎回调转发

MultiEventTrigger 必须将 Godot 引擎回调转发给所有 EventBinding：

### _process / _physics_process

```gdscript
func _process(delta: float) -> void:
    for i: int in range(event_bindings.size()):
        var binding: EventBinding = event_bindings[i]
        if binding.event != null and binding.event.has_method("on_process"):
            var event_instance: RuntimeEventInstance = _runtime_event_instances[i]
            binding.event.on_process(delta, event_instance)

func _physics_process(delta: float) -> void:
    for i: int in range(event_bindings.size()):
        var binding: EventBinding = event_bindings[i]
        if binding.event != null and binding.event.has_method("on_physics_process"):
            var event_instance: RuntimeEventInstance = _runtime_event_instances[i]
            binding.event.on_physics_process(delta, event_instance)
```

### _notification

```gdscript
func _notification(what: int) -> void:
    if what == NOTIFICATION_PROCESS or what == NOTIFICATION_PHYSICS_PROCESS:
        for i: int in range(event_bindings.size()):
            var binding: EventBinding = event_bindings[i]
            if binding.event == null:
                continue
            if what == NOTIFICATION_PROCESS:
                if binding.event.has_method("handle_process_notification"):
                    binding.event.handle_process_notification()
            elif what == NOTIFICATION_PHYSICS_PROCESS:
                if binding.event.has_method("handle_physics_process_notification"):
                    binding.event.handle_physics_process_notification()
```

### _unhandled_input

```gdscript
func _unhandled_input(event: InputEvent) -> void:
    for binding: EventBinding in event_bindings:
        if binding.event != null and binding.event.has_method("handle_input"):
            binding.event.handle_input(event)
```

## 冷却模式

与原 Trigger 保持一致的三种模式：

| 模式 | 行为 |
|------|------|
| `NONE` | 无冷却，每次都触发 |
| `GLOBAL_COOLDOWN` | 触发后所有物体都需要等待冷却时间 |
| `PER_OBJECT_COOLDOWN` | 每个物体有独立的冷却计时器 |

冷却检查实现：

```gdscript
func _check_cooldown(index: int, context: Node) -> bool:
    var binding: EventBinding = event_bindings[index]
    if binding.cooldown_mode == CooldownMode.NONE or binding.cooldown_time <= 0.0:
        return true

    var event_instance: RuntimeEventInstance = _runtime_event_instances[index]
    if event_instance == null:
        return true

    var current_time := Time.get_ticks_msec() / 1000.0

    match binding.cooldown_mode:
        CooldownMode.GLOBAL_COOLDOWN:
            var last_time: float = event_instance.runtime_state.get("last_trigger_time", 0.0)
            if current_time - last_time < binding.cooldown_time:
                return false
            event_instance.runtime_state["last_trigger_time"] = current_time

        CooldownMode.PER_OBJECT_COOLDOWN:
            var object_cooldowns: Dictionary = event_instance.runtime_state.get("object_cooldowns", {})
            var object_id: int = context.get_instance_id() if context else 0
            if object_id != 0 and object_cooldowns.has(object_id):
                var last_time: float = object_cooldowns[object_id]
                if current_time - last_time < binding.cooldown_time:
                    return false
            object_cooldowns[object_id] = current_time
            event_instance.runtime_state["object_cooldowns"] = object_cooldowns

    return true
```

## 池化支持

对象池复用时调用 `pool_reset()`：

```gdscript
func pool_reset() -> void:
    # 1. 重置状态
    for i in range(_has_triggered.size()):
        _has_triggered[i] = false

    # 2. 禁用处理
    set_physics_process(false)
    set_process(false)

    # 3. 终止并清理
    _stop_all_events()
    _cleanup_runtime_instances()

    # 4. 重新初始化
    _initialize_runtime_instances()
    _start_all_events()

    # 5. 启用处理
    set_physics_process(true)
    set_process(true)
```

## 验证与手动控制

### validate()

```gdscript
func validate() -> Array[String]:
    var errors: Array[String] = []
    for i: int in range(event_bindings.size()):
        var binding: EventBinding = event_bindings[i]
        if binding.event == null:
            errors.append("EventBinding[%d]: event 未配置" % i)
        if binding.action_runner == null:
            errors.append("EventBinding[%d]: action_runner 未配置" % i)
        if binding.event != null:
            errors.append_array(binding.event.validate())
    return errors
```

### reset()

```gdscript
func reset() -> void:
    for i: int in range(_has_triggered.size()):
        _has_triggered[i] = false

    for i: int in range(event_bindings.size()):
        var binding: EventBinding = event_bindings[i]
        if binding.event != null:
            binding.event.reset()

    # 清理冷却状态
    for event_instance: RuntimeEventInstance in _runtime_event_instances:
        if event_instance != null:
            event_instance.runtime_state.erase("last_trigger_time")
            event_instance.runtime_state.erase("object_cooldowns")
```

### trigger_manually()

```gdscript
func trigger_manually(index: int, context: Node = null) -> void:
    if index < 0 or index >= event_bindings.size():
        return
    _on_event_fired(context, index)
```

### set_binding_enabled()

```gdscript
func set_binding_enabled(index: int, enabled: bool) -> void:
    if index < 0 or index >= event_bindings.size():
        return

    event_bindings[index].enabled = enabled

    var event_instance: RuntimeEventInstance = _runtime_event_instances[index]
    if event_instance != null:
        if enabled:
            event_instance.start_listening()
        else:
            event_instance.stop_listening()
```

## 编辑器支持

不需要额外的 Inspector 插件：

| 属性 | 编辑器支持 |
|------|-----------|
| `Array[EventBinding]` | Godot 原生数组编辑器 |
| `event: BaseEvent` | `bricks_inspector_plugin` 已支持 |
| `action_runner: ActionRunner` | Godot 原生 Resource 编辑器 |
| `enabled: bool` | Godot 原生复选框 |
| `cooldown_mode` | Godot 原生枚举下拉框 |

## 性能对比

| 指标 | 之前 | 之后 |
|------|------|------|
| 节点数/子弹 | 8 | 5 |
| Trigger 节点/子弹 | 4 | 1 (MultiEventTrigger) |
| 100 颗子弹节点数 | 800 | 500 |

## 文件结构

```
addons/bricks/core/
├── event_binding.gd          # EventBinding 资源类
└── multi_event_trigger.gd    # MultiEventTrigger 节点类
```

## 迁移步骤

1. 创建 `event_binding.gd` 和 `multi_event_trigger.gd`
2. 在 `enemy_bullet.tscn` 中：
   - 删除 4 个 Trigger 子节点
   - 添加 1 个 MultiEventTrigger 节点
   - 配置 4 个 EventBinding
3. 测试池化功能

## API 参考

### MultiEventTrigger

| 方法 | 描述 |
|------|------|
| `pool_reset()` | 对象池复用时重置所有状态 |
| `reset()` | 重置触发状态和冷却状态 |
| `validate() -> Array[String]` | 验证配置，返回错误列表 |
| `trigger_manually(index, context)` | 手动触发指定绑定 |
| `set_binding_enabled(index, enabled)` | 动态启用/禁用指定绑定 |

| 信号 | 描述 |
|------|------|
| `event_completed(binding_index, context)` | ActionRunner 执行完成 |
| `event_stopped(binding_index, reason, context)` | ActionRunner 停止或失败 |

### EventBinding

| 属性 | 类型 | 描述 |
|------|------|------|
| `event` | `BaseEvent` | 事件定义 |
| `action_runner` | `ActionRunner` | 动作运行器 |
| `enabled` | `bool` | 是否启用 |
| `trigger_once` | `bool` | 是否只触发一次 |
| `cooldown_mode` | `CooldownMode` | 冷却模式 |
| `cooldown_time` | `float` | 冷却时间（秒） |

---

**日期**: 2026-03-13
**状态**: 设计完成，待实现
