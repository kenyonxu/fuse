# condition_registry.gd
class_name ConditionRegistry extends RefCounted

## Condition 注册器
##
## 提供便捷的 Condition 注册方法，内部调用 ComponentRegistry
##
## 使用示例：
## ```gdscript
## ConditionRegistry.register_condition(MyConditionScript)
## var all_conditions = ConditionRegistry.get_all_conditions()
## var my_condition = ConditionRegistry.get_condition_by_name("MyCondition")
## ```

# ============================================================
# 注册方法
# ============================================================

## 注册 Condition
##
## 参数：
## - condition_class: Condition 类（GDScript）
##
## 返回：
## - bool - 是否注册成功
##
## 使用示例：
## ```gdscript
## ConditionRegistry.register_condition(MyConditionScript)
## ```
static func register_condition(condition_class: GDScript) -> bool:
	return ComponentRegistry.register(
		ComponentRegistry.ComponentType.CONDITION,
		condition_class,
		"_get_condition_metadata"
	)

# ============================================================
# 查询方法
# ============================================================

## 获取所有 Condition
##
## 返回：
## - Array[Dictionary] - Condition 信息数组
static func get_all_conditions() -> Array[Dictionary]:
	return ComponentRegistry.get_all(ComponentRegistry.ComponentType.CONDITION)

## 根据名称获取 Condition
##
## 参数：
## - name: Condition 名称/标识符
##
## 返回：
## - Dictionary - Condition 信息字典，未找到返回空字典
static func get_condition_by_name(name: String) -> Dictionary:
	return ComponentRegistry.get_by_name(ComponentRegistry.ComponentType.CONDITION, name)

## 获取 Condition 数量
##
## 返回：
## - int - Condition 数量
static func get_condition_count() -> int:
	return ComponentRegistry.get_count(ComponentRegistry.ComponentType.CONDITION)

# ============================================================
# 搜索方法
# ============================================================

## 搜索 Condition
##
## 参数：
## - query: 搜索关键词
## - search_by: 搜索字段（可选，默认搜索所有）
##   可选值："name", "category", "keywords" 或空字符串（搜索所有）
##
## 返回：
## - Array[Dictionary] - 匹配的 Condition 信息数组
##
## 使用示例：
## ```gdscript
## # 搜索所有字段
## var results = ConditionRegistry.search_conditions("health")
##
## # 只搜索名称
## var results = ConditionRegistry.search_conditions("health", "name")
##
## # 只搜索分类
## var results = ConditionRegistry.search_conditions("health", "category")
## ```
static func search_conditions(query: String, search_by: String = "") -> Array[Dictionary]:
	return ComponentRegistry.search(ComponentRegistry.ComponentType.CONDITION, query, search_by)

# ============================================================
# 清理方法
# ============================================================

## 清空所有 Condition（用于插件卸载时）
static func clear_all_conditions():
	ComponentRegistry.clear_all(ComponentRegistry.ComponentType.CONDITION)
