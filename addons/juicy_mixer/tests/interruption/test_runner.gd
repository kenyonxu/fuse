extends SceneTree
# 中断系统测试运行器
# 运行所有中断系统测试并生成报告

const TEST_FILES = [
	# 单元测试
	"res://addons/juicy_mixer/tests/interruption/unit/test_interruption_state.gd",
	"res://addons/juicy_mixer/tests/interruption/unit/test_channel_interruption_config.gd", 
	"res://addons/juicy_mixer/tests/interruption/unit/test_juicy_interruption_manager.gd",
	"res://addons/juicy_mixer/tests/interruption/unit/test_interruption_middleware.gd",
	"res://addons/juicy_mixer/tests/interruption/unit/test_juicy_mixer_enums.gd",
	
	# 集成测试
	"res://addons/juicy_mixer/tests/interruption/integration/test_director_integration.gd",
	"res://addons/juicy_mixer/tests/interruption/integration/test_middleware_integration.gd"
]

var _test_results: Dictionary = {}
var _total_tests: int = 0
var _passed_tests: int = 0
var _failed_tests: int = 0
var _start_time: float = 0

func _init():
	_test_results = {}
	_total_tests = 0
	_passed_tests = 0
	_failed_tests = 0

func run_all_tests() -> Dictionary:
	"""
	运行所有中断系统测试
	@return: 测试结果字典
	"""
	print("=== 开始运行中断系统所有测试 ===")
	_start_time = Time.get_ticks_msec()
	
	for test_file in TEST_FILES:
		var result = run_single_test(test_file)
		_test_results[test_file] = result
		
		if result.success:
			_passed_tests += 1
		else:
			_failed_tests += 1
	
	var end_time = Time.get_ticks_msec()
	var total_time = (end_time - _start_time) / 1000.0
	
	return generate_test_report(total_time)

func run_single_test(test_file: String) -> Dictionary:
	"""
	运行单个测试文件
	@param test_file: 测试文件路径
	@return: 测试结果字典
	"""
	print("\n--- 运行测试: " + test_file + " ---")
	
	# 加载测试脚本
	var test_script = load(test_file)
	if not test_script:
		return {
			"success": false,
			"error": "无法加载测试文件",
			"details": test_file
		}
	
	# 创建测试实例
	var test_instance = test_script.new()
	if not test_instance or not test_instance.has_method("run_all_tests"):
		return {
			"success": false,
			"error": "测试实例无效或缺少 run_all_tests 方法",
			"details": test_file
		}
	
	# 运行测试
	var test_result = test_instance.run_all_tests()
	
	# 获取测试结果详情
	var result_details = {}
	if test_instance.has_method("get_test_results"):
		result_details = test_instance.get_test_results()
	
	# 清理测试实例
	if test_instance.has_method("cleanup"):
		test_instance.cleanup()
	
	test_instance.free()
	
	return {
		"success": test_result,
		"details": result_details,
		"test_file": test_file
	}

func generate_test_report(total_time: float) -> Dictionary:
	"""
	生成测试报告
	@param total_time: 总执行时间
	@return: 测试报告字典
	"""
	var report = {
		"summary": {
			"total_tests": len(TEST_FILES),
			"passed_tests": _passed_tests,
			"failed_tests": _failed_tests,
			"success_rate": float(_passed_tests) / len(TEST_FILES) * 100,
			"total_time": total_time,
			"timestamp": Time.get_datetime_string_from_system()
		},
		"detailed_results": _test_results,
		"coverage_analysis": analyze_test_coverage(),
		"recommendations": generate_recommendations()
	}
	
	print("\n=== 测试报告 ===")
	print("总测试数: " + str(report.summary.total_tests))
	print("通过测试: " + str(report.summary.passed_tests))
	print("失败测试: " + str(report.summary.failed_tests))
	print("成功率: " + str(report.summary.success_rate) + "%")
	print("总耗时: " + str(report.summary.total_time) + " 秒")
	
	return report

func analyze_test_coverage() -> Dictionary:
	"""
	分析测试覆盖率
	@return: 覆盖率分析字典
	"""
	var coverage = {
		"unit_tests": {
			"total": 5,
			"completed": 5,
			"coverage": "100%"
		},
		"integration_tests": {
			"total": 5,
			"completed": 2,
			"coverage": "40%"
		},
		"performance_tests": {
			"total": 5,
			"completed": 0,
			"coverage": "0%"
		},
		"end_to_end_tests": {
			"total": 4,
			"completed": 0,
			"coverage": "0%"
		}
	}
	
	return coverage

