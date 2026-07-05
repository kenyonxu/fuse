# Bricks Events Phase 4 Development Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 完成 8 个高优先级 Bricks 事件，将事件完成度从 52% 提升到 62%（42 → 50 事件）

**Architecture:** 基于 BaseEvent 基类，遵循事件目录分类，每个事件包含：事件类文件、测试脚本、测试场景、本地化翻译，代码质量目标 100/100

**Tech Stack:** Godot 4.6, GDScript 2.0, BaseEvent 系统，TDD 开发模式，规范合规性审查流程

---

## 开发原则

### 核心原则
- **DRY** - 复用现有事件代码模式
- **YAGNI** - 只实现必要功能
- **TDD** - 先写测试，再实现代码
- **频繁提交** - 每个事件完成后立即 commit
- **规范审查** - 每个事件通过双重审查（规范合规 + 代码质量）

### 参考文档
- **开发指南**: `@addons/bricks/docs/development/event_creation_guide.md` - **必须严格遵循**
- **路线图**: `@addons/bricks/docs/roadmap/2026-01-25-bricks-event-roadmap.md`
- **评估报告**: `@addons/bricks/docs/roadmap/2026-01-25-bricks-event-evaluation-report-v2.md`
- **Phase 3 参考**: `@docs/plans/2026-01-29-bricks-event-phase-3-development.md`

### 质量标准
- 每个 `@abstract` 方法必须实现
- `initialize()` 中验证参数、连接信号/设置监听、记录初始化日志
- `terminate()` 中断开信号、清理资源（Timer → stop → disconnect → remove_child → queue_free）
- 所有用户可见文本使用 `tr()` 本地化
- 信号连接前检查 `is_connected()`
- 使用 `is_instance_valid()` 检查节点有效性
- 避免使用三元运算符（`?:`），使用 if-else
- 使用 Tab 缩进，类型注解完整

### 代码审查流程
1. **实现阶段** - 子代理实现事件
2. **规范审查** - 检查是否符合 event_creation_guide.md
3. **修复改进** - 子代理修复发现的问题
4. **质量审查** - 确保达到 100/100 评分
5. **Git 提交** - 规范的 commit message

---

## Phase 4A: 信号和场景事件（2 个事件）

**目标**: 补充基础设施，完成 P1 级剩余核心事件

### Task 1: On Tween Completed（Tween 补间动画完成）

**优先级**: 🔴 高（P1 级，53.0 分，高频需求）

**目录**: `addons/bricks/events/tween/`

**参考**: `on_animation_finished.gd` 的实现模式

**Files:**
- Create: `addons/bricks/events/tween/on_tween_completed.gd`
- Create: `addons/bricks/tests/events/test_on_tween_completed.gd`
- Create: `addons/bricks/tests/events/test_on_tween_completed.tscn`
- Modify: `addons/bricks/localization/translations.csv`

**Step 1: 添加本地化翻译**

在 `translations.csv` 末尾添加：

```csv
# Phase 04 - On Tween Completed Event
BRICKS_EVENT_ON_TWEEN_COMPLETED_NAME,Tween 完成,Tween Completed
BRICKS_EVENT_ON_TWEEN_COMPLETED_DESC,Tween 补间动画完成时触发,Triggers when Tween animation completes
BRICKS_LOG_EVENT_TWEEN_COMPLETED,Tween 完成事件触发，节点：{node},Tween completed event triggered, node: {node}
BRICKS_ERROR_TWEEN_NODE_NOT_FOUND,未找到 Tween 节点：{node_path},Tween node not found: {node_path}
BRICKS_DESC_TWEEN_COMPLETED,监听 Tween：,Monitoring Tween:
BRICKS_TEXT_NOT_SPECIFIED,未指定,Not Specified
```

**Step 2: 创建事件类**

创建 `addons/bricks/events/tween/on_tween_completed.gd`：

```gdscript
@tool
@icon("res://addons/bricks/icons/builtin/Tween.svg")
extends BaseEvent
class_name OnTweenCompleted

## Tween 补间动画完成时触发

## 目标 Tween 节点路径
@export var tween_node_path: NodePath = NodePath(""):
	set(value):
		tween_node_path = value
		_update_resource_name()

var _tween: Tween = null
var _owner_node_ref: Node = null

## 更新资源名称（必需）
func _update_resource_name() -> void:
	var path_text = str(tween_node_path) if not tween_node_path.is_empty() else tr("BRICKS_TEXT_NOT_SPECIFIED")
	resource_name = "Tween Completed: %s" % path_text

## 初始化事件监听（必需）
func initialize(owner_node: Node) -> void:
	if not owner_node:
		_create_bricks_error_localized("BRICKS_ERROR_TARGET_NODE_NULL", BricksError.ErrorType.CONFIGURATION_ERROR, {})
		return

	_owner_node_ref = owner_node

	if tween_node_path.is_empty():
		_create_bricks_error_localized("BRICKS_ERROR_TARGET_NODE_EMPTY", BricksError.ErrorType.CONFIGURATION_ERROR, {})
		return

	_tween = owner_node.get_node_or_null(tween_node_path) as Tween

	if not _tween:
		_create_bricks_error_localized("BRICKS_ERROR_TWEEN_NODE_NOT_FOUND", BricksError.ErrorType.CONFIGURATION_ERROR, {
			"node_path": str(tween_node_path)
		})
		return

	if not _tween.tween_completed.is_connected(_on_tween_completed):
		_tween.tween_completed.connect(_on_tween_completed)

	_log_debug_localized("BRICKS_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

## Tween 完成回调
func _on_tween_completed() -> void:
	if not is_monitoring:
		return

	_log_debug_localized("BRICKS_LOG_EVENT_TWEEN_COMPLETED", {
		"node": _tween.name
	})

	var context = {
		"node": _tween
	}
	triggered.emit(context)

## 清理事件监听（必需）
func terminate(owner_node: Node) -> void:
	if _tween and is_instance_valid(_tween):
		if _tween.tween_completed.is_connected(_on_tween_completed):
			_tween.tween_completed.disconnect(_on_tween_completed)

	_tween = null
	_owner_node_ref = null

	_log_debug_localized("BRICKS_LOG_EVENT_TERMINATED", {"event_type": get_event_type()})

## 获取事件描述
func get_description() -> String:
	return "监听 Tween 补间动画完成"

## 获取事件类型
func get_event_type() -> String:
	return "tween_completed"

## 获取事件分类
func get_event_category() -> String:
	return "tween"

## 验证事件配置
func validate() -> Array[String]:
	var errors: Array[String] = []

	if tween_node_path.is_empty():
		errors.append(tr("BRICKS_ERROR_TARGET_NODE_EMPTY"))

	return errors

## 重置事件状态
func reset() -> void:
	super.reset()
	_log_debug_localized("BRICKS_LOG_EVENT_RESET", {"event_type": get_event_type()})

## 获取事件元数据
static func _get_event_metadata() -> EventMetadata:
	var metadata = EventMetadata.new()
	metadata.name_key = "BRICKS_EVENT_ON_TWEEN_COMPLETED_NAME"
	metadata.category_key = "BRICKS_EVENT_CATEGORY_TWEEN"
	metadata.description_key = "BRICKS_EVENT_ON_TWEEN_COMPLETED_DESC"
	metadata.keywords = ["tween", "补间", "animation", "动画", "completed", "完成", "finished", "结束"]
	metadata.builtin_icon = "Tween"
	return metadata
```

