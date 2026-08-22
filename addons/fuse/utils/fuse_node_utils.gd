## FuseNodeUtils
##
## 节点相关的工具函数集合
class_name FuseNodeUtils extends RefCounted

## 静态缓存字典
## 键格式: "root_path:relative_path:max_depth"
## 值: NodePath（缓存路径而非节点引用，避免悬空引用）
static var _node_cache: Dictionary = {}

## 缓存的最大大小（防止内存泄漏）
static var _cache_max_size: int = 1000

## 缓存命中计数（用于调试）
static var _cache_hits: int = 0
static var _cache_misses: int = 0

## 生成缓存键（内部方法）
##
## 基于根节点路径和目标路径生成唯一的缓存键
static func _generate_cache_key(root: Node, path_string: String, max_depth: int) -> String:
	if not root:
		return "null_root:%s:%d" % [path_string, max_depth]
	# root 不在场景树中时，get_path() 会报错，用 instance_id 作为回退
	if not root.is_inside_tree():
		return "detached_root:%d:%s:%d" % [root.get_instance_id(), path_string, max_depth]
	return "%s:%s:%d" % [root.get_path(), path_string, max_depth]

## 从缓存获取节点（内部方法）
##
## 尝试从缓存中获取节点路径并动态解析，避免返回已释放的节点实例
static func _get_from_cache(root: Node, path_string: String, max_depth: int) -> Node:
	var cache_key = _generate_cache_key(root, path_string, max_depth)
	if _node_cache.has(cache_key):
		var cached_path: NodePath = _node_cache[cache_key]

		# 尝试从缓存的路径获取节点
		if root and root.has_node(cached_path):
			var node = root.get_node(cached_path)
			# 验证节点是否在场景树中
			if node and node.is_inside_tree():
				_cache_hits += 1
				return node

		# 缓存失效，移除该条目
		_node_cache.erase(cache_key)

	_cache_misses += 1
	return null

## 将结果存入缓存（内部方法）
static func _store_in_cache(root: Node, path_string: String, max_depth: int, node: Node):
	var cache_key = _generate_cache_key(root, path_string, max_depth)

	# 如果缓存太大，清除最旧的条目（简单实现：清除一半）
	if _node_cache.size() >= _cache_max_size:
		_clear_half_cache()

	# 缓存节点的相对路径（从根节点到目标节点的路径）
	# 这样即使节点被重新创建，只要路径相同就能找到
	# 需要确保 root 和 node 都在场景树中，否则 get_path_to() 会报错
	if node and root and root.is_inside_tree() and node.is_inside_tree():
		var node_path = root.get_path_to(node)
		_node_cache[cache_key] = node_path
	else:
		# 缓存空路径表示未找到
		_node_cache[cache_key] = NodePath()

## 获取缓存命中率（用于调试）
static func _get_cache_hit_rate() -> float:
	var total = _cache_hits + _cache_misses
	if total == 0:
		return 0.0
	return float(_cache_hits) / float(total) * 100.0

## 清除一半缓存（内部方法）
static func _clear_half_cache():
	var keys_to_remove = _node_cache.keys()
	var remove_count = keys_to_remove.size() / 2
	for i in range(remove_count):
		_node_cache.erase(keys_to_remove[i])

## 清除所有缓存
##
## 在以下情况下应该调用此方法：
## - 场景树发生重大变化
## - 节点被大量添加或删除
## - 需要强制重新查找节点时
static func clear_all_cache():
	_node_cache.clear()
	_cache_hits = 0
	_cache_misses = 0

## 在运行时通过相对路径查找节点（多种策略）
##
## 这个方法尝试多种策略来查找节点，提高成功率：
## 1. 从起始节点直接使用相对路径获取
## 2. 从场景根节点使用相对路径获取
## 3. 递归搜索匹配节点名称的节点
##
## 参数：
## - start_node: Node - 搜索的起始节点（通常是 Trigger 节点）
## - relative_path: NodePath - 要查找的相对路径
## - max_depth: int = 10 - 最大搜索深度
##
## 返回：
## - Node - 找到的节点，如果没找到则返回 null
static func find_node_at_runtime(start_node: Node, relative_path: NodePath, max_depth: int = 10) -> Node:
	if not start_node or relative_path.is_empty():
		return null

	var path_string = str(relative_path)

	# 策略 1: 从起始节点直接使用相对路径获取
	var target = start_node.get_node_or_null(relative_path)
	if target:
		return target

	# 策略 2: 从场景根节点使用相对路径获取
	var scene_root = Engine.get_main_loop().current_scene
	if scene_root:
		target = scene_root.get_node_or_null(relative_path)
		if target:
			return target

	# 策略 3: 获取节点名称，递归搜索
	var path_parts = path_string.split("/")
	var target_name = path_parts[-1]

	if target_name.is_empty() or target_name == "..":
		return null

	# 从场景根节点递归搜索
	if scene_root:
		target = _recursive_find_node_by_name(scene_root, target_name, 0, max_depth)
		if target:
			return target

	return null

