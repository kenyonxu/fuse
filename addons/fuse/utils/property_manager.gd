@tool
class_name PropertyManager
extends RefCounted

## 属性管理器类
## 提供节点属性的发现、过滤、验证和操作功能

## 获取缓存实例（使用全局单例）
static func _get_cache() -> ReflectionCache:
	return ReflectionCache.get_instance()

## 属性过滤器
enum PropertyFilter {
	ALL,				## 所有属性
	WRITABLE_ONLY,	  ## 仅可写属性
	EXPORTED_ONLY,	   ## 仅导出属性
	NUMERIC_ONLY,		## 仅数值属性
	CONTAINER_ONLY,	   ## 仅容器属性
	CUSTOM_PROPERTIES	## 自定义属性过滤器
}

## 获取节点的所有属性信息
static func get_all_properties(node: Node) -> Array[PropertyInfo]:
	if node == null:
		return []

	# 使用统一缓存
	var cached = _get_cache().fetch(ReflectionCache.CacheType.PROPERTY, node)
	if cached != null:
		return (cached as Array[PropertyInfo]).duplicate()  # 返回副本，防止外部修改影响缓存

	var properties: Array[PropertyInfo] = []
	var property_list = node.get_property_list()

	for prop_dict in property_list:
		var property_info = PropertyInfo.create(prop_dict)
		properties.append(property_info)

	# 缓存结果
	_get_cache().set_node_cache(ReflectionCache.CacheType.PROPERTY, node, properties)

	return properties

## 获取节点的可写属性
static func get_writable_properties(node: Node) -> Array[PropertyInfo]:
	return get_filtered_properties(node, PropertyFilter.WRITABLE_ONLY)

## 获取节点的导出属性
static func get_exported_properties(node: Node) -> Array[PropertyInfo]:
	return get_filtered_properties(node, PropertyFilter.EXPORTED_ONLY)

## 获取节点的数值属性
static func get_numeric_properties(node: Node) -> Array[PropertyInfo]:
	return get_filtered_properties(node, PropertyFilter.NUMERIC_ONLY)

## 获取节点的容器属性
static func get_container_properties(node: Node) -> Array[PropertyInfo]:
	return get_filtered_properties(node, PropertyFilter.CONTAINER_ONLY)

## 根据过滤器获取属性
static func get_filtered_properties(node: Node, filter: PropertyFilter) -> Array[PropertyInfo]:
	var all_properties = get_all_properties(node)
	var filtered_properties: Array[PropertyInfo] = []
	
	for property_info in all_properties:
		if _passes_filter(property_info, filter):
			filtered_properties.append(property_info)
	
	return filtered_properties

## 检查属性是否通过过滤器
static func _passes_filter(property_info: PropertyInfo, filter: PropertyFilter) -> bool:
	match filter:
		PropertyFilter.ALL:
			return true
		PropertyFilter.WRITABLE_ONLY:
			return property_info.is_writable() and _is_valid_settable_property(property_info)
		PropertyFilter.EXPORTED_ONLY:
			return property_info.is_exported and _is_valid_settable_property(property_info)
		PropertyFilter.NUMERIC_ONLY:
			return property_info.is_numeric() and _is_valid_settable_property(property_info)
		PropertyFilter.CONTAINER_ONLY:
			return property_info.is_container() and _is_valid_settable_property(property_info)
		PropertyFilter.CUSTOM_PROPERTIES:
			return _custom_filter_check(property_info) and _is_valid_settable_property(property_info)
		_:
			return _is_valid_settable_property(property_info)

## 自定义过滤器检查（可扩展）
static func _custom_filter_check(property_info: PropertyInfo) -> bool:
	# 默认实现：排除内部属性和脚本变量
	return not property_info.is_internal and not property_info.is_script_variable

## 检查属性是否是有效的可设置属性
static func _is_valid_settable_property(property_info: PropertyInfo) -> bool:
	"""
	过滤掉那些无法设置参数的属性，比如类型名、常量等
	"""
	# 排除空属性名
	if property_info.name.is_empty():
		return false
	
	# 排除内部属性（以下划线开头）
	if property_info.name.begins_with("_"):
		return false
	
	# 排除看起来像是类型名的属性（全大写或首字母大写且没有小写）
	if _looks_like_type_name(property_info.name):
		return false
	
	# 排除常见的非设置table属性
	var non_settable_names = [
		"Transform", "Rect2", "Vector2", "Vector3", "Color", "String", "int", "float", "bool",
		"Array", "Dictionary", "Object", "Node", "Node2D", "Node3D", "Control", "Sprite2D"
	]
	
	if property_info.name in non_settable_names:
		return false
	
	# 检查属性名是否看起来像是常量（全大写）
	if property_info.name == property_info.name.to_upper():
		return false
	
	# 检查属性是否有有效的类型（不是NIL）
	if property_info.type == TYPE_NIL:
		return false
	
	return true

