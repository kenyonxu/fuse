extends Node

## OnAnimationFinished 事件测试

func _ready():
	print("=== Testing OnAnimationFinished ===")
	await get_tree().process_frame
	test_basic_functionality()
	test_specific_animation()
	test_validation()
	print("=== All OnAnimationFinished tests passed! ===")

## 测试基本功能
func test_basic_functionality():
	print("Test 1: Basic functionality")

	var event = OnAnimationFinished.new()
	var anim_player = AnimationPlayer.new()
	anim_player.name = "TestAnimationPlayer"
	add_child(anim_player)

	# 创建测试动画
	var animation = Animation.new()
	animation.length = 0.1
	animation.track_insert_key(0, 0.0, Transform3D())
	anim_player.add_animation("test", animation)

	var trigger = Node.new()
	add_child(trigger)

	event.animation_player = trigger.get_path_to(anim_player)
	event.animation_name = ""

	var triggered = false
	event.triggered.connect(func(node):
		triggered = true
		print("  Event triggered! Animation: %s" % node.get_meta("animation_name"))
	)

	event.initialize(trigger)
	await get_tree().process_frame

	# 播放动画
	anim_player.play("test")
	await get_tree().create_timer(0.2).timeout

	assert(triggered, "Event should trigger when animation finishes")
	print("  ✓ Test 1 passed\n")

	event.terminate(trigger)
	anim_player.queue_free()
	trigger.queue_free()

## 测试指定动画
func test_specific_animation():
	print("Test 2: Specific animation")

	var event = OnAnimationFinished.new()
	var anim_player = AnimationPlayer.new()
	anim_player.name = "TestAnimationPlayer"
	add_child(anim_player)

	# 创建两个测试动画
	var anim1 = Animation.new()
	anim1.length = 0.1
	anim_player.add_animation("anim1", anim1)

	var anim2 = Animation.new()
	anim2.length = 0.1
	anim_player.add_animation("anim2", anim2)

	var trigger = Node.new()
	add_child(trigger)

	event.animation_player = trigger.get_path_to(anim_player)
	event.animation_name = "anim1"

	var triggered = false
	var triggered_anim = ""
	event.triggered.connect(func(node):
		triggered = true
		triggered_anim = node.get_meta("animation_name")
	)

	event.initialize(trigger)
	await get_tree().process_frame

	# 播放其他动画
	anim_player.play("anim2")
	await get_tree().create_timer(0.2).timeout

	assert(not triggered, "Event should not trigger for different animation")

	# 播放指定动画
	anim_player.play("anim1")
	await get_tree().create_timer(0.2).timeout

	assert(triggered, "Event should trigger for specified animation")
	assert(triggered_anim == "anim1", "Should trigger for correct animation")
	print("  ✓ Test 2 passed\n")

	event.terminate(trigger)
	anim_player.queue_free()
	trigger.queue_free()

## 测试参数验证
func test_validation():
	print("Test 3: Parameter validation")

	var event = OnAnimationFinished.new()

	# 测试空目标节点
	event.animation_player = NodePath("")
	var errors = event.validate()
	assert(not errors.is_empty(), "Should have validation errors for empty target")
	print("  ✓ Empty target validation passed")

	print("  ✓ Test 3 passed\n")
