@tool
@icon("res://addons/fuse/icons/builtin/Search.png")
extends BaseInstruction
class_name FindNode

## 查找节点指令
##
## 按名称、类型或组查找节点，并将找到的节点路径保存到变量中。
##
## 重构变量系统: 2026-02-09 - 使用 VariableOperations 统一变量访问

## 作用域来源枚举
enum ScopeSource {
	NEAREST,        ## 最近的作用域容器（默认）
	CUSTOM_ID,      ## 指定 scope_id
	TRIGGER_SCOPE,  ## Trigger 节点上的作用域
	TARGET_NODE     ## Target 节点上的作用域
}

# 搜索类型
enum SearchType {
	BY_NAME,    ## 按名称查找
	BY_TYPE,    ## 按类型查找（使用 get_class()）
	BY_GROUP    ## 按组查找
}

# 搜索范围
enum SearchScope {
	CHILDREN,   ## 在子节点中查找
	SCENE,      ## 在当前场景中查找
	GLOBAL      ## 在整个场景树中查找
}

# 错误处理模式
enum ErrorHandling {
	STRICT,      ## 严格模式：找不到时记录错误
	SILENT,      ## 静默模式：找不到时不记录，返回 null
	WARNING      ## 警告模式：找不到时记录警告
}

# 搜索类型
var search_type: SearchType = SearchType.BY_NAME

# 搜索范围
var search_scope: SearchScope = SearchScope.CHILDREN

# 搜索值（名称、类型或组名）
var search_value: String = ""

# 是否使用递归查找（仅对 BY_NAME 和 BY_TYPE 有效）
var recursive: bool = true

# 是否只返回第一个匹配项
var first_match_only: bool = true

# 结果变量名
var result_variable: String = ""

# 结果变量作用域
var result_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		if result_scope != value:
			result_scope = value
			_update_resource_name()
			notify_property_list_changed()

## 作用域来源（仅当 result_scope == SCOPE 时使用）
var scope_source: ScopeSource = ScopeSource.NEAREST:
	set(value):
		if scope_source != value:
			scope_source = value
			_update_resource_name()
			notify_property_list_changed()

## 自定义作用域 ID（CUSTOM_ID 模式使用）
var custom_scope_id: String = "":
	set(value):
		if custom_scope_id != value:
			custom_scope_id = value
			_update_resource_name()

## 目标节点路径（TARGET_NODE 模式使用）
var target_node_path: NodePath = NodePath(""):
	set(value):
		if target_node_path != value:
			target_node_path = value
			_update_resource_name()

# 错误处理模式
var error_handling: ErrorHandling = ErrorHandling.STRICT

# 静态缓存：搜索类型枚举
static var _cached_search_types: Array[String] = []
static var _search_types_cached: bool = false

# 静态缓存：搜索范围枚举
static var _cached_search_scopes: Array[String] = []
static var _search_scopes_cached: bool = false

# 静态缓存：错误处理模式枚举
static var _cached_error_handling: Array[String] = []
static var _error_handling_cached: bool = false

## 初始化搜索类型缓存
static func _init_search_types_cache() -> void:
	if _search_types_cached:
		return

	_cached_search_types = [
		FuseLocalization.translate("FUSE_SEARCH_TYPE_BY_NAME"),
		FuseLocalization.translate("FUSE_SEARCH_TYPE_BY_TYPE"),
		FuseLocalization.translate("FUSE_SEARCH_TYPE_BY_GROUP")
	]

	_search_types_cached = true

## 初始化搜索范围缓存
static func _init_search_scopes_cache() -> void:
	if _search_scopes_cached:
		return

	_cached_search_scopes = [
		FuseLocalization.translate("FUSE_SEARCH_SCOPE_CHILDREN"),
		FuseLocalization.translate("FUSE_SEARCH_SCOPE_SCENE"),
		FuseLocalization.translate("FUSE_SEARCH_SCOPE_GLOBAL")
	]

	_search_scopes_cached = true

## 初始化错误处理模式缓存
static func _init_error_handling_cache() -> void:
	if _error_handling_cached:
		return

	_cached_error_handling = [
		FuseLocalization.translate("FUSE_ERROR_HANDLING_STRICT"),
		FuseLocalization.translate("FUSE_ERROR_HANDLING_SILENT"),
		FuseLocalization.translate("FUSE_ERROR_HANDLING_WARNING")
	]

	_error_handling_cached = true

## 获取指令元数据（用于指令选择器）
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_FIND_NODE_NAME"
	metadata.category_key = "FUSE_CATEGORY_NODE_OPERATIONS"
	metadata.description_key = "FUSE_INSTRUCTION_FIND_NODE_DESC"
	metadata.keywords = ["find", "node", "search", "get", "查找", "节点", "搜索", "获取"]
	# 设置指令选择器图标
	metadata.builtin_icon = "Search"
	return metadata

