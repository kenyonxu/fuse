extends Node

## 测试指令并发执行
##
## 验证多个触发器同时执行同一指令资源时状态隔离
## 验证暂停/恢复功能正常工作

# 测试结果
var _test_results: Array[Dictionary] = []
var _completed_count: int = 0
var _test_phase: String = ""
var _start_time: float = 0.0

# 引用
var _test_node: Node = null

func _ready():
	# 创建测试节点
	_test_node = Node.new()
	_test_node.name = "TestNode"
	add_child(_test_node)

	# 延迟执行测试，确保场景树准备完毕
	await get_tree().process_frame
	_run_all_tests()

func _run_all_tests():
	print("========================================")
	print("Fuse RuntimeInstructionInstance 并发执行测试")
	print("========================================")

	# 测试 1: Wait 指令并发执行
	await _test_concurrent_wait()

	# 测试 2: Tween 指令并发执行
	await _test_concurrent_tween()

	# 测试 3: 暂停/恢复功能
	await _test_pause_resume()

	# 打印总结
	_print_summary()

	# 退出测试
	await get_tree().create_timer(0.5).timeout
	get_tree().quit()

## 测试 1: Wait 指令并发执行
func _test_concurrent_wait():
	_test_phase = "ConcurrentWait"
	print("\n[Test 1] Wait 指令并发执行测试")
	print("----------------------------------------")

	_test_results.clear()
	_completed_count = 0
	_start_time = Time.get_ticks_msec() / 1000.0

	# 创建 Wait 指令资源（同一资源被多个实例使用）
	var wait_instruction = Wait.new()
	wait_instruction.wait_time = 0.5

	# 创建三个并发的执行上下文和运行时实例
	var instances: Array[RuntimeInstructionInstance] = []
	for i in range(3):
		var context = ExecutionContext.new()
		context.trigger_node = _test_node

		var instance = RuntimeInstructionInstance.new(wait_instruction, context)
		instances.append(instance)
		instance.finished.connect(_on_test_instance_finished.bind(instance, i))

	# 同时执行所有实例
	print("  启动 3 个并发 Wait 实例（每个等待 0.5 秒）")
	for instance in instances:
		instance.execute_async()

	# 等待所有实例完成（最多 2 秒）
	var timeout_timer = get_tree().create_timer(2.0)
	var check_interval = get_tree().create_timer(0.1)
	while _completed_count < 3 and timeout_timer.time_left > 0:
		await get_tree().create_timer(0.05).timeout

	# 验证结果
	var elapsed = (Time.get_ticks_msec() / 1000.0) - _start_time
	print("  完成数量: %d/3" % _completed_count)
	print("  总耗时: %.2f 秒" % elapsed)

	if _completed_count == 3:
		print("  ✓ 所有实例完成")
		if elapsed < 1.0:
			print("  ✓ 并发执行验证通过（应接近 0.5 秒）")
		else:
			print("  ✗ 并发执行验证失败（可能为串行执行）")
	else:
		print("  ✗ 部分实例未完成")

	# 清理
	for instance in instances:
		if not instance.is_completed():
			instance.cancel()

