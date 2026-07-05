@tool
@icon("res://addons/fuse/icons/builtin/Remove.png")
extends BaseInstruction
class_name QueueFreeNode

## 延迟释放节点
##
## 重构: 2026-03-03 - 添加从变量获取 NodePath 功能

## 作用域来源
enum ScopeSource {
	NEAREST,        ## 最近的作用域容器（默认）
	CUSTOM_ID,      ## 指定 scope_id
	TRIGGER_SCOPE,  ## Trigger 节点上的作用域
	TARGET_NODE     ## Target 节点上的作用域
}

# 节点来源类型
enum NodeSource {
	DIRECT,     ## 直接选择节点
	VARIABLE    ## 从变量获取 NodePath
}
var node_source: NodeSource = NodeSource.DIRECT:
	set(value):
		node_source = value
		notify_property_list_changed()
		_update_resource_name()

# 目标节点路径（直接模式）
var target_node: NodePath = NodePath(""):
	set(value):
		target_node = value
		_update_resource_name()
		notify_property_list_changed()

# 节点路径变量名（变量模式）
var target_node_variable: String = "":
	set(value):
		target_node_variable = value
		_update_resource_name()

# 节点路径变量作用域
var target_node_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		target_node_scope = value
		_update_resource_name()
		notify_property_list_changed()

## 节点路径变量作用域来源（仅当 target_node_scope == SCOPE 时使用）
var target_node_scope_source: ScopeSource = ScopeSource.NEAREST:
	set(value):
		target_node_scope_source = value
		_update_resource_name()
		notify_property_list_changed()

## 节点路径变量自定义作用域 ID（CUSTOM_ID 模式使用）
var target_node_custom_scope_id: String = "":
	set(value):
		target_node_custom_scope_id = value
		_update_resource_name()

## 节点路径变量目标节点路径（TARGET_NODE 模式使用）
var target_node_target_node_path: NodePath = NodePath(""):
	set(value):
		target_node_target_node_path = value
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

