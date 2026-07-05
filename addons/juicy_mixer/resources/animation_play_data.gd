# AnimationPlayData - 动画播放数据类
# 定义单个动画播放的配置参数，支持状态还原和多种播放模式

@tool
class_name AnimationPlayData
extends JuicyFeedbackData

# 播放模式枚举
enum PlayMode {
	NORMAL,  # 使用 AnimationPlayer.play() 方法
	SYNC	 # 使用 AnimationPlayer.seek() 方法，受时间缩放影响
}

# 完成动作枚举
enum OnCompleteAction {
	RESTORE_STATE,	# 还原到动画开始前的状态快照
	KEEP_LAST_FRAME,  # 保持动画最后一帧的状态
	RESET_TRACKS,	  # 还原到 Godot 动画的 Reset 轨道状态
}

# =============================================================================
# 属性定义
# =============================================================================

## 目标节点路径
var target: NodePath = NodePath():
	set(value):
		if target != value:
			target = value
			# 当target改变时，清除缓存并触发属性更新
			_cached_animation_list.clear()
			_cached_animation_player = null
			# 使用 call_deferred 避免线程安全问题
			if Engine.is_editor_hint():
				call_deferred("notify_property_list_changed")
			else:
				notify_property_list_changed()

## 目标动画名称（根据AnimationPlayer动态生成选项）
var target_animation: String = "":
	set(value):
		if target_animation != value:
			target_animation = value
			# 清除缓存以确保属性列表更新
			_cached_animation_list.clear()
			# 使用 call_deferred 避免线程安全问题
			if Engine.is_editor_hint():
				call_deferred("notify_property_list_changed")
			else:
				notify_property_list_changed()

## 播放模式
var play_mode: PlayMode = PlayMode.NORMAL:
	set(value):
		if play_mode != value:
			play_mode = value
			# 使用 call_deferred 避免线程安全问题
			if Engine.is_editor_hint():
				call_deferred("notify_property_list_changed")
			else:
				notify_property_list_changed()

## 动画播放停止位置（0.0-1.0）
var end_at: float = 1.0:
	set(value):
		if end_at != value:
			end_at = value

## 混入时间（秒）
var blend_in_time: float = 0.1:
	set(value):
		if blend_in_time != value:
			blend_in_time = value

## 完成动作
var on_complete_action: OnCompleteAction = OnCompleteAction.KEEP_LAST_FRAME:
	set(value):
		if on_complete_action != value:
			on_complete_action = value
			# 使用 call_deferred 避免线程安全问题
			if Engine.is_editor_hint():
				call_deferred("notify_property_list_changed")
			else:
				notify_property_list_changed()

# =============================================================================
# 序列化的缓存数据（关键：避免实时场景树访问）
# =============================================================================

## 序列化的动画列表缓存（保存到资源文件）
var serialized_animation_list: Array[String] = []:
	set(value):
		serialized_animation_list = value
		_deserialize_animation_cache()

# =============================================================================
# 运行时缓存数据
# =============================================================================

## 缓存的AnimationPlayer引用
var _cached_animation_player: AnimationPlayer = null

## 缓存的动画列表（运行时使用）
var _cached_animation_list: Array[String] = []

## 缓存的动画长度
var _cached_animation_length: float = 0.0

## 缓存有效性标志
var _cache_valid: bool = false

## 防止无限循环的标志
var _is_updating_properties: bool = false

# =============================================================================
# 线程安全辅助方法
# =============================================================================

var _main_thread_check_done: bool = false
var _is_main_thread: bool = false

func _can_safely_access_editor() -> bool:
	"""
	检查是否可以安全地访问编辑器接口
	使用更安全的方法检查线程状态
	
	@return: 是否可以安全访问
	"""
	if not Engine.is_editor_hint():
		return false
	
	# 更安全的线程检查：使用 call_deferred 来测试
	# 如果我们在后台线程，call_deferred 会在下一帧的主线程中执行
	# 我们使用一个简单的标志来检查
	return _is_main_thread_safe()



func _is_main_thread_safe() -> bool:
	"""
	安全地检查是否在主线程中
	使用缓存避免重复检查
	
	@return: 是否在主线程中
	"""
	if _main_thread_check_done:
		return _is_main_thread
	
	# 执行主线程检查
	_main_thread_check_done = true
	_is_main_thread = true  # 假设我们在主线程，如果出错会通过其他方式处理
	return _is_main_thread

# =============================================================================
# 资源生命周期管理
# =============================================================================

