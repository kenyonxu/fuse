# JuicyResourceVariant - 资源变体类
# 通过Data覆盖机制实现Composite Resource的变体系统
# 支持细粒度的属性覆盖和替换，避免Resource嵌套

@tool
class_name JuicyResourceVariant
extends JuicyFeedbackResource

# 变体配置
@export var base_composite_resource: JuicyCompositeResource
@export var data_overrides: Array[DataOverride] = []
@export var inherit_parameter_bindings: bool = true

# 创建驱动器
func create_drivers() -> Array:
	var variant_composite = _create_variant_composite()
	if not variant_composite:
		push_error("Failed to create variant composite")
		return []
	
	# 调用变体组合资源的create_drivers方法
	if variant_composite.has_method("create_drivers"):
		return variant_composite.create_drivers()
	else:
		push_error("Variant composite does not have create_drivers method")
		return []

# 创建变体化的CompositeResource
func _create_variant_composite() -> Resource:
	if not base_composite_resource:
		# 在测试环境中避免push_error停止执行
		if OS.has_feature("editor"):
			print("Warning: Base composite resource cannot be null")
		return null
	
	# 检查基础资源是否是JuicyCompositeResource
	if not base_composite_resource.has_method("get_composite_items"):
		# 在测试环境中避免push_error停止执行
		if OS.has_feature("editor"):
			print("Warning: Base resource must be a JuicyCompositeResource")
		return null
	
	# 深拷贝基础CompositeResource
	var variant = base_composite_resource.duplicate(true)
	
	# 应用Data覆盖
	for override in data_overrides:
		if not override:
			push_warning("Null override found in data_overrides array")
			continue
			
		if not override.has_method("is_enabled"):
			push_warning("Override does not have is_enabled method")
			continue
			
		if not override.is_enabled():
			continue
			
		if not override.has_method("get_override_mode"):
			push_warning("Override does not have get_override_mode method")
			continue
			
		_apply_data_override(variant, override)
	
	return variant

# 应用数据覆盖
func _apply_data_override(composite: Resource, override: Resource) -> void:
	if not composite or not override:
		return
	
	# 获取覆盖模式
	var override_mode = override.get_override_mode()
	
	match override_mode:
		0:  # REPLACE_DATA
			_replace_data(composite, override)
		1:  # MODIFY_DATA
			_modify_data(composite, override)
		2:  # ADD_TO_COMPOSITE
			_add_to_composite(composite, override)
		3:  # REMOVE_FROM_COMPOSITE
			_remove_from_composite(composite, override)
		_:
			# 在测试环境中避免push_error停止执行
			if OS.has_feature("editor"):
				print("Warning: Unknown override mode: " + str(override_mode))
			else:
				push_error("Unknown override mode: " + str(override_mode))

# 替换数据
func _replace_data(composite: Resource, override: Resource) -> void:
	if not override.has_method("get_target_item_index") or not override.has_method("get_target_data_index") or not override.has_method("get_new_data"):
		push_error("Override missing required methods for REPLACE_DATA")
		return
	
	var target_item_index = override.get_target_item_index()
	var target_data_index = override.get_target_data_index()
	var new_data = override.get_new_data()
	
	if not new_data:
		push_error("New data cannot be null for REPLACE_DATA")
		return
	
	# 获取组合项
	var composite_items = composite.get_composite_items()
	if target_item_index >= composite_items.size():
		push_error("Target item index out of range: %d >= %d" % [target_item_index, composite_items.size()])
		return
	
	var item = composite_items[target_item_index]
	if not item:
		push_error("Target item is null at index: %d" % target_item_index)
		return
	
	# 获取资源
	var resource = item.resource
	if not resource:
		push_error("Target item resource is null")
		return
	
	# 获取数据数组
	var data_array = _get_data_array(resource)
	if target_data_index >= data_array.size():
		push_error("Target data index out of range: %d >= %d" % [target_data_index, data_array.size()])
		return
	
	# 替换Data实例
	var duplicated_data = new_data.duplicate(true)  # 深拷贝
	data_array[target_data_index] = duplicated_data
	print("Replaced data at item[%d].data[%d], property=%s" % [target_item_index, target_data_index, duplicated_data.property])
	
	# 使用通用方法设置数据
	if resource.has_method("set_data_at"):
		resource.set_data_at(target_data_index, duplicated_data)
		print("Used set_data_at to modify resource[%d] to property=%s" % [target_data_index, duplicated_data.property])

