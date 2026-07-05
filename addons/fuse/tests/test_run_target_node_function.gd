extends Node

## RunTargetNodeFunction 指令测试脚本
## 用于验证新指令的功能和正确性

var test_results: Array[String] = []
var test_passed: int = 0
var test_failed: int = 0

# 测试用的目标节点
var test_node: Node = null
var test_sprite: Sprite2D = null

func _ready():
	print("=== RunTargetNodeFunction 指令测试开始 ===")
	
	# 创建测试节点
	_setup_test_nodes()
	
	# 运行测试
	_run_all_tests()
	
	# 显示测试结果
	_show_test_results()
	
	print("=== RunTargetNodeFunction 指令测试完成 ===")

## 设置测试节点
func _setup_test_nodes():
	# 创建测试节点
	test_node = Node.new()
	test_node.name = "TestNode"
	add_child(test_node)
	
	# 创建 Sprite2D 用于测试可见性等方法
	test_sprite = Sprite2D.new()
	test_sprite.name = "TestSprite"
	test_node.add_child(test_sprite)
	
	print("测试节点已创建: %s, %s" % [test_node.name, test_sprite.name])

## 运行所有测试
func _run_all_tests():
	# 基础功能测试
	_test_basic_functionality()
	
	# 参数处理测试
	_test_parameter_handling()
	
	# 返回值处理测试
	_test_return_value_handling()
	
	# 错误处理测试
	_test_error_handling()
	
	# 性能测试
	_test_performance()

## 测试基础功能
func _test_basic_functionality():
	print("\n--- 测试基础功能 ---")
	
	# 测试1: 创建指令实例
	var instruction = RunTargetNodeFunction.new()
	instruction.log_level = FuseLogger.LogLevel.DEBUG
	if instruction:
		_record_test_result("创建指令实例", true)
	else:
		_record_test_result("创建指令实例", false)
		return
	
	# 测试2: 设置目标节点
	instruction.target_node = get_node_path(test_node)
	if instruction.target_node == get_node_path(test_node):
		_record_test_result("设置目标节点", true)
	else:
		_record_test_result("设置目标节点", false)
	
	# 测试3: 获取可用方法
	var methods = FunctionManager.get_callable_methods(test_node)
	if methods.size() > 0:
		_record_test_result("获取可用方法", true)
		print("找到 %d 个可用方法" % methods.size())
	else:
		_record_test_result("获取可用方法", false)
	
	# 测试4: 设置目标函数
	if methods.size() > 0:
		var first_method = methods[0]
		var method_name = first_method.get("name", "")
		if not method_name.is_empty():
			instruction.target_function = method_name
			if instruction.target_function == method_name:
				_record_test_result("设置目标函数", true)
			else:
				_record_test_result("设置目标函数", false)
		else:
			_record_test_result("设置目标函数", false)
	
	# 测试5: 执行简单函数调用
	_test_simple_function_call(instruction)

## 测试简单函数调用
func _test_simple_function_call(instruction):
	print("测试简单函数调用...")
	
	# 创建一个简单的测试上下文
	var context = ExecutionContext.new()
	
	# 设置调用 show() 方法（如果存在）
	var methods = FunctionManager.get_callable_methods(test_node)
	for method in methods:
		var method_name = method.get("name", "")
		if method_name == "show":
			instruction.target_function = "show"
			instruction.function_args = []
			
			# 执行指令
			var execution_result = {"executed": false}
			instruction.finished.connect(func(): execution_result.executed = true)
			instruction.execute(context)
			
			# 等待执行完成
			await get_tree().create_timer(0.1).timeout
			
			if execution_result.executed:
				_record_test_result("执行简单函数调用", true)
			else:
				_record_test_result("执行简单函数调用", false)
			return
	
	_record_test_result("执行简单函数调用", false, "未找到合适的测试方法")

## 测试参数处理
func _test_parameter_handling():
	print("\n--- 测试参数处理 ---")
	
	# 测试带参数的函数调用
	var instruction = RunTargetNodeFunction.new()
	instruction.log_level = FuseLogger.LogLevel.DEBUG
	instruction.target_node = get_node_path(test_sprite)
	
	# 尝试调用 set_visible 方法
	var methods = FunctionManager.get_callable_methods(test_sprite)
	for method in methods:
		var method_name = method.get("name", "")
		if method_name == "set_visible":
			instruction.target_function = "set_visible"
			instruction.function_args = [true]  # 设置为可见
			
			# 验证参数
			var function_info = FunctionInfo.new(method)
			if function_info.validate_arguments(instruction.function_args):
				_record_test_result("参数验证", true)
			else:
				_record_test_result("参数验证", false)
			
			# 执行调用
			var context = ExecutionContext.new()
			var execution_result = {"executed": false}
			instruction.finished.connect(func(): execution_result.executed = true)
			instruction.execute(context)
			
			await get_tree().create_timer(0.1).timeout
			
			if execution_result.executed and test_sprite.visible:
				_record_test_result("带参数函数调用", true)
			else:
				_record_test_result("带参数函数调用", false)
			return
	
	_record_test_result("参数处理测试", false, "未找到 set_visible 方法")

