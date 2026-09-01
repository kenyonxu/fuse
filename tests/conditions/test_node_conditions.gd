extends Node2D

## 测试节点激活条件

func _ready():
	test_node_active_condition()
	test_node_in_group_condition()
	print("节点条件测试完成")

## 测试节点激活条件
func test_node_active_condition():
	# 创建执行上下文
	var context = ExecutionContext.new()

	# 创建测试节点
	var test_node = Node2D.new()
	test_node.name = "TestNode"
	add_child(test_node)
	context.scene_context = self

	# 创建条件
	var condition = CheckNodeActive.new()
	condition.check_node_path = NodePath("TestNode")
	condition.check_type = CheckNodeActive.CheckType.VISIBLE

	# 测试:节点可见
	test_node.visible = true
	var result1 = condition.check(context)
	print("节点可见 => ", result1)
	assert(result1 == true, "可见节点应该返回 true")

	# 测试:节点不可见
	test_node.visible = false
	var result2 = condition.check(context)
	print("节点不可见 => ", result2)
	assert(result2 == false, "不可见节点应该返回 false")

	# 测试:处理状态
	test_node.visible = true
	condition.check_type = CheckNodeActive.CheckType.PROCESSING

	test_node.process_mode = Node.PROCESS_MODE_INHERIT
	var result3 = condition.check(context)
	print("节点处理中 => ", result3)
	assert(result3 == true, "处理中的节点应该返回 true")

	test_node.process_mode = Node.PROCESS_MODE_DISABLED
	var result4 = condition.check(context)
	print("节点处理禁用 => ", result4)
	assert(result4 == false, "处理禁用的节点应该返回 false")

	# 测试:场景树中
	condition.check_type = CheckNodeActive.CheckType.INSIDE_TREE
	var result5 = condition.check(context)
	print("节点在场景树中 => ", result5)
	assert(result5 == true, "在场景树中的节点应该返回 true")

	# 清理
	test_node.queue_free()

	print("节点激活条件测试通过!")

## 测试节点组检测条件
func test_node_in_group_condition():
	print("\n--- 测试节点组检测条件 ---")

	# 创建执行上下文
	var context = ExecutionContext.new()

	# 创建测试节点
	var test_node = Node2D.new()
	test_node.name = "TestNodeGroup"
	add_child(test_node)
	context.scene_context = self

	# 创建条件
	var condition = CheckNodeInGroup.new()
	condition.target_node = NodePath("TestNodeGroup")
	condition.group_name = "test_group"

	# 测试:节点不在组中
	var result1 = condition.check(context)
	print("节点不在组中 => ", result1)
	assert(result1 == false, "不在组中的节点应该返回 false")

	# 测试:节点在组中
	test_node.add_to_group("test_group")
	var result2 = condition.check(context)
	print("节点在组中 => ", result2)
	assert(result2 == true, "在组中的节点应该返回 true")

	# 测试:节点在多个组中
	test_node.add_to_group("another_group")
	var result3 = condition.check(context)
	print("节点仍在 test_group 中 => ", result3)
	assert(result3 == true, "仍在组中的节点应该返回 true")

	# 测试:从组中移除
	test_node.remove_from_group("test_group")
	var result4 = condition.check(context)
	print("节点从组中移除 => ", result4)
	assert(result4 == false, "从组中移除的节点应该返回 false")

	# 测试:验证功能
	condition.target_node = NodePath("")
	var errors = condition.validate()
	assert(not errors.is_empty(), "空节点路径应该验证失败")
	print("✓ 正确检测到空节点路径")

	condition.target_node = NodePath("TestNodeGroup")
	condition.group_name = ""
	errors = condition.validate()
	assert(not errors.is_empty(), "空组名应该验证失败")
	print("✓ 正确检测到空组名")

	# 测试:序列化和反序列化
	condition.target_node = NodePath("TestNodeGroup")
	condition.group_name = "test_group"
	var params = condition.get_parameters()
	print("序列化参数:", params)
	assert(params["target_node"] == NodePath("TestNodeGroup"), "节点路径应该正确")
	assert(params["group_name"] == "test_group", "组名应该正确")

	var new_condition = CheckNodeInGroup.new()
	new_condition.set_parameters(params)
	assert(new_condition.group_name == "test_group", "组名应该被正确设置")
	print("✓ 序列化/反序列化正常")

	# 清理
	test_node.queue_free()
	condition.queue_free()
	new_condition.queue_free()

	print("节点组检测条件测试通过!")
