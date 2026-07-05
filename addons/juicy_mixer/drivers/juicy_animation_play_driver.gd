# JuicyAnimationPlayDriver - 动画播放驱动器
# 实现动画播放控制，支持多种播放模式和状态还原
# 处理动画序列播放和完成动作执行

class_name JuicyAnimationPlayDriver
extends JuicyDriver

# =============================================================================
# 动画播放状态类
# =============================================================================

class AnimationPlayState:
	var animation_player: AnimationPlayer = null
	var animation_data: Object = null
	var start_time: float = 0.0
	var is_playing: bool = false
	var is_completed: bool = false
	var blend_start_time: float = 0.0
	var is_blending_in: bool = false
	var is_blending_out: bool = false
	var end_at: float = 1.0  # 停止位置比例
	
	func _init(player: AnimationPlayer, data: Object):
		animation_player = player
		animation_data = data

# =============================================================================
# 属性配置
# =============================================================================

var animation_states: Dictionary = {}  # context_id -> [AnimationPlayState]
var current_animation_index: Dictionary = {}  # context_id -> int

# =============================================================================
# 生命周期管理
# =============================================================================

func _init():
	"""
	初始化动画播放驱动器
	设置驱动器名称和支持的属性列表
	"""
	driver_name = "JuicyAnimationPlayDriver"
	supported_properties = []  # 不直接处理属性，通过AnimationPlayer控制
	required_context_data = ["animation_data"]

func prepare(context: JuicyContext, delta: float, buffer: JuicyPropertyBuffer) -> void:
	"""
	准备动画播放数据，在效果开始前调用一次
	
	@param context: JuicyContext实例，包含效果运行所需的所有数据
	@param delta: 时间增量（秒）
	@param buffer: JuicyPropertyBuffer实例，用于写入属性值
	"""
	# 从Context中的Resource获取动画数据
	var animation_resource = context.resource
	if not animation_resource or not "animation_data" in animation_resource:
		push_warning("Invalid animation resource in context")
		context.complete()
		return
	
	var animation_data_array = animation_resource.animation_data
	if animation_data_array.is_empty():
		push_warning("No animation data found in resource")
		context.complete()
		return
	
	# 检查完成动作类型，优化状态快照策略
	var completion_action = _get_completion_action(context)
	if completion_action == AnimationPlayData.OnCompleteAction.KEEP_LAST_FRAME:
		# KEEP_LAST_FRAME模式：跳过状态快照以提高性能
		_skip_state_snapshot(context)
		print("AnimationPlayDriver: Skipping state snapshot for KEEP_LAST_FRAME mode")
	elif completion_action == AnimationPlayData.OnCompleteAction.RESTORE_STATE:
		# RESTORE_STATE模式：需要状态快照
		_ensure_state_snapshot(context)
		print("AnimationPlayDriver: Ensuring state snapshot for RESTORE_STATE mode")
	elif completion_action == AnimationPlayData.OnCompleteAction.RESET_TRACKS:
		# RESET_TRACKS模式：使用Godot的Reset轨道，不需要快照
		_skip_state_snapshot(context)
		print("AnimationPlayDriver: Using Reset tracks for RESET_TRACKS mode")
	
	# 初始化动画播放状态
	_initialize_animation_states(context, animation_data_array)
	
	# 使用基类时间管理
	_initialize_driver_time(context)
	
	# 开始播放第一个动画
	current_animation_index[context.context_id] = 0
	_start_current_animation(context)

func process(context: JuicyContext, delta: float, buffer: JuicyPropertyBuffer) -> void:
	"""
	处理动画播放，每帧调用
	
	@param context: JuicyContext实例，包含效果运行所需的所有数据
	@param delta: 时间增量（秒）
	@param buffer: JuicyPropertyBuffer实例，用于写入属性值
	"""
	var start_time = _start_execution_timer()
	
	# 使用基类时间管理
	var effective_delta = _update_driver_time(context, delta)
	
	# 获取当前动画状态
	var states = animation_states.get(context.context_id, [])
	var current_index = current_animation_index.get(context.context_id, 0)
	
	if current_index >= states.size():
		context.complete()
		_end_execution_timer(start_time)
		return
	
	var current_state = states[current_index]
	if not current_state:
		push_error("Invalid animation state at index %d" % current_index)
		_move_to_next_animation(context)
		_end_execution_timer(start_time)
		return
	
	# 处理当前动画
	_process_animation(context, current_state, effective_delta)
	
	# 检查当前动画是否完成
	if current_state.is_completed:
		_move_to_next_animation(context)
	
	_end_execution_timer(start_time)

