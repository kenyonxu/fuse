# addons/fuse/core/threading/fuse_task_manager.gd
## Fuse 任务管理器
## 封装 WorkerThreadPool 提供统一的异步任务接口
##
## ⚠️ 重要：信号发射是线程安全的，但调用者应使用 CONNECT_DEFERRED 连接
## 示例：task_manager.task_completed.connect(_on_task_completed, Callable.CONNECT_DEFERRED)
class_name FuseTaskManager extends RefCounted

## 单例实例（静态初始化，避免竞态条件）
static var _instance: FuseTaskManager = FuseTaskManager.new()

## 任务状态
enum TaskStatus {
	PENDING,    ## 等待执行
	RUNNING,    ## 正在执行
	COMPLETED,  ## 已完成
	FAILED,     ## 执行失败
	CANCELED    ## 已取消
}

## 任务信息
class TaskInfo extends RefCounted:
	var id: int = 0
	var status: TaskStatus = TaskStatus.PENDING
	var callable: Callable
	var start_time: float = 0.0
	var end_time: float = 0.0
	var result: Variant = null
	var error: String = ""

## 任务跟踪
var _tasks: Dictionary = {}  # task_id -> TaskInfo
var _task_counter: int = 0
var _task_mutex: Mutex = Mutex.new()

## 完成信号队列（用于主线程发射）
var _pending_completions: Array[Dictionary] = []
var _completion_mutex: Mutex = Mutex.new()

## 信号 - 注意：调用者应使用 CONNECT_DEFERRED 连接
signal task_completed(task_id: int, result: Variant)
signal task_failed(task_id: int, error: String)

## 获取单例
static func get_instance() -> FuseTaskManager:
	return _instance

## 检查是否有实例
static func has_instance() -> bool:
	return true  # 静态初始化后始终存在

## 提交异步任务
## 返回任务 ID，可用于跟踪
func submit_task(callable: Callable, high_priority: bool = false) -> int:
	# 创建任务信息
	_task_mutex.lock()
	_task_counter += 1
	var task_id = _task_counter
	var task_info = TaskInfo.new()
	task_info.id = task_id
	task_info.callable = callable
	task_info.status = TaskStatus.PENDING
	task_info.start_time = Time.get_ticks_msec() / 1000.0
	_tasks[task_id] = task_info
	_task_mutex.unlock()

	# 提交到 WorkerThreadPool
	WorkerThreadPool.add_task(
		_execute_task.bind(task_id),
		high_priority
	)

	return task_id

## 执行任务（内部方法，在工作线程中运行）
func _execute_task(task_id: int) -> void:
	var task_info: TaskInfo = null

	# 获取任务信息
	_task_mutex.lock()
	if _tasks.has(task_id):
		task_info = _tasks[task_id]
		# 执行前检查是否已取消
		if task_info.status == TaskStatus.CANCELED:
			_task_mutex.unlock()
			return  # 任务已取消，直接返回
		task_info.status = TaskStatus.RUNNING
	_task_mutex.unlock()

	if task_info == null:
		return

	# 执行任务
	var success = true
	var result: Variant = null
	var error_msg = ""

	if task_info.callable.is_valid():
		var call_result = task_info.callable.call()
		if call_result is Array and call_result.size() > 0:
			result = call_result[0]
		else:
			result = call_result
	else:
		success = false
		error_msg = "Callable is invalid"

	# 更新任务状态
	_task_mutex.lock()
	# 执行后再次检查取消状态
	if task_info.status == TaskStatus.CANCELED:
		_task_mutex.unlock()
		return  # 任务被取消，不删除任务，让 cancel_task() 的调用者知道状态

	if success:
		task_info.status = TaskStatus.COMPLETED
		task_info.result = result
	else:
		task_info.status = TaskStatus.FAILED
		task_info.error = error_msg
	task_info.end_time = Time.get_ticks_msec() / 1000.0
	_task_mutex.unlock()

	# 将完成信息加入队列（线程安全）
	_completion_mutex.lock()
	_pending_completions.append({
		"task_id": task_id,
		"success": success,
		"result": result,
		"error": error_msg
	})
	_completion_mutex.unlock()

	# 直接发射信号（GDScript 信号发射是线程安全的）
	# 但接收者需要使用 CONNECT_DEFERRED 来确保在主线程处理
	if success:
		task_completed.emit(task_id, result)
	else:
		task_failed.emit(task_id, error_msg)

	# 清理任务
	_task_mutex.lock()
	_tasks.erase(task_id)
	_task_mutex.unlock()