## 检查属性名是否看起来像是类型名
static func _looks_like_type_name(name: String) -> bool:
	"""
	判断属性名是否看起来像是类型名而不是实际的属性
	"""
	# 如果全是小写，可能是实际属性
	if name == name.to_lower():
		return false
	
	# 如果包含下划线，可能是实际属性
	if name.contains("_"):
		return false
	
	# 如果首字母大写且后面没有小写字母，可能是类型名
	if name.length() > 0 and _is_upper_case_char(name[0]) and name.substr(1).to_upper() == name.substr(1):
		return true
	
	# 常见的Godot类型名模式
	var type_patterns = ["2D", "3D", "Rect", "Vector", "Transform", "Color", "Node"]
	for pattern in type_patterns:
		if name.contains(pattern):
			# 检查是否完全是类型名
			if name in ["Transform2D", "Transform3D", "Rect2", "Rect2i", "Vector2", "Vector2i", "Vector3", "Vector3i"]:
				return true
	
	return false

## 检查字符是否为大写字母
static func _is_upper_case_char(char: String) -> bool:
	return char >= "A" and char <= "Z"

## 查找指定属性
static func find_property(node: Node, property_name: String) -> PropertyInfo:
	var properties = get_all_properties(node)
	
	for property_info in properties:
		if property_info.name == property_name:
			return property_info
	
	return null

## 检查属性是否存在
static func has_property(node: Node, property_name: String) -> bool:
	return find_property(node, property_name) != null

## 检查属性是否可写
static func is_property_writable(node: Node, property_name: String) -> bool:
	var property_info = find_property(node, property_name)
	return property_info != null and property_info.is_writable()

## 验证属性值
static func validate_property_value(node: Node, property_name: String, value: Variant) -> Dictionary:
	var property_info = find_property(node, property_name)
	if property_info == null:
		return {"valid": false, "error": "属性不存在: " + property_name}
	
	if not property_info.is_writable():
		return {"valid": false, "error": "属性不可写: " + property_name}
	
	return property_info.validate_value(value)

## 安全设置属性值
static func set_property_safe(node: Node, property_name: String, value: Variant) -> Dictionary:
	# 调试信息（已关闭：每帧 trigger 调用会刷屏；需要排查时取消注释）
	# print("[PropertyManager] 尝试设置属性: 节点=%s, 属性名='%s', 值=%s" % [node.name, property_name, str(value)])
	
	# 检查属性名是否为空
	if property_name.is_empty():
		print("[PropertyManager] 错误: 属性名为空")
		return {"success": false, "error": "属性名不能为空"}
	
	# 特殊处理：如果属性名是 "name" 且值为空字符串，跳过设置
	if property_name == "name" and value == "":
		print("[PropertyManager] 警告: 跳过设置空名称")
		return {"success": true, "value": value, "warning": "跳过设置空名称"}
	
	var validation = validate_property_value(node, property_name, value)
	if not validation.valid:
		print("[PropertyManager] 验证失败: %s" % validation.error)
		return {"success": false, "error": validation.error}
	
	var converted_value = validation.converted_value
	
	# node.set() 不返回布尔值，直接调用并假设成功
	node.set(property_name, converted_value)
	# print("[PropertyManager] 属性设置成功: %s = %s" % [property_name, str(converted_value)])
	return {"success": true, "value": converted_value}

## 批量设置属性
static func set_properties_batch(node: Node, property_values: Dictionary) -> Dictionary:
	var results = {"success_count": 0, "failed_count": 0, "errors": []}
	
	for property_name in property_values:
		var value = property_values[property_name]
		var result = set_property_safe(node, property_name, value)
		
		if result.success:
			results.success_count += 1
		else:
			results.failed_count += 1
			results.errors.append({
				"property": property_name,
				"error": result.error
			})
	
	return results

## 复制属性到另一个节点
static func copy_properties(source: Node, target: Node, property_names: Array[String] = []) -> Dictionary:
	var results = {"copied_count": 0, "failed_count": 0, "errors": []}
	
	var source_properties = get_all_properties(source)
	var properties_to_copy = property_names
	
	# 如果没有指定属性名，则复制所有可写属性
	if properties_to_copy.is_empty():
		print("[PropertyManager] 未指定属性，收集所有可写属性")
		for prop_info in source_properties:
			print("[PropertyManager] 检查属性: '%s', 可写: %s, 空名: %s" % [prop_info.name, prop_info.is_writable(), prop_info.name.is_empty()])
			if prop_info.is_writable() and not prop_info.name.is_empty():
				properties_to_copy.append(prop_info.name)
				print("[PropertyManager] 添加属性: '%s'" % prop_info.name)
			else:
				print("[PropertyManager] 跳过属性: '%s' (原因: 不可写或空名)" % prop_info.name)
	
	# 执行复制
	print("[PropertyManager] 开始批量复制，属性数量: %d" % properties_to_copy.size())
	for property_name in properties_to_copy:
		print("[PropertyManager] 处理属性: '%s'" % property_name)
		
		# 再次检查属性名是否为空（防御性编程）
		if property_name.is_empty():
			print("[PropertyManager] 警告: 发现空属性名，跳过")
			results.failed_count += 1
			results.errors.append({
				"property": "[空属性名]",
				"error": "跳过空属性名"
			})
			continue
			
		var source_value = source.get(property_name)
		var result = set_property_safe(target, property_name, source_value)
		
		if result.success:
			results.copied_count += 1
		else:
			results.failed_count += 1
			results.errors.append({
				"property": property_name,
				"error": result.error
			})
	
	return results

