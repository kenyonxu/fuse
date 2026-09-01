extends Node

## 变量查找优化测试运行器
##
## 用于在 Godot 编辑器中运行性能测试

func _ready():
	print("=== ExecutionContext 变量查找优化测试 ===")

	# 创建测试实例
	var test_script = load("res://tests/variable_lookup_optimization_test.gd")
	if test_script:
		var test_instance = test_script.new()
		if test_instance and test_instance.has_method("run_tests"):
			test_instance.run_tests()
		else:
			print("错误: 测试脚本没有 run_tests 方法")
	else:
		print("错误: 无法加载测试脚本")

	# 延迟退出，让输出完成
	await get_tree().create_timer(1.0).timeout
	get_tree().quit()

func _exit_tree():
	print("测试运行器退出")