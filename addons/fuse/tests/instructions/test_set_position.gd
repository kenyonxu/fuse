extends Node

## Set Position 指令测试脚本

# 测试节点
var test_node_2d: Node2D
var test_node_3d: Node3D

# 执行上下文
var context: ExecutionContext

# 测试结果
var tests_passed := 0
var tests_failed := 0
var test_results := []

func _ready():
	print("=== Set Position 指令测试开始 ===\n")

	# 初始化测试环境
	_setup_test_environment()

	# 运行测试
	_test_set_position_2d_global()
	_test_set_position_2d_local()
	_test_set_position_3d_global()
	_test_set_position_3d_local()
	_test_set_position_from_variable()
	_test_validation()
	_test_invalid_node_type()
	_test_nan_position()
	_test_extreme_positions()

	# 输出测试结果
	_print_test_results()

	# 清理
	_cleanup()

	# 退出测试
	print("\n=== 测试完成 ===")
	get_tree().quit()

## 初始化测试环境
func _setup_test_environment():
	# 创建 2D 测试节点
	test_node_2d = Node2D.new()
	test_node_2d.name = "TestNode2D"
	add_child(test_node_2d)

	# 创建 3D 测试节点
	test_node_3d = Node3D.new()
	test_node_3d.name = "TestNode3D"
	add_child(test_node_3d)

	# 创建执行上下文
	var scene_tree = get_tree()
	context = ExecutionContext.new(test_node_2d, null, null, scene_tree)

	print("测试环境初始化完成")
	print("  - 创建 Node2D: %s" % test_node_2d.name)
	print("  - 创建 Node3D: %s" % test_node_3d.name)
	print("  - 创建执行上下文\n")

## 测试 1: 设置 2D 节点的全局位置
func _test_set_position_2d_global():
	print("测试 1: 设置 2D 节点的全局位置")

	# 创建指令
	var instruction_script = load("res://addons/fuse/instructions/set_position.gd")
	var instruction = instruction_script.new()
	instruction.target_node = NodePath("../TestNode2D")
	instruction.position = Vector3(100.0, 200.0, 0.0)
	instruction.space = 0  # GLOBAL
	instruction.use_variable = false

	# 记录初始位置
	var initial_pos = test_node_2d.global_position
	print("  初始位置: (%.2f, %.2f)" % [initial_pos.x, initial_pos.y])

	# 执行指令
	instruction.execute(context)

	# 验证结果
	await get_tree().process_frame
	var expected = Vector2(100.0, 200.0)
	var actual = test_node_2d.global_position

	if actual.is_equal_approx(expected):
		_test_pass("设置 2D 全局位置成功")
		print("  期望位置: (%.2f, %.2f)" % [expected.x, expected.y])
		print("  实际位置: (%.2f, %.2f)" % [actual.x, actual.y])
	else:
		_test_fail("设置 2D 全局位置失败")
		print("  期望位置: (%.2f, %.2f)" % [expected.x, expected.y])
		print("  实际位置: (%.2f, %.2f)" % [actual.x, actual.y])

	print()

## 测试 2: 设置 2D 节点的局部位置
func _test_set_position_2d_local():
	print("测试 2: 设置 2D 节点的局部位置")

	# 创建指令
	var instruction_script = load("res://addons/fuse/instructions/set_position.gd")
	var instruction = instruction_script.new()
	instruction.target_node = NodePath("../TestNode2D")
	instruction.position = Vector3(50.0, 75.0, 0.0)
	instruction.space = 1  # LOCAL
	instruction.use_variable = false

	# 执行指令
	instruction.execute(context)

	# 验证结果
	await get_tree().process_frame
	var expected = Vector2(50.0, 75.0)
	var actual = test_node_2d.position

	if actual.is_equal_approx(expected):
		_test_pass("设置 2D 局部位置成功")
		print("  期望位置: (%.2f, %.2f)" % [expected.x, expected.y])
		print("  实际位置: (%.2f, %.2f)" % [actual.x, actual.y])
	else:
		_test_fail("设置 2D 局部位置失败")
		print("  期望位置: (%.2f, %.2f)" % [expected.x, expected.y])
		print("  实际位置: (%.2f, %.2f)" % [actual.x, actual.y])

	print()

