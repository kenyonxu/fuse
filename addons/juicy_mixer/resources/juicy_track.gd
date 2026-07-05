# JuicyTrack - 轨道基类
# 定义所有轨道类型的通用接口和行为
# 作为Timeline系统的基础组件，提供统一的轨道管理接口

@tool
class_name JuicyTrack
extends Resource

# 基础属性
var target: NodePath:					# 作用目标
	set(value):
		target = value
		notify_property_list_changed()
		emit_changed()  # 触发 changed 信号，通知监听器
@export var enabled: bool = true                    # 是否启用
@export var track_name: String = "Track"           # 轨道名称
@export var track_color: Color = Color.WHITE       # 编辑器显示颜色
@export var muted: bool = false                    # 静音状态

# 高级属性
@export var priority: int = 0                      # 优先级（用于排序）
@export var condition: JuicyCondition              # 触发条件
@export var description: String = ""                # 轨道描述


# 获取轨道名
func get_track_name() -> String:
	return track_name


# 获取轨道类型标识
func get_track_type() -> String:
	"""
	获取轨道类型标识
	
	@return: 轨道类型字符串
	"""
	return "BaseTrack"

# 验证轨道配置
func validate_track() -> String:
	"""
	验证轨道配置
	
	@return: 错误信息字符串，空字符串表示无错误
	"""
	# 基类默认无错误
	return ""

# 获取轨道描述信息
func get_description() -> String:
	"""
	获取轨道描述信息
	
	@return: 描述字符串
	"""
	var desc = "JuicyTrack: "
	desc += "type=" + get_track_type()
	desc += ", name=" + track_name
	desc += ", enabled=" + ("true" if enabled else "false")
	desc += ", muted=" + ("true" if muted else "false")
	
	if not description.is_empty():
		desc += ", description=" + description
	
	return desc

# 检查轨道是否在指定时间点活跃
func is_active_at_time(time: float, context: JuicyContext) -> bool:
	"""
	检查轨道是否在指定时间点活跃
	
	@param time: 时间点
	@param context: JuicyContext实例
	@return: 是否活跃
	"""
	# 基础检查
	if not enabled or muted:
		return false
	
	# 条件检查
	if condition:
		return condition.evaluate(context)
	
	return true

# 获取轨道的开始时间
func get_start_time() -> float:
	"""
	获取轨道的开始时间
	
	@return: 开始时间（秒）
	"""
	return 0.0

# 获取轨道的结束时间
func get_end_time() -> float:
	"""
	获取轨道的结束时间
	
	@return: 结束时间（秒）
	"""
	return 0.0

# 获取轨道的持续时间
func get_duration() -> float:
	"""
	获取轨道的持续时间
	
	@return: 持续时间（秒）
	"""
	return get_end_time() - get_start_time()

# 初始化轨道
func initialize_track(context: JuicyContext) -> void:
	"""
	初始化轨道
	
	@param context: JuicyContext实例
	"""
	pass

# 清理轨道
func cleanup_track(context: JuicyContext) -> void:
	"""
	清理轨道
	
	@param context: JuicyContext实例
	"""
	pass

# 序列化支持
func get_config_dict() -> Dictionary:
	"""
	获取配置字典（用于序列化）
	
	@return: 配置字典
	"""
	return {
		"enabled": enabled,
		"track_name": track_name,
		"track_color": track_color.to_html(),
		"muted": muted,
		"priority": priority,
		"description": description
	}

# 从配置字典加载
func load_from_dict(config_dict: Dictionary) -> bool:
	"""
	从配置字典加载
	
	@param config_dict: 配置字典
	@return: 是否成功加载
	"""
	if not config_dict:
		return false
	
	if config_dict.has("enabled"):
		enabled = config_dict["enabled"]
	if config_dict.has("track_name"):
		track_name = config_dict["track_name"]
	if config_dict.has("track_color"):
		track_color = Color.from_string(config_dict["track_color"], Color.WHITE)
	if config_dict.has("muted"):
		muted = config_dict["muted"]
	if config_dict.has("priority"):
		priority = config_dict["priority"]
	if config_dict.has("description"):
		description = config_dict["description"]
	
	return true

# 获取轨道的编辑器图标
func get_editor_icon() -> String:
	"""
	获取轨道的编辑器图标
	
	@return: 图标名称
	"""
	return "Animation"

# 获取轨道的编辑器颜色
func get_editor_color() -> Color:
	"""
	获取轨道的编辑器颜色
	
	@return: 颜色
	"""
	return track_color

# 克隆轨道
func clone() -> JuicyTrack:
	"""
	克隆轨道
	
	@return: 克隆的轨道实例
	"""
	var cloned_track = get_script().new()
	
	# 复制基础属性
	cloned_track.enabled = enabled
	cloned_track.track_name = track_name
	cloned_track.track_color = track_color
	cloned_track.muted = muted
	cloned_track.priority = priority
	cloned_track.condition = condition
	cloned_track.description = description
	
	return cloned_track

func get_target_node() -> Node:
	if target.is_empty():
		push_error("目标节点路径为空")
		return null

	var target_node :Node
	var target_node_str = str(target)
	# 在编辑器中，尝试从当前编辑场景获取节点
	var edited_scene_root = null

	if Engine.is_editor_hint():
		edited_scene_root = EditorInterface.get_edited_scene_root()
		if not edited_scene_root:
			return null

		# 尝试直接获取节点
		target_node = edited_scene_root.get_node_or_null(target)

		if target_node:
			return target_node

		# 如果直接获取失败，尝试组合绝对路径
		elif target_node_str.begins_with("../"):
			var root_path = str(edited_scene_root.get_path())

			target_node = edited_scene_root.get_node(_get_absolute_path(target_node_str, root_path))
			if target_node:
				return target_node
			else:
				return null
		else:
			return null
	else:
		var root = Engine.get_main_loop().current_scene

		# 🔥 检查 root 是否为 null
		if not root:
			return null

		var root_path = root.get_path()
		var path_to_target = _get_absolute_path(target, root_path)

		target_node = root.get_node_or_null(path_to_target)
		return target_node

# 编辑器环境下的节点获取
func _get_target_node_in_editor(base_target: Node) -> Node:
	"""
	在编辑器环境下获取节点
	
	@param base_target: 基础目标节点
	@return: 节点实例
	"""
	var editor_interface = Engine.get_singleton("EditorInterface")
	if not editor_interface:
		return base_target.get_node(target)
	
	var edited_root = editor_interface.get_edited_scene_root()
	if not edited_root:
		return base_target.get_node(target)
	
	# 尝试直接获取节点
	var target_node = edited_root.get_node_or_null(target)
	if target_node:
		return target_node
	
	# 如果直接获取失败，尝试组合绝对路径
	var target_str = str(target)
	if target_str.begins_with("../"):
		var root_path = str(edited_root.get_path())

		target_node = edited_root.get_node(_get_absolute_path(target_str, root_path))
	
	return target_node if target_node else base_target

func _get_absolute_path(relative_path: String, root_path: String) -> String:
	# 处理以 "../" 开头的相对路径
	if relative_path.begins_with("../"):
		relative_path = relative_path.substr(3)  # 移除 "../"
		var absolute_path = root_path + "/" + relative_path
		return absolute_path
	# 处理简单的相对路径（如 "TestSprite"）
	else:
		# 直接从根节点访问
		return root_path + "/" + relative_path