## 获取属性值（带类型转换）
static func get_property_value(node: Node, property_name: String, target_type: int = TYPE_NIL) -> Dictionary:
	var property_info = find_property(node, property_name)
	if property_info == null:
		return {"success": false, "error": "属性不存在: " + property_name}
	
	var value = node.get(property_name)
	
	# 如果需要类型转换
	if target_type != TYPE_NIL and typeof(value) != target_type:
		value = TypeConverter.safe_convert(value, target_type)
	
	return {"success": true, "value": value}

## 获取属性类型
static func get_property_type(node: Node, property_name: String) -> int:
	var property_info = find_property(node, property_name)
	return property_info.type if property_info != null else TYPE_NIL

## 获取属性默认值
static func get_property_default(node: Node, property_name: String) -> Variant:
	var property_info = find_property(node, property_name)
	return property_info.default_value if property_info != null else null

## 重置属性为默认值
static func reset_property_to_default(node: Node, property_name: String) -> Dictionary:
	var default_value = get_property_default(node, property_name)
	if default_value == null:
		return {"success": false, "error": "无法获取属性默认值: " + property_name}
	
	return set_property_safe(node, property_name, default_value)

## 清除指定节点的缓存
static func clear_cache(node: Node):
	if node == null:
		return
	_get_cache().clear_node(node)

## 清除所有缓存
static func clear_all_cache():
	_get_cache().clear_all()

## 获取缓存统计信息
static func get_cache_stats() -> Dictionary:
	var stats = _get_cache().get_stats()
	return {
		"cached_nodes": stats.property_entries,
		"cached_properties": 0,
		"memory_usage": _estimate_memory_usage()
	}

## 估算内存使用量
static func _estimate_memory_usage() -> int:
	var stats = _get_cache().get_stats()
	# 估算每个 PropertyInfo 约 100 字节，每节点平均 20 个属性
	return stats.property_entries * 20 * 100

## 监听节点变化（用于自动更新缓存）
static func monitor_node_changes(node: Node):
	if node == null:
		return
	
	# 监听节点的属性变化
	node.property_list_changed.connect(_on_node_property_list_changed.bind(node))
	
	# 监听节点的删除事件
	node.tree_exiting.connect(_on_node_tree_exiting.bind(node))

## 节点属性列表变化处理
static func _on_node_property_list_changed(node: Node):
	clear_cache(node)

## 节点退出树处理
static func _on_node_tree_exiting(node: Node):
	clear_cache(node)

## 获取调试信息
static func get_debug_info() -> String:
	var stats = get_cache_stats()
	return "PropertyManager - 缓存节点: %d, 估算内存: %d 字节" % [stats.cached_nodes, stats.memory_usage]

## 批量验证属性值
static func validate_properties_batch(node: Node, property_values: Dictionary) -> Dictionary:
	var results = {"valid_count": 0, "invalid_count": 0, "validation_results": {}}
	
	for property_name in property_values:
		var value = property_values[property_name]
		var validation = validate_property_value(node, property_name, value)
		
		results.validation_results[property_name] = validation
		
		if validation.valid:
			results.valid_count += 1
		else:
			results.invalid_count += 1
	
	return results

## 获取属性分类
static func get_property_categories(node: Node) -> Array[String]:
	var properties = get_all_properties(node)
	var categories: Array[String] = []
	
	for property_info in properties:
		if property_info.category != "" and not categories.has(property_info.category):
			categories.append(property_info.category)
	
	categories.sort()
	return categories

## 按分类获取属性
static func get_properties_by_category(node: Node, category: String) -> Array[PropertyInfo]:
	var properties = get_all_properties(node)
	var categorized_properties: Array[PropertyInfo] = []
	
	for property_info in properties:
		if property_info.category == category:
			categorized_properties.append(property_info)
	
	return categorized_properties

## 搜索属性
static func search_properties(node: Node, search_term: String, filter: PropertyFilter = PropertyFilter.ALL) -> Array[PropertyInfo]:
	var properties = get_filtered_properties(node, filter)
	var search_results: Array[PropertyInfo] = []
	
	var lower_search = search_term.to_lower()
	
	for property_info in properties:
		# 搜索属性名
		if property_info.name.to_lower().contains(lower_search):
			search_results.append(property_info)
			continue
		
		# 搜索显示名称
		if property_info.get_display_name().to_lower().contains(lower_search):
			search_results.append(property_info)
			continue
		
		# 搜索描述
		if property_info.description.to_lower().contains(lower_search):
			search_results.append(property_info)
			continue
		
		# 搜索类型名称
		if property_info.get_type_name().to_lower().contains(lower_search):
			search_results.append(property_info)
			continue
	
	return search_results