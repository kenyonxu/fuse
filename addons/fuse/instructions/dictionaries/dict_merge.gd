@tool
@icon("res://addons/fuse/icons/builtin/Dictionary.svg")
extends BaseInstruction
class_name DictMerge

## DictMerge 指令
##
## 将源字典合并到目标字典。
## 如果键不存在则创建，存在则根据 overwrite_existing 选项决定是否覆盖。
## 如果目标字典不存在则报错。
##
## 使用 VariableOperations 统一变量访问 API

## 作用域来源枚举
enum ScopeSource {
	NEAREST,        ## 最近的作用域容器（默认）
	CUSTOM_ID,      ## 指定 scope_id
	TRIGGER_SCOPE,  ## Trigger 节点上的作用域
	TARGET_NODE     ## Target 节点上的作用域
}

# ========== 源字典配置 ==========

## 源字典变量名
var source_dict_variable: String = "":
	set(value):
		if source_dict_variable != value:
			source_dict_variable = value
			_update_resource_name()

## 源字典变量作用域
var source_dict_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		if source_dict_scope != value:
			source_dict_scope = value
			_update_resource_name()
			notify_property_list_changed()

## 源字典作用域来源（仅当 source_dict_scope == SCOPE 时使用）
var source_scope_source: ScopeSource = ScopeSource.NEAREST:
	set(value):
		if source_scope_source != value:
			source_scope_source = value
			_update_resource_name()
			notify_property_list_changed()

## 源字典自定义作用域 ID（CUSTOM_ID 模式使用）
var source_custom_scope_id: String = "":
	set(value):
		if source_custom_scope_id != value:
			source_custom_scope_id = value
			_update_resource_name()

## 源字典目标节点路径（TARGET_NODE 模式使用）
var source_target_node_path: NodePath = NodePath(""):
	set(value):
		if source_target_node_path != value:
			source_target_node_path = value
			_update_resource_name()

# ========== 目标字典配置 ==========

## 目标字典变量名
var target_dict_variable: String = "":
	set(value):
		if target_dict_variable != value:
			target_dict_variable = value
			_update_resource_name()

## 目标字典变量作用域
var target_dict_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		if target_dict_scope != value:
			target_dict_scope = value
			_update_resource_name()
			notify_property_list_changed()

## 目标字典作用域来源（仅当 target_dict_scope == SCOPE 时使用）
var target_scope_source: ScopeSource = ScopeSource.NEAREST:
	set(value):
		if target_scope_source != value:
			target_scope_source = value
			_update_resource_name()
			notify_property_list_changed()

## 目标字典自定义作用域 ID（CUSTOM_ID 模式使用）
var target_custom_scope_id: String = "":
	set(value):
		if target_custom_scope_id != value:
			target_custom_scope_id = value
			_update_resource_name()

## 目标字典目标节点路径（TARGET_NODE 模式使用）
var target_target_node_path: NodePath = NodePath(""):
	set(value):
		if target_target_node_path != value:
			target_target_node_path = value
			_update_resource_name()

# ========== 合并选项 ==========

## 是否覆盖已存在的键
@export var overwrite_existing: bool = true:
	set(value):
		overwrite_existing = value
		_update_resource_name()

## 获取指令元数据（用于指令选择器）
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_DICT_MERGE_NAME"
	metadata.category_key = "FUSE_CATEGORY_DICTIONARIES"
	metadata.description_key = "FUSE_INSTRUCTION_DICT_MERGE_DESC"
	metadata.keywords = ["字典", "合并", "合并", "dictionary", "merge", "合并"]
	metadata.builtin_icon = "Dictionary"
	return metadata

## 设置指令元数据
func _setup_metadata():
	pass

## 声明变量读写模式（source_dict=read, target_dict=write 合并结果）
func get_variable_modes() -> Array[Dictionary]:
	return [
		{"name": "source_dict_variable", "mode": "read"},
		{"name": "target_dict_variable", "mode": "write"},
	]