func cleanup(context: JuicyContext) -> void:
	"""
	清理动画播放数据，在效果结束时调用
	
	@param context: JuicyContext实例，包含效果运行所需的所有数据
	"""
	# 根据完成动作类型执行不同的清理策略
	var completion_action = _get_completion_action(context)
	
	match completion_action:
		AnimationPlayData.OnCompleteAction.RESTORE_STATE:
			# RESTORE_STATE: 依赖StateRestorationMiddleware自动还原
			print("AnimationPlayDriver: State restoration will be handled by middleware")
			
		AnimationPlayData.OnCompleteAction.KEEP_LAST_FRAME:
			# KEEP_LAST_FRAME: 保持最后一帧，不需要特殊处理
			print("AnimationPlayDriver: Keeping last frame")
			
		AnimationPlayData.OnCompleteAction.RESET_TRACKS:
			# RESET_TRACKS: 使用Godot的Reset轨道还原
			_reset_to_initial_tracks(context)
			print("AnimationPlayDriver: Reset to initial tracks")
	
	# 停止所有正在播放的动画
	var states = animation_states.get(context.context_id, [])
	for state in states:
		if state and state.animation_player and state.is_playing:
			state.animation_player.stop()
	
	# 清理状态
	animation_states.erase(context.context_id)
	current_animation_index.erase(context.context_id)
	
	# 清理基类时间状态
	_cleanup_driver_time(context)

# =============================================================================
# 内部实现 - 初始化
# =============================================================================

func _initialize_animation_states(context: JuicyContext, animation_data_array: Array) -> void:
	"""
	初始化动画播放状态
	
	@param context: JuicyContext实例
	@param animation_data_array: 动画数据数组
	"""
	var states = []
	
	for data in animation_data_array:
		if not data:
			continue
		
		# 获取AnimationPlayer
		var player = _get_animation_player_from_data(data, context.target)
		if not player:
			push_warning("Failed to get AnimationPlayer for: " + str(data.target if "target" in data else "unknown"))
			continue
		
		# 创建播放状态
		var state = AnimationPlayState.new(player, data)
		states.append(state)
	
	animation_states[context.context_id] = states

func _get_animation_player_from_data(data: Object, context_node: Node) -> AnimationPlayer:
	"""
	从动画数据获取AnimationPlayer
	
	@param data: 动画数据对象
	@param context_node: 上下文节点
	@return: AnimationPlayer实例，如果未找到则返回null
	"""
	if not data or not "target" in data:
		return null
	
	var target_path = data.target
	if not target_path or target_path.is_empty():
		return null
	
	# 解析目标节点
	var target_node = context_node.get_node(target_path)
	if not target_node:
		push_warning("AnimationPlayData: Target node not found: " + str(target_path))
		return null
	
	# 尝试通过get_animation_player()方法获取
	if target_node.has_method("get_animation_player"):
		var player = target_node.get_animation_player()
		if player and player is AnimationPlayer:
			return player
	
	# 尝试通过递归查找子AnimationPlayer
	var player = _find_child_animation_player(target_node)
	if player:
		return player
	
	push_warning("AnimationPlayData: AnimationPlayer not found for target: " + str(target_path))
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
# 内部实现 - 动画播放控制
# =============================================================================

func _start_current_animation(context: JuicyContext) -> void:
	"""
	开始播放当前动画
	
	@param context: JuicyContext实例
	"""
	var current_index = current_animation_index.get(context.context_id, 0)
	var states = animation_states.get(context.context_id, [])
	
	if current_index >= states.size():
		return
	
	var state = states[current_index]
	if not state:
		return
	
	var data = state.animation_data
	var player = state.animation_player
	
	# 根据播放模式选择播放方法
	match data.play_mode if "play_mode" in data else 0:  # 默认NORMAL模式
		0:  # NORMAL
			_play_animation_normal(state, context)
		1:  # SYNC
			_play_animation_sync(state, context)

func _play_animation_normal(state: AnimationPlayState, context: JuicyContext) -> void:
	"""
	使用NORMAL模式播放动画
	
	@param state: 动画播放状态
	@param context: JuicyContext实例
	"""
	var data = state.animation_data
	var player = state.animation_player
	
	# 连接动画完成信号
	if not player.animation_finished.is_connected(_on_animation_finished):
		player.animation_finished.connect(_on_animation_finished.bind(context.context_id))
	
	# 设置混入时间
	if "blend_in_time" in data and data.blend_in_time > 0:
		state.is_blending_in = true
		state.blend_start_time = Time.get_ticks_msec() / 1000.0
	
	# 获取动画名称
	var anim_name = data.target_animation if "target_animation" in data else ""
	if anim_name.is_empty():
		push_warning("Animation name is empty")
		state.is_completed = true
		return
	
	# 获取 end_at 参数
	state.end_at = data.end_at if "end_at" in data else 1.0
	
	# 播放动画
	player.play(anim_name, data.blend_in_time if "blend_in_time" in data else 0.0)
	state.start_time = Time.get_ticks_msec() / 1000.0
	state.is_playing = true
	state.is_completed = false
	
	print("Playing animation normally: ", anim_name, " (target length:", state.normal_target_length, "s, end_at:", state.end_at, ")")

