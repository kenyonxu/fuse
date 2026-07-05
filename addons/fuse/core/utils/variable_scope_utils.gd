@tool
class_name VariableScopeUtils extends RefCounted

## 变量作用域工具类
##
## 提供作用域枚举和字符串之间的转换功能，统一处理作用域相关操作。
##
## 功能：
## - 枚举与字符串互相转换
## - 作用域验证
## - 获取有效作用域列表
## - ScopeSource 支持（获取指定来源的作用域容器）

## 将作用域枚举转换为字符串
##
## 参数：
## - scope: BaseVariable.VariableScope - 作用域枚举
##
## 返回：
## - String - 作用域字符串 ("local" 或 "global")
##
## 示例：
## ```gdscript
## var scope_str = VariableScopeUtils.enum_to_string(BaseVariable.VariableScope.GLOBAL)
## # 返回: "global"
## ```
static func enum_to_string(scope: BaseVariable.VariableScope) -> String:
	match scope:
		BaseVariable.VariableScope.LOCAL:
			return "local"
		BaseVariable.VariableScope.SCOPE:
			return "scope"
		BaseVariable.VariableScope.GLOBAL:
			return "global"
		_:
			_log_warning("未知的作用域: %s，使用 LOCAL" % scope)
			return "local"

## 将字符串转换为作用域枚举
##
## 参数：
## - scope_str: String - 作用域字符串
##
## 返回：
## - BaseVariable.VariableScope - 作用域枚举
##
## 示例：
## ```gdscript
## var scope = VariableScopeUtils.string_to_enum("global")
## # 返回: BaseVariable.VariableScope.GLOBAL
## ```
static func string_to_enum(scope_str: String) -> BaseVariable.VariableScope:
	match scope_str.to_lower():
		"local":
			return BaseVariable.VariableScope.LOCAL
		"scope":
			return BaseVariable.VariableScope.SCOPE
		"global":
			return BaseVariable.VariableScope.GLOBAL
		_:
			_log_warning("未知的作用域字符串: '%s'，使用 LOCAL" % scope_str)
			return BaseVariable.VariableScope.LOCAL

## 验证作用域字符串是否有效
##
## 参数：
## - scope_str: String - 作用域字符串
##
## 返回：
## - bool - 是否有效
##
## 示例：
## ```gdscript
## VariableScopeUtils.is_valid_scope_string("local")   # true
## VariableScopeUtils.is_valid_scope_string("invalid") # false
## ```
static func is_valid_scope_string(scope_str: String) -> bool:
	var lower = scope_str.to_lower()
	return lower == "local" or lower == "scope" or lower == "global"

## @deprecated 使用 is_valid_scope_string() 代替
static func is_valid_scope(scope_str: String) -> bool:
	return is_valid_scope_string(scope_str)

## 获取所有有效的作用域名称
##
## 返回：
## - Array[String] - 作用域名称数组
##
## 示例：
## ```gdscript
## var scopes = VariableScopeUtils.get_valid_scopes()
## # 返回: ["local", "global"]
## ```
static func get_valid_scopes() -> Array[String]:
	return ["local", "scope", "global"]

## 检查作用域是否为局部作用域
##
## 参数：
## - scope: BaseVariable.VariableScope - 作用域枚举
##
## 返回：
## - bool - 是否为局部作用域
static func is_local(scope: BaseVariable.VariableScope) -> bool:
	return scope == BaseVariable.VariableScope.LOCAL

## 检查作用域是否为作用域级别（SCOPE）
##
## 参数：
## - scope: BaseVariable.VariableScope - 作用域枚举
##
## 返回：
## - bool - 是否为作用域级别
static func is_scope(scope: BaseVariable.VariableScope) -> bool:
	return scope == BaseVariable.VariableScope.SCOPE

## 检查作用域是否为全局作用域
##
## 参数：
## - scope: BaseVariable.VariableScope - 作用域枚举
##
## 返回：
## - bool - 是否为全局作用域
static func is_global(scope: BaseVariable.VariableScope) -> bool:
	return scope == BaseVariable.VariableScope.GLOBAL