## 测试 2: Tween 指令并发执行
func _test_concurrent_tween():
	_test_phase = "ConcurrentTween"
	print("\n[Test 2] Tween 指令并发执行测试")
	print("----------------------------------------")

	_test_results.clear()
	_completed_count = 0
	_start_time = Time.get_ticks_msec() / 1000.0

	# 创建测试用的 Control 节点（需要有 modulate 属性）
	var test_controls: Array[Control] = []
	for i in range(3):
		var control = Control.new()
		control.name = "TestControl_%d" % i
		control.modulate = Color.WHITE
		_test_node.add_child(control)
		test_controls.append(control)

	# 创建 TweenColorTransition 指令资源
	var tween_instruction = TweenColorTransition.new()
	tween_instruction.target_color = Color.RED
	tween_instruction.duration = 0.5

	# 创建三个并发的执行上下文和运行时实例
	var instances: Array[RuntimeInstructionInstance] = []
	for i in range(3):
		var context = ExecutionContext.new()
		context.trigger_node = test_controls[i]

		# 设置目标节点为自身
		tween_instruction.target_node = NodePath(".")

		var instance = RuntimeInstructionInstance.new(tween_instruction, context)
		instances.append(instance)
		instance.finished.connect(_on_test_instance_finished.bind(instance, i))

	# 同时执行所有实例
	print("  启动 3 个并发 Tween 实例（每个持续 0.5 秒）")
	for i in range(instances.size()):
		instances[i].execute_async()

	# 等待所有实例完成（最多 2 秒）
	var timeout_timer = get_tree().create_timer(2.0)
	while _completed_count < 3 and timeout_timer.time_left > 0:
		await get_tree().create_timer(0.05).timeout

	# 验证结果
	var elapsed = (Time.get_ticks_msec() / 1000.0) - _start_time
	print("  完成数量: %d/3" % _completed_count)
	print("  总耗时: %.2f 秒" % elapsed)

	# 验证颜色变化
	var all_red = true
	for control in test_controls:
		if not control.modulate.is_equal_approx(Color.RED):
			all_red = false
			break

	if all_red:
		print("  ✓ 所有目标节点颜色正确变化")
	else:
		print("  ✗ 部分目标节点颜色未正确变化")

	# 清理
	for control in test_controls:
		control.queue_free()

	for instance in instances:
		if not instance.is_completed():
			instance.cancel()

## 测试 3: 暂停/恢复功能
func _test_pause_resume():
	_test_phase = "PauseResume"
	print("\n[Test 3] 暂停/恢复功能测试")
	print("----------------------------------------")

	_test_results.clear()
	_completed_count = 0
	_start_time = Time.get_ticks_msec() / 1000.0

	# 创建 Wait 指令
	var wait_instruction = Wait.new()
	wait_instruction.wait_time = 1.0

	var context = ExecutionContext.new()
	context.trigger_node = _test_node

	var instance = RuntimeInstructionInstance.new(wait_instruction, context)
	instance.finished.connect(_on_test_instance_finished.bind(instance, 0))

	# 启动实例
	print("  启动 Wait 实例（1.0 秒）")
	instance.execute_async()

	# 等待 0.3 秒后暂停
	await get_tree().create_timer(0.3).timeout
	print("  暂停实例（已执行 0.3 秒）")
	instance.pause()

	# 等待 0.5 秒（暂停期间）
	await get_tree().create_timer(0.5).timeout
	print("  恢复实例（暂停了 0.5 秒）")
	instance.resume()

	# 等待完成
	var remaining_time = 1.0  # 剩余约 0.7 秒
	var timeout_timer = get_tree().create_timer(remaining_time + 0.5)
	while not instance.is_completed() and timeout_timer.time_left > 0:
		await get_tree().create_timer(0.05).timeout

	var elapsed = (Time.get_ticks_msec() / 1000.0) - _start_time
	print("  总耗时: %.2f 秒（预期约 1.8 秒：0.3 + 0.5暂停 + 0.7剩余）" % elapsed)

	if instance.is_completed():
		print("  ✓ 实例正常完成")
		# 验证总时间（允许 0.2 秒误差）
		if elapsed >= 1.5 and elapsed <= 2.0:
			print("  ✓ 暂停/恢复时间验证通过")
		else:
			print("  ⚠ 暂停/恢复时间可能不准确")
	else:
		print("  ✗ 实例未完成")

## 测试实例完成回调
func _on_test_instance_finished(instance: RuntimeInstructionInstance, index: int):
	_completed_count += 1
	var elapsed = (Time.get_ticks_msec() / 1000.0) - _start_time

	var result = {
		"index": index,
		"completed": instance.is_completed(),
		"has_error": instance.has_error(),
		"elapsed": elapsed
	}
	_test_results.append(result)

	print("  [实例 %d] 完成，耗时: %.2f 秒" % [index, elapsed])

## 打印测试总结
func _print_summary():
	print("\n========================================")
	print("测试总结")
	print("========================================")

	var total_tests = 3
	var passed_tests = 0

	# 简单统计
	if _test_results.size() >= 3:
		passed_tests += 1  # 并发 Wait 测试
	if _test_results.size() >= 6:
		passed_tests += 1  # 并发 Tween 测试
	if _completed_count > 0:
		passed_tests += 1  # 暂停恢复测试

	print("  通过: %d/%d" % [passed_tests, total_tests])
	print("========================================")
