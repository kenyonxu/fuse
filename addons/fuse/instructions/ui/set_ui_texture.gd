@tool
@icon("res://addons/fuse/icons/builtin/Image.png")
extends BaseInstruction
class_name SetUITexture


## 作用域来源枚举
enum ScopeSource {
	NEAREST,        ## 最近的作用域容器（默认）
	CUSTOM_ID,      ## 指定 scope_id
	TRIGGER_SCOPE,  ## Trigger 节点上的作用域
	TARGET_NODE     ## Target 节点上的作用域
}

## 设置 TextureRect 的纹理资源
##
## 重构变量系统: 2026-02-09 - 使用 VariableOperations 统一变量访问
## 修复变量作用域: 2026-02-10 - 添加 ScopeSource 支持

# 目标 UI 节点路径
var target_node: NodePath = NodePath("")

## 是否从变量获取UI 节点
var use_variable_for_target: bool = false:
	set(value):
		use_variable_for_target = value
		_update_resource_name()
		notify_property_list_changed()

## UI 节点变量名
var target_variable: String = "":
	set(value):
		target_variable = value
		_update_resource_name()

## UI 节点变量作用域
var target_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		target_scope = value
		_update_resource_name()
		notify_property_list_changed()

## UI 节点作用域来源（仅当 target_scope == SCOPE 时使用）
var target_scope_source: ScopeSource = ScopeSource.NEAREST:
	set(value):
		target_scope_source = value
		_update_resource_name()
		notify_property_list_changed()

## UI 节点自定义作用域 ID（CUSTOM_ID 模式使用）
var target_custom_scope_id: String = "":
	set(value):
		target_custom_scope_id = value
		_update_resource_name()

## UI 节点目标节点路径（TARGET_NODE 模式使用）
var target_target_node_path: NodePath = NodePath(""):
	set(value):
		target_target_node_path = value
		_update_resource_name()

# 纹理来源
enum TextureSource {
	RESOURCE_PATH,
	VARIABLE
}
var texture_source: TextureSource = TextureSource.RESOURCE_PATH

# 纹理资源路径
var texture_path: String = ""

# 纹理变量名
var texture_variable: String = ""

# 纹理变量作用域
var texture_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		texture_scope = value
		_update_resource_name()
		notify_property_list_changed()

## 作用域来源（仅当 texture_scope == SCOPE 时使用）
var scope_source: ScopeSource = ScopeSource.NEAREST:
	set(value):
		scope_source = value
		_update_resource_name()
		notify_property_list_changed()

## 自定义作用域 ID（CUSTOM_ID 模式使用）
var custom_scope_id: String = "":
	set(value):
		custom_scope_id = value
		_update_resource_name()

## 目标节点路径（TARGET_NODE 模式使用）
var target_node_path: NodePath = NodePath(""):
	set(value):
		target_node_path = value
		_update_resource_name()

