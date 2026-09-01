extends Node

## Vector Operation 指令测试脚本

var test_results: Array[String] = []
var test_passed: int = 0
var test_failed: int = 0

func _ready():
	print("=== Vector Operation 指令测试开始 ===")

	# 运行测试
	_run_all_tests()

	# 显示测试结果
	_show_test_results()

	print("=== Vector Operation 指令测试完成 ===")

## 运行所有测试
func _run_all_tests():
	# 向量加法测试
	_test_vector_add()

	# 向量减法测试
	_test_vector_subtract()

	# 向量归一化测试
	_test_vector_normalize()

	# 向量长度测试
	_test_vector_length()

	# 两点距离测试
	_test_vector_distance()

	# Vector3 运算测试
	_test_vector3_operations()

	# 零向量归一化测试
	_test_zero_vector_normalize()

	# 变量向量测试
	_test_variable_vectors()

	# 验证测试
	_test_validation()

## 测试向量加法
func _test_vector_add():
	print("\n--- 测试向量加法 ---")

	var instruction = VectorOperation.new()
	instruction.log_level = FuseLogger.LogLevel.DEBUG
	instruction.operation_type = VectorOperation.OperationType.VECTOR_ADD
	instruction.vector_type = VectorOperation.VectorType.VECTOR2
	instruction.vector_a_variable = "vec_a"
	instruction.vector_a_scope = BaseVariable.VariableScope.LOCAL
	instruction.vector_b_use_variable = false
	instruction.vector_b_value = Vector2(5, 15)
	instruction.save_to_variable = "test_add"
	instruction.save_to_scope = BaseVariable.VariableScope.LOCAL

	var context =ExecutionContext.new()
	context.set_variable("vec_a", Vector2(10, 20))

	var execution_result= {"executed": false}
	instruction.finished.connect(func(): execution_result.executed = true)
	instruction.execute(context)

	await get_tree().create_timer(0.1).timeout

	if execution_result.executed and context.has_variable("test_add"):
		var result = context.get_variable("test_add")
		if result is Vector2 and result.x == 15.0 and result.y == 35.0:
			_record_test_result("Vector2 加法 (10,20) + (5,15) = (15,35)", true)
		else:
			_record_test_result("Vector2 加法", false, "期望: Vector2(15,35), 实际: %s" % str(result))
	else:
		_record_test_result("Vector2 加法", false)

## 测试向量减法
func _test_vector_subtract():
	print("\n--- 测试向量减法 ---")

	var instruction = VectorOperation.new()
	instruction.log_level = FuseLogger.LogLevel.DEBUG
	instruction.operation_type = VectorOperation.OperationType.VECTOR_SUBTRACT
	instruction.vector_type = VectorOperation.VectorType.VECTOR3
	instruction.vector_a_variable= "vec_a"
	instruction.vector_a_scope = BaseVariable.VariableScope.LOCAL
	instruction.vector_b_use_variable = false
	instruction.vector_b_value = Vector3(3, 5, 7)
	instruction.save_to_variable = "test_subtract"
	instruction.save_to_scope = BaseVariable.VariableScope.LOCAL

	var context = ExecutionContext.new()
	context.set_variable("vec_a", Vector3(10, 20, 30))

	var execution_result= {"executed": false}
	instruction.finished.connect(func(): execution_result.executed = true)
	instruction.execute(context)

	await get_tree().create_timer(0.1).timeout

	if execution_result.executed and context.has_variable("test_subtract"):
		var result = context.get_variable("test_subtract")
		if result is Vector3 and result.x == 7.0 and result.y == 15.0 and result.z == 23.0:
			_record_test_result("Vector3 减法 (10,20,30) - (3,5,7) = (7,15,23)", true)
		else:
			_record_test_result("Vector3 减法", false, "期望: Vector3(7,15,23), 实际: %s" % str(result))
	else:
		_record_test_result("Vector3 减法", false)

## 测试向量归一化
func _test_vector_normalize():
	print("\n--- 测试向量归一化 ---")

	var instruction = VectorOperation.new()
	instruction.log_level = FuseLogger.LogLevel.DEBUG
	instruction.operation_type = VectorOperation.OperationType.NORMALIZE
	instruction.vector_type = VectorOperation.VectorType.VECTOR2
	instruction.vector_a_variable = "vec_a"
	instruction.vector_a_scope = BaseVariable.VariableScope.LOCAL
	instruction.save_to_variable = "test_normalize"
	instruction.save_to_scope = BaseVariable.VariableScope.LOCAL

	var context = ExecutionContext.new()
	context.set_variable("vec_a", Vector2(30, 40))

	var execution_result= {"executed": false}
	instruction.finished.connect(func(): execution_result.executed = true)
	instruction.execute(context)

	await get_tree().create_timer(0.1).timeout

	if execution_result.executed and context.has_variable("test_normalize"):
		var result = context.get_variable("test_normalize")
		var length = result.length()
		if result is Vector2 and is_equal_approx(length, 1.0):
			_record_test_result("向量归一化 (30,40) → 单位向量", true)
		else:
			_record_test_result("向量归一化", false, "期望长度: 1.0, 实际: %s" % str(length))
	else:
		_record_test_result("向量归一化", false)

