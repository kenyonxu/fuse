@tool
class_name ReflectionCache
extends RefCounted

## 统一反射缓存管理器
## 集中管理方法、属性、信号的缓存，提供自动清理和 LRU 淘汰
## 替代 PropertyManager/SignalManager 中各自独立的缓存实现
##
## 使用单例模式确保全局共享唯一实例：
##   ReflectionCache.get_instance()

## 全局单例实例
static var _instance: ReflectionCache = null

## 获取全局单例实例
static func get_instance() -> ReflectionCache:
	if _instance == null:
		_instance = ReflectionCache.new()
	return _instance

## 缓存类型枚举
enum CacheType {
	METHOD,		## 方法列表和 Callable
	PROPERTY,	## 属性列表
	SIGNAL,		## 信号列表
	SIGNATURE	## 方法签名
}

## 缓存存储
var _caches: Dictionary = {
	CacheType.METHOD: {},		## {instance_id: {method_name: info}}
	CacheType.PROPERTY: {},	## {instance_id: [PropertyInfo]}
	CacheType.SIGNAL: {},		## {instance_id: [SignalInfo]}
	CacheType.SIGNATURE: {},	## {instance_id:method_name: signature}
}

## LRU 配置
var _max_entries: int = 200
var _access_order: Dictionary = {
	CacheType.METHOD: [],
	CacheType.PROPERTY: [],
	CacheType.SIGNAL: [],
	CacheType.SIGNATURE: [],
}

## 获取缓存
## @param cache_type: 缓存类型
## @param node: 目标节点
## @param key: 子键（方法名等），为空时返回整个节点的缓存
## @return: 缓存值，未命中返回 null
func fetch(cache_type: CacheType, node: Node, key: String = "") -> Variant:
	if not node:
		return null

	# 防止 instance_id 回收后返回过期缓存
	if not is_instance_valid(node):
		clear_node(node)
		return null

	var instance_key = str(node.get_instance_id())
	var cache = _caches[cache_type]

	if not cache.has(instance_key):
		return null

	# 更新 LRU 访问顺序
	_update_access_order(cache_type, instance_key)

	if key.is_empty():
		return cache[instance_key]

	var node_cache = cache[instance_key]
	if node_cache is Dictionary:
		return node_cache.get(key, null)
	return null

## 设置缓存（以节点为粒度的整体缓存，如属性列表、信号列表）
## @param cache_type: 缓存类型
## @param node: 目标节点
## @param value: 缓存值
func set_node_cache(cache_type: CacheType, node: Node, value: Variant):
	if not node:
		return

	var instance_key = str(node.get_instance_id())

	if not _caches[cache_type].has(instance_key):
		_evict_if_needed(cache_type)

	_caches[cache_type][instance_key] = value
	_update_access_order(cache_type, instance_key)

## 设置缓存（以节点+键为粒度的细粒度缓存，如单个方法信息）
## @param cache_type: 缓存类型
## @param node: 目标节点
## @param key: 子键
## @param value: 缓存值
func set_keyed_cache(cache_type: CacheType, node: Node, key: String, value: Variant):
	if not node or key.is_empty():
		return

	var instance_key = str(node.get_instance_id())

	if not _caches[cache_type].has(instance_key):
		_evict_if_needed(cache_type)
		_caches[cache_type][instance_key] = {}

	_caches[cache_type][instance_key][key] = value
	_update_access_order(cache_type, instance_key)

## 检查缓存是否存在
func has(cache_type: CacheType, node: Node, key: String = "") -> bool:
	if not node:
		return false

	var instance_key = str(node.get_instance_id())
	var cache = _caches[cache_type]

	if not cache.has(instance_key):
		return false

	if key.is_empty():
		return true

	var node_cache = cache[instance_key]
	if node_cache is Dictionary:
		return node_cache.has(key)

	return false

## 清理指定节点的所有缓存
func clear_node(node: Node):
	if not node:
		return

	var instance_key = str(node.get_instance_id())

	for cache_type in _caches:
		_caches[cache_type].erase(instance_key)
		# 从 LRU 访问顺序中移除
		var order = _access_order.get(cache_type, []) as Array
		var idx = order.find(instance_key)
		if idx >= 0:
			order.remove_at(idx)

## 清理所有缓存
func clear_all():
	for cache_type in _caches:
		_caches[cache_type].clear()
	for cache_type in _access_order:
		_access_order[cache_type].clear()

## 获取缓存统计
func get_stats() -> Dictionary:
	var total = 0
	for cache_type in _caches:
		total += _caches[cache_type].size()

	return {
		"method_entries": _caches[CacheType.METHOD].size(),
		"property_entries": _caches[CacheType.PROPERTY].size(),
		"signal_entries": _caches[CacheType.SIGNAL].size(),
		"signature_entries": _caches[CacheType.SIGNATURE].size(),
		"total_entries": total,
		"max_entries_per_type": _max_entries
	}

## 更新 LRU 访问顺序
func _update_access_order(cache_type: CacheType, instance_key: String):
	var order = _access_order.get(cache_type, []) as Array
	var idx = order.find(instance_key)
	if idx >= 0:
		order.remove_at(idx)
	order.append(instance_key)
	_access_order[cache_type] = order

## LRU 淘汰
func _evict_if_needed(cache_type: CacheType):
	var order = _access_order.get(cache_type, []) as Array
	while order.size() >= _max_entries and order.size() > 0:
		var oldest = order[0] as String
		order.pop_front()
		_caches[cache_type].erase(oldest)
	_access_order[cache_type] = order
