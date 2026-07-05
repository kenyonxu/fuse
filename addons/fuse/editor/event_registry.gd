# event_registry.gd
class_name EventRegistry extends RefCounted

## Event 注册器
##
## 提供便捷的 Event 注册方法，内部调用 ComponentRegistry
##
## 使用示例：
## ```gdscript
## EventRegistry.register_event(MyEventScript)
## var all_events = EventRegistry.get_all_events()
## var my_event = EventRegistry.get_event_by_name("MyEvent")
## ```

# ============================================================
# 注册方法
# ============================================================

## 注册 Event
##
## 参数：
## - event_class: Event 类（GDScript）
##
## 返回：
## - bool - 是否注册成功
##
## 使用示例：
## ```gdscript
## EventRegistry.register_event(MyEventScript)
## ```
static func register_event(event_class: GDScript) -> bool:
	return ComponentRegistry.register(
		ComponentRegistry.ComponentType.EVENT,
		event_class,
		"_get_event_metadata"
	)

# ============================================================
# 查询方法
# ============================================================

## 获取所有 Event
##
## 返回：
## - Array[Dictionary] - Event 信息数组
static func get_all_events() -> Array[Dictionary]:
	return ComponentRegistry.get_all(ComponentRegistry.ComponentType.EVENT)

## 根据名称获取 Event
##
## 参数：
## - name: Event 名称/标识符
##
## 返回：
## - Dictionary - Event 信息字典，未找到返回空字典
static func get_event_by_name(name: String) -> Dictionary:
	return ComponentRegistry.get_by_name(ComponentRegistry.ComponentType.EVENT, name)

## 获取 Event 数量
##
## 返回：
## - int - Event 数量
static func get_event_count() -> int:
	return ComponentRegistry.get_count(ComponentRegistry.ComponentType.EVENT)

# ============================================================
# 搜索方法
# ============================================================

## 搜索 Event
##
## 参数：
## - query: 搜索关键词
## - search_by: 搜索字段（可选，默认搜索所有）
##   可选值："name", "category", "keywords" 或空字符串（搜索所有）
##
## 返回：
## - Array[Dictionary] - 匹配的 Event 信息数组
##
## 使用示例：
## ```gdscript
## # 搜索所有字段
## var results = EventRegistry.search_events("input")
##
## # 只搜索名称
## var results = EventRegistry.search_events("input", "name")
##
## # 只搜索分类
## var results = EventRegistry.search_events("input", "category")
## ```
static func search_events(query: String, search_by: String = "") -> Array[Dictionary]:
	return ComponentRegistry.search(ComponentRegistry.ComponentType.EVENT, query, search_by)

# ============================================================
# 清理方法
# ============================================================

## 清空所有 Event（用于插件卸载时）
static func clear_all_events():
	ComponentRegistry.clear_all(ComponentRegistry.ComponentType.EVENT)
