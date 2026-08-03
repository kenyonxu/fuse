@tool
@icon("res://addons/fuse/icons/builtin/SampleLibrary.png")
extends BaseTweenInstruction
class_name TweenPulseAnimation


## 作用域来源枚举
enum ScopeSource {
	NEAREST,        ## 最近的作用域容器（默认）
	CUSTOM_ID,      ## 指定 scope_id
	TRIGGER_SCOPE,  ## Trigger 节点上的作用域
	TARGET_NODE     ## Target 节点上的作用域
}

## Tween Pulse Animation 指令 - 呼吸/脉冲效果（缩放往复动画）

## 运行时状态
var _tween: Tween = null

## 参数配置
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

var loop_count: int = 0:
	set(value):
		loop_count = value
		_update_resource_name()
		notify_property_list_changed()

## 获取指令元数据
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_TWEEN_PULSE_ANIMATION_NAME"
	metadata.category_key = "FUSE_CATEGORY_TWEEN"
	metadata.description_key = "FUSE_INSTRUCTION_TWEEN_PULSE_ANIMATION_DESC"
	metadata.keywords = ["tween", "pulse", "breathing", "脉冲", "呼吸", "循环"]
	metadata.builtin_icon = "SampleLibrary"
	return metadata

## 设置指令元数据
func _setup_metadata():
	pass

## 声明变量读写模式
func get_variable_modes() -> Array[Dictionary]:
	var modes: Array[Dictionary] = []
	if use_variable_for_target:
		modes.append({"name": "target_variable", "mode": "read"})
	return modes


