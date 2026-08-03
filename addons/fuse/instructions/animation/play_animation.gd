@tool
@icon("res://addons/fuse/icons/builtin/AnimationPlayer.png")
extends BaseInstruction
class_name PlayAnimation


## 作用域来源枚举
enum ScopeSource {
	NEAREST,        ## 最近的作用域容器（默认）
	CUSTOM_ID,      ## 指定 scope_id
	TRIGGER_SCOPE,  ## Trigger 节点上的作用域
	TARGET_NODE     ## Target 节点上的作用域
}

## 播放 AnimationPlayer 中的指定动画

# 目标 AnimationPlayer 节点路径
var target_player: NodePath = NodePath("")

## 是否从变量获取AnimationPlayer
var use_variable_for_target: bool = false:
	set(value):
		use_variable_for_target = value
		_update_resource_name()
		notify_property_list_changed()

## AnimationPlayer变量名
var target_variable: String = "":
	set(value):
		target_variable = value
		_update_resource_name()

## AnimationPlayer变量作用域
var target_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		target_scope = value
		_update_resource_name()
		notify_property_list_changed()

## AnimationPlayer作用域来源（仅当 target_scope == SCOPE 时使用）
var target_scope_source: ScopeSource = ScopeSource.NEAREST:
	set(value):
		target_scope_source = value
		_update_resource_name()
		notify_property_list_changed()

## AnimationPlayer自定义作用域 ID（CUSTOM_ID 模式使用）
var target_custom_scope_id: String = "":
	set(value):
		target_custom_scope_id = value
		_update_resource_name()

## AnimationPlayer目标节点路径（TARGET_NODE 模式使用）
var target_target_node_path: NodePath = NodePath(""):
	set(value):
		target_target_node_path = value
		_update_resource_name()

# 动画名称
var animation_name: String = ""

# 播放速度
var speed: float = 1.0

# 是否从结尾开始反向播放
var from_end: bool = false

# 是否仅自动播放
var autoplay_only: bool = false

