# JuicyTimeScaleMiddleware - 时间缩放中间件
# 应用全局和局部时间缩放，支持时间组管理和动画系统
# 提供时间缩放统计和调试功能

class_name JuicyTimeScaleMiddleware
extends JuicyMiddleware

# 时间缩放配置
var global_time_scale: float = 1.0
var time_group_config: JuicyTimeGroupConfig  # 时间组配置资源
var time_group_animations: Dictionary = {}  # group_name -> animation_data

# 时间组动画数据
class TimeGroupAnimation:
	var from_scale: float
	var to_scale: float
	var duration: float
	var elapsed_time: float
	var ease_type: Tween.EaseType
	var callback: Callable
	var last_update_time: float = 0.0

func _init():
	middleware_name = "TimeScaleMiddleware"
	priority = 800  # 中等优先级
	description = "Applies time scaling to effects"

func process(context: JuicyContext, next: Callable) -> bool:
	"""应用时间缩放"""
	# 只保留时间缩放特定的验证逻辑 - 验证context是否存在
	if not context:
		# 没有上下文，跳过时间缩放处理但允许继续执行
		return next.call()
	
	var start_time = _start_execution_timer()
	
	# 应用全局时间缩放
	context.time_scale *= global_time_scale
	
	# 应用时间组缩放
	var time_group = ""
	if context.resource and context.resource.has_method("get_time_group"):
		time_group = context.resource.get_time_group()
	
	if not time_group.is_empty() and time_group_config and time_group_config.has_time_group(time_group):
		context.time_scale *= time_group_config.get_time_scale(time_group)
	
	# 更新时间组动画
	_update_time_group_animations()
	
	_end_execution_timer(start_time)
	return next.call()

# 时间缩放管理
func set_global_time_scale(scale: float) -> void:
	"""设置全局时间缩放"""
	global_time_scale = max(0.0, scale)
	_log_debug("Global time scale set", {"scale": global_time_scale})

func get_global_time_scale() -> float:
	"""获取全局时间缩放"""
	return global_time_scale

func set_time_group_scale(group_name: String, scale: float) -> void:
	"""设置时间组缩放"""
	if time_group_config:
		time_group_config.set_time_scale(group_name, scale)
		_log_debug("Time group scale set", {"group": group_name, "scale": scale})

func get_time_group_scale(group_name: String) -> float:
	"""获取时间组缩放"""
	if time_group_config:
		return time_group_config.get_time_scale(group_name)
	return 1.0

func remove_time_group(group_name: String) -> void:
	"""移除时间组"""
	if time_group_config:
		time_group_config.remove_time_group(group_name)
	time_group_animations.erase(group_name)
	_log_debug("Time group removed", {"group": group_name})

# 时间组配置管理
func set_time_group_config(config: JuicyTimeGroupConfig) -> void:
	"""设置时间组配置"""
	time_group_config = config
	_log_debug("Time group config set", {"config": config.config_name if config else "null"})

func get_time_group_config() -> JuicyTimeGroupConfig:
	"""获取时间组配置"""
	return time_group_config

func load_time_group_config(resource_path: String) -> JuicyTimeGroupConfig:
	"""从文件加载时间组配置"""
	if ResourceLoader.exists(resource_path):
		var config = load(resource_path) as JuicyTimeGroupConfig
		if config:
			time_group_config = config
			_log_debug("Time group config loaded", {"path": resource_path, "config": config.config_name})
		return config
	_log_warning("Time group config file not found", {"path": resource_path})
	return null

func save_time_group_config(config: JuicyTimeGroupConfig, resource_path: String) -> bool:
	"""保存时间组配置到文件"""
	time_group_config = config
	var result = ResourceSaver.save(config, resource_path) == OK
	if result:
		_log_debug("Time group config saved", {"path": resource_path, "config": config.config_name})
	else:
		_log_error("Failed to save time group config", {"path": resource_path})
	return result

# 时间组动画
func animate_time_group_scale(group_name: String, to_scale: float, duration: float,
						   ease_type: Tween.EaseType = Tween.EASE_IN_OUT,
						   callback: Callable = Callable()) -> void:
	"""动画时间组缩放"""
	var from_scale = get_time_group_scale(group_name)
	
	var animation = TimeGroupAnimation.new()
	animation.from_scale = from_scale
	animation.to_scale = to_scale
	animation.duration = duration
	animation.elapsed_time = 0.0
	animation.ease_type = ease_type
	animation.callback = callback
	
	time_group_animations[group_name] = animation
	_log_debug("Time group animation started", {
		"group": group_name,
		"from": from_scale,
		"to": to_scale,
		"duration": duration
	})

func stop_time_group_animation(group_name: String) -> void:
	"""停止时间组动画"""
	if time_group_animations.has(group_name):
		time_group_animations.erase(group_name)
		_log_debug("Time group animation stopped", {"group": group_name})