## 测试向量长度
func _test_vector_length():
	print("\n--- 测试向量长度 ---")

	var instruction = VectorOperation.new()
	instruction.log_level = FuseLogger.LogLevel.DEBUG
	instruction.operation_type = VectorOperation.OperationType.LENGTH
	instruction.vector_type = VectorOperation.VectorType.VECTOR2
	instruction.vector_a_variable = "vec_a"
	instruction.vector_a_scope = BaseVariable.VariableScope.LOCAL
	instruction.save_to_variable = "test_length"
	instruction.save_to_scope = BaseVariable.VariableScope.LOCAL

	var context = ExecutionContext.new()
	context.set_variable("vec_a", Vector2(3, 4))

	var execution_result= {"executed": false}
	instruction.finished.connect(func(): execution_result.executed = true)
	instruction.execute(context)

	await get_tree().create_timer(0.1).timeout

	if execution_result.executed and context.has_variable("test_length"):
		var result = context.get_variable("test_length")
		if result is float and is_equal_approx(result, 5.0):
			_record_test_result("向量长度 |(3,4)| = 5.0", true)
		else:
			_record_test_result("向量长度", false, "期望: 5.0, 实际: %s" % str(result))
	else:
		_record_test_result("向量长度", false)

## 测试两点距离
func _test_vector_distance():
	print("\n--- 测试两点距离 ---")

	var instruction = VectorOperation.new()
	instruction.log_level = FuseLogger.LogLevel.DEBUG
	instruction.operation_type = VectorOperation.OperationType.DISTANCE
	instruction.vector_type = VectorOperation.VectorType.VECTOR2
	instruction.vector_a_variable = "vec_a"
	instruction.vector_a_scope = BaseVariable.VariableScope.LOCAL
	instruction.vector_b_use_variable = false
	instruction.vector_b_value = Vector2(3, 4)
	instruction.save_to_variable = "test_distance"
	instruction.save_to_scope = BaseVariable.VariableScope.LOCAL

	var context = ExecutionContext.new()
	context.set_variable("vec_a", Vector2(0, 0))

	var execution_result= {"executed": false}
	instruction.finished.connect(func(): execution_result.executed = true)
	instruction.execute(context)

	await get_tree().create_timer(0.1).timeout

	if execution_result.executed and context.has_variable("test_distance"):
		var result = context.get_variable("test_distance")
		if result is float and is_equal_approx(result, 5.0):
			_record_test_result("两点距离 (0,0) 到 (3,4) = 5.0", true)
		else:
			_record_test_result("两点距离", false, "期望: 5.0, 实际: %s" % str(result))
	else:
		_record_test_result("两点距离", false)

## 测试 Vector3 运算
func _test_vector3_operations():
	print("\n--- 测试 Vector3 运算 ---")

	# Vector3 长度
	var instruction = VectorOperation.new()
	instruction.log_level = FuseLogger.LogLevel.DEBUG
	instruction.operation_type = VectorOperation.OperationType.LENGTH
	instruction.vector_type = VectorOperation.VectorType.VECTOR3
	instruction.vector_a_variable = "vec_a"
	instruction.vector_a_scope = BaseVariable.VariableScope.LOCAL
	instruction.save_to_variable = "test_v3_length"
	instruction.save_to_scope = BaseVariable.VariableScope.LOCAL

	var context = ExecutionContext.new()
	context.set_variable("vec_a", Vector3(1, 2, 2))

	var execution_result= {"executed": false}
	instruction.finished.connect(func(): execution_result.executed = true)
	instruction.execute(context)

	await get_tree().create_timer(0.1).timeout

	if execution_result.executed and context.has_variable("test_v3_length"):
		var result = context.get_variable("test_v3_length")
		if result is float and is_equal_approx(result, 3.0):
			_record_test_result("Vector3 长度 |(1,2,2)| = 3.0", true)
		else:
			_record_test_result("Vector3 长度", false, "期望: 3.0, 实际: %s" % str(result))
	else:
		_record_test_result("Vector3 长度", false)