**Step 3: 创建测试场景**

创建 `addons/bricks/tests/events/test_on_tween_completed.tscn`：

```gdscript
[gd_scene load_steps=2 format=3 uid="uid://test_on_tween_completed"]

[ext_resource type="Script" path="res://addons/bricks/tests/events/test_on_tween_completed.gd" id="1"]

[node name="TestOnTweenCompleted" type="Node"]
script = ExtResource("1")

[node name="TestSprite" type="Sprite2D" parent="."]
position = Vector2(100, 100)
```

**Step 4: 创建测试脚本**

创建 `addons/bricks/tests/events/test_on_tween_completed.gd`：

```gdscript
extends Node

## OnTweenCompleted 事件测试

@onready var test_sprite = $TestSprite

func _ready():
	print("=== Testing OnTweenCompleted ===")
	test_tween_completion()
	test_termination()
	cleanup()
	print("=== All OnTweenCompleted tests passed! ===")

func test_tween_completion():
	print("Test 1: Tween completion detection")

	var tween = create_tween()
	var event_script = load("res://addons/bricks/events/tween/on_tween_completed.gd")
	var event = event_script.new()
	event.tween_node_path = NodePath("../TestTween")

	add_child(tween)
	var trigger = Node.new()
	add_child(trigger)

	var triggered = false
	event.triggered.connect(func(_context):
		triggered = true
	)

	event.initialize(trigger)
	await get_tree().process_frame

	# 执行 Tween
	tween.tween_property(test_sprite, "position", Vector2(200, 200), 1.0)
	await get_tree().create_timer(1.5).timeout

	assert(triggered, "Event should trigger when tween completes")
	print("  ✓ Test 1 passed: Tween completion detection works\n")

	event.terminate(trigger)
	trigger.queue_free()
	tween.queue_free()

func test_termination():
	print("Test 2: Termination and cleanup")

	var tween = create_tween()
	var event_script = load("res://addons/bricks/events/tween/on_tween_completed.gd")
	var event = event_script.new()
	event.tween_node_path = NodePath("../TestTween")

	add_child(tween)
	var trigger = Node.new()
	add_child(trigger)

	event.initialize(trigger)
	await get_tree().process_frame

	# 验证信号已连接
	assert(tween.tween_completed.is_connected(event._on_tween_completed), "tween_completed should be connected")

	# 终止事件
	event.terminate(trigger)

	# 验证信号已断开
	assert(not tween.tween_completed.is_connected(event._on_tween_completed), "tween_completed should be disconnected")
	assert(event._tween == null, "Tween reference should be cleared")
	print("  ✓ Test 2 passed: Termination works\n")

	event.terminate(trigger)
	trigger.queue_free()
	tween.queue_free()

func cleanup():
	# 清理测试资源
	pass

func create_tween() -> Tween:
	var tween = Tween.new()
	tween.name = "TestTween"
	add_child(tween)
	return tween
```

**Step 5: 验证实现**

运行: 在 Godot 中打开 `test_on_tween_completed.tscn` 并按 F5 运行

Expected:
- 所有测试通过
- 控制台输出 "All OnTweenCompleted tests passed!"

**Step 6: Commit**

```bash
cd e:\Godot\GodotProjects\project-juicy-godot
git add addons/bricks/events/tween/on_tween_completed.gd
git add addons/bricks/tests/events/test_on_tween_completed.*
git add addons/bricks/localization/translations.csv
git commit -m "feat(tween): add OnTweenCompleted event

- 监听 Tween 补间动画完成
- 支持 Tween.tween_completed 信号
- 完整的测试覆盖和本地化支持

Phase 4A: Signal/Scene Events - Task 1"
```

---

### Task 2: On Scene About To Change（场景切换前）

**优先级**: 🔴 高（P2 级，53.5 分，游戏必备功能）

**目录**: `addons/bricks/events/scene/`

**参考**: `on_scene_loaded.gd` 的实现模式

**Files:**
- Create: `addons/bricks/events/scene/on_scene_about_to_change.gd`
- Create: `addons/bricks/tests/events/test_on_scene_about_to_change.gd`
- Create: `addons/bricks/tests/events/test_on_scene_about_to_change.tscn`
- Modify: `addons/bricks/localization/translations.csv`

**Step 1: 添加本地化翻译**

在 `translations.csv` 末尾添加：

```csv
# Phase 04 - On Scene About To Change Event
BRICKS_EVENT_ON_SCENE_ABOUT_TO_CHANGE_NAME,场景切换前,Scene About To Change
BRICKS_EVENT_ON_SCENE_ABOUT_TO_CHANGE_DESC,场景切换前触发，用于保存数据,Triggers before scene changes, for saving data
BRICKS_LOG_EVENT_SCENE_ABOUT_TO_CHANGE,场景切换事件触发，目标场景：{scene},Scene change event triggered, target scene: {scene}
BRICKS_DESC_SCENE_ABOUT_TO_CHANGE,监听场景切换,Monitoring scene changes
```

**Step 2: 创建事件类**

创建 `addons/bricks/events/scene/on_scene_about_to_change.gd`：

