@tool
@icon("res://addons/fuse/icons/builtin/Time.png")
extends BaseInstruction
class_name WaitUntil

## 等待直到条件成立
##
## 阻塞执行直到指定条件成立，或超时。
## 支持变量比较、节点属性检查等条件类型。
##
## 重构变量系统: 2026-02-09 - 使用 VariableOperations 统一变量访问
## 重构 ScopeSource: 2026-02-10 - 添加 ScopeSource 支持

# 作用域来源枚举
enum ScopeSource {
	NEAREST,        ## 最近的作用域容器（默认）
	CUSTOM_ID,      ## 指定 scope_id
	TRIGGER_SCOPE,  ## Trigger 节点上的作用域
	TARGET_NODE     ## Target 节点上的作用域
}

# 条件类型
enum ConditionType {
	VARIABLE_COMPARISON,    # 变量值比较
	NODE_PROPERTY,          # 节点属性检查
	VARIABLE_EXISTS         # 变量存在性检查
}

var condition_type: ConditionType = ConditionType.VARIABLE_COMPARISON

# 变量比较参数
var variable_a: String = ""

# 变量 A 作用域
@export var variable_a_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		if variable_a_scope != value:
			variable_a_scope = value
			_update_resource_name()
			notify_property_list_changed()

## 作用域来源（仅当 variable_a_scope == SCOPE 时使用）
var variable_a_scope_source: ScopeSource = ScopeSource.NEAREST:
	set(value):
		if variable_a_scope_source != value:
			variable_a_scope_source = value
			_update_resource_name()
			notify_property_list_changed()

## 自定义作用域 ID（CUSTOM_ID 模式使用）
var variable_a_custom_scope_id: String = "":
	set(value):
		if variable_a_custom_scope_id != value:
			variable_a_custom_scope_id = value
			_update_resource_name()

## 目标节点路径（TARGET_NODE 模式使用）
var variable_a_target_node_path: NodePath = NodePath(""):
	set(value):
		if variable_a_target_node_path != value:
			variable_a_target_node_path = value
			_update_resource_name()

var comparison_operator: int = 0  # 0:等于, 1:不等于, 2:大于, 3:小于, 4:大于等于, 5:小于等于
var value_b: Variant = null
var use_variable_b: bool = false
var variable_b: String = ""

# 变量 B 作用域
@export var variable_b_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		if variable_b_scope != value:
			variable_b_scope = value
			_update_resource_name()
			notify_property_list_changed()

## 作用域来源（仅当 variable_b_scope == SCOPE 时使用）
var variable_b_scope_source: ScopeSource = ScopeSource.NEAREST:
	set(value):
		if variable_b_scope_source != value:
			variable_b_scope_source = value
			_update_resource_name()
			notify_property_list_changed()

## 自定义作用域 ID（CUSTOM_ID 模式使用）
var variable_b_custom_scope_id: String = "":
	set(value):
		if variable_b_custom_scope_id != value:
			variable_b_custom_scope_id = value
			_update_resource_name()

## 目标节点路径（TARGET_NODE 模式使用）
var variable_b_target_node_path: NodePath = NodePath(""):
	set(value):
		if variable_b_target_node_path != value:
			variable_b_target_node_path = value
			_update_resource_name()

# 节点属性检查参数
var target_node: NodePath = NodePath("")
var property_name: String = ""
var property_value: Variant = null

# 变量存在性检查参数
var check_variable_name: String = ""

# 检查变量作用域
@export var check_variable_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		if check_variable_scope != value:
			check_variable_scope = value
			_update_resource_name()
			notify_property_list_changed()

## 作用域来源（仅当 check_variable_scope == SCOPE 时使用）
var check_variable_scope_source: ScopeSource = ScopeSource.NEAREST:
	set(value):
		if check_variable_scope_source != value:
			check_variable_scope_source = value
			_update_resource_name()
			notify_property_list_changed()

## 自定义作用域 ID（CUSTOM_ID 模式使用）
var check_variable_custom_scope_id: String = "":
	set(value):
		if check_variable_custom_scope_id != value:
			check_variable_custom_scope_id = value
			_update_resource_name()

## 目标节点路径（TARGET_NODE 模式使用）
var check_variable_target_node_path: NodePath = NodePath(""):
	set(value):
		if check_variable_target_node_path != value:
			check_variable_target_node_path = value
			_update_resource_name()

# 检查间隔（秒）
var check_interval: float = 0.1

# 超时时间（秒，0 = 无超时）
var timeout: float = 0.0

# 定时器
var _timer: SceneTreeTimer = null
var _start_time: float = 0.0
var _check_timer: SceneTreeTimer = null

func _init():
	# 🔧 关键修复：明确声明此指令是异步的
	# WaitUntil 指令使用回调机制（信号连接）而非 await，所以源码检测无法正确识别
	_is_synchronous_hint = false
	_sync_hint_manually_set = true

