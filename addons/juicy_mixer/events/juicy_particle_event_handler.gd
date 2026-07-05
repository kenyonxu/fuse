class_name JuicyParticleEventHandler
extends JuicyEventHandler

# 粒子系统池
var _particle_pool: Array[GPUParticles2D] = []
var _active_particles: Dictionary = {}  # particle_id -> particle_info
var _max_pool_size: int = 30
var _max_concurrent_systems: int = 15

# 粒子配置
var _particle_root: Node
var _auto_cleanup_time: float = 10.0

func _init():
	handler_name = "ParticleEventHandler"
	supported_events = [
		JuicyEvent.EventType.PARTICLE_SPAWN,
		JuicyEvent.EventType.PARTICLE_STOP
	]
	description = "Handles particle system events"

func handle_event(event: JuicyEvent) -> bool:
	"""处理粒子事件"""
	var start_time = _start_handling_timer()
	
	var success = false
	
	match event.event_type:
		JuicyEvent.EventType.PARTICLE_SPAWN:
			success = _handle_particle_spawn(event)
		JuicyEvent.EventType.PARTICLE_STOP:
			success = _handle_particle_stop(event)
		_:
			_log_warning("Unsupported event type: " + str(event.event_type))
	
	_end_handling_timer(start_time)
	
	if success:
		_record_success()
	else:
		_record_failure()
	
	return success

# 粒子生成处理
func _handle_particle_spawn(event: JuicyEvent) -> bool:
	"""处理粒子生成事件"""
	var particle_scene = event.event_data.get("particle_scene")
	var amount = event.event_data.get("amount", 10)
	var position = event.event_data.get("position", Vector2.ZERO)
	
	if not particle_scene:
		_log_error("Particle scene is null")
		return false
	
	# 检查并发限制
	if _active_particles.size() >= _max_concurrent_systems:
		_log_warning("Maximum concurrent particle systems reached, stopping oldest")
		_stop_oldest_particles()
	
	# 获取粒子系统
	var particles = _get_particle_system()
	if not particles:
		_log_error("Failed to get particle system")
		return false
	
	# 配置粒子系统
	_setup_particle_system(particles, particle_scene, amount, position)
	
	# 启动粒子系统
	particles.emitting = true
	
	# 记录活跃粒子系统
	var particle_id = particles.get_instance_id()
	_active_particles[particle_id] = {
		"particles": particles,
		"context_id": event.context_id,
		"event_id": event.event_id,
		"start_time": Time.get_ticks_msec() / 1000.0,
		"auto_cleanup_time": _auto_cleanup_time
	}
	
	return true

func _handle_particle_stop(event: JuicyEvent) -> bool:
	"""处理粒子停止事件"""
	var context_id = event.context_id
	var event_id = event.event_id
	
	var particles_to_stop: Array[GPUParticles2D] = []
	
	# 查找要停止的粒子系统
	for particle_id in _active_particles.keys():
		var particle_info = _active_particles[particle_id]
		if particle_info.context_id == context_id or particle_info.event_id == event_id:
			particles_to_stop.append(particle_info.particles)
	
	# 停止粒子系统
	for particles in particles_to_stop:
		_stop_particle_system(particles)
	
	return particles_to_stop.size() > 0

# 粒子系统管理
func _get_particle_system() -> GPUParticles2D:
	"""获取粒子系统"""
	# 从池中获取
	if not _particle_pool.is_empty():
		return _particle_pool.pop_back()
	
	# 创建新的粒子系统
	if _particle_pool.size() + _active_particles.size() < _max_pool_size:
		var particles = GPUParticles2D.new()
		_setup_particle_system_defaults(particles)
		return particles
	
	return null

func _setup_particle_system_defaults(particles: GPUParticles2D) -> void:
	"""设置粒子系统默认值"""
	particles.emitting = false
	particles.explosiveness = 0.0
	particles.amount = 50
	particles.lifetime = 2.0
	particles.one_shot = true
	
	# 添加到场景树
	var particle_root = _get_particle_root()
	particle_root.add_child(particles)

