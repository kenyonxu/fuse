@tool
@icon("res://addons/fuse/icons/builtin/Play.png")
extends BaseInstruction
class_name RunRunner

## 执行 Runner 指令
##
## 触发场景中 Runner 节点的 run() 方法，支持同步和异步两种执行模式。
##
## 功能：
## - 通过 NodePath 指定目标 Runner 节点
## - 支持等待执行完成（异步模式）或立即返回（同步模式）
## - 可选：传递上下文节点参数
## - 可选：将执行结果存储到变量

## 执行结果枚举
enum ExecutionResult {
	SUCCESS,      ## 执行成功
	FAILED,       ## 执行失败
	CANCELED,     ## 执行取消
	NOT_RUNNING   ## Runner 未运行
}

## 作用域来源（仅当 result_variable_scope == SCOPE 时使用）
enum ScopeSource {
	NEAREST,        ## 最近的作用域容器（默认）
	CUSTOM_ID,      ## 指定 scope_id
	TRIGGER_SCOPE,  ## Trigger 节点上的作用域
	TARGET_NODE     ## Target 节点上的作用域
}

# 关键：实现这个静态方法，用于指令选择器
static func _get_instruction_metadata() -> InstructionMetadata:
	metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_RUN_RUNNER_NAME"
	metadata.category_key = "FUSE_CATEGORY_FLOW_CONTROL"
	metadata.description_key = "FUSE_INSTRUCTION_RUN_RUNNER_DESC"
	metadata.keywords = ["runner", "执行", "触发", "action", "run", "execute", "trigger", "runner"]
	metadata.builtin_icon = "Play"
	return metadata

## 目标 Runner 节点路径
var target_runner: NodePath = NodePath(""):
	set(value):
		target_runner = value
		_update_resource_name()

## 是否等待执行完成
var wait_for_completion: bool = true:
	set(value):
		wait_for_completion = value
		_update_resource_name()
		notify_property_list_changed()

## 上下文节点路径（可选）
var context_node_path: NodePath = NodePath(""):
	set(value):
		context_node_path = value
		_update_resource_name()

## 是否存储执行结果
var store_result: bool = false:
	set(value):
		store_result = value
		_update_resource_name()
		notify_property_list_changed()

## 结果变量名
var result_variable_name: String = "":
	set(value):
		result_variable_name = value
		_update_resource_name()

## 结果变量作用域
var result_variable_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		result_variable_scope = value
		_update_resource_name()
		notify_property_list_changed()

## 作用域来源（仅当 result_variable_scope == SCOPE 时使用）
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

## 内部状态
var _connected_runner: Runner = null
var _execution_result: ExecutionResult = ExecutionResult.NOT_RUNNING
var _execution_context: ExecutionContext = null

func _init():
	# 此指令可能是异步的（当 wait_for_completion == true 时）
	_is_synchronous_hint = false
	_sync_hint_manually_set = true

## 设置指令元数据
func _setup_metadata():
	pass

