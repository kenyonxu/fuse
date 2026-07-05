extends Node

## Math Operation 指令测试脚本

var test_results: Array[String] = []
var test_passed: int = 0
var test_failed: int = 0

func _ready():
	print("=== Math Operation 指令测试开始 ===")

	# 运行测试
	_run_all_tests()

	# 显示测试结果
	_show_test_results()

	print("=== Math Operation 指令测试完成 ===")

## 运行所有测试
func _run_all_tests():
	# 加法运算测试
	_test_add_operation()

	# 减法运算测试
	_test_subtract_operation()

	# 乘法运算测试
	_test_multiply_operation()

	# 除法运算测试
	_test_divide_operation()

	# 取模运算测试
	_test_modulo_operation()

	# 除零错误测试
	_test_division_by_zero()

	# 变量操作数测试
	_test_variable_operands()

	# 验证测试
	_test_validation()

## 测试加法运算
func _test_add_operation():
	print("\n--- 测试加法运算 ---")

	var instruction = MathOperation.new()
	instruction.log_level = FuseLogger.LogLevel.DEBUG
	instruction.operation_type = MathOperation.OperationType.ADD
	instruction.operand_a_source = MathOperation.OperandASource.VALUE
	instruction.operand_a_value = 10.0
	instruction.operand_b_source = MathOperation.OperandBSource.VALUE
	instruction.operand_b_value = 5.0
	instruction.save_to_variable = "test_add"
	instruction.is_global = false

	var context = ExecutionContext.new()
	var execution_result = {"executed": false}
	instruction.finished.connect(func(): execution_result.executed = true)
	instruction.execute(context)

	await get_tree().create_timer(0.1).timeout

	if execution_result.executed and context.has_variable("test_add"):
		var result = context.get_variable("test_add")
		if is_equal_approx(result, 15.0):
			_record_test_result("加法运算 (10 + 5 = 15)", true)
		else:
			_record_test_result("加法运算", false, "期望: 15.0, 实际: %s" % str(result))
	else:
		_record_test_result("加法运算", false)

## 测试减法运算
func _test_subtract_operation():
	print("\n--- 测试减法运算 ---")

	var instruction = MathOperation.new()
	instruction.log_level = FuseLogger.LogLevel.DEBUG
	instruction.operation_type = MathOperation.OperationType.SUBTRACT
	instruction.operand_a_source = MathOperation.OperandASource.VALUE
	instruction.operand_a_value = 20.0
	instruction.operand_b_source = MathOperation.OperandBSource.VALUE
	instruction.operand_b_value = 8.0
	instruction.save_to_variable = "test_subtract"
	instruction.is_global = false

	var context = ExecutionContext.new()
	var execution_result = {"executed": false}
	instruction.finished.connect(func(): execution_result.executed = true)
	instruction.execute(context)

	await get_tree().create_timer(0.1).timeout

	if execution_result.executed and context.has_variable("test_subtract"):
		var result = context.get_variable("test_subtract")
		if is_equal_approx(result, 12.0):
			_record_test_result("减法运算 (20 - 8 = 12)", true)
		else:
			_record_test_result("减法运算", false, "期望: 12.0, 实际: %s" % str(result))
	else:
		_record_test_result("减法运算", false)

## 测试乘法运算
func _test_multiply_operation():
	print("\n--- 测试乘法运算 ---")

	var instruction = MathOperation.new()
	instruction.log_level = FuseLogger.LogLevel.DEBUG
	instruction.operation_type = MathOperation.OperationType.MULTIPLY
	instruction.operand_a_source = MathOperation.OperandASource.VALUE
	instruction.operand_a_value = 6.0
	instruction.operand_b_source = MathOperation.OperandBSource.VALUE
	instruction.operand_b_value = 7.0
	instruction.save_to_variable = "test_multiply"
	instruction.is_global = false

	var context = ExecutionContext.new()
	var execution_result = {"executed": false}
	instruction.finished.connect(func(): execution_result.executed = true)
	instruction.execute(context)

	await get_tree().create_timer(0.1).timeout

	if execution_result.executed and context.has_variable("test_multiply"):
		var result = context.get_variable("test_multiply")
		if is_equal_approx(result, 42.0):
			_record_test_result("乘法运算 (6 × 7 = 42)", true)
		else:
			_record_test_result("乘法运算", false, "期望: 42.0, 实际: %s" % str(result))
	else:
		_record_test_result("乘法运算", false)

## 测试除法运算
func _test_divide_operation():
	print("\n--- 测试除法运算 ---")

	var instruction = MathOperation.new()
	instruction.log_level = FuseLogger.LogLevel.DEBUG
	instruction.operation_type = MathOperation.OperationType.DIVIDE
	instruction.operand_a_source = MathOperation.OperandASource.VALUE
	instruction.operand_a_value = 20.0
	instruction.operand_b_source = MathOperation.OperandBSource.VALUE
	instruction.operand_b_value = 4.0
	instruction.save_to_variable = "test_divide"
	instruction.is_global = false

	var context = ExecutionContext.new()
	var execution_result = {"executed": false}
	instruction.finished.connect(func(): execution_result.executed = true)
	instruction.execute(context)

	await get_tree().create_timer(0.1).timeout

	if execution_result.executed and context.has_variable("test_divide"):
		var result = context.get_variable("test_divide")
		if is_equal_approx(result, 5.0):
			_record_test_result("除法运算 (20 ÷ 4 = 5)", true)
		else:
			_record_test_result("除法运算", false, "期望: 5.0, 实际: %s" % str(result))
	else:
		_record_test_result("除法运算", false)

