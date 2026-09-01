extends Node

## ArrayAdd 指令测试
##
## 测试场景：
## 1. 向数组添加元素（直接值）
## 2. 向数组添加元素（从变量）
## 3. 向数组添加元素（从变量 - 数组不存在则创建）
## 4. 向节点子节点数组添加元素
## 5. 向节点组添加元素

func _ready():
	print("=== ArrayAdd 指令测试开始 ===\n")

	await test_array_add_with_value()
	await test_array_add_with_variable()
	await test_array_add_create_new_array()
	await test_array_add_node_children()
	await test_array_add_node_group()
	await test_validation()

	print("\n=== ArrayAdd 指令测试完成 ===")

## 测试 1: 向数组添加元素（直接值）
func test_array_add_with_value():
	print("\n--- 测试 1: 向数组添加元素（直接值） ---")

	var array_add_script = load("res://addons/fuse/instructions/arrays/array_add.gd")
	var array_add = array_add_script.new()
	array_add.source_type = 0  # VARIABLE
	array_add.array_variable = "test_array"
	array_add.array_scope = BaseVariable.VariableScope.LOCAL
	array_add.use_element_from_variable = false
	array_add.element_value = "new_element"

	# 创建执行上下文
	var context = ExecutionContext.new()

	# 设置数组变量
	var test_array = ["a", "b", "c"]
	context.set_variable("test_array", test_array)

	# 执行 ArrayAdd
	array_add.execute(context)

	# ArrayAdd 是同步指令
	await get_tree().process_frame

	# 验证结果
	assert(array_add.is_completed(), "ArrayAdd 应该成功完成")
	assert(test_array.size() == 4, "数组应该有 4 个元素")
	assert(test_array[3] == "new_element", "第4个元素应该是 'new_element'")
	print("✓ 向数组添加元素（直接值）测试通过")

## 测试 2: 向数组添加元素（从变量）
func test_array_add_with_variable():
	print("\n--- 测试 2: 向数组添加元素（从变量） ---")

	var array_add = ArrayAdd.new()
	array_add.source_type = 0  # VARIABLE
	array_add.array_variable = "test_array2"
	array_add.array_scope = BaseVariable.VariableScope.LOCAL
	array_add.use_element_from_variable = true
	array_add.element_from_variable = "element_value"
	array_add.element_from_variable_scope = BaseVariable.VariableScope.LOCAL

	# 创建执行上下文
	var context = ExecutionContext.new()

	# 设置数组变量
	var test_array = ["x", "y"]
	context.set_variable("test_array2", test_array)

	# 设置元素值变量
	context.set_variable("element_value", "from_variable")

	# 执行 ArrayAdd
	array_add.execute(context)

	await get_tree().process_frame

	# 验证结果
	assert(array_add.is_completed(), "ArrayAdd 应该成功完成")
	assert(test_array.size() == 3, "数组应该有 3 个元素")
	assert(test_array[2] == "from_variable", "第3个元素应该是 'from_variable'")
	print("✓ 向数组添加元素（从变量）测试通过")

## 测试 3: 向数组添加元素（数组不存在则创建）
func test_array_add_create_new_array():
	print("\n--- 测试 3: 向数组添加元素（数组不存在则创建） ---")

	var array_add = ArrayAdd.new()
	array_add.source_type = 0  # VARIABLE
	array_add.array_variable = "new_array"
	array_add.array_scope = BaseVariable.VariableScope.LOCAL
	array_add.use_element_from_variable = false
	array_add.element_value = 42

	# 创建执行上下文（没有设置数组）
	var context = ExecutionContext.new()

	# 执行 ArrayAdd
	array_add.execute(context)

	await get_tree().process_frame

	# 验证结果
	assert(array_add.is_completed(), "ArrayAdd 应该成功完成")

	# 检查数组是否被创建
	var new_array = context.get_variable("new_array", null)
	assert(new_array != null, "数组应该被创建")
	assert(new_array is Array, "创建的应该是数组类型")
	assert(new_array.size() == 1, "新数组应该有 1 个元素")
	assert(new_array[0] == 42, "第1个元素应该是 42")
	print("✓ 向数组添加元素（数组不存在则创建）测试通过")

## 测试 4: 向节点子节点数组添加元素
func test_array_add_node_children():
	print("\n--- 测试 4: 向节点子节点数组添加元素 ---")

	var array_add = ArrayAdd.new()
	array_add.source_type = 1  # NODE_CHILDREN
	array_add.target_node_path = NodePath(".")
	array_add.use_element_from_variable = false
	array_add.element_value = "child_element"

	# 创建测试节点
	var parent_node = Node2D.new()
	parent_node.name = "ParentNode"
	get_tree().current_scene.add_child(parent_node)

	# 添加子节点
	var child1 = Node2D.new()
	child1.name = "Child1"
	var child2 = Node2D.new()
	child2.name = "Child2"
	parent_node.add_child(child1)
	parent_node.add_child(child2)

	# 创建执行上下文
	var context = ExecutionContext.new()
	context.trigger = parent_node

	# 执行 ArrayAdd
	array_add.execute(context)

	await get_tree().process_frame

	# 验证结果
	assert(array_add.is_completed(), "ArrayAdd 应该成功完成")

	# 清理
	parent_node.queue_free()
	print("✓ 向节点子节点数组添加元素测试通过")

## 测试 5: 向节点组添加元素
func test_array_add_node_group():
	print("\n--- 测试 5: 向节点组添加元素 ---")

	var array_add = ArrayAdd.new()
	array_add.source_type = 2  # NODE_GROUP
	array_add.group_name = "test_add_group"
	array_add.use_element_from_variable = false
	array_add.element_value = "group_element"

	# 创建测试节点组
	var node1 = Node2D.new()
	node1.name = "GroupNode1"
	get_tree().current_scene.add_child(node1)
	node1.add_to_group("test_add_group")

	# 创建执行上下文
	var context = ExecutionContext.new()

	# 执行 ArrayAdd
	array_add.execute(context)

	await get_tree().process_frame

	# 验证结果
	# 注意：节点组是只读的，不能直接添加元素
	# 所以这个测试应该验证错误处理
	assert(array_add.has_error() == false, "ArrayAdd 不应该有错误（会创建新数组）")
	print("✓ 向节点组添加元素测试通过")

	# 清理
	node1.queue_free()

## 测试 6: 验证测试
func test_validation():
	print("\n--- 测试 6: 验证测试 ---")

	# 测试空数组变量名
	var array_add = ArrayAdd.new()
	array_add.source_type = 0  # VARIABLE
	array_add.array_variable = ""
	array_add.use_element_from_variable = false
	array_add.element_value = "test"

	var errors = array_add.validate()
	assert(errors.size() > 0, "应该返回验证错误")
	print("✓ 验证测试通过")

	# 测试空元素变量名（当 use_element_from_variable = true 时）
	array_add = ArrayAdd.new()
	array_add.source_type = 0  # VARIABLE
	array_add.array_variable = "my_array"
	array_add.use_element_from_variable = true
	array_add.element_from_variable = ""

	errors = array_add.validate()
	assert(errors.size() > 0, "应该返回元素变量名验证错误")
	print("✓ 元素变量验证测试通过")
