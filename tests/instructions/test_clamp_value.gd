extends Node

## Clamp Value 指令测试脚本

var test_results: Array[String] = []
var test_passed: int = 0
var test_failed: int = 0

func _ready():
	print("=== Clamp Value 指令测试开始 ===")

	# 运行测试
	_run_all_tests()

	# 显示测试结果
	_show_test_results()

	print("=== Clamp Value 指令测试完成 ===")

## 运行所有测试
func _run_all_tests():
	# 基础功能测试
	_test_basic_functionality()

	# 直接值测试
	_test_direct_value()

	# 变量值测试
	_test_variable_value()

	# 边界值测试
	_test_boundary_values()

	# 验证测试
	_test_validation()

## 测试基础功能
func _test_basic_functionality():
	print("\n--- 测试基础功能 ---")

	# 测试1: 创建指令实例
	var instruction = ClampValue.new()
	instruction.log_level = FuseLogger.LogLevel.DEBUG
	if instruction:
		_record_test_result("创建指令实例", true)
	else:
		_record_test_result("创建指令实例", false)
		return

	# 测试2: 设置参数
	instruction.value_source = ClampValue.ValueSource.DIRECT
	instruction.value = 150.0
	instruction.min_value = 0.0
	instruction.max_value = 100.0
	instruction.save_to_variable = "test_clamped"
	instruction.is_global = false

	if instruction.min_value == 0.0 and instruction.max_value == 100.0:
		_record_test_result("设置参数", true)
	else:
		_record_test_result("设置参数", false)

## 测试直接值
func _test_direct_value():
	print("\n--- 测试直接值 ---")

	# 测试1: 值大于最大值
	var instruction = ClampValue.new()
	instruction.log_level = FuseLogger.LogLevel.DEBUG
	instruction.value_source = ClampValue.ValueSource.DIRECT
	instruction.value = 150.0
	instruction.min_value = 0.0
	instruction.max_value = 100.0
	instruction.save_to_variable = "test_clamp_high"
	instruction.is_global = false

	var context = ExecutionContext.new()
	var execution_result = {"executed": false}
	instruction.finished.connect(func(): execution_result.executed = true)
	instruction.execute(context)

	await get_tree().create_timer(0.1).timeout

	if execution_result.executed and context.has_variable("test_clamp_high"):
		var clamped_val = context.get_variable("test_clamp_high")
		if clamped_val == 100.0:
			_record_test_result("限制高值", true, "150.0 → 100.0")
		else:
			_record_test_result("限制高值", false, "期望: 100.0, 实际: %s" % str(clamped_val))
	else:
		_record_test_result("限制高值", false)

	# 测试2: 值小于最小值
	instruction.value = -50.0
	instruction.save_to_variable = "test_clamp_low"

	context = ExecutionContext.new()
	execution_result = {"executed": false}
	instruction.finished.connect(func(): execution_result.executed = true)
	instruction.execute(context)

	await get_tree().create_timer(0.1).timeout

	if execution_result.executed and context.has_variable("test_clamp_low"):
		var clamped_val = context.get_variable("test_clamp_low")
		if clamped_val == 0.0:
			_record_test_result("限制低值", true, "-50.0 → 0.0")
		else:
			_record_test_result("限制低值", false, "期望: 0.0, 实际: %s" % str(clamped_val))
	else:
		_record_test_result("限制低值", false)

	# 测试3: 值在范围内
	instruction.value = 50.0
	instruction.save_to_variable = "test_clamp_mid"

	context = ExecutionContext.new()
	execution_result = {"executed": false}
	instruction.finished.connect(func(): execution_result.executed = true)
	instruction.execute(context)

	await get_tree().create_timer(0.1).timeout

	if execution_result.executed and context.has_variable("test_clamp_mid"):
		var clamped_val = context.get_variable("test_clamp_mid")
		if clamped_val == 50.0:
			_record_test_result("值在范围内", true, "50.0 → 50.0")
		else:
			_record_test_result("值在范围内", false, "期望: 50.0, 实际: %s" % str(clamped_val))
	else:
		_record_test_result("值在范围内", false)

