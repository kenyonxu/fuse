extends Node

## 测试 OnAnimationBlend 事件

@onready var animation_tree = $AnimationTree
var test_event: Resource

func _ready():
	print("=== 测试 OnAnimationBlend 事件 ===")

	# 创建测试事件
	test_event = load("res://addons/fuse/events/animation/on_animation_blend.gd").new()

	# 配置测试事件
	test_event.animation_tree_path = NodePath("AnimationTree")
	test_event.blend_path = NodePath("parameters/blend_position")
	test_event.threshold = 0.5
	test_event.comparison = 0  # GREATER_OR_EQUAL

	# 连接触发信号
	test_event.triggered.connect(_on_event_triggered)

	# 初始化事件
	test_event.initialize(self)

	print("✓ 事件已初始化")
	print("  - AnimationTree 路径: %s" % test_event.animation_tree_path)
	print("  - 混合路径: %s" % test_event.blend_path)
	print("  - 阈值: %.2f" % test_event.threshold)
	print("  - 比较方式: >=")

	# 测试权重变化（延迟 1 秒）
	await get_tree().create_timer(1.0).timeout
	print("\n开始测试权重变化...")

	# 模拟权重变化（手动设置 AnimationTree 参数）
	_animation_tree_test_sequence()

func _animation_tree_test_sequence():
	# 测试 1: 权重从 0.0 增加到 1.0
	print("\n测试 1: 权重从 0.0 -> 1.0")
	for i in range(11):
		var weight = i / 10.0
		if animation_tree and is_instance_valid(animation_tree):
			animation_tree.set("parameters/blend_position", weight)
		print("  设置权重: %.1f" % weight)
		await get_tree().create_timer(0.2).timeout

	# 测试 2: 权重从 1.0 减少到 0.0
	print("\n测试 2: 权重从 1.0 -> 0.0")
	for i in range(10, -1, -1):
		var weight = i / 10.0
		if animation_tree and is_instance_valid(animation_tree):
			animation_tree.set("parameters/blend_position", weight)
		print("  设置权重: %.1f" % weight)
		await get_tree().create_timer(0.2).timeout

	# 完成测试
	await get_tree().create_timer(1.0).timeout
	print("\n✓ 测试完成")
	test_event.terminate(self)

func _on_event_triggered(context: Node) -> void:
	if context:
		var path = context.get_meta("blend_path") if context.has_meta("blend_path") else "未知"
		var weight = context.get_meta("weight") if context.has_meta("weight") else -1.0
		var threshold = context.get_meta("threshold") if context.has_meta("threshold") else -1.0
		var comp = context.get_meta("comparison") if context.has_meta("comparison") else -1

		var comp_text = "未知"
		match comp:
			0: comp_text = ">="
			1: comp_text = "<="
			2: comp_text = "=="

		print("\n✓ 事件触发成功！")
		print("  - 混合路径: %s" % path)
		print("  - 当前权重: %.2f" % weight)
		print("  - 阈值: %.2f" % threshold)
		print("  - 比较方式: %s" % comp_text)
	else:
		print("\n✓ 事件触发（无上下文）")

func _exit_tree():
	# 确保清理
	if test_event:
		test_event.terminate(self)
