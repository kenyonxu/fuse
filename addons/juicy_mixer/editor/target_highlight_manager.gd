# TargetHighlightManager - 目标节点高亮管理器
#
# 功能说明：
# - 管理场景编辑器和场景树中的目标节点高亮显示
# - 在2D场景编辑器中绘制彩色矩形框标记目标节点
# - 支持多轨道同时选择，使用不同颜色区分
# - 自动清理无效节点的高亮，避免内存泄漏
#
# 使用方式：
# var manager = TargetHighlightManager.get_instance()
# manager.add_highlight(track, viewport)
# manager.clear_all()
#
# 架构：
# - 单例模式：全局唯一实例
# - HighlightInfo：高亮信息数据结构
# - 非 RTI：每帧动态绘制，不保存绘制状态
#
# 相关类：
# - JuicyTimelineEditor: 轨道选择监听
# - JuicyMixer Plugin: 场景绘制层
#
# @see docs/juicy_mixer/target-highlight-system.md

class_name TargetHighlightManager
extends RefCounted

## 高亮信息数据结构
class HighlightInfo extends RefCounted:

	var track: JuicyTrack          # 来源轨道
	var node_path: NodePath         # 目标节点路径
	var color: Color                # 标记颜色（使用 track_color）
	var viewport: Viewport          # 所属视口
	var cached_global_rect: Rect2   # 缓存全局位置，减少每帧计算
	var node: Node                  # 缓存节点引用，用于获取屏幕位置

	func is_valid() -> bool:
		"""检查高亮是否仍然有效"""
		return track != null and not track.target.is_empty()

static var instance: TargetHighlightManager = null

## 活动高亮列表
var active_highlights: Array[HighlightInfo] = []

## 单例模式
static func get_instance() -> TargetHighlightManager:
	"""获取高亮管理器单例"""
	if not instance:
		instance = TargetHighlightManager.new()
	return instance

## 添加轨道目标的高亮
func add_highlight(track: JuicyTrack, viewport: Viewport) -> bool:
	"""添加轨道目标的高亮

	@param track: 要高亮的轨道
	@param viewport: 目标视口
	@return: 成功返回 true，失败返回 false
	"""
	if not track:
		return false

	if track.target.is_empty():
		return false

	var node = _get_target_node(track.target, viewport)
	if not node:
		return false

	# 检查是否已存在该轨道的高亮
	for highlight in active_highlights:
		if highlight.track == track:
			# 更新颜色和缓存位置
			highlight.color = track.track_color
			highlight.cached_global_rect = _get_node_bounds(node)
			# 更新节点上的元数据
			if highlight.node:
				highlight.node.set_meta("timeline_track_highlight", track.track_color)
			return true

	# 创建新的高亮信息
	var info = HighlightInfo.new()
	info.track = track
	info.node_path = track.target
	info.color = track.track_color
	info.viewport = viewport
	info.cached_global_rect = _get_node_bounds(node)
	info.node = node  # 保存节点引用，用于获取屏幕位置

	# 在节点上存储颜色元数据（用于场景树高亮）
	node.set_meta("timeline_track_highlight", track.track_color)

	active_highlights.append(info)
	return true

## 移除指定轨道的所有高亮
func remove_highlights_for_track(track: JuicyTrack):
	"""移除指定轨道的所有高亮

	@param track: 要移除高亮的轨道
	"""
	# 清除节点上的元数据
	for highlight in active_highlights:
		if highlight.track == track and highlight.node:
			highlight.node.remove_meta("timeline_track_highlight")

	active_highlights = active_highlights.filter(
		func(h): return h.track != track
	)

## 清除所有高亮
func clear_all():
	"""清除所有高亮"""
	# 清除所有节点上的元数据
	for highlight in active_highlights:
		if highlight.node:
			highlight.node.remove_meta("timeline_track_highlight")

	active_highlights.clear()

