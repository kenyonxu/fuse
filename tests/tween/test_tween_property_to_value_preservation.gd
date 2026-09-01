# 文件：tests/tween/test_tween_property_to_value_preservation.gd
extends Node

## TweenProperty to_value 保留性回归测试
##
## 回归背景：_set_default_value_for_type 原本无条件把 to_value 覆盖成属性类型
## 默认值。编辑器里 Inspector 每次重建（_get_property_list → _update_target_node_info
## → _update_property_type_info）都会触发该覆盖，导致重启编辑器后已保存的
## to_value（如 1.0）被抹成 0.0 并随场景保存写盘。
## 修复后语义：仅当当前值与新属性类型不匹配时才重置默认值。

## ==================== 常量 ====================

const TweenPropertyClass = preload("res://addons/fuse/instructions/tween/tween_property.gd")

## ==================== 测试状态 ====================

var _test_count: int = 0
var _pass_count: int = 0
var _fail_count: int = 0

## ==================== 生命周期 ====================

func _ready() -> void:
	print("========================================")
	print("TweenProperty to_value 保留性测试")
	print("========================================")

	test_reparse_preserves_matching_type_value()
	test_switch_property_resets_mismatched_type()
	test_float_property_preserves_value()

	_print_test_report()
	get_tree().quit(1 if _fail_count > 0 else 0)

## ==================== 测试用例 ====================

## 回归用例：类型匹配时重新解析（模拟 Inspector 重建）不得覆盖 to_value
func test_reparse_preserves_matching_type_value() -> void:
	_test_count += 1
	var test_name: String = "test_reparse_preserves_matching_type_value"
	print("\n[%s] 开始测试..." % test_name)

	var node := Node2D.new()
	add_child(node)

	var instr = TweenPropertyClass.new()
	instr._target_node_instance = node
	instr.property_path = "modulate"
	instr.to_value = Color.RED

	# 模拟编辑器 Inspector 重建时的重新解析链路
	instr._update_property_type_info()

	var preserved: bool = instr.to_value == Color.RED
	node.queue_free()

	if preserved:
		_pass_count += 1
		print("[PASS] %s: Color 属性重新解析后保留 to_value" % test_name)
	else:
		_fail_count += 1
		print("[FAIL] %s: to_value 被覆盖为 %s，期望保留 Color.RED" % [test_name, instr.to_value])

## 原设计意图：切换到不同类型属性时重置为该类型默认值
func test_switch_property_resets_mismatched_type() -> void:
	_test_count += 1
	var test_name: String = "test_switch_property_resets_mismatched_type"
	print("\n[%s] 开始测试..." % test_name)

	var node := Node2D.new()
	add_child(node)

	var instr = TweenPropertyClass.new()
	instr._target_node_instance = node
	instr.to_value = 3.14
	instr.property_path = "modulate"

	var reset_ok: bool = instr.to_value == Color.WHITE
	node.queue_free()

	if reset_ok:
		_pass_count += 1
		print("[PASS] %s: float→Color 类型不匹配时重置为 Color.WHITE" % test_name)
	else:
		_fail_count += 1
		print("[FAIL] %s: to_value = %s，期望 Color.WHITE" % [test_name, instr.to_value])

## float 属性重新解析后保留已有值（对应 progress_ratio = 1.0 丢失场景）
func test_float_property_preserves_value() -> void:
	_test_count += 1
	var test_name: String = "test_float_property_preserves_value"
	print("\n[%s] 开始测试..." % test_name)

	var node := Node2D.new()
	add_child(node)

	var instr = TweenPropertyClass.new()
	instr._target_node_instance = node
	instr.property_path = "rotation"
	instr.to_value = 1.0

	# 模拟编辑器 Inspector 重建时的重新解析链路
	instr._update_property_type_info()

	var preserved: bool = is_equal_approx(float(instr.to_value), 1.0)
	node.queue_free()

	if preserved:
		_pass_count += 1
		print("[PASS] %s: float 属性重新解析后保留 to_value = 1.0" % test_name)
	else:
		_fail_count += 1
		print("[FAIL] %s: to_value = %s，期望 1.0" % [test_name, instr.to_value])

## ==================== 辅助方法 ====================

## 打印测试报告
func _print_test_report() -> void:
	print("\n========================================")
	print("测试报告")
	print("========================================")
	print("总测试数: %d" % _test_count)
	print("通过: %d" % _pass_count)
	print("失败: %d" % _fail_count)
	print("通过率: %.1f%%" % (float(_pass_count) / float(_test_count) * 100.0))
	print("========================================")

	if _fail_count == 0:
		print("所有测试通过!")
	else:
		print("存在失败的测试!")
