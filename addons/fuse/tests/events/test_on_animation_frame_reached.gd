extends Node

## 测试 OnAnimationFrameReached 事件

@onready var animation_player = $AnimationPlayer
var test_event: Resource

func _ready():
	print("=== 测试 OnAnimationFrameReached 事件 ===")

	# 创建测试事件
	test_event = load("res://addons/fuse/events/animation/on_animation_frame_reached.gd").new()

	# 配置测试事件
	test_event.animation_player_path = NodePath("AnimationPlayer")
	test_event.target_frame = 5  # 测试第 5 帧
	test_event.animation_name = ""  # 监听当前动画
	test_event.emit_animation_name = true
	test_event.emit_current_frame = true
	test_event.emit_position = true

	# 连接触发信号
	test_event.triggered.connect(_on_event_triggered)

	# 初始化事件
	test_event.initialize(self)

	print("✓ 事件已初始化")
	print("  - 目标帧: %d" % test_event.target_frame)
	print("  - 动画名称: %s" % ("当前动画" if test_event.animation_name.is_empty() else test_event.animation_name))

	# 播放动画（延迟 1 秒）
	await get_tree().create_timer(1.0).timeout
	print("\n开始播放测试动画...")
	animation_player.play("test_animation")

func _on_event_triggered(context: Node) -> void:
	if context:
		var anim_name = context.get_meta("animation_name") if context.has_meta("animation_name") else "未知"
		var frame = context.get_meta("current_frame") if context.has_meta("current_frame") else -1
		var pos = context.get_meta("position") if context.has_meta("position") else -1.0

		print("\n✓ 事件触发成功！")
		print("  - 动画名称: %s" % anim_name)
		print("  - 当前帧: %d" % frame)
		print("  - 播放位置: %.3f 秒" % pos)
		print("  - 目标帧: %d" % context.get_meta("target_frame"))
	else:
		print("\n✓ 事件触发（无上下文）")

	# 清理测试
	await get_tree().create_timer(1.0).timeout
	test_event.terminate(self)
	print("\n✓ 测试完成，事件已清理")

func _exit_tree():
	# 确保清理
	if test_event:
		test_event.terminate(self)
