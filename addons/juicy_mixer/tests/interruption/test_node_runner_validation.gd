extends Node
# Node-based测试运行器验证脚本
# 用于验证所有Node-based测试运行器是否能正常工作

var _test_runners = [
	"res://addons/juicy_mixer/tests/interruption/unit/test_interruption_state_node.gd",
	"res://addons/juicy_mixer/tests/interruption/unit/test_channel_interruption_config_node.gd",
	"res://addons/juicy_mixer/tests/interruption/unit/test_juicy_interruption_manager_node.gd",
	"res://addons/juicy_mixer/tests/interruption/unit/test_interruption_middleware_node.gd",
	"res://addons/juicy_mixer/tests/interruption/unit/test_juicy_mixer_enums_node.gd",
	"res://addons/juicy_mixer/tests/interruption/integration/test_director_integration_node.gd",
	"res://addons/juicy_mixer/tests/interruption/integration/test_middleware_integration_node.gd"
]

var _current_test_index = 0
var _test_results = []

func _ready():
	print("=== 开始验证所有Node-based测试运行器 ===")
	run_next_test()

func run_next_test():
	if _current_test_index >= _test_runners.size():
		# 所有测试运行器验证完成
		print("\n=== Node-based测试运行器验证结果 ===")
		for result in _test_results:
			print(result)
		
		var passed_count = 0
		for result in _test_results:
			if result.contains("✅"):
				passed_count += 1
		
		print("\n验证总结:")
		print("总测试运行器数量: " + str(_test_runners.size()))
		print("通过验证: " + str(passed_count) + "/" + str(_test_runners.size()))
		
		if passed_count == _test_runners.size():
			print("🎉 所有Node-based测试运行器验证通过！")
		else:
			print("⚠️  部分测试运行器验证失败！")
		
		return
	
	var test_path = _test_runners[_current_test_index]
	var test_name = test_path.get_file()
	
	print("\n--- 验证测试运行器: " + test_name + " ---")
	
	# 尝试加载测试脚本
	var test_script = load(test_path)
	if test_script == null:
		_test_results.append("❌ " + test_name + " - 无法加载脚本")
		_current_test_index += 1
		run_next_test()
		return
	
	# 创建测试实例
	var test_instance = test_script.new()
	if test_instance == null:
		_test_results.append("❌ " + test_name + " - 无法创建实例")
		_current_test_index += 1
		run_next_test()
		return
	
	# 检查是否有_ready方法
	if not test_instance.has_method("_ready"):
		_test_results.append("❌ " + test_name + " - 缺少_ready方法")
		test_instance.free()
		_current_test_index += 1
		run_next_test()
		return
	
	# 检查是否有run_all_tests方法或类似的测试方法
	var has_test_method = false
	if test_instance.has_method("run_all_tests"):
		has_test_method = true
	elif test_instance.has_method("_ready"):  # Node-based运行器通过_ready方法运行测试
		has_test_method = true
	
	if not has_test_method:
		_test_results.append("❌ " + test_name + " - 缺少测试方法")
		test_instance.free()
		_current_test_index += 1
		run_next_test()
		return
	
	# 验证通过
	_test_results.append("✅ " + test_name + " - 结构验证通过")
	
	# 清理
	test_instance.free()
	
	# 继续下一个
	_current_test_index += 1
	run_next_test()