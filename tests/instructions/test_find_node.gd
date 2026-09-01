extends Node

## Find Node 指令测试脚本

# 测试节点
var test_parent: Node
var test_owner: Node

# 执行上下文
var context: ExecutionContext

# 测试结果
var tests_passed := 0
var tests_failed := 0
var test_results := []

func _ready():
	print("=== Find Node 指令测试开始 ===\n")

	# 初始化测试环境
	_setup_test_environment()

	# 运行测试
	_test_find_by_name_single()
	_test_find_by_name_multiple()
	_test_find_by_name_recursive()
	_test_find_by_type_single()
	_test_find_by_type_multiple()
	_test_find_by_group_single()
	_test_find_by_group_multiple()
	_test_search_scope_children()
	_test_search_scope_scene()
	_test_search_scope_global()
	_test_save_to_local_variable()
	_test_save_to_global_variable()
	_test_validation()
	_test_not_found_case()
	_test_error_handling_strict()
	_test_error_handling_warning()
	_test_error_handling_silent()

	# 输出测试结果
	_print_test_results()

	# 清理
	_cleanup()

	# 退出测试
	print("\n=== 测试完成 ===")
	get_tree().quit()

## 初始化测试环境
func _setup_test_environment():
	# 获取场景中的节点
	test_parent = $TestParent
	test_owner = self

	# 创建执行上下文
	var scene_tree = get_tree()
	context = ExecutionContext.new(test_owner, null, null, scene_tree)

	print("测试环境初始化完成")
	print("  - 测试父节点: %s" % test_parent.name)
	print("  - 测试所有者: %s" % test_owner.name)
	print("  - 创建执行上下文\n")

## 测试 1: 按名称查找单个节点
func _test_find_by_name_single():
	print("测试 1: 按名称查找单个节点")

	# 创建指令
	var instruction_script = load("res://addons/fuse/instructions/find_node.gd")
	var instruction = instruction_script.new()
	instruction.search_type = 0  # BY_NAME
	instruction.search_scope = 0  # CHILDREN
	instruction.search_value = "Child1"
	instruction.recursive = true
	instruction.first_match_only = true
	instruction.result_variable = "found_node"
	instruction.is_global = false

	# 执行指令
	instruction.execute(context)

	# 验证结果（指令是同步执行的，不需要 await）
	var result = context.get_variable("found_node")

	if result != null:
		var expected_path = "/root/TestFindNodeInstruction/TestParent/Child1"
		if result == expected_path:
			_test_pass("按名称查找单个节点成功")
			print("  找到节点路径: %s" % result)
		else:
			_test_fail("按名称查找单个节点失败：路径不匹配")
			print("  期望: %s" % expected_path)
			print("  实际: %s" % result)
	else:
		_test_fail("按名称查找单个节点失败：未找到节点")

	print()

## 测试 2: 按名称查找多个节点
func _test_find_by_name_multiple():
	print("测试 2: 按名称查找多个节点（使用不同名称的节点）")

	# 创建多个不同名称的节点，用于测试 first_match_only = false
	var extra_child1 = Node2D.new()
	extra_child1.name = "SearchNode1"
	test_owner.add_child(extra_child1)

	var extra_child2 = Node2D.new()
	extra_child2.name = "SearchNode2"
	test_owner.add_child(extra_child2)

	var extra_child3 = Node2D.new()
	extra_child3.name = "SearchNode3"
	test_owner.add_child(extra_child3)

	# 注意：这里我们实际上是在测试查找所有子节点
	# 因为 Godot 不允许完全同名的节点，我们改用按类型查找

	# 创建指令（改用按类型查找）
	var instruction_script = load("res://addons/fuse/instructions/find_node.gd")
	var instruction = instruction_script.new()
	instruction.search_type = 1  # BY_TYPE - 改为按类型查找
	instruction.search_scope = 0  # CHILDREN
	instruction.search_value = "Node2D"
	instruction.recursive = false  # 只查找直接子节点
	instruction.first_match_only = false
	instruction.result_variable = "found_nodes"
	instruction.is_global = false

	# 执行指令
	instruction.execute(context)

	# 验证结果（指令是同步执行的，不需要 await）
	var result = context.get_variable("found_nodes")

	# 应该找到至少3个 Node2D (SearchNode1, SearchNode2, SearchNode3)
	if result is Array and result.size() >= 3:
		_test_pass("按类型查找多个节点成功")
		print("  找到 %d 个 Node2D 节点" % result.size())
	else:
		_test_fail("按类型查找多个节点失败")
		if result is Array:
			print("  期望至少找到 3 个 Node2D 节点，实际找到: %d" % result.size())
		else:
			print("  结果类型错误: %s" % type_string(typeof(result)))

	# 清理
	extra_child1.queue_free()
	extra_child2.queue_free()
	extra_child3.queue_free()
	print()

