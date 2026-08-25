@tool
@icon("res://addons/fuse/icons/builtin/MoveRight.png")
extends BaseTweenInstruction
class_name TweenMoveTo


## 作用域来源枚举
enum ScopeSource {
	NEAREST,        ## 最近的作用域容器（默认）
	CUSTOM_ID,      ## 指定 scope_id
	TRIGGER_SCOPE,  ## Trigger 节点上的作用域
	TARGET_NODE     ## Target 节点上的作用域
}

## Tween Move To 指令 - 平滑移动节点（相对移动，支持全局/局部坐标空间）

# 坐标空间枚举
enum SpaceMode {
	GLOBAL,
	LOCAL
}

# 参数配置
var target_node: NodePath = NodePath(""):
	set(value):
		target_node = value
		_update_resource_name()
		notify_property_list_changed()

## 是否从变量获取目标节点
var use_variable_for_target: bool = false:
	set(value):
		use_variable_for_target = value
		_update_resource_name()
		notify_property_list_changed()

## 目标节点变量名
var target_variable: String = "":
	set(value):
		target_variable = value
		_update_resource_name()

## 目标节点变量作用域
var target_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		target_scope = value
		_update_resource_name()
		notify_property_list_changed()

## 目标节点作用域来源（仅当 target_scope == SCOPE 时使用）
var target_scope_source: ScopeSource = ScopeSource.NEAREST:
	set(value):
		target_scope_source = value
		_update_resource_name()
		notify_property_list_changed()

## 目标节点自定义作用域 ID（CUSTOM_ID 模式使用）
var target_custom_scope_id: String = "":
	set(value):
		target_custom_scope_id = value
		_update_resource_name()

## 目标节点目标节点路径（TARGET_NODE 模式使用）
var target_target_node_path: NodePath = NodePath(""):
	set(value):
		target_target_node_path = value
		_update_resource_name()

var target_position: Vector2 = Vector2.ZERO:
	set(value):
		target_position = value
		_update_resource_name()

var duration: float = 0.5:
	set(value):
		duration = value
		_update_resource_name()

## 时长来源
enum DurationSource {
	DIRECT,    ## 直接设置
	VARIABLE   ## 从变量读取
}

## 时长值来源模式
var duration_source: DurationSource = DurationSource.DIRECT:
	set(value):
		duration_source = value
		_update_resource_name()
		notify_property_list_changed()

## 时长变量名（当 duration_source == VARIABLE 时使用）
var duration_variable: String = "":
	set(value):
		duration_variable = value
		_update_resource_name()

## 时长变量作用域
var duration_variable_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		duration_variable_scope = value
		_update_resource_name()
		notify_property_list_changed()

## 时长作用域来源（仅当 duration_variable_scope == SCOPE 时使用）
var duration_scope_source: ScopeSource = ScopeSource.NEAREST:
	set(value):
		duration_scope_source = value
		_update_resource_name()
		notify_property_list_changed()

## 时长自定义作用域 ID（CUSTOM_ID 模式使用）
var duration_custom_scope_id: String = "":
	set(value):
		duration_custom_scope_id = value
		_update_resource_name()

## 时长目标节点路径（TARGET_NODE 模式使用）
var duration_target_node_path: NodePath = NodePath(""):
	set(value):
		duration_target_node_path = value
		_update_resource_name()

var space_mode: SpaceMode = SpaceMode.GLOBAL:
	set(value):
		space_mode = value
		_update_resource_name()
		notify_property_list_changed()

var easing_type: EasingType = EasingType.EASE_IN_OUT:
	set(value):
		easing_type = value
		_update_resource_name()

var trans_type: TransitionType = TransitionType.SINE:
	set(value):
		trans_type = value
		_update_resource_name()

## 获取指令元数据
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_TWEEN_MOVE_TO_NAME"
	metadata.category_key = "FUSE_CATEGORY_TWEEN"
	metadata.description_key = "FUSE_INSTRUCTION_TWEEN_MOVE_TO_DESC"
	metadata.keywords = ["tween", "move", "position", "移动", "位置", "动画"]
	metadata.builtin_icon = "MoveRight"
	return metadata

## 设置指令元数据
func _setup_metadata():
	pass