func _play_animation_sync(state: AnimationPlayState, context: JuicyContext) -> void:
	"""
	使用SYNC模式播放动画 - 响应context.time_scale变化
	
	@param state: 动画播放状态
	@param context: JuicyContext实例
	"""
	var data = state.animation_data
	var player = state.animation_player
	
	# 设置混入时间
	if "blend_in_time" in data and data.blend_in_time > 0:
		state.is_blending_in = true
		state.blend_start_time = Time.get_ticks_msec() / 1000.0
	
	# 获取动画名称
	var anim_name = data.target_animation if "target_animation" in data else ""
	if anim_name.is_empty():
		push_warning("Animation name is empty")
		state.is_completed = true
		return
	
	# 获取动画长度
	var anim_length = _get_animation_length(data, context.target)
	var end_at = data.end_at if "end_at" in data else 1.0
	
	print("DEBUG: SYNC模式初始化 - anim_length:", anim_length, "end_at:", end_at)
	
	# 像NORMAL模式一样播放动画，但通过实时更新speed_scale来响应time_scale变化
	player.play(anim_name, data.blend_in_time if "blend_in_time" in data else 0.0)
	
	state.start_time = Time.get_ticks_msec() / 1000.0
	state.is_playing = true
	state.is_completed = false
	
	print("Playing animation in sync mode: ", anim_name, " (end_at:", end_at, ")")

func _process_animation(context: JuicyContext, state: AnimationPlayState, effective_delta: float) -> void:
	"""
	处理动画播放逻辑 - 使用 Godot 原生 API 简化进度检测，保留 SYNC 模式 time_scale 支持
	
	@param context: JuicyContext实例
	@param state: 动画播放状态
	@param effective_delta: 有效时间增量
	"""
	var data = state.animation_data
	var player = state.animation_player
	
	# 使用 Godot 原生 API 获取当前动画状态
	var current_pos = player.current_animation_position
	var anim_length = player.current_animation_length
	
	# 计算 end_at 目标位置
	var end_at = data.end_at if "end_at" in data else 1.0
	var target_position = anim_length * end_at
	
	# 简单直接的进度检测 - 适用于所有模式
	if current_pos >= target_position:
		state.is_completed = true
		print("动画完成：当前位置", current_pos, "目标位置", target_position)
	
	# 处理SYNC模式的time_scale响应 - 保留关键功能
	if "play_mode" in data and data.play_mode == 1:  # SYNC模式
		# 关键修复：实时更新AnimationPlayer的speed_scale来响应context.time_scale变化
		var base_speed_scale = 1.0  # 正常播放速度
		var time_scale = context.time_scale if context and "time_scale" in context else 1.0
		var target_speed_scale = base_speed_scale * time_scale
		
		# 应用speed_scale，让AnimationPlayer自动响应time_scale变化
		player.speed_scale = target_speed_scale
		
		# 只在关键节点输出调试信息
		if Engine.get_frames_drawn() % 60 == 0:  # 每秒输出一次
			print("SYNC模式进度 - 当前位置:", current_pos, "目标位置:", target_position, "time_scale:", time_scale, "completed:", state.is_completed)
	
	# 处理混入效果（保持现有逻辑）
	if state.is_blending_in:
		var blend_elapsed = (Time.get_ticks_msec() / 1000.0) - state.blend_start_time
		var blend_in_time = data.blend_in_time if "blend_in_time" in data else 0.0
		if blend_elapsed >= blend_in_time:
			state.is_blending_in = false

func _get_animation_length(data: Object, context_node: Node) -> float:
	"""
	获取动画长度
	
	@param data: 动画数据
	@param context_node: 上下文节点
	@return: 动画长度（秒）
	"""
	if not data or not "target_animation" in data:
		return 1.0
	
	var anim_name = data.target_animation
	if anim_name.is_empty():
		return 1.0
	
	# 尝试从AnimationPlayer获取动画长度
	var player = _get_animation_player_from_data(data, context_node)
	if not player:
		return 1.0
	
	var animation = player.get_animation(anim_name)
	if not animation:
		push_warning("Animation not found: " + anim_name)
		return 1.0
	
	return animation.length