func _setup_particle_system(particles: GPUParticles2D, particle_scene: PackedScene, 
						   amount: int, position: Vector2) -> void:
	"""设置粒子系统参数"""
	particles.position = position
	particles.amount = amount
	
	# 如果有粒子场景，设置其属性
	if particle_scene:
		# 这里可以根据需要配置粒子场景
		pass

func _stop_particle_system(particles: GPUParticles2D) -> void:
	"""停止粒子系统"""
	if not particles or not is_instance_valid(particles):
		return
	
	particles.emitting = false
	_return_particle_system(particles)

func _return_particle_system(particles: GPUParticles2D) -> void:
	"""归还粒子系统到池"""
	var particle_id = particles.get_instance_id()
	
	# 从活跃列表中移除
	_active_particles.erase(particle_id)
	
	# 重置粒子系统状态
	particles.emitting = false
	particles.position = Vector2.ZERO
	particles.amount = 50
	particles.lifetime = 2.0
	
	# 返回到池
	if _particle_pool.size() < _max_pool_size:
		_particle_pool.append(particles)
	else:
		particles.queue_free()

func _stop_oldest_particles() -> void:
	"""停止最老的粒子系统"""
	var oldest_time = INF
	var oldest_particle_id = -1
	
	for particle_id in _active_particles.keys():
		var particle_info = _active_particles[particle_id]
		if particle_info.start_time < oldest_time:
			oldest_time = particle_info.start_time
			oldest_particle_id = particle_id
	
	if oldest_particle_id != -1:
		var particle_info = _active_particles[oldest_particle_id]
		_stop_particle_system(particle_info.particles)

# 自动清理
func update_auto_cleanup(delta: float) -> void:
	"""更新自动清理"""
	var particles_to_cleanup: Array[GPUParticles2D] = []
	
	for particle_id in _active_particles.keys():
		var particle_info = _active_particles[particle_id]
		particle_info.auto_cleanup_time -= delta
		
		if particle_info.auto_cleanup_time <= 0.0:
			particles_to_cleanup.append(particle_info.particles)
	
	# 清理到期的粒子系统
	for particles in particles_to_cleanup:
		_stop_particle_system(particles)

# 工具方法
func _get_particle_root() -> Node:
	"""获取粒子根节点"""
	if not _particle_root:
		var scene_root = Engine.get_main_loop().current_scene
		_particle_root = Node.new()
		_particle_root.name = "JuicyParticleRoot"
		scene_root.add_child(_particle_root)
	
	return _particle_root

# 配置管理
func configure(config: Dictionary) -> void:
	super.configure(config)
	
	if config.has("max_pool_size"):
		_max_pool_size = config.max_pool_size
	
	if config.has("max_concurrent_systems"):
		_max_concurrent_systems = config.max_concurrent_systems
	
	if config.has("auto_cleanup_time"):
		_auto_cleanup_time = config.auto_cleanup_time

func get_configuration() -> Dictionary:
	var config = super.get_configuration()
	config["max_pool_size"] = _max_pool_size
	config["max_concurrent_systems"] = _max_concurrent_systems
	config["auto_cleanup_time"] = _auto_cleanup_time
	return config

# 统计和调试
func get_particle_stats() -> Dictionary:
	"""获取粒子统计信息"""
	return {
		"pool_size": _particle_pool.size(),
		"active_particles": _active_particles.size(),
		"max_pool_size": _max_pool_size,
		"max_concurrent_systems": _max_concurrent_systems
	}

func cleanup() -> void:
	"""清理粒子处理器"""
	# 停止所有活跃粒子系统
	for particle_id in _active_particles.keys():
		var particle_info = _active_particles[particle_id]
		_stop_particle_system(particle_info.particles)
	
	# 清空粒子系统池
	for particles in _particle_pool:
		if is_instance_valid(particles):
			particles.queue_free()
	_particle_pool.clear()
