extends Node2D

## SetCollisionLayer 指令测试

func _ready():
	print("=== Testing SetCollisionLayer ===")
	test_set_layer()
	test_set_mask()
	test_set_both()
	test_bit_values()
	test_error_handling()
	print("=== All SetCollisionLayer tests passed! ===")

## 测试设置碰撞层
func test_set_layer():
	print("\n[Test 1] 设置碰撞层")

	# 创建 Area2D 测试节点
	var area = Area2D.new()
	area.name = "TestArea2D"
	add_child(area)

	# 创建指令
	var SetCollisionLayerScript = load("res://addons/fuse/instructions/set_collision_layer.gd")
	var instruction = SetCollisionLayerScript.new()
	instruction.target_node = NodePath("TestArea2D")
	instruction.use_3d = false
	instruction.set_type = 0  # SetCollisionLayer.SetType.LAYER
	instruction.layer_value = 0b1010  # 第1层和第3层

	# 创建执行上下文
	var context = ExecutionContext.new()

	# 执行指令
	instruction.execute(context)
	await get_tree().process_frame

	# 验证结果
	assert(area.collision_layer == 0b1010, "应该设置碰撞层为 0b1010")
	assert(not context.had_error(), "不应该有错误")
	print("  ✓ 碰撞层正确设置为 0b1010 (第1层和第3层)")

	# 清理
	area.queue_free()

## 测试设置碰撞掩码
func test_set_mask():
	print("\n[Test 2] 设置碰撞掩码")

	# 创建 RigidBody2D 测试节点
	var body = RigidBody2D.new()
	body.name = "TestRigidBody2D"
	add_child(body)

	# 创建指令
	var SetCollisionLayerScript = load("res://addons/fuse/instructions/set_collision_layer.gd")
	var instruction = SetCollisionLayerScript.new()
	instruction.target_node = NodePath("TestRigidBody2D")
	instruction.use_3d = false
	instruction.set_type = 1  # MASK
	instruction.mask_value = 0b0101  # 第0层和第2层

	# 创建执行上下文
	var context = ExecutionContext.new()

	# 执行指令
	instruction.execute(context)
	await get_tree().process_frame

	# 验证结果
	assert(body.collision_mask == 0b0101, "应该设置碰撞掩码为 0b0101")
	assert(not context.had_error(), "不应该有错误")
	print("  ✓ 碰撞掩码正确设置为 0b0101 (第0层和第2层)")

	# 清理
	body.queue_free()

## 测试同时设置层和掩码
func test_set_both():
	print("\n[Test 3] 同时设置层和掩码")

	# 创建 CharacterBody2D 测试节点
	var body = CharacterBody2D.new()
	body.name = "TestCharacterBody2D"
	add_child(body)

	# 创建指令
	var SetCollisionLayerScript = load("res://addons/fuse/instructions/set_collision_layer.gd")
	var instruction = SetCollisionLayerScript.new()
	instruction.target_node = NodePath("TestCharacterBody2D")
	instruction.use_3d = false
	instruction.set_type = 2  # BOTH
	instruction.layer_value = 0b0001  # 第0层
	instruction.mask_value = 0b1111  # 前4层

	# 创建执行上下文
	var context = ExecutionContext.new()

	# 执行指令
	instruction.execute(context)
	await get_tree().process_frame

	# 验证结果
	assert(body.collision_layer == 0b0001, "应该设置碰撞层为 0b0001")
	assert(body.collision_mask == 0b1111, "应该设置碰撞掩码为 0b1111")
	assert(not context.had_error(), "不应该有错误")
	print("  ✓ 碰撞层设置为 0b0001, 碰撞掩码设置为 0b1111")

	# 清理
	body.queue_free()

