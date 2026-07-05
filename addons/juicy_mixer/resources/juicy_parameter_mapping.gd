# JuicyParameterMapping - 参数映射配置
# 定义参数映射的配置，用于将外部输入参数映射到特定属性
# 支持曲线映射，实现复杂的参数转换关系
# 兼容组合资源和轨道级参数映射

@tool
class_name JuicyParameterMapping
extends Resource

# 映射类型枚举
enum MappingType {
	COMPOSITE_RESOURCE,  # 映射到组合资源中的项（传统模式）
	TRACK_PROPERTY,     # 映射到轨道属性
	TRACK_TIME,         # 映射到轨道时间参数
	TRACK_VALUE,        # 映射到轨道值参数
	METHOD_ARGUMENT,    # 映射到方法参数
	EVENT_PROPERTY,     # 映射到事件属性
	CUSTOM              # 自定义映射
}

# 参数映射配置
@export var input_parameter: String = "intensity"  # 外部输入的参数名
@export var mapping_type: MappingType = MappingType.COMPOSITE_RESOURCE  # 映射类型
@export var target_item_index: int = 0           # 绑定到Composite中的哪个子Resource（仅用于COMPOSITE_RESOURCE类型）
@export var target_property: String = ""          # 绑定到Resource的哪个属性
@export var target_argument_index: int = -1       # 目标参数索引（用于METHOD_ARGUMENT类型）
@export var curve: Curve                         # 映射曲线
@export var enabled: bool = true
@export var custom_handler: String = ""           # 自定义处理函数名（用于CUSTOM类型）

# 高级映射选项
@export var input_range: Vector2 = Vector2(0.0, 1.0)    # 输入值范围
@export var output_range: Vector2 = Vector2(0.0, 1.0)   # 输出值范围
@export var clamp_output: bool = true                    # 是否限制输出值
@export var invert_mapping: bool = false                 # 是否反转映射

# 验证映射配置
func validate_mapping() -> String:
	"""
	验证映射配置的有效性
	
	@return: 错误信息，如果验证通过则返回空字符串
	"""
	if input_parameter.is_empty():
		return "Input parameter cannot be empty"
	
	# 根据映射类型验证不同字段
	match mapping_type:
		MappingType.COMPOSITE_RESOURCE:
			if target_property.is_empty():
				return "Target property cannot be empty for composite resource mapping"
			if target_item_index < 0:
				return "Target item index cannot be negative"
		
		MappingType.METHOD_ARGUMENT:
			if target_argument_index < 0:
				return "Target argument index cannot be negative for method argument mapping"
		
		MappingType.CUSTOM:
			if custom_handler.is_empty():
				return "Custom handler name cannot be empty for custom mapping"
		
		_:  # 其他类型
			if target_property.is_empty():
				return "Target property cannot be empty"
	
	# 验证输入范围
	if input_range.x >= input_range.y:
		return "Input range minimum must be less than maximum"
	
	# 验证输出范围
	if output_range.x >= output_range.y:
		return "Output range minimum must be less than maximum"
	
	return ""  # 验证通过

# 获取映射的描述信息
func get_description() -> String:
	"""
	获取映射配置的描述信息
	
	@return: 描述字符串，包含输入参数、目标项索引、目标属性和曲线信息
	"""
	var desc = "%s -> item[%d].%s" % [
		input_parameter, target_item_index, target_property
	]
	if curve:
		desc += " (with curve mapping)"
	else:
		desc += " (direct mapping)"
	return desc

# 应用映射
func apply_mapping(input_value: float) -> float:
	"""
	应用参数映射，使用曲线进行值转换
	
	@param input_value: 输入参数值
	@return: 映射后的参数值
	"""
	if not enabled:
		return 0.0
	
	# 应用输入范围映射
	var normalized_input = _normalize_input(input_value)
	
	# 应用曲线映射（如果有）
	var mapped_value = normalized_input
	if curve and curve.get_point_count() > 0:
		mapped_value = curve.sample(clampf(normalized_input, 0.0, 1.0))
	
	# 应用输出范围映射
	var final_value = _denormalize_output(mapped_value)
	
	# 反转映射（如果需要）
	if invert_mapping:
		final_value = output_range.y - (final_value - output_range.x)
	
	# 限制输出值（如果需要）
	if clamp_output:
		final_value = clampf(final_value, output_range.x, output_range.y)
	
	return final_value

# 标准化输入值到0-1范围
func _normalize_input(value: float) -> float:
	"""
	将输入值标准化到0-1范围
	
	@param value: 原始输入值
	@return: 标准化后的值
	"""
	if input_range.x == input_range.y:
		return 0.0
	
	return clampf((value - input_range.x) / (input_range.y - input_range.x), 0.0, 1.0)

