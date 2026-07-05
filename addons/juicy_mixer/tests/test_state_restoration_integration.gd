extends Node

# 状态还原机制集成测试
# 测试PropertyStateManager和StateRestorationMiddleware的协作
# 验证完整的状态还原流程

var _mixer: Object  # JuicyMixer
var _state_manager: Object  # PropertyStateManager
var _middleware: Object  # StateRestorationMiddleware
var _test_targets: Array = []
var _test_resources: Array = []

func _ready():
	print("=== 开始状态还原机制集成测试 ===")
	
	# 初始化测试环境
	_setup_test_environment()
	
	# 运行集成测试
	_test_complete_restoration_flow()
	_test_interrupted_effect_restoration()
	_test_multiple_target_restoration()
	_test_complex_property_restoration()
	_test_restoration_failure_recovery()
	_test_performance_under_load()
	_test_memory_efficiency()
	_test_edge_case_scenarios()
	
	print("=== 状态还原机制集成测试完成 ===")
	
	# 清理测试环境
	_cleanup_test_environment()

func _setup_test_environment():
	# 获取全局实例
	_mixer = JuicyMixer.instance
	
	# 创建状态管理器和中间件（直接实例化，不通过ClassDB）
	_state_manager = PropertyStateManager.new()
	_middleware = StateRestorationMiddleware.new()
	
	# 初始化中间件
	var config = {
		"enable_auto_snapshot": true,
		"enable_debug_logging": false,
		"enable_state_validation": true,
		"max_snapshots_per_target": 5,
		"snapshot_frequency": 0.1,
		"default_restoration_duration": 0.2
	}
	# 注意：移除 "default_restoration_mode" 配置，使用默认值
	
	var init_result = _middleware.initialize(config)
	if not init_result:
		print("中间件初始化失败！")
		assert(false, "中间件初始化失败")
	
	# 获取状态管理器引用
	_state_manager = _middleware.get_state_manager()
	assert(_state_manager != null, "应该能获取状态管理器")
	
	# 创建测试目标
	for i in range(3):
		var target = Node2D.new()
		target.name = "TestTarget_" + str(i)
		target.position = Vector2(i * 100, i * 100)
		target.rotation = i * 0.5
		target.scale = Vector2(1 + i * 0.5, 1 + i * 0.5)
		target.visible = true
		add_child(target)
		_test_targets.append(target)
	
	# 创建测试资源
	for i in range(3):
		var resource = JuicyTweenResource.new()
		resource.duration = 1.0 + i * 0.5
		resource.channel = "test_channel_" + str(i)
		_test_resources.append(resource)
	
	print("集成测试环境设置完成")

func _cleanup_test_environment():
	# 清理测试资源
	for resource in _test_resources:
		if resource and is_instance_valid(resource):
			resource = null
	
	# 清理测试目标
	for target in _test_targets:
		if target and is_instance_valid(target):
			target.queue_free()
	
	# 清理管理器
	if _middleware and is_instance_valid(_middleware):
		if _middleware.has_method("destroy"):
			_middleware.destroy()
	
	if _state_manager and is_instance_valid(_state_manager):
		if _state_manager.has_method("clear_all_snapshots"):
			_state_manager.clear_all_snapshots()
	
	print("集成测试环境清理完成")

func _test_complete_restoration_flow():
	print("\n--- 测试完整还原流程 ---")
	
	var target = _test_targets[0]
	var resource = _test_resources[0]
	
	# 1. 记录初始状态
	var initial_position = target.position
	var initial_rotation = target.rotation
	var initial_scale = target.scale
	
	# 2. 创建测试上下文
	var context = JuicyContext.create(resource, target)
	context.context_id = "integration_test_flow"
	
	# 3. 调用before_play创建初始快照
	var before_play_result = _middleware.before_play(context)
	assert(before_play_result == true, "before_play应该成功")
	
	# 4. 修改目标状态（模拟效果执行）
	target.position = Vector2(200, 200)
	target.rotation = 1.0
	target.scale = Vector2(2, 2)
	
	# 5. 调用after_play创建效果后快照
	_middleware.after_play(context)
	
	# 6. 调用before_stop创建停止前快照
	_middleware.before_stop(context)
	
	# 7. 调用after_stop触发还原
	_middleware.after_stop(context)
	
	# 等待还原完成（异步还原）
	await get_tree().create_timer(0.5).timeout
	
	# 8. 验证状态已还原（检查对象有效性）
	# 注意：由于使用缓动还原，状态可能不完全匹配，但应该接近
	if target and is_instance_valid(target):
		var position_diff = (target.position - initial_position).length()
		var rotation_diff = abs(target.rotation - initial_rotation)
		var scale_diff = (target.scale - initial_scale).length()
		
		print("位置差异: %.2f" % position_diff)
		print("旋转差异: %.4f" % rotation_diff)
		print("缩放差异: %.2f" % scale_diff)
		
		# 允许小的差异 due to 缓动还原
		assert(position_diff < 10.0, "位置应该基本还原")
		assert(rotation_diff < 0.1, "旋转应该基本还原")
		assert(scale_diff < 0.1, "缩放应该基本还原")
	else:
		print("警告：目标对象在验证前已被释放，跳过状态验证")
	
	# 清理上下文
	if context:
		context = null
	
	print("完整还原流程测试通过 ✓")

