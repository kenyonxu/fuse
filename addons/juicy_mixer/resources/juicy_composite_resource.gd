# JuicyCompositeResource - 组合反馈资源
# 定义效果组合的配置结构，管理多个JuicyFeedbackResource的组合
# 支持参数绑定系统，提供混合模式和权重控制

@tool
class_name JuicyCompositeResource
extends JuicyFeedbackResource

# 组合混合模式
enum CompositeBlendMode {
	ADDITIVE,           # 叠加
	MULTIPLICATIVE,     # 乘法
	OVERRIDE,          # 覆盖
	WEIGHTED_AVERAGE    # 加权平均
}

# 组合配置
@export var composite_items: Array[JuicyCompositeItem] = []
@export var blend_mode: CompositeBlendMode = CompositeBlendMode.ADDITIVE
@export var normalize_weights: bool = true
@export var dynamic_weight_adjustment: bool = false

# 联觉系统配置
@export var parameter_mappings: Array[JuicyParameterMapping] = []
@export var enable_parameter_mapping: bool = false
@export var auto_update_parameters: bool = true

func create_drivers() -> Array:
	var driver = JuicyCompositeDriver.new()
	driver.composite_resource = self
	return [driver]

func validate_config() -> ValidationResult:
	var result = super.validate_config()
	
	if composite_items.is_empty():
		result.valid = false
		result.issues.append("Composite items cannot be empty")
	
	# 验证每个组合项
	for i in range(composite_items.size()):
		var item = composite_items[i]
		if not item:
			result.valid = false
			result.issues.append("Item cannot be null at index " + str(i))
			continue
			
		if not item.resource:
			result.valid = false
			result.issues.append("Resource cannot be null at index " + str(i))
		
		if item.weight < 0.0:
			result.valid = false
			result.issues.append("Weight cannot be negative at index " + str(i))
		
		# 验证组合项配置
		var item_validation_error = item.validate_item()
		if not item_validation_error.is_empty():
			result.valid = false
			result.issues.append("Item validation failed at index " + str(i) + ": " + item_validation_error)
	
	# 验证参数映射
	if enable_parameter_mapping:
		for i in range(parameter_mappings.size()):
			var mapping = parameter_mappings[i]
			if not mapping:
				result.valid = false
				result.issues.append("Parameter mapping cannot be null at index " + str(i))
				continue
				
			var mapping_error = mapping.validate_mapping() if mapping.has_method("validate_mapping") else ""
			if not mapping_error.is_empty():
				result.valid = false
				result.issues.append("Parameter mapping error at index " + str(i) + ": " + mapping_error)
	
	return result

# 获取组合项数量
func get_item_count() -> int:
	return composite_items.size()

# 获取组合项数组
func get_composite_items() -> Array[JuicyCompositeItem]:
	return composite_items

# 添加组合项
func add_composite_item(item) -> void:
	if item:
		composite_items.append(item)

# 移除组合项
func remove_composite_item(index: int) -> void:
	if index >= 0 and index < composite_items.size():
		composite_items.remove_at(index)

# 清空所有组合项
func clear_composite_items() -> void:
	composite_items.clear()

# 添加参数映射
func add_parameter_mapping(mapping) -> void:
	if mapping:
		parameter_mappings.append(mapping)

# 移除参数映射
func remove_parameter_mapping(index: int) -> void:
	if index >= 0 and index < parameter_mappings.size():
		parameter_mappings.remove_at(index)

# 清空所有参数映射
func clear_parameter_mappings() -> void:
	parameter_mappings.clear()

# 获取总权重
func get_total_weight() -> float:
	var total_weight = 0.0
	for item in composite_items:
		if item and item.enabled:
			total_weight += item.weight
	return total_weight

# 获取标准化权重
func get_normalized_weights() -> Array[float]:
	var weights: Array[float] = []
	var total_weight = get_total_weight()
	
	if total_weight <= 0.0:
		# 如果总权重为0，平均分配权重
		var count = composite_items.size()
		for i in range(count):
			weights.append(1.0 / count)
	else:
		for item in composite_items:
			if item and item.enabled:
				weights.append(item.weight / total_weight)
			else:
				weights.append(0.0)
	
	return weights

# 获取描述信息
func get_description() -> String:
	var desc = "JuicyCompositeResource: "
	desc += "%d items, blend_mode=%s, mapping_enabled=%s" % [
		composite_items.size(),
		CompositeBlendMode.keys()[blend_mode],
		"true" if enable_parameter_mapping else "false"
	]
	return desc

# 获取时长来源类型
func get_duration_source() -> DurationSource:
	"""
	返回组合资源的时长来源类型
	
	@return: 
		- EXACT: 如果所有子资源都是精确时长
		- ESTIMATED: 如果有任何子资源是估算时长
	"""
	if composite_items.is_empty():
		return DurationSource.EXACT
	
	# 检查所有子资源的时长类型
	for item in composite_items:
		if item and item.resource and item.resource.has_method("get_duration_source"):
			var source = item.resource.get_duration_source()
			if source == DurationSource.ESTIMATED:
				# 如果有任何子资源是估算时长，返回估算（保守估计）
				return DurationSource.ESTIMATED
	
	# 所有子资源都是精确时长
	return DurationSource.EXACT

# 获取时长（取所有子项的最大时长）
func get_duration() -> float:
	var max_duration = 0.0
	for item in composite_items:
		if item and item.resource and item.resource.has_method("get_duration"):
			var item_duration = item.resource.get_duration()
			max_duration = max(max_duration, item_duration)
	return max_duration

# 序列化支持
func get_config_dict() -> Dictionary:
	var config = super.get_config_dict()
	config["blend_mode"] = CompositeBlendMode.keys()[blend_mode]
	config["normalize_weights"] = normalize_weights
	config["dynamic_weight_adjustment"] = dynamic_weight_adjustment
	config["enable_parameter_mapping"] = enable_parameter_mapping
	config["auto_update_parameters"] = auto_update_parameters
	return config

func load_from_dict(config_dict: Dictionary) -> bool:
	if not super.load_from_dict(config_dict):
		return false
	
	if config_dict.has("blend_mode"):
		var mode_name = config_dict["blend_mode"]
		for i in range(CompositeBlendMode.values().size()):
			if CompositeBlendMode.keys()[i] == mode_name:
				blend_mode = CompositeBlendMode.values()[i]
				break
	
	if config_dict.has("normalize_weights"):
		normalize_weights = config_dict["normalize_weights"]
	if config_dict.has("dynamic_weight_adjustment"):
		dynamic_weight_adjustment = config_dict["dynamic_weight_adjustment"]
	if config_dict.has("enable_parameter_mapping"):
		enable_parameter_mapping = config_dict["enable_parameter_mapping"]
	if config_dict.has("auto_update_parameters"):
		auto_update_parameters = config_dict["auto_update_parameters"]
	
	return true

# 实现JuicyFeedbackResource的抽象方法
func get_data_count() -> int:
	return 0

func get_data_at(index: int) -> JuicyFeedbackData:
	return null

func set_data_at(index: int, source: JuicyFeedbackData) -> void:
	pass

func get_data() -> Array[JuicyFeedbackData]:
	return []
