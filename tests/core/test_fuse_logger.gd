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
	_test_format_message_dual_render()
	_test_fuse_error_context_filtering()
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

## format_message 双渲染：plain 供 push_error/push_warning（无 BBCode、ASCII 级别前缀），
## rich 供 print_rich（BBCode 着色）；两版字段顺序同构
func _test_format_message_dual_render() -> void:
	var plain_error: String = FuseLogger.format_message(
		FuseLogger.LogLevel.ERROR, "Comp", "boom", "ctx", false
	)
	_assert_eq(plain_error, "[ERROR][Comp]ctx boom", "plain error 完整结构化文本")

	var plain_no_context: String = FuseLogger.format_message(
		FuseLogger.LogLevel.WARNING, "Comp", "boom", "", false
	)
	_assert_eq(plain_no_context, "[WARNING][Comp] boom", "plain 空 context 不留空括号")

	var rich_error: String = FuseLogger.format_message(
		FuseLogger.LogLevel.ERROR, "Comp", "boom", "ctx", true
	)
	_assert_eq(rich_error.contains("[color=red]"), true, "rich 版级别着色")
	_assert_eq(rich_error.contains("[/color]"), true, "rich 版闭合标签")
	_assert_eq(rich_error.contains("[[/color]"), false, "rich 版无双重方括号残留（回归）")

	var plain = [plain_error, plain_no_context]
	for line: String in plain:
		_assert_eq(line.contains("[color"), false, "plain 版不掺 BBCode 标签")

## FuseError 上下文输出：内部字段（message_key 等）不打进纯文本，自定义键保留为 key=value
func _test_fuse_error_context_filtering() -> void:
	var error := FuseError.create_validation_error_localized(
		"TestComp", "logger_test_absent_key", {}, {"node_path": "Enemy", "signal": "hit"}
	)
	var formatted: String = error.get_formatted_message()
	_assert_eq(formatted.contains("message_key"), false, "内部字段 message_key 不外显")
	_assert_eq(formatted.contains("message_args"), false, "内部字段 message_args 不外显")
	_assert_eq(formatted.contains("node_path=Enemy"), true, "自定义上下文保留为 key=value")
	_assert_eq(formatted.contains("signal=hit"), true, "多个自定义上下文以逗号分隔保留")

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
