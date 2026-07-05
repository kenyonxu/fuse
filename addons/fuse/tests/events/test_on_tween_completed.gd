extends Node

## OnTweenCompleted 事件测试

@onready var test_sprite = $TestSprite

func _ready():
	print("=== Testing OnTweenCompleted ===")
	await get_tree().process_frame
	test_tween_completion()
	test_termination()
	test_validation()
	cleanup()
	print("=== All OnTweenCompleted tests passed! ===")

## 测试 Tween 完成检测
func test_tween_completion():
	print("Test 1: Tween completion detection")

	var tween = create_tween()
	var event_script = load("res://addons/fuse/events/tween/on_tween_completed.gd")
	var event = event_script.new()
	event.tween_node_path = NodePath("../TestTween")

	add_child(tween)
	var trigger = Node.new()
	add_child(trigger)

	var triggered = false
	var context_tween = null
	event.triggered.connect(func(context):
		triggered = true
		if context and context.has_meta("tween"):
			context_tween = context.get_meta("tween")
	)

	event.initialize(trigger)
	await get_tree().process_frame

	# 执行 Tween
	tween.tween_property(test_sprite, "position", Vector2(200, 200), 0.5)
	await get_tree().create_timer(1.0).timeout

	assert(triggered, "Event should trigger when tween completes")
	assert(context_tween == tween, "Event should pass correct tween reference")
	print("  ✓ Test 1 passed: Tween completion detection works\n")

	event.terminate(trigger)
	trigger.queue_free()
	tween.queue_free()

## 测试终止和清理
func test_termination():
	print("Test 2: Termination and cleanup")

	var tween = create_tween()
	var event_script = load("res://addons/fuse/events/tween/on_tween_completed.gd")
	var event = event_script.new()
	event.tween_node_path = NodePath("../TestTween")

	add_child(tween)
	var trigger = Node.new()
	add_child(trigger)

	event.initialize(trigger)
	await get_tree().process_frame

	# 验证信号已连接
	assert(tween.finished.is_connected(event._on_tween_finished), "finished should be connected")

	# 终止事件
	event.terminate(trigger)

	# 验证信号已断开
	assert(not tween.finished.is_connected(event._on_tween_finished), "finished should be disconnected")
	assert(event._tween == null, "Tween reference should be cleared")
	assert(not event._is_monitoring, "_is_monitoring should be false")
	print("  ✓ Test 2 passed: Termination works\n")

	event.terminate(trigger)
	trigger.queue_free()
	tween.queue_free()

## 测试验证
func test_validation():
	print("Test 3: Parameter validation")

	var event_script = load("res://addons/fuse/events/tween/on_tween_completed.gd")
	var event = event_script.new()

	# 测试空目标节点
	event.tween_node_path = NodePath("")
	var errors = event.validate()
	assert(not errors.is_empty(), "Should have validation errors for empty target")
	print("  ✓ Empty target validation passed")

	print("  ✓ Test 3 passed\n")

## 清理测试资源
func cleanup():
	# 清理测试资源
	pass
