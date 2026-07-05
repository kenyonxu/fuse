# JuicyCompositeCondition - 复合条件类
# 用于组合多个条件形成复杂的逻辑表达式

@tool
class_name JuicyCompositeCondition
extends JuicyCondition

# 逻辑操作符
enum LogicalOperator {
	AND,    # 所有条件都必须满足
	OR       # 至少一个条件满足
}

# 复合条件配置
@export var operator: LogicalOperator = LogicalOperator.AND
@export var conditions: Array[JuicyCondition] = []

# 短路评估优化
var _short_circuit_result: Dictionary = {}

func evaluate(context: JuicyContext) -> bool:
	if not enabled or conditions.is_empty():
		return true
	
	# 生成上下文唯一标识（用于短路评估缓存）
	var context_key = _generate_context_key(context)
	
	# 检查缓存
	if _short_circuit_result.has(context_key):
		return _short_circuit_result[context_key]
	
	var result = false
	
	match operator:
		LogicalOperator.AND:
			# 所有条件都必须满足（短路评估）
			result = true
			for condition in conditions:
				if not condition.evaluate(context):
					result = false
					break  # 短路：只要有一个条件不满足，整个AND表达式为false
		
		LogicalOperator.OR:
			# 至少一个条件满足（短路评估）
			result = false
			for condition in conditions:
				if condition.evaluate(context):
					result = true
					break  # 短路：只要有一个条件满足，整个OR表达式为true
		
		_:
			result = false
	
	# 缓存结果
	_short_circuit_result[context_key] = result
	return result

func get_description() -> String:
	var op_str = "AND" if operator == LogicalOperator.AND else "OR"
	var descriptions = []
	for condition in conditions:
		descriptions.append(condition.get_description())
	return "(%s)" % (" %s " % op_str).join(descriptions)

func validate_condition() -> String:
	if conditions.is_empty():
		return "Composite condition must have at least one sub-condition"
	
	for i in range(conditions.size()):
		var condition = conditions[i]
		if not condition:
			return "Condition at index %d is null" % i
		
		var error = condition.validate_condition()
		if not error.is_empty():
			return "Sub-condition %d error: %s" % [i, error]
	
	return ""

# 清除缓存（当参数变化时调用）
func clear_cache() -> void:
	_short_circuit_result.clear()
	
	# 递归清除子条件缓存
	for condition in conditions:
		if condition.has_method("clear_cache"):
			condition.clear_cache()

func _generate_context_key(context: JuicyContext) -> String:
	"""生成用于缓存的上下文唯一标识"""
	var key_parts = [context.context_id]
	
	# 添加相关参数值到key中
	for condition in conditions:
		if condition is JuicyParameterCondition:
			var param_cond = condition as JuicyParameterCondition
			var param_value = context.get_parameter(param_cond.parameter_name, 0.0)
			key_parts.append("%s:%.3f" % [param_cond.parameter_name, param_value])
	
	return "|".join(key_parts)

func on_parameter_changed(parameter_name: String, old_value: float, new_value: float) -> void:
	# 当参数变化时清除缓存
	clear_cache()