## 处理待处理的完成通知（可选，用于需要主线程处理的场景）
func process_completions() -> void:
	_completion_mutex.lock()
	var completions = _pending_completions.duplicate()
	_pending_completions.clear()
	_completion_mutex.unlock()

	_log_debug("Processed %d task completions" % completions.size())

## 记录调试日志
func _log_debug(message: String) -> void:
	FuseLogger.log_debug("FuseTaskManager", FuseLogger.LogLevel.DEBUG, message, "")

## 获取任务状态
## 返回 Variant：TaskStatus 或 null（任务不存在）
func get_task_status(task_id: int) -> Variant:
	_task_mutex.lock()
	var status: Variant = null  # null 表示任务不存在
	if _tasks.has(task_id):
		status = _tasks[task_id].status
	_task_mutex.unlock()
	return status

## 等待任务完成
## 返回任务结果，超时返回 null
## ⚠️ 此方法会在当前线程阻塞，不要在主线程使用
func await_task(task_id: int, timeout: float = 5.0) -> Variant:
	var start_time = Time.get_ticks_msec() / 1000.0

	while true:
		_task_mutex.lock()
		var has_task = _tasks.has(task_id)
		var result: Variant = null
		var status = TaskStatus.PENDING
		if has_task:
			status = _tasks[task_id].status
			result = _tasks[task_id].result
		_task_mutex.unlock()

		if not has_task or status == TaskStatus.COMPLETED:
			return result

		if status == TaskStatus.FAILED:
			return null

		# 检查超时
		if Time.get_ticks_msec() / 1000.0 - start_time > timeout:
			return null

		# 短暂等待
		OS.delay_msec(10)

	return null

## 等待任务完成（await_task 的别名）
## 返回任务结果，超时返回 null
## ⚠️ 此方法会在当前线程阻塞，不要在主线程使用
func wait_for_task(task_id: int, timeout: float = 5.0) -> Variant:
	return await_task(task_id, timeout)

## 取消任务
## 返回 true 表示成功取消，false 表示任务不存在或已完成
## 注意：已经开始执行的 RUNNING 任务无法真正中断，只能标记为取消
func cancel_task(task_id: int) -> bool:
	_task_mutex.lock()
	var has_task = _tasks.has(task_id)
	var can_cancel = false
	var task_info: TaskInfo = null

	if has_task:
		task_info = _tasks[task_id]
		var current_status = task_info.status
		# 只有 PENDING 或 RUNNING 状态的任务可以取消
		if current_status == TaskStatus.PENDING or current_status == TaskStatus.RUNNING:
			can_cancel = true
			task_info.status = TaskStatus.CANCELED
			task_info.end_time = Time.get_ticks_msec() / 1000.0
			task_info.error = "Task canceled by user"

	_task_mutex.unlock()

	return can_cancel

## 批量提交任务
## 返回任务 ID 数组
func submit_batch(callables: Array[Callable], high_priority: bool = false) -> Array[int]:
	var task_ids: Array[int] = []
	for callable in callables:
		task_ids.append(submit_task(callable, high_priority))
	return task_ids

## 等待所有任务完成
## 返回结果字典 {task_id: result}
func await_all(task_ids: Array[int], timeout: float = 30.0) -> Dictionary:
	var results = {}
	var start_time = Time.get_ticks_msec() / 1000.0

	for task_id in task_ids:
		var remaining_time = timeout - (Time.get_ticks_msec() / 1000.0 - start_time)
		if remaining_time <= 0:
			results[task_id] = {"error": "timeout"}
		else:
			var result = await_task(task_id, remaining_time)
			results[task_id] = {"result": result}

	return results

## 获取待处理任务数量
func get_pending_task_count() -> int:
	_task_mutex.lock()
	var count = _tasks.size()
	_task_mutex.unlock()
	return count

## 清理所有任务（慎用）
func clear_all_tasks() -> void:
	_task_mutex.lock()
	_tasks.clear()
	_task_mutex.unlock()

	_completion_mutex.lock()
	_pending_completions.clear()
	_completion_mutex.unlock()
