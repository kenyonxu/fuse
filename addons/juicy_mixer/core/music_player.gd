@tool
class_name MusicPlayer
extends Node

## 音乐播放器（逻辑层）
##
## 负责管理游戏音乐的状态优先级和切换逻辑
## 通过优先级堆栈系统决定"播什么"
## 调用 MusicManager 执行实际的播放操作
##
## 使用方法：
## 1. 在场景中添加 MusicPlayer 节点
## 2. 配置 state_map 资源
## 3. 调用 push_state/pop_state/switch_state

# =============================================================================
# 常量定义
# =============================================================================

## 音乐优先级枚举
enum Priority {
	GLOBAL = 0,      ## 全局/默认音乐（菜单、标题）
	EXPLORING = 1,   ## 探索音乐
	COMBAT = 2,      ## 战斗音乐
	BOSS = 3,        ## Boss战音乐
	EVENT = 4        ## 特殊事件/临时音乐
}

const MUSIC_PLAYER_GROUP: StringName = &"music_player"
const DEFAULT_FADE_TIME: float = 2.0

# =============================================================================
# 导出配置
# =============================================================================

@export_group("Configuration", "config_")

## 状态映射资源（定义状态到音乐轨道的映射）
@export var state_map: MusicStateMap = null:
	set(value):
		state_map = value
		# 当 state_map 改变时，刷新 Inspector 以显示/隐藏按钮
		if Engine.is_editor_hint():
			notify_property_list_changed()

## 优先级配置资源（定义可自定义的优先级列表）
@export var priority_config: MusicPriorityConfig = null

## 默认淡入淡出时间（秒）
@export_range(0.0, 10.0, 0.1) var default_fade_time: float = DEFAULT_FADE_TIME

## 是否启用调试日志
@export var enable_debug_logging: bool = false

# =============================================================================
# 内部数据结构
# =============================================================================

## 堆栈项：记录一个活跃的音乐状态
class MusicStackItem:
	var priority: int              ## 优先级
	var state_name: StringName      ## 状态名称
	var track: MusicTrackResource   ## 音乐轨道资源
	var timestamp: float            ## 添加时间戳

	func _init(p: int, s: StringName, t: MusicTrackResource):
		priority = p
		state_name = s
		track = t
		timestamp = Time.get_unix_time_from_system()

	func _to_string() -> String:
		return "MusicStackItem(%s, priority=%d)" % [state_name, priority]

# =============================================================================
# 内部状态
# =============================================================================

var _stack: Array[MusicStackItem] = []        ## 优先级堆栈
var _current_state: StringName = &""           ## 当前播放的状态
var _current_priority: int = -1                ## 当前状态的优先级
var _music_manager: MusicManager = null        ## MusicManager 引用
var _active_states: Dictionary = {}             ## 活跃音乐状态字典（{StringName: String (track_id)}）

# =============================================================================
# 信号
# =============================================================================

## 状态切换信号
signal state_changed(old_state: StringName, new_state: StringName, track: MusicTrackResource)
## 状态压入堆栈信号
signal state_pushed(state: StringName, priority: int)
## 状态从堆栈弹出信号
signal state_popped(state: StringName)

# =============================================================================
# 生命周期
# =============================================================================

func _ready():
	# 在编辑器中跳过运行时初始化
	if Engine.is_editor_hint():
		return

	# 添加到全局组，方便全局访问
	add_to_group(MUSIC_PLAYER_GROUP)

	# 获取 MusicManager 引用
	_music_manager = MusicManager.get_instance()
	if not _music_manager:
		push_error("[MusicPlayer] 未找到 MusicManager 节点")
		return

	if enable_debug_logging:
		print("[MusicPlayer] 初始化完成")
		print("[MusicPlayer]   - 状态映射: ", state_map)
		print("[MusicPlayer]   - 默认淡入淡出: ", default_fade_time, "秒")

func _exit_tree():
	# 清理堆栈
	_stack.clear()

# =============================================================================
# 核心 API
# =============================================================================

