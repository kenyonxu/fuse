extends Node

## 验证 FuseThreadingConfig 单例性（B4）

const FuseThreadingConfig = preload("res://addons/fuse/core/threading/fuse_threading_config.gd")

var _fail_count: int = 0

func _ready() -> void:
	_test_get_instance_singleton()
	print("\n=== 结果: %d 处失败 ===" % _fail_count)
	if _fail_count > 0:
		push_error("FuseThreadingConfig 单例测试失败: %d 处" % _fail_count)
	get_tree().quit()

func _check(condition: bool, msg: String) -> void:
	if condition:
		print("  PASS: ", msg)
	else:
		_fail_count += 1
		push_error("  FAIL: ", msg)

func _test_get_instance_singleton() -> void:
	print("\n--- get_instance 返回同一实例 ---")
	var a := FuseThreadingConfig.get_instance()
	var b := FuseThreadingConfig.get_instance()
	_check(a == b, "get_instance() 两次返回同一对象")
	_check(a != null, "get_instance() 非空")
	_check(FuseThreadingConfig.has_instance() == true, "has_instance() == true")
