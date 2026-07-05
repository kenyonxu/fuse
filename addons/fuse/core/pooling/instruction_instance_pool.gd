# InstructionInstancePool - RuntimeInstructionInstance 对象池
# Phase 2 性能优化：复用指令实例，避免频繁内存分配
#
# 预期收益：减少 ~25μs 的 RuntimeInstructionInstance.new() 开销

class_name InstructionInstancePool extends RefCounted

## 池配置
var _pool: Array[RuntimeInstructionInstance] = []
var _pool_size: int = 32
var _max_pool_size: int = 128

## 统计信息
var _total_created: int = 0
var _total_reused: int = 0
var _peak_usage: int = 0

## 当前使用中的实例数
var _current_usage: int = 0

## 调试模式
var _enable_debug: bool = false

## 日志级别（用于池化实例的日志）
var _default_log_level: FuseLogger.LogLevel = FuseLogger.LogLevel.INFO

## 构造函数
func _init(initial_size: int = 32, max_size: int = 128):
	_pool_size = clamp(initial_size, 8, max_size)
	_max_pool_size = max_size

## 从池中获取 RuntimeInstructionInstance
##
## 如果池中有可用实例，则复用；否则创建新实例
##
## 参数：
## - instruction: BaseInstruction - 指令定义
## - context: ExecutionContext - 执行上下文
## - runner: RuntimeActionRunnerInstance - 拥有此实例的 ActionRunner
##
## 返回：
## - RuntimeInstructionInstance - 可用的指令实例
func acquire(
	instruction: BaseInstruction,
	context: ExecutionContext,
	runner: RuntimeActionRunnerInstance
) -> RuntimeInstructionInstance:
	var instance: RuntimeInstructionInstance = null

	if not _pool.is_empty():
		# 从池中取出一个实例并重新初始化
		instance = _pool.pop_back()
		instance.reinitialize(instruction, context, runner)
		_total_reused += 1
		_current_usage += 1

		if _enable_debug:
			_log_debug("复用池化实例", {
				"pool_remaining": _pool.size(),
				"total_reused": _total_reused
			})
	else:
		# 池为空，创建新实例
		instance = RuntimeInstructionInstance.new(instruction, context, runner)
		_total_created += 1
		_current_usage += 1

		if _enable_debug:
			_log_debug("创建新实例", {
				"total_created": _total_created,
				"pool_size": _pool.size()
			})

	# 更新峰值使用量
	if _current_usage > _peak_usage:
		_peak_usage = _current_usage

	return instance

## 将 RuntimeInstructionInstance 归还到池中
##
## 重置实例状态并放回池中等待复用
##
## 参数：
## - instance: RuntimeInstructionInstance - 要归还的实例
func release(instance: RuntimeInstructionInstance) -> void:
	if not instance:
		return

	# 重置实例状态以便复用
	instance.reset_for_pool()

	# 检查池是否未满
	if _pool.size() < _max_pool_size:
		_pool.append(instance)

		if _enable_debug:
			_log_debug("归还实例到池", {
				"pool_size": _pool.size(),
				"max_pool_size": _max_pool_size
			})
	else:
		# 池已满，实例将被 GC 回收
		if _enable_debug:
			_log_debug("池已满，实例被丢弃", {
				"pool_size": _pool.size()
			})

	_current_usage = max(0, _current_usage - 1)

## 批量释放多个实例
##
## 参数：
## - instances: Array[RuntimeInstructionInstance] - 要归还的实例数组
func release_all(instances: Array[RuntimeInstructionInstance]) -> void:
	for instance in instances:
		release(instance)

## 预热池
##
## 预先创建指定数量的实例放入池中
##
## 参数：
## - count: int - 要预热的实例数量
func warm_up(count: int) -> void:
	var actual_count = min(count, _pool_size - _pool.size())

	for i in range(actual_count):
		var instance = RuntimeInstructionInstance.new(null, null, null)
		_pool.append(instance)
		_total_created += 1

	if _enable_debug:
		_log_debug("池预热完成", {
			"warm_up_count": actual_count,
			"pool_size": _pool.size()
		})

## 清空池
func clear() -> void:
	_pool.clear()
	_total_created = 0
	_total_reused = 0
	_peak_usage = 0
	_current_usage = 0

	_log_debug("池已清空", {})

## 获取统计信息
func get_statistics() -> Dictionary:
	var reuse_ratio = float(_total_reused) / max(_total_created, 1)

	return {
		"pool_size": _pool.size(),
		"max_pool_size": _max_pool_size,
		"current_usage": _current_usage,
		"total_created": _total_created,
		"total_reused": _total_reused,
		"peak_usage": _peak_usage,
		"reuse_ratio": reuse_ratio,
		"efficiency_score": _calculate_efficiency_score()
	}

## 计算效率评分
func _calculate_efficiency_score() -> float:
	if _total_created == 0:
		return 0.0

	var reuse_ratio = float(_total_reused) / float(_total_created)
	var utilization = float(_current_usage) / max(_pool.size(), 1)

	return reuse_ratio * 0.6 + utilization * 0.4

## 设置调试模式
func set_debug_logging(enabled: bool) -> void:
	_enable_debug = enabled

## 设置默认日志级别
func set_default_log_level(level: FuseLogger.LogLevel) -> void:
	_default_log_level = level

## 日志方法
func _log_debug(message: String, data: Dictionary = {}) -> void:
	if _enable_debug:
		print("[InstructionInstancePool DEBUG] ", message, " ", data)