## 测试位掩码值
func test_bit_values():
	print("\n[Test 4] 测试位掩码值")

	# 测试单个位
	var area1 = Area2D.new()
	area1.name = "TestArea2D_1"
	add_child(area1)

	var SetCollisionLayerScript1 = load("res://addons/fuse/instructions/set_collision_layer.gd")
	var instruction1 = SetCollisionLayerScript1.new()
	instruction1.target_node = NodePath("TestArea2D_1")
	instruction1.set_type = 0  # LAYER
	instruction1.layer_value = 1  # 第0层 (2^0)

	var context1 = ExecutionContext.new()
	add_child(context1)
	instruction1.execute(context1)
	await get_tree().process_frame

	assert(area1.collision_layer == 1, "应该设置第0层")
	print("  ✓ 第0层 (2^0 = 1): %d" % area1.collision_layer)

	# 测试第1层
	var area2 = Area2D.new()
	area2.name = "TestArea2D_2"
	add_child(area2)

	var SetCollisionLayerScript2 = load("res://addons/fuse/instructions/set_collision_layer.gd")
	var instruction2 = SetCollisionLayerScript2.new()
	instruction2.target_node = NodePath("TestArea2D_2")
	instruction2.set_type = 0  # LAYER
	instruction2.layer_value = 2  # 第1层 (2^1)

	var context2 = ExecutionContext.new()
	add_child(context2)
	instruction2.execute(context2)
	await get_tree().process_frame

	assert(area2.collision_layer == 2, "应该设置第1层")
	print("  ✓ 第1层 (2^1 = 2): %d" % area2.collision_layer)

	# 测试第5层
	var area3 = Area2D.new()
	area3.name = "TestArea2D_3"
	add_child(area3)

	var SetCollisionLayerScript3 = load("res://addons/fuse/instructions/set_collision_layer.gd")
	var instruction3 = SetCollisionLayerScript3.new()
	instruction3.target_node = NodePath("TestArea2D_3")
	instruction3.set_type = 0  # LAYER
	instruction3.layer_value = 32  # 第5层 (2^5)

	var context3 = ExecutionContext.new()
	add_child(context3)
	instruction3.execute(context3)
	await get_tree().process_frame

	assert(area3.collision_layer == 32, "应该设置第5层")
	print("  ✓ 第5层 (2^5 = 32): %d" % area3.collision_layer)

	# 测试多个位组合
	var area4 = Area2D.new()
	area4.name = "TestArea2D_4"
	add_child(area4)

	var SetCollisionLayerScript4 = load("res://addons/fuse/instructions/set_collision_layer.gd")
	var instruction4 = SetCollisionLayerScript4.new()
	instruction4.target_node = NodePath("TestArea2D_4")
	instruction4.set_type = 2  # BOTH
	instruction4.layer_value = 0b101010  # 第1、3、5层
	instruction4.mask_value = 0b010101  # 第0、2、4层

	var context4 = ExecutionContext.new()
	add_child(context4)
	instruction4.execute(context4)
	await get_tree().process_frame

	assert(area4.collision_layer == 0b101010, "应该设置第1、3、5层")
	assert(area4.collision_mask == 0b010101, "应该设置第0、2、4层")
	print("  ✓ 多层组合: 层=%d, 掩码=%d" % [area4.collision_layer, area4.collision_mask])

	# 清理
	area1.queue_free()
	area2.queue_free()
	area3.queue_free()
	area4.queue_free()

## 测试错误处理
func test_error_handling():
	print("\n[Test 5] 测试错误处理")

	# 测试空节点路径
	var SetCollisionLayerScript1 = load("res://addons/fuse/instructions/set_collision_layer.gd")
	var instruction1 = SetCollisionLayerScript1.new()
	instruction1.target_node = NodePath("")

	var context1 = ExecutionContext.new()
	add_child(context1)
	instruction1.execute(context1)
	await get_tree().process_frame

	assert(context1.had_error(), "应该有错误：空节点路径")
	print("  ✓ 正确处理空节点路径错误")

	# 测试无效节点路径
	var SetCollisionLayerScript2 = load("res://addons/fuse/instructions/set_collision_layer.gd")
	var instruction2 = SetCollisionLayerScript2.new()
	instruction2.target_node = NodePath("NonExistentNode")

	var context2 = ExecutionContext.new()
	add_child(context2)
	instruction2.execute(context2)
	await get_tree().process_frame

	assert(context2.had_error(), "应该有错误：节点不存在")
	print("  ✓ 正确处理节点不存在错误")

	# 测试无效节点类型
	var sprite = Sprite2D.new()
	sprite.name = "TestSprite2D"
	add_child(sprite)

	var SetCollisionLayerScript3 = load("res://addons/fuse/instructions/set_collision_layer.gd")
	var instruction3 = SetCollisionLayerScript3.new()
	instruction3.target_node = NodePath("TestSprite2D")

	var context3 = ExecutionContext.new()
	add_child(context3)
	instruction3.execute(context3)
	await get_tree().process_frame

	assert(context3.had_error(), "应该有错误：无效节点类型")
	print("  ✓ 正确处理无效节点类型错误")

	# 清理
	sprite.queue_free()
