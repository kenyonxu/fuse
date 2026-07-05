@tool
@icon("res://addons/fuse/icons/builtin/Tree.png")
extends BaseCondition
class_name CheckComposite

## 条件组合 (CheckComposite)
##
## 支持复杂的嵌套逻辑表达式，通过组合 AND/OR/NOT 条件来实现。
## 这是 Phase 1 最复杂的条件，为未来的可视化逻辑编辑器做准备。
##
## 示例:
## - (A AND B) OR (C AND D)
## - (A OR B) AND NOT C
## - A AND (B OR C) AND NOT D

## 逻辑操作符类型
enum LogicOperator {
	AND,  # 所有操作数都为 true
	OR,   # 任意操作数为 true
	NOT   # 对单个操作数取反
}

## 逻辑节点结构
## 每个节点可以是:
## 1. 叶子节点 - 包含一个 BaseCondition
## 2. 逻辑节点 - 包含操作符和多个子节点
class LogicNode:
	var operator: LogicOperator
	var condition: BaseCondition  # 仅用于叶子节点
	var operands: Array[LogicNode]  # 仅用于逻辑节点

	func _init(op: LogicOperator = LogicOperator.AND):
		operator = op

	## 判断是否为叶子节点
	func is_leaf() -> bool:
		return condition != null

	## 添加子节点
	func add_operand(node: LogicNode):
		operands.append(node)

	## 创建叶子节点
	static func create_leaf(cond: BaseCondition) -> LogicNode:
		var node = LogicNode.new()
		node.condition = cond
		return node

	## 创建逻辑节点
	static func create_logic(op: LogicOperator, children: Array[LogicNode] = []) -> LogicNode:
		var node = LogicNode.new(op)
		for child in children:
			node.add_operand(child)
		return node

## 根逻辑节点
@export_group("Composite Condition")
var _root_node: LogicNode = null:
	set(value):
		_root_node = value
		clear_dependencies_cache()
		_update_resource_name()

## 是否使用短路求值
@export var use_short_circuit: bool = true

## 用于序列化的扁平化逻辑树
## 格式: [{"operator": "AND", "conditions": [...]}, ...]
@export var logic_tree_serialized: Array = []:
	set(value):
		logic_tree_serialized = value
		_build_logic_tree_from_serialized()

## 构建后的根节点
var _built_root: LogicNode = null

## 更新资源名称（必需）
func _update_resource_name() -> void:
	if _root_node == null:
		resource_name = FuseLocalization.translate("FUSE_CONDITION_COMPOSITE_EMPTY")
	else:
		var desc = _describe_node(_root_node)
		# 限制长度
		if desc.length() > 50:
			desc = desc.substr(0, 47) + "..."
		resource_name = FuseLocalization.translate_format("FUSE_CONDITION_COMPOSITE_WITH_DESC", {"desc": desc})

## 描述节点
func _describe_node(node: LogicNode, depth: int = 0) -> String:
	if node == null:
		return "null"

	if node.is_leaf():
		if node.condition != null:
			return node.condition.get_description()
		return "null"

	var op_name = LogicOperator.keys()[node.operator]
	var parts = []
	for operand in node.operands:
		parts.append(_describe_node(operand, depth + 1))

	# 根据深度决定是否使用括号
	var result = "(%s)" % " %s " % op_name
	var max_display = 3
	if parts.size() <= max_display:
		result = "(%s)" % (" %s " % op_name).join(parts)
	else:
		result = "(%s ... %d 项)" % [op_name, parts.size()]

	return result

## 评估条件
func _evaluate_condition(context: ExecutionContext) -> bool:
	if _root_node == null:
		_log_warning(FuseLocalization.translate("FUSE_CONDITION_WARNING_COMPOSITE_ROOT_NULL"))
		return false

	return _evaluate_node(_root_node, context)

## 递归评估节点
func _evaluate_node(node: LogicNode, context: ExecutionContext) -> bool:
	if node == null:
		_log_error(FuseLocalization.translate("FUSE_CONDITION_ERROR_LOGIC_NODE_NULL"))
		return false

	# 叶子节点 - 直接评估条件
	if node.is_leaf():
		if node.condition == null:
			var error_msg = FuseLocalization.translate("FUSE_CONDITION_ERROR_LEAF_CONDITION_NULL")
			_log_error(error_msg)
			_create_fuse_error(error_msg, FuseError.ErrorType.VALIDATION_ERROR)
			return false

		var result = node.condition.check(context)
		_log_debug(FuseLocalization.translate_format(
			"FUSE_CONDITION_LOG_LEAF_EVALUATION",
			{"desc": node.condition.get_description(), "result": "true" if result else "false"}
		))
		return result

	# 逻辑节点 - 根据操作符评估
	if node.operands.is_empty():
		_log_warning(FuseLocalization.translate("FUSE_CONDITION_WARNING_LOGIC_NODE_NO_OPERANDS"))
		return false

	match node.operator:
		LogicOperator.AND:
			return _evaluate_and(node, context)
		LogicOperator.OR:
			return _evaluate_or(node, context)
		LogicOperator.NOT:
			return _evaluate_not(node, context)
		_:
			_log_error(FuseLocalization.translate_format("FUSE_CONDITION_ERROR_UNKNOWN_OPERATOR", {"operator": node.operator}))
			return false

