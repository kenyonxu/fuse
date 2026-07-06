# OnMouseEnter RuntimeEventInstance 状态迁移

## 修改日期
2026-02-03

## 目标
将 OnMouseEnter 事件类的运行时状态从共享的 Event 资源迁移到独立的 RuntimeEventInstance，实现完全的状态隔离。

## 问题背景

### 旧架构的问题
```gdscript
# 旧代码（存在状态共享问题）
extends BaseEvent
class_name OnMouseEnter

var _is_hovered: bool = false  # ❌ 共享状态，多个 Trigger 会相互覆盖
var _owner_node_ref: Node = null  # ❌ 共享引用
```

**问题场景：**
- 场景中有两个按钮：start 和 continue
- 两个按钮都使用同一个 OnMouseEnter 事件资源
- 鼠标悬停在 start 按钮上：
  - start 的 Trigger 调用 `initialize()`，设置 `_is_hovered = true`
  - continue 的 Trigger 也使用同一个事件资源，`_is_hovered` 也变成了 true
- 结果：continue 按钮也会响应，即使鼠标并没有悬停在它上面

### 新架构的解决方案
```gdscript
# 新代码（状态完全隔离）
extends BaseEvent
class_name OnMouseEnter

# 🔧 运行时状态现在存储在 RuntimeEventInstance 中
var _runtime_instance_ref: RuntimeEventInstance = null
```

**新架构：**
```
旧架构：
OnMouseEnter (Resource)
  └─ _is_hovered (共享状态) ❌

新架构：
OnMouseEnter (Resource)
  └─ _runtime_instance_ref → RuntimeEventInstance
        └─ runtime_state["is_hovered"] (独立状态) ✅
```

## 修改内容

### 1. 删除共享的状态变量
**位置：** `addons/fuse/events/input/on_mouse_enter.gd:22-23`

**删除：**
```gdscript
var _is_hovered: bool = false
var _owner_node_ref: Node = null
```

**替换为：**
```gdscript
# 🔧 运行时状态现在存储在 RuntimeEventInstance 中，不再在 Event 资源中存储状态
# 每个 Trigger 通过 runtime_instance 访问独立的状态
var _runtime_instance_ref: RuntimeEventInstance = null
```

### 2. 添加新的初始化方法
**位置：** `addons/fuse/events/input/on_mouse_enter.gd:109-151`

**新增方法：**
```gdscript
## 🔧 使用 RuntimeEventInstance 初始化事件
##
## 这是推荐的方法，通过 RuntimeEventInstance 管理运行时状态
##
## 参数：
## - owner_node: Node - 拥有此事件的 Trigger 节点
## - runtime_instance: RuntimeEventInstance - 运行时事件实例
func initialize_with_runtime_instance(owner_node: Node, runtime_instance: RuntimeEventInstance) -> void:
	if Engine.is_editor_hint():
		_log_debug("编辑器模式下，跳过事件初始化")
		return

	# 保存 RuntimeEventInstance 引用
	_runtime_instance_ref = runtime_instance

	# 验证 owner_node
	if not owner_node:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NULL", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# 验证目标节点路径
	if target_node_path.is_empty():
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_EMPTY", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# 🔧 动态解析目标节点
	var target_node = owner_node.get_node_or_null(target_node_path)
	if not target_node:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", FuseError.ErrorType.CONFIGURATION_ERROR, {"node_path": str(target_node_path)})
		return

	# 验证节点类型
	if not _is_valid_target_type(target_node):
		_create_fuse_error_localized("FUSE_ERROR_INVALID_TARGET", FuseError.ErrorType.CONFIGURATION_ERROR, {
			"node_path": str(target_node_path),
			"expected_types": "Control, CollisionObject2D, 或 CollisionObject3D"
		})
		return

	# 根据节点类型连接相应的信号
	_connect_hover_signals(target_node, owner_node)

	_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})
```

### 3. 修改 `_on_mouse_entered_with_context()` 使用 RuntimeEventInstance 状态
**位置：** `addons/fuse/events/input/on_mouse_enter.gd:221-265`

**关键修改：**

