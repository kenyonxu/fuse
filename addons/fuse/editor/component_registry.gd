# component_registry.gd
class_name ComponentRegistry extends RefCounted

## Fuse 组件通用注册器
##
## 统一管理 Instruction、Event、Condition 三种组件的注册
## 提供通用的注册、查询、搜索功能

## 组件类型枚举
enum ComponentType {
	INSTRUCTION,
	EVENT,
	CONDITION
}

# 分别存储三种组件的数据
static var _instructions: Array[Dictionary] = []
static var _events: Array[Dictionary] = []
static var _conditions: Array[Dictionary] = []

# 用于快速查找的映射表（name/identifier -> component_info）
static var _instruction_map: Dictionary = {}
static var _event_map: Dictionary = {}
static var _condition_map: Dictionary = {}

# 重复注册计数（扫描可观测性，Task 1.4 使用）
static var _duplicate_counts: Dictionary = {}  # ComponentType -> int

# ============================================================
# 注册方法
# ============================================================

## 注册组件
##
## 参数：
## - component_type: 组件类型（INSTRUCTION、EVENT、CONDITION）
## - component_class: 组件类（GDScript）
## - metadata_method: 元数据方法名（如 "_get_instruction_metadata"）
##
## 返回：
## - bool - 是否注册成功
static func register(component_type: ComponentType, component_class: GDScript, metadata_method: String) -> bool:
	# 确保本地化系统已初始化
	var FuseLocalization_class = load("res://addons/fuse/localization/fuse_localization.gd")
	if FuseLocalization_class and FuseLocalization_class.has_method("init"):
		FuseLocalization_class.init()

	# 检查组件类是否有元数据方法
	if not component_class.has_method(metadata_method):
		return false

	var metadata = component_class.call(metadata_method)
	if metadata == null:
		return false

	# 获取组件的标识名称（优先使用 name_key，回退到 name）
	var identifier = ""

	# 对于新的 Resource 元数据，使用 name_key 作为标识符
	if metadata.has_method("get") and metadata.get("name_key") and not metadata.get("name_key").is_empty():
		identifier = metadata.name_key
	elif metadata.has_method("get") and metadata.get("name") and not metadata.get("name").is_empty():
		identifier = metadata.name
	else:
		# 如果是旧的 Dictionary 元数据
		if metadata.has("name_key") and metadata.name_key and not metadata.name_key.is_empty():
			identifier = metadata.name_key
		elif metadata.has("name") and metadata.name and not metadata.name.is_empty():
			identifier = metadata.name
		else:
			return false

	# 根据组件类型选择对应的存储
	var components_array: Array[Dictionary]
	var components_map: Dictionary
	var type_name: String

	match component_type:
		ComponentType.INSTRUCTION:
			components_array = _instructions
			components_map = _instruction_map
			type_name = "指令"
		ComponentType.EVENT:
			components_array = _events
			components_map = _event_map
			type_name = "事件"
		ComponentType.CONDITION:
			components_array = _conditions
			components_map = _condition_map
			type_name = "条件"
		_:
			return false

	# 检查是否已经注册
	if components_map.has(identifier):
		print("警告：%s '%s' 已经注册，将被覆盖" % [type_name, identifier])

	var component_info = {
		"identifier": identifier,
		"class": component_class,
		"metadata": metadata
	}

	if components_map.has(identifier):
		# upsert：map 更新 + array 中定位并替换对应项
		components_map[identifier] = component_info
		var updated := false
		for i in range(components_array.size()):
			if components_array[i].get("identifier", "") == identifier:
				components_array[i] = component_info
				updated = true
				break
		if not updated:
			components_array.append(component_info)
		# 累加重复计数（Task 1.4 使用）
		_increment_duplicate_count(component_type)
	else:
		components_array.append(component_info)
		components_map[identifier] = component_info

	return true


## 获取所有组件
##
## 参数：
## - component_type: 组件类型
##
## 返回：
## - Array[Dictionary] - 组件信息数组
static func get_all(component_type: ComponentType) -> Array[Dictionary]:
	match component_type:
		ComponentType.INSTRUCTION:
			return _instructions
		ComponentType.EVENT:
			return _events
		ComponentType.CONDITION:
			return _conditions
		_:
			return []

## 根据名称获取组件
##
## 参数：
## - component_type: 组件类型
## - name: 组件名称/标识符
##
## 返回：
## - Dictionary - 组件信息字典，未找到返回空字典
static func get_by_name(component_type: ComponentType, name: String) -> Dictionary:
	match component_type:
		ComponentType.INSTRUCTION:
			return _instruction_map.get(name, {})
		ComponentType.EVENT:
			return _event_map.get(name, {})
		ComponentType.CONDITION:
			return _condition_map.get(name, {})
		_:
			return {}

