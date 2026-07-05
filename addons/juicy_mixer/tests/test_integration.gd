# 集成测试
# 测试核心组件之间的协作和数据流

extends Node

var _mixer: Object
var _test_target: Node2D

func _ready():
	# 初始化全局实例
	_mixer = JuicyMixer.instance
	
	# 创建测试目标
	_test_target = Node2D.new()
	_test_target.position = Vector2(100, 100)
	add_child(_test_target)
	
	# 运行集成测试
	_test_basic_data_flow()
	_test_buffer_integration()
	_test_context_lifecycle_integration()
	_test_performance_baseline()
	
	print("✅ All integration tests passed!")

func _test_basic_data_flow():
	print("Testing basic data flow integration...")
	
	# 创建测试资源 - 使用JuicyTweenResource
	var resource = JuicyTweenResource.new()
	resource.duration = 1.0
	
	# 测试播放效果
	var context_id = JuicyMixer.play(resource, _test_target)
	
	assert(not context_id.is_empty(), "Context ID should be generated")
	assert(JuicyMixer.is_context_active(context_id), "Context should be active")
	
	# 测试停止效果
	var stop_result = JuicyMixer.stop(context_id)
	assert(stop_result == true, "Stop operation should succeed")
	assert(not JuicyMixer.is_context_active(context_id), "Context should not be active after stop")
	
	print("✅ Basic data flow integration test passed")

func _test_buffer_integration():
	print("Testing buffer integration...")
	
	# 创建属性缓冲区
	var buffer = JuicyPropertyBuffer.new()
	
	# 测试属性混合
	buffer.add_sample(_test_target, "position", Vector2(200, 200), JuicyPropertyBuffer.BlendMode.OVERRIDE_BASE)
	buffer.flush_target_samples(_test_target)
	
	assert(_test_target.position == Vector2(200, 200), "Buffer should modify target properties")
	
	# 测试多个属性的混合
	buffer.add_sample(_test_target, "scale", Vector2(2, 2), JuicyPropertyBuffer.BlendMode.OVERRIDE_BASE)
	buffer.add_sample(_test_target, "rotation", 0.5, JuicyPropertyBuffer.BlendMode.ADDITIVE)
	buffer.flush_target_samples(_test_target)
	
	assert(_test_target.scale == Vector2(2, 2), "Scale should be modified")
	assert(_test_target.rotation == 0.5, "Rotation should be modified")
	
	print("✅ Buffer integration test passed")

func _test_context_lifecycle_integration():
	print("Testing context lifecycle integration...")
	
	# 创建测试资源 - 使用JuicyTweenResource
	var resource = JuicyTweenResource.new()
	resource.duration = 0.1  # 短持续时间用于测试
	
	# 播放效果
	var context_id = JuicyMixer.play(resource, _test_target)
	var context = JuicyMixer.get_context(context_id)
	
	assert(context != null, "Context should be retrievable")
	assert(context.is_active, "Context should be active initially")
	
	# 测试暂停和恢复
	# 这里需要实现pause/resume功能
	# var pause_result = JuicyMixer.pause(context_id)
	# assert(pause_result == true, "Pause should succeed")
	# assert(context.is_paused, "Context should be paused")
	
	# var resume_result = JuicyMixer.resume(context_id)
	# assert(resume_result == true, "Resume should succeed")
	# assert(not context.is_paused, "Context should not be paused after resume")
	
	print("✅ Context lifecycle integration test passed")

func _test_performance_baseline():
	print("Testing performance baseline...")
	
	# 测试Context创建性能
	var start_time = Time.get_ticks_msec()
	var context_count = 100
	
	for i in range(context_count):
		var resource = JuicyTweenResource.new()
		resource.duration = 1.0
		var context = JuicyContext.create(resource, _test_target)
	
	var end_time = Time.get_ticks_msec()
	var creation_time = (end_time - start_time) / 1000.0
	var avg_creation_time = creation_time / context_count
	
	print("Created ", context_count, " contexts in ", creation_time, " seconds")
	print("Average creation time: ", avg_creation_time * 1000, " ms")
	
	# 验证性能基准（应该小于0.1ms每个Context）
	assert(avg_creation_time < 0.0001, "Context creation should be fast (< 0.1ms per context)")
	
	# 测试缓冲区操作性能
	var buffer = JuicyPropertyBuffer.new()
	start_time = Time.get_ticks_msec()
	var sample_count = 1000
	
	for i in range(sample_count):
		buffer.add_sample(_test_target, "position", Vector2(i, i), JuicyPropertyBuffer.BlendMode.ADDITIVE)
	
	end_time = Time.get_ticks_msec()
	var buffer_time = (end_time - start_time) / 1000.0
	var avg_buffer_time = buffer_time / sample_count
	
	print("Added ", sample_count, " buffer samples in ", buffer_time, " seconds")
	print("Average buffer operation time: ", avg_buffer_time * 1000, " ms")
	
	# 验证缓冲区性能基准（应该小于0.01ms每个操作）
	assert(avg_buffer_time < 0.00001, "Buffer operations should be fast (< 0.01ms per operation)")
	
	print("✅ Performance baseline test passed")

func _test_batch_operations():
	print("Testing batch operations...")
	
	# 创建多个资源和目标
	var resources = []
	var targets = []
	
	for i in range(5):
		var resource = JuicyTweenResource.new()
		resource.duration = 1.0
		resources.append(resource)
		
		var target = Node2D.new()
		target.position = Vector2(i * 100, i * 100)
		add_child(target)
		targets.append(target)
	
	# 测试批处理播放
	var context_ids = JuicyMixer.play_batch(resources, targets)
	
	assert(context_ids.size() == 5, "Should create 5 contexts")
	
	# 清理测试目标
	for target in targets:
		target.queue_free()
	
	print("✅ Batch operations test passed")

func _exit_tree():
	# 清理全局实例
	JuicyMixer.cleanup()
	
	if _test_target:
		_test_target.queue_free()
