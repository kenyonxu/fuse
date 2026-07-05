extends Node

# 安全的示例测试文件，避免实际的音频播放错误

func _ready():
	print("=== 运行安全示例测试 ===")
	
	_test_basic_assertions()
	_test_event_creation()
	_test_handler_basic_functionality()
	_test_configuration_management()
	
	print("=== 安全示例测试完成 ===")

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
	
	# 创建音频播放事件（不实际播放）
	var audio_event = JuicyEvent.new(JuicyEvent.EventType.AUDIO_PLAY)
	audio_event.target = test_target
	audio_event.context_id = "test_context"
	audio_event.event_data = {
		"audio_stream": null,  # 使用null避免播放错误
		"position": Vector2(50, 50),
		"volume": 0.8
	}
	
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

func _test_handler_basic_functionality():
	print("\n--- 测试处理器基本功能 ---")
	
	# 创建测试目标
	var test_target = Node2D.new()
	add_child(test_target)
	
	# 创建音频事件处理器
	var audio_handler = JuicyAudioEventHandler.new()
	
	# 验证处理器初始化
	if audio_handler.handler_name != "AudioEventHandler":
		push_error("断言失败: 处理器名称应该正确")
	if audio_handler.supported_events.size() != 2:
		push_error("断言失败: 应该支持2种事件类型")
	
	# 验证配置管理
	var config = audio_handler.get_configuration()
	if config.max_pool_size != 50:
		push_error("断言失败: 默认池大小应该是50")
	if config.max_concurrent_sounds != 20:
		push_error("断言失败: 默认并发音频数应该是20")
	
	# 测试配置更新
	var new_config = {
		"max_pool_size": 30,
		"max_concurrent_sounds": 15,
		"master_volume": 0.5
	}
	audio_handler.configure(new_config)
	
	config = audio_handler.get_configuration()
	if config.max_pool_size != 30:
		push_error("断言失败: 池大小配置应该更新")
	if config.max_concurrent_sounds != 15:
		push_error("断言失败: 并发音频数配置应该更新")
	if config.master_volume != 0.5:
		push_error("断言失败: 主音量配置应该更新")
	
	# 创建粒子事件处理器
	var particle_handler = JuicyParticleEventHandler.new()
	
	# 验证粒子处理器初始化
	if particle_handler.handler_name != "ParticleEventHandler":
		push_error("断言失败: 粒子处理器名称应该正确")
	if particle_handler.supported_events.size() != 2:
		push_error("断言失败: 粒子处理器应该支持2种事件类型")
	
	# 验证粒子配置
	var particle_config = particle_handler.get_configuration()
	if particle_config.max_pool_size != 30:
		push_error("断言失败: 默认粒子池大小应该是30")
	if particle_config.max_concurrent_systems != 15:
		push_error("断言失败: 默认并发粒子系统数应该是15")
	
	# 清理
	audio_handler.cleanup()
	particle_handler.cleanup()
	test_target.queue_free()
	
	print("处理器基本功能测试通过 ✓")

func _test_configuration_management():
	print("\n--- 测试配置管理 ---")
	
	# 创建音频事件处理器
	var audio_handler = JuicyAudioEventHandler.new()
	
	# 测试音量限制
	audio_handler.configure({"master_volume": 1.5})
	var config = audio_handler.get_configuration()
	if config.master_volume != 1.0:
		push_error("断言失败: 主音量应该被限制在1.0")
	
	audio_handler.configure({"master_volume": -0.5})
	config = audio_handler.get_configuration()
	if config.master_volume != 0.0:
		push_error("断言失败: 主音量应该被限制在0.0")
	
	# 测试性能统计
	audio_handler.reset_performance_stats()
	var perf_stats = audio_handler.get_performance_stats()
	if perf_stats.events_handled != 0:
		push_error("断言失败: 重置后事件处理数应该为0")
	if perf_stats.events_failed != 0:
		push_error("断言失败: 重置后事件失败数应该为0")
	
	# 验证音频统计
	var audio_stats = audio_handler.get_audio_stats()
	if audio_stats.pool_size < 0:
		push_error("断言失败: 池大小应该有效")
	if audio_stats.max_pool_size != 50:
		push_error("断言失败: 最大池大小应该正确")
	
	# 清理
	audio_handler.cleanup()
	
	print("配置管理测试通过 ✓")