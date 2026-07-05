# Bricks Event System - Phase 5 (Final) Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 完成剩余9个事件的实现，使 Bricks Event System 达到 100% 完成度（59/59）。

**Architecture:** 使用 BaseEvent 架构，每个事件监听特定 Godot 信号或状态变化，通过 triggered 信号触发响应指令链。

**Tech Stack:** Godot 4.6, GDScript 2.0, Bricks Event System, bricks-event-generator 技能

---

## 实施策略

### Sub Agent 并行开发模式

**Batch 1: 生命周期事件（2个）- 简单优先**
- On Enter Tree - 连接 NOTIFICATION_ENTER_TREE
- On Exit Tree - 连接 NOTIFICATION_EXIT_TREE

**Batch 2: 输入事件（2个）- 中等复杂度**
- On Touch Swipe - 触摸轨迹检测
- On Input Text - 文本输入过滤

**Batch 3: 物理/碰撞事件（2个）- 中等复杂度**
- On Screen Entered/Exited - 摄像机视野检测
- On Overlapping Bodies - Area2D 重叠计数

**Batch 4: 场景管理事件（3个）- 高复杂度**
- On Background Load Progress - 异步加载监控
- On Tree Changed - 场景树变化监听
- On Node Paused/Resumed - 暂停模式检测

### 开发流程

每个事件遵循 TDD 流程：
1. 使用 bricks-event-generator 技能生成事件代码
2. 创建测试场景和测试脚本
3. 运行测试验证功能
4. 添加本地化翻译
5. Git 提交
6. 代码审查

---

## Batch 1: 生命周期事件

### Task 1: On Enter Tree 事件

**Files:**
- Create: `addons/bricks/events/lifecycle/on_enter_tree.gd`
- Create: `addons/bricks/tests/events/test_on_enter_tree.gd`
- Create: `addons/bricks/tests/events/test_on_enter_tree.tscn`
- Modify: `addons/bricks/localization/translations.csv`

**Step 1: 使用 bricks-event-generator 生成事件**

```
使用 Skill: bricks-event-generator
事件名称: On Enter Tree
文件名: on_enter_tree
类名: OnEnterTree
分类: lifecycle
功能: 节点进入场景树时触发（连接 NOTIFICATION_ENTER_TREE 通知）
参数: 无
```

生成内容应包含：
- `_update_resource_name()` - "节点进入场景树"
- `initialize()` - 连接 owner_node 的 tree_entered 信号
- `terminate()` - 断开信号连接
- `get_event_type()` - 返回 "enter_tree"
- `get_event_category()` - 返回 "lifecycle"
- `_get_event_metadata()` - 图标: "Reload"

**Step 2: 创建测试场景**

创建 `addons/bricks/tests/events/test_on_enter_tree.tscn`:

```gdscript
[gd_scene load_steps=2 format=3 uid="uid://test_on_enter_tree"]

[ext_resource type="Script" path="res://addons/bricks/tests/events/test_on_enter_tree.gd" id="1"]

[node name="TestOnEnterTree" type="Node"]
script = ExtResource("1")

[node name="DynamicNode" type="Node" parent="."]
```

**Step 3: 创建测试脚本**

创建 `addons/bricks/tests/events/test_on_enter_tree.gd`:

```gdscript
extends Node

## OnEnterTree 事件测试

func _ready():
	print("=== Testing OnEnterTree ===")
	await get_tree().process_frame
	test_basic_functionality()
	test_dynamic_node()
	print("=== All OnEnterTree tests passed! ===")

## 测试基本功能
func test_basic_functionality():
	print("Test 1: Basic functionality")

	var event = OnEnterTree.new()
	var trigger = Node.new()
	add_child(trigger)

	var triggered = false
	event.triggered.connect(func(node):
		triggered = true
		print("  Event triggered!")
	)

	# 初始化事件（此时 trigger 已在树中，应立即触发）
	event.initialize(trigger)
	await get_tree().process_frame

	assert(triggered, "Event should trigger when node is already in tree")
	print("  ✓ Test 1 passed\n")

	event.terminate(trigger)
	trigger.queue_free()

## 测试动态节点
func test_dynamic_node():
	print("Test 2: Dynamic node")

	var event = OnEnterTree.new()
	var trigger = Node.new()

	var triggered = false
	event.triggered.connect(func(node):
		triggered = true
		print("  Event triggered!")
	)

	# 初始化事件（trigger 不在树中）
	event.initialize(trigger)
	await get_tree().process_frame

	assert(not triggered, "Event should not trigger yet")

	# 添加到场景树
	add_child(trigger)
	await get_tree().process_frame

	assert(triggered, "Event should trigger when node enters tree")
	print("  ✓ Test 2 passed\n")

	event.terminate(trigger)
	trigger.queue_free()
```

**Step 4: 运行测试验证**

打开测试场景 `test_on_enter_tree.tscn`，按 F5 运行。

预期输出：
```
=== Testing OnEnterTree ===
Test 1: Basic functionality
  Event triggered!
  ✓ Test 1 passed

Test 2: Dynamic node
  Event triggered!
  ✓ Test 2 passed

=== All OnEnterTree tests passed! ===
```

**Step 5: 添加本地化翻译**

修改 `addons/bricks/localization/translations.csv`，添加：

```csv
BRICKS_EVENT_ON_ENTER_TREE_NAME,进入场景树,Enter Tree
BRICKS_EVENT_ON_ENTER_TREE_DESC,当节点进入场景树时触发,Triggers when node enters scene tree
BRICKS_LOG_EVENT_ENTER_TREE_TRIGGERED,节点进入场景树,Node entered scene tree
BRICKS_EVENT_CATEGORY_LIFECYCLE,生命周期,Lifecycle
```

**Step 6: Git 提交**

```bash
git add addons/bricks/events/lifecycle/on_enter_tree.gd
git add addons/bricks/tests/events/test_on_enter_tree.gd
git add addons/bricks/tests/events/test_on_enter_tree.tscn
git add addons/bricks/localization/translations.csv
git commit -m "feat: add OnEnterTree event - detect when node enters scene tree

- Implement on_enter_tree.gd with tree_entered signal connection
- Add comprehensive test coverage for static and dynamic nodes
- Add localization support for event name and description
- Use @icon annotation with builtin icon: Reload

Phase 5 - Lifecycle Events (1/2)"
```

---

### Task 2: On Exit Tree 事件

**Files:**
- Create: `addons/bricks/events/lifecycle/on_exit_tree.gd`
- Create: `addons/bricks/tests/events/test_on_exit_tree.gd`
- Create: `addons/bricks/tests/events/test_on_exit_tree.tscn`
- Modify: `addons/bricks/localization/translations.csv`

**Step 1: 使用 bricks-event-generator 生成事件**

```
使用 Skill: bricks-event-generator
事件名称: On Exit Tree
文件名: on_exit_tree
类名: OnExitTree
分类: lifecycle
功能: 节点退出场景树时触发（连接 tree_exited 信号）
参数:
  - cleanup_resources: bool = false - 是否清理资源
```

生成内容应包含：
- `_update_resource_name()` - 显示 "退出场景树 [清理资源]"
- `initialize()` - 连接 tree_exited 信号
- `terminate()` - 断开信号连接
- `get_event_type()` - 返回 "exit_tree"
- `_get_event_metadata()` - 图标: "Exit"

**Step 2: 创建测试场景**

创建 `addons/bricks/tests/events/test_on_exit_tree.tscn`:

```gdscript
[gd_scene load_steps=2 format=3 uid="uid://test_on_exit_tree"]

[ext_resource type="Script" path="res://addons/bricks/tests/events/test_on_exit_tree.gd" id="1"]

[node name="TestOnExitTree" type="Node"]
script = ExtResource("1")

[node name="DynamicNode" type="Node" parent="."]
```