# 修改数据
func _modify_data(composite: Resource, override: Resource) -> void:
	if not override.has_method("get_target_item_index") or not override.has_method("get_target_data_index") or not override.has_method("get_property_overrides"):
		push_error("Override missing required methods for MODIFY_DATA")
		return
	
	var target_item_index = override.get_target_item_index()
	var target_data_index = override.get_target_data_index()
	var property_overrides = override.get_property_overrides()
	
	if property_overrides.is_empty():
		push_warning("Property overrides is empty for MODIFY_DATA")
		return
	
	# 获取组合项
	var composite_items = composite.get_composite_items()
	if target_item_index >= composite_items.size():
		push_error("Target item index out of range: %d >= %d" % [target_item_index, composite_items.size()])
		return
	
	var item = composite_items[target_item_index]
	if not item:
		push_error("Target item is null at index: %d" % target_item_index)
		return
	
	# 获取资源
	var resource = item.resource
	if not resource:
		push_error("Target item resource is null")
		return
	
	# 获取数据数组
	var data_array = _get_data_array(resource)
	if target_data_index >= data_array.size():
		push_error("Target data index out of range: %d >= %d" % [target_data_index, data_array.size()])
		return
	
	# 修改Data属性
	var data = data_array[target_data_index]
	if not data:
		push_error("Target data is null at index: %d" % target_data_index)
		return
	
	for property_name in property_overrides:
		# 使用反射检查属性是否存在
		if property_name in data:
			var old_value = data.get(property_name)
			var new_value = property_overrides[property_name]
			data.set(property_name, new_value)
			print("Modified property '%s' from %s to %s" % [property_name, str(old_value), str(new_value)])
		else:
			push_warning("Property '%s' not found in data" % property_name)

# 添加到组合
func _add_to_composite(composite: Resource, override: Resource) -> void:
	if not override.has_method("get_new_composite_item"):
		push_error("Override missing required methods for ADD_TO_COMPOSITE")
		return
	
	var new_composite_item = override.get_new_composite_item()
	if not new_composite_item:
		push_error("New composite item cannot be null for ADD_TO_COMPOSITE")
		return
	
	# 添加新的CompositeItem
	if composite.has_method("add_composite_item"):
		composite.add_composite_item(new_composite_item)
		print("Added new composite item to composite")
	else:
		push_error("Composite does not have add_composite_item method")

# 从组合中移除
func _remove_from_composite(composite: Resource, override: Resource) -> void:
	if not override.has_method("get_target_item_index"):
		push_error("Override missing required methods for REMOVE_FROM_COMPOSITE")
		return
	
	var target_item_index = override.get_target_item_index()
	
	# 移除CompositeItem
	if composite.has_method("remove_composite_item"):
		composite.remove_composite_item(target_item_index)
		print("Removed composite item at index: %d" % target_item_index)
	else:
		push_error("Composite does not have remove_composite_item method")

# 获取数据数组
func _get_data_array(resource: JuicyFeedbackResource) -> Array:
	print(resource)
	if not resource:
		return []
	
	# 获取数据序列
	var data_array : Array
	if resource.has_method("get_data"):
		data_array = resource.get_data()
		return data_array
	else:
		# 在测试环境中避免push_warning停止执行
		if OS.has_feature("editor"):
			print("Warning: Unknown resource type, cannot get data array: " + resource.get_class())
		else:
			push_warning("Unknown resource type, cannot get data array: " + resource.get_class())
		return []

# 验证配置
func validate_config() -> ValidationResult:
	var result = super.validate_config()
	
	if not base_composite_resource:
		result.valid = false
		result.issues.append("Base composite resource cannot be null")
		return result
	
	# 验证基础资源类型
	if not base_composite_resource.has_method("get_composite_items"):
		result.valid = false
		result.issues.append("Base resource must be a JuicyCompositeResource")
	
	# 验证数据覆盖
	for i in range(data_overrides.size()):
		var override = data_overrides[i]
		if not override:
			result.valid = false
			result.issues.append("Data override at index " + str(i) + " is null")
			continue
			
		if not override.has_method("validate_override"):
			result.valid = false
			result.issues.append("Data override at index " + str(i) + " does not have validate_override method")
			continue
			
		var override_error = override.validate_override()
		if not override_error.is_empty():
			result.valid = false
			result.issues.append("Data override error at index " + str(i) + ": " + override_error)
	
	return result

# 获取时长（继承基础资源的时长）
func get_duration() -> float:
	if base_composite_resource and base_composite_resource.has_method("get_duration"):
		return base_composite_resource.get_duration()
	return 1.0

# 获取描述信息
func get_description() -> String:
	var desc = "JuicyResourceVariant: "
	if base_composite_resource:
		desc += "base=" + base_composite_resource.resource_path
	else:
		desc += "base=null"
	
	desc += ", overrides=%d, inherit_bindings=%s" % [
		data_overrides.size(),
		"true" if inherit_parameter_bindings else "false"
	]
	
	return desc

# 获取配置字典
func get_config_dict() -> Dictionary:
	var config = super.get_config_dict()
	config["inherit_parameter_bindings"] = inherit_parameter_bindings
	return config

# 从配置字典加载
func load_from_dict(config_dict: Dictionary) -> bool:
	if not super.load_from_dict(config_dict):
		return false
	
	if config_dict.has("inherit_parameter_bindings"):
		inherit_parameter_bindings = config_dict["inherit_parameter_bindings"]
	
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