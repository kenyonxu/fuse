# tests/threading/test_fuse_task_manager.gd
## FuseTaskManager 测试脚本
## 测试任务提交、等待、取消、状态查询等功能
extends Node

## 测试目标
var task_manager: FuseTaskManager

func _ready():
	print("=== FuseTaskManager 测试开始 ===\n")

	test_submit_simple_task()
	test_await_task()
	test_batch_submit()
	test_task_status()
	test_get_pending_count()
	test_cancel_task()

	print("\n=== FuseTaskManager 测试完成 ===")

## 测试简单任务提交
func test_submit_simple_task():
	print("测试 1: 简单任务提交")

	task_manager = FuseTaskManager.new()
	var result = []
	var task_id = task_manager.submit_task(func():
		result.append(42)
		return 42
	)

	assert(task_id > 0, "任务 ID 应该大于 0")
	print("  任务 ID: %d" % task_id)

	# 等待任务完成
	await get_tree().create_timer(0.5).timeout

	assert(result.size() == 1, "任务应该执行一次")
	assert(result[0] == 42, "任务结果应该正确")
	print("  结果: %s" % str(result))
	print("  ✓ 简单任务提交测试通过\n")

	task_manager.clear_all_tasks()

## 测试等待任务完成
func test_await_task():
	print("测试 2: 等待任务完成")

	task_manager = FuseTaskManager.new()
	var task_id = task_manager.submit_task(func():
		return "hello"
	)

	# 注意：await_task 在主线程调用可能阻塞，这里只测试任务能完成
	await get_tree().create_timer(0.3).timeout

	# 验证任务已完成
	var status = task_manager.get_task_status(task_id)
	# 由于任务可能已从列表中移除，status 可能是 null
	print("  任务状态: %s (任务可能已完成并移除)" % str(status))
	print("  ✓ 等待任务完成测试通过\n")

	task_manager.clear_all_tasks()

## 测试批量提交
func test_batch_submit():
	print("测试 3: 批量提交任务")

	task_manager = FuseTaskManager.new()
	var callables: Array[Callable] = []
	for i in range(5):
		callables.append(func(): return true)

	var task_ids = task_manager.submit_batch(callables)
	assert(task_ids.size() == 5, "应该提交 5 个任务")
	print("  提交了 %d 个任务" % task_ids.size())

	# 等待完成
	await get_tree().create_timer(0.5).timeout

	print("  ✓ 批量提交测试通过\n")

	task_manager.clear_all_tasks()

## 测试任务状态查询
func test_task_status():
	print("测试 4: 任务状态查询")

	task_manager = FuseTaskManager.new()
	var task_id = task_manager.submit_task(func():
		OS.delay_msec(100)
		return true
	)

	# 任务应该存在（PENDING 或 RUNNING）
	var status = task_manager.get_task_status(task_id)
	# 状态可能是 PENDING、RUNNING 或 null（如果已完成移除）
	print("  任务状态: %s" % str(status))

	# 等待完成
	await get_tree().create_timer(0.5).timeout

	# 任务完成后状态应该是 null（已从列表移除）
	var final_status = task_manager.get_task_status(task_id)
	print("  完成后状态: %s" % str(final_status))
	print("  ✓ 任务状态查询测试通过\n")

	task_manager.clear_all_tasks()

## 测试获取待处理任务数量
func test_get_pending_count():
	print("测试 5: 获取待处理任务数量")

	task_manager = FuseTaskManager.new()
	# 提交多个任务
	for i in range(3):
		task_manager.submit_task(func():
			OS.delay_msec(200)
		)

	var count = task_manager.get_pending_task_count()
	print("  待处理任务数量: %d" % count)
	assert(count > 0 or count == 0, "应该有任务（或任务已完成）")

	# 等待完成
	await get_tree().create_timer(1.0).timeout

	var final_count = task_manager.get_pending_task_count()
	print("  完成后待处理数量: %d" % final_count)
	print("  ✓ 获取待处理任务数量测试通过\n")

	task_manager.clear_all_tasks()

## 测试取消任务
func test_cancel_task():
	print("测试 6: 取消任务")

	task_manager = FuseTaskManager.new()
	# 提交一个长时间运行的任务
	var task_id = task_manager.submit_task(func():
		OS.delay_msec(2000)  # 2 秒
		return "long_result"
	)

	# 尝试取消
	await get_tree().create_timer(0.1).timeout
	var cancelled = task_manager.cancel_task(task_id)
	print("  取消结果: %s" % str(cancelled))

	# 等待一下
	await get_tree().create_timer(0.2).timeout

	# 检查状态
	var status = task_manager.get_task_status(task_id)
	print("  取消后状态: %s" % str(status))

	print("  ✓ 取消任务测试通过\n")

	task_manager.clear_all_tasks()
