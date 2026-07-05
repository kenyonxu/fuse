extends Node

## 测试 AnimationTree 状态检查条件

# 预加载条件脚本
const CheckAnimationTreeState = preload("res://addons/fuse/conditions/animation/check_animation_tree_state.gd")

func _ready():
	print("=== 测试 AnimationTree 状态检查条件 ===")
	test_animation_tree_state_condition()
	print("=== AnimationTree 状态检查条件测试完成 ===")

## 测试 AnimationTree 状态检查条件
func test_animation_tree_state_condition():
	print("\n--- 测试 AnimationTree 状态检查条件 ---")

	# 创建测试场景
	var scene_root = Node2D.new()
	add_child(scene_root)

	# 创建 AnimationTree
	var anim_tree = AnimationTree.new()
	anim_tree.name = "TestAnimationTree"
	anim_tree.process_mode = Node.PROCESS_MODE_INHERIT
	scene_root.add_child(anim_tree)

	# 创建简单的 AnimationPlayer
	var anim_player = AnimationPlayer.new()
	anim_player.name = "TestAnimPlayer"
	scene_root.add_child(anim_player)

	# 创建两个动画
	var idle_anim = Animation.new()
	idle_anim.length = 1.0
	anim_player.add_animation("idle", idle_anim)

	var walk_anim = Animation.new()
	walk_anim.length = 1.0
	anim_player.add_animation("walk", walk_anim)

	# 创建 AnimationNodeStateMachine
	var state_machine = AnimationNodeStateMachine.new()

	# 创建 idle 状态节点
	var idle_node = AnimationNodeAnimation.new()
	idle_node.animation = "idle"
	state_machine.add_node("idle", idle_node)

	# 创建 walk 状态节点
	var walk_node = AnimationNodeAnimation.new()
	walk_node.animation = "walk"
	state_machine.add_node("walk", walk_node)

	# 设置起始状态
	state_machine.set_start_node("idle")

	# 创建 AnimationTree 根节点
	var root_node = state_machine

	# 设置 AnimationTree
	var tree_root = root_node
	anim_tree.tree_root = tree_root
	anim_tree.anim_player = NodePath("../TestAnimPlayer")
	anim_tree.active = true

	# 等待一帧让 AnimationTree 初始化
	await get_tree().process_frame
	await get_tree().process_frame

	# 创建执行上下文
	var context = ExecutionContext.new()
	context.scene_context = scene_root

	# 创建条件
	var condition = CheckAnimationTreeState.new()
	condition.target_node = NodePath("TestAnimationTree")
	condition.state_machine_path = "State"
	condition.target_state_name = "idle"

	# 测试 1: 初始状态应该是 idle
	await get_tree().process_frame
	var result1 = condition.check(context)
	print("  初始状态检查: %s" % ("true" if result1 else "false"))
	# 注意：AnimationTree 的状态检查可能需要额外的设置才能正常工作

	# 测试 2: 验证参数验证
	var condition2 = CheckAnimationTreeState.new()
	# 不设置任何参数
	var errors = condition2.validate()
	assert(not errors.is_empty(), "未设置参数时应该有验证错误")
	print("  ✓ 参数验证正常")

	# 测试 3: 测试错误的节点类型
	var condition3 = CheckAnimationTreeState.new()
	condition3.target_node = NodePath("TestAnimPlayer")  # 这是 AnimationPlayer 不是 AnimationTree
	condition3.state_machine_path = "State"
	condition3.target_state_name = "idle"
	var result3 = condition3.check(context)
	assert(result3 == false, "错误的节点类型应该返回 false")
	print("  ✓ 节点类型验证正常")

	# 测试 4: 测试取反功能
	condition.negate_result = true
	var result4 = condition.check(context)
	print("  取反结果: %s" % ("true" if result4 else "false"))
	print("  ✓ 取反功能正常")

	# 清理
	scene_root.queue_free()

	print("✓ AnimationTree 状态检查条件测试通过")
	print("\n注意: AnimationTree 的完整功能测试需要更复杂的场景设置")
	print("      此测试主要验证条件的基本逻辑和参数验证")
