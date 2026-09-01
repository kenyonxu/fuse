# 文件：tests/test_trigger_merger/test_trigger_merger.gd
extends Node

## TriggerMerger 单元测试
##
## 测试 TriggerMerger.can_merge() 静态方法的各种场景

## ==================== 常量 ====================

const TriggerMergerClass = preload("res://addons/fuse/editor/context_menu/trigger_merger.gd")
const TriggerClass = preload("res://addons/fuse/core/trigger.gd")

## ==================== 测试状态 ====================

var _test_count: int = 0
var _pass_count: int = 0
var _fail_count: int = 0

## ==================== 生命周期 ====================

func _ready() -> void:
	print("========================================")
	print("TriggerMerger 单元测试")
	print("========================================")

	# 运行所有测试
	test_can_merge_two_triggers()
	test_can_merge_rejects_single_trigger()
	test_can_merge_rejects_mixed_nodes()
	test_can_merge_rejects_different_parents()
	test_resolve_owner_returns_parent_owner()
	test_resolve_owner_falls_back_to_scene_root()

	# 输出测试报告
	_print_test_report()

	# 退出场景
	get_tree().quit()

## ==================== 测试用例 ====================

## 测试：可以合并两个同父节点的 Trigger
func test_can_merge_two_triggers() -> void:
	_test_count += 1
	var test_name: String = "test_can_merge_two_triggers"
	print("\n[%s] 开始测试..." % test_name)

	# 创建父节点
	var parent := Node.new()
	parent.name = "TestParent"
	add_child(parent)

	# 创建两个 Trigger
	var trigger1 := TriggerClass.new()
	trigger1.name = "Trigger1"
	parent.add_child(trigger1)

	var trigger2 := TriggerClass.new()
	trigger2.name = "Trigger2"
	parent.add_child(trigger2)

	# 构建节点数组
	var nodes: Array[Node] = [trigger1, trigger2]

	# 执行测试
	var result: bool = TriggerMergerClass.can_merge(nodes)

	# 清理
	parent.queue_free()

	# 验证结果
	if result == true:
		_pass_count += 1
		print("[PASS] %s: 两个同父节点的 Trigger 可以合并" % test_name)
	else:
		_fail_count += 1
		print("[FAIL] %s: 期望返回 true，实际返回 %s" % [test_name, result])

## 测试：拒绝合并单个 Trigger
func test_can_merge_rejects_single_trigger() -> void:
	_test_count += 1
	var test_name: String = "test_can_merge_rejects_single_trigger"
	print("\n[%s] 开始测试..." % test_name)

	# 创建父节点
	var parent := Node.new()
	parent.name = "TestParent"
	add_child(parent)

	# 创建单个 Trigger
	var trigger1 := TriggerClass.new()
	trigger1.name = "Trigger1"
	parent.add_child(trigger1)

	# 构建节点数组（只有一个元素）
	var nodes: Array[Node] = [trigger1]

	# 执行测试
	var result: bool = TriggerMergerClass.can_merge(nodes)

	# 清理
	parent.queue_free()

	# 验证结果
	if result == false:
		_pass_count += 1
		print("[PASS] %s: 单个 Trigger 无法合并" % test_name)
	else:
		_fail_count += 1
		print("[FAIL] %s: 期望返回 false，实际返回 %s" % [test_name, result])

## 测试：拒绝合并混合节点类型
func test_can_merge_rejects_mixed_nodes() -> void:
	_test_count += 1
	var test_name: String = "test_can_merge_rejects_mixed_nodes"
	print("\n[%s] 开始测试..." % test_name)

	# 创建父节点
	var parent := Node.new()
	parent.name = "TestParent"
	add_child(parent)

	# 创建一个 Trigger
	var trigger1 := TriggerClass.new()
	trigger1.name = "Trigger1"
	parent.add_child(trigger1)

	# 创建一个普通 Node
	var regular_node := Node.new()
	regular_node.name = "RegularNode"
	parent.add_child(regular_node)

	# 构建混合节点数组
	var nodes: Array[Node] = [trigger1, regular_node]

	# 执行测试
	var result: bool = TriggerMergerClass.can_merge(nodes)

	# 清理
	parent.queue_free()

	# 验证结果
	if result == false:
		_pass_count += 1
		print("[PASS] %s: 混合节点类型无法合并" % test_name)
	else:
		_fail_count += 1
		print("[FAIL] %s: 期望返回 false，实际返回 %s" % [test_name, result])

## 测试：拒绝合并不同父节点的 Trigger
func test_can_merge_rejects_different_parents() -> void:
	_test_count += 1
	var test_name: String = "test_can_merge_rejects_different_parents"
	print("\n[%s] 开始测试..." % test_name)

	# 创建两个不同的父节点
	var parent1 := Node.new()
	parent1.name = "Parent1"
	add_child(parent1)

	var parent2 := Node.new()
	parent2.name = "Parent2"
	add_child(parent2)

	# 创建两个 Trigger，分别属于不同父节点
	var trigger1 := TriggerClass.new()
	trigger1.name = "Trigger1"
	parent1.add_child(trigger1)

	var trigger2 := TriggerClass.new()
	trigger2.name = "Trigger2"
	parent2.add_child(trigger2)

	# 构建节点数组
	var nodes: Array[Node] = [trigger1, trigger2]

	# 执行测试
	var result: bool = TriggerMergerClass.can_merge(nodes)

	# 清理
	parent1.queue_free()
	parent2.queue_free()

	# 验证结果
	if result == false:
		_pass_count += 1
		print("[PASS] %s: 不同父节点的 Trigger 无法合并" % test_name)
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

	var resolved: Node = TriggerMergerClass._resolve_owner(parent)

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
## 回归用例：Trigger 直接挂在场景根下时（如 saw.tscn），parent.owner 为 null，
## 新节点 owner 若被设为 null 将不出现在场景面板且保存时被丢弃
func test_resolve_owner_falls_back_to_scene_root() -> void:
	_test_count += 1
	var test_name: String = "test_resolve_owner_falls_back_to_scene_root"
	print("\n[%s] 开始测试..." % test_name)

	# 场景根的 owner 恒为 null（headless 下 add_child 也不会设置 owner）
	var parent := Node.new()
	parent.name = "SceneRoot"
	add_child(parent)

	var resolved: Node = TriggerMergerClass._resolve_owner(parent)

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
