extends Node

## OnInputText 事件测试

func _ready():
	print("=== Testing OnInputText ===")
	await get_tree().process_frame
	test_basic_input()
	test_character_filter()
	test_length_limit()
	print("=== All OnInputText tests passed! ===")

## 测试基本输入
func test_basic_input():
	print("Test 1: Basic input")

	var event = OnInputText.new()
	event.emit_text = true

	var trigger = Node.new()
	add_child(trigger)

	var triggered = false
	var received_text = ""
	event.triggered.connect(func(context):
		triggered = true
		if context:
			received_text = context.get_meta("text", "")
			print("  Input received: '%s'" % received_text)
	)

	event.initialize(trigger)
	await get_tree().process_frame

	# 模拟文本输入事件（使用 unicode 设置字符）
	var input_event = InputEventKey.new()
	input_event.unicode = ord('H')
	trigger._input(input_event)
	await get_tree().process_frame

	assert(triggered, "Event should trigger on text input")
	assert(received_text == "H", "Should receive correct text")
	print("  ✓ Test 1 passed\n")

	event.terminate(trigger)
	trigger.queue_free()

## 测试字符过滤
func test_character_filter():
	print("Test 2: Character filter")

	var event = OnInputText.new()
	event.filter_characters = "[0-9]"  # 只允许数字
	event.emit_text = true

	var trigger = Node.new()
	add_child(trigger)

	var digit_triggered = false
	var letter_triggered = false

	event.triggered.connect(func(context):
		var text = context.get_meta("text", "") if context else ""
		if text == "5":
			digit_triggered = true
		elif text == "a":
			letter_triggered = true
	)

	event.initialize(trigger)
	await get_tree().process_frame

	# 输入数字（应触发）
	var input_event = InputEventKey.new()
	input_event.unicode = ord('5')
	trigger._input(input_event)
	await get_tree().process_frame

	assert(digit_triggered, "Event should trigger for digit")

	# 输入字母（不应触发）
	input_event = InputEventKey.new()
	input_event.unicode = ord('a')
	trigger._input(input_event)
	await get_tree().process_frame

	assert(not letter_triggered, "Event should not trigger for letter")
	print("  ✓ Test 2 passed\n")

	event.terminate(trigger)
	trigger.queue_free()

## 测试长度限制
func test_length_limit():
	print("Test 3: Length limit")

	var event = OnInputText.new()
	event.max_length = 3
	event.emit_text = true

	var trigger = Node.new()
	add_child(trigger)

	var trigger_count = 0
	event.triggered.connect(func(context):
		trigger_count += 1
		print("  Trigger count: %d" % trigger_count)
	)

	event.initialize(trigger)
	await get_tree().process_frame

	# 输入3个字符（都应触发）
	for i in range(3):
		var input_event = InputEventKey.new()
		input_event.unicode = ord('a')
		trigger._input(input_event)
		await get_tree().process_frame

	assert(trigger_count == 3, "Should trigger for first 3 characters")

	# 第4个字符（不应触发）
	var input_event = InputEventKey.new()
	input_event.unicode = ord('a')
	trigger._input(input_event)
	await get_tree().process_frame

	assert(trigger_count == 3, "Should not trigger beyond max length")
	print("  ✓ Test 3 passed\n")

	event.terminate(trigger)
	trigger.queue_free()