## 评估 AND 节点
func _evaluate_and(node: LogicNode, context: ExecutionContext) -> bool:
	for i in range(node.operands.size()):
		var operand = node.operands[i]
		var result = _evaluate_node(operand, context)

		# 短路求值: 遇到 false 立即返回
		if not result:
			_log_debug(FuseLocalization.translate_format("FUSE_CONDITION_LOG_AND_FAILED", {"index": i}))
			return false

	_log_debug(FuseLocalization.translate_format("FUSE_CONDITION_LOG_AND_SUCCESS", {"count": node.operands.size()}))
	return true

## 评估 OR 节点
func _evaluate_or(node: LogicNode, context: ExecutionContext) -> bool:
	for i in range(node.operands.size()):
		var operand = node.operands[i]
		var result = _evaluate_node(operand, context)

		# 短路求值: 遇到 true 立即返回
		if result:
			_log_debug(FuseLocalization.translate_format("FUSE_CONDITION_LOG_OR_SUCCESS", {"index": i}))
			return true

	_log_debug(FuseLocalization.translate_format("FUSE_CONDITION_LOG_OR_FAILED", {"count": node.operands.size()}))
	return false

## 评估 NOT 节点
func _evaluate_not(node: LogicNode, context: ExecutionContext) -> bool:
	if node.operands.size() != 1:
		_log_error(FuseLocalization.translate_format("FUSE_CONDITION_ERROR_NOT_OPERAND_COUNT", {"count": node.operands.size()}))
		return false

	var operand = node.operands[0]
	var inner_result = _evaluate_node(operand, context)
	var result = not inner_result

	_log_debug(FuseLocalization.translate_format(
		"FUSE_CONDITION_LOG_NOT_RESULT",
		{"input": "true" if inner_result else "false", "result": "true" if result else "false"}
	))

	return result

## 计算依赖
func _compute_dependencies() -> Array[String]:
	var all_deps: Array[String] = []
	if _root_node != null:
		_collect_dependencies(_root_node, all_deps)
	return all_deps

## 递归收集依赖
func _collect_dependencies(node: LogicNode, deps: Array[String]):
	if node == null:
		return

	if node.is_leaf():
		if node.condition != null:
			var condition_deps = node.condition.get_dependencies()
			for dep in condition_deps:
				if not dep in deps:
					deps.append(dep)
	else:
		for operand in node.operands:
			_collect_dependencies(operand, deps)

## 获取条件类型
func get_condition_type() -> String:
	return "composite"

## 获取条件分类
func get_condition_category() -> String:
	return "composite"

## 获取条件描述
func get_description() -> String:
	if _root_node == null:
		return FuseLocalization.translate("FUSE_CONDITION_COMPOSITE_EMPTY")

	var desc = _describe_node(_root_node)

	# 限制描述长度
	if desc.length() > 100:
		desc = desc.substr(0, 97) + "..."

	return desc

## 验证条件
func validate() -> Array[String]:
	var errors = super.validate()

	if _root_node == null:
		errors.append(FuseLocalization.translate("FUSE_CONDITION_ERROR_COMPOSITE_ROOT_NULL"))
	else:
		var node_errors = []
		_validate_node(_root_node, node_errors)
		errors.append_array(node_errors)

	return errors

## 递归验证节点
func _validate_node(node: LogicNode, errors: Array[String]):
	if node == null:
		errors.append(FuseLocalization.translate("FUSE_CONDITION_ERROR_LOGIC_NODE_NULL"))
		return

	if node.is_leaf():
		if node.condition == null:
			errors.append(FuseLocalization.translate("FUSE_CONDITION_ERROR_LEAF_CONDITION_NULL"))
		else:
			var inner_errors = node.condition.validate()
			for err in inner_errors:
				errors.append(FuseLocalization.translate_format("FUSE_CONDITION_ERROR_LEAF", {"error": err}))
	else:
		if node.operands.is_empty():
			errors.append(FuseLocalization.translate_format("FUSE_CONDITION_ERROR_LOGIC_NODE_NO_OPERANDS_VALIDATION", {"operator": node.operator}))

		if node.operator == LogicOperator.NOT and node.operands.size() != 1:
			errors.append(FuseLocalization.translate("FUSE_CONDITION_ERROR_NOT_OPERAND_COUNT_VALIDATION"))

		for operand in node.operands:
			_validate_node(operand, errors)

## 获取参数
func get_parameters() -> Dictionary:
	return {
		"use_short_circuit": use_short_circuit,
		"logic_tree": logic_tree_serialized
	}

## 设置参数
func set_parameters(parameters: Dictionary):
	if parameters.has("use_short_circuit"):
		use_short_circuit = parameters["use_short_circuit"]
	if parameters.has("logic_tree"):
		logic_tree_serialized = parameters["logic_tree"]

