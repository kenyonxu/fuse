extends Node2D

## 测试对象距离条件

func _ready():
	test_distance_condition()
	print("对象距离条件测试完成")

## 测试对象距离条件
func test_distance_condition():
	# 创建执行上下文
	var context = ExecutionContext.new()
	context.scene_context = self

	# 创建两个测试节点
	var node_a = Node2D.new()
	node_a.name = "NodeA"
	node_a.position = Vector2(0, 0)
	add_child(node_a)

	var node_b = Node2D.new()
	node_b.name = "NodeB"
	node_b.position = Vector2(100, 0)
	add_child(node_b)

	# 测试 1: 距离小于阈值
	var condition1 = CheckDistance.new()
	condition1.source_node = NodePath("NodeA")
	condition1.target_node = NodePath("NodeB")
	condition1.comparison_operator = CheckDistance.ComparisonOperator.LESS_THAN
	condition1.threshold = 150.0

	var result1 = condition1.check(context)
	print("距离 100 < 150 => ", result1)
	assert(result1 == true, "距离 100 应该小于 150")

	# 测试 2: 距离大于阈值
	var condition2 = CheckDistance.new()
	condition2.source_node = NodePath("NodeA")
	condition2.target_node = NodePath("NodeB")
	condition2.comparison_operator = CheckDistance.ComparisonOperator.GREATER_THAN
	condition2.threshold = 50.0

	var result2 = condition2.check(context)
	print("距离 100 > 50 => ", result2)
	assert(result2 == true, "距离 100 应该大于 50")

	# 测试 3: 距离等于阈值（在容差范围内）
	var condition3 = CheckDistance.new()
	condition3.source_node = NodePath("NodeA")
	condition3.target_node = NodePath("NodeB")
	condition3.comparison_operator = CheckDistance.ComparisonOperator.EQUAL
	condition3.threshold = 100.0
	condition3.equality_tolerance = 5.0

	var result3 = condition3.check(context)
	print("距离 100 ≈ 100 (容差 ±5) => ", result3)
	assert(result3 == true, "距离 100 应该在 100±5 范围内")

	# 测试 4: 移动节点后的距离检测
	node_b.position = Vector2(200, 0)

	var condition4 = CheckDistance.new()
	condition4.source_node = NodePath("NodeA")
	condition4.target_node = NodePath("NodeB")
	condition4.comparison_operator = CheckDistance.ComparisonOperator.GREATER_THAN
	condition4.threshold = 150.0

	var result4 = condition4.check(context)
	print("距离 200 > 150 => ", result4)
	assert(result4 == true, "距离 200 应该大于 150")

	# 测试 5: 使用平方距离（性能优化）
	var condition5 = CheckDistance.new()
	condition5.source_node = NodePath("NodeA")
	condition5.target_node = NodePath("NodeB")
	condition5.comparison_operator = CheckDistance.ComparisonOperator.LESS_THAN
	condition5.threshold = 250.0
	condition5.use_squared_distance = true

	var result5 = condition5.check(context)
	print("距离 200 < 250 (平方距离模式) => ", result5)
	assert(result5 == true, "距离 200 应该小于 250")

	# 清理
	node_a.queue_free()
	node_b.queue_free()

	print("对象距离条件测试通过!")
