## 测试 JuicyAudioPlayer 的 target 属性和智能目标节点系统
extends Node

## 测试场景
## 验证新的 target 属性和向后兼容性

# 动态加载类（支持 headless 模式）
var JuicyAudioPlayerClass: Script = load("res://addons/juicy_mixer/core/juicy_audio_player.gd")

func _ready():
	print("\n=== JuicyAudioPlayer Target 属性测试 ===\n")

	_test_backward_compatibility()
	await get_tree().process_frame
	_test_explicit_target()
	await get_tree().process_frame
	_test_target_null_case()

	print("\n✅ 所有测试完成！")
	get_tree().quit()

## 测试向后兼容性（旧的父节点模式）
func _test_backward_compatibility():
	print("[测试 1] 向后兼容性（父节点模式）")

	var parent = Node.new()
	parent.name = "ParentNode"
	add_child(parent)

	var player = JuicyAudioPlayerClass.new()
	player.name = "AudioPlayer"
	parent.add_child(player)

	# 模拟 _ready 逻辑
	var effective_target = player._get_effective_target()

	assert(effective_target == parent, "应该回退到父节点")
	assert(player.target == null, "target 应该为 null（未设置）")

	print("  ✓ 父节点模式正常工作")
	print("    - 有效目标: %s" % effective_target.name)
	print("    - Target 属性: %s" % ("null" if player.target == null else player.target.name))

	parent.queue_free()

## 测试显式 target 模式（新功能）
func _test_explicit_target():
	print("\n[测试 2] 显式 target 模式")

	var parent = Node.new()
	parent.name = "ParentNode"
	add_child(parent)

	var target = Node.new()
	target.name = "TargetNode"
	add_child(target)

	var player = JuicyAudioPlayerClass.new()
	player.name = "AudioPlayer"
	player.target = target
	parent.add_child(player)

	# 模拟 _ready 逻辑
	var effective_target = player._get_effective_target()

	assert(effective_target == target, "应该使用显式指定的 target")
	assert(player.target == target, "target 应该指向目标节点")

	print("  ✓ 显式 target 模式正常工作")
	print("    - 有效目标: %s" % effective_target.name)
	print("    - Target 属性: %s" % player.target.name)
	print("    - 父节点: %s（被忽略）" % parent.name)

	parent.queue_free()
	target.queue_free()

## 测试 target 和父节点都为空的情况
func _test_target_null_case():
	print("\n[测试 3] target 和父节点都为空")

	var player = JuicyAudioPlayerClass.new()
	player.name = "AudioPlayer"
	# 不添加到场景树，没有父节点

	# 模拟 _ready 逻辑
	var effective_target = player._get_effective_target()

	assert(effective_target == null, "应该返回 null（无父节点且未设置 target）")

	print("  ✓ 正确处理无目标节点的情况")
	print("    - 有效目标: null")

	player.queue_free()
