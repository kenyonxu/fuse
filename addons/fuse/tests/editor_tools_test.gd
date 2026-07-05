@tool
extends Node
class_name EditorToolsTest

## 编辑器工具测试
##
## 测试静态分析工具和调试可视化工具的功能

# 预加载模拟指令类
const MockNormalInstruction = preload("res://addons/fuse/tests/mock_instructions/mock_normal_instruction.gd")
const MockVariableInstruction = preload("res://addons/fuse/tests/mock_instructions/mock_variable_instruction.gd")
const MockUseVariableInstruction = preload("res://addons/fuse/tests/mock_instructions/mock_use_variable_instruction.gd")
const MockJumpInstruction = preload("res://addons/fuse/tests/mock_instructions/mock_jump_instruction.gd")
const MockFileOperationInstruction = preload("res://addons/fuse/tests/mock_instructions/mock_file_operation_instruction.gd")
const MockHeavyOperationInstruction = preload("res://addons/fuse/tests/mock_instructions/mock_heavy_operation_instruction.gd")

var instruction_validator: InstructionValidator
var execution_tracker: ExecutionTracker
var static_analysis_panel: StaticAnalysisPanel
var debug_visualizer: DebugVisualizer
var test_results: Dictionary = {}

func _ready():
	print("开始编辑器工具测试...")
	_setup_test_environment()
	_run_static_analysis_tests()
	_run_debugging_tests()
	_display_test_results()

## 设置测试环境
func _setup_test_environment():
	# 创建测试用的指令
	instruction_validator = InstructionValidator.new()
	execution_tracker = ExecutionTracker.new()
	static_analysis_panel = StaticAnalysisPanel.new()
	debug_visualizer = DebugVisualizer.new()
	
	test_results = {
		"static_analysis": {"passed": 0, "failed": 0, "total": 0},
		"debugging": {"passed": 0, "failed": 0, "total": 0},
		"integration": {"passed": 0, "failed": 0, "total": 0}
	}
	
	print("测试环境设置完成")

## 运行静态分析测试
func _run_static_analysis_tests():
	print("\n=== 静态分析工具测试 ===")
	
	# 测试1: 验证空指令序列
	var test1_result = _test_empty_instruction_sequence()
	_record_test_result("static_analysis", "空指令序列验证", test1_result)
	
	# 测试2: 验证变量引用
	var test2_result = _test_variable_reference_validation()
	_record_test_result("static_analysis", "变量引用验证", test2_result)
	
	# 测试3: 检测潜在死循环
	var test3_result = _test_loop_detection()
	_record_test_result("static_analysis", "死循环检测", test3_result)
	
	# 测试4: 性能问题分析
	var test4_result = _test_performance_analysis()
	_record_test_result("static_analysis", "性能问题分析", test4_result)
	
	print("静态分析测试完成")

## 测试空指令序列
func _test_empty_instruction_sequence() -> bool:
	var empty_instructions: Array[BaseInstruction] = []
	var result = instruction_validator.validate_instruction_sequence(empty_instructions)
	
	if not result:
		print("❌ 空指令序列测试失败: 没有返回结果")
		return false
	
	if not result.valid:
		print("❌ 空指令序列测试失败: 验证未通过")
		return false
	
	if result.errors.size() > 0:
		print("❌ 空指令序列测试失败: 出现错误")
		return false
	
	print("✅ 空指令序列测试通过")
	return true

## 测试变量引用验证
func _test_variable_reference_validation() -> bool:
	# 创建模拟指令
	var mock_instructions = _create_mock_instructions_with_variable_issues()
	var result = instruction_validator.validate_instruction_sequence(mock_instructions)
	
	if not result:
		print("❌ 变量引用测试失败: 没有返回结果")
		return false
	
	# 应该检测到未定义变量的使用
	var has_undefined_variable_error = false
	for error in result.errors:
		if "未定义" in error:
			has_undefined_variable_error = true
			break
	
	if not has_undefined_variable_error:
		print("❌ 变量引用测试失败: 未检测到未定义变量错误")
		return false
	
	print("✅ 变量引用测试通过")
	return true

## 测试死循环检测
func _test_loop_detection() -> bool:
	# 创建模拟的跳转指令
	var mock_instructions = _create_mock_instructions_with_loops()
	var result = instruction_validator.validate_instruction_sequence(mock_instructions)
	
	if not result:
		print("❌ 死循环检测测试失败: 没有返回结果")
		return false
	
	# 应该检测到潜在的循环
	var has_loop_warning = false
	for warning in result.warnings:
		if "循环" in warning:
			has_loop_warning = true
			break
	
	if not has_loop_warning:
		print("❌ 死循环检测测试失败: 未检测到循环警告")
		return false
	
	print("✅ 死循环检测测试通过")
	return true

