# 文件：tests/test_fuse_node_utils/test_fuse_node_utils.gd
extends Node

## FuseNodeUtils 单元测试
##
## 重点测试 find_node_from_resource_context 的资源持有节点查找：
## Trigger（event_definition/action_runner）与 MultiEventTrigger（event_bindings）两种结构

## ==================== 常量 ====================

const FuseNodeUtils = preload("res://addons/fuse/utils/fuse_node_utils.gd")
const TriggerClass = preload("res://addons/fuse/core/trigger.gd")
const MultiEventTriggerClass = preload("res://addons/fuse/core/multi_event_trigger.gd")
const EventBindingClass = preload("res://addons/fuse/core/event_binding.gd")
const ActionRunnerClass = preload("res://addons/fuse/core/base/action_runner.gd")
const ProgressRatioEventClass = preload("res://addons/fuse/events/node/on_path_follow_2d_progress_ratio.gd")
const TweenPropertyClass = preload("res://addons/fuse/instructions/tween/tween_property.gd")
const IfThenClass = preload("res://addons/fuse/instructions/flow_control/if_then.gd")
const CheckNodePropertyClass = preload("res://addons/fuse/conditions/node/check_node_property.gd")

## ==================== 测试状态 ====================

var _test_count: int = 0
var _pass_count: int = 0
var _fail_count: int = 0

## ==================== 生命周期 ====================

func _ready() -> void:
	print("========================================")
	print("FuseNodeUtils 单元测试")
	print("========================================")

	# 运行所有测试
	test_resource_context_resolves_from_trigger()
	test_resource_context_resolves_instruction_in_multi_event_trigger()
	test_resource_context_resolves_event_in_multi_event_trigger()
	test_resource_context_returns_null_for_unknown_resource()
	test_resource_context_resolves_nested_condition_in_if_then()
	test_resource_context_resolves_nested_instruction_in_if_then()
	test_resource_context_resolves_condition_in_trigger_conditions()

	# 输出测试报告
	_print_test_report()

	# 退出场景
	get_tree().quit(1 if _fail_count > 0 else 0)

## ==================== 测试用例 ====================

## 测试：Trigger 节点 action_runner 内的指令可通过 ".." 解析到 Trigger 的父节点
func test_resource_context_resolves_from_trigger() -> void:
	_test_count += 1
	var test_name: String = "test_resource_context_resolves_from_trigger"
	print("\n[%s] 开始测试..." % test_name)

	# 构造 root / Trigger / action_runner.instructions[0] = instr
	var root := Node2D.new()
	root.name = "Saw"
	add_child(root)

	var trigger := TriggerClass.new()
	trigger.name = "OnProgressRatio0"
	root.add_child(trigger)

	var instr := TweenPropertyClass.new()
	var runner := ActionRunnerClass.new()
	runner.instructions = [instr]
	trigger.action_runner = runner

	var resolved: Node = FuseNodeUtils.find_node_from_resource_context(root, instr, NodePath(".."))

	# 清理
	root.queue_free()

	# 验证结果：应解析到 Trigger 的父节点 root
	if resolved == root:
		_pass_count += 1
		print("[PASS] %s: Trigger 内指令的 '..' 解析到其父节点" % test_name)
	else:
		_fail_count += 1
		print("[FAIL] %s: 期望返回 root，实际返回 %s" % [test_name, resolved])

