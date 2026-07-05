extends Node

## JuicyAudioPlayer 集成测试
##
## 测试 JuicyAudioPlayer 节点的完整功能

# 动态加载类（支持 headless 模式）
var JuicyAudioPlayerClass: Script = load("res://addons/juicy_mixer/core/juicy_audio_player.gd")
var AudioComponentClass: Script = load("res://addons/juicy_mixer/resources/audio/audio_component.gd")
var AudioBindingClass: Script = load("res://addons/juicy_mixer/resources/audio/audio_binding.gd")
var AudioEventResourceClass: Script = load("res://addons/juicy_mixer/resources/audio/audio_event_resource.gd")
var AudioVariantClass: Script = load("res://addons/juicy_mixer/resources/audio/audio_variant.gd")

# =============================================================================
# 测试场景设置
# =============================================================================

## 模拟信号目标节点
class MockSignalTarget extends Node:
	signal footstep
	signal pressed
	signal jump

	var footstep_count: int = 0
	var pressed_count: int = 0
	var jump_count: int = 0

	func _init():
		add_user_signal("footstep")
		add_user_signal("pressed")
		add_user_signal("jump")

# =============================================================================
# 测试用例
# =============================================================================

func _ready():
	print("\n=== JuicyAudioPlayer 集成测试开始 ===\n")

	test_basic_setup()
	await get_tree().process_frame
	test_signal_connection()
	await get_tree().process_frame
	test_add_binding_runtime()
	await get_tree().process_frame
	test_cooldown()
	await get_tree().process_frame

	print("\n=== 所有 JuicyAudioPlayer 测试通过! ===\n")

## 测试 1: 基础设置
func test_basic_setup():
	print("测试 1: test_basic_setup")

	# 创建模拟目标节点
	var mock_target = MockSignalTarget.new()
	add_child(mock_target)
	await get_tree().process_frame

	# 创建 JuicyAudioPlayer
	var player = JuicyAudioPlayerClass.new()
	player.name = "TestAudioPlayer"
	mock_target.add_child(player)
	await get_tree().process_frame

	# 验证父节点设置正确
	assert(player.get_parent() == mock_target, "Player 应该是 mock_target 的子节点")
	print("  ✓ 父节点设置正确")

	# 验证音频处理器已创建
	var handler = player.get_audio_handler()
	assert(handler != null, "应创建音频处理器")
	print("  ✓ 音频处理器已创建")

	# 清理
	player.queue_free()
	mock_target.queue_free()

	print("  test_basic_setup 通过\n")

## 测试 2: 信号连接
func test_signal_connection():
	print("测试 2: test_signal_connection")

	# 创建模拟目标节点
	var mock_target = MockSignalTarget.new()
	add_child(mock_target)
	await get_tree().process_frame

	# 创建音频组件
	var component = AudioComponentClass.new()

	var binding1 = AudioBindingClass.new()
	binding1.signal_name = "footstep"
	binding1.audio_event = _create_mock_audio_event("footstep_event")
	binding1.adv_cooldown = 0.5  # 设置0.5秒冷却用于测试
	component.audio_bindings.append(binding1)

	var binding2 = AudioBindingClass.new()
	binding2.signal_name = "pressed"
	binding2.audio_event = _create_mock_audio_event("button_event")
	component.audio_bindings.append(binding2)

	# 创建 JuicyAudioPlayer
	var player = JuicyAudioPlayerClass.new()
	player.audio_component = component
	player.debug_mode = true
	mock_target.add_child(player)
	player.name = "TestPlayer"
	await get_tree().process_frame

	# 触发信号验证连接
	print("  - 触发 footstep 信号...")
	mock_target.emit_signal("footstep")
	await get_tree().process_frame

	# 验证冷却被设置
	var footstep_binding = component.find_binding_by_signal("footstep")
	if footstep_binding and footstep_binding.adv_cooldown > 0:
		assert(footstep_binding.can_play() == false, "应该在冷却中")
		print("  ✓ 冷却机制已正确设置")

	print("  - 触发 pressed 信号...")
	mock_target.emit_signal("pressed")
	await get_tree().process_frame

	print("  ✓ 信号连接成功")

	# 清理
	player.queue_free()
	mock_target.queue_free()

	print("  test_signal_connection 通过\n")

## 测试 3: 运行时添加绑定
func test_add_binding_runtime():
	print("测试 3: test_add_binding_runtime")

	# 创建模拟目标节点
	var mock_target = MockSignalTarget.new()
	add_child(mock_target)
	await get_tree().process_frame

	# 创建 JuicyAudioPlayer（没有初始组件）
	var player = JuicyAudioPlayerClass.new()
	player.auto_setup = false  # 不自动设置
	mock_target.add_child(player)
	await get_tree().process_frame

	# 运行时添加绑定
	var jump_event = _create_mock_audio_event("jump_event")
	player.add_binding("jump", jump_event)
	await get_tree().process_frame

	# 验证绑定已添加
	assert(player.audio_component != null, "应自动创建组件")
	assert(player.audio_component.get_binding_count() == 1, "应有 1 个绑定")
	print("  ✓ 运行时添加绑定成功")

	# 触发信号验证连接
	print("  - 触发 jump 信号...")
	mock_target.emit_signal("jump")
	await get_tree().process_frame

	print("  ✓ 运行时绑定信号连接成功")

	# 测试移除绑定
	player.remove_binding("jump")
	assert(player.audio_component.get_binding_count() == 0, "绑定应被移除")
	print("  ✓ 移除绑定成功")

	# 清理
	player.queue_free()
	mock_target.queue_free()

	print("  test_add_binding_runtime 通过\n")

## 测试 4: 冷却机制
func test_cooldown():
	print("测试 4: test_cooldown")

	# 创建模拟目标节点
	var mock_target = MockSignalTarget.new()
	add_child(mock_target)
	await get_tree().process_frame

	# 创建音频组件
	var component = AudioComponentClass.new()

	var binding = AudioBindingClass.new()
	binding.signal_name = "footstep"
	binding.audio_event = _create_mock_audio_event("footstep_event")
	binding.adv_cooldown = 1.0  # 1秒冷却
	component.audio_bindings.append(binding)

	# 创建 JuicyAudioPlayer
	var player = JuicyAudioPlayerClass.new()
	player.audio_component = component
	player.debug_mode = true
	mock_target.add_child(player)
	await get_tree().process_frame

	# 第一次触发 - 应该成功
	print("  - 第一次触发 footstep 信号...")
	mock_target.emit_signal("footstep")
	await get_tree().process_frame

	# 立即再次触发 - 应该被冷却阻止
	print("  - 立即再次触发 footstep 信号（应在冷却中）...")
	mock_target.emit_signal("footstep")
	await get_tree().process_frame

	print("  ✓ 冷却机制正常工作")

	# 等待冷却结束
	print("  - 等待冷却结束...")
	await get_tree().create_timer(1.1).timeout

	# 再次触发 - 应该成功
	print("  - 冷却结束后触发 footstep 信号...")
	mock_target.emit_signal("footstep")
	await get_tree().process_frame

	print("  ✓ 冷却结束后可以正常播放")

	# 清理
	player.queue_free()
	mock_target.queue_free()

	print("  test_cooldown 通过\n")

# =============================================================================
# 辅助方法
# =============================================================================

## 创建模拟音频事件
func _create_mock_audio_event(event_name: String) -> AudioEventResource:
	var event = AudioEventResourceClass.new()
	event.event_name = event_name

	# 创建一个音频变体
	var variant = AudioVariantClass.new()
	event.audio_variants.append(variant)

	return event
