@tool
class_name MusicPriorityConfig
extends Resource

## 音乐优先级配置资源
##
## 定义可自定义的优先级列表
## 运行时按照这个列表进行优先级堆栈管理

# =============================================================================
# 优先级定义
# =============================================================================

var _is_reassigning: bool = false  ## 防止递归调用

## 优先级列表（按数值升序排列）
@export var priorities: Array[MusicPriorityEntry] = []:
	set(value):
		priorities = value
		if Engine.is_editor_hint() and not _is_reassigning:
			# 在编辑器中调整数组顺序后，自动重新分配优先级数值
			_reassign_priorities_from_order()

# =============================================================================
# 预设配置
# =============================================================================

## 创建默认配置
static func create_default() -> MusicPriorityConfig:
	var config = MusicPriorityConfig.new()
	config.priorities = [
		MusicPriorityEntry.new(&"global", 0, "全局/默认音乐（菜单、标题）"),
		MusicPriorityEntry.new(&"exploring", 1, "探索音乐"),
		MusicPriorityEntry.new(&"combat", 2, "战斗音乐"),
		MusicPriorityEntry.new(&"boss", 3, "Boss战音乐"),
		MusicPriorityEntry.new(&"event", 4, "特殊事件/临时音乐")
	]
	return config

## 创建分层配置（用于复杂游戏）
static func create_layered() -> MusicPriorityConfig:
	var config = MusicPriorityConfig.new()
	config.priorities = [
		MusicPriorityEntry.new(&"ambient", 0, "环境音（最低优先级）"),
		MusicPriorityEntry.new(&"exploration", 10, "基础探索"),
		MusicPriorityEntry.new(&"secondary", 20, "次要音乐层"),
		MusicPriorityEntry.new(&"primary", 30, "主要音乐"),
		MusicPriorityEntry.new(&"focus", 40, "焦点事件"),
		MusicPriorityEntry.new(&"critical", 50, "关键事件（最高优先级）")
	]
	return config

# =============================================================================
# 公共 API
# =============================================================================

## 获取指定名称的优先级数值
func get_priority_value(name: StringName) -> int:
	"""
	获取指定名称的优先级数值

	@param name: 优先级名称
	@return: 优先级数值，如果未找到返回 -1
	"""
	for entry in priorities:
		if entry.name == name:
			return entry.value
	return -1

## 检查是否包含指定优先级名称
func has_priority(name: StringName) -> bool:
	"""检查是否包含指定优先级名称"""
	return get_priority_value(name) >= 0

## 获取所有优先级名称
func get_priority_names() -> Array[StringName]:
	"""获取所有优先级名称"""
	var names: Array[StringName] = []
	for entry in priorities:
		names.append(entry.name)
	return names

## 添加优先级
func add_priority(name: StringName, value: int, description: String = "") -> void:
	"""
	添加一个新的优先级

	@param name: 优先级名称
	@param value: 优先级数值（现在会被自动重新分配）
	@param description: 描述
	"""
	# 移除已存在的同名优先级
	remove_priority(name)

	var entry = MusicPriorityEntry.new(name, value, description)
	priorities.append(entry)

	# 根据数组顺序重新分配所有优先级数值
	_reassign_priorities_from_order()

## 移除优先级
func remove_priority(name: StringName) -> void:
	"""
	移除指定的优先级

	@param name: 要移除的优先级名称
	"""
	for i in range(priorities.size() - 1, -1, -1):
		if priorities[i].name == name:
			priorities.remove_at(i)
			emit_changed()
			return

## 更新优先级数值
func update_priority_value(name: StringName, new_value: int) -> bool:
	"""
	更新指定优先级的数值（通过移动数组位置）

	@param name: 优先级名称
	@param new_value: 新的优先级数值（会移动到数组的该位置）
	@return: 是否成功更新

	注意：此方法现在通过调整数组顺序来改变优先级数值
	移动后，所有优先级的数值会自动重新分配
	"""
	# 找到要移动的条目
	var target_index = -1
	for i in range(priorities.size()):
		if priorities[i].name == name:
			target_index = i
			break

	if target_index == -1:
		return false

	# 如果已经在正确位置，无需移动
	if target_index == new_value:
		return true

	# 保存条目
	var entry = priorities[target_index]

	# 从原位置移除
	priorities.remove_at(target_index)

	# 插入到新位置（处理索引越界）
	var insert_index = clamp(new_value, 0, priorities.size())
	priorities.insert(insert_index, entry)

	# 根据数组顺序重新分配所有数值
	_reassign_priorities_from_order()

	return true

## 清空所有优先级
func clear() -> void:
	"""清空所有优先级"""
	priorities.clear()
	emit_changed()

## 获取优先级数量
func get_priority_count() -> int:
	"""获取优先级列表中的优先级数量"""
	return priorities.size()