## 测试 3: 按名称递归查找
func _test_find_by_name_recursive():
	print("测试 3: 按名称递归查找")

	# 创建指令
	var instruction_script = load("res://addons/fuse/instructions/find_node.gd")
	var instruction = instruction_script.new()
	instruction.search_type = 0  # BY_NAME
	instruction.search_scope = 0  # CHILDREN
	instruction.search_value = "GrandChild1"
	instruction.recursive = true
	instruction.first_match_only = true
	instruction.result_variable = "found_node"
	instruction.is_global = false

	# 执行指令
	instruction.execute(context)

	# 验证结果（指令是同步执行的，不需要 await）
	var result = context.get_variable("found_node")

	if result != null:
		var expected_path = "/root/TestFindNodeInstruction/TestParent/SubContainer/GrandChild1"
		if result == expected_path:
			_test_pass("递归查找孙节点成功")
			print("  找到节点路径: %s" % result)
		else:
			_test_fail("递归查找孙节点失败：路径不匹配")
	else:
		_test_fail("递归查找孙节点失败：未找到节点")

	print()

## 测试 4: 按类型查找单个节点
func _test_find_by_type_single():
	print("测试 4: 按类型查找单个节点")

	# 创建指令
	var instruction_script = load("res://addons/fuse/instructions/find_node.gd")
	var instruction = instruction_script.new()
	instruction.search_type = 1  # BY_TYPE
	instruction.search_scope = 0  # CHILDREN
	instruction.search_value = "Node2D"
	instruction.recursive = true
	instruction.first_match_only = true
	instruction.result_variable = "found_node"
	instruction.is_global = false

	# 执行指令
	instruction.execute(context)

	# 验证结果（指令是同步执行的，不需要 await）
	var result = context.get_variable("found_node")

	if result != null:
		# 验证路径有效且指向 Node2D 类型的节点
		var node = get_node(NodePath(result))
		if node and node is Node2D:
			_test_pass("按类型查找单个节点成功")
			print("  找到 Node2D 节点: %s" % result)
		else:
			_test_fail("按类型查找单个节点失败：节点类型不匹配")
			print("  路径: %s" % result)
			print("  节点类型: %s" % (node.get_class() if node else "null"))
	else:
		_test_fail("按类型查找单个节点失败")
		print("  结果: %s" % result)

	print()

## 测试 5: 按类型查找多个节点
func _test_find_by_type_multiple():
	print("测试 5: 按类型查找多个节点")

	# 创建指令
	var instruction_script = load("res://addons/fuse/instructions/find_node.gd")
	var instruction = instruction_script.new()
	instruction.search_type = 1  # BY_TYPE
	instruction.search_scope = 0  # CHILDREN
	instruction.search_value = "Node2D"
	instruction.recursive = true
	instruction.first_match_only = false
	instruction.result_variable = "found_nodes"
	instruction.is_global = false

	# 执行指令
	instruction.execute(context)

	# 验证结果（指令是同步执行的，不需要 await）
	var result = context.get_variable("found_nodes")

	if result is Array and result.size() >= 3:
		_test_pass("按类型查找多个节点成功")
		print("  找到 %d 个 Node2D 节点" % result.size())
	else:
		_test_fail("按类型查找多个节点失败")
		if result is Array:
			print("  期望至少找到 3 个 Node2D 节点，实际找到: %d" % result.size())
		else:
			print("  结果类型错误")

	print()

