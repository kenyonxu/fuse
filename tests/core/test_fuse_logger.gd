# 文件：tests/core/test_fuse_logger.gd
extends Node

## FuseLogger.should_log 阈值式过滤语义测试
##
## 语义矩阵（组件级别 → 可见消息）：
## NONE / ERROR → 仅 ERROR
## WARNING     → ERROR + WARNING
## INFO        → ERROR + WARNING + INFO
## DEBUG       → 全部

var _test_count: int = 0
var _pass_count: int = 0
var _fail_count: int = 0

func _ready() -> void:
	print("=== Running Test: FuseLogger.should_log ===")
	_test_threshold_matrix()
	_test_error_survives_none()
	_print_test_report()
	get_tree().quit(1 if _fail_count > 0 else 0)

## 全矩阵断言：5 组件级别 × 4 消息级别
func _test_threshold_matrix() -> void:
	# 每行：组件级别 → [ERROR, WARNING, INFO, DEBUG] 的期望可见性
	var expected: Dictionary = {
		FuseLogger.LogLevel.NONE: [true, false, false, false],
		FuseLogger.LogLevel.ERROR: [true, false, false, false],
		FuseLogger.LogLevel.WARNING: [true, true, false, false],
		FuseLogger.LogLevel.INFO: [true, true, true, false],
		FuseLogger.LogLevel.DEBUG: [true, true, true, true],
	}
	var message_levels: Array[int] = [
		FuseLogger.LogLevel.ERROR,
		FuseLogger.LogLevel.WARNING,
		FuseLogger.LogLevel.INFO,
		FuseLogger.LogLevel.DEBUG,
	]

	for component_level: int in expected:
		var row: Array = expected[component_level]
		for i: int in message_levels.size():
			var actual: bool = FuseLogger.should_log(component_level, message_levels[i])
			_assert_eq(actual, row[i], "%s 组件 + %s 消息" % [
				FuseLogger.LogLevel.keys()[component_level],
				FuseLogger.LogLevel.keys()[message_levels[i]],
			])

## 核心诉求单独强调：NONE（静音）组件的 ERROR 不被吞掉
func _test_error_survives_none() -> void:
	_assert_eq(
		FuseLogger.should_log(FuseLogger.LogLevel.NONE, FuseLogger.LogLevel.ERROR),
		true,
		"NONE 组件仍能看到 ERROR"
	)

func _assert_eq(actual: Variant, expected: Variant, label: String) -> void:
	_test_count += 1
	if actual == expected:
		_pass_count += 1
		print("[PASS] " + label)
	else:
		_fail_count += 1
		push_error("[FAIL] %s: 期望 %s，实际 %s" % [label, str(expected), str(actual)])

func _print_test_report() -> void:
	print("=== Test Complete: %d/%d passed ===" % [_pass_count, _test_count])