## 获取属性列表
func _get_property_list() -> Array[Dictionary]:
	var properties := []

	# Node Operation 分类
	properties.append({
		name = "Node Operation",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	# 节点来源选择
	properties.append({
		name = "node_source",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Direct,Variable",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	if node_source == NodeSource.DIRECT:
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
			name = "target_node_variable",
			type = TYPE_STRING,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		# 变量作用域
		properties.append({
			name = "target_node_scope",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "Local,Scope,Global",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		# 只在 target_node_scope == SCOPE 时显示 ScopeSource 配置
		if target_node_scope == BaseVariable.VariableScope.SCOPE:
			properties.append({
				name = "target_node_scope_source",
				type = TYPE_INT,
				hint = PROPERTY_HINT_ENUM,
				hint_string = "Nearest,Custom ID,Trigger Scope,Target Node",
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})

			# 根据作用域来源添加额外属性
			if target_node_scope_source == ScopeSource.CUSTOM_ID:
				properties.append({
					name = "target_node_custom_scope_id",
					type = TYPE_STRING,
					hint = PROPERTY_HINT_NONE,
					usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
				})
			elif target_node_scope_source == ScopeSource.TARGET_NODE:
				properties.append({
					name = "target_node_target_node_path",
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

	if node_source == NodeSource.DIRECT:
		# 直接模式
		if not target_node.is_empty():
			parts.append("'%s'" % _get_node_display_name(target_node))
		else:
			parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_QUEUE_FREE_NODE_NO_NODE"))
	else:
		# 变量模式
		if not target_node_variable.is_empty():
			var scope_str = VariableScopeUtils.enum_to_string(target_node_scope).to_upper()
			parts.append("%s [%s]" % [target_node_variable, scope_str])
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

	# 获取实际的节点路径
	var actual_node_path: NodePath

	if node_source == NodeSource.DIRECT:
		# 直接模式
		if target_node.is_empty():
			_log_error_localized("FUSE_ERROR_TARGET_NODE_EMPTY", {})
			set_error_localized("FUSE_ERROR_TARGET_NODE_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
			finished.emit()
			return
		actual_node_path = target_node
	else:
		# 变量模式：从变量获取 NodePath
		if target_node_variable.is_empty():
			_log_error_localized("FUSE_ERROR_TARGET_NODE_VARIABLE_EMPTY", {})
			set_error_localized("FUSE_ERROR_TARGET_NODE_VARIABLE_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
			finished.emit()
			return

		# 根据作用域类型获取变量值
		var node_path_value: Variant
		if target_node_scope == BaseVariable.VariableScope.SCOPE:
			# SCOPE 作用域：根据 scope_source 获取变量
			if target_node_scope_source == ScopeSource.NEAREST:
				# NEAREST 模式：使用 VariableOperations 的默认行为
				node_path_value = VariableOperations.get_variable(context, target_node_variable, BaseVariable.VariableScope.SCOPE, null)
			else:
				# 其他模式：获取指定作用域容器并读取变量
				var utils_scope_source = target_node_scope_source as VariableScopeUtils.ScopeSource
				var scope_container = VariableScopeUtils.get_scope_container_by_source(
					context,
					utils_scope_source,
					target_node_custom_scope_id,
					target_node_target_node_path
				)

				if scope_container == null:
					_log_error_localized("FUSE_ERROR_TARGET_NODE_SCOPE_CONTAINER_NOT_FOUND", {})
					set_error_localized("FUSE_ERROR_TARGET_NODE_SCOPE_CONTAINER_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {})
					finished.emit()
					return

				node_path_value = scope_container.get_variable(target_node_variable, null)
		else:
			# LOCAL 或 GLOBAL 作用域：使用 VariableOperations
			node_path_value = VariableOperations.get_variable(context, target_node_variable, target_node_scope, null)

		# 转换为 NodePath
		if node_path_value == null:
			_log_error_localized("FUSE_ERROR_TARGET_NODE_VARIABLE_NOT_FOUND", {"name": target_node_variable})
			set_error_localized("FUSE_ERROR_TARGET_NODE_VARIABLE_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {"name": target_node_variable})
			finished.emit()
			return

		# 类型转换
		actual_node_path = TypeConverter.safe_convert_to_node_path(node_path_value)
		if actual_node_path.is_empty() and not str(node_path_value).is_empty():
			_log_error_localized("FUSE_ERROR_TARGET_NODE_VARIABLE_INVALID_NODEPATH", {"value": str(node_path_value)})
			set_error_localized("FUSE_ERROR_TARGET_NODE_VARIABLE_INVALID_NODEPATH", FuseError.ErrorType.RUNTIME_ERROR, {"value": str(node_path_value)})
			finished.emit()
			return

	# 获取目标节点
	var node := context.get_node(actual_node_path)
	if not node:
		_log_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", {"node": str(actual_node_path)})
		set_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {"node": str(actual_node_path)})
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

	if node_source == NodeSource.DIRECT:
		if target_node.is_empty():
			errors.append(FuseLocalization.translate("FUSE_ERROR_TARGET_NODE_PATH_EMPTY"))
	else:
		# 变量模式验证
		if target_node_variable.is_empty():
			errors.append(FuseLocalization.translate("FUSE_ERROR_TARGET_NODE_VARIABLE_NAME_EMPTY"))

		# 验证 SCOPE 作用域需要 ScopeVariableManager
		if target_node_scope == BaseVariable.VariableScope.SCOPE:
			var manager = ScopeVariableManager.get_instance()
			if manager == null:
				errors.append(FuseLocalization.translate("FUSE_ERROR_SCOPE_MANAGER_NOT_FOUND"))

			# 验证 ScopeSource 相关参数
			var utils_scope_source = target_node_scope_source as VariableScopeUtils.ScopeSource
			errors.append_array(VariableScopeUtils.validate_scope_source_params(
				utils_scope_source,
				target_node_custom_scope_id,
				target_node_target_node_path
			))

	if delay < 0.0:
		errors.append(FuseLocalization.translate("FUSE_ERROR_DELAY_CANNOT_BE_NEGATIVE"))

	return errors

## 验证属性可见性
func _validate_property(property: Dictionary) -> void:
	# 处理直接模式下的变量相关属性
	if node_source == NodeSource.DIRECT:
		if property.name in ["target_node_variable", "target_node_scope", "target_node_scope_source", "target_node_custom_scope_id", "target_node_target_node_path"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR
	else:
		# 变量模式：隐藏直接选择节点属性
		if property.name == "target_node":
			property.usage = PROPERTY_USAGE_NO_EDITOR

	# 处理 target_node_scope 的 ScopeSource 相关属性
	var show_scope_source = node_source == NodeSource.VARIABLE and target_node_scope == BaseVariable.VariableScope.SCOPE
	if not show_scope_source:
		if property.name in ["target_node_scope_source", "target_node_custom_scope_id", "target_node_target_node_path"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR
	elif target_node_scope_source != ScopeSource.CUSTOM_ID:
		if property.name == "target_node_custom_scope_id":
			property.usage = PROPERTY_USAGE_NO_EDITOR
	elif target_node_scope_source != ScopeSource.TARGET_NODE:
		if property.name == "target_node_target_node_path":
			property.usage = PROPERTY_USAGE_NO_EDITOR

## 获取指令描述
func get_description() -> String:
	var node_desc: String

	if node_source == NodeSource.DIRECT:
		node_desc = _get_node_display_name(target_node)
	else:
		var scope_str = _get_scope_source_string()
		node_desc = "%s [%s]" % [target_node_variable, scope_str]

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
	# 根据 target_node_scope 返回不同的作用域字符串
	match target_node_scope:
		BaseVariable.VariableScope.LOCAL:
			return FuseLocalization.translate("FUSE_VARIABLE_SCOPE_LOCAL_STR")
		BaseVariable.VariableScope.GLOBAL:
			return FuseLocalization.translate("FUSE_VARIABLE_SCOPE_GLOBAL_STR")
		BaseVariable.VariableScope.SCOPE:
			# SCOPE 作用域时，使用 ScopeSource 获取具体域信息
			return VariableScopeUtils.get_scope_source_string(
				target_node_scope_source as VariableScopeUtils.ScopeSource,
				target_node_custom_scope_id,
				target_node_target_node_path
			)
		_:
			return FuseLocalization.translate("FUSE_VARIABLE_SCOPE_UNKNOWN")
