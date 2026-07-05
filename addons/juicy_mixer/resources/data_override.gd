# DataOverride - 数据覆盖类
# 用于在JuicyResourceVariant中实现Data级别的精确覆盖机制
# 支持替换、修改、添加和移除Composite中的Data实例

@tool
class_name DataOverride
extends Resource

# 覆盖模式枚举
enum OverrideMode {
	REPLACE_DATA,        # 替换整个Data
	MODIFY_DATA,         # 修改Data的特定属性
	ADD_TO_COMPOSITE,    # 添加新的CompositeItem
	REMOVE_FROM_COMPOSITE # 从Composite移除Item
}

# 覆盖配置
@export var override_mode: OverrideMode = OverrideMode.REPLACE_DATA
@export var target_item_index: int = -1     # 目标CompositeItem索引
@export var target_data_index: int = -1      # 目标Data索引
@export var new_data: Resource               # 新Data（用于REPLACE_DATA模式）
@export var property_overrides: Dictionary = {} # 属性覆盖（用于MODIFY_DATA模式）
@export var new_composite_item: Resource     # 新CompositeItem（用于ADD_TO_COMPOSITE）
@export var enabled: bool = true

# 验证覆盖配置
func validate_override() -> String:
	if not enabled:
		return ""  # 禁用的覆盖不需要验证
	
	if override_mode == OverrideMode.REPLACE_DATA:
		if not new_data:
			return "New data cannot be null when override_mode is REPLACE_DATA"
		if target_item_index < 0:
			return "Target item index cannot be negative for REPLACE_DATA"
		if target_data_index < 0:
			return "Target data index cannot be negative for REPLACE_DATA"
	
	if override_mode == OverrideMode.MODIFY_DATA:
		if property_overrides.is_empty():
			return "Property overrides cannot be empty when override_mode is MODIFY_DATA"
		if target_item_index < 0:
			return "Target item index cannot be negative for MODIFY_DATA"
		if target_data_index < 0:
			return "Target data index cannot be negative for MODIFY_DATA"
	
	if override_mode == OverrideMode.ADD_TO_COMPOSITE:
		if not new_composite_item:
			return "New composite item cannot be null when override_mode is ADD_TO_COMPOSITE"
	
	if override_mode == OverrideMode.REMOVE_FROM_COMPOSITE:
		if target_item_index < 0:
			return "Target item index cannot be negative for REMOVE_FROM_COMPOSITE"
	
	return ""  # 验证通过

# 获取覆盖的描述信息
func get_description() -> String:
	if not enabled:
		return "Disabled override"
	
	var desc = "%s" % OverrideMode.keys()[override_mode]
	
	match override_mode:
		OverrideMode.REPLACE_DATA:
			desc += " -> item[%d].data[%d]" % [target_item_index, target_data_index]
			if new_data:
				desc += " with %s" % new_data.get_class()
		OverrideMode.MODIFY_DATA:
			desc += " -> item[%d].data[%d].properties" % [target_item_index, target_data_index]
			desc += " (%d properties)" % property_overrides.size()
		OverrideMode.ADD_TO_COMPOSITE:
			desc += " -> new item"
			if new_composite_item:
				desc += " (%s)" % new_composite_item.get_class()
		OverrideMode.REMOVE_FROM_COMPOSITE:
			desc += " -> item[%d]" % target_item_index
	
	return desc

# 获取配置字典（用于序列化）
func get_config_dict() -> Dictionary:
	return {
		"override_mode": OverrideMode.keys()[override_mode],
		"target_item_index": target_item_index,
		"target_data_index": target_data_index,
		"property_overrides": property_overrides,
		"enabled": enabled
	}

# 从配置字典加载
func load_from_dict(config_dict: Dictionary) -> bool:
	if not config_dict:
		return false
	
	if config_dict.has("override_mode"):
		var mode_name = config_dict["override_mode"]
		for i in range(OverrideMode.values().size()):
			if OverrideMode.keys()[i] == mode_name:
				override_mode = OverrideMode.values()[i]
				break
	
	if config_dict.has("target_item_index"):
		target_item_index = config_dict["target_item_index"]
	if config_dict.has("target_data_index"):
		target_data_index = config_dict["target_data_index"]
	if config_dict.has("property_overrides"):
		property_overrides = config_dict["property_overrides"]
	if config_dict.has("enabled"):
		enabled = config_dict["enabled"]
	
	return true

# 获取是否激活
func is_enabled() -> bool:
	return enabled

# 获取覆盖模式
func get_override_mode() -> OverrideMode:
	return override_mode

# 获取目标项索引
func get_target_item_index() -> int:
	return target_item_index

# 获取目标数据索引
func get_target_data_index() -> int:
	return target_data_index

# 获取新数据
func get_new_data() -> Resource:
	return new_data

# 获取属性覆盖
func get_property_overrides() -> Dictionary:
	return property_overrides

# 获取新组合项
func get_new_composite_item() -> Resource:
	return new_composite_item