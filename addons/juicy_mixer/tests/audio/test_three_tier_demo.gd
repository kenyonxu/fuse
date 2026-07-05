extends Node

## 三层音频架构端到端测试
##
## 完整测试音频管理系统的三层限额架构：
## 1. 实例级限额（7种策略）
## 2. 类别级限额（智能优先级排序）
## 3. 全局级限额（虚声部系统）
## 4. 相位保护机制

var _test_results: Array[Dictionary] = []
var _mock_players: Array[AudioStreamPlayer2D] = []

# =============================================================================
# 测试入口
# =============================================================================

func _ready() -> void:
	print("\n" + "=".repeat(70))
	print("三层音频架构端到端测试")
	print("Three-Tier Audio Architecture End-to-End Test")
	print("=".repeat(70) + "\n")

	await get_tree().process_frame

	run_all_tests()

	print_test_summary()

	await get_tree().create_timer(1.0).timeout
	get_tree().quit()

func run_all_tests() -> void:
	"""运行所有测试"""
	print("开始测试序列...\n")

	# 实例级限额测试
	print("=" .repeat(70))
	print("第一层：实例级限额测试 (Instance-Level Limiting)")
	print("=".repeat(70) + "\n")

	test_fifo_strategy()
	test_lifo_strategy()
	test_priority_strategy()
	test_newest_steals_oldest_strategy()
	test_fade_out_oldest_strategy()
	test_fade_in_newest_strategy()
	test_crossfade_strategy()

	# 类别级限额测试
	print("\n" + "=".repeat(70))
	print("第二层：类别级限额测试 (Category-Level Limiting)")
	print("=".repeat(70) + "\n")

	test_category_limiting()
	test_smart_priority_sorting()
	test_multiple_categories_interaction()
	test_category_priority_override()

	# 全局级限额测试
	print("\n" + "=".repeat(70))
	print("第三层：全局级限额测试 (Global-Level Limiting)")
	print("=".repeat(70) + "\n")

	test_global_voice_limit()
	test_virtual_voice_distance()
	test_virtual_voice_importance()
	test_bus_limits()

	# 相位保护测试
	print("\n" + "=".repeat(70))
	print("相位保护机制测试 (Phase Protection)")
	print("=".repeat(70) + "\n")

	test_phase_cooldown_blocks_fast_repeats()
	test_phase_protection_disabled()

	# 集成测试
	print("\n" + "=".repeat(70))
	print("三层协同工作集成测试 (Integration Tests)")
	print("=".repeat(70) + "\n")

	test_three_tier_collaboration()
	test_real_world_scenario()

# =============================================================================
# 辅助函数
# =============================================================================

func create_mock_player(position: Vector2 = Vector2.ZERO) -> AudioStreamPlayer2D:
	"""创建模拟音频播放器"""
	var player = AudioStreamPlayer2D.new()
	player.position = position
	add_child(player)
	_mock_players.append(player)
	return player

func cleanup_mock_players() -> void:
	"""清理所有模拟播放器"""
	for player in _mock_players:
		if is_instance_valid(player):
			player.queue_free()
	_mock_players.clear()

func record_test(test_name: String, passed: bool, details: String = "") -> void:
	"""记录测试结果"""
	var result = {
		"name": test_name,
		"passed": passed,
		"details": details
	}
	_test_results.append(result)

	var status = "✓ PASS" if passed else "✗ FAIL"
	print("%s: %s" % [status, test_name])
	if not details.is_empty():
		print("    详情: %s" % details)
	print()

func print_test_summary() -> void:
	"""打印测试摘要"""
	print("\n" + "=".repeat(70))
	print("测试摘要 (Test Summary)")
	print("=".repeat(70))

	var passed_count = 0
	var failed_count = 0

	for result in _test_results:
		if result.passed:
			passed_count += 1
		else:
			failed_count += 1

	print("总计: %d 个测试" % _test_results.size())
	print("通过: %d 个" % passed_count)
	print("失败: %d 个" % failed_count)

	if failed_count > 0:
		print("\n失败的测试:")
		for result in _test_results:
			if not result.passed:
				print("  - %s" % result.name)
				if not result.details.is_empty():
					print("    %s" % result.details)

	print("\n" + "=".repeat(70))

# =============================================================================
# 第一层：实例级限额测试 (7种策略)
# =============================================================================