## 测试变量值
func _test_variable_value():
	print("\n--- 测试变量值 ---")

	var instruction = ClampValue.new()
	instruction.log_level = FuseLogger.LogLevel.DEBUG
	instruction.value_source = ClampValue.ValueSource.VARIABLE
	instruction.value_variable = "input_value"
	instruction.min_value = 10.0
	instruction.max_value = 90.0
	instruction.save_to_variable = "test_clamp_var"
	instruction.is_global = false

	var context = ExecutionContext.new()
	context.set_variable("input_value", 120.0)

	var execution_result = {"executed": false}
	instruction.finished.connect(func(): execution_result.executed = true)
	instruction.execute(context)

	await get_tree().create_timer(0.1).timeout

	if execution_result.executed and context.has_variable("test_clamp_var"):
		var clamped_val = context.get_variable("test_clamp_var")
		if clamped_val == 90.0:
			_record_test_result("变量值限制", true, "120.0 → 90.0")
		else:
			_record_test_result("变量值限制", false, "期望: 90.0, 实际: %s" % str(clamped_val))
	else:
		_record_test_result("变量值限制", false)

## 测试边界值
func _test_boundary_values():
	print("\n--- 测试边界值 ---")

	var instruction = ClampValue.new()
	instruction.log_level = FuseLogger.LogLevel.DEBUG
	instruction.value_source = ClampValue.ValueSource.DIRECT
	instruction.min_value = 0.0
	instruction.max_value = 100.0
	instruction.is_global = false

	# 测试1: 等于最小值
	instruction.value = 0.0
	instruction.save_to_variable = "test_boundary_min"

	var context = ExecutionContext.new()
	var execution_result = {"executed": false}
	instruction.finished.connect(func(): execution_result.executed = true)
	instruction.execute(context)

	await get_tree().create_timer(0.1).timeout

	if context.has_variable("test_boundary_min"):
		var val = context.get_variable("test_boundary_min")
		if val == 0.0:
			_record_test_result("边界值（最小值）", true)
		else:
			_record_test_result("边界值（最小值）", false)
	else:
		_record_test_result("边界值（最小值）", false)

	# 测试2: 等于最大值
	instruction.value = 100.0
	instruction.save_to_variable = "test_boundary_max"

	context = ExecutionContext.new()
	execution_result = {"executed": false}
	instruction.finished.connect(func(): execution_result.executed = true)
	instruction.execute(context)

	await get_tree().create_timer(0.1).timeout

	if context.has_variable("test_boundary_max"):
		var val = context.get_variable("test_boundary_max")
		if val == 100.0:
			_record_test_result("边界值（最大值）", true)
		else:
			_record_test_result("边界值（最大值）", false)
	else:
		_record_test_result("边界值（最大值）", false)

## 测试验证
func _test_validation():
	print("\n--- 测试验证 ---")

	# 测试1: 最小值 > 最大值
	var instruction = ClampValue.new()
	instruction.log_level = FuseLogger.LogLevel.DEBUG
	instruction.value_source = ClampValue.ValueSource.DIRECT
	instruction.min_value = 100.0
	instruction.max_value = 50.0
	instruction.save_to_variable = "test_var"

	var errors = instruction.validate()
	if errors.size() > 0:
		_record_test_result("范围验证（最小值 > 最大值）", true)
	else:
		_record_test_result("范围验证（最小值 > 最大值）", false)

	# 测试2: 空变量名
	instruction.min_value = 0.0
	instruction.max_value = 100.0
	instruction.save_to_variable = ""

	errors = instruction.validate()
	if errors.size() > 0:
		_record_test_result("变量名验证（空变量名）", true)
	else:
		_record_test_result("变量名验证（空变量名）", false)

	# 测试3: 变量来源但变量名为空
	instruction.value_source = ClampValue.ValueSource.VARIABLE
	instruction.value_variable = ""
	instruction.save_to_variable = "test_var"

	errors = instruction.validate()
	if errors.size() > 0:
		_record_test_result("变量来源验证（空变量名）", true)
	else:
		_record_test_result("变量来源验证（空变量名）", false)

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