# 反标准化输出值到目标范围
func _denormalize_output(value: float) -> float:
	"""
	将0-1范围的值反标准化到输出范围
	
	@param value: 标准化的值
	@return: 反标准化后的值
	"""
	if output_range.x == output_range.y:
		return output_range.x
	
	return output_range.x + value * (output_range.y - output_range.x)

# 验证目标项索引（仅用于COMPOSITE_RESOURCE类型）
func _validate_target_item_index(composite_resource: JuicyCompositeResource) -> String:
	"""
	验证目标项索引是否有效
	
	@param composite_resource: 组合资源实例
	@return: 错误信息，如果验证通过则返回空字符串
	"""
	if mapping_type != MappingType.COMPOSITE_RESOURCE:
		return ""
	
	if not composite_resource:
		return "Composite resource cannot be null"
	
	if target_item_index >= composite_resource.composite_items.size():
		return "Target item index %d is out of bounds (max: %d)" % [
			target_item_index, composite_resource.composite_items.size() - 1
		]
	
	var target_item = composite_resource.composite_items[target_item_index]
	if not target_item:
		return "Target item at index %d is null" % target_item_index
	
	if not target_item.resource:
		return "Target item resource at index %d is null" % target_item_index
	
	return ""  # 验证通过

# 验证目标属性
func _validate_target_property(target_resource: Resource) -> String:
	"""
	验证目标属性是否存在于资源中
	
	@param target_resource: 目标资源实例
	@return: 错误信息，如果验证通过则返回空字符串
	"""
	if not target_resource:
		return "Target resource cannot be null"
	
	if target_property.is_empty():
		return "Target property cannot be empty"
	
	# 根据映射类型进行不同的验证
	match mapping_type:
		MappingType.COMPOSITE_RESOURCE:
			# 检查属性是否存在于资源中
			if target_resource.has_method("get_data_array"):
				var data_array = target_resource.get_data_array()
				if data_array.size() > 0:
					var first_data = data_array[0]
					if first_data and first_data.has_method("has_property"):
						if not first_data.has_property(target_property):
							return "Target property '%s' not found in resource data" % target_property
					else:
						# 如果没有has_property方法，尝试直接检查
						if not target_property in first_data:
							return "Target property '%s' not found in resource data" % target_property
				else:
					return "No data found in target resource"
			else:
				# 如果没有get_data_array方法，尝试直接检查资源属性
				if not target_property in target_resource:
					return "Target property '%s' not found in resource" % target_property
		
		MappingType.TRACK_PROPERTY, MappingType.TRACK_TIME, MappingType.TRACK_VALUE:
			# 轨道级映射的属性验证
			var valid_track_properties = ["intensity", "time_scale", "time_offset", "value_range_min", "value_range_max", "offset", "scale", "override"]
			if not target_property in valid_track_properties:
				return "Invalid track property '%s'. Valid properties: %s" % [target_property, valid_track_properties]
		
		MappingType.EVENT_PROPERTY:
			# 事件属性验证
			var valid_event_properties = ["volume", "pitch", "position", "intensity", "duration"]
			if not target_property in valid_event_properties:
				return "Invalid event property '%s'. Valid properties: %s" % [target_property, valid_event_properties]
	
	return ""  # 验证通过

# 获取配置字典（用于序列化）
func get_config_dict() -> Dictionary:
	"""
	获取映射配置的字典表示，用于序列化
	
	@return: 包含所有配置属性的字典
	"""
	var config = {
		"input_parameter": input_parameter,
		"mapping_type": MappingType.keys()[mapping_type],
		"target_item_index": target_item_index,
		"target_property": target_property,
		"target_argument_index": target_argument_index,
		"enabled": enabled,
		"input_range": {"x": input_range.x, "y": input_range.y},
		"output_range": {"x": output_range.x, "y": output_range.y},
		"clamp_output": clamp_output,
		"invert_mapping": invert_mapping,
		"custom_handler": custom_handler
	}
	
	# 保存曲线资源路径（如果存在）
	if curve:
		config["curve_path"] = curve.resource_path
	
	return config

