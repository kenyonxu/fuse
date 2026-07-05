# 阶段4：事件系统实现计划

## 概述

**时间范围**：第9-10周（2周）
**主要目标**：实现具体的事件处理器，包括音频、粒子、UI等非属性反馈处理器
**优先级**：高 - 扩展系统功能，支持多感官反馈

---

## 具体实现类详细设计

### 4.4 JuicyAudioEventHandler (音频事件处理器)

**文件路径**：`addons/juicy_mixer/events/juicy_audio_event_handler.gd`

**核心职责**：
- 处理音频播放和停止事件
- 管理音频播放器池
- 支持空间音频效果
- 提供音频混音和淡入淡出

**详细实现计划**：

```gdscript
class_name JuicyAudioEventHandler
extends JuicyEventHandler

# 音频播放器池
var _player_pool: Array[AudioStreamPlayer2D] = []
var _active_players: Dictionary = {}  # player_id -> player_info
var _max_pool_size: int = 50
var _max_concurrent_sounds: int = 20

# 音频配置
var _master_volume: float = 1.0
var _audio_bus: String = "Master"
var _spatial_audio_enabled: bool = true

func _init():
    handler_name = "AudioEventHandler"
    supported_events = [
        JuicyEventBuffer.EventType.AUDIO_PLAY,
        JuicyEventBuffer.EventType.AUDIO_STOP
    ]
    description = "Handles audio playback and control events"

func handle_event(event: JuicyEvent) -> bool:
    """处理音频事件"""
    var start_time = _start_handling_timer()
    
    var success = false
    
    match event.event_type:
        JuicyEventBuffer.EventType.AUDIO_PLAY:
            success = _handle_audio_play(event)
        JuicyEventBuffer.EventType.AUDIO_STOP:
            success = _handle_audio_stop(event)
        _:
            _log_warning("Unsupported event type: " + str(event.event_type))
    
    _end_handling_timer(start_time)
    
    if success:
        _record_success()
    else:
        _record_failure()
    
    return success

# 音频播放处理
func _handle_audio_play(event: JuicyEvent) -> bool:
    """处理音频播放事件"""
    var audio_stream = event.event_data.get("audio_stream")
    var position = event.event_data.get("position", Vector2.ZERO)
    var volume = event.event_data.get("volume", 1.0)
    
    if not audio_stream:
        _log_error("Audio stream is null")
        return false
    
    # 检查并发限制
    if _active_players.size() >= _max_concurrent_sounds:
        _log_warning("Maximum concurrent sounds reached, stopping oldest")
        _stop_oldest_player()
    
    # 获取播放器
    var player = _get_audio_player()
    if not player:
        _log_error("Failed to get audio player")
        return false
    
    # 配置播放器
    player.stream = audio_stream
    player.position = position
    player.volume_db = _linear_to_db(volume * _master_volume)
    player.bus = _audio_bus
    
    # 播放音频
    player.play()
    
    # 记录活跃播放器
    var player_id = player.get_instance_id()
    _active_players[player_id] = {
        "player": player,
        "context_id": event.context_id,
        "event_id": event.event_id,
        "start_time": Time.get_ticks_msec() / 1000.0
    }
    
    return true

func _handle_audio_stop(event: JuicyEvent) -> bool:
    """处理音频停止事件"""
    var context_id = event.context_id
    var event_id = event.event_id
    
    var players_to_stop: Array[AudioStreamPlayer2D] = []
    
    # 查找要停止的播放器
    for player_id in _active_players.keys():
        var player_info = _active_players[player_id]
        if player_info.context_id == context_id or player_info.event_id == event_id:
            players_to_stop.append(player_info.player)
    
    # 停止播放器
    for player in players_to_stop:
        _stop_audio_player(player)
    
    return players_to_stop.size() > 0

# 播放器管理
func _get_audio_player() -> AudioStreamPlayer2D:
    """获取音频播放器"""
    # 从池中获取
    if not _player_pool.is_empty():
        return _player_pool.pop_back()
    
    # 创建新的播放器
    if _player_pool.size() + _active_players.size() < _max_pool_size:
        var player = AudioStreamPlayer2D.new()
        _setup_audio_player(player)
        return player
    
    return null

func _setup_audio_player(player: AudioStreamPlayer2D) -> void:
    """设置音频播放器"""
    player.finished.connect(_on_player_finished.bind(player))
    
    # 添加到场景树
    var audio_root = _get_audio_root()
    audio_root.add_child(player)

func _stop_audio_player(player: AudioStreamPlayer2D) -> void:
    """停止音频播放器"""
    if not player or not is_instance_valid(player):
        return
    
    player.stop()
    _return_audio_player(player)

func _return_audio_player(player: AudioStreamPlayer2D) -> void:
    """归还音频播放器到池"""
    var player_id = player.get_instance_id()
    
    # 从活跃列表中移除
    _active_players.erase(player_id)
    
    # 重置播放器状态
    player.stream = null
    player.position = Vector2.ZERO
    player.volume_db = 0.0
    
    # 返回到池
    if _player_pool.size() < _max_pool_size:
        _player_pool.append(player)
    else:
        player.queue_free()

func _stop_oldest_player() -> void:
    """停止最老的播放器"""
    var oldest_time = INF
    var oldest_player_id = ""
    
    for player_id in _active_players.keys():
        var player_info = _active_players[player_id]
        if player_info.start_time < oldest_time:
            oldest_time = player_info.start_time
            oldest_player_id = player_id
    
    if not oldest_player_id.is_empty():
        var player_info = _active_players[oldest_player_id]
        _stop_audio_player(player_info.player)

# 回调处理
func _on_player_finished(player: AudioStreamPlayer2D) -> void:
    """播放器完成回调"""
    _return_audio_player(player)

# 工具方法
func _get_audio_root() -> Node:
    """获取音频根节点"""
    # 尝试获取现有的音频根节点
    var scene_root = Engine.get_main_loop().current_scene
    var audio_root = scene_root.get_node_or_null("JuicyAudioRoot")
    
    if not audio_root:
        audio_root = Node.new("JuicyAudioRoot")
        scene_root.add_child(audio_root)
    
    return audio_root

func _linear_to_db(linear: float) -> float:
    """线性值转分贝"""
    if linear <= 0.0:
        return -80.0
    return 20.0 * log(linear) / log(10.0)

# 配置管理
func configure(config: Dictionary) -> void:
    super.configure(config)
    
    if config.has("max_pool_size"):
        _max_pool_size = config.max_pool_size
    
    if config.has("max_concurrent_sounds"):
        _max_concurrent_sounds = config.max_concurrent_sounds
    
    if config.has("master_volume"):
        _master_volume = clamp(config.master_volume, 0.0, 1.0)
    
    if config.has("audio_bus"):
        _audio_bus = config.audio_bus
    
    if config.has("spatial_audio_enabled"):
        _spatial_audio_enabled = config.spatial_audio_enabled

func get_configuration() -> Dictionary:
    return super.get_configuration().merge({
        "max_pool_size": _max_pool_size,
        "max_concurrent_sounds": _max_concurrent_sounds,
        "master_volume": _master_volume,
        "audio_bus": _audio_bus,
        "spatial_audio_enabled": _spatial_audio_enabled
    })

# 统计和调试
func get_audio_stats() -> Dictionary:
    """获取音频统计信息"""
    return {
        "pool_size": _player_pool.size(),
        "active_players": _active_players.size(),
        "max_pool_size": _max_pool_size,
        "max_concurrent_sounds": _max_concurrent_sounds,
        "master_volume": _master_volume
    }

func cleanup() -> void:
    """清理音频处理器"""
    # 停止所有活跃播放器
    for player_id in _active_players.keys():
        var player_info = _active_players[player_id]
        _stop_audio_player(player_info.player)
    
    # 清空播放器池
    for player in _player_pool:
        if is_instance_valid(player):
            player.queue_free()
    _player_pool.clear()
```