## 测试性能问题分析
func _test_performance_analysis() -> bool:
	# 创建模拟的高频操作指令
	var mock_instructions = _create_mock_instructions_with_performance_issues()
	var result = instruction_validator.validate_instruction_sequence(mock_instructions)
	
	if not result:
		print("❌ 性能分析测试失败: 没有返回结果")
		return false
	
	# 应该提供性能优化建议
	if result.suggestions.size() == 0:
		print("❌ 性能分析测试失败: 没有提供优化建议")
		return false
	
	print("✅ 性能分析测试通过")
	return true

## 运行调试测试
func _run_debugging_tests():
	print("\n=== 调试工具测试 ===")
	
	# 测试1: 执行跟踪基本功能
	var test1_result = _test_execution_tracking()
	_record_test_result("debugging", "执行跟踪基本功能", test1_result)
	
	# 测试2: 历史记录管理
	var test2_result = _test_history_management()
	_record_test_result("debugging", "历史记录管理", test2_result)
	
	# 测试3: 性能指标收集
	var test3_result = _test_performance_metrics()
	_record_test_result("debugging", "性能指标收集", test3_result)
	
	# 测试4: 导出功能
	var test4_result = _test_export_functionality()
	_record_test_result("debugging", "导出功能", test4_result)
	
	print("调试测试完成")

## 测试执行跟踪
func _test_execution_tracking() -> bool:
	# 开始跟踪
	var mock_context = ExecutionContext.new()
	execution_tracker.start_tracking(mock_context)
	
	if not execution_tracker.is_tracking:
		print("❌ 执行跟踪测试失败: 跟踪未启动")
		return false
	
	# 模拟指令执行
	var mock_instruction = _create_mock_instruction()
	execution_tracker.record_instruction_start(mock_instruction, mock_context)
	
	# 模拟指令完成
	execution_tracker.record_instruction_complete(mock_instruction, mock_context)
	
	# 停止跟踪
	execution_tracker.stop_tracking()
	
	if execution_tracker.is_tracking:
		print("❌ 执行跟踪测试失败: 跟踪未停止")
		return false
	
	# 检查历史记录
	var history = execution_tracker.get_execution_history()
	if history.size() == 0:
		print("❌ 执行跟踪测试失败: 没有历史记录")
		return false
	
	print("✅ 执行跟踪测试通过")
	return true

## 测试历史记录管理
func _test_history_management() -> bool:
	# 清除历史记录
	execution_tracker.clear_execution_history()
	
	var history = execution_tracker.get_execution_history()
	if history.size() > 0:
		print("❌ 历史记录管理测试失败: 清除功能异常")
		return false
	
	# 添加一些历史记录
	for i in range(3):
		var mock_context = ExecutionContext.new()
		execution_tracker.start_tracking(mock_context)
		execution_tracker.stop_tracking()
	
	history = execution_tracker.get_execution_history()
	if history.size() != 3:
		print("❌ 历史记录管理测试失败: 历史记录数量不正确")
		return false
	
	print("✅ 历史记录管理测试通过")
	return true

## 测试性能指标收集
func _test_performance_metrics() -> bool:
	var mock_context = ExecutionContext.new()
	execution_tracker.start_tracking(mock_context)
	
	# 记录一些性能数据
	execution_tracker.record_performance_bottleneck("memory_usage", "medium", {"usage": 100})
	
	execution_tracker.stop_tracking()
	
	var stats = execution_tracker.get_execution_stats()
	if not stats or stats.has("error"):
		print("❌ 性能指标测试失败: 无法获取统计信息")
		return false
	
	print("✅ 性能指标测试通过")
	return true

## 测试导出功能
func _test_export_functionality() -> bool:
	var file_path = "user://test_execution_history.json"
	
	# 创建一些历史记录
	var mock_context = ExecutionContext.new()
	execution_tracker.start_tracking(mock_context)
	execution_tracker.stop_tracking()
	
	# 尝试导出
	var export_result = execution_tracker.export_execution_history(file_path)
	
	if not export_result:
		print("❌ 导出功能测试失败: 导出失败")
		return false
	
	# 检查文件是否存在
	if not FileAccess.file_exists(file_path):
		print("❌ 导出功能测试失败: 文件未创建")
		return false
	
	print("✅ 导出功能测试通过")
	return true

## 运行集成测试
func _run_integration_tests():
	print("\n=== 集成测试 ===")
	
	# 测试1: ActionRunner调试集成
	var test1_result = _test_action_runner_debug_integration()
	_record_test_result("integration", "ActionRunner调试集成", test1_result)
	
	# 测试2: 面板功能测试
	var test2_result = _test_panel_functionality()
	_record_test_result("integration", "面板功能测试", test2_result)
	
	print("集成测试完成")

