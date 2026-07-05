extends Node

## OnAudioBusVolumeChanged 事件测试

func _ready():
	print("=== Testing OnAudioBusVolumeChanged ===")
	await get_tree().process_frame
	test_basic_functionality()
	test_volume_threshold()
	test_validation()
	print("=== All OnAudioBusVolumeChanged tests passed! ===")

## 测试基本功能
func test_basic_functionality():
	print("Test 1: Basic functionality")

	var event = OnAudioBusVolumeChanged.new()

	# 使用 Master 总线（总是存在）
	event.bus_name = "Master"
	event.check_interval = 0.1
	event.trigger_on_any_change = true
	event.volume_threshold = 1.0

	var trigger = Node.new()
	add_child(trigger)

	var triggered = false
	var volume_change_received = false
	event.triggered.connect(func(node):
		triggered = true
		volume_change_received = node.has_meta("volume_change_db")
		print("  Event triggered! Volume change: %s dB" % node.get_meta("volume_change_db"))
	)

	event.initialize(trigger)
	await get_tree().process_frame

	# 修改总线音量
	var original_volume = AudioServer.get_bus_volume_db(0)
	AudioServer.set_bus_volume_db(0, original_volume - 5.0)

	# 等待事件触发
	await get_tree().create_timer(0.2).timeout

	assert(triggered, "Event should trigger when volume changes")
	assert(volume_change_received, "Should receive volume change metadata")
	print("  ✓ Test 1 passed\n")

	# 恢复原始音量
	AudioServer.set_bus_volume_db(0, original_volume)

	event.terminate(trigger)
	trigger.queue_free()

## 测试音量阈值
func test_volume_threshold():
	print("Test 2: Volume threshold")

	var event = OnAudioBusVolumeChanged.new()

	event.bus_name = "Master"
	event.check_interval = 0.1
	event.volume_threshold = 10.0  # 设置较高的阈值

	var trigger = Node.new()
	add_child(trigger)

	var triggered = false
	event.triggered.connect(func(node):
		triggered = true
	)

	event.initialize(trigger)
	await get_tree().process_frame

	# 小幅度修改音量（低于阈值）
	var original_volume = AudioServer.get_bus_volume_db(0)
	AudioServer.set_bus_volume_db(0, original_volume - 2.0)

	await get_tree().create_timer(0.2).timeout

	# 应该不会触发（变化小于阈值）
	assert(not triggered, "Event should not trigger when change is below threshold")
	print("  ✓ Threshold test passed")

	# 大幅度修改音量（超过阈值）
	AudioServer.set_bus_volume_db(0, original_volume - 15.0)

	await get_tree().create_timer(0.2).timeout

	assert(triggered, "Event should trigger when change exceeds threshold")
	print("  ✓ Large change test passed")

	# 恢复原始音量
	AudioServer.set_bus_volume_db(0, original_volume)

	print("  ✓ Test 2 passed\n")

	event.terminate(trigger)
	trigger.queue_free()

## 测试元数据传递
func test_metadata():
	print("Test 3: Metadata passing")

	var event = OnAudioBusVolumeChanged.new()

	event.bus_name = "Master"
	event.check_interval = 0.1
	event.emit_old_volume = true
	event.emit_new_volume = true
	event.emit_volume_change = true

	var trigger = Node.new()
	add_child(trigger)

	var metadata_complete = false
	event.triggered.connect(func(node):
		metadata_complete = (
			node.has_meta("bus_name") and
			node.has_meta("bus_index") and
			node.has_meta("old_volume_db") and
			node.has_meta("new_volume_db") and
			node.has_meta("volume_change_db")
		)
		print("  Bus name: %s" % node.get_meta("bus_name"))
		print("  Old volume: %s dB" % node.get_meta("old_volume_db"))
		print("  New volume: %s dB" % node.get_meta("new_volume_db"))
		print("  Volume change: %s dB" % node.get_meta("volume_change_db"))
	)

	event.initialize(trigger)
	await get_tree().process_frame

	# 修改音量
	var original_volume = AudioServer.get_bus_volume_db(0)
	AudioServer.set_bus_volume_db(0, original_volume - 3.0)

	await get_tree().create_timer(0.2).timeout

	assert(metadata_complete, "Should receive complete metadata")
	print("  ✓ Test 3 passed\n")

	# 恢复原始音量
	AudioServer.set_bus_volume_db(0, original_volume)

	event.terminate(trigger)
	trigger.queue_free()

## 测试参数验证
func test_validation():
	print("Test 4: Parameter validation")

	var event = OnAudioBusVolumeChanged.new()

	# 测试空总线名称
	event.bus_name = ""
	var errors = event.validate()
	assert(not errors.is_empty(), "Should have validation errors for empty bus name")
	print("  ✓ Empty bus name validation passed")

	# 测试无效检查间隔
	event.bus_name = "Master"
	event.check_interval = -1.0
	errors = event.validate()
	assert(not errors.is_empty(), "Should have validation errors for negative check interval")
	print("  ✓ Invalid check interval validation passed")

	# 测试无效音量阈值
	event.check_interval = 0.1
	event.volume_threshold = -1.0
	errors = event.validate()
	assert(not errors.is_empty(), "Should have validation errors for negative volume threshold")
	print("  ✓ Invalid volume threshold validation passed")

	# 测试有效配置
	event.volume_threshold = 1.0
	errors = event.validate()
	assert(errors.is_empty(), "Should not have validation errors for valid config")
	print("  ✓ Valid configuration passed")

	print("  ✓ Test 4 passed\n")