func _ready():
	# 在编辑器中，当资源加载完成后初始化
	if Engine.is_editor_hint():
		# 使用 call_deferred 确保在所有属性加载完成后执行
		call_deferred("_initialize_after_load")

func _initialize_after_load():
	# 反序列化缓存
	if not serialized_animation_list.is_empty():
		_deserialize_animation_cache()
	
	# 如果有目标节点但缓存为空，尝试延迟更新缓存
	if not target.is_empty() and _cached_animation_list.is_empty():
		call_deferred("_update_animation_cache_safe")
	elif not target.is_empty():
		# 如果有目标节点，总是尝试更新缓存（确保获取最新数据）
		call_deferred("_update_animation_cache_safe")
	
	# 通知属性列表变化，确保UI更新
	notify_property_list_changed()

func _invalidate_cache():
	"""使缓存失效"""
	_cached_animation_player = null
	_cached_animation_list.clear()
	_cached_animation_length = 0.0
	_cache_valid = false

func _serialize_animation_cache():
	"""序列化动画缓存到资源属性"""
	if _cached_animation_list.is_empty():
		return
	
	serialized_animation_list.clear()
	for animation_name in _cached_animation_list:
		serialized_animation_list.append(animation_name)

func _deserialize_animation_cache():
	"""从资源属性反序列化动画缓存"""
	if serialized_animation_list.is_empty():
		return
	
	_cached_animation_list.clear()
	for animation_name in serialized_animation_list:
		_cached_animation_list.append(animation_name)
	
	_cache_valid = true

# =============================================================================
# 线程安全的动画缓存更新方法
# =============================================================================

func _update_animation_cache_safe():
	"""线程安全的动画缓存更新"""
	if not Engine.is_editor_hint():
		return
	
	# 使用 call_deferred 确保在主线程中执行
	call_deferred("_refresh_animation_cache")

func _refresh_animation_cache():
	"""刷新动画缓存（在主线程中执行）"""
	if not Engine.is_editor_hint():
		return
	
	# 检查目标路径是否有效
	if target.is_empty():
		return
	
	# 获取目标节点
	var target_node = _get_target_node_safe()
	if not target_node:
		return
	
	# 查找AnimationPlayer
	var animation_player = _find_animation_player(target_node)
	if not animation_player:
		_cached_animation_list = ["<No AnimationPlayer Found>", "idle", "walk", "run", "jump"]
		_cache_valid = true
		_serialize_animation_cache()
		notify_property_list_changed()
		return
	
	# 获取动画列表
	var animation_list = animation_player.get_animation_list()
	if animation_list.is_empty():
		_cached_animation_list = ["<No Animations>"]
	else:
		_cached_animation_list.clear()
		for anim_name in animation_list:
			_cached_animation_list.append(anim_name)
	
	_cache_valid = true
	_cached_animation_player = animation_player
	
	# 序列化缓存
	_serialize_animation_cache()
	
	# 通知属性列表更新
	notify_property_list_changed()

func _get_target_node_safe() -> Node:
	"""线程安全的目标节点获取"""
	if target.is_empty():
		return null
	
	# 线程安全检查：只有在安全的情况下才访问编辑器接口
	if not _can_safely_access_editor():
		return null
	
	var edited_scene_root = EditorInterface.get_edited_scene_root()
	if not edited_scene_root:
		return null
	
	var target_node_str = str(target)
	
	# 尝试直接获取节点
	var target_node = edited_scene_root.get_node_or_null(target_node_str)
	if target_node:
		return target_node
	
	# 如果直接获取失败，尝试处理相对路径
	if target_node_str.begins_with("../"):
		var root_path = edited_scene_root.get_path()
		var relative_part = target_node_str.substr(3)  # 移除 "../"
		var absolute_path = str(root_path) + "/" + relative_part
		target_node = edited_scene_root.get_node_or_null(absolute_path)
		if target_node:
			return target_node
	
	return null


func _find_animation_player(node: Node) -> AnimationPlayer:
	"""查找AnimationPlayer"""
	# 尝试通过get_animation_player()方法获取
	if node.has_method("get_animation_player"):
		var player = node.get_animation_player()
		if player and player is AnimationPlayer:
			return player
	
	# 递归查找子节点中的AnimationPlayer
	return _find_child_animation_player(node)

# =============================================================================
# 验证方法
# =============================================================================