## 在编辑器场景中通过相对路径查找节点
##
## 在编辑器中，Resource 可能还没有实例化到场景中，
## 所以无法直接使用相对路径。这个函数会在整个编辑场景中递归搜索匹配的节点。
##
## 参数：
## - root: Node - 搜索的根节点（通常是 edited_scene_root）
## - relative_path: NodePath - 要查找的相对路径
## - max_depth: int = 10 - 最大搜索深度
## - use_cache: bool = true - 是否使用缓存（默认启用）
##
## 返回：
## - Node - 找到的节点，如果没找到则返回 null
static func find_node_by_relative_path(root: Node, relative_path: NodePath, max_depth: int = 10, use_cache: bool = true) -> Node:
	if not root or relative_path.is_empty():
		return null

	var path_string = str(relative_path)

	# 检查缓存
	if use_cache:
		var cached_node = _get_from_cache(root, path_string, max_depth)
		if cached_node != null:
			return cached_node

	# 尝试直接获取（可能是绝对路径或相对路径刚好匹配）
	var node = root.get_node_or_null(relative_path)
	if node:
		# 存入缓存（如果是有效节点）
		if use_cache and node.is_inside_tree():
			_store_in_cache(root, path_string, max_depth, node)
		return node

	# 获取相对路径的最后一部分（节点名称）
	var path_parts = path_string.split("/")
	var target_name = path_parts[-1]

	# 如果最后一部分是空或者是 ".."，返回null
	if target_name.is_empty() or target_name == "..":
		return null

	# 递归遍历所有节点，查找节点名称匹配的节点
	var result = _recursive_find_node_by_name(root, target_name, 0, max_depth, false)

	# 存入缓存（只缓存有效的节点，避免重复查找不存在的节点）
	if use_cache:
		if result and result.is_inside_tree():
			_store_in_cache(root, path_string, max_depth, result)

	return result

## 从资源上下文查找节点（推荐用于编辑器模式）
##
## 这个方法会自动找到资源所在的节点，然后从那里解析相对路径。
## 这解决了资源存储在子节点下时，相对路径解析错误的问题。
##
## 参数：
## - root: Node - 搜索的根节点（通常是 edited_scene_root）
## - resource: Resource - 调用此方法的资源（通常是指令或事件）
## - target_path: NodePath - 要查找的目标节点路径
## - max_depth: int = 10 - 最大搜索深度
## - use_cache: bool = true - 是否使用缓存（默认启用）
##
## 返回：
## - Node - 找到的节点，如果没找到则返回 null
static func find_node_from_resource_context(root: Node, resource: Resource, target_path: NodePath, max_depth: int = 10, use_cache: bool = true) -> Node:
	if not root or not resource or target_path.is_empty():
		return null

	# 如果是绝对路径，直接从根节点获取
	if target_path.is_absolute():
		return root.get_node_or_null(target_path)

	# 查找资源所在的节点
	var resource_owner = _find_resource_owner(root, resource, use_cache)
	if resource_owner:
		# 从资源所在的 Trigger 节点解析相对路径
		# ".." 表示 Trigger 的父节点，"." 表示 Trigger 本身
		var target = resource_owner.get_node_or_null(target_path)
		if target:
			return target

	# 降级到普通的相对路径查找
	return find_node_by_relative_path(root, target_path, max_depth, use_cache)

