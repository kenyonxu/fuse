## 性能追踪工具
## 用于定位性能瓶颈的辅助工具
@tool
class_name FusePerformanceTracker
extends RefCounted

## 追踪项数据结构
class TrackItem:
	var name: String = ""
	var start_time: int = 0
	var end_time: int = 0
	var duration_usec: int = 0
	var call_count: int = 0
	var total_duration: int = 0
	var max_duration: int = 0
	var min_duration: int = 9223372036854775807  # INT_MAX

	func start() -> void:
		start_time = Time.get_ticks_usec()

	func stop() -> void:
		end_time = Time.get_ticks_usec()
		duration_usec = end_time - start_time
		call_count += 1
		total_duration += duration_usec
		if duration_usec > max_duration:
			max_duration = duration_usec
		if duration_usec < min_duration:
			min_duration = duration_usec

	func get_avg_duration() -> float:
		if call_count == 0:
			return 0.0
		return float(total_duration) / float(call_count)

	func get_report() -> String:
		return "%s: calls=%d, avg=%.2fμs, min=%dμs, max=%dμs, total=%.2fms" % [
			name, call_count, get_avg_duration(), min_duration, max_duration,
			float(total_duration) / 1000.0
		]

## 追踪项字典
var _track_items: Dictionary = {}

## 是否启用追踪
var enabled: bool = true

## 日志级别（保留用于扩展，当前只有统计报告输出）
var log_level: int = 0  # 0=off, 1=summary, 2=verbose（verbose已禁用）

## 单例实例
static var _instance: FusePerformanceTracker = null

static func get_instance() -> FusePerformanceTracker:
	if _instance == null:
		_instance = FusePerformanceTracker.new()
	return _instance

## 开始追踪
func start_track(name: String) -> void:
	if not enabled:
		return

	var item: TrackItem
	if _track_items.has(name):
		item = _track_items[name]
	else:
		item = TrackItem.new()
		item.name = name
		_track_items[name] = item

	item.start()

## 停止追踪
func stop_track(name: String) -> void:
	if not enabled:
		return

	if _track_items.has(name):
		var item = _track_items[name]
		item.stop()
		# 实时输出已禁用，使用 print_report() 查看统计

## 生成报告
func generate_report() -> String:
	var lines: Array[String] = []
	lines.append("=== Performance Tracker Report ===")
	lines.append("")

	# 按总时间排序
	var sorted_items = _track_items.values()
	sorted_items.sort_custom(func(a, b): return a.total_duration > b.total_duration)

	for item in sorted_items:
		lines.append(item.get_report())

	lines.append("")
	lines.append("=== System Stats ===")
	lines.append("FPS: %d" % Performance.get_monitor(Performance.TIME_FPS))
	lines.append("Process Time: %.2fms" % (Performance.get_monitor(Performance.TIME_PROCESS) * 1000))
	lines.append("Physics Time: %.2fms" % (Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000))
	lines.append("Node Count: %d" % Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	lines.append("Object Count: %d" % Performance.get_monitor(Performance.OBJECT_COUNT))
	lines.append("Memory: %.2fMB" % (Performance.get_monitor(Performance.MEMORY_STATIC) / 1024.0 / 1024.0))
	lines.append("")
	lines.append("=== Object Pool Stats ===")
	# 添加池状态信息
	var pool_stats = FusePoolManager.get_instance().get_detailed_status()
	var pool_stats_dict = pool_stats.get("pool_statistics", {})
	if pool_stats_dict.is_empty():
		lines.append("No active pools")
	else:
		for pool_path in pool_stats_dict.keys():
			var stats = pool_stats_dict[pool_path]
			var pool_name = pool_path.get_file().get_basename() if pool_path.contains("/") else pool_path
			var unused = stats.get("unused_count", 0) if stats.has("unused_count") else 0
			var in_use = stats.get("current_usage", 0) if stats.has("current_usage") else 0
			var pool_size = stats.get("pool_size", 0) if stats.has("pool_size") else 0
			var reused = stats.get("total_reused", 0) if stats.has("total_reused") else 0
			var created = stats.get("total_created", 0) if stats.has("total_created") else 0
			lines.append("%s: unused=%d, in_use=%d, pool_size=%d, reused=%d, created=%d" % [pool_name, unused, in_use, pool_size, reused, created])

	return "\n".join(lines)

## 打印报告
func print_report() -> void:
	print(generate_report())

## 重置追踪数据
func reset() -> void:
	_track_items.clear()

## 获取追踪项
func get_track_item(name: String) -> TrackItem:
	return _track_items.get(name, null)


## ============================================================
## 便捷方法
## ============================================================

## 追踪一个函数调用的执行时间
static func track_call(name: String, callable: Callable) -> Variant:
	var tracker = get_instance()
	tracker.start_track(name)
	var result = callable.call()
	tracker.stop_track(name)
	return result

## 追踪一个异步协程的执行时间
static func track_coroutine(name: String, coroutine: Callable) -> void:
	var tracker = get_instance()
	tracker.start_track(name)
	await coroutine.call()
	tracker.stop_track(name)