## 测试ActionRunner调试集成
func _test_action_runner_debug_integration() -> bool:
	var action_runner = ActionRunner.new()
	
	# 启用调试
	action_runner.enable_debug()
	
	if not action_runner.is_debug_enabled():
		print("❌ ActionRunner调试集成测试失败: 调试模式未启用")
		return false
	
	if not action_runner.get_execution_tracker():
		print("❌ ActionRunner调试集成测试失败: 执行跟踪器未创建")
		return false
	
	# 禁用调试
	action_runner.disable_debug()
	
	if action_runner.is_debug_enabled():
		print("❌ ActionRunner调试集成测试失败: 调试模式未禁用")
		return false
	
	print("✅ ActionRunner调试集成测试通过")
	return true

## 测试面板功能
func _test_panel_functionality() -> bool:
	# 测试静态分析面板
	var analysis_info = static_analysis_panel.get_panel_info()
	if not analysis_info or not analysis_info.has("is_analyzing"):
		print("❌ 面板功能测试失败: 静态分析面板信息异常")
		return false
	
	# 测试调试可视化面板
	var debug_info = debug_visualizer.get_panel_info()
	if not debug_info or not debug_info.has("execution_count"):
		print("❌ 面板功能测试失败: 调试可视化面板信息异常")
		return false
	
	print("✅ 面板功能测试通过")
	return true

## 创建模拟指令（带变量问题）
func _create_mock_instructions_with_variable_issues() -> Array[BaseInstruction]:
	var instructions: Array[BaseInstruction] = []
	
	# 创建一个定义变量的指令
	var define_instruction = MockVariableInstruction.new("test_var", 42)
	instructions.append(define_instruction)
	
	# 创建一个使用未定义变量的指令
	var use_undefined_instruction = MockUseVariableInstruction.new("undefined_var")
	instructions.append(use_undefined_instruction)
	
	return instructions

## 创建模拟指令（带循环）
func _create_mock_instructions_with_loops() -> Array[BaseInstruction]:
	var instructions: Array[BaseInstruction] = []
	
	# 创建一些普通指令
	for i in range(3):
		var normal_instruction = MockNormalInstruction.new("指令_%d" % i)
		instructions.append(normal_instruction)
	
	# 创建一个跳转指令，跳转到更早的指令
	var jump_instruction = MockJumpInstruction.new(1)  # 跳转到索引1
	instructions.append(jump_instruction)
	
	return instructions

## 创建模拟指令（带性能问题）
func _create_mock_instructions_with_performance_issues() -> Array[BaseInstruction]:
	var instructions: Array[BaseInstruction] = []
	
	# 创建大量相同类型的指令（高频操作）
	for i in range(15):
		var file_instruction = MockFileOperationInstruction.new("文件操作_%d" % i)
		instructions.append(file_instruction)
	
	# 创建一个资源密集型指令
	var heavy_instruction = MockHeavyOperationInstruction.new("大型数据处理")
	instructions.append(heavy_instruction)
	
	return instructions

## 创建基础模拟指令
func _create_mock_instruction() -> BaseInstruction:
	return MockNormalInstruction.new("测试指令")

## 记录测试结果
func _record_test_result(category: String, test_name: String, passed: bool):
	test_results[category].total += 1
	
	if passed:
		test_results[category].passed += 1
	else:
		test_results[category].failed += 1
	
	var status = "✅ 通过" if passed else "❌ 失败"
	print("%s - %s" % [status, test_name])

## 显示测试结果
func _display_test_results():
	print("\n=== 测试结果汇总 ===")
	
	var total_passed = 0
	var total_failed = 0
	var total_tests = 0
	
	for category in test_results:
		var category_results = test_results[category]
		total_passed += category_results.passed
		total_failed += category_results.failed
		total_tests += category_results.total
		
		print("\n%s:" % category)
		print("  通过: %d" % category_results.passed)
		print("  失败: %d" % category_results.failed)
		print("  总计: %d" % category_results.total)
		print("  通过率: %.1f%%" % (category_results.passed * 100.0 / category_results.total if category_results.total > 0 else 0))
	
	print("\n总体结果:")
	print("  通过: %d" % total_passed)
	print("  失败: %d" % total_failed)
	print("  总计: %d" % total_tests)
	print("  通过率: %.1f%%" % (total_passed * 100.0 / total_tests if total_tests > 0 else 0))
	
	if total_failed == 0:
		print("\n🎉 所有测试通过！编辑器工具功能正常。")
	else:
		print("\n⚠️  部分测试失败，请检查相关功能。")

## 获取测试结果
func get_test_results() -> Dictionary:
	return test_results.duplicate()