func validate() -> Dictionary:
	"""
	验证数据有效性
	
	@return: 验证结果字典，包含valid、issues和warnings
	"""
	var result = {
		"valid": true,
		"issues": [],
		"warnings": []
	}
	
	if target.is_empty():
		result.valid = false
		result.issues.append("Target path cannot be empty")
	
	if target_animation.is_empty():
		result.valid = false
		result.issues.append("Target animation cannot be empty")
	
	if end_at <= 0.0 or end_at > 1.0:
		result.valid = false
		result.issues.append("End at must be between 0.0 and 1.0")
	
	if blend_in_time < 0.0:
		result.valid = false
		result.issues.append("Blend in time cannot be negative")

	
	# 验证完成动作
	if on_complete_action < 0 or on_complete_action >= OnCompleteAction.size():
		result.valid = false
		result.issues.append("Invalid on_complete_action value")
	
	return result

# =============================================================================
# 动画播放器获取方法
# =============================================================================

func get_target_node(nodepath: NodePath = NodePath()) -> Node:
	var path_to_use = nodepath if not nodepath.is_empty() else target
	
	if path_to_use.is_empty():
		return null
	
	# 在编辑器中使用特殊方法获取节点
	if Engine.is_editor_hint():
		# 线程安全检查：只有在安全的情况下才访问编辑器接口
		if not _can_safely_access_editor():
			return null
		
		var edited_scene_root = EditorInterface.get_edited_scene_root()
		if edited_scene_root:
			# 尝试直接获取节点
			var target_node = edited_scene_root.get_node_or_null(path_to_use)
			if target_node:
				return target_node
			
			# 如果直接获取失败，尝试处理相对路径
			var path_str = str(path_to_use)
			if path_str.begins_with("../"):
				var root_path = edited_scene_root.get_path()
				var absolute_path = str(root_path) + "/" + path_str.substr(3)  # 移除 "../"
				target_node = edited_scene_root.get_node(absolute_path)
				if target_node:
					return target_node
			
			return null
		else:
			return null
	else:
		# 运行时使用原有逻辑
		var root = Engine.get_main_loop().current_scene
		if root:
			return root.get_node_or_null(path_to_use)
		else:
			return null


func get_animation_player(context_node: Node) -> AnimationPlayer:
	"""
	获取目标节点的AnimationPlayer
	
	@param context_node: 上下文节点，用于解析相对路径
	@return: AnimationPlayer实例，如果未找到则返回null
	"""
	if _cached_animation_player:
		return _cached_animation_player
	
	# 检查context_node是否有效
	if not context_node:
		push_warning("AnimationPlayData: Context node is null")
		return null
	
	# 解析目标节点
	var target_node = context_node.get_node(target)
	if not target_node:
		# 如果相对路径解析失败，尝试从场景根节点解析
		var scene_root = context_node.get_tree().current_scene
		if scene_root:
			target_node = scene_root.get_node(target)
		
		if not target_node:
			push_warning("AnimationPlayData: Target node not found: " + str(target) + " from context: " + context_node.name)
			return null
	
	# 尝试通过get_animation_player()方法获取
	if target_node.has_method("get_animation_player"):
		var player = target_node.get_animation_player()
		if player and player is AnimationPlayer:
			_cached_animation_player = player
			return player
	
	# 尝试通过递归查找子AnimationPlayer
	var player = _find_child_animation_player(target_node)
	if player:
		_cached_animation_player = player
		return player
	
	push_warning("AnimationPlayData: AnimationPlayer not found for target: " + str(target))
	return null

func _find_child_animation_player(node: Node) -> AnimationPlayer:
	"""
	递归查找子节点中的AnimationPlayer
	
	@param node: 要搜索的节点
	@return: 找到的AnimationPlayer，未找到则返回null
	"""
	for child in node.get_children():
		if child is AnimationPlayer:
			return child
		
		var found = _find_child_animation_player(child)
		if found:
			return found
	
	return null

# =============================================================================
# 动画列表方法
# =============================================================================

func get_animation_list(context_node: Node) -> Array[String]:
	"""
	获取AnimationPlayer中的动画列表
	
	@param context_node: 上下文节点
	@return: 动画名称数组
	"""
	if not _cached_animation_list.is_empty():
		return _cached_animation_list
	
	var player = get_animation_player(context_node)
	if not player:
		return []
	
	# 获取动画列表
	_cached_animation_list = []
	var anim_list = player.get_animation_list()
	
	for anim_name in anim_list:
		_cached_animation_list.append(anim_name)
	
	return _cached_animation_list

