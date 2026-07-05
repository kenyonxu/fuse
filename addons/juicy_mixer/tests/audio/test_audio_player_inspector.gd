@tool
extends Node2D

## JuicyAudioPlayer Inspector 测试
##
## 测试 JuicyAudioPlayerInspector 插件的功能
##
## 测试步骤:
## 1. 在编辑器中打开此场景
## 2. 选择 PlayerParent/JuicyAudioPlayer 节点
## 3. 在 Inspector 中应该看到:
##    - 状态面板显示"父节点: PlayerParent"
##    - 绑定数量标签
##    - "🧪 测试所有绑定"按钮
## 4. 点击测试按钮，控制台应打印绑定信息

# =============================================================================
# 测试场景设置
# =============================================================================

## 模拟信号目标节点
class TestParentNode extends Node2D:
	signal test_signal_1
	signal test_signal_2

	var test_signal_1_count: int = 0
	var test_signal_2_count: int = 0

	func _init():
		add_user_signal("test_signal_1")
		add_user_signal("test_signal_2")

# =============================================================================
# 生命周期
# =============================================================================

func _ready():
	print("\n=== JuicyAudioPlayer Inspector 测试 ===")
	print("请在编辑器中选择 PlayerParent/JuicyAudioPlayer 节点")
	print("检查 Inspector 中的自定义面板")
	print("点击'🧪 测试所有绑定'按钮测试功能")
	print("====================================\n")

	# 设置测试场景
	_setup_test_scene()

	# 运行自动化测试
	await get_tree().process_frame
	_run_automated_tests()

func _setup_test_scene():
	## 设置测试场景
	print("设置测试场景...")

	# 获取节点引用
	var player_parent = $PlayerParent
	var player = $PlayerParent/JuicyAudioPlayer

	# 创建音频组件
	var audio_component = AudioComponent.new()

	# 创建测试音频事件
	var event1 = _create_test_event("Event_Test_1")
	var event2 = _create_test_event("Event_Test_2")

	# 创建绑定
	var binding1 = AudioBinding.new()
	binding1.signal_name = "test_signal_1"
	binding1.audio_event = event1

	var binding2 = AudioBinding.new()
	binding2.signal_name = "test_signal_2"
	binding2.audio_event = event2

	# 添加绑定到组件
	audio_component.audio_bindings.append(binding1)
	audio_component.audio_bindings.append(binding2)

	# 分配组件给播放器
	player.audio_component = audio_component

	# 设置组件
	audio_component.setup(player_parent, player)

	print("✓ 测试场景设置完成")
	print("  - 父节点: %s" % player_parent.name)
	print("  - 绑定数量: %d" % audio_component.get_binding_count())

func _run_automated_tests():
	## 运行自动化测试

	print("\n运行自动化测试...")

	# 测试 1: 验证父节点
	var player = $PlayerParent/JuicyAudioPlayer
	var parent = player.get_parent()
	assert(parent != null, "Player 应该有父节点")
	assert(parent.name == "PlayerParent", "父节点应该是 PlayerParent")
	print("✓ 测试 1 通过: 父节点正确")

	# 测试 2: 验证音频组件
	assert(player.audio_component != null, "Player 应该有 AudioComponent")
	print("✓ 测试 2 通过: AudioComponent 存在")

	# 测试 3: 验证绑定数量
	var binding_count = player.audio_component.get_binding_count()
	assert(binding_count == 2, "应该有 2 个绑定，实际有 %d" % binding_count)
	print("✓ 测试 3 通过: 绑定数量正确 (2)")

	# 测试 4: 验证绑定信息
	var binding1 = player.audio_component.audio_bindings[0]
	var binding2 = player.audio_component.audio_bindings[1]

	assert(binding1.signal_name == "test_signal_1", "Binding 1 信号名称错误")
	assert(binding1.audio_event != null, "Binding 1 音频事件为空")
	assert(binding2.signal_name == "test_signal_2", "Binding 2 信号名称错误")
	assert(binding2.audio_event != null, "Binding 2 音频事件为空")
	print("✓ 测试 4 通过: 绑定信息正确")

	# 测试 5: 打印绑定信息（模拟点击测试按钮）
	print("\n模拟点击'测试所有绑定'按钮:")
	_print_all_bindings(player)

	print("\n=== 所有自动化测试通过! ===")
	print("请手动检查 Inspector 中的 UI 显示\n")

func _print_all_bindings(player: JuicyAudioPlayer):
	## 打印所有绑定信息（模拟测试按钮功能）

	print("\n=== JuicyAudioPlayer Test ===")

	var parent_node = player.get_parent()
	print("Parent: %s" % (parent_node.name if parent_node else "无"))

	var binding_count = player.audio_component.get_binding_count()
	print("Bindings: %d" % binding_count)

	for i in range(binding_count):
		var binding: AudioBinding = player.audio_component.audio_bindings[i]

		if not binding:
			print("  [%d] null" % i)
			continue

		var signal_name = binding.signal_name if binding.signal_name else "null"
		var event_name = "null"
		if binding.audio_event:
			event_name = binding.audio_event.event_name if binding.audio_event.event_name else "null"

		print("  [%d] Signal: %s, Event: %s" % [i, signal_name, event_name])

	print("============================\n")

func _create_test_event(event_name: String) -> AudioEventResource:
	## 创建测试音频事件

	var event = AudioEventResource.new()
	event.event_name = event_name

	# 创建一个音频变体
	var variant = AudioVariant.new()
	event.audio_variants.append(variant)

	return event
