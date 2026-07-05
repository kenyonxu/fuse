# JuicyCompositeItem - 组合反馈项
# 定义组合效果中的单个项，包含资源引用、权重、条件等配置
# 用于JuicyCompositeResource中的组合项管理

@tool
class_name JuicyCompositeItem
extends Resource

# 基础配置
@export var resource: JuicyFeedbackResource
@export var weight: float = 1.0
@export var condition: JuicyCondition
@export var enabled: bool = true
@export var priority: int = 0

# 验证组合项配置
func validate_item() -> String:
	var errors = []
	
	# 检查resource不为null
	if not resource:
		errors.append("Resource cannot be null")
	
	# 检查weight不为负数
	if weight < 0.0:
		errors.append("Weight cannot be negative")
	
	# 如果有condition，验证condition
	if condition:
		var condition_error = condition.validate_condition()
		if not condition_error.is_empty():
			errors.append("Condition validation failed: " + condition_error)
	
	return "\n".join(errors)

# 获取组合项的描述信息
func get_description() -> String:
	var desc = "JuicyCompositeItem: "
	
	# 资源路径
	if resource:
		desc += "resource=" + resource.resource_path
	else:
		desc += "resource=null"
	
	# 权重
	desc += ", weight=" + str(weight)
	
	# 优先级
	desc += ", priority=" + str(priority)
	
	# 启用状态
	desc += ", enabled=" + ("true" if enabled else "false")
	
	# 条件描述
	if condition:
		desc += ", condition=" + condition.get_description()
	else:
		desc += ", condition=null"
	
	return desc

# 获取资源类型
func get_resource_type() -> String:
	return "JuicyCompositeItem"

# 序列化支持
func get_config_dict() -> Dictionary:
	var config = {
		"weight": weight,
		"enabled": enabled,
		"priority": priority
	}
	
	# 保存资源引用
	if resource:
		config["resource_path"] = resource.resource_path
	
	# 保存条件引用
	if condition:
		config["condition_path"] = condition.resource_path
	
	return config

# 反序列化支持
func load_from_dict(config_dict: Dictionary) -> bool:
	if not config_dict:
		return false
	
	# 加载基础配置
	if config_dict.has("weight"):
		weight = config_dict["weight"]
	if config_dict.has("enabled"):
		enabled = config_dict["enabled"]
	if config_dict.has("priority"):
		priority = config_dict["priority"]
	
	# 注意：资源引用的实际加载需要在更高层处理
	# 这里只保存配置数据
	
	return true