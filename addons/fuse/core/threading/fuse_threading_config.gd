# addons/fuse/core/threading/fuse_threading_config.gd
## Fuse 多线程配置资源
## 用于全局配置多线程行为
class_name FuseThreadingConfig extends Resource

## 全局开关
@export_group("General")
@export var enable_multithreading: bool = true:
	set(value):
		enable_multithreading = value
		_notify_config_changed("enable_multithreading")

## 并行条件评估
@export_group("Condition Evaluation")
@export var parallel_condition_evaluation: bool = true:
	set(value):
		parallel_condition_evaluation = value
		_notify_config_changed("parallel_condition_evaluation")

@export_range(1, 16) var max_parallel_conditions: int = 8:
	set(value):
		max_parallel_conditions = clampi(value, 1, 16)
		_notify_config_changed("max_parallel_conditions")

@export_range(0.01, 1.0) var timeout_per_condition: float = 0.1:
	set(value):
		timeout_per_condition = clampf(value, 0.01, 1.0)
		_notify_config_changed("timeout_per_condition")

## 变量访问
@export_group("Variable Access")
@export var thread_safe_variables: bool = true:
	set(value):
		thread_safe_variables = value
		_notify_config_changed("thread_safe_variables")

## 异步保存
@export_group("Async Saving")
@export var use_thread_pool_for_saving: bool = true:
	set(value):
		use_thread_pool_for_saving = value
		_notify_config_changed("use_thread_pool_for_saving")

@export_range(0.1, 10.0) var auto_save_delay: float = 1.0:
	set(value):
		auto_save_delay = clampf(value, 0.1, 10.0)
		_notify_config_changed("auto_save_delay")

## 资源预加载
@export_group("Resource Preloading")
@export var enable_resource_preload: bool = true:
	set(value):
		enable_resource_preload = value
		_notify_config_changed("enable_resource_preload")

@export_range(1.0, 30.0) var preload_timeout: float = 5.0:
	set(value):
		preload_timeout = clampf(value, 1.0, 30.0)
		_notify_config_changed("preload_timeout")

## 信号
signal config_changed(key: String, new_value: Variant)

## 单例
static var _instance: FuseThreadingConfig = null

static func get_instance() -> FuseThreadingConfig:
	if _instance == null:
		_instance = FuseThreadingConfig.new()
	return _instance

static func has_instance() -> bool:
	return _instance != null

func _notify_config_changed(key: String) -> void:
	config_changed.emit(key, get(key))

## 获取评估模式
func get_evaluation_mode() -> int:
	if not enable_multithreading or not parallel_condition_evaluation:
		return ParallelConditionEvaluator.EvaluationMode.SEQUENTIAL
	return ParallelConditionEvaluator.EvaluationMode.PARALLEL_SAFE

## 获取调试信息
func get_debug_info() -> Dictionary:
	return {
		"enable_multithreading": enable_multithreading,
		"parallel_condition_evaluation": parallel_condition_evaluation,
		"max_parallel_conditions": max_parallel_conditions,
		"thread_safe_variables": thread_safe_variables,
		"use_thread_pool_for_saving": use_thread_pool_for_saving
	}
