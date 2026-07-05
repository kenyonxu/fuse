# FuseRecycleTimer - Fuse 专用回收定时器
##
## 用于解决对象池回收定时器与指令生命周期解耦的问题。
## 继承自 Node，确保生命周期由 Godot 管理。

class_name FuseRecycleTimer
extends Node

## 场景路径
var scene_path: String = ""

## 要回收的实例（使用弱引用避免循环引用）
var _instance_weak_ref: WeakRef = null

## 🔧 新增：创建时的 usage_count（用于检测对象是否被复用）
var _creation_usage_count: int = -1

## 定时器引用
var _timer: SceneTreeTimer = null

## 是否已触发
var _triggered: bool = false

## 调试标志
var _debug_enabled: bool = false

## 创建回收定时器
##
## 参数：
## - scene_path: 场景路径
## - instance: 要回收的实例节点
## - delay: 延迟时间（秒）
##
## 返回：
## - FuseRecycleTimer: 创建的定时器实例，如果失败返回 null
static func create(scene_path: String, instance: Node, delay: float) -> FuseRecycleTimer:
	if scene_path.is_empty() or not instance:
		push_error("[FuseRecycleTimer] 参数无效: scene_path=%s, instance=%s" % [scene_path, instance])
		return null

	# 创建为临时节点，不需要添加到场景树
	var timer = FuseRecycleTimer.new()
	timer.name = "FuseRecycleTimer_" + str(Time.get_ticks_msec())
	timer.scene_path = scene_path
	timer._instance_weak_ref = weakref(instance)

	# 🔧 新增：记录创建时的 usage_count
	var pool_manager = FusePoolManager.get_instance()
	if pool_manager:
		timer._creation_usage_count = pool_manager.get_instance_usage_count(scene_path, instance)

	# 注册到池管理器，防止被提前释放
	if pool_manager:
		pool_manager.register_recycle_timer(timer)

	timer._setup_timer(delay)

	return timer

## 设置定时器
func _setup_timer(delay: float) -> void:
	var scene_tree = Engine.get_main_loop()
	if not scene_tree:
		push_error("[FuseRecycleTimer] 无法获取 SceneTree")
		return

	_timer = scene_tree.create_timer(delay)
	if _timer == null:
		push_error("[FuseRecycleTimer] create_timer 返回 null")
		return

	_timer.timeout.connect(_on_timeout)
	_log_debug("定时器创建成功，延迟: %s 秒" % delay)

## 超时回调
func _on_timeout() -> void:
	if _triggered:
		return

	_triggered = true

	# 获取实例
	var instance = _instance_weak_ref.get_ref()
	if instance == null:
		_cleanup_and_remove()
		return

	# 检查实例是否仍然有效
	if not is_instance_valid(instance):
		_cleanup_and_remove()
		return

	var pool_manager = FusePoolManager.get_instance()

	# 检查 usage_count 是否匹配
	# 如果 usage_count 不匹配，说明对象已被回收并复用
	if pool_manager and _creation_usage_count >= 0:
		var current_usage_count = pool_manager.get_instance_usage_count(scene_path, instance)
		if current_usage_count != _creation_usage_count:
			_cleanup_and_remove()
			return

	# 检查实例是否在场景树中
	# 当实例被其他方式回收时，它会从场景树移除
	if not instance.is_inside_tree():
		_cleanup_and_remove()
		return

	# 检查实例是否在池中被标记为"未使用"
	# 由于 return_object() 会立即标记为未使用，但延迟从场景树移除
	if pool_manager and pool_manager.is_instance_in_use(scene_path, instance) == false:
		_cleanup_and_remove()
		return

	# 调用池管理器回收
	if pool_manager:
		pool_manager.recycle_pooled(scene_path, instance)
		pool_manager.unregister_recycle_timer(self)
	else:
		push_error("[FuseRecycleTimer] 池管理器获取失败")

	_cleanup_and_remove()

## 取消定时器
func cancel() -> void:
	if _timer and not _triggered:
		if _timer.timeout.is_connected(_on_timeout):
			_timer.timeout.disconnect(_on_timeout)
		_timer = null
	_triggered = true

	# 从池管理器中注销
	var pool_manager = FusePoolManager.get_instance()
	if pool_manager:
		pool_manager.unregister_recycle_timer(self)

## 清理并移除节点
func _cleanup_and_remove() -> void:
	cancel()
	# 移除自身
	if get_parent():
		get_parent().remove_child(self)
	queue_free()

## 日志方法
func _log_debug(message: String) -> void:
	if _debug_enabled:
		print("[FuseRecycleTimer DEBUG] ", message)
