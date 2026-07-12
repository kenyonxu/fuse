@tool
@icon("res://addons/fuse/icons/builtin/Dictionary.svg")
extends BaseInstruction
class_name DictClear

## DictClear 指令
##
## 清空字典（清除所有键值对）。
## 支持从变量获取字典。
## 只在 VARIABLE 模式下保存回变量。
##
## 使用 VariableOperations 统一变量访问 API

## 作用域来源枚举
enum ScopeSource {
	NEAREST,        ## 最近的作用域容器（默认）
	CUSTOM_ID,      ## 指定 scope_id
	TRIGGER_SCOPE,  ## Trigger 节点上的作用域
	TARGET_NODE     ## Target 节点上的作用域
}

# 字典变量名
var dict_variable: String = ""

# 字典变量作用域
var dict_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		if dict_scope != value:
			dict_scope = value
			_update_resource_name()
			notify_property_list_changed()

## 字典作用域来源（仅当 dict_scope == SCOPE 时使用）
var dict_scope_source: ScopeSource = ScopeSource.NEAREST:
	set(value):
		if dict_scope_source != value:
			dict_scope_source = value
			_update_resource_name()
			notify_property_list_changed()

## 自定义字典作用域 ID（CUSTOM_ID 模式使用）
var dict_custom_scope_id: String = "":
	set(value):
		if dict_custom_scope_id != value:
			dict_custom_scope_id = value
			_update_resource_name()

## 字典目标节点路径（TARGET_NODE 模式使用）
var dict_target_node_path: NodePath = NodePath(""):
	set(value):
		if dict_target_node_path != value:
			dict_target_node_path = value
			_update_resource_name()

## 获取指令元数据（用于指令选择器）
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_DICT_CLEAR_NAME"
	metadata.category_key = "FUSE_CATEGORY_DICTIONARIES"
	metadata.description_key = "FUSE_INSTRUCTION_DICT_CLEAR_DESC"
	metadata.keywords = ["字典", "清空", "清除", "dictionary", "clear", "empty", "键值对"]
	metadata.builtin_icon = "Dictionary"
	return metadata

## 设置指令元数据
func _setup_metadata():
	pass

## 声明变量读写模式（dict=read 原地清空）
func get_variable_modes() -> Array[Dictionary]:
	return [{"name": "dict_variable", "mode": "read"}]

