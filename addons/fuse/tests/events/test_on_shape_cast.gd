extends Node2D

## 测试 OnShapeCast 事件

var test_event: Resource

func _ready():
	print("=== 测试 OnShapeCast 事件 ===")

	# 创建测试事件
	test_event = load("res://addons/fuse/events/physics/on_shape_cast.gd").new()

	# 配置测试事件
	test_event.origin_node_path = NodePath("")
	test_event.shape_type = 0  # RECTANGLE
	test_event.shape_size = Vector2(20, 20)
	test_event.target_position = Vector2(100, 0)
	test_event.collision_mask = 1
	test_event.emit_collision_point = true

	# 连接触发信号
	test_event.triggered.connect(_on_event_triggered)

	# 初始化事件
	test_event.initialize(self)

	print("✓ 事件已初始化")
	print("  - 形状类型: 矩形 (20x20)")
	print("  - 目标位置: (100, 0)")

	await get_tree().create_timer(2.0).timeout
	print("\n✓ 测试完成")
	test_event.terminate(self)

func _on_event_triggered(context: Node) -> void:
	if context:
		var collider = context.get_meta("collider") if context.has_meta("collider") else null
		var point = context.get_meta("collision_point") if context.has_meta("collision_point") else Vector2.ZERO

		print("\n✓ 形状投射事件触发！")
		print("  - 碰撞体: %s" % (collider.name if collider else "null"))
		print("  - 碰撞点: %s" % str(point))

func _exit_tree():
	if test_event:
		test_event.terminate(self)
