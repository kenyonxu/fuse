# Bricks Tween Instructions Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 为 Bricks 可视化编程系统实现 11 个 Tween 补间动画指令，覆盖淡入淡出、移动、缩放、旋转、颜色过渡和预置动画效果。

**Architecture:** 所有 Tween 指令继承自 BaseInstruction，使用 Godot 原生 Tween 系统（`tween_property()` API），支持异步执行（`_is_async = true`）。基础属性动画统一支持 easing_type 和 trans_type 参数，Tween Fade Out 和 Tween Property 支持 auto_free 参数用于动画后自动清理。

**Tech Stack:** Godot 4.6+, GDScript 2.0, Bricks Framework (BaseInstruction, ExecutionContext, PropertyManager, PropertyInfo)

---

## Table of Contents
1. [Phase 0: 基础架构准备](#phase-0-基础架构准备)
2. [Phase 1: P0 核心动画指令](#phase-1-p0-核心动画指令)
3. [Phase 2: P1-P2 预置动画](#phase-2-p1-p2-预置动画)
4. [Phase 3: P3 高级功能](#phase-3-p3-高级功能)
5. [Testing Strategy](#testing-strategy)
6. [Documentation Requirements](#documentation-requirements)

---

## Phase 0: 基础架构准备

### Task 0.1: 创建 Tween 指令目录结构

**Files:**
- Create: `addons/bricks/instructions/tween/` (directory)
- Create: `addons/bricks/instructions/tween/README.md`

**Step 1: 创建目录**

```bash
mkdir -p addons/bricks/instructions/tween
```

**Step 2: 创建 README 说明文件**

Create: `addons/bricks/instructions/tween/README.md`

```markdown
# Bricks Tween Instructions

Tween 补间动画指令集合，基于 Godot 原生 Tween 系统。

## 指令清单

### 基础属性动画 (P0-P1)
- TweenFadeIn - 淡入动画
- TweenFadeOut - 淡出动画 (支持 auto_free)
- TweenMoveTo - 移动动画
- TweenScaleTo - 缩放动画
- TweenRotateTo - 旋转动画
- TweenColorTransition - 颜色过渡

### 预置动画 (P2-P3)
- TweenPopAnimation - 弹出动画
- TweenShakeAnimation - 震动动画
- TweenBounceAnimation - 弹跳动画
- TweenPulseAnimation - 脉冲动画

### 高级功能 (P3)
- TweenProperty - 通用属性动画 (支持 auto_free)

## 技术要点

- 所有指令都是异步的 (_is_async = true)
- 基础动画支持 easing_type 和 trans_type 参数
- 使用 create_tween() 和 tween_property() API
- 参考 Tween 通用模式: docs/tween-common-patterns.md
```

**Step 3: Commit**

```bash
git add addons/bricks/instructions/tween/
git commit -m "chore: create tween instructions directory structure"
```

---

### Task 0.2: 创建 Tween 基类（可选，用于共享代码）

**Files:**
- Create: `addons/bricks/instructions/tween/base_tween_instruction.gd`

**Step 1: 创建基础 Tween 指令类**

Create: `addons/bricks/instructions/tween/base_tween_instruction.gd`

```gdscript
@tool
extends BaseInstruction
class_name BaseTweenInstruction

## Tween 基类，提供通用功能

# 缓动类型枚举
enum EasingType {
	EASE_IN,
	EASE_OUT,
	EASE_IN_OUT,
	EASE_OUT_IN
}

# 过渡类型枚举
enum TransitionType {
	LINEAR,
	SINE,
	QUAD,
	CUBIC,
	QUART,
	QUINT,
	EXPO,
	CIRC,
	BACK,
	SPRING,
	BOUNCE,
	ELASTIC
}

## 标记为异步指令
func _init():
	_is_async = true

## 创建并配置 Tween
func _create_tween(target: Node) -> Tween:
	var tween = target.create_tween()
	return tween

## 应用缓动设置
func _apply_easing_settings(tween: Tween, easing_type: int, trans_type: int) -> void:
	var tween_easing = Tween.EaseType.EASE_IN_OUT
	var tween_trans = Tween.TransitionType.TRANS_SINE

	# 转换 easing_type
	match easing_type:
		0: tween_easing = Tween.EaseType.EASE_IN
		1: tween_easing = Tween.EaseType.EASE_OUT
		2: tween_easing = Tween.EaseType.EASE_IN_OUT
		3: tween_easing = Tween.EaseType.EASE_OUT_IN

	# 转换 trans_type
	match trans_type:
		0: tween_trans = Tween.TransitionType.TRANS_LINEAR
		1: tween_trans = Tween.TransitionType.TRANS_SINE
		2: tween_trans = Tween.TransitionType.TRANS_QUAD
		3: tween_trans = Tween.TransitionType.TRANS_CUBIC
		4: tween_trans = Tween.TransitionType.TRANS_QUART
		5: tween_trans = Tween.TransitionType.TRANS_QUINT
		6: tween_trans = Tween.TransitionType.TRANS_EXPO
		7: tween_trans = Tween.TransitionType.TRANS_CIRC
		8: tween_trans = Tween.TransitionType.TRANS_BACK
		9: tween_trans = Tween.TransitionType.TRANS_SPRING
		10: tween_trans = Tween.TransitionType.TRANS_BOUNCE
		11: tween_trans = Tween.TransitionType.TRANS_ELASTIC

	tween.set_ease(tween_easing)
	tween.set_trans(tween_trans)

## 获取目标节点
func _get_target_node(context: ExecutionContext, node_path: NodePath) -> Node:
	var scene_root = Engine.get_main_loop().current_scene
	var root_path = scene_root.get_path()
	var target_path = NodePath(str(root_path) + str(node_path).replace("..", ""))
	return scene_root.get_node_or_null(target_path)
```

**Step 2: Commit**

```bash
git add addons/bricks/instructions/tween/base_tween_instruction.gd
git commit -m "feat: add BaseTweenInstruction base class"
```

---

## Phase 1: P0 核心动画指令

### Task 1.1: Tween Fade In 指令

**Files:**
- Create: `addons/bricks/instructions/tween/tween_fade_in.gd`
- Create: `addons/bricks/tests/tween/test_tween_fade_in.tscn`
- Create: `addons/bricks/tests/tween/test_tween_fade_in_instruction.gd`

**Step 1: 使用 bricks-instruction-generator 技能生成模板**

可以使用 **bricks-instruction-generator** 技能快速生成指令模板代码。

或者手动创建：

**Step 2: 创建 TweenFadeIn 指令**

Create: `addons/bricks/instructions/tween/tween_fade_in.gd`

```gdscript
@tool
@icon("res://addons/bricks/icons/builtin/MemberProperty.png")
extends BaseTweenInstruction
class_name TweenFadeIn

## 指令元数据
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "BRICKS_INSTRUCTION_TWEEN_FADE_IN_NAME"
	metadata.category_key = "BRICKS_CATEGORY_TWEEN"
	metadata.description_key = "BRICKS_INSTRUCTION_TWEEN_FADE_IN_DESC"
	metadata.keywords = ["tween", "fade", "in", "opacity", "alpha", "淡入", "透明度", "动画"]
	metadata.builtin_icon = "MemberProperty"
	return metadata

## 参数配置
var target_node: NodePath = NodePath(""):
	set(value):
		target_node = value
		_update_resource_name()
		notify_property_list_changed()

var duration: float = 0.5:
	set(value):
		duration = value
		_update_resource_name()

var from_alpha: float = 0.0:
	set(value):
		from_alpha = value
		_update_resource_name()

var to_alpha: float = 1.0:
	set(value):
		to_alpha = value
		_update_resource_name()

var easing_type: EasingType = EASE_OUT:
	set(value):
		easing_type = value
		_update_resource_name()

var trans_type: TransitionType = TRANS_SINE:
	set(value):
		trans_type = value
		_update_resource_name()

## 执行指令
func execute(context: ExecutionContext) -> void:
	_start_execution(context)

	# 获取目标节点
	var target = _get_target_node(context, target_node)
	if target == null:
		_log_error_localized("BRICKS_ERROR_TARGET_NODE_NOT_FOUND", {"node": str(target_node)})
		set_error_localized("BRICKS_ERROR_TARGET_NODE_NOT_FOUND", BricksError.ErrorType.RUNTIME_ERROR, {"node": str(target_node)})
		finished.emit()
		return

	# 验证节点有 modulate 属性
	if not "modulate" in target:
		_log_error("目标节点不支持 modulate 属性")
		set_error(BricksError.ErrorType.VALIDATION_ERROR)
		finished.emit()
		return

	# 创建 Tween
	var tween = _create_tween(target)
	_apply_easing_settings(tween, easing_type, trans_type)

	# 设置起始透明度
	if target.has_method("set_modulate"):
		target.modulate.a = from_alpha

	# 播放淡入动画
	tween.tween_property(target, "modulate:a", to_alpha, duration)

	_log_info_localized("BRICKS_LOG_TWEEN_FADE_IN", {
		"node": target.name,
		"from": str(from_alpha),
		"to": str(to_alpha),
		"duration": str(duration)
	})

	# 等待动画完成
	await tween.finished
	_on_execution_completed()

## 取消指令
func cancel():
	if is_running():
		_log_debug("取消 Tween Fade In 指令")
		super.cancel()

## 更新资源名称
func _update_resource_name():
	var parts = []
	parts.append("Tween Fade In")

	if not target_node.is_empty():
		parts.append("[%s]" % str(target_node))
	else:
		parts.append("[未选择节点]")

	parts.append("alpha: %s→%s" % [str(from_alpha), str(to_alpha)])
	parts.append("(%.2fs)" % duration)

	resource_name = " ".join(parts)

## 获取指令描述
func get_description() -> String:
	var target_desc = str(target_node) if not target_node.is_empty() else "未选择节点"
	return "淡入 %s 的透明度从 %.2f 到 %.2f" % [target_desc, from_alpha, to_alpha]
```

**Step 3: 创建测试场景**

Create: `addons/bricks/tests/tween/test_tween_fade_in.tscn`

```gdscript
[gd_scene load_steps=2 format=3 uid="uid://test_tween_fade_in"]

[ext_resource type="Script" path="res://addons/bricks/tests/tween/test_tween_fade_in_instruction.gd" id="1_0xyza"]

[node name="TestTweenFadeIn" type="Node2D"]
script = ExtResource("1_0xyza")

[node name="TestSprite" type="Sprite2D" parent="."]
modulate = Color(1, 1, 1, 0)
position = Vector2(100, 100)

[node name="Label" type="Label" parent="."]
offset_left = 20.0
offset_top = 20.0
offset_right = 420.0
offset_bottom = 60.0
text = "Tween Fade In Test - Press SPACE to start"
```

**Step 4: 创建测试脚本**

Create: `addons/bricks/tests/tween/test_tween_fade_in_instruction.gd`

```gdscript
extends Node2D

## Tween Fade In 指令测试

func _input(event):
	if event.is_action_pressed("ui_accept"):
		_test_fade_in()

func _test_fade_in():
	print("=== 测试 Tween Fade In 指令 ===")

	var context = ExecutionContext.new()
	var instruction = TweenFadeIn.new()

	# 配置参数
	instruction.target_node = ^"TestSprite"
	instruction.duration = 1.0
	instruction.from_alpha = 0.0
	instruction.to_alpha = 1.0
	instruction.easing_type = BaseTweenInstruction.EasingType.EASE_OUT

	# 连接完成信号
	instruction.finished.connect(_on_fade_in_completed)

	# 执行指令
	add_child(instruction)
	instruction.execute(context)

	print("✓ Tween Fade In 指令已启动")

func _on_fade_in_completed():
	print("✓ Tween Fade In 指令已完成")
	print("测试通过！")
```

**Step 5: 在 Godot 中运行测试**

1. 打开 Godot 编辑器
2. 打开 `addons/bricks/tests/tween/test_tween_fade_in.tscn`
3. 按 F5 运行场景
4. 按空格键触发测试
5. 验证 Sprite 从透明逐渐变为不透明

**Expected Output:**
- Sprite 在 1 秒内从完全透明淡入到完全不透明
- 控制台输出："✓ Tween Fade In 指令已完成"

**Step 6: Commit**

```bash
git add addons/bricks/instructions/tween/tween_fade_in.gd
git add addons/bricks/tests/tween/test_tween_fade_in.*
git commit -m "feat: implement TweenFadeIn instruction"
```

---

### Task 1.2: Tween Fade Out 指令（包含 auto_free）

**Files:**
- Create: `addons/bricks/instructions/tween/tween_fade_out.gd`
- Create: `addons/bricks/tests/tween/test_tween_fade_out.tscn`
- Create: `addons/bricks/tests/tween/test_tween_fade_out_instruction.gd`

**Step 1: 创建 TweenFadeOut 指令**

Create: `addons/bricks/instructions/tween/tween_fade_out.gd`

```gdscript
@tool
@icon("res://addons/bricks/icons/builtin/MemberProperty.png")
extends BaseTweenInstruction
class_name TweenFadeOut

## 指令元数据
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "BRICKS_INSTRUCTION_TWEEN_FADE_OUT_NAME"
	metadata.category_key = "BRICKS_CATEGORY_TWEEN"
	metadata.description_key = "BRICKS_INSTRUCTION_TWEEN_FADE_OUT_DESC"
	metadata.keywords = ["tween", "fade", "out", "opacity", "alpha", "淡出", "透明度", "动画", "自动释放"]
	metadata.builtin_icon = "MemberProperty"
	return metadata

## 参数配置
var target_node: NodePath = NodePath(""):
	set(value):
		target_node = value
		_update_resource_name()
		notify_property_list_changed()

var duration: float = 0.5:
	set(value):
		duration = value
		_update_resource_name()

var auto_free: bool = false:
	set(value):
		auto_free = value
		_update_resource_name()
		notify_property_list_changed()

var easing_type: EasingType = EASE_IN:
	set(value):
		easing_type = value
		_update_resource_name()

var trans_type: TransitionType = TRANS_SINE:
	set(value):
		trans_type = value
		_update_resource_name()

## 执行指令
func execute(context: ExecutionContext) -> void:
	_start_execution(context)

	# 获取目标节点
	var target = _get_target_node(context, target_node)
	if target == null:
		_log_error_localized("BRICKS_ERROR_TARGET_NODE_NOT_FOUND", {"node": str(target_node)})
		set_error_localized("BRICKS_ERROR_TARGET_NODE_NOT_FOUND", BricksError.ErrorType.RUNTIME_ERROR, {"node": str(target_node)})
		finished.emit()
		return

	# 验证节点有 modulate 属性
	if not "modulate" in target:
		_log_error("目标节点不支持 modulate 属性")
		set_error(BricksError.ErrorType.VALIDATION_ERROR)
		finished.emit()
		return

	# 创建 Tween
	var tween = _create_tween(target)
	_apply_easing_settings(tween, easing_type, trans_type)

	# 播放淡出动画
	tween.tween_property(target, "modulate:a", 0.0, duration)

	# 如果启用 auto_free，在动画结束后释放节点
	if auto_free:
		tween.tween_callback(target.queue_free)
		_log_info("auto_free 已启用，动画完成后将释放节点: %s" % target.name)

	_log_info_localized("BRICKS_LOG_TWEEN_FADE_OUT", {
		"node": target.name,
		"duration": str(duration),
		"auto_free": str(auto_free)
	})

	# 等待动画完成
	await tween.finished
	_on_execution_completed()

## 更新资源名称
func _update_resource_name():
	var parts = []
	parts.append("Tween Fade Out")

	if not target_node.is_empty():
		parts.append("[%s]" % str(target_node))

	if auto_free:
		parts.append("[auto_free]")

	parts.append("(%.2fs)" % duration)

	resource_name = " ".join(parts)

## 获取指令描述
func get_description() -> String:
	var target_desc = str(target_node) if not target_node.is_empty() else "未选择节点"
	var auto_free_desc = " + 自动释放" if auto_free else ""
	return "淡出 %s 的透明度%s" % [target_desc, auto_free_desc]
```

**Step 2-6:** 创建测试场景、测试脚本、运行测试、提交（参考 Task 1.1）

**测试要点：**
- 测试淡出效果（透明度 1.0 → 0.0）
- 测试 auto_free 功能（验证节点在动画结束后被删除）

```bash
git add addons/bricks/instructions/tween/tween_fade_out.gd
git add addons/bricks/tests/tween/test_tween_fade_out.*
git commit -m "feat: implement TweenFadeOut instruction with auto_free support"
```

---

### Task 1.3: Tween Move To 指令

**Files:**
- Create: `addons/bricks/instructions/tween/tween_move_to.gd`
- Create: `addons/bricks/tests/tween/test_tween_move_to.tscn`
- Create: `addons/bricks/tests/tween/test_tween_move_to_instruction.gd`

**Step 1: 创建 TweenMoveTo 指令**

Create: `addons/bricks/instructions/tween/tween_move_to.gd`

```gdscript
@tool
@icon("res://addons/bricks/icons/builtin/MemberProperty.png")
extends BaseTweenInstruction
class_name TweenMoveTo

## 指令元数据
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "BRICKS_INSTRUCTION_TWEEN_MOVE_TO_NAME"
	metadata.category_key = "BRICKS_CATEGORY_TWEEN"
	metadata.description_key = "BRICKS_INSTRUCTION_TWEEN_MOVE_TO_DESC"
	metadata.keywords = ["tween", "move", "position", "移动", "位置", "动画"]
	metadata.builtin_icon = "MemberProperty"
	return metadata

## 坐标空间枚举
enum SpaceMode {
	GLOBAL,
	LOCAL
}

## 参数配置
var target_node: NodePath = NodePath(""):
	set(value):
		target_node = value
		_update_resource_name()
		notify_property_list_changed()

var target_position: Vector2 = Vector2.ZERO:
	set(value):
		target_position = value
		_update_resource_name()

var duration: float = 0.5:
	set(value):
		duration = value
		_update_resource_name()

var space_mode: SpaceMode = SpaceMode.GLOBAL:
	set(value):
		space_mode = value
		_update_resource_name()
		notify_property_list_changed()

var easing_type: EasingType = EASE_IN_OUT:
	set(value):
		easing_type = value
		_update_resource_name()

var trans_type: TransitionType = TRANS_SINE:
	set(value):
		trans_type = value
		_update_resource_name()

## 执行指令
func execute(context: ExecutionContext) -> void:
	_start_execution(context)

	# 获取目标节点
	var target = _get_target_node(context, target_node)
	if target == null:
		_log_error_localized("BRICKS_ERROR_TARGET_NODE_NOT_FOUND", {"node": str(target_node)})
		set_error_localized("BRICKS_ERROR_TARGET_NODE_NOT_FOUND", BricksError.ErrorType.RUNTIME_ERROR, {"node": str(target_node)})
		finished.emit()
		return

	# 验证节点有 position 属性
	if not "position" in target:
		_log_error("目标节点不支持 position 属性")
		set_error(BricksError.ErrorType.VALIDATION_ERROR)
		finished.emit()
		return

	# 创建 Tween
	var tween = _create_tween(target)
	_apply_easing_settings(tween, easing_type, trans_type)

	# 根据坐标空间选择属性
	var property_name = "global_position" if space_mode == SpaceMode.GLOBAL else "position"

	# 播放移动动画
	tween.tween_property(target, property_name, target_position, duration)

	_log_info_localized("BRICKS_LOG_TWEEN_MOVE_TO", {
		"node": target.name,
		"position": str(target_position),
		"space": "global" if space_mode == SpaceMode.GLOBAL else "local",
		"duration": str(duration)
	})

	# 等待动画完成
	await tween.finished
	_on_execution_completed()

## 更新资源名称
func _update_resource_name():
	var parts = []
	parts.append("Tween Move To")

	if not target_node.is_empty():
		parts.append("[%s]" % str(target_node))

	parts.append(str(target_position))
	parts.append("(%s)" % ("global" if space_mode == SpaceMode.GLOBAL else "local"))
	parts.append("(%.2fs)" % duration)

	resource_name = " ".join(parts)

## 获取指令描述
func get_description() -> String:
	var target_desc = str(target_node) if not target_node.is_empty() else "未选择节点"
	var space_desc = "全局" if space_mode == SpaceMode.GLOBAL else "本地"
	return "移动 %s 到 %s (%s坐标)" % [target_desc, str(target_position), space_desc]
```

**Step 2-6:** 创建测试场景、测试脚本、运行测试、提交

**测试要点：**
- 测试全局坐标移动
- 测试本地坐标移动
- 验证移动平滑性

```bash
git add addons/bricks/instructions/tween/tween_move_to.gd
git add addons/bricks/tests/tween/test_tween_move_to.*
git commit -m "feat: implement TweenMoveTo instruction"
```

---

### Task 1.4: Tween Scale To 指令

**Files:**
- Create: `addons/bricks/instructions/tween/tween_scale_to.gd`
- Test: `addons/bricks/tests/tween/test_tween_scale_to.*`

**Step 1: 创建 TweenScaleTo 指令**

Create: `addons/bricks/instructions/tween/tween_scale_to.gd`

```gdscript
@tool
@icon("res://addons/bricks/icons/builtin/MemberProperty.png")
extends BaseTweenInstruction
class_name TweenScaleTo

## 指令元数据
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "BRICKS_INSTRUCTION_TWEEN_SCALE_TO_NAME"
	metadata.category_key = "BRICKS_CATEGORY_TWEEN"
	metadata.description_key = "BRICKS_INSTRUCTION_TWEEN_SCALE_TO_DESC"
	metadata.keywords = ["tween", "scale", "size", "缩放", "大小", "动画"]
	metadata.builtin_icon = "MemberProperty"
	return metadata

## 参数配置
var target_node: NodePath = NodePath(""):
	set(value):
		target_node = value
		_update_resource_name()
		notify_property_list_changed()

var target_scale: Vector2 = Vector2.ONE:
	set(value):
		target_scale = value
		_update_resource_name()

var duration: float = 0.5:
	set(value):
		duration = value
		_update_resource_name()

var easing_type: EasingType = EASE_OUT:
	set(value):
		easing_type = value
		_update_resource_name()

var trans_type: TransitionType = TRANS_BACK:
	set(value):
		trans_type = value
		_update_resource_name()

## 执行指令
func execute(context: ExecutionContext) -> void:
	_start_execution(context)

	var target = _get_target_node(context, target_node)
	if target == null:
		_log_error_localized("BRICKS_ERROR_TARGET_NODE_NOT_FOUND", {"node": str(target_node)})
		set_error_localized("BRICKS_ERROR_TARGET_NODE_NOT_FOUND", BricksError.ErrorType.RUNTIME_ERROR, {"node": str(target_node)})
		finished.emit()
		return

	if not "scale" in target:
		_log_error("目标节点不支持 scale 属性")
		set_error(BricksError.ErrorType.VALIDATION_ERROR)
		finished.emit()
		return

	var tween = _create_tween(target)
	_apply_easing_settings(tween, easing_type, trans_type)

	tween.tween_property(target, "scale", target_scale, duration)

	_log_info_localized("BRICKS_LOG_TWEEN_SCALE_TO", {
		"node": target.name,
		"scale": str(target_scale),
		"duration": str(duration)
	})

	await tween.finished
	_on_execution_completed()

## 更新资源名称、获取指令描述
# (参考前面的指令实现模式)
```

**Step 2-6:** 测试、提交（参考 Task 1.3）

```bash
git add addons/bricks/instructions/tween/tween_scale_to.gd
git add addons/bricks/tests/tween/test_tween_scale_to.*
git commit -m "feat: implement TweenScaleTo instruction"
```

---

### Task 1.5: Tween Rotate To 指令

**Files:**
- Create: `addons/bricks/instructions/tween/tween_rotate_to.gd`
- Test: `addons/bricks/tests/tween/test_tween_rotate_to.*`

**Step 1: 创建 TweenRotateTo 指令**

Create: `addons/bricks/instructions/tween/tween_rotate_to.gd`

```gdscript
@tool
@icon("res://addons/bricks/icons/builtin/MemberProperty.png")
extends BaseTweenInstruction
class_name TweenRotateTo

## 指令元数据
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "BRICKS_INSTRUCTION_TWEEN_ROTATE_TO_NAME"
	metadata.category_key = "BRICKS_CATEGORY_TWEEN"
	metadata.description_key = "BRICKS_INSTRUCTION_TWEEN_ROTATE_TO_DESC"
	metadata.keywords = ["tween", "rotate", "rotation", "angle", "旋转", "角度", "动画"]
	metadata.builtin_icon = "MemberProperty"
	return metadata

## 坐标空间枚举
enum SpaceMode {
	GLOBAL,
	LOCAL
}

## 参数配置
var target_node: NodePath = NodePath(""):
	set(value):
		target_node = value
		_update_resource_name()
		notify_property_list_changed()

var target_rotation: float = 0.0:
	set(value):
		target_rotation = value
		_update_resource_name()

var duration: float = 0.5:
	set(value):
		duration = value
		_update_resource_name()

var space_mode: SpaceMode = SpaceMode.LOCAL:
	set(value):
		space_mode = value
		_update_resource_name()
		notify_property_list_changed()

var easing_type: EasingType = EASE_IN_OUT:
	set(value):
		easing_type = value
		_update_resource_name()

var trans_type: TransitionType = TRANS_SINE:
	set(value):
		trans_type = value
		_update_resource_name()

## 执行指令
func execute(context: ExecutionContext) -> void:
	_start_execution(context)

	var target = _get_target_node(context, target_node)
	if target == null:
		_log_error_localized("BRICKS_ERROR_TARGET_NODE_NOT_FOUND", {"node": str(target_node)})
		set_error_localized("BRICKS_ERROR_TARGET_NODE_NOT_FOUND", BricksError.ErrorType.RUNTIME_ERROR, {"node": str(target_node)})
		finished.emit()
		return

	# Node2D 使用 rotation，Node3D 使用 rotation_degrees
	var property_name = "rotation" if target is Node2D else "rotation_degrees"

	if not property_name in target:
		_log_error("目标节点不支持 %s 属性" % property_name)
		set_error(BricksError.ErrorType.VALIDATION_ERROR)
		finished.emit()
		return

	var tween = _create_tween(target)
	_apply_easing_settings(tween, easing_type, trans_type)

	tween.tween_property(target, property_name, deg_to_rad(target_rotation) if target is Node2D else target_rotation, duration)

	_log_info_localized("BRICKS_LOG_TWEEN_ROTATE_TO", {
		"node": target.name,
		"rotation": str(target_rotation),
		"duration": str(duration)
	})

	await tween.finished
	_on_execution_completed()

## 更新资源名称、获取指令描述
# (参考前面的指令实现模式)
```

**Step 2-6:** 测试、提交

```bash
git add addons/bricks/instructions/tween/tween_rotate_to.gd
git add addons/bricks/tests/tween/test_tween_rotate_to.*
git commit -m "feat: implement TweenRotateTo instruction"
```

---

## Phase 2: P1-P2 预置动画

### Task 2.1: Tween Color Transition 指令 (P1)

**Files:**
- Create: `addons/bricks/instructions/tween/tween_color_transition.gd`
- Test: `addons/bricks/tests/tween/test_tween_color_transition.*`

**Step 1: 创建 TweenColorTransition 指令**

Create: `addons/bricks/instructions/tween/tween_color_transition.gd`

```gdscript
@tool
@icon("res://addons/bricks/icons/builtin/MemberProperty.png")
extends BaseTweenInstruction
class_name TweenColorTransition

## 指令元数据
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "BRICKS_INSTRUCTION_TWEEN_COLOR_TRANSITION_NAME"
	metadata.category_key = "BRICKS_CATEGORY_TWEEN"
	metadata.description_key = "BRICKS_INSTRUCTION_TWEEN_COLOR_TRANSITION_DESC"
	metadata.keywords = ["tween", "color", "modulate", "颜色", "过渡", "动画"]
	metadata.builtin_icon = "MemberProperty"
	return metadata

## 参数配置
var target_node: NodePath = NodePath(""):
	set(value):
		target_node = value
		_update_resource_name()
		notify_property_list_changed()

var target_color: Color = Color.WHITE:
	set(value):
		target_color = value
		_update_resource_name()

var duration: float = 0.5:
	set(value):
		duration = value
		_update_resource_name()

var easing_type: EasingType = EASE_IN_OUT:
	set(value):
		easing_type = value
		_update_resource_name()

var trans_type: TransitionType = TRANS_SINE:
	set(value):
		trans_type = value
		_update_resource_name()

## 执行指令
func execute(context: ExecutionContext) -> void:
	_start_execution(context)

	var target = _get_target_node(context, target_node)
	if target == null:
		_log_error_localized("BRICKS_ERROR_TARGET_NODE_NOT_FOUND", {"node": str(target_node)})
		set_error_localized("BRICKS_ERROR_TARGET_NODE_NOT_FOUND", BricksError.ErrorType.RUNTIME_ERROR, {"node": str(target_node)})
		finished.emit()
		return

	if not "modulate" in target:
		_log_error("目标节点不支持 modulate 属性")
		set_error(BricksError.ErrorType.VALIDATION_ERROR)
		finished.emit()
		return

	var tween = _create_tween(target)
	_apply_easing_settings(tween, easing_type, trans_type)

	tween.tween_property(target, "modulate", target_color, duration)

	_log_info_localized("BRICKS_LOG_TWEEN_COLOR_TRANSITION", {
		"node": target.name,
		"color": str(target_color),
		"duration": str(duration)
	})

	await tween.finished
	_on_execution_completed()

## 更新资源名称、获取指令描述
# (参考前面的指令实现模式)
```

**Step 2-6:** 测试、提交

```bash
git add addons/bricks/instructions/tween/tween_color_transition.gd
git add addons/bricks/tests/tween/test_tween_color_transition.*
git commit -m "feat: implement TweenColorTransition instruction"
```

---

### Task 2.2: Tween Pop Animation 指令 (P2)

**Files:**
- Create: `addons/bricks/instructions/tween/tween_pop_animation.gd`
- Test: `addons/bricks/tests/tween/test_tween_pop_animation.*`

**Step 1: 创建 TweenPopAnimation 指令**

Create: `addons/bricks/instructions/tween/tween_pop_animation.gd`

```gdscript
@tool
@icon("res://addons/bricks/icons/builtin/MemberProperty.png")
extends BaseTweenInstruction
class_name TweenPopAnimation

## 指令元数据
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "BRICKS_INSTRUCTION_TWEEN_POP_ANIMATION_NAME"
	metadata.category_key = "BRICKS_CATEGORY_TWEEN"
	metadata.description_key = "BRICKS_INSTRUCTION_TWEEN_POP_ANIMATION_DESC"
	metadata.keywords = ["tween", "pop", "scale", "弹出", "缩放", "弹簧"]
	metadata.builtin_icon = "MemberProperty"
	return metadata

## 参数配置
var target_node: NodePath = NodePath(""):
	set(value):
		target_node = value
		_update_resource_name()
		notify_property_list_changed()

var target_scale: Vector2 = Vector2.ONE:
	set(value):
		target_scale = value
		_update_resource_name()

var duration: float = 0.4:
	set(value):
		duration = value
		_update_resource_name()

## 执行指令
func execute(context: ExecutionContext) -> void:
	_start_execution(context)

	var target = _get_target_node(context, target_node)
	if target == null:
		_log_error_localized("BRICKS_ERROR_TARGET_NODE_NOT_FOUND", {"node": str(target_node)})
		set_error_localized("BRICKS_ERROR_TARGET_NODE_NOT_FOUND", BricksError.ErrorType.RUNTIME_ERROR, {"node": str(target_node)})
		finished.emit()
		return

	if not "scale" in target:
		_log_error("目标节点不支持 scale 属性")
		set_error(BricksError.ErrorType.VALIDATION_ERROR)
		finished.emit()
		return

	# 设置初始缩放为 0
	target.scale = Vector2.ZERO

	# 创建 Tween 并设置弹簧效果
	var tween = _create_tween(target)
	tween.set_trans(Tween.TransitionType.TRANS_SPRING)
	tween.set_ease(Tween.EaseType.EASE_OUT)

	tween.tween_property(target, "scale", target_scale, duration)

	_log_info_localized("BRICKS_LOG_TWEEN_POP_ANIMATION", {
		"node": target.name,
		"scale": str(target_scale),
		"duration": str(duration)
	})

	await tween.finished
	_on_execution_completed()

## 更新资源名称、获取指令描述
# (参考前面的指令实现模式)
```

**Step 2-6:** 测试（验证弹簧弹出效果）、提交

```bash
git add addons/bricks/instructions/tween/tween_pop_animation.gd
git add addons/bricks/tests/tween/test_tween_pop_animation.*
git commit -m "feat: implement TweenPopAnimation instruction with spring effect"
```

---

### Task 2.3: Tween Shake Animation 指令 (P2)

**Files:**
- Create: `addons/bricks/instructions/tween/tween_shake_animation.gd`
- Test: `addons/bricks/tests/tween/test_tween_shake_animation.*`

**Step 1: 创建 TweenShakeAnimation 指令**

Create: `addons/bricks/instructions/tween/tween_shake_animation.gd`

```gdscript
@tool
@icon("res://addons/bricks/icons/builtin/MemberProperty.png")
extends BaseTweenInstruction
class_name TweenShakeAnimation

## 指令元数据
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "BRICKS_INSTRUCTION_TWEEN_SHAKE_ANIMATION_NAME"
	metadata.category_key = "BRICKS_CATEGORY_TWEEN"
	metadata.description_key = "BRICKS_INSTRUCTION_TWEEN_SHAKE_ANIMATION_DESC"
	metadata.keywords = ["tween", "shake", "震动", "抖动"]
	metadata.builtin_icon = "MemberProperty"
	return metadata

## 震动轴向枚举
enum ShakeAxis {
	X,
	Y,
	XY
}

## 参数配置
var target_node: NodePath = NodePath(""):
	set(value):
		target_node = value
		_update_resource_name()
		notify_property_list_changed()

var intensity: float = 10.0:
	set(value):
		intensity = value
		_update_resource_name()

var duration: float = 0.3:
	set(value):
		duration = value
		_update_resource_name()

var shake_count: int = 3:
	set(value):
		shake_count = value
		_update_resource_name()
		notify_property_list_changed()

var shake_axis: ShakeAxis = ShakeAxis.XY:
	set(value):
		shake_axis = value
		_update_resource_name()
		notify_property_list_changed()

## 执行指令
func execute(context: ExecutionContext) -> void:
	_start_execution(context)

	var target = _get_target_node(context, target_node)
	if target == null:
		_log_error_localized("BRICKS_ERROR_TARGET_NODE_NOT_FOUND", {"node": str(target_node)})
		set_error_localized("BRICKS_ERROR_TARGET_NODE_NOT_FOUND", BricksError.ErrorType.RUNTIME_ERROR, {"node": str(target_node)})
		finished.emit()
		return

	if not "position" in target:
		_log_error("目标节点不支持 position 属性")
		set_error(BricksError.ErrorType.VALIDATION_ERROR)
		finished.emit()
		return

	var tween = _create_tween(target)
	tween.set_loops(shake_count)
	tween.set_parallel(true)

	# 根据轴向选择震动方向
	match shake_axis:
		ShakeAxis.X:
			tween.tween_property(target, "position:x", intensity, duration * 0.25).as_relative()
			tween.tween_property(target, "position:x", -intensity, duration * 0.25).as_relative()
			tween.tween_property(target, "position:x", 0, duration * 0.25).as_relative()
		ShakeAxis.Y:
			tween.tween_property(target, "position:y", intensity, duration * 0.25).as_relative()
			tween.tween_property(target, "position:y", -intensity, duration * 0.25).as_relative()
			tween.tween_property(target, "position:y", 0, duration * 0.25).as_relative()
		ShakeAxis.XY:
			tween.tween_property(target, "position", Vector2(intensity, intensity), duration * 0.25).as_relative()
			tween.tween_property(target, "position", Vector2(-intensity, -intensity), duration * 0.25).as_relative()
			tween.tween_property(target, "position", Vector2.ZERO, duration * 0.25).as_relative()

	_log_info_localized("BRICKS_LOG_TWEEN_SHAKE_ANIMATION", {
		"node": target.name,
		"intensity": str(intensity),
		"count": str(shake_count),
		"axis": "X" if shake_axis == ShakeAxis.X else "Y" if shake_axis == ShakeAxis.Y else "XY"
	})

	await tween.finished
	_on_execution_completed()

## 更新资源名称、获取指令描述
# (参考前面的指令实现模式)
```

**Step 2-6:** 测试（验证震动效果）、提交

```bash
git add addons/bricks/instructions/tween/tween_shake_animation.gd
git add addons/bricks/tests/tween/test_tween_shake_animation.*
git commit -m "feat: implement TweenShakeAnimation instruction"
```

---

### Task 2.4: Tween Bounce Animation 指令 (P2)

**Files:**
- Create: `addons/bricks/instructions/tween/tween_bounce_animation.gd`
- Test: `addons/bricks/tests/tween/test_tween_bounce_animation.*`

**Step 1: 创建 TweenBounceAnimation 指令**

Create: `addons/bricks/instructions/tween/tween_bounce_animation.gd`

```gdscript
@tool
@icon("res://addons/bricks/icons/builtin/MemberProperty.png")
extends BaseTweenInstruction
class_name TweenBounceAnimation

## 指令元数据
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "BRICKS_INSTRUCTION_TWEEN_BOUNCE_ANIMATION_NAME"
	metadata.category_key = "BRICKS_CATEGORY_TWEEN"
	metadata.description_key = "BRICKS_INSTRUCTION_TWEEN_BOUNCE_ANIMATION_DESC"
	metadata.keywords = ["tween", "bounce", "弹跳", "掉落"]
	metadata.builtin_icon = "MemberProperty"
	return metadata

## 参数配置
var target_node: NodePath = NodePath(""):
	set(value):
		target_node = value
		_update_resource_name()
		notify_property_list_changed()

var bounce_height: float = 50.0:
	set(value):
		bounce_height = value
		_update_resource_name()

var bounce_count: int = 3:
	set(value):
		bounce_count = value
		_update_resource_name()
		notify_property_list_changed()

var duration: float = 0.5:
	set(value):
		duration = value
		_update_resource_name()

## 执行指令
func execute(context: ExecutionContext) -> void:
	_start_execution(context)

	var target = _get_target_node(context, target_node)
	if target == null:
		_log_error_localized("BRICKS_ERROR_TARGET_NODE_NOT_FOUND", {"node": str(target_node)})
		set_error_localized("BRICKS_ERROR_TARGET_NODE_NOT_FOUND", BricksError.ErrorType.RUNTIME_ERROR, {"node": str(target_node)})
		finished.emit()
		return

	if not "position" in target:
		_log_error("目标节点不支持 position 属性")
		set_error(BricksError.ErrorType.VALIDATION_ERROR)
		finished.emit()
		return

	var original_position = target.position

	var tween = _create_tween(target)
	tween.set_trans(Tween.TransitionType.TRANS_BOUNCE)
	tween.set_ease(Tween.EaseType.EASE_OUT)

	tween.tween_property(target, "position:y", original_position.y - bounce_height, duration)

	_log_info_localized("BRICKS_LOG_TWEEN_BOUNCE_ANIMATION", {
		"node": target.name,
		"height": str(bounce_height),
		"count": str(bounce_count)
	})

	await tween.finished
	_on_execution_completed()

## 更新资源名称、获取指令描述
# (参考前面的指令实现模式)
```

**Step 2-6:** 测试（验证弹跳效果）、提交

```bash
git add addons/bricks/instructions/tween/tween_bounce_animation.gd
git add addons/bricks/tests/tween/test_tween_bounce_animation.*
git commit -m "feat: implement TweenBounceAnimation instruction"
```

---

## Phase 3: P3 高级功能

### Task 3.1: Tween Pulse Animation 指令 (P3)

**Files:**
- Create: `addons/bricks/instructions/tween/tween_pulse_animation.gd`
- Test: `addons/bricks/tests/tween/test_tween_pulse_animation.*`

**Step 1: 创建 TweenPulseAnimation 指令**

Create: `addons/bricks/instructions/tween/tween_pulse_animation.gd`

```gdscript
@tool
@icon("res://addons/bricks/icons/builtin/MemberProperty.png")
extends BaseTweenInstruction
class_name TweenPulseAnimation

## 指令元数据
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "BRICKS_INSTRUCTION_TWEEN_PULSE_ANIMATION_NAME"
	metadata.category_key = "BRICKS_CATEGORY_TWEEN"
	metadata.description_key = "BRICKS_INSTRUCTION_TWEEN_PULSE_ANIMATION_DESC"
	metadata.keywords = ["tween", "pulse", "breathing", "脉冲", "呼吸"]
	metadata.builtin_icon = "MemberProperty"
	return metadata

## 参数配置
var target_node: NodePath = NodePath(""):
	set(value):
		target_node = value
		_update_resource_name()
		notify_property_list_changed()

var min_scale: Vector2 = Vector2(0.9, 0.9):
	set(value):
		min_scale = value
		_update_resource_name()

var max_scale: Vector2 = Vector2(1.1, 1.1):
	set(value):
		max_scale = value
		_update_resource_name()

var duration: float = 1.0:
	set(value):
		duration = value
		_update_resource_name()

var loop_count: int = 0:  # 0 = 无限循环
	set(value):
		loop_count = value
		_update_resource_name()
		notify_property_list_changed()

## 执行指令
func execute(context: ExecutionContext) -> void:
	_start_execution(context)

	var target = _get_target_node(context, target_node)
	if target == null:
		_log_error_localized("BRICKS_ERROR_TARGET_NODE_NOT_FOUND", {"node": str(target_node)})
		set_error_localized("BRICKS_ERROR_TARGET_NODE_NOT_FOUND", BricksError.ErrorType.RUNTIME_ERROR, {"node": str(target_node)})
		finished.emit()
		return

	if not "scale" in target:
		_log_error("目标节点不支持 scale 属性")
		set_error(BricksError.ErrorType.VALIDATION_ERROR)
		finished.emit()
		return

	var tween = _create_tween(target)

	if loop_count > 0:
		tween.set_loops(loop_count)
	else:
		tween.set_loops()  # 无限循环

	tween.set_parallel(true)
	tween.tween_property(target, "scale", max_scale, duration * 0.5)
	tween.tween_property(target, "scale", min_scale, duration * 0.5)

	_log_info_localized("BRICKS_LOG_TWEEN_PULSE_ANIMATION", {
		"node": target.name,
		"min_scale": str(min_scale),
		"max_scale": str(max_scale),
		"loops": "infinite" if loop_count == 0 else str(loop_count)
	})

	# 如果是无限循环，需要手动停止
	if loop_count == 0:
		_log_warning("Pulse 动画设置为无限循环，需要手动调用 cancel() 停止")
	else:
		await tween.finished
		_on_execution_completed()

## 停止脉冲动画
func cancel():
	if is_running():
		# 停止所有 tween
		for node in get_tree().get_nodes_in_group("tween_targets"):
			for child in node.get_children():
				if child is Tween:
					child.kill()
		super.cancel()

## 更新资源名称、获取指令描述
# (参考前面的指令实现模式)
```

**Step 2-6:** 测试（验证脉冲效果）、提交

```bash
git add addons/bricks/instructions/tween/tween_pulse_animation.gd
git add addons/bricks/tests/tween/test_tween_pulse_animation.*
git commit -m "feat: implement TweenPulseAnimation instruction with infinite loop support"
```

---

### Task 3.2: Tween Property 通用属性动画指令 (P3)

**Files:**
- Create: `addons/bricks/instructions/tween/tween_property.gd`
- Test: `addons/bricks/tests/tween/test_tween_property.*

**Step 1: 创建 TweenProperty 指令**

这是最复杂的指令，需要集成 PropertyManager 和 PropertyInfo。

Create: `addons/bricks/instructions/tween/tween_property.gd`

```gdscript
@tool
@icon("res://addons/bricks/icons/builtin/MemberProperty.png")
extends BaseInstruction
class_name TweenPropertyInstruction

## 预加载
const PropertyManager = preload("res://addons/bricks/utils/property_manager.gd")
const PropertyInfo = preload("res://addons/bricks/utils/property_info.gd")

## 指令元数据
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "BRICKS_INSTRUCTION_TWEEN_PROPERTY_NAME"
	metadata.category_key = "BRICKS_CATEGORY_TWEEN"
	metadata.description_key = "BRICKS_INSTRUCTION_TWEEN_PROPERTY_DESC"
	metadata.keywords = ["tween", "property", "animate", "custom", "属性", "动画", "自定义"]
	metadata.builtin_icon = "MemberProperty"
	return metadata

## 异步指令
func _init():
	_is_async = true

## 参数配置
var target_node: NodePath = NodePath(""):
	set(value):
		target_node = value
		_update_target_node_info()
		_update_resource_name()
		notify_property_list_changed()

var property_path: String = "":
	set(value):
		property_path = value
		_update_property_type_info()
		_update_resource_name()
		notify_property_list_changed()

var to_value: Variant = null:
	set(value):
		to_value = value
		_update_resource_name()

var duration: float = 0.5:
	set(value):
		duration = value
		_update_resource_name()

var auto_free: bool = false:
	set(value):
		auto_free = value
		_update_resource_name()
		notify_property_list_changed()

var easing_type: BaseTweenInstruction.EasingType = BaseTweenInstruction.EasingType.EASE_IN_OUT:
	set(value):
		easing_type = value
		_update_resource_name()

var trans_type: BaseTweenInstruction.TransitionType = BaseTweenInstruction.TransitionType.TRANS_SINE:
	set(value):
		trans_type = value
		_update_resource_name()

## 运行时状态
var _target_node_instance: Node = null
var _current_property_info: PropertyInfo = null
var _available_properties: Array[PropertyInfo] = []

## 获取属性列表（编辑器）
func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []

	# 添加属性定义
	properties.append({
		"name": "target_node",
		"type": TYPE_NODE_PATH,
		"hint": PROPERTY_HINT_NODE_PATH_VALID_TYPES,
		"hint_string": "Node",
		"default": NodePath("")
	})

	# 动态生成属性枚举
	var enum_string = _get_property_enum_string()
	properties.append({
		"name": "property_path",
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": enum_string,
		"default": ""
	})

	properties.append({
		"name": "to_value",
		"type": TYPE_NIL,  # 动态类型
		"hint": PROPERTY_HINT_NONE,
		"default": null
	})

	properties.append({
		"name": "duration",
		"type": TYPE_FLOAT,
		"hint": PROPERTY_HINT_RANGE,
		"hint_string": "0.0:10.0:0.1",
		"default": 0.5
	})

	properties.append({
		"name": "auto_free",
		"type": TYPE_BOOL,
		"hint": PROPERTY_HINT_NONE,
		"default": false
	})

	properties.append({
		"name": "easing_type",
		"type": TYPE_INT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": "In,Out,InOut,OutIn",
		"default": 2  # InOut
	})

	properties.append({
		"name": "trans_type",
		"type": TYPE_INT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": "Linear,Sine,Quad,Cubic,Quart,Quint,Expo,Circ,Back,Spring,Bounce,Elastic",
		"default": 1  # Sine
	})

	return properties

## 获取属性枚举字符串
func _get_property_enum_string() -> String:
	if _target_node_instance == null:
		return "请先选择目标节点"

	var property_infos = _get_available_properties()
	var property_names = []

	for prop_info in property_infos:
		property_names.append(prop_info.name)

	if property_names.is_empty():
		return "无可用的属性"

	return ",".join(property_names)

## 更新目标节点信息
func _update_target_node_info():
	_target_node_instance = null
	_available_properties = []
	_current_property_info = null

	if target_node.is_empty():
		return

	# 编辑器模式下获取节点
	if Engine.is_editor_hint():
		var editor_interface = Engine.get_singleton("EditorInterface")
		if editor_interface:
			var edited_root = editor_interface.get_edited_scene_root()
			if edited_root:
				_target_node_instance = edited_root.get_node_or_null(target_node)

	if _target_node_instance:
		_available_properties = _get_available_properties()
		notify_property_list_changed()

## 更新属性类型信息
func _update_property_type_info():
	_current_property_info = null

	if _target_node_instance == null or property_path.is_empty():
		return

	_current_property_info = PropertyManager.find_property(_target_node_instance, property_path)

## 获取可用属性列表
func _get_available_properties() -> Array[PropertyInfo]:
	if _target_node_instance == null:
		return []

	return PropertyManager.get_writable_properties(_target_node_instance)

## 执行指令
func execute(context: ExecutionContext) -> void:
	_start_execution(context)

	# 获取目标节点
	var target = _get_target_node(context, target_node)
	if target == null:
		_log_error_localized("BRICKS_ERROR_TARGET_NODE_NOT_FOUND", {"node": str(target_node)})
		set_error_localized("BRICKS_ERROR_TARGET_NODE_NOT_FOUND", BricksError.ErrorType.RUNTIME_ERROR, {"node": str(target_node)})
		finished.emit()
		return

	# 验证属性
	var validation = PropertyManager.validate_property_value(target, property_path, to_value)
	if not validation.valid:
		_log_error("属性验证失败: " + validation.error)
		set_error(BricksError.ErrorType.VALIDATION_ERROR)
		finished.emit()
		return

	# 创建 Tween
	var tween = target.create_tween()

	# 应用缓动设置
	var base_tween = BaseTweenInstruction.new()
	base_tween._apply_easing_settings(tween, easing_type, trans_type)

	# 播放动画
	tween.tween_property(target, property_path, to_value, duration)

	# auto_free 支持
	if auto_free:
		tween.tween_callback(target.queue_free)
		_log_info("auto_free 已启用，动画完成后将释放节点: %s" % target.name)

	_log_info_localized("BRICKS_LOG_TWEEN_PROPERTY", {
		"node": target.name,
		"property": property_path,
		"value": str(to_value),
		"duration": str(duration)
	})

	await tween.finished
	_on_execution_completed()

## 获取目标节点
func _get_target_node(context: ExecutionContext, node_path: NodePath) -> Node:
	var scene_root = Engine.get_main_loop().current_scene
	var root_path = scene_root.get_path()
	var target_path = NodePath(str(root_path) + str(node_path).replace("..", ""))
	return scene_root.get_node_or_null(target_path)

## 更新资源名称
func _update_resource_name():
	var parts = []
	parts.append("Tween Property")

	if not target_node.is_empty():
		parts.append("[%s]" % str(target_node))

	if not property_path.is_empty():
		parts.append(".%s" % property_path)
	else:
		parts.append(".[未选择属性]")

	parts.append("= %s" % str(to_value))
	parts.append("(%.2fs)" % duration)

	if auto_free:
		parts.append("[auto_free]")

	resource_name = " ".join(parts)

## 获取指令描述
func get_description() -> String:
	var target_desc = str(target_node) if not target_node.is_empty() else "未选择节点"
	var prop_desc = property_path if not property_path.is_empty() else "未选择属性"
	return "动画化 %s 的属性 %s 为 %s" % [target_desc, prop_desc, str(to_value)]

## 日志方法
func _log_debug(message: String):
	BricksLogger.log_debug("TweenProperty", log_level, message, property_path)

func _log_info(message: String):
	BricksLogger.log_info("TweenProperty", log_level, message, property_path)

func _log_warning(message: String):
	BricksLogger.log_warning("TweenProperty", log_level, message, property_path)

func _log_error(message: String):
	BricksLogger.log_error("TweenProperty", log_level, message, property_path)
```

**Step 2-6:** 测试（包括 Material 动画）、提交

```bash
git add addons/bricks/instructions/tween/tween_property.gd
git add addons/bricks/tests/tween/test_tween_property.*
git commit -m "feat: implement TweenProperty instruction with PropertyManager integration"
```

---

## Testing Strategy

### 单元测试标准

每个 Tween 指令需要创建：

1. **测试场景** (`.tscn`)
   - 包含测试目标节点（Sprite2D、Control 等）
   - 包含触发 UI（Label 说明如何触发）

2. **测试脚本** (`.gd`)
   - 测试基本功能
   - 测试参数验证
   - 测试错误处理
   - 测试异步完成

3. **测试清单**
   - ✅ 动画是否正确播放
   - ✅ 参数是否正确应用
   - ✅ 异步行为是否正确（await finished）
   - ✅ 取消是否正常工作
   - ✅ auto_free 是否正确释放节点（相关指令）
   - ✅ 错误处理是否正确（节点不存在、属性不存在等）

### 集成测试场景

创建综合测试场景：

**File:** `addons/bricks/tests/tween/test_tween_integration.tscn`

测试组合动画：
- 并行动画（Fade In + Move To）
- 序列动画（Fade In → Wait → Move To）
- 循环动画（For Loop + Shake Animation）
- 预置动画（Pop、Bounce、Pulse）
- 通用属性动画（Tween Property）

---

## Documentation Requirements

### 1. 用户文档

创建用户指南：

**File:** `addons/bricks/docs/user_docs/guides/tween-animation-guide.md`

内容：
- Tween 指令概述
- 如何使用基础动画指令
- 如何使用预置动画
- 参数说明（easing_type、trans_type、auto_free）
- 常见使用场景和示例

### 2. 本地化

**File:** `addons/bricks/translations.csv`

添加所有 Tween 指令的本地化键值：

```csv
key,zh_CN,en
BRICKS_CATEGORY_TWEEN,补间动画,Tween Animation
BRICKS_INSTRUCTION_TWEEN_FADE_IN_NAME,淡入,Fade In
BRICKS_INSTRUCTION_TWEEN_FADE_IN_DESC,让节点逐渐变为不透明,Gradually make node opaque
BRICKS_INSTRUCTION_TWEEN_FADE_OUT_NAME,淡出,Fade Out
BRICKS_INSTRUCTION_TWEEN_FADE_OUT_DESC,让节点逐渐变为透明（可自动释放节点）,Gradually make node transparent (with auto_free option)
BRICKS_INSTRUCTION_TWEEN_MOVE_TO_NAME,移动到,Move To
BRICKS_INSTRUCTION_TWEEN_MOVE_TO_DESC,平滑移动节点到目标位置,Smoothly move node to target position
BRICKS_INSTRUCTION_TWEEN_SCALE_TO_NAME,缩放到,Scale To
BRICKS_INSTRUCTION_TWEEN_SCALE_TO_DESC,平滑缩放节点,Smoothly scale node
BRICKS_INSTRUCTION_TWEEN_ROTATE_TO_NAME,旋转到,Rotate To
BRICKS_INSTRUCTION_TWEEN_ROTATE_TO_DESC,平滑旋转节点到目标角度,Smoothly rotate node to target angle
BRICKS_INSTRUCTION_TWEEN_COLOR_TRANSITION_NAME,颜色过渡,Color Transition
BRICKS_INSTRUCTION_TWEEN_COLOR_TRANSITION_DESC,平滑改变节点颜色,Smoothly transition node color
BRICKS_INSTRUCTION_TWEEN_POP_ANIMATION_NAME,弹出动画,Pop Animation
BRICKS_INSTRUCTION_TWEEN_POP_ANIMATION_DESC,弹簧弹出效果（缩放从 0 到目标值）,Spring pop animation (scale from 0 to target)
BRICKS_INSTRUCTION_TWEEN_SHAKE_ANIMATION_NAME,震动动画,Shake Animation
BRICKS_INSTRUCTION_TWEEN_SHAKE_ANIMATION_DESC,震动效果,Shake effect
BRICKS_INSTRUCTION_TWEEN_BOUNCE_ANIMATION_NAME,弹跳动画,Bounce Animation
BRICKS_INSTRUCTION_TWEEN_BOUNCE_ANIMATION_DESC,弹跳效果（掉落后反弹）,Bounce effect (drop and bounce)
BRICKS_INSTRUCTION_TWEEN_PULSE_ANIMATION_NAME,脉冲动画,Pulse Animation
BRICKS_INSTRUCTION_TWEEN_PULSE_ANIMATION_DESC,呼吸/脉冲效果（可循环）,Breathing/pulse effect (loopable)
BRICKS_INSTRUCTION_TWEEN_PROPERTY_NAME,属性动画,Property Animation
BRICKS_INSTRUCTION_TWEEN_PROPERTY_DESC,动画化节点的任意属性（高级）,Animate any property of a node (advanced)

# 日志键值
BRICKS_LOG_TWEEN_FADE_IN,开始淡入动画: {node} alpha {from}→{to} 耗时 {duration}秒
BRICKS_LOG_TWEEN_FADE_OUT,开始淡出动画: {node} 耗时 {duration}秒 auto_free={auto_free}
BRICKS_LOG_TWEEN_MOVE_TO,开始移动动画: {node} 到 {position} ({space}坐标) 耗时 {duration}秒
BRICKS_LOG_TWEEN_SCALE_TO,开始缩放动画: {node} 到 {scale} 耗时 {duration}秒
BRICKS_LOG_TWEEN_ROTATE_TO,开始旋转动画: {node} 到 {rotation}° 耗时 {duration}秒
BRICKS_LOG_TWEEN_COLOR_TRANSITION,开始颜色过渡: {node} 到 {color} 耗时 {duration}秒
BRICKS_LOG_TWEEN_POP_ANIMATION,开始弹出动画: {node} 到 {scale} 耗时 {duration}秒
BRICKS_LOG_TWEEN_SHAKE_ANIMATION,开始震动动画: {node} 强度{intensity} {count}次 轴向{axis}
BRICKS_LOG_TWEEN_BOUNCE_ANIMATION,开始弹跳动画: {node} 高度{height} {count}次
BRICKS_LOG_TWEEN_PULSE_ANIMATION,开始脉冲动画: {node} {min_scale}↔{max_scale} {loops}
BRICKS_LOG_TWEEN_PROPERTY,开始属性动画: {node}.{property} = {value} 耗时 {duration}秒
```

---

## 开发工具和技能推荐

### 可用技能

- **bricks-instruction-generator** - 快速生成指令模板代码
  - 使用方法：调用该技能并提供指令名称和参数列表
  - 自动生成基础的指令结构、元数据、参数配置

### 参考文档

- [Tween 通用使用模式参考](../../../docs/tween-common-patterns.md) - 39 种 Tween 模式详细说明
- [Bricks Instruction Roadmap](../addons/bricks/docs/roadmap/2026-01-27-bricks-tween-instruction-roadmap.md) - 完整路线图
- [SetPropertyValue 实现](../addons/bricks/instructions/node_operations/set_property_value.gd) - PropertyManager 集成参考

---

## 评审标准和质量保证

### 评审标准文档

所有 Tween 指令必须遵循 **[instruction_creation_guide.md](../addons/bricks/docs/development/instruction_creation_guide.md)** 中定义的标准。

### 关键评审要点

#### 1. 命名规范检查

**文件命名：**
- ✅ 使用 `snake_case`，**不添加** `_instruction` 后缀
  - 正确：`tween_fade_in.gd`, `tween_move_to.gd`
  - 错误：`tween_fade_in_instruction.gd`, `tween_move_to_instruction.gd`

**类命名：**
- ✅ 使用 `PascalCase`，**不添加** `Instruction` 后缀
  - 正确：`class_name TweenFadeIn`, `class_name TweenMoveTo`
  - 错误：`class_name TweenFadeInInstruction`, `class_name TweenMoveToInstruction`

**测试文件命名：**
- ✅ `test_tween_fade_in.gd`, `test_tween_fade_in.tscn`
- ❌ `test_tween_fade_in_instruction.gd`

#### 2. 必需方法实现检查

所有指令必须实现以下方法：

```gdscript
## ✅ 必需方法清单
func _update_resource_name()  # 更新资源名称
func validate() -> Array[String]  # 验证参数
func get_description() -> String  # 获取指令描述
```

#### 3. 执行流程检查

**同步指令（Tween Fade In/Out 等）：**
```gdscript
func execute(context: ExecutionContext):
    _start_execution(context)  # ✅ 必须首先调用

    # 验证逻辑
    if error:
        _log_error_localized("ERROR_KEY", {})
        set_error_localized("ERROR_KEY", BricksError.ErrorType.RUNTIME_ERROR, {})
        finished.emit()
        return

    # 执行逻辑
    # ...

    _on_execution_completed()  # ✅ 同步完成
```

**异步指令（所有 Tween 指令）：**
```gdscript
func _init():
    _is_async = true  # ✅ 标记为异步

func execute(context: ExecutionContext):
    _start_execution(context)

    # 创建 Tween
    var tween = target.create_tween()
    # ...

    await tween.finished  # ✅ 等待完成
    _on_execution_completed()  # ✅ 然后完成
```

#### 4. API 使用检查

**❌ 错误用法：**
```gdscript
var tree = get_tree()  # ❌ 在指令中不可用
var tween = create_tween()  # ❌ 在指令中不可用
```

**✅ 正确用法：**
```gdscript
var scene_tree = Engine.get_main_loop()  # ✅ 正确
if scene_tree:
    var tween = scene_tree.create_tween()  # ✅ 正确
```

#### 5. 节点获取检查

**❌ 错误用法：**
```gdscript
var node = get_node(target_node)  # ❌ 无法正确解析相对路径
```

**✅ 正确用法：**
```gdscript
var node = context.get_node(target_node)  # ✅ 支持相对路径
```

#### 6. 错误处理检查

**所有错误必须使用本地化消息：**
```gdscript
if target_node.is_empty():
    _log_error_localized("BRICKS_ERROR_TARGET_NODE_EMPTY", {})
    set_error_localized("BRICKS_ERROR_TARGET_NODE_EMPTY", BricksError.ErrorType.VALIDATION_ERROR, {})
    finished.emit()
    return
```

#### 7. 异步指令特殊要求

**Tween 创建检查：**
```gdscript
# ✅ 正确：先检查 SceneTree
var scene_tree = Engine.get_main_loop()
if not scene_tree:
    _log_error_localized("BRICKS_ERROR_CANNOT_CREATE_TWEEN", {})
    set_error_localized("BRICKS_ERROR_CANNOT_CREATE_TWEEN", BricksError.ErrorType.RUNTIME_ERROR, {})
    finished.emit()
    return

var tween = scene_tree.create_tween()
```

**auto_free 实现检查（Tween Fade Out 和 Tween Property）：**
```gdscript
# ✅ 正确：使用 tween_callback
if auto_free:
    tween.tween_callback(target.queue_free)
```

**资源清理检查：**
```gdscript
func _cleanup_resources():
    # ✅ 清理 Tween 资源
    if _tween and is_instance_valid(_tween):
        _tween.kill()
        _tween = null
```

#### 8. 代码质量检查

**类型注解：**
```gdscript
# ✅ 推荐：明确的类型注解
var node: Node = context.get_node(target_node)

# ✅ 也可以：使用 :=
var node := context.get_node(target_node)

# ❌ 避免：未初始化的类型声明
var node: Node
node = context.get_node(target_node)
```

**属性刷新：**
```gdscript
var some_param: bool = false:
set(value):
    some_param = value
    notify_property_list_changed()  # ✅ 在 setter 中调用
```

### 评审检查清单

每个指令完成后，使用以下检查清单进行评审：

- [ ] **命名规范** - 文件名、类名符合规范（无 `_instruction` 后缀）
- [ ] **必需方法** - 实现所有必需方法（`_update_resource_name`, `validate`, `get_description`）
- [ ] **执行流程** - 正确调用 `_start_execution()` 和完成方法
- [ ] **API 使用** - 使用 `context.get_node()`, `Engine.get_main_loop()`
- [ ] **错误处理** - 所有错误使用本地化消息
- [ ] **异步处理** - 正确实现 `_is_async = true` 和 `await`
- [ ] **Tween 创建** - 先检查 SceneTree，后创建 Tween
- [ ] **auto_free** - 正确使用 `tween_callback(target.queue_free)`（相关指令）
- [ ] **资源清理** - 实现 `_cleanup_resources()` 清理 Tween
- [ ] **测试覆盖** - 有测试场景和测试脚本
- [ ] **本地化** - 添加所有必要的本地化键值

### 不符合标准的处理

如果指令不符合上述标准：

1. **命名问题** - 立即修复，确保符合规范
2. **缺少必需方法** - 补充实现，通过所有检查
3. **API 使用错误** - 修正为正确的 API 调用
4. **缺少测试** - 补充测试场景和测试脚本
5. **缺少本地化** - 添加必要的本地化键值

**提交前必须：**
- 运行所有测试，确保通过
- 在 Godot 编辑器中测试指令功能
- 使用检查清单进行自审
- 确保代码符合 GDScript 2.0 规范

---

## 开发检查清单

### Phase 1: P0 核心动画 (5 个指令)
- [ ] Tween Fade In
- [ ] Tween Fade Out (包含 auto_free)
- [ ] Tween Move To
- [ ] Tween Scale To
- [ ] Tween Rotate To

### Phase 2: P1-P2 预置动画 (4 个指令)
- [ ] Tween Color Transition (P1)
- [ ] Tween Pop Animation (P2)
- [ ] Tween Shake Animation (P2)
- [ ] Tween Bounce Animation (P2)

### Phase 3: P3 高级功能 (2 个指令)
- [ ] Tween Pulse Animation (P3)
- [ ] Tween Property (P3) - 包含 PropertyManager 集成和 auto_free

### 文档和测试
- [ ] 所有指令都有测试场景和测试脚本
- [ ] 所有指令都通过基本功能测试
- [ ] 用户文档已创建
- [ ] 本地化键值已添加
- [ ] 综合集成测试已通过

---

## 预期成果

完成此计划后：

1. **11 个 Tween 指令**全部实现并可正常使用
2. **覆盖 90% 的游戏动画需求**（淡入淡出、移动、缩放、旋转、颜色、预置动画）
3. **完整的测试覆盖**（单元测试 + 集成测试）
4. **用户文档齐全**（使用指南 + 本地化）
5. **代码质量高**（遵循 DRY、YAGNI、TDD 原则）

---

## 最后更新

**文档创建日期:** 2026-01-28
**Godot 版本:** 4.6+
**Bricks 版本:** 开发中
**预计开发时间:** 4-6 周（Phase 1: 2 周，Phase 2: 2 周，Phase 3: 1-2 周）