## 测试取模运算
func _test_modulo_operation():
	print("\n--- 测试取模运算 ---")

	var instruction = MathOperation.new()
	instruction.log_level = FuseLogger.LogLevel.DEBUG
	instruction.operation_type = MathOperation.OperationType.MODULO
	instruction.operand_a_source = MathOperation.OperandASource.VALUE
	instruction.operand_a_value = 17.0
	instruction.operand_b_source = MathOperation.OperandBSource.VALUE
	instruction.operand_b_value = 5.0
	instruction.save_to_variable = "test_modulo"
	instruction.is_global = false

	var context = ExecutionContext.new()
	var execution_result = {"executed": false}
	instruction.finished.connect(func(): execution_result.executed = true)
	instruction.execute(context)

	await get_tree().create_timer(0.1).timeout

	if execution_result.executed and context.has_variable("test_modulo"):
		var result = context.get_variable("test_modulo")
		if is_equal_approx(result, 2.0):
			_record_test_result("取模运算 (17 % 5 = 2)", true)
		else:
			_record_test_result("取模运算", false, "期望: 2.0, 实际: %s" % str(result))
	else:
		_record_test_result("取模运算", false)

## 测试除零错误
func _test_division_by_zero():
	print("\n--- 测试除零错误 ---")

	# 测试1: 除法除零
	var instruction = MathOperation.new()
	instruction.log_level = FuseLogger.LogLevel.DEBUG
	instruction.operation_type = MathOperation.OperationType.DIVIDE
	instruction.operand_a_source = MathOperation.OperandASource.VALUE
	instruction.operand_a_value = 10.0
	instruction.operand_b_source = MathOperation.OperandBSource.VALUE
	instruction.operand_b_value = 0.0
	instruction.save_to_variable = "test_div_zero"
	instruction.is_global = false

	var context = ExecutionContext.new()
	var execution_result = {"executed": false}
	instruction.finished.connect(func(): execution_result.executed = true)
	instruction.execute(context)

	await get_tree().create_timer(0.1).timeout

	if execution_result.executed and context.had_error():
		_record_test_result("除法除零错误检测", true)
	else:
		_record_test_result("除法除零错误检测", false)

	# 测试2: 取模除零
	instruction.operation_type = MathOperation.OperationType.MODULO
	instruction.save_to_variable = "test_mod_zero"

	context = ExecutionContext.new()
	execution_result = {"executed": false}
	instruction.finished.connect(func(): execution_result.executed = true)
	instruction.execute(context)

	await get_tree().create_timer(0.1).timeout

	if execution_result.executed and context.had_error():
		_record_test_result("取模除零错误检测", true)
	else:
		_record_test_result("取模除零错误检测", false)

## 测试变量操作数
func _test_variable_operands():
	print("\n--- 测试变量操作数 ---")

	var instruction = MathOperation.new()
	instruction.log_level = FuseLogger.LogLevel.DEBUG
	instruction.operation_type = MathOperation.OperationType.ADD
	instruction.operand_a_source = MathOperation.OperandASource.VARIABLE
	instruction.operand_a_variable = "var_a"
	instruction.operand_b_source = MathOperation.OperandBSource.VARIABLE
	instruction.operand_b_variable = "var_b"
	instruction.save_to_variable = "test_var_operands"
	instruction.is_global = false

	var context = ExecutionContext.new()
	context.set_variable("var_a", 15.0)
	context.set_variable("var_b", 25.0)

	var execution_result = {"executed": false}
	instruction.finished.connect(func(): execution_result.executed = true)
	instruction.execute(context)

	await get_tree().create_timer(0.1).timeout

	if execution_result.executed and context.has_variable("test_var_operands"):
		var result = context.get_variable("test_var_operands")
		if is_equal_approx(result, 40.0):
			_record_test_result("变量操作数 (15 + 25 = 40)", true)
		else:
			_record_test_result("变量操作数", false, "期望: 40.0, 实际: %s" % str(result))
	else:
		_record_test_result("变量操作数", false)

## 测试验证
func _test_validation():
	print("\n--- 测试验证 ---")

	# 测试1: 空变量名
	var instruction = MathOperation.new()
	instruction.log_level = FuseLogger.LogLevel.DEBUG
	instruction.operation_type = MathOperation.OperationType.ADD
	instruction.operand_a_source = MathOperation.OperandASource.VALUE
	instruction.operand_a_value = 10.0
	instruction.operand_b_source = MathOperation.OperandBSource.VALUE
	instruction.operand_b_value = 5.0
	instruction.save_to_variable = ""

	var errors = instruction.validate()
	if errors.size() > 0:
		_record_test_result("变量名验证（空变量名）", true)
	else:
		_record_test_result("变量名验证（空变量名）", false)

	# 测试2: 操作数 A 变量来源但变量名为空
	instruction.save_to_variable = "test_var"
	instruction.operand_a_source = MathOperation.OperandASource.VARIABLE
	instruction.operand_a_variable = ""

	errors = instruction.validate()
	if errors.size() > 0:
		_record_test_result("操作数 A 变量验证", true)
	else:
		_record_test_result("操作数 A 变量验证", false)

	# 测试3: 操作数 B 变量来源但变量名为空
	instruction.operand_a_source = MathOperation.OperandASource.VALUE
	instruction.operand_b_source = MathOperation.OperandBSource.VARIABLE
	instruction.operand_b_variable = ""

	errors = instruction.validate()
	if errors.size() > 0:
		_record_test_result("操作数 B 变量验证", true)
	else:
		_record_test_result("操作数 B 变量验证", false)

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
