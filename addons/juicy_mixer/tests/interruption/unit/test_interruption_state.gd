extends SceneTree
# InterruptionState 单元测试
# 测试中断状态管理的核心功能

const InterruptionState = preload("res://addons/juicy_mixer/core/interruption_state.gd")
const JuicyMixerEnms = preload("res://addons/juicy_mixer/core/juicy_mixer_enums.gd")

var _test_results: Array = []

func _init():
	_test_results = []

func test_interruption_state_creation():
	# 测试基本创建
	var state = InterruptionState.new()
	assert(state != null, "InterruptionState 应该成功创建")
	assert(state.target_id == 0, "初始 target_id 应该是 0")
	assert(state.active_contexts.size() == 0, "初始活跃上下文应该是空")
	assert(state.queued_contexts.size() == 0, "初始队列上下文应该是空")
	assert(state.current_policy == JuicyMixerEnms.InterruptionPolicy.STACK, "初始策略应该是 STACK")
	
	# 测试带目标节点创建
	var test_node = Node.new()
	var state_with_target = InterruptionState.new(test_node)
	assert(state_with_target != null, "带目标的 InterruptionState 应该成功创建")
	assert(state_with_target.target_id == test_node.get_instance_id(), "target_id 应该正确设置")
	
	test_node.free()
	
	_test_results.append("test_interruption_state_creation: PASSED")

func test_active_context_management():
	var state = InterruptionState.new()
	
	# 测试添加活跃上下文
	state.add_active_context("context_1")
	assert(state.has_active_context("context_1"), "应该存在 context_1")
	assert(state.get_active_context_count() == 1, "活跃上下文数量应该是 1")
	
	# 测试重复添加
	state.add_active_context("context_1")
	assert(state.get_active_context_count() == 1, "重复添加上下文不应该增加数量")
	
	# 测试添加多个上下文
	state.add_active_context("context_2")
	assert(state.has_active_context("context_2"), "应该存在 context_2")
	assert(state.get_active_context_count() == 2, "活跃上下文数量应该是 2")
	
	# 测试移除上下文
	state.remove_active_context("context_1")
	assert(not state.has_active_context("context_1"), "context_1 应该被移除")
	assert(state.get_active_context_count() == 1, "活跃上下文数量应该是 1")
	
	# 测试清空所有上下文
	state.clear_active_contexts()
	assert(state.get_active_context_count() == 0, "清空后活跃上下文数量应该是 0")
	
	_test_results.append("test_active_context_management: PASSED")

func test_queued_context_management():
	var state = InterruptionState.new()
	
	# 测试添加队列上下文
	state.add_queued_context("queued_1")
	assert(state.has_queued_context("queued_1"), "应该存在 queued_1")
	assert(state.get_queued_context_count() == 1, "队列上下文数量应该是 1")
	
	# 测试重复添加
	state.add_queued_context("queued_1")
	assert(state.get_queued_context_count() == 1, "重复添加队列上下文不应该增加数量")
	
	# 测试获取下一个队列上下文
	state.add_queued_context("queued_2")
	var next_context = state.get_next_queued_context()
	assert(next_context == "queued_1", "下一个队列上下文应该是 queued_1")
	assert(state.get_queued_context_count() == 2, "获取操作不应该移除上下文")
	
	# 测试弹出下一个队列上下文
	var popped_context = state.pop_next_queued_context()
	assert(popped_context == "queued_1", "弹出的上下文应该是 queued_1")
	assert(state.get_queued_context_count() == 1, "弹出后队列数量应该是 1")
	assert(not state.has_queued_context("queued_1"), "queued_1 应该被移除")
	
	# 测试空队列
	state.clear_queued_contexts()
	assert(state.get_next_queued_context() == "", "空队列应该返回空字符串")
	assert(state.pop_next_queued_context() == "", "空队列弹出应该返回空字符串")
	
	_test_results.append("test_queued_context_management: PASSED")

func test_priority_queue_management():
	var state = InterruptionState.new()
	
	# 测试添加优先级队列项
	state.add_priority_queue_item("high_priority", 10)
	state.add_priority_queue_item("low_priority", 1)
	state.add_priority_queue_item("medium_priority", 5)
	
	assert(state.get_priority_queue_count() == 3, "优先级队列数量应该是 3")
	
	# 测试优先级排序（高优先级在前）
	var next_item = state.get_next_priority_item()
	assert(next_item.context_id == "high_priority", "第一个优先级项应该是高优先级")
	assert(next_item.priority == 10, "高优先级的优先级值应该是 10")
	
	# 测试弹出优先级项
	var popped_item = state.pop_next_priority_item()
	assert(popped_item.context_id == "high_priority", "弹出的应该是高优先级项")
	assert(state.get_priority_queue_count() == 2, "弹出后队列数量应该是 2")
	
	# 测试剩余项的顺序
	var next_item_after_pop = state.get_next_priority_item()
	assert(next_item_after_pop.context_id == "medium_priority", "下一个应该是中等优先级")
	
	# 测试空队列
	state.clear_priority_queue()
	assert(state.get_priority_queue_count() == 0, "清空后队列数量应该是 0")
	assert(state.get_next_priority_item() == {}, "空队列应该返回空字典")
	
	_test_results.append("test_priority_queue_management: PASSED")

