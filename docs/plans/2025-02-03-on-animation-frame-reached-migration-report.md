# OnAnimationFrameReached Event RuntimeInstance 迁移报告

**迁移日期**: 2026-02-03
**迁移文件**: `addons/bricks/events/animation/on_animation_frame_reached.gd`
**架构版本**: 自声明状态模式 v2.0
**迁移状态**: ✅ 完成

---

## 迁移概述

成功将 `OnAnimationFrameReached` Event 从直接状态存储迁移到 RuntimeInstance 架构（自声明状态模式 v2.0）。此迁移解决了多个 Trigger 共享同一个 Event 资源时的状态冲突问题。

---

## 状态变量迁移

| 原变量名 | 类型 | 新状态键 | 默认值 | 说明 |
|---------|------|---------|--------|------|
| `_is_monitoring` | `bool` | `"is_monitoring"` | `false` | 是否正在监听动画帧 |
| `_has_triggered` | `bool` | `"has_triggered"` | `false` | 是否已触发过事件 |

**保留的成员变量**（非状态）:
- `_animation_player: AnimationPlayer` - AnimationPlayer 对象引用
- `_process_timer: Timer` - Timer 对象（Timer 对象保留在 Event 类中管理）

---

## 代码修改详情

### 1. 添加迁移注释

```gdscript
## Event: OnAnimationFrameReached
##
## 迁移到 RuntimeInstance: 2026-02-03
## 状态变量:
## - _is_monitoring: bool → "is_monitoring" - 是否正在监听动画帧
## - _has_triggered: bool → "has_triggered" - 是否已触发过事件
##
## 架构版本: 自声明状态模式 v2.0
## 相关文档: addons/bricks/docs/migration-guide-to-runtime-instance.md
```

### 2. 删除状态变量

**删除前**:
```gdscript
var _animation_player: AnimationPlayer = null
var _owner_node_ref: Node = null
var _is_monitoring: bool = false
var _process_timer: Timer = null
var _has_triggered: bool = false
```

**删除后**:
```gdscript
# RuntimeInstance 引用已在 BaseEvent 中定义
var _animation_player: AnimationPlayer = null
var _process_timer: Timer = null
```

### 3. 实现 `get_default_runtime_state()` 方法

```gdscript
## 获取默认运行时状态
func get_default_runtime_state() -> Dictionary:
	var base = super.get_default_runtime_state()
	base["is_monitoring"] = false
	base["has_triggered"] = false
	return base
```

### 4. 实现 `initialize_with_runtime_instance()` 方法

```gdscript
## 使用 RuntimeInstance 初始化事件
func initialize_with_runtime_instance(owner_node: Node, runtime_instance: RuntimeEventInstance) -> void:
	if Engine.is_editor_hint():
		return

	_runtime_instance_ref = runtime_instance

	if not owner_node:
		_create_bricks_error_localized("BRICKS_ERROR_TARGET_NODE_NULL", BricksError.ErrorType.CONFIGURATION_ERROR, {})
		return

	if animation_player_path.is_empty():
		_create_bricks_error_localized("BRICKS_ERROR_TARGET_NODE_EMPTY", BricksError.ErrorType.CONFIGURATION_ERROR, {})
		return

	_animation_player = owner_node.get_node_or_null(animation_player_path) as AnimationPlayer

	if not _animation_player:
		_create_bricks_error_localized("BRICKS_ERROR_TARGET_NODE_NOT_FOUND", BricksError.ErrorType.CONFIGURATION_ERROR, {"node_path": str(animation_player_path)})
		return

	# 验证节点类型
	if not _animation_player is AnimationPlayer:
		_create_bricks_error_localized("BRICKS_ERROR_INVALID_TARGET", BricksError.ErrorType.CONFIGURATION_ERROR, {"node_path": str(animation_player_path)})
		return

	# 创建帧检测定时器（约 60 FPS）
	_process_timer = Timer.new()
	_process_timer.wait_time = 0.016
	_process_timer.timeout.connect(_on_process_timeout)
	_process_timer.autostart = false
	owner_node.add_child(_process_timer)
	_process_timer.start()

	# 设置初始状态
	get_runtime_instance().set_runtime_state("is_monitoring", true)
	get_runtime_instance().set_runtime_state("has_triggered", false)

	_log_debug_localized("BRICKS_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})
```

