@icon("res://addons/fuse/icons/builtin/CharacterBody2D.svg")
@tool
extends BaseInstruction
class_name MoveCharacterBody2DComposite

## Instruction: MoveCharacterBody2DComposite
##
## 使用合并后的输入向量移动 CharacterBody2D 节点
## 支持三种移动模式：直接、平滑、加速度

## 移动模式枚举
enum MoveMode {
	DIRECT,           # 直接设置 velocity
	SMOOTH,           # 平滑插值到目标速度
	ACCELERATION      # 使用加速度和摩擦力
}

## 目标 CharacterBody2D 节点
var target_node: NodePath = NodePath(""):
	set(value):
		target_node = value
		_update_resource_name()

## 移动速度（像素/秒）
var speed: float = 200.0:
	set(value):
		speed = value
		_update_resource_name()

## 移动模式
var move_mode: MoveMode = MoveMode.DIRECT:
	set(value):
		move_mode = value
		_update_resource_name()
		if Engine.is_editor_hint():
			notify_property_list_changed()

## 平滑因子（仅 SMOOTH 模式）
## 值越大，变化越快
var smooth_factor: float = 10.0

## 加速度（像素/秒²，仅 ACCELERATION 模式）
var acceleration: float = 1000.0

## 摩擦力（像素/秒²，仅 ACCELERATION 模式）
var friction: float = 800.0

## 是否使用相对方向（基于节点旋转）
var use_relative_direction: bool = false:
	set(value):
		use_relative_direction = value
		_update_resource_name()

## 获取指令元数据（用于指令选择器）
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_MOVE_CHARACTER_BODY_2D_COMPOSITE_NAME"
	metadata.category_key = "FUSE_CATEGORY_MOVEMENT"
	metadata.description_key = "FUSE_INSTRUCTION_MOVE_CHARACTER_BODY_2D_COMPOSITE_DESC"
	metadata.keywords = ["move", "character", "movement", "velocity", "smooth", "acceleration", "移动", "角色", "速度", "平滑", "加速"]
	metadata.builtin_icon = "CharacterBody2D"
	return metadata

## 设置指令元数据
func _setup_metadata():
	pass

## 更新资源名称
func _update_resource_name():
	var parts = []

	# 基础信息
	parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_MOVE_CHARACTER_BODY_2D_COMPOSITE_BASE"))

	# 目标节点
	if not target_node.is_empty():
		parts.append(FuseLocalization.translate_format("FUSE_INSTRUCTION_MOVE_CHARACTER_BODY_2D_COMPOSITE_TARGET", {
			"node": _get_node_display_name(target_node)
		}))
	else:
		parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_MOVE_CHARACTER_BODY_2D_COMPOSITE_NO_NODE"))

	# 移动模式
	var mode_key = ""
	match move_mode:
		MoveMode.DIRECT:
			mode_key = "FUSE_MOVE_MODE_DIRECT"
		MoveMode.SMOOTH:
			mode_key = "FUSE_MOVE_MODE_SMOOTH"
		MoveMode.ACCELERATION:
			mode_key = "FUSE_MOVE_MODE_ACCELERATION"
	parts.append(FuseLocalization.translate(mode_key))

	# 速度
	parts.append(FuseLocalization.translate_format("FUSE_INSTRUCTION_MOVE_CHARACTER_BODY_2D_COMPOSITE_SPEED", {
		"speed": str(speed)
	}))

	# 相对方向
	if use_relative_direction:
		parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_MOVE_CHARACTER_BODY_2D_COMPOSITE_RELATIVE"))

	resource_name = " ".join(parts)