func test_interruption_history():
	var state = InterruptionState.new()
	
	# 测试添加中断记录
	var record1 = {
		"timestamp": Time.get_ticks_msec() / 1000.0,
		"new_context": "new_ctx_1",
		"existing_context": "existing_ctx_1",
		"policy": JuicyMixerEnms.InterruptionPolicy.RESTART,
		"target_id": 123
	}
	
	state.add_interruption_record(record1)
	var history = state.get_interruption_history()
	assert(history.size() == 1, "历史记录数量应该是 1")
	assert(history[0].new_context == "new_ctx_1", "历史记录应该包含正确的数据")
	
	# 测试添加多个记录
	var record2 = {
		"timestamp": Time.get_ticks_msec() / 1000.0,
		"new_context": "new_ctx_2",
		"existing_context": "existing_ctx_2",
		"policy": JuicyMixerEnms.InterruptionPolicy.STACK,
		"target_id": 456
	}
	
	state.add_interruption_record(record2)
	history = state.get_interruption_history()
	assert(history.size() == 2, "历史记录数量应该是 2")
	
	# 测试历史记录限制（模拟超过100条记录）
	for i in range(105):
		state.add_interruption_record({
			"timestamp": Time.get_ticks_msec() / 1000.0,
			"new_context": "ctx_" + str(i),
			"existing_context": "existing_ctx",
			"policy": JuicyMixerEnms.InterruptionPolicy.STACK,
			"target_id": i
		})
	
	history = state.get_interruption_history()
	assert(history.size() == 100, "历史记录数量应该被限制为 100")
	
	# 测试清空历史记录
	state.clear_interruption_history()
	assert(state.get_interruption_history().size() == 0, "清空后历史记录数量应该是 0")
	
	_test_results.append("test_interruption_history: PASSED")

func test_transition_management():
	var state = InterruptionState.new()
	
	# 测试初始状态
	assert(not state.is_transitioning(), "初始状态应该不在过渡中")
	assert(not state.is_transition_complete(), "初始过渡进度应该是不完整的")
	
	# 测试设置过渡
	state.set_transition("transition_ctx")
	assert(state.is_transitioning(), "设置过渡后应该正在过渡")
	assert(not state.is_transition_complete(), "过渡开始时应该不完整")
	assert(state.transition_context == "transition_ctx", "过渡上下文应该正确设置")
	assert(state.transition_progress == 0.0, "过渡进度应该为 0")
	
	# 测试更新过渡进度
	state.update_transition_progress(0.5)
	assert(state.transition_progress == 0.5, "过渡进度应该更新为 0.5")
	assert(not state.is_transition_complete(), "进度 0.5 时应该还未完成")
	
	# 测试完成过渡
	state.update_transition_progress(0.6)  # 总进度 1.1
	assert(state.is_transition_complete(), "进度超过 1.0 时应该完成")
	assert(state.transition_progress == 1.0, "过渡进度应该被限制为 1.0")
	
	# 测试清除过渡
	state.clear_transition()
	assert(not state.is_transitioning(), "清除后应该不在过渡中")
	assert(state.transition_context == "", "过渡上下文应该被清除")
	assert(state.transition_progress == 0.0, "过渡进度应该被重置")
	
	_test_results.append("test_transition_management: PASSED")

func test_policy_management():
	var state = InterruptionState.new()
	
	# 测试默认策略
	assert(state.current_policy == JuicyMixerEnms.InterruptionPolicy.STACK, "默认策略应该是 STACK")
	
	# 测试策略设置
	state.current_policy = JuicyMixerEnms.InterruptionPolicy.RESTART
	assert(state.current_policy == JuicyMixerEnms.InterruptionPolicy.RESTART, "策略应该设置为 RESTART")
	
	state.current_policy = JuicyMixerEnms.InterruptionPolicy.SMOOTH_TRANSITION
	assert(state.current_policy == JuicyMixerEnms.InterruptionPolicy.SMOOTH_TRANSITION, "策略应该设置为 SMOOTH_TRANSITION")
	
	_test_results.append("test_policy_management: PASSED")