func generate_recommendations() -> Array:
	"""
	生成测试建议
	@return: 建议数组
	"""
	var recommendations = []
	
	if _failed_tests > 0:
		recommendations.append({
			"priority": "HIGH",
			"category": "测试失败",
			"description": "有 " + str(_failed_tests) + " 个测试失败，需要修复",
			"action": "检查失败的测试并修复相关问题"
		})
	
	# 检查集成测试覆盖率
	if _test_results.size() < len(TEST_FILES):
		recommendations.append({
			"priority": "MEDIUM",
			"category": "测试覆盖",
			"description": "部分测试文件未能成功运行",
			"action": "确保所有测试文件都能正确加载和执行"
		})
	
	# 检查性能测试
	var has_performance_tests = false
	for test_file in _test_results.keys():
		if "performance" in test_file.to_lower():
			has_performance_tests = true
			break
	
	if not has_performance_tests:
		recommendations.append({
			"priority": "MEDIUM",
			"category": "性能测试",
			"description": "缺少性能测试，无法验证系统性能",
			"action": "添加性能测试以验证中断系统的性能指标"
		})
	
	# 检查端到端测试
	var has_e2e_tests = false
	for test_file in _test_results.keys():
		if "end_to_end" in test_file.to_lower() or "e2e" in test_file.to_lower():
			has_e2e_tests = true
			break
	
	if not has_e2e_tests:
		recommendations.append({
			"priority": "LOW",
			"category": "端到端测试",
			"description": "缺少端到端测试，无法验证完整流程",
			"action": "添加端到端测试以验证完整的中断流程"
		})
	
	return recommendations

func print_detailed_results():
	"""
	打印详细的测试结果
	"""
	print("\n=== 详细测试结果 ===")
	
	for test_file in _test_results.keys():
		var result = _test_results[test_file]
		var status = "✓ PASSED" if result.success else "✗ FAILED"
		print(status + " - " + test_file)
		
		if not result.success and result.has("error"):
			print("  错误: " + result.error)
			print("  详情: " + str(result.details))
		
		if result.has("details") and result.details is Dictionary:
			if result.details.has("test_count"):
				print("  测试用例数: " + str(result.details.test_count))
			if result.details.has("passed_count"):
				print("  通过数: " + str(result.details.passed_count))

func save_report_to_file(report: Dictionary, file_path: String) -> bool:
	"""
	将测试报告保存到文件
	@param report: 测试报告
	@param file_path: 文件路径
	@return: 是否成功保存
	"""
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if not file:
		print("错误: 无法打开文件 " + file_path)
		return false
	
	var json_string = JSON.stringify(report, "\t")
	file.store_string(json_string)
	file.close()
	
	print("测试报告已保存到: " + file_path)
	return true

func get_test_summary() -> String:
	"""
	获取测试摘要
	@return: 测试摘要字符串
	"""
	var summary = "中断系统测试摘要:\n"
	summary += "总测试数: " + str(len(TEST_FILES)) + "\n"
	summary += "通过测试: " + str(_passed_tests) + "\n"
	summary += "失败测试: " + str(_failed_tests) + "\n"
	summary += "成功率: " + str(float(_passed_tests) / len(TEST_FILES) * 100) + "%\n"
	
	if _failed_tests > 0:
		summary += "\n失败的测试:\n"
		for test_file in _test_results.keys():
			var result = _test_results[test_file]
			if not result.success:
				summary += "- " + test_file + ": " + result.get("error", "未知错误") + "\n"
	
	return summary

# 主执行函数
func run_tests():
	var report = run_all_tests()
	print_detailed_results()
	
	# 保存报告到文件
	var timestamp = Time.get_time_string_from_system().replace(":", "-")
	var report_file = "user://interruption_test_report_" + timestamp + ".json"
	save_report_to_file(report, report_file)
	
	print("\n" + get_test_summary())
	return report

# 主执行函数（供外部调用）
func main():
	var report = run_tests()
	return report

# 如果直接运行此脚本，执行测试
func _ready():
	if get_script().get_path().ends_with("test_runner.gd"):
		main()