func test_fifo_strategy():
	"""测试 FIFO (First In First Out) 策略"""
	print("测试 FIFO 策略...")

	var resource = AudioEventResource.new()
	resource.event_name = "explosion_fifo"

	var config = AudioMixingConfig.new()
	config.max_instances = 3
	config.limit_policy = AudioMixingConfig.LimitPolicy.FIFO
	resource.mixing = config

	var controller = AudioMixingController.new()

	# 添加 3 个实例
	var player1 = create_mock_player(Vector2(10, 0))
	var player2 = create_mock_player(Vector2(20, 0))
	var player3 = create_mock_player(Vector2(30, 0))

	controller.record_instance("explosion_fifo", player1, 50, resource, Vector3(10, 0, 0))
	controller.record_instance("explosion_fifo", player2, 50, resource, Vector3(20, 0, 0))
	controller.record_instance("explosion_fifo", player3, 50, resource, Vector3(30, 0, 0))

	# 第 4 个应该替换最老的实例
	var player4 = create_mock_player(Vector2(40, 0))
	var can_play = controller.can_play(resource, "explosion_fifo", player4, Vector3(40, 0, 0), 50)

	record_test("FIFO 策略", can_play == true, "第4个实例应该替换最老的实例")

	cleanup_mock_players()

func test_lifo_strategy():
	"""测试 LIFO (Last In First Out) 策略"""
	print("测试 LIFO 策略...")

	var resource = AudioEventResource.new()
	resource.event_name = "explosion_lifo"

	var config = AudioMixingConfig.new()
	config.max_instances = 3
	config.limit_policy = AudioMixingConfig.LimitPolicy.LIFO
	resource.mixing = config

	var controller = AudioMixingController.new()

	# 添加 3 个实例
	var player1 = create_mock_player(Vector2(10, 0))
	var player2 = create_mock_player(Vector2(20, 0))
	var player3 = create_mock_player(Vector2(30, 0))

	controller.record_instance("explosion_lifo", player1, 50, resource, Vector3(10, 0, 0))
	controller.record_instance("explosion_lifo", player2, 50, resource, Vector3(20, 0, 0))
	controller.record_instance("explosion_lifo", player3, 50, resource, Vector3(30, 0, 0))

	# 第 4 个应该被拒绝（LIFO 不替换，只是拒绝）
	var player4 = create_mock_player(Vector2(40, 0))
	var can_play = controller.can_play(resource, "explosion_lifo", player4, Vector3(40, 0, 0), 50)

	record_test("LIFO 策略", can_play == false, "第4个实例应该被拒绝")

	cleanup_mock_players()

func test_priority_strategy():
	"""测试基于优先级的策略"""
	print("测试优先级策略...")

	var resource = AudioEventResource.new()
	resource.event_name = "explosion_priority"

	var config = AudioMixingConfig.new()
	config.max_instances = 3
	config.limit_policy = AudioMixingConfig.LimitPolicy.PRIORITY
	config.priority = 5
	resource.mixing = config

	var controller = AudioMixingController.new()

	# 添加 3 个低优先级实例
	var player1 = create_mock_player(Vector2(10, 0))
	var player2 = create_mock_player(Vector2(20, 0))
	var player3 = create_mock_player(Vector2(30, 0))

	controller.record_instance("explosion_priority", player1, 30, resource, Vector3(10, 0, 0))
	controller.record_instance("explosion_priority", player2, 30, resource, Vector3(20, 0, 0))
	controller.record_instance("explosion_priority", player3, 30, resource, Vector3(30, 0, 0))

	# 高优先级实例应该替换低优先级的
	var player4 = create_mock_player(Vector2(40, 0))
	var can_play = controller.can_play(resource, "explosion_priority", player4, Vector3(40, 0, 0), 90)

	record_test("优先级策略", can_play == true, "高优先级实例应该替换低优先级的")

	cleanup_mock_players()