## 测试：MultiEventTrigger 的 event_bindings[].action_runner 内的指令可通过 ".." 解析到父节点
## 回归用例：合并 Trigger 后指令存于 EventBinding 中，_find_resource_owner 原本不认识该结构，
## 导致编辑器里 TweenProperty 解析不到目标节点、属性列表为空（如 saw.tscn 的 progress_ratio）
func test_resource_context_resolves_instruction_in_multi_event_trigger() -> void:
	_test_count += 1
	var test_name: String = "test_resource_context_resolves_instruction_in_multi_event_trigger"
	print("\n[%s] 开始测试..." % test_name)

	# 构造 root / MultiEventTrigger / event_bindings[0].action_runner.instructions[0] = instr
	var root := Node2D.new()
	root.name = "Saw"
	add_child(root)

	var multi := MultiEventTriggerClass.new()
	multi.name = "MultiEventTrigger"
	root.add_child(multi)

	var instr := TweenPropertyClass.new()
	var runner := ActionRunnerClass.new()
	runner.instructions = [instr]

	var binding := EventBindingClass.new()
	binding.action_runner = runner
	multi.event_bindings = [binding]

	var resolved: Node = FuseNodeUtils.find_node_from_resource_context(root, instr, NodePath(".."))

	# 清理
	root.queue_free()

	# 验证结果：应解析到 MultiEventTrigger 的父节点 root
	if resolved == root:
		_pass_count += 1
		print("[PASS] %s: MultiEventTrigger 内指令的 '..' 解析到其父节点" % test_name)
	else:
		_fail_count += 1
		print("[FAIL] %s: 期望返回 root，实际返回 %s" % [test_name, resolved])

## 测试：MultiEventTrigger 的 event_bindings[].event 事件资源可通过 "." 解析到 MultiEventTrigger 自身
func test_resource_context_resolves_event_in_multi_event_trigger() -> void:
	_test_count += 1
	var test_name: String = "test_resource_context_resolves_event_in_multi_event_trigger"
	print("\n[%s] 开始测试..." % test_name)

	var root := Node2D.new()
	root.name = "Saw"
	add_child(root)

	var multi := MultiEventTriggerClass.new()
	multi.name = "MultiEventTrigger"
	root.add_child(multi)

	# BaseEvent 是抽象类，用具体事件子类（saw.tscn 使用的同款事件）
	var event_res := ProgressRatioEventClass.new()
	var binding := EventBindingClass.new()
	binding.event = event_res
	multi.event_bindings = [binding]

	var resolved: Node = FuseNodeUtils.find_node_from_resource_context(root, event_res, NodePath("."))

	# 清理
	root.queue_free()

	# 验证结果："." 应解析到持有资源的 MultiEventTrigger 自身
	if resolved == multi:
		_pass_count += 1
		print("[PASS] %s: EventBinding 内事件的 '.' 解析到 MultiEventTrigger 自身" % test_name)
	else:
		_fail_count += 1
		print("[FAIL] %s: 期望返回 MultiEventTrigger，实际返回 %s" % [test_name, resolved])

## 测试：不属于任何节点的资源按名字降级查找，名字不存在时返回 null
func test_resource_context_returns_null_for_unknown_resource() -> void:
	_test_count += 1
	var test_name: String = "test_resource_context_returns_null_for_unknown_resource"
	print("\n[%s] 开始测试..." % test_name)

	var root := Node2D.new()
	root.name = "Saw"
	add_child(root)

	var orphan := TweenPropertyClass.new()

	# 资源无持有节点 → 降级按最后一级名字查找；名字不存在 → null
	var resolved: Node = FuseNodeUtils.find_node_from_resource_context(root, orphan, NodePath("../NoSuchNode"))

	# 清理
	root.queue_free()

	# 验证结果
	if resolved == null:
		_pass_count += 1
		print("[PASS] %s: 无持有者的资源解析不存在的名字返回 null" % test_name)
	else:
		_fail_count += 1
		print("[FAIL] %s: 期望返回 null，实际返回 %s" % [test_name, resolved])