**旧代码：**
```gdscript
# 检查是否只触发一次
if trigger_once_per_enter and _is_hovered:
	_log_debug_localized("FUSE_LOG_EVENT_ALREADY_ENTERED", {})
	return

_is_hovered = true
```

**新代码：**
```gdscript
# 🔧 使用 RuntimeEventInstance 的状态（如果可用）
var is_hovered: bool = false
if _runtime_instance_ref and _runtime_instance_ref.has_runtime_state("is_hovered"):
	is_hovered = _runtime_instance_ref.get_runtime_state("is_hovered")
else:
	# 回退：使用向后兼容的模式（不应该发生，但作为安全措施）
	is_hovered = false

# 检查是否只触发一次
if trigger_once_per_enter and is_hovered:
	_log_debug_localized("FUSE_LOG_EVENT_ALREADY_ENTERED", {})
	return

# 🔧 更新 RuntimeEventInstance 的状态
if _runtime_instance_ref:
	_runtime_instance_ref.set_runtime_state("is_hovered", true)
	# 更新触发统计
	_runtime_instance_ref.update_trigger_stats()
```

### 4. 修改 `terminate()` 清理 RuntimeEventInstance 状态
**位置：** `addons/fuse/events/input/on_mouse_enter.gd:73-107`

**关键修改：**

**旧代码：**
```gdscript
# 清理引用
_owner_node_ref = null
_is_hovered = false
```

**新代码：**
```gdscript
# 🔧 清理 RuntimeEventInstance 的状态
if _runtime_instance_ref:
	_runtime_instance_ref.set_runtime_state("is_hovered", false)

# 清理引用
_runtime_instance_ref = null
```

### 5. 修改 `initialize()` 方法
**位置：** `addons/fuse/events/input/on_mouse_enter.gd:42-71`

**关键修改：**
- 移除对 `_owner_node_ref` 的赋值
- 直接使用传入的 `owner_node` 参数解析目标节点

**旧代码：**
```gdscript
_owner_node_ref = owner_node
var target_node = _get_target_node()
```

**新代码：**
```gdscript
# 🔧 动态解析目标节点（使用传入的 owner_node 参数）
var target_node = owner_node.get_node_or_null(target_node_path)
```

### 6. 修改 `reset()` 方法
**位置：** `addons/fuse/events/input/on_mouse_enter.gd:300-306`

**旧代码：**
```gdscript
func reset() -> void:
	super.reset()
	_is_hovered = false
	_log_debug_localized("FUSE_LOG_EVENT_RESET", {"event_type": get_event_type()})
```

**新代码：**
```gdscript
func reset() -> void:
	super.reset()
	# 🔧 重置 RuntimeEventInstance 的状态
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("is_hovered", false)
	_log_debug_localized("FUSE_LOG_EVENT_RESET", {"event_type": get_event_type()})
```

### 7. 删除 `_get_target_node()` 方法
**位置：** `addons/fuse/events/input/on_mouse_enter.gd:213-224`

**原因：** 该方法依赖已删除的 `_owner_node_ref`，现在直接使用参数传入的 `owner_node`

## RuntimeEventInstance 状态初始化

**位置：** `addons/fuse/core/runtime_event_instance.gd:69-73`

RuntimeEventInstance 已经在初始化时为 `mouse_enter` 事件类型设置了运行时状态：

```gdscript
"mouse_enter":
	runtime_state["is_hovered"] = false
	runtime_state["initialized"] = true
	runtime_state["trigger_count"] = 0
	runtime_state["last_trigger_time"] = 0.0
```

## 向后兼容性

### 旧的 `initialize()` 方法保留
- 旧的 `initialize()` 方法仍然存在，保持向后兼容
- 如果 Trigger 调用 `initialize()` 而不是 `initialize_with_runtime_instance()`，事件仍然可以工作
- 但是在这种情况下，状态隔离不会被使用（向后兼容模式）

### 新的 `initialize_with_runtime_instance()` 方法
- Trigger 现在调用 `initialize_with_runtime_instance()` 方法（在 `trigger.gd:54`）
- 这是推荐的方法，提供完全的状态隔离

## 测试验证

### 测试场景
**文件：** `demos/fuse/btn_title_option.tscn`