func test_newest_steals_oldest_strategy():
	"""测试 NEWEST_STEALS_OLDEST 策略"""
	print("测试 NEWEST_STEALS_OLDEST 策略...")

	var resource = AudioEventResource.new()
	resource.event_name = "gunfire_steals"

	var config = AudioMixingConfig.new()
	config.max_instances = 5
	config.limit_policy = AudioMixingConfig.LimitPolicy.NEWEST_STEALS_OLDEST
	resource.mixing = config

	var controller = AudioMixingController.new()

	# 填满所有实例槽
	for i in range(5):
		var player = create_mock_player(Vector2(i * 10, 0))
		controller.record_instance("gunfire_steals", player, 50, resource, Vector3(i * 10, 0, 0))

	# 新实例应该替换最老的
	var new_player = create_mock_player(Vector2(100, 0))
	var can_play = controller.can_play(resource, "gunfire_steals", new_player, Vector3(100, 0, 0), 50)

	record_test("NEWEST_STEALS_OLDEST 策略", can_play == true, "新实例应该替换最老的")

	cleanup_mock_players()

func test_fade_out_oldest_strategy():
	"""测试 FADE_OUT_OLDEST 策略"""
	print("测试 FADE_OUT_OLDEST 策略...")

	var resource = AudioEventResource.new()
	resource.event_name = "explosion_fade_out"

	var config = AudioMixingConfig.new()
	config.max_instances = 3
	config.limit_policy = AudioMixingConfig.LimitPolicy.FADE_OUT_OLDEST
	config.ducking_fade_out = 0.5  # 0.5秒淡出
	resource.mixing = config

	var controller = AudioMixingController.new()

	# 添加实例
	var player1 = create_mock_player(Vector2(10, 0))
	var player2 = create_mock_player(Vector2(20, 0))
	var player3 = create_mock_player(Vector2(30, 0))

	controller.record_instance("explosion_fade_out", player1, 50, resource, Vector3(10, 0, 0))
	controller.record_instance("explosion_fade_out", player2, 50, resource, Vector3(20, 0, 0))
	controller.record_instance("explosion_fade_out", player3, 50, resource, Vector3(30, 0, 0))

	# 新实例应该触发最老的淡出
	var player4 = create_mock_player(Vector2(40, 0))
	var can_play = controller.can_play(resource, "explosion_fade_out", player4, Vector3(40, 0, 0), 50)

	record_test("FADE_OUT_OLDEST 策略", can_play == true, "新实例应该触发最老的淡出")

	cleanup_mock_players()

func test_fade_in_newest_strategy():
	"""测试 FADE_IN_NEWEST 策略"""
	print("测试 FADE_IN_NEWEST 策略...")

	var resource = AudioEventResource.new()
	resource.event_name = "explosion_fade_in"

	var config = AudioMixingConfig.new()
	config.max_instances = 3
	config.limit_policy = AudioMixingConfig.LimitPolicy.FADE_IN_NEWEST
	config.ducking_fade_in = 0.3  # 0.3秒淡入
	resource.mixing = config

	var controller = AudioMixingController.new()

	# 添加实例
	var player1 = create_mock_player(Vector2(10, 0))
	var player2 = create_mock_player(Vector2(20, 0))
	var player3 = create_mock_player(Vector2(30, 0))

	controller.record_instance("explosion_fade_in", player1, 50, resource, Vector3(10, 0, 0))
	controller.record_instance("explosion_fade_in", player2, 50, resource, Vector3(20, 0, 0))
	controller.record_instance("explosion_fade_in", player3, 50, resource, Vector3(30, 0, 0))

	# 新实例应该淡入
	var player4 = create_mock_player(Vector2(40, 0))
	var can_play = controller.can_play(resource, "explosion_fade_in", player4, Vector3(40, 0, 0), 50)

	record_test("FADE_IN_NEWEST 策略", can_play == true, "新实例应该淡入")

	cleanup_mock_players()

func test_crossfade_strategy():
	"""测试 CROSSFADE 策略"""
	print("测试 CROSSFADE 策略...")

	var resource = AudioEventResource.new()
	resource.event_name = "ambient_crossfade"

	var config = AudioMixingConfig.new()
	config.max_instances = 2
	config.limit_policy = AudioMixingConfig.LimitPolicy.CROSSFADE
	config.ducking_fade_out = 0.5
	config.ducking_fade_in = 0.5
	resource.mixing = config

	var controller = AudioMixingController.new()

	# 添加实例
	var player1 = create_mock_player(Vector2(10, 0))
	var player2 = create_mock_player(Vector2(20, 0))

	controller.record_instance("ambient_crossfade", player1, 50, resource, Vector3(10, 0, 0))
	controller.record_instance("ambient_crossfade", player2, 50, resource, Vector3(20, 0, 0))

	# 新实例应该触发交叉淡入淡出
	var player3 = create_mock_player(Vector2(30, 0))
	var can_play = controller.can_play(resource, "ambient_crossfade", player3, Vector3(30, 0, 0), 50)

	record_test("CROSSFADE 策略", can_play == true, "新实例应该触发交叉淡入淡出")

	cleanup_mock_players()