## 声明变量读写模式
func get_variable_modes() -> Array[Dictionary]:
	var modes: Array[Dictionary] = []
	if use_variable_for_target:
		modes.append({"name": "target_variable", "mode": "read"})
	if duration_source == DurationSource.VARIABLE:
		modes.append({"name": "duration_variable", "mode": "read"})
	return modes

## 解析实际时长（DIRECT 直返；VARIABLE 读变量，失败返回 -1.0 由调用方报错）
func _get_duration(context: ExecutionContext) -> float:
	if duration_source == DurationSource.DIRECT:
		return duration

	if duration_variable.is_empty():
		return -1.0

	var var_value: Variant
	if duration_variable_scope == BaseVariable.VariableScope.SCOPE:
		if duration_scope_source == ScopeSource.NEAREST:
			var_value = VariableOperations.get_variable(context, duration_variable, BaseVariable.VariableScope.SCOPE, null)
		else:
			var utils_scope_source = duration_scope_source as VariableScopeUtils.ScopeSource
			var scope_container = VariableScopeUtils.get_scope_container_by_source(
				context,
				utils_scope_source,
				duration_custom_scope_id,
				duration_target_node_path
			)
			if scope_container == null:
				return -1.0
			var_value = scope_container.get_variable(duration_variable, null)
	else:
		var_value = VariableOperations.get_variable(context, duration_variable, duration_variable_scope, null)

	if var_value == null:
		return -1.0
	return TypeConverter.safe_convert_to_float(var_value)


