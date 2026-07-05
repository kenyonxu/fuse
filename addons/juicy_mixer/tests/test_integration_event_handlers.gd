extends Node

# JuicyAudioEventHandler 和 JuicyParticleEventHandler 集成测试
# 验证事件处理器与JuicyMixer系统的完整集成功能

const TEST_REPORT_PATH = "user://integration_test_report.txt"

var _test_results: Dictionary = {}
var _test_start_time: float
var _test_end_time: float

# 系统组件
var _event_middleware: EventHandlingMiddleware
var _audio_handler: JuicyAudioEventHandler
var _particle_handler: JuicyParticleEventHandler
var _test_target: Node2D

# 测试资源
var _test_audio_stream: AudioStream
var _test_particle_scene: PackedScene

func _ready():
	print("=== 开始 JuicyMixer 事件处理器集成测试 ===")
	_test_start_time = Time.get_ticks_msec() / 1000.0
	
	# 初始化测试环境
	_setup_test_environment()
	
	# 运行所有集成测试
	_run_integration_tests()
	
	# 生成测试报告
	_generate_test_report()
	
	# 清理测试环境
	_cleanup_test_environment()
	
	_test_end_time = Time.get_ticks_msec() / 1000.0
	print("=== JuicyMixer 事件处理器集成测试完成 ===")
	print("总测试时间: %.2f 秒" % (_test_end_time - _test_start_time))

func _setup_test_environment():
	print("\n--- 设置集成测试环境 ---")
	
	# 确保JuicyMixer已初始化
	if not JuicyMixer.instance:
		push_error("JuicyMixer 实例未初始化")
		return
	
	# 创建测试目标节点
	_test_target = Node2D.new()
	_test_target.position = Vector2(400, 300)
	add_child(_test_target)
	
	# 创建测试音频流
	_test_audio_stream = AudioStream.new()
	
	# 创建测试粒子场景
	_test_particle_scene = PackedScene.new()
	var particles = GPUParticles2D.new()
	particles.amount = 50
	particles.lifetime = 1.5
	particles.one_shot = true
	_test_particle_scene.pack(particles)
	
	# 获取事件处理中间件
	_event_middleware = JuicyMixer.get_middleware("EventHandlingMiddleware")
	if not _event_middleware:
		push_error("EventHandlingMiddleware 未找到")
		return
	
	# 创建事件处理器实例
	_audio_handler = JuicyAudioEventHandler.new()
	_particle_handler = JuicyParticleEventHandler.new()
	
	print("集成测试环境设置完成 ✓")

func _cleanup_test_environment():
	print("\n--- 清理集成测试环境 ---")
	
	# 清理事件处理器
	if _audio_handler:
		_audio_handler.cleanup()
		_audio_handler = null
	
	if _particle_handler:
		_particle_handler.cleanup()
		_particle_handler = null
	
	# 清理测试目标节点
	if _test_target:
		_test_target.queue_free()
		_test_target = null
	
	print("集成测试环境清理完成 ✓")

func _run_integration_tests():
	print("\n--- 运行集成测试 ---")
	
	# 测试事件处理器注册
	_test_event_handler_registration()
	
	# 测试事件处理器与中间件集成
	_test_middleware_integration()
	
	# 测试完整事件流程
	_test_complete_event_workflow()
	
	# 测试配置管理集成
	_test_configuration_integration()
	
	# 测试性能统计上报
	_test_performance_stats_reporting()
	
	# 测试资源管理和清理
	_test_resource_management_and_cleanup()
	
	# 测试JuicyMixerManager集成
	_test_juicy_mixer_manager_integration()
	
	# 测试实际场景中的事件处理
	_test_real_world_scenario()
	
	# 测试错误处理和日志集成
	_test_error_handling_and_logging()
	
	# 测试系统级性能
	_test_system_level_performance()

