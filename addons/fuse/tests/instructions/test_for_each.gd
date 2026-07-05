extends Node

## For Each 指令测试
##
## 测试场景：
## 1. 遍历数组
## 2. 遍历节点组
## 3. 跳过空元素
## 4. 嵌套循环

func _ready():
	print("=== For Each 指令测试开始 ===\n")

	await test_for_each_array()
	await test_for_each_node_group()
	await test_for_each_skip_null()
	await test_nested_for_each()
	await test_validation()

	print("\n=== For Each 指令测试完成 ===")

## 测试 1: 遍历数组
func test_for_each_array():
	print("\n--- 测试 1: 遍历数组 ---")

	var for_each_script = load("res://addons/fuse/instructions/for_each.gd")
	var for_each = for_each_script.new()
	for_each.source_type = 0  # ARRAY
	for_each.array_variable = "my_array"
	for_each.item_variable = "item"
	for_each.skip_null_items = false

	# 创建打印指令
	var print_inst = Print.new()
	print_inst.message = "元素: {item}"
	for_each.loop_instructions.append(print_inst)

	# 创建执行上下文
	var context = ExecutionContext.new()

	# 设置数组变量
	var test_array = [1, 2, 3, 4, 5]
	context.set_variable("my_array", test_array)

	# 执行 For Each
	for_each.execute(context)

	# For Each 是同步指令
	await get_tree().process_frame

	# 验证结果
	assert(for_each.is_completed(), "For Each 应该成功完成")
	print("✓ 遍历数组测试通过")

## 测试 2: 遍历节点组
func test_for_each_node_group():
	print("\n--- 测试 2: 遍历节点组 ---")

	var for_each = ForEach.new()
	for_each.source_type = 1  # NODE_GROUP
	for_each.group_name = "test_group"
	for_each.item_variable = "node"

	# 创建打印指令
	var print_inst = Print.new()
	print_inst.message = "节点: {node}"
	for_each.loop_instructions.append(print_inst)

	# 创建测试节点组
	var node1 = Node2D.new()
	node1.name = "TestNode1"
	var node2 = Node2D.new()
	node2.name = "TestNode2"

	get_tree().current_scene.add_child(node1)
	get_tree().current_scene.add_child(node2)
	node1.add_to_group("test_group")
	node2.add_to_group("test_group")

	# 创建执行上下文
	var context = ExecutionContext.new()

	# 执行 For Each
	for_each.execute(context)

	await get_tree().process_frame

	# 验证结果
	assert(for_each.is_completed(), "For Each 应该成功完成")
	print("✓ 遍历节点组测试通过")

	# 清理
	node1.queue_free()
	node2.queue_free()

## 测试 3: 跳过空元素
func test_for_each_skip_null():
	print("\n--- 测试 3: 跳过空元素 ---")

	var for_each = ForEach.new()
	for_each.source_type = 0  # ARRAY
	for_each.array_variable = "mixed_array"
	for_each.item_variable = "item"
	for_each.skip_null_items = true

	# 创建打印指令
	var print_inst = Print.new()
	print_inst.message = "元素: {item}"
	for_each.loop_instructions.append(print_inst)

	# 创建执行上下文
	var context = ExecutionContext.new()

	# 设置包含空元素的数组
	var test_array = [1, null, 2, null, 3]
	context.set_variable("mixed_array", test_array)

	# 执行 For Each
	for_each.execute(context)

	await get_tree().process_frame

	# 验证结果
	assert(for_each.is_completed(), "For Each 应该成功完成")
	print("✓ 跳过空元素测试通过")

## 测试 4: 嵌套 For Each
func test_nested_for_each():
	print("\n--- 测试 4: 嵌套 For Each ---")

	# 外层 For Each（遍历行）
	var outer_for_each = ForEach.new()
	outer_for_each.source_type = 0  # ARRAY
	outer_for_each.array_variable = "matrix"
	outer_for_each.item_variable = "row"

	# 内层 For Each（遍历列）
	var inner_for_each = ForEach.new()
	inner_for_each.source_type = 0  # ARRAY
	inner_for_each.array_variable = "row"
	inner_for_each.item_variable = "col"

	# 创建打印指令
	var print_inst = Print.new()
	print_inst.message = "行: {row}, 列: {col}"
	inner_for_each.loop_instructions.append(print_inst)

	# 将内层 For Each 添加到外层
	outer_for_each.loop_instructions.append(inner_for_each)

	# 创建执行上下文
	var context = ExecutionContext.new()

	# 设置二维数组
	var test_matrix = [
		[1, 2, 3],
		[4, 5, 6],
		[7, 8, 9]
	]
	context.set_variable("matrix", test_matrix)

	# 执行外层 For Each
	outer_for_each.execute(context)

	await get_tree().process_frame

	# 验证结果
	assert(outer_for_each.is_completed(), "外层 For Each 应该成功完成")
	assert(inner_for_each.is_completed(), "内层 For Each 应该成功完成")
	print("✓ 嵌套 For Each 测试通过")

## 测试 5: 验证参数
func test_validation():
	print("\n--- 测试 5: 验证参数 ---")

	var for_each = ForEach.new()

	# 测试空元素变量名
	for_each.item_variable = ""
	var errors = for_each.validate()
	assert(errors.size() > 0, "空元素变量名应该产生验证错误")
	print("✓ 空元素变量名验证通过")

	# 测试空数组变量名（当源类型为 ARRAY 时）
	for_each.source_type = 0  # ARRAY
	for_each.array_variable = ""
	errors = for_each.validate()
	assert(errors.size() > 0, "空数组变量名应该产生验证错误")
	print("✓ 空数组变量名验证通过")

	# 测试空组名（当源类型为 NODE_GROUP 时）
	for_each.source_type = 1  # NODE_GROUP
	for_each.group_name = ""
	errors = for_each.validate()
	assert(errors.size() > 0, "空组名应该产生验证错误")
	print("✓ 空组名验证通过")

	print("✓ 所有验证测试通过")