## 查找拥有指定资源的节点（内部方法）
##
## 通过遍历场景树，找到包含指定资源的 Trigger/Runner 节点或其他容器节点
## 返回资源所在的容器节点本身（用于正确解析相对路径）
static func _find_resource_owner(root: Node, resource: Resource, use_cache: bool = true) -> Node:
	if not root or not resource:
		return null

	var all_nodes = _get_all_nodes_recursive(root)

	for node in all_nodes:
		# 检查节点是否是 MultiEventTrigger 类型
		# MultiEventTrigger 的资源存储在 event_bindings 数组的各 EventBinding 中
		# （binding.event / binding.action_runner.instructions），没有直接的
		# event_definition / action_runner 属性
		if "event_bindings" in node:
			var event_bindings = node.get("event_bindings")
			if event_bindings:
				for binding in event_bindings:
					if binding == resource:
						return node
					if not binding is Resource:
						continue
					if "event" in binding and binding.get("event") == resource:
						return node
					if "action_runner" in binding:
						var binding_runner = binding.get("action_runner")
						if binding_runner and _check_action_runner_ownership(binding_runner, resource):
							return node

		# 检查节点是否是 Trigger 类型
		# Trigger 类有 event_definition 和 action_runner 两个 @export 属性
		if "event_definition" in node and "action_runner" in node:
			# 首先检查 event_definition 是否是目标资源
			var event_definition = node.get("event_definition")
			if event_definition == resource:
				return node

			# 然后检查 action_runner 是否包含目标资源
			var action_runner = node.get("action_runner")
			if action_runner:
				if _check_action_runner_ownership(action_runner, resource):
					return node

		# 检查节点是否是 Runner 类型（有 action_runner 但没有 event_definition）
		elif "action_runner" in node and not "event_definition" in node:
			var action_runner = node.get("action_runner")
			if action_runner:
				if _check_action_runner_ownership(action_runner, resource):
					return node

	return null

## 检查 ActionRunner 资源是否包含目标资源
static func _check_action_runner_ownership(action_runner: Resource, resource: Resource) -> bool:
	# 检查 action_runner 本身是否是目标资源
	if action_runner == resource:
		return true

	# 直接访问 instructions 属性
	if "instructions" in action_runner:
		var instructions = action_runner.get("instructions")
		if instructions:
			for inst in instructions:
				if inst == resource:
					return true

	return false

## 递归获取所有节点（内部方法）
static func _get_all_nodes_recursive(root: Node) -> Array[Node]:
	var nodes: Array[Node] = []
	nodes.append(root)

	for child in root.get_children():
		nodes.append_array(_get_all_nodes_recursive(child))

	return nodes

## 递归查找节点（内部使用，按名称匹配，优化版）
##
## 优化说明：
## 1. 使用路径匹配优先（深度优先）
## 2. 限制最大遍历节点数
## 3. 提前退出机制
static func _recursive_find_node_by_name(parent: Node, target_name: String, current_depth: int, max_depth: int, debug: bool = false) -> Node:
	if current_depth >= max_depth:
		return null

	# 检查当前节点是否匹配
	if parent.name == target_name:
		return parent

	# 递归检查子节点（使用广度优先搜索，更容易找到浅层节点）
	var children = parent.get_children()
	if children.is_empty():
		return null

	# 优化：先检查直接子节点，再递归检查
	for child in children:
		if child.name == target_name:
			return child

	# 没有在直接子节点中找到，递归查找
	for child in children:
		var result = _recursive_find_node_by_name(child, target_name, current_depth + 1, max_depth, debug)
		if result:
			return result

	return null

## 获取节点的完整路径字符串（用于调试）
static func get_node_path_string(node: Node) -> String:
	if not node or not node.is_inside_tree():
		return ""
	return str(node.get_path())

## 验证节点路径是否有效
##
## 在编辑器中，检查给定的相对路径能否在场景中找到对应的节点
##
## 参数：
## - root: Node - 场景根节点
## - relative_path: NodePath - 要验证的相对路径
##
## 返回：
## - bool - 路径是否有效
static func validate_node_path(root: Node, relative_path: NodePath) -> bool:
	if not root or relative_path.is_empty():
		return false

	var found = find_node_by_relative_path(root, relative_path)
	return found != null

## 获取缓存统计信息（用于调试和性能监控）
##
## 返回包含以下信息的字典：
## - cache_size: 当前缓存条目数量
## - cache_hits: 缓存命中次数
## - cache_misses: 缓存未命中次数
## - hit_rate: 缓存命中率（百分比）
## - max_size: 缓存最大容量
static func get_cache_stats() -> Dictionary:
	return {
		"cache_size": _node_cache.size(),
		"cache_hits": _cache_hits,
		"cache_misses": _cache_misses,
		"hit_rate": _get_cache_hit_rate(),
		"max_size": _cache_max_size
	}