## 获取在指定视口中可见的高亮
func get_visible_highlights(viewport: Viewport) -> Array[HighlightInfo]:
	"""获取在指定视口中可见的高亮

	@param viewport: 目标视口（暂未使用，返回所有高亮）
	@return: 高亮信息数组
	"""
	# 直接返回所有高亮，因为 EditorInterface.get_editor_viewport_2d()
	# 和 overlay.get_viewport() 可能返回不同的对象实例
	return active_highlights.duplicate()

## 获取所有高亮
func get_all_highlights() -> Array[HighlightInfo]:
	"""获取所有活动的高亮（用于场景树高亮）

	@return: 所有活动高亮的副本
	"""
	return active_highlights.duplicate()

## 清理无效的高亮
func cleanup_invalid_highlights():
	"""清理无效的高亮（节点被删除等）"""
	active_highlights = active_highlights.filter(func(h):
		if not h.is_valid():
			return false
		return _get_target_node(h.node_path, h.viewport) != null
	)

## 安全获取目标节点
func _get_target_node(node_path: NodePath, viewport: Viewport) -> Node:
	"""安全获取目标节点，处理各种边界情况

	@param node_path: 节点路径
	@param viewport: 视口（用于获取编辑场景）
	@return: 目标节点，失败返回 null
	"""
	# 1. 获取当前编辑的场景根节点
	var edited_root = EditorInterface.get_edited_scene_root()
	if not edited_root:
		return null

	# 2. 处理相对路径：如果以 ../ 开头，转换为绝对路径
	var path_string = str(node_path)
	var actual_path = node_path

	if path_string.begins_with("../"):
		# 去掉前导的 ../ 并从 edited_root 解析
		var relative_part = path_string.substr(3)  # 去掉 "../"
		actual_path = NodePath(relative_part)

	# 3. 尝试使用相对路径获取节点
	var node = edited_root.get_node_or_null(actual_path)
	if node:
		return node

	# 4. 尝试绝对路径（从主场景树获取）
	if node_path.is_absolute():
		# 绝对路径需要从主场景树的根获取
		var main_root = Engine.get_main_loop() as SceneTree
		if main_root:
			node = main_root.get_node_or_null(node_path)

	return node

## 获取节点的绘制边界
func _get_node_bounds(node: Node) -> Rect2:
	"""获取节点的绘制边界

	@param node: 目标节点
	@return: 节点的全局边界矩形
	"""
	# Control 节点（UI）
	if node is Control:
		return node.get_global_rect()

	# Node2D 节点
	elif node is Node2D:
		var node2d = node as Node2D
		var size = _estimate_node2d_size(node2d)
		return Rect2(node2d.global_position, size)

	# 其他类型节点（使用默认大小）
	else:
		var transform = node.get_global_transform() if node.has_method("get_global_transform") else Transform2D()
		return Rect2(transform.get_origin(), Vector2(32, 32))

## 估算 Node2D 节点的大小
func _estimate_node2d_size(node: Node) -> Vector2:
	"""估算 Node2D 节点的大小

	@param node: Node2D 节点
	@return: 估算的大小
	"""
	# 尝试从节点的属性获取大小信息
	if node.has_method("get_size"):
		var size = node.call("get_size")
		if size is Vector2:
			return size

	# 根据节点类型返回合理的大小
	if node is Sprite2D:
		if node.texture:
			return node.texture.get_size() * node.scale
		return Vector2(64, 64)
	elif node is Label:
		var theme = ThemeDB.get_default_theme()
		if theme:
			var font = theme.get_font(&"font", &"Label")
			if font:
				return font.get_string_size(node.text)
		return Vector2(100, 20)
	elif node is TileMap:
		return Vector2(128, 128)
	else:
		# 默认大小
		return Vector2(64, 64)

## 调试信息
func get_debug_info() -> String:
	"""获取调试信息"""
	var info = "TargetHighlightManager 活动高亮:\n"
	for i in range(active_highlights.size()):
		var h = active_highlights[i]
		info += "  [%d] 轨道: %s, 目标: %s, 颜色: %s\n" % [
			i,
			h.track.track_name if h.track else "null",
			h.node_path,
			h.color
		]
	return info
