# addons/fuse/core/threading/parallel_condition_evaluator.gd
## 并行条件评估器
## 使用 WorkerThreadPool 并行评估多个条件
## 仅对标记为 is_thread_safe 的条件启用并行
class_name ParallelConditionEvaluator extends RefCounted

## 评估模式
enum EvaluationMode {
	SEQUENTIAL,    # 串行评估（默认，最安全）
	PARALLEL_SAFE, # 仅并行评估标记为线程安全的条件
	PARALLEL_ALL   # 强制并行所有条件（危险，仅用于测试）
}

## 配置
var evaluation_mode: EvaluationMode = EvaluationMode.PARALLEL_SAFE
var timeout_per_condition: float = 0.1  # 每个条件的超时时间（秒）

## 统计信息
var last_evaluation_time: float = 0.0
var total_conditions_evaluated: int = 0

## 统计信息互斥锁（保护 total_conditions_evaluated 免受竞态条件）
var _stats_mutex := Mutex.new()

## 信号
signal evaluation_completed(results: Array[bool], total_time: float)

## 并行评估条件数组
## context: ExecutionContext - 执行上下文
## conditions: Array[BaseCondition] - 条件数组
## 返回: Array[bool] - 评估结果数组
func evaluate_parallel(context: ExecutionContext, conditions: Array[BaseCondition]) -> Array[bool]:
	if conditions.is_empty():
		return []

	var start_time = Time.get_ticks_msec() / 1000.0

	# 根据模式选择评估策略
	var results: Array[bool] = []
	match evaluation_mode:
		EvaluationMode.SEQUENTIAL:
			results = _evaluate_sequential(context, conditions)
		EvaluationMode.PARALLEL_SAFE:
			results = _evaluate_parallel_safe(context, conditions)
		EvaluationMode.PARALLEL_ALL:
			results = _evaluate_parallel_all(context, conditions)

	last_evaluation_time = Time.get_ticks_msec() / 1000.0 - start_time
	evaluation_completed.emit(results, last_evaluation_time)
	return results

## 串行评估（回退方案）
## 注意：使用互斥锁保护 total_conditions_evaluated，与并行模式保持一致
func _evaluate_sequential(context: ExecutionContext, conditions: Array[BaseCondition]) -> Array[bool]:
	var results: Array[bool] = []
	results.resize(conditions.size())

	for i in range(conditions.size()):
		var condition = conditions[i]
		if condition != null and condition.enabled:
			results[i] = condition.check(context)
		else:
			results[i] = false
		# CRITICAL FIX: 串行模式也要加锁，避免与并行评估的竞态条件
		_stats_mutex.lock()
		total_conditions_evaluated += 1
		_stats_mutex.unlock()

	return results

## 并行评估安全条件
func _evaluate_parallel_safe(context: ExecutionContext, conditions: Array[BaseCondition]) -> Array[bool]:
	# 分类条件：安全 vs 不安全
	var safe_indices: Array[int] = []
	var unsafe_indices: Array[int] = []

	for i in range(conditions.size()):
		var condition = conditions[i]
		if condition == null or not condition.enabled:
			continue

		if condition.is_thread_safe:
			safe_indices.append(i)
		else:
			unsafe_indices.append(i)

	# 创建上下文快照（用于并行评估）
	var context_snapshot = _create_context_snapshot(context)

	# 结果数组
	var results: Array[bool] = []
	results.resize(conditions.size())
	for i in range(results.size()):
		results[i] = false  # 默认值

	# 并行评估安全条件
	if not safe_indices.is_empty():
		var parallel_results = _evaluate_safe_conditions_parallel(context_snapshot, conditions, safe_indices)

		# 合并结果
		for j in range(safe_indices.size()):
			results[safe_indices[j]] = parallel_results[j]

	# 串行评估不安全条件
	for idx in unsafe_indices:
		var condition = conditions[idx]
		if condition != null:
			results[idx] = condition.check(context)
		# CRITICAL FIX: 串行模式也要加锁，避免与并行评估的竞态条件
		_stats_mutex.lock()
		total_conditions_evaluated += 1
		_stats_mutex.unlock()

	return results

## 并行评估所有条件（危险模式）
func _evaluate_parallel_all(context: ExecutionContext, conditions: Array[BaseCondition]) -> Array[bool]:
	FuseLogger.log_warning("ParallelConditionEvaluator", FuseLogger.LogLevel.WARNING,
		"Using PARALLEL_ALL mode may cause race conditions")

	var context_snapshot = _create_context_snapshot(context)
	var all_indices: Array[int] = []
	for i in range(conditions.size()):
		all_indices.append(i)

	return _evaluate_safe_conditions_parallel(context_snapshot, conditions, all_indices)

