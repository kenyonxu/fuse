# RuntimeInstance 架构迁移 - 批次 5

**迁移日期**: 2026-02-03
**架构版本**: 自声明状态模式 v2.0
**相关文档**: `addons/bricks/docs/migration-guide-to-runtime-instance.md`

## 迁移概述

本批次成功迁移了 **5 个 Bricks Events** 到 RuntimeInstance 架构。这些 Events 涵盖了游戏玩法、时间控制和补间动画等领域。

## 迁移的 Events

### 1. OnHealthChanged (`addons/bricks/events/gameplay/on_health_changed.gd`)

**功能**: 监听目标节点的生命值变化，支持多级阈值触发（低生命值、危急、耗尽）

**迁移的状态变量**:
- `last_health_value` (float) - 上次生命值
- `has_triggered_low` (bool) - 是否已触发低生命值
- `has_triggered_critical` (bool) - 是否已触发危急生命值
- `has_triggered_depleted` (bool) - 是否已触发生命值耗尽

**特殊处理**:
- 保留了 `_timer` 对象在 Event 类中（不存储在 RuntimeEventInstance）
- 保留了节点引用（`_target_node_ref`）在 Event 类中
- 使用轮询 Timer 检查生命值变化
- 支持四种触发模式的动态状态管理

### 2. OnSoundListened (`addons/bricks/events/gameplay/on_sound_listened.gd`)

**功能**: 检测声音是否被监听器"听到"（基于距离和方向，可选视线检测）

**迁移的状态变量**:
- `check_timer` (float) - 检查计时器
- `was_heard` (bool) - 上次是否听到
- `has_triggered_once` (bool) - 是否已触发一次

**特殊处理**:
- 在 `on_process()` 中更新 `check_timer` 状态
- 支持三种触发模式（听到、听不到、状态改变）
- 保留节点引用（`_sound_source_ref`, `_listener_ref`）在 Event 类中
- 使用 PhysicsRayQueryParameters3D 进行视线检测

### 3. OnRealtime (`addons/bricks/events/timing/on_realtime.gd`)

**功能**: 按实际时间触发事件（不受 Engine.time_scale 影响）

**迁移的状态变量**:
- `trigger_count` (int) - 触发次数计数器

**特殊处理**:
- 使用 `Timer.ignore_time_scale = true` 实现不受时间缩放影响的计时
- 支持最大触发次数限制
- 保留 `_timer` 对象在 Event 类中
- 等待节点进入场景树后再启动定时器

### 4. OnTweenCompleted (`addons/bricks/events/tween/on_tween_completed.gd`)

**功能**: Tween 补间动画完成时触发

**迁移的状态变量**:
- `is_monitoring` (bool) - 是否正在监听

**特殊处理**:
- 连接 Tween 的 `finished` 信号（Godot 4.6）
- 保留 `_tween` 引用和 `_owner_node_ref` 在 Event 类中
- 最简单的状态管理（仅需一个布尔标志）

### 5. OnCountdown (`addons/bricks/events/timing/on_countdown.gd`)

**功能**: 倒计时事件，支持进度更新和暂停/恢复

**迁移的状态变量**:
- `remaining_time` (float) - 剩余时间
- `is_completed` (bool) - 是否已完成
- `is_running` (bool) - 是否正在运行

**特殊处理**:
- 使用两个 Timer（主倒计时定时器 + 进度更新定时器）
- 提供外部控制方法（`start_countdown()`, `pause_countdown()`, `resume_countdown()`, `reset_countdown()`）
- 提供查询方法（`get_remaining_time()`, `is_running()`, `is_completed()`）
- 所有 Timer 对象保留在 Event 类中

## 迁移模式总结

### 核心变更

所有 Events 都实现了以下核心方法：

#### 1. `get_default_runtime_state()`
```gdscript
func get_default_runtime_state() -> Dictionary:
    var base = super.get_default_runtime_state()
    base["状态键"] = 默认值
    return base
```

#### 2. `initialize_with_runtime_instance()`
```gdscript
func initialize_with_runtime_instance(owner_node: Node, runtime_instance: RuntimeEventInstance) -> void:
    if Engine.is_editor_hint():
        return

    _runtime_instance_ref = runtime_instance

    # ... 验证和初始化逻辑 ...

    # 初始化运行时状态
    _runtime_instance_ref.set_runtime_state("key", value)
```

#### 3. 状态读取模式
```gdscript
var value: bool = false
if _runtime_instance_ref.has_runtime_state("key"):
    value = _runtime_instance_ref.get_runtime_state("key")
```

#### 4. 状态写入模式
```gdscript
if _runtime_instance_ref:
    _runtime_instance_ref.set_runtime_state("key", new_value)
```

#### 5. 状态清理模式（在 `terminate()` 和 `reset()` 中）
```gdscript
if _runtime_instance_ref:
    _runtime_instance_ref.set_runtime_state("key", default_value)
```

### 保留在 Event 类中的内容

✅ **保留**:
- Timer 对象（`_timer`, `_main_timer`, `_update_timer`）
- 节点引用（`_target_node_ref`, `_owner_node_ref`, `_tween`, 等）
- 配置变量（所有 `@export` 变量）
- 枚举类型

❌ **迁移到 RuntimeEventInstance**:
- 运行时状态标志（bool）
- 计数器（int, float）
- 临时存储值

## 验证检查清单

- [x] 所有 Events 都实现了 `get_default_runtime_state()`
- [x] 所有 Events 都实现了 `initialize_with_runtime_instance()`
- [x] 所有状态变量都通过 `_runtime_instance_ref` 访问
- [x] 在 `terminate()` 中清理状态
- [x] 在 `reset()` 中重置状态
- [x] 添加了迁移注释和文档链接
- [x] 删除了原始的状态变量声明
- [x] 使用 TAB 缩进
- [x] 检查 `Engine.is_editor_hint()`

## 测试建议

### OnHealthChanged
- 测试四种触发模式（ON_CHANGE, ON_LOW, ON_CRITICAL, ON_DEPLETED）
- 测试低/危急阈值的交叉验证逻辑
- 测试状态重置后阈值标记是否正确重置

### OnSoundListened
- 测试三种触发模式
- 测试距离计算（2D 和 3D 节点）
- 测试视线检测功能
- 测试状态变化时的触发逻辑

### OnRealtime
- 测试实际时间触发（不受 time_scale 影响）
- 测试最大触发次数限制
- 测试暂停游戏后仍能触发

### OnTweenCompleted
- 测试 Tween 完成时正确触发
- 测试 `terminate()` 后不再触发
- 测试多个 Tween 并发的情况

### OnCountdown
- 测试自动启动和手动启动
- 测试暂停/恢复功能
- 测试进度更新触发
- 测试重置功能
- 测试状态查询方法

## 后续工作

- 在真实游戏场景中测试这些 Events
- 验证与 Instructions 的集成
- 检查性能影响（特别是轮询类型的 Events）
- 更新用户文档

## 相关文件

- `addons/bricks/events/gameplay/on_health_changed.gd`
- `addons/bricks/events/gameplay/on_sound_listened.gd`
- `addons/bricks/events/timing/on_realtime.gd`
- `addons/bricks/events/tween/on_tween_completed.gd`
- `addons/bricks/events/timing/on_countdown.gd`

---

**迁移完成度**: 5/5 Events ✅
**代码质量**: 符合项目编码规范
**架构一致性**: 完全符合 RuntimeInstance v2.0 架构