## 压入状态到堆栈
func push_state(state: StringName, priority: int = Priority.EXPLORING, fade_time: float = -1.0) -> bool:
	"""
	压入一个新的音乐状态到堆栈（使用优先级数值）

	@param state: 状态名称（必须在 state_map 中定义）
	@param priority: 优先级数值
	@param fade_time: 淡入淡出时间（-1 使用默认值）
	@return: 是否成功压入
	"""
	if not _validate_ready():
		return false

	# 从状态映射获取音乐轨道
	var track := _get_track_from_state(state)
	if not track:
		push_error("[MusicPlayer] 无法找到状态 '%s' 的音乐轨道" % state)
		return false

	# 处理默认淡入淡出时间
	var actual_fade_time: float = fade_time if fade_time >= 0 else default_fade_time

	# 创建堆栈项
	var item := MusicStackItem.new(priority, state, track)

	# 检查是否已经存在相同状态
	var existing_index := _find_state_index(state)
	if existing_index >= 0:
		# 已存在，更新优先级并移到堆栈顶部
		_stack.remove_at(existing_index)
		_stack.append(item)

		if enable_debug_logging:
			print("[MusicPlayer] 更新状态: %s (优先级 %d)" % [state, priority])
	else:
		# 新状态，添加到堆栈
		_stack.append(item)

		if enable_debug_logging:
			print("[MusicPlayer] 压入状态: %s (优先级 %d)" % [state, priority])

	state_pushed.emit(state, priority)

	# 更新播放（如果优先级更高）
	_update_top_priority(actual_fade_time)

	return true

## 压入状态到堆栈（使用优先级名称）
func push_state_by_name(state: StringName, priority_name: StringName, fade_time: float = -1.0) -> bool:
	"""
	压入一个新的音乐状态到堆栈（使用优先级名称）

	@param state: 状态名称（必须在 state_map 中定义）
	@param priority_name: 优先级名称（必须在 priority_config 中定义）
	@param fade_time: 淡入淡出时间（-1 使用默认值）
	@return: 是否成功压入
	"""
	# 解析优先级名称到数值
	var priority_value := _resolve_priority(priority_name)
	if priority_value < 0:
		push_error("[MusicPlayer] 无法找到优先级名称: %s" % priority_name)
		return false

	if enable_debug_logging:
		print("[MusicPlayer] 解析优先级: %s → %d" % [priority_name, priority_value])

	# 调用原有的 push_state
	return push_state(state, priority_value, fade_time)

## 从堆栈弹出状态
func pop_state(state: StringName, fade_time: float = -1.0) -> bool:
	"""
	从堆栈弹出一个音乐状态

	@param state: 要弹出的状态名称
	@param fade_time: 淡入淡出时间（-1 使用默认值）
	@return: 是否成功弹出
	"""
	if not _validate_ready():
		return false

	var index := _find_state_index(state)
	if index < 0:
		push_warning("[MusicPlayer] 堆栈中不存在状态: %s" % state)
		return false

	# 移除堆栈项
	_stack.remove_at(index)

	if enable_debug_logging:
		print("[MusicPlayer] 弹出状态: %s" % state)

	state_popped.emit(state)

	# 处理默认淡入淡出时间
	var actual_fade_time: float = fade_time if fade_time >= 0 else default_fade_time

	# 更新播放（回退到下一个最高优先级）
	_update_top_priority(actual_fade_time)

	return true

## 切换到指定状态（覆盖当前）
func switch_state(state: StringName, priority: int = Priority.EXPLORING, fade_time: float = -1.0) -> bool:
	"""
	切换到指定状态（清空堆栈并压入新状态）

	@param state: 目标状态名称
	@param priority: 优先级
	@param fade_time: 淡入淡出时间
	@return: 是否成功切换
	"""
	if enable_debug_logging:
		print("[MusicPlayer] 切换状态: %s (清空堆栈)" % state)

	# 清空堆栈
	_stack.clear()

	# 压入新状态
	return push_state(state, priority, fade_time)

## 强制停止所有音乐
func stop_all(fade_time: float = -1.0) -> void:
	"""
	停止所有音乐并清空堆栈

	@param fade_time: 淡出时间
	"""
	if not _validate_ready():
		return

	var actual_fade_time: float = fade_time if fade_time >= 0 else default_fade_time

	# 清空堆栈
	_stack.clear()

	# 停止音乐
	_music_manager.stop_music(actual_fade_time)

	_current_state = &""
	_current_priority = -1

	if enable_debug_logging:
		print("[MusicPlayer] 停止所有音乐")