## 获取属性列表
func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	# Runner 配置分类
	properties.append({
		name = "Runner",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	# 目标 Runner 节点
	properties.append({
		name = "target_runner",
		type = TYPE_NODE_PATH,
		hint = PROPERTY_HINT_NODE_PATH_VALID_TYPES,
		hint_string = "Runner",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 是否等待完成
	properties.append({
		name = "wait_for_completion",
		type = TYPE_BOOL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 上下文节点（可选）
	properties.append({
		name = "context_node_path",
		type = TYPE_NODE_PATH,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 结果存储分类
	properties.append({
		name = "Result",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	# 是否存储结果
	properties.append({
		name = "store_result",
		type = TYPE_BOOL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	if store_result:
		# 结果变量名
		properties.append({
			name = "result_variable_name",
			type = TYPE_STRING,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		# 结果变量作用域
		properties.append({
			name = "result_variable_scope",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "Local,Scope,Global",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		# 只在 result_variable_scope == SCOPE 时显示 ScopeSource 配置
		if result_variable_scope == BaseVariable.VariableScope.SCOPE:
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
	var parts := []
	parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_RUN_RUNNER_RESOURCE_BASE"))

	if target_runner.is_empty():
		parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_RUN_RUNNER_NO_TARGET"))
	else:
		parts.append("'%s'" % str(target_runner))

	if wait_for_completion:
		parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_RUN_RUNNER_WAITING"))
	else:
		parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_RUN_RUNNER_IMMEDIATE"))

	if store_result and not result_variable_name.is_empty():
		var scope_str = _get_scope_source_string()
		parts.append("→ %s [%s]" % [result_variable_name, scope_str])

	resource_name = " ".join(parts)

## 获取作用域来源字符串
func _get_scope_source_string() -> String:
	match result_variable_scope:
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

	# 保存上下文引用（用于异步回调）
	_execution_context = context

	# 验证目标 Runner 路径
	if target_runner.is_empty():
		_log_error_localized("FUSE_ERROR_TARGET_NODE_EMPTY", {})
		set_error_localized("FUSE_ERROR_TARGET_NODE_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
		finished.emit()
		return

	# 获取目标 Runner 节点
	var runner_node = context.get_node(target_runner)
	if runner_node == null:
		_log_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", {"node": str(target_runner)})
		set_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {"node": str(target_runner)})
		finished.emit()
		return

	# 验证节点类型
	if not runner_node is Runner:
		_log_error_localized("FUSE_ERROR_NODE_NOT_RUNNER", {"node": runner_node.name})
		set_error_localized("FUSE_ERROR_NODE_NOT_RUNNER", FuseError.ErrorType.RUNTIME_ERROR, {"node": runner_node.name})
		finished.emit()
		return

	_connected_runner = runner_node

	# 检查 Runner 是否正在运行
	if _connected_runner.is_running():
		_log_warning_localized("FUSE_WARNING_RUNNER_ALREADY_RUNNING", {"runner": _connected_runner.name})
		# 设置结果并继续
		_execution_result = ExecutionResult.NOT_RUNNING
		_store_result_if_needed(context)
		_on_execution_completed()
		return

	# 获取上下文节点（可选）
	var context_node: Node = null
	if not context_node_path.is_empty():
		context_node = context.get_node(context_node_path)

	if wait_for_completion:
		# 异步模式：连接信号并等待完成
		_connect_runner_signals()
		_connected_runner.run(context_node)
	else:
		# 同步模式：立即执行并返回
		_connected_runner.run(context_node)
		_execution_result = ExecutionResult.SUCCESS
		_store_result_if_needed(context)
		_on_execution_completed()

## 连接 Runner 信号
func _connect_runner_signals():
	if _connected_runner == null:
		return

	if not _connected_runner.execution_completed.is_connected(_on_runner_completed):
		_connected_runner.execution_completed.connect(_on_runner_completed)

	if not _connected_runner.execution_failed.is_connected(_on_runner_failed):
		_connected_runner.execution_failed.connect(_on_runner_failed)

	if not _connected_runner.execution_canceled.is_connected(_on_runner_canceled):
		_connected_runner.execution_canceled.connect(_on_runner_canceled)

## 断开 Runner 信号
func _disconnect_runner_signals():
	if _connected_runner == null:
		return

	if _connected_runner.execution_completed.is_connected(_on_runner_completed):
		_connected_runner.execution_completed.disconnect(_on_runner_completed)

	if _connected_runner.execution_failed.is_connected(_on_runner_failed):
		_connected_runner.execution_failed.disconnect(_on_runner_failed)

	if _connected_runner.execution_canceled.is_connected(_on_runner_canceled):
		_connected_runner.execution_canceled.disconnect(_on_runner_canceled)

## Runner 执行完成回调
func _on_runner_completed(total_time: float):
	_execution_result = ExecutionResult.SUCCESS
	_disconnect_runner_signals()
	_store_result_if_needed(_execution_context)
	_log_info_localized("FUSE_LOG_RUNNER_COMPLETED", {"runner": _connected_runner.name, "time": "%.3f" % total_time})
	_on_execution_completed()

## Runner 执行失败回调
func _on_runner_failed(error_message: String):
	_execution_result = ExecutionResult.FAILED
	_disconnect_runner_signals()
	_store_result_if_needed(_execution_context)
	_log_error_localized("FUSE_LOG_RUNNER_FAILED", {"runner": _connected_runner.name, "error": error_message})
	_on_execution_completed()

## Runner 执行取消回调
func _on_runner_canceled(reason: String):
	_execution_result = ExecutionResult.CANCELED
	_disconnect_runner_signals()
	_store_result_if_needed(_execution_context)
	_log_debug_localized("FUSE_LOG_RUNNER_CANCELED", {"runner": _connected_runner.name, "reason": reason})
	_on_execution_completed()

## 存储执行结果到变量
func _store_result_if_needed(context: ExecutionContext):
	if not store_result or result_variable_name.is_empty():
		return

	if context == null:
		return

	var result_string := _get_result_string()

	match result_variable_scope:
		BaseVariable.VariableScope.LOCAL:
			VariableOperations.set_variable(context, result_variable_name, BaseVariable.VariableScope.LOCAL, result_string)

		BaseVariable.VariableScope.SCOPE:
			if scope_source == ScopeSource.NEAREST:
				VariableOperations.set_variable(context, result_variable_name, BaseVariable.VariableScope.SCOPE, result_string)
			else:
				var utils_scope_source = scope_source as VariableScopeUtils.ScopeSource
				var scope_container = VariableScopeUtils.get_scope_container_by_source(
					context,
					utils_scope_source,
					custom_scope_id,
					target_node_path
				)

				if scope_container != null:
					scope_container.set_variable(result_variable_name, result_string)

		BaseVariable.VariableScope.GLOBAL:
			VariableOperations.set_variable(context, result_variable_name, BaseVariable.VariableScope.GLOBAL, result_string)

## 获取执行结果字符串
func _get_result_string() -> String:
	match _execution_result:
		ExecutionResult.SUCCESS:
			return "SUCCESS"
		ExecutionResult.FAILED:
			return "FAILED"
		ExecutionResult.CANCELED:
			return "CANCELED"
		ExecutionResult.NOT_RUNNING:
			return "NOT_RUNNING"
		_:
			return "UNKNOWN"

## 验证指令参数
func validate() -> Array[String]:
	var errors = super.validate()

	if target_runner.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_TARGET_NODE_EMPTY"))

	if store_result and result_variable_name.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_RESULT_VAR_NAME_EMPTY"))

	# 验证 SCOPE 作用域需要 ScopeVariableManager
	if store_result and result_variable_scope == BaseVariable.VariableScope.SCOPE:
		var manager = ScopeVariableManager.get_instance()
		if manager == null:
			errors.append(FuseLocalization.translate("FUSE_ERROR_SCOPE_MANAGER_NOT_FOUND"))

		# 验证 ScopeSource 相关参数
		var utils_scope_source = scope_source as VariableScopeUtils.ScopeSource
		errors.append_array(VariableScopeUtils.validate_scope_source_params(
			utils_scope_source,
			custom_scope_id,
			target_node_path
		))

	return errors

## 验证属性可见性
func _validate_property(property: Dictionary) -> void:
	# 只在 store_result == true 时显示结果存储相关属性
	if not store_result:
		if property.name in ["result_variable_name", "result_variable_scope", "scope_source", "custom_scope_id", "target_node_path"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR
		return

	# 只在 SCOPE 作用域时验证 ScopeSource 相关属性
	if result_variable_scope == BaseVariable.VariableScope.SCOPE:
		VariableScopeUtils.validate_scope_source_property(property, scope_source as VariableScopeUtils.ScopeSource)
	else:
		# 非 SCOPE 作用域时隐藏 ScopeSource 相关属性
		if property.name in ["scope_source", "custom_scope_id", "target_node_path"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR

## 获取指令描述
func get_description() -> String:
	var target_str = str(target_runner) if not target_runner.is_empty() else FuseLocalization.translate("FUSE_INSTRUCTION_RUN_RUNNER_NO_TARGET")
	var mode_str = FuseLocalization.translate("FUSE_INSTRUCTION_RUN_RUNNER_WAITING") if wait_for_completion else FuseLocalization.translate("FUSE_INSTRUCTION_RUN_RUNNER_IMMEDIATE")

	var desc = FuseLocalization.translate_format("FUSE_INSTRUCTION_RUN_RUNNER_DESC_FORMAT", {
		"target": target_str,
		"mode": mode_str
	})

	if store_result and not result_variable_name.is_empty():
		var scope_str = _get_scope_source_string()
		desc += " → %s [%s]" % [result_variable_name, scope_str]

	return desc

## 取消指令执行
func cancel():
	# 断开信号连接
	_disconnect_runner_signals()

	# 如果正在等待完成且 Runner 正在运行，取消 Runner
	if wait_for_completion and _connected_runner and _connected_runner.is_running():
		_connected_runner.cancel(FuseLocalization.translate("FUSE_LOG_INSTRUCTION_CANCELLED"))

	_connected_runner = null
	_execution_result = ExecutionResult.CANCELED

	super.cancel()

## 资源清理
func _cleanup_resources():
	super._cleanup_resources()

	_disconnect_runner_signals()
	_connected_runner = null
	_execution_result = ExecutionResult.NOT_RUNNING
	_log_debug_localized("FUSE_LOG_CLEANUP_COMPLETE", {"component": "RunRunner"})