## 获取属性列表
func _get_property_list() -> Array[Dictionary]:
	var properties := []

	# Source 分类
	properties.append({
		name = "Source",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	# 字典变量名
	properties.append({
		name = "dict_variable",
		type = TYPE_STRING,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 字典作用域
	properties.append({
		name = "dict_scope",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Local,Scope,Global",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 只在 dict_scope == SCOPE 时显示字典 ScopeSource 配置
	if dict_scope == BaseVariable.VariableScope.SCOPE:
		properties.append({
			name = "Dictionary Scope Configuration",
			type = TYPE_NIL,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_CATEGORY
		})

		properties.append({
			name = "dict_scope_source",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "Nearest,Custom ID,Trigger Scope,Target Node",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		# 根据作用域来源添加额外属性
		if dict_scope_source == ScopeSource.CUSTOM_ID:
			properties.append({
				name = "dict_custom_scope_id",
				type = TYPE_STRING,
				hint = PROPERTY_HINT_NONE,
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})
		elif dict_scope_source == ScopeSource.TARGET_NODE:
			properties.append({
				name = "dict_target_node_path",
				type = TYPE_NODE_PATH,
				hint = PROPERTY_HINT_NONE,
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})

	return properties

## 更新资源名称
func _update_resource_name():
	var source_str := ""

	# 源信息
	if dict_variable.is_empty():
		source_str = FuseLocalization.translate("FUSE_INSTRUCTION_DICT_CLEAR_NO_DICT")
	else:
		source_str = FuseLocalization.translate_format("FUSE_INSTRUCTION_DICT_CLEAR_DICT", {"name": dict_variable})

	resource_name = " ".join(["Dict Clear", source_str])

## 动态属性设置（支持属性刷新）
func _set(property: StringName, value: Variant) -> bool:
	if property == "dict_variable":
		dict_variable = value
		_update_resource_name()
		return false

	return false

## 执行指令
func execute(context: ExecutionContext):
	_start_execution(context)

	_log_debug_localized("FUSE_LOG_INSTRUCTION_START", {"instruction": "DictClear"})

	# 调试输出：打印当前全局变量信息
	_debug_print_global_variables()

	# 验证字典变量名
	if dict_variable.is_empty():
		_log_error_localized("FUSE_ERROR_DICT_VARIABLE_EMPTY", {})
		set_error_localized("FUSE_ERROR_DICT_VARIABLE_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
		finished.emit()
		return

	# 调试输出：显示字典变量的作用域信息
	_debug_log_dict_scope_info()

	# 获取字典变量
	var target_dict: Dictionary = _get_dict_variable(context)

	if target_dict == null or not target_dict is Dictionary:
		_log_error_localized("FUSE_ERROR_DICT_VARIABLE_NOT_FOUND", {"name": dict_variable})
		set_error_localized("FUSE_ERROR_DICT_VARIABLE_NOT_FOUND", FuseError.ErrorType.VALIDATION_ERROR, {"name": dict_variable})
		finished.emit()
		return

	# 调试输出：清空前的字典状态
	var dict_size_before := target_dict.size()
	_log_debug("字典 '%s' 清空前: 大小=%d, 内容=%s" % [dict_variable, dict_size_before, str(target_dict)])

	# 清空字典
	target_dict.clear()

	# 调试输出：清空后的字典状态
	var dict_size_after := target_dict.size()

	# 获取作用域名称用于日志输出
	var scope_name_for_log := _get_scope_name_for_log()

	_log_debug("════════════════════════════════════════════════════")
	_log_debug("📤 DictClear 执行结果:")
	_log_debug("  • 目标字典: '%s'" % dict_variable)
	_log_debug("  • 作用域: %s" % scope_name_for_log)
	_log_debug("  • 字典大小: %d → %d" % [dict_size_before, dict_size_after])
	_log_debug("  • 最终内容: %s" % str(target_dict))
	_log_debug("════════════════════════════════════════════════════")

	_log_info_localized("FUSE_LOG_DICT_CLEARED", {"dict": dict_variable})

	# 验证清空是否成功
	if dict_size_after == 0:
		_log_debug("验证成功: 字典已正确清空")
	else:
		_log_error("验证失败: 字典大小不为 0 (实际 %d)" % dict_size_after)

	# 触发变量变化通知（重要：clear 修改的是字典内容而非引用，需要手动触发信号）
	if dict_scope == BaseVariable.VariableScope.GLOBAL:
		var verified_dict = VariableOperations.get_variable(context, dict_variable, BaseVariable.VariableScope.GLOBAL, null)
		if verified_dict is Dictionary:
			_log_debug("全局变量 '%s' 最终验证: 大小=%d, 内容=%s" % [dict_variable, verified_dict.size(), str(verified_dict)])
			# 触发变量变化通知（让 GlobalVariableAssistant 知道持久化变量已变化）
			_notify_global_variable_changed(dict_variable)
		else:
			_log_error("全局变量 '%s' 验证失败: 不是字典类型 (类型: %s)" % [dict_variable, typeof(verified_dict)])

	elif dict_scope == BaseVariable.VariableScope.SCOPE:
		# 触发 SCOPE 变量变化通知
		_notify_scope_variable_changed(context)

	_on_execution_completed()

## 获取字典变量
func _get_dict_variable(context: ExecutionContext) -> Variant:
	var dict_value: Variant = null

	match dict_scope:
		BaseVariable.VariableScope.LOCAL:
			dict_value = VariableOperations.get_variable(context, dict_variable, BaseVariable.VariableScope.LOCAL, null)

		BaseVariable.VariableScope.SCOPE:
			if dict_scope_source == ScopeSource.NEAREST:
				dict_value = VariableOperations.get_variable(context, dict_variable, BaseVariable.VariableScope.SCOPE, null)
			else:
				var utils_scope_source = dict_scope_source as VariableScopeUtils.ScopeSource
				var scope_container = VariableScopeUtils.get_scope_container_by_source(
					context,
					utils_scope_source,
					dict_custom_scope_id,
					dict_target_node_path
				)
				if scope_container == null:
					return null
				dict_value = scope_container.get_variable(dict_variable, null)

		BaseVariable.VariableScope.GLOBAL:
			dict_value = VariableOperations.get_variable(context, dict_variable, BaseVariable.VariableScope.GLOBAL, null)

	if dict_value is Dictionary:
		return dict_value
	else:
		# 变量存在但不是字典，返回 null
		_log_debug("变量 '%s' 不是字典类型 (类型: %s)" % [dict_variable, typeof(dict_value)])
		return null

## 验证指令参数
func validate() -> Array[String]:
	var errors = super.validate()

	# 验证字典变量名
	if dict_variable.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_DICT_VARIABLE_EMPTY"))

	# 验证字典 SCOPE 作用域需要 ScopeVariableManager
	if dict_scope == BaseVariable.VariableScope.SCOPE:
		var manager = ScopeVariableManager.get_instance()
		if manager == null:
			errors.append(FuseLocalization.translate("FUSE_ERROR_SCOPE_MANAGER_NOT_FOUND"))

		# 验证 ScopeSource 参数
		var dict_utils_scope_source = dict_scope_source as VariableScopeUtils.ScopeSource
		errors.append_array(VariableScopeUtils.validate_scope_source_params(
			dict_utils_scope_source,
			dict_custom_scope_id,
			dict_target_node_path
		))

	return errors

## 验证属性可见性
func _validate_property(property: Dictionary) -> void:
	# 字典作用域相关属性
	if dict_scope == BaseVariable.VariableScope.SCOPE:
		if property.name == "dict_scope_source":
			return  # 始终显示
		elif property.name == "dict_custom_scope_id":
			if dict_scope_source != ScopeSource.CUSTOM_ID:
				property.usage = PROPERTY_USAGE_NO_EDITOR
		elif property.name == "dict_target_node_path":
			if dict_scope_source != ScopeSource.TARGET_NODE:
				property.usage = PROPERTY_USAGE_NO_EDITOR
	else:
		if property.name in ["dict_scope_source", "dict_custom_scope_id", "dict_target_node_path"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR

## 获取指令描述
func get_description() -> String:
	var source_str := ""

	if not dict_variable.is_empty():
		source_str = FuseLocalization.translate_format("FUSE_INSTRUCTION_DICT_CLEAR_DESC_DICT", {"name": dict_variable})
	else:
		source_str = FuseLocalization.translate("FUSE_INSTRUCTION_DICT_CLEAR_DESC_NO_DICT")

	return "Dict Clear: %s" % source_str

## 重置指令状态
func reset():
	super.reset()
	_log_debug_localized("FUSE_LOG_DICT_CLEAR_RESET", {})

## 调试输出：打印当前全局变量信息
func _debug_print_global_variables():
	var assistant = GlobalVariableAssistant.get_instance()
	if assistant == null:
		_log_debug("无法获取全局变量助手")
		return

	var all_vars_info = assistant.get_all_global_variables_info()
	if all_vars_info.is_empty():
		_log_debug("当前全局变量: (无)")
		return

	_log_debug("当前全局变量列表 (%d 个):" % all_vars_info.size())
	for var_name in all_vars_info.keys():
		var var_info = all_vars_info[var_name]
		var type_name = var_info.get("type", "Unknown")
		var value_str = str(var_info.get("value", ""))
		var persistent_flag = var_info.get("persistent", false)
		# 如果值太长则截断
		if value_str.length() > 50:
			value_str = value_str.substr(0, 47) + "..."
		var persistent_mark = "P" if persistent_flag else ""
		_log_debug("  - %s [%s] = %s%s" % [var_name, type_name, value_str, persistent_mark])

## 调试输出：显示字典变量的作用域信息
func _debug_log_dict_scope_info():
	var scope_name := ""
	match dict_scope:
		BaseVariable.VariableScope.LOCAL:
			scope_name = "LOCAL"
		BaseVariable.VariableScope.SCOPE:
			scope_name = "SCOPE"
		BaseVariable.VariableScope.GLOBAL:
			scope_name = "GLOBAL"

	if dict_scope == BaseVariable.VariableScope.SCOPE:
		var source_name := ""
		match dict_scope_source:
			ScopeSource.NEAREST:
				source_name = "NEAREST"
			ScopeSource.CUSTOM_ID:
				source_name = "CUSTOM_ID: %s" % dict_custom_scope_id
			ScopeSource.TRIGGER_SCOPE:
				source_name = "TRIGGER_SCOPE"
			ScopeSource.TARGET_NODE:
				source_name = "TARGET_NODE: %s" % str(dict_target_node_path)
		_log_debug("目标字典: '%s' | 作用域: %s | 来源: %s" % [dict_variable, scope_name, source_name])
	else:
		_log_debug("目标字典: '%s' | 作用域: %s" % [dict_variable, scope_name])

## 获取作用域名称（用于日志输出）
func _get_scope_name_for_log() -> String:
	match dict_scope:
		BaseVariable.VariableScope.LOCAL:
			return "LOCAL"
		BaseVariable.VariableScope.SCOPE:
			var source_name := ""
			match dict_scope_source:
				ScopeSource.NEAREST:
					source_name = "NEAREST"
				ScopeSource.CUSTOM_ID:
					source_name = "CUSTOM_ID[%s]" % dict_custom_scope_id
				ScopeSource.TRIGGER_SCOPE:
					source_name = "TRIGGER_SCOPE"
				ScopeSource.TARGET_NODE:
					source_name = "TARGET_NODE[%s]" % str(dict_target_node_path)
			return "SCOPE - %s" % source_name
		BaseVariable.VariableScope.GLOBAL:
			return "GLOBAL"
	return "UNKNOWN"

## 通知全局变量已变化（用于触发自动保存等）
## 由于 clear 修改的是字典内容而非引用，value_changed 信号不会自动触发
## 因此需要手动通知 GlobalVariableManager 变量已变化
func _notify_global_variable_changed(var_name: String) -> void:
	var manager = GlobalVariableManager.get_instance()
	if manager == null:
		_log_debug("无法获取全局变量管理器，跳过变化通知")
		return

	var variable = manager.get_variable(var_name)
	if variable == null:
		_log_debug("全局变量 '%s' 不存在，跳过变化通知" % var_name)
		return

	# 检查是否是持久化变量
	if variable.persistent:
		_log_debug("持久化变量 '%s' 已修改，触发变化通知" % var_name)
		# 使用 GlobalVariableManager 提供的方法通知变量内容已变化
		manager.notify_variable_content_changed(var_name)
	else:
		_log_debug("变量 '%s' 不是持久化变量，跳过自动保存通知" % var_name)

## 通知 SCOPE 作用域变量已变化
## 由于 clear 修改的是字典内容而非引用，需要调用 notify_property_list_changed
## 让远程调试器能够观测到变量变化
func _notify_scope_variable_changed(context: ExecutionContext) -> void:
	var utils_scope_source = dict_scope_source as VariableScopeUtils.ScopeSource
	var scope_container = VariableScopeUtils.get_scope_container_by_source(
		context,
		utils_scope_source,
		dict_custom_scope_id,
		dict_target_node_path
	)

	if scope_container == null:
		_log_debug("无法获取 ScopeVariableContainer，跳过变化通知")
		return

	_log_debug("SCOPE 变量 '%s' 已修改，触发 notify_property_list_changed" % dict_variable)
	scope_container.notify_property_list_changed()
