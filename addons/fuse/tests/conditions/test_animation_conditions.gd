extends Node

## 测试动画检测条件

# 预加载条件脚本
const CheckIsPlaying = preload("res://addons/fuse/conditions/animation/check_is_playing.gd")
const CheckIsAnimation = preload("res://addons/fuse/conditions/animation/check_is_animation.gd")
const CheckAnimationFinished = preload("res://addons/fuse/conditions/animation/check_animation_finished.gd")

func _ready():
	print("=== 测试动画检测条件 ===")
	test_is_playing_condition()
	test_is_animation_condition()
	test_animation_finished_condition()
	print("=== 动画检测条件测试完成 ===")

## 测试动画播放中条件
func test_is_playing_condition():
	print("\n--- 测试动画播放中条件 ---")

	# 创建测试场景
	var scene_root = Node2D.new()
	add_child(scene_root)

	# 创建 AnimationPlayer
	var anim_player = AnimationPlayer.new()
	anim_player.name = "TestAnimPlayer"
	scene_root.add_child(anim_player)

	# 创建简单动画
	var animation = Animation.new()
	animation.length = 1.0
	animation.track_insert_key(0, 0.0, 0)
	anim_player.add_animation("test_anim", animation)

	# 创建执行上下文
	var context = ExecutionContext.new()
	context.scene_context = scene_root

	# 创建条件
	var condition = CheckIsPlaying.new()
	condition.target_node = NodePath("TestAnimPlayer")

	# 测试：未播放时应该返回 false
	var result1 = condition.check(context)
	assert(result1 == false, "未播放时应该返回 false")
	print("  ✓ 未播放时返回 false")

	# 测试：播放时应该返回 true
	anim_player.play("test_anim")
	await get_tree().process_frame
	var result2 = condition.check(context)
	assert(result2 == true, "播放时应该返回 true")
	print("  ✓ 播放时返回 true")

	# 测试：播放完成后应该返回 false
	await get_tree().create_timer(1.5).timeout
	var result3 = condition.check(context)
	assert(result3 == false, "播放完成后应该返回 false")
	print("  ✓ 播放完成后返回 false")

	# 测试：测试取反功能
	condition.negate_result = true
	anim_player.play("test_anim")
	await get_tree().process_frame
	var result4 = condition.check(context)
	assert(result4 == false, "取反后播放时应该返回 false")
	print("  ✓ 取反功能正常")

	# 清理
	scene_root.queue_free()

	print("✓ 动画播放中条件测试通过")

## 测试指定动画条件
func test_is_animation_condition():
	print("\n--- 测试指定动画条件 ---")

	# 创建测试场景
	var scene_root = Node2D.new()
	add_child(scene_root)

	# 创建 AnimationPlayer
	var anim_player = AnimationPlayer.new()
	anim_player.name = "TestAnimPlayer2"
	scene_root.add_child(anim_player)

	# 创建两个动画
	var anim1 = Animation.new()
	anim1.length = 1.0
	anim_player.add_animation("walk", anim1)

	var anim2 = Animation.new()
	anim2.length = 1.0
	anim_player.add_animation("run", anim2)

	# 创建执行上下文
	var context = ExecutionContext.new()
	context.scene_context = scene_root

	# 创建条件
	var condition = CheckIsAnimation.new()
	condition.target_node = NodePath("TestAnimPlayer2")
	condition.animation_name = "walk"

	# 测试：未播放时应该返回 false
	var result1 = condition.check(context)
	assert(result1 == false, "未播放时应该返回 false")
	print("  ✓ 未播放时返回 false")

	# 测试：播放指定动画时应该返回 true
	anim_player.play("walk")
	await get_tree().process_frame
	var result2 = condition.check(context)
	assert(result2 == true, "播放指定动画时应该返回 true")
	print("  ✓ 播放指定动画时返回 true")

	# 测试：播放其他动画时应该返回 false
	anim_player.play("run")
	await get_tree().process_frame
	var result3 = condition.check(context)
	assert(result3 == false, "播放其他动画时应该返回 false")
	print("  ✓ 播放其他动画时返回 false")

	# 测试：取反功能
	condition.negate_result = true
	anim_player.play("walk")
	await get_tree().process_frame
	var result4 = condition.check(context)
	assert(result4 == false, "取反后播放指定动画应该返回 false")
	print("  ✓ 取反功能正常")

	# 清理
	scene_root.queue_free()

	print("✓ 指定动画条件测试通过")

## 测试动画完成条件
func test_animation_finished_condition():
	print("\n--- 测试动画完成条件 ---")

	# 创建测试场景
	var scene_root = Node2D.new()
	add_child(scene_root)

	# 创建 AnimationPlayer
	var anim_player = AnimationPlayer.new()
	anim_player.name = "TestAnimPlayer3"
	scene_root.add_child(anim_player)

	# 创建动画
	var anim1 = Animation.new()
	anim1.length = 1.0
	anim_player.add_animation("walk", anim1)

	var anim2 = Animation.new()
	anim2.length = 1.0
	anim_player.add_animation("run", anim2)

	# 创建执行上下文
	var context = ExecutionContext.new()
	context.scene_context = scene_root

	# 测试 1: 未播放时应该返回 true（已完成）
	var condition1 = CheckAnimationFinished.new()
	condition1.target_node = NodePath("TestAnimPlayer3")
	var result1 = condition1.check(context)
	assert(result1 == true, "未播放时应该返回 true（已完成）")
	print("  ✓ 未播放时返回 true")

	# 测试 2: 播放中应该返回 false
	anim_player.play("walk")
	await get_tree().process_frame
	var result2 = condition1.check(context)
	assert(result2 == false, "播放中应该返回 false")
	print("  ✓ 播放中返回 false")

	# 测试 3: 播放完成后应该返回 true
	await get_tree().create_timer(1.5).timeout
	var result3 = condition1.check(context)
	assert(result3 == true, "播放完成后应该返回 true")
	print("  ✓ 播放完成后返回 true")

	# 测试 4: 检查指定动画
	var condition2 = CheckAnimationFinished.new()
	condition2.target_node = NodePath("TestAnimPlayer3")
	condition2.animation_name = "walk"

	anim_player.play("walk")
	await get_tree().process_frame
	var result4 = condition2.check(context)
	assert(result4 == false, "指定动画播放中应该返回 false")
	print("  ✓ 指定动画播放中返回 false")

	await get_tree().create_timer(1.5).timeout
	var result5 = condition2.check(context)
	assert(result5 == true, "指定动画完成应该返回 true")
	print("  ✓ 指定动画完成返回 true")

	# 测试 5: 播放其他动画时，指定动画应认为已完成
	anim_player.play("run")
	await get_tree().process_frame
	var result6 = condition2.check(context)
	assert(result6 == true, "播放其他动画时，指定动画应认为已完成")
	print("  ✓ 播放其他动画时指定动画认为已完成")

	# 测试 6: 取反功能
	condition2.negate_result = true
	anim_player.play("walk")
	await get_tree().process_frame
	var result7 = condition2.check(context)
	assert(result7 == true, "取反后播放中应该返回 true")
	print("  ✓ 取反功能正常")

	# 清理
	scene_root.queue_free()

	print("✓ 动画完成条件测试通过")