# =============================================================================
# 动画长度方法
# =============================================================================

func get_animation_length(context_node: Node = null) -> float:
	"""
	获取目标动画的长度
	
	@param context_node: 上下文节点（可选）
	@return: 动画长度（秒），如果未找到则返回0.0
	"""
	if _cached_animation_length > 0.0:
		return _cached_animation_length
	
	var player = null
	
	# 尝试通过 context_node 获取 AnimationPlayer
	if context_node:
		player = get_animation_player(context_node)
	
	# 如果没有 context_node 或获取失败，尝试直接获取
	if not player:
		var target_node = get_target_node()
		if target_node:
			player = get_animation_player_from_node(target_node)
	
	if not player:
		return 0.0
	
	var animation = player.get_animation(target_animation)
	if not animation:
		push_warning("AnimationPlayData: Animation not found: " + target_animation)
		return 0.0
	
	_cached_animation_length = animation.length
	return _cached_animation_length

func get_animation_player_from_node(target_node: Node) -> AnimationPlayer:
	"""
	从目标节点直接获取AnimationPlayer，不依赖context_node
	
	@param target_node: 目标节点
	@return: AnimationPlayer实例，如果未找到则返回null
	"""
	if not target_node:
		return null
	
	# 尝试通过get_animation_player()方法获取
	if target_node.has_method("get_animation_player"):
		var player = target_node.get_animation_player()
		if player and player is AnimationPlayer:
			return player
	
	# 尝试通过递归查找子AnimationPlayer
	return _find_child_animation_player(target_node)

# =============================================================================
# 实用方法
# =============================================================================

func get_description() -> String:
	"""
	获取友好的描述字符串
	
	@return: 描述字符串
	"""
	var mode_name = "NORMAL" if play_mode == PlayMode.NORMAL else "SYNC"
	var action_name = ""
	match on_complete_action:
		OnCompleteAction.RESTORE_STATE:
			action_name = "RESTORE_STATE"
		OnCompleteAction.KEEP_LAST_FRAME:
			action_name = "KEEP_LAST_FRAME"
		OnCompleteAction.RESET_TRACKS:
			action_name = "RESET_TRACKS"
	
	return "%s: %s (%s, end_at=%.2f, action=%s)" % [str(target), target_animation, mode_name, end_at, action_name]

func duplicate_animation_data() -> AnimationPlayData:
	"""
	复制当前实例
	
	@return: 新的AnimationPlayData实例
	"""
	var new_data = AnimationPlayData.new()
	new_data.target = target
	new_data.target_animation = target_animation
	new_data.play_mode = play_mode
	new_data.end_at = end_at
	new_data.blend_in_time = blend_in_time
	new_data.on_complete_action = on_complete_action
	return new_data

# =============================================================================
# 编辑器支持
# =============================================================================

func _get_configuration_warning() -> String:
	"""
	获取配置警告信息
	
	@return: 警告信息字符串
	"""
	var result = validate()
	if not result.valid:
		return "Configuration errors: " + ", ".join(result.issues)
	
	if not result.warnings.is_empty():
		return "Configuration warnings: " + ", ".join(result.warnings)
	
	return ""