```gdscript
@tool
@icon("res://addons/bricks/icons/builtin/PackedScene.svg")
extends BaseEvent
class_name OnSceneAboutToChange

## 场景切换前触发

## 是否传递场景路径
@export var emit_scene_path: bool = false:
	set(value):
		emit_scene_path = value
		_update_resource_name()

var _owner_node_ref: Node = null
var _is_connected: bool = false

## 更新资源名称（必需）
func _update_resource_name() -> void:
	resource_name = "Scene About To Change"

## 初始化事件监听（必需）
func initialize(owner_node: Node) -> void:
	if not owner_node:
		_create_bricks_error_localized("BRICKS_ERROR_TARGET_NODE_NULL", BricksError.ErrorType.CONFIGURATION_ERROR, {})
		return

	_owner_node_ref = owner_node

	# 连接场景切换信号
	if not owner_node.tree_entered.is_connected(_on_tree_entered):
		owner_node.tree_entered.connect(_on_tree_entered)

	_setup_scene_monitoring()

	_log_debug_localized("BRICKS_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

## 设置场景监听
func _setup_scene_monitoring() -> void:
	if not _owner_node_ref:
		return

	if _owner_node_ref.is_inside_tree():
		_connect_scene_signal()
	else:
		# 等待进入场景树后再连接
		if not _owner_node_ref.tree_entered.is_connected(_on_tree_entered):
			_owner_node_ref.tree_entered.connect(_on_tree_entered)

func _connect_scene_signal() -> void:
	if not _is_connected:
		get_tree().root.about_to_disconnect_from_scene().connect(_on_scene_about_to_change)
		_is_connected = true

## 当节点进入场景树
func _on_tree_entered() -> void:
	_setup_scene_monitoring()

## 场景切换前回调
func _on_scene_about_to_change() -> void:
	if not is_monitoring:
		return

	var target_scene = "未知"
	if emit_scene_path and get_tree().current_scene:
		target_scene = get_tree().current_scene.scene_file_path

	_log_debug_localized("BRICKS_LOG_EVENT_SCENE_ABOUT_TO_CHANGE", {
		"scene": target_scene
	})

	var context = {
		"scene_path": target_scene
	}
	triggered.emit(context)

## 清理事件监听（必需）
func terminate(owner_node: Node) -> void:
	if _is_connected:
		if get_tree():
			get_tree().root.about_to_disconnect_from_scene().disconnect(_on_scene_about_to_change)
		_is_connected = false

	if owner_node and owner_node.tree_entered.is_connected(_on_tree_entered):
		owner_node.tree_entered.disconnect(_on_tree_entered)

	_owner_node_ref = null

	_log_debug_localized("BRICKS_LOG_EVENT_TERMINATED", {"event_type": get_event_type()})

## 获取事件描述
func get_description() -> String:
	return "监听场景切换前事件"

## 获取事件类型
func get_event_type() -> String:
	return "scene_about_to_change"

## 获取事件分类
func get_event_category() -> String:
	return "scene"

## 验证事件配置
func validate() -> Array[String]:
	var errors: Array[String] = []
	return errors

## 重置事件状态
func reset() -> void:
	super.reset()
	_connect_scene_signal()
	_log_debug_localized("BRICKS_LOG_EVENT_RESET", {"event_type": get_event_type()})

## 获取事件元数据
static func _get_event_metadata() -> EventMetadata:
	var metadata = EventMetadata.new()
	metadata.name_key = "BRICKS_EVENT_ON_SCENE_ABOUT_TO_CHANGE_NAME"
	metadata.category_key = "BRICKS_EVENT_CATEGORY_SCENE"
	metadata.description_key = "BRICKS_EVENT_ON_SCENE_ABOUT_TO_CHANGE_DESC"
	metadata.keywords = ["scene", "场景", "change", "切换", "save", "保存", "load", "加载", "transition", "过渡"]
	metadata.builtin_icon = "PackedScene"
	return metadata
```

**Step 3-6: 创建测试场景、测试脚本、验证、提交**

（格式同 Task 1，创建测试场景和脚本，测试场景切换功能，提交代码）

---

## Phase 4B: 动画和音频扩展（3 个事件）

**目标**: 提升游戏表现力，扩展动画和音频事件

### Task 3: On Animation Frame Reached（动画帧到达）

**优先级**: 🟡 中高（P2 级，52.5 分，精确动画控制）

**目录**: `addons/bricks/events/animation/`

**参考**: `on_animation_marker.gd` 的实现模式

**Files:**
- Create: `addons/bricks/events/animation/on_animation_frame_reached.gd`
- Create: `addons/bricks/tests/events/test_on_animation_frame_reached.gd`
- Create: `addons/bricks/tests/events/test_on_animation_frame_reached.tscn`
- Modify: `addons/bricks/localization/translations.csv`

**Step 1: 添加本地化翻译**

```csv
# Phase 04 - On Animation Frame Reached Event
BRICKS_EVENT_ON_ANIMATION_FRAME_REACHED_NAME,动画帧到达,Animation Frame Reached
BRICKS_EVENT_ON_ANIMATION_FRAME_REACHED_DESC,动画播放到指定帧时触发,Triggers when animation reaches specified frame
BRICKS_LOG_EVENT_ANIMATION_FRAME_REACHED,动画帧到达事件触发：帧 {frame},Animation frame reached event triggered: frame {frame}
BRICKS_ERROR_FRAME_INDEX_INVALID,帧索引必须 >= 0,Frame index must be >= 0
BRICKS_DESC_ANIMATION_FRAME,帧 {frame},Frame {frame}
```

**Step 2: 创建事件类**

创建 `addons/bricks/events/animation/on_animation_frame_reached.gd`：

