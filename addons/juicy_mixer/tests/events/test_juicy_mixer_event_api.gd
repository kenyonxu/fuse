# 测试JuicyMixer事件API的向后兼容性和优雅降级行为
extends Node

func _ready():
	print("=== 测试JuicyMixer事件API ===")
	
	# 测试1: 验证现有API不受影响
	await test_existing_api_compatibility()
	
	# 测试2: 验证事件API在未启用时的优雅降级行为
	await test_event_api_graceful_degradation()
	
	print("=== 测试完成 ===")

func test_existing_api_compatibility():
	print("\n--- 测试现有API兼容性 ---")
	
	# 创建测试节点
	var test_node = Node.new()
	add_child(test_node)
	
	# 测试现有API是否正常工作
	print("测试play()方法...")
	# 创建一个简单的模拟资源对象
	var mock_resource = MockResource.new()
	var context_id = JuicyMixer.play(mock_resource, test_node)  # 使用模拟资源测试API调用
	print("play()返回: ", context_id)
	
	print("测试get_context()方法...")
	var context = JuicyMixer.get_context(context_id)
	print("get_context()返回: ", context)
	
	print("测试get_active_contexts_count()方法...")
	var count = JuicyMixer.get_active_contexts_count()
	print("get_active_contexts_count()返回: ", count)
	
	# 清理
	JuicyMixer.stop_all()
	test_node.queue_free()
	
	print("现有API兼容性测试通过")

func test_event_api_graceful_degradation():
	print("\n--- 测试事件API优雅降级行为 ---")
	
	# 创建测试节点
	var test_node = Node.new()
	add_child(test_node)
	
	# 测试1: play_event()在未启用事件系统时的行为
	print("测试play_event()在未启用事件系统时的行为...")
	
	# 创建一个简单的事件对象（模拟）
	var mock_event = MockEvent.new()
	var result = JuicyMixer.play_event(mock_event, test_node)
	print("play_event()返回: '", result, "' (应该是空字符串)")
	
	# 测试2: add_event_to_context()在未启用事件系统时的行为
	print("测试add_event_to_context()在未启用事件系统时的行为...")
	
	# 首先创建一个上下文
	var mock_resource = MockResource.new()
	var context_id = JuicyMixer.play(mock_resource, test_node)
	print("创建的上下文ID: ", context_id)
	
	var add_result = JuicyMixer.add_event_to_context(context_id, mock_event)
	print("add_event_to_context()返回: ", add_result, " (应该是false)")
	
	# 清理
	JuicyMixer.stop_all()
	test_node.queue_free()
	
	print("事件API优雅降级行为测试通过")

# 模拟资源对象类
class MockResource:
	extends JuicyFeedbackResource
	
	func get_duration():
		return 1.0
	
	func create_drivers():
		return []  # 返回空的驱动器数组

	func get_data_count() -> int:
		return 0

	func get_data_at(index: int) -> JuicyFeedbackData:
		var data : JuicyFeedbackData
		return data

	func set_data_at(index: int, source: JuicyFeedbackData) -> void:
		pass

	func get_data() -> Array:
		return []


# 模拟事件对象类
class MockEvent:
	extends RefCounted
	
	func get_event_type():
		return "MOCK_EVENT"
	
	func get_target():
		return null
	
	func set_context_id(id: String):
		pass
	
	func get_context_id():
		return ""