**Step 3: 创建测试脚本**

创建 `addons/bricks/tests/events/test_on_exit_tree.gd`:

```gdscript
extends Node

## OnExitTree 事件测试

func _ready():
	print("=== Testing OnExitTree ===")
	await get_tree().process_frame
	test_basic_functionality()
	test_cleanup_flag()
	print("=== All OnExitTree tests passed! ===")

## 测试基本功能
func test_basic_functionality():
	print("Test 1: Basic functionality")

	var event = OnExitTree.new()
	var trigger = Node.new()
	add_child(trigger)

	var triggered = false
	event.triggered.connect(func(node):
		triggered = true
		print("  Event triggered!")
	)

	event.initialize(trigger)
	await get_tree().process_frame

	# 从场景树移除
	remove_child(trigger)
	await get_tree().process_frame

	assert(triggered, "Event should trigger when node exits tree")
	print("  ✓ Test 1 passed\n")

	event.terminate(trigger)
	trigger.queue_free()

## 测试清理标志
func test_cleanup_flag():
	print("Test 2: Cleanup flag")

	var event = OnExitTree.new()
	event.cleanup_resources = true

	var trigger = Node.new()
	add_child(trigger)

	var cleanup_called = false
	event.triggered.connect(func(node):
		cleanup_called = true
		print("  Event triggered with cleanup!")
	)

	event.initialize(trigger)
	await get_tree().process_frame

	remove_child(trigger)
	await get_tree().process_frame

	assert(cleanup_called, "Event should trigger with cleanup flag")
	print("  ✓ Test 2 passed\n")

	event.terminate(trigger)
	trigger.queue_free()
```

**Step 4: 运行测试验证**

打开测试场景 `test_on_exit_tree.tscn`，按 F5 运行。

预期输出：
```
=== Testing OnExitTree ===
Test 1: Basic functionality
  Event triggered!
  ✓ Test 1 passed

Test 2: Cleanup flag
  Event triggered with cleanup!
  ✓ Test 2 passed

=== All OnExitTree tests passed! ===
```

**Step 5: 添加本地化翻译**

修改 `addons/bricks/localization/translations.csv`，添加：

```csv
BRICKS_EVENT_ON_EXIT_TREE_NAME,退出场景树,Exit Tree
BRICKS_EVENT_ON_EXIT_TREE_DESC,当节点退出场景树时触发,Triggers when node exits scene tree
BRICKS_LOG_EVENT_EXIT_TREE_TRIGGERED,节点退出场景树,Node exited scene tree
```

**Step 6: Git 提交**

```bash
git add addons/bricks/events/lifecycle/on_exit_tree.gd
git add addons/bricks/tests/events/test_on_exit_tree.gd
git add addons/bricks/tests/events/test_on_exit_tree.tscn
git add addons/bricks/localization/translations.csv
git commit -m "feat: add OnExitTree event - detect when node exits scene tree

- Implement on_exit_tree.gd with tree_exited signal connection
- Add cleanup_resources flag for resource cleanup option
- Add comprehensive test coverage
- Add localization support

Phase 5 - Lifecycle Events (2/2) Complete"
```

---

## Batch 2: 输入事件

### Task 3: On Touch Swipe 事件

**Files:**
- Create: `addons/bricks/events/input/on_touch_swipe.gd`
- Create: `addons/bricks/tests/events/test_on_touch_swipe.gd`
- Create: `addons/bricks/tests/events/test_on_touch_swipe.tscn`
- Modify: `addons/bricks/localization/translations.csv`

**Step 1: 使用 bricks-event-generator 生成事件**

```
使用 Skill: bricks-event-generator
事件名称: On Touch Swipe
文件名: on_touch_swipe
类名: OnTouchSwipe
分类: input
功能: 检测触摸滑动手势
参数:
  - min_distance: float = 50.0 - 最小滑动距离（像素）
  - swipe_direction: SwipeDirection = Any - 滑动方向（上/下/左/右/任意）
  - time_window: float = 0.5 - 时间窗口（秒）
  - emit_velocity: bool = false - 是否传递滑动速度

枚举:
  SwipeDirection:
    - Up (0)
    - Down (1)
    - Left (2)
    - Right (3)
    - Any (4)
```

生成内容应包含：
- `_update_resource_name()` - 显示 "触摸滑动: [方向] >距离px"
- `initialize()` - 连接 `_input` 处理 InputEventScreenTouch
- `terminate()` - 断开输入处理
- `get_event_type()` - 返回 "touch_swipe"
- 内部变量：`_start_position: Vector2`, `_start_time: float`

**Step 2: 创建测试场景**

创建 `addons/bricks/tests/events/test_on_touch_swipe.tscn`:

```gdscript
[gd_scene load_steps=2 format=3 uid="uid://test_on_touch_swipe"]

[ext_resource type="Script" path="res://addons/bricks/tests/events/test_on_touch_swipe.gd" id="1"]

[node name="TestOnTouchSwipe" type="Node"]
script = ExtResource("1")

[node name="Label" type="Label" parent="."]
offset_left = 50.0
offset_top = 50.0
offset_right = 500.0
offset_bottom = 150.0
text = "Simulate touch swipe events in console"
```

**Step 3: 创建测试脚本**

创建 `addons/bricks/tests/events/test_on_touch_swipe.gd`:

```gdscript
extends Node

## OnTouchSwipe 事件测试

func _ready():
	print("=== Testing OnTouchSwipe ===")
	await get_tree().process_frame
	test_horizontal_swipe()
	test_vertical_swipe()
	test_direction_filter()
	print("=== All OnTouchSwipe tests passed! ===")

## 测试水平滑动
func test_horizontal_swipe():
	print("Test 1: Horizontal swipe")

	var event = OnTouchSwipe.new()
	event.swipe_direction = OnTouchSwipe.SwipeDirection.Any
	event.min_distance = 50.0
	event.time_window = 0.5

	var trigger = Node.new()
	add_child(trigger)

	var triggered = false
	var received_velocity = Vector2.ZERO
	event.triggered.connect(func(context):
		triggered = true
		if context:
			received_velocity = context.get_meta("velocity", Vector2.ZERO)
			print("  Swipe detected! Velocity: %s" % received_velocity)
	)

	event.initialize(trigger)
	await get_tree().process_frame

	# 模拟滑动事件
	var touch_event = InputEventScreenTouch.new()
	touch_event.index = 0
	touch_event.pressed = true
	touch_event.position = Vector2(100, 300)

	# 触摸开始
	trigger._input(touch_event)
	await get_tree().process_frame

	# 触摸结束（模拟向右滑动）
	touch_event.pressed = false
	touch_event.position = Vector2(200, 300)
	trigger._input(touch_event)
	await get_tree().process_frame

	assert(triggered, "Event should trigger on horizontal swipe")
	print("  ✓ Test 1 passed\n")

	event.terminate(trigger)
	trigger.queue_free()

## 测试垂直滑动
func test_vertical_swipe():
	print("Test 2: Vertical swipe")

	var event = OnTouchSwipe.new()
	event.swipe_direction = OnTouchSwipe.SwipeDirection.Any
	event.min_distance = 50.0

	var trigger = Node.new()
	add_child(trigger)

	var triggered = false
	event.triggered.connect(func(context):
		triggered = true
		print("  Vertical swipe detected!")
	)

	event.initialize(trigger)
	await get_tree().process_frame

	# 模拟向上滑动
	var touch_event = InputEventScreenTouch.new()
	touch_event.index = 0
	touch_event.pressed = true
	touch_event.position = Vector2(200, 400)

	trigger._input(touch_event)
	await get_tree().process_frame

	touch_event.pressed = false
	touch_event.position = Vector2(200, 300)
	trigger._input(touch_event)
	await get_tree().process_frame

	assert(triggered, "Event should trigger on vertical swipe")
	print("  ✓ Test 2 passed\n")

	event.terminate(trigger)
	trigger.queue_free()

## 测试方向过滤
func test_direction_filter():
	print("Test 3: Direction filter")

	var event = OnTouchSwipe.new()
	event.swipe_direction = OnTouchSwipe.SwipeDirection.Up
	event.min_distance = 50.0

	var trigger = Node.new()
	add_child(trigger)

	var triggered = false
	event.triggered.connect(func(context):
		triggered = true
	)

	event.initialize(trigger)
	await get_tree().process_frame

	# 模拟向下滑动（不应触发）
	var touch_event = InputEventScreenTouch.new()
	touch_event.index = 0
	touch_event.pressed = true
	touch_event.position = Vector2(200, 300)

	trigger._input(touch_event)
	await get_tree().process_frame

	touch_event.pressed = false
	touch_event.position = Vector2(200, 400)
	trigger._input(touch_event)
	await get_tree().process_frame

	assert(not triggered, "Event should not trigger on wrong direction")

	# 模拟向上滑动（应触发）
	touch_event.pressed = true
	touch_event.position = Vector2(200, 400)
	trigger._input(touch_event)
	await get_tree().process_frame

	touch_event.pressed = false
	touch_event.position = Vector2(200, 300)
	trigger._input(touch_event)
	await get_tree().process_frame

	assert(triggered, "Event should trigger on correct direction")
	print("  ✓ Test 3 passed\n")

	event.terminate(trigger)
	trigger.queue_free()
```

