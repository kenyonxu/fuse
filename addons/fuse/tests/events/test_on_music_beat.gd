extends Node

## 测试 OnMusicBeat 事件

var test_event: Resource
var test_duration: float = 5.0  # 测试 5 秒

func _ready():
	print("=== 测试 OnMusicBeat 事件 ===")

	# 创建测试事件
	test_event = load("res://addons/fuse/events/audio/on_music_beat.gd").new()

	# 配置测试事件（120 BPM = 每秒 2 拍）
	test_event.bpm = 120.0
	test_event.beat_interval = 1  # 每拍触发一次
	test_event.emit_beat_count = true
	test_event.emit_bpm = true
	test_event.emit_elapsed_time = true

	# 连接触发信号
	test_event.triggered.connect(_on_event_triggered)

	# 初始化事件
	test_event.initialize(self)

	print("✓ 事件已初始化")
	print("  - BPM: %.1f" % test_event.bpm)
	print("  - 节拍间隔: %d 拍" % test_event.beat_interval)
	print("  - 预期触发频率: %.1f 次/秒" % (test_event.bpm / 60.0))

	# 延迟后开始测试
	await get_tree().create_timer(1.0).timeout
	print("\n开始测试节拍检测（测试 %d 秒）..." % test_duration)

	# 测试计时器
	var test_timer = get_tree().create_timer(test_duration)
	test_timer.timeout.connect(_on_test_complete)

func _on_event_triggered(context: Node) -> void:
	if context:
		var beat_count = context.get_meta("beat_count") if context.has_meta("beat_count") else -1
		var bpm = context.get_meta("bpm") if context.has_meta("bpm") else -1.0
		var elapsed = context.get_meta("elapsed_time") if context.has_meta("elapsed_time") else -1.0
		var interval = context.get_meta("beat_interval") if context.has_meta("beat_interval") else -1

		print("✓ 节拍事件触发：第 %d 拍（经过时间：%.2f 秒）" % [beat_count, elapsed])

		# 验证时间精度（允许 ±0.1 秒误差）
		var expected_time = beat_count * (60.0 / bpm)
		var time_diff = abs(elapsed - expected_time)
		if time_diff > 0.1:
			print("  ⚠️ 时间偏差：%.3f 秒（预期：%.3f）" % [time_diff, expected_time])
	else:
		print("✓ 节拍事件触发（无上下文）")

func _on_test_complete():
	print("\n✓ 测试完成")
	print("  清理事件...")
	test_event.terminate(self)
	print("  ✓ 事件已清理")

	# 延迟退出
	await get_tree().create_timer(0.5).timeout

func _exit_tree():
	# 确保清理
	if test_event:
		test_event.terminate(self)