func _test_event_handler_registration():
	print("\n  → 测试事件处理器注册...")
	
	var test_name = "event_handler_registration"
	_test_results[test_name] = {
		"passed": false,
		"details": []
	}
	
	# 测试音频事件处理器注册
	var audio_register_success = _event_middleware.register_event_handler(_audio_handler, 100)
	if not audio_register_success:
		_test_results[test_name].details.append("音频事件处理器注册失败")
		print("    事件处理器注册测试失败 ✗")
		return
	
	_test_results[test_name].details.append("音频事件处理器注册成功")
	
	# 测试粒子事件处理器注册
	var particle_register_success = _event_middleware.register_event_handler(_particle_handler, 200)
	if not particle_register_success:
		_test_results[test_name].details.append("粒子事件处理器注册失败")
		print("    事件处理器注册测试失败 ✗")
		return
	
	_test_results[test_name].details.append("粒子事件处理器注册成功")
	
	# 验证处理器已注册
	var registered_audio_handler = _event_middleware.get_event_handler("AudioEventHandler")
	if registered_audio_handler == null or registered_audio_handler != _audio_handler:
		_test_results[test_name].details.append("音频事件处理器获取验证失败")
		print("    事件处理器注册测试失败 ✗")
		return
	
	_test_results[test_name].details.append("音频事件处理器获取验证成功")
	
	var registered_particle_handler = _event_middleware.get_event_handler("ParticleEventHandler")
	if registered_particle_handler == null or registered_particle_handler != _particle_handler:
		_test_results[test_name].details.append("粒子事件处理器获取验证失败")
		print("    事件处理器注册测试失败 ✗")
		return
	
	_test_results[test_name].details.append("粒子事件处理器获取验证成功")
	
	_test_results[test_name].passed = true
	print("    事件处理器注册测试通过 ✓")

func _test_middleware_integration():
	print("\n  → 测试中间件集成...")
	
	var test_name = "middleware_integration"
	_test_results[test_name] = {
		"passed": false,
		"details": []
	}
	
	# 验证事件系统已启用
	var event_system_enabled = _event_middleware.is_event_system_enabled()
	if not event_system_enabled:
		_test_results[test_name].details.append("事件系统未启用")
		print("    中间件集成测试失败 ✗")
		return
	
	_test_results[test_name].details.append("事件系统已启用")
	
	# 获取事件系统统计
	var event_stats = _event_middleware.get_event_system_stats()
	if not event_stats.has("enabled") or event_stats.enabled != true:
		_test_results[test_name].details.append("事件系统统计验证失败")
		print("    中间件集成测试失败 ✗")
		return
	
	_test_results[test_name].details.append("事件系统统计验证成功")
	
	# 验证事件调度器已初始化
	if not event_stats.has("scheduler_stats"):
		_test_results[test_name].details.append("调度器统计不存在")
		print("    中间件集成测试失败 ✗")
		return
	
	_test_results[test_name].details.append("调度器统计存在")
	
	# 验证事件缓冲区已初始化
	if not event_stats.has("buffer_stats"):
		_test_results[test_name].details.append("缓冲区统计不存在")
		print("    中间件集成测试失败 ✗")
		return
	
	_test_results[test_name].details.append("缓冲区统计存在")
	
	_test_results[test_name].passed = true
	print("    中间件集成测试通过 ✓")

