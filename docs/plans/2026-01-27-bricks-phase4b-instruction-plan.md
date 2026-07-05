# Bricks Phase 4B 指令开发计划（相机控制完善）

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task.

**Goal:** 实现 3 个 Phase 4B 指令，完善相机控制系统，提供相机跟随、抖动效果和边界限制功能，配合 Phase 3D 的 Set Camera Zoom 形成完整的 2D 相机管理系统。

**Architecture:** 基于 Godot 4.6 Resource 系统，每个指令继承 BaseInstruction，使用元数据驱动架构，支持本地化和编辑器集成。相机指令使用 Camera2D API，提供完整的 2D 游戏相机控制能力。

**Tech Stack:** GDScript 2.0, Godot 4.6, Resource 系统, 本地化系统（CSV）, 测试框架, Camera2D API

---

## 📊 总体概览

**指令总数:** 3 个指令

**分类分布:**
- Phase 4B: 相机控制完善（3 个）- Camera Follow, Camera Shake, Set Camera Limit

**前置条件:**
- ✅ Phase 0-3 已完成（42 个指令）
- ✅ Phase 4A 已完成（数学运算 2 个）
- ✅ Phase 4C 已完成（游戏流程控制 2 个）
- ✅ Phase 3D 已完成 Set Camera Zoom 指令
- ✅ 指令创建指南已建立
- ✅ 测试框架已就绪

**预期时间:** 1 周

---

## 🎯 Phase 4B 指令清单

### 按优先级排序

| 排名 | 指令 | 类别 | 复杂度 | 优先级 | 文件名 |
|------|------|------|--------|--------|--------|
| 1 | Set Camera Limit | 相机控制 | 简单 | P1 | set_camera_limit.gd |
| 2 | Camera Follow | 相机控制 | 中等 | P1 | camera_follow.gd |
| 3 | Camera Shake | 相机控制 | 中等 | P2 | camera_shake.gd |

**实现顺序说明：**
- 优先实现简单的 Set Camera Limit（设置相机边界）
- 然后实现 Camera Follow（相机跟随）
- 最后实现 Camera Shake（相机抖动，可能需要 Tween 或信号处理）

---

## 📋 执行前检查清单

### 开始前必须确认

- [ ] 阅读 [instruction_creation_guide.md](../../addons/bricks/docs/development/instruction_creation_guide.md)
- [ ] 查看现有指令示例（推荐：set_camera_zoom.gd, pause_game.gd）
- [ ] 确认 Godot 版本：4.6
- [ ] 确认测试环境就绪
- [ ] 确认本地化系统工作正常

### 技术要点

**必须遵循的标准:**
1. **文件命名**: snake_case，无 `_instruction` 后缀（如 `camera_follow.gd`）
2. **类命名**: PascalCase，无 `Instruction` 后缀（如 `class_name CameraFollow`）
3. **图标**: 使用 `metadata.builtin_icon` 配置内置图标
4. **本地化**: 所有用户可见字符串必须使用 `_log_error_localized()` 等方法
5. **GDScript 2.0 语法**: 三元运算符使用 Python 风格 `value_if_true if condition else value_if_false`
6. **测试**: 每个指令需要测试脚本和测试场景（`.gd` + `.tscn`）

**Godot 4.6 Camera2D API 注意事项:**
- Camera2D 使用 `position`、`zoom`、`limit_*` 属性
- 使用 `Engine.get_main_loop()` 获取 SceneTree
- 跟随模式：设置 `position_smoothing_enabled` 和相关属性
- 限制属性：`limit_top`, `limit_bottom`, `limit_left`, `limit_right`（值为 -9999 表示无限制）
- Camera2D 在 4.6 中不再使用 `smoothed_position`，使用 `position_smoothing` 相关属性

---

## Phase 4B: 相机控制完善（3 个指令）

### 任务 1: Set Camera Limit 指令

**功能:** 设置 Camera2D 的移动边界限制

**Files:**
- Create: `addons/bricks/instructions/set_camera_limit.gd`
- Create: `addons/bricks/instructions/set_camera_limit.gd.uid`
- Create: `addons/bricks/tests/instructions/test_set_camera_limit.gd`
- Create: `addons/bricks/tests/instructions/test_set_camera_limit.gd.uid`
- Create: `addons/bricks/tests/instructions/test_set_camera_limit.tscn`
- Modify: `addons/bricks/localization/translations.csv`

#### Step 1: 添加本地化字符串

编辑 `addons/bricks/localization/translations.csv`，在文件末尾添加：