# =============================================================================
# 第二层：类别级限额测试
# =============================================================================

func test_category_limiting():
	"""测试类别限额"""
	print("测试类别限额...")

	var resource = AudioEventResource.new()
	resource.event_name = "explosion"

	var category = AudioCategory.new()
	category.category_name = "Explosions"
	category.max_instances = 2
	category.category_priority = AudioCategory.AudioCategoryPriority.HIGH

	resource.categories.append(category)

	var config = AudioMixingConfig.new()
	config.max_instances = 10  # 实例级限额较大
	resource.mixing = config

	var controller = AudioMixingController.new()

	# 添加 2 个类别实例
	var player1 = create_mock_player(Vector2(10, 0))
	var player2 = create_mock_player(Vector2(20, 0))
	controller.record_instance("explosion", player1, 50, resource, Vector3(10, 0, 0))
	controller.record_instance("explosion", player2, 50, resource, Vector3(20, 0, 0))

	# 第 3 个应该被类别限额阻止
	var player3 = create_mock_player(Vector2(30, 0))
	var result = controller.can_play(resource, "explosion", player3, Vector3(30, 0, 0), 50)

	record_test("类别限额阻止", result == false, "第3个实例应该被类别限额阻止")

	cleanup_mock_players()

func test_smart_priority_sorting():
	"""测试智能优先级排序（距离 40% + 重要性 40% + 最近 20%）"""
	print("测试智能优先级排序...")

	var resource = AudioEventResource.new()
	resource.event_name = "gunshot"

	var category = AudioCategory.new()
	category.category_name = "Combat"
	category.max_instances = 2
	# 默认权重：距离 40%, 重要性 40%, 最近 20%

	resource.categories.append(category)

	var config = AudioMixingConfig.new()
	config.max_instances = 10
	resource.mixing = config

	var controller = AudioMixingController.new()

	# 添加 2 个远距离、低重要性实例
	var player1 = create_mock_player(Vector2(100, 0))
	var player2 = create_mock_player(Vector2(100, 0))
	controller.record_instance("gunshot", player1, 30, resource, Vector3(100, 0, 0))
	controller.record_instance("gunshot", player2, 30, resource, Vector3(100, 0, 0))

	# 第 3 个近距离、高重要性实例应该替换远距离的
	var player3 = create_mock_player(Vector2(5, 0))
	var can_play = controller.can_play(resource, "gunshot", player3, Vector3(5, 0, 0), 90)

	record_test("智能优先级排序", can_play == true, "近距离高重要性实例应该替换远距离低重要性的")

	cleanup_mock_players()

func test_multiple_categories_interaction():
	"""测试多个类别的交互"""
	print("测试多类别交互...")

	var resource = AudioEventResource.new()
	resource.event_name = "explosion"

	# 类别 1：爆炸
	var category1 = AudioCategory.new()
	category1.category_name = "Explosions"
	category1.max_instances = 2

	# 类别 2：战斗音效
	var category2 = AudioCategory.new()
	category2.category_name = "Combat"
	category2.max_instances = 5

	resource.categories.append(category1)
	resource.categories.append(category2)

	var config = AudioMixingConfig.new()
	config.max_instances = 10
	resource.mixing = config

	var controller = AudioMixingController.new()

	# 填满 Explosions 类别
	var player1 = create_mock_player(Vector2(10, 0))
	var player2 = create_mock_player(Vector2(20, 0))
	controller.record_instance("explosion", player1, 50, resource, Vector3(10, 0, 0))
	controller.record_instance("explosion", player2, 50, resource, Vector3(20, 0, 0))

	# 第 3 个应该被 Explosions 类别限额阻止（即使 Combat 类别未满）
	var player3 = create_mock_player(Vector2(30, 0))
	var result = controller.can_play(resource, "explosion", player3, Vector3(30, 0, 0), 50)

	record_test("多类别交互", result == false, "应该被最严格的类别限额阻止")

	cleanup_mock_players()