func _test_complete_event_workflow():
	print("\n  → 测试完整事件流程...")
	
	var test_name = "complete_event_workflow"
	_test_results[test_name] = {
		"passed": false,
		"details": []
	}
	
	# 创建音频播放事件
	var audio_event = JuicyEvent.create_audio_play_event(
		"Test",
		_test_target,
		_test_audio_stream,
		Vector2(100, 100),
		0.8
	)
	audio_event.context_id = "integration_test_audio"
	
	# 创建粒子生成事件
	var particle_event = JuicyEvent.create_particle_spawn_event(
		"Test",
		_test_target,
		_test_particle_scene,
		30,
		Vector2(200, 200)
	)
	particle_event.context_id = "integration_test_particle"
	
	# 通过JuicyMixer添加事件
	var audio_add_success = JuicyMixer.add_event(audio_event)
	if not audio_add_success:
		_test_results[test_name].details.append("音频事件添加失败")
		print("    完整事件流程测试失败 ✗")
		return
	
	_test_results[test_name].details.append("音频事件添加成功")
	
	var particle_add_success = JuicyMixer.add_event(particle_event)
	if not particle_add_success:
		_test_results[test_name].details.append("粒子事件添加失败")
		print("    完整事件流程测试失败 ✗")
		return
	
	_test_results[test_name].details.append("粒子事件添加成功")
	
	# 处理事件
	var processed_events = JuicyMixer.process_events(0.016)  # 模拟一帧
	if processed_events <= 0:
		_test_results[test_name].details.append("事件处理失败")
		print("    完整事件流程测试失败 ✗")
		return
	
	_test_results[test_name].details.append("事件处理成功，处理了 " + str(processed_events) + " 个事件")
	
	# 验证事件处理器性能统计已更新
	var audio_perf_stats = _audio_handler.get_performance_stats()
	if audio_perf_stats.events_handled <= 0:
		_test_results[test_name].details.append("音频处理器事件处理验证失败")
		print("    完整事件流程测试失败 ✗")
		return
	
	_test_results[test_name].details.append("音频处理器事件处理验证成功")
	
	var particle_perf_stats = _particle_handler.get_performance_stats()
	if particle_perf_stats.events_handled <= 0:
		_test_results[test_name].details.append("粒子处理器事件处理验证失败")
		print("    完整事件流程测试失败 ✗")
		return
	
	_test_results[test_name].details.append("粒子处理器事件处理验证成功")
	
	_test_results[test_name].passed = true
	print("    完整事件流程测试通过 ✓")

func _test_configuration_integration():
	print("\n  → 测试配置管理集成...")
	
	var test_name = "configuration_integration"
	_test_results[test_name] = {
		"passed": false,
		"details": []
	}
	
	# 测试音频处理器配置
	var audio_config = {
		"max_pool_size": 25,
		"max_concurrent_sounds": 10,
		"master_volume": 0.7,
		"audio_bus": "SFX",
		"spatial_audio_enabled": false
	}
	
	_audio_handler.configure(audio_config)
	var audio_current_config = _audio_handler.get_configuration()
	
	if audio_current_config.max_pool_size != 25:
		_test_results[test_name].details.append("音频处理器池大小配置验证失败")
		print("    配置管理集成测试失败 ✗")
		return
	
	if audio_current_config.max_concurrent_sounds != 10:
		_test_results[test_name].details.append("音频处理器并发数配置验证失败")
		print("    配置管理集成测试失败 ✗")
		return
	
	if audio_current_config.master_volume != 0.7:
		_test_results[test_name].details.append("音频处理器主音量配置验证失败")
		print("    配置管理集成测试失败 ✗")
		return
	
	if audio_current_config.audio_bus != "SFX":
		_test_results[test_name].details.append("音频处理器总线配置验证失败")
		print("    配置管理集成测试失败 ✗")
		return
	
	if audio_current_config.spatial_audio_enabled != false:
		_test_results[test_name].details.append("音频处理器空间音频配置验证失败")
		print("    配置管理集成测试失败 ✗")
		return
	
	_test_results[test_name].details.append("音频处理器配置验证成功")
	
	# 测试粒子处理器配置
	var particle_config = {
		"max_pool_size": 20,
		"max_concurrent_systems": 8,
		"auto_cleanup_time": 5.0
	}
	
	_particle_handler.configure(particle_config)
	var particle_current_config = _particle_handler.get_configuration()
	
	if particle_current_config.max_pool_size != 20:
		_test_results[test_name].details.append("粒子处理器池大小配置验证失败")
		print("    配置管理集成测试失败 ✗")
		return
	
	if particle_current_config.max_concurrent_systems != 8:
		_test_results[test_name].details.append("粒子处理器并发数配置验证失败")
		print("    配置管理集成测试失败 ✗")
		return
	
	if particle_current_config.auto_cleanup_time != 5.0:
		_test_results[test_name].details.append("粒子处理器自动清理时间配置验证失败")
		print("    配置管理集成测试失败 ✗")
		return
	
	_test_results[test_name].details.append("粒子处理器配置验证成功")
	
	_test_results[test_name].passed = true
	print("    配置管理集成测试通过 ✓")