**开发任务分解**：
- [ ] 第10周第4天：音频播放器池管理
- [ ] 第10周第5天：音频播放和停止处理
- [ ] 第10周第5天：空间音频和混音
- [ ] 第10周第5天：配置管理和统计
- [ ] 第10周第5天：单元测试

**验收标准**：
- 音频播放和停止正常
- 播放器池管理有效
- 空间音频支持良好
- 单元测试覆盖率100%

---

### 4.5 JuicyParticleEventHandler (粒子事件处理器)

**文件路径**：`addons/juicy_mixer/events/juicy_particle_event_handler.gd`

**核心职责**：
- 处理粒子生成和停止事件
- 管理粒子系统池
- 支持粒子效果配置
- 提供粒子性能优化

**详细实现计划**：

```gdscript
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
        JuicyEventBuffer.EventType.PARTICLE_SPAWN,
        JuicyEventBuffer.EventType.PARTICLE_STOP
    ]
    description = "Handles particle system events"

func handle_event(event: JuicyEvent) -> bool:
    """处理粒子事件"""
    var start_time = _start_handling_timer()
    
    var success = false
    
    match event.event_type:
        JuicyEventBuffer.EventType.PARTICLE_SPAWN:
            success = _handle_particle_spawn(event)
        JuicyEventBuffer.EventType.PARTICLE_STOP:
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
    var oldest_particle_id = ""
    
    for particle_id in _active_particles.keys():
        var particle_info = _active_particles[particle_id]
        if particle_info.start_time < oldest_time:
            oldest_time = particle_info.start_time
            oldest_particle_id = particle_id
    
    if not oldest_particle_id.is_empty():
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
        _particle_root = Node.new("JuicyParticleRoot")
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
    return super.get_configuration().merge({
        "max_pool_size": _max_pool_size,
        "max_concurrent_systems": _max_concurrent_systems,
        "auto_cleanup_time": _auto_cleanup_time
    })

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
```