func test_category_priority_override():
	"""测试类别优先级覆盖"""
	print("测试类别优先级覆盖...")

	var resource_low = AudioEventResource.new()
	resource_low.event_name = "ambient_low"

	var category_low = AudioCategory.new()
	category_low.category_name = "Ambient"
	category_low.max_instances = 3
	category_low.category_priority = AudioCategory.AudioCategoryPriority.LOW

	resource_low.categories.append(category_low)

	var resource_high = AudioEventResource.new()
	resource_high.event_name = "alert_high"

	var category_high = AudioCategory.new()
	category_high.category_name = "Alerts"
	category_high.max_instances = 3
	category_high.category_priority = AudioCategory.AudioCategoryPriority.CRITICAL

	resource_high.categories.append(category_high)

	var config = AudioMixingConfig.new()
	config.max_instances = 10
	resource_low.mixing = config
	resource_high.mixing = config

	var controller = AudioMixingController.new()

	# 填满低优先级类别
	for i in range(3):
		var player = create_mock_player(Vector2(i * 10, 0))
		controller.record_instance("ambient_low", player, 50, resource_low, Vector3(i * 10, 0, 0))

	# 高优先级事件应该能够播放（即使低优先级类别已满）
	var player_high = create_mock_player(Vector2(100, 0))
	var can_play = controller.can_play(resource_high, "alert_high", player_high, Vector3(100, 0, 0), 50)

	record_test("类别优先级覆盖", can_play == true, "高优先级事件应该能够播放")

	cleanup_mock_players()

# =============================================================================
# 第三层：全局级限额测试
# =============================================================================

func test_global_voice_limit():
	"""测试全局声部限制"""
	print("测试全局声部限制...")

	var global_config = GlobalAudioLimitConfig.new()
	global_config.max_total_voices = 5  # 限制为 5 个真实声部

	# 创建多个音频事件资源
	var resources: Array[AudioEventResource] = []
	for i in range(10):
		var resource = AudioEventResource.new()
		resource.event_name = "sound_%d" % i

		var config = AudioMixingConfig.new()
		config.max_instances = 10
		resource.mixing = config

		resources.append(resource)

	# 模拟播放超过全局限制的音效
	var controller = AudioMixingController.new()
	var play_count = 0

	for i in range(10):
		var player = create_mock_player(Vector2(i * 10, 0))
		var can_play = controller.can_play(resources[i], "sound_%d" % i, player, Vector3(i * 10, 0, 0), 50)
		if can_play:
			play_count += 1
			controller.record_instance("sound_%d" % i, player, 50, resources[i], Vector3(i * 10, 0, 0))

	# 应该限制在全局范围内
	record_test("全局声部限制", play_count <= 5, "播放数量应该被全局限制在5个以内")

	cleanup_mock_players()

func test_virtual_voice_distance():
	"""测试基于距离的虚声部转换"""
	print("测试虚声部距离转换...")

	var global_config = GlobalAudioLimitConfig.new()
	global_config.virtual_voice_enabled = true
	global_config.virtual_max_distance = 50.0  # 50米后转为虚声部

	var manager = VirtualVoiceManager.new()
	manager.set_global_config(global_config)

	var resource = AudioEventResource.new()
	resource.event_name = "distant_explosion"

	# 远距离音效应该创建虚声部
	var info = manager.check_virtual_voice(resource, Vector3(100, 0, 0), 50, global_config)

	var passed = info != null and info.is_virtual == true
	record_test("虚声部距离转换", passed, "远距离音效应该创建虚声部")

func test_virtual_voice_importance():
	"""测试基于重要性的虚声部转换"""
	print("测试虚声部重要性转换...")

	var global_config = GlobalAudioLimitConfig.new()
	global_config.virtual_voice_enabled = true
	global_config.virtual_min_importance = 60  # 重要性低于60转为虚声部

	var manager = VirtualVoiceManager.new()
	manager.set_global_config(global_config)

	var resource = AudioEventResource.new()
	resource.event_name = "unimportant_sound"

	# 低重要性音效应该创建虚声部
	var info = manager.check_virtual_voice(resource, Vector3(10, 0, 0), 30, global_config)

	var passed = info != null and info.is_virtual == true
	record_test("虚声部重要性转换", passed, "低重要性音效应该创建虚声部")