**Step 4: 运行测试验证**

打开测试场景 `test_on_touch_swipe.tscn`，按 F5 运行。

**Step 5: 添加本地化翻译**

修改 `addons/bricks/localization/translations.csv`，添加：

```csv
BRICKS_EVENT_ON_TOUCH_SWIPE_NAME,触摸滑动,Touch Swipe
BRICKS_EVENT_ON_TOUCH_SWIPE_DESC,检测触摸滑动手势,Detect touch swipe gestures
BRICKS_LOG_EVENT_TOUCH_SWIPE_TRIGGERED,检测到滑动: 方向={direction}, 距离={distance},Swipe detected: direction={direction}, distance={distance}
```

**Step 6: Git 提交**

```bash
git add addons/bricks/events/input/on_touch_swipe.gd
git add addons/bricks/tests/events/test_on_touch_swipe.gd
git add addons/bricks/tests/events/test_on_touch_swipe.tscn
git add addons/bricks/localization/translations.csv
git commit -m "feat: add OnTouchSwipe event - detect touch swipe gestures

- Implement on_touch_swipe.gd with direction and distance filtering
- Support 4 directions: Up/Down/Left/Right/Any
- Add time_window parameter to prevent accidental swipes
- Optional velocity emission in context
- Add comprehensive test coverage

Phase 5 - Input Events (1/2)"
```

---

### Task 4: On Input Text 事件

**Files:**
- Create: `addons/bricks/events/input/on_input_text.gd`
- Create: `addons/bricks/tests/events/test_on_input_text.gd`
- Create: `addons/bricks/tests/events/test_on_input_text.tscn`
- Modify: `addons/bricks/localization/translations.csv`

**Step 1: 使用 bricks-event-generator 生成事件**

```
使用 Skill: bricks-event-generator
事件名称: On Input Text
文件名: on_input_text
类名: OnInputText
分类: input
功能: 监听文本输入事件
参数:
  - filter_characters: String = "" - 字符过滤器（正则表达式）
  - max_length: int = 0 - 最大长度（0 = 无限制）
  - emit_text: bool = true - 是否传递输入的文本
```

生成内容应包含：
- `_update_resource_name()` - 显示 "文本输入 [过滤] [最大长度]"
- `initialize()` - 设置输入处理
- `terminate()` - 清理输入处理
- `get_event_type()` - 返回 "input_text"
- `_get_event_metadata()` - 图标: "TextEdit"

**Step 2: 创建测试场景**

创建 `addons/bricks/tests/events/test_on_input_text.tscn`:

```gdscript
[gd_scene load_steps=2 format=3 uid="uid://test_on_input_text"]

[ext_resource type="Script" path="res://addons/bricks/tests/events/test_on_input_text.gd" id="1"]

[node name="TestOnInputText" type="Node"]
script = ExtResource("1")

[node name="LineEdit" type="LineEdit" parent="."]
offset_left = 100.0
offset_top = 100.0
offset_right = 500.0
offset_bottom = 130.0
placeholder_text = "Type here to test input event"
```

**Step 3: 创建测试脚本**

创建 `addons/bricks/tests/events/test_on_input_text.gd`:

```gdscript
extends Node

## OnInputText 事件测试

func _ready():
	print("=== Testing OnInputText ===")
	await get_tree().process_frame
	test_basic_input()
	test_character_filter()
	test_length_limit()
	print("=== All OnInputText tests passed! ===")

## 测试基本输入
func test_basic_input():
	print("Test 1: Basic input")

	var event = OnInputText.new()
	event.emit_text = true

	var trigger = Node.new()
	add_child(trigger)

	var triggered = false
	var received_text = ""
	event.triggered.connect(func(context):
		triggered = true
		if context:
			received_text = context.get_meta("text", "")
			print("  Input received: '%s'" % received_text)
	)

	event.initialize(trigger)
	await get_tree().process_frame

	# 模拟文本输入事件
	var input_event = InputEventText.new()
	input_event.text = "Hello"
	trigger._input(input_event)
	await get_tree().process_frame

	assert(triggered, "Event should trigger on text input")
	assert(received_text == "Hello", "Should receive correct text")
	print("  ✓ Test 1 passed\n")

	event.terminate(trigger)
	trigger.queue_free()

## 测试字符过滤
func test_character_filter():
	print("Test 2: Character filter")

	var event = OnInputText.new()
	event.filter_characters = "[0-9]"  # 只允许数字
	event.emit_text = true

	var trigger = Node.new()
	add_child(trigger)

	var digit_triggered = false
	var letter_triggered = false

	event.triggered.connect(func(context):
		var text = context.get_meta("text", "") if context else ""
		if text == "5":
			digit_triggered = true
		elif text == "a":
			letter_triggered = true
	)

	event.initialize(trigger)
	await get_tree().process_frame

	# 输入数字（应触发）
	var input_event = InputEventText.new()
	input_event.text = "5"
	trigger._input(input_event)
	await get_tree().process_frame

	assert(digit_triggered, "Event should trigger for digit")

	# 输入字母（不应触发）
	input_event.text = "a"
	trigger._input(input_event)
	await get_tree().process_frame

	assert(not letter_triggered, "Event should not trigger for letter")
	print("  ✓ Test 2 passed\n")

	event.terminate(trigger)
	trigger.queue_free()

## 测试长度限制
func test_length_limit():
	print("Test 3: Length limit")

	var event = OnInputText.new()
	event.max_length = 3
	event.emit_text = true

	var trigger = Node.new()
	add_child(trigger)

	var trigger_count = 0
	event.triggered.connect(func(context):
		trigger_count += 1
		print("  Trigger count: %d" % trigger_count)
	)

	event.initialize(trigger)
	await get_tree().process_frame

	# 输入3个字符（都应触发）
	for i in range(3):
		var input_event = InputEventText.new()
		input_event.text = "a"
		trigger._input(input_event)
		await get_tree().process_frame

	assert(trigger_count == 3, "Should trigger for first 3 characters")

	# 第4个字符（不应触发）
	var input_event = InputEventText.new()
	input_event.text = "a"
	trigger._input(input_event)
	await get_tree().process_frame

	assert(trigger_count == 3, "Should not trigger beyond max length")
	print("  ✓ Test 3 passed\n")

	event.terminate(trigger)
	trigger.queue_free()
```