## 获取属性列表
func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	# 基础参数分类
	properties.append({
		name = "Tween Pulse Animation",
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
			hint_string = "Node2D,Control",
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

	# 最小缩放
	properties.append({
		name = "min_scale",
		type = TYPE_VECTOR2,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 最大缩放
	properties.append({
		name = "max_scale",
		type = TYPE_VECTOR2,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 持续时间
	properties.append({
		name = "duration",
		type = TYPE_FLOAT,
		hint = PROPERTY_HINT_RANGE,
		hint_string = "0.1,10,0.1,or_greater",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 循环次数
	properties.append({
		name = "loop_count",
		type = TYPE_INT,
		hint = PROPERTY_HINT_RANGE,
		hint_string = "0,100,1",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	return properties

## 更新资源名称（必需）
func _update_resource_name():
	var parts = []
	parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_TWEEN_PULSE_ANIMATION_NAME"))
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

	parts.append(FuseLocalization.translate_format("FUSE_INSTRUCTION_TWEEN_PULSE_ANIMATION_SCALE_RANGE", {"min": str(min_scale), "max": str(max_scale)}))

	if loop_count > 0:
		parts.append(FuseLocalization.translate_format("FUSE_INSTRUCTION_TWEEN_PULSE_ANIMATION_LOOP_COUNT", {"count": loop_count}))
	else:
		parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_TWEEN_PULSE_ANIMATION_INFINITE_LOOP"))

	parts.append("(%.2fs)" % duration)

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
	var loop_desc = FuseLocalization.translate_format("FUSE_INSTRUCTION_TWEEN_PULSE_ANIMATION_LOOP_COUNT_DESC", {"count": loop_count}) if loop_count > 0 else FuseLocalization.translate("FUSE_INSTRUCTION_TWEEN_PULSE_ANIMATION_INFINITE_LOOP")
	return FuseLocalization.translate_format("FUSE_INSTRUCTION_TWEEN_PULSE_ANIMATION_DESC_FORMAT", {
		"target": target_desc,
		"min": str(min_scale),
		"max": str(max_scale),
		"loop": loop_desc
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

	# 验证节点有 scale 属性
	if not "scale" in target:
		_log_error_localized("FUSE_ERROR_NODE_TYPE_INVALID", {"node": target.name, "expected": "Node2D or Control"})
		set_error_localized("FUSE_ERROR_NODE_TYPE_INVALID", FuseError.ErrorType.VALIDATION_ERROR, {"node": target.name, "expected": "Node2D or Control"})
		finished.emit()
		return

	# 创建 Tween
	_tween = _create_tween(target)
	if _tween == null:
		_log_error_localized("FUSE_ERROR_CANNOT_CREATE_TWEEN", {})
		set_error_localized("FUSE_ERROR_CANNOT_CREATE_TWEEN", FuseError.ErrorType.RUNTIME_ERROR, {})
		finished.emit()
		return

	# 设置循环次数
	if loop_count > 0:
		_tween.set_loops(loop_count)
	else:
		_tween.set_loops()

	# 设置并行动画（使用 set_parallel 实现往复效果）
	_tween.set_parallel(true)

	# 播放脉冲动画（放大 + 缩小往复）
	_tween.tween_property(target, "scale", max_scale, duration * 0.5)
	_tween.tween_property(target, "scale", min_scale, duration * 0.5)

	var loop_desc = FuseLocalization.translate("FUSE_INSTRUCTION_TWEEN_PULSE_ANIMATION_INFINITE_LOG") if loop_count == 0 else FuseLocalization.translate_format("FUSE_INSTRUCTION_TWEEN_PULSE_ANIMATION_LOOP_LOG", {"count": loop_count})
	_log_info_localized("FUSE_LOG_TWEEN_PULSE_ANIMATION", {
		"node": target.name,
		"min_scale": str(min_scale),
		"max_scale": str(max_scale),
		"loops": loop_desc
	})

	# 如果是无限循环，不等待完成
	if loop_count == 0:
		_log_warning_localized("FUSE_WARNING_TWEEN_PULSE_INFINITE_LOOP", {})
		# 无限循环不等待完成
		return

	# 有限循环，等待完成
	await _tween.finished
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


	if duration <= 0:
		errors.append(FuseLocalization.translate("FUSE_ERROR_DURATION_MUST_BE_POSITIVE"))

	if loop_count < 0:
		errors.append(FuseLocalization.translate("FUSE_ERROR_LOOP_COUNT_NEGATIVE"))

	# 验证缩放值
	if min_scale.x < 0 or min_scale.y < 0:
		errors.append(FuseLocalization.translate("FUSE_ERROR_MIN_SCALE_NEGATIVE"))

	if max_scale.x < 0 or max_scale.y < 0:
		errors.append(FuseLocalization.translate("FUSE_ERROR_MAX_SCALE_NEGATIVE"))

	return errors

## 停止脉冲动画（用于停止无限循环）
func cancel():
	if is_running():
		# 停止 tween
		if _tween != null and is_instance_valid(_tween):
			_tween.kill()
			_tween = null
		super.cancel()

## 资源清理
func _cleanup_resources():
	super._cleanup_resources()
	if _tween != null and is_instance_valid(_tween):
		_tween.kill()
		_tween = null

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
	state["is_infinite"] = false  # 是否无限循环
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

	# 验证节点有 scale 属性
	if not "scale" in target:
		_log_error_localized("FUSE_ERROR_NODE_TYPE_INVALID", {"node": target.name, "expected": "Node2D or Control"})
		set_error_localized("FUSE_ERROR_NODE_TYPE_INVALID", FuseError.ErrorType.VALIDATION_ERROR, {"node": target.name, "expected": "Node2D or Control"})
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

	state["tween"] = tween
	state["is_running"] = true
	state["is_infinite"] = (loop_count == 0)

	# 设置循环次数
	if loop_count > 0:
		tween.set_loops(loop_count)
	else:
		tween.set_loops()  # 无限循环

	# 设置并行动画（使用 set_parallel 实现往复效果）
	tween.set_parallel(true)

	# 播放脉冲动画（放大 + 缩小往复）
	tween.tween_property(target, "scale", max_scale, duration * 0.5)
	tween.tween_property(target, "scale", min_scale, duration * 0.5)

	var loop_desc = FuseLocalization.translate("FUSE_INSTRUCTION_TWEEN_PULSE_ANIMATION_INFINITE_LOG") if loop_count == 0 else FuseLocalization.translate_format("FUSE_INSTRUCTION_TWEEN_PULSE_ANIMATION_LOOP_LOG", {"count": loop_count})
	_log_info_localized("FUSE_LOG_TWEEN_PULSE_ANIMATION", {
		"node": target.name,
		"min_scale": str(min_scale),
		"max_scale": str(max_scale),
		"loops": loop_desc
	})

	# 如果是无限循环，不等待完成
	if loop_count == 0:
		_log_warning_localized("FUSE_WARNING_TWEEN_PULSE_INFINITE_LOOP", {})
		# 无限循环不等待完成，立即返回
		runtime_instance._complete_execution()
		return true

	# 有限循环，等待完成
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

## 取消运行时实例执行
func on_runtime_cancel(runtime_instance: RuntimeInstructionInstance) -> void:
	var state = runtime_instance.runtime_state
	var tween = state.get("tween")

	if tween and is_instance_valid(tween):
		tween.kill()
		state["tween"] = null
		state["is_running"] = false
		state["tween_callback"] = null

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