# 从配置字典加载（用于反序列化）
func load_from_dict(config_dict: Dictionary) -> bool:
	"""
	从字典加载映射配置，用于反序列化
	
	@param config_dict: 包含配置属性的字典
	@return: 加载是否成功
	"""
	# 空字典应该加载成功，但不改变任何现有值
	if not config_dict:
		return true
	
	# 加载基础配置
	if config_dict.has("input_parameter"):
		input_parameter = config_dict["input_parameter"]
	if config_dict.has("mapping_type"):
		var type_name = config_dict["mapping_type"]
		for i in range(MappingType.values().size()):
			if MappingType.keys()[i] == type_name:
				mapping_type = MappingType.values()[i]
				break
	if config_dict.has("target_item_index"):
		target_item_index = config_dict["target_item_index"]
	if config_dict.has("target_property"):
		target_property = config_dict["target_property"]
	if config_dict.has("target_argument_index"):
		target_argument_index = config_dict["target_argument_index"]
	if config_dict.has("enabled"):
		enabled = config_dict["enabled"]
	
	# 加载高级配置
	if config_dict.has("input_range"):
		var range_dict = config_dict["input_range"]
		input_range = Vector2(range_dict.get("x", 0.0), range_dict.get("y", 1.0))
	if config_dict.has("output_range"):
		var range_dict = config_dict["output_range"]
		output_range = Vector2(range_dict.get("x", 0.0), range_dict.get("y", 1.0))
	if config_dict.has("clamp_output"):
		clamp_output = config_dict["clamp_output"]
	if config_dict.has("invert_mapping"):
		invert_mapping = config_dict["invert_mapping"]
	if config_dict.has("custom_handler"):
		custom_handler = config_dict["custom_handler"]
	
	# 注意：曲线资源的实际加载需要在更高层处理
	# 这里只保存配置数据
	
	return true

# 获取资源类型
func get_resource_type() -> String:
	"""
	获取资源类型标识
	
	@return: 资源类型字符串
	"""
	return "JuicyParameterMapping"

# 复制资源
func _duplicate_properties(destination: Resource) -> void:
	"""
	复制资源属性到目标资源
	
	@param destination: 目标资源实例
	"""
	if destination is JuicyParameterMapping:
		var mapping = destination as JuicyParameterMapping
		mapping.input_parameter = input_parameter
		mapping.mapping_type = mapping_type
		mapping.target_item_index = target_item_index
		mapping.target_property = target_property
		mapping.target_argument_index = target_argument_index
		mapping.enabled = enabled
		mapping.input_range = input_range
		mapping.output_range = output_range
		mapping.clamp_output = clamp_output
		mapping.invert_mapping = invert_mapping
		mapping.custom_handler = custom_handler
		
		# 深拷贝曲线
		if curve:
			mapping.curve = curve.duplicate()

# 获取映射类型描述
func get_mapping_type_description() -> String:
	"""
	获取映射类型的描述
	
	@return: 映射类型描述字符串
	"""
	match mapping_type:
		MappingType.COMPOSITE_RESOURCE:
			return "Composite Resource"
		MappingType.TRACK_PROPERTY:
			return "Track Property"
		MappingType.TRACK_TIME:
			return "Track Time"
		MappingType.TRACK_VALUE:
			return "Track Value"
		MappingType.METHOD_ARGUMENT:
			return "Method Argument"
		MappingType.EVENT_PROPERTY:
			return "Event Property"
		MappingType.CUSTOM:
			return "Custom"
		_:
			return "Unknown"

# 获取调试信息
func get_debug_info() -> String:
	"""
	获取调试信息
	
	@return: 调试信息字符串
	"""
	var info = "JuicyParameterMapping:\n"
	info += "  Input Parameter: " + input_parameter + "\n"
	info += "  Mapping Type: " + get_mapping_type_description() + "\n"
	info += "  Target Item Index: " + str(target_item_index) + "\n"
	info += "  Target Property: " + target_property + "\n"
	info += "  Target Argument Index: " + str(target_argument_index) + "\n"
	info += "  Enabled: " + ("true" if enabled else "false") + "\n"
	info += "  Input Range: " + str(input_range) + "\n"
	info += "  Output Range: " + str(output_range) + "\n"
	info += "  Clamp Output: " + ("true" if clamp_output else "false") + "\n"
	info += "  Invert Mapping: " + ("true" if invert_mapping else "false") + "\n"
	info += "  Custom Handler: " + custom_handler + "\n"
	info += "  Has Curve: " + ("true" if curve else "false") + "\n"
	
	if curve:
		info += "  Curve Points: " + str(curve.get_point_count()) + "\n"
	
	return info

# 应用自定义映射处理
func apply_custom_mapping(input_value: float, context: Object = null) -> float:
	"""
	应用自定义映射处理
	
	@param input_value: 输入值
	@param context: 上下文对象（可选）
	@return: 处理后的值
	"""
	if mapping_type != MappingType.CUSTOM or custom_handler.is_empty():
		return apply_mapping(input_value)
	
	if not context:
		return apply_mapping(input_value)
	
	# 尝试调用自定义处理函数
	if context.has_method(custom_handler):
		var args = [input_value, self]
		return context.callv(custom_handler, args)
	else:
		print("Warning: Custom handler '", custom_handler, "' not found in context")
		return apply_mapping(input_value)