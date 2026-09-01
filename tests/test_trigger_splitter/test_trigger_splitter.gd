# 文件：tests/test_trigger_splitter/test_trigger_splitter.gd
extends Node

## TriggerSplitter 单元测试
##
## 测试 TriggerSplitter.can_split() 静态方法的各种场景

## ==================== 常量 ====================

const TriggerSplitterClass = preload("res://addons/fuse/editor/context_menu/trigger_splitter.gd")
const TriggerClass = preload("res://addons/fuse/core/trigger.gd")
const MultiEventTriggerClass = preload("res://addons/fuse/core/multi_event_trigger.gd")
const EventBindingClass = preload("res://addons/fuse/core/event_binding.gd")

## ==================== 测试状态 ====================

var _test_count: int = 0
var _pass_count: int = 0
var _fail_count: int = 0

## ==================== 生命周期 ====================

func _ready() -> void:
	print("========================================")
	print("TriggerSplitter 单元测试")
	print("========================================")

	# 运行所有测试
	test_can_split_multi_trigger_with_two_bindings()
	test_can_split_rejects_single_binding()
	test_can_split_rejects_regular_trigger()
	test_can_split_rejects_regular_node()
	test_resolve_owner_returns_parent_owner()
	test_resolve_owner_falls_back_to_scene_root()

	# 输出测试报告
	_print_test_report()

	# 退出场景
	get_tree().quit()

## ==================== 测试用例 ====================

## 测试：可以拆分有两个 EventBinding 的 MultiEventTrigger
func test_can_split_multi_trigger_with_two_bindings() -> void:
	_test_count += 1
	var test_name: String = "test_can_split_multi_trigger_with_two_bindings"
	print("\n[%s] 开始测试..." % test_name)

	# 创建 MultiEventTrigger
	var multi_trigger := MultiEventTriggerClass.new()
	multi_trigger.name = "MultiEventTrigger"

	# 添加两个 EventBinding
	var binding1 := EventBindingClass.new()
	binding1.enabled = true
	multi_trigger.event_bindings.append(binding1)

	var binding2 := EventBindingClass.new()
	binding2.enabled = true
	multi_trigger.event_bindings.append(binding2)

	# 执行测试
	var result: bool = TriggerSplitterClass.can_split(multi_trigger)

	# 验证结果
	if result == true:
		_pass_count += 1
		print("[PASS] %s: 有两个 EventBinding 的 MultiEventTrigger 可以拆分" % test_name)
	else:
		_fail_count += 1
		print("[FAIL] %s: 期望返回 true，实际返回 %s" % [test_name, result])

## 测试：拒绝拆分只有一个 EventBinding 的 MultiEventTrigger
func test_can_split_rejects_single_binding() -> void:
	_test_count += 1
	var test_name: String = "test_can_split_rejects_single_binding"
	print("\n[%s] 开始测试..." % test_name)

	# 创建 MultiEventTrigger
	var multi_trigger := MultiEventTriggerClass.new()
	multi_trigger.name = "MultiEventTrigger"

	# 只添加一个 EventBinding
	var binding1 := EventBindingClass.new()
	binding1.enabled = true
	multi_trigger.event_bindings.append(binding1)

	# 执行测试
	var result: bool = TriggerSplitterClass.can_split(multi_trigger)

	# 验证结果
	if result == false:
		_pass_count += 1
		print("[PASS] %s: 只有一个 EventBinding 的 MultiEventTrigger 无法拆分" % test_name)
	else:
		_fail_count += 1
		print("[FAIL] %s: 期望返回 false，实际返回 %s" % [test_name, result])

## 测试：拒绝拆分普通 Trigger 节点
func test_can_split_rejects_regular_trigger() -> void:
	_test_count += 1
	var test_name: String = "test_can_split_rejects_regular_trigger"
	print("\n[%s] 开始测试..." % test_name)

	# 创建普通 Trigger
	var trigger := TriggerClass.new()
	trigger.name = "RegularTrigger"

	# 执行测试
	var result: bool = TriggerSplitterClass.can_split(trigger)

	# 验证结果
	if result == false:
		_pass_count += 1
		print("[PASS] %s: 普通 Trigger 节点无法拆分" % test_name)
	else:
		_fail_count += 1
		print("[FAIL] %s: 期望返回 false，实际返回 %s" % [test_name, result])

## 测试：拒绝拆分普通 Node 节点
func test_can_split_rejects_regular_node() -> void:
	_test_count += 1
	var test_name: String = "test_can_split_rejects_regular_node"
	print("\n[%s] 开始测试..." % test_name)

	# 创建普通 Node
	var regular_node := Node.new()
	regular_node.name = "RegularNode"

	# 执行测试
	var result: bool = TriggerSplitterClass.can_split(regular_node)

	# 验证结果
	if result == false:
		_pass_count += 1
		print("[PASS] %s: 普通 Node 节点无法拆分" % test_name)
	else:
		_fail_count += 1
		print("[FAIL] %s: 期望返回 false，实际返回 %s" % [test_name, result])

## 测试：父节点 owner 非空时 _resolve_owner 返回该 owner
func test_resolve_owner_returns_parent_owner() -> void:
	_test_count += 1
	var test_name: String = "test_resolve_owner_returns_parent_owner"
	print("\n[%s] 开始测试..." % test_name)

	# 构造 root / parent 两层，parent.owner 指向 root（深层节点的常见情况）
	var root := Node.new()
	root.name = "SceneRoot"
	add_child(root)

	var parent := Node.new()
	parent.name = "Parent"
	root.add_child(parent)
	parent.owner = root

	var resolved: Node = TriggerSplitterClass._resolve_owner(parent)

	# 清理
	root.queue_free()

	# 验证结果
	if resolved == root:
		_pass_count += 1
		print("[PASS] %s: owner 非空时返回 parent.owner" % test_name)
	else:
		_fail_count += 1
		print("[FAIL] %s: 期望返回 root，实际返回 %s" % [test_name, resolved])

## 测试：父节点即场景根（owner 为 null）时 _resolve_owner 回落为父节点本身
## 回归用例：MultiEventTrigger 直接挂在场景根下时，parent.owner 为 null，
## 新节点 owner 若被设为 null 将不出现在场景面板且保存时被丢弃
func test_resolve_owner_falls_back_to_scene_root() -> void:
	_test_count += 1
	var test_name: String = "test_resolve_owner_falls_back_to_scene_root"
	print("\n[%s] 开始测试..." % test_name)

	# 场景根的 owner 恒为 null（headless 下 add_child 也不会设置 owner）
	var parent := Node.new()
	parent.name = "SceneRoot"
	add_child(parent)

	var resolved: Node = TriggerSplitterClass._resolve_owner(parent)

	# 清理
	parent.queue_free()

	# 验证结果
	if resolved == parent:
		_pass_count += 1
		print("[PASS] %s: owner 为 null 时回落为父节点本身" % test_name)
	else:
		_fail_count += 1
		print("[FAIL] %s: 期望返回 parent 本身，实际返回 %s" % [test_name, resolved])

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
