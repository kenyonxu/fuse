# JuicyCondition - 条件基类
# 定义所有条件类型的通用接口，提供条件评估的基础框架

@tool
@abstract
class_name JuicyCondition
extends Resource

# 条件启用状态
@export var enabled: bool = true

# 虚拟方法 - 子类必须实现
@abstract
func evaluate(context: JuicyContext) -> bool

# 获取条件描述
@abstract
func get_description() -> String

# 验证条件配置
@abstract
func validate_condition() -> String

# 条件变化通知（可选实现）
@abstract
func on_parameter_changed(parameter_name: String, old_value: float, new_value: float) -> void