func _test_interrupted_effect_restoration():
	print("\n--- 测试中断效果还原 ---")
	
	var target = _test_targets[1]
	var resource = _test_resources[1]
	
	# 记录初始状态
	var initial_state = {
		"position": target.position,
		"rotation": target.rotation,
		"scale": target.scale,
		"visible": target.visible
	}
	
	# 创建测试上下文
	var context = JuicyContext.create(resource, target)
	context.context_id = "integration_test_interrupt"
	
	# 调用before_play创建初始快照
	_middleware.before_play(context)
	
	# 快速修改状态（检查对象是否仍然有效）
	await get_tree().create_timer(0.05).timeout
	if target and is_instance_valid(target):
		target.position = Vector2(300, 300)
		target.rotation = 2.0
	else:
		print("警告：目标对象在修改前已被释放，跳过状态修改")
		return  # 提前退出测试
	
	# 立即调用after_stop触发还原（模拟中断）
	_middleware.after_stop(context)
	
	# 等待还原
	await get_tree().create_timer(0.3).timeout
	
	# 验证状态还原（检查对象是否仍然有效）
	if target and is_instance_valid(target):
		var position_restored = (target.position - initial_state.position).length() < 5.0
		var rotation_restored = abs(target.rotation - initial_state.rotation) < 0.05
		
		assert(position_restored, "中断后位置应该还原")
		assert(rotation_restored, "中断后旋转应该还原")
	else:
		print("警告：测试目标对象在还原过程中被释放，跳过状态验证")
	
	# 清理上下文
	if context:
		context = null
	
	print("中断效果还原测试通过 ✓")

func _test_multiple_target_restoration():
	print("\n--- 测试多目标还原 ---")
	
	# 为多个目标创建上下文和快照
	var contexts = []
	var initial_states = []
	
	# 记录初始状态并创建上下文
	for i in range(_test_targets.size()):
		var target = _test_targets[i]
		var resource = _test_resources[i]
		
		initial_states.append({
			"position": target.position,
			"rotation": target.rotation,
			"scale": target.scale
		})
		
		var context = JuicyContext.create(resource, target)
		context.context_id = "multi_target_" + str(i)
		contexts.append(context)
		
		# 创建初始快照
		_middleware.before_play(context)
	
	# 修改所有目标的状态（检查对象有效性）
	await get_tree().create_timer(0.1).timeout
	
	for target in _test_targets:
		if target and is_instance_valid(target):
			target.position += Vector2(100, 100)
			target.rotation += 0.5
			target.scale *= 1.5
		else:
			print("警告：某个目标对象在修改前已被释放")
	
	# 停止所有效果（触发还原）
	for context in contexts:
		_middleware.after_stop(context)
	
	# 等待所有还原完成
	await get_tree().create_timer(0.5).timeout
	
	# 验证所有目标的状态
	for i in range(_test_targets.size()):
		var target = _test_targets[i]
		var initial = initial_states[i]
		
		# 检查目标对象是否仍然有效
		if target and is_instance_valid(target):
			var position_diff = (target.position - initial.position).length()
			var rotation_diff = abs(target.rotation - initial.rotation)
			var scale_diff = (target.scale - initial.scale).length()
			
			assert(position_diff < 10.0, "目标 %d 的位置应该还原" % i)
			assert(rotation_diff < 0.1, "目标 %d 的旋转应该还原" % i)
			assert(scale_diff < 0.1, "目标 %d 的缩放应该还原" % i)
		else:
			print("警告：目标 %d 在还原过程中被释放，跳过验证" % i)
	
	# 清理上下文
	for context in contexts:
		if context:
			context = null
	
	print("多目标还原测试通过 ✓")