## 获取属性列表
func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	# 基础参数分类
	properties.append({
		name = "Tween Move To",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	# 目标节点

	# 是否从变量获取目标节点
	properties.append({
		name = "use_variable_for_target",
		type = TYPE_BOOL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	if not use_variable_for_target:
		# 直接指定节点路径
		properties.append({
			name = "target_node",
			type = TYPE_NODE_PATH,
			hint = PROPERTY_HINT_NODE_PATH_VALID_TYPES,
			hint_string = "Node2D,Node3D",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})
	else:
		# 从变量获取节点
		properties.append({
			name = "target_variable",
			type = TYPE_STRING,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		properties.append({
			name = "target_scope",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "Local,Scope,Global",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		if target_scope == BaseVariable.VariableScope.SCOPE:
			properties.append({
				name = "target_scope_source",
				type = TYPE_INT,
				hint = PROPERTY_HINT_ENUM,
				hint_string = "Nearest,Custom ID,Trigger Scope,Target Node",
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})

			if target_scope_source == ScopeSource.CUSTOM_ID:
				properties.append({
					name = "target_custom_scope_id",
					type = TYPE_STRING,
					hint = PROPERTY_HINT_NONE,
					usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
				})
			elif target_scope_source == ScopeSource.TARGET_NODE:
				properties.append({
					name = "target_target_node_path",
					type = TYPE_NODE_PATH,
					hint = PROPERTY_HINT_NONE,
					usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
				})

	# 目标位置
	properties.append({
		name = "target_position",
		type = TYPE_VECTOR2,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 持续时间（双轨：直填 / 变量）
	properties.append({
		name = "duration_source",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Direct,Variable",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})
	if duration_source == DurationSource.DIRECT:
		properties.append({
			name = "duration",
			type = TYPE_FLOAT,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "0,10,0.1,or_greater",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})
	else:
		properties.append({
			name = "duration_variable",
			type = TYPE_STRING,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})
		properties.append({
			name = "duration_variable_scope",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "Local,Scope,Global",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})
		if duration_variable_scope == BaseVariable.VariableScope.SCOPE:
			properties.append({
				name = "duration_scope_source",
				type = TYPE_INT,
				hint = PROPERTY_HINT_ENUM,
				hint_string = "Nearest,Custom ID,Trigger Scope,Target Node",
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})
			if duration_scope_source == ScopeSource.CUSTOM_ID:
				properties.append({
					name = "duration_custom_scope_id",
					type = TYPE_STRING,
					hint = PROPERTY_HINT_NONE,
					usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
				})
			elif duration_scope_source == ScopeSource.TARGET_NODE:
				properties.append({
					name = "duration_target_node_path",
					type = TYPE_NODE_PATH,
					hint = PROPERTY_HINT_NONE,
					usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
				})

	# 坐标空间
	properties.append({
		name = "space_mode",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Global,Local",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 缓动类型
	properties.append({
		name = "easing_type",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "In,Out,InOut,OutIn",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 过渡类型
	properties.append({
		name = "trans_type",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Linear,Sine,Quad,Cubic,Quart,Quint,Expo,Circ,Back,Spring,Bounce,Elastic",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	return properties

## 更新资源名称（必需）
func _update_resource_name():
	var parts = []
	parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_TWEEN_MOVE_TO_NAME"))
	var target_str := ""
	if use_variable_for_target:
		if target_variable.is_empty():
			target_str = FuseLocalization.translate("FUSE_COMMON_NO_NODE_SELECTED")
		else:
			var target_scope_str := VariableScopeUtils.enum_to_string(target_scope).to_upper()
			if target_scope == BaseVariable.VariableScope.SCOPE:
				var target_utils_scope_source = target_scope_source as VariableScopeUtils.ScopeSource
				target_scope_str = VariableScopeUtils.get_scope_source_string(target_utils_scope_source, target_custom_scope_id, target_target_node_path)
			target_str = "%s [%s]" % [target_variable, target_scope_str]
	else:
		target_str = _get_node_display_name(target_node) if not target_node.is_empty() else FuseLocalization.translate("FUSE_COMMON_NO_NODE_SELECTED")
	parts.append("[%s]" % target_str)

	parts.append(str(target_position))
	var space_key = "FUSE_SPACE_GLOBAL" if space_mode == SpaceMode.GLOBAL else "FUSE_SPACE_LOCAL"
	parts.append("(%s)" % FuseLocalization.translate(space_key))
	if duration_source == DurationSource.DIRECT:
		parts.append("(%.2fs)" % duration)
	else:
		var dur_str := duration_variable if not duration_variable.is_empty() else "-"
		parts.append("(%s)" % dur_str)

	resource_name = " ".join(parts)

## 属性验证
func _validate_property(property: Dictionary) -> void:
	# 控制目标节点相关属性可见性
	if not use_variable_for_target:
		if property.name in ["target_variable", "target_scope", "target_scope_source", "target_custom_scope_id", "target_target_node_path"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR
	else:
		if property.name == "target_node":
			property.usage = PROPERTY_USAGE_NO_EDITOR

		if target_scope != BaseVariable.VariableScope.SCOPE:
			if property.name in ["target_scope_source", "target_custom_scope_id", "target_target_node_path"]:
				property.usage = PROPERTY_USAGE_NO_EDITOR
		else:
			var target_utils_scope_source = target_scope_source as VariableScopeUtils.ScopeSource
			VariableScopeUtils.validate_scope_source_property(property, target_utils_scope_source)

	# 时长来源相关属性可见性
	if duration_source == DurationSource.DIRECT:
		if property.name in ["duration_variable", "duration_variable_scope", "duration_scope_source", "duration_custom_scope_id", "duration_target_node_path"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR
	else:
		if property.name == "duration":
			property.usage = PROPERTY_USAGE_NO_EDITOR
		if duration_variable_scope != BaseVariable.VariableScope.SCOPE:
			if property.name in ["duration_scope_source", "duration_custom_scope_id", "duration_target_node_path"]:
				property.usage = PROPERTY_USAGE_NO_EDITOR
		else:
			var duration_utils_scope_source = duration_scope_source as VariableScopeUtils.ScopeSource
			VariableScopeUtils.validate_scope_source_property(property, duration_utils_scope_source)
## 动态属性设置
func _set(property: StringName, value: Variant) -> bool:
	if property in ["use_variable_for_target", "target_scope", "target_scope_source"]:
		set(property, value)
		notify_property_list_changed()
		return true
	return false
## 获取指令描述（必需）
func get_description() -> String:
	var target_desc := ""
	if use_variable_for_target:
		if target_variable.is_empty():
			target_desc = FuseLocalization.translate("FUSE_COMMON_NO_NODE_SELECTED")
		else:
			var target_scope_str := VariableScopeUtils.enum_to_string(target_scope).to_upper()
			if target_scope == BaseVariable.VariableScope.SCOPE:
				var target_utils_scope_source = target_scope_source as VariableScopeUtils.ScopeSource
				target_scope_str = VariableScopeUtils.get_scope_source_string(target_utils_scope_source, target_custom_scope_id, target_target_node_path)
			target_desc = "%s [%s]" % [target_variable, target_scope_str]
	else:
		target_desc = _get_node_display_name(target_node) if not target_node.is_empty() else FuseLocalization.translate("FUSE_COMMON_NO_NODE_SELECTED")
	# target_desc ready
	var space_key = "FUSE_SPACE_GLOBAL" if space_mode == SpaceMode.GLOBAL else "FUSE_SPACE_LOCAL"
	var space_desc = FuseLocalization.translate(space_key)
	return FuseLocalization.translate_format("FUSE_INSTRUCTION_TWEEN_MOVE_TO_DESC_FORMAT", {
		"target": target_desc,
		"position": str(target_position),
		"space": space_desc
	})

## 执行指令
func execute(context: ExecutionContext) -> void:
	_start_execution(context)

	# 验证目标节点

	# 获取目标节点
	var target = _resolve_node(
		context,
		use_variable_for_target,
		target_node,
		target_variable,
		target_scope,
		target_scope_source,
		target_custom_scope_id,
		target_target_node_path,
		"FUSE_ERROR_TARGET_VARIABLE_EMPTY",
		"FUSE_ERROR_TARGET_NODE_EMPTY",
		"FUSE_ERROR_TARGET_NODE_NOT_FOUND"
	)
	if not target:
		finished.emit()
		return

	# 验证节点有 position 属性
	if not "position" in target:
		_log_error_localized("FUSE_ERROR_NODE_TYPE_INVALID", {"node": target.name, "expected": "Node2D or Node3D"})
		set_error_localized("FUSE_ERROR_NODE_TYPE_INVALID", FuseError.ErrorType.VALIDATION_ERROR, {"node": target.name, "expected": "Node2D or Node3D"})
		finished.emit()
		return

	# 创建 Tween
	var tween = _create_tween(target)
	if tween == null:
		_log_error_localized("FUSE_ERROR_CANNOT_CREATE_TWEEN", {})
		set_error_localized("FUSE_ERROR_CANNOT_CREATE_TWEEN", FuseError.ErrorType.RUNTIME_ERROR, {})
		finished.emit()
		return

	# 应用缓动设置
	_apply_easing_settings(tween, easing_type, trans_type)

	# 解析实际时长（变量源失败为负，报错终止）
	var actual_duration := _get_duration(context)
	if actual_duration < 0:
		_log_error_localized("FUSE_ERROR_INVALID_PARAMETER", {"param": "duration"})
		set_error_localized("FUSE_ERROR_INVALID_PARAMETER", FuseError.ErrorType.VALIDATION_ERROR, {"param": "duration"})
		finished.emit()
		return

	# 获取当前位置并计算相对移动的目标位置
	var current_position: Vector2
	var final_position: Vector2

	if space_mode == SpaceMode.GLOBAL:
		# 获取当前世界坐标
		if target is Node2D:
			current_position = target.global_position
		elif target.has_method("get_global_position"):
			current_position = target.get_global_position()
		else:
			current_position = target.position
		# 计算相对偏移后的目标位置
		final_position = current_position + target_position
	else:
		# 获取当前本地坐标
		current_position = target.position
		# 计算相对偏移后的目标位置
		final_position = current_position + target_position

	# 根据坐标空间选择属性
	var property_name = "global_position" if space_mode == SpaceMode.GLOBAL else "position"

	# 播放移动动画到相对偏移后的位置
	tween.tween_property(target, property_name, final_position, actual_duration)

	_log_info_localized("FUSE_LOG_TWEEN_MOVE_TO", {
		"node": target.name,
		"position": str(final_position),
		"from": str(current_position),
		"offset": str(target_position),
		"space": "global" if space_mode == SpaceMode.GLOBAL else "local",
		"duration": str(actual_duration)
	})

	# 等待动画完成
	await tween.finished
	_on_execution_completed()

## 验证参数（必需）
func validate() -> Array[String]:
	var errors = super.validate()
	# 验证 目标节点
	if use_variable_for_target:
		if target_variable.is_empty():
			errors.append(FuseLocalization.translate("FUSE_ERROR_TARGET_VARIABLE_EMPTY"))
		if target_scope == BaseVariable.VariableScope.SCOPE:
			var target_utils_scope_source = target_scope_source as VariableScopeUtils.ScopeSource
			errors.append_array(VariableScopeUtils.validate_scope_source_params(
				target_utils_scope_source,
				target_custom_scope_id,
				target_target_node_path
			))
	else:
		if target_node.is_empty():
			errors.append(FuseLocalization.translate("FUSE_ERROR_TARGET_NODE_EMPTY"))


	if duration_source == DurationSource.DIRECT:
		if duration <= 0:
			errors.append(FuseLocalization.translate("FUSE_ERROR_DURATION_MUST_BE_POSITIVE"))
	else:
		if duration_variable.is_empty():
			errors.append(FuseLocalization.translate("FUSE_ERROR_VAR_NAME_EMPTY"))
		if duration_variable_scope == BaseVariable.VariableScope.SCOPE:
			var duration_utils_scope_source = duration_scope_source as VariableScopeUtils.ScopeSource
			errors.append_array(VariableScopeUtils.validate_scope_source_params(
				duration_utils_scope_source,
				duration_custom_scope_id,
				duration_target_node_path
			))

	return errors

## ============================================================
## 运行时实例模式支持（RuntimeInstructionInstance 架构）
## ============================================================

## 获取默认运行时状态
func get_default_runtime_state() -> Dictionary:
	var state = super.get_default_runtime_state()
	state["tween"] = null
	state["target_instance"] = null
	state["tween_callback"] = null
	state["is_running"] = false
	return state

## 使用运行时实例执行
func execute_with_runtime_instance(runtime_instance: RuntimeInstructionInstance) -> bool:
	_start_execution(runtime_instance.execution_context)

	var state = runtime_instance.runtime_state

	# 验证目标节点
	if target_node.is_empty():
		_log_error_localized("FUSE_ERROR_TARGET_NODE_EMPTY", {})
		set_error_localized("FUSE_ERROR_TARGET_NODE_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
		runtime_instance._complete_execution()
		return true

	# 获取目标节点
	var target = _resolve_node(
		runtime_instance.execution_context,
		use_variable_for_target,
		target_node,
		target_variable,
		target_scope,
		target_scope_source,
		target_custom_scope_id,
		target_target_node_path,
		"FUSE_ERROR_TARGET_VARIABLE_EMPTY",
		"FUSE_ERROR_TARGET_NODE_EMPTY",
		"FUSE_ERROR_TARGET_NODE_NOT_FOUND"
	)
	if target == null:
		_log_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", {"node": str(target_node)})
		set_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {"node": str(target_node)})
		runtime_instance._complete_execution()
		return true

	# 验证节点有 position 属性
	if not "position" in target:
		_log_error_localized("FUSE_ERROR_NODE_TYPE_INVALID", {"node": target.name, "expected": "Node2D or Node3D"})
		set_error_localized("FUSE_ERROR_NODE_TYPE_INVALID", FuseError.ErrorType.VALIDATION_ERROR, {"node": target.name, "expected": "Node2D or Node3D"})
		runtime_instance._complete_execution()
		return true

	state["target_instance"] = target

	# 创建 Tween
	var tween = _create_tween(target)
	if tween == null:
		_log_error_localized("FUSE_ERROR_CANNOT_CREATE_TWEEN", {})
		set_error_localized("FUSE_ERROR_CANNOT_CREATE_TWEEN", FuseError.ErrorType.RUNTIME_ERROR, {})
		runtime_instance._complete_execution()
		return true

	# 解析实际时长（变量源失败为负，报错终止）
	var actual_duration := _get_duration(runtime_instance.execution_context)
	if actual_duration < 0:
		_log_error_localized("FUSE_ERROR_INVALID_PARAMETER", {"param": "duration"})
		set_error_localized("FUSE_ERROR_INVALID_PARAMETER", FuseError.ErrorType.VALIDATION_ERROR, {"param": "duration"})
		runtime_instance._has_error = true
		runtime_instance._error_message = get_error_message()
		runtime_instance._complete_execution()
		return true

	state["tween"] = tween
	state["is_running"] = true

	# 应用缓动设置
	_apply_easing_settings(tween, easing_type, trans_type)

	# 获取当前位置并计算相对移动的目标位置
	var current_position: Vector2
	var final_position: Vector2

	if space_mode == SpaceMode.GLOBAL:
		if target is Node2D:
			current_position = target.global_position
		elif target.has_method("get_global_position"):
			current_position = target.get_global_position()
		else:
			current_position = target.position
		final_position = current_position + target_position
	else:
		current_position = target.position
		final_position = current_position + target_position

	# 根据坐标空间选择属性
	var property_name = "global_position" if space_mode == SpaceMode.GLOBAL else "position"

	# 播放移动动画
	tween.tween_property(target, property_name, final_position, actual_duration)

	_log_info_localized("FUSE_LOG_TWEEN_MOVE_TO", {
		"node": target.name,
		"position": str(final_position),
		"from": str(current_position),
		"offset": str(target_position),
		"space": "global" if space_mode == SpaceMode.GLOBAL else "local",
		"duration": str(actual_duration)
	})

	# 使用回调注册机制
	var callback = _create_tween_callback(runtime_instance)
	tween.finished.connect(callback, CONNECT_ONE_SHOT)
	runtime_instance.register_timer_callback(callback)
	state["tween_callback"] = callback

	return false

## 创建 Tween 完成回调
func _create_tween_callback(runtime_instance: RuntimeInstructionInstance) -> Callable:
	var callback = func():
		_on_runtime_tween_finished(runtime_instance)
	return callback

## Tween 完成回调
func _on_runtime_tween_finished(runtime_instance: RuntimeInstructionInstance) -> void:
	if not runtime_instance or runtime_instance.is_completed():
		return

	var state = runtime_instance.runtime_state
	state["tween"] = null
	state["target_instance"] = null
	state["is_running"] = false
	state["tween_callback"] = null

	runtime_instance._complete_execution()

## 暂停处理
func on_runtime_pause(runtime_instance: RuntimeInstructionInstance) -> void:
	var state = runtime_instance.runtime_state
	var tween = state.get("tween")

	if tween and is_instance_valid(tween):
		tween.pause()
		state["is_running"] = false

## 恢复处理
func on_runtime_resume(runtime_instance: RuntimeInstructionInstance) -> void:
	var state = runtime_instance.runtime_state
	var tween = state.get("tween")

	if tween and is_instance_valid(tween):
		tween.play()
		state["is_running"] = true

## 从变量或节点路径解析节点
func _resolve_node(
	context: ExecutionContext,
	use_variable: bool,
	node_path: NodePath,
	variable_name: String,
	variable_scope: BaseVariable.VariableScope,
	scope_source: ScopeSource,
	custom_scope_id: String,
	target_node_path: NodePath,
	empty_variable_error_key: String,
	empty_node_error_key: String,
	not_found_error_key: String
) -> Node:
	if use_variable:
		if variable_name.is_empty():
			_log_error_localized(empty_variable_error_key, {})
			set_error_localized(empty_variable_error_key, FuseError.ErrorType.VALIDATION_ERROR, {})
			return null

		var node_value = VariableOperations.get_variable(
			context,
			variable_name,
			variable_scope,
			null
		)

		if node_value == null and not VariableOperations.has_variable(context, variable_name, variable_scope):
			_log_error_localized("FUSE_ERROR_VAR_NOT_FOUND", {"variable": variable_name})
			set_error_localized("FUSE_ERROR_VAR_NOT_FOUND", FuseError.ErrorType.VALIDATION_ERROR, {"variable": variable_name})
			return null

		# 支持多种类型：Node、String（节点路径）、NodePath
		if node_value is Node:
			return node_value
		elif node_value is String or node_value is NodePath:
			var resolved_path = NodePath(node_value)
			var resolved_node = context.get_node(resolved_path)
			if not resolved_node:
				_log_error_localized(not_found_error_key, {"node": str(node_value)})
				set_error_localized(not_found_error_key, FuseError.ErrorType.RUNTIME_ERROR, {"node": str(node_value)})
				return null
			return resolved_node
		else:
			_log_error_localized("FUSE_ERROR_VAR_TYPE_NOT_NODE_OR_PATH", {"variable": variable_name, "actual_type": type_string(typeof(node_value))})
			set_error_localized("FUSE_ERROR_VAR_TYPE_NOT_NODE_OR_PATH", FuseError.ErrorType.VALIDATION_ERROR, {"variable": variable_name, "actual_type": type_string(typeof(node_value))})
			return null
	else:
		if node_path.is_empty():
			_log_error_localized(empty_node_error_key, {})
			set_error_localized(empty_node_error_key, FuseError.ErrorType.VALIDATION_ERROR, {})
			return null

		var resolved_node = context.get_node(node_path)
		if not resolved_node:
			_log_error_localized(not_found_error_key, {"node": str(node_path)})
			set_error_localized(not_found_error_key, FuseError.ErrorType.RUNTIME_ERROR, {"node": str(node_path)})
			return null
		return resolved_node