func _move_to_next_animation(context: JuicyContext) -> void:
	"""
	移动到下一个动画
	
	@param context: JuicyContext实例
	"""
	var current_index = current_animation_index.get(context.context_id, 0)
	var states = animation_states.get(context.context_id, [])
	var animation_resource = context.resource
	
	current_index += 1
	
	# 检查是否还有更多动画
	if current_index < states.size():
		current_animation_index[context.context_id] = current_index
		_start_current_animation(context)
	else:
		# 检查是否需要循环
		if animation_resource and "loop" in animation_resource and animation_resource.loop:
			# 处理循环延迟
			if "loop_delay" in animation_resource and animation_resource.loop_delay > 0:
				# 这里可以添加延迟逻辑
				pass
			
			# 重置到第一个动画
			current_animation_index[context.context_id] = 0
			_reset_animation_states(context)
			_start_current_animation(context)
		else:
			# 序列完成
			context.complete()

func _reset_animation_states(context: JuicyContext) -> void:
	"""
	重置所有动画状态，用于循环播放
	
	@param context: JuicyContext实例
	"""
	var states = animation_states.get(context.context_id, [])
	for state in states:
		if state:
			state.start_time = 0.0
			state.current_time = 0.0
			state.is_playing = false
			state.is_completed = false
			state.is_blending_in = false
			state.is_blending_out = false
			state.end_at = 1.0

# =============================================================================
# 事件处理
# =============================================================================

func _on_animation_finished(context_id: String, anim_name: StringName) -> void:
	"""
	处理动画完成事件
	
	@param context_id: 上下文ID
	@param anim_name: 完成的动画名称
	"""
	var states = animation_states.get(context_id, [])
	var current_index = current_animation_index.get(context_id, 0)
	
	if current_index < states.size():
		var state = states[current_index]
		if state and state.animation_data and "target_animation" in state.animation_data:
			if state.animation_data.target_animation == anim_name:
				state.is_completed = true

# =============================================================================
# 验证接口实现
# =============================================================================

func validate_context(context: JuicyContext) -> Dictionary:
	"""
	验证Context是否适合此Driver
	
	@param context: 要验证的JuicyContext实例
	@return: 验证结果字典
	"""
	var result = super.validate_context(context)
	
	# 检查动画数据
	var animation_data = null
	if context and context.resource and "animation_data" in context.resource:
		animation_data = context.resource.animation_data
	
	if animation_data == null:
		result.valid = false
		result.issues.append("Missing animation data in context")
	elif not animation_data is Array:
		result.valid = false
		result.issues.append("Animation data must be an array")
	elif animation_data.is_empty():
		result.valid = false
		result.issues.append("Animation data cannot be empty")
	
	return result

# =============================================================================
# 状态还原集成
# =============================================================================

func _get_completion_action(context: JuicyContext) -> int:
	"""
	获取完成动作类型
	
	@param context: JuicyContext实例
	@return: 完成动作枚举值
	"""
	if not context or not context.resource:
		return AnimationPlayData.OnCompleteAction.KEEP_LAST_FRAME  # 默认动作
	
	var resource = context.resource
	# 检查resource是否有animation_data属性
	if "animation_data" in resource and resource.animation_data.size() > 0:
		var first_data = resource.animation_data[0]
		if first_data and "on_complete_action" in first_data:
			return first_data.on_complete_action
	
	return AnimationPlayData.OnCompleteAction.KEEP_LAST_FRAME  # 默认动作

func _skip_state_snapshot(context: JuicyContext) -> void:
	"""
	跳过状态快照（用于KEEP_LAST_FRAME和RESET_TRACKS模式）
	
	@param context: JuicyContext实例
	"""
	# 设置上下文标志，告诉StateRestorationMiddleware跳过快照
	context.set_middleware_data("StateRestorationMiddleware", "skip_snapshot", true)
	context.set_middleware_data("StateRestorationMiddleware", "skip_reason", "optimized_for_keep_last_frame")

func _ensure_state_snapshot(context: JuicyContext) -> void:
	"""
	确保状态快照（用于RESTORE_STATE模式）
	
	@param context: JuicyContext实例
	"""
	# 设置上下文标志，告诉StateRestorationMiddleware确保快照
	context.set_middleware_data("StateRestorationMiddleware", "require_snapshot", true)
	context.set_middleware_data("StateRestorationMiddleware", "snapshot_priority", "high")

func _reset_to_initial_tracks(context: JuicyContext) -> void:
	"""
	使用Godot的Reset轨道还原到初始状态
	
	@param context: JuicyContext实例
	"""
	var states = animation_states.get(context.context_id, [])
	for state in states:
		if state and state.animation_player:
			var player = state.animation_player
			# 尝试使用Reset轨道
			if player.has_method("reset"):
				player.reset()
			else:
				# 如果没有reset方法，尝试停止并清除当前动画
				player.stop()
				player.clear_caches()