## 测试返回值处理
func _test_return_value_handling():
	print("\n--- 测试返回值处理 ---")
	
	var instruction = RunTargetNodeFunction.new()
	instruction.log_level = FuseLogger.LogLevel.DEBUG
	instruction.target_node = get_node_path(test_sprite)
	
	# 尝试调用 is_visible 方法
	var methods = FunctionManager.get_callable_methods(test_sprite)
	for method in methods:
		var method_name = method.get("name", "")
		if method_name == "is_visible":
			instruction.target_function = "is_visible"
			instruction.function_args = []
			instruction.store_result = true
			instruction.result_variable_name = "visibility_result"
			instruction.result_variable_scope = BaseVariable.VariableScope.LOCAL
			
			# 执行调用
			var context = ExecutionContext.new()
			var execution_result = {"executed": false}
			instruction.finished.connect(func(): execution_result.executed = true)
			instruction.execute(context)
			
			await get_tree().create_timer(0.1).timeout
			
			if execution_result.executed:
				# 检查变量是否被创建
				var result_var = context.get_variable("visibility_result", null)
				if result_var and result_var.has_value():
					_record_test_result("返回值存储", true)
					print("返回值: %s" % str(result_var.get_value()))
				else:
					_record_test_result("返回值存储", false)
			else:
				_record_test_result("返回值存储", false)
			return
	
	_record_test_result("返回值处理测试", false, "未找到 is_visible 方法")

## 测试错误处理
func _test_error_handling():
	print("\n--- 测试错误处理 ---")
	
	# 测试1: 无效节点路径
	var instruction = RunTargetNodeFunction.new()
	instruction.log_level = FuseLogger.LogLevel.DEBUG
	instruction.target_node = NodePath("/NonExistent/Node")
	instruction.target_function = "some_method"
	
	var context = ExecutionContext.new()
	var error_result = {"error_occurred": false}
	instruction.finished.connect(func():
		if instruction.has_error():
			error_result.error_occurred = true
	)
	
	instruction.execute(context)
	await get_tree().create_timer(0.1).timeout
	
	if error_result.error_occurred:
		_record_test_result("无效节点路径错误处理", true)
	else:
		_record_test_result("无效节点路径错误处理", false)
	
	# 测试2: 无效方法名
	instruction = RunTargetNodeFunction.new()
	instruction.log_level = FuseLogger.LogLevel.DEBUG
	instruction.target_node = get_node_path(test_node)
	instruction.target_function = "non_existent_method"
	
	var error_result2 = {"error_occurred": false}
	instruction.finished.connect(func():
		if instruction.has_error():
			error_result2.error_occurred = true
	)
	
	instruction.execute(context)
	await get_tree().create_timer(0.1).timeout
	
	if error_result2.error_occurred:
		_record_test_result("无效方法名错误处理", true)
	else:
		_record_test_result("无效方法名错误处理", false)

## 测试性能
func _test_performance():
	print("\n--- 测试性能 ---")
	
	var start_time = Time.get_ticks_msec()
	
	# 测试方法发现性能
	for i in range(100):
		var _methods = FunctionManager.get_callable_methods(test_node)
	
	var discovery_time = Time.get_ticks_msec() - start_time
	_record_test_result("方法发现性能", discovery_time < 100, "耗时: %d ms" % discovery_time)
	
	# 测试方法调用性能
	start_time = Time.get_ticks_msec()
	var instruction = RunTargetNodeFunction.new()
	instruction.log_level = FuseLogger.LogLevel.DEBUG
	instruction.target_node = get_node_path(test_node)
	instruction.target_function = "get_name"
	instruction.function_args = []
	
	var context = ExecutionContext.new()
	for i in range(50):
		instruction.execute(context)
		await get_tree().create_timer(0.01).timeout
	
	var call_time = Time.get_ticks_msec() - start_time
	_record_test_result("方法调用性能", call_time < 500, "耗时: %d ms" % call_time)

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

## 获取节点路径
func get_node_path(node: Node) -> NodePath:
	if not node or not is_instance_valid(node):
		return NodePath("")
	
	# 获取相对于当前节点的路径
	return get_path_to(node)

## 清理测试资源
func _exit_tree():
	if test_node and is_instance_valid(test_node):
		test_node.queue_free()
		print("测试节点已清理")