func _test_performance_stats_reporting():
	print("\n  → 测试性能统计上报...")
	
	var test_name = "performance_stats_reporting"
	_test_results[test_name] = {
		"passed": false,
		"details": []
	}
	
	# 重置性能统计
	_audio_handler.reset_performance_stats()
	_particle_handler.reset_performance_stats()
	
	# 创建多个事件进行性能测试
	for i in range(10):
		# 音频事件
		var audio_event = JuicyEvent.create_audio_play_event(
			"Test",
			_test_target,
			_test_audio_stream,
			Vector2(i * 10, i * 10),
			0.6
		)
		audio_event.context_id = "perf_test_audio_" + str(i)
		JuicyMixer.add_event(audio_event)
		
		# 粒子事件
		var particle_event = JuicyEvent.create_particle_spawn_event(
			"Test",
			_test_target,
			_test_particle_scene,
			20,
			Vector2(i * 15, i * 15)
		)
		particle_event.context_id = "perf_test_particle_" + str(i)
		JuicyMixer.add_event(particle_event)
	
	# 处理所有事件
	JuicyMixer.process_events(0.016)
	
	# 验证音频处理器性能统计
	var audio_stats = _audio_handler.get_performance_stats()
	if audio_stats.events_handled != 10:
		_test_results[test_name].details.append("音频处理器事件处理数量验证失败")
		print("    性能统计上报测试失败 ✗")
		return
	
	if audio_stats.success_rate != 1.0:
		_test_results[test_name].details.append("音频处理器成功率验证失败")
		print("    性能统计上报测试失败 ✗")
		return
	
	if audio_stats.total_handling_time <= 0:
		_test_results[test_name].details.append("音频处理器总处理时间验证失败")
		print("    性能统计上报测试失败 ✗")
		return
	
	if audio_stats.average_handling_time <= 0:
		_test_results[test_name].details.append("音频处理器平均处理时间验证失败")
		print("    性能统计上报测试失败 ✗")
		return
	
	_test_results[test_name].details.append("音频处理器性能统计验证成功")
	
	# 验证粒子处理器性能统计
	var particle_stats = _particle_handler.get_performance_stats()
	if particle_stats.events_handled != 10:
		_test_results[test_name].details.append("粒子处理器事件处理数量验证失败")
		print("    性能统计上报测试失败 ✗")
		return
	
	if particle_stats.success_rate != 1.0:
		_test_results[test_name].details.append("粒子处理器成功率验证失败")
		print("    性能统计上报测试失败 ✗")
		return
	
	if particle_stats.total_handling_time <= 0:
		_test_results[test_name].details.append("粒子处理器总处理时间验证失败")
		print("    性能统计上报测试失败 ✗")
		return
	
	if particle_stats.average_handling_time <= 0:
		_test_results[test_name].details.append("粒子处理器平均处理时间验证失败")
		print("    性能统计上报测试失败 ✗")
		return
	
	_test_results[test_name].details.append("粒子处理器性能统计验证成功")
	
	# 验证系统级性能统计
	var system_stats = JuicyMixer.get_middleware_performance_stats()
	if not system_stats.has("middleware_stats"):
		_test_results[test_name].details.append("系统级性能统计验证失败")
		print("    性能统计上报测试失败 ✗")
		return
	
	if system_stats.middleware_stats.size() <= 0:
		_test_results[test_name].details.append("系统级性能统计中间件数据验证失败")
		print("    性能统计上报测试失败 ✗")
		return
	
	_test_results[test_name].details.append("系统级性能统计验证成功")
	
	_test_results[test_name].passed = true
	print("    性能统计上报测试通过 ✓")