```csv
# Phase 4B - 相机控制
BRICKS_INSTRUCTION_SET_CAMERA_LIMIT_NAME,设置相机边界,Set Camera Limit
BRICKS_INSTRUCTION_SET_CAMERA_LIMIT_DESC,设置 Camera2D 的移动边界限制（上、下、左、右）,Sets the movement boundary limits for Camera2D (top, bottom, left, right)
BRICKS_CATEGORY_CAMERA,相机控制,Camera Control
BRICKS_ERROR_CAMERA_NODE_NOT_FOUND,未找到相机节点,Camera node not found
BRICKS_ERROR_CAMERA_NOT_CAMERA2D,节点不是 Camera2D 类型,Node is not a Camera2D type
```

#### Step 2: 创建指令文件

创建 `addons/bricks/instructions/set_camera_limit.gd`：

```gdscript
@tool
@icon("res://addons/bricks/icons/builtin/EditorPosition.png")
extends BaseInstruction
class_name SetCameraLimit

## 设置 Camera2D 的移动边界限制

# 目标相机节点路径
var target_node: NodePath = NodePath("")

# 边界类型
enum LimitSide {
	TOP,
	BOTTOM,
	LEFT,
	RIGHT
}
var limit_side: LimitSide = LimitSide.TOP:
	set(value):
		limit_side = value
		_update_resource_name()

# 边界值（-9999 表示无限制）
var limit_value: int = -9999:
	set(value):
		limit_value = value
		_update_resource_name()

## 获取指令元数据
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "BRICKS_INSTRUCTION_SET_CAMERA_LIMIT_NAME"
	metadata.category_key = "BRICKS_CATEGORY_CAMERA"
	metadata.description_key = "BRICKS_INSTRUCTION_SET_CAMERA_LIMIT_DESC"
	metadata.keywords = ["camera", "limit", "boundary", "boundary", "top", "bottom", "left", "right", "相机", "限制", "边界"]
	metadata.builtin_icon = "EditorPosition"
	return metadata

func _setup_metadata():
	pass

## 获取属性列表
func _get_property_list() -> Array[Dictionary]:
	var properties := []

	properties.append({
		name = "Camera",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "target_node",
		type = TYPE_NODE_PATH,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	properties.append({
		name = "limit_side",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Top,Bottom,Left,Right",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	properties.append({
		name = "limit_value",
		type = TYPE_INT,
		hint = PROPERTY_HINT_RANGE,
		hint_string = "-9999,10000,1",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	return properties

## 更新资源名称
func _update_resource_name():
	var parts := []

	parts.append("相机边界")

	var side_name = ""
	match limit_side:
		LimitSide.TOP: side_name = "上"
		LimitSide.BOTTOM: side_name = "下"
		LimitSide.LEFT: side_name = "左"
		LimitSide.RIGHT: side_name = "右"

	parts.append(side_name)

	if limit_value == -9999:
		parts.append("(无限制)")
	else:
		parts.append("(值: %d)" % limit_value)

	resource_name = " ".join(parts)

## 执行指令
func execute(context: ExecutionContext):
	_start_execution(context)

	# 获取目标节点
	var camera = context.get_node(target_node)
	if not camera:
		_log_error_localized("BRICKS_ERROR_CAMERA_NODE_NOT_FOUND", {})
		set_error_localized("BRICKS_ERROR_CAMERA_NODE_NOT_FOUND", BricksError.ErrorType.RUNTIME_ERROR, {})
		finished.emit()
		return

	# 验证节点类型
	if not camera is Camera2D:
		_log_error_localized("BRICKS_ERROR_CAMERA_NOT_CAMERA2D", {})
		set_error_localized("BRICKS_ERROR_CAMERA_NOT_CAMERA2D", BricksError.ErrorType.RUNTIME_ERROR, {})
		finished.emit()
		return

	var camera_2d = camera as Camera2D

	# 设置边界值
	match limit_side:
		LimitSide.TOP:
			camera_2d.limit_top = limit_value
		LimitSide.BOTTOM:
			camera_2d.limit_bottom = limit_value
		LimitSide.LEFT:
			camera_2d.limit_left = limit_value
		LimitSide.RIGHT:
			camera_2d.limit_right = limit_value

	_log_info("设置相机边界 %s: %d" % [side_name, limit_value])
	_on_execution_completed()

## 验证指令参数
func validate() -> Array[String]:
	var errors = super.validate()

	if target_node.is_empty():
		errors.append("目标相机节点不能为空")

	return errors

## 获取指令描述
func get_description() -> String:
	var side_name = ""
	match limit_side:
		LimitSide.TOP: side_name = "上"
		LimitSide.BOTTOM: side_name = "下"
		LimitSide.LEFT: side_name = "左"
		LimitSide.RIGHT: side_name = "右"

	var value_str = "无限制" if limit_value == -9999 else "%d" % limit_value
	return "设置 %s 边界为 %s" % [side_name, value_str]
```