## 测试 3: 设置 3D 节点的全局位置
func _test_set_position_3d_global():
	print("测试 3: 设置 3D 节点的全局位置")

	# 创建指令
	var instruction_script = load("res://addons/fuse/instructions/set_position.gd")
	var instruction = instruction_script.new()
	instruction.target_node = NodePath("../TestNode3D")
	instruction.position = Vector3(10.0, 20.0, 30.0)
	instruction.space = 0  # GLOBAL
	instruction.use_variable = false

	# 执行指令
	instruction.execute(context)

	# 验证结果
	await get_tree().process_frame
	var expected = Vector3(10.0, 20.0, 30.0)
	var actual = test_node_3d.global_position

	if actual.is_equal_approx(expected):
		_test_pass("设置 3D 全局位置成功")
		print("  期望位置: (%.2f, %.2f, %.2f)" % [expected.x, expected.y, expected.z])
		print("  实际位置: (%.2f, %.2f, %.2f)" % [actual.x, actual.y, actual.z])
	else:
		_test_fail("设置 3D 全局位置失败")
		print("  期望位置: (%.2f, %.2f, %.2f)" % [expected.x, expected.y, expected.z])
		print("  实际位置: (%.2f, %.2f, %.2f)" % [actual.x, actual.y, actual.z])

	print()

## 测试 4: 设置 3D 节点的局部位置
func _test_set_position_3d_local():
	print("测试 4: 设置 3D 节点的局部位置")

	# 创建指令
	var instruction_script = load("res://addons/fuse/instructions/set_position.gd")
	var instruction = instruction_script.new()
	instruction.target_node = NodePath("../TestNode3D")
	instruction.position = Vector3(5.0, 10.0, 15.0)
	instruction.space = 1  # LOCAL
	instruction.use_variable = false

	# 执行指令
	instruction.execute(context)

	# 验证结果
	await get_tree().process_frame
	var expected = Vector3(5.0, 10.0, 15.0)
	var actual = test_node_3d.position

	if actual.is_equal_approx(expected):
		_test_pass("设置 3D 局部位置成功")
		print("  期望位置: (%.2f, %.2f, %.2f)" % [expected.x, expected.y, expected.z])
		print("  实际位置: (%.2f, %.2f, %.2f)" % [actual.x, actual.y, actual.z])
	else:
		_test_fail("设置 3D 局部位置失败")
		print("  期望位置: (%.2f, %.2f, %.2f)" % [expected.x, expected.y, expected.z])
		print("  实际位置: (%.2f, %.2f, %.2f)" % [actual.x, actual.y, actual.z])

	print()

## 测试 5: 从变量设置位置
func _test_set_position_from_variable():
	print("测试 5: 从变量设置位置")

	# 设置变量
	var test_position = Vector2(150.0, 250.0)
	context.set_variable("test_pos", test_position)

	# 创建指令
	var instruction_script = load("res://addons/fuse/instructions/set_position.gd")
	var instruction = instruction_script.new()
	instruction.target_node = NodePath("../TestNode2D")
	instruction.space = 0  # GLOBAL
	instruction.use_variable = true
	instruction.position_variable = "test_pos"

	# 执行指令
	instruction.execute(context)

	# 验证结果
	await get_tree().process_frame
	var actual = test_node_2d.global_position

	if actual.is_equal_approx(test_position):
		_test_pass("从变量设置位置成功")
		print("  变量值: (%.2f, %.2f)" % [test_position.x, test_position.y])
		print("  实际位置: (%.2f, %.2f)" % [actual.x, actual.y])
	else:
		_test_fail("从变量设置位置失败")
		print("  变量值: (%.2f, %.2f)" % [test_position.x, test_position.y])
		print("  实际位置: (%.2f, %.2f)" % [actual.x, actual.y])

	print()

## 测试 6: 参数验证
func _test_validation():
	print("测试 6: 参数验证")

	# 测试空目标节点
	var instruction_script = load("res://addons/fuse/instructions/set_position.gd")
	var instruction1 = instruction_script.new()
	instruction1.target_node = NodePath("")
	var errors1 = instruction1.validate()

	if errors1.size() > 0 and "目标节点路径不能为空" in errors1[0]:
		_test_pass("空目标节点验证成功")
		print("  错误信息: %s" % errors1[0])
	else:
		_test_fail("空目标节点验证失败")

	# 测试空变量名（use_variable = true）
	var instruction2 = instruction_script.new()
	instruction2.target_node = NodePath("../TestNode2D")
	instruction2.use_variable = true
	instruction2.position_variable = ""
	var errors2 = instruction2.validate()

	if errors2.size() > 0 and "位置变量名不能为空" in errors2[0]:
		_test_pass("空变量名验证成功")
		print("  错误信息: %s" % errors2[0])
	else:
		_test_fail("空变量名验证失败")

	print()