func test_bus_limits():
	"""测试总线级限制"""
	print("测试总线级限制...")

	var global_config = GlobalAudioLimitConfig.new()
	global_config.bus_limits = {
		"Master": 64,
		"SFX": 10,
		"Music": 2
	}

	# 测试 SFX 总线限制
	var sfx_limit = global_config.get_bus_limit("SFX")
	var music_limit = global_config.get_bus_limit("Music")
	var master_limit = global_config.get_bus_limit("Master")

	var passed = sfx_limit == 10 and music_limit == 2 and master_limit == 64
	record_test("总线级限制", passed, "总线限制应该正确配置")

# =============================================================================
# 相位保护测试
# =============================================================================

func test_phase_cooldown_blocks_fast_repeats():
	"""测试相位冷却阻止快速重复"""
	print("测试相位冷却...")

	var resource = AudioEventResource.new()
	resource.event_name = "test_phase"
	resource.anti_phase_cancellation = true
	resource.phase_cooldown = 0.1  # 100ms

	var config = AudioMixingConfig.new()
	config.max_instances = 10
	resource.mixing = config

	var controller = AudioMixingController.new()

	# 第一次播放应该通过
	var result1 = controller.can_play(resource, "test_phase")
	var first_pass = result1 == true

	# 立即第二次播放应该被阻止
	var result2 = controller.can_play(resource, "test_phase")
	var second_blocked = result2 == false

	var passed = first_pass and second_blocked
	record_test("相位冷却阻止快速重复", passed, "第一次通过，第二次被阻止")

func test_phase_protection_disabled():
	"""测试禁用相位保护"""
	print("测试禁用相位保护...")

	var resource = AudioEventResource.new()
	resource.event_name = "test_no_phase"
	resource.anti_phase_cancellation = false  # 禁用相位保护

	var config = AudioMixingConfig.new()
	config.max_instances = 10
	resource.mixing = config

	var controller = AudioMixingController.new()

	# 连续播放都应该通过
	var result1 = controller.can_play(resource, "test_no_phase")
	var result2 = controller.can_play(resource, "test_no_phase")
	var result3 = controller.can_play(resource, "test_no_phase")

	var passed = result1 == true and result2 == true and result3 == true
	record_test("禁用相位保护", passed, "所有播放都应该通过")

# =============================================================================
# 集成测试
# =============================================================================

func test_three_tier_collaboration():
	"""测试三层协同工作"""
	print("测试三层协同工作...")

	var global_config = GlobalAudioLimitConfig.new()
	global_config.max_total_voices = 20
	global_config.virtual_voice_enabled = true

	var resource = AudioEventResource.new()
	resource.event_name = "explosion"
	resource.anti_phase_cancellation = true
	resource.phase_cooldown = 0.05

	# 实例级配置
	var mixing_config = AudioMixingConfig.new()
	mixing_config.max_instances = 5
	mixing_config.limit_policy = AudioMixingConfig.LimitPolicy.PRIORITY
	resource.mixing = mixing_config

	# 类别级配置
	var category = AudioCategory.new()
	category.category_name = "Explosions"
	category.max_instances = 3
	category.category_priority = AudioCategory.AudioCategoryPriority.HIGH
	resource.categories.append(category)

	var controller = AudioMixingController.new()

	# 测试三层限额协同工作
	var play_count = 0
	var blocked_by_phase = 0
	var blocked_by_category = 0
	var blocked_by_instance = 0

	for i in range(10):
		var player = create_mock_player(Vector2(i * 5, 0))
		var can_play = controller.can_play(resource, "explosion", player, Vector3(i * 5, 0, 0), 50)

		if can_play:
			play_count += 1
			controller.record_instance("explosion", player, 50, resource, Vector3(i * 5, 0, 0))
		else:
			# 分析被阻止的原因
			var instances = controller._active_instances.get("explosion", [])
			if instances.size() >= mixing_config.max_instances:
				blocked_by_instance += 1
			else:
				blocked_by_category += 1

	# 等待相位冷却
	await get_tree().create_timer(0.1).timeout

	# 再次尝试播放
	var player_late = create_mock_player(Vector2(100, 0))
	var can_play_late = controller.can_play(resource, "explosion", player_late, Vector3(100, 0, 0), 50)

	var passed = play_count <= 5 and can_play_late == true
	var details = "播放了 %d 个实例，相位冷却后可以再次播放" % play_count

	record_test("三层协同工作", passed, details)

	cleanup_mock_players()