```gdscript
@tool
@icon("res://addons/bricks/icons/builtin/AnimationPlayer.svg")
extends BaseEvent
class_name OnAnimationFrameReached

## 动画播放到指定帧时触发

## 目标 AnimationPlayer 节点路径
@export var animation_player_path: NodePath = NodePath(""):
	set(value):
		animation_player_path = value
		_update_resource_name()

## 目标帧索引
@export_range(0, 10000) var target_frame: int = 0:
	set(value):
		target_frame = value
		_update_resource_name()

## 动画名称（空 = 当前动画）
@export var animation_name: String = "":
	set(value):
		animation_name = value
		_update_resource_name()

var _animation_player: AnimationPlayer = null
var _owner_node_ref: Node = null
var _is_monitoring: bool = false
var _process_timer: Timer = null

## 更新资源名称（必需）
func _update_resource_name() -> void:
	var player_text = str(animation_player_path) if not animation_player_path.is_empty() else tr("BRICKS_TEXT_NOT_SPECIFIED")
	var anim_text = animation_name if not animation_name.is_empty() else "<current>"
	resource_name = "Animation Frame %d: %s (%s)" % [target_frame, player_text, anim_text]

## 初始化事件监听（必需）
func initialize(owner_node: Node) -> void:
	if not owner_node:
		_create_bricks_error_localized("BRICKS_ERROR_TARGET_NODE_NULL", BricksError.ErrorType.CONFIGURATION_ERROR, {})
		return

	_owner_node_ref = owner_node

	if animation_player_path.is_empty():
		_create_bricks_error_localized("BRICKS_ERROR_TARGET_NODE_EMPTY", BricksError.ErrorType.CONFIGURATION_ERROR, {})
		return

	_animation_player = owner_node.get_node_or_null(animation_player_path) as AnimationPlayer

	if not _animation_player:
		_create_bricks_error_localized("BRICKS_ERROR_TARGET_NODE_NOT_FOUND", BricksError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# 创建帧检测定时器
	_process_timer = Timer.new()
	_process_timer.wait_time = 0.016  # 约 60 FPS
	_process_timer.timeout.connect(_on_process_timeout)
	_process_timer.autostart = false
	owner_node.add_child(_process_timer)
	_process_timer.start()

	_is_monitoring = true

	_log_debug_localized("BRICKS_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

## 定时检查帧位置
func _on_process_timeout() -> void:
	if not _animation_player or not is_instance_valid(_animation_player):
		return

	if not _animation_player.is_playing():
		return

	# 获取当前动画
	var current_anim = animation_name if not animation_name.is_empty() else _animation_player.current_animation
	var current_frame = _animation_player.get_animation_current_frame_position(current_anim)

	# 检查是否到达目标帧
	if current_frame >= float(target_frame):
		_trigger_event(current_frame)

## 触发事件
func _trigger_event(frame: float) -> void:
	_log_debug_localized("BRICKS_LOG_EVENT_ANIMATION_FRAME_REACHED", {
		"frame": str(int(frame))
	})

	var context = {
		"animation": _animation_player.current_animation,
		"frame": int(frame),
		"player": _animation_player
	}
	triggered.emit(context)

## 清理事件监听（必需）
func terminate(owner_node: Node) -> void:
	_is_monitoring = false

	if _process_timer:
		_process_timer.stop()
		if _process_timer.timeout.is_connected(_on_process_timeout):
			_process_timer.timeout.disconnect(_on_process_timeout)
		if owner_node and is_instance_valid(owner_node):
			owner_node.remove_child(_process_timer)
		_process_timer.queue_free()
		_process_timer = null

	_animation_player = null
	_owner_node_ref = null

	_log_debug_localized("BRICKS_LOG_EVENT_TERMINATED", {"event_type": get_event_type()})

## 获取事件描述
func get_description() -> String:
	return "监听动画帧到达，目标帧：%d" % target_frame

## 获取事件类型
func get_event_type() -> String:
	return "animation_frame_reached"

## 获取事件分类
func get_event_category() -> String:
	return "animation"

## 验证事件配置
func validate() -> Array[String]:
	var errors: Array[String] = []

	if target_frame < 0:
		errors.append(tr("BRICKS_ERROR_FRAME_INDEX_INVALID"))

	return errors

## 重置事件状态
func reset() -> void:
	super.reset()
	_is_monitoring = false
	if _owner_node_ref and is_instance_valid(_owner_node_ref):
		initialize(_owner_node_ref)
	_log_debug_localized("BRICKS_LOG_EVENT_RESET", {"event_type": get_event_type()})

## 获取事件元数据
static func _get_event_metadata() -> EventMetadata:
	var metadata = EventMetadata.new()
	metadata.name_key = "BRICKS_EVENT_ON_ANIMATION_FRAME_REACHED_NAME"
	metadata.category_key = "BRICKS_EVENT_CATEGORY_ANIMATION"
	metadata.description_key = "BRICKS_EVENT_ON_ANIMATION_FRAME_REACHED_DESC"
	metadata.keywords = ["animation", "动画", "frame", "帧", "position", "位置", "sync", "同步"]
	metadata.builtin_icon = "AnimationPlayer"
	return metadata
```

**Step 3-6: 创建测试场景、测试脚本、验证、提交**

（测试动画帧检测功能，提交代码）

---

### Task 4: On Animation Blend（动画混合）

**优先级**: 🟡 中（P2 级，52.0 分，混合检测）

**目录**: `addons/bricks/events/animation/`

**参考**: `on_animation_finished.gd` 的实现模式

**Files:**
- Create: `addons/bricks/events/animation/on_animation_blend.gd`
- Create: `addons/bricks/tests/events/test_on_animation_blend.gd`
- Create: `addons/bricks/tests/events/test_on_animation_blend.tscn`
- Modify: `addons/bricks/localization/translations.csv`

**Step 1: 添加本地化翻译**

```csv
# Phase 04 - On Animation Blend Event
BRICKS_EVENT_ON_ANIMATION_BLEND_NAME,动画混合,Animation Blend
BRICKS_EVENT_ON_ANIMATION_BLEND_DESC,检测 AnimationTree 混合权重变化,Detects AnimationTree blend weight changes
BRICKS_LOG_EVENT_ANIMATION_BLEND_TRIGGERED,动画混合事件触发：路径 {path},权重 {weight},Animation blend event triggered: path {path}, weight {weight}
BRICKS_ERROR_BLEND_PATH_INVALID,混合路径不能为空,Blend path cannot be empty
BRICKS_DESC_BLEND_THRESHOLD,阈值 {threshold},Threshold {threshold}
```

**Step 2: 创建事件类**

创建 `addons/bricks/events/animation/on_animation_blend.gd`：