**Step 4: 运行测试验证**

**Step 5: 添加本地化翻译**

修改 `addons/bricks/localization/translations.csv`，添加：

```csv
BRICKS_EVENT_ON_INPUT_TEXT_NAME,文本输入,Input Text
BRICKS_EVENT_ON_INPUT_TEXT_DESC,监听文本输入事件,Listen to text input events
BRICKS_LOG_EVENT_INPUT_TEXT_TRIGGERED,文本输入: {text},Text input: {text}
```

**Step 6: Git 提交**

```bash
git add addons/bricks/events/input/on_input_text.gd
git add addons/bricks/tests/events/test_on_input_text.gd
git add addons/bricks/tests/events/test_on_input_text.tscn
git add addons/bricks/localization/translations.csv
git commit -m "feat: add OnInputText event - listen to text input

- Implement on_input_text.gd with regex character filtering
- Support max_length parameter to limit input
- Optional text emission in context
- Add comprehensive test coverage for filtering

Phase 5 - Input Events (2/2) Complete"
```

---

## Batch 3: 物理/碰撞事件

### Task 5: On Screen Entered/Exited 事件

**Files:**
- Create: `addons/bricks/events/physics/on_screen_entered_exited.gd`
- Create: `addons/bricks/tests/events/test_on_screen_entered_exited.gd`
- Create: `addons/bricks/tests/events/test_on_screen_entered_exited.tscn`
- Modify: `addons/bricks/localization/translations.csv`

**Step 1: 使用 bricks-event-generator 生成事件**

```
使用 Skill: bricks-event-generator
事件名称: On Screen Entered/Exited
文件名: on_screen_entered_exited
类名: OnScreenEnteredExited
分类: physics
功能: 节点进入或离开摄像机视野时触发
参数:
  - target_node: NodePath - 目标节点
  - camera: NodePath = NodePath("") - 相机节点（空 = 默认相机）
  - trigger_on: TriggerOn = Both - 触发时机（进入/离开/两者）
  - margin: float = 0.0 - 边缘余量（像素）
  - check_interval: float = 0.1 - 检查间隔（秒）

枚举:
  TriggerOn:
    - Enter (0)
    - Exit (1)
    - Both (2)
```

生成内容应包含：
- `_update_resource_name()` - 显示 "屏幕进入/离开: [时机]"
- `initialize()` - 创建 Timer 定期检查 `is_on_screen()`
- `terminate()` - 停止并清理 Timer
- `get_event_type()` - 返回 "screen_entered_exited"
- 内部逻辑：缓存上次屏幕状态，检测状态变化

**Step 2: 创建测试场景**

创建 `addons/bricks/tests/events/test_on_screen_entered_exited.tscn`:

```gdscript
[gd_scene load_steps=3 format=3 uid="uid://test_on_screen_entered_exited"]

[ext_resource type="Script" path="res://addons/bricks/tests/events/test_on_screen_entered_exited.gd" id="1"]
[ext_resource type="Script" path="res://addons/bricks/test_camera_movement.gd" id="2"]

[node name="TestOnScreenEnteredExited" type="Node2D"]
script = ExtResource("1")

[node name="Camera2D" type="Camera2D" parent="."]
position = Vector2(500, 300)
zoom = Vector2(0.5, 0.5)
script = ExtResource("2")

[node name="TargetSprite" type="Sprite2D" parent="."]
position = Vector2(-200, 300)
texture = preload("res://icon.svg")
```

**Step 3: 创建测试脚本**

创建 `addons/bricks/tests/events/test_on_screen_entered_exited.gd`:

```gdscript
extends Node2D

## OnScreenEnteredExited 事件测试

@onready var camera = $Camera2D
@onready var target = $TargetSprite

func _ready():
	print("=== Testing OnScreenEnteredExited ===")
	await get_tree().process_frame
	test_screen_enter()
	test_screen_exit()
	test_both_triggers()
	print("=== All OnScreenEnteredExited tests passed! ===")

## 测试进入屏幕
func test_screen_enter():
	print("Test 1: Screen enter")

	var event = OnScreenEnteredExited.new()
	event.target_node = target.get_path()
	event.trigger_on = OnScreenEnteredExited.TriggerOn.Enter
	event.check_interval = 0.1

	var trigger = Node.new()
	add_child(trigger)

	var triggered = false
	event.triggered.connect(func(node):
		triggered = true
		print("  Node entered screen!")
	)

	event.initialize(trigger)
	await get_tree().process_frame

	# 移动相机让目标进入视野
	camera.position = Vector2(0, 300)
	await get_tree().create_timer(0.2).timeout

	assert(triggered, "Event should trigger when node enters screen")
	print("  ✓ Test 1 passed\n")

	event.terminate(trigger)
	trigger.queue_free()

## 测试离开屏幕
func test_screen_exit():
	print("Test 2: Screen exit")

	var event = OnScreenEnteredExited.new()
	event.target_node = target.get_path()
	event.trigger_on = OnScreenEnteredExited.TriggerOn.Exit
	event.check_interval = 0.1

	var trigger = Node.new()
	add_child(trigger)

	var triggered = false
	event.triggered.connect(func(node):
		triggered = true
		print("  Node exited screen!")
	)

	event.initialize(trigger)
	await get_tree().process_frame

	# 目标在屏幕内
	camera.position = Vector2(0, 300)
	await get_tree().create_timer(0.2).timeout

	# 移动相机让目标离开视野
	camera.position = Vector2(1000, 300)
	await get_tree().create_timer(0.2).timeout

	assert(triggered, "Event should trigger when node exits screen")
	print("  ✓ Test 2 passed\n")

	event.terminate(trigger)
	trigger.queue_free()

## 测试两者都触发
func test_both_triggers():
	print("Test 3: Both enter and exit")

	var event = OnScreenEnteredExited.new()
	event.target_node = target.get_path()
	event.trigger_on = OnScreenEnteredExited.TriggerOn.Both
	event.check_interval = 0.1

	var trigger = Node.new()
	add_child(trigger)

	var enter_triggered = false
	var exit_triggered = false
	event.triggered.connect(func(node):
		if target.is_on_screen():
			enter_triggered = true
			print("  Enter triggered!")
		else:
			exit_triggered = true
			print("  Exit triggered!")
	)

	event.initialize(trigger)
	await get_tree().process_frame

	# 进入屏幕
	camera.position = Vector2(0, 300)
	await get_tree().create_timer(0.2).timeout

	assert(enter_triggered, "Should trigger on enter")

	# 离开屏幕
	camera.position = Vector2(1000, 300)
	await get_tree().create_timer(0.2).timeout

	assert(exit_triggered, "Should trigger on exit")
	print("  ✓ Test 3 passed\n")

	event.terminate(trigger)
	trigger.queue_free()
```

**Step 4: 运行测试验证**

**Step 5: 添加本地化翻译**

修改 `addons/bricks/localization/translations.csv`，添加：

```csv
BRICKS_EVENT_ON_SCREEN_ENTERED_EXITED_NAME,屏幕进入/离开,Screen Entered/Exited
BRICKS_EVENT_ON_SCREEN_ENTERED_EXITED_DESC,节点进入或离开摄像机视野时触发,Triggers when node enters or exits camera view
BRICKS_LOG_EVENT_SCREEN_ENTERED,节点进入屏幕,Node entered screen
BRICKS_LOG_EVENT_SCREEN_EXITED,节点离开屏幕,Node exited screen
```

**Step 6: Git 提交**