## 测试 6: 按组查找单个节点
func _test_find_by_group_single():
	print("测试 6: 按组查找单个节点")

	# 手动创建测试组节点（因为在 headless 模式下场景组可能未初始化）
	var group_member1 = Node.new()
	group_member1.name = "RuntimeGroupMember1"
	add_child(group_member1)
	group_member1.add_to_group("test_group")

	var group_member2 = Node2D.new()
	group_member2.name = "RuntimeGroupMember2"
	add_child(group_member2)
	group_member2.add_to_group("test_group")

	# 先检查组是否存在
	var tree = get_tree()
	var group_nodes = tree.get_nodes_in_group("test_group")
	print("  组 'test_group' 中的节点数: %d" % group_nodes.size())
	for node in group_nodes:
		print("    - %s (%s)" % [node.name, node.get_class()])

	# 创建指令
	var instruction_script = load("res://addons/fuse/instructions/find_node.gd")
	var instruction = instruction_script.new()
	instruction.search_type = 2  # BY_GROUP
	instruction.search_scope = 2  # GLOBAL
	instruction.search_value = "test_group"
	instruction.first_match_only = true
	instruction.result_variable = "found_node"
	instruction.is_global = false

	# 执行指令
	instruction.execute(context)

	# 验证结果（指令是同步执行的，不需要 await）
	var result = context.get_variable("found_node")

	if result != null:
		_test_pass("按组查找单个节点成功")
		print("  找到组成员节点: %s" % result)
	else:
		_test_fail("按组查找单个节点失败")

	# 清理运行时创建的节点
	group_member1.queue_free()
	group_member2.queue_free()
	print()

## 测试 7: 按组查找多个节点
func _test_find_by_group_multiple():
	print("测试 7: 按组查找多个节点")

	# 手动创建测试组节点
	var group_member1 = Node.new()
	group_member1.name = "RuntimeGroupMember1"
	add_child(group_member1)
	group_member1.add_to_group("test_group")

	var group_member2 = Node2D.new()
	group_member2.name = "RuntimeGroupMember2"
	add_child(group_member2)
	group_member2.add_to_group("test_group")

	var group_member3 = Node.new()
	group_member3.name = "RuntimeGroupMember3"
	add_child(group_member3)
	group_member3.add_to_group("test_group")

	# 创建指令
	var instruction_script = load("res://addons/fuse/instructions/find_node.gd")
	var instruction = instruction_script.new()
	instruction.search_type = 2  # BY_GROUP
	instruction.search_scope = 2  # GLOBAL
	instruction.search_value = "test_group"
	instruction.first_match_only = false
	instruction.result_variable = "found_nodes"
	instruction.is_global = false

	# 执行指令
	instruction.execute(context)

	# 验证结果（指令是同步执行的，不需要 await）
	var result = context.get_variable("found_nodes")

	if result is Array and result.size() == 5:  # 3个运行时 + 2个场景中的
		_test_pass("按组查找多个节点成功")
		print("  找到 %d 个组成员" % result.size())
	else:
		_test_fail("按组查找多个节点失败")
		if result is Array:
			print("  期望找到 5 个组成员，实际找到: %d" % result.size())
		else:
			print("  结果类型错误")

	# 清理运行时创建的节点
	group_member1.queue_free()
	group_member2.queue_free()
	group_member3.queue_free()
	print()

## 测试 8: 搜索范围 - 子节点
func _test_search_scope_children():
	print("测试 8: 搜索范围 - 子节点")

	# 创建指令
	var instruction_script = load("res://addons/fuse/instructions/find_node.gd")
	var instruction = instruction_script.new()
	instruction.search_type = 0  # BY_NAME
	instruction.search_scope = 0  # CHILDREN
	instruction.search_value = "Child1"
	instruction.first_match_only = true
	instruction.result_variable = "found_node"
	instruction.is_global = false

	# 执行指令
	instruction.execute(context)

	# 验证结果（指令是同步执行的，不需要 await）
	var result = context.get_variable("found_node")

	if result != null and "Child1" in result:
		_test_pass("在子节点范围内查找成功")
		print("  找到节点: %s" % result)
	else:
		_test_fail("在子节点范围内查找失败")

	print()

## 测试 9: 搜索范围 - 场景
func _test_search_scope_scene():
	print("测试 9: 搜索范围 - 场景")

	# 创建指令
	var instruction_script = load("res://addons/fuse/instructions/find_node.gd")
	var instruction = instruction_script.new()
	instruction.search_type = 0  # BY_NAME
	instruction.search_scope = 1  # SCENE
	instruction.search_value = "TestParent"
	instruction.first_match_only = true
	instruction.result_variable = "found_node"
	instruction.is_global = false

	# 执行指令
	instruction.execute(context)

	# 验证结果（指令是同步执行的，不需要 await）
	var result = context.get_variable("found_node")

	if result != null and "TestParent" in result:
		_test_pass("在场景范围内查找成功")
		print("  找到节点: %s" % result)
	else:
		_test_fail("在场景范围内查找失败")

	print()