func test_real_world_scenario():
	"""测试真实游戏场景"""
	print("测试真实游戏场景...")

	# 模拟战斗场景
	var global_config = GlobalAudioLimitConfig.new()
	global_config.max_total_voices = 32
	global_config.virtual_voice_enabled = true
	global_config.virtual_max_distance = 40.0

	var controller = AudioMixingController.new()

	# 1. 枪声（高频，优先级高）
	var gunshot_resource = AudioEventResource.new()
	gunshot_resource.event_name = "gunshot"
	gunshot_resource.anti_phase_cancellation = true
	gunshot_resource.phase_cooldown = 0.03

	var gunshot_config = AudioMixingConfig.new()
	gunshot_config.max_instances = 8
	gunshot_config.limit_policy = AudioMixingConfig.LimitPolicy.NEWEST_STEALS_OLDEST
	gunshot_resource.mixing = gunshot_config

	var gunshot_category = AudioCategory.new()
	gunshot_category.category_name = "Combat"
	gunshot_category.max_instances = 5
	gunshot_category.category_priority = AudioCategory.AudioCategoryPriority.HIGH
	gunshot_resource.categories.append(gunshot_category)

	# 2. 脚步声（中频，优先级中）
	var footstep_resource = AudioEventResource.new()
	footstep_resource.event_name = "footstep"
	footstep_resource.anti_phase_cancellation = true
	footstep_resource.phase_cooldown = 0.15

	var footstep_config = AudioMixingConfig.new()
	footstep_config.max_instances = 4
	footstep_config.limit_policy = AudioMixingConfig.LimitPolicy.FIFO
	footstep_resource.mixing = footstep_config

	var footstep_category = AudioCategory.new()
	footstep_category.category_name = "Footsteps"
	footstep_category.max_instances = 2
	footstep_category.category_priority = AudioCategory.AudioCategoryPriority.MEDIUM
	footstep_resource.categories.append(footstep_category)

	# 3. 爆炸声（低频，优先级高）
	var explosion_resource = AudioEventResource.new()
	explosion_resource.event_name = "explosion"

	var explosion_config = AudioMixingConfig.new()
	explosion_config.max_instances = 3
	explosion_config.limit_policy = AudioMixingConfig.LimitPolicy.PRIORITY
	explosion_resource.mixing = explosion_config

	var explosion_category = AudioCategory.new()
	explosion_category.category_name = "Explosions"
	explosion_category.max_instances = 2
	explosion_category.category_priority = AudioCategory.AudioCategoryPriority.CRITICAL
	explosion_resource.categories.append(explosion_category)

	# 模拟战斗序列
	var sounds_played = 0

	# 快速连射（10发）
	for i in range(10):
		var player = create_mock_player(Vector2(i * 2, 0))
		if controller.can_play(gunshot_resource, "gunshot", player, Vector3(i * 2, 0, 0), 80):
			sounds_played += 1
			controller.record_instance("gunshot", player, 80, gunshot_resource, Vector3(i * 2, 0, 0))

	# 脚步声
	for i in range(5):
		var player = create_mock_player(Vector2(20 + i * 3, 0))
		if controller.can_play(footstep_resource, "footstep", player, Vector3(20 + i * 3, 0, 0), 50):
			sounds_played += 1
			controller.record_instance("footstep", player, 50, footstep_resource, Vector3(20 + i * 3, 0, 0))

	# 爆炸
	for i in range(3):
		var player = create_mock_player(Vector2(50 + i * 10, 0))
		if controller.can_play(explosion_resource, "explosion", player, Vector3(50 + i * 10, 0, 0), 90):
			sounds_played += 1
			controller.record_instance("explosion", player, 90, explosion_resource, Vector3(50 + i * 10, 0, 0))

	# 验证：应该播放了一些声音，但不是全部（因为限额）
	var passed = sounds_played > 0 and sounds_played < 18  # 总共18个声音，但受限于各类别限额
	var details = "在真实战斗场景中播放了 %d 个声音（总共18个请求）" % sounds_played

	record_test("真实游戏场景", passed, details)

	cleanup_mock_players()