## 测试：IfThen.condition 里嵌套的条件资源可通过 "../.." 解析到 Trigger 的上级
## 回归用例：player.tscn OnInputActionJump 的 If/Then 内嵌 CheckNodeProperty 时，
## _check_action_runner_ownership 原本只查 runner.instructions 直接成员，
## 找不到嵌套条件的宿主 → 编辑器属性下拉为空
func test_resource_context_resolves_nested_condition_in_if_then() -> void:
	_test_count += 1
	var test_name: String = "test_resource_context_resolves_nested_condition_in_if_then"
	print("\n[%s] 开始测试..." % test_name)

	# 复刻 player.tscn 结构：root(player) / PlayerController / Trigger
	var root := Node2D.new()
	root.name = "player"
	add_child(root)

	var controller := Node.new()
	controller.name = "PlayerController"
	root.add_child(controller)

	var trigger := TriggerClass.new()
	trigger.name = "OnInputActionJump"
	controller.add_child(trigger)

	var condition := CheckNodePropertyClass.new()
	var if_then := IfThenClass.new()
	if_then.condition = condition
	var runner := ActionRunnerClass.new()
	runner.instructions = [if_then]
	trigger.action_runner = runner

	var resolved: Node = FuseNodeUtils.find_node_from_resource_context(root, condition, NodePath("../.."))

	# 清理
	root.queue_free()

	# 验证结果：从 Trigger 起算 "../.." 应解析到 root
	if resolved == root:
		_pass_count += 1
		print("[PASS] %s: IfThen 嵌套条件的 '../..' 解析到场景根" % test_name)
	else:
		_fail_count += 1
		print("[FAIL] %s: 期望返回 root，实际返回 %s" % [test_name, resolved])

## 测试：IfThen.instructions 里嵌套的指令资源可通过 ".." 解析到 Trigger 的父节点
func test_resource_context_resolves_nested_instruction_in_if_then() -> void:
	_test_count += 1
	var test_name: String = "test_resource_context_resolves_nested_instruction_in_if_then"
	print("\n[%s] 开始测试..." % test_name)

	var root := Node2D.new()
	root.name = "player"
	add_child(root)

	var controller := Node.new()
	controller.name = "PlayerController"
	root.add_child(controller)

	var trigger := TriggerClass.new()
	trigger.name = "OnInputActionJump"
	controller.add_child(trigger)

	var nested_instr := TweenPropertyClass.new()
	var if_then := IfThenClass.new()
	if_then.instructions = [nested_instr]
	var runner := ActionRunnerClass.new()
	runner.instructions = [if_then]
	trigger.action_runner = runner

	var resolved: Node = FuseNodeUtils.find_node_from_resource_context(root, nested_instr, NodePath(".."))

	# 清理
	root.queue_free()

	# 验证结果：从 Trigger 起算 ".." 应解析到 controller
	if resolved == controller:
		_pass_count += 1
		print("[PASS] %s: IfThen 嵌套指令的 '..' 解析到 Trigger 父节点" % test_name)
	else:
		_fail_count += 1
		print("[FAIL] %s: 期望返回 controller，实际返回 %s" % [test_name, resolved])

## 测试：Trigger.conditions 数组里的门控条件可通过 ".." 解析到 Trigger 的父节点
## 回归用例：_find_resource_owner 原本不检查 Trigger 自带的 conditions 数组
func test_resource_context_resolves_condition_in_trigger_conditions() -> void:
	_test_count += 1
	var test_name: String = "test_resource_context_resolves_condition_in_trigger_conditions"
	print("\n[%s] 开始测试..." % test_name)

	var root := Node2D.new()
	root.name = "player"
	add_child(root)

	var controller := Node.new()
	controller.name = "PlayerController"
	root.add_child(controller)

	var trigger := TriggerClass.new()
	trigger.name = "OnInputActionJump"
	controller.add_child(trigger)

	var condition := CheckNodePropertyClass.new()
	trigger.conditions = [condition]

	var resolved: Node = FuseNodeUtils.find_node_from_resource_context(root, condition, NodePath(".."))

	# 清理
	root.queue_free()

	# 验证结果：从 Trigger 起算 ".." 应解析到 controller
	if resolved == controller:
		_pass_count += 1
		print("[PASS] %s: Trigger.conditions 条件的 '..' 解析到 Trigger 父节点" % test_name)
	else:
		_fail_count += 1
		print("[FAIL] %s: 期望返回 controller，实际返回 %s" % [test_name, resolved])

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