## 测试 7: 无效节点类型
func _test_invalid_node_type():
	print("测试 7: 无效节点类型")

	# 创建一个无效的测试节点（Node 而非 Node2D/Node3D）
	var invalid_node = Node.new()
	invalid_node.name = "InvalidNode"
	add_child(invalid_node)

	# 创建指令
	var instruction_script = load("res://addons/fuse/instructions/set_position.gd")
	var instruction = instruction_script.new()
	instruction.target_node = NodePath("../InvalidNode")
	instruction.position = Vector3(1.0, 2.0, 3.0)
	instruction.space = 0  # GLOBAL
	instruction.use_variable = false

	# 执行指令
	instruction.execute(context)

	# 验证结果
	await get_tree().process_frame
	if instruction.has_error():
		_test_pass("无效节点类型错误处理成功")
		print("  错误信息: %s" % instruction.get_error_message())
	else:
		_test_fail("无效节点类型错误处理失败")

	# 清理
	invalid_node.queue_free()
	print()

## 测试 8: NaN 位置处理
func _test_nan_position():
	print("测试 8: NaN 位置处理")

	# 创建指令，尝试设置 NaN 位置
	var instruction_script = load("res://addons/fuse/instructions/set_position.gd")
	var instruction = instruction_script.new()
	instruction.target_node = NodePath("../TestNode2D")
	instruction.position = Vector3(NAN, NAN, NAN)
	instruction.space = 0  # GLOBAL
	instruction.use_variable = false

	# 执行指令
	instruction.execute(context)

	# 验证结果
	await get_tree().process_frame
	var actual = test_node_2d.global_position

	# NaN 检查：位置应该是有限值
	var is_valid = is_finite(actual.x) and is_finite(actual.y)

	if is_valid:
		_test_pass("NaN 位置被正确拒绝或处理")
		print("  位置保持为有限值: (%.2f, %.2f)" % [actual.x, actual.y])
	else:
		_test_fail("NaN 位置未被正确处理")
		print("  位置为非有限值: (%s, %s)" % [str(actual.x), str(actual.y)])

	print()

## 测试 9: 极值位置测试
func _test_extreme_positions():
	print("测试 9: 极值位置处理")

	var extreme_positions = [
		Vector3(1e6, 1e6, 0),      # 超大值
		Vector3(-1e6, -1e6, 0),    # 超小值
		Vector3(1e-6, 1e-6, 0),    # 接近零
		Vector3(1e38, 1e38, 0)     # 接近浮点极限
	]

	var all_valid = true

	for i in range(extreme_positions.size()):
		var pos = extreme_positions[i]

		# 创建指令
		var instruction_script = load("res://addons/fuse/instructions/set_position.gd")
		var instruction = instruction_script.new()
		instruction.target_node = NodePath("../TestNode2D")
		instruction.position = pos
		instruction.space = 0  # GLOBAL
		instruction.use_variable = false

		# 执行指令
		instruction.execute(context)
		await get_tree().process_frame

		# 验证位置仍然是有限值
		var actual = test_node_2d.global_position
		var is_valid = is_finite(actual.x) and is_finite(actual.y)

		if not is_valid:
			all_valid = false
			print("  位置 %d: 失败 (%s, %s)" % [i, str(actual.x), str(actual.y)])
		else:
			print("  位置 %d: 通过 (%.2e, %.2e)" % [i, actual.x, actual.y])

	if all_valid:
		_test_pass("所有极值位置都被正确处理")
	else:
		_test_fail("某些极值位置未被正确处理")

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
		var status_symbol = "✓" if result.status == "PASS" else "✗"
		print("%d. %s %s" % [i + 1, status_symbol, result.description])

	print("=".repeat(50))

## 清理资源
func _cleanup():
	if test_node_2d:
		test_node_2d.queue_free()
	if test_node_3d:
		test_node_3d.queue_free()
	context = null

	print("测试环境已清理")