## 获取指令元数据（用于指令选择器）
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_PLAY_ANIMATION_NAME"
	metadata.category_key = "FUSE_CATEGORY_ANIMATION"
	metadata.description_key = "FUSE_INSTRUCTION_PLAY_ANIMATION_DESC"
	metadata.keywords = ["animation", "play", "animate", "播放", "动画"]
	metadata.builtin_icon = "AnimationPlayer"
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
	# Animation 分类
	properties.append({
		name = "Animation",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	# 目标 AnimationPlayer

	# 是否从变量获取AnimationPlayer
	properties.append({
		name = "use_variable_for_target",
		type = TYPE_BOOL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	if not use_variable_for_target:
		# 直接指定节点路径
		properties.append({
			name = "target_player",
			type = TYPE_NODE_PATH,
			hint = PROPERTY_HINT_NODE_PATH_VALID_TYPES,
			hint_string = "AnimationPlayer",
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

	# 动画名称
	properties.append({
		name = "animation_name",
		type = TYPE_STRING,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# Playback 分类
	properties.append({
		name = "Playback",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	# 播放速度
	properties.append({
		name = "speed",
		type = TYPE_FLOAT,
		hint = PROPERTY_HINT_RANGE,
		hint_string = "0.01,10,0.01,or_greater",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 是否从结尾开始反向播放
	properties.append({
		name = "from_end",
		type = TYPE_BOOL,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 是否仅自动播放
	properties.append({
		name = "autoplay_only",
		type = TYPE_BOOL,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	return properties

## 更新资源名称
func _update_resource_name():
	var parts = []

	parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_PLAY_ANIMATION_SHORT"))

	if not target_player.is_empty():
		parts.append("'%s'" % target_player)
	else:
		parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_PLAY_ANIMATION_NO_PLAYER"))

	if not animation_name.is_empty():
		parts.append("'%s'" % animation_name)
	else:
		parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_PLAY_ANIMATION_NO_ANIMATION"))

	if speed != 1.0:
		parts.append(FuseLocalization.translate_format("FUSE_INSTRUCTION_PLAY_ANIMATION_WITH_SPEED", {"speed": speed}))

	if from_end:
		parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_PLAY_ANIMATION_FROM_END"))

	if autoplay_only:
		parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_PLAY_ANIMATION_AUTOPLAY_ONLY"))

	resource_name = " ".join(parts)

## 执行指令
func execute(context: ExecutionContext):
	_start_execution(context)

	# 验证目标节点

	# 获取 AnimationPlayer 节点
	var node := _resolve_node(
		context,
		use_variable_for_target,
		target_player,
		target_variable,
		target_scope,
		target_scope_source,
		target_custom_scope_id,
		target_target_node_path,
		"FUSE_ERROR_TARGET_VARIABLE_EMPTY",
		"FUSE_ERROR_TARGET_NODE_EMPTY",
		"FUSE_ERROR_TARGET_NODE_NOT_FOUND"
	)
	if not node:
		finished.emit()
		return

	# 验证节点类型
	if not node is AnimationPlayer:
		var type_str = node.get_class()
		_log_error_localized("FUSE_ERROR_NODE_TYPE_INVALID", {"node": node.name, "actual_type": type_str})
		set_error_localized("FUSE_ERROR_NODE_TYPE_INVALID", FuseError.ErrorType.RUNTIME_ERROR, {"node": node.name, "actual_type": type_str})
		finished.emit()
		return

	var animation_player := node as AnimationPlayer

	# 验证动画名称
	if animation_name.is_empty():
		_log_error_localized("FUSE_ERROR_ANIMATION_NAME_EMPTY", {})
		set_error_localized("FUSE_ERROR_ANIMATION_NAME_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
		finished.emit()
		return

	# 验证动画是否存在
	if not animation_player.has_animation(animation_name):
		_log_error_localized("FUSE_ERROR_ANIMATION_NOT_FOUND", {"animation": animation_name})
		set_error_localized("FUSE_ERROR_ANIMATION_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {"animation": animation_name})
		finished.emit()
		return

	# 验证速度值
	if speed <= 0.0:
		_log_error_localized("FUSE_ERROR_INVALID_SPEED", {})
		set_error_localized("FUSE_ERROR_INVALID_SPEED", FuseError.ErrorType.VALIDATION_ERROR, {})
		finished.emit()
		return

	# 播放动画
	if from_end:
		animation_player.play_backwards(animation_name, -1.0)
		_log_info("反向播放动画 '%s'，速度 %.2fx" % [animation_name, speed])
	else:
		animation_player.play(animation_name, -1.0, speed)
		_log_info("播放动画 '%s'，速度 %.2fx" % [animation_name, speed])

	# 应用速度缩放
	animation_player.speed_scale = speed

	_on_execution_completed()

## 验证指令参数
func validate() -> Array[String]:
	var errors = super.validate()
	# 验证 AnimationPlayer
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
		if target_player.is_empty():
			errors.append(FuseLocalization.translate("FUSE_ERROR_TARGET_NODE_EMPTY"))


	if animation_name.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_ANIMATION_NAME_EMPTY"))

	if speed <= 0.0:
		errors.append(FuseLocalization.translate("FUSE_ERROR_INVALID_SPEED"))

	return errors

## 属性验证
func _validate_property(property: Dictionary) -> void:
	# 控制AnimationPlayer相关属性可见性
	if not use_variable_for_target:
		if property.name in ["target_variable", "target_scope", "target_scope_source", "target_custom_scope_id", "target_target_node_path"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR
	else:
		if property.name == "target_player":
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
## 获取指令描述
func get_description() -> String:
	var options = []

	if speed != 1.0:
		options.append(FuseLocalization.translate_format("FUSE_INSTRUCTION_PLAY_ANIMATION_SPEED", {"speed": speed}))

	if from_end:
		options.append(FuseLocalization.translate("FUSE_INSTRUCTION_PLAY_ANIMATION_REVERSE"))

	if autoplay_only:
		options.append(FuseLocalization.translate("FUSE_INSTRUCTION_PLAY_ANIMATION_AUTOPLAY_ONLY_SHORT"))

	var options_str = ""
	if options.size() > 0:
		options_str = " (" + ", ".join(options) + ")"

	var anim_name = animation_name if not animation_name.is_empty() else FuseLocalization.translate("FUSE_INSTRUCTION_PLAY_ANIMATION_NO_ANIMATION")
	return FuseLocalization.translate_format("FUSE_INSTRUCTION_PLAY_ANIMATION_DESC_FORMAT", {"animation": anim_name, "options": options_str})

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

