extends Node

## Random Number 指令测试脚本

var test_results: Array[String] = []
var test_passed: int = 0
var test_failed: int = 0

func _ready():
	print("=== Random Number 指令测试开始 ===")

	# 运行测试
	_run_all_tests()

	# 显示测试结果
	_show_test_results()

	print("=== Random Number 指令测试完成 ===")

## 运行所有测试
func _run_all_tests():
	# 基础功能测试
	_test_basic_functionality()

	# 整数随机数测试
	_test_integer_random()

	# 浮点随机数测试
	_test_float_random()

	# 变量存储测试
	_test_variable_storage()

	# 范围验证测试
	_test_range_validation()

## 测试基础功能
func _test_basic_functionality():
	print("\n--- 测试基础功能 ---")

	# 测试1: 创建指令实例
	var instruction = RandomNumber.new()
	instruction.log_level = FuseLogger.LogLevel.DEBUG
	if instruction:
		_record_test_result("创建指令实例", true)
	else:
		_record_test_result("创建指令实例", false)
		return

	# 测试2: 设置参数
	instruction.min_value = 10.0
	instruction.max_value = 20.0
	instruction.is_integer = false
	instruction.save_to_variable = "test_random"
	instruction.is_global = false

	if instruction.min_value == 10.0 and instruction.max_value == 20.0:
		_record_test_result("设置参数", true)
	else:
		_record_test_result("设置参数", false)

	# 测试3: 执行指令
	var context = ExecutionContext.new()
	var execution_result = {"executed": false}
	instruction.finished.connect(func(): execution_result.executed = true)
	instruction.execute(context)

	await get_tree().create_timer(0.1).timeout

	if execution_result.executed:
		_record_test_result("执行指令", true)
	else:
		_record_test_result("执行指令", false)

	# 测试4: 检查变量值
	if context.has_variable("test_random"):
		var random_val = context.get_variable("test_random")
		if random_val >= 10.0 and random_val <= 20.0:
			_record_test_result("变量值在范围内", true)
			print("生成的随机数: %s" % str(random_val))
		else:
			_record_test_result("变量值在范围内", false, "值: %s" % str(random_val))
	else:
		_record_test_result("变量值在范围内", false, "变量未创建")

## 测试整数随机数
func _test_integer_random():
	print("\n--- 测试整数随机数 ---")

	var instruction = RandomNumber.new()
	instruction.log_level = FuseLogger.LogLevel.DEBUG
	instruction.min_value = 1.0
	instruction.max_value = 10.0
	instruction.is_integer = true
	instruction.save_to_variable = "test_int_random"
	instruction.is_global = false

	var context = ExecutionContext.new()
	var execution_result = {"executed": false}
	instruction.finished.connect(func(): execution_result.executed = true)
	instruction.execute(context)

	await get_tree().create_timer(0.1).timeout

	if execution_result.executed and context.has_variable("test_int_random"):
		var random_val = context.get_variable("test_int_random")
		var is_int = (random_val == int(random_val))
		var in_range = (random_val >= 1 and random_val <= 10)

		if is_int and in_range:
			_record_test_result("整数随机数", true, "值: %s" % str(random_val))
		else:
			_record_test_result("整数随机数", false, "值: %s, 是整数: %s, 在范围内: %s" % [str(random_val), is_int, in_range])
	else:
		_record_test_result("整数随机数", false)

## 测试浮点随机数
func _test_float_random():
	print("\n--- 测试浮点随机数 ---")

	var instruction = RandomNumber.new()
	instruction.log_level = FuseLogger.LogLevel.DEBUG
	instruction.min_value = 0.0
	instruction.max_value = 1.0
	instruction.is_integer = false
	instruction.save_to_variable = "test_float_random"
	instruction.is_global = false

	var context = ExecutionContext.new()
	var execution_result = {"executed": false}
	instruction.finished.connect(func(): execution_result.executed = true)
	instruction.execute(context)

	await get_tree().create_timer(0.1).timeout

	if execution_result.executed and context.has_variable("test_float_random"):
		var random_val = context.get_variable("test_float_random")
		var in_range = (random_val >= 0.0 and random_val <= 1.0)

		if in_range:
			_record_test_result("浮点随机数", true, "值: %s" % str(random_val))
		else:
			_record_test_result("浮点随机数", false, "值: %s" % str(random_val))
	else:
		_record_test_result("浮点随机数", false)

## 测试变量存储
func _test_variable_storage():
	print("\n--- 测试变量存储 ---")

	# 测试本地变量
	var instruction = RandomNumber.new()
	instruction.log_level = FuseLogger.LogLevel.DEBUG
	instruction.min_value = 5.0
	instruction.max_value = 15.0
	instruction.is_integer = true
	instruction.save_to_variable = "local_random"
	instruction.is_global = false

	var context = ExecutionContext.new()
	var execution_result = {"executed": false}
	instruction.finished.connect(func(): execution_result.executed = true)
	instruction.execute(context)

	await get_tree().create_timer(0.1).timeout

	if execution_result.executed and context.has_variable("local_random"):
		_record_test_result("本地变量存储", true)
	else:
		_record_test_result("本地变量存储", false)

## 测试范围验证
func _test_range_validation():
	print("\n--- 测试范围验证 ---")

	# 测试1: 无效范围（最小值 > 最大值）
	var instruction = RandomNumber.new()
	instruction.log_level = FuseLogger.LogLevel.DEBUG
	instruction.min_value = 100.0
	instruction.max_value = 10.0
	instruction.save_to_variable = "test_invalid"

	# 验证方法应该捕获这个错误
	var errors = instruction.validate()
	if errors.size() > 0:
		_record_test_result("范围验证（最小值 > 最大值）", true)
	else:
		_record_test_result("范围验证（最小值 > 最大值）", false, "应该检测到范围错误")

	# 测试2: 空变量名
	instruction.min_value = 10.0
	instruction.max_value = 20.0
	instruction.save_to_variable = ""

	errors = instruction.validate()
	if errors.size() > 0:
		_record_test_result("变量名验证（空变量名）", true)
	else:
		_record_test_result("变量名验证（空变量名）", false, "应该检测到空变量名")

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
