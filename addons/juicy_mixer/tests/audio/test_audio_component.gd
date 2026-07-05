extends Node

## AudioComponent 单元测试
##
## 测试 AudioComponent 资源类的功能

# 动态加载类（支持 headless 模式）
var AudioComponentClass: Script = load("res://addons/juicy_mixer/resources/audio/audio_component.gd")
var AudioBindingClass: Script = load("res://addons/juicy_mixer/resources/audio/audio_binding.gd")
var AudioEventResourceClass: Script = load("res://addons/juicy_mixer/resources/audio/audio_event_resource.gd")

# =============================================================================
# 测试场景设置
# =============================================================================

## 模拟音频播放器（用于测试）
class MockAudioPlayer extends Node:
	var triggered_bindings: Array = []

	func _on_binding_triggered(binding):
		triggered_bindings.append(binding)

## 模拟信号目标节点
class MockSignalTarget extends Node:
	signal footstep
	signal pressed
	signal custom_signal

# =============================================================================
# 测试用例
# =============================================================================

func _ready():
	print("\n=== AudioComponent 测试开始 ===\n")

	test_empty_component()
	await get_tree().process_frame
	test_add_binding()
	await get_tree().process_frame
	test_find_binding()
	await get_tree().process_frame
	test_factory_methods()
	await get_tree().process_frame
	test_setup_signal_connections()
	await get_tree().process_frame
	test_duplicate_setup_prevention()
	await get_tree().process_frame

	print("\n=== 所有 AudioComponent 测试通过! ===\n")

## 测试 1: 空组件验证
func test_empty_component():
	print("测试 1: test_empty_component")

	var component = AudioComponentClass.new()
	assert(component.get_binding_count() == 0, "新组件应有 0 个绑定")
	print("  ✓ 新组件绑定数量为 0")

	var validation = component.validate()
	assert(validation.valid, "空组件应有效（只有警告）")
	assert(validation.warnings.size() > 0, "空组件应有警告")
	print("  ✓ 空组件验证通过")

	print("  test_empty_component 通过\n")

## 测试 2: 添加绑定
func test_add_binding():
	print("测试 2: test_add_binding")

	var component = AudioComponentClass.new()
	var binding = AudioBindingClass.new()
	binding.signal_name = "test_signal"
	binding.audio_event = AudioEventResourceClass.new()  # 添加音频事件以通过验证

	component.audio_bindings.append(binding)
	assert(component.get_binding_count() == 1, "组件应有 1 个绑定")
	print("  ✓ 成功添加绑定")

	# 验证组件
	var validation = component.validate()
	assert(validation.valid, "带有有效绑定的组件应有效")
	print("  ✓ 带绑定的组件验证通过")

	print("  test_add_binding 通过\n")

## 测试 3: 查找绑定
func test_find_binding():
	print("测试 3: test_find_binding")

	var component = AudioComponentClass.new()

	# 添加多个绑定
	var binding1 = AudioBindingClass.new()
	binding1.signal_name = "footstep"
	component.audio_bindings.append(binding1)

	var binding2 = AudioBindingClass.new()
	binding2.signal_name = "pressed"
	component.audio_bindings.append(binding2)

	# 测试查找存在的绑定
	var found = component.find_binding_by_signal("footstep")
	assert(found != null, "应找到 footstep 绑定")
	assert(found.signal_name == "footstep", "找到的绑定信号名应匹配")
	print("  ✓ 成功找到存在的绑定")

	# 测试查找不存在的绑定
	var not_found = component.find_binding_by_signal("nonexistent")
	assert(not_found == null, "不应找到不存在的绑定")
	print("  ✓ 正确处理不存在的绑定")

	print("  test_find_binding 通过\n")