## 获取动态属性列表
func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []

	# CharacterBody2D 分类
	properties.append({
		name = "CharacterBody2D",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	# 目标节点
	properties.append({
		name = "target_node",
		type = TYPE_NODE_PATH,
		hint = PROPERTY_HINT_NODE_PATH_VALID_TYPES,
		hint_string = "CharacterBody2D",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# Movement 分类
	properties.append({
		name = "Movement",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	# 移动速度
	properties.append({
		name = "speed",
		type = TYPE_FLOAT,
		hint = PROPERTY_HINT_RANGE,
		hint_string = "0.0,2000.0,10.0",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 移动模式
	properties.append({
		name = "move_mode",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Direct,Smooth,Acceleration",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 平滑因子（仅 SMOOTH 模式显示）
	if move_mode == MoveMode.SMOOTH:
		properties.append({
			name = "smooth_factor",
			type = TYPE_FLOAT,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "0.1,20.0,0.1",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

	# 加速度和摩擦力（仅 ACCELERATION 模式显示）
	if move_mode == MoveMode.ACCELERATION:
		properties.append({
			name = "acceleration",
			type = TYPE_FLOAT,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "0.0,5000.0,50.0",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		properties.append({
			name = "friction",
			type = TYPE_FLOAT,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "0.0,5000.0,50.0",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

	# Options 分类
	properties.append({
		name = "Options",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	# 相对方向
	properties.append({
		name = "use_relative_direction",
		type = TYPE_BOOL,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	return properties

## 执行指令
func execute(context: ExecutionContext):
	_start_execution(context)

	# 验证目标节点
	if target_node.is_empty():
		_log_error_localized("FUSE_ERROR_TARGET_NODE_NOT_SPECIFIED", {})
		set_error_localized("FUSE_ERROR_TARGET_NODE_NOT_SPECIFIED", FuseError.ErrorType.VALIDATION_ERROR, {})
		finished.emit()
		return

	# 获取目标节点
	var target = context.get_node(target_node)
	if not target:
		_log_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", {"node": str(target_node)})
		set_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {"node": str(target_node)})
		finished.emit()
		return

	# 验证节点类型
	if not target is CharacterBody2D:
		var type_str = target.get_class()
		_log_error_localized("FUSE_ERROR_TARGET_NODE_NOT_CHARACTER_BODY_2D", {"actual_type": type_str})
		_log_error("Target node type: %s, expected: CharacterBody2D" % type_str)
		set_error_localized("FUSE_ERROR_TARGET_NODE_NOT_CHARACTER_BODY_2D", FuseError.ErrorType.RUNTIME_ERROR, {"actual_type": type_str})
		finished.emit()
		return

	var char_body = target as CharacterBody2D

	# 从 RuntimeEventInstance 获取输入向量
	var input_vector = _get_input_vector(context)
	if input_vector == Vector2.ZERO:
		_log_warning_localized("FUSE_WARNING_CHARACTER_BODY_2D_ZERO_VELOCITY", {})
		# 在 ACCELERATION 模式下，零输入仍然需要应用摩擦力
		if move_mode == MoveMode.ACCELERATION:
			_apply_friction(char_body, context.delta)
			char_body.move_and_slide()
		# 其他模式下，零速度仍然执行 move_and_slide 以便处理碰撞
		else:
			char_body.velocity = Vector2.ZERO
			char_body.move_and_slide()
		_on_execution_completed()
		return

	# 计算移动方向
	var direction = input_vector.normalized()

	# 如果使用相对方向，应用节点旋转
	if use_relative_direction:
		direction = direction.rotated(char_body.rotation)

	# 应用移动模式
	match move_mode:
		MoveMode.DIRECT:
			_apply_direct_movement(char_body, direction)
		MoveMode.SMOOTH:
			_apply_smooth_movement(char_body, direction, context.delta)
		MoveMode.ACCELERATION:
			_apply_acceleration_movement(char_body, direction, context.delta)

	# 执行移动
	char_body.move_and_slide()

	_log_debug_localized("FUSE_LOG_CHARACTER_BODY_2D_MOVEMENT_APPLIED", {
		"mode": MoveMode.keys()[move_mode],
		"velocity": str(char_body.velocity),
		"direction": str(direction)
	})

	_on_execution_completed()

## 应用直接移动模式
func _apply_direct_movement(target: CharacterBody2D, direction: Vector2) -> void:
	target.velocity = direction * speed

## 应用平滑移动模式
func _apply_smooth_movement(target: CharacterBody2D, direction: Vector2, delta: float) -> void:
	var target_velocity = direction * speed
	var smooth_speed = smooth_factor if smooth_factor > 0 else 10.0
	target.velocity = target.velocity.lerp(target_velocity, smooth_speed * delta)

## 应用加速度移动模式
func _apply_acceleration_movement(target: CharacterBody2D, direction: Vector2, delta: float) -> void:
	var accel = acceleration if acceleration > 0 else 1000.0
	var target_velocity = direction * speed
	target.velocity = target.velocity.move_toward(target_velocity, accel * delta)

## 应用摩擦力（加速度模式下停止时）
func _apply_friction(target: CharacterBody2D, delta: float) -> void:
	var frict = friction if friction > 0 else 800.0
	target.velocity = target.velocity.move_toward(Vector2.ZERO, frict * delta)

## 从上下文获取输入向量
func _get_input_vector(context: ExecutionContext) -> Vector2:
	# 尝试从事件实例获取输入向量
	if context.has_method("get_event_instance"):
		var event_instance = context.get_event_instance()
		if event_instance and event_instance.has_method("get_runtime_state"):
			var input_vector = event_instance.get_runtime_state("last_input_vector")
			if input_vector is Vector2:
				return input_vector

	# 备选方案：从执行上下文的变量获取
	if context.has_method("get_variable"):
		var input_vector = context.get_variable("input_vector", Vector2.ZERO)
		if input_vector is Vector2:
			return input_vector

	return Vector2.ZERO

## 验证指令配置
func validate() -> Array[String]:
	var errors: Array[String] = super.validate()

	if target_node.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_TARGET_NODE_NOT_SPECIFIED"))

	if speed <= 0:
		errors.append(FuseLocalization.translate("FUSE_ERROR_SPEED_MUST_BE_POSITIVE"))

	if move_mode == MoveMode.SMOOTH and smooth_factor <= 0:
		errors.append(FuseLocalization.translate("FUSE_ERROR_SMOOTH_FACTOR_MUST_BE_POSITIVE"))

	if move_mode == MoveMode.ACCELERATION:
		if acceleration <= 0:
			errors.append(FuseLocalization.translate("FUSE_ERROR_ACCELERATION_MUST_BE_POSITIVE"))
		if friction <= 0:
			errors.append(FuseLocalization.translate("FUSE_ERROR_FRICTION_MUST_BE_POSITIVE"))

	return errors

## 获取指令描述
func get_description() -> String:
	var parts = []

	# 基础描述
	if not target_node.is_empty():
		parts.append(FuseLocalization.translate_format("FUSE_INSTRUCTION_MOVE_CHARACTER_BODY_2D_COMPOSITE_DESC_TARGET", {
			"node": _get_node_display_name(target_node)
		}))
	else:
		parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_MOVE_CHARACTER_BODY_2D_COMPOSITE_DESC_NO_NODE"))

	# 模式描述
	var mode_desc = ""
	match move_mode:
		MoveMode.DIRECT:
			mode_desc = FuseLocalization.translate("FUSE_MOVE_MODE_DIRECT_DESC")
		MoveMode.SMOOTH:
			mode_desc = FuseLocalization.translate("FUSE_MOVE_MODE_SMOOTH_DESC")
		MoveMode.ACCELERATION:
			mode_desc = FuseLocalization.translate("FUSE_MOVE_MODE_ACCELERATION_DESC")
	parts.append(mode_desc)

	# 速度描述
	parts.append(FuseLocalization.translate_format("FUSE_INSTRUCTION_MOVE_CHARACTER_BODY_2D_COMPOSITE_DESC_SPEED", {
		"speed": str(speed)
	}))

	return ", ".join(parts)

## 动态属性设置
func _set(property: StringName, value: Variant) -> bool:
	if property == "move_mode":
		move_mode = value
		notify_property_list_changed()
		_update_resource_name()
		return true
	return false

## 属性验证
func _validate_property(property: Dictionary) -> void:
	if property.name == "smooth_factor" and move_mode != MoveMode.SMOOTH:
		property.usage = PROPERTY_USAGE_NO_EDITOR

	if property.name == "acceleration" and move_mode != MoveMode.ACCELERATION:
		property.usage = PROPERTY_USAGE_NO_EDITOR

	if property.name == "friction" and move_mode != MoveMode.ACCELERATION:
		property.usage = PROPERTY_USAGE_NO_EDITOR