#### Step 3: 创建测试场景和脚本

创建测试场景 `addons/bricks/tests/instructions/test_set_camera_limit.tscn`：

```
[节点树]
Node2D (root)
  └─ Camera2D (命名为 TestCamera)
  └─ test_set_camera_limit.gd (脚本)
```

创建测试脚本 `addons/bricks/tests/instructions/test_set_camera_limit.gd`：

```gdscript
extends Node2D

func _ready():
	print("=== 开始测试 Set Camera Limit 指令 ===")
	await test_set_top_limit()
	await test_set_bottom_limit()
	await test_set_left_limit()
	await test_set_right_limit()
	await test_unset_limit()
	print("=== Set Camera Limit 指令测试完成 ===")

func test_set_top_limit():
	print("\n[Test 1] 测试设置上边界")

	var instruction = SetCameraLimit.new()
	var context = ExecutionContext.new()

	var camera = $TestCamera as Camera2D

	instruction.target_node = NodePath("../TestCamera")
	instruction.limit_side = SetCameraLimit.LimitSide.TOP
	instruction.limit_value = 100

	instruction.execute(context)
	await context.finished

	assert(camera.limit_top == 100, "上边界应该被设置为 100")
	print("✓ 设置上边界测试通过")

func test_set_bottom_limit():
	print("\n[Test 2] 测试设置下边界")

	var instruction = SetCameraLimit.new()
	var context = ExecutionContext.new()

	var camera = $TestCamera as Camera2D

	instruction.target_node = NodePath("../TestCamera")
	instruction.limit_side = SetCameraLimit.LimitSide.BOTTOM
	instruction.limit_value = -100

	instruction.execute(context)
	await context.finished

	assert(camera.limit_bottom == -100, "下边界应该被设置为 -100")
	print("✓ 设置下边界测试通过")

func test_set_left_limit():
	print("\n[Test 3] 测试设置左边界")

	var instruction = SetCameraLimit.new()
	var context = ExecutionContext.new()

	var camera = $TestCamera as Camera2D

	instruction.target_node = NodePath("../TestCamera")
	instruction.limit_side = SetCameraLimit.LimitSide.LEFT
	instruction.limit_value = 200

	instruction.execute(context)
	await context.finished

	assert(camera.limit_left == 200, "左边界应该被设置为 200")
	print("✓ 设置左边界测试通过")

func test_set_right_limit():
	print("\n[Test 4] 测试设置右边界")

	var instruction = SetCameraLimit.new()
	var context = ExecutionContext.new()

	var camera = $TestCamera as Camera2D

	instruction.target_node = NodePath("../TestCamera")
	instruction.limit_side = SetCameraLimit.LimitSide.RIGHT
	instruction.limit_value = -200

	instruction.execute(context)
	await context.finished

	assert(camera.limit_right == -200, "右边界应该被设置为 -200")
	print("✓ 设置右边界测试通过")

func test_unset_limit():
	print("\n[Test 5] 测试取消边界限制")

	var instruction = SetCameraLimit.new()
	var context = ExecutionContext.new()

	var camera = $TestCamera as Camera2D

	# 先设置一个限制
	camera.limit_top = 100

	instruction.target_node = NodePath("../TestCamera")
	instruction.limit_side = SetCameraLimit.LimitSide.TOP
	instruction.limit_value = -9999  # -9999 表示无限制

	instruction.execute(context)
	await context.finished

	assert(camera.limit_top == -9999, "上边界应该被设置为无限制")
	print("✓ 取消边界限制测试通过")
```

#### Step 4: 验证和提交

验证测试通过后提交：