# =============================================================================
# 内部逻辑
# =============================================================================

## 更新最高优先级状态的播放
func _update_top_priority(fade_time: float) -> void:
	"""
	根据堆栈更新当前应该播放的音乐

	@param fade_time: 淡入淡出时间
	"""
	if _stack.is_empty():
		# 堆栈为空，停止所有音乐并清空状态
		_clear_all_states(fade_time)
		return

	# 找到最高优先级的状态
	var top_item := _get_top_priority_item()
	if not top_item:
		return

	# 检查是否需要切换
	if top_item.state_name != _current_state:
		var old_state := _current_state
		_current_state = top_item.state_name
		_current_priority = top_item.priority

		# 挂起旧状态（如果不是当前状态，则不做任何事）
		if old_state != &"" and old_state in _active_states:
			_suspend_state(old_state, fade_time)

		# 激活新状态
		_activate_state(top_item, fade_time)

		state_changed.emit(old_state, _current_state, top_item.track)

		if enable_debug_logging:
			print("[MusicPlayer] 切换到状态: %s (优先级 %d)" % [_current_state, _current_priority])

## 获取最高优先级的堆栈项
func _get_top_priority_item() -> MusicStackItem:
	"""
	从堆栈中获取最高优先级的项

	@return: 最高优先级的 MusicStackItem，如果堆栈为空返回 null
	"""
	if _stack.is_empty():
		return null

	var top_item: MusicStackItem = _stack[0]

	for i in range(1, _stack.size()):
		var item: MusicStackItem = _stack[i]
		if item.priority > top_item.priority:
			top_item = item

	return top_item

## 查找状态在堆栈中的索引
func _find_state_index(state: StringName) -> int:
	"""
	查找指定状态在堆栈中的索引

	@param state: 状态名称
	@return: 索引，如果未找到返回 -1
	"""
	for i in range(_stack.size()):
		if _stack[i].state_name == state:
			return i
	return -1

## 从状态映射获取音乐轨道
func _get_track_from_state(state: StringName) -> MusicTrackResource:
	"""
	从状态映射中获取指定状态的音乐轨道

	@param state: 状态名称
	@return: 对应的 MusicTrackResource，如果不存在返回 null
	"""
	if not state_map:
		push_error("[MusicPlayer] state_map 未配置")
		return null

	return state_map.get_track(state)

## 解析优先级名称到数值
func _resolve_priority(priority_name: StringName) -> int:
	"""
	从 priority_config 解析优先级名称到数值

	@param priority_name: 优先级名称
	@return: 优先级数值，如果未找到返回 -1
	"""
	# 如果配置了 priority_config，从配置中查找
	if priority_config:
		var value = priority_config.get_priority_value(priority_name)
		if value >= 0:
			return value
		else:
			push_warning("[MusicPlayer] priority_config 中未找到: %s，尝试使用枚举" % priority_name)

	# 回退到枚举值（保持向后兼容）
	match priority_name:
		&"global":
			return Priority.GLOBAL
		&"exploring":
			return Priority.EXPLORING
		&"combat":
			return Priority.COMBAT
		&"boss":
			return Priority.BOSS
		&"event":
			return Priority.EVENT
		_:
			push_error("[MusicPlayer] 未知的优先级名称: %s" % priority_name)
			return -1

## 验证是否已准备好
func _validate_ready() -> bool:
	"""验证 MusicPlayer 是否已准备好"""
	if not _music_manager:
		push_error("[MusicPlayer] MusicManager 未初始化")
		return false

	if not state_map:
		push_error("[MusicPlayer] state_map 未配置")
		return false

	# priority_config 是可选的
	if not priority_config:
		if enable_debug_logging:
			print("[MusicPlayer] 未配置 priority_config，使用默认枚举")

	return true

# =============================================================================
# 查询 API
# =============================================================================

## 获取当前状态
func get_current_state() -> StringName:
	"""获取当前播放的状态名称"""
	return _current_state

