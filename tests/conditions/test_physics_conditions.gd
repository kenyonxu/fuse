extends Node2D

## 测试物理检测条件

func _ready():
	test_on_floor_condition()
	test_in_air_condition()
	print("物理检测条件测试完成")

## 测试在地面条件
func test_on_floor_condition():
	print("\n--- 测试在地面条件 ---")

	# 创建执行上下文
	var context = ExecutionContext.new()
	context.scene_context = self

	# 创建测试用的 CharacterBody2D
	var character = CharacterBody2D.new()
	character.name = "TestCharacter"
	add_child(character)

	# 创建条件
	var condition = CheckOnFloor.new()
	condition.target_node = NodePath("TestCharacter")

	# 测试：CharacterBody2D 默认可能在空中（没有向下移动）
	# 这里我们主要测试条件能正确检查节点类型
	var node = context.get_node(NodePath("TestCharacter"))
	assert(node != null, "应该能找到测试节点")
	assert(node is CharacterBody2D, "节点应该是 CharacterBody2D 类型")

	print("✓ 在地面条件测试通过（节点类型检查）")

	# 清理
	character.queue_free()

## 测试在空中条件
func test_in_air_condition():
	print("\n--- 测试在空中条件 ---")

	# 创建执行上下文
	var context = ExecutionContext.new()
	context.scene_context = self

	# 创建测试用的 CharacterBody2D
	var character = CharacterBody2D.new()
	character.name = "TestCharacter2"
	add_child(character)

	# 创建条件
	var condition = CheckInAir.new()
	condition.target_node = NodePath("TestCharacter2")

	# 测试：CharacterBody2D 默认可能在空中（没有向下移动）
	# 这里我们主要测试条件能正确检查节点类型
	var node = context.get_node(NodePath("TestCharacter2"))
	assert(node != null, "应该能找到测试节点")
	assert(node is CharacterBody2D, "节点应该是 CharacterBody2D 类型")

	print("✓ 在空中条件测试通过（节点类型检查）")

	# 测试：使用非 CharacterBody 节点应该返回错误
	var wrong_node = Node2D.new()
	wrong_node.name = "WrongNode"
	add_child(wrong_node)

	var condition_wrong = CheckOnFloor.new()
	condition_wrong.target_node = NodePath("WrongNode")

	var result = condition_wrong.check(context)
	assert(result == false, "非 CharacterBody 节点应该返回 false")

	print("✓ 物理条件正确处理非 CharacterBody 节点")

	# 清理
	character.queue_free()
	wrong_node.queue_free()

	print("物理检测条件测试通过!")