# 更新所有动画（用于测试和独立更新）
func update_animations() -> void:
	"""更新所有时间组动画"""
	_update_time_group_animations()

func _update_time_group_animations() -> void:
	"""更新时间组动画"""
	var groups_to_remove: Array[String] = []
	
	for group_name in time_group_animations.keys():
		var animation = time_group_animations[group_name]
		
		# 使用时间差计算，基于当前时间戳
		var current_time = Time.get_ticks_msec() / 1000.0
		var last_time = current_time
		if "last_update_time" in animation:
			last_time = animation.last_update_time
		else:
			animation.last_update_time = current_time
		
		var delta_time = current_time - last_time
		animation.elapsed_time += delta_time
		animation.last_update_time = current_time
		
		if animation.elapsed_time >= animation.duration:
			# 动画完成
			set_time_group_scale(group_name, animation.to_scale)
			groups_to_remove.append(group_name)
			
			# 调用回调
			if animation.callback.is_valid():
				animation.callback.call()
		else:
			# 计算当前值
			var progress = animation.elapsed_time / animation.duration
			progress = _apply_easing(progress, animation.ease_type)
			
			var current_scale = lerp(animation.from_scale, animation.to_scale, progress)
			set_time_group_scale(group_name, current_scale)
	
	# 移除完成的动画
	for group_name in groups_to_remove:
		time_group_animations.erase(group_name)

func _apply_easing(progress: float, ease_type: Tween.EaseType) -> float:
	"""应用缓动函数"""
	match ease_type:
		Tween.EASE_IN:
			return progress * progress
		Tween.EASE_OUT:
			return 1.0 - (1.0 - progress) * (1.0 - progress)
		Tween.EASE_IN_OUT:
			if progress < 0.5:
				return 2.0 * progress * progress
			else:
				return 1.0 - 2.0 * (1.0 - progress) * (1.0 - progress)
		_:
			return progress

# 统计和调试
func get_time_scale_stats() -> Dictionary:
	"""获取时间缩放统计"""
	var time_group_stats = {}
	if time_group_config:
		for group_name in time_group_config.get_time_group_names():
			time_group_stats[group_name] = {
				"time_scale": time_group_config.get_time_scale(group_name)
			}
	
	return {
		"global_time_scale": global_time_scale,
		"time_groups": time_group_stats,
		"active_animations": time_group_animations.size(),
		"animated_groups": time_group_animations.keys()
	}

func debug_print_time_scales() -> void:
	"""打印时间缩放信息"""
	print("=== JuicyMixer Time Scales ===")
	print("Global: ", global_time_scale)
	if time_group_config:
		print("Time Groups:")
		for group_name in time_group_config.get_time_group_names():
			print("  ", group_name, ": ", time_group_config.get_time_scale(group_name))
	
	if not time_group_animations.is_empty():
		print("Active Animations:")
		for group_name in time_group_animations.keys():
			var animation = time_group_animations[group_name]
			print("  ", group_name, ": ", animation.from_scale, " -> ", animation.to_scale,
				  " (", animation.elapsed_time, "/", animation.duration, ")")

# 生命周期方法
func cleanup(context: JuicyContext) -> void:
	"""清理阶段，在效果结束时调用"""
	_log_debug("Cleanup called", {"context_id": context.context_id if context else "null"})

func on_context_created(context: JuicyContext) -> void:
	"""上下文创建时调用"""
	_log_debug("Context created", {"context_id": context.context_id if context else "null"})

func on_context_destroyed(context: JuicyContext) -> void:
	"""上下文销毁时调用"""
	_log_debug("Context destroyed", {"context_id": context.context_id if context else "null"})

func on_context_paused(context: JuicyContext) -> void:
	"""上下文暂停时调用"""
	_log_debug("Context paused", {"context_id": context.context_id if context else "null"})

func on_context_resumed(context: JuicyContext) -> void:
	"""上下文恢复时调用"""
	_log_debug("Context resumed", {"context_id": context.context_id if context else "null"})

# 验证必需的Context数据 - 已移除
# 重复的验证逻辑由 ValidationMiddleware 统一处理
# 此中间件只在 process() 方法中保留时间缩放特定的验证

# 设置默认配置
func _setup_default_configuration() -> void:
	"""设置默认配置"""
	_default_configuration = {
		"enable_performance_monitoring": true,
		"enable_debug_logging": false,
		"priority": 800,
		"max_log_entries": 100,
		"global_time_scale": 1.0
	}
	
	# 设置配置模式
	set_configuration_schema({
		"enable_performance_monitoring": {"type": "bool"},
		"enable_debug_logging": {"type": "bool"},
		"priority": {"type": "int"},
		"max_log_entries": {"type": "int"},
		"global_time_scale": {"type": "float"}
	})