## 测试 10: 搜索范围 - 全局
func _test_search_scope_global():
	print("测试 10: 搜索范围 - 全局")

	# 创建指令
	var instruction_script = load("res://addons/fuse/instructions/find_node.gd")
	var instruction = instruction_script.new()
	instruction.search_type = 0  # BY_NAME
	instruction.search_scope = 2  # GLOBAL
	instruction.search_value = "TestFindNodeInstruction"
	instruction.first_match_only = true
	instruction.result_variable = "found_node"
	instruction.is_global = false

	# 执行指令
	instruction.execute(context)

	# 验证结果（指令是同步执行的，不需要 await）
	var result = context.get_variable("found_node")

	if result != null and "TestFindNodeInstruction" in result:
		_test_pass("在全局范围内查找成功")
		print("  找到节点: %s" % result)
	else:
		_test_fail("在全局范围内查找失败")

	print()

## 测试 11: 保存到局部变量
func _test_save_to_local_variable():
	print("测试 11: 保存到局部变量")

	# 创建指令
	var instruction_script = load("res://addons/fuse/instructions/find_node.gd")
	var instruction = instruction_script.new()
	instruction.search_type = 0  # BY_NAME
	instruction.search_scope = 0  # CHILDREN
	instruction.search_value = "Child2"
	instruction.first_match_only = true
	instruction.result_variable = "local_node"
	instruction.is_global = false

	# 执行指令
	instruction.execute(context)

	# 验证结果（指令是同步执行的，不需要 await）
	var result = context.get_variable("local_node")

	if result != null and "Child2" in result:
		_test_pass("保存到局部变量成功")
		print("  局部变量值: %s" % result)
	else:
		_test_fail("保存到局部变量失败")

	print()

## 测试 12: 保存到全局变量
func _test_save_to_global_variable():
	print("测试 12: 保存到全局变量")

	# 确保全局变量管理器存在
	if not context.global_variables:
		_test_skip("全局变量管理器未初始化")
		print()
		return

	# 创建指令
	var instruction_script = load("res://addons/fuse/instructions/find_node.gd")
	var instruction = instruction_script.new()
	instruction.search_type = 0  # BY_NAME
	instruction.search_scope = 0  # CHILDREN
	instruction.search_value = "Child3"
	instruction.first_match_only = true
	instruction.result_variable = "global_node"
	instruction.is_global = true

	# 执行指令
	instruction.execute(context)

	# 验证结果（指令是同步执行的，不需要 await）
	var result = context.global_variables.get_variable("global_node")

	if result != null and "Child3" in result:
		_test_pass("保存到全局变量成功")
		print("  全局变量值: %s" % result)
	else:
		_test_fail("保存到全局变量失败")

	print()

## 测试 13: 参数验证
func _test_validation():
	print("测试 13: 参数验证")

	# 测试空搜索值
	var instruction_script = load("res://addons/fuse/instructions/find_node.gd")
	var instruction1 = instruction_script.new()
	instruction1.search_value = ""
	instruction1.result_variable = "test"
	var errors1 = instruction1.validate()

	if errors1.size() > 0 and "搜索值不能为空" in errors1[0]:
		_test_pass("空搜索值验证成功")
		print("  错误信息: %s" % errors1[0])
	else:
		_test_fail("空搜索值验证失败")

	# 测试空变量名
	var instruction2 = instruction_script.new()
	instruction2.search_value = "TestNode"
	instruction2.result_variable = ""
	var errors2 = instruction2.validate()

	if errors2.size() > 0 and "结果变量名不能为空" in errors2[0]:
		_test_pass("空变量名验证成功")
		print("  错误信息: %s" % errors2[0])
	else:
		_test_fail("空变量名验证失败")

	print()

## 测试 14: 未找到节点的情况
func _test_not_found_case():
	print("测试 14: 未找到节点的情况")

	# 创建指令
	var instruction_script = load("res://addons/fuse/instructions/find_node.gd")
	var instruction = instruction_script.new()
	instruction.search_type = 0  # BY_NAME
	instruction.search_scope = 0  # CHILDREN
	instruction.search_value = "NonExistentNode"
	instruction.first_match_only = true
	instruction.result_variable = "not_found"
	instruction.is_global = false

	# 执行指令
	instruction.execute(context)

	# 验证结果（指令是同步执行的，不需要 await）
	var result = context.get_variable("not_found")

	if result == null:
		_test_pass("未找到节点时返回 null 成功")
		print("  返回值: null")
	else:
		_test_fail("未找到节点时返回值错误")
		print("  返回值: %s" % result)

	print()

