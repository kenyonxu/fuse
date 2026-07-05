extends Node

# 集成测试运行器
# 运行所有集成测试并生成报告

const INTEGRATION_TEST_SCENE = "res://addons/juicy_mixer/tests/test_integration_event_handlers.gd"

var _test_node: Node
var _test_completed: bool = false

func _ready():
	print("=== JuicyMixer 集成测试运行器 ===")
	
	# 创建测试节点
	_test_node = Node.new()
	add_child(_test_node)
	
	# 运行集成测试
	_run_integration_tests()
	
	# 等待测试完成
	await _wait_for_completion()
	
	# 清理
	_cleanup()

func _run_integration_tests():
	print("开始运行集成测试...")
	
	# 动态加载并实例化集成测试脚本
	var test_script = load(INTEGRATION_TEST_SCENE)
	if not test_script:
		push_error("无法加载集成测试脚本: " + INTEGRATION_TEST_SCENE)
		return
	
	# 创建测试实例
	var test_instance = test_script.new()
	_test_node.add_child(test_instance)
	
	print("集成测试已启动，等待完成...")

func _wait_for_completion():
	# 等待一段时间让测试完成
	var wait_time = 0
	var max_wait_time = 30.0  # 最多等待30秒
	
	while wait_time < max_wait_time:
		await get_tree().create_timer(1.0).timeout
		wait_time += 1.0
		
		# 检查是否还有活动的测试节点
		var active_tests = 0
		for child in _test_node.get_children():
			if child.has_method("_ready"):  # 简单的存在检查
				active_tests += 1
		
		if active_tests == 0:
			print("检测到测试完成")
			break
	
	if wait_time >= max_wait_time:
		print("测试超时，已等待 " + str(max_wait_time) + " 秒")
	
	_test_completed = true

func _cleanup():
	print("清理测试运行器...")
	
	# 清理测试节点
	if _test_node:
		for child in _test_node.get_children():
			child.queue_free()
		_test_node.queue_free()
		_test_node = null
	
	print("集成测试运行器清理完成")

func _exit_tree():
	_cleanup()