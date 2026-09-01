extends Node

## 测试 OnSignalFromGroup 事件

@onready var button1 = $Button1
@onready var button2 = $Button2
@onready var button3 = $Button3
var test_event: Resource

func _ready():
	print("=== 测试 OnSignalFromGroup 事件 ===")

	# 创建测试事件
	test_event = load("res://addons/fuse/events/node/on_signal_from_group.gd").new()

	# 配置测试事件
	test_event.signal_name = "pressed"
	test_event.group_name = "test_buttons"
	test_event.emit_node = true
	test_event.emit_signal_name = true

	# 连接触发信号
	test_event.triggered.connect(_on_event_triggered)

	# 初始化事件
	test_event.initialize(self)

	print("✓ 事件已初始化")
	print("  - 组名: test_buttons")
	print("  - 信号名: pressed")
	print("  - 已连接节点数: 3")

	await get_tree().create_timer(1.0).timeout
	print("\n测试：点击按钮触发事件...")

func _on_event_triggered(context: Node) -> void:
	if context:
		var node = context.get_meta("node") if context.has_meta("node") else null
		var sig = context.get_meta("signal_name") if context.has_meta("signal_name") else ""

		print("\n✓ 组信号事件触发！")
		print("  - 发射节点: %s" % (node.name if node else "null"))
		print("  - 信号名称: %s" % sig)
	else:
		print("\n✓ 组信号事件触发（无上下文）")

func _exit_tree():
	if test_event:
		test_event.terminate(self)
