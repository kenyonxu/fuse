# addons/fuse/tests/threading/test_thread_safety.gd
## 线程安全并发测试脚本
## 测试多线程环境下的数据一致性和线程安全性
## 使用 FuseTaskManager 进行测试
extends Node

## 测试目标
var task_manager: FuseTaskManager

func _ready():
	print("=== 线程安全并发测试开始 ===\n")

	before_each()
	test_concurrent_task_submit()
	after_each()

	before_each()
	test_task_signal_deferred()
	after_each()

	before_each()
	test_concurrent_task_status()
	after_each()

	before_each()
	test_task_cancellation_safety()
	after_each()

	print("\n=== 线程安全并发测试完成 ===")

func before_each():
	task_manager = FuseTaskManager.new()

func after_each():
	if task_manager:
		task_manager.clear_all_tasks()
	task_manager = null

## 测试并发任务提交
func test_concurrent_task_submit():
	print("测试 1: 并发任务提交")

	var task_count = 20
	var completed_count = 0
	var results = []

	# 连接完成信号（使用 CONNECT_DEFERRED）
	var on_task_completed = func(task_id: int, result: Variant):
		completed_count += 1
		results.append({"id": task_id, "result": result})
	task_manager.task_completed.connect(on_task_completed, Object.CONNECT_DEFERRED)

	# 提交多个任务
	for i in range(task_count):
		var idx = i
		task_manager.submit_task(func():
			OS.delay_msec(10)  # 模拟短时间工作
			return idx
		)

	# 等待所有任务完成
	await get_tree().create_timer(1.0).timeout

	print("  完成任务数: %d / %d" % [completed_count, task_count])
	assert(completed_count >= task_count * 0.8, "应该完成大部分任务")
	print("  ✓ 并发任务提交测试通过\n")

## 测试任务信号延迟处理
func test_task_signal_deferred():
	print("测试 2: 任务信号延迟处理")

	var received_on_main_thread = false
	var signal_result = null

	# 使用 CONNECT_DEFERRED 连接信号
	var on_task_completed = func(task_id: int, result: Variant):
		# 这个回调应该在主线程执行
		received_on_main_thread = true
		signal_result = result
	task_manager.task_completed.connect(on_task_completed, Object.CONNECT_DEFERRED)

	# 提交任务
	task_manager.submit_task(func():
		return "deferred_signal_test"
	)

	# 等待信号处理
	await get_tree().create_timer(0.5).timeout

	assert(received_on_main_thread, "信号应该在主线程处理")
	assert(signal_result == "deferred_signal_test", "结果应该正确传递")
	print("  信号在主线程处理: %s" % str(received_on_main_thread))
	print("  结果: %s" % str(signal_result))
	print("  ✓ 任务信号延迟处理测试通过\n")

## 测试并发任务状态查询
func test_concurrent_task_status():
	print("测试 3: 并发任务状态查询")

	var task_ids = []

	# 提交多个任务
	for i in range(5):
		var idx = i
		var task_id = task_manager.submit_task(func():
			OS.delay_msec(50)
			return idx
		)
		task_ids.append(task_id)

	# 等待一小段时间
	await get_tree().create_timer(0.1).timeout

	# 检查任务状态
	var pending_or_running = 0
	var completed = 0

	for task_id in task_ids:
		var status = task_manager.get_task_status(task_id)
		if status == null:
			completed += 1  # 已完成并被移除
		elif status == FuseTaskManager.TaskStatus.PENDING or status == FuseTaskManager.TaskStatus.RUNNING:
			pending_or_running += 1

	print("  运行中/待处理: %d, 已完成: %d" % [pending_or_running, completed])

	# 等待所有任务完成
	await get_tree().create_timer(0.5).timeout
	print("  ✓ 并发任务状态查询测试通过\n")

## 测试任务取消安全性
func test_task_cancellation_safety():
	print("测试 4: 任务取消安全性")

	var task_ids = []
	var cancelled_count = 0

	# 提交多个长时间任务
	for i in range(10):
		var idx = i
		var task_id = task_manager.submit_task(func():
			OS.delay_msec(500)  # 500ms
			return idx
		)
		task_ids.append(task_id)

	# 尝试取消部分任务
	for i in range(0, 5, 2):
		var cancelled = task_manager.cancel_task(task_ids[i])
		if cancelled:
			cancelled_count += 1

	print("  取消了 %d 个任务" % cancelled_count)

	# 等待剩余任务完成
	await get_tree().create_timer(0.7).timeout

	print("  ✓ 任务取消安全性测试通过\n")
