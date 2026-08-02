@tool
@icon("res://addons/fuse/icons/builtin/Loop.png")
extends BaseInstruction
class_name ForLoop

## For Loop 指令
##
## 重复执行指令序列固定次数，支持循环索引变量。
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

# 循环次数
var loop_count: int = 3

# 是否使用变量作为循环次数
var use_variable_count: bool = false

# 循环次数变量名
var loop_count_variable: String = ""

# 循环次数变量作用域
@export var loop_count_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		if loop_count_scope != value:
			loop_count_scope = value
			_update_resource_name()
			notify_property_list_changed()

## 循环次数作用域来源（仅当 loop_count_scope == SCOPE 时使用）
var loop_count_scope_source: ScopeSource = ScopeSource.NEAREST:
	set(value):
		if loop_count_scope_source != value:
			loop_count_scope_source = value
			_update_resource_name()
			notify_property_list_changed()

## 自定义循环次数作用域 ID（CUSTOM_ID 模式使用）
var loop_count_custom_scope_id: String = "":
	set(value):
		if loop_count_custom_scope_id != value:
			loop_count_custom_scope_id = value
			_update_resource_name()

## 循环次数目标节点路径（TARGET_NODE 模式使用）
var loop_count_target_node_path: NodePath = NodePath(""):
	set(value):
		if loop_count_target_node_path != value:
			loop_count_target_node_path = value
			_update_resource_name()

# 循环索引变量名（可选）
var index_variable: String = "i"

# 索引变量作用域
@export var index_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		if index_scope != value:
			index_scope = value
			_update_resource_name()
			notify_property_list_changed()

## 索引作用域来源（仅当 index_scope == SCOPE 时使用）
var index_scope_source: ScopeSource = ScopeSource.NEAREST:
	set(value):
		if index_scope_source != value:
			index_scope_source = value
			_update_resource_name()
			notify_property_list_changed()

## 自定义索引作用域 ID（CUSTOM_ID 模式使用）
var index_custom_scope_id: String = "":
	set(value):
		if index_custom_scope_id != value:
			index_custom_scope_id = value
			_update_resource_name()

## 索引目标节点路径（TARGET_NODE 模式使用）
var index_target_node_path: NodePath = NodePath(""):
	set(value):
		if index_target_node_path != value:
			index_target_node_path = value
			_update_resource_name()

# 是否启用索引变量
var use_index_variable: bool = true

# 嵌套指令列表
var loop_instructions: Array[BaseInstruction] = []

## 状态迁移到 ExecutionContext.custom_data（2026-02-03）
## 状态键: "loop_forloop_current_index"
## 避免资源共享导致的状态污染问题
##
## RuntimeInstructionInstance 架构迁移（2026-03-10）
## 支持独立运行时状态，解决并发执行状态冲突

func _init():
	# 🔧 关键修复：明确声明此指令是异步的
	# ForLoop 指令使用回调机制（信号连接）而非 await，所以源码检测无法正确识别
	_is_synchronous_hint = false
	_sync_hint_manually_set = true

## 获取指令元数据（用于指令选择器）
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_FOR_LOOP_NAME"
	metadata.category_key = "FUSE_CATEGORY_FLOW_CONTROL"
	metadata.description_key = "FUSE_INSTRUCTION_FOR_LOOP_DESC"
	metadata.keywords = ["循环", "重复", "for", "loop", "repeat", "iteration", "计数"]
	# 设置指令选择器图标
	metadata.builtin_icon = "Loop"
	return metadata

## 设置指令元数据
func _setup_metadata():
	pass