该场景包含：
- 一个按钮节点（Button）
- MouseEnter Trigger（使用 OnMouseEnter 事件）
- MouseExit Trigger（使用 OnMouseExit 事件）
- 鼠标进入时：打印消息并放大到 1.25 倍
- 鼠标离开时：缩小回 1.0 倍

### 测试步骤
1. 在 Godot 编辑器中打开 `demos/fuse/brick_ui_demo.tscn`
2. 运行场景
3. 鼠标悬停在 start 按钮上：
   - **预期：** 只有 start 按钮放大
   - **预期：** 控制台输出 "鼠标进入: start" 消息
4. 鼠标移出 start 按钮：
   - **预期：** start 按钮缩小回原始大小
5. 鼠标悬停在 continue 按钮上：
   - **预期：** 只有 continue 按钮放大
   - **预期：** 控制台输出 "鼠标进入: continue" 消息
6. 鼠标移出 continue 按钮：
   - **预期：** continue 按钮缩小回原始大小

### 预期结果
- ✅ 每个按钮的行为完全独立
- ✅ 鼠标悬停在一个按钮上，不会影响其他按钮
- ✅ 状态完全隔离，互不干扰

## 架构优势

### 1. 完全的状态隔离
- 每个 Trigger 有独立的 RuntimeEventInstance
- 每个实例有独立的 `runtime_state` 字典
- 多个 Trigger 共享同一个 Event 资源时，状态不会相互覆盖

### 2. 内存优化
- RuntimeEventInstance 是轻量级的 RefCounted 对象
- 避免了复制整个 Event 资源
- 只复制运行时状态，不复制配置数据

### 3. 数据与逻辑分离
- Event 资源：只包含配置（数据）
- RuntimeEventInstance：只包含运行时状态（状态）
- 符合"数据与逻辑分离"的架构原则

### 4. 可扩展性
- 其他事件类型（OnMouseExit, OnInterval 等）可以采用同样的模式
- RuntimeEventInstance 可以根据事件类型初始化特定的运行时状态
- 统一的状态管理接口

## 后续工作

### OnMouseExit 迁移
OnMouseExit 也有同样的问题，需要进行类似的状态迁移：

**需要修改的变量：**
- `_has_exited: bool = false` → 迁移到 `runtime_state["has_exited"]`
- `_owner_node_ref: Node = null` → 删除

**需要添加的方法：**
- `initialize_with_runtime_instance()` 方法

### 其他事件类型的迁移
根据需要，其他事件类型也可以采用相同的模式进行迁移。

## 相关文件

- `addons/fuse/events/input/on_mouse_enter.gd` - 修改的主要文件
- `addons/fuse/core/runtime_event_instance.gd` - RuntimeEventInstance 类
- `addons/fuse/core/trigger.gd` - Trigger 节点（调用 `initialize_with_runtime_instance()`）
- `addons/fuse/core/base/base_event.gd` - BaseEvent 基类
- `demos/fuse/btn_title_option.tscn` - 测试场景
- `demos/fuse/brick_ui_demo.tscn` - 主演示场景

## 提交信息

```
refactor(mouse-enter): 使用 RuntimeEventInstance 管理状态，实现完全隔离

修改内容：
- 删除共享状态变量 (_is_hovered, _owner_node_ref)
- 添加 initialize_with_runtime_instance() 方法
- 修改 _on_mouse_entered_with_context() 使用 RuntimeEventInstance 状态
- 修改 terminate() 和 reset() 清理 RuntimeEventInstance 状态
- 删除 _get_target_node() 方法（不再需要）

解决的问题：
- 多个 Trigger 共享同一个 OnMouseEnter 资源时，状态会相互覆盖
- 导致错误的按钮响应（例如鼠标悬停在 start 上，continue 也响应）

架构优势：
- 状态完全隔离，每个 Trigger 有独立的 RuntimeEventInstance
- 符合"数据与逻辑分离"架构原则
- 内存优化，避免不必要的资源复制

相关文件：
- addons/fuse/events/input/on_mouse_enter.gd
- addons/fuse/core/runtime_event_instance.gd
```