```bash
git add addons/bricks/events/physics/on_screen_entered_exited.gd
git add addons/bricks/tests/events/test_on_screen_entered_exited.gd
git add addons/bricks/tests/events/test_on_screen_entered_exited.tscn
git add addons/bricks/localization/translations.csv
git commit -m "feat: add OnScreenEnteredExited event - detect screen visibility

- Implement on_screen_entered_exited.gd with periodic is_on_screen() checks
- Support trigger_on: Enter/Exit/Both modes
- Optional camera parameter and margin for edge cases
- Add comprehensive test coverage

Phase 5 - Physics Events (1/2)"
```

---

### Task 6: On Overlapping Bodies 事件

**Files:**
- Create: `addons/bricks/events/physics/on_overlapping_bodies.gd`
- Create: `addons/bricks/tests/events/test_on_overlapping_bodies.gd`
- Create: `addons/bricks/tests/events/test_on_overlapping_bodies.tscn`
- Modify: `addons/bricks/localization/translations.csv`

**Step 1: 使用 bricks-event-generator 生成事件**

```
使用 Skill: bricks-event-generator
事件名称: On Overlapping Bodies
文件名: on_overlapping_bodies
类名: OnOverlappingBodies
分类: physics
功能: 区域内重叠物体数量变化时触发
参数:
  - area_node: NodePath - Area 节点
  - check_threshold: int = 1 - 数量阈值
  - comparison: Comparison = Greater - 比较方式（大于/小于/等于）
  - emit_count: bool = true - 是否传递当前数量

枚举:
  Comparison:
    - Greater (0)
    - Less (1)
    - Equal (2)
```

生成内容应包含：
- `_update_resource_name()` - 显示 "重叠物体: [比较] [阈值]"
- `initialize()` - 连接 Area2D/3D 的 `body_entered` 和 `body_exited` 信号
- `terminate()` - 断开信号连接
- `get_event_type()` - 返回 "overlapping_bodies"
- 内部逻辑：每次进入/退出时检查 `get_overlapping_bodies().size()`

**Step 2: 创建测试场景**

创建 `addons/bricks/tests/events/test_on_overlapping_bodies.tscn`:

```gdscript
[gd_scene load_steps=4 format=3 uid="uid://test_on_overlapping_bodies"]

[ext_resource type="Script" path="res://addons/bricks/tests/events/test_on_overlapping_bodies.gd" id="1"]

[sub_resource type="CircleShape2D" id="CircleShape2D_1"]
radius = 50.0

[node name="TestOnOverlappingBodies" type="Node2D"]
script = ExtResource("1")

[node name="Area2D" type="Area2D" parent="."]
position = Vector2(400, 300)

[node name="CollisionShape2D" type="CollisionShape2D" parent="Area2D"]
shape = SubResource("CircleShape2D_1")

[node name="Body1" type="RigidBody2D" parent="."]
position = Vector2(400, 300)

[node name="CollisionShape2D" type="CollisionShape2D" parent="Body1"]
shape = SubResource("CircleShape2D_1")

[node name="Body2" type="RigidBody2D" parent="."]
position = Vector2(450, 300)

[node name="CollisionShape2D" type="CollisionShape2D" parent="Body2"]
shape = SubResource("CircleShape2D_1")
```

**Step 3: 创建测试脚本**

创建 `addons/bricks/tests/events/test_on_overlapping_bodies.gd`:

```gdscript
extends Node2D

## OnOverlappingBodies 事件测试

@onready var area = $Area2D
@onready var body1 = $Body1
@onready var body2 = $Body2

func _ready():
	print("=== Testing OnOverlappingBodies ===")
	await get_tree().process_frame
	test_greater_threshold()
	test_equal_threshold()
	test_count_emission()
	print("=== All OnOverlappingBodies tests passed! ===")

## 测试大于阈值
func test_greater_threshold():
	print("Test 1: Greater than threshold")

	var event = OnOverlappingBodies.new()
	event.area_node = area.get_path()
	event.check_threshold = 1
	event.comparison = OnOverlappingBodies.Comparison.Greater

	var trigger = Node.new()
	add_child(trigger)

	var triggered = false
	var received_count = 0
	event.triggered.connect(func(context):
		triggered = true
		if context:
			received_count = context.get_meta("count", 0)
			print("  Overlapping count: %d" % received_count)
	)

	event.initialize(trigger)
	await get_tree().process_frame

	# 移动 body1 到区域外（count = 1，body2）
	body1.position = Vector2(600, 300)
	await get_tree().process_frame

	# 移动 body2 到区域外（count = 0，不触发）
	body2.position = Vector2(600, 300)
	await get_tree().process_frame

	# 移动 body1 回区域内（count = 1，达到阈值）
	body1.position = Vector2(400, 300)
	await get_tree().process_frame

	assert(triggered, "Event should trigger when count >= threshold")
	assert(received_count == 1, "Should emit correct count")
	print("  ✓ Test 1 passed\n")

	event.terminate(trigger)
	trigger.queue_free()

## 测试等于阈值
func test_equal_threshold():
	print("Test 2: Equal to threshold")

	var event = OnOverlappingBodies.new()
	event.area_node = area.get_path()
	event.check_threshold = 2
	event.comparison = OnOverlappingBodies.Comparison.Equal

	var trigger = Node.new()
	add_child(trigger)

	var triggered = false
	event.triggered.connect(func(context):
		triggered = true
		print("  Count equals threshold!")
	)

	event.initialize(trigger)
	await get_tree().process_frame

	# 重置位置
	body1.position = Vector2(400, 300)
	body2.position = Vector2(450, 300)
	await get_tree().process_frame

	assert(triggered, "Event should trigger when count equals threshold")
	print("  ✓ Test 2 passed\n")

	event.terminate(trigger)
	trigger.queue_free()

## 测试数量传递
func test_count_emission():
	print("Test 3: Count emission")

	var event = OnOverlappingBodies.new()
	event.area_node = area.get_path()
	event.check_threshold = 0
	event.emit_count = true

	var trigger = Node.new()
	add_child(trigger)

	var count_received = false
	event.triggered.connect(func(context):
		if context and context.has_meta("count"):
			count_received = true
			print("  Count successfully emitted!")
	)

	event.initialize(trigger)
	await get_tree().process_frame

	assert(count_received, "Event should emit count when emit_count is true")
	print("  ✓ Test 3 passed\n")

	event.terminate(trigger)
	trigger.queue_free()
```

**Step 4: 运行测试验证**

**Step 5: 添加本地化翻译**

修改 `addons/bricks/localization/translations.csv`，添加：

```csv
BRICKS_EVENT_ON_OVERLAPPING_BODIES_NAME,重叠物体数量,Overlapping Bodies Count
BRICKS_EVENT_ON_OVERLAPPING_BODIES_DESC,区域内重叠物体数量变化时触发,Triggers when overlapping body count changes
BRICKS_LOG_EVENT_OVERLAPPING_BODIES_TRIGGERED,重叠物体数量: {count},Overlapping bodies: {count}
```

**Step 6: Git 提交**

```bash
git add addons/bricks/events/physics/on_overlapping_bodies.gd
git add addons/bricks/tests/events/test_on_overlapping_bodies.gd
git add addons/bricks/tests/events/test_on_overlapping_bodies.tscn
git add addons/bricks/localization/translations.csv
git commit -m "feat: add OnOverlappingBodies event - monitor overlapping body count

- Implement on_overlapping_bodies.gd with body_entered/exited signals
- Support comparison modes: Greater/Less/Equal
- Optional count emission in context
- Add comprehensive test coverage

Phase 5 - Physics Events (2/2) Complete"
```

---

## Batch 4: 场景管理事件

### Task 7: On Background Load Progress 事件

**Files:**
- Create: `addons/bricks/events/scene/on_background_load_progress.gd`
- Create: `addons/bricks/tests/events/test_on_background_load_progress.gd`
- Create: `addons/bricks/tests/events/test_on_background_load_progress.tscn`
- Modify: `addons/bricks/localization/translations.csv`