```gdscript
@tool
@icon("res://addons/bricks/icons/builtin/AnimationTree.svg")
extends BaseEvent
class_name OnAnimationBlend

## 检测 AnimationTree 混合权重变化

## 目标 AnimationTree 节点路径
@export var animation_tree_path: NodePath = NodePath(""):
	set(value):
		animation_tree_path = value
		_update_resource_name()

## 混合路径（AnimationTree 的 blend 节点路径）
@export var blend_path: NodePath = NodePath(""):
	set(value):
		blend_path = value
		_update_resource_name()

## 权重阈值（0-1）
@export_range(0.0, 1.0, 0.01) var threshold: float = 0.5:
	set(value):
		threshold = value
		_update_resource_name()

## 比较方式
enum Comparison {
	GREATER_OR_EQUAL,  ## 大于等于
	LESS_OR_EQUAL,     ## 小于等于
	EQUAL               ## 等于
}

@export var comparison: Comparison = Comparison.GREATER_OR_EQUAL:
	set(value):
		comparison = value
		_update_resource_name()

var _animation_tree: AnimationTree = null
var _owner_node_ref: Node = null
var _is_monitoring: bool = false
var _process_timer: Timer = null
var _last_weight: float = -1.0

## 更新资源名称（必需）
func _update_resource_name() -> void:
	var path_text = str(blend_path) if not blend_path.is_empty() else "<blend_path>"
	var comp_text = ""
	match comparison:
		Comparison.GREATER_OR_EQUAL:
			comp_text = ">="
		Comparison.LESS_OR_EQUAL:
			comp_text = "<="
		Comparison.EQUAL:
			comp_text = "=="

	resource_name = "Animation Blend: %s (threshold %.2f %s)" % [path_text, threshold, comp_text]

## 初始化事件监听（必需）
func initialize(owner_node: Node) -> void:
	if not owner_node:
		_create_bricks_error_localized("BRICKS_ERROR_TARGET_NODE_NULL", BricksError.ErrorType.CONFIGURATION_ERROR, {})
		return

	_owner_node_ref = owner_node

	if animation_tree_path.is_empty():
		_create_bricks_error_localized("BRICKS_ERROR_TARGET_NODE_EMPTY", BricksError.ErrorType.CONFIGURATION_ERROR, {})
		return

	if blend_path.is_empty():
		_create_bricks_error_localized("BRICKS_ERROR_BLEND_PATH_INVALID", BricksError.ErrorType.CONFIGURATION_ERROR, {})
		return

	_animation_tree = owner_node.get_node_or_null(animation_tree_path) as AnimationTree

	if not _animation_tree:
		_create_bricks_error_localized("BRICKS_ERROR_TARGET_NODE_NOT_FOUND", BricksError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# 创建检测定时器
	_process_timer = Timer.new()
	_process_timer.wait_time = 0.1  # 每 0.1 秒检查一次
	_process_timer.timeout.connect(_on_process_timeout)
	_process_timer.autostart = false
	owner_node.add_child(_process_timer)
	_process_timer.start()

	_is_monitoring = true

	_log_debug_localized("BRICKS_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

## 定时检查混合权重
func _on_process_timeout() -> void:
	if not _animation_tree or not is_instance_valid(_animation_tree):
		return

	# 获取混合权重（使用 get_parameter）
	var weight = _animation_tree.get(blend_path + ":blend_amount")

	if weight == null:
		return

	# 检查是否应该触发
	var should_trigger = false
	match comparison:
		Comparison.GREATER_OR_EQUAL:
			should_trigger = weight >= threshold and _last_weight < threshold
		Comparison.LESS_OR_EQUAL:
			should_trigger = weight <= threshold and _last_weight > threshold
		Comparison.EQUAL:
			should_trigger = abs(weight - threshold) < 0.01 and _last_weight != threshold

	if should_trigger:
		_trigger_event(weight)

	_last_weight = weight

## 触发事件
func _trigger_event(weight: float) -> void:
	_log_debug_localized("BRICKS_LOG_EVENT_ANIMATION_BLEND_TRIGGERED", {
		"path": str(blend_path),
		"weight": str(weight)
	})

	var context = {
		"blend_path": str(blend_path),
		"weight": weight
	}
	triggered.emit(context)

## 清理事件监听（必需）
func terminate(owner_node: Node) -> void:
	_is_monitoring = false

	if _process_timer:
		_process_timer.stop()
		if _process_timer.timeout.is_connected(_on_process_timeout):
			_process_timer.timeout.disconnect(_on_process_timeout)
		if owner_node and is_instance_valid(owner_node):
			owner_node.remove_child(_process_timer)
		_process_timer.queue_free()
		_process_timer = null

	_animation_tree = null
	_owner_node_ref = null

	_log_debug_localized("BRICKS_LOG_EVENT_TERMINATED", {"event_type": get_event_type()})

## 获取事件描述
func get_description() -> String:
	return "检测动画混合权重变化，阈值：%.2f" % threshold

## 获取事件类型
func get_event_type() -> String:
	return "animation_blend"

## 获取事件分类
func get_event_category() -> String:
	return "animation"

## 验证事件配置
func validate() -> Array[String]:
	var errors: Array[String] = []

	if blend_path.is_empty():
		errors.append(tr("BRICKS_ERROR_BLEND_PATH_INVALID"))

	return errors

## 重置事件状态
func reset() -> void:
	super.reset()
	_last_weight = -1.0
	_is_monitoring = false
	if _owner_node_ref and is_instance_valid(_owner_node_ref):
		initialize(_owner_node_ref)
	_log_debug_localized("BRICKS_LOG_EVENT_RESET", {"event_type": get_event_type()})

## 获取事件元数据
static func _get_event_metadata() -> EventMetadata:
	var metadata = EventMetadata.new()
	metadata.name_key = "BRICKS_EVENT_ON_ANIMATION_BLEND_NAME"
	metadata.category_key = "BRICKS_EVENT_CATEGORY_ANIMATION"
	metadata.description_key = "BRICKS_EVENT_ON_ANIMATION_BLEND_DESC"
	metadata.keywords = ["animation", "动画", "blend", "混合", "weight", "权重", "tree", "树"]
	metadata.builtin_icon = "AnimationTree"
	return metadata
```

**Step 3-6: 创建测试、验证、提交**

---

### Task 5: On Music Beat（音乐节拍）

**优先级**: 🟡 中（P2 级，50.5 分，节奏游戏核心）

**目录**: `addons/bricks/events/audio/`

**参考**: `on_interval.gd` 的实现模式

**Files:**
- Create: `addons/bricks/events/audio/on_music_beat.gd`
- Create: `addons/bricks/tests/events/test_on_music_beat.gd`
- Create: `addons/bricks/tests/events/test_on_music_beat.tscn`
- Modify: `addons/bricks/localization/translations.csv`

**Step 1: 添加本地化翻译**

```csv
# Phase 04 - On Music Beat Event
BRICKS_EVENT_ON_MUSIC_BEAT_NAME,音乐节拍,Music Beat
BRICKS_EVENT_ON_MUSIC_BEAT_DESC,检测音乐节拍（BPM）,Detects music beats (BPM)
BRICKS_LOG_EVENT_MUSIC_BEAT_TRIGGERED,音乐节拍事件触发：节拍 {count},Music beat event triggered: beat {count}
BRICKS_ERROR_BPM_INVALID,BPM 必须大于 0,BPM must be greater than 0
BRICKS_DESC_MUSIC_BEAT,节拍 {bpm},Beat {bpm}
```

**Step 2: 创建事件类**

创建 `addons/bricks/events/audio/on_music_beat.gd`：

