extends Node

## OnAnimationStarted 事件测试

func _ready():
	print("=== Testing OnAnimationStarted ===")
	await get_tree().process_frame
	test_basic_functionality()
	test_specific_animation()
	test_trigger_once_per_animation()
	test_validation()
	print("=== All OnAnimationStarted tests passed! ===")

## 测试基本功能
func test_basic_functionality():
	print("Test 1: Basic functionality")

	var event = OnAnimationStarted.new()
	var anim_player = AnimationPlayer.new()
	anim_player.name = "TestAnimationPlayer"
	add_child(anim_player)

	# 创建测试动画
	var animation = Animation.new()
	animation.length = 0.1
	animation.loop_mode = Animation.LOOP_NONE
	anim_player.add_animation("test", animation)

	var trigger = Node.new()
	add_child(trigger)

	event.target_node_path = trigger.get_path_to(anim_player)
	event.animation_name = ""

	var triggered = false
	var received_anim_name = ""
	event.triggered.connect(func(node):
		triggered = true
		if node:
			received_anim_name = node.get_meta("animation_name", "")
		print("  Event triggered! Animation: %s" % received_anim_name)
	)

	event.initialize(trigger)
	await get_tree().process_frame

	# 播放动画
	anim_player.play("test")
	await get_tree().create_timer(0.05).timeout

	assert(triggered, "Event should trigger when animation starts")
	assert(received_anim_name == "test", "Should pass correct animation name")
	print("  ✓ Test 1 passed\n")

	event.terminate(trigger)
	anim_player.queue_free()
	trigger.queue_free()

## 测试指定动画
func test_specific_animation():
	print("Test 2: Specific animation")

	var event = OnAnimationStarted.new()
	var anim_player = AnimationPlayer.new()
	anim_player.name = "TestAnimationPlayer"
	add_child(anim_player)

	# 创建两个测试动画
	var anim1 = Animation.new()
	anim1.length = 0.1
	anim1.loop_mode = Animation.LOOP_NONE
	anim_player.add_animation("anim1", anim1)

	var anim2 = Animation.new()
	anim2.length = 0.1
	anim2.loop_mode = Animation.LOOP_NONE
	anim_player.add_animation("anim2", anim2)

	var trigger = Node.new()
	add_child(trigger)

	event.target_node_path = trigger.get_path_to(anim_player)
	event.animation_name = "anim1"

	var triggered = false
	var received_anim_name = ""
	event.triggered.connect(func(node):
		triggered = true
		if node:
			received_anim_name = node.get_meta("animation_name", "")
	)

	event.initialize(trigger)
	await get_tree().process_frame

	# 播放其他动画
	anim_player.play("anim2")
	await get_tree().create_timer(0.05).timeout

	assert(not triggered, "Event should not trigger for different animation")

	# 播放指定动画
	anim_player.play("anim1")
	await get_tree().create_timer(0.05).timeout

	assert(triggered, "Event should trigger for specified animation")
	assert(received_anim_name == "anim1", "Should trigger for correct animation")
	print("  ✓ Test 2 passed\n")

	event.terminate(trigger)
	anim_player.queue_free()
	trigger.queue_free()

## 测试每个动画只触发一次
func test_trigger_once_per_animation():
	print("Test 3: Trigger once per animation")

	var event = OnAnimationStarted.new()
	var anim_player = AnimationPlayer.new()
	anim_player.name = "TestAnimationPlayer"
	add_child(anim_player)

	# 创建测试动画
	var animation = Animation.new()
	animation.length = 0.05
	animation.loop_mode = Animation.LOOP_NONE
	anim_player.add_animation("test", animation)

	var trigger = Node.new()
	add_child(trigger)

	event.target_node_path = trigger.get_path_to(anim_player)
	event.animation_name = ""
	event.trigger_once_per_animation = true

	var trigger_count = 0
	event.triggered.connect(func(node):
		trigger_count += 1
		print("  Event triggered! Count: %d" % trigger_count)
	)

	event.initialize(trigger)
	await get_tree().process_frame

	# 播放动画两次
	anim_player.play("test")
	await get_tree().create_timer(0.1).timeout

	anim_player.play("test")
	await get_tree().create_timer(0.1).timeout

	assert(trigger_count == 1, "Event should trigger only once per animation")
	print("  ✓ Test 3 passed\n")

	event.terminate(trigger)
	anim_player.queue_free()
	trigger.queue_free()

## 测试参数验证
func test_validation():
	print("Test 4: Parameter validation")

	var event = OnAnimationStarted.new()

	# 测试空目标节点
	event.target_node_path = NodePath("")
	var errors = event.validate()
	assert(not errors.is_empty(), "Should have validation errors for empty target")
	print("  ✓ Empty target validation passed")

	# 测试有效配置
	event.target_node_path = NodePath("SomeNode")
	errors = event.validate()
	assert(errors.is_empty(), "Should have no validation errors for valid config")
	print("  ✓ Valid configuration passed")

	print("  ✓ Test 4 passed\n")
