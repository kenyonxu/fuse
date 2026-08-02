@tool
@icon("res://addons/fuse/icons/builtin/Loop.png")
extends BaseInstruction
class_name WhileLoop

## While Loop 指令
##
## 当条件为真时重复执行（支持最大迭代次数限制）。
## 支持嵌套循环、break/continue 控制。
## 支持同步和异步两种执行模式。
##
## 重构变量系统: 2026-02-09 - 使用 VariableOperations 统一变量访问

## 指令序列执行模式枚举
enum SequenceMode {
	SYNCHRONOUS,  ## 同步执行，不等待指令完成
	ASYNCHRONOUS  ## 异步执行，等待每个指令完成后再继续
}

## 指令序列执行模式（默认异步，确保子指令正确执行）
@export var sequence_mode: SequenceMode = SequenceMode.ASYNCHRONOUS:
	set(value):
		sequence_mode = value
		_update_resource_name()

## 作用域来源枚举
enum ScopeSource {
	NEAREST,        ## 最近的作用域容器（默认）
	CUSTOM_ID,      ## 指定 scope_id
	TRIGGER_SCOPE,  ## Trigger 节点上的作用域
	TARGET_NODE     ## Target 节点上的作用域
}

# 条件变量名
var condition_variable: String = ""

# 变量作用域（LOCAL/SCOPE/GLOBAL）
var variable_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		if variable_scope != value:
			variable_scope = value
			_update_resource_name()
			notify_property_list_changed()

## 作用域来源（仅当 variable_scope == SCOPE 时使用）
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

# 条件检查类型
enum ConditionCheck {
	IS_TRUE,
	IS_FALSE,
	IS_NOT_NULL
}
var condition_check: ConditionCheck = ConditionCheck.IS_TRUE

# 最大迭代次数（防止死循环）
var max_iterations: int = 1000

# 嵌套指令列表
var loop_instructions: Array[BaseInstruction] = []

## 状态迁移到 ExecutionContext.custom_data（2026-02-03）
## 状态键: "loop_whileloop_current_iteration"
## 避免资源共享导致的状态污染问题
##
## RuntimeInstructionInstance 架构迁移（2026-03-10）
## 支持独立运行时状态，解决并发执行状态冲突

func _init():
	# 🔧 关键修复：明确声明此指令是异步的
	# WhileLoop 指令使用回调机制（信号连接）而非 await，所以源码检测无法正确识别
	_is_synchronous_hint = false
	_sync_hint_manually_set = true

## 获取指令元数据（用于指令选择器）
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_WHILE_LOOP_NAME"
	metadata.category_key = "FUSE_CATEGORY_FLOW_CONTROL"
	metadata.description_key = "FUSE_INSTRUCTION_WHILE_LOOP_DESC"
	metadata.keywords = ["循环", "while", "条件", "重复", "condition", "repeat", "loop"]
	metadata.builtin_icon = "Loop"
	return metadata

## 设置指令元数据
func _setup_metadata():
	pass

