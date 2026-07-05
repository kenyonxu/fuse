extends Node2D

## 测试 Blend Animation 指令

func _ready():
	print("=== 开始测试 Blend Animation 指令 ===")
	await test_set_blend_value()
	await test_use_variable_blend()
	await test_blend_value_clamping()
	await test_error_handling()
	print("=== Blend Animation 指令测试完成 ===")

## 测试 1: 直接设置混合值
func test_set_blend_value():
	print("\n[Test 1] 测试直接设置混合值")

	var instruction_script = load("res://addons/fuse/instructions/blend_animation.gd")
	var instruction = instruction_script.new()
	var context = ExecutionContext.new()

	var animation_tree = get_node("Character/AnimationTree") as AnimationTree

	instruction.target_tree = NodePath("Character/AnimationTree")
	instruction.blend_path = "blend_position"
	instruction.use_variable = false
	instruction.blend_amount = 0.75

	instruction.execute(context)

	await context.finished
	await get_tree().process_frame

	var result = animation_tree.get("parameters/blend_position")
	assert(is_equal_approx(result, 0.75), "混合值应该是 0.75，实际为 %.2f" % result)
	print("✓ 直接设置混合值测试通过")

## 测试 2: 从变量读取混合值
func test_use_variable_blend():
	print("\n[Test 2] 测试从变量读取混合值")

	var instruction_script = load("res://addons/fuse/instructions/blend_animation.gd")
	var instruction = instruction_script.new()
	var context = ExecutionContext.new()

	var animation_tree = get_node("Character/AnimationTree") as AnimationTree

	# 设置变量值
	context.set_variable("blend_var", 0.25)

	instruction.target_tree = NodePath("Character/AnimationTree")
	instruction.blend_path = "blend_position"
	instruction.use_variable = true
	instruction.blend_variable = "blend_var"

	instruction.execute(context)

	await context.finished
	await get_tree().process_frame

	var result = animation_tree.get("parameters/blend_position")
	assert(is_equal_approx(result, 0.25), "混合值应该是 0.25，实际为 %.2f" % result)
	print("✓ 从变量读取混合值测试通过")

## 测试 3: 混合值被限制在 0-1
func test_blend_value_clamping():
	print("\n[Test 3] 测试混合值被限制在 0-1")

	var instruction_script = load("res://addons/fuse/instructions/blend_animation.gd")
	var instruction = instruction_script.new()
	var context = ExecutionContext.new()

	var animation_tree = get_node("Character/AnimationTree") as AnimationTree

	# 测试超出范围的上限
	instruction.target_tree = NodePath("Character/AnimationTree")
	instruction.blend_path = "blend_position"
	instruction.use_variable = false
	instruction.blend_amount = 1.5

	instruction.execute(context)

	await context.finished
	await get_tree().process_frame

	var result = animation_tree.get("parameters/blend_position")
	assert(is_equal_approx(result, 1.0), "混合值应该被限制为 1.0，实际为 %.2f" % result)
	print("  ✓ 上限限制测试通过")

	# 测试超出范围的下限
	instruction.blend_amount = -0.5

	var context2 = ExecutionContext.new()
	instruction.execute(context2)

	await context2.finished
	await get_tree().process_frame

	result = animation_tree.get("parameters/blend_position")
	assert(is_equal_approx(result, 0.0), "混合值应该被限制为 0.0，实际为 %.2f" % result)
	print("  ✓ 下限限制测试通过")

## 测试 4: 错误处理
func test_error_handling():
	print("\n[Test 4] 测试错误处理")

	var instruction_script = load("res://addons/fuse/instructions/blend_animation.gd")

	# 测试空目标节点
	var instruction1 = instruction_script.new()
	var context1 = ExecutionContext.new()

	instruction1.target_tree = NodePath("")
	instruction1.blend_path = "blend_position"

	instruction1.execute(context1)

	await context1.finished
	await get_tree().process_frame

	assert(context1.has_error(), "应该产生错误（空目标节点）")
	print("  ✓ 空目标节点错误处理通过")

	# 测试无效节点
	var instruction2 = instruction_script.new()
	var context2 = ExecutionContext.new()

	instruction2.target_tree = NodePath("InvalidNode")
	instruction2.blend_path = "blend_position"

	instruction2.execute(context2)

	await context2.finished
	await get_tree().process_frame

	assert(context2.has_error(), "应该产生错误（无效节点）")
	print("  ✓ 无效节点错误处理通过")

	# 测试空混合路径
	var instruction3 = instruction_script.new()
	var context3 = ExecutionContext.new()

	instruction3.target_tree = NodePath("Character/AnimationTree")
	instruction3.blend_path = ""

	instruction3.execute(context3)

	await context3.finished
	await get_tree().process_frame

	assert(context3.has_error(), "应该产生错误（空混合路径）")
	print("  ✓ 空混合路径错误处理通过")

	# 测试未找到变量
	var instruction4 = instruction_script.new()
	var context4 = ExecutionContext.new()

	instruction4.target_tree = NodePath("Character/AnimationTree")
	instruction4.blend_path = "blend_position"
	instruction4.use_variable = true
	instruction4.blend_variable = "nonexistent_var"

	instruction4.execute(context4)

	await context4.finished
	await get_tree().process_frame

	assert(context4.has_error(), "应该产生错误（未找到变量）")
	print("  ✓ 未找到变量错误处理通过")

	print("✓ 错误处理测试通过")

## 辅助函数：浮点数比较
func is_equal_approx(a: float, b: float, epsilon: float = 0.0001) -> bool:
	return abs(a - b) < epsilon