## 测试通过
func _test_pass(description: String):
	tests_passed += 1
	test_results.append({"status": "PASS", "description": description})
	print("  ✓ %s\n" % description)

## 测试失败
func _test_fail(description: String):
	tests_failed += 1
	test_results.append({"status": "FAIL", "description": description})
	print("  ✗ %s\n" % description)

## 测试跳过
func _test_skip(description: String):
	test_results.append({"status": "SKIP", "description": description})
	print("  ⊘ %s\n" % description)

## 打印测试结果
func _print_test_results():
	print("\n" + "=".repeat(50))
	print("测试结果汇总")
	print("=".repeat(50))

	var total = tests_passed + tests_failed
	print("总测试数: %d" % total)
	print("通过: %d" % tests_passed)
	print("失败: %d" % tests_failed)
	print("成功率: %.1f%%" % (float(tests_passed) / float(total) * 100.0 if total > 0 else 0.0))

	print("\n详细结果:")
	for i in range(test_results.size()):
		var result = test_results[i]
		var status_symbol = "✓" if result.status == "PASS" else ("✗" if result.status == "FAIL" else "⊘")
		print("%d. %s %s" % [i + 1, status_symbol, result.description])

	print("=".repeat(50))

## 测试 14: 错误处理 - 严格模式
func _test_error_handling_strict():
	print("测试 14: 错误处理 - 严格模式")

	# 创建指令
	var instruction_script = load("res://addons/fuse/instructions/find_node.gd")
	var instruction = instruction_script.new()
	instruction.search_type = 0  # BY_NAME
	instruction.search_scope = 1  # SCENE
	instruction.search_value = "NonexistentNode"
	instruction.error_handling = 0  # STRICT
	instruction.result_variable = "result"

	# 执行指令
	instruction.execute(context)

	# 验证结果（严格模式下应该有错误）
	var result = context.get_variable("result")

	if result == null and instruction.has_error():
		_test_pass("严格模式：未找到节点且记录了错误")
		print("  返回值: null")
		print("  有错误: %s" % instruction.has_error())
	else:
		_test_fail("严格模式错误处理失败")
		print("  返回值: %s" % result)
		print("  有错误: %s" % instruction.has_error())

	print()

## 测试 15: 错误处理 - 警告模式
func _test_error_handling_warning():
	print("测试 15: 错误处理 - 警告模式")

	# 创建指令
	var instruction_script = load("res://addons/fuse/instructions/find_node.gd")
	var instruction = instruction_script.new()
	instruction.search_type = 0  # BY_NAME
	instruction.search_scope = 1  # SCENE
	instruction.search_value = "NonexistentNode"
	instruction.error_handling = 2  # WARNING
	instruction.result_variable = "result"

	# 执行指令
	instruction.execute(context)

	# 验证结果（警告模式下应该没有错误，但返回null）
	var result = context.get_variable("result")

	if result == null and not instruction.has_error():
		_test_pass("警告模式：未找到节点且未记录错误")
		print("  返回值: null")
		print("  无错误: %s" % not instruction.has_error())
	else:
		_test_fail("警告模式错误处理失败")
		print("  返回值: %s" % result)
		print("  有错误: %s" % instruction.has_error())

	print()

## 测试 16: 错误处理 - 静默模式
func _test_error_handling_silent():
	print("测试 16: 错误处理 - 静默模式")

	# 创建指令
	var instruction_script = load("res://addons/fuse/instructions/find_node.gd")
	var instruction = instruction_script.new()
	instruction.search_type = 0  # BY_NAME
	instruction.search_scope = 1  # SCENE
	instruction.search_value = "NonexistentNode"
	instruction.error_handling = 1  # SILENT
	instruction.result_variable = "result"

	# 执行指令
	instruction.execute(context)

	# 验证结果（静默模式下应该没有任何记录，直接返回null）
	var result = context.get_variable("result")

	if result == null:
		_test_pass("静默模式：未找到节点且静默处理")
		print("  返回值: null")
		print("  无错误: %s" % not instruction.has_error())
	else:
		_test_fail("静默模式错误处理失败")
		print("  返回值: %s" % result)

	print()

## 清理资源
func _cleanup():
	context = null
	print("测试环境已清理")