## 获取作用域的显示名称（本地化友好）
##
## 参数：
## - scope: BaseVariable.VariableScope - 作用域枚举
##
## 返回：
## - String - 显示名称
static func enum_to_display_name(scope: BaseVariable.VariableScope) -> String:
	match scope:
		BaseVariable.VariableScope.LOCAL:
			return "局部变量"
		BaseVariable.VariableScope.SCOPE:
			return "作用域变量"
		BaseVariable.VariableScope.GLOBAL:
			return "全局变量"
		_:
			return "未知"

## @deprecated 使用 enum_to_display_name() 代替
static func get_display_name(scope: BaseVariable.VariableScope) -> String:
	return enum_to_display_name(scope)

## 统一日志方法
static func _log_warning(message: String):
	FuseLogger.log_warning("VariableScopeUtils", FuseLogger.LogLevel.INFO, message)

static func _log_debug(message: String):
	FuseLogger.log_debug("VariableScopeUtils", FuseLogger.LogLevel.INFO, message)

## ==================== ScopeSource 支持 ====================

## 作用域来源枚举
enum ScopeSource {
	NEAREST,        ## 最近的作用域容器（默认）
	CUSTOM_ID,      ## 指定 scope_id
	TRIGGER_SCOPE,  ## Trigger 节点上的作用域
	TARGET_NODE     ## Target 节点上的作用域
}

## 根据作用域来源获取作用域容器
##
## 参数：
## - context: ExecutionContext - 执行上下文
## - scope_source: ScopeSource - 作用域来源枚举
## - custom_scope_id: String - 自定义作用域 ID（CUSTOM_ID 模式使用）
## - target_node_path: NodePath - 目标节点路径（TARGET_NODE 模式使用）
##
## 返回：
## - ScopeVariableContainer - 找到的作用域容器，如果未找到则返回 null
##
## 示例：
## ```gdscript
## var container = VariableScopeUtils.get_scope_container_by_source(
##     context,
##     ScopeSource.CUSTOM_ID,
##     "player_scope",
##     NodePath("")
## )
## ```
static func get_scope_container_by_source(
	context: ExecutionContext,
	scope_source: ScopeSource,
	custom_scope_id: String,
	target_node_path: NodePath
) -> ScopeVariableContainer:
	if context == null:
		_log_warning("ExecutionContext 为空")
		return null

	var manager = ScopeVariableManager.get_instance()
	if manager == null:
		_log_warning("ScopeVariableManager 未找到")
		return null

	match scope_source:
		ScopeSource.NEAREST:
			# 使用工具类查找最近的作用域
			return VariableOperations.get_scope_container(context)

		ScopeSource.CUSTOM_ID:
			if custom_scope_id.is_empty():
				_log_warning("custom_scope_id 为空")
				return null
			return manager.get_scope_by_id(custom_scope_id)

		ScopeSource.TRIGGER_SCOPE:
			if context.trigger != null:
				return VariableOperations.get_scope_container(context, context.trigger)
			_log_warning("context.trigger 为空")
			return null

		ScopeSource.TARGET_NODE:
			if target_node_path.is_empty():
				_log_warning("target_node_path 为空")
				return null
			var node = context.get_node(target_node_path)
			if node == null:
				_log_warning("未找到目标节点: %s" % str(target_node_path))
				return null
			# 使用工具类从目标节点查找作用域
			return VariableOperations.get_scope_container(context, node)

		_:
			_log_warning("未知的作用域来源类型: %s" % scope_source)
			return null

## 验证 ScopeSource 相关属性的可见性
##
## 此方法用于 _validate_property() 回调中，根据当前 scope_source
## 控制 custom_scope_id 和 target_node_path 的显示/隐藏。
##
## 参数：
## - property: Dictionary - Godot 属性字典
## - scope_source: ScopeSource - 当前作用域来源
##
## 使用示例：
## ```gdscript
## func _validate_property(property: Dictionary) -> void:
##     VariableScopeUtils.validate_scope_source_property(property, scope_source)
## ```
static func validate_scope_source_property(property: Dictionary, scope_source: ScopeSource) -> void:
	match scope_source:
		ScopeSource.CUSTOM_ID:
			# CUSTOM_ID 模式：只显示 custom_scope_id，隐藏 target_node_path
			if property.name == "target_node_path":
				property.usage = PROPERTY_USAGE_NO_EDITOR

		ScopeSource.TARGET_NODE:
			# TARGET_NODE 模式：只显示 target_node_path，隐藏 custom_scope_id
			if property.name == "custom_scope_id":
				property.usage = PROPERTY_USAGE_NO_EDITOR

		_:
			# NEAREST 和 TRIGGER_SCOPE 不需要这两个参数
			if property.name == "custom_scope_id" or property.name == "target_node_path":
				property.usage = PROPERTY_USAGE_NO_EDITOR