## 获取属性列表
func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	# Loop Configuration 分类
	properties.append({
		name = "Loop Configuration",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	# 循环次数（当不使用变量时显示）
	properties.append({
		name = "loop_count",
		type = TYPE_INT,
		hint = PROPERTY_HINT_RANGE,
		hint_string = "0,10000,1",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 是否使用变量
	properties.append({
		name = "use_variable_count",
		type = TYPE_BOOL,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 循环次数变量名（当使用变量时显示）
	properties.append({
		name = "loop_count_variable",
		type = TYPE_STRING,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 循环次数作用域（当使用变量时显示）
	properties.append({
		name = "loop_count_scope",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Local,Scope,Global",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 只在 loop_count_scope == SCOPE 时显示 ScopeSource 配置
	if use_variable_count and loop_count_scope == BaseVariable.VariableScope.SCOPE:
		properties.append({
			name = "Loop Count Scope Configuration",
			type = TYPE_NIL,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_CATEGORY
		})

		properties.append({
			name = "loop_count_scope_source",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "Nearest,Custom ID,Trigger Scope,Target Node",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		# 根据作用域来源添加额外属性
		if loop_count_scope_source == ScopeSource.CUSTOM_ID:
			properties.append({
				name = "loop_count_custom_scope_id",
				type = TYPE_STRING,
				hint = PROPERTY_HINT_NONE,
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})
		elif loop_count_scope_source == ScopeSource.TARGET_NODE:
			properties.append({
				name = "loop_count_target_node_path",
				type = TYPE_NODE_PATH,
				hint = PROPERTY_HINT_NONE,
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})

	# Index Variable 分类
	properties.append({
		name = "Index Variable",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	# 是否启用索引变量
	properties.append({
		name = "use_index_variable",
		type = TYPE_BOOL,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 索引变量名
	properties.append({
		name = "index_variable",
		type = TYPE_STRING,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 索引作用域
	properties.append({
		name = "index_scope",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Local,Scope,Global",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 只在 index_scope == SCOPE 时显示 ScopeSource 配置
	if use_index_variable and index_scope == BaseVariable.VariableScope.SCOPE:
		properties.append({
			name = "Index Scope Configuration",
			type = TYPE_NIL,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_CATEGORY
		})

		properties.append({
			name = "index_scope_source",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "Nearest,Custom ID,Trigger Scope,Target Node",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		# 根据作用域来源添加额外属性
		if index_scope_source == ScopeSource.CUSTOM_ID:
			properties.append({
				name = "index_custom_scope_id",
				type = TYPE_STRING,
				hint = PROPERTY_HINT_NONE,
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})
		elif index_scope_source == ScopeSource.TARGET_NODE:
			properties.append({
				name = "index_target_node_path",
				type = TYPE_NODE_PATH,
				hint = PROPERTY_HINT_NONE,
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})

	# Loop Instructions 分类
	properties.append({
		name = "Loop Instructions",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	# 嵌套指令列表
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
	var count_str := ""
	if use_variable_count:
		if loop_count_variable.is_empty():
			count_str = FuseLocalization.translate("FUSE_INSTRUCTION_FOR_LOOP_NO_VAR")
		else:
			count_str = FuseLocalization.translate_format("FUSE_INSTRUCTION_FOR_LOOP_VAR_TIMES", {"var": loop_count_variable})
	else:
		count_str = FuseLocalization.translate_format("FUSE_INSTRUCTION_FOR_LOOP_TIMES", {"count": loop_count})

	var index_str := ""
	if use_index_variable and not index_variable.is_empty():
		index_str = FuseLocalization.translate_format("FUSE_INSTRUCTION_FOR_LOOP_INDEX", {"var": index_variable})

	var instruction_count = loop_instructions.size()
	var instructions_str = FuseLocalization.translate_format("FUSE_INSTRUCTION_FOR_LOOP_INSTRUCTION_COUNT", {"count": instruction_count})

	# 显示执行模式
	var mode_key = "FUSE_INSTRUCTION_IF_ELSE_MODE_SYNC" if sequence_mode == SequenceMode.SYNCHRONOUS else "FUSE_INSTRUCTION_IF_ELSE_MODE_ASYNC"
	var mode_str = "[%s]" % FuseLocalization.translate(mode_key)

	resource_name = " ".join(["For Loop", count_str, index_str, instructions_str, mode_str])

## 动态属性设置（支持属性刷新）
func _set(property: StringName, value: Variant) -> bool:
	if property == "use_variable_count":
		use_variable_count = value
		notify_property_list_changed()
		_update_resource_name()
		return true

	if property == "use_index_variable":
		use_index_variable = value
		notify_property_list_changed()
		_update_resource_name()
		return true

	if property == "loop_count" or property == "loop_count_variable" or property == "index_variable":
		_update_resource_name()
		return false

	if property == "loop_instructions":
		loop_instructions = value
		_update_resource_name()
		return false

	return false

## 属性验证
func _validate_property(property: Dictionary) -> void:
	# 当使用变量时隐藏固定次数
	if property.name == "loop_count" and use_variable_count:
		property.usage = PROPERTY_USAGE_NO_EDITOR

	# 当不使用变量时隐藏变量名和作用域
	if property.name == "loop_count_variable" and not use_variable_count:
		property.usage = PROPERTY_USAGE_NO_EDITOR

	if not use_variable_count:
		if property.name.begins_with("loop_count_"):
			property.usage = PROPERTY_USAGE_NO_EDITOR

	# 当不启用索引变量时隐藏变量名和作用域
	if property.name == "index_variable" and not use_index_variable:
		property.usage = PROPERTY_USAGE_NO_EDITOR

	if not use_index_variable:
		if property.name.begins_with("index_"):
			property.usage = PROPERTY_USAGE_NO_EDITOR

	# 循环次数作用域相关属性
	if use_variable_count and loop_count_scope == BaseVariable.VariableScope.SCOPE:
		# 手动处理循环次数作用域属性验证
		if property.name == "loop_count_scope_source":
			return  # 始终显示
		elif property.name == "loop_count_custom_scope_id":
			if loop_count_scope_source != ScopeSource.CUSTOM_ID:
				property.usage = PROPERTY_USAGE_NO_EDITOR
		elif property.name == "loop_count_target_node_path":
			if loop_count_scope_source != ScopeSource.TARGET_NODE:
				property.usage = PROPERTY_USAGE_NO_EDITOR
	elif use_variable_count:
		# 非 SCOPE 作用域时隐藏所有 ScopeSource 属性
		if property.name in ["loop_count_scope_source", "loop_count_custom_scope_id", "loop_count_target_node_path"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR

	# 索引作用域相关属性
	if use_index_variable and index_scope == BaseVariable.VariableScope.SCOPE:
		# 手动处理索引作用域属性验证
		if property.name == "index_scope_source":
			return  # 始终显示
		elif property.name == "index_custom_scope_id":
			if index_scope_source != ScopeSource.CUSTOM_ID:
				property.usage = PROPERTY_USAGE_NO_EDITOR
		elif property.name == "index_target_node_path":
			if index_scope_source != ScopeSource.TARGET_NODE:
				property.usage = PROPERTY_USAGE_NO_EDITOR
	elif use_index_variable:
		# 非 SCOPE 作用域时隐藏所有 ScopeSource 属性
		if property.name in ["index_scope_source", "index_custom_scope_id", "index_target_node_path"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR

## 执行指令
func execute(context: ExecutionContext):
	_start_execution(context)

	_log_debug_localized("FUSE_LOG_INSTRUCTION_START", {"instruction": "For Loop"})

	# 验证循环次数
	var count: int

	if use_variable_count:
		if loop_count_variable.is_empty():
			_log_error_localized("FUSE_ERROR_VAR_NAME_EMPTY", {})
			set_error_localized("FUSE_ERROR_VAR_NAME_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
			finished.emit()
			return

		var var_value = null
		match loop_count_scope:
			BaseVariable.VariableScope.LOCAL:
				var_value = VariableOperations.get_variable(context, loop_count_variable, BaseVariable.VariableScope.LOCAL, null)
			BaseVariable.VariableScope.SCOPE:
				if loop_count_scope_source == ScopeSource.NEAREST:
					var_value = VariableOperations.get_variable(context, loop_count_variable, BaseVariable.VariableScope.SCOPE, null)
				else:
					var utils_scope_source = loop_count_scope_source as VariableScopeUtils.ScopeSource
					var scope_container = VariableScopeUtils.get_scope_container_by_source(
						context,
						utils_scope_source,
						loop_count_custom_scope_id,
						loop_count_target_node_path
					)
					if scope_container == null:
						_log_error_localized("FUSE_ERROR_SCOPE_CONTAINER_NOT_FOUND", {})
						set_error_localized("FUSE_ERROR_SCOPE_CONTAINER_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {})
						finished.emit()
						return
					var_value = scope_container.get_variable(loop_count_variable, null)
			BaseVariable.VariableScope.GLOBAL:
				var_value = VariableOperations.get_variable(context, loop_count_variable, BaseVariable.VariableScope.GLOBAL, null)

		if var_value == null and not VariableOperations.has_variable(context, loop_count_variable, loop_count_scope):
			_log_error_localized("FUSE_ERROR_VAR_NOT_FOUND", {"variable": loop_count_variable})
			set_error_localized("FUSE_ERROR_VAR_NOT_FOUND", FuseError.ErrorType.VALIDATION_ERROR, {"variable": loop_count_variable})
			finished.emit()
			return

		# 验证类型
		if not (var_value is int or var_value is float):
			var type_str = type_string(typeof(var_value))
			_log_error_localized("FUSE_ERROR_VAR_TYPE_INVALID", {
				"variable": loop_count_variable,
				"actual_type": type_str
			})
			set_error_localized("FUSE_ERROR_VAR_TYPE_INVALID", FuseError.ErrorType.VALIDATION_ERROR, {
				"variable": loop_count_variable,
				"actual_type": type_str
			})
			finished.emit()
			return

		count = int(var_value)

		# 验证循环次数范围
		if count < 0:
			_log_error_localized("FUSE_ERROR_NEGATIVE_LOOP_COUNT", {"count": str(count)})
			set_error_localized("FUSE_ERROR_NEGATIVE_LOOP_COUNT", FuseError.ErrorType.VALIDATION_ERROR, {"count": str(count)})
			finished.emit()
			return

		if count > 10000:
			_log_warning_localized("FUSE_WARNING_LOOP_COUNT_TOO_LARGE", {"count": str(count)})
	else:
		count = loop_count

		# 验证循环次数范围
		if count < 0:
			_log_error_localized("FUSE_ERROR_NEGATIVE_LOOP_COUNT", {"count": str(count)})
			set_error_localized("FUSE_ERROR_NEGATIVE_LOOP_COUNT", FuseError.ErrorType.VALIDATION_ERROR, {"count": str(count)})
			finished.emit()
			return

	# 保存外层循环标志并开始新循环（使用栈管理）
	context.push_loop_flags()

	# 根据执行模式选择执行方式
	if sequence_mode == SequenceMode.SYNCHRONOUS:
		_execute_loop_synchronous(context, count)
	else:
		_execute_loop_asynchronous(context, count)

## 同步执行循环
func _execute_loop_synchronous(context: ExecutionContext, count: int):
	_log_info_localized("FUSE_LOG_START_FOR_LOOP", {"count": str(count)})

	var total_executed: int = 0

	for i in range(count):
		# 将循环索引存储在 ExecutionContext.custom_data 中
		context.set_custom_data("loop_forloop_current_index", i)

		# 检查 break 标志
		if context.should_break_loop():
			_log_info_localized("FUSE_LOG_BREAK_DETECTED", {"index": str(i)})
			break

		# 检查 continue 标志
		if context.should_continue_loop():
			_log_info_localized("FUSE_LOG_CONTINUE_DETECTED", {"index": str(i)})
			context.clear_loop_flags()
			continue

		# 设置索引变量
		_set_index_variable(context, i)

		# 执行嵌套指令（同步）
		_log_debug_localized("FUSE_LOG_EXECUTE_ITERATION", {"current": str(i + 1), "total": str(count)})
		_execute_instructions_synchronous(context)

		total_executed += 1

		# 检查 break 标志（可能在循环体中被设置）
		if context.should_break_loop():
			_log_info_localized("FUSE_LOG_BREAK_DETECTED", {"index": str(i)})
			break

	_log_info_localized("FUSE_LOG_FOR_LOOP_COMPLETED", {"count": str(total_executed)})

	# 恢复外层循环标志（使用栈管理）
	context.pop_loop_flags()

	_on_execution_completed()

## 异步执行循环
func _execute_loop_asynchronous(context: ExecutionContext, count: int):
	_log_info_localized("FUSE_LOG_START_FOR_LOOP", {"count": str(count)})

	var total_executed: int = 0

	for i in range(count):
		# 将循环索引存储在 ExecutionContext.custom_data 中
		context.set_custom_data("loop_forloop_current_index", i)

		# 检查 break 标志
		if context.should_break_loop():
			_log_info_localized("FUSE_LOG_BREAK_DETECTED", {"index": str(i)})
			break

		# 检查 continue 标志
		if context.should_continue_loop():
			_log_info_localized("FUSE_LOG_CONTINUE_DETECTED", {"index": str(i)})
			context.clear_loop_flags()
			continue

		# 设置索引变量
		_set_index_variable(context, i)

		# 执行嵌套指令（异步）
		_log_debug_localized("FUSE_LOG_EXECUTE_ITERATION", {"current": str(i + 1), "total": str(count)})
		await _execute_instructions_asynchronous(context)

		total_executed += 1

		# 检查 break 标志（可能在循环体中被设置）
		if context.should_break_loop():
			_log_info_localized("FUSE_LOG_BREAK_DETECTED", {"index": str(i)})
			break

	_log_info_localized("FUSE_LOG_FOR_LOOP_COMPLETED", {"count": str(total_executed)})

	# 恢复外层循环标志（使用栈管理）
	context.pop_loop_flags()

	_on_execution_completed()

## 设置索引变量
func _set_index_variable(context: ExecutionContext, index: int):
	if use_index_variable and not index_variable.is_empty():
		match index_scope:
			BaseVariable.VariableScope.LOCAL:
				VariableOperations.set_variable(context, index_variable, BaseVariable.VariableScope.LOCAL, index)
			BaseVariable.VariableScope.SCOPE:
				if index_scope_source == ScopeSource.NEAREST:
					VariableOperations.set_variable(context, index_variable, BaseVariable.VariableScope.SCOPE, index)
				else:
					var utils_scope_source = index_scope_source as VariableScopeUtils.ScopeSource
					var scope_container = VariableScopeUtils.get_scope_container_by_source(
						context,
						utils_scope_source,
						index_custom_scope_id,
						index_target_node_path
					)
					if scope_container != null:
						scope_container.set_variable(index_variable, index)
			BaseVariable.VariableScope.GLOBAL:
				VariableOperations.set_variable(context, index_variable, BaseVariable.VariableScope.GLOBAL, index)
		_log_debug_localized("FUSE_LOG_SET_INDEX_VARIABLE", {"var": index_variable, "value": str(index)})

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

## 验证指令参数
func validate() -> Array[String]:
	var errors = super.validate()

	if not use_variable_count and loop_count < 0:
		errors.append(FuseLocalization.translate("FUSE_ERROR_NEGATIVE_LOOP_COUNT"))

	if use_variable_count and loop_count_variable.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_LOOP_COUNT_VAR_NAME_EMPTY"))

	if use_index_variable and index_variable.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_INDEX_VARIABLE_EMPTY"))

	# 验证循环次数 SCOPE 作用域需要 ScopeVariableManager
	if use_variable_count and loop_count_scope == BaseVariable.VariableScope.SCOPE:
		var manager = ScopeVariableManager.get_instance()
		if manager == null:
			errors.append(FuseLocalization.translate("FUSE_ERROR_SCOPE_MANAGER_NOT_FOUND"))

		# 验证 ScopeSource 参数
		var loop_count_utils_scope_source = loop_count_scope_source as VariableScopeUtils.ScopeSource
		errors.append_array(VariableScopeUtils.validate_scope_source_params(
			loop_count_utils_scope_source,
			loop_count_custom_scope_id,
			loop_count_target_node_path
		))

	# 验证索引 SCOPE 作用域需要 ScopeVariableManager
	if use_index_variable and index_scope == BaseVariable.VariableScope.SCOPE:
		var manager = ScopeVariableManager.get_instance()
		if manager == null:
			errors.append(FuseLocalization.translate("FUSE_ERROR_SCOPE_MANAGER_NOT_FOUND"))

		# 验证 ScopeSource 参数
		var index_utils_scope_source = index_scope_source as VariableScopeUtils.ScopeSource
		errors.append_array(VariableScopeUtils.validate_scope_source_params(
			index_utils_scope_source,
			index_custom_scope_id,
			index_target_node_path
		))

	# 验证同步模式下是否包含异步指令
	BaseInstruction.validate_async_in_sync_mode(
		loop_instructions,
		sequence_mode == SequenceMode.SYNCHRONOUS,
		errors
	)

	return errors

## 获取指令描述
func get_description() -> String:
	var count_str := ""

	if use_variable_count:
		count_str = FuseLocalization.translate_format("FUSE_INSTRUCTION_FOR_LOOP_DESC_VAR", {"var": loop_count_variable}) if not loop_count_variable.is_empty() else FuseLocalization.translate("FUSE_INSTRUCTION_FOR_LOOP_DESC_NO_VAR")
	else:
		count_str = FuseLocalization.translate_format("FUSE_INSTRUCTION_FOR_LOOP_DESC_TIMES", {"count": loop_count})

	var index_str := ""
	if use_index_variable and not index_variable.is_empty():
		index_str = FuseLocalization.translate_format("FUSE_INSTRUCTION_FOR_LOOP_DESC_INDEX", {"var": index_variable})

	var instructions_str = FuseLocalization.translate_format("FUSE_INSTRUCTION_FOR_LOOP_DESC_INSTRUCTIONS", {"count": loop_instructions.size()})

	return "For Loop: %s%s, %s" % [count_str, index_str, instructions_str]

## 重置指令状态
func reset():
	super.reset()
	# 状态已迁移到 ExecutionContext.custom_data，无需手动重置
	_log_debug_localized("FUSE_LOG_DEBUG_FOR_LOOP_RESET", {})

## ============================================================
## 运行时实例模式支持（RuntimeInstructionInstance 架构）
## ============================================================

## 获取默认运行时状态
##
## 声明 ForLoop 指令需要的运行时状态。
## 这些状态会在 RuntimeInstructionInstance 初始化时被复制。
func get_default_runtime_state() -> Dictionary:
	var state = super.get_default_runtime_state()
	state["current_index"] = 0  # 当前循环索引
	state["total_count"] = 0  # 总循环次数
	state["is_running"] = false  # 是否正在运行
	state["is_paused"] = false  # 是否暂停
	state["current_instruction_index"] = 0  # 当前执行的子指令索引
	state["is_executing_instruction"] = false  # 是否正在执行子指令
	state["child_instance"] = null  # 子指令的运行时实例
	state["current_child_callback"] = null  # 当前子指令完成回调引用（用于断开连接）
	state["total_executed"] = 0  # 已执行的总迭代次数
	return state

## 使用运行时实例执行（推荐模式）
##
## 这种模式下，所有状态存储在 runtime_instance.runtime_state 中，
## 确保多个执行实例互不干扰。
func execute_with_runtime_instance(runtime_instance: RuntimeInstructionInstance) -> bool:
	_start_execution(runtime_instance.execution_context)

	_log_debug_localized("FUSE_LOG_INSTRUCTION_START", {"instruction": "For Loop"})

	var state = runtime_instance.runtime_state

	# 获取循环次数
	var count = _get_loop_count(runtime_instance.execution_context)

	# 验证循环次数
	if count < 0:
		_log_error_localized("FUSE_ERROR_NEGATIVE_LOOP_COUNT", {"count": str(count)})
		set_error_localized("FUSE_ERROR_NEGATIVE_LOOP_COUNT", FuseError.ErrorType.VALIDATION_ERROR, {"count": str(count)})
		runtime_instance._complete_execution()
		return true

	if count > 10000:
		_log_warning_localized("FUSE_WARNING_LOOP_COUNT_TOO_LARGE", {"count": str(count)})

	# 初始化运行时状态
	state["total_count"] = count
	state["current_index"] = 0
	state["total_executed"] = 0
	state["is_running"] = true
	state["is_paused"] = false
	state["current_instruction_index"] = 0
	state["is_executing_instruction"] = false
	state["child_instance"] = null

	_log_info_localized("FUSE_LOG_START_FOR_LOOP", {"count": str(count)})

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

## 获取循环次数（提取为独立方法）
##
## 根据配置获取实际循环次数，支持直接设置和变量模式
func _get_loop_count(context: ExecutionContext) -> int:
	if use_variable_count:
		if loop_count_variable.is_empty():
			return -1

		var var_value: Variant
		match loop_count_scope:
			BaseVariable.VariableScope.LOCAL:
				var_value = VariableOperations.get_variable(context, loop_count_variable, BaseVariable.VariableScope.LOCAL, null)
			BaseVariable.VariableScope.SCOPE:
				if loop_count_scope_source == ScopeSource.NEAREST:
					var_value = VariableOperations.get_variable(context, loop_count_variable, BaseVariable.VariableScope.SCOPE, null)
				else:
					var utils_scope_source = loop_count_scope_source as VariableScopeUtils.ScopeSource
					var scope_container = VariableScopeUtils.get_scope_container_by_source(
						context,
						utils_scope_source,
						loop_count_custom_scope_id,
						loop_count_target_node_path
					)
					if scope_container == null:
						return -1
					var_value = scope_container.get_variable(loop_count_variable, null)
			BaseVariable.VariableScope.GLOBAL:
				var_value = VariableOperations.get_variable(context, loop_count_variable, BaseVariable.VariableScope.GLOBAL, null)

		if var_value == null:
			return -1

		if not (var_value is int or var_value is float):
			return -1

		return int(var_value)
	else:
		return loop_count

## 执行下一次迭代（运行时模式）
func _execute_next_iteration_runtime(runtime_instance: RuntimeInstructionInstance) -> void:
	var state = runtime_instance.runtime_state

	# 检查是否完成
	var current_index = state.get("current_index", 0)
	var total_count = state.get("total_count", 0)

	if current_index >= total_count:
		_complete_loop_runtime(runtime_instance)
		return

	# 检查 break 标志
	if runtime_instance.execution_context.should_break_loop():
		_log_info_localized("FUSE_LOG_BREAK_DETECTED", {"index": str(current_index)})
		_complete_loop_runtime(runtime_instance)
		return

	# 检查 continue 标志
	if runtime_instance.execution_context.should_continue_loop():
		_log_info_localized("FUSE_LOG_CONTINUE_DETECTED", {"index": str(current_index)})
		runtime_instance.execution_context.clear_loop_flags()
		state["current_index"] = current_index + 1
		_execute_next_iteration_runtime(runtime_instance)
		return

	# 设置索引变量
	_set_index_variable(runtime_instance.execution_context, current_index)

	# 存储当前索引到 custom_data
	runtime_instance.execution_context.set_custom_data("loop_forloop_current_index", current_index)

	_log_debug_localized("FUSE_LOG_EXECUTE_ITERATION", {"current": str(current_index + 1), "total": str(total_count)})

	# 执行指令序列
	_execute_instruction_sequence_runtime(runtime_instance)

## 执行指令序列（运行时模式 - 异步）
func _execute_instruction_sequence_runtime(runtime_instance: RuntimeInstructionInstance) -> void:
	var state = runtime_instance.runtime_state

	# 检查是否有子指令
	if loop_instructions.is_empty():
		# 没有子指令，直接进入下一次迭代
		state["current_index"] = state.get("current_index", 0) + 1
		state["total_executed"] = state.get("total_executed", 0) + 1
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
			_log_info_localized("FUSE_LOG_BREAK_DETECTED", {"index": str(state.get("current_index", 0))})
			_complete_loop_runtime(runtime_instance)
			return

		# 进入下一次迭代
		state["current_index"] = state.get("current_index", 0) + 1
		state["total_executed"] = state.get("total_executed", 0) + 1
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

	_log_info_localized("FUSE_LOG_FOR_LOOP_COMPLETED", {"count": str(state.get("total_executed", 0))})

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
	var count = state.get("total_count", 0)
	var total_executed: int = 0

	for i in range(count):
		# 将循环索引存储在 ExecutionContext.custom_data 中
		runtime_instance.execution_context.set_custom_data("loop_forloop_current_index", i)

		# 检查 break 标志
		if runtime_instance.execution_context.should_break_loop():
			_log_info_localized("FUSE_LOG_BREAK_DETECTED", {"index": str(i)})
			break

		# 检查 continue 标志
		if runtime_instance.execution_context.should_continue_loop():
			_log_info_localized("FUSE_LOG_CONTINUE_DETECTED", {"index": str(i)})
			runtime_instance.execution_context.clear_loop_flags()
			continue

		# 设置索引变量
		_set_index_variable(runtime_instance.execution_context, i)

		# 执行嵌套指令（同步）
		_log_debug_localized("FUSE_LOG_EXECUTE_ITERATION", {"current": str(i + 1), "total": str(count)})
		_execute_instructions_synchronous(runtime_instance.execution_context)

		total_executed += 1

		# 检查 break 标志（可能在循环体中被设置）
		if runtime_instance.execution_context.should_break_loop():
			_log_info_localized("FUSE_LOG_BREAK_DETECTED", {"index": str(i)})
			break

	_log_info_localized("FUSE_LOG_FOR_LOOP_COMPLETED", {"count": str(total_executed)})

	# 恢复外层循环标志（使用栈管理）
	runtime_instance.execution_context.pop_loop_flags()

	# 标记完成
	state["is_running"] = false
	state["total_executed"] = total_executed
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

	_log_debug_localized("FUSE_LOG_DEBUG_FOR_LOOP_PAUSED", {})

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

	_log_debug_localized("FUSE_LOG_DEBUG_FOR_LOOP_RESUMED", {})

## 获取当前循环索引
## 参数：
## - context: ExecutionContext - 执行上下文（可选）
## 返回：int - 当前循环索引
func get_current_index(context: ExecutionContext = null) -> int:
	if context:
		return context.get_custom_data("loop_forloop_current_index", 0)
	return 0

## 获取循环进度
## 参数：
## - context: ExecutionContext - 执行上下文（可选）
## 返回：float - 循环进度（0.0 - 1.0）
func get_loop_progress(context: ExecutionContext = null) -> float:
	var total: int
	if use_variable_count:
		# 无法计算，返回 0
		return 0.0
	else:
		total = loop_count

	if total <= 0:
		return 0.0

	var current_index = 0
	if context:
		current_index = context.get_custom_data("loop_forloop_current_index", 0)

	return float(current_index) / float(total)