func test_serialization():
	var state = InterruptionState.new()
	
	# 设置一些测试数据
	state.add_active_context("active_ctx")
	state.add_queued_context("queued_ctx")
	state.add_priority_queue_item("priority_ctx", 5)
	state.add_interruption_record({
		"timestamp": 123.456,
		"new_context": "test_ctx",
		"existing_context": "old_ctx",
		"policy": JuicyMixerEnms.InterruptionPolicy.STACK,
		"target_id": 789
	})
	state.set_transition("trans_ctx")
	state.update_transition_progress(0.7)
	
	# 测试序列化
	var serialized = state.serialize()
	assert(typeof(serialized) == TYPE_DICTIONARY, "序列化结果应该是字典")
	assert(serialized.has("target_id"), "序列化应该包含 target_id")
	assert(serialized.has("active_contexts"), "序列化应该包含 active_contexts")
	assert(serialized.has("queued_contexts"), "序列化应该包含 queued_contexts")
	assert(serialized.has("priority_queue"), "序列化应该包含 priority_queue")
	assert(serialized.has("interruption_history"), "序列化应该包含 interruption_history")
	assert(serialized.has("current_policy"), "序列化应该包含 current_policy")
	assert(serialized.has("transition_context"), "序列化应该包含 transition_context")
	assert(serialized.has("transition_progress"), "序列化应该包含 transition_progress")
	
	# 测试反序列化
	var new_state = InterruptionState.new()
	var success = new_state.deserialize(serialized)
	assert(success, "反序列化应该成功")
	assert(new_state.target_id == state.target_id, "反序列化后的 target_id 应该相同")
	assert(new_state.get_active_context_count() == state.get_active_context_count(), "反序列化后的活跃上下文数量应该相同")
	assert(new_state.get_queued_context_count() == state.get_queued_context_count(), "反序列化后的队列上下文数量应该相同")
	assert(new_state.get_priority_queue_count() == state.get_priority_queue_count(), "反序列化后的优先级队列数量应该相同")
	assert(new_state.current_policy == state.current_policy, "反序列化后的策略应该相同")
	assert(new_state.transition_context == state.transition_context, "反序列化后的过渡上下文应该相同")
	assert(new_state.transition_progress == state.transition_progress, "反序列化后的过渡进度应该相同")
	
	_test_results.append("test_serialization: PASSED")

func test_validation():
	var state = InterruptionState.new()
	
	# 测试序列化数据验证
	var valid_data = {
		"target_id": 123,
		"active_contexts": ["ctx1", "ctx2"],
		"queued_contexts": ["q_ctx1"],
		"current_policy": "stack",
		"transition_context": "trans_ctx",
		"transition_progress": 0.5,
		"interruption_history": [],
		"priority_queue": []
	}
	
	var validation_result = state.validate_serialization_data(valid_data)
	assert(validation_result.valid, "有效的数据应该通过验证")
	assert(validation_result.issues.size() == 0, "有效数据不应该有验证问题")
	
	# 测试无效数据
	var invalid_data = {
		"target_id": "invalid",  # 应该是整数
		"active_contexts": "not_array",  # 应该是数组
		"queued_contexts": ["valid"],
		"current_policy": 123,  # 应该是字符串
	}
	
	validation_result = state.validate_serialization_data(invalid_data)
	assert(not validation_result.valid, "无效数据应该验证失败")
	assert(validation_result.issues.size() > 0, "无效数据应该有验证问题")
	
	# 测试缺失必需字段
	var incomplete_data = {
		"active_contexts": ["ctx1"],
		"queued_contexts": ["q_ctx1"]
		# 缺少 target_id 和 current_policy
	}
	
	validation_result = state.validate_serialization_data(incomplete_data)
	assert(not validation_result.valid, "不完整数据应该验证失败")
	
	_test_results.append("test_validation: PASSED")

func test_string_representation():
	var state = InterruptionState.new()
	
	# 测试字符串表示
	var str_repr = state.to_string()
	assert(str_repr.contains("InterruptionState"), "字符串表示应该包含类名")
	assert(str_repr.contains("target_id"), "字符串表示应该包含 target_id")
	
	# 测试状态摘要
	var summary = state.get_state_summary()
	assert(typeof(summary) == TYPE_DICTIONARY, "状态摘要应该是字典")
	assert(summary.has("target_id"), "摘要应该包含 target_id")
	assert(summary.has("active_contexts"), "摘要应该包含 active_contexts")
	assert(summary.has("queued_contexts"), "摘要应该包含 queued_contexts")
	assert(summary.has("priority_queue_size"), "摘要应该包含 priority_queue_size")
	assert(summary.has("current_policy"), "摘要应该包含 current_policy")
	assert(summary.has("is_transitioning"), "摘要应该包含 is_transitioning")
	assert(summary.has("transition_progress"), "摘要应该包含 transition_progress")
	assert(summary.has("history_size"), "摘要应该包含 history_size")
	
	_test_results.append("test_string_representation: PASSED")

