extends Node2D

## 测试 OnRaycastHit 事件

@onready var raycast_origin = $RaycastOrigin
@onready var target_sprite = $TargetSprite
var test_event: Resource

func _ready():
	print("=== 测试 OnRaycastHit 事件 ===")

	# 创建测试事件
	test_event = load("res://addons/fuse/events/physics/on_raycast_hit.gd").new()

	# 配置测试事件
	test_event.origin_node_path = NodePath("RaycastOrigin")
	test_event.target_position = Vector2(200, 0)  # 向右发射 200 像素
	test_event.collision_mask = 1  # 第 1 层
	test_event.emit_collision_point = true
	test_event.emit_collision_normal = true
	test_event.emit_raycast_origin = true

	# 连接触发信号
	test_event.triggered.connect(_on_event_triggered)

	# 初始化事件
	test_event.initialize(self)

	print("✓ 事件已初始化")
	print("  - 原点节点: RaycastOrigin")
	print("  - 目标位置: (200, 0)")
	print("  - 碰撞掩码: 第 1 层")

	# 测试延迟
	await get_tree().create_timer(1.0).timeout
	print("\n开始测试射线检测...")

	# 测试 1: 目标在射线路径上
	print("\n测试 1: 移动目标到射线路径上")
	target_sprite.position = Vector2(150, 0)
	await get_tree().create_timer(1.0).timeout

	# 测试 2: 移动目标出射线路径
	print("\n测试 2: 移动目标出射线路径")
	target_sprite.position = Vector2(150, 100)
	await get_tree().create_timer(1.0).timeout

	# 测试 3: 目标回到射线路径
	print("\n测试 3: 目标回到射线路径")
	target_sprite.position = Vector2(100, 0)
	await get_tree().create_timer(1.0).timeout

	# 完成测试
	await get_tree().create_timer(0.5).timeout
	print("\n✓ 测试完成")
	test_event.terminate(self)

func _on_event_triggered(context: Node) -> void:
	if context:
		var collider = context.get_meta("collider") if context.has_meta("collider") else null
		var collision_point = context.get_meta("collision_point") if context.has_meta("collision_point") else Vector2.ZERO
		var collision_normal = context.get_meta("collision_normal") if context.has_meta("collision_normal") else Vector2.ZERO
		var origin = context.get_meta("raycast_origin") if context.has_meta("raycast_origin") else Vector2.ZERO

		print("\n✓ 射线命中事件触发！")
		print("  - 碰撞体: %s" % (collider.name if collider else "null"))
		print("  - 碰撞点: %s" % str(collision_point))
		print("  - 碰撞法线: %s" % str(collision_normal))
		print("  - 射线原点: %s" % str(origin))
	else:
		print("\n✓ 射线命中事件触发（无上下文）")

func _exit_tree():
	# 确保清理
	if test_event:
		test_event.terminate(self)
