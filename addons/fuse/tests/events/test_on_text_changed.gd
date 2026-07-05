extends Node

## OnTextChanged 事件测试

func _ready():
	print("=== Testing OnTextChanged ===")
	await get_tree().process_frame
	test_lineedit_on_change()
	test_lineedit_on_empty()
	test_lineedit_on_pattern_match()
	test_textedit_on_change()
	test_validation()
	print("=== All OnTextChanged tests passed! ===")

## 测试 LineEdit 文本改变
func test_lineedit_on_change():
	print("Test 1: LineEdit text changed")

	var event = OnTextChanged.new()
	var lineedit = LineEdit.new()
	lineedit.name = "TestLineEdit"
	lineedit.placeholder_text = "Enter text..."
	add_child(lineedit)

	var trigger = Node.new()
	add_child(trigger)

	event.target_node_path = trigger.get_path_to(lineedit)
	event.trigger_mode = OnTextChanged.TriggerMode.ON_CHANGE

	var triggered = false
	var new_text = ""
	var old_text = ""
	var text_length = -1

	event.triggered.connect(func(context):
		triggered = true
		if context:
			new_text = context.get_meta("new_text", "")
			old_text = context.get_meta("old_text", "")
			text_length = context.get_meta("text_length", -1)
		print("  Event triggered! New: '%s', Old: '%s', Length: %d" % [new_text, old_text, text_length])
	)

	event.initialize(trigger)
	await get_tree().process_frame

	# 改变文本
	lineedit.text = "Hello World"
	lineedit.emit_signal("text_changed", "Hello World")
	await get_tree().process_frame

	assert(triggered, "Event should trigger when LineEdit text changes")
	assert(new_text == "Hello World", "New text should be 'Hello World'")
	assert(text_length == 11, "Text length should be 11")
	print("  ✓ Test 1 passed\n")

	event.terminate(trigger)
	lineedit.queue_free()
	trigger.queue_free()

## 测试 LineEdit 文本为空
func test_lineedit_on_empty():
	print("Test 2: LineEdit text empty")

	var event = OnTextChanged.new()
	var lineedit = LineEdit.new()
	lineedit.name = "EmptyLineEdit"
	lineedit.text = "Some text"
	add_child(lineedit)

	var trigger = Node.new()
	add_child(trigger)

	event.target_node_path = trigger.get_path_to(lineedit)
	event.trigger_mode = OnTextChanged.TriggerMode.ON_EMPTY

	var triggered = false

	event.triggered.connect(func(context):
		triggered = true
		print("  Event triggered! Text is empty")
	)

	event.initialize(trigger)
	await get_tree().process_frame

	# 清空文本
	lineedit.text = ""
	lineedit.emit_signal("text_changed", "")
	await get_tree().process_frame

	assert(triggered, "Event should trigger when LineEdit text becomes empty")
	print("  ✓ Test 2 passed\n")

	event.terminate(trigger)
	lineedit.queue_free()
	trigger.queue_free()

## 测试 LineEdit 模式匹配
func test_lineedit_on_pattern_match():
	print("Test 3: LineEdit pattern match")

	var event = OnTextChanged.new()
	var lineedit = LineEdit.new()
	lineedit.name = "PatternLineEdit"
	add_child(lineedit)

	var trigger = Node.new()
	add_child(trigger)

	event.target_node_path = trigger.get_path_to(lineedit)
	event.trigger_mode = OnTextChanged.TriggerMode.ON_PATTERN_MATCH
	event.pattern = "^\\d+$"  # 仅数字

	var triggered = false
	var pattern_matched = false

	event.triggered.connect(func(context):
		triggered = true
		if context:
			pattern_matched = context.get_meta("pattern_matched", false)
		print("  Event triggered! Pattern matched: ", pattern_matched)
	)

	event.initialize(trigger)
	await get_tree().process_frame

	# 输入数字（应该匹配）
	lineedit.text = "12345"
	lineedit.emit_signal("text_changed", "12345")
	await get_tree().process_frame

	assert(triggered, "Event should trigger when text matches pattern")
	assert(pattern_matched, "Pattern should be matched")
	print("  ✓ Test 3 passed\n")

	event.terminate(trigger)
	lineedit.queue_free()
	trigger.queue_free()

## 测试 TextEdit 文本改变
func test_textedit_on_change():
	print("Test 4: TextEdit text changed")

	var event = OnTextChanged.new()
	var textedit = TextEdit.new()
	textedit.name = "TestTextEdit"
	add_child(textedit)

	var trigger = Node.new()
	add_child(trigger)

	event.target_node_path = trigger.get_path_to(textedit)
	event.trigger_mode = OnTextChanged.TriggerMode.ON_MAX_LENGTH
	event.max_length = 10

	var triggered = false
	var text_length = -1

	event.triggered.connect(func(context):
		triggered = true
		if context:
			text_length = context.get_meta("text_length", -1)
		print("  Event triggered! Text length: %d" % text_length)
	)

	event.initialize(trigger)
	await get_tree().process_frame

	# 输入超过最大长度的文本
	textedit.text = "Hello World!"
	textedit.emit_signal("text_changed")
	await get_tree().process_frame

	assert(triggered, "Event should trigger when text reaches max length")
	assert(text_length >= 10, "Text length should be >= 10")
	print("  ✓ Test 4 passed\n")

	event.terminate(trigger)
	textedit.queue_free()
	trigger.queue_free()

## 测试参数验证
func test_validation():
	print("Test 5: Parameter validation")

	var event = OnTextChanged.new()

	# 测试空目标节点
	event.target_node_path = NodePath("")
	var errors = event.validate()
	assert(not errors.is_empty(), "Should have validation errors for empty target")
	print("  ✓ Empty target validation passed")

	# 测试模式匹配但模式为空
	event.target_node_path = NodePath("../ValidNode")
	event.trigger_mode = OnTextChanged.TriggerMode.ON_PATTERN_MATCH
	event.pattern = ""
	errors = event.validate()
	assert(not errors.is_empty(), "Should have validation errors for empty pattern")
	print("  ✓ Empty pattern validation passed")

	# 测试无效的最大长度
	event.max_length = -1
	errors = event.validate()
	assert(not errors.is_empty(), "Should have validation errors for negative max_length")
	print("  ✓ Invalid max_length validation passed")

	print("  ✓ Test 5 passed\n")