## 打印缓存统计信息（用于调试）
static func print_cache_stats():
	var stats = get_cache_stats()
	print("[FuseNodeUtils] === 缓存统计 ===")
	print("[FuseNodeUtils] 缓存大小: %d / %d" % [stats.cache_size, stats.max_size])
	print("[FuseNodeUtils] 命中次数: %d, 未命中次数: %d" % [stats.cache_hits, stats.cache_misses])
	print("[FuseNodeUtils] 命中率: %.2f%%" % stats.hit_rate)
	print("[FuseNodeUtils] ================")

## 在编辑器模式下从相对路径解析节点名称
##
## 将相对路径（如 "..", "../NodeName"）解析为可读的节点名称。
## 用于 resource_name 等需要用户可读显示的场景。
##
## 解析策略：
## 1. 快速路径：路径末尾有明确节点名（非纯相对引用）→ 直接提取
## 2. 编辑器模式：通过 EditorInterface 和 find_node_from_resource_context 解析
## 3. 回退：返回原始路径字符串
##
## 参数：
## - resource: Resource - 调用此方法的资源（通常是指令或事件）
## - path: NodePath - 要解析的节点路径
##
## 返回：
## - String - 可读的节点名称
static func resolve_node_name_for_display(resource: Resource, path: NodePath) -> String:
	if path.is_empty():
		return ""
	# 快速路径：路径末尾有明确节点名（非纯相对引用）
	var file_name = str(path).get_file()
	if not file_name.is_empty() and file_name != ".." and file_name != ".":
		return file_name
	# 编辑器模式下尝试解析纯相对引用（.. / .）
	if Engine.is_editor_hint():
		var editor_interface = Engine.get_singleton("EditorInterface")
		if editor_interface:
			var root = editor_interface.get_edited_scene_root()
			if root:
				var node = find_node_from_resource_context(root, resource, path)
				if node:
					return node.name
	# 回退：返回原始路径
	return str(path)

## 清除特定根节点的所有缓存
##
## 当某个场景树发生重大变化时，可以使用此方法清除相关缓存
##
## 参数：
## - root: Node - 要清除缓存的目标根节点
static func clear_cache_for_root(root: Node):
	if not root or not root.is_inside_tree():
		return

	var root_path = root.get_path()
	var keys_to_remove = []

	for key in _node_cache.keys():
		if key.begins_with(root_path):
			keys_to_remove.append(key)

	for key in keys_to_remove:
		_node_cache.erase(key)

## UID 路径显示名称缓存（避免重复处理）
static var _uid_display_name_cache: Dictionary = {}

## 获取路径的显示名称（处理 UID 路径）
##
## 当路径以 "uid://" 开头时，通过 ResourceUID 解析为实际路径后提取文件名，
## 不使用 load() 避免触发级联资源加载。
##
## 参数：
## - path: String - 要处理的路径（可能是 res:// 路径或 uid:// 路径）
##
## 返回：
## - String - 可读的文件名
static func get_path_display_name(path: String) -> String:
	if path.is_empty():
		return ""

	if _uid_display_name_cache.has(path):
		return _uid_display_name_cache[path]

	var display_name: String
	if path.begins_with("uid://"):
		# 通过 ResourceUID 解析，不需要 load()
		var uid_int = ResourceUID.text_to_id(path)
		if uid_int != ResourceUID.INVALID_ID:
			var real_path = ResourceUID.get_id_path(uid_int)
			if not real_path.is_empty():
				display_name = real_path.get_file()
		if display_name.is_empty():
			# 回退：显示 UID 文本
			display_name = path.trim_prefix("uid://")
	else:
		display_name = path.get_file()

	_uid_display_name_cache[path] = display_name
	return display_name

## 设置缓存最大容量
##
## 默认值为 1000，可以根据需要调整
##
## 参数：
## - size: int - 新的最大缓存容量（必须大于 0）
static func set_cache_max_size(size: int):
	if size <= 0:
		push_error("[FuseNodeUtils] 缓存最大容量必须大于 0")
		return

	_cache_max_size = size

	# 如果当前缓存大小超过新的最大值，清除部分缓存
	if _node_cache.size() > _cache_max_size:
		_clear_half_cache()