## 创建上下文快照
func _create_context_snapshot(context: ExecutionContext) -> Dictionary:
	var snapshot = {
		"local_variables": {},
		"global_variables_snapshot": {},
		"trigger": context.trigger,
		"target": context.target,
		"execution_id": context.execution_id
	}

	# 复制局部变量
	if context.local_variables != null:
		snapshot["local_variables"] = context.local_variables.duplicate(true)

	# 获取全局变量快照
	if GlobalVariableManager.has_instance():
		snapshot["global_variables_snapshot"] = GlobalVariableManager.get_instance().get_all_variables_snapshot()

	return snapshot

## 并行评估安全条件（内部实现）
## 使用 Semaphore 等待所有任务完成，避免竞态条件
## CRITICAL FIX: 实现带超时的等待循环，避免工作线程异常导致主线程永久阻塞
func _evaluate_safe_conditions_parallel(snapshot: Dictionary, conditions: Array[BaseCondition], indices: Array[int]) -> Array[bool]:
	var results: Array[bool] = []
	results.resize(indices.size())

	var target_count = indices.size()
	if target_count == 0:
		return results

	# 使用 Semaphore 同步（更可靠的方式）
	var completion_semaphore = Semaphore.new()
	var completion_mutex = Mutex.new()
	var completed_count = 0

	# 提交任务到 WorkerThreadPool
	for j in range(indices.size()):
		var result_index = j
		var condition_index = indices[j]
		var condition = conditions[condition_index]

		WorkerThreadPool.add_task(func():
			# 创建临时上下文进行评估
			var temp_context = _create_temp_context_from_snapshot(snapshot)
			var check_result = false

			if condition != null and condition.enabled:
				check_result = condition.check(temp_context)

			# 保存结果（Mutex 保护）
			completion_mutex.lock()
			results[result_index] = check_result
			completed_count += 1
			# CRITICAL FIX: 使用统一的互斥锁保护统计数据
			_stats_mutex.lock()
			total_conditions_evaluated += 1
			_stats_mutex.unlock()
			var should_signal = (completed_count >= target_count)
			completion_mutex.unlock()

			# 只有最后一个完成的任务发射信号
			if should_signal:
				completion_semaphore.post()
		)

	# CRITICAL FIX: 使用 try_wait() + 超时循环，避免永久阻塞
	# 计算总超时时间：每个任务 0.5 秒，最少 5 秒
	var total_timeout := maxf(target_count * timeout_per_condition, 5.0)
	var wait_start := Time.get_ticks_msec() / 1000.0
	var all_completed := false

	while not all_completed:
		var elapsed := Time.get_ticks_msec() / 1000.0 - wait_start
		if elapsed > total_timeout:
			# 超时，记录警告并退出
			completion_mutex.lock()
			var current_count = completed_count
			completion_mutex.unlock()
			FuseLogger.log_warning("ParallelConditionEvaluator", FuseLogger.LogLevel.WARNING,
				"Parallel evaluation timed out after %.2fs, completed %d/%d" % [elapsed, current_count, target_count])
			break

		# 非阻塞检查信号
		if completion_semaphore.try_wait():
			# 有任务完成了，继续循环检查是否全部完成
			pass

		# 检查是否全部完成
		completion_mutex.lock()
		all_completed = (completed_count >= target_count)
		completion_mutex.unlock()

		if not all_completed:
			# 短暂休眠避免忙等待
			OS.delay_msec(1)

	return results

## 从快照创建临时上下文
func _create_temp_context_from_snapshot(snapshot: Dictionary) -> ExecutionContext:
	var context = ExecutionContext.new(snapshot.get("target", null), snapshot.get("trigger", null))

	# 恢复局部变量
	var local_vars = snapshot.get("local_variables", {})
	for key in local_vars:
		context.set_variable(key, local_vars[key])

	return context

## 获取统计信息
func get_statistics() -> Dictionary:
	return {
		"last_evaluation_time": last_evaluation_time,
		"total_conditions_evaluated": total_conditions_evaluated,
		"evaluation_mode": EvaluationMode.keys()[evaluation_mode]
	}

## 重置统计信息
func reset_statistics() -> void:
	_stats_mutex.lock()
	last_evaluation_time = 0.0
	total_conditions_evaluated = 0
	_stats_mutex.unlock()