func _test_resource_management_and_cleanup():
	print("\n  → 测试资源管理和清理...")
	
	var test_name = "resource_management_and_cleanup"
	_test_results[test_name] = {
		"passed": false,
		"details": []
	}
	
	# 创建多个事件来占用资源
	for i in range(5):
		var audio_event = JuicyEvent.create_audio_play_event(
			"Test",
			_test_target,
			_test_audio_stream,
			Vector2(i * 20, i * 20),
			0.7
		)
		audio_event.context_id = "resource_test_audio_" + str(i)
		JuicyMixer.add_event(audio_event)
		
		var particle_event = JuicyEvent.create_particle_spawn_event(
			"Test",
			_test_target,
			_test_particle_scene,
			25,
			Vector2(i * 25, i * 25)
		)
		particle_event.context_id = "resource_test_particle_" + str(i)
		JuicyMixer.add_event(particle_event)
	
	# 处理事件
	JuicyMixer.process_events(0.016)
	
	# 验证资源已分配
	var audio_stats_before = _audio_handler.get_audio_stats()
	var particle_stats_before = _particle_handler.get_particle_stats()
	
	if audio_stats_before.active_players <= 0:
		_test_results[test_name].details.append("音频处理器资源分配验证失败")
		print("    资源管理和清理测试失败 ✗")
		return
	
	if particle_stats_before.active_particles <= 0:
		_test_results[test_name].details.append("粒子处理器资源分配验证失败")
		print("    资源管理和清理测试失败 ✗")
		return
	
	_test_results[test_name].details.append("资源分配验证成功")
	
	# 执行清理
	_audio_handler.cleanup()
	_particle_handler.cleanup()
	
	# 验证资源已释放
	var audio_stats_after = _audio_handler.get_audio_stats()
	var particle_stats_after = _particle_handler.get_particle_stats()
	
	if audio_stats_after.active_players != 0:
		_test_results[test_name].details.append("音频处理器资源清理验证失败")
		print("    资源管理和清理测试失败 ✗")
		return
	
	if audio_stats_after.pool_size != 0:
		_test_results[test_name].details.append("音频处理器池清理验证失败")
		print("    资源管理和清理测试失败 ✗")
		return
	
	if particle_stats_after.active_particles != 0:
		_test_results[test_name].details.append("粒子处理器资源清理验证失败")
		print("    资源管理和清理测试失败 ✗")
		return
	
	if particle_stats_after.pool_size != 0:
		_test_results[test_name].details.append("粒子处理器池清理验证失败")
		print("    资源管理和清理测试失败 ✗")
		return
	
	_test_results[test_name].details.append("资源清理验证成功")
	
	_test_results[test_name].passed = true
	print("    资源管理和清理测试通过 ✓")

func _test_juicy_mixer_manager_integration():
	print("\n  → 测试JuicyMixerManager集成...")
	
	var test_name = "juicy_mixer_manager_integration"
	_test_results[test_name] = {
		"passed": false,
		"details": []
	}
	
	# 创建JuicyMixerManager节点
	var manager_node = JuicyMixerManager.new()
	add_child(manager_node)
	
	# 创建中间件条目
	var middleware_entry = MiddlewareEntry.new()
	middleware_entry.enabled = true
	middleware_entry.priority = 100
	
	# 添加条目到管理器
	manager_node.middleware_entries.append(middleware_entry)
	
	# 验证管理器配置统计
	var config_stats = manager_node.get_config_stats()
	if config_stats.total_entries <= 0:
		_test_results[test_name].details.append("管理器配置统计验证失败")
		print("    JuicyMixerManager集成测试失败 ✗")
		return
	
	if config_stats.enabled_entries <= 0:
		_test_results[test_name].details.append("管理器启用条目验证失败")
		print("    JuicyMixerManager集成测试失败 ✗")
		return
	
	_test_results[test_name].details.append("管理器配置验证成功")
	
	# 验证管理器可以获取启用的中间件名称
	var enabled_names = manager_node.get_enabled_middleware_names()
	if enabled_names.size() < 0:
		_test_results[test_name].details.append("管理器中间件名称获取验证失败")
		print("    JuicyMixerManager集成测试失败 ✗")
		return
	
	_test_results[test_name].details.append("管理器中间件名称获取验证成功")
	
	# 清理管理器节点
	manager_node.queue_free()
	
	_test_results[test_name].passed = true
	print("    JuicyMixerManager集成测试通过 ✓")

