extends Node

## Play Animation 指令测试

func _ready():
	print("=== Testing Play Animation ===")
	await test_basic_functionality()
	await test_error_handling()
	await test_playback_modes()
	print("=== All Play Animation tests passed! ===")

## 测试 1: 基础功能
func test_basic_functionality():
	print("Test 1: Basic functionality")

	# 创建测试场景
	var animation_player = AnimationPlayer.new()
	animation_player.name = "TestAnimationPlayer"
	add_child(animation_player)

	# 创建一个简单的动画
	var animation = Animation.new()
	var track_index = animation.add_track(Animation.TYPE_POSITION_3D)
	animation.track_set_path(track_index, ".")
	animation.track_set_interpolation_type(track_index, Animation.INTERPOLATION_LINEAR)
	animation.length = 1.0
	animation_player.add_animation("test_anim", animation)

	# 创建指令
	var instruction_script = load("res://addons/fuse/instructions/play_animation.gd")
	var instruction = instruction_script.new()
	instruction.target_player = NodePath("TestAnimationPlayer")
	instruction.animation_name = "test_anim"
	instruction.speed = 1.0
	instruction.from_end = false
	instruction.autoplay_only = false

	# 创建执行上下文
	var context = ExecutionContext.new()
	add_child(context)

	# 执行指令
	instruction.execute(context)
	await get_tree().process_frame

	# 验证动画正在播放
	assert(animation_player.is_playing(), "动画应该正在播放")
	print("  ✓ 动画正在播放")

	# 验证速度设置
	assert(animation_player.speed_scale == 1.0, "动画速度应该为 1.0")
	print("  ✓ 动画速度设置正确")

	# 清理
	animation_player.queue_free()
	context.queue_free()

	print("  ✓ Test 1 passed\n")

## 测试 2: 错误处理
func test_error_handling():
	print("Test 2: Error handling")

	var context = ExecutionContext.new()
	add_child(context)

	# 测试 2.1: 空目标节点
	print("  Test 2.1: Empty target node")
	var instruction1 = load("res://addons/fuse/instructions/play_animation.gd").new()
	instruction1.target_player = NodePath("")
	instruction1.animation_name = "test"
	instruction1.execute(context)
	await get_tree().process_frame
	assert(context.had_error(), "应该报告错误：目标节点为空")
	print("    ✓ 正确处理空目标节点")

	# 测试 2.2: 节点不存在
	print("  Test 2.2: Node not found")
	var instruction2 = load("res://addons/fuse/instructions/play_animation.gd").new()
	instruction2.target_player = NodePath("NonExistentNode")
	instruction2.animation_name = "test"
	instruction2.execute(context)
	await get_tree().process_frame
	assert(context.had_error(), "应该报告错误：节点不存在")
	print("    ✓ 正确处理节点不存在")

	# 测试 2.3: 节点类型错误
	print("  Test 2.3: Invalid node type")
	var node2d = Node2D.new()
	node2d.name = "TestNode2D"
	add_child(node2d)

	var instruction3 = load("res://addons/fuse/instructions/play_animation.gd").new()
	instruction3.target_player = NodePath("TestNode2D")
	instruction3.animation_name = "test"
	instruction3.execute(context)
	await get_tree().process_frame
	assert(context.had_error(), "应该报告错误：节点类型错误")
	print("    ✓ 正确处理节点类型错误")

	node2d.queue_free()

	# 测试 2.4: 动画不存在
	print("  Test 2.4: Animation not found")
	var animation_player = AnimationPlayer.new()
	animation_player.name = "TestAnimationPlayer2"
	add_child(animation_player)

	var instruction4 = load("res://addons/fuse/instructions/play_animation.gd").new()
	instruction4.target_player = NodePath("TestAnimationPlayer2")
	instruction4.animation_name = "non_existent_anim"
	instruction4.execute(context)
	await get_tree().process_frame
	assert(context.had_error(), "应该报告错误：动画不存在")
	print("    ✓ 正确处理动画不存在")

	animation_player.queue_free()
	context.queue_free()

	print("  ✓ Test 2 passed\n")

## 测试 3: 播放模式
func test_playback_modes():
	print("Test 3: Playback modes")

	var animation_player = AnimationPlayer.new()
	animation_player.name = "TestAnimationPlayer3"
	add_child(animation_player)

	# 创建测试动画
	var animation = Animation.new()
	var track_index = animation.add_track(Animation.TYPE_POSITION_3D)
	animation.track_set_path(track_index, ".")
	animation.track_set_interpolation_type(track_index, Animation.INTERPOLATION_LINEAR)
	animation.length = 1.0
	animation_player.add_animation("test_anim2", animation)

	var context = ExecutionContext.new()
	add_child(context)

	# 测试 3.1: 从结尾反向播放
	print("  Test 3.1: Play from end")
	var instruction1 = load("res://addons/fuse/instructions/play_animation.gd").new()
	instruction1.target_player = NodePath("TestAnimationPlayer3")
	instruction1.animation_name = "test_anim2"
	instruction1.from_end = true
	instruction1.speed = 1.0
	instruction1.execute(context)
	await get_tree().process_frame
	assert(animation_player.is_playing(), "动画应该正在播放")
	print("    ✓ 从结尾反向播放正常")

	# 测试 3.2: 自定义速度
	print("  Test 3.2: Custom speed")
	var instruction2 = load("res://addons/fuse/instructions/play_animation.gd").new()
	instruction2.target_player = NodePath("TestAnimationPlayer3")
	instruction2.animation_name = "test_anim2"
	instruction2.speed = 2.0
	instruction2.execute(context)
	await get_tree().process_frame
	assert(animation_player.speed_scale == 2.0, "动画速度应该为 2.0")
	print("    ✓ 自定义速度设置正确")

	# 清理
	animation_player.queue_free()
	context.queue_free()

	print("  ✓ Test 3 passed\n")