## 测试 4: 工厂方法
func test_factory_methods():
	print("测试 4: test_factory_methods")

	# 测试脚步声组件工厂
	var footstep_component = AudioComponentClass.create_footstep_component()
	assert(footstep_component != null, "工厂应返回有效组件")
	assert(footstep_component.get_binding_count() == 1, "脚步声组件应有 1 个绑定")
	assert(footstep_component.audio_bindings[0].signal_name == "footstep", "信号名应为 footstep")
	assert(footstep_component.audio_bindings[0].adv_cooldown == 0.3, "冷却时间应为 0.3")
	print("  ✓ create_footstep_component 工厂方法正确")

	# 测试 UI 按钮组件工厂
	var mock_event = AudioEventResourceClass.new()
	var button_component = AudioComponentClass.create_ui_button_component(mock_event)
	assert(button_component != null, "工厂应返回有效组件")
	assert(button_component.get_binding_count() == 1, "按钮组件应有 1 个绑定")
	assert(button_component.audio_bindings[0].signal_name == "pressed", "信号名应为 pressed")
	assert(button_component.audio_bindings[0].audio_event == mock_event, "音频事件应匹配")
	print("  ✓ create_ui_button_component 工厂方法正确")

	print("  test_factory_methods 通过\n")

## 测试 5: Setup 方法（信号连接）
func test_setup_signal_connections():
	print("测试 5: test_setup_signal_connections")

	var component = AudioComponent.new()

	# 创建绑定
	var binding1 = AudioBinding.new()
	binding1.signal_name = "footstep"
	component.audio_bindings.append(binding1)

	var binding2 = AudioBinding.new()
	binding2.signal_name = "pressed"
	component.audio_bindings.append(binding2)

	# 创建模拟节点
	var mock_player = MockAudioPlayer.new()
	var mock_target = MockSignalTarget.new()

	# 添加到场景树（信号连接需要节点在树中）
	add_child(mock_player)
	add_child(mock_target)

	# 调用 setup
	component.setup(mock_target, mock_player)

	# 触发信号验证连接
	mock_target.emit_signal("footstep")
	await get_tree().process_frame
	assert(mock_player.triggered_bindings.size() == 1, "应触发 1 个绑定")
	assert(mock_player.triggered_bindings[0] == binding1, "应触发正确的绑定")
	print("✓ footstep 信号连接成功")

	mock_player.triggered_bindings.clear()
	mock_target.emit_signal("pressed")
	await get_tree().process_frame
	assert(mock_player.triggered_bindings.size() == 1, "应触发 1 个绑定")
	assert(mock_player.triggered_bindings[0] == binding2, "应触发正确的绑定")
	print("✓ pressed 信号连接成功")

	# 清理
	mock_player.queue_free()
	mock_target.queue_free()

	print("test_setup_signal_connections PASSED\n")

## 测试 6: 防止重复连接
func test_duplicate_setup_prevention():
	print("测试 6: test_duplicate_setup_prevention")

	var component = AudioComponent.new()

	# 创建绑定
	var binding1 = AudioBinding.new()
	binding1.signal_name = "footstep"
	component.audio_bindings.append(binding1)

	var binding2 = AudioBinding.new()
	binding2.signal_name = "pressed"
	component.audio_bindings.append(binding2)

	# 创建模拟节点
	var mock_player = MockAudioPlayer.new()
	var mock_target = MockSignalTarget.new()

	# 添加到场景树（信号连接需要节点在树中）
	add_child(mock_player)
	add_child(mock_target)

	# 第一次调用 setup
	component.setup(mock_target, mock_player)

	# 第二次调用 setup（应该不会重复连接）
	component.setup(mock_target, mock_player)

	# 第三次调用 setup（仍然不应该重复连接）
	component.setup(mock_target, mock_player)

	# 触发信号验证只调用了一次
	mock_target.emit_signal("footstep")
	await get_tree().process_frame
	assert(mock_player.triggered_bindings.size() == 1, "即使多次调用 setup()，footstep 信号应只触发 1 次，而不是 3 次")
	assert(mock_player.triggered_bindings[0] == binding1, "应触发正确的绑定")
	print("✓ 多次调用 setup() 不会导致重复连接")

	mock_player.triggered_bindings.clear()
	mock_target.emit_signal("pressed")
	await get_tree().process_frame
	assert(mock_player.triggered_bindings.size() == 1, "即使多次调用 setup()，pressed 信号应只触发 1 次，而不是 3 次")
	assert(mock_player.triggered_bindings[0] == binding2, "应触发正确的绑定")
	print("✓ 多个信号都正确防止了重复连接")

	# 清理
	mock_player.queue_free()
	mock_target.queue_free()

	print("test_duplicate_setup_prevention PASSED\n")