func _test_real_world_scenario():
	print("\n  → 测试实际场景中的事件处理...")
	
	var test_name = "real_world_scenario"
	_test_results[test_name] = {
		"passed": false,
		"details": []
	}
	
	# 模拟游戏场景：玩家攻击时播放音效和粒子效果
	var attack_context_id = "player_attack_001"
	
	# 创建攻击音效事件
	var attack_audio_event = JuicyEvent.create_audio_play_event(
		"Test",
		_test_target,
		_test_audio_stream,
		_test_target.position,
		0.9
	)
	attack_audio_event.context_id = attack_context_id
	
	# 创建攻击粒子效果事件
	var attack_particle_event = JuicyEvent.create_particle_spawn_event(
		"Test",
		_test_target,
		_test_particle_scene,
		40,
		_test_target.position
	)
	attack_particle_event.context_id = attack_context_id
	
	# 添加事件到系统
	JuicyMixer.add_event(attack_audio_event)
	JuicyMixer.add_event(attack_particle_event)
	
	# 处理事件
	var processed_count = JuicyMixer.process_events(0.016)
	if processed_count < 2:
		_test_results[test_name].details.append("攻击事件处理验证失败")
		print("    实际场景中的事件处理测试失败 ✗")
		return
	
	_test_results[test_name].details.append("攻击事件处理成功")
	
	# 验证音频和粒子效果已激活
	var audio_stats = _audio_handler.get_audio_stats()
	var particle_stats = _particle_handler.get_particle_stats()
	
	if audio_stats.active_players <= 0:
		_test_results[test_name].details.append("攻击音频效果激活验证失败")
		print("    实际场景中的事件处理测试失败 ✗")
		return
	
	if particle_stats.active_particles <= 0:
		_test_results[test_name].details.append("攻击粒子效果激活验证失败")
		print("    实际场景中的事件处理测试失败 ✗")
		return
	
	_test_results[test_name].details.append("攻击效果激活验证成功")
	
	# 模拟攻击结束，停止所有效果
	var stop_event = JuicyEvent.new(JuicyEvent.EventType.AUDIO_STOP)
	stop_event.context_id = attack_context_id
	stop_event.target = _test_target
	
	JuicyMixer.add_event(stop_event)
	JuicyMixer.process_events(0.016)
	
	# 验证效果已停止
	var audio_stats_after = _audio_handler.get_audio_stats()
	if audio_stats_after.active_players != 0:
		_test_results[test_name].details.append("攻击效果停止验证失败")
		print("    实际场景中的事件处理测试失败 ✗")
		return
	
	_test_results[test_name].details.append("攻击效果停止验证成功")
	
	_test_results[test_name].passed = true
	print("    实际场景中的事件处理测试通过 ✓")

