@tool
@icon("res://addons/fuse/icons/builtin/Tree.png")
extends BaseInstruction
class_name GetScenePath

## 获取当前场景的路径或根节点路径，保存到变量
##
## 重构变量系统: 2026-02-09 - 使用 VariableOperations 统一变量访问

# 路径模式枚举
enum PathMode {
	CURRENT_SCENE,  # 当前场景文件路径
	ROOT_NODE       # 根节点路径
}

# 路径模式
var path_mode: PathMode = PathMode.CURRENT_SCENE

# 保存到的变量名
var save_to_variable: String = ""

## 作用域来源
enum ScopeSource {
	NEAREST,        ## 最近的作用域容器（默认）
	CUSTOM_ID,      ## 指定 scope_id
	TRIGGER_SCOPE,  ## Trigger 节点上的作用域
	TARGET_NODE     ## Target 节点上的作用域
}

## 保存到作用域
var save_to_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		if save_to_scope != value:
			save_to_scope = value
			_update_resource_name()
			notify_property_list_changed()

## 作用域来源（仅当 save_to_scope == SCOPE 时使用）
var scope_source: ScopeSource = ScopeSource.NEAREST:
	set(value):
		if scope_source != value:
			scope_source = value
			_update_resource_name()
			notify_property_list_changed()

## 自定义作用域 ID（CUSTOM_ID 模式使用）
var custom_scope_id: String = ""

## 目标节点路径（TARGET_NODE 模式使用）
var target_node_path: NodePath = NodePath("")

## 获取指令元数据（用于指令选择器）
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_GET_SCENE_PATH_NAME"
	metadata.category_key = "FUSE_CATEGORY_SCENE"
	metadata.description_key = "FUSE_INSTRUCTION_GET_SCENE_PATH_DESC"
	metadata.keywords = ["scene", "path", "get", "场景", "路径"]
	metadata.builtin_icon = "Tree"
	return metadata

## 设置指令元数据
func _setup_metadata():
	pass

## 声明变量读写模式（save_to=write）
func get_variable_modes() -> Array[Dictionary]:
	return [{"name": "save_to_variable", "mode": "write"}]