## 测试零向量归一化
func _test_zero_vector_normalize():
	print("\n--- 测试零向量归一化 ---")

	var instruction = VectorOperation.new()
	instruction.log_level = FuseLogger.LogLevel.DEBUG
	instruction.operation_type = VectorOperation.OperationType.NORMALIZE
	instruction.vector_type = VectorOperation.VectorType.VECTOR2
	instruction.vector_a_variable = "vec_a"
	instruction.vector_a_scope = BaseVariable.VariableScope.LOCAL
	instruction.save_to_variable = "test_zero_normalize"
	instruction.save_to_scope = BaseVariable.VariableScope.LOCAL

	var context = ExecutionContext.new()
	context.set_variable("vec_a", Vector2(0, 0))

	var execution_result= {"executed": false}
	instruction.finished.connect(func(): execution_result.executed = true)
	instruction.execute(context)

	await get_tree().create_timer(0.1).timeout

	if execution_result.executed and context.has_variable("test_zero_normalize"):
		var result = context.get_variable("test_zero_normalize")
		if result is Vector2 and result == Vector2(0, 0):
			_record_test_result("零向量归一化返回零向量", true)
		else:
			_record_test_result("零向量归一化", false, "期望: Vector2(0,0), 实际: %s" % str(result))
	else:
		_record_test_result("零向量归一化", false)

## 测试变量向量
func _test_variable_vectors():
	print("\n--- 测试变量向量 ---")

	var instruction = VectorOperation.new()
	instruction.log_level = FuseLogger.LogLevel.DEBUG
	instruction.operation_type = VectorOperation.OperationType.VECTOR_ADD
	instruction.vector_type = VectorOperation.VectorType.VECTOR2
	instruction.vector_a_variable = "vec_a"
	instruction.vector_a_scope = BaseVariable.VariableScope.LOCAL
	instruction.vector_b_use_variable = true
	instruction.vector_b_variable = "vec_b"
	instruction.vector_b_scope = BaseVariable.VariableScope.LOCAL
	instruction.save_to_variable = "test_var_vec"
	instruction.save_to_scope = BaseVariable.VariableScope.LOCAL

	var context = ExecutionContext.new()
	context.set_variable("vec_a", Vector2(100, 200))
	context.set_variable("vec_b", Vector2(50, 75))

	var execution_result= {"executed": false}
	instruction.finished.connect(func(): execution_result.executed = true)
	instruction.execute(context)

	await get_tree().create_timer(0.1).timeout

	if execution_result.executed and context.has_variable("test_var_vec"):
		var result = context.get_variable("test_var_vec")
		if result is Vector2 and result.x == 150.0 and result.y == 275.0:
			_record_test_result("变量向量 (100,200) + (50,75) = (150,275)", true)
		else:
			_record_test_result("变量向量", false, "期望: Vector2(150,275), 实际: %s" % str(result))
	else:
		_record_test_result("变量向量", false)

## 测试验证
func _test_validation():
	print("\n--- 测试验证 ---")

	# 测试1: 空变量名
	var instruction = VectorOperation.new()
	instruction.log_level = FuseLogger.LogLevel.DEBUG
	instruction.operation_type = VectorOperation.OperationType.VECTOR_ADD
	instruction.vector_type = VectorOperation.VectorType.VECTOR2
	instruction.vector_a_variable = "vec_a"
	instruction.vector_a_scope = BaseVariable.VariableScope.LOCAL
	instruction.vector_b_use_variable = false
	instruction.vector_b_value = Vector2(5, 15)
	instruction.save_to_variable = ""

	var errors = instruction.validate()
	if errors.size() > 0:
		_record_test_result("变量名验证（空变量名）", true)
	else:
		_record_test_result("变量名验证（空变量名）", false)

	# 测试2: 向量 A 变量名为空
	instruction.save_to_variable = "test_var"
	instruction.vector_a_variable = ""

	errors = instruction.validate()
	if errors.size() > 0:
		_record_test_result("向量 A 变量验证", true)
	else:
		_record_test_result("向量 A 变量验证", false)

	# 测试3: 向量 B 变量来源但变量名为空
	instruction.vector_a_variable = "vec_a"
	instruction.vector_b_use_variable = true
	instruction.vector_b_variable = ""

	errors = instruction.validate()
	if errors.size() > 0:
		_record_test_result("向量 B 变量验证", true)
	else:
		_record_test_result("向量 B 变量验证", false)

## 记录测试结果
func _record_test_result(test_name: String, passed: bool, details: String = ""):
	var status = "PASS" if passed else "FAIL"
	var result = "[%s] %s" % [status, test_name]
	if not details.is_empty():
		result += " - " + details

	test_results.append(result)

	if passed:
		test_passed += 1
	else:
		test_failed += 1

	print(result)

## 显示测试结果
func _show_test_results():
	print("\n=== 测试结果汇总 ===")
	print("通过: %d" % test_passed)
	print("失败: %d" % test_failed)
	print("总计: %d" % (test_passed + test_failed))

	if test_failed > 0:
		print("\n失败的测试:")
		for result in test_results:
			if result.begins_with("[FAIL]"):
				print("  " + result)

	print("\n所有测试详情:")
	for result in test_results:
		print("  " + result)