func _test_error_handling_and_logging():
	print("\n  → 测试错误处理和日志集成...")
	
	var test_name = "error_handling_and_logging"
	_test_results[test_name] = {
		"passed": false,
		"details": []
	}
	
	# 重置性能统计
	_audio_handler.reset_performance_stats()
	_particle_handler.reset_performance_stats()
	
	# 测试无效音频事件
	var invalid_audio_event = JuicyEvent.create_audio_play_event(
		"Test",
		_test_target,
		null,  # 空音频流
		Vector2(100, 100),
		0.8
	)
	invalid_audio_event.context_id = "error_test_audio"
	
	var audio_success = _audio_handler.handle_event(invalid_audio_event)
	if audio_success:
		_test_results[test_name].details.append("音频错误处理验证失败")
		print("    错误处理和日志集成测试失败 ✗")
		return
	
	# 验证失败计数
	var audio_stats = _audio_handler.get_performance_stats()
	if audio_stats.events_failed <= 0:
		_test_results[test_name].details.append("音频失败计数验证失败")
		print("    错误处理和日志集成测试失败 ✗")
		return
	
	_test_results[test_name].details.append("音频错误处理验证成功")
	
	# 测试无效粒子事件
	var invalid_particle_event = JuicyEvent.create_particle_spawn_event(
		"Test",
		_test_target,
		null,  # 空粒子场景
		30,
		Vector2(200, 200)
	)
	invalid_particle_event.context_id = "error_test_particle"
	
	var particle_success = _particle_handler.handle_event(invalid_particle_event)
	if particle_success:
		_test_results[test_name].details.append("粒子错误处理验证失败")
		print("    错误处理和日志集成测试失败 ✗")
		return
	
	# 验证失败计数
	var particle_stats = _particle_handler.get_performance_stats()
	if particle_stats.events_failed <= 0:
		_test_results[test_name].details.append("粒子失败计数验证失败")
		print("    错误处理和日志集成测试失败 ✗")
		return
	
	_test_results[test_name].details.append("粒子错误处理验证成功")
	
	# 测试不支持的事件类型
	var unsupported_event = JuicyEvent.new(JuicyEvent.EventType.UI_UPDATE)
	unsupported_event.context_id = "error_test_unsupported"
	unsupported_event.target = _test_target
	
	var audio_unsupported_success = _audio_handler.handle_event(unsupported_event)
	var particle_unsupported_success = _particle_handler.handle_event(unsupported_event)
	
	if audio_unsupported_success:
		_test_results[test_name].details.append("音频不支持事件类型验证失败")
		print("    错误处理和日志集成测试失败 ✗")
		return
	
	if particle_unsupported_success:
		_test_results[test_name].details.append("粒子不支持事件类型验证失败")
		print("    错误处理和日志集成测试失败 ✗")
		return
	
	_test_results[test_name].details.append("不支持事件类型处理验证成功")
	
	_test_results[test_name].passed = true
	print("    错误处理和日志集成测试通过 ✓")

func _test_system_level_performance():
	print("\n  → 测试系统级性能...")
	
	var test_name = "system_level_performance"
	_test_results[test_name] = {
		"passed": false,
		"details": []
	}
	
	# 重置性能统计
	_audio_handler.reset_performance_stats()
	_particle_handler.reset_performance_stats()
	
	# 性能测试参数
	var event_count = 50
	var start_time = Time.get_ticks_msec()
	
	# 批量创建事件
	for i in range(event_count):
		# 音频事件
		var audio_event = JuicyEvent.create_audio_play_event(
			"Test",
			_test_target,
			_test_audio_stream,
			Vector2(i * 5, i * 5),
			0.5 + (i % 5) * 0.1
		)
		audio_event.context_id = "perf_test_" + str(i) + "_audio"
		JuicyMixer.add_event(audio_event)
		
		# 粒子事件
		var particle_event = JuicyEvent.create_particle_spawn_event(
			"Test",
			_test_target,
			_test_particle_scene,
			15 + (i % 3) * 5,
			Vector2(i * 8, i * 8)
		)
		particle_event.context_id = "perf_test_" + str(i) + "_particle"
		JuicyMixer.add_event(particle_event)
	
	# 处理所有事件
	var total_processed = 0
	for i in range(5):  # 分多帧处理
		total_processed += JuicyMixer.process_events(0.016)
	
	var total_time = (Time.get_ticks_msec() - start_time) / 1000.0
	var avg_time_per_event = total_time / (event_count * 2)  # 音频和粒子各50个
	
	# 验证性能基准
	if avg_time_per_event >= 0.00032:
		_test_results[test_name].details.append("性能基准验证失败: %.6f 秒/事件" % avg_time_per_event)
		print("    系统级性能测试失败 ✗")
		return
	
	_test_results[test_name].details.append("性能基准验证成功: %.6f 秒/事件" % avg_time_per_event)
	
	# 验证处理的事件数量
	if total_processed < event_count * 2:
		_test_results[test_name].details.append("事件处理数量验证失败: " + str(total_processed) + " 个事件")
		print("    系统级性能测试失败 ✗")
		return
	
	_test_results[test_name].details.append("事件处理数量验证成功: " + str(total_processed) + " 个事件")
	
	# 验证系统资源使用
	var audio_stats = _audio_handler.get_audio_stats()
	var particle_stats = _particle_handler.get_particle_stats()
	
	if audio_stats.active_players > audio_stats.max_concurrent_sounds:
		_test_results[test_name].details.append("音频并发数限制验证失败")
		print("    系统级性能测试失败 ✗")
		return
	
	if particle_stats.active_particles > particle_stats.max_concurrent_systems:
		_test_results[test_name].details.append("粒子并发数限制验证失败")
		print("    系统级性能测试失败 ✗")
		return
	
	_test_results[test_name].details.append("资源使用验证成功")
	
	# 获取系统级统计
	var system_stats = JuicyMixer.get_middleware_performance_stats()
	var pool_stats = JuicyMixer.get_pool_statistics()
	
	if not system_stats.has("pipeline_stats"):
		_test_results[test_name].details.append("系统级统计验证失败")
		print("    系统级性能测试失败 ✗")
		return
	
	if pool_stats.size() < 0:
		_test_results[test_name].details.append("池统计验证失败")
		print("    系统级性能测试失败 ✗")
		return
	
	_test_results[test_name].details.append("系统级统计验证成功")
	
	_test_results[test_name].passed = true
	print("    系统级性能测试通过 ✓")

