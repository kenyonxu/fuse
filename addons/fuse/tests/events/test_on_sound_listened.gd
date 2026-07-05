extends Node

## OnSoundListened 事件测试

func _ready():
	print("=== Testing OnSoundListened ===")
	await get_tree().process_frame
	test_basic_functionality()
	test_distance_check()
	test_trigger_mode()
	test_validation()
	print("=== All OnSoundListened tests passed! ===")

## 测试基本功能
func test_basic_functionality():
	print("Test 1: Basic functionality (3D)")

	var event = OnSoundListened.new()

	# 创建声源
	var audio_player = AudioStreamPlayer3D.new()
	audio_player.name = "TestSoundSource"
	audio_player.position = Vector3(0, 0, 0)
	add_child(audio_player)

	# 创建监听器
	var listener = Node3D.new()
	listener.name = "TestListener"
	listener.position = Vector3(5, 0, 0)  # 距离声源 5 米
	add_child(listener)

	var trigger = Node.new()
	add_child(trigger)

	event.sound_source_path = trigger.get_path_to(audio_player)
	event.listener_path = trigger.get_path_to(listener)
	event.max_distance = 10.0
	event.check_interval = 0.1
	event.trigger_mode = OnSoundListened.TriggerMode.ON_CHANGE

	var triggered = false
	var is_heard = false
	var distance = 0.0
	event.triggered.connect(func(node):
		triggered = true
		is_heard = node.get_meta("is_heard")
		distance = node.get_meta("distance")
		print("  Event triggered! Heard: %s, Distance: %.2f" % [is_heard, distance])
	)

	event.initialize(trigger)
	await get_tree().process_frame

	# 等待第一次检测
	await get_tree().create_timer(0.2).timeout

	assert(triggered, "Event should trigger on initial check")
	assert(is_heard, "Should hear sound at this distance")
	assert(distance <= 10.0, "Distance should be within max distance")
	print("  ✓ Test 1 passed\n")

	event.terminate(trigger)
	audio_player.queue_free()
	listener.queue_free()
	trigger.queue_free()

## 测试距离检查
func test_distance_check():
	print("Test 2: Distance check (3D)")

	var event = OnSoundListened.new()

	# 创建声源
	var audio_player = AudioStreamPlayer3D.new()
	audio_player.name = "TestSoundSource"
	audio_player.position = Vector3(0, 0, 0)
	add_child(audio_player)

	# 创建监听器（远距离）
	var listener = Node3D.new()
	listener.name = "TestListener"
	listener.position = Vector3(50, 0, 0)  # 距离声源 50 米
	add_child(listener)

	var trigger = Node.new()
	add_child(trigger)

	event.sound_source_path = trigger.get_path_to(audio_player)
	event.listener_path = trigger.get_path_to(listener)
	event.max_distance = 10.0  # 设置较小的最大距离
	event.check_interval = 0.1
	event.trigger_mode = OnSoundListened.TriggerMode.ON_CHANGE

	var triggered = false
	var is_heard = false
	event.triggered.connect(func(node):
		triggered = true
		is_heard = node.get_meta("is_heard")
		print("  Event triggered! Heard: %s" % is_heard)
	)

	event.initialize(trigger)
	await get_tree().process_frame

	await get_tree().create_timer(0.2).timeout

	assert(triggered, "Event should trigger")
	assert(not is_heard, "Should not hear sound at this distance")
	print("  ✓ Test 2 passed\n")

	event.terminate(trigger)
	audio_player.queue_free()
	listener.queue_free()
	trigger.queue_free()

## 测试触发模式
func test_trigger_mode():
	print("Test 3: Trigger modes")

	var event = OnSoundListened.new()

	# 创建声源
	var audio_player = AudioStreamPlayer3D.new()
	audio_player.name = "TestSoundSource"
	audio_player.position = Vector3(0, 0, 0)
	add_child(audio_player)

	# 创建监听器
	var listener = Node3D.new()
	listener.name = "TestListener"
	listener.position = Vector3(5, 0, 0)
	add_child(listener)

	var trigger = Node.new()
	add_child(trigger)

	event.sound_source_path = trigger.get_path_to(audio_player)
	event.listener_path = trigger.get_path_to(listener)
	event.max_distance = 10.0
	event.check_interval = 0.1

	# 测试 ON_HEARD 模式
	event.trigger_mode = OnSoundListened.TriggerMode.ON_HEARD

	var trigger_count = 0
	event.triggered.connect(func(node):
		trigger_count += 1
		print("  Trigger count: %d" % trigger_count)
	)

	event.initialize(trigger)
	await get_tree().process_frame

	await get_tree().create_timer(0.3).timeout

	assert(trigger_count == 1, "ON_HEARD mode should trigger only once")
	print("  ✓ ON_HEARD mode passed")

	# 重置并测试 ON_NOT_HEARD 模式
	event.terminate(trigger)
	event.trigger_mode = OnSoundListened.TriggerMode.ON_NOT_HEARD
	event.max_distance = 1.0  # 设置很小的距离，确保听不到

	trigger_count = 0
	event.initialize(trigger)
	await get_tree().process_frame

	await get_tree().create_timer(0.3).timeout

	assert(trigger_count == 1, "ON_NOT_HEARD mode should trigger only once")
	print("  ✓ ON_NOT_HEARD mode passed")

	print("  ✓ Test 3 passed\n")

	event.terminate(trigger)
	audio_player.queue_free()
	listener.queue_free()
	trigger.queue_free()

## 测试参数验证
func test_validation():
	print("Test 4: Parameter validation")

	var event = OnSoundListened.new()

	# 测试空声源路径
	event.sound_source_path = NodePath("")
	event.listener_path = NodePath("TestListener")
	var errors = event.validate()
	assert(not errors.is_empty(), "Should have validation errors for empty sound source")
	print("  ✓ Empty sound source validation passed")

	# 测试空监听器路径
	event.sound_source_path = NodePath("TestSource")
	event.listener_path = NodePath("")
	errors = event.validate()
	assert(not errors.is_empty(), "Should have validation errors for empty listener")
	print("  ✓ Empty listener validation passed")

	# 测试无效检查间隔
	event.sound_source_path = NodePath("TestSource")
	event.listener_path = NodePath("TestListener")
	event.check_interval = -1.0
	errors = event.validate()
	assert(not errors.is_empty(), "Should have validation errors for negative check interval")
	print("  ✓ Invalid check interval validation passed")

	# 测试无效最大距离
	event.check_interval = 0.1
	event.max_distance = -1.0
	errors = event.validate()
	assert(not errors.is_empty(), "Should have validation errors for negative max distance")
	print("  ✓ Invalid max distance validation passed")

	# 测试有效配置
	event.max_distance = 10.0
	errors = event.validate()
	assert(errors.is_empty(), "Should not have validation errors for valid config")
	print("  ✓ Valid configuration passed")

	print("  ✓ Test 4 passed\n")
