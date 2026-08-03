@tool
@icon("res://addons/fuse/icons/builtin/Remove.png")
extends BaseInstruction
class_name QueueFreeNode

## 延迟释放节点
##
## 重构: 2026-03-03 - 添加从变量获取 NodePath 功能
## 命名统一: 2026-08-03 - node_source 枚举改为 use_variable_for_target 开关

## 作用域来源
enum ScopeSource {
	NEAREST,        ## 最近的作用域容器（默认）
	CUSTOM_ID,      ## 指定 scope_id
	TRIGGER_SCOPE,  ## Trigger 节点上的作用域
	TARGET_NODE     ## Target 节点上的作用域
}

# 目标节点路径（直接模式）
var target_node: NodePath = NodePath(""):
	set(value):
		target_node = value
		_update_resource_name()
		notify_property_list_changed()

## 是否从变量获取目标节点
var use_variable_for_target: bool = false:
	set(value):
		use_variable_for_target = value
		notify_property_list_changed()
		_update_resource_name()

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

# 延迟时间（秒）
var delay: float = 0.0

# 定时器
var _timer: SceneTreeTimer = null

## 获取指令元数据（用于指令选择器）
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_QUEUE_FREE_NODE_NAME"
	metadata.category_key = "FUSE_CATEGORY_NODE_OPERATIONS"
	metadata.description_key = "FUSE_INSTRUCTION_QUEUE_FREE_NODE_DESC"
	metadata.keywords = ["queue free", "destroy", "remove", "delete", "释放", "删除", "销毁"]
	# 设置指令选择器图标
	metadata.builtin_icon = "Remove"
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
	# Node Operation 分类
	properties.append({
		name = "Node Operation",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	# 是否从变量获取目标节点
	properties.append({
		name = "use_variable_for_target",
		type = TYPE_BOOL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	if not use_variable_for_target:
		# 直接模式：目标节点
		properties.append({
			name = "target_node",
			type = TYPE_NODE_PATH,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})
	else:
		# 变量模式：变量名
		properties.append({
			name = "target_variable",
			type = TYPE_STRING,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		# 变量作用域
		properties.append({
			name = "target_scope",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "Local,Scope,Global",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		# 只在 target_scope == SCOPE 时显示 ScopeSource 配置
		if target_scope == BaseVariable.VariableScope.SCOPE:
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

	# Timing 分类
	properties.append({
		name = "Timing",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	# 延迟时间
	properties.append({
		name = "delay",
		type = TYPE_FLOAT,
		hint = PROPERTY_HINT_RANGE,
		hint_string = "0,10,0.1,or_greater",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	return properties

## 更新资源名称
func _update_resource_name():
	var parts = []

	parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_QUEUE_FREE_NODE_ACTION"))

	if not use_variable_for_target:
		# 直接模式
		if not target_node.is_empty():
			parts.append("'%s'" % _get_node_display_name(target_node))
		else:
			parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_QUEUE_FREE_NODE_NO_NODE"))
	else:
		# 变量模式
		if not target_variable.is_empty():
			var scope_str = _get_scope_source_string()
			parts.append("%s [%s]" % [target_variable, scope_str])
		else:
			parts.append(FuseLocalization.translate("FUSE_VALUE_VARIABLE_EMPTY"))

	if delay > 0.0:
		parts.append(FuseLocalization.translate_format("FUSE_INSTRUCTION_QUEUE_FREE_NODE_DELAY", {
			"delay": str(delay)
		}))

	resource_name = " ".join(parts)

## 执行指令
func execute(context: ExecutionContext):
	_start_execution(context)

	# 获取目标节点
	var node: Node
	if use_variable_for_target:
		node = _resolve_node(
			context,
			use_variable_for_target,
			target_node,
			target_variable,
			target_scope,
			target_scope_source,
			target_custom_scope_id,
			target_target_node_path,
			"FUSE_ERROR_TARGET_NODE_VARIABLE_EMPTY",
			"FUSE_ERROR_TARGET_NODE_EMPTY",
			"FUSE_ERROR_TARGET_NODE_NOT_FOUND"
		)
		if node == null:
			finished.emit()
			return
	else:
		if target_node.is_empty():
			_log_error_localized("FUSE_ERROR_TARGET_NODE_EMPTY", {})
			set_error_localized("FUSE_ERROR_TARGET_NODE_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
			finished.emit()
			return
		node = context.get_node(target_node)
		if not node:
			_log_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", {"node": str(target_node)})
			set_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {"node": str(target_node)})
			finished.emit()
			return

	if delay <= 0.0:
		# 立即释放
		node.queue_free()
		_log_info_localized("FUSE_LOG_NODE_QUEUED_IMMEDIATE", {"node": node.name})
		_on_execution_completed()
	else:
		# 延迟释放（异步）
		var scene_tree = Engine.get_main_loop()
		if scene_tree:
			_timer = scene_tree.create_timer(delay)
			_timer.timeout.connect(_on_timer_timeout.bind(node, context))
			_log_info_localized("FUSE_LOG_NODE_WILL_DELETE_DELAY", {
				"node": node.name,
				"delay": str(delay)
			})
		else:
			_log_error_localized("FUSE_ERROR_NO_SCENE_TREE", {})
			finished.emit()

## 定时器超时回调
func _on_timer_timeout(node: Node, context: ExecutionContext) -> void:
	if is_instance_valid(node):
		node.queue_free()
		_log_info_localized("FUSE_LOG_NODE_DELETED_AFTER_DELAY", {"node": node.name})

	finished.emit()

## 清理资源
func _cleanup_resources() -> void:
	if _timer and is_instance_valid(_timer):
		if _timer.timeout.is_connected(_on_timer_timeout):
			_timer.timeout.disconnect(_on_timer_timeout)
		_timer = null

## 验证指令参数
func validate() -> Array[String]:
	var errors = super.validate()

	if use_variable_for_target:
		if target_variable.is_empty():
			errors.append(FuseLocalization.translate("FUSE_ERROR_TARGET_NODE_VARIABLE_NAME_EMPTY"))
		if target_scope == BaseVariable.VariableScope.SCOPE:
			var manager = ScopeVariableManager.get_instance()
			if manager == null:
				errors.append(FuseLocalization.translate("FUSE_ERROR_SCOPE_MANAGER_NOT_FOUND"))
			var utils_scope_source = target_scope_source as VariableScopeUtils.ScopeSource
			errors.append_array(VariableScopeUtils.validate_scope_source_params(
				utils_scope_source,
				target_custom_scope_id,
				target_target_node_path
			))
	else:
		if target_node.is_empty():
			errors.append(FuseLocalization.translate("FUSE_ERROR_TARGET_NODE_PATH_EMPTY"))

	if delay < 0.0:
		errors.append(FuseLocalization.translate("FUSE_ERROR_DELAY_CANNOT_BE_NEGATIVE"))

	return errors

## 验证属性可见性
func _validate_property(property: Dictionary) -> void:
	# 处理直接模式下的变量相关属性
	if not use_variable_for_target:
		if property.name in ["target_variable", "target_scope", "target_scope_source", "target_custom_scope_id", "target_target_node_path"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR
	else:
		# 变量模式：隐藏直接选择节点属性
		if property.name == "target_node":
			property.usage = PROPERTY_USAGE_NO_EDITOR

	# 处理 target_scope 的 ScopeSource 相关属性
	var show_scope_source = use_variable_for_target and target_scope == BaseVariable.VariableScope.SCOPE
	if not show_scope_source:
		if property.name in ["target_scope_source", "target_custom_scope_id", "target_target_node_path"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR
	elif target_scope_source != ScopeSource.CUSTOM_ID:
		if property.name == "target_custom_scope_id":
			property.usage = PROPERTY_USAGE_NO_EDITOR
	elif target_scope_source != ScopeSource.TARGET_NODE:
		if property.name == "target_target_node_path":
			property.usage = PROPERTY_USAGE_NO_EDITOR

## 动态属性设置（含向后兼容旧属性名）
func _set(property: StringName, value: Variant) -> bool:
	# 向后兼容：旧 node_source 枚举（DIRECT=0/VARIABLE=1）→ use_variable_for_target
	if property == "node_source":
		use_variable_for_target = (int(value) != 0)
		notify_property_list_changed()
		_update_resource_name()
		return true
	# 向后兼容：旧 target_node_* 属性名
	if property == "target_node_variable":
		target_variable = value
		_update_resource_name()
		return true
	if property == "target_node_scope":
		target_scope = value
		notify_property_list_changed()
		_update_resource_name()
		return true
	if property == "target_node_scope_source":
		target_scope_source = value
		notify_property_list_changed()
		_update_resource_name()
		return true
	if property == "target_node_custom_scope_id":
		target_custom_scope_id = value
		_update_resource_name()
		return true
	if property == "target_node_target_node_path":
		target_target_node_path = value
		_update_resource_name()
		return true
	# 新属性：触发刷新
	if property in ["use_variable_for_target", "target_scope", "target_scope_source"]:
		set(property, value)
		notify_property_list_changed()
		_update_resource_name()
		return true
	return false

## 获取指令描述
func get_description() -> String:
	var node_desc: String

	if not use_variable_for_target:
		node_desc = _get_node_display_name(target_node) if not target_node.is_empty() else FuseLocalization.translate("FUSE_INSTRUCTION_QUEUE_FREE_NODE_NO_NODE")
	else:
		var scope_str = _get_scope_source_string()
		if not target_variable.is_empty():
			node_desc = "%s [%s]" % [target_variable, scope_str]
		else:
			node_desc = FuseLocalization.translate("FUSE_VALUE_VARIABLE_EMPTY")

	if delay > 0.0:
		return FuseLocalization.translate_format("FUSE_INSTRUCTION_QUEUE_FREE_NODE_DESC_WITH_DELAY", {
			"node": node_desc,
			"delay": str(delay)
		})
	else:
		return FuseLocalization.translate_format("FUSE_INSTRUCTION_QUEUE_FREE_NODE_DESC", {
			"node": node_desc
		})

## 获取作用域来源字符串
func _get_scope_source_string() -> String:
	# 根据 target_scope 返回不同的作用域字符串
	match target_scope:
		BaseVariable.VariableScope.LOCAL:
			return FuseLocalization.translate("FUSE_VARIABLE_SCOPE_LOCAL_STR")
		BaseVariable.VariableScope.GLOBAL:
			return FuseLocalization.translate("FUSE_VARIABLE_SCOPE_GLOBAL_STR")
		BaseVariable.VariableScope.SCOPE:
			# SCOPE 作用域时，使用 ScopeSource 获取具体域信息
			return VariableScopeUtils.get_scope_source_string(
				target_scope_source as VariableScopeUtils.ScopeSource,
				target_custom_scope_id,
				target_target_node_path
			)
		_:
			return FuseLocalization.translate("FUSE_VARIABLE_SCOPE_UNKNOWN")

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