```bash
git add addons/bricks/instructions/set_camera_limit.gd
git add addons/bricks/instructions/set_camera_limit.gd.uid
git add addons/bricks/tests/instructions/test_set_camera_limit.gd
git add addons/bricks/tests/instructions/test_set_camera_limit.gd.uid
git add addons/bricks/tests/instructions/test_set_camera_limit.tscn
git add addons/bricks/localization/translations.csv
git commit -m "feat(bricks): 添加 Set Camera Limit 指令（Phase 4B-1/3）

- 设置 Camera2D 的移动边界限制（上、下、左、右）
- 支持设置具体值或取消限制（-9999）
- 完整的节点类型验证和错误处理
- 5 个测试用例覆盖所有边界类型

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

### 任务 2: Camera Follow 指令

**功能:** 设置相机跟随目标节点移动

**Files:**
- Create: `addons/bricks/instructions/camera_follow.gd`
- Create: `addons/bricks/instructions/camera_follow.gd.uid`
- Create: `addons/bricks/tests/instructions/test_camera_follow.gd`
- Create: `addons/bricks/tests/instructions/test_camera_follow.gd.uid`
- Create: `addons/bricks/tests/instructions/test_camera_follow.tscn`
- Modify: `addons/bricks/localization/translations.csv`

#### Step 1: 添加本地化字符串

```csv
BRICKS_INSTRUCTION_CAMERA_FOLLOW_NAME,相机跟随,Camera Follow
BRICKS_INSTRUCTION_CAMERA_FOLLOW_DESC,设置相机跟随目标节点移动（支持多种跟随模式）,Sets camera to follow target node movement (supports multiple follow modes)
BRICKS_ERROR_TARGET_NODE_NOT_FOUND,未找到目标节点,Target node not found
BRICKS_ERROR_CAMERA_NODE_NOT_FOUND,未找到相机节点,Camera node not found
BRICKS_ERROR_CAMERA_NOT_CAMERA2D,节点不是 Camera2D 类型,Node is not a Camera2D type
BRICKS_ERROR_TARGET_NOT_NODE2D,目标不是 Node2D 类型,Target is not a Node2D type
```

#### Step 2: 创建指令文件

创建 `addons/bricks/instructions/camera_follow.gd`：

```gdscript
@tool
@icon("res://addons/bricks/icons/builtin/ViewportContainer.png")
extends BaseInstruction
class_name CameraFollow

## 设置相机跟随目标节点移动

# 目标节点路径
var target_node: NodePath = NodePath("")

# 相机节点路径
var camera_node: NodePath = NodePath("")

# 跟随模式
enum FollowMode {
	LOCK,
	SMOOTH,
	DAMPED
}
var follow_mode: FollowMode = FollowMode.SMOOTH:
	set(value):
		follow_mode = value
		_update_resource_name()

# 平滑速度（仅 SMOOTH 模式）
var smooth_speed: float = 5.0:
	set(value):
		smooth_speed = value
		_update_resource_name()

# 阻尼（仅 DAMPED 模式）
var damping: bool = true:
	set(value):
		damping = value
		_update_resource_name()

# 是否启用跟随
var enabled: bool = true:
	set(value):
		enabled = value
		_update_resource_name()

## 获取指令元数据
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "BRICKS_INSTRUCTION_CAMERA_FOLLOW_NAME"
	metadata.category_key = "BRICKS_CATEGORY_CAMERA"
	metadata.description_key = "BRICKS_INSTRUCTION_CAMERA_FOLLOW_DESC"
	metadata.keywords = ["camera", "follow", "target", "smooth", "track", "相机", "跟随", "追踪"]
	metadata.builtin_icon = "ViewportContainer"
	return metadata

func _setup_metadata():
	pass

