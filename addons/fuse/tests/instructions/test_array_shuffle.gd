extends Node

## ArrayShuffle 指令测试
##
## 测试场景：
## 1. 打乱数组（本地变量）
## 2. 打乱数组保留所有元素
## 3. 打乱空数组
## 4. 打乱不存在的数组（应报错）
## 5. 打乱节点子节点数组
## 6. 打乱节点组数组
## 7. 验证测试

func _ready():
	print("=== ArrayShuffle 指令测试开始 ===\n")

	await test_array_shuffle_local()
	await test_array_shuffle_preserves_elements()
	await test_array_shuffle_empty_array()
	await test_array_shuffle_not_exists()
	await test_array_shuffle_node_children()
	await test_array_shuffle_node_group()
	await test_validation()

	print("\n=== ArrayShuffle 指令测试完成 ===")

## 测试 1: 打乱数组（本地变量）
func test_array_shuffle_local():
	print("\n--- 测试 1: 打乱数组（本地变量） ---")

	var array_shuffle = ArrayShuffle.new()
	array_shuffle.source_type = 0  # VARIABLE
	array_shuffle.array_variable = "my_array"
	array_shuffle.array_scope = BaseVariable.VariableScope.LOCAL

	# 创建执行上下文
	var context = ExecutionContext.new()

	# 设置数组变量
	var test_array = [1, 2, 3, 4, 5]
	context.set_variable("my_array", test_array)

	# 执行 ArrayShuffle
	array_shuffle.execute(context)

	# ArrayShuffle 是同步指令
	await get_tree().process_frame

	# 验证结果
	assert(array_shuffle.is_completed(), "ArrayShuffle 应该成功完成")
	assert(test_array.size() == 5, "数组大小应该保持为 5")
	# 验证所有元素都还在
	for i in range(1, 6):
		assert(test_array.has(i), "元素 %d 应该仍在数组中" % i)
	print("打乱数组（本地变量）测试通过")

## 测试 2: 打乱数组保留所有元素
func test_array_shuffle_preserves_elements():
	print("\n--- 测试 2: 打乱数组保留所有元素 ---")

	var array_shuffle = ArrayShuffle.new()
	array_shuffle.source_type = 0  # VARIABLE
	array_shuffle.array_variable = "my_array"
	array_shuffle.array_scope = BaseVariable.VariableScope.LOCAL

	# 创建执行上下文
	var context = ExecutionContext.new()

	# 设置数组变量
	var original = [10, 20, 30, 40, 50]
	var test_array = original.duplicate()
	context.set_variable("my_array", test_array)

	# 执行 ArrayShuffle
	array_shuffle.execute(context)

	await get_tree().process_frame

	# 验证结果
	assert(array_shuffle.is_completed(), "ArrayShuffle 应该成功完成")

	var result = context.get_variable("my_array", null)
	# 验证所有原始元素都还在（只是顺序可能不同）
	for elem in original:
		assert(result.has(elem), "元素 %s 应该仍在数组中" % str(elem))
	print("打乱数组保留所有元素测试通过")

## 测试 3: 打乱空数组
func test_array_shuffle_empty_array():
	print("\n--- 测试 3: 打乱空数组 ---")

	var array_shuffle = ArrayShuffle.new()
	array_shuffle.source_type = 0  # VARIABLE
	array_shuffle.array_variable = "empty_array"
	array_shuffle.array_scope = BaseVariable.VariableScope.LOCAL

	# 创建执行上下文
	var context = ExecutionContext.new()

	# 设置空数组变量
	var test_array = []
	context.set_variable("empty_array", test_array)

	# 执行 ArrayShuffle
	array_shuffle.execute(context)

	await get_tree().process_frame

	# 验证结果
	assert(array_shuffle.is_completed(), "ArrayShuffle 应该成功完成")
	assert(test_array.size() == 0, "空数组打乱后大小仍为 0")
	assert(test_array == [], "数组应该仍为空数组")
	print("打乱空数组测试通过")

