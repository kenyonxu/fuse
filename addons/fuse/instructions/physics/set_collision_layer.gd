@tool
@icon("res://addons/fuse/icons/builtin/GuiMiniCheckerboard.png")
extends BaseInstruction
class_name SetCollisionLayer


## 作用域来源枚举
enum ScopeSource {
	NEAREST,        ## 最近的作用域容器（默认）
	CUSTOM_ID,      ## 指定 scope_id
	TRIGGER_SCOPE,  ## Trigger 节点上的作用域
	TARGET_NODE     ## Target 节点上的作用域
}

## 设置 CollisionObject 的碰撞层和/或掩码

# 目标碰撞对象节点路径
var target_node: NodePath = NodePath("")

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

# 是否使用 3D 节点
var use_3d: bool = false

# 设置类型枚举
enum SetType {
	LAYER = 0,  # 仅设置层
	MASK = 1,   # 仅设置掩码
	BOTH = 2    # 同时设置层和掩码
}

# 设置类型
var set_type: SetType = SetType.BOTH

# 碰撞层值（位掩码）
var layer_value: int = 1

# 碰撞掩码值（位掩码）
var mask_value: int = 1

## 获取指令元数据
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_SET_COLLISION_LAYER_NAME"
	metadata.category_key = "FUSE_CATEGORY_PHYSICS"
	metadata.description_key = "FUSE_INSTRUCTION_SET_COLLISION_LAYER_DESC"
	metadata.keywords = ["collision", "layer", "mask", "physics", "碰撞", "层", "掩码", "物理"]
	metadata.builtin_icon = "GuiMiniCheckerboard"
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
	# Target 分类
	properties.append({
		name = "Target",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	# 目标碰撞对象节点

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
			hint_string = "Area2D,Area3D,RigidBody2D,RigidBody3D,CharacterBody2D,CharacterBody3D",
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

	# 是否使用 3D
	properties.append({
		name = "use_3d",
		type = TYPE_BOOL,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# Settings 分类
	properties.append({
		name = "Settings",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	# 设置类型
	properties.append({
		name = "set_type",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Layer,Mask,Both",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# Layer Value 分类（根据设置类型显示）
	if set_type == SetType.LAYER or set_type == SetType.BOTH:
		properties.append({
			name = "Layer Value",
			type = TYPE_NIL,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_CATEGORY
		})

		properties.append({
			name = "layer_value",
			type = TYPE_INT,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

	# Mask Value 分类（根据设置类型显示）
	if set_type == SetType.MASK or set_type == SetType.BOTH:
		properties.append({
			name = "Mask Value",
			type = TYPE_NIL,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_CATEGORY
		})

		properties.append({
			name = "mask_value",
			type = TYPE_INT,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

	return properties

## 更新资源名称
func _update_resource_name():
	var target_str = _get_node_display_name(target_node) if not target_node.is_empty() else FuseLocalization.translate("FUSE_TEXT_UNSPECIFIED")

	if set_type == SetType.LAYER:
		resource_name = FuseLocalization.translate_format("FUSE_INSTRUCTION_SET_COLLISION_LAYER_RESOURCE", {
			"target": target_str,
			"value": layer_value
		})
	elif set_type == SetType.MASK:
		resource_name = FuseLocalization.translate_format("FUSE_INSTRUCTION_SET_COLLISION_MASK_RESOURCE", {
			"target": target_str,
			"value": mask_value
		})
	else:  # BOTH
		resource_name = FuseLocalization.translate_format("FUSE_INSTRUCTION_SET_COLLISION_BOTH_RESOURCE", {
			"target": target_str,
			"layer": layer_value,
			"mask": mask_value
		})

## 执行指令
func execute(context: ExecutionContext):
	_start_execution(context)

	# 验证目标节点

	# 获取碰撞对象节点
	var node := _resolve_node(
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
	if not node:
		finished.emit()
		return

	# 根据节点类型设置碰撞层/掩码
	var success := false
	var obj_type := ""

	if node is CollisionObject2D:
		var obj := node as CollisionObject2D

		if set_type == SetType.LAYER:
			obj.collision_layer = layer_value
			_log_info_localized("FUSE_LOG_SET_COLLISION_LAYER", {"value": layer_value})
		elif set_type == SetType.MASK:
			obj.collision_mask = mask_value
			_log_info_localized("FUSE_LOG_SET_COLLISION_MASK", {"value": mask_value})
		else:  # BOTH
			obj.collision_layer = layer_value
			obj.collision_mask = mask_value
			_log_info_localized("FUSE_LOG_SET_COLLISION_BOTH", {
				"layer": layer_value,
				"mask": mask_value
			})

		obj_type = "CollisionObject2D"
		success = true

	elif node is CollisionObject3D:
		var obj := node as CollisionObject3D

		if set_type == SetType.LAYER:
			obj.collision_layer = layer_value
			_log_info_localized("FUSE_LOG_SET_COLLISION_LAYER", {"value": layer_value})
		elif set_type == SetType.MASK:
			obj.collision_mask = mask_value
			_log_info_localized("FUSE_LOG_SET_COLLISION_MASK", {"value": mask_value})
		else:  # BOTH
			obj.collision_layer = layer_value
			obj.collision_mask = mask_value
			_log_info_localized("FUSE_LOG_SET_COLLISION_BOTH", {
				"layer": layer_value,
				"mask": mask_value
			})

		obj_type = "CollisionObject3D"
		success = true

	else:
		# 节点类型无效
		var type_str = node.get_class()
		_log_error_localized("FUSE_ERROR_NODE_TYPE_INVALID", {
			"node": node.name,
			"actual_type": type_str
		})
		set_error_localized("FUSE_ERROR_NODE_TYPE_INVALID", FuseError.ErrorType.RUNTIME_ERROR, {
			"node": node.name,
			"actual_type": type_str
		})
		finished.emit()
		return

	# 记录成功日志
	if success:
		_log_info_localized("FUSE_LOG_SET_COLLISION_SUCCESS", {
			"type": obj_type,
			"node": node.name
		})

	_on_execution_completed()

## 验证参数
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


	# 验证位掩码值在有效范围内（1-32位）
	if set_type == SetType.LAYER or set_type == SetType.BOTH:
		if layer_value < 0 or layer_value > 0xFFFFFFFF:
			errors.append(FuseLocalization.translate("FUSE_ERROR_COLLISION_LAYER_VALUE_OUT_OF_RANGE"))

	if set_type == SetType.MASK or set_type == SetType.BOTH:
		if mask_value < 0 or mask_value > 0xFFFFFFFF:
			errors.append(FuseLocalization.translate("FUSE_ERROR_COLLISION_MASK_VALUE_OUT_OF_RANGE"))

	return errors

## 获取描述
func get_description() -> String:
	var target_str = _get_node_display_name(target_node) if not target_node.is_empty() else FuseLocalization.translate("FUSE_TEXT_UNSPECIFIED")

	if set_type == SetType.LAYER:
		return FuseLocalization.translate_format("FUSE_INSTRUCTION_SET_COLLISION_LAYER_DESC", {
			"target": target_str,
			"value": layer_value
		})
	elif set_type == SetType.MASK:
		return FuseLocalization.translate_format("FUSE_INSTRUCTION_SET_COLLISION_MASK_DESC", {
			"target": target_str,
			"value": mask_value
		})
	else:  # BOTH
		return FuseLocalization.translate_format("FUSE_INSTRUCTION_SET_COLLISION_BOTH_DESC", {
			"target": target_str,
			"layer": layer_value,
			"mask": mask_value
		})

## 动态属性设置
func _set(property: StringName, value: Variant) -> bool:
	if property in ["use_variable_for_target", "target_scope", "target_scope_source"]:
		set(property, value)
		notify_property_list_changed()
		return true
	if property == "use_3d" or property == "set_type":
		set(property, value)
		notify_property_list_changed()
		_update_resource_name()
		return true
	if property == "layer_value" or property == "mask_value":
		set(property, value)
		_update_resource_name()
		return true
	return false

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