## 获取属性列表
func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	# Loop 分类
	properties.append({
		name = "Loop",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "condition_variable",
		type = TYPE_STRING,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	properties.append({
		name = "variable_scope",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Local,Scope,Global",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 只在 variable_scope == SCOPE 时显示 ScopeSource 配置
	if variable_scope == BaseVariable.VariableScope.SCOPE:
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

	properties.append({
		name = "condition_check",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "IsTrue,IsFalse,IsNotNull",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# Safety 分类
	properties.append({
		name = "Safety",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "max_iterations",
		type = TYPE_INT,
		hint = PROPERTY_HINT_RANGE,
		hint_string = "1,100000,1",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# Loop Instructions 分类
	properties.append({
		name = "Loop Instructions",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "loop_instructions",
		type = TYPE_ARRAY,
		hint = PROPERTY_HINT_RESOURCE_TYPE,
		hint_string = "BaseInstruction",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	return properties

## 更新资源名称
func _update_resource_name():
	var check_key := ""
	match condition_check:
		ConditionCheck.IS_TRUE:
			check_key = "FUSE_INSTRUCTION_WHILE_LOOP_CHECK_TRUE"
		ConditionCheck.IS_FALSE:
			check_key = "FUSE_INSTRUCTION_WHILE_LOOP_CHECK_FALSE"
		ConditionCheck.IS_NOT_NULL:
			check_key = "FUSE_INSTRUCTION_WHILE_LOOP_CHECK_NOT_NULL"

	var check_str = FuseLocalization.translate(check_key)
	var var_str = condition_variable if not condition_variable.is_empty() else FuseLocalization.translate("FUSE_INSTRUCTION_WHILE_LOOP_NO_VAR")
	var scope_str = _get_scope_source_string()

	var instruction_count = loop_instructions.size()
	var count_str = FuseLocalization.translate_format("FUSE_INSTRUCTION_WHILE_LOOP_INSTRUCTION_COUNT", {"count": instruction_count})

	# 显示执行模式
	var mode_key = "FUSE_INSTRUCTION_IF_ELSE_MODE_SYNC" if sequence_mode == SequenceMode.SYNCHRONOUS else "FUSE_INSTRUCTION_IF_ELSE_MODE_ASYNC"
	var mode_str = "[%s]" % FuseLocalization.translate(mode_key)

	resource_name = "While %s(%s [%s]) %s %s" % [check_str, var_str, scope_str, count_str, mode_str]

## 获取作用域来源字符串
func _get_scope_source_string() -> String:
	match variable_scope:
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

## 动态属性设置（支持属性刷新）
func _set(property: StringName, value: Variant) -> bool:
	if property == "condition_variable" or property == "condition_check" or property == "variable_scope":
		_update_resource_name()
		return false

	if property == "loop_instructions":
		loop_instructions = value
		_update_resource_name()
		return false

	return false

## 执行指令
func execute(context: ExecutionContext):
	_start_execution(context)

	_log_debug_localized("FUSE_LOG_INSTRUCTION_START", {"instruction": "While Loop"})

	# 验证条件变量名
	if condition_variable.is_empty():
		_log_error_localized("FUSE_ERROR_CONDITION_VARIABLE_EMPTY", {})
		set_error_localized("FUSE_ERROR_CONDITION_VARIABLE_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
		finished.emit()
		return

	# 验证最大迭代次数
	if max_iterations <= 0:
		_log_error_localized("FUSE_ERROR_MAX_ITERATIONS_INVALID", {})
		set_error_localized("FUSE_ERROR_MAX_ITERATIONS_INVALID", FuseError.ErrorType.VALIDATION_ERROR, {})
		finished.emit()
		return

	# 保存外层循环标志并开始新循环（使用栈管理）
	context.push_loop_flags()

	# 根据执行模式选择执行方式
	if sequence_mode == SequenceMode.SYNCHRONOUS:
		_execute_loop_synchronous(context)
	else:
		_execute_loop_asynchronous(context)

## 同步执行循环
func _execute_loop_synchronous(context: ExecutionContext):
	# 执行循环
	_log_info_localized("FUSE_LOG_WHILE_LOOP_START", {})

	# 初始化迭代次数到 ExecutionContext.custom_data
	context.set_custom_data("loop_whileloop_current_iteration", 0)
	var condition_met := true

	while context.get_custom_data("loop_whileloop_current_iteration", 0) < max_iterations:
		var current_iteration = context.get_custom_data("loop_whileloop_current_iteration", 0)

		# 检查 break 标志
		if context.should_break_loop():
			_log_info_localized("FUSE_LOG_BREAK_DETECTED_WHILE", {"iteration": str(current_iteration)})
			break

		# 检查 continue 标志
		if context.should_continue_loop():
			_log_info_localized("FUSE_LOG_CONTINUE_DETECTED_WHILE", {"iteration": str(current_iteration)})
			context.clear_loop_flags()
			context.set_custom_data("loop_whileloop_current_iteration", current_iteration + 1)
			continue

		# 检查条件
		var condition_value = _get_condition_value(context)
		if condition_value == null and not VariableOperations.has_variable(context, condition_variable, variable_scope):
			_log_error_localized("FUSE_ERROR_VAR_NOT_FOUND", {"variable": condition_variable})
			set_error_localized("FUSE_ERROR_VAR_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {"variable": condition_variable})
			break
		condition_met = _check_condition(condition_value)

		_log_debug_localized("FUSE_LOG_WHILE_LOOP_CONDITION_CHECK", {
			"variable": condition_variable,
			"value": condition_value
		})

		if not condition_met:
			_log_debug_localized("FUSE_LOG_WHILE_LOOP_CONDITION_NOT_MET", {})
			break

		_log_debug_localized("FUSE_LOG_WHILE_LOOP_CONDITION_MET", {})

		# 执行嵌套指令（同步）
		_log_debug_localized("FUSE_LOG_WHILE_LOOP_ITERATION", {
			"current": current_iteration + 1,
			"max": max_iterations
		})
		_execute_instructions_synchronous(context)

		# 增加迭代次数
		context.set_custom_data("loop_whileloop_current_iteration", current_iteration + 1)

		# 检查 break 标志（可能在循环体中被设置）
		if context.should_break_loop():
			_log_info_localized("FUSE_LOG_BREAK_DETECTED_WHILE", {"iteration": str(current_iteration + 1)})
			break

	# 检查是否达到最大迭代次数
	var final_iteration = context.get_custom_data("loop_whileloop_current_iteration", 0)
	if final_iteration >= max_iterations:
		_log_warning_localized("FUSE_WARNING_MAX_ITERATIONS_REACHED", {})

	_log_info_localized("FUSE_LOG_WHILE_LOOP_COMPLETE", {"count": final_iteration})

	# 恢复外层循环标志（使用栈管理）
	context.pop_loop_flags()

	_on_execution_completed()

## 异步执行循环
func _execute_loop_asynchronous(context: ExecutionContext):
	# 执行循环
	_log_info_localized("FUSE_LOG_WHILE_LOOP_START", {})

	# 初始化迭代次数到 ExecutionContext.custom_data
	context.set_custom_data("loop_whileloop_current_iteration", 0)
	var condition_met := true

	while context.get_custom_data("loop_whileloop_current_iteration", 0) < max_iterations:
		var current_iteration = context.get_custom_data("loop_whileloop_current_iteration", 0)

		# 检查 break 标志
		if context.should_break_loop():
			_log_info_localized("FUSE_LOG_BREAK_DETECTED_WHILE", {"iteration": str(current_iteration)})
			break

		# 检查 continue 标志
		if context.should_continue_loop():
			_log_info_localized("FUSE_LOG_CONTINUE_DETECTED_WHILE", {"iteration": str(current_iteration)})
			context.clear_loop_flags()
			context.set_custom_data("loop_whileloop_current_iteration", current_iteration + 1)
			continue

		# 检查条件
		var condition_value = _get_condition_value(context)
		if condition_value == null and not VariableOperations.has_variable(context, condition_variable, variable_scope):
			_log_error_localized("FUSE_ERROR_VAR_NOT_FOUND", {"variable": condition_variable})
			set_error_localized("FUSE_ERROR_VAR_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {"variable": condition_variable})
			break
		condition_met = _check_condition(condition_value)

		_log_debug_localized("FUSE_LOG_WHILE_LOOP_CONDITION_CHECK", {
			"variable": condition_variable,
			"value": condition_value
		})

		if not condition_met:
			_log_debug_localized("FUSE_LOG_WHILE_LOOP_CONDITION_NOT_MET", {})
			break

		_log_debug_localized("FUSE_LOG_WHILE_LOOP_CONDITION_MET", {})

		# 执行嵌套指令（异步）
		_log_debug_localized("FUSE_LOG_WHILE_LOOP_ITERATION", {
			"current": current_iteration + 1,
			"max": max_iterations
		})
		await _execute_instructions_asynchronous(context)

		# 增加迭代次数
		context.set_custom_data("loop_whileloop_current_iteration", current_iteration + 1)

		# 检查 break 标志（可能在循环体中被设置）
		if context.should_break_loop():
			_log_info_localized("FUSE_LOG_BREAK_DETECTED_WHILE", {"iteration": str(current_iteration + 1)})
			break

	# 检查是否达到最大迭代次数
	var final_iteration = context.get_custom_data("loop_whileloop_current_iteration", 0)
	if final_iteration >= max_iterations:
		_log_warning_localized("FUSE_WARNING_MAX_ITERATIONS_REACHED", {})

	_log_info_localized("FUSE_LOG_WHILE_LOOP_COMPLETE", {"count": final_iteration})

	# 恢复外层循环标志（使用栈管理）
	context.pop_loop_flags()

	_on_execution_completed()

## 获取条件变量值
func _get_condition_value(context: ExecutionContext) -> Variant:
	var condition_value = null
	match variable_scope:
		BaseVariable.VariableScope.LOCAL:
			condition_value = VariableOperations.get_variable(context, condition_variable, BaseVariable.VariableScope.LOCAL, null)
		BaseVariable.VariableScope.SCOPE:
			if scope_source == ScopeSource.NEAREST:
				condition_value = VariableOperations.get_variable(context, condition_variable, BaseVariable.VariableScope.SCOPE, null)
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
					return null
				condition_value = scope_container.get_variable(condition_variable, null)
		BaseVariable.VariableScope.GLOBAL:
			condition_value = VariableOperations.get_variable(context, condition_variable, BaseVariable.VariableScope.GLOBAL, null)
	return condition_value

## 同步执行指令序列
func _execute_instructions_synchronous(context: ExecutionContext):
	for instruction in loop_instructions:
		if not instruction:
			_log_warning_localized("FUSE_WARNING_SKIP_EMPTY_INSTRUCTION", {})
			continue

		# 检测是否为异步指令，发出警告
		BaseInstruction.log_async_in_sync_mode_warning(instruction)

		# 执行指令（同步执行）
		instruction.execute(context)

		# 验证指令是否完成
		if not instruction.is_completed():
			_log_warning_localized("FUSE_WARNING_INSTRUCTION_NOT_SYNCED", {"name": instruction.get_description()})

## 异步执行指令序列
func _execute_instructions_asynchronous(context: ExecutionContext):
	for instruction in loop_instructions:
		if not instruction:
			_log_warning_localized("FUSE_WARNING_SKIP_EMPTY_INSTRUCTION", {})
			continue

		# 重置指令状态（确保可以重新执行）
		instruction.reset()

		# 执行指令
		instruction.execute(context)

		# 等待指令完成
		if not instruction.is_completed():
			_log_debug_localized("FUSE_INSTRUCTION_IF_ELSE_WAITING_FOR_INSTRUCTION", {"instruction": instruction.get_description()})
			await instruction.finished

## 检查条件
func _check_condition(value: Variant) -> bool:
	match condition_check:
		ConditionCheck.IS_TRUE:
			return bool(value)
		ConditionCheck.IS_FALSE:
			return not bool(value)
		ConditionCheck.IS_NOT_NULL:
			return value != null
		_:
			return false

## 验证指令参数
func validate() -> Array[String]:
	var errors = super.validate()

	if condition_variable.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_CONDITION_VARIABLE_EMPTY"))

	if max_iterations <= 0:
		errors.append(FuseLocalization.translate("FUSE_ERROR_MAX_ITERATIONS_INVALID"))

	# 验证 SCOPE 作用域需要 ScopeVariableManager
	if variable_scope == BaseVariable.VariableScope.SCOPE:
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

	# 验证同步模式下是否包含异步指令
	BaseInstruction.validate_async_in_sync_mode(
		loop_instructions,
		sequence_mode == SequenceMode.SYNCHRONOUS,
		errors
	)

	return errors
func _validate_property(property: Dictionary) -> void:
	# 只在 SCOPE 作用域时验证 ScopeSource 相关属性
	if variable_scope == BaseVariable.VariableScope.SCOPE:
		VariableScopeUtils.validate_scope_source_property(property, scope_source as VariableScopeUtils.ScopeSource)
	else:
		# 非 SCOPE 作用域时隐藏 ScopeSource 相关属性
		if property.name in ["scope_source", "custom_scope_id", "target_node_path"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR

## 获取指令描述
func get_description() -> String:
	var check_key := ""
	match condition_check:
		ConditionCheck.IS_TRUE:
			check_key = "FUSE_INSTRUCTION_WHILE_LOOP_DESC_TRUE"
		ConditionCheck.IS_FALSE:
			check_key = "FUSE_INSTRUCTION_WHILE_LOOP_DESC_FALSE"
		ConditionCheck.IS_NOT_NULL:
			check_key = "FUSE_INSTRUCTION_WHILE_LOOP_DESC_NOT_NULL"

	var check_str = FuseLocalization.translate(check_key)
	var scope_str = _get_scope_source_string()

	return FuseLocalization.translate_format("FUSE_INSTRUCTION_WHILE_LOOP_DESCRIPTION", {
		"variable": condition_variable,
		"scope": scope_str,
		"check": check_str,
		"max": max_iterations
	})

## 重置指令状态
func reset():
	super.reset()
	# 状态已迁移到 ExecutionContext.custom_data，无需手动重置
	_log_debug_localized("FUSE_LOG_WHILE_LOOP_RESET", {})

## 获取当前迭代次数
## 参数：
## - context: ExecutionContext - 执行上下文（可选）
## 返回：int - 当前迭代次数
func get_current_iteration(context: ExecutionContext = null) -> int:
	if context:
		return context.get_custom_data("loop_whileloop_current_iteration", 0)
	return 0

## 获取循环进度
## 参数：
## - context: ExecutionContext - 执行上下文（可选）
## 返回：float - 循环进度（0.0 - 1.0）
## 注意：由于 While 循环的迭代次数在运行时才能确定，进度可能不准确
func get_loop_progress(context: ExecutionContext = null) -> float:
	if max_iterations <= 0:
		return 0.0

	var current_iteration = 0
	if context:
		current_iteration = context.get_custom_data("loop_whileloop_current_iteration", 0)

	return float(current_iteration) / float(max_iterations)


## ============================================================
## 运行时实例模式支持（RuntimeInstructionInstance 架构）
## ============================================================

## 获取默认运行时状态
##
## 声明 WhileLoop 指令需要的运行时状态。
## 这些状态会在 RuntimeInstructionInstance 初始化时被复制。
func get_default_runtime_state() -> Dictionary:
	var state = super.get_default_runtime_state()
	state["current_iteration"] = 0  # 当前迭代次数
	state["is_running"] = false  # 是否正在运行
	state["is_paused"] = false  # 是否暂停
	state["current_instruction_index"] = 0  # 当前执行的子指令索引
	state["is_executing_instruction"] = false  # 是否正在执行子指令
	state["child_instance"] = null  # 子指令的运行时实例
	state["current_child_callback"] = null  # 当前子指令完成回调引用（用于断开连接）
	state["iteration_count"] = 0  # 已执行的总迭代次数
	return state

## 使用运行时实例执行（推荐模式）
##
## 这种模式下，所有状态存储在 runtime_instance.runtime_state 中，
## 确保多个执行实例互不干扰。
func execute_with_runtime_instance(runtime_instance: RuntimeInstructionInstance) -> bool:
	_start_execution(runtime_instance.execution_context)

	_log_debug_localized("FUSE_LOG_INSTRUCTION_START", {"instruction": "While Loop"})

	var state = runtime_instance.runtime_state

	# 验证条件变量名
	if condition_variable.is_empty():
		_log_error_localized("FUSE_ERROR_CONDITION_VARIABLE_EMPTY", {})
		set_error_localized("FUSE_ERROR_CONDITION_VARIABLE_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
		runtime_instance._complete_execution()
		return true

	# 验证最大迭代次数
	if max_iterations <= 0:
		_log_error_localized("FUSE_ERROR_MAX_ITERATIONS_INVALID", {})
		set_error_localized("FUSE_ERROR_MAX_ITERATIONS_INVALID", FuseError.ErrorType.VALIDATION_ERROR, {})
		runtime_instance._complete_execution()
		return true

	# 初始化运行时状态
	state["current_iteration"] = 0
	state["iteration_count"] = 0
	state["is_running"] = true
	state["is_paused"] = false
	state["current_instruction_index"] = 0
	state["is_executing_instruction"] = false
	state["child_instance"] = null

	_log_info_localized("FUSE_LOG_WHILE_LOOP_START", {})

	# 保存外层循环标志并开始新循环（使用栈管理）
	runtime_instance.execution_context.push_loop_flags()

	# 根据执行模式选择执行方式
	if sequence_mode == SequenceMode.SYNCHRONOUS:
		_execute_loop_synchronous_runtime(runtime_instance)
		return true  # 同步完成
	else:
		# 异步模式：开始第一次迭代
		_execute_next_iteration_runtime(runtime_instance)
		return false  # 异步执行

## 检查条件（运行时模式）
##
## 从运行时状态中获取条件值并检查
func _check_condition_from_state(runtime_instance: RuntimeInstructionInstance) -> bool:
	var context = runtime_instance.execution_context

	# 获取条件变量值
	var condition_value = _get_condition_value(context)
	if condition_value == null and not VariableOperations.has_variable(context, condition_variable, variable_scope):
		_log_error_localized("FUSE_ERROR_VAR_NOT_FOUND", {"variable": condition_variable})
		set_error_localized("FUSE_ERROR_VAR_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {"variable": condition_variable})
		return false

	_log_debug_localized("FUSE_LOG_WHILE_LOOP_CONDITION_CHECK", {
		"variable": condition_variable,
		"value": condition_value
	})

	return _check_condition(condition_value)

## 执行下一次迭代（运行时模式 - 异步）
func _execute_next_iteration_runtime(runtime_instance: RuntimeInstructionInstance) -> void:
	var state = runtime_instance.runtime_state

	# 检查是否达到最大迭代次数
	var current_iteration = state.get("current_iteration", 0)

	if current_iteration >= max_iterations:
		_log_warning_localized("FUSE_WARNING_MAX_ITERATIONS_REACHED", {})
		_complete_loop_runtime(runtime_instance)
		return

	# 检查 break 标志
	if runtime_instance.execution_context.should_break_loop():
		_log_info_localized("FUSE_LOG_BREAK_DETECTED_WHILE", {"iteration": str(current_iteration)})
		_complete_loop_runtime(runtime_instance)
		return

	# 检查 continue 标志
	if runtime_instance.execution_context.should_continue_loop():
		_log_info_localized("FUSE_LOG_CONTINUE_DETECTED_WHILE", {"iteration": str(current_iteration)})
		runtime_instance.execution_context.clear_loop_flags()
		state["current_iteration"] = current_iteration + 1
		_execute_next_iteration_runtime(runtime_instance)
		return

	# 检查条件
	var condition_met = _check_condition_from_state(runtime_instance)
	if not condition_met:
		_log_debug_localized("FUSE_LOG_WHILE_LOOP_CONDITION_NOT_MET", {})
		_complete_loop_runtime(runtime_instance)
		return

	_log_debug_localized("FUSE_LOG_WHILE_LOOP_CONDITION_MET", {})

	# 存储当前迭代到 custom_data
	runtime_instance.execution_context.set_custom_data("loop_whileloop_current_iteration", current_iteration)

	_log_debug_localized("FUSE_LOG_WHILE_LOOP_ITERATION", {
		"current": current_iteration + 1,
		"max": max_iterations
	})

	# 执行指令序列
	_execute_instruction_sequence_runtime(runtime_instance)

## 执行指令序列（运行时模式 - 异步）
func _execute_instruction_sequence_runtime(runtime_instance: RuntimeInstructionInstance) -> void:
	var state = runtime_instance.runtime_state

	# 检查是否有子指令
	if loop_instructions.is_empty():
		# 没有子指令，直接进入下一次迭代
		state["current_iteration"] = state.get("current_iteration", 0) + 1
		state["iteration_count"] = state.get("iteration_count", 0) + 1
		_execute_next_iteration_runtime(runtime_instance)
		return

	# 从第一个指令开始
	state["current_instruction_index"] = 0
	state["is_executing_instruction"] = true

	# 开始执行子指令
	_execute_next_instruction_runtime(runtime_instance)

## 执行下一个子指令（运行时模式 - 异步）
func _execute_next_instruction_runtime(runtime_instance: RuntimeInstructionInstance) -> void:
	var state = runtime_instance.runtime_state
	var instruction_index = state.get("current_instruction_index", 0)

	# 检查是否所有指令都已执行
	if instruction_index >= loop_instructions.size():
		# 当前迭代的指令序列完成
		state["is_executing_instruction"] = false
		state["child_instance"] = null

		# 检查 break 标志（可能在循环体中被设置）
		if runtime_instance.execution_context.should_break_loop():
			_log_info_localized("FUSE_LOG_BREAK_DETECTED_WHILE", {"iteration": str(state.get("current_iteration", 0))})
			_complete_loop_runtime(runtime_instance)
			return

		# 进入下一次迭代
		state["current_iteration"] = state.get("current_iteration", 0) + 1
		state["iteration_count"] = state.get("iteration_count", 0) + 1
		_execute_next_iteration_runtime(runtime_instance)
		return

	# 获取当前指令
	var instruction = loop_instructions[instruction_index]
	if not instruction:
		_log_warning_localized("FUSE_WARNING_SKIP_EMPTY_INSTRUCTION", {})
		state["current_instruction_index"] = instruction_index + 1
		_execute_next_instruction_runtime(runtime_instance)
		return

	# 重置指令状态（确保可以重新执行）
	instruction.reset()

	# 创建子指令的运行时实例
	var child_instance = RuntimeInstructionInstance.new(instruction, runtime_instance.execution_context, runtime_instance.owner_runner)
	state["child_instance"] = child_instance

	# 创建回调（避免使用 bind）
	var callback = func(): _on_child_instruction_completed(runtime_instance)
	state["current_child_callback"] = callback

	# 连接完成信号
	child_instance.finished.connect(callback)

	# 执行子指令
	var is_sync = child_instance.execute_sync()

	# 如果同步完成，直接继续下一个指令
	if is_sync:
		_on_child_instruction_completed(runtime_instance)

## 子指令完成回调
func _on_child_instruction_completed(runtime_instance: RuntimeInstructionInstance) -> void:
	var state = runtime_instance.runtime_state

	# 检查实例是否仍然有效
	if not runtime_instance or runtime_instance.is_completed():
		return

	# 断开信号（使用存储的回调引用）
	var child_instance = state.get("child_instance")
	var callback = state.get("current_child_callback")
	if child_instance and callback and child_instance.finished.is_connected(callback):
		child_instance.finished.disconnect(callback)

	# 清理引用
	state["child_instance"] = null
	state["current_child_callback"] = null

	# 移动到下一个指令
	state["current_instruction_index"] = state.get("current_instruction_index", 0) + 1

	# 继续执行
	_execute_next_instruction_runtime(runtime_instance)

## 完成循环（运行时模式）
func _complete_loop_runtime(runtime_instance: RuntimeInstructionInstance) -> void:
	var state = runtime_instance.runtime_state
	var final_iteration = state.get("iteration_count", 0)

	# 检查是否达到最大迭代次数
	if state.get("current_iteration", 0) >= max_iterations:
		_log_warning_localized("FUSE_WARNING_MAX_ITERATIONS_REACHED", {})

	_log_info_localized("FUSE_LOG_WHILE_LOOP_COMPLETE", {"count": final_iteration})

	# 恢复外层循环标志（使用栈管理）
	runtime_instance.execution_context.pop_loop_flags()

	# 清理状态
	state["is_running"] = false
	state["is_executing_instruction"] = false
	state["child_instance"] = null

	# 标记完成
	runtime_instance._complete_execution()

## 同步执行循环（运行时模式）
func _execute_loop_synchronous_runtime(runtime_instance: RuntimeInstructionInstance) -> void:
	var state = runtime_instance.runtime_state
	var total_executed: int = 0

	while state.get("current_iteration", 0) < max_iterations:
		var current_iteration = state.get("current_iteration", 0)

		# 将当前迭代存储在 ExecutionContext.custom_data 中
		runtime_instance.execution_context.set_custom_data("loop_whileloop_current_iteration", current_iteration)

		# 检查 break 标志
		if runtime_instance.execution_context.should_break_loop():
			_log_info_localized("FUSE_LOG_BREAK_DETECTED_WHILE", {"iteration": str(current_iteration)})
			break

		# 检查 continue 标志
		if runtime_instance.execution_context.should_continue_loop():
			_log_info_localized("FUSE_LOG_CONTINUE_DETECTED_WHILE", {"iteration": str(current_iteration)})
			runtime_instance.execution_context.clear_loop_flags()
			state["current_iteration"] = current_iteration + 1
			continue

		# 检查条件
		var condition_value = _get_condition_value(runtime_instance.execution_context)
		if condition_value == null and not VariableOperations.has_variable(runtime_instance.execution_context, condition_variable, variable_scope):
			_log_error_localized("FUSE_ERROR_VAR_NOT_FOUND", {"variable": condition_variable})
			set_error_localized("FUSE_ERROR_VAR_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {"variable": condition_variable})
			break

		var condition_met = _check_condition(condition_value)

		_log_debug_localized("FUSE_LOG_WHILE_LOOP_CONDITION_CHECK", {
			"variable": condition_variable,
			"value": condition_value
		})

		if not condition_met:
			_log_debug_localized("FUSE_LOG_WHILE_LOOP_CONDITION_NOT_MET", {})
			break

		_log_debug_localized("FUSE_LOG_WHILE_LOOP_CONDITION_MET", {})

		# 执行嵌套指令（同步）
		_log_debug_localized("FUSE_LOG_WHILE_LOOP_ITERATION", {
			"current": current_iteration + 1,
			"max": max_iterations
		})
		_execute_instructions_synchronous(runtime_instance.execution_context)

		total_executed += 1

		# 增加迭代次数
		state["current_iteration"] = current_iteration + 1

		# 检查 break 标志（可能在循环体中被设置）
		if runtime_instance.execution_context.should_break_loop():
			_log_info_localized("FUSE_LOG_BREAK_DETECTED_WHILE", {"iteration": str(current_iteration + 1)})
			break

	# 检查是否达到最大迭代次数
	if state.get("current_iteration", 0) >= max_iterations:
		_log_warning_localized("FUSE_WARNING_MAX_ITERATIONS_REACHED", {})

	_log_info_localized("FUSE_LOG_WHILE_LOOP_COMPLETE", {"count": total_executed})

	# 恢复外层循环标志（使用栈管理）
	runtime_instance.execution_context.pop_loop_flags()

	# 标记完成
	state["is_running"] = false
	state["iteration_count"] = total_executed
	runtime_instance._complete_execution()

## 暂停处理
##
## 当运行时实例被暂停时，暂停子指令执行
func on_runtime_pause(runtime_instance: RuntimeInstructionInstance) -> void:
	var state = runtime_instance.runtime_state
	state["is_paused"] = true

	# 如果有正在执行的子指令，暂停它
	var child_instance = state.get("child_instance")
	if child_instance and child_instance is RuntimeInstructionInstance:
		if not child_instance.is_completed() and not child_instance.is_paused():
			child_instance.pause()

	_log_debug_localized("FUSE_LOG_DEBUG_WHILE_LOOP_PAUSED", {})

## 恢复处理
##
## 当运行时实例被恢复时，恢复子指令执行
func on_runtime_resume(runtime_instance: RuntimeInstructionInstance) -> void:
	var state = runtime_instance.runtime_state
	state["is_paused"] = false

	# 如果有暂停的子指令，恢复它
	var child_instance = state.get("child_instance")
	if child_instance and child_instance is RuntimeInstructionInstance:
		if child_instance.is_paused():
			child_instance.resume()

	_log_debug_localized("FUSE_LOG_DEBUG_WHILE_LOOP_RESUMED", {})
