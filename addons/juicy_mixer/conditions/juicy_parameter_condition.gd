# JuicyParameterCondition - 参数条件类
# 用于比较Context中的参数值与目标值

@tool
class_name JuicyParameterCondition
extends JuicyCondition

# 参数比较操作符
enum ComparisonOperator {
	GREATER_THAN,        # >
	LESS_THAN,           # <
	GREATER_EQUAL,       # >=
	LESS_EQUAL,          # <=
	EQUAL,               # ==
	NOT_EQUAL            # !=
}

# 条件配置
@export var parameter_name: String = ""           # 参数名
@export var operator: ComparisonOperator = ComparisonOperator.EQUAL
@export var target_value: float = 0.0           # 目标值
@export var tolerance: float = 0.0001           # 浮点数比较容差

# 上次评估结果（用于缓存优化）
var _last_evaluation: bool = false
var _last_parameter_value: float = 0.0

func evaluate(context: JuicyContext) -> bool:
	if not enabled or parameter_name.is_empty():
		return false
	
	# 从Context获取参数值
	var current_value = context.get_parameter(parameter_name, 0.0)
	
	# 缓存优化：如果参数值没有变化，返回上次结果
	if abs(current_value - _last_parameter_value) < tolerance:
		return _last_evaluation
	
	_last_parameter_value = current_value
	
	# 执行比较
	match operator:
		ComparisonOperator.GREATER_THAN:
			_last_evaluation = current_value > target_value
		ComparisonOperator.LESS_THAN:
			_last_evaluation = current_value < target_value
		ComparisonOperator.GREATER_EQUAL:
			_last_evaluation = current_value >= target_value
		ComparisonOperator.LESS_EQUAL:
			_last_evaluation = current_value <= target_value
		ComparisonOperator.EQUAL:
			_last_evaluation = abs(current_value - target_value) <= tolerance
		ComparisonOperator.NOT_EQUAL:
			_last_evaluation = abs(current_value - target_value) > tolerance
		_:
			_last_evaluation = false
	
	return _last_evaluation

func get_description() -> String:
	var op_str = ""
	match operator:
		ComparisonOperator.GREATER_THAN:
			op_str = ">"
		ComparisonOperator.LESS_THAN:
			op_str = "<"
		ComparisonOperator.GREATER_EQUAL:
			op_str = ">="
		ComparisonOperator.LESS_EQUAL:
			op_str = "<="
		ComparisonOperator.EQUAL:
			op_str = "=="
		ComparisonOperator.NOT_EQUAL:
			op_str = "!="
	
	return "%s %s %.3f" % [parameter_name, op_str, target_value]

func validate_condition() -> String:
	if parameter_name.is_empty():
		return "Parameter name cannot be empty"
	return ""

func on_parameter_changed(parameter_name: String, old_value: float, new_value: float) -> void:
	# 如果是相关参数，清除缓存
	if parameter_name == self.parameter_name:
		_last_parameter_value = NAN  # 强制重新评估