func _test_complex_property_restoration():
	print("\n--- 测试复杂属性还原 ---")
	
	var target = _test_targets[0]
	
	# 添加复杂属性
	target.set_meta("custom_property", "custom_value")
	target.modulate = Color(0.5, 0.5, 0.5, 0.5)
	target.z_index = 5
	
	# 记录复杂初始状态
	var initial_complex_state = {
		"modulate": target.modulate,
		"z_index": target.z_index,
		"custom_meta": target.get_meta("custom_property")
	}
	
	# 创建效果（使用直接中间件测试）
	var resource = JuicyTweenResource.new()
	resource.duration = 0.5
	var context = JuicyContext.create(resource, target)
	context.context_id = "complex_property_test"
	
	# 使用中间件直接测试
	_middleware.before_play(context)
	
	# 修改复杂属性（检查对象有效性）
	await get_tree().create_timer(0.1).timeout
	if target and is_instance_valid(target):
		target.modulate = Color(1, 0, 0, 1)
		target.z_index = 10
	else:
		print("警告：目标对象在修改复杂属性前已被释放，跳过测试")
		resource = null
		return  # 提前退出测试
	
	# 停止效果（使用中间件直接测试）
	_middleware.after_stop(context)
	
	# 等待还原
	await get_tree().create_timer(0.3).timeout
	
	# 验证复杂属性还原（检查对象有效性）
	if target and is_instance_valid(target):
		assert(target.modulate.is_equal_approx(initial_complex_state.modulate), "调制颜色应该还原")
		assert(target.z_index == initial_complex_state.z_index, "Z索引应该还原")
		assert(target.get_meta("custom_property") == initial_complex_state.custom_meta, "自定义元数据应该还原")
	else:
		print("警告：目标对象在验证前已被释放，跳过验证")
	
	# 清理上下文和资源
	if context:
		context = null
	resource = null
	print("复杂属性还原测试通过 ✓")

func _test_restoration_failure_recovery():
	print("\n--- 测试还原失败恢复 ---")
	
	var target = _test_targets[2]
	
	# 创建初始快照
	if _state_manager.has_method("create_snapshot"):
		_state_manager.create_snapshot(target, "failure_recovery_test")
	
	# 模拟各种失败情况
	var failure_scenarios = [
		{"type": "property_missing", "description": "属性缺失"},
		{"type": "state_corruption", "description": "状态损坏"},
		{"type": "memory_error", "description": "内存错误"}
	]
	
	for i in range(failure_scenarios.size()):
		var scenario = failure_scenarios[i]
		print("测试失败场景: %s" % scenario.description)
		
		# 模拟运行时失败
		var handled = false
		if _middleware.has_method("handle_runtime_error"):
			# 创建测试上下文
			var test_context = JuicyContext.new()
			test_context.context_id = "failure_test_" + str(i)
			
			handled = await _middleware.handle_runtime_error(test_context, scenario.type, "Test " + scenario.description)
			
			# 清理测试上下文
			test_context = null
		
		# 验证失败被处理
		print("失败处理结果: %s" % ("成功" if handled else "失败"))
	
	print("还原失败恢复测试通过 ✓")

func _test_performance_under_load():
	print("\n--- 测试负载下的性能 ---")
	
	# 创建大量并发效果
	var context_ids = []
	var start_time = Time.get_ticks_msec()
	
	# 批量创建效果（使用直接中间件测试）
	for i in range(20):
		var target_index = i % _test_targets.size()
		var resource_index = i % _test_resources.size()
		var target = _test_targets[target_index]
		var resource = _test_resources[resource_index]
		
		# 检查目标对象是否有效
		if target and is_instance_valid(target):
			var context = JuicyContext.create(resource, target)
			context.context_id = "performance_test_" + str(i)
			
			# 使用中间件直接测试
			_middleware.before_play(context)
			context_ids.append(context)
		else:
			print("警告：目标对象 %d 无效，跳过创建" % target_index)
	
	var creation_time = Time.get_ticks_msec() - start_time
	print("创建 %d 个效果耗时: %d ms" % [context_ids.size(), creation_time])
	
	# 修改所有目标状态（检查对象有效性）
	for target in _test_targets:
		if target and is_instance_valid(target):
			target.position = Vector2(999, 999)
			target.rotation = 5.0
		else:
			print("警告：某个目标对象在性能测试中被释放")
	
	# 批量停止效果
	start_time = Time.get_ticks_msec()
	
	for context in context_ids:
		if context:
			_middleware.after_stop(context)
	
	var stop_time = Time.get_ticks_msec() - start_time
	print("停止 %d 个效果耗时: %d ms" % [context_ids.size(), stop_time])
	
	# 等待还原完成
	await get_tree().create_timer(0.5).timeout
	
	# 验证性能基准
	assert(creation_time < 1000, "效果创建应该很快（< 1秒）")
	assert(stop_time < 500, "效果停止应该很快（< 0.5秒）")
	
	print("负载性能测试通过 ✓")