## 设置指令元数据
func _setup_metadata():
	pass

## 获取属性列表
func _get_property_list() -> Array[Dictionary]:
	var properties := []

	# 初始化静态缓存
	_init_search_types_cache()
	_init_search_scopes_cache()
	_init_error_handling_cache()

	# Search Options 分类
	properties.append({
		name = "Search Options",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	# 搜索类型
	properties.append({
		name = "search_type",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = ",".join(_cached_search_types),
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 搜索范围
	properties.append({
		name = "search_scope",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = ",".join(_cached_search_scopes),
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 搜索值
	properties.append({
		name = "search_value",
		type = TYPE_STRING,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 递归选项（对 BY_NAME 和 BY_TYPE 有效）
	properties.append({
		name = "recursive",
		type = TYPE_BOOL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 只返回第一个匹配项
	properties.append({
		name = "first_match_only",
		type = TYPE_BOOL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# Result Options 分类
	properties.append({
		name = "Result Options",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	# 结果变量名
	properties.append({
		name = "result_variable",
		type = TYPE_STRING,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 结果变量作用域
	properties.append({
		name = "result_scope",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Local,Scope,Global",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 只在 result_scope == SCOPE 时显示 ScopeSource 配置
	if result_scope == BaseVariable.VariableScope.SCOPE:
		properties.append({
			name = "Scope Configuration",
			type = TYPE_NIL,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_CATEGORY
		})

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

	# Error Handling 分类
	properties.append({
		name = "Error Handling",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	# 错误处理模式
	properties.append({
		name = "error_handling",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = ",".join(_cached_error_handling),
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	return properties

## 更新资源名称
func _update_resource_name():
	var parts = []

	parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_FIND_NODE_RESOURCE_BASE"))

	parts.append("[%s]" % _get_search_type_string())

	if search_value.is_empty():
		parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_FIND_NODE_NO_SEARCH_VALUE"))
	else:
		parts.append("'%s'" % search_value)

	var scope_key = _get_search_scope_key()
	parts.append(FuseLocalization.translate_format(
		"FUSE_INSTRUCTION_FIND_NODE_IN_TEMPLATE",
		{"scope": FuseLocalization.translate(scope_key)}
	))

	if result_variable.is_empty():
		parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_FIND_NODE_NO_VARIABLE"))
	else:
		var scope_str = _get_scope_source_string()
		parts.append(FuseLocalization.translate_format(
			"FUSE_INSTRUCTION_FIND_NODE_VAR_TEMPLATE",
			{"var_type": scope_str, "var": result_variable}
		))

	resource_name = " ".join(parts)

## 获取作用域来源字符串
func _get_scope_source_string() -> String:
	match result_scope:
		BaseVariable.VariableScope.LOCAL:
			return FuseLocalization.translate("FUSE_VARIABLE_SCOPE_LOCAL_STR")
		BaseVariable.VariableScope.GLOBAL:
			return FuseLocalization.translate("FUSE_VARIABLE_SCOPE_GLOBAL_STR")
		BaseVariable.VariableScope.SCOPE:
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

	# 验证搜索值
	if search_value.is_empty():
		_log_error_localized("FUSE_ERROR_MISSING_PARAMETER", {"param": "搜索值"})
		set_error_localized("FUSE_ERROR_MISSING_PARAMETER", FuseError.ErrorType.VALIDATION_ERROR, {"param": "搜索值"})
		finished.emit()
		return

	# 验证结果变量名
	if result_variable.is_empty():
		_log_error_localized("FUSE_ERROR_VAR_NAME_EMPTY", {})
		set_error_localized("FUSE_ERROR_VAR_NAME_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
		finished.emit()
		return

	# 获取搜索起始节点
	var search_root := _get_search_root(context)
	if not search_root:
		_log_error_localized("FUSE_LOG_FIND_NODE_CANNOT_GET_ROOT", {})
		set_error_localized("FUSE_LOG_FIND_NODE_CANNOT_GET_ROOT", FuseError.ErrorType.RUNTIME_ERROR, {})
		finished.emit()
		return

	# 执行搜索
	var result = _perform_search(search_root)

	# 处理搜索结果
	var found_node = result != null and not (result is Array and result.is_empty())

	if not found_node:
		# 根据错误处理模式响应
		match error_handling:
			ErrorHandling.STRICT:
				# 严格模式：找不到时记录错误
				_log_error_localized("FUSE_ERROR_NODE_NOT_FOUND", {
					"criteria": search_value,
					"scope": _get_search_scope_string()
				})
				set_error_localized("FUSE_ERROR_NODE_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {
					"criteria": search_value,
					"scope": _get_search_scope_string()
				})
			ErrorHandling.WARNING:
				# 警告模式：找不到时记录警告
				_log_warning_localized("FUSE_LOG_FIND_NODE_NOT_FOUND", {
					"value": search_value,
					"type": _get_search_type_string(),
					"scope": _get_search_scope_string()
				})
			ErrorHandling.SILENT:
				# 靑默模式：不记录，直接保存 null
				_log_debug_localized("FUSE_LOG_FIND_NODE_NOT_FOUND_SILENT", {"value": search_value})

		# 保存 null 结果
		_save_result(context, null)
	else:
		# 找到节点，保存结果
		if result is Array:
			_log_info_localized("FUSE_LOG_FIND_NODE_FOUND_MULTIPLE", {"count": result.size()})
			_save_result(context, result)
		else:  # 单个结果（字符串路径）
			_log_info_localized("FUSE_LOG_FIND_NODE_FOUND_SINGLE", {"path": str(result)})
			_save_result(context, result)

	_on_execution_completed()

## 执行搜索
func _perform_search(search_root: Node) -> Variant:
	match search_type:
		SearchType.BY_NAME:
			return _search_by_name(search_root)
		SearchType.BY_TYPE:
			return _search_by_type(search_root)
		SearchType.BY_GROUP:
			return _search_by_group(search_root)
		_:
			return null

## 按名称搜索
func _search_by_name(search_root: Node) -> Variant:
	if first_match_only:
		# 查找第一个匹配项
		var node = search_root.find_child(search_value, recursive, false)
		if node:
			return str(node.get_path())
		return null
	else:
		# 查找所有匹配项
		var results = []
		_collect_nodes_by_name(search_root, search_value, results)
		if results.is_empty():
			return []
		# 转换为节点路径字符串数组
		var paths = []
		for node in results:
			paths.append(str(node.get_path()))
		return paths

## 递归收集所有匹配名称的节点
func _collect_nodes_by_name(node: Node, name: String, results: Array):
	# 检查当前节点
	if node.name == name:
		results.append(node)

	# 如果需要递归，检查子节点
	if recursive:
		for child in node.get_children():
			_collect_nodes_by_name(child, name, results)

## 按类型搜索
func _search_by_type(search_root: Node) -> Variant:
	var results = []

	if recursive:
		# 递归搜索所有节点
		_collect_nodes_by_type(search_root, search_value, results)
	else:
		# 只搜索直接子节点
		for child in search_root.get_children():
			if child.get_class() == search_value:
				results.append(child)

	if results.is_empty():
		return []

	if first_match_only:
		return str(results[0].get_path())
	else:
		# 转换为节点路径字符串数组
		var paths = []
		for node in results:
			paths.append(str(node.get_path()))
		return paths

## 递归收集所有匹配类型的节点
func _collect_nodes_by_type(node: Node, type_name: String, results: Array):
	# 检查当前节点
	if node.get_class() == type_name:
		results.append(node)

	# 递归检查子节点
	for child in node.get_children():
		_collect_nodes_by_type(child, type_name, results)

## 按组搜索
func _search_by_group(search_root: Node) -> Variant:
	var tree = search_root.get_tree()
	if not tree:
		return null if first_match_only else []

	var nodes = tree.get_nodes_in_group(search_value)

	if nodes.is_empty():
		return null if first_match_only else []

	if first_match_only:
		# 返回找到的第一个节点
		return str(nodes[0].get_path())
	else:
		# 返回所有节点路径
		var paths = []
		for node in nodes:
			paths.append(str(node.get_path()))
		return paths

## 获取搜索根节点
func _get_search_root(context: ExecutionContext) -> Node:
	match search_scope:
		SearchScope.CHILDREN:
			# 在 target 节点的子节点中查找
			return context.target
		SearchScope.SCENE:
			# 在当前场景中查找
			var scene_tree = context.get_tree()
			return scene_tree.current_scene if scene_tree else null
		SearchScope.GLOBAL:
			# 在整个场景树中查找
			var scene_tree = context.get_tree()
			return scene_tree.root if scene_tree else null
		_:
			return null

## 保存结果到变量
func _save_result(context: ExecutionContext, value: Variant):
	var success = false
	match result_scope:
		BaseVariable.VariableScope.LOCAL:
			success = VariableOperations.set_variable(context, result_variable, BaseVariable.VariableScope.LOCAL, value)
		BaseVariable.VariableScope.SCOPE:
			if scope_source == ScopeSource.NEAREST:
				success = VariableOperations.set_variable(context, result_variable, BaseVariable.VariableScope.SCOPE, value)
			else:
				var utils_scope_source = scope_source as VariableScopeUtils.ScopeSource
				var scope_container = VariableScopeUtils.get_scope_container_by_source(
					context,
					utils_scope_source,
					custom_scope_id,
					target_node_path
				)
				if scope_container != null:
					success = scope_container.set_variable(result_variable, value)
				else:
					success = false
		BaseVariable.VariableScope.GLOBAL:
			success = VariableOperations.set_variable(context, result_variable, BaseVariable.VariableScope.GLOBAL, value)

	if success:
		var scope_str = _get_scope_source_string()
		_log_info_localized("FUSE_LOG_FIND_NODE_SAVED_TO_SCOPE", {
			"var": result_variable,
			"scope": scope_str
		})
	else:
		_log_error_localized("FUSE_LOG_FIND_NODE_SAVE_FAILED", {
			"var": result_variable,
			"scope": _get_scope_source_string()
		})

## 验证指令参数
func validate() -> Array[String]:
	var errors = super.validate()

	if search_value.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_FIND_NODE_SEARCH_VALUE_EMPTY"))

	if result_variable.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_FIND_NODE_RESULT_VAR_EMPTY"))

	# 验证 SCOPE 作用域需要 ScopeVariableManager
	if result_scope == BaseVariable.VariableScope.SCOPE:
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

## 验证属性可见性
func _validate_property(property: Dictionary) -> void:
	# recursive 只对 BY_NAME 和 BY_TYPE 有效
	if property.name == "recursive" and search_type == SearchType.BY_GROUP:
		property.usage = PROPERTY_USAGE_NO_EDITOR

	# 只在 SCOPE 作用域时验证 ScopeSource 相关属性
	if result_scope == BaseVariable.VariableScope.SCOPE:
		VariableScopeUtils.validate_scope_source_property(property, scope_source as VariableScopeUtils.ScopeSource)
	else:
		# 非 SCOPE 作用域时隐藏 ScopeSource 相关属性
		if property.name in ["scope_source", "custom_scope_id", "target_node_path"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR

## 动态属性设置（支持属性刷新）
func _set(property: StringName, value: Variant) -> bool:
	if property == "search_type":
		search_type = value
		notify_property_list_changed()
		return true
	return false

## 获取搜索类型的本地化字符串
func _get_search_type_string() -> String:
	var key = _get_search_type_key()
	return FuseLocalization.translate(key)

## 获取搜索类型的翻译键
func _get_search_type_key() -> String:
	match search_type:
		SearchType.BY_NAME:
			return "FUSE_SEARCH_TYPE_BY_NAME"
		SearchType.BY_TYPE:
			return "FUSE_SEARCH_TYPE_BY_TYPE"
		SearchType.BY_GROUP:
			return "FUSE_SEARCH_TYPE_BY_GROUP"
		_:
			return "FUSE_SEARCH_TYPE_BY_NAME"  # 默认值

## 获取搜索范围的本地化字符串
func _get_search_scope_string() -> String:
	var key = _get_search_scope_key()
	return FuseLocalization.translate(key)

## 获取搜索范围的翻译键
func _get_search_scope_key() -> String:
	match search_scope:
		SearchScope.CHILDREN:
			return "FUSE_SEARCH_SCOPE_CHILDREN"
		SearchScope.SCENE:
			return "FUSE_SEARCH_SCOPE_SCENE"
		SearchScope.GLOBAL:
			return "FUSE_SEARCH_SCOPE_GLOBAL"
		_:
			return "FUSE_SEARCH_SCOPE_CHILDREN"  # 默认值

## 获取指令描述
func get_description() -> String:
	var type_str = _get_search_type_string()
	var scope_str = _get_search_scope_string()

	var desc = FuseLocalization.translate_format(
		"FUSE_INSTRUCTION_FIND_NODE_DESC_BASE",
		{"type": type_str, "value": search_value, "scope": scope_str}
	)

	if first_match_only:
		desc += FuseLocalization.translate("FUSE_INSTRUCTION_FIND_NODE_DESC_FIRST_MATCH")
	else:
		desc += FuseLocalization.translate("FUSE_INSTRUCTION_FIND_NODE_DESC_ALL_MATCHES")

	var var_scope_str = _get_scope_source_string()
	desc += FuseLocalization.translate_format(
		"FUSE_INSTRUCTION_FIND_NODE_DESC_VAR_TYPE",
		{"var_type": var_scope_str, "var": result_variable}
	)

	return desc