```gdscript
@tool
@icon("res://addons/bricks/icons/builtin/AudioStreamPlayer.svg")
extends BaseEvent
class_name OnMusicBeat

## 检测音乐节拍（BPM）

## BPM（每分钟节拍数）
@export_range(1.0, 300.0, 1.0) var bpm: float = 120.0:
	set(value):
		bpm = value
		_update_resource_name()

## 节拍间隔（1 = 每拍，4 = 每小节）
@export_range(1, 16) var beat_interval: int = 1:
	set(value):
		beat_interval = value
		_update_resource_name()

## 是否传递节拍数
@export var emit_beat_count: bool = false:
	set(value):
		emit_beat_count = value
		_update_resource_name()

var _beat_timer: float = 0.0
var _beat_count: int = 0
var _owner_node_ref: Node = null
var _is_monitoring: bool = false

## 更新资源名称（必需）
func _update_resource_name() -> void:
	resource_name = "Music Beat: %d BPM (every %d beats)" % [int(bpm), beat_interval]

## 初始化事件监听（必需）
func initialize(owner_node: Node) -> void:
	if not owner_node:
		_create_bricks_error_localized("BRICKS_ERROR_TARGET_NODE_NULL", BricksError.ErrorType.CONFIGURATION_ERROR, {})
		return

	_owner_node_ref = owner_node
	_is_monitoring = true
	_beat_count = 0
	_beat_timer = 0.0

	_log_debug_localized("BRICKS_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

## 物理帧处理（Godot 4.x 虚拟函数）
func _process(delta: float) -> void:
	if not _is_monitoring:
		return

	var beat_duration = 60.0 / bpm
	_beat_timer += delta

	if _beat_timer >= beat_duration * beat_interval:
		_beat_count += 1
		_beat_timer = 0.0
		_trigger_event()

## 触发事件
func _trigger_event() -> void:
	_log_debug_localized("BRICKS_LOG_EVENT_MUSIC_BEAT_TRIGGERED", {
		"count": str(_beat_count)
	})

	var context = {
		"beat_count": _beat_count
	}

	if emit_beat_count:
		context["beat_count"] = _beat_count

	triggered.emit(context)

## 清理事件监听（必需）
func terminate(owner_node: Node) -> void:
	_is_monitoring = false
	_beat_timer = 0.0
	_owner_node_ref = null

	_log_debug_localized("BRICKS_LOG_EVENT_TERMINATED", {"event_type": get_event_type()})

## 获取事件描述
func get_description() -> String:
	return "检测音乐节拍，BPM：%d，间隔：%d 拍" % [int(bpm), beat_interval]

## 获取事件类型
func get_event_type() -> String:
	return "music_beat"

## 获取事件分类
func get_event_category() -> String:
	return "audio"

## 验证事件配置
func validate() -> Array[String]:
	var errors: Array[String] = []

	if bpm <= 0:
		errors.append(tr("BRICKS_ERROR_BPM_INVALID"))

	return errors

## 重置事件状态
func reset() -> void:
	super.reset()
	_beat_count = 0
	_beat_timer = 0.0
	_is_monitoring = false
	if _owner_node_ref and is_instance_valid(_owner_node_ref):
		_is_monitoring = true
	_log_debug_localized("BRICKS_LOG_EVENT_RESET", {"event_type": get_event_type()})

## 获取事件元数据
static func _get_event_metadata() -> EventMetadata:
	var metadata = EventMetadata.new()
	metadata.name_key = "BRICKS_EVENT_ON_MUSIC_BEAT_NAME"
	metadata.category_key = "BRICKS_EVENT_CATEGORY_AUDIO"
	metadata.description_key = "BRICKS_EVENT_ON_MUSIC_BEAT_DESC"
	metadata.keywords = ["music", "音乐", "beat", "节拍", "bpm", "rhythm", "节奏", "timing", "时机"]
	metadata.builtin_icon = "AudioStreamPlayer"
	return metadata
```

**Step 3-6: 创建测试、验证、提交**

---

## Phase 4C: 碰撞和节点事件（3 个事件）

**目标**: 完善物理碰撞系统，支持复杂游戏逻辑

### Task 6: On Raycast Hit（射线检测命中）

**优先级**: 🟡 中高（P2 级，51.0 分，射击检测必备）

**目录**: `addons/bricks/events/physics/`

**参考**: `on_body_entered.gd` 的实现模式

**Files:**
- Create: `addons/bricks/events/physics/on_raycast_hit.gd`
- Create: `addons/bricks/tests/events/test_on_raycast_hit.gd`
- Create: `addons/bricks/tests/events/test_on_raycast_hit.tscn`
- Modify: `addons/bricks/localization/translations.csv`

**Step 1: 添加本地化翻译**

```csv
# Phase 04 - On Raycast Hit Event
BRICKS_EVENT_ON_RAYCAST_HIT_NAME,射线命中,Raycast Hit
BRICKS_EVENT_ON_RAYCAST_HIT_DESC,射线检测到碰撞体时触发,Triggers when raycast hits colliders
BRICKS_LOG_EVENT_RAYCAST_HIT,射线命中事件触发：碰撞体 {collider},Raycast hit event triggered: collider {collider}
BRICKS_ERROR_RAYCAST_TARGET_INVALID,射线目标节点无效,Raycast target node invalid
BRICKS_DESC_RAYCAST,射线,Raycast
```

**Step 2: 创建事件类**

创建 `addons/bricks/events/physics/on_raycast_hit.gd`：