## 获取当前优先级
func get_current_priority() -> int:
	"""获取当前状态的优先级"""
	return _current_priority

## 获取堆栈大小
func get_stack_size() -> int:
	"""获取当前堆栈中的状态数量"""
	return _stack.size()

## 检查状态是否在堆栈中
func is_state_active(state: StringName) -> bool:
	"""检查指定状态是否在堆栈中"""
	return _find_state_index(state) >= 0

## 获取堆栈信息（调试用）
func get_stack_info() -> String:
	"""获取当前堆栈的详细信息（调试用）"""
	if _stack.is_empty():
		return "堆栈为空"

	var info: String = ""
	info += "当前堆栈 (%d 个状态):\n" % _stack.size()

	# 按优先级排序显示
	var sorted_stack := _stack.duplicate()
	sorted_stack.sort_custom(func(a, b): return a.priority > b.priority)

	for item in sorted_stack:
		var current_marker = " ← 当前" if item.state_name == _current_state else ""
		info += "  [%d] %s (优先级 %d)%s\n" % [item.priority, item.state_name, item.priority, current_marker]

	return info

# =============================================================================
# 全局访问辅助方法
# =============================================================================

## 获取场景树中的第一个 MusicPlayer
static func get_instance(node: Node) -> MusicPlayer:
	"""
	从指定节点的场景树中获取 MusicPlayer 实例

	@param node: 场景树中的任意节点
	@return: MusicPlayer 实例，如果未找到返回 null
	"""
	if not node or not is_instance_valid(node):
		return null

	var tree := node.get_tree()
	if not tree:
		return null

	return tree.get_first_node_in_group(MUSIC_PLAYER_GROUP) as MusicPlayer

## 从场景树加载并播放状态（便捷方法）
static func play_state(node: Node, state: StringName, priority: int = Priority.EXPLORING, fade_time: float = -1.0) -> bool:
	"""
	便捷方法：从场景树获取 MusicPlayer 并播放指定状态

	@param node: 场景树中的任意节点
	@param state: 状态名称
	@param priority: 优先级
	@param fade_time: 淡入淡出时间
	@return: 是否成功
	"""
	var player := get_instance(node)
	if not player:
		push_error("[MusicPlayer] 未找到 MusicPlayer 实例")
		return false

	return player.push_state(state, priority, fade_time)

# =============================================================================
# 调试
# =============================================================================

func _to_string() -> String:
	return "MusicPlayer(state=%s, priority=%d, stack_size=%d)" % [_current_state, _current_priority, _stack.size()]

# =============================================================================
# 编辑器扩展
# =============================================================================

## 动态属性列表（添加 Inspector 按钮）
func _get_property_list() -> Array[Dictionary]:
	"""添加自定义按钮到 Inspector"""
	var properties: Array[Dictionary] = []

	# 只有在编辑器中且配置了 state_map 时才显示按钮
	if Engine.is_editor_hint() and state_map:
		properties.append({
			"name": "create_priority_from_states",
			"class_name": "",
			"type": TYPE_BOOL,
			"usage": PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_SCRIPT_VARIABLE,
			"hint": PROPERTY_HINT_NONE,
			"hint_string": ""
		})

	return properties

## 属性设置器（处理按钮点击）
func _set(property: StringName, value: Variant) -> bool:
	"""处理属性设置，特别是按钮点击"""
	if property == &"create_priority_from_states" and value:
		_create_priority_config_from_state_map()
		# 触发 Inspector 刷新
		notify_property_list_changed()
		return true
	return false

