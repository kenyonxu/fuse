extends Node

## AudioBinding 单元测试
##
## 测试音频绑定资源的所有功能

# 动态加载 AudioBinding 类（支持 headless 模式）
var AudioBindingClass: Script = load("res://addons/juicy_mixer/resources/audio/audio_binding.gd")
var AudioEventResourceClass: Script = load("res://addons/juicy_mixer/resources/audio/audio_event_resource.gd")

func _ready():
	print("\n=== AudioBinding 测试开始 ===\n")

	test_basic_binding()
	await get_tree().process_frame
	test_cooldown()
	await get_tree().process_frame
	test_reset_cooldown()
	await get_tree().process_frame

	print("\n=== 所有 AudioBinding 测试通过! ===\n")

## 测试1: 基础属性设置
func test_basic_binding():
	print("测试1: test_basic_binding")

	var binding = AudioBindingClass.new()
	assert(binding != null, "应该能创建 AudioBinding")

	# 设置基础属性
	binding.signal_name = "test_signal"
	assert(binding.signal_name == "test_signal", "signal_name 应该被正确设置")

	# 创建简单的音频事件
	var audio_event = AudioEventResourceClass.new()
	audio_event.event_name = "test_audio_event"
	binding.audio_event = audio_event
	assert(binding.audio_event != null, "audio_event 应该被正确设置")

	# 设置高级属性
	binding.adv_cooldown = 1.0
	assert(binding.adv_cooldown == 1.0, "adv_cooldown 应该被正确设置")

	binding.adv_delay = 0.5
	assert(binding.adv_delay == 0.5, "adv_delay 应该被正确设置")

	binding.adv_volume_override = 1.5
	assert(binding.adv_volume_override == 1.5, "adv_volume_override 应该被正确设置")

	# 验证
	var validation = binding.validate()
	assert(validation.valid, "验证应该通过: " + str(validation.issues))

	print("  ✓ test_basic_binding 通过")

## 测试2: 冷却机制
func test_cooldown():
	print("测试2: test_cooldown")

	var binding = AudioBindingClass.new()
	binding.signal_name = "cooldown_test"
	binding.audio_event = AudioEventResourceClass.new()
	binding.adv_cooldown = 0.5  # 500ms 冷却

	# 初始状态应该可以播放
	assert(binding.can_play(), "初始状态应该可以播放")

	# 标记为已播放
	binding.mark_played()

	# 立即检查,应该不能播放
	assert(not binding.can_play(), "播放后立即检查应该被冷却阻止")

	# 等待冷却时间
	await get_tree().create_timer(0.6).timeout

	# 冷却结束后应该可以播放
	assert(binding.can_play(), "冷却结束后应该可以播放")

	print("  ✓ test_cooldown 通过")

## 测试3: 重置冷却
func test_reset_cooldown():
	print("测试3: test_reset_cooldown")

	var binding = AudioBindingClass.new()
	binding.signal_name = "reset_test"
	binding.audio_event = AudioEventResourceClass.new()
	binding.adv_cooldown = 1.0  # 1秒冷却

	# 初始可以播放
	assert(binding.can_play(), "初始状态应该可以播放")

	# 标记为已播放
	binding.mark_played()

	# 立即检查,应该不能播放
	assert(not binding.can_play(), "播放后立即检查应该被冷却阻止")

	# 重置冷却
	binding.reset_cooldown()

	# 重置后应该可以播放
	assert(binding.can_play(), "重置冷却后应该可以播放")

	print("  ✓ test_reset_cooldown 通过")