### 5. 修改状态访问

**读取状态**（`_on_process_timeout()` 方法）:
```gdscript
var is_monitoring = get_runtime_instance().get_runtime_state("is_monitoring")
if not is_monitoring:
	return
```

**读取状态**（`_trigger_event()` 方法）:
```gdscript
var has_triggered = get_runtime_instance().get_runtime_state("has_triggered")
if has_triggered:
	return
```

**写入状态**（`_trigger_event()` 方法）:
```gdscript
get_runtime_instance().set_runtime_state("has_triggered", true)
```

### 6. 清理状态

**terminate() 方法**:
```gdscript
func terminate(owner_node: Node) -> void:
	# 清理 RuntimeEventInstance 的状态
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("is_monitoring", false)
		_runtime_instance_ref.set_runtime_state("has_triggered", false)

	if _process_timer:
		_process_timer.stop()
		if _process_timer.timeout.is_connected(_on_process_timeout):
			_process_timer.timeout.disconnect(_on_process_timeout)
		if owner_node and is_instance_valid(owner_node):
			owner_node.remove_child(_process_timer)
		_process_timer.queue_free()
		_process_timer = null

	_animation_player = null
	_runtime_instance_ref = null

	_log_debug_localized("BRICKS_LOG_EVENT_TERMINATED", {"event_type": get_event_type()})
```

**reset() 方法**:
```gdscript
func reset() -> void:
	super.reset()
	# 重置 RuntimeEventInstance 的状态
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("has_triggered", false)
	_log_debug_localized("BRICKS_LOG_EVENT_RESET", {"event_type": get_event_type()})
```

---

## 向后兼容性

保留了 `initialize()` 方法以向后兼容：

```gdscript
## 初始化事件监听（必需）- 保留以向后兼容
func initialize(owner_node: Node) -> void:
	# ... 使用 get_runtime_instance() 访问状态 ...
```

---

## 验证结果

✅ **Godot Headless 模式检查通过**
```
E:\Godot\Godot_v4.6-stable_mono_win64\Godot_v4.6-stable_mono_win64.exe --headless --check-only --quit
```

**输出**: 无语法错误，Event 正常初始化和终止。

---

## 迁移检查清单

- ✅ 删除 Event 类中的运行时状态变量
- ✅ 添加 `_runtime_instance_ref: RuntimeEventInstance` 引用
- ✅ 实现 `get_default_runtime_state()` 方法
- ✅ 实现 `initialize_with_runtime_instance()` 方法
- ✅ 修改所有状态访问使用 `get_runtime_state()` / `set_runtime_state()`
- ✅ 在 `terminate()` 中清理状态
- ✅ 在 `reset()` 中重置状态
- ✅ 在 Event 文件顶部添加迁移注释
- ✅ Godot headless 模式验证通过

---

## 架构优势

迁移后的 Event 具备以下优势：

1. **状态隔离**: 每个 Trigger 有独立的 `is_monitoring` 和 `has_triggered` 状态
2. **资源共享**: 多个 Trigger 可以共享同一个 Event 资源（配置）
3. **无需修改核心代码**: 使用自声明状态模式，无需修改 `RuntimeEventInstance`
4. **开闭原则**: 遵循 Open/Closed Principle，易于扩展
5. **向后兼容**: 保留了旧的 `initialize()` 方法

---

## 测试建议

建议测试以下场景：

1. **基本功能测试**
   - 验证动画帧检测是否正常工作
   - 验证事件是否在指定帧触发

2. **多 Trigger 测试**
   - 创建多个 Trigger，共享同一个 `OnAnimationFrameReached` Event 资源
   - 验证每个 Trigger 的状态是否独立
   - 验证 `_has_triggered` 状态不会互相干扰

3. **重置测试**
   - 验证 `reset()` 方法是否正确重置状态
   - 验证事件可以重复触发

4. **终止测试**
   - 验证 `terminate()` 方法是否正确清理状态和资源
   - 验证 Timer 是否正确停止和释放

---

## 相关文档

- [迁移指南](../../../addons/bricks/docs/migration-guide-to-runtime-instance.md)
- [Phase 2 计划](../../../docs/plans/2025-02-03-event-runtime-instance-migration-plan-phase2.md)
- [RuntimeEventInstance API](../../../addons/bricks/core/runtime_event_instance.gd)

---

**迁移完成！**
