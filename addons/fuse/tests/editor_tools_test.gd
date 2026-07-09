@tool
extends Node
class_name EditorToolsTest

## 编辑器工具测试
##
## 测试调试可视化工具的功能

var execution_tracker: ExecutionTracker
var debug_visualizer: DebugVisualizer
var test_results: Dictionary = {}

func _ready():
	print("开始编辑器工具测试...")
	_setup_test_environment()
	_run_debugging_tests()
	_display_test_results()

## 设置测试环境
func _setup_test_environment():
	# 创建测试用的指令
	execution_tracker = ExecutionTracker.new()
	debug_visualizer = DebugVisualizer.new()

	test_results = {
		"debugging": {"passed": 0, "failed": 0, "total": 0}
	}
	
	print("测试环境设置完成")

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