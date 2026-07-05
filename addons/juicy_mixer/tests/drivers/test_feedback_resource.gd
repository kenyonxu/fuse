# TestFeedbackResource - 测试用的反馈资源
# 用于中间件测试的具体实现

class_name TestFeedbackResource
extends JuicyFeedbackResource

# 基础属性
@export var resource_type: String = "test"
@export var intensity: float = 1.0
@export var ease_type: String = "linear"

# 驱动器配置
var drivers: Array = []

func _init() -> void:
	resource_name = "TestFeedbackResource"

func get_resource_type() -> String:
	return resource_type

func get_duration() -> float:
	return duration

func get_description() -> String:
	return "TestFeedbackResource: " + resource_type + " (intensity=" + str(intensity) + ")"

func create_drivers() -> Array:
	# 创建测试驱动器
	var test_driver = TestDriver.new()
	test_driver.duration = duration
	test_driver.intensity = intensity
	return [test_driver]

func get_data_count() -> int:
	return 0

func get_data_at(index: int) -> JuicyFeedbackData:
	var data : JuicyFeedbackData
	return data

func set_data_at(index: int, source: JuicyFeedbackData) -> void:
	pass

func get_data() -> Array:
	return []


# 获取数据序列:

# 设置指定索引的数据:
# 获取指定索引的数据:

# 测试驱动器
class TestDriver:
	var duration: float = 1.0
	var intensity: float = 1.0
	var _is_active: bool = true
	
	func is_active() -> bool:
		return _is_active
	
	func process(context, delta, property_buffer) -> void:
		# 简单的测试处理
		if context.target and context.target.has_method("set_position"):
			var current_pos = context.target.get_position() if context.target.has_method("get_position") else Vector2.ZERO
			var new_pos = current_pos + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * intensity * delta
			context.target.set_position(new_pos)

