extends Control

## OnFocus 事件测试

# 预加载 OnFocus 类
const OnFocus = preload("res://addons/fuse/events/ui/on_focus.gd")

@onready var button1 = $Button1
@onready var button2 = $Button2

func _ready():
	print("=== Testing OnFocus ===")
	await get_tree().process_frame
	test_focus_entered()
	await get_tree().process_frame
	test_focus_exited()
	await get_tree().process_frame
	test_focus_mode_filtering()
	await get_tree().process_frame
	test_termination()
	await get_tree().process_frame
	cleanup()
	print("=== All OnFocus tests passed! ===")

func test_focus_entered():
	print("Test 1: Focus entered detection")

	var event_script = load("res://addons/fuse/events/ui/on_focus.gd")
	var event = event_script.new()
	event.target_node_path = NodePath("../Button1")
	event.focus_mode = OnFocus.FocusMode.ON_BOTH

	var trigger = Node.new()
	add_child(trigger)

	# 记录焦点进入时的上下文
	var received_context = null
	event.triggered.connect(func(context):
		received_context = context
	)

	event.initialize(trigger)
	await get_tree().process_frame

	# 模拟焦点进入
	button1.grab_focus()
	await get_tree().process_frame

	assert(received_context != null, "Event should trigger on focus entered")
	assert(received_context["action"] == "entered", "Should be entered action")
	assert(received_context["node"] == button1, "Should capture the node")
	print("  ✓ Test 1 passed: Focus entered detection works\n")

	event.terminate(trigger)
	trigger.queue_free()

func test_focus_exited():
	print("Test 2: Focus exited detection")

	var event_script = load("res://addons/fuse/events/ui/on_focus.gd")
	var event = event_script.new()
	event.target_node_path = NodePath("../Button1")
	event.focus_mode = OnFocus.FocusMode.ON_BOTH

	var trigger = Node.new()
	add_child(trigger)

	# 记录焦点离开时的上下文
	var received_context = null
	event.triggered.connect(func(context):
		received_context = context
	)

	event.initialize(trigger)
	await get_tree().process_frame

	# 先获取焦点
	button1.grab_focus()
	await get_tree().process_frame

	# 切换到另一个按钮
	button2.grab_focus()
	await get_tree().process_frame

	assert(received_context != null, "Event should trigger on focus exited")
	assert(received_context["action"] == "exited", "Should be exited action")
	print("  ✓ Test 2 passed: Focus exited detection works\n")

	event.terminate(trigger)
	trigger.queue_free()

func test_focus_mode_filtering():
	print("Test 3: Focus mode filtering")

	var event_script = load("res://addons/fuse/events/ui/on_focus.gd")
	var event = event_script.new()
	event.target_node_path = NodePath("../Button1")
	event.focus_mode = OnFocus.FocusMode.ON_ENTERED  # 只监听进入

	var trigger = Node.new()
	add_child(trigger)

	# 统计触发次数和记录动作类型
	var trigger_count = 0
	var actions = []
	event.triggered.connect(func(context):
		trigger_count += 1
		actions.append(context["action"])
	)

	event.initialize(trigger)
	await get_tree().process_frame

	# 焦点进入
	button1.grab_focus()
	await get_tree().process_frame

	# 焦点离开
	button2.grab_focus()
	await get_tree().process_frame

	assert(trigger_count == 1, "Should trigger only once (on entered), got %d" % trigger_count)
	assert(actions[0] == "entered", "Should only trigger entered action")
	print("  ✓ Test 3 passed: Focus mode filtering works\n")

	event.terminate(trigger)
	trigger.queue_free()

func test_termination():
	print("Test 4: Termination and cleanup")

	var event_script = load("res://addons/fuse/events/ui/on_focus.gd")
	var event = event_script.new()
	event.target_node_path = NodePath("../Button1")

	var trigger = Node.new()
	add_child(trigger)

	event.initialize(trigger)
	await get_tree().process_frame

	# 验证信号已连接
	assert(button1.focus_entered.is_connected(event._on_focus_entered), "focus_entered should be connected")
	assert(button1.focus_exited.is_connected(event._on_focus_exited), "focus_exited should be connected")

	# 终止事件
	event.terminate(trigger)

	# 验证信号已断开
	assert(not button1.focus_entered.is_connected(event._on_focus_entered), "focus_entered should be disconnected")
	assert(not button1.focus_exited.is_connected(event._on_focus_exited), "focus_exited should be disconnected")
	assert(event._target_node == null, "Target node reference should be cleared")
	print("  ✓ Test 4 passed: Termination works\n")

	trigger.queue_free()

func cleanup():
	# 清理测试资源
	button1.release_focus()
