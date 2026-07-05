## 游戏场景性能追踪脚本
## 按 P 打印性能报告，按 R 重置追踪数据
extends Node2D

func _ready() -> void:
	print("[GameScene] 性能追踪已启用 - 按 P 打印报告，按 R 重置数据")

func _input(event: InputEvent) -> void:
	# 按 P 键打印性能报告
	if event is InputEventKey and event.pressed and event.keycode == KEY_P:
		print("\n" + "=".repeat(50))
		FusePerformanceTracker.get_instance().print_report()
		print("=".repeat(50) + "\n")

	# 按 R 键重置追踪数据
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		FusePerformanceTracker.get_instance().reset()
		print("[Perf] 追踪数据已重置")

	# 按 O 键切换详细日志模式
	if event is InputEventKey and event.pressed and event.keycode == KEY_O:
		var tracker = FusePerformanceTracker.get_instance()
		tracker.log_level = 2 if tracker.log_level < 2 else 1
		print("[Perf] 详细日志模式: %s" % ("开启" if tracker.log_level == 2 else "关闭"))