## 测试 4: 打乱不存在的数组（应报错）
func test_array_shuffle_not_exists():
	print("\n--- 测试 4: 打乱不存在的数组（应报错） ---")

	var array_shuffle = ArrayShuffle.new()
	array_shuffle.source_type = 0  # VARIABLE
	array_shuffle.array_variable = "non_existent_array"
	array_shuffle.array_scope = BaseVariable.VariableScope.LOCAL

	# 创建执行上下文（不设置数组）
	var context = ExecutionContext.new()

	# 执行 ArrayShuffle
	array_shuffle.execute(context)

	await get_tree().process_frame

	# 验证结果 - 不存在的数组应该报错
	assert(array_shuffle.has_error(), "ArrayShuffle 应该有错误（数组不存在）")
	print("打乱不存在的数组测试通过")

## 测试 5: 打乱节点子节点数组
func test_array_shuffle_node_children():
	print("\n--- 测试 5: 打乱节点子节点数组 ---")

	var array_shuffle = ArrayShuffle.new()
	array_shuffle.source_type = 1  # NODE_CHILDREN
	array_shuffle.target_node_path = NodePath(".")

	# 创建测试节点
	var parent_node = Node2D.new()
	parent_node.name = "ParentNode"
	get_tree().current_scene.add_child(parent_node)

	# 添加子节点
	var child1 = Node2D.new()
	child1.name = "Child1"
	var child2 = Node2D.new()
	child2.name = "Child2"
	var child3 = Node2D.new()
	child3.name = "Child3"
	parent_node.add_child(child1)
	parent_node.add_child(child2)
	parent_node.add_child(child3)

	# 创建执行上下文
	var context = ExecutionContext.new()
	context.trigger = parent_node

	# 执行 ArrayShuffle
	array_shuffle.execute(context)

	await get_tree().process_frame

	# 验证结果
	assert(array_shuffle.is_completed(), "ArrayShuffle 应该成功完成")
	# 注意：get_children() 返回的数组是副本，打乱不影响原节点
	# 这里主要测试指令执行不报错

	# 清理
	parent_node.queue_free()
	print("打乱节点子节点数组测试通过")

## 测试 6: 打乱节点组数组
func test_array_shuffle_node_group():
	print("\n--- 测试 6: 打乱节点组数组 ---")

	var array_shuffle = ArrayShuffle.new()
	array_shuffle.source_type = 2  # NODE_GROUP
	array_shuffle.group_name = "test_shuffle_group"

	# 创建测试节点组
	var node1 = Node2D.new()
	node1.name = "GroupNode1"
	get_tree().current_scene.add_child(node1)
	node1.add_to_group("test_shuffle_group")

	var node2 = Node2D.new()
	node2.name = "GroupNode2"
	get_tree().current_scene.add_child(node2)
	node2.add_to_group("test_shuffle_group")

	# 创建执行上下文
	var context = ExecutionContext.new()

	# 执行 ArrayShuffle
	array_shuffle.execute(context)

	await get_tree().process_frame

	# 验证结果
	# 注意：get_nodes_in_group() 返回的数组是副本，打乱不影响原节点组
	assert(array_shuffle.is_completed(), "ArrayShuffle 应该成功完成")
	print("打乱节点组数组测试通过")

	# 清理
	node1.queue_free()
	node2.queue_free()

## 测试 7: 验证测试
func test_validation():
	print("\n--- 测试 7: 验证测试 ---")

	# 测试空数组变量名
	var array_shuffle = ArrayShuffle.new()
	array_shuffle.source_type = 0  # VARIABLE
	array_shuffle.array_variable = ""

	var errors = array_shuffle.validate()
	assert(errors.size() > 0, "应该返回验证错误（空数组变量名）")
	print("空数组变量名验证测试通过")

	# 测试空节点路径
	array_shuffle = ArrayShuffle.new()
	array_shuffle.source_type = 1  # NODE_CHILDREN
	array_shuffle.target_node_path = NodePath("")

	errors = array_shuffle.validate()
	assert(errors.size() > 0, "应该返回验证错误（空节点路径）")
	print("空节点路径验证测试通过")

	# 测试空组名
	array_shuffle = ArrayShuffle.new()
	array_shuffle.source_type = 2  # NODE_GROUP
	array_shuffle.group_name = ""

	errors = array_shuffle.validate()
	assert(errors.size() > 0, "应该返回验证错误（空组名）")
	print("空组名验证测试通过")

	print("验证测试全部通过")