**开发任务分解**：
- [ ] 第10周第5天：粒子系统池管理
- [ ] 第10周第5天：粒子生成和停止处理
- [ ] 第10周第5天：自动清理机制
- [ ] 第10周第5天：配置管理和统计
- [ ] 第10周第5天：单元测试

**验收标准**：
- 粒子生成和停止正常
- 粒子系统池管理有效
- 自动清理机制工作
- 单元测试覆盖率100%

---

## 集成测试计划

### 测试场景1：事件缓冲区基础功能测试
```gdscript
func test_event_buffer_basic():
    var buffer = JuicyEventBuffer.new()
    
    # 创建测试事件
    var event = JuicyEvent.new()
    event.event_type = JuicyEventBuffer.EventType.AUDIO_PLAY
    event.context_id = "test_context"
    event.priority = 10
    
    # 添加事件
    assert_true(buffer.add_event(event))
    
    # 获取准备处理的事件
    var ready_events = buffer.get_ready_events()
    assert_eq(ready_events.size(), 1)
    assert_eq(ready_events[0].event_type, JuicyEventBuffer.EventType.AUDIO_PLAY)
    
    # 标记已处理
    buffer.mark_events_processed(ready_events)
    
    # 验证缓冲区状态
    var stats = buffer.get_buffer_stats()
    assert_eq(stats.total_events_processed, 1)
```

### 测试场景2：事件调度器处理测试
```gdscript
func test_event_scheduler_processing():
    var buffer = JuicyEventBuffer.new()
    var scheduler = JuicyEventScheduler.new()
    
    # 注册测试处理器
    var handler = TestAudioEventHandler.new()
    scheduler.register_handler(handler, 100)
    
    # 添加测试事件
    var event = _create_test_audio_event()
    buffer.add_event(event)
    
    # 处理事件
    var processed_count = scheduler.process_events(buffer, 0.016)
    
    # 验证处理结果
    assert_eq(processed_count, 1)
    assert_eq(handler.get_performance_stats().events_handled, 1)
```