## 根据 state_map 创建优先级配置
func _create_priority_config_from_state_map() -> void:
	"""
	从当前 state_map 的键创建 priority_config

	自动为每个状态创建优先级条目，优先级按顺序递增
	"""
	if not state_map:
		push_error("[MusicPlayer] 无法创建优先级配置：state_map 未配置")
		return

	# 创建新的优先级配置
	var config := MusicPriorityConfig.new()
	var priority_value: int = 0

	# 获取 state_map 中的所有状态键
	var state_keys: Array = state_map.state_map.keys()

	if state_keys.is_empty():
		push_warning("[MusicPlayer] state_map 中没有状态键")
		return

	# 为每个状态创建优先级条目
	for state_key in state_keys:
		var state_name: StringName = StringName(state_key)
		var description: String = "优先级 %d - %s" % [priority_value, state_name]

		var entry := MusicPriorityEntry.new(state_name, priority_value, description)
		config.priorities.append(entry)

		priority_value += 1

	# 应用到 MusicPlayer
	priority_config = config

	# 通知属性变化
	notify_property_list_changed()

	# 输出日志
	print("[MusicPlayer] ✓ 已从 state_map 创建优先级配置（%d 个状态）" % config.priorities.size())
	print("[MusicPlayer] 创建的优先级列表：")
	for entry in config.priorities:
		print("  - [%d] %s: %s" % [entry.value, entry.name, entry.description])

# =============================================================================
# 状态管理辅助方法（用于支持中断处理）
# =============================================================================

## 清空所有状态
func _clear_all_states(fade_time: float) -> void:
	"""停止并清空所有活跃状态"""
	for state_name in _active_states.keys():
		var track_id: String = _active_states[state_name]
		var state: ActiveMusicState = _music_manager.get_active_state(track_id)
		if state and state.current_stream_player:
			_music_manager.stop_music(fade_time)
		_active_states.erase(state_name)

	_current_state = &""
	_current_priority = -1

	if enable_debug_logging:
		print("[MusicPlayer] 清空所有活跃状态")

## 挂起状态
func _suspend_state(state_name: StringName, fade_time: float) -> void:
	"""根据中断模式挂起指定状态"""
	if not state_name in _active_states:
		return

	var track_id: String = _active_states[state_name]
	var state: ActiveMusicState = _music_manager.get_active_state(track_id)
	if not state:
		return

	var track := state.track_resource
	var mode := track.interruption_mode

	match mode:
		MusicTrackResource.InterruptionMode.STOP_AND_RESTART:
			# 停止音乐
			_music_manager.stop_music_by_state(state, track.interruption_fade_out_time)

		MusicTrackResource.InterruptionMode.PAUSE_AND_RESUME:
			# 暂停音乐 - 使用专用的中断淡出时间
			_music_manager.pause_music(state, track.interruption_fade_out_time)

		MusicTrackResource.InterruptionMode.KEEP_PLAYING_SILENTLY:
			# 降低音量但不停止 - 使用专用的中断淡出时间
			_music_manager.duck_music(state, track.ducked_volume_db, track.interruption_fade_out_time)

	# 调用状态对象的 suspend 方法
	if state.current_stream_player:
		state.suspend(mode, state.current_stream_player)

## 激活状态
func _activate_state(item: MusicStackItem, fade_time: float) -> void:
	"""激活一个音乐状态（播放或恢复）"""
	# 检查是否已有挂起的状态
	if item.state_name in _active_states:
		# 恢复挂起的状态
		var track_id: String = _active_states[item.state_name]
		var state: ActiveMusicState = _music_manager.get_active_state(track_id)
		if state:
			_resume_state(state, fade_time)
	else:
		# 创建新状态并播放
		var track_id: String = _music_manager.play_music(item.track, fade_time)
		_active_states[item.state_name] = track_id

## 恢复状态
func _resume_state(state: ActiveMusicState, fade_time: float) -> void:
	"""恢复挂起的状态"""
	var mode: MusicTrackResource.InterruptionMode = state.resume()
	var track := state.track_resource

	match mode:
		MusicTrackResource.InterruptionMode.STOP_AND_RESTART:
			# 重新播放（从头开始） - 使用专用的中断淡入时间
			_music_manager.play_music(track, track.interruption_fade_in_time)

		MusicTrackResource.InterruptionMode.PAUSE_AND_RESUME:
			# 从暂停位置恢复 - 使用专用的中断淡入时间
			_music_manager.resume_music(state, track.interruption_fade_in_time)

		MusicTrackResource.InterruptionMode.KEEP_PLAYING_SILENTLY:
			# 恢复音量 - 使用专用的中断淡入时间
			_music_manager.unduck_music(state, state.original_volume_db, track.interruption_fade_in_time)