**Step 1: 使用 bricks-event-generator 生成事件**

```
使用 Skill: bricks-event-generator
事件名称: On Background Load Progress
文件名: on_background_load_progress
类名: OnBackgroundLoadProgress
分类: scene
功能: 后台加载进度变化时触发
参数:
  - resource_path: String = "" - 资源路径
  - check_interval: float = 0.1 - 检查间隔（秒）
  - progress_threshold: float = 0.1 - 进度阈值（0-1）
  - emit_progress: bool = true - 是否传递进度值
```

生成内容应包含：
- `_update_resource_name()` - 显示 "后台加载进度: [路径]"
- `initialize()` - 启动 `ResourceLoader.load_threaded()` 并创建 Timer
- `terminate()` - 停止 Timer 并清理加载状态
- `get_event_type()` - 返回 "background_load_progress"
- 内部逻辑：使用 `load_threaded_get_status()` 检查进度

**Step 2: 创建测试脚本**

创建 `addons/bricks/tests/events/test_on_background_load_progress.gd`:

```gdscript
extends Node

## OnBackgroundLoadProgress 事件测试

func _ready():
	print("=== Testing OnBackgroundLoadProgress ===")
	await get_tree().process_frame
	test_load_progress()
	test_progress_threshold()
	print("=== All OnBackgroundLoadProgress tests passed! ===")

## 测试加载进度
func test_load_progress():
	print("Test 1: Load progress monitoring")

	var event = OnBackgroundLoadProgress.new()
	event.resource_path = "res://icon.svg"  # 使用内置资源
	event.check_interval = 0.05
	event.progress_threshold = 0.0  # 每次都触发

	var trigger = Node.new()
	add_child(trigger)

	var progress_values = []
	event.triggered.connect(func(context):
		if context:
			var progress = context.get_meta("progress", 0.0)
			progress_values.append(progress)
			print("  Progress: %.2f" % progress)
	)

	event.initialize(trigger)
	await get_tree().process_frame

	# 开始后台加载
	ResourceLoader.load_threaded_request(event.resource_path)

	# 等待加载完成
	await get_tree().create_timer(1.0).timeout

	assert(progress_values.size() > 0, "Should receive progress updates")
	assert(progress_values[-1] == 1.0, "Final progress should be 1.0")
	print("  ✓ Test 1 passed\n")

	event.terminate(trigger)
	trigger.queue_free()

## 测试进度阈值
func test_progress_threshold():
	print("Test 2: Progress threshold")

	var event = OnBackgroundLoadProgress.new()
	event.resource_path = "res://icon.svg"
	event.check_interval = 0.05
	event.progress_threshold = 0.5  # 50%才触发

	var trigger = Node.new()
	add_child(trigger)

	var trigger_count = 0
	event.triggered.connect(func(context):
		trigger_count += 1
		print("  Triggered at threshold!")
	)

	event.initialize(trigger)
	await get_tree().process_frame

	ResourceLoader.load_threaded_request(event.resource_path)
	await get_tree().create_timer(1.0).timeout

	# 应该只触发一次（超过阈值时）
	assert(trigger_count == 1, "Should trigger once when crossing threshold")
	print("  ✓ Test 2 passed\n")

	event.terminate(trigger)
	trigger.queue_free()
```

**Step 3: 创建测试场景**

**Step 4: 运行测试验证**

**Step 5: 添加本地化翻译**

修改 `addons/bricks/localization/translations.csv`，添加：

```csv
BRICKS_EVENT_ON_BACKGROUND_LOAD_PROGRESS_NAME,后台加载进度,Background Load Progress
BRICKS_EVENT_ON_BACKGROUND_LOAD_PROGRESS_DESC,后台加载进度变化时触发,Triggers on background load progress changes
BRICKS_LOG_EVENT_BACKGROUND_LOAD_PROGRESS,加载进度: {progress}%,Load progress: {progress}%
```

**Step 6: Git 提交**

```bash
git add addons/bricks/events/scene/on_background_load_progress.gd
git add addons/bricks/tests/events/test_on_background_load_progress.gd
git add addons/bricks/tests/events/test_on_background_load_progress.tscn
git add addons/bricks/localization/translations.csv
git commit -m "feat: add OnBackgroundLoadProgress event - monitor async loading

- Implement on_background_load_progress.gd with ResourceLoader.load_threaded
- Support progress_threshold to filter triggers
- Optional progress emission in context
- Add test coverage for async loading scenarios

Phase 5 - Scene Management Events (1/3)"
```

---

### Task 8: On Tree Changed 事件

**Files:**
- Create: `addons/bricks/events/scene/on_tree_changed.gd`
- Create: `addons/bricks/tests/events/test_on_tree_changed.gd`
- Create: `addons/bricks/tests/events/test_on_tree_changed.tscn`
- Modify: `addons/bricks/localization/translations.csv`

**Step 1: 使用 bricks-event-generator 生成事件**

```
使用 Skill: bricks-event-generator
事件名称: On Tree Changed
文件名: on_tree_changed
类名: OnTreeChanged
分类: scene
功能: 场景树结构变化时触发
参数:
  - change_type: ChangeType = Any - 变化类型
  - filter_by_group: String = "" - 组过滤（可选）
  - emit_changed_node: bool = true - 是否传递变化节点

枚举:
  ChangeType:
    - NodeAdded (0)
    - NodeRemoved (1)
    - Any (2)
```

生成内容应包含：
- `_update_resource_name()` - 显示 "场景树变化: [类型]"
- `initialize()` - 连接 SceneTree 的 `node_added` 和 `node_removed` 信号
- `terminate()` - 断开信号连接
- `get_event_type()` - 返回 "tree_changed"
- `_get_event_metadata()` - 图标: "SceneTree"

**Step 2: 创建测试脚本**

创建 `addons/bricks/tests/events/test_on_tree_changed.gd`:

```gdscript
extends Node

## OnTreeChanged 事件测试

func _ready():
	print("=== Testing OnTreeChanged ===")
	await get_tree().process_frame
	test_node_added()
	test_node_removed()
	test_group_filter()
	print("=== All OnTreeChanged tests passed! ===")

## 测试节点添加
func test_node_added():
	print("Test 1: Node added")

	var event = OnTreeChanged.new()
	event.change_type = OnTreeChanged.ChangeType.NodeAdded

	var trigger = Node.new()
	add_child(trigger)

	var triggered = false
	var added_node = null
	event.triggered.connect(func(context):
		triggered = true
		if context:
			added_node = context.get_meta("node")
			print("  Node added: %s" % added_node.name)
	)

	event.initialize(trigger)
	await get_tree().process_frame

	# 添加节点
	var new_node = Node.new()
	new_node.name = "TestNode"
	add_child(new_node)
	await get_tree().process_frame

	assert(triggered, "Event should trigger on node added")
	assert(added_node == new_node, "Should emit the added node")
	print("  ✓ Test 1 passed\n")

	new_node.queue_free()
	event.terminate(trigger)
	trigger.queue_free()

## 测试节点移除
func test_node_removed():
	print("Test 2: Node removed")

	var event = OnTreeChanged.new()
	event.change_type = OnTreeChanged.ChangeType.NodeRemoved

	var trigger = Node.new()
	add_child(trigger)

	var triggered = false
	event.triggered.connect(func(context):
		triggered = true
		print("  Node removed!")
	)

	event.initialize(trigger)
	await get_tree().process_frame

	# 移除节点
	var test_node = Node.new()
	add_child(test_node)
	await get_tree().process_frame
	test_node.queue_free()
	await get_tree().process_frame

	assert(triggered, "Event should trigger on node removed")
	print("  ✓ Test 2 passed\n")

	event.terminate(trigger)
	trigger.queue_free()

## 测试组过滤
func test_group_filter():
	print("Test 3: Group filter")

	var event = OnTreeChanged.new()
	event.change_type = OnTreeChanged.ChangeType.NodeAdded
	event.filter_by_group = "test_group"

	var trigger = Node.new()
	add_child(trigger)

	var triggered = false
	event.triggered.connect(func(context):
		triggered = true
		print("  Group node added!")
	)

	event.initialize(trigger)
	await get_tree().process_frame

	# 添加不在组的节点（不应触发）
	var node1 = Node.new()
	add_child(node1)
	await get_tree().process_frame

	assert(not triggered, "Should not trigger for nodes outside group")

	# 添加在组的节点（应触发）
	var node2 = Node.new()
	node2.add_to_group("test_group")
	add_child(node2)
	await get_tree().process_frame

	assert(triggered, "Should trigger for nodes in group")
	print("  ✓ Test 3 passed\n")

	node1.queue_free()
	node2.queue_free()
	event.terminate(trigger)
	trigger.queue_free()
```