## 获取指令元数据
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_SET_UI_TEXTURE_NAME"
	metadata.category_key = "FUSE_CATEGORY_UI"
	metadata.description_key = "FUSE_INSTRUCTION_SET_UI_TEXTURE_DESC"
	metadata.keywords = ["ui", "texture", "image", "TextureRect", "UI", "纹理", "图片"]
	metadata.builtin_icon = "Image"
	return metadata

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
	properties.append({
		name = "UI",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})


	# 是否从变量获取UI 节点
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
			hint_string = "Control",
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

	properties.append({
		name = "Texture",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "texture_source",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Resource Path,Variable",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	if texture_source == TextureSource.RESOURCE_PATH:
		properties.append({
			name = "texture_path",
			type = TYPE_STRING,
			hint = PROPERTY_HINT_FILE,
			hint_string = "*.png,*.jpg,*.jpeg,*.webp,*.tres,*.res",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})
	else:
		properties.append({
			name = "texture_variable",
			type = TYPE_STRING,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		properties.append({
			name = "texture_scope",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "Local,Scope,Global",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		# 只在 texture_scope == SCOPE 时显示 ScopeSource 配置
		if texture_scope == BaseVariable.VariableScope.SCOPE:
			properties.append({
				name = "scope_source",
				type = TYPE_INT,
				hint = PROPERTY_HINT_ENUM,
				hint_string = "Nearest,Custom ID,Trigger Scope,Target Node",
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})

			if scope_source == ScopeSource.CUSTOM_ID:
				properties.append({
					name = "custom_scope_id",
					type = TYPE_STRING,
					hint = PROPERTY_HINT_NONE,
					usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
				})
			elif scope_source == ScopeSource.TARGET_NODE:
				properties.append({
					name = "target_node_path",
					type = TYPE_NODE_PATH,
					hint = PROPERTY_HINT_NONE,
					usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
				})

	return properties

## 更新资源名称
func _update_resource_name():
	var parts := []

	parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_SET_UI_TEXTURE_RESOURCE"))

	var target_str := ""
	if use_variable_for_target:
		if target_variable.is_empty():
			target_str = FuseLocalization.translate("FUSE_UI_NODE_NOT_SELECTED")
		else:
			var target_scope_str := VariableScopeUtils.enum_to_string(target_scope).to_upper()
			if target_scope == BaseVariable.VariableScope.SCOPE:
				var target_utils_scope_source = target_scope_source as VariableScopeUtils.ScopeSource
				target_scope_str = VariableScopeUtils.get_scope_source_string(target_utils_scope_source, target_custom_scope_id, target_target_node_path)
			target_str = "%s [%s]" % [target_variable, target_scope_str]
	else:
		target_str = _get_node_display_name(target_node) if not target_node.is_empty() else FuseLocalization.translate("FUSE_UI_NODE_NOT_SELECTED")
	parts.append("→ %s" % target_str)

	var source_str = ""
	if texture_source == TextureSource.RESOURCE_PATH:
		if texture_path.is_empty():
			source_str = FuseLocalization.translate("FUSE_TEXTURE_FILE_NOT_SELECTED")
		else:
			source_str = FuseNodeUtils.get_path_display_name(texture_path)
	else:
		var scope_str = ""
		match texture_scope:
			BaseVariable.VariableScope.LOCAL:
				scope_str = FuseLocalization.translate("FUSE_VARIABLE_SCOPE_LOCAL_STR")
			BaseVariable.VariableScope.GLOBAL:
				scope_str = FuseLocalization.translate("FUSE_VARIABLE_SCOPE_GLOBAL_STR")
			BaseVariable.VariableScope.SCOPE:
				# SCOPE 作用域时，使用 ScopeSource 获取具体域信息
				scope_str = VariableScopeUtils.get_scope_source_string(
					scope_source as VariableScopeUtils.ScopeSource,
					custom_scope_id,
					target_node_path
				)
		var var_name = texture_variable if not texture_variable.is_empty() else FuseLocalization.translate("FUSE_VALUE_VARIABLE_EMPTY")
		source_str = "%s [%s]" % [var_name, scope_str]
	parts.append("(%s)" % source_str)

	resource_name = " ".join(parts)

## 执行指令
func execute(context: ExecutionContext):
	_start_execution(context)

	# 获取目标节点
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

	# 验证节点类型
	if not node is TextureRect:
		_log_error_localized("FUSE_ERROR_UI_NODE_NOT_TEXTURERECT", {})
		set_error_localized("FUSE_ERROR_UI_NODE_NOT_TEXTURERECT", FuseError.ErrorType.RUNTIME_ERROR, {})
		finished.emit()
		return

	var texture_rect := node as TextureRect

	# 获取纹理资源
	var texture: Texture2D = null
	if texture_source == TextureSource.RESOURCE_PATH:
		if texture_path.is_empty():
			_log_error_localized("FUSE_ERROR_TEXTURE_NOT_FOUND", {})
			set_error_localized("FUSE_ERROR_TEXTURE_NOT_FOUND", FuseError.ErrorType.VALIDATION_ERROR, {})
			finished.emit()
			return

		# 加载纹理资源
		texture = load(texture_path) as Texture2D
		if not texture:
			_log_error_localized("FUSE_ERROR_TEXTURE_NOT_FOUND", {})
			set_error_localized("FUSE_ERROR_TEXTURE_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {})
			finished.emit()
			return
	else:
		if texture_variable.is_empty():
			_log_error_localized("FUSE_ERROR_VAR_NAME_EMPTY", {})
			set_error_localized("FUSE_ERROR_VAR_NAME_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
			finished.emit()
			return

		# 从变量读取纹理
		texture = null
		match texture_scope:
			BaseVariable.VariableScope.LOCAL:
				texture = VariableOperations.get_variable(context, texture_variable, BaseVariable.VariableScope.LOCAL, null) as Texture2D

			BaseVariable.VariableScope.SCOPE:
				if scope_source == ScopeSource.NEAREST:
					texture = VariableOperations.get_variable(context, texture_variable, BaseVariable.VariableScope.SCOPE, null) as Texture2D
				else:
					var utils_scope_source = scope_source as VariableScopeUtils.ScopeSource
					var scope_container = VariableScopeUtils.get_scope_container_by_source(
						context,
						utils_scope_source,
						custom_scope_id,
						target_node_path
					)

					if scope_container == null:
						_log_error_localized("FUSE_ERROR_SCOPE_CONTAINER_NOT_FOUND", {})
						set_error_localized("FUSE_ERROR_SCOPE_CONTAINER_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {})
						finished.emit()
						return

					texture = scope_container.get_variable(texture_variable, null) as Texture2D

			BaseVariable.VariableScope.GLOBAL:
				texture = VariableOperations.get_variable(context, texture_variable, BaseVariable.VariableScope.GLOBAL, null) as Texture2D

		# 检查变量是否存在
		if texture == null and not VariableOperations.has_variable(context, texture_variable, texture_scope):
			_log_error_localized("FUSE_ERROR_TEXTURE_NOT_FOUND", {})
			set_error_localized("FUSE_ERROR_TEXTURE_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {})
			finished.emit()
			return

	# 设置纹理
	texture_rect.texture = texture
	_log_info_localized("FUSE_LOG_SET_UI_TEXTURE", {"node": texture_rect.name, "texture": texture.resource_path if texture.resource_path else FuseLocalization.translate("FUSE_TEXTURE")})
	_on_execution_completed()

## 验证属性可见性
func _validate_property(property: Dictionary) -> void:
	# 只在使用变量且 SCOPE 作用域时验证 ScopeSource 相关属性
	if texture_source == TextureSource.VARIABLE:
		if texture_scope == BaseVariable.VariableScope.SCOPE:
			VariableScopeUtils.validate_scope_source_property(property, scope_source as VariableScopeUtils.ScopeSource)
		else:
			# 非 SCOPE 作用域时隐藏 ScopeSource 相关属性
			if property.name in ["scope_source", "custom_scope_id", "target_node_path"]:
				property.usage = PROPERTY_USAGE_NO_EDITOR
	else:
		# 不使用变量时，隐藏所有作用域相关属性
		if property.name in ["texture_scope", "scope_source", "custom_scope_id", "target_node_path"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR
	# 控制UI 节点相关属性可见性
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

## 验证指令参数
func validate() -> Array[String]:
	var errors = super.validate()
	# 验证 UI 节点
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


	if texture_source == TextureSource.RESOURCE_PATH:
		if texture_path.is_empty():
			errors.append(FuseLocalization.translate("FUSE_ERROR_TEXTURE_PATH_EMPTY"))
	else:
		if texture_variable.is_empty():
			errors.append(FuseLocalization.translate("FUSE_ERROR_TEXTURE_VAR_NAME_EMPTY"))

		# 验证 SCOPE 作用域需要 ScopeVariableManager
		if texture_scope == BaseVariable.VariableScope.SCOPE:
			var manager = ScopeVariableManager.get_instance()
			if manager == null:
				errors.append(FuseLocalization.translate("FUSE_ERROR_SCOPE_MANAGER_NOT_FOUND"))

			# 验证 ScopeSource 参数
			var utils_scope_source = scope_source as VariableScopeUtils.ScopeSource
			errors.append_array(VariableScopeUtils.validate_scope_source_params(
				utils_scope_source,
				custom_scope_id,
				target_node_path
			))

	return errors

## 获取指令描述
func get_description() -> String:
	var source_str = ""
	if texture_source == TextureSource.RESOURCE_PATH:
		source_str = texture_path if not texture_path.is_empty() else "(%s)" % FuseLocalization.translate("FUSE_TEXTURE_FILE_NOT_SELECTED")
	else:
		var scope_str = ""
		match texture_scope:
			BaseVariable.VariableScope.LOCAL:
				scope_str = FuseLocalization.translate("FUSE_VARIABLE_SCOPE_LOCAL_STR")
			BaseVariable.VariableScope.GLOBAL:
				scope_str = FuseLocalization.translate("FUSE_VARIABLE_SCOPE_GLOBAL_STR")
			BaseVariable.VariableScope.SCOPE:
				# SCOPE 作用域时，使用 ScopeSource 获取具体域信息
				scope_str = VariableScopeUtils.get_scope_source_string(
					scope_source as VariableScopeUtils.ScopeSource,
					custom_scope_id,
					target_node_path
				)
		var var_name = texture_variable if not texture_variable.is_empty() else FuseLocalization.translate("FUSE_VALUE_VARIABLE_EMPTY")
		source_str = "%s [%s]" % [var_name, scope_str]
	var node_str := ""
	if use_variable_for_target:
		if target_variable.is_empty():
			node_str = "(%s)" % FuseLocalization.translate("FUSE_UI_NODE_NOT_SELECTED")
		else:
			var target_scope_str := VariableScopeUtils.enum_to_string(target_scope).to_upper()
			if target_scope == BaseVariable.VariableScope.SCOPE:
				var target_utils_scope_source = target_scope_source as VariableScopeUtils.ScopeSource
				target_scope_str = VariableScopeUtils.get_scope_source_string(target_utils_scope_source, target_custom_scope_id, target_target_node_path)
			node_str = "%s [%s]" % [target_variable, target_scope_str]
	else:
		node_str = _get_node_display_name(target_node) if not target_node.is_empty() else "(%s)" % FuseLocalization.translate("FUSE_UI_NODE_NOT_SELECTED")
	return FuseLocalization.translate_format("FUSE_INSTRUCTION_SET_UI_TEXTURE_DESC_FORMAT", {"node": node_str, "value": source_str})

## 动态属性设置
func _set(property: StringName, value: Variant) -> bool:
	if property in ["use_variable_for_target", "target_scope", "target_scope_source"]:
		set(property, value)
		notify_property_list_changed()
		return true
	if property == "texture_source":
		set(property, value)
		notify_property_list_changed()
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
			_log_error_localized("FUSE_ERROR_VAR_NOT_FOUND", {"name": variable_name})
			set_error_localized("FUSE_ERROR_VAR_NOT_FOUND", FuseError.ErrorType.VALIDATION_ERROR, {"name": variable_name})
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