## 获取属性列表
func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	# Path Mode 分类
	properties.append({
		name = "Path Mode",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	# 路径模式
	properties.append({
		name = "path_mode",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Current Scene File Path,Root Node Path",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# Variable 分类
	properties.append({
		name = "Variable",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	# 保存到的变量名
	properties.append({
		name = "save_to_variable",
		type = TYPE_STRING,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	properties.append({
		name = "save_to_scope",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Local,Scope,Global",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 只在 save_to_scope == SCOPE 时显示 ScopeSource 配置
	if save_to_scope == BaseVariable.VariableScope.SCOPE:
		properties.append({
			name = "scope_source",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "Nearest,Custom ID,Trigger Scope,Target Node",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		# 根据作用域来源添加额外属性
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
	var parts = []

	parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_GET_SCENE_PATH_BASE"))

	parts.append("[%s]" % _get_path_mode_string())

	if not save_to_variable.is_empty():
		var scope_str = _get_scope_source_string()
		parts.append(FuseLocalization.translate_format("FUSE_INSTRUCTION_GET_SCENE_PATH_TO_VARIABLE_FORMAT", {"scope": scope_str, "name": save_to_variable}))
	else:
		parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_GET_SCENE_PATH_NO_VARIABLE"))

	resource_name = " ".join(parts)

## 获取作用域来源字符串
func _get_scope_source_string() -> String:
	# 根据 save_to_scope 返回不同的作用域字符串
	match save_to_scope:
		BaseVariable.VariableScope.LOCAL:
			return FuseLocalization.translate("FUSE_VARIABLE_SCOPE_LOCAL_STR")
		BaseVariable.VariableScope.GLOBAL:
			return FuseLocalization.translate("FUSE_VARIABLE_SCOPE_GLOBAL_STR")
		BaseVariable.VariableScope.SCOPE:
			# SCOPE 作用域时，使用 ScopeSource 获取具体域信息
			return VariableScopeUtils.get_scope_source_string(
				scope_source as VariableScopeUtils.ScopeSource,
				custom_scope_id,
				target_node_path
			)
		_:
			return FuseLocalization.translate("FUSE_VARIABLE_SCOPE_UNKNOWN")

## 执行指令
func execute(context: ExecutionContext):
	_start_execution(context)

	# 验证变量名
	if save_to_variable.is_empty():
		_log_error_localized("FUSE_ERROR_VAR_NAME_EMPTY", {})
		set_error_localized("FUSE_ERROR_VAR_NAME_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
		finished.emit()
		return

	# 获取 SceneTree
	var scene_tree = Engine.get_main_loop()
	if not scene_tree:
		_log_error_localized("FUSE_ERROR_CANNOT_GET_SCENETREE", {})
		set_error_localized("FUSE_ERROR_CANNOT_GET_SCENETREE", FuseError.ErrorType.RUNTIME_ERROR, {})
		finished.emit()
		return

	if not scene_tree.current_scene:
		_log_error_localized("FUSE_ERROR_CANNOT_GET_CURRENT_SCENE", {})
		set_error_localized("FUSE_ERROR_CANNOT_GET_CURRENT_SCENE", FuseError.ErrorType.RUNTIME_ERROR, {})
		finished.emit()
		return

	# 根据模式获取路径
	var path_value: String

	match path_mode:
		PathMode.CURRENT_SCENE:
			path_value = scene_tree.current_scene.scene_file_path
			if path_value.is_empty():
				_log_warning_localized("FUSE_WARNING_SCENE_NO_FILE_PATH", {})
		PathMode.ROOT_NODE:
			path_value = scene_tree.current_scene.get_path()
		_:
			_log_error_localized("FUSE_ERROR_INVALID_PATH_MODE", {"mode": path_mode})
			set_error_localized("FUSE_ERROR_INVALID_PATH_MODE", FuseError.ErrorType.RUNTIME_ERROR, {"mode": path_mode})
			finished.emit()
			return

	# 保存到变量
	match save_to_scope:
		BaseVariable.VariableScope.LOCAL:
			# 保存到 LOCAL 变量
			var success = VariableOperations.set_variable(context, save_to_variable, BaseVariable.VariableScope.LOCAL, path_value)
			if not success:
				_log_error_localized("FUSE_ERROR_SET_LOCAL_VARIABLE_FAILED", {"name": save_to_variable})
				set_error_localized("FUSE_ERROR_SET_LOCAL_VARIABLE_FAILED", FuseError.ErrorType.RUNTIME_ERROR, {"name": save_to_variable})
				finished.emit()
				return

		BaseVariable.VariableScope.SCOPE:
			# 保存到 SCOPE 变量
			if scope_source == ScopeSource.NEAREST:
				# NEAREST 模式：使用 VariableOperations 的默认行为
				VariableOperations.set_variable(context, save_to_variable, BaseVariable.VariableScope.SCOPE, path_value)
			else:
				# 其他模式：获取指定作用域容器并设置变量
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

				# 设置作用域变量
				var success = scope_container.set_variable(save_to_variable, path_value)
				if not success:
					_log_error_localized("FUSE_ERROR_SET_SCOPE_VARIABLE_FAILED", {"name": save_to_variable})
					set_error_localized("FUSE_ERROR_SET_SCOPE_VARIABLE_FAILED", FuseError.ErrorType.RUNTIME_ERROR, {"name": save_to_variable})
					finished.emit()
					return

		BaseVariable.VariableScope.GLOBAL:
			# 保存到 GLOBAL 变量
			var success = VariableOperations.set_variable(context, save_to_variable, BaseVariable.VariableScope.GLOBAL, path_value)
			if not success:
				_log_error_localized("FUSE_ERROR_SET_GLOBAL_VARIABLE_FAILED", {"name": save_to_variable})
				set_error_localized("FUSE_ERROR_SET_GLOBAL_VARIABLE_FAILED", FuseError.ErrorType.RUNTIME_ERROR, {"name": save_to_variable})
				finished.emit()
				return

	# 记录成功信息
	var scope_str = _get_scope_source_string()
	_log_info_localized("FUSE_LOG_SAVED_PATH_TO_VARIABLE", {"name": save_to_variable, "path": path_value, "scope": scope_str})

	_on_execution_completed()

## 验证指令参数
func validate() -> Array[String]:
	var errors = super.validate()

	if save_to_variable.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_VAR_NAME_EMPTY"))

	# 只在 SCOPE 作用域时验证 ScopeSource 相关参数
	if save_to_scope == BaseVariable.VariableScope.SCOPE:
		var utils_scope_source = scope_source as VariableScopeUtils.ScopeSource
		errors.append_array(VariableScopeUtils.validate_scope_source_params(
			utils_scope_source,
			custom_scope_id,
			target_node_path
		))

	return errors

## 验证属性可见性
func _validate_property(property: Dictionary) -> void:
	# 只在 SCOPE 作用域时验证 ScopeSource 相关属性
	if save_to_scope == BaseVariable.VariableScope.SCOPE:
		VariableScopeUtils.validate_scope_source_property(property, scope_source as VariableScopeUtils.ScopeSource)
	else:
		# 非 SCOPE 作用域时隐藏 ScopeSource 相关属性
		if property.name in ["scope_source", "custom_scope_id", "target_node_path"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR

## 获取路径模式的本地化字符串
func _get_path_mode_string() -> String:
	match path_mode:
		PathMode.CURRENT_SCENE:
			return FuseLocalization.translate("FUSE_INSTRUCTION_GET_SCENE_PATH_MODE_CURRENT")
		PathMode.ROOT_NODE:
			return FuseLocalization.translate("FUSE_INSTRUCTION_GET_SCENE_PATH_MODE_ROOT")
		_:
			return FuseLocalization.translate("FUSE_INSTRUCTION_GET_SCENE_PATH_MODE_UNKNOWN")

## 动态属性设置
func _set(property: StringName, value: Variant) -> bool:
	if property == "path_mode" or property == "save_to_variable" or property == "scope_source" or property == "custom_scope_id" or property == "target_node_path":
		set(property, value)
		_update_resource_name()
		return true
	return false

## 获取指令描述
func get_description() -> String:
	var mode_str = _get_path_mode_string()
	var scope_str = _get_scope_source_string()
	var var_name = save_to_variable if not save_to_variable.is_empty() else FuseLocalization.translate("FUSE_INSTRUCTION_GET_SCENE_PATH_NO_VARIABLE")
	return FuseLocalization.translate_format("FUSE_INSTRUCTION_GET_SCENE_PATH_DESC_FORMAT", {"mode": mode_str, "scope": scope_str, "name": var_name})
