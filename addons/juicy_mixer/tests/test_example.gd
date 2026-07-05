extends Node

# 示例测试文件，用于验证测试框架

func _ready():
	print("=== 运行示例测试 ===")
	
	_test_basic_assertions()
	_test_event_creation()
	_test_handler_functionality()
	
	print("=== 示例测试完成 ===")

func _test_basic_assertions():
	print("\n--- 测试基本断言 ---")
	
	# 测试基本相等性
	var a = 5
	var b = 5
	if a != b:
		push_error("断言失败: 5 应该等于 5")
	
	# 测试字符串
	var str1 = "hello"
	var str2 = "hello"
	if str1 != str2:
		push_error("断言失败: 字符串应该相等")
	
	# 测试向量
	var vec1 = Vector2(1, 2)
	var vec2 = Vector2(1, 2)
	if vec1 != vec2:
		push_error("断言失败: 向量应该相等")
	
	print("基本断言测试通过 ✓")

func _test_event_creation():
	print("\n--- 测试事件创建 ---")
	
	# 创建测试目标
	var test_target = Node2D.new()
	test_target.position = Vector2(100, 100)
	add_child(test_target)
	
	# 创建音频流
	var audio_stream = AudioStream.new()
	
	# 创建音频播放事件
	var audio_event = JuicyEvent.create_audio_play_event(
		"Test",
		test_target,
		audio_stream,
		Vector2(50, 50),
		0.8
	)
	
	# 验证事件属性
	if audio_event == null:
		push_error("断言失败: 事件应该被创建")
	if audio_event.event_type != JuicyEvent.EventType.AUDIO_PLAY:
		push_error("断言失败: 事件类型应该是音频播放")
	if audio_event.target != test_target:
		push_error("断言失败: 目标应该正确")
	if not audio_event.event_data.has("audio_stream"):
		push_error("断言失败: 事件数据应该包含音频流")
	if not audio_event.event_data.has("position"):
		push_error("断言失败: 事件数据应该包含位置")
	if not audio_event.event_data.has("volume"):
		push_error("断言失败: 事件数据应该包含音量")
	
	# 创建粒子生成事件
	var particle_scene = PackedScene.new()
	var particle_event = JuicyEvent.create_particle_spawn_event(
		"Test",
		test_target,
		particle_scene,
		30,
		Vector2(200, 200)
	)
	
	# 验证粒子事件
	if particle_event == null:
		push_error("断言失败: 粒子事件应该被创建")
	if particle_event.event_type != JuicyEvent.EventType.PARTICLE_SPAWN:
		push_error("断言失败: 事件类型应该是粒子生成")
	if not particle_event.event_data.has("particle_scene"):
		push_error("断言失败: 事件数据应该包含粒子场景")
	if not particle_event.event_data.has("amount"):
		push_error("断言失败: 事件数据应该包含数量")
	if not particle_event.event_data.has("position"):
		push_error("断言失败: 事件数据应该包含位置")
	
	# 清理
	test_target.queue_free()
	
	print("事件创建测试通过 ✓")

func _test_handler_functionality():
	print("\n--- 测试处理器功能 ---")
	
	# 创建测试目标
	var test_target = Node2D.new()
	add_child(test_target)
	
	# 创建音频流
	var audio_stream = AudioStream.new()
	
	# 创建音频事件处理器
	var audio_handler = JuicyAudioEventHandler.new()
	
	# 创建音频播放事件
	var audio_event = JuicyEvent.create_audio_play_event(
		"Test",
		test_target,
		audio_stream,
		Vector2(75, 75),
		0.9
	)
	audio_event.context_id = "test_context"
	
	# 处理事件
	var success = audio_handler.handle_event(audio_event)
	if not success:
		push_error("断言失败: 音频事件应该被成功处理")
	
	# 验证处理器状态
	var stats = audio_handler.get_audio_stats()
	if stats.active_players <= 0:
		push_error("断言失败: 应该有活跃的音频播放器")
	
	# 创建粒子事件处理器
	var particle_handler = JuicyParticleEventHandler.new()
	
	# 创建粒子场景
	var particle_scene = PackedScene.new()
	var particles = GPUParticles2D.new()
	particles.amount = 50
	particle_scene.pack(particles)
	
	# 创建粒子生成事件
	var particle_event = JuicyEvent.create_particle_spawn_event(
		"Test",
		test_target,
		particle_scene,
		25,
		Vector2(150, 150)
	)
	particle_event.context_id = "test_particle_context"
	
	# 处理粒子事件
	success = particle_handler.handle_event(particle_event)
	if not success:
		push_error("断言失败: 粒子事件应该被成功处理")
	
	# 验证粒子处理器状态
	var particle_stats = particle_handler.get_particle_stats()
	if particle_stats.active_particles <= 0:
		push_error("断言失败: 应该有活跃的粒子系统")
	
	# 清理
	audio_handler.cleanup()
	particle_handler.cleanup()
	test_target.queue_free()
	
	print("处理器功能测试通过 ✓")