# =============================================================================
# 查询 API
# =============================================================================

## 获取最低优先级
func get_lowest_priority() -> int:
	"""获取最低优先级数值"""
	if priorities.is_empty():
		return 0
	var lowest = priorities[0].value
	for entry in priorities:
		if entry.value < lowest:
			lowest = entry.value
	return lowest

## 获取最高优先级
func get_highest_priority() -> int:
	"""获取最高优先级数值"""
	if priorities.is_empty():
		return 0
	var highest = priorities[0].value
	for entry in priorities:
		if entry.value > highest:
			highest = entry.value
	return highest

## 比较两个优先级
func compare(a: StringName, b: StringName) -> int:
	"""
	比较两个优先级的数值

	@param a: 优先级名称 A
	@param b: 优先级名称 B
	@return: -1 如果 A < B, 0 如果 A == B, 1 如果 A > B
	"""
	var val_a = get_priority_value(a)
	var val_b = get_priority_value(b)

	if val_a < val_b:
		return -1
	elif val_a > val_b:
		return 1
	else:
		return 0

## 获取优先级信息（调试用）
func get_priority_info() -> String:
	"""获取所有优先级的详细信息（调试用）"""
	if priorities.is_empty():
		return "优先级列表为空"

	var info: String = ""
	info += "优先级配置 (%d 个优先级):\n" % priorities.size()

	for entry in priorities:
		info += "  [%d] %s - %s\n" % [entry.value, entry.name, entry.description]

	return info

# =============================================================================
# 内部方法
# =============================================================================

## 根据数组顺序重新分配优先级数值
func _reassign_priorities_from_order() -> void:
	"""
	根据当前数组顺序重新分配优先级数值

	这样用户可以通过在 Inspector 中拖动调整数组顺序来改变优先级
	数组第 0 项的 value = 0，第 1 项的 value = 1，以此类推
	"""
	# 防止递归调用
	if _is_reassigning:
		return
	_is_reassigning = true

	# 分配所有数值
	for i in range(priorities.size()):
		priorities[i].value = i

	# 清除标志并发出变更信号
	_is_reassigning = false
	emit_changed()

## 排序优先级列表（按数值升序）- 已弃用
##
## 现在用户通过调整数组顺序来控制优先级，不需要自动排序
func _sort_priorities() -> void:
	"""此方法已弃用，保留以避免破坏现有代码"""
	pass

# =============================================================================
# 验证
# =============================================================================

## 验证配置
func validate() -> Dictionary:
	"""
	验证优先级配置的有效性

	@return: 包含 valid, issues, warnings 的字典
	"""
	var issues: Array[String] = []
	var warnings: Array[String] = []

	if priorities.is_empty():
		warnings.append("优先级列表为空")

	# 检查重复的优先级数值
	var values: Array[int] = []
	for entry in priorities:
		if entry.value in values:
			issues.append("重复的优先级数值: %d (用于 %s)" % [entry.value, entry.name])
		values.append(entry.value)

	# 检查重复的优先级名称
	var names: Array[StringName] = []
	for entry in priorities:
		if entry.name in names:
			issues.append("重复的优先级名称: %s" % entry.name)
		names.append(entry.name)

	return {
		"valid": issues.is_empty(),
		"issues": issues,
		"warnings": warnings
	}

# =============================================================================
# 序列化
# =============================================================================

## 导出为字典
func to_dict() -> Dictionary:
	"""
	导出优先级配置为字典

	@return: 字典格式的优先级配置
	"""
	var dict = {}
	for entry in priorities:
		var entry_dict = {
			"value": entry.value,
			"description": entry.description
		}
		dict[entry.name] = entry_dict
	return dict

## 从字典加载
func load_from_dict(dict: Dictionary) -> void:
	"""
	从字典加载优先级配置

	@param dict: 字典格式的优先级配置

	注意：加载后会根据数组顺序重新分配优先级数值
	"""
	priorities.clear()

	# 先收集所有条目
	var entries: Array[Dictionary] = []
	for name in dict:
		var entry_dict = dict[name]
		entries.append({
			"name": StringName(name),
			"value": entry_dict.get("value", 0),
			"description": entry_dict.get("description", "")
		})

	# 按 value 排序，然后添加到数组
	entries.sort_custom(func(a, b): return a.value < b.value)

	for entry_data in entries:
		var entry = MusicPriorityEntry.new(
			entry_data.name,
			entry_data.value,
			entry_data.description
		)
		priorities.append(entry)

	# 根据数组顺序重新分配数值（确保连续）
	_reassign_priorities_from_order()

# =============================================================================
# 字符串表示
# =============================================================================

func _to_string() -> String:
	return "MusicPriorityConfig (%d priorities)" % priorities.size()