```gdscript
@tool
@icon("res://addons/bricks/icons/builtin/RayCast2D.svg")
extends BaseEvent
class_name OnRaycastHit

## 射线检测到碰撞体时触发

## 射线原点（相对节点）
@export var origin_node_path: NodePath = NodePath(""):
	set(value):
		origin_node_path = value
		_update_resource_name()

## 射线目标位置（相对原点）
@export var target_position: Vector2 = Vector2(100, 0):
	set(value):
		target_position = value
		_update_resource_name()

## 碰撞层
@export_flags_2d_physics_layers var collision_layers: int = 1:
	set(value):
		collision_layers = value
		_update_resource_name()

## 是否传递碰撞点
@export var emit_collision_point: bool = false:
	set(value):
		emit_collision_point = value
		_update_resource_name()

var _origin_node: Node2D = null
var _owner_node_ref: Node = null
var _raycast: RayCast2D = null
var _is_monitoring: bool = false
var _process_timer: Timer = null

## 更新资源名称（必需）
func _update_resource_name() -> void:
	var origin_text = str(origin_node_path) if not origin_node_path.is_empty() else "<self>"
	resource_name = "Raycast Hit: %s → %s" % [origin_text, target_position]

## 初始化事件监听（必需）
func initialize(owner_node: Node) -> void:
	if not owner_node:
		_create_bricks_error_localized("BRICKS_ERROR_TARGET_NODE_NULL", BricksError.ErrorType.CONFIGURATION_ERROR, {})
		return

	_owner_node_ref = owner_node

	# 获取原点节点
	if not origin_node_path.is_empty():
		_origin_node = owner_node.get_node_or_null(origin_node_path) as Node2D
	else:
		_origin_node = owner_node as Node2D

	if not _origin_node:
		_create_bricks_error_localized("BRICKS_ERROR_RAYCAST_TARGET_INVALID", BricksError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# 创建 RayCast2D
	_raycast = RayCast2D.new()
	_raycast.target_position = target_position
	_raycast.collision_mask = collision_layers
	_raycast.enabled = true
	_origin_node.add_child(_raycast)

	# 创建检测定时器
	_process_timer = Timer.new()
	_process_timer.wait_time = 0.016  # 约 60 FPS
	_process_timer.timeout.connect(_on_process_timeout)
	_process_timer.autostart = false
	owner_node.add_child(_process_timer)
	_process_timer.start()

	_is_monitoring = true

	_log_debug_localized("BRICKS_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

## 定时检测射线
func _on_process_timeout() -> void:
	if not _raycast or not is_instance_valid(_raycast):
		return

	if _raycast.is_colliding():
		var collider = _raycast.get_collider()
		_trigger_event(collider)

## 触发事件
func _trigger_event(collider: Object) -> void:
	_log_debug_localized("BRICKS_LOG_EVENT_RAYCAST_HIT", {
		"collider": collider.name
	})

	var context = {
		"collider": collider
	}

	if emit_collision_point:
		context["collision_point"] = _raycast.get_collision_point()

	triggered.emit(context)

## 清理事件监听（必需）
func terminate(owner_node: Node) -> void:
	_is_monitoring = false

	if _process_timer:
		_process_timer.stop()
		if _process_timer.timeout.is_connected(_on_process_timeout):
			_process_timer.timeout.disconnect(_on_process_timeout)
		if owner_node and is_instance_valid(owner_node):
			owner_node.remove_child(_process_timer)
		_process_timer.queue_free()
		_process_timer = null

	if _raycast and is_instance_valid(_raycast):
		_raycast.queue_free()
		_raycast = null

	_origin_node = null
	_owner_node_ref = null

	_log_debug_localized("BRICKS_LOG_EVENT_TERMINATED", {"event_type": get_event_type()})

## 获取事件描述
func get_description() -> String:
	return "射线检测命中，目标位置：%s" % str(target_position)

## 获取事件类型
func get_event_type() -> String:
	return "raycast_hit"

## 获取事件分类
func get_event_category() -> String:
	return "physics"

## 验证事件配置
func validate() -> Array[String]:
	var errors: Array[String] = []
	return errors

## 重置事件状态
func reset() -> void:
	super.reset()
	_is_monitoring = false
	if _owner_node_ref and is_instance_valid(_owner_node_ref):
		initialize(_owner_node_ref)
	_log_debug_localized("BRICKS_LOG_EVENT_RESET", {"event_type": get_event_type()})

## 获取事件元数据
static func _get_event_metadata() -> EventMetadata:
	var metadata = EventMetadata.new()
	metadata.name_key = "BRICKS_EVENT_ON_RAYCAST_HIT_NAME"
	metadata.category_key = "BRICKS_EVENT_CATEGORY_PHYSICS"
	metadata.description_key = "BRICKS_EVENT_ON_RAYCAST_HIT_DESC"
	metadata.keywords = ["raycast", "射线", "hit", "命中", "detection", "检测", "line", "线"]
	metadata.builtin_icon = "RayCast2D"
	return metadata
```

**Step 3-6: 创建测试、验证、提交**

---

### Task 7: On Shape Cast（形状投射）

**优先级**: 🟡 中（P2 级，49.5 分，2D/3D 形状投射）

**目录**: `addons/bricks/events/physics/`

**参考**: `on_raycast_hit.gd` 的实现模式

**Files:**
- Create: `addons/bricks/events/physics/on_shape_cast.gd`
- Create: `addons/bricks/tests/events/test_on_shape_cast.gd`
- Create: `addons/bricks/tests/events/test_on_shape_cast.tscn`
- Modify: `addons/bricks/localization/translations.csv`

**Step 1: 添加本地化翻译**

```csv
# Phase 04 - On Shape Cast Event
BRICKS_EVENT_ON_SHAPE_CAST_NAME,形状投射,Shape Cast
BRICKS_EVENT_ON_SHAPE_CAST_DESC,形状投射检测碰撞,Detects collisions using shape casting
BRICKS_LOG_EVENT_SHAPE_CAST_TRIGGERED,形状投射事件触发：碰撞体 {collider},Shape cast event triggered: collider {collider}
BRICKS_ERROR_SHAPE_TARGET_INVALID,形状目标节点无效,Shape target node invalid
```

**Step 2: 创建事件类（支持 2D ShapeCast2D）**

创建 `addons/bricks/events/physics/on_shape_cast.gd`，实现类似 RayCast 的逻辑，但使用 ShapeCast2D。

**Step 3-6: 创建测试、验证、提交**

---

### Task 8: On Signal From Group（组信号监听）

**优先级**: 🟡 中高（P2 级，54.0 分，批量对象控制）

**目录**: `addons/bricks/events/node/`

**参考**: `on_target_signal_emit.gd` 的实现模式

**Files:**
- Create: `addons/bricks/events/node/on_signal_from_group.gd`
- Create: `addons/bricks/tests/events/test_on_signal_from_group.gd`
- Create: `addons/bricks/tests/events/test_on_signal_from_group.tscn`
- Modify: `addons/bricks/localization/translations.csv`

**Step 1: 添加本地化翻译**

```csv
# Phase 04 - On Signal From Group Event
BRICKS_EVENT_ON_SIGNAL_FROM_GROUP_NAME,组信号监听,Signal From Group
BRICKS_EVENT_ON_SIGNAL_FROM_GROUP_DESC,监听指定组中任意节点的信号,Monitors signals from any node in specified group
BRICKS_LOG_EVENT_SIGNAL_FROM_GROUP_TRIGGERED,组信号事件触发：节点 {node},信号 {signal},Group signal event triggered: node {node}, signal {signal}
BRICKS_ERROR_SIGNAL_NAME_INVALID,信号名称不能为空,Signal name cannot be empty
BRICKS_ERROR_GROUP_NAME_INVALID,组名不能为空,Group name cannot be empty
```

**Step 2: 创建事件类**

创建 `addons/bricks/events/node/on_signal_from_group.gd`：