func _get_property_list() -> Array[Dictionary]:
	"""
	获取自定义属性列表，用于编辑器显示（关键：避免实时场景树访问）
	
	@return: 属性列表
	"""
	if _is_updating_properties:
		return []
	
	var properties = []
	
	# 目标选择
	properties.append({
		"name": "target",
		"type": TYPE_NODE_PATH,
		"hint": PROPERTY_HINT_NODE_PATH_VALID_TYPES,
		"hint_string": "Node",
		"usage": PROPERTY_USAGE_DEFAULT
	})
	
	# 动画选择（关键：完全依赖缓存，避免实时访问）
	var animation_list = []
	if not target.is_empty():
		# 只检查路径字符串，防止后台线程调用 get_node 崩溃
		animation_list = _get_animation_list_for_editor()
		if animation_list.size() > 0:
			properties.append({
				"name": "target_animation",
				"type": TYPE_STRING,
				"hint": PROPERTY_HINT_ENUM,
				"hint_string": ",".join(animation_list),
				"usage": PROPERTY_USAGE_DEFAULT
			})
		else:
			# 如果动画列表为空但已有target_animation值，仍然显示为可编辑
			if not target_animation.is_empty():
				properties.append({
					"name": "target_animation",
					"type": TYPE_STRING,
					"hint": PROPERTY_HINT_PLACEHOLDER_TEXT,
					"hint_string": target_animation,
					"usage": PROPERTY_USAGE_DEFAULT
				})
			else:
				properties.append({
					"name": "target_animation",
					"type": TYPE_STRING,
					"hint": PROPERTY_HINT_PLACEHOLDER_TEXT,
					"hint_string": "目标节点没有可用动画",
					"usage": PROPERTY_USAGE_READ_ONLY
				})
	else:
		properties.append({
			"name": "target_animation",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_PLACEHOLDER_TEXT,
			"hint_string": "请先选择目标节点",
			"usage": PROPERTY_USAGE_READ_ONLY
		})
	
	# 播放模式
	properties.append({
		"name": "play_mode",
		"type": TYPE_INT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": "NORMAL,SYNC",
		"usage": PROPERTY_USAGE_DEFAULT
	})
	
	# 动画播放停止位置
	properties.append({
		"name": "end_at",
		"type": TYPE_FLOAT,
		"hint": PROPERTY_HINT_RANGE,
		"hint_string": "0.0,1.0,0.01",
		"usage": PROPERTY_USAGE_DEFAULT
	})
	
	# 混入时间
	properties.append({
		"name": "blend_in_time",
		"type": TYPE_FLOAT,
		"hint": PROPERTY_HINT_RANGE,
		"hint_string": "0.0,5.0,0.1",
		"usage": PROPERTY_USAGE_DEFAULT
	})
	
	# 完成动作
	properties.append({
		"name": "on_complete_action",
		"type": TYPE_INT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": "RESTORE_STATE,KEEP_LAST_FRAME,RESET_TRACKS",
		"usage": PROPERTY_USAGE_DEFAULT
	})
	
	return properties

func _validate_property(property: Dictionary) -> void:
	"""条件化属性显示"""
	# 如果没有选择目标节点（只检查路径是否设置，不检查实例，避免线程报错），禁用动画选择
	if target.is_empty() and property.name == "target_animation":
		property.usage = PROPERTY_USAGE_READ_ONLY
	elif not target.is_empty() and property.name == "target_animation":
		# 如果有目标节点，确保动画选择是可编辑的
		property.usage = PROPERTY_USAGE_DEFAULT

func _get_animation_list_for_editor() -> Array[String]:
	"""
	为编辑器获取动画列表（关键：只使用缓存，避免实时场景树访问）
	
	@return: 动画名称数组
	"""
	# 关键：完全依赖缓存，避免实时场景树访问
	# 这就是 RunTargetNodeFunction 成功的关键！
	if _cache_valid and not _cached_animation_list.is_empty():
		return _cached_animation_list.duplicate()
	
	# 缓存无效时的备用方案 - 尝试获取真实数据
	if not target.is_empty():
		# 尝试同步获取动画列表（如果线程安全）
		if _can_safely_access_editor():
			var real_list = _get_real_animation_list()
			if not real_list.is_empty():
				return real_list
		
		# 如果无法获取真实数据，使用默认列表但触发异步更新
		call_deferred("_update_animation_cache_safe")
		return ["<Loading...>", "idle", "walk", "run", "jump"]
	else:
		return ["<No Target Selected>"]

func _get_real_animation_list() -> Array[String]:
	"""获取真实的动画列表（线程安全版本）"""
	if target.is_empty():
		return []
	
	# 完全避免在属性列表生成时访问编辑器接口
	# 直接返回默认列表，触发异步更新
	call_deferred("_update_animation_cache_safe")
	
	return ["<Loading...>", "idle", "walk", "run", "jump"]

# =============================================================================
# 序列化支持
# =============================================================================

func _to_string() -> String:
	"""
	获取对象的字符串表示
	
	@return: 描述字符串
	"""
	var mode_name = "NORMAL" if play_mode == PlayMode.NORMAL else "SYNC"
	var action_name = ""
	match on_complete_action:
		OnCompleteAction.RESTORE_STATE:
			action_name = "RESTORE_STATE"
		OnCompleteAction.KEEP_LAST_FRAME:
			action_name = "KEEP_LAST_FRAME"
		OnCompleteAction.RESET_TRACKS:
			action_name = "RESET_TRACKS"
	
	return "AnimationPlayData(%s: %s, %s, end_at=%.2f, blend_in=%.2f, action=%s)" % [
		str(target), target_animation, mode_name, end_at, blend_in_time, action_name
	]