## 获取指令元数据（用于指令选择器）
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_WAIT_UNTIL_NAME"
	metadata.category_key = "FUSE_CATEGORY_FLOW_CONTROL"
	metadata.description_key = "FUSE_INSTRUCTION_WAIT_UNTIL_DESC"
	metadata.keywords = ["wait", "until", "condition", "poll", "等待", "条件"]
	metadata.builtin_icon = "Time"
	return metadata

## 设置指令元数据
func _setup_metadata():
	pass

## 获取属性列表
func _get_property_list() -> Array[Dictionary]:
	var properties := []

	# Condition 分类
	properties.append({
		name = "Condition",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	# 条件类型
	properties.append({
		name = "condition_type",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Variable Comparison,Node Property,Variable Exists",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# Variable Comparison 参数
	properties.append({
		name = "variable_a",
		type = TYPE_STRING,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 变量 A 的作用域来源（仅在 variable_a_scope == SCOPE 时显示）
	if variable_a_scope == BaseVariable.VariableScope.SCOPE:
		properties.append({
			name = "variable_a_scope_source",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "Nearest,Custom ID,Trigger Scope,Target Node",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		if variable_a_scope_source == ScopeSource.CUSTOM_ID:
			properties.append({
				name = "variable_a_custom_scope_id",
				type = TYPE_STRING,
				hint = PROPERTY_HINT_NONE,
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})

		if variable_a_scope_source == ScopeSource.TARGET_NODE:
			properties.append({
				name = "variable_a_target_node_path",
				type = TYPE_NODE_PATH,
				hint = PROPERTY_HINT_NODE_PATH_VALID_TYPES,
				hint_string = "Node",
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})

	properties.append({
		name = "comparison_operator",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Equal,Not Equal,Greater Than,Less Than,Greater or Equal,Less or Equal",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	properties.append({
		name = "use_variable_b",
		type = TYPE_BOOL,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	properties.append({
		name = "value_b",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	properties.append({
		name = "variable_b",
		type = TYPE_STRING,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 变量 B 的作用域来源（仅在 variable_b_scope == SCOPE 时显示）
	if variable_b_scope == BaseVariable.VariableScope.SCOPE:
		properties.append({
			name = "variable_b_scope_source",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "Nearest,Custom ID,Trigger Scope,Target Node",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		if variable_b_scope_source == ScopeSource.CUSTOM_ID:
			properties.append({
				name = "variable_b_custom_scope_id",
				type = TYPE_STRING,
				hint = PROPERTY_HINT_NONE,
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})

		if variable_b_scope_source == ScopeSource.TARGET_NODE:
			properties.append({
				name = "variable_b_target_node_path",
				type = TYPE_NODE_PATH,
				hint = PROPERTY_HINT_NODE_PATH_VALID_TYPES,
				hint_string = "Node",
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})

	# Node Property 参数
	properties.append({
		name = "target_node",
		type = TYPE_NODE_PATH,
		hint = PROPERTY_HINT_NODE_PATH_VALID_TYPES,
		hint_string = "Node",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	properties.append({
		name = "property_name",
		type = TYPE_STRING,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	properties.append({
		name = "property_value",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# Variable Exists 参数
	properties.append({
		name = "check_variable_name",
		type = TYPE_STRING,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 检查变量的作用域来源（仅在 check_variable_scope == SCOPE 时显示）
	if check_variable_scope == BaseVariable.VariableScope.SCOPE:
		properties.append({
			name = "check_variable_scope_source",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "Nearest,Custom ID,Trigger Scope,Target Node",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		if check_variable_scope_source == ScopeSource.CUSTOM_ID:
			properties.append({
				name = "check_variable_custom_scope_id",
				type = TYPE_STRING,
				hint = PROPERTY_HINT_NONE,
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})

		if check_variable_scope_source == ScopeSource.TARGET_NODE:
			properties.append({
				name = "check_variable_target_node_path",
				type = TYPE_NODE_PATH,
				hint = PROPERTY_HINT_NODE_PATH_VALID_TYPES,
				hint_string = "Node",
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})

	# Timing 分类
	properties.append({
		name = "Timing",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "check_interval",
		type = TYPE_FLOAT,
		hint = PROPERTY_HINT_RANGE,
		hint_string = "0.01,10,0.01,or_greater",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	properties.append({
		name = "timeout",
		type = TYPE_FLOAT,
		hint = PROPERTY_HINT_RANGE,
		hint_string = "0,3600,0.1,or_greater",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	return properties

## 更新资源名称
func _update_resource_name():
	var parts = []

	parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_WAIT_UNTIL_NAME"))

	match condition_type:
		ConditionType.VARIABLE_COMPARISON:
			if not variable_a.is_empty():
				parts.append(FuseLocalization.translate_format("FUSE_INSTRUCTION_WAIT_UNTIL_VAR_A", {"var": variable_a}))
			else:
				parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_WAIT_UNTIL_NOT_SPECIFIED"))
			var op_str = _get_operator_string()
			parts.append(op_str)
			if use_variable_b:
				if not variable_b.is_empty():
					parts.append(FuseLocalization.translate_format("FUSE_INSTRUCTION_WAIT_UNTIL_VAR_B", {"var": variable_b}))
				else:
					parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_WAIT_UNTIL_NOT_SPECIFIED"))
			else:
				parts.append(str(value_b))
		ConditionType.NODE_PROPERTY:
			if not target_node.is_empty():
				parts.append(FuseLocalization.translate_format("FUSE_INSTRUCTION_WAIT_UNTIL_NODE", {"node": _get_node_display_name(target_node)}))
			else:
				parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_WAIT_UNTIL_NOT_SPECIFIED"))
			parts.append(FuseLocalization.translate_format("FUSE_INSTRUCTION_WAIT_UNTIL_PROPERTY", {"prop": property_name}))
		ConditionType.VARIABLE_EXISTS:
			parts.append(FuseLocalization.translate_format("FUSE_INSTRUCTION_WAIT_UNTIL_VAR_EXISTS", {"var": check_variable_name}))

	if timeout > 0.0:
		parts.append(FuseLocalization.translate_format("FUSE_INSTRUCTION_WAIT_UNTIL_TIMEOUT", {"timeout": "%.1f" % timeout}))

	resource_name = " ".join(parts)

## 执行指令
func execute(context: ExecutionContext):
	_start_execution(context)

	_start_time = Time.get_ticks_msec() / 1000.0

	# 立即检查一次条件
	if _check_condition(context):
		_log_info_localized("FUSE_INSTRUCTION_WAIT_UNTIL_CONDITION_MET_IMMEDIATELY", {})
		_on_execution_completed()
		return

	# 开始轮询检查条件
	_log_info_localized("FUSE_INSTRUCTION_WAIT_UNTIL_START_POLLING", {"interval": "%.2f" % check_interval})
	_start_polling(context)

## 开始轮询
func _start_polling(context: ExecutionContext) -> void:
	var scene_tree = Engine.get_main_loop()
	if not scene_tree:
		_log_error_localized("FUSE_ERROR_CANNOT_GET_SCENETREE", {})
		_cleanup_resources()
		finished.emit()
		return

	_poll_condition(context)

## 轮询检查条件
func _poll_condition(context: ExecutionContext) -> void:
	# 检查条件是否满足
	if _check_condition(context):
		_log_info_localized("FUSE_INSTRUCTION_WAIT_UNTIL_CONDITION_MET", {})
		_on_execution_completed()
		return

	# 检查是否超时
	if timeout > 0.0:
		var elapsed = (Time.get_ticks_msec() / 1000.0) - _start_time
		if elapsed >= timeout:
			_log_warning_localized("FUSE_INSTRUCTION_WAIT_UNTIL_TIMEOUT_REACHED", {"timeout": "%.1f" % timeout})
			set_error_localized("FUSE_INSTRUCTION_WAIT_UNTIL_ERROR_TIMEOUT", FuseError.ErrorType.RUNTIME_ERROR, {})
			_cleanup_resources()
			finished.emit()
			return

	# 创建定时器继续检查（使用 lambda 替代 bind）
	var scene_tree = Engine.get_main_loop()
	if scene_tree:
		_check_timer = scene_tree.create_timer(check_interval)
		var callback = func(): _on_check_timer_timeout(context)
		_check_timer.timeout.connect(callback)

## 定时器超时回调
func _on_check_timer_timeout(context: ExecutionContext) -> void:
	_poll_condition(context)

## 检查条件
func _check_condition(context: ExecutionContext) -> bool:
	match condition_type:
		ConditionType.VARIABLE_COMPARISON:
			return _check_variable_comparison(context)
		ConditionType.NODE_PROPERTY:
			return _check_node_property(context)
		ConditionType.VARIABLE_EXISTS:
			return _check_variable_exists(context)
		_:
			return false

## 检查变量比较
func _check_variable_comparison(context: ExecutionContext) -> bool:
	if variable_a.is_empty():
		return false

	# 获取变量 A 的值
	var value_a
	match variable_a_scope:
		BaseVariable.VariableScope.LOCAL:
			value_a = VariableOperations.get_variable(context, variable_a, BaseVariable.VariableScope.LOCAL, null)
		BaseVariable.VariableScope.SCOPE:
			if variable_a_scope_source == ScopeSource.NEAREST:
				value_a = VariableOperations.get_variable(context, variable_a, BaseVariable.VariableScope.SCOPE, null)
			else:
				var utils_scope_source = variable_a_scope_source as VariableScopeUtils.ScopeSource
				var scope_container = VariableScopeUtils.get_scope_container_by_source(
					context, utils_scope_source, variable_a_custom_scope_id, variable_a_target_node_path
				)
				if scope_container == null:
					_log_error_localized("FUSE_ERROR_SCOPE_CONTAINER_NOT_FOUND", {})
					return false
				value_a = scope_container.get_variable(variable_a, null)
		BaseVariable.VariableScope.GLOBAL:
			value_a = VariableOperations.get_variable(context, variable_a, BaseVariable.VariableScope.GLOBAL, null)

	if value_a == null and not VariableOperations.has_variable(context, variable_a, variable_a_scope):
		return false

	var compare_value = value_b
	if use_variable_b:
		if variable_b.is_empty():
			return false

		# 获取变量 B 的值
		match variable_b_scope:
			BaseVariable.VariableScope.LOCAL:
				compare_value = VariableOperations.get_variable(context, variable_b, BaseVariable.VariableScope.LOCAL, null)
			BaseVariable.VariableScope.SCOPE:
				if variable_b_scope_source == ScopeSource.NEAREST:
					compare_value = VariableOperations.get_variable(context, variable_b, BaseVariable.VariableScope.SCOPE, null)
				else:
					var utils_scope_source = variable_b_scope_source as VariableScopeUtils.ScopeSource
					var scope_container = VariableScopeUtils.get_scope_container_by_source(
						context, utils_scope_source, variable_b_custom_scope_id, variable_b_target_node_path
					)
					if scope_container == null:
						_log_error_localized("FUSE_ERROR_SCOPE_CONTAINER_NOT_FOUND", {})
						return false
					compare_value = scope_container.get_variable(variable_b, null)
			BaseVariable.VariableScope.GLOBAL:
				compare_value = VariableOperations.get_variable(context, variable_b, BaseVariable.VariableScope.GLOBAL, null)

		if compare_value == null and not VariableOperations.has_variable(context, variable_b, variable_b_scope):
			return false

	match comparison_operator:
		0: return value_a == compare_value  # 等于
		1: return value_a != compare_value  # 不等于
		2: return value_a > compare_value   # 大于
		3: return value_a < compare_value   # 小于
		4: return value_a >= compare_value  # 大于等于
		5: return value_a <= compare_value  # 小于等于
		_: return false

## 检查节点属性
func _check_node_property(context: ExecutionContext) -> bool:
	if target_node.is_empty() or property_name.is_empty():
		return false

	var node = context.get_node(target_node)
	if not node:
		return false

	# 检查节点是否有该属性
	if not node.has_method("get") and not node.has_method(property_name):
		return false

	var current_value
	if node.has_method("get"):
		current_value = node.get(property_name)
	else:
		current_value = node.call(property_name)

	return current_value == property_value

## 检查变量存在
func _check_variable_exists(context: ExecutionContext) -> bool:
	if check_variable_name.is_empty():
		return false

	match check_variable_scope:
		BaseVariable.VariableScope.LOCAL:
			return VariableOperations.has_variable(context, check_variable_name, BaseVariable.VariableScope.LOCAL)
		BaseVariable.VariableScope.SCOPE:
			if check_variable_scope_source == ScopeSource.NEAREST:
				return VariableOperations.has_variable(context, check_variable_name, BaseVariable.VariableScope.SCOPE)
			else:
				var utils_scope_source = check_variable_scope_source as VariableScopeUtils.ScopeSource
				var scope_container = VariableScopeUtils.get_scope_container_by_source(
					context, utils_scope_source, check_variable_custom_scope_id, check_variable_target_node_path
				)
				if scope_container == null:
					return false
				return scope_container.has_variable(check_variable_name)
		BaseVariable.VariableScope.GLOBAL:
			return VariableOperations.has_variable(context, check_variable_name, BaseVariable.VariableScope.GLOBAL)

	return false

## 获取操作符字符串
func _get_operator_string() -> String:
	match comparison_operator:
		0: return "=="
		1: return "!="
		2: return ">"
		3: return "<"
		4: return ">="
		5: return "<="
		_: return "?"

## 获取作用域来源字符串
func _get_scope_source_string(source: ScopeSource) -> String:
	match source:
		ScopeSource.NEAREST: return "Nearest"
		ScopeSource.CUSTOM_ID: return "Custom ID"
		ScopeSource.TRIGGER_SCOPE: return "Trigger Scope"
		ScopeSource.TARGET_NODE: return "Target Node"
		_: return ""

## 获取变量 A 作用域字符串
func _get_variable_a_scope_string() -> String:
	if variable_a_scope == BaseVariable.VariableScope.LOCAL:
		return "LOCAL"
	elif variable_a_scope == BaseVariable.VariableScope.GLOBAL:
		return "GLOBAL"
	elif variable_a_scope == BaseVariable.VariableScope.SCOPE:
		return "SCOPE:%s" % _get_scope_source_string(variable_a_scope_source)
	return ""

## 获取变量 B 作用域字符串
func _get_variable_b_scope_string() -> String:
	if variable_b_scope == BaseVariable.VariableScope.LOCAL:
		return "LOCAL"
	elif variable_b_scope == BaseVariable.VariableScope.GLOBAL:
		return "GLOBAL"
	elif variable_b_scope == BaseVariable.VariableScope.SCOPE:
		return "SCOPE:%s" % _get_scope_source_string(variable_b_scope_source)
	return ""

## 获取检查变量作用域字符串
func _get_check_variable_scope_string() -> String:
	if check_variable_scope == BaseVariable.VariableScope.LOCAL:
		return "LOCAL"
	elif check_variable_scope == BaseVariable.VariableScope.GLOBAL:
		return "GLOBAL"
	elif check_variable_scope == BaseVariable.VariableScope.SCOPE:
		return "SCOPE:%s" % _get_scope_source_string(check_variable_scope_source)
	return ""

## 清理资源
func _cleanup_resources() -> void:
	if _check_timer and is_instance_valid(_check_timer):
		# 注意：由于使用 lambda，无法直接断开连接
		# 在遗留模式中，我们只能清理引用
		_check_timer = null
	_timer = null

## 验证指令参数
func validate() -> Array[String]:
	var errors = super.validate()

	if condition_type == ConditionType.VARIABLE_COMPARISON:
		if variable_a.is_empty():
			errors.append(FuseLocalization.translate("FUSE_INSTRUCTION_WAIT_UNTIL_ERROR_VAR_A_EMPTY"))

		# 验证变量 A 的 ScopeSource 参数
		if variable_a_scope == BaseVariable.VariableScope.SCOPE:
			if variable_a_scope_source == ScopeSource.CUSTOM_ID and variable_a_custom_scope_id.is_empty():
				errors.append(FuseLocalization.translate("FUSE_ERROR_SCOPE_ID_EMPTY"))
			if variable_a_scope_source == ScopeSource.TARGET_NODE and variable_a_target_node_path.is_empty():
				errors.append(FuseLocalization.translate("FUSE_ERROR_TARGET_NODE_EMPTY"))

		if use_variable_b and variable_b.is_empty():
			errors.append(FuseLocalization.translate("FUSE_INSTRUCTION_WAIT_UNTIL_ERROR_VAR_B_EMPTY"))

		# 验证变量 B 的 ScopeSource 参数
		if use_variable_b and variable_b_scope == BaseVariable.VariableScope.SCOPE:
			if variable_b_scope_source == ScopeSource.CUSTOM_ID and variable_b_custom_scope_id.is_empty():
				errors.append(FuseLocalization.translate("FUSE_ERROR_SCOPE_ID_EMPTY"))
			if variable_b_scope_source == ScopeSource.TARGET_NODE and variable_b_target_node_path.is_empty():
				errors.append(FuseLocalization.translate("FUSE_ERROR_TARGET_NODE_EMPTY"))

	elif condition_type == ConditionType.NODE_PROPERTY:
		if target_node.is_empty():
			errors.append(FuseLocalization.translate("FUSE_INSTRUCTION_WAIT_UNTIL_ERROR_NODE_EMPTY"))
		if property_name.is_empty():
			errors.append(FuseLocalization.translate("FUSE_INSTRUCTION_WAIT_UNTIL_ERROR_PROPERTY_EMPTY"))

	elif condition_type == ConditionType.VARIABLE_EXISTS:
		if check_variable_name.is_empty():
			errors.append(FuseLocalization.translate("FUSE_INSTRUCTION_WAIT_UNTIL_ERROR_CHECK_VAR_EMPTY"))

		# 验证检查变量的 ScopeSource 参数
		if check_variable_scope == BaseVariable.VariableScope.SCOPE:
			if check_variable_scope_source == ScopeSource.CUSTOM_ID and check_variable_custom_scope_id.is_empty():
				errors.append(FuseLocalization.translate("FUSE_ERROR_SCOPE_ID_EMPTY"))
			if check_variable_scope_source == ScopeSource.TARGET_NODE and check_variable_target_node_path.is_empty():
				errors.append(FuseLocalization.translate("FUSE_ERROR_TARGET_NODE_EMPTY"))

	if check_interval <= 0:
		errors.append(FuseLocalization.translate("FUSE_INSTRUCTION_WAIT_UNTIL_ERROR_INVALID_INTERVAL"))

	if timeout < 0:
		errors.append(FuseLocalization.translate("FUSE_INSTRUCTION_WAIT_UNTIL_ERROR_NEGATIVE_TIMEOUT"))

	return errors

## 动态属性设置（支持属性刷新）
func _set(property: StringName, value: Variant) -> bool:
	if property == "condition_type" or property == "use_variable_b":
		set(property, value)
		notify_property_list_changed()
		_update_resource_name()
		return true
	return false

## 属性验证
func _validate_property(property: Dictionary) -> void:
	# 根据条件类型显示/隐藏参数
	if property.name in ["variable_a", "comparison_operator", "value_b", "variable_b"]:
		if condition_type != ConditionType.VARIABLE_COMPARISON:
			property.usage = PROPERTY_USAGE_NO_EDITOR

	if property.name == "variable_b" and condition_type == ConditionType.VARIABLE_COMPARISON:
		if not use_variable_b:
			property.usage = PROPERTY_USAGE_NO_EDITOR

	if property.name == "value_b" and condition_type == ConditionType.VARIABLE_COMPARISON:
		if use_variable_b:
			property.usage = PROPERTY_USAGE_NO_EDITOR

	# 变量 A 的 ScopeSource 属性控制
	if property.name in ["variable_a_scope_source", "variable_a_custom_scope_id", "variable_a_target_node_path"]:
		if variable_a_scope != BaseVariable.VariableScope.SCOPE or condition_type != ConditionType.VARIABLE_COMPARISON:
			property.usage = PROPERTY_USAGE_NO_EDITOR
		elif property.name == "variable_a_custom_scope_id" and variable_a_scope_source != ScopeSource.CUSTOM_ID:
			property.usage = PROPERTY_USAGE_NO_EDITOR
		elif property.name == "variable_a_target_node_path" and variable_a_scope_source != ScopeSource.TARGET_NODE:
			property.usage = PROPERTY_USAGE_NO_EDITOR

	# 变量 B 的 ScopeSource 属性控制
	if property.name in ["variable_b_scope_source", "variable_b_custom_scope_id", "variable_b_target_node_path"]:
		if variable_b_scope != BaseVariable.VariableScope.SCOPE or condition_type != ConditionType.VARIABLE_COMPARISON or not use_variable_b:
			property.usage = PROPERTY_USAGE_NO_EDITOR
		elif property.name == "variable_b_custom_scope_id" and variable_b_scope_source != ScopeSource.CUSTOM_ID:
			property.usage = PROPERTY_USAGE_NO_EDITOR
		elif property.name == "variable_b_target_node_path" and variable_b_scope_source != ScopeSource.TARGET_NODE:
			property.usage = PROPERTY_USAGE_NO_EDITOR

	# 检查变量的 ScopeSource 属性控制
	if property.name in ["check_variable_scope_source", "check_variable_custom_scope_id", "check_variable_target_node_path"]:
		if check_variable_scope != BaseVariable.VariableScope.SCOPE or condition_type != ConditionType.VARIABLE_EXISTS:
			property.usage = PROPERTY_USAGE_NO_EDITOR
		elif property.name == "check_variable_custom_scope_id" and check_variable_scope_source != ScopeSource.CUSTOM_ID:
			property.usage = PROPERTY_USAGE_NO_EDITOR
		elif property.name == "check_variable_target_node_path" and check_variable_scope_source != ScopeSource.TARGET_NODE:
			property.usage = PROPERTY_USAGE_NO_EDITOR

	if property.name in ["target_node", "property_name", "property_value"]:
		if condition_type != ConditionType.NODE_PROPERTY:
			property.usage = PROPERTY_USAGE_NO_EDITOR

	if property.name == "check_variable_name":
		if condition_type != ConditionType.VARIABLE_EXISTS:
			property.usage = PROPERTY_USAGE_NO_EDITOR

## 获取指令描述
func get_description() -> String:
	var condition_desc = ""

	match condition_type:
		ConditionType.VARIABLE_COMPARISON:
			var op_str = _get_operator_string()
			var value_b_str = FuseLocalization.translate_format("FUSE_INSTRUCTION_WAIT_UNTIL_VAR_B", {"var": variable_b}) if use_variable_b else str(value_b)
			condition_desc = FuseLocalization.translate_format("FUSE_INSTRUCTION_WAIT_UNTIL_DESC_VAR_COMPARISON", {"var_a": variable_a, "op": op_str, "var_b": value_b_str})
		ConditionType.NODE_PROPERTY:
			condition_desc = FuseLocalization.translate_format("FUSE_INSTRUCTION_WAIT_UNTIL_DESC_NODE_PROPERTY", {"node": _get_node_display_name(target_node), "prop": property_name, "value": str(property_value)})
		ConditionType.VARIABLE_EXISTS:
			condition_desc = FuseLocalization.translate_format("FUSE_INSTRUCTION_WAIT_UNTIL_DESC_VAR_EXISTS", {"var": check_variable_name})

	var timeout_desc = ""
	if timeout > 0.0:
		timeout_desc = FuseLocalization.translate_format("FUSE_INSTRUCTION_WAIT_UNTIL_DESC_TIMEOUT", {"timeout": "%.1f" % timeout})

	return FuseLocalization.translate_format("FUSE_INSTRUCTION_WAIT_UNTIL_DESC_FORMAT", {"condition": condition_desc, "timeout": timeout_desc})

## ============================================================
## 运行时实例模式支持（RuntimeInstructionInstance 架构）
## ============================================================

## 获取默认运行时状态
##
## 声明 WaitUntil 指令需要的运行时状态。
## 这些状态会在 RuntimeInstructionInstance 初始化时被复制。
func get_default_runtime_state() -> Dictionary:
	var state = super.get_default_runtime_state()
	state["check_timer"] = null  # 轮询计时器
	state["timeout_timer"] = null  # 超时计时器（可选）
	state["start_time"] = 0.0  # 开始时间
	state["current_poll_callback"] = null  # 当前轮询回调引用（用于暂停时断开）
	state["current_timeout_callback"] = null  # 当前超时回调引用（用于暂停时断开）
	state["pause_remaining_poll_time"] = 0.0  # 暂停时轮询剩余时间
	state["pause_remaining_timeout"] = 0.0  # 暂停时超时剩余时间
	state["pause_elapsed_time"] = 0.0  # 暂停时已用时间
	return state

## 使用运行时实例执行（推荐模式）
##
## 这种模式下，所有状态存储在 runtime_instance.runtime_state 中，
## 确保多个执行实例互不干扰。
##
## 使用 runtime_instance 管理信号连接，避免 bind 泄漏
func execute_with_runtime_instance(runtime_instance: RuntimeInstructionInstance) -> bool:
	_start_execution(runtime_instance.execution_context)

	var state = runtime_instance.runtime_state
	state["start_time"] = Time.get_ticks_msec() / 1000.0

	# 立即检查一次条件
	if _check_condition_from_state(runtime_instance):
		_log_info_localized("FUSE_INSTRUCTION_WAIT_UNTIL_CONDITION_MET_IMMEDIATELY", {})
		runtime_instance._complete_execution()
		return true

	# 开始轮询检查条件
	_log_info_localized("FUSE_INSTRUCTION_WAIT_UNTIL_START_POLLING", {"interval": "%.2f" % check_interval})
	_start_runtime_polling(runtime_instance)

	# 如果设置了超时，启动超时计时器
	if timeout > 0.0:
		_start_runtime_timeout_timer(runtime_instance)

	return false  # 异步执行

## 创建轮询回调（避免 bind）
##
## 使用 Callable 和闭包，但存储引用以便清理
func _create_poll_callback(runtime_instance: RuntimeInstructionInstance) -> Callable:
	var callback = func():
		_on_runtime_poll_timeout(runtime_instance)
	return callback

## 开始运行时轮询
func _start_runtime_polling(runtime_instance: RuntimeInstructionInstance) -> void:
	var state = runtime_instance.runtime_state
	var scene_tree = Engine.get_main_loop()
	if not scene_tree:
		_log_error_localized("FUSE_ERROR_CANNOT_GET_SCENETREE", {})
		runtime_instance._complete_execution()
		return

	# 创建轮询计时器
	var check_timer = scene_tree.create_timer(check_interval)
	state["check_timer"] = check_timer

	# 使用回调注册机制
	var callback = _create_poll_callback(runtime_instance)
	check_timer.timeout.connect(callback)
	runtime_instance.register_timer_callback(callback)
	state["current_poll_callback"] = callback  # 存储引用，用于暂停时断开

## 运行时轮询超时处理
func _on_runtime_poll_timeout(runtime_instance: RuntimeInstructionInstance) -> void:
	# 检查实例是否仍然有效
	if not runtime_instance or runtime_instance.is_completed():
		return

	var state = runtime_instance.runtime_state

	# 检查条件是否满足
	if _check_condition_from_state(runtime_instance):
		_log_info_localized("FUSE_INSTRUCTION_WAIT_UNTIL_CONDITION_MET", {})
		_cleanup_runtime_timers(runtime_instance)
		runtime_instance._complete_execution()
		return

	# 检查是否超时（如果没有使用超时计时器，则在这里检查）
	if timeout <= 0.0:
		# 没有超时限制，继续轮询
		_start_runtime_polling(runtime_instance)
	# 如果有超时计时器，超时会通过 timeout_timer 触发

## 开始运行时超时计时器
func _start_runtime_timeout_timer(runtime_instance: RuntimeInstructionInstance) -> void:
	var state = runtime_instance.runtime_state
	var scene_tree = Engine.get_main_loop()
	if not scene_tree:
		return

	# 创建超时计时器
	var timeout_timer = scene_tree.create_timer(timeout)
	state["timeout_timer"] = timeout_timer

	# 使用回调注册机制
	var callback = func():
		_on_runtime_timeout_reached(runtime_instance)
	timeout_timer.timeout.connect(callback)
	runtime_instance.register_timer_callback(callback)
	state["current_timeout_callback"] = callback  # 存储引用，用于暂停时断开

## 运行时超时回调
func _on_runtime_timeout_reached(runtime_instance: RuntimeInstructionInstance) -> void:
	# 检查实例是否仍然有效
	if not runtime_instance or runtime_instance.is_completed():
		return

	_log_warning_localized("FUSE_INSTRUCTION_WAIT_UNTIL_TIMEOUT_REACHED", {"timeout": "%.1f" % timeout})
	set_error_localized("FUSE_INSTRUCTION_WAIT_UNTIL_ERROR_TIMEOUT", FuseError.ErrorType.RUNTIME_ERROR, {})

	_cleanup_runtime_timers(runtime_instance)
	runtime_instance._complete_execution()

## 清理运行时计时器
func _cleanup_runtime_timers(runtime_instance: RuntimeInstructionInstance) -> void:
	var state = runtime_instance.runtime_state

	# 清理轮询计时器
	if state.has("check_timer") and state["check_timer"]:
		var check_timer = state["check_timer"]
		var poll_callback = state.get("current_poll_callback")
		if poll_callback and check_timer.timeout.is_connected(poll_callback):
			check_timer.timeout.disconnect(poll_callback)
		state["check_timer"] = null
		state["current_poll_callback"] = null

	# 清理超时计时器
	if state.has("timeout_timer") and state["timeout_timer"]:
		var timeout_timer = state["timeout_timer"]
		var timeout_callback = state.get("current_timeout_callback")
		if timeout_callback and timeout_timer.timeout.is_connected(timeout_callback):
			timeout_timer.timeout.disconnect(timeout_callback)
		state["timeout_timer"] = null
		state["current_timeout_callback"] = null

## 从运行时状态检查条件
##
## 包装原有的条件检查方法，使用 runtime_instance 获取上下文
func _check_condition_from_state(runtime_instance: RuntimeInstructionInstance) -> bool:
	if not runtime_instance or not runtime_instance.execution_context:
		return false
	return _check_condition(runtime_instance.execution_context)

## 暂停处理
##
## 当运行时实例被暂停时，记录剩余时间并断开计时器
func on_runtime_pause(runtime_instance: RuntimeInstructionInstance) -> void:
	var state = runtime_instance.runtime_state

	# 记录已用时间
	var elapsed = Time.get_ticks_msec() / 1000.0 - state.get("start_time", 0.0)
	state["pause_elapsed_time"] = elapsed

	# 处理轮询计时器
	if state.has("check_timer") and state["check_timer"]:
		var check_timer = state["check_timer"]
		# SceneTreeTimer 无法暂停，断开连接
		var poll_callback = state.get("current_poll_callback")
		if poll_callback and check_timer.timeout.is_connected(poll_callback):
			check_timer.timeout.disconnect(poll_callback)
		state["check_timer"] = null
		state["current_poll_callback"] = null

	# 处理超时计时器
	if state.has("timeout_timer") and state["timeout_timer"]:
		var timeout_timer = state["timeout_timer"]
		# 计算超时剩余时间
		var remaining_timeout = timeout - elapsed
		state["pause_remaining_timeout"] = max(0.0, remaining_timeout)

		# 断开超时计时器
		var timeout_callback = state.get("current_timeout_callback")
		if timeout_callback and timeout_timer.timeout.is_connected(timeout_callback):
			timeout_timer.timeout.disconnect(timeout_callback)
		state["timeout_timer"] = null
		state["current_timeout_callback"] = null

## 恢复处理
##
## 当运行时实例被恢复时，重新开始轮询和超时计时
func on_runtime_resume(runtime_instance: RuntimeInstructionInstance) -> void:
	var state = runtime_instance.runtime_state
	var elapsed = state.get("pause_elapsed_time", 0.0)

	# 更新开始时间（减去已用时间，保持时间连续性）
	state["start_time"] = Time.get_ticks_msec() / 1000.0 - elapsed

	# 先检查条件是否已满足
	if _check_condition_from_state(runtime_instance):
		_log_info_localized("FUSE_INSTRUCTION_WAIT_UNTIL_CONDITION_MET", {})
		runtime_instance._complete_execution()
		return

	# 重新开始轮询
	_start_runtime_polling(runtime_instance)

	# 如果有剩余超时时间，重新开始超时计时器
	var remaining_timeout = state.get("pause_remaining_timeout", 0.0)
	if remaining_timeout > 0.0:
		var scene_tree = Engine.get_main_loop()
		if scene_tree:
			var timeout_timer = scene_tree.create_timer(remaining_timeout)
			state["timeout_timer"] = timeout_timer

			var callback = func():
				_on_runtime_timeout_reached(runtime_instance)
			timeout_timer.timeout.connect(callback)
			runtime_instance.register_timer_callback(callback)
			state["current_timeout_callback"] = callback

	# 清除暂停状态
	state["pause_remaining_poll_time"] = 0.0
	state["pause_remaining_timeout"] = 0.0
	state["pause_elapsed_time"] = 0.0