## 重置条件状态
func reset():
	super.reset()
	if _root_node != null:
		_reset_node(_root_node)

## 递归重置节点
func _reset_node(node: LogicNode):
	if node == null:
		return

	if node.is_leaf():
		if node.condition != null and node.condition.has_method("reset"):
			node.condition.reset()
	else:
		for operand in node.operands:
			_reset_node(operand)

## ==================== 辅助构建方法 ====================

## 创建一个简单的 AND 组合
## conditions: 要组合的条件数组
static func create_and(conditions: Array[BaseCondition]) -> CheckComposite:
	var composite = CheckComposite.new()
	var and_node = LogicNode.create_logic(LogicOperator.AND)

	for cond in conditions:
		if cond != null:
			and_node.add_operand(LogicNode.create_leaf(cond))

	composite._root_node = and_node
	composite._update_resource_name()
	return composite

## 创建一个简单的 OR 组合
## conditions: 要组合的条件数组
static func create_or(conditions: Array[BaseCondition]) -> CheckComposite:
	var composite = CheckComposite.new()
	var or_node = LogicNode.create_logic(LogicOperator.OR)

	for cond in conditions:
		if cond != null:
			or_node.add_operand(LogicNode.create_leaf(cond))

	composite._root_node = or_node
	composite._update_resource_name()
	return composite

## 创建一个 NOT 组合
## condition: 要取反的条件
static func create_not(condition: BaseCondition) -> CheckComposite:
	var composite = CheckComposite.new()
	var not_node = LogicNode.create_logic(LogicOperator.NOT)

	if condition != null:
		not_node.add_operand(LogicNode.create_leaf(condition))

	composite._root_node = not_node
	composite._update_resource_name()
	return composite

## 创建复杂的嵌套组合
## structure: 嵌套的字典结构
## 示例: {
##   "operator": "OR",
##   "operands": [
##     {"operator": "AND", "conditions": [cond1, cond2]},
##     {"operator": "AND", "conditions": [cond3, cond4]}
##   ]
## }
static func create_complex(structure: Dictionary) -> CheckComposite:
	var composite = CheckComposite.new()
	composite._root_node = _build_node_from_structure(structure)
	composite._update_resource_name()
	return composite

## 从结构字典构建节点
static func _build_node_from_structure(structure: Dictionary) -> LogicNode:
	if structure.is_empty():
		return null

	# 检查是否有操作符
	if not structure.has("operator"):
		return null

	var op_str = structure["operator"]
	var operator: LogicOperator

	match op_str:
		"AND":
			operator = LogicOperator.AND
		"OR":
			operator = LogicOperator.OR
		"NOT":
			operator = LogicOperator.NOT
		_:
			return null

	# 如果有条件数组，这是叶子节点或简单逻辑节点
	if structure.has("conditions"):
		var conditions = structure["conditions"]
		if conditions.is_empty():
			return LogicNode.create_logic(operator)

		# 如果只有一个条件且操作符是 NOT，直接创建叶子节点
		if conditions.size() == 1 and operator == LogicOperator.NOT:
			var cond = conditions[0]
			if cond is BaseCondition:
				return LogicNode.create_leaf(cond)

		# 否则创建逻辑节点
		var node = LogicNode.create_logic(operator)
		for item in conditions:
			if item is BaseCondition:
				node.add_operand(LogicNode.create_leaf(item))
			elif item is Dictionary:
				var child_node = _build_node_from_structure(item)
				if child_node != null:
					node.add_operand(child_node)

		return node

	# 如果有操作数数组
	if structure.has("operands"):
		var operands = structure["operands"]
		var node = LogicNode.create_logic(operator)

		for item in operands:
			if item is BaseCondition:
				node.add_operand(LogicNode.create_leaf(item))
			elif item is Dictionary:
				var child_node = _build_node_from_structure(item)
				if child_node != null:
					node.add_operand(child_node)

		return node

	return null

## 从序列化数据构建逻辑树
func _build_logic_tree_from_serialized():
	if logic_tree_serialized.is_empty():
		_root_node = null
		return

	# 使用第一个元素作为根节点
	if logic_tree_serialized.size() > 0:
		var root_structure = logic_tree_serialized[0]
		_root_node = _build_node_from_structure(root_structure)
	else:
		_root_node = null

## 获取条件元数据
static func _get_condition_metadata() -> ConditionMetadata:
	var metadata = ConditionMetadata.new()
	metadata.name_key = "FUSE_CONDITION_COMPOSITE_NAME"
	metadata.category_key = "FUSE_CATEGORY_COMPOSITE"
	metadata.description_key = "FUSE_CONDITION_COMPOSITE_DESC"
	metadata.keywords = ["组合", "composite", "complex", "复杂", "nested", "嵌套", "logic", "逻辑", "expression", "表达式", "tree", "树"]
	metadata.builtin_icon = "Tree"
	return metadata