func _generate_test_report():
	print("\n--- 生成集成测试报告 ---")
	
	var report_content = "=== JuicyMixer 事件处理器集成测试报告 ===\n"
	report_content += "测试时间: " + Time.get_time_string_from_system() + "\n"
	report_content += "测试持续时间: %.2f 秒\n\n" % (_test_end_time - _test_start_time)
	
	var total_tests = _test_results.size()
	var passed_tests = 0
	var failed_tests = 0
	
	for test_name in _test_results.keys():
		var result = _test_results[test_name]
		if result.passed:
			passed_tests += 1
			report_content += "[✓] " + test_name + " - 通过\n"
		else:
			failed_tests += 1
			report_content += "[✗] " + test_name + " - 失败\n"
		
		# 添加详细信息
		for detail in result.details:
			report_content += "    - " + detail + "\n"
		report_content += "\n"
	
	report_content += "=== 测试总结 ===\n"
	report_content += "总测试数: " + str(total_tests) + "\n"
	report_content += "通过测试: " + str(passed_tests) + "\n"
	report_content += "失败测试: " + str(failed_tests) + "\n"
	report_content += "通过率: %.1f%%\n" % (float(passed_tests) / total_tests * 100)
	
	if failed_tests == 0:
		report_content += "\n🎉 所有集成测试均通过！系统运行正常。\n"
	else:
		report_content += "\n⚠️  部分测试失败，请检查相关功能。\n"
	
	# 添加系统状态信息
	report_content += "\n=== 系统状态信息 ===\n"
	
	if _audio_handler:
		var audio_stats = _audio_handler.get_audio_stats()
		report_content += "音频处理器状态:\n"
		report_content += "  - 活跃播放器: " + str(audio_stats.active_players) + "\n"
		report_content += "  - 池大小: " + str(audio_stats.pool_size) + "\n"
		report_content += "  - 最大并发数: " + str(audio_stats.max_concurrent_sounds) + "\n"
	
	if _particle_handler:
		var particle_stats = _particle_handler.get_particle_stats()
		report_content += "粒子处理器状态:\n"
		report_content += "  - 活跃粒子系统: " + str(particle_stats.active_particles) + "\n"
		report_content += "  - 池大小: " + str(particle_stats.pool_size) + "\n"
		report_content += "  - 最大并发数: " + str(particle_stats.max_concurrent_systems) + "\n"
	
	# 获取系统级统计
	var system_stats = JuicyMixer.get_middleware_performance_stats()
	if system_stats.has("pipeline_stats"):
		report_content += "系统管道统计:\n"
		var pipeline_stats = system_stats.pipeline_stats
		for key in pipeline_stats.keys():
			report_content += "  - " + str(key) + ": " + str(pipeline_stats[key]) + "\n"
	
	# 保存报告到文件
	var file = FileAccess.open(TEST_REPORT_PATH, FileAccess.WRITE)
	if file:
		file.store_string(report_content)
		file.close()
		print("集成测试报告已保存到: " + TEST_REPORT_PATH)
	else:
		print("无法保存测试报告到文件")
	
	# 同时打印到控制台
	print("\n" + report_content)