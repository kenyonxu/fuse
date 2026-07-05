# 文件：addons/fuse/utils/signal_manager.gd
@tool
class_name SignalManager extends RefCounted

## 获取缓存实例（使用全局单例）
static func _get_cache() -> ReflectionCache:
	return ReflectionCache.get_instance()

## 获取节点的所有信号信息
static func get_node_signals(node):
	if not node:
		return []

	# 使用统一缓存
	var cached = _get_cache().fetch(ReflectionCache.CacheType.SIGNAL, node)
	if cached != null:
		return cached.duplicate()  # 返回副本，防止外部修改影响缓存

	var signals = []
	var signal_list = node.get_signal_list()
	var node_class = node.get_class()

	for signal_dict in signal_list:
		var signal_info = SignalInfo.from_godot_signal(signal_dict, node_class)
		signals.append(signal_info)

	# 缓存结果
	_get_cache().set_node_cache(ReflectionCache.CacheType.SIGNAL, node, signals)

	return signals.duplicate()  # 返回副本，防止外部修改影响缓存

## 根据名称查找信号信息
static func find_signal_by_name(node, signal_name: String):
	var signals = get_node_signals(node)

	for signal_info in signals:
		if signal_info.name == signal_name:
			return signal_info

	return null

## 检查节点是否有指定信号
static func has_signal_named(node, signal_name: String):
	return find_signal_by_name(node, signal_name) != null

## 获取信号名称列表
static func get_signal_names(node):
	var signals = get_node_signals(node)
	var names = []

	for signal_info in signals:
		names.append(signal_info.name)

	return names

## 获取信号显示名称列表
static func get_signal_display_names(node):
	var signals = get_node_signals(node)
	var display_names = []

	for signal_info in signals:
		display_names.append(signal_info.get_display_name())

	return display_names

## 清理指定节点的缓存
static func clear_cache_for_node(node):
	if not node:
		return
	_get_cache().clear_node(node)

## 清理所有缓存
static func clear_all_cache():
	_get_cache().clear_all()

## 获取缓存统计信息
static func get_cache_stats():
	var stats = _get_cache().get_stats()
	return {
		"cached_nodes": stats.signal_entries,
		"total_signals": _get_total_signal_count(),
		"max_cache_size": stats.max_entries_per_type
	}

## 私有方法：获取总信号数量
static func _get_total_signal_count():
	# 遍历缓存中所有信号数组的元素总数
	var cache = _get_cache()._caches.get(ReflectionCache.CacheType.SIGNAL, {})
	var total = 0
	for entry in cache.values():
		if entry is Array:
			total += entry.size()
	return total