## 验证 ScopeSource 相关参数
##
## 参数：
## - scope_source: ScopeSource - 作用域来源
## - custom_scope_id: String - 自定义作用域 ID
## - target_node_path: NodePath - 目标节点路径
##
## 返回：
## - Array[String] - 错误消息数组，如果没有错误则返回空数组
##
## 使用示例：
## ```gdscript
## func validate() -> Array[String]:
##     var errors = super.validate()
##     errors.append_array(VariableScopeUtils.validate_scope_source_params(
##         scope_source, custom_scope_id, target_node_path
##     ))
##     return errors
## ```
static func validate_scope_source_params(
	scope_source: ScopeSource,
	custom_scope_id: String,
	target_node_path: NodePath
) -> Array[String]:
	var errors: Array[String] = []

	if scope_source == ScopeSource.CUSTOM_ID and custom_scope_id.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_SCOPE_ID_EMPTY"))

	if scope_source == ScopeSource.TARGET_NODE and target_node_path.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_TARGET_NODE_PATH_EMPTY"))

	return errors

## 获取作用域来源的显示字符串
##
## 参数：
## - scope_source: ScopeSource - 作用域来源
## - custom_scope_id: String - 自定义作用域 ID
## - target_node_path: NodePath - 目标节点路径
##
## 返回：
## - String - 显示用的字符串
##
## 使用示例：
## ```gdscript
## func _update_resource_name():
##     var scope_str = VariableScopeUtils.get_scope_source_string(
##         scope_source, custom_scope_id, target_node_path
##     )
##     resource_name = "设置变量 [%s] ..." % scope_str
## ```
static func get_scope_source_string(
	scope_source: ScopeSource,
	custom_scope_id: String,
	target_node_path: NodePath
) -> String:
	match scope_source:
		ScopeSource.NEAREST:
			return FuseLocalization.translate("FUSE_SCOPE_SOURCE_NEAREST_STR")

		ScopeSource.CUSTOM_ID:
			if custom_scope_id.is_empty():
				return FuseLocalization.translate("FUSE_SCOPE_SOURCE_CUSTOM_ID_UNSET")
			return "ID:%s" % custom_scope_id

		ScopeSource.TRIGGER_SCOPE:
			return FuseLocalization.translate("FUSE_SCOPE_SOURCE_TRIGGER_SCOPE_STR")

		ScopeSource.TARGET_NODE:
			if target_node_path.is_empty():
				return FuseLocalization.translate("FUSE_SCOPE_SOURCE_TARGET_NODE_UNSET")
			var path_str = str(target_node_path)
			var display_name = path_str.get_file()
			if display_name.is_empty() or display_name == ".." or display_name == ".":
				display_name = path_str
			return FuseLocalization.translate_format("FUSE_SCOPE_SOURCE_TARGET_NODE_FORMAT", {"path": display_name})

		_:
			return FuseLocalization.translate("FUSE_SCOPE_SOURCE_UNKNOWN")

## 追加 ScopeSource 动态属性到属性列表
##
## 当 variable_scope == SCOPE 时,在 _get_property_list() 中调用此方法,
## 自动注入 scope_source / custom_scope_id / target_node_path 的 Inspector 显示。
##
## 使用示例:
## ```gdscript
## func _get_property_list() -> Array[Dictionary]:
##     var properties := []
##     ...
##     if variable_scope == BaseVariable.VariableScope.SCOPE:
##         VariableScopeUtils.append_scope_source_properties(properties, scope_source)
##     return properties
## ```
static func append_scope_source_properties(properties: Array, scope_source: ScopeSource) -> void:
	properties.append({
		name = "Scope Source",
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
