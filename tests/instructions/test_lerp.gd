extends Node

## Lerp 指令测试脚本

var test_results: Array[String] = []
var test_passed: int = 0
var test_failed: int = 0

func _ready():
	print("=== Lerp 指令测试开始 ===")

	# 运行测试
	_run_all_tests()

	# 显示测试结果
	_show_test_results()

	print("=== Lerp 指令测试完成 ===")

## 运行所有测试
func _run_all_tests():
	# 基础功能测试
	_test_basic_functionality()

	# 直接值测试
	_test_direct_values()

	# 变量值测试
	_test_variable_values()

	# 权重测试
	_test_weight_values()

	# 边界测试
	_test_boundary_weights()

	# 验证测试
	_test_validation()

## 测试基础功能
func _test_basic_functionality():
	print("\n--- 测试基础功能 ---")

	# 测试1: 创建指令实例
	var instruction = Lerp.new()
	instruction.log_level = FuseLogger.LogLevel.DEBUG
	if instruction:
		_record_test_result("创建指令实例", true)
	else:
		_record_test_result("创建指令实例", false)
		return

	# 测试2: 设置参数
	instruction.from_source = Lerp.FromSource.DIRECT
	instruction.from_value = 0.0
	instruction.to_source = Lerp.ToSource.DIRECT
	instruction.to_value = 100.0
	instruction.weight_source = Lerp.WeightSource.DIRECT
	instruction.weight = 0.5
	instruction.save_to_variable = "test_lerp"
	instruction.is_global = false

	if instruction.from_value == 0.0 and instruction.to_value == 100.0:
		_record_test_result("设置参数", true)
	else:
		_record_test_result("设置参数", false)

## 测试直接值
func _test_direct_values():
	print("\n--- 测试直接值 ---")

	# 测试1: 标准插值 (0.5)
	var instruction = Lerp.new()
	instruction.log_level = FuseLogger.LogLevel.DEBUG
	instruction.from_source = Lerp.FromSource.DIRECT
	instruction.from_value = 0.0
	instruction.to_source = Lerp.ToSource.DIRECT
	instruction.to_value = 100.0
	instruction.weight_source = Lerp.WeightSource.DIRECT
	instruction.weight = 0.5
	instruction.save_to_variable = "test_lerp_mid"
	instruction.is_global = false

	var context = ExecutionContext.new()
	var execution_result = {"executed": false}
	instruction.finished.connect(func(): execution_result.executed = true)
	instruction.execute(context)

	await get_tree().create_timer(0.1).timeout

	if execution_result.executed and context.has_variable("test_lerp_mid"):
		var lerped_val = context.get_variable("test_lerp_mid")
		# lerp(0, 100, 0.5) = 50.0
		if is_equal_approx(lerped_val, 50.0):
			_record_test_result("中点插值", true, "lerp(0, 100, 0.5) = 50.0")
		else:
			_record_test_result("中点插值", false, "期望: 50.0, 实际: %s" % str(lerped_val))
	else:
		_record_test_result("中点插值", false)

	# 测试2: 起始点 (weight = 0.0)
	instruction.weight = 0.0
	instruction.save_to_variable = "test_lerp_start"

	context = ExecutionContext.new()
	execution_result = {"executed": false}
	instruction.finished.connect(func(): execution_result.executed = true)
	instruction.execute(context)

	await get_tree().create_timer(0.1).timeout

	if context.has_variable("test_lerp_start"):
		var lerped_val = context.get_variable("test_lerp_start")
		if is_equal_approx(lerped_val, 0.0):
			_record_test_result("起始点插值", true, "lerp(0, 100, 0.0) = 0.0")
		else:
			_record_test_result("起始点插值", false, "期望: 0.0, 实际: %s" % str(lerped_val))
	else:
		_record_test_result("起始点插值", false)

	# 测试3: 终点 (weight = 1.0)
	instruction.weight = 1.0
	instruction.save_to_variable = "test_lerp_end"

	context = ExecutionContext.new()
	execution_result = {"executed": false}
	instruction.finished.connect(func(): execution_result.executed = true)
	instruction.execute(context)

	await get_tree().create_timer(0.1).timeout

	if context.has_variable("test_lerp_end"):
		var lerped_val = context.get_variable("test_lerp_end")
		if is_equal_approx(lerped_val, 100.0):
			_record_test_result("终点插值", true, "lerp(0, 100, 1.0) = 100.0")
		else:
			_record_test_result("终点插值", false, "期望: 100.0, 实际: %s" % str(lerped_val))
	else:
		_record_test_result("终点插值", false)

## 测试变量值
func _test_variable_values():
	print("\n--- 测试变量值 ---")

	var instruction = Lerp.new()
	instruction.log_level = FuseLogger.LogLevel.DEBUG
	instruction.from_source = Lerp.FromSource.VARIABLE
	instruction.from_variable = "var_from"
	instruction.to_source = Lerp.ToSource.VARIABLE
	instruction.to_variable = "var_to"
	instruction.weight_source = Lerp.WeightSource.DIRECT
	instruction.weight = 0.5
	instruction.save_to_variable = "test_lerp_vars"
	instruction.is_global = false

	var context = ExecutionContext.new()
	context.set_variable("var_from", 10.0)
	context.set_variable("var_to", 30.0)

	var execution_result = {"executed": false}
	instruction.finished.connect(func(): execution_result.executed = true)
	instruction.execute(context)

	await get_tree().create_timer(0.1).timeout

	if execution_result.executed and context.has_variable("test_lerp_vars"):
		var lerped_val = context.get_variable("test_lerp_vars")
		# lerp(10, 30, 0.5) = 20.0
		if is_equal_approx(lerped_val, 20.0):
			_record_test_result("变量值插值", true, "lerp(10, 30, 0.5) = 20.0")
		else:
			_record_test_result("变量值插值", false, "期望: 20.0, 实际: %s" % str(lerped_val))
	else:
		_record_test_result("变量值插值", false)