```gdscript
@tool
@icon("res://addons/bricks/icons/builtin/Node.svg")
extends BaseEvent
class_name OnSignalFromGroup

## 监听指定组中任意节点的信号

## 信号名称
@export var signal_name: String = "":
	set(value):
		signal_name = value
		_update_resource_name()

## 节点组名
@export var group_name: String = "":
	set(value):
		group_name = value
		_update_resource_name()

## 是否传递节点引用
@export var emit_node: bool = false:
	set(value):
		emit_node = value
		_update_resource_name()

var _connected_nodes: Array[Node] = []
var _owner_node_ref: Node = null
var _is_monitoring: bool = false

## 更新资源名称（必需）
func _update_resource_name() -> void:
	var group_text = group_name if not group_name.is_empty() else "<group>"
	var signal_text = signal_name if not signal_name.is_empty() else "<signal>"
	resource_name = "Signal From Group: %s.%s" % [group_text, signal_text]

## 初始化事件监听（必需）
func initialize(owner_node: Node) -> void:
	if not owner_node:
		_create_bricks_error_localized("BRICKS_ERROR_TARGET_NODE_NULL", BricksError.ErrorType.CONFIGURATION_ERROR, {})
		return

	_owner_node_ref = owner_node

	if signal_name.is_empty():
		_create_bricks_error_localized("BRICKS_ERROR_SIGNAL_NAME_INVALID", BricksError.ErrorType.CONFIGURATION_ERROR, {})
		return

	if group_name.is_empty():
		_create_bricks_error_localized("BRICKS_ERROR_GROUP_NAME_INVALID", BricksError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# 连接组内所有节点的信号
	_connect_group_signals()

	_is_monitoring = true

	_log_debug_localized("BRICKS_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

## 连接组内节点的信号
func _connect_group_signals() -> void:
	var nodes = get_tree().get_nodes_in_group(group_name)

	for node in nodes:
		if not is_instance_valid(node):
			continue

		if not node.has_signal(signal_name):
			continue

		if not node.signal_name.is_connected(_on_signal_emitted):
			node.signal_name.connect(_on_signal_emitted)
			_connected_nodes.append(node)

## 信号发射回调
func _on_signal_emitted(args: Array = []) -> void:
	if not is_monitoring:
		return

	var emitting_node = get_tree().current_scene
	if not emitting_node:
		return

	_log_debug_localized("BRICKS_LOG_EVENT_SIGNAL_FROM_GROUP_TRIGGERED", {
		"node": emitting_node.name,
		"signal": signal_name
	})

	var context = {
		"node": emitting_node,
		"signal": signal_name
	}

	if emit_node:
		context["emitting_node"] = emitting_node

	triggered.emit(context)

## 清理事件监听（必需）
func terminate(owner_node: Node) -> void:
	_is_monitoring = false

	# 断开所有信号连接
	for node in _connected_nodes:
		if is_instance_valid(node) and node.has_signal(signal_name):
			if node.signal_name.is_connected(_on_signal_emitted):
				node.signal_name.disconnect(_on_signal_emitted)

	_connected_nodes.clear()
	_owner_node_ref = null

	_log_debug_localized("BRICKS_LOG_EVENT_TERMINATED", {"event_type": get_event_type()})

## 获取事件描述
func get_description() -> String:
	return "监听组 %s 的信号：%s" % [group_name, signal_name]

## 获取事件类型
func get_event_type() -> String:
	return "signal_from_group"

## 获取事件分类
func get_event_category() -> String:
	return "node"

## 验证事件配置
func validate() -> Array[String]:
	var errors: Array[String] = []

	if signal_name.is_empty():
		errors.append(tr("BRICKS_ERROR_SIGNAL_NAME_INVALID"))

	if group_name.is_empty():
		errors.append(tr("BRICKS_ERROR_GROUP_NAME_INVALID"))

	return errors

## 重置事件状态
func reset() -> void:
	super.reset()
	_is_monitoring = false
	if _owner_node_ref and is_instance_valid(_owner_node_ref):
		initialize(_owner_node_ref)
	_log_debug_localized("BRICKS_LOG_EVENT_RESET", {"event_type": get_event_type()})

## 获取事件元数据
static func _get_event_metadata() -> EventMetadata:
	var metadata = EventMetadata.new()
	metadata.name_key = "BRICKS_EVENT_ON_SIGNAL_FROM_GROUP_NAME"
	metadata.category_key = "BRICKS_EVENT_CATEGORY_NODE"
	metadata.description_key = "BRICKS_EVENT_ON_SIGNAL_FROM_GROUP_DESC"
	metadata.keywords = ["signal", "信号", "group", "组", "batch", "批量", "multiple", "多个"]
	metadata.builtin_icon = "Node"
	return metadata
```

**Step 3-6: 创建测试、验证、提交**

---

## 开发检查清单

每个事件完成前必须验证：

### 代码质量
- [ ] 文件命名：`on_<event>.gd`, `test_on_<event>.gd`, `test_on_<event>.tscn`
- [ ] 类命名：`On<EventName>`
- [ ] 所有变量使用 snake_case，私有变量使用 _前缀
- [ ] 使用 Tab 缩进，类型注解完整
- [ ] 实现 `_update_resource_name()`, `initialize()`, `terminate()`, `validate()`, `reset()`
- [ ] 信号连接前检查 `is_connected()`
- [ ] 使用 `is_instance_valid()` 检查节点有效性
- [ ] 资源清理：stop → disconnect → remove_child → queue_free

### 本地化
- [ ] 所有用户可见文本使用 `tr()`
- [ ] 翻译键已添加到 `translations.csv`
- [ ] 日志使用 `_log_debug_localized()`
- [ ] 错误使用 `_create_bricks_error_localized()`

### 测试
- [ ] 测试脚本已创建
- [ ] 测试场景已创建
- [ ] 测试覆盖：初始化、触发、清理、边界情况
- [ ] 测试在 Godot 中运行通过

### 文档
- [ ] 事件元数据 `_get_event_metadata()` 已实现
- [ ] `name_key`, `category_key`, `description_key`, `keywords`, `builtin_icon` 全部配置
- [ ] `get_description()` 方法返回有意义的描述
- [ ] `get_event_type()` 返回唯一的类型标识
- [ ] `get_event_category()` 返回正确的分类

### Git
- [ ] 每个事件独立 commit
- [ ] Commit message 遵循格式：
  ```
  feat(category): add EventName event

  - 简短描述
  - 关键特性列表

  Phase 4[A/B/C]: Category - Task N
  ```

---

## 进度跟踪

### Phase 4A: 信号和场景事件（2 个事件）
- [ ] Task 1: On Tween Completed
- [ ] Task 2: On Scene About To Change

### Phase 4B: 动画和音频扩展（3 个事件）
- [ ] Task 3: On Animation Frame Reached
- [ ] Task 4: On Animation Blend
- [ ] Task 5: On Music Beat

### Phase 4C: 碰撞和节点事件（3 个事件）
- [ ] Task 6: On Raycast Hit
- [ ] Task 7: On Shape Cast
- [ ] Task 8: On Signal From Group

**总计**: 8 个事件

**预期完成度提升**: 52% → 62%

---

## 下一步

完成此计划后，考虑：
1. 添加 UI 事件扩展（On Drag Started/Dropped, On Menu Visibility Changed）
2. 添加状态事件（On Node Paused/Resumed, On Game State Changed）
3. 添加输入事件扩展（On Input Text, On Touch Swipe）

---

**文档维护**: Bricks 开发团队
**创建日期**: 2026-01-29
**最后更新**: 2026-01-29
**参考**: `@addons/bricks/docs/development/event_creation_guide.md`