**Step 3: 创建测试场景**

**Step 4: 运行测试验证**

**Step 5: 添加本地化翻译**

修改 `addons/bricks/localization/translations.csv`，添加：

```csv
BRICKS_EVENT_ON_TREE_CHANGED_NAME,场景树变化,Tree Changed
BRICKS_EVENT_ON_TREE_CHANGED_DESC,场景树结构变化时触发,Triggers when scene tree structure changes
BRICKS_LOG_EVENT_TREE_NODE_ADDED,节点添加: {node},Node added: {node}
BRICKS_LOG_EVENT_TREE_NODE_REMOVED,节点移除,Node removed
```

**Step 6: Git 提交**

```bash
git add addons/bricks/events/scene/on_tree_changed.gd
git add addons/bricks/tests/events/test_on_tree_changed.gd
git add addons/bricks/tests/events/test_on_tree_changed.tscn
git add addons/bricks/localization/translations.csv
git commit -m "feat: add OnTreeChanged event - monitor scene tree changes

- Implement on_tree_changed.gd with SceneTree node_added/removed signals
- Support change_type filtering: NodeAdded/NodeRemoved/Any
- Optional group filtering for specific node types
- Optional node emission in context
- Add comprehensive test coverage

Phase 5 - Scene Management Events (2/3)"
```

---

### Task 9: On Node Paused/Resumed 事件

**Files:**
- Create: `addons/bricks/events/scene/on_node_paused_resumed.gd`
- Create: `addons/bricks/tests/events/test_on_node_paused_resumed.gd`
- Create: `addons/bricks/tests/events/test_on_node_paused_resumed.tscn`
- Modify: `addons/bricks/localization/translations.csv`

**Step 1: 使用 bricks-event-generator 生成事件**

```
使用 Skill: bricks-event-generator
事件名称: On Node Paused/Resumed
文件名: on_node_paused_resumed
类名: OnNodePausedResumed
分类: scene
功能: 节点暂停模式变化时触发
参数:
  - target_node: NodePath - 目标节点
  - trigger_on: TriggerOn = Both - 触发时机

枚举:
  TriggerOn:
    - Paused (0)
    - Resumed (1)
    - Both (2)
```

生成内容应包含：
- `_update_resource_name()` - 显示 "节点暂停/恢复: [时机]"
- `initialize()` - 创建 Timer 定期检查 `process_mode`
- `terminate()` - 停止并清理 Timer
- `get_event_type()` - 返回 "node_paused_resumed"
- 内部逻辑：缓存上次 process_mode，检测变化

**Step 2: 创建测试脚本**

创建 `addons/bricks/tests/events/test_on_node_paused_resumed.gd`:

```gdscript
extends Node

## OnNodePausedResumed 事件测试

func _ready():
	print("=== Testing OnNodePausedResumed ===")
	await get_tree().process_frame
	test_node_paused()
	test_node_resumed()
	test_both_triggers()
	print("=== All OnNodePausedResumed tests passed! ===")

## 测试暂停
func test_node_paused():
	print("Test 1: Node paused")

	var event = OnNodePausedResumed.new()
	event.target_node = NodePath(".")
	event.trigger_on = OnNodePausedResumed.TriggerOn.Paused

	var triggered = false
	event.triggered.connect(func(node):
		triggered = true
		print("  Node paused!")
	)

	event.initialize(self)
	await get_tree().process_frame

	# 暂停节点
	pause_mode = Node.PAUSE_MODE_STOP
	await get_tree().process_frame

	assert(triggered, "Event should trigger when node is paused")
	print("  ✓ Test 1 passed\n")

	event.terminate(self)

## 测试恢复
func test_node_resumed():
	print("Test 2: Node resumed")

	var event = OnNodePausedResumed.new()
	event.target_node = NodePath(".")
	event.trigger_on = OnNodePausedResumed.TriggerOn.Resumed

	var triggered = false
	event.triggered.connect(func(node):
		triggered = true
		print("  Node resumed!")
	)

	event.initialize(self)
	await get_tree().process_frame

	# 先暂停
	pause_mode = Node.PAUSE_MODE_STOP
	await get_tree().process_frame

	# 恢复
	pause_mode = Node.PAUSE_MODE_PROCESS
	await get_tree().process_frame

	assert(triggered, "Event should trigger when node is resumed")
	print("  ✓ Test 2 passed\n")

	event.terminate(self)

## 测试两者都触发
func test_both_triggers():
	print("Test 3: Both paused and resumed")

	var event = OnNodePausedResumed.new()
	event.target_node = NodePath(".")
	event.trigger_on = OnNodePausedResumed.TriggerOn.Both

	var paused_triggered = false
	var resumed_triggered = false
	event.triggered.connect(func(node):
		if pause_mode == Node.PAUSE_MODE_STOP:
			paused_triggered = true
		else:
			resumed_triggered = true
	)

	event.initialize(self)
	await get_tree().process_frame

	# 暂停
	pause_mode = Node.PAUSE_MODE_STOP
	await get_tree().process_frame

	assert(paused_triggered, "Should trigger on paused")

	# 恢复
	pause_mode = Node.PAUSE_MODE_PROCESS
	await get_tree().process_frame

	assert(resumed_triggered, "Should trigger on resumed")
	print("  ✓ Test 3 passed\n")

	event.terminate(self)
```

**Step 3: 创建测试场景**

**Step 4: 运行测试验证**

**Step 5: 添加本地化翻译**

修改 `addons/bricks/localization/translations.csv`，添加：

```csv
BRICKS_EVENT_ON_NODE_PAUSED_RESUMED_NAME,节点暂停/恢复,Node Paused/Resumed
BRICKS_EVENT_ON_NODE_PAUSED_RESUMED_DESC,节点暂停模式变化时触发,Triggers when node pause mode changes
BRICKS_LOG_EVENT_NODE_PAUSED,节点已暂停,Node paused
BRICKS_LOG_EVENT_NODE_RESUMED,节点已恢复,Node resumed
```

**Step 6: Git 提交**

```bash
git add addons/bricks/events/scene/on_node_paused_resumed.gd
git add addons/bricks/tests/events/test_on_node_paused_resumed.gd
git add addons/bricks/tests/events/test_on_node_paused_resumed.tscn
git add addons/bricks/localization/translations.csv
git commit -m "feat: add OnNodePausedResumed event - detect pause mode changes

- Implement on_node_paused_resumed.gd with process_mode monitoring
- Support trigger_on: Paused/Resumed/Both modes
- Periodic checking with configurable interval
- Add comprehensive test coverage

Phase 5 - Scene Management Events (3/3) Complete"
```

---

## 最终验证

### Task 10: 更新 Roadmap 和统计