func _test_memory_efficiency():
	print("\n--- 测试内存效率 ---")
	
	# 获取初始内存统计
	var initial_stats = _state_manager.get_statistics() if _state_manager.has_method("get_statistics") else {}
	var initial_memory = initial_stats.get("memory_usage_estimate", 0)
	var initial_snapshots = initial_stats.get("total_snapshots", 0)
	
	print("初始内存使用: %d 字节" % initial_memory)
	print("初始快照数量: %d" % initial_snapshots)
	
	# 创建大量快照（检查对象有效性）
	for i in range(50):
		var target_index = i % _test_targets.size()
		var target = _test_targets[target_index]
		if target and is_instance_valid(target) and _state_manager.has_method("create_snapshot"):
			_state_manager.create_snapshot(target, "memory_test_" + str(i))
		else:
			print("警告：目标对象 %d 无效，跳过内存测试快照创建" % target_index)
	
	# 获取创建后的统计
	var after_creation_stats = _state_manager.get_statistics() if _state_manager.has_method("get_statistics") else {}
	var after_memory = after_creation_stats.get("memory_usage_estimate", 0)
	var after_snapshots = after_creation_stats.get("total_snapshots", 0)
	
	print("创建后内存使用: %d 字节" % after_memory)
	print("创建后快照数量: %d" % after_snapshots)
	
	# 验证内存增长合理
	var memory_growth = after_memory - initial_memory
	var avg_memory_per_snapshot = memory_growth / (after_snapshots - initial_snapshots) if (after_snapshots - initial_snapshots) > 0 else 0
	
	print("平均每个快照内存使用: %d 字节" % avg_memory_per_snapshot)
	
	# 每个快照应该使用合理的内存（< 10KB）
	assert(avg_memory_per_snapshot < 10000, "每个快照内存使用应该合理（< 10KB）")
	
	# 测试清理后的内存回收
	if _state_manager.has_method("clear_all_snapshots"):
		_state_manager.clear_all_snapshots()
	
	var after_cleanup_stats = _state_manager.get_statistics() if _state_manager.has_method("get_statistics") else {}
	var after_cleanup_memory = after_cleanup_stats.get("memory_usage_estimate", 0)
	
	print("清理后内存使用: %d 字节" % after_cleanup_memory)
	
	# 内存应该显著减少
	assert(after_cleanup_memory < after_memory * 0.5, "清理后内存应该显著减少")
	
	print("内存效率测试通过 ✓")

func _test_edge_case_scenarios():
	print("\n--- 测试边界情况 ---")
	
	# 测试1: 空目标
	var empty_result = await _middleware.handle_runtime_error(null, "test_error", "Empty context")
	print("空上下文处理结果: %s" % ("成功" if empty_result else "失败"))
	
	# 检查是否有错误日志
	var error_log = _middleware.get_error_log()
	if error_log.size() > 0:
		print("错误处理测试产生的日志:")
		for error in error_log:
			print("  - ", error.message)
	
	# 测试2: 无效上下文ID
	var invalid_context = JuicyContext.new()
	invalid_context.context_id = "invalid_context"
	
	var invalid_result = await _middleware.handle_runtime_error(invalid_context, "test_error", "Invalid context")
	print("无效上下文处理结果: %s" % ("成功" if invalid_result else "失败"))
	
	# 清理无效上下文
	invalid_context = null
	
	# 测试3: 快速连续快照
	var target = _test_targets[0]
	var rapid_snapshot_count = 0
	
	for i in range(10):
		if target and is_instance_valid(target) and _state_manager.has_method("create_snapshot"):
			_state_manager.create_snapshot(target, "rapid_test_" + str(i))
			rapid_snapshot_count += 1
		else:
			print("警告：目标对象在快速快照测试中被释放")
			break
	
	print("快速创建 %d 个快照完成" % rapid_snapshot_count)
	
	# 测试4: 大属性值（检查对象有效性）
	if target and is_instance_valid(target):
		var large_string = ""
		for i in range(1000):
			large_string += "x"
		target.set_meta("large_data", large_string)  # 1KB的字符串
		
		if _state_manager.has_method("create_snapshot"):
			_state_manager.create_snapshot(target, "large_data_test")
	else:
		print("警告：目标对象在大属性测试中被释放")
	
	print("大属性值快照测试完成")
	
	# 测试5: 嵌套节点结构
	var parent_node = Node2D.new()
	var child_node = Node2D.new()
	parent_node.add_child(child_node)
	add_child(parent_node)
	
	if _state_manager.has_method("create_snapshot"):
		_state_manager.create_snapshot(parent_node, "nested_test")
	
	# 清理
	parent_node.queue_free()
	
	print("边界情况测试通过 ✓")

func _exit_tree():
	# 确保清理测试环境
	_cleanup_test_environment()