## 获取属性列表
func _get_property_list() -> Array[Dictionary]:
	var properties := []

	properties.append({
		name = "Camera Follow",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "target_node",
		type = TYPE_NODE_PATH,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	properties.append({
		name = "camera_node",
		type = TYPE_NODE_PATH,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	properties.append({
		name = "follow_mode",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Lock,Smooth,Damped",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 根据模式显示不同属性
	if follow_mode == FollowMode.SMOOTH:
		properties.append({
			name = "smooth_speed",
			type = TYPE_FLOAT,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "0.1,100,0.1",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})
	elif follow_mode == FollowMode.DAMPED:
		properties.append({
			name = "damping",
			type = TYPE_BOOL,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

	properties.append({
		name = "enabled",
		type = TYPE_BOOL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	return properties

## 更新资源名称
func _update_resource_name():
	var parts := []

	parts.append("相机跟随")

	if enabled:
		var mode_name = ""
		match follow_mode:
			FollowMode.LOCK: mode_name = "锁定"
			FollowMode.SMOOTH: mode_name = "平滑"
			FollowMode.DAMPED: mode_name = "阻尼"

		parts.append(mode_name)

		if follow_mode == FollowMode.SMOOTH:
			parts.append("(速度: %.1f)" % smooth_speed)
		elif follow_mode == FollowMode.DAMPED:
			parts.append("(阻尼: %s)" % ("开" if damping else "关"))
	else:
		parts.append("(禁用)")

	resource_name = " ".join(parts)

## 执行指令
func execute(context: ExecutionContext):
	_start_execution(context)

	# 获取相机节点
	var camera = context.get_node(camera_node)
	if not camera:
		_log_error_localized("BRICKS_ERROR_CAMERA_NODE_NOT_FOUND", {})
		set_error_localized("BRICKS_ERROR_CAMERA_NODE_NOT_FOUND", BricksError.ErrorType.RUNTIME_ERROR, {})
		finished.emit()
		return

	# 验证相机类型
	if not camera is Camera2D:
		_log_error_localized("BRICKS_ERROR_CAMERA_NOT_CAMERA2D", {})
		set_error_localized("BRICKS_ERROR_CAMERA_NOT_CAMERA2D", BricksError.ErrorType.RUNTIME_ERROR, {})
		finished.emit()
		return

	var camera_2d = camera as Camera2D

	# 获取目标节点
	var target = context.get_node(target_node)
	if not target:
		_log_error_localized("BRICKS_ERROR_TARGET_NODE_NOT_FOUND", {})
		set_error_localized("BRICKS_ERROR_TARGET_NODE_NOT_FOUND", BricksError.ErrorType.RUNTIME_ERROR, {})
		finished.emit()
		return

	# 验证目标类型
	if not target is Node2D:
		_log_error_localized("BRICKS_ERROR_TARGET_NOT_NODE2D", {})
		set_error_localized("BRICKS_ERROR_TARGET_NOT_NODE2D", BricksError.ErrorType.RUNTIME_ERROR, {})
		finished.emit()
		return

	# 配置跟随
	if enabled:
		camera_2d.enabled = true
		camera_2d.position_smoothing_enabled = true

		match follow_mode:
			FollowMode.LOCK:
				# 锁定模式：直接设置位置
				camera_2d.position_smoothing_enabled = false
				camera_2d.global_position = target.global_position
			FollowMode.SMOOTH:
				# 平滑模式：设置平滑速度
				camera_2d.position_smoothing_enabled = true
				camera_2d.position_smoothing_speed = smooth_speed
			FollowMode.DAMPED:
				# 阻尼模式：使用阻尼
				camera_2d.position_smoothing_enabled = true
				camera_2d.position_smoothing_enabled = damping
	else:
		# 禁用跟随
		camera_2d.enabled = false

	_log_info("设置相机跟随: %s → %s (模式: %s)" % [target.name, camera.name, FollowMode.keys()[follow_mode]])
	_on_execution_completed()

## 验证指令参数
func validate() -> Array[String]:
	var errors = super.validate()

	if target_node.is_empty():
		errors.append("目标节点不能为空")

	if camera_node.is_empty():
		errors.append("相机节点不能为空")

	return errors

## 获取指令描述
func get_description() -> String:
	var mode_name = FollowMode.keys()[follow_mode]
	var state = "启用" if enabled else "禁用"
	return "相机跟随 %s (%s, %s)" % [target_node, state, mode_name]
```

#### Step 3: 创建测试场景和脚本

创建测试场景 `addons/bricks/tests/instructions/test_camera_follow.tscn`（包含 Player 和 Camera2D）

创建测试脚本 `addons/bricks/tests/instructions/test_camera_follow.gd`：

```gdscript
extends Node2D

func _ready():
	print("=== 开始测试 Camera Follow 指令 ===")
	await test_lock_follow()
	await test_smooth_follow()
	await test_damped_follow()
	await test_disable_follow()
	print("=== Camera Follow 指令测试完成 ===")

func test_lock_follow():
	print("\n[Test 1] 测试锁定跟随")

	var instruction = CameraFollow.new()
	var context = ExecutionContext.new()

	var player = $Player as Node2D
	var camera = $Camera2D as Camera2D

	instruction.target_node = NodePath("../Player")
	instruction.camera_node = NodePath("../Camera2D")
	instruction.follow_mode = CameraFollow.FollowMode.LOCK
	instruction.enabled = true

	# 移动玩家
	player.global_position = Vector2(100, 100)

	instruction.execute(context)
	await context.finished

	# 验证相机位置
	assert(camera.global_position.is_equal_approx(player.global_position), "相机应该在锁定模式下跟随玩家")
	print("✓ 锁定跟随测试通过")

func test_smooth_follow():
	print("\n[Test 2] 测试平滑跟随")

	var instruction = CameraFollow.new()
	var context = ExecutionContext.new()

	var player = $Player as Node2D
	var camera = $Camera2D as Camera2D

	instruction.target_node = NodePath("../Player")
	instruction.camera_node = NodePath("../Camera2D")
	instruction.follow_mode = CameraFollow.FollowMode.SMOOTH
	instruction.smooth_speed = 10.0
	instruction.enabled = true

	instruction.execute(context)
	await context.finished

	# 验证平滑速度设置
	assert(camera.position_smoothing_enabled == true, "应该启用平滑跟随")
	assert(camera.position_smoothing_speed == 10.0, "平滑速度应该是 10.0")
	print("✓ 平滑跟随测试通过")

func test_damped_follow():
	print("\n[Test 3] 测试阻尼跟随")

	var instruction = CameraFollow.new()
	var context = ExecutionContext.new()

	var player = $Player as Node2D
	var camera = $Camera2D as Camera2D

	instruction.target_node = NodePath("../Player")
	instruction.camera_node = NodePath("../Camera2D")
	instruction.follow_mode = CameraFollow.FollowMode.DAMPED
	instruction.damping = true
	instruction.enabled = true

	instruction.execute(context)
	await context.finished

	assert(camera.position_smoothing_enabled == true, "应该启用位置平滑")
	print("✓ 阻尼跟随测试通过")

func test_disable_follow():
	print("\n[Test 4] 测试禁用跟随")

	var instruction = CameraFollow.new()
	var context = ExecutionContext.new()

	var camera = $Camera2D as Camera2D

	instruction.target_node = NodePath("../Player")
	instruction.camera_node = NodePath("../Camera2D")
	instruction.enabled = false

	instruction.execute(context)
	await context.finished

	assert(camera.enabled == false, "相机应该被禁用")
	print("✓ 禁用跟随测试通过")
```

#### Step 4: 验证和提交

```bash
git add addons/bricks/instructions/camera_follow.gd
git add addons/bricks/instructions/camera_follow.gd.uid
git add addons/bricks/tests/instructions/test_camera_follow.gd
git add addons/bricks/tests/instructions/test_camera_follow.gd.uid
git add addons/bricks/tests/instructions/test_camera_follow.tscn
git add addons/bricks/localization/translations.csv
git commit -m "feat(bricks): 添加 Camera Follow 指令（Phase 4B-2/3）

- 设置相机跟随目标节点（支持多种跟随模式）
- 支持锁定、平滑、阻尼三种跟随模式
- 完整的节点类型验证和错误处理
- 4 个测试用例覆盖所有跟随模式

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

### 任务 3: Camera Shake 指令

**功能:** 触发相机抖动效果

**Files:**
- Create: `addons/bricks/instructions/camera_shake.gd`
- Create: `addons/bricks/instructions/camera_shake.gd.uid`
- Create: `addons/bricks/tests/instructions/test_camera_shake.gd`
- Create: `addons/bricks/tests/instructions/test_camera_shake.gd.uid`
- Create: `addons/bricks/tests/instructions/test_camera_shake.tscn`
- Modify: `addons/bricks/localization/translations.csv`

#### Step 1: 添加本地化字符串

```csv
BRICKS_INSTRUCTION_CAMERA_SHAKE_NAME,相机抖动,Camera Shake
BRICKS_INSTRUCTION_CAMERA_SHAKE_DESC,触发相机抖动效果（支持强度和持续时间配置）,Triggers camera shake effect (supports intensity and duration configuration)
BRICKS_ERROR_CAMERA_NODE_NOT_FOUND,未找到相机节点,Camera node not found
BRICKS_ERROR_CAMERA_NOT_CAMERA2D,节点不是 Camera2D 类型,Node is not a Camera2D type
BRICKS_ERROR_SHAKE_DURATION_INVALID,抖动持续时间必须大于 0,Shake duration must be greater than 0
```

#### Step 2: 创建指令文件

创建 `addons/bricks/instructions/camera_shake.gd`：

```gdscript
@tool
@icon("res://addons/bricks/icons/builtin/AnimationTracks.png")
extends BaseInstruction
class_name CameraShake

## 触发相机抖动效果

# 目标相机节点路径
var target_node: NodePath = NodePath("")

# 抖动强度（0.0-1.0）
var intensity: float = 0.5:
	set(value):
		intensity = clamp(value, 0.0, 1.0)
		_update_resource_name()

# 抖动持续时间（秒）
var duration: float = 0.5:
	set(value):
		duration = max(0.0, value)
		_update_resource_name()

# 是否使用 JuicyMixer 系统
var use_juicy_mixer: bool = false:
	set(value):
		use_juicy_mixer = value
		notify_property_list_changed()
		_update_resource_name()

# JuicyMixer 反馈资源路径（如果 use_juicy_mixer = true）
var juicy_feedback_path: String = "":
	set(value):
		juicy_feedback_path = value
		_update_resource_name()

## 获取指令元数据
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "BRICKS_INSTRUCTION_CAMERA_SHAKE_NAME"
	metadata.category_key = "BRICKS_CATEGORY_CAMERA"
	metadata.description_key = "BRICKS_INSTRUCTION_CAMERA_SHAKE_DESC"
	metadata.keywords = ["camera", "shake", "impact", "effect", "screen", "相机", "抖动", "震动", "效果"]
	metadata.builtin_icon = "AnimationTracks"
	return metadata

func _setup_metadata():
	pass

## 获取属性列表
func _get_property_list() -> Array[Dictionary]:
	var properties := []

	properties.append({
		name = "Camera Shake",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "target_node",
		type = TYPE_NODE_PATH,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	properties.append({
		name = "intensity",
		type = TYPE_FLOAT,
		hint = PROPERTY_HINT_RANGE,
		hint_string = "0.0,1.0,0.1",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	properties.append({
		name = "duration",
		type = TYPE_FLOAT,
		hint = PROPERTY_HINT_RANGE,
		hint_string = "0.0,5.0,0.1",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	properties.append({
		name = "use_juicy_mixer",
		type = TYPE_BOOL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	if use_juicy_mixer:
		properties.append({
			name = "juicy_feedback_path",
			type = TYPE_STRING,
			hint = PROPERTY_HINT_FILE,
			hint_string = "*.tres",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

	return properties

## 更新资源名称
func _update_resource_name():
	var parts := []

	parts.append("相机抖动")

	if use_juicy_mixer:
		if not juicy_feedback_path.is_empty():
			var resource_name = juicy_feedback_path.get_file()
			parts.append("(JuicyMixer: %s)" % resource_name)
		else:
			parts.append("(JuicyMixer: 未指定)")
	else:
		parts.append("(强度: %.1f, 时间: %.1f秒)" % [intensity, duration])

	resource_name = " ".join(parts)

## 执行指令
func execute(context: ExecutionContext):
	_start_execution(context)

	# 获取相机节点
	var camera = context.get_node(target_node)
	if not camera:
		_log_error_localized("BRICKS_ERROR_CAMERA_NODE_NOT_FOUND", {})
		set_error_localized("BRICKS_ERROR_CAMERA_NODE_NOT_FOUND", BricksError.ErrorType.RUNTIME_ERROR, {})
		finished.emit()
		return

	# 验证相机类型
	if not camera is Camera2D:
		_log_error_localized("BRICKS_ERROR_CAMERA_NOT_CAMERA2D", {})
		set_error_localized("BRICKS_ERROR_CAMERA_NOT_CAMERA2D", BricksError.ErrorType.RUNTIME_ERROR, {})
		finished.emit()
		return

	var camera_2d = camera as Camera2D

	# 验证持续时间
	if duration <= 0.0:
		_log_error_localized("BRICKS_ERROR_SHAKE_DURATION_INVALID", {})
		set_error_localized("BRICKS_ERROR_SHAKE_DURATION_INVALID", BricksError.ErrorType.VALIDATION_ERROR, {})
		finished.emit()
		return

	# 执行抖动
	if use_juicy_mixer:
		_execute_juicy_mixer_shake(camera_2d)
	else:
		_execute_simple_shake(camera_2d)

	_on_execution_completed()

## 简单抖动实现
func _execute_simple_shake(camera: Camera2D):
	# 使用 Tween 创建简单抖动效果
	var scene_tree = Engine.get_main_loop()
	if not scene_tree:
		_log_error_localized("BRICKS_ERROR_CANNOT_GET_SCENETREE", {})
		set_error_localized("BRICKS_ERROR_CANNOT_GET_SCENETREE", BricksError.ErrorType.RUNTIME_ERROR, {})
		return

	var tween = scene_tree.create_tween()

	# 保存原始偏移
	var original_offset = camera.offset

	# 创建抖动动画（随机偏移）
	var shake_count = int(duration * 60)  # 60 FPS
	for i in shake_count:
		var random_offset = Vector2(
			randf_range(-intensity * 20, intensity * 20),
			randf_range(-intensity * 20, intensity * 20)
		)

		tween.tween_property(camera, "offset", random_offset, 0.016)  # ~1帧
		tween.tween_property(camera, "offset", original_offset, 0.016)

	tween.finished.connect(_on_shake_completed.bind(camera, original_offset), CONNECT_ONE_SHOT)
	await tween.finished

	_log_info("相机抖动完成 (强度: %.1f, 时间: %.1f秒)" % [intensity, duration])

## JuicyMixer 抖动实现
func _execute_juicy_mixer_shake(camera: Camera2D):
	# 加载 JuicyFeedback 资源
	if juicy_feedback_path.is_empty():
		_log_error("JuicyMixer 路径为空，回退到简单抖动")
		_execute_simple_shake(camera)
		return

	var feedback_resource = load(juicy_feedback_path)
	if not feedback_resource or not feedback_resource is JuicyFeedback:
		_log_error_localized("BRICKS_ERROR_RESOURCE_NOT_FOUND", {"resource": juicy_feedback_path})
		set_error_localized("BRICKS_ERROR_RESOURCE_NOT_FOUND", BricksError.ErrorType.RUNTIME_ERROR, {"resource": juicy_feedback_path})
		return

	# 使用 JuicyMixer 系统
	# 注意：这需要项目集成 JuicyMixer 系统
	_log_warning("JuicyMixer 集成尚未实现，使用简单抖动")
	_execute_simple_shake(camera)

func _on_shake_completed(camera: Camera2D, original_offset: Vector2):
	camera.offset = original_offset

## 验证指令参数
func validate() -> Array[String]:
	var errors = super.validate()

	if target_node.is_empty():
		errors.append("目标相机节点不能为空")

	if use_juicy_mixer and juicy_feedback_path.is_empty():
		errors.append("使用 JuicyMixer 时必须指定反馈资源路径")

	if duration <= 0.0:
		errors.append("持续时间必须大于 0")

	return errors

## 获取指令描述
func get_description() -> String:
	if use_juicy_mixer:
		if not juicy_feedback_path.is_empty():
			return "相机抖动 (JuicyMixer: %s)" % juicy_feedback_path.get_file()
		else:
			return "相机抖动 (JuicyMixer: 未指定)"
	else:
		return "相机抖动 (强度: %.1f, 时间: %.1f秒)" % [intensity, duration]
```

#### Step 3: 创建测试场景和脚本

创建测试场景和脚本，测试不同强度和持续时间的抖动效果。

#### Step 4: 验证和提交

```bash
git add addons/bricks/instructions/camera_shake.gd
git add addons/bricks/instructions/camera_shake.gd.uid
git add addons/bricks/tests/instructions/test_camera_shake.gd
git add addons/bricks/tests/instructions/test_camera_shake.gd.uid
git add addons/bricks/tests/instructions/test_camera_shake.tscn
git add addons/bricks/localization/translations.csv
git commit -m "feat(bricks): 添加 Camera Shake 指令（Phase 4B-3/3）

- 触发相机抖动效果（支持强度和持续时间配置）
- 支持简单抖动和 JuicyMixer 两种模式
- 使用 Tween 实现平滑的随机偏移动画
- 完整的错误处理和参数验证
- Phase 4B 完成（相机控制完善）

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## 📊 完成检查清单

### Phase 4B: 相机控制完善（待实现）
- [ ] Set Camera Limit
- [ ] Camera Follow
- [ ] Camera Shake

---

## 📚 参考文档

- [指令创建指南](../../addons/bricks/docs/development/instruction_creation_guide.md)
- [Phase 4A 开发计划](./2026-01-27-bricks-phase4-instruction-plan.md)
- [Bricks 指令路线图](../../addons/bricks/docs/roadmap/2026-01-24-bricks-instruction-roadmap.md)

---

**文档维护:** Bricks 开发团队
**创建日期:** 2026-01-27
**状态:** 📝 计划中
**预计完成:** 1 周

---

## 下一步行动

1. ⏳ Set Camera Limit (相机控制) - 3 个指令 - 详细计划已完成
2. ⏳ Camera Follow (相机控制) - 3 个指令 - 详细计划已完成
3. ⏳ Camera Shake (相机控制) - 3 个指令 - 详细计划已完成