## 测试权重值
func _test_weight_values():
	print("\n--- 测试权重值 ---")

	var instruction = Lerp.new()
	instruction.log_level = FuseLogger.LogLevel.DEBUG
	instruction.from_source = Lerp.FromSource.DIRECT
	instruction.from_value = 0.0
	instruction.to_source = Lerp.ToSource.DIRECT
	instruction.to_value = 100.0
	instruction.weight_source = Lerp.WeightSource.VARIABLE
	instruction.weight_variable = "var_weight"
	instruction.save_to_variable = "test_lerp_weight"
	instruction.is_global = false

	var context = ExecutionContext.new()
	context.set_variable("var_weight", 0.25)

	var execution_result = {"executed": false}
	instruction.finished.connect(func(): execution_result.executed = true)
	instruction.execute(context)

	await get_tree().create_timer(0.1).timeout

	if execution_result.executed and context.has_variable("test_lerp_weight"):
		var lerped_val = context.get_variable("test_lerp_weight")
		# lerp(0, 100, 0.25) = 25.0
		if is_equal_approx(lerped_val, 25.0):
			_record_test_result("变量权重插值", true, "lerp(0, 100, 0.25) = 25.0")
		else:
			_record_test_result("变量权重插值", false, "期望: 25.0, 实际: %s" % str(lerped_val))
	else:
		_record_test_result("变量权重插值", false)

## 测试边界权重
func _test_boundary_weights():
	print("\n--- 测试边界权重 ---")

	var instruction = Lerp.new()
	instruction.log_level = FuseLogger.LogLevel.DEBUG
	instruction.from_source = Lerp.FromSource.DIRECT
	instruction.from_value = -50.0
	instruction.to_source = Lerp.ToSource.DIRECT
	instruction.to_value = 50.0
	instruction.weight_source = Lerp.WeightSource.DIRECT
	instruction.is_global = false

	# 测试1: 权重 < 0 (应该在 Godot 的 lerp 中正常处理)
	instruction.weight = -0.5
	instruction.save_to_variable = "test_lerp_neg_weight"

	var context = ExecutionContext.new()
	var execution_result = {"executed": false}
	instruction.finished.connect(func(): execution_result.executed = true)
	instruction.execute(context)

	await get_tree().create_timer(0.1).timeout

	if context.has_variable("test_lerp_neg_weight"):
		_record_test_result("负权重", true)
	else:
		_record_test_result("负权重", false)

	# 测试2: 权重 > 1 (应该在 Godot 的 lerp 中正常处理)
	instruction.weight = 1.5
	instruction.save_to_variable = "test_lerp_over_weight"

	context = ExecutionContext.new()
	execution_result = {"executed": false}
	instruction.finished.connect(func(): execution_result.executed = true)
	instruction.execute(context)

	await get_tree().create_timer(0.1).timeout

	if context.has_variable("test_lerp_over_weight"):
		_record_test_result("超范围权重", true)
	else:
		_record_test_result("超范围权重", false)

## 测试验证
func _test_validation():
	print("\n--- 测试验证 ---")

	# 测试1: 空变量名
	var instruction = Lerp.new()
	instruction.log_level = FuseLogger.LogLevel.DEBUG
	instruction.from_source = Lerp.FromSource.DIRECT
	instruction.from_value = 0.0
	instruction.to_source = Lerp.ToSource.DIRECT
	instruction.to_value = 100.0
	instruction.weight_source = Lerp.WeightSource.DIRECT
	instruction.weight = 0.5
	instruction.save_to_variable = ""

	var errors = instruction.validate()
	if errors.size() > 0:
		_record_test_result("变量名验证（空变量名）", true)
	else:
		_record_test_result("变量名验证（空变量名）", false)

	# 测试2: From 变量来源但变量名为空
	instruction.save_to_variable = "test_var"
	instruction.from_source = Lerp.FromSource.VARIABLE
	instruction.from_variable = ""

	errors = instruction.validate()
	if errors.size() > 0:
		_record_test_result("From 变量验证", true)
	else:
		_record_test_result("From 变量验证", false)

	# 测试3: To 变量来源但变量名为空
	instruction.from_source = Lerp.FromSource.DIRECT
	instruction.to_source = Lerp.ToSource.VARIABLE
	instruction.to_variable = ""

	errors = instruction.validate()
	if errors.size() > 0:
		_record_test_result("To 变量验证", true)
	else:
		_record_test_result("To 变量验证", false)

	# 测试4: Weight 变量来源但变量名为空
	instruction.to_source = Lerp.ToSource.DIRECT
	instruction.weight_source = Lerp.WeightSource.VARIABLE
	instruction.weight_variable = ""

	errors = instruction.validate()
	if errors.size() > 0:
		_record_test_result("Weight 变量验证", true)
	else:
		_record_test_result("Weight 变量验证", false)

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