func test_clear_all():
	var state = InterruptionState.new()
	
	# 添加一些数据
	state.add_active_context("active_ctx")
	state.add_queued_context("queued_ctx")
	state.add_priority_queue_item("priority_ctx", 5)
	state.add_interruption_record({
		"timestamp": 123.456,
		"new_context": "test_ctx",
		"policy": JuicyMixerEnms.InterruptionPolicy.STACK
	})
	state.set_transition("trans_ctx")
	
	# 测试清空所有
	state.clear_all()
	assert(state.get_active_context_count() == 0, "清空后活跃上下文数量应该是 0")
	assert(state.get_queued_context_count() == 0, "清空后队列上下文数量应该是 0")
	assert(state.get_priority_queue_count() == 0, "清空后优先级队列数量应该是 0")
	assert(state.get_interruption_history().size() == 0, "清空后历史记录数量应该是 0")
	assert(not state.is_transitioning(), "清空后应该不在过渡中")
	assert(state.current_policy == JuicyMixerEnms.InterruptionPolicy.STACK, "策略应该重置为默认")
	
	_test_results.append("test_clear_all: PASSED")

func test_edge_cases():
	var state = InterruptionState.new()
	
	# 测试空字符串上下文
	state.add_active_context("")
	assert(state.has_active_context(""), "应该能处理空字符串上下文")
	
	# 测试特殊字符上下文
	state.add_queued_context("special!@#$%^&*()")
	assert(state.has_queued_context("special!@#$%^&*()"), "应该能处理特殊字符上下文")
	
	# 测试极大优先级值
	state.add_priority_queue_item("extreme_priority", 999999)
	var next_item = state.get_next_priority_item()
	assert(next_item.priority == 999999, "应该能处理极大优先级值")
	
	# 测试负优先级值
	state.add_priority_queue_item("negative_priority", -100)
	state.add_priority_queue_item("normal_priority", 1)
	var items = []
	while state.get_priority_queue_count() > 0:
		items.append(state.pop_next_priority_item())
	
	# 负优先级应该在正常优先级之后
	assert(items[-1].priority == -100, "负优先级应该排在最后")
	
	# 测试过渡进度边界
	state.set_transition("test_transition")  # 先设置过渡状态
	state.update_transition_progress(1000)  # 极大值
	print("过渡进度值: ", state.transition_progress)  # 添加调试信息
	assert(state.transition_progress == 1.0, "过渡进度应该被限制在 1.0")
	
	_test_results.append("test_edge_cases: PASSED")

func test_serialization_size():
	var state = InterruptionState.new()
	
	# 添加一些数据来测试大小计算
	state.add_active_context("test_context")
	state.add_queued_context("queued_context")
	state.add_priority_queue_item("priority_item", 5)
	state.add_interruption_record({
		"timestamp": 123.456,
		"new_context": "test",
		"policy": JuicyMixerEnms.InterruptionPolicy.STACK
	})
	state.set_transition("transition_context")
	
	# 测试序列化大小计算
	var size = state.get_serialization_size()
	assert(size > 0, "序列化大小应该是正数")
	assert(typeof(size) == TYPE_INT, "序列化大小应该是整数")
	
	# 测试空状态的序列化大小
	var empty_state = InterruptionState.new()
	var empty_size = empty_state.get_serialization_size()
	assert(empty_size > 0, "空状态的序列化大小也应该是正数")
	assert(empty_size < size, "空状态的序列化大小应该小于有数据的状态")
	
	_test_results.append("test_serialization_size: PASSED")

func run_all_tests():
	print("=== 开始 InterruptionState 单元测试 ===")
	
	test_interruption_state_creation()
	test_active_context_management()
	test_queued_context_management()
	test_priority_queue_management()
	test_interruption_history()
	test_transition_management()
	test_policy_management()
	test_serialization()
	test_validation()
	test_string_representation()
	test_clear_all()
	test_edge_cases()
	test_serialization_size()
	
	print("=== InterruptionState 单元测试结果 ===")
	for result in _test_results:
		print(result)
	
	var passed_count = _test_results.size()
	var total_tests = 13
	print("通过测试: " + str(passed_count) + "/" + str(total_tests))
	
	if passed_count == total_tests:
		print("所有测试通过！")
		return true
	else:
		print("部分测试失败！")
		return false
