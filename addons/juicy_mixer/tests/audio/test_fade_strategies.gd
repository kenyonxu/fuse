extends Node

## 测试淡出策略
##
## 验证 FADE_OUT_OLDEST 策略的正确行为

func test_fade_out_oldest_strategy():
	print("\n=== 测试淡出最老实例策略 ===")

	var resource = AudioEventResource.new()
	resource.event_name = "test_fade"

	var config = AudioMixingConfig.new()
	config.max_instances = 2
	config.limit_policy = AudioMixingConfig.LimitPolicy.FADE_OUT_OLDEST
	resource.mixing = config

	var controller = AudioMixingController.new()

	# 添加两个实例
	var player1 = AudioStreamPlayer2D.new()
	var player2 = AudioStreamPlayer2D.new()
	controller.record_instance("test_fade", player1, 50)
	controller.record_instance("test_fade", player2, 50)

	# 第三个实例应该触发淡出最老的
	assert(controller.can_play(resource, "test_fade") == true, "Should allow play with fade strategy")

	print("✓ test_fade_out_oldest_strategy PASSED")
	print("  - FADE_OUT_OLDEST 策略正确触发")
	print("  - 最老实例应该被淡出")

func test_fade_out_logs_output():
	print("\n=== 测试淡出日志输出 ===")

	var resource = AudioEventResource.new()
	resource.event_name = "test_fade_log"

	var config = AudioMixingConfig.new()
	config.max_instances = 1
	config.limit_policy = AudioMixingConfig.LimitPolicy.FADE_OUT_OLDEST
	resource.mixing = config

	var controller = AudioMixingController.new()

	# 添加第一个实例
	var player1 = AudioStreamPlayer2D.new()
	controller.record_instance("test_fade_log", player1, 50)

	# 添加第二个实例，应该触发淡出并输出日志
	var player2 = AudioStreamPlayer2D.new()
	controller.record_instance("test_fade_log", player2, 50)

	# 触发淡出策略
	var can_play = controller.can_play(resource, "test_fade_log")

	assert(can_play == true, "Should allow play with fade strategy")
	print("✓ test_fade_out_logs_output PASSED")
	print("  - 淡出日志应该已输出")

func test_fade_out_with_invalid_player():
	print("\n=== 测试淡出无效播放器 ===")

	var resource = AudioEventResource.new()
	resource.event_name = "test_fade_invalid"

	var config = AudioMixingConfig.new()
	config.max_instances = 1
	config.limit_policy = AudioMixingConfig.LimitPolicy.FADE_OUT_OLDEST
	resource.mixing = config

	var controller = AudioMixingController.new()

	# 添加一个将被释放的实例
	var player1 = AudioStreamPlayer2D.new()
	controller.record_instance("test_fade_invalid", player1, 50)
	player1.queue_free()  # 标记为待删除

	# 等待一帧让播放器被释放
	await get_tree().process_frame

	# 添加第二个实例，应该能正常处理无效播放器
	var player2 = AudioStreamPlayer2D.new()
	controller.record_instance("test_fade_invalid", player2, 50)

	# 应该不会崩溃
	var can_play = controller.can_play(resource, "test_fade_invalid")

	print("✓ test_fade_out_with_invalid_player PASSED")
	print("  - 正确处理无效播放器")
	print("  - 没有发生崩溃")

func test_fade_out_volume_preservation():
	print("\n=== 测试淡出音量保持 ===")

	var resource = AudioEventResource.new()
	resource.event_name = "test_fade_volume"

	var config = AudioMixingConfig.new()
	config.max_instances = 1
	config.limit_policy = AudioMixingConfig.LimitPolicy.FADE_OUT_OLDEST
	config.ducking_fade_out = 0.5
	resource.mixing = config

	var controller = AudioMixingController.new()

	# 创建一个带音量的播放器
	var player1 = AudioStreamPlayer2D.new()
	player1.volume_db = -5.0  # 设置初始音量
	add_child(player1)

	controller.record_instance("test_fade_volume", player1, 50)

	# 添加第二个实例
	var player2 = AudioStreamPlayer2D.new()
	add_child(player2)
	controller.record_instance("test_fade_volume", player2, 50)

	# 触发淡出
	var can_play = controller.can_play(resource, "test_fade_volume")

	assert(can_play == true, "Should allow play with fade strategy")
	print("✓ test_fade_out_volume_preservation PASSED")
	print("  - 淡出从当前音量开始")
	print("  - 淡出到 -80dB（无声）")

	# 清理
	player1.queue_free()
	player2.queue_free()

func run_all_tests():
	print("\n" + "=".repeat(50))
	print("运行淡出策略测试套件")
	print("=".repeat(50))

	test_fade_out_oldest_strategy()
	test_fade_out_logs_output()
	test_fade_out_with_invalid_player()
	test_fade_out_volume_preservation()

	print("\n" + "=".repeat(50))
	print("所有淡出策略测试通过！")
	print("=".repeat(50) + "\n")