## 获取组件数量
##
## 参数：
## - component_type: 组件类型
##
## 返回：
## - int - 组件数量
static func get_count(component_type: ComponentType) -> int:
	match component_type:
		ComponentType.INSTRUCTION:
			return _instructions.size()
		ComponentType.EVENT:
			return _events.size()
		ComponentType.CONDITION:
			return _conditions.size()
		_:
			return 0

## 清空所有组件
##
## 参数：
## - component_type: 组件类型（可选，不提供则清空所有）
static func clear_all(component_type: ComponentType = -1):
	if component_type == -1:
		# 清空所有
		_instructions.clear()
		_events.clear()
		_conditions.clear()
		_instruction_map.clear()
		_event_map.clear()
		_condition_map.clear()
		_duplicate_counts.clear()
	else:
		# 清空指定类型
		match component_type:
			ComponentType.INSTRUCTION:
				_instructions.clear()
				_instruction_map.clear()
			ComponentType.EVENT:
				_events.clear()
				_event_map.clear()
			ComponentType.CONDITION:
				_conditions.clear()
				_condition_map.clear()
		_duplicate_counts.erase(component_type)

## 累加重复注册计数（内部使用）
static func _increment_duplicate_count(component_type: ComponentType) -> void:
	_duplicate_counts[component_type] = _duplicate_counts.get(component_type, 0) + 1

## 获取指定类型的重复注册次数
static func get_duplicate_count(component_type: ComponentType) -> int:
	return _duplicate_counts.get(component_type, 0)

## 重置指定类型的重复注册计数
static func reset_duplicate_count(component_type: ComponentType = -1) -> void:
	if component_type == -1:
		_duplicate_counts.clear()
	else:
		_duplicate_counts.erase(component_type)

# ============================================================
# 搜索方法
# ============================================================

## 搜索组件
##
## 参数：
## - component_type: 组件类型
## - query: 搜索关键词
## - search_by: 搜索字段（可选，默认搜索所有）
##   可选值： "name", "category", "keywords" 或 空字符串（搜索所有）
##
## 返回：
## - Array[Dictionary] - 匹配的组件信息数组
static func search(component_type: ComponentType, query: String, search_by: String = "") -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var components = get_all(component_type)

	# 如果搜索查询为空，返回所有组件
	if query.is_empty():
		return components

	var query_lower = query.to_lower()

	for component_info in components:
		var metadata = component_info.metadata
		var should_add = false

		# 如果指定了搜索字段，只搜索该字段
		if not search_by.is_empty():
			match search_by:
				"name":
					should_add = _check_name_match(metadata, query_lower)
				"category":
					should_add = _check_category_match(metadata, query_lower)
				"keywords":
					should_add = _check_keywords_match(metadata, query_lower)
		else:
			# 搜索所有字段
			should_add = _check_name_match(metadata, query_lower)
			should_add = should_add or _check_category_match(metadata, query_lower)
			should_add = should_add or _check_keywords_match(metadata, query_lower)

		if should_add:
			results.append(component_info)

	return results

# ============================================================
# 内部辅助方法
# ============================================================

## 检查名称匹配
static func _check_name_match(metadata: Variant, query_lower: String) -> bool:
	var name = ""

	# 尝试获取名称（支持新旧元数据格式）
	if metadata.has_method("get_localized_name"):
		# 新的 Resource 元数据
		name = metadata.get_localized_name()
	elif metadata.has("name_key") and metadata.name_key and not metadata.name_key.is_empty():
		# 旧的 Dictionary 元数据，优先使用 name_key
		name = metadata.name_key
	elif metadata.has("name") and metadata.name:
		# 旧的 Dictionary 元数据，使用 name
		name = metadata.name

	return not name.is_empty() and name.to_lower().contains(query_lower)

## 检查分类匹配
static func _check_category_match(metadata: Variant, query_lower: String) -> bool:
	var category = ""

	# 尝试获取分类（支持新旧元数据格式）
	if metadata.has_method("get_localized_category"):
		# 新的 Resource 元数据
		category = metadata.get_localized_category()
	elif metadata.has("category_key") and metadata.category_key and not metadata.category_key.is_empty():
		# 旧的 Dictionary 元数据，优先使用 category_key
		category = metadata.category_key
	elif metadata.has("category") and metadata.category:
		# 旧的 Dictionary 元数据，使用 category
		category = metadata.category

	return not category.is_empty() and category.to_lower().contains(query_lower)

## 检查关键词匹配
static func _check_keywords_match(metadata: Variant, query_lower: String) -> bool:
	# 检查是否有 keywords 字段/属性
	var keywords: Array = []

	# 尝试从 Resource 获取 keywords 属性
	if metadata.has_method("get"):
		# Resource 类型，直接使用 get() 方法
		var kw = metadata.get("keywords")
		keywords = kw if kw != null else []
	elif metadata.has("keywords"):
		# Dictionary 类型，使用 has() 检查
		keywords = metadata.keywords

	if keywords.is_empty():
		return false

	# 检查是否有关键词匹配
	for keyword in keywords:
		if keyword and str(keyword).to_lower().contains(query_lower):
			return true

	return false