## 获取属性列表
func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	# ========== Source Dictionary 分类 ==========
	properties.append({
		name = "Source Dictionary",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "source_dict_variable",
		type = TYPE_STRING,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	properties.append({
		name = "source_dict_scope",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Local,Scope,Global",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 只在 source_dict_scope == SCOPE 时显示源字典 ScopeSource 配置
	if source_dict_scope == BaseVariable.VariableScope.SCOPE:
		properties.append({
			name = "Source Scope Configuration",
			type = TYPE_NIL,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_CATEGORY
		})

		properties.append({
			name = "source_scope_source",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "Nearest,Custom ID,Trigger Scope,Target Node",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		# 根据作用域来源添加额外属性
		if source_scope_source == ScopeSource.CUSTOM_ID:
			properties.append({
				name = "source_custom_scope_id",
				type = TYPE_STRING,
				hint = PROPERTY_HINT_NONE,
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})
		elif source_scope_source == ScopeSource.TARGET_NODE:
			properties.append({
				name = "source_target_node_path",
				type = TYPE_NODE_PATH,
				hint = PROPERTY_HINT_NONE,
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})

	# ========== Target Dictionary 分类 ==========
	properties.append({
		name = "Target Dictionary",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "target_dict_variable",
		type = TYPE_STRING,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	properties.append({
		name = "target_dict_scope",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Local,Scope,Global",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 只在 target_dict_scope == SCOPE 时显示目标字典 ScopeSource 配置
	if target_dict_scope == BaseVariable.VariableScope.SCOPE:
		properties.append({
			name = "Target Scope Configuration",
			type = TYPE_NIL,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_CATEGORY
		})

		properties.append({
			name = "target_scope_source",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "Nearest,Custom ID,Trigger Scope,Target Node",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		# 根据作用域来源添加额外属性
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

	# ========== Options 分类 ==========
	properties.append({
		name = "Options",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "overwrite_existing",
		type = TYPE_BOOL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	return properties

## 更新资源名称
func _update_resource_name():
	var source_str := ""
	var target_str := ""

	# 源字典信息
	if source_dict_variable.is_empty():
		source_str = FuseLocalization.translate("FUSE_INSTRUCTION_DICT_NO_DICT")
	else:
		source_str = FuseLocalization.translate_format("FUSE_INSTRUCTION_DICT_DICT", {"name": source_dict_variable})

	# 目标字典信息
	if target_dict_variable.is_empty():
		target_str = FuseLocalization.translate("FUSE_INSTRUCTION_DICT_NO_DICT")
	else:
		target_str = FuseLocalization.translate_format("FUSE_INSTRUCTION_DICT_DICT", {"name": target_dict_variable})

	var mode_str := "merge" if overwrite_existing else "merge+keep"
	resource_name = " ".join(["Dict", mode_str, source_str, "->", target_str])

## 执行指令
func execute(context: ExecutionContext):
	_start_execution(context)

	_log_debug_localized("FUSE_LOG_INSTRUCTION_START", {"instruction": "DictMerge"})

	# 验证源字典变量名
	if source_dict_variable.is_empty():
		_log_error_localized("FUSE_ERROR_DICT_VARIABLE_EMPTY", {})
		set_error_localized("FUSE_ERROR_DICT_VARIABLE_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
		finished.emit()
		return

	# 验证目标字典变量名
	if target_dict_variable.is_empty():
		_log_error_localized("FUSE_ERROR_DICT_VARIABLE_EMPTY", {})
		set_error_localized("FUSE_ERROR_DICT_VARIABLE_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
		finished.emit()
		return

	# 获取源字典
	var source_dict: Dictionary = _get_dict_variable(context, source_dict_variable, source_dict_scope, source_scope_source, source_custom_scope_id, source_target_node_path)
	if source_dict.is_empty():
		# 源字典为空或不存在，直接完成
		_log_debug("源字典为空或不存在，跳过合并")
		_on_execution_completed()
		return

	# 获取目标字典（必须存在）
	var target_dict: Variant = _get_dict_value(context, target_dict_variable, target_dict_scope, target_scope_source, target_custom_scope_id, target_target_node_path)
	if target_dict == null:
		_log_error_localized("FUSE_ERROR_DICT_NOT_FOUND", {"name": target_dict_variable})
		set_error_localized("FUSE_ERROR_DICT_NOT_FOUND", FuseError.ErrorType.EXECUTION_ERROR, {"name": target_dict_variable})
		finished.emit()
		return

	if not target_dict is Dictionary:
		_log_error_localized("FUSE_ERROR_DICT_NOT_DICTIONARY", {"name": target_dict_variable})
		set_error_localized("FUSE_ERROR_DICT_NOT_DICTIONARY", FuseError.ErrorType.EXECUTION_ERROR, {"name": target_dict_variable})
		finished.emit()
		return

	target_dict = target_dict as Dictionary

	# 调试输出
	_log_debug("════════════════════════════════════════════════════")
	_log_debug("📤 DictMerge 执行:")
	_log_debug("  • 源字典: '%s'" % source_dict_variable)
	_log_debug("  • 目标字典: '%s'" % target_dict_variable)
	_log_debug("  • 覆盖已存在键: %s" % overwrite_existing)
	_log_debug("  • 源字典键数: %d" % source_dict.size())
	_log_debug("  • 目标字典键数: %d" % target_dict.size())
	_log_debug("════════════════════════════════════════════════════")

	# 执行合并
	var merged_count := 0
	var skipped_count := 0

	for key in source_dict.keys():
		if overwrite_existing or not target_dict.has(key):
			target_dict[key] = source_dict[key]
			merged_count += 1
		else:
			skipped_count += 1

	_log_debug("合并完成: 合并 %d 个键, 跳过 %d 个已存在键" % [merged_count, skipped_count])
	_log_info_localized("FUSE_LOG_DICT_MERGED", {
		"source": source_dict_variable,
		"target": target_dict_variable,
		"merged": merged_count,
		"skipped": skipped_count
	})

	# 触发变量变化通知
	if target_dict_scope == BaseVariable.VariableScope.GLOBAL:
		_notify_global_variable_changed(target_dict_variable)
	elif target_dict_scope == BaseVariable.VariableScope.SCOPE:
		_notify_scope_variable_changed(context)

	_on_execution_completed()

## 获取字典值（可能为 null）
func _get_dict_value(
	context: ExecutionContext,
	var_name: String,
	scope: BaseVariable.VariableScope,
	scope_source: ScopeSource,
	custom_scope_id: String,
	target_node_path: NodePath
) -> Variant:
	match scope:
		BaseVariable.VariableScope.LOCAL:
			if VariableOperations.has_variable(context, var_name, BaseVariable.VariableScope.LOCAL):
				return VariableOperations.get_variable(context, var_name, BaseVariable.VariableScope.LOCAL, null)
			return null

		BaseVariable.VariableScope.SCOPE:
			if scope_source == ScopeSource.NEAREST:
				if VariableOperations.has_variable(context, var_name, BaseVariable.VariableScope.SCOPE):
					return VariableOperations.get_variable(context, var_name, BaseVariable.VariableScope.SCOPE, null)
				return null
			else:
				var utils_scope_source = scope_source as VariableScopeUtils.ScopeSource
				var scope_container = VariableScopeUtils.get_scope_container_by_source(
					context,
					utils_scope_source,
					custom_scope_id,
					target_node_path
				)
				if scope_container == null:
					return null
				if scope_container.has_variable(var_name):
					return scope_container.get_variable(var_name, null)
				return null

		BaseVariable.VariableScope.GLOBAL:
			if VariableOperations.has_variable(context, var_name, BaseVariable.VariableScope.GLOBAL):
				return VariableOperations.get_variable(context, var_name, BaseVariable.VariableScope.GLOBAL, null)
			return null

	return null

## 获取字典变量（如果不存在返回空字典）
func _get_dict_variable(
	context: ExecutionContext,
	var_name: String,
	scope: BaseVariable.VariableScope,
	scope_source: ScopeSource,
	custom_scope_id: String,
	target_node_path: NodePath
) -> Dictionary:
	var dict_value = _get_dict_value(context, var_name, scope, scope_source, custom_scope_id, target_node_path)
	if dict_value is Dictionary:
		return dict_value
	return {}

## 验证指令参数
func validate() -> Array[String]:
	var errors = super.validate()

	# 验证源字典变量名
	if source_dict_variable.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_DICT_VARIABLE_EMPTY"))

	# 验证目标字典变量名
	if target_dict_variable.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_DICT_VARIABLE_EMPTY"))

	# 验证源字典 SCOPE 作用域
	if source_dict_scope == BaseVariable.VariableScope.SCOPE:
		var manager = ScopeVariableManager.get_instance()
		if manager == null:
			errors.append(FuseLocalization.translate("FUSE_ERROR_SCOPE_MANAGER_NOT_FOUND"))

		var source_utils_scope_source = source_scope_source as VariableScopeUtils.ScopeSource
		errors.append_array(VariableScopeUtils.validate_scope_source_params(
			source_utils_scope_source,
			source_custom_scope_id,
			source_target_node_path
		))

	# 验证目标字典 SCOPE 作用域
	if target_dict_scope == BaseVariable.VariableScope.SCOPE:
		var manager = ScopeVariableManager.get_instance()
		if manager == null:
			errors.append(FuseLocalization.translate("FUSE_ERROR_SCOPE_MANAGER_NOT_FOUND"))

		var target_utils_scope_source = target_scope_source as VariableScopeUtils.ScopeSource
		errors.append_array(VariableScopeUtils.validate_scope_source_params(
			target_utils_scope_source,
			target_custom_scope_id,
			target_target_node_path
		))

	return errors

## 验证属性可见性
func _validate_property(property: Dictionary) -> void:
	# 源字典作用域相关属性
	if source_dict_scope == BaseVariable.VariableScope.SCOPE:
		if property.name == "source_scope_source":
			return  # 始终显示
		elif property.name == "source_custom_scope_id":
			if source_scope_source != ScopeSource.CUSTOM_ID:
				property.usage = PROPERTY_USAGE_NO_EDITOR
		elif property.name == "source_target_node_path":
			if source_scope_source != ScopeSource.TARGET_NODE:
				property.usage = PROPERTY_USAGE_NO_EDITOR
	else:
		if property.name in ["source_scope_source", "source_custom_scope_id", "source_target_node_path"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR

	# 目标字典作用域相关属性
	if target_dict_scope == BaseVariable.VariableScope.SCOPE:
		if property.name == "target_scope_source":
			return  # 始终显示
		elif property.name == "target_custom_scope_id":
			if target_scope_source != ScopeSource.CUSTOM_ID:
				property.usage = PROPERTY_USAGE_NO_EDITOR
		elif property.name == "target_target_node_path":
			if target_scope_source != ScopeSource.TARGET_NODE:
				property.usage = PROPERTY_USAGE_NO_EDITOR
	else:
		if property.name in ["target_scope_source", "target_custom_scope_id", "target_target_node_path"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR

## 获取指令描述
func get_description() -> String:
	var source_str := ""
	var target_str := ""

	if source_dict_variable.is_empty():
		source_str = FuseLocalization.translate("FUSE_INSTRUCTION_DICT_NO_DICT")
	else:
		source_str = FuseLocalization.translate_format("FUSE_INSTRUCTION_DICT_DICT", {"name": source_dict_variable})

	if target_dict_variable.is_empty():
		target_str = FuseLocalization.translate("FUSE_INSTRUCTION_DICT_NO_DICT")
	else:
		target_str = FuseLocalization.translate_format("FUSE_INSTRUCTION_DICT_DICT", {"name": target_dict_variable})

	var mode_str := "merge" if overwrite_existing else "merge+keep"
	return "Dict %s: %s -> %s" % [mode_str, source_str, target_str]

## 重置指令状态
func reset():
	super.reset()
	_log_debug_localized("FUSE_LOG_DICT_MERGE_RESET", {})

## 通知全局变量已变化
func _notify_global_variable_changed(var_name: String) -> void:
	var manager = GlobalVariableManager.get_instance()
	if manager == null:
		_log_debug("无法获取全局变量管理器，跳过变化通知")
		return

	var variable = manager.get_variable(var_name)
	if variable == null:
		_log_debug("全局变量 '%s' 不存在，跳过变化通知" % var_name)
		return

	if variable.persistent:
		_log_debug("持久化变量 '%s' 已修改，触发变化通知" % var_name)
		manager.notify_variable_content_changed(var_name)
	else:
		_log_debug("变量 '%s' 不是持久化变量，跳过自动保存通知" % var_name)

## 通知 SCOPE 作用域变量已变化
func _notify_scope_variable_changed(context: ExecutionContext) -> void:
	var utils_scope_source = target_scope_source as VariableScopeUtils.ScopeSource
	var scope_container = VariableScopeUtils.get_scope_container_by_source(
		context,
		utils_scope_source,
		target_custom_scope_id,
		target_target_node_path
	)

	if scope_container == null:
		_log_debug("无法获取 ScopeVariableContainer，跳过变化通知")
		return

	_log_debug("SCOPE 变量 '%s' 已修改，触发 notify_property_list_changed" % target_dict_variable)
	scope_container.notify_property_list_changed()