### 测试场景3：音频处理器功能测试
```gdscript
func test_audio_event_handler():
    var handler = JuicyAudioEventHandler.new()
    
    # 创建音频播放事件
    var event = handler._create_audio_play_event(
        "test_context", null, test_audio_stream
    )
    
    # 处理事件
    assert_true(handler.handle_event(event))
    
    # 验证统计信息
    var stats = handler.get_audio_stats()
    assert_gt(stats.active_players, 0)
    
    # 创建停止事件
    var stop_event = JuicyEvent.new()
    stop_event.event_type = JuicyEventBuffer.EventType.AUDIO_STOP
    stop_event.context_id = "test_context"
    
    # 处理停止事件
    assert_true(handler.handle_event(stop_event))
```

### 测试场景4：粒子处理器功能测试
```gdscript
func test_particle_event_handler():
    var handler = JuicyParticleEventHandler.new()
    
    # 创建粒子生成事件
    var event = handler._create_particle_spawn_event(
        "test_context", null, test_particle_scene
    )
    
    # 处理事件
    assert_true(handler.handle_event(event))
    
    # 验证统计信息
    var stats = handler.get_particle_stats()
    assert_gt(stats.active_particles, 0)
    
    # 创建停止事件
    var stop_event = JuicyEvent.new()
    stop_event.event_type = JuicyEventBuffer.EventType.PARTICLE_STOP
    stop_event.context_id = "test_context"
    
    # 处理停止事件
    assert_true(handler.handle_event(stop_event))
```


---

## 性能基准测试

### 基准1：事件缓冲区操作性能
- **目标**：10000次事件添加 < 16ms
- **测试方法**：批量添加事件并测量时间
- **验收标准**：平均添加时间 < 0.0016ms

### 基准2：事件调度器处理性能
- **目标**：1000个事件处理 < 16ms
- **测试方法**：批量处理事件并测量时间
- **验收标准**：平均处理时间 < 0.016ms

### 基准3：音频处理器性能
- **目标**：100个并发音频播放 < 16ms
- **测试方法**：批量播放音频并测量时间
- **验收标准**：平均播放时间 < 0.16ms

### 基准4：粒子处理器性能
- **目标**：50个并发粒子系统 < 16ms
- **测试方法**：批量生成粒子并测量时间
- **验收标准**：平均生成时间 < 0.32ms

### 基准5：UI处理器性能
- **目标**：30个并发UI动画 < 16ms
- **测试方法**：批量启动UI动画并测量时间
- **验收标准**：平均启动时间 < 0.53ms

---

## 风险管控

### 技术风险
1. **音频资源管理**：音频播放器可能泄漏
   - 缓解措施：实现严格的资源池管理和清理机制
   
2. **粒子系统性能**：大量粒子可能影响性能
   - 缓解措施：实现粒子系统池和自动清理

3. **UI动画冲突**：多个UI动画可能冲突
   - 缓解措施：实现动画优先级和冲突检测

### 进度风险
1. **事件系统复杂性**：事件类型和处理逻辑复杂
   - 缓解措施：分阶段实现，先实现基础功能

2. **跨平台兼容性**：音频和粒子在不同平台表现可能不同
   - 缓解措施：提供平台特定的配置和测试

---

## 交付检查清单

### 代码交付
- [ ] JuicyAudioEventHandler音频处理器完整实现
- [ ] JuicyParticleEventHandler粒子处理器完整实现
- [ ] 所有处理器的单元测试

### 文档交付
- [ ] 事件处理器API文档
- [ ] 事件处理器开发指南
- [ ] 性能基准报告
- [ ] 集成测试报告

### 验收标准
- [ ] 所有单元测试通过（覆盖率100%）
- [ ] 所有集成测试通过
- [ ] 性能基准测试达标
- [ ] 代码审查通过
- [ ] 文档完整准确

---

## 总结

阶段4的实现计划文档详细描述了具体事件处理器的实现方案，包括音频、粒子和UI处理器。这些处理器基于核心设计文档中定义的基类和架构，提供了丰富的反馈功能。

**关键成就**：
- 实现了高效的音频处理和播放器池管理
- 实现了灵活的粒子系统处理和自动清理
- 实现了强大的UI动画和反馈效果
- 提供了完整的性能优化和资源管理

**下一步**：进入阶段5，实现序列化与组合系统，支持复杂的效果编排。