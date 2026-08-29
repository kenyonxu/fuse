@tool
@icon("res://addons/fuse/icons/builtin/Loop.png")
extends BaseInstruction
class_name ForEach

## For Each 指令
##
## 遍历数组或节点组中的每个元素。
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

# 源类型
enum SourceType {
	ARRAY,      # 数组变量
	NODE_GROUP  # 节点组
}

# 源类型
var source_type: SourceType = SourceType.ARRAY

# 数组变量名（当源类型为 ARRAY 时使用）
var array_variable: String = ""

# 数组变量作用域
var array_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		if array_scope != value:
			array_scope = value
			_update_resource_name()
			notify_property_list_changed()

## 数组作用域来源（仅当 array_scope == SCOPE 时使用）
var array_scope_source: ScopeSource = ScopeSource.NEAREST:
	set(value):
		if array_scope_source != value:
			array_scope_source = value
			_update_resource_name()
			notify_property_list_changed()

## 自定义数组作用域 ID（CUSTOM_ID 模式使用）
var array_custom_scope_id: String = "":
	set(value):
		if array_custom_scope_id != value:
			array_custom_scope_id = value
			_update_resource_name()

## 数组目标节点路径（TARGET_NODE 模式使用）
var array_target_node_path: NodePath = NodePath(""):
	set(value):
		if array_target_node_path != value:
			array_target_node_path = value
			_update_resource_name()

# 节点组名（当源类型为 NODE_GROUP 时使用）
var group_name: String = ""

# 元素变量名
var item_variable: String = "item"

# 索引变量名
var index_variable: String = "index":
	set(value):
		if index_variable != value:
			index_variable = value
			_update_resource_name()

# 索引变量作用域
var index_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
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

# 元素变量作用域
var item_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		if item_scope != value:
			item_scope = value
			_update_resource_name()
			notify_property_list_changed()

## 元素作用域来源（仅当 item_scope == SCOPE 时使用）
var item_scope_source: ScopeSource = ScopeSource.NEAREST:
	set(value):
		if item_scope_source != value:
			item_scope_source = value
			_update_resource_name()
			notify_property_list_changed()

## 自定义元素作用域 ID（CUSTOM_ID 模式使用）
var item_custom_scope_id: String = "":
	set(value):
		if item_custom_scope_id != value:
			item_custom_scope_id = value
			_update_resource_name()

## 元素目标节点路径（TARGET_NODE 模式使用）
var item_target_node_path: NodePath = NodePath(""):
	set(value):
		if item_target_node_path != value:
			item_target_node_path = value
			_update_resource_name()

# 是否跳过空元素
var skip_null_items: bool = true

# 嵌套指令列表
var loop_instructions: Array[BaseInstruction] = []

## 状态迁移到 ExecutionContext.custom_data（2026-02-03）
## 状态键: "loop_foreach_current_index"
## 避免资源共享导致的状态污染问题
##
## RuntimeInstructionInstance 架构迁移（2026-03-10）
## 支持独立运行时状态，解决并发执行状态冲突

func _init():
	# 🔧 关键修复：明确声明此指令是异步的
	# ForEach 指令使用回调机制（信号连接）而非 await，所以源码检测无法正确识别
	_is_synchronous_hint = false
	_sync_hint_manually_set = true

## 获取指令元数据（用于指令选择器）
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_FOR_EACH_NAME"
	metadata.category_key = "FUSE_CATEGORY_FLOW_CONTROL"
	metadata.description_key = "FUSE_INSTRUCTION_FOR_EACH_DESC"
	metadata.keywords = ["遍历", "循环", "each", "iterate", "for", "array", "group"]
	metadata.builtin_icon = "Loop"
	return metadata

## 设置指令元数据
func _setup_metadata():
	pass

## 获取属性列表
func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	# Source 分类
	properties.append({
		name = "Source",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "source_type",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Array,NodeGroup",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 数组变量名（当源类型为 ARRAY 时显示）
	properties.append({
		name = "array_variable",
		type = TYPE_STRING,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 数组作用域（当源类型为 ARRAY 时显示）
	properties.append({
		name = "array_scope",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Local,Scope,Global",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 只在 array_scope == SCOPE 时显示数组 ScopeSource 配置
	if source_type == SourceType.ARRAY and array_scope == BaseVariable.VariableScope.SCOPE:
		properties.append({
			name = "Array Scope Configuration",
			type = TYPE_NIL,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_CATEGORY
		})

		properties.append({
			name = "array_scope_source",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "Nearest,Custom ID,Trigger Scope,Target Node",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		# 根据作用域来源添加额外属性
		if array_scope_source == ScopeSource.CUSTOM_ID:
			properties.append({
				name = "array_custom_scope_id",
				type = TYPE_STRING,
				hint = PROPERTY_HINT_NONE,
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})
		elif array_scope_source == ScopeSource.TARGET_NODE:
			properties.append({
				name = "array_target_node_path",
				type = TYPE_NODE_PATH,
				hint = PROPERTY_HINT_NONE,
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})

	# 节点组名（当源类型为 NODE_GROUP 时显示）
	properties.append({
		name = "group_name",
		type = TYPE_STRING,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# Item Variable 分类
	properties.append({
		name = "Item Variable",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "item_variable",
		type = TYPE_STRING,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 元素作用域
	properties.append({
		name = "item_scope",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Local,Scope,Global",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 只在 item_scope == SCOPE 时显示元素 ScopeSource 配置
	if item_scope == BaseVariable.VariableScope.SCOPE:
		properties.append({
			name = "Item Scope Configuration",
			type = TYPE_NIL,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_CATEGORY
		})

		properties.append({
			name = "item_scope_source",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "Nearest,Custom ID,Trigger Scope,Target Node",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		# 根据作用域来源添加额外属性
		if item_scope_source == ScopeSource.CUSTOM_ID:
			properties.append({
				name = "item_custom_scope_id",
				type = TYPE_STRING,
				hint = PROPERTY_HINT_NONE,
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})
		elif item_scope_source == ScopeSource.TARGET_NODE:
			properties.append({
				name = "item_target_node_path",
				type = TYPE_NODE_PATH,
				hint = PROPERTY_HINT_NONE,
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})

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

	# 只在 index_scope == SCOPE 时显示索引 ScopeSource 配置
	if index_scope == BaseVariable.VariableScope.SCOPE:
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

	properties.append({
		name = "skip_null_items",
		type = TYPE_BOOL,
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
	var source_str := ""
	var item_str := ""
	var index_str := ""

	match source_type:
		SourceType.ARRAY:
			if array_variable.is_empty():
				source_str = FuseLocalization.translate("FUSE_INSTRUCTION_FOR_EACH_NO_ARRAY")
			else:
				source_str = FuseLocalization.translate_format("FUSE_INSTRUCTION_FOR_EACH_ARRAY", {"name": array_variable})
		SourceType.NODE_GROUP:
			if group_name.is_empty():
				source_str = FuseLocalization.translate("FUSE_INSTRUCTION_FOR_EACH_NO_GROUP")
			else:
				source_str = FuseLocalization.translate_format("FUSE_INSTRUCTION_FOR_EACH_GROUP", {"name": group_name})

	if not item_variable.is_empty():
		item_str = FuseLocalization.translate_format("FUSE_INSTRUCTION_FOR_EACH_TO_ITEM", {"item": item_variable})
	else:
		item_str = FuseLocalization.translate("FUSE_INSTRUCTION_FOR_EACH_NO_ITEM")

	if not index_variable.is_empty():
		index_str = FuseLocalization.translate_format("FUSE_INSTRUCTION_FOR_EACH_INDEX_VAR", {"index": index_variable})

	var instruction_count = loop_instructions.size()
	var count_str = FuseLocalization.translate_format("FUSE_INSTRUCTION_FOR_EACH_INSTRUCTION_COUNT", {"count": instruction_count})

	resource_name = " ".join(["For Each", source_str, item_str, index_str, count_str])

## 动态属性设置（支持属性刷新）
func _set(property: StringName, value: Variant) -> bool:
	if property == "source_type":
		source_type = value
		notify_property_list_changed()
		_update_resource_name()
		return true

	if property == "array_variable" or property == "group_name" or property == "item_variable" or property == "index_variable":
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

	_log_debug_localized("FUSE_LOG_INSTRUCTION_START", {"instruction": "For Each"})

	# 验证元素变量名
	if item_variable.is_empty():
		_log_error_localized("FUSE_ERROR_ITEM_VARIABLE_EMPTY", {})
		set_error_localized("FUSE_ERROR_ITEM_VARIABLE_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
		finished.emit()
		return

	# 获取要遍历的元素列表
	var items: Array

	match source_type:
		SourceType.ARRAY:
			# 验证数组变量名
			if array_variable.is_empty():
				_log_error_localized("FUSE_ERROR_ARRAY_VARIABLE_EMPTY", {})
				set_error_localized("FUSE_ERROR_ARRAY_VARIABLE_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
				finished.emit()
				return

			# 获取数组变量
			if not VariableOperations.has_variable(context, array_variable, array_scope):
				_log_error_localized("FUSE_ERROR_ARRAY_VARIABLE_NOT_FOUND", {"name": array_variable})
				set_error_localized("FUSE_ERROR_ARRAY_VARIABLE_NOT_FOUND", FuseError.ErrorType.VALIDATION_ERROR, {"name": array_variable})
				finished.emit()
				return

			var array_value = _get_variable_by_scope(
				context,
				array_variable,
				array_scope,
				array_scope_source,
				array_custom_scope_id,
				array_target_node_path,
				null
			)

			# 验证是否为可迭代类型（Array 或 PackedArray）
			if not _is_iterable(array_value):
				_log_error_localized("FUSE_ERROR_ARRAY_VARIABLE_NOT_ARRAY", {"name": array_variable})
				set_error_localized("FUSE_ERROR_ARRAY_VARIABLE_NOT_ARRAY", FuseError.ErrorType.VALIDATION_ERROR, {"name": array_variable})
				finished.emit()
				return

			# 转换为 Array 以便统一遍历
			items = _to_array(array_value)

		SourceType.NODE_GROUP:
			# 验证组名
			if group_name.is_empty():
				_log_error_localized("FUSE_ERROR_GROUP_NAME_EMPTY", {})
				set_error_localized("FUSE_ERROR_GROUP_NAME_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
				finished.emit()
				return

			# 获取节点树（context.get_tree()：tree 属性访问器，未设置时从当前场景回退，
			# 同构参照 get_nodes_in_group.gd；旧 get_node_tree() 在 ExecutionContext 上不存在）
			var node_tree = context.get_tree()
			if not node_tree:
				_log_error_localized("FUSE_ERROR_NO_SCENE_TREE", {})
				set_error_localized("FUSE_ERROR_NO_SCENE_TREE", FuseError.ErrorType.RUNTIME_ERROR, {})
				finished.emit()
				return

			# 获取节点组
			items = node_tree.get_nodes_in_group(group_name)

			if items.is_empty():
				_log_warning_localized("FUSE_ERROR_NODE_GROUP_NOT_FOUND", {"name": group_name})

		_:
			_log_error_localized("FUSE_ERROR_SOURCE_TYPE_INVALID", {})
			set_error_localized("FUSE_ERROR_SOURCE_TYPE_INVALID", FuseError.ErrorType.VALIDATION_ERROR, {})
			finished.emit()
			return

	# 保存外层循环标志并开始新循环（使用栈管理）
	context.push_loop_flags()

	# 根据执行模式选择执行方式
	if sequence_mode == SequenceMode.SYNCHRONOUS:
		_execute_loop_synchronous(context, items)
	else:
		_execute_loop_asynchronous(context, items)

## 同步执行循环
func _execute_loop_synchronous(context: ExecutionContext, items: Array):
	# 执行遍历
	_log_info_localized("FUSE_LOG_FOR_EACH_START", {})

	var processed_count := 0

	for i in range(items.size()):
		# 将当前索引存储在 ExecutionContext.custom_data 中
		context.set_custom_data("loop_foreach_current_index", i)
		var item = items[i]

		# 检查 break 标志
		if context.should_break_loop():
			_log_info_localized("FUSE_LOG_BREAK_DETECTED", {"index": str(i)})
			break

		# 检查 continue 标志
		if context.should_continue_loop():
			_log_info_localized("FUSE_LOG_CONTINUE_DETECTED", {"index": str(i)})
			context.clear_loop_flags()
			continue

		# 跳过空元素（如果启用）
		if skip_null_items and item == null:
			_log_debug_localized("FUSE_LOG_FOR_EACH_SKIP_ITEM", {})
			continue

		# 设置元素变量和索引变量
		_set_item_variable(context, item)
		_set_index_variable(context, i)
		_log_debug_localized("FUSE_LOG_FOR_EACH_ITEM", {"index": i, "item": item})

		# 执行嵌套指令（同步）
		_execute_instructions_synchronous(context)

		processed_count += 1

		# 检查 break 标志（可能在循环体中被设置）
		if context.should_break_loop():
			_log_info_localized("FUSE_LOG_BREAK_DETECTED", {"index": str(i)})
			break

	_log_info_localized("FUSE_LOG_FOR_EACH_COMPLETE", {"count": processed_count})

	# 恢复外层循环标志（使用栈管理）
	context.pop_loop_flags()

	_on_execution_completed()

## 异步执行循环
func _execute_loop_asynchronous(context: ExecutionContext, items: Array):
	# 执行遍历
	_log_info_localized("FUSE_LOG_FOR_EACH_START", {})

	var processed_count := 0

	for i in range(items.size()):
		# 将当前索引存储在 ExecutionContext.custom_data 中
		context.set_custom_data("loop_foreach_current_index", i)
		var item = items[i]

		# 检查 break 标志
		if context.should_break_loop():
			_log_info_localized("FUSE_LOG_BREAK_DETECTED", {"index": str(i)})
			break

		# 检查 continue 标志
		if context.should_continue_loop():
			_log_info_localized("FUSE_LOG_CONTINUE_DETECTED", {"index": str(i)})
			context.clear_loop_flags()
			continue

		# 跳过空元素（如果启用）
		if skip_null_items and item == null:
			_log_debug_localized("FUSE_LOG_FOR_EACH_SKIP_ITEM", {})
			continue

		# 设置元素变量和索引变量
		_set_item_variable(context, item)
		_set_index_variable(context, i)
		_log_debug_localized("FUSE_LOG_FOR_EACH_ITEM", {"index": i, "item": item})

		# 执行嵌套指令（异步）
		await _execute_instructions_asynchronous(context)

		processed_count += 1

		# 检查 break 标志（可能在循环体中被设置）
		if context.should_break_loop():
			_log_info_localized("FUSE_LOG_BREAK_DETECTED", {"index": str(i)})
			break

	_log_info_localized("FUSE_LOG_FOR_EACH_COMPLETE", {"count": processed_count})

	# 恢复外层循环标志（使用栈管理）
	context.pop_loop_flags()

	_on_execution_completed()

## 设置元素变量
func _set_item_variable(context: ExecutionContext, item: Variant):
	_set_variable_by_scope(
		context,
		item_variable,
		item_scope,
		item_scope_source,
		item_custom_scope_id,
		item_target_node_path,
		item
	)

## 设置索引变量
func _set_index_variable(context: ExecutionContext, index: int):
	_set_variable_by_scope(
		context,
		index_variable,
		index_scope,
		index_scope_source,
		index_custom_scope_id,
		index_target_node_path,
		index
	)

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

		# ContinueLoop 标准语义：立即中止本迭代剩余指令
		# （原实现漏检致剩余照跑、标志泄漏到下一迭代头反跳一轮）
		if context.should_continue_loop():
			context.clear_continue_flag()
			break
		if context.should_break_loop():
			break

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

		# ContinueLoop 标准语义：立即中止本迭代剩余指令
		if context.should_continue_loop():
			context.clear_continue_flag()
			break
		if context.should_break_loop():
			break

## 验证指令参数
func validate() -> Array[String]:
	var errors = super.validate()

	if item_variable.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_ITEM_VARIABLE_EMPTY"))

	if source_type == SourceType.ARRAY and array_variable.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_ARRAY_VARIABLE_EMPTY"))

	if source_type == SourceType.NODE_GROUP and group_name.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_GROUP_NAME_EMPTY"))

	# 验证数组 SCOPE 作用域需要 ScopeVariableManager
	if source_type == SourceType.ARRAY and array_scope == BaseVariable.VariableScope.SCOPE:
		var manager = ScopeVariableManager.get_instance()
		if manager == null:
			errors.append(FuseLocalization.translate("FUSE_ERROR_SCOPE_MANAGER_NOT_FOUND"))

		# 验证 ScopeSource 参数
		var array_utils_scope_source = array_scope_source as VariableScopeUtils.ScopeSource
		errors.append_array(VariableScopeUtils.validate_scope_source_params(
			array_utils_scope_source,
			array_custom_scope_id,
			array_target_node_path
		))

	# 验证元素 SCOPE 作用域需要 ScopeVariableManager
	if item_scope == BaseVariable.VariableScope.SCOPE:
		var manager = ScopeVariableManager.get_instance()
		if manager == null:
			errors.append(FuseLocalization.translate("FUSE_ERROR_SCOPE_MANAGER_NOT_FOUND"))

		# 验证 ScopeSource 参数
		var item_utils_scope_source = item_scope_source as VariableScopeUtils.ScopeSource
		errors.append_array(VariableScopeUtils.validate_scope_source_params(
			item_utils_scope_source,
			item_custom_scope_id,
			item_target_node_path
		))

	# 验证索引 SCOPE 作用域需要 ScopeVariableManager
	if index_scope == BaseVariable.VariableScope.SCOPE:
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

## 验证属性可见性
func _validate_property(property: Dictionary) -> void:
	# 当源类型为 ARRAY 时隐藏组名
	if property.name == "group_name" and source_type != SourceType.NODE_GROUP:
		property.usage = PROPERTY_USAGE_NO_EDITOR

	# 当源类型为 NODE_GROUP 时隐藏数组变量名
	if property.name == "array_variable" and source_type != SourceType.ARRAY:
		property.usage = PROPERTY_USAGE_NO_EDITOR

	# 数组作用域相关属性
	if source_type == SourceType.ARRAY:
		if array_scope == BaseVariable.VariableScope.SCOPE:
			# 手动处理数组作用域属性验证
			if property.name == "array_scope_source":
				return  # 始终显示
			elif property.name == "array_custom_scope_id":
				if array_scope_source != ScopeSource.CUSTOM_ID:
					property.usage = PROPERTY_USAGE_NO_EDITOR
			elif property.name == "array_target_node_path":
				if array_scope_source != ScopeSource.TARGET_NODE:
					property.usage = PROPERTY_USAGE_NO_EDITOR
		else:
			# 非 SCOPE 作用域时隐藏所有 ScopeSource 属性
			if property.name in ["array_scope_source", "array_custom_scope_id", "array_target_node_path"]:
				property.usage = PROPERTY_USAGE_NO_EDITOR
	else:
		# 非 ARRAY 源类型时隐藏所有数组相关属性
		if property.name.begins_with("array_"):
			property.usage = PROPERTY_USAGE_NO_EDITOR

	# 元素作用域相关属性
	if item_scope == BaseVariable.VariableScope.SCOPE:
		# 手动处理元素作用域属性验证
		if property.name == "item_scope_source":
			return  # 始终显示
		elif property.name == "item_custom_scope_id":
			if item_scope_source != ScopeSource.CUSTOM_ID:
				property.usage = PROPERTY_USAGE_NO_EDITOR
		elif property.name == "item_target_node_path":
			if item_scope_source != ScopeSource.TARGET_NODE:
				property.usage = PROPERTY_USAGE_NO_EDITOR
	else:
		# 非 SCOPE 作用域时隐藏所有 ScopeSource 属性
		if property.name in ["item_scope_source", "item_custom_scope_id", "item_target_node_path"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR

	# 索引作用域相关属性
	if index_scope == BaseVariable.VariableScope.SCOPE:
		# 手动处理索引作用域属性验证
		if property.name == "index_scope_source":
			return  # 始终显示
		elif property.name == "index_custom_scope_id":
			if index_scope_source != ScopeSource.CUSTOM_ID:
				property.usage = PROPERTY_USAGE_NO_EDITOR
		elif property.name == "index_target_node_path":
			if index_scope_source != ScopeSource.TARGET_NODE:
				property.usage = PROPERTY_USAGE_NO_EDITOR
	else:
		# 非 SCOPE 作用域时隐藏所有 ScopeSource 属性
		if property.name in ["index_scope_source", "index_custom_scope_id", "index_target_node_path"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR

## 声明变量读写模式（精确化静态分析）
## array_variable 读源数组；item_variable/index_variable 每次迭代写入
func get_variable_modes() -> Array[Dictionary]:
	return [
		{"name": "array_variable", "mode": "read"},
		{"name": "item_variable", "mode": "write"},
		{"name": "index_variable", "mode": "write"},
	]

## 获取指令描述
func get_description() -> String:
	var source_str := ""

	match source_type:
		SourceType.ARRAY:
			source_str = FuseLocalization.translate_format("FUSE_INSTRUCTION_FOR_EACH_DESC_ARRAY", {"name": array_variable}) if not array_variable.is_empty() else FuseLocalization.translate("FUSE_INSTRUCTION_FOR_EACH_DESC_NO_ARRAY")
		SourceType.NODE_GROUP:
			source_str = FuseLocalization.translate_format("FUSE_INSTRUCTION_FOR_EACH_DESC_GROUP", {"name": group_name}) if not group_name.is_empty() else FuseLocalization.translate("FUSE_INSTRUCTION_FOR_EACH_DESC_NO_GROUP")

	var item_str := FuseLocalization.translate_format("FUSE_INSTRUCTION_FOR_EACH_DESC_ITEM", {"item": item_variable}) if not item_variable.is_empty() else FuseLocalization.translate("FUSE_INSTRUCTION_FOR_EACH_DESC_NO_ITEM")

	var index_str := ""
	if not index_variable.is_empty():
		index_str = FuseLocalization.translate_format("FUSE_INSTRUCTION_FOR_EACH_DESC_INDEX", {"index": index_variable})

	var count_str = FuseLocalization.translate_format("FUSE_INSTRUCTION_FOR_EACH_DESC_COUNT", {"count": loop_instructions.size()})

	var result := "For Each: %s -> %s" % [source_str, item_str]
	if not index_str.is_empty():
		result += ", %s" % index_str
	result += ", %s" % count_str
	return result

## 重置指令状态
func reset():
	super.reset()
	# 状态已迁移到 ExecutionContext.custom_data，无需手动重置
	_log_debug_localized("FUSE_LOG_FOR_EACH_RESET", {})

## 获取当前元素索引
## 参数：
## - context: ExecutionContext - 执行上下文（可选）
## 返回：int - 当前元素索引
func get_current_index(context: ExecutionContext = null) -> int:
	if context:
		return context.get_custom_data("loop_foreach_current_index", 0)
	return 0

## 获取遍历进度
## 返回：float - 遍历进度（0.0 - 1.0）
## 注意：对于动态数组，无法准确计算进度，返回 0.0
func get_iteration_progress() -> float:
	return 0.0

## 检查是否为可迭代类型（Array 或 PackedArray）
func _is_iterable(value: Variant) -> bool:
	return value is Array or _is_packed_array(value)

## 检查是否为 PackedArray 类型
func _is_packed_array(value: Variant) -> bool:
	return value is PackedInt32Array or \
		value is PackedInt64Array or \
		value is PackedFloat32Array or \
		value is PackedFloat64Array or \
		value is PackedByteArray or \
		value is PackedVector2Array or \
		value is PackedVector3Array or \
		value is PackedColorArray or \
		value is PackedStringArray

## 将可迭代类型转换为 Array（用于统一遍历）
func _to_array(value: Variant) -> Array:
	if value is Array:
		return value
	elif _is_packed_array(value):
		# PackedArray 可以直接转换为 Array
		return Array(value)
	return []

## 根据作用域来源获取作用域容器（用于减少代码重复）
func _get_scope_container(context: ExecutionContext, scope_source: ScopeSource, custom_scope_id: String, target_node_path: NodePath) -> Node:
	var utils_scope_source = scope_source as VariableScopeUtils.ScopeSource
	return VariableScopeUtils.get_scope_container_by_source(
		context,
		utils_scope_source,
		custom_scope_id,
		target_node_path
	)

## 根据作用域获取变量（统一接口）
## 参数：
## - context: 执行上下文
## - var_name: 变量名
## - scope: 作用域类型
## - scope_source: 作用域来源（仅当 scope == SCOPE 时使用）
## - custom_scope_id: 自定义作用域 ID
## - target_node_path: 目标节点路径
## - default_value: 默认值
## 返回：变量值
func _get_variable_by_scope(
	context: ExecutionContext,
	var_name: String,
	scope: BaseVariable.VariableScope,
	scope_source: ScopeSource,
	custom_scope_id: String,
	target_node_path: NodePath,
	default_value: Variant = null
) -> Variant:
	match scope:
		BaseVariable.VariableScope.LOCAL:
			return VariableOperations.get_variable(context, var_name, BaseVariable.VariableScope.LOCAL, default_value)
		BaseVariable.VariableScope.SCOPE:
			if scope_source == ScopeSource.NEAREST:
				return VariableOperations.get_variable(context, var_name, BaseVariable.VariableScope.SCOPE, default_value)
			else:
				var scope_container = _get_scope_container(context, scope_source, custom_scope_id, target_node_path)
				if scope_container != null:
					return scope_container.get_variable(var_name, default_value)
				return default_value
		BaseVariable.VariableScope.GLOBAL:
			return VariableOperations.get_variable(context, var_name, BaseVariable.VariableScope.GLOBAL, default_value)
	return default_value

## 根据作用域设置变量（统一接口）
## 参数：
## - context: 执行上下文
## - var_name: 变量名
## - scope: 作用域类型
## - scope_source: 作用域来源（仅当 scope == SCOPE 时使用）
## - custom_scope_id: 自定义作用域 ID
## - target_node_path: 目标节点路径
## - value: 变量值
func _set_variable_by_scope(
	context: ExecutionContext,
	var_name: String,
	scope: BaseVariable.VariableScope,
	scope_source: ScopeSource,
	custom_scope_id: String,
	target_node_path: NodePath,
	value: Variant
) -> void:
	match scope:
		BaseVariable.VariableScope.LOCAL:
			VariableOperations.set_variable(context, var_name, BaseVariable.VariableScope.LOCAL, value)
		BaseVariable.VariableScope.SCOPE:
			if scope_source == ScopeSource.NEAREST:
				VariableOperations.set_variable(context, var_name, BaseVariable.VariableScope.SCOPE, value)
			else:
				var scope_container = _get_scope_container(context, scope_source, custom_scope_id, target_node_path)
				if scope_container != null:
					scope_container.set_variable(var_name, value)
		BaseVariable.VariableScope.GLOBAL:
			VariableOperations.set_variable(context, var_name, BaseVariable.VariableScope.GLOBAL, value)

## ============================================================
## 运行时实例模式支持（RuntimeInstructionInstance 架构）
## ============================================================

## 获取默认运行时状态
##
## 声明 ForEach 指令需要的运行时状态。
## 这些状态会在 RuntimeInstructionInstance 初始化时被复制。
func get_default_runtime_state() -> Dictionary:
	var state = super.get_default_runtime_state()
	state["current_index"] = 0  # 当前循环索引
	state["array_items"] = []  # 要遍历的元素数组
	state["is_running"] = false  # 是否正在运行
	state["is_paused"] = false  # 是否暂停
	state["current_instruction_index"] = 0  # 当前执行的子指令索引
	state["is_executing_instruction"] = false  # 是否正在执行子指令
	state["child_instance"] = null  # 子指令的运行时实例
	state["current_child_callback"] = null  # 当前子指令完成回调引用（用于断开连接）
	state["processed_count"] = 0  # 已处理的元素数量
	return state

## 使用运行时实例执行（推荐模式）
##
## 这种模式下，所有状态存储在 runtime_instance.runtime_state 中，
## 确保多个执行实例互不干扰。
func execute_with_runtime_instance(runtime_instance: RuntimeInstructionInstance) -> bool:
	_start_execution(runtime_instance.execution_context)

	_log_debug_localized("FUSE_LOG_INSTRUCTION_START", {"instruction": "For Each"})

	var state = runtime_instance.runtime_state

	# 验证元素变量名
	if item_variable.is_empty():
		_log_error_localized("FUSE_ERROR_ITEM_VARIABLE_EMPTY", {})
		set_error_localized("FUSE_ERROR_ITEM_VARIABLE_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
		runtime_instance._complete_execution()
		return true

	# 获取要遍历的元素列表
	var items = _get_items_to_iterate(runtime_instance.execution_context)

	# 如果返回 null 表示出错
	if items == null:
		runtime_instance._complete_execution()
		return true

	# 初始化运行时状态
	state["array_items"] = items
	state["current_index"] = 0
	state["processed_count"] = 0
	state["is_running"] = true
	state["is_paused"] = false
	state["current_instruction_index"] = 0
	state["is_executing_instruction"] = false
	state["child_instance"] = null

	_log_info_localized("FUSE_LOG_FOR_EACH_START", {})

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

## 获取要遍历的元素列表（提取为独立方法）
##
## 根据配置获取实际要遍历的元素，支持数组和节点组模式
func _get_items_to_iterate(context: ExecutionContext) -> Variant:
	match source_type:
		SourceType.ARRAY:
			# 验证数组变量名
			if array_variable.is_empty():
				_log_error_localized("FUSE_ERROR_ARRAY_VARIABLE_EMPTY", {})
				set_error_localized("FUSE_ERROR_ARRAY_VARIABLE_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
				return null

			# 获取数组变量
			if not VariableOperations.has_variable(context, array_variable, array_scope):
				_log_error_localized("FUSE_ERROR_ARRAY_VARIABLE_NOT_FOUND", {"name": array_variable})
				set_error_localized("FUSE_ERROR_ARRAY_VARIABLE_NOT_FOUND", FuseError.ErrorType.VALIDATION_ERROR, {"name": array_variable})
				return null

			var array_value = _get_variable_by_scope(
				context,
				array_variable,
				array_scope,
				array_scope_source,
				array_custom_scope_id,
				array_target_node_path,
				null
			)

			# 验证是否为可迭代类型（Array 或 PackedArray）
			if not _is_iterable(array_value):
				_log_error_localized("FUSE_ERROR_ARRAY_VARIABLE_NOT_ARRAY", {"name": array_variable})
				set_error_localized("FUSE_ERROR_ARRAY_VARIABLE_NOT_ARRAY", FuseError.ErrorType.VALIDATION_ERROR, {"name": array_variable})
				return null

			# 转换为 Array 以便统一遍历
			return _to_array(array_value)

		SourceType.NODE_GROUP:
			# 验证组名
			if group_name.is_empty():
				_log_error_localized("FUSE_ERROR_GROUP_NAME_EMPTY", {})
				set_error_localized("FUSE_ERROR_GROUP_NAME_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
				return null

			# 获取节点树（context.get_tree()：tree 属性访问器，未设置时从当前场景回退，
			# 同构参照 get_nodes_in_group.gd；旧 get_node_tree() 在 ExecutionContext 上不存在）
			var node_tree = context.get_tree()
			if not node_tree:
				_log_error_localized("FUSE_ERROR_NO_SCENE_TREE", {})
				set_error_localized("FUSE_ERROR_NO_SCENE_TREE", FuseError.ErrorType.RUNTIME_ERROR, {})
				return null

			# 获取节点组
			var items = node_tree.get_nodes_in_group(group_name)

			if items.is_empty():
				_log_warning_localized("FUSE_ERROR_NODE_GROUP_NOT_FOUND", {"name": group_name})

			return items

		_:
			_log_error_localized("FUSE_ERROR_SOURCE_TYPE_INVALID", {})
			set_error_localized("FUSE_ERROR_SOURCE_TYPE_INVALID", FuseError.ErrorType.VALIDATION_ERROR, {})
			return null

## 执行下一次迭代（运行时模式）
func _execute_next_iteration_runtime(runtime_instance: RuntimeInstructionInstance) -> void:
	var state = runtime_instance.runtime_state
	var items: Array = state.get("array_items", [])
	var current_index: int = state.get("current_index", 0)

	# 检查是否完成
	if current_index >= items.size():
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

	var item = items[current_index]

	# 跳过空元素（如果启用）
	if skip_null_items and item == null:
		_log_debug_localized("FUSE_LOG_FOR_EACH_SKIP_ITEM", {})
		state["current_index"] = current_index + 1
		_execute_next_iteration_runtime(runtime_instance)
		return

	# 设置元素变量和索引变量
	_set_item_variable(runtime_instance.execution_context, item)
	_set_index_variable(runtime_instance.execution_context, current_index)

	# 存储当前索引到 custom_data
	runtime_instance.execution_context.set_custom_data("loop_foreach_current_index", current_index)

	_log_debug_localized("FUSE_LOG_FOR_EACH_ITEM", {"index": current_index, "item": item})

	# 执行指令序列
	_execute_instruction_sequence_runtime(runtime_instance)

## 执行指令序列（运行时模式 - 异步）
func _execute_instruction_sequence_runtime(runtime_instance: RuntimeInstructionInstance) -> void:
	var state = runtime_instance.runtime_state

	# 检查是否有子指令
	if loop_instructions.is_empty():
		# 没有子指令，直接进入下一次迭代
		state["current_index"] = state.get("current_index", 0) + 1
		state["processed_count"] = state.get("processed_count", 0) + 1
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
	var instruction_index: int = state.get("current_instruction_index", 0)

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
		state["processed_count"] = state.get("processed_count", 0) + 1
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

	# 如果同步完成，直接继续下一个指令。
	# 守卫：同步子指令的 finished 在 execute_sync 内同步发射时，信号路径
	# （实例 finished → _on_child_instruction_completed）已推进过一次——
	# state 中的 child_instance 已被清理或换成后续子指令，此时直调是第二次
	# 调用，会断开在途异步兄弟的完成回调并使指令索引双前进（迭代提前结束）
	if is_sync and state.get("child_instance") == child_instance:
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

	_log_info_localized("FUSE_LOG_FOR_EACH_COMPLETE", {"count": state.get("processed_count", 0)})

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
	var items: Array = state.get("array_items", [])
	var processed_count: int = 0

	for i in range(items.size()):
		# 将当前索引存储在 ExecutionContext.custom_data 中
		runtime_instance.execution_context.set_custom_data("loop_foreach_current_index", i)
		var item = items[i]

		# 检查 break 标志
		if runtime_instance.execution_context.should_break_loop():
			_log_info_localized("FUSE_LOG_BREAK_DETECTED", {"index": str(i)})
			break

		# 检查 continue 标志
		if runtime_instance.execution_context.should_continue_loop():
			_log_info_localized("FUSE_LOG_CONTINUE_DETECTED", {"index": str(i)})
			runtime_instance.execution_context.clear_loop_flags()
			continue

		# 跳过空元素（如果启用）
		if skip_null_items and item == null:
			_log_debug_localized("FUSE_LOG_FOR_EACH_SKIP_ITEM", {})
			continue

		# 设置元素变量和索引变量
		_set_item_variable(runtime_instance.execution_context, item)
		_set_index_variable(runtime_instance.execution_context, i)

		# 执行嵌套指令（同步）
		_log_debug_localized("FUSE_LOG_FOR_EACH_ITEM", {"index": i, "item": item})
		_execute_instructions_synchronous(runtime_instance.execution_context)

		processed_count += 1

		# 检查 break 标志（可能在循环体中被设置）
		if runtime_instance.execution_context.should_break_loop():
			_log_info_localized("FUSE_LOG_BREAK_DETECTED", {"index": str(i)})
			break

	_log_info_localized("FUSE_LOG_FOR_EACH_COMPLETE", {"count": processed_count})

	# 恢复外层循环标志（使用栈管理）
	runtime_instance.execution_context.pop_loop_flags()

	# 标记完成
	state["is_running"] = false
	state["processed_count"] = processed_count
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

	_log_debug_localized("FUSE_LOG_DEBUG_FOR_EACH_PAUSED", {})

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

	_log_debug_localized("FUSE_LOG_DEBUG_FOR_EACH_RESUMED", {})

## 取消通知
##
## 取消链路传播：对在途子实例递归取消并清理回调引用。
## 调用时机由 RuntimeInstructionInstance.cancel_and_notify 保证——本实例
## 已先占终态，子实例取消触发的迟到 finished 会被完成回调首行守卫拦截
func on_runtime_cancel(runtime_instance: RuntimeInstructionInstance) -> void:
	var state = runtime_instance.runtime_state
	var child_instance = state.get("child_instance")
	if child_instance and child_instance is RuntimeInstructionInstance:
		# 先断开完成回调再取消：子实例的迟到 finished 不再进入本容器
		var callback = state.get("current_child_callback")
		if callback and child_instance.finished.is_connected(callback):
			child_instance.finished.disconnect(callback)
		if not child_instance.is_completed():
			child_instance.cancel_and_notify()
	state["child_instance"] = null
	state["current_child_callback"] = null
	_log_debug("ForEach: 取消传播完成")