**Files:**
- Modify: `addons/bricks/docs/roadmap/2026-01-25-bricks-event-roadmap.md`

**Step 1: 标记所有 Phase 5 事件为已完成**

在 roadmap 文件的详细规格部分，为以下事件添加 ✅ 标记：
- 1.3 On Enter Tree ✅
- 1.4 On Exit Tree ✅
- 2.7 On Touch Swipe ✅
- 2.8 On Input Text ✅
- 3.4 On Screen Entered/Exited ✅
- 3.8 On Overlapping Bodies ✅
- 6.3 On Background Load Progress ✅
- 6.5 On Tree Changed ✅
- 7.3 On Node Paused/Resumed ✅

**Step 2: 更新统计部分**

修改"已实现统计"表格，将所有分类完成度更新为 100%：

```markdown
### 已实现统计（截至 2026-01-29）

| 类别 | 已实现 | 总数 | 完成度 |
|------|--------|------|--------|
| **生命周期事件** | 5 | 5 | 100% ✅ |
| **输入事件** | 8 | 8 | 100% ✅ |
| **碰撞/物理事件** | 10 | 10 | 100% ✅ |
| **信号事件** | 3 | 3 | 100% ✅ |
| **时间相关事件** | 5 | 5 | 100% ✅ |
| **场景管理事件** | 5 | 5 | 100% ✅ |
| **状态变化事件** | 8 | 8 | 100% ✅ |
| **动画事件** | 6 | 6 | 100% ✅ |
| **音频事件** | 5 | 5 | 100% ✅ |
| **UI 事件** | 8 | 8 | 100% ✅ |
| **Tween 事件** | 1 | 1 | 100% ✅ |
| **节点事件** | 4 | 4 | 100% ✅ |
| **总计** | **68** | **68** | **100% ✅** |
```

**Step 3: 添加 Phase 5 开发总结**

在 roadmap 末尾添加：

```markdown
## Phase 5 开发总结（最终阶段）

**开发时间**: 2026-01-29
**完成事件**: 9 个
**提交数**: 10 个（9个事件 + 1个roadmap更新）

### 已完成事件列表

**生命周期事件（2个）**
1. ✅ On Enter Tree - 节点进入场景树时触发
2. ✅ On Exit Tree - 节点退出场景树时触发

**输入事件（2个）**
3. ✅ On Touch Swipe - 触摸滑动手势检测
4. ✅ On Input Text - 文本输入事件监听

**物理/碰撞事件（2个）**
5. ✅ On Screen Entered/Exited - 进入/离开摄像机视野
6. ✅ On Overlapping Bodies - 区域内重叠物体数量变化

**场景管理事件（3个）**
7. ✅ On Background Load Progress - 后台加载进度变化
8. ✅ On Tree Changed - 场景树结构变化
9. ✅ On Node Paused/Resumed - 节点暂停/恢复

### 关键成就

- ✅ **完成所有剩余事件** - 实现了规划的全部 59 个事件
- ✅ **100% 测试覆盖** - 每个事件都有完整的测试场景和脚本
- ✅ **完整本地化** - 所有事件支持中英文双语
- ✅ **使用 Sub Agent 模式** - 使用 bricks-event-generator 技能高效生成代码
- ✅ **代码质量保证** - 遵循 event_creation_guide.md 规范
- ✅ **Git 提交规范** - 遵循 Conventional Commits 标准

### 最终统计

| 指标 | 数值 |
|------|------|
| **总事件数** | 59 个（不含 Network、AI、Persistence 等） |
| **完成度** | 100% ✅ |
| **测试文件** | 118 个（59 个 .gd + 59 个 .tscn） |
| **翻译条目** | ~600 条（中英文） |
| **开发周期** | Phase 0-5（已完成） |

### 技术亮点

1. **Sub Agent 并行开发** - 每个 Task 独立 agent，高效协作
2. **TDD 开发流程** - 测试先行，确保质量
3. **完整文档** - 每个事件都有详细注释和测试
4. **可维护性** - 统一命名规范，清晰架构
5. **本地化支持** - 完整的中英文翻译
```

**Step 4: Git 提交**

```bash
git add addons/bricks/docs/roadmap/2026-01-25-bricks-event-roadmap.md
git commit -m "docs: update roadmap - Phase 5 complete, 100% event coverage

- Mark all Phase 5 events as completed (9 events)
- Update statistics: 59/59 events (100%)
- Add Phase 5 development summary
- All event categories now complete
- Total: 68 events with lifecycle, input, physics, scene, state, animation, audio, UI

Phase 5 (Final) Complete - Bricks Event System 100% 🎉"
```

---

## 质量保证检查清单

在每个 Task 完成后，验证以下项目：

### 代码质量
- [ ] 文件命名正确：`on_<event_name>.gd`
- [ ] 类命名正确：`class_name On<EventName>`
- [ ] 使用 TAB 缩进（无空格）
- [ ] 实现所有必需方法：`_update_resource_name()`, `initialize()`, `terminate()`
- [ ] 实现推荐方法：`get_event_type()`, `get_event_category()`, `get_description()`, `validate()`, `_get_event_metadata()`

### 功能完整性
- [ ] 事件正确触发
- [ ] 参数验证工作正常
- [ ] 错误处理正确
- [ ] 资源清理无泄漏

### 测试覆盖
- [ ] 测试场景文件存在：`test_on_<event_name>.tscn`
- [ ] 测试脚本完整：至少 3 个测试用例
- [ ] 所有测试通过
- [ ] 边界情况已测试

### 本地化
- [ ] 翻译键添加到 translations.csv
- [ ] 使用本地化日志方法：`_log_*_localized()`
- [ ] 使用本地化错误方法：`_create_bricks_error_localized()`
- [ ] 占位符格式正确：`{variable_name}`

### Git 提交
- [ ] 提交消息遵循 Conventional Commits
- [ ] 所有相关文件已添加
- [ ] 提交包含清晰的功能描述

---

## 预期成果

### 功能完整性
- ✅ 59 个事件全部实现
- ✅ 每个事件都有完整测试
- ✅ 所有事件支持本地化
- ✅ 代码质量达到生产标准

### 代码统计
- 事件实现文件：59 个 `.gd` 文件
- 测试场景文件：59 个 `.tscn` 文件
- 测试脚本文件：59 个 `.gd` 文件
- 翻译条目：~600 条（中英文）
- 代码行数：~15,000 行（估算）

### 文档完整性
- ✅ Roadmap 更新至 100% 完成度
- ✅ 每个事件都有详细注释
- ✅ 测试用例覆盖所有功能
- ✅ 开发指南完整（event_creation_guide.md）

### 系统能力
Bricks Event System 将支持：
- 生命周期管理（5 个事件）
- 完整输入系统（8 个事件）
- 物理碰撞检测（10 个事件）
- 信号监听（3 个事件）
- 时间控制（5 个事件）
- 场景管理（5 个事件）
- 状态监控（8 个事件）
- 动画控制（6 个事件）
- 音频处理（5 个事件）
- UI 交互（8 个事件）
- Tween 控制（1 个事件）
- 节点操作（4 个事件）

---

## 总结

本计划将完成 Bricks Event System 的最后 9 个事件，达到 100% 完成度（59/59）。

**开发策略**：
- 使用 Sub Agent 模式，每个事件独立开发
- 严格遵循 `event_creation_guide.md` 规范
- 使用 `bricks-event-generator` 技能生成代码
- TDD 开发流程，测试先行
- 完整的本地化和文档支持

**预期时间**：每个事件约 15-20 分钟，总计约 3-4 小时

**质量保证**：
- 每个事件独立审查
- 所有测试必须通过
- 代码规范检查
- 文档完整性验证

**最终目标**：🎉 Bricks Event System 100% 完成！
