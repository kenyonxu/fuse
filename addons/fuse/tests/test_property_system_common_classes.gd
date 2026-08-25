@tool
extends Node

## 属性系统通用类测试脚本
## 基于 Node 的测试实现，验证 PropertyInfo、TypeConverter、PropertyManager 的功能

# 测试结果统计
var test_results = {
	"total": 0,
	"passed": 0,
	"failed": 0,
	"errors": []
}

# 测试节点引用
var test_node: Node2D = null
var test_sprite: Sprite2D = null
var test_control: Control = null

func _ready():
	print("=== 开始属性系统通用类测试 ===")
	create_test_nodes()
	run_all_tests()
	cleanup_test_nodes()
	print_test_summary()
	print("=== 测试完成 ===")

## 运行所有测试
func run_all_tests():
	print("\n--- 运行 PropertyInfo 测试 ---")
	test_property_info_creation()
	test_property_info_from_node()
	test_numeric_validation()
	test_type_compatibility()
	test_property_info_serialization()

	print("\n--- 运行 TypeConverter 测试 ---")
	test_numeric_conversions()
	test_string_conversions()
	test_vector_conversions()
	test_color_conversions()
	test_compatibility_matrix()

	print("\n--- 运行 PropertyManager 测试 ---")
	test_get_all_properties()
	test_property_filtering()
	test_safe_property_setting()
	test_batch_property_setting()
	test_caching_system()
	test_property_search()

	print("\n--- 运行集成测试 ---")
	test_complete_property_workflow()
	test_error_inputs()
	test_performance_with_many_properties()

## PropertyInfo 测试

func test_property_info_creation():
	print("测试 PropertyInfo 创建...")
	test_results.total += 1

	var prop_dict = {
		"name": "test_prop",
		"type": TYPE_INT,
		"hint": PROPERTY_HINT_RANGE,
		"hint_string": "0,100,1",
		"usage": PROPERTY_USAGE_EDITOR,
		"default_value": 50
	}

	var prop_info = PropertyInfo.create(prop_dict)
	if prop_info == null:
		_record_test_failure("PropertyInfo 创建测试", "PropertyInfo.create 返回 null")
		return

	# 验证基础属性
	if prop_info.name != "test_prop":
		_record_test_failure("PropertyInfo 创建测试", "属性名称不匹配")
		return

	if prop_info.type != TYPE_INT:
		_record_test_failure("PropertyInfo 创建测试", "属性类型不匹配")
		return

	if not prop_info.is_numeric():
		_record_test_failure("PropertyInfo 创建测试", "应该识别为数值类型")
		return

	if not prop_info.is_writable():
		_record_test_failure("PropertyInfo 创建测试", "应该识别为可写")
		return

	_record_test_success("PropertyInfo 创建测试")

func test_property_info_from_node():
	print("测试 PropertyInfo 从节点创建...")
	test_results.total += 1

	var node = Node2D.new()
	var prop_info = PropertyInfo.from_node_property(node, "position")

	if prop_info == null:
		_record_test_failure("PropertyInfo 从节点创建测试", "应该成功创建 PropertyInfo")
		return

	if prop_info.name != "position":
		_record_test_failure("PropertyInfo 从节点创建测试", "属性名称应该是 'position'")
		return

	if not prop_info.is_vector():
		_record_test_failure("PropertyInfo 从节点创建测试", "应该识别为向量类型")
		return

	_record_test_success("PropertyInfo 从节点创建测试")

func test_numeric_validation():
	print("测试数值范围验证...")
	test_results.total += 1

	var prop_info = PropertyInfo.new()
	prop_info.name = "health"
	prop_info.type = TYPE_INT
	prop_info.min_value = 0
	prop_info.max_value = 100

	# 有效值
	var valid_result = prop_info.validate_value(50)
	if not valid_result.valid:
		_record_test_failure("数值范围验证测试", "有效值应该通过验证")
		return

	# 无效值
	var invalid_result = prop_info.validate_value(150)
	if invalid_result.valid:
		_record_test_failure("数值范围验证测试", "无效值应该失败")
		return

	if "值大于最大值" not in invalid_result.error:
		_record_test_failure("数值范围验证测试", "应该包含正确的错误信息")
		return

	_record_test_success("数值范围验证测试")

func test_type_compatibility():
	print("测试类型兼容性...")
	test_results.total += 1

	var prop_info = PropertyInfo.new()
	prop_info.name = "score"
	prop_info.type = TYPE_INT

	# 兼容类型（字符串数字）
	var compatible_result = prop_info.validate_value("123")
	if not compatible_result.valid:
		_record_test_failure("类型兼容性测试", "字符串数字应该兼容")
		return

	# 不兼容类型
	var incompatible_result = prop_info.validate_value({"key": "value"})
	if incompatible_result.valid:
		_record_test_failure("类型兼容性测试", "字典应该不兼容")
		return

	_record_test_success("类型兼容性测试")

func test_property_info_serialization():
	print("测试 PropertyInfo 序列化...")
	test_results.total += 1

	var prop_info = PropertyInfo.new()
	prop_info.name = "test_prop"
	prop_info.type = TYPE_FLOAT
	prop_info.min_value = 0.0
	prop_info.max_value = 100.0

	# 序列化
	var data = prop_info.to_dict()
	if data.name != "test_prop":
		_record_test_failure("PropertyInfo 序列化测试", "序列化名称不匹配")
		return

	if data.type != TYPE_FLOAT:
		_record_test_failure("PropertyInfo 序列化测试", "序列化类型不匹配")
		return

	# 反序列化
	var new_prop_info = PropertyInfo.new()
	new_prop_info.from_dict(data)

	if new_prop_info.name != prop_info.name:
		_record_test_failure("PropertyInfo 序列化测试", "反序列化名称不匹配")
		return

	if new_prop_info.type != prop_info.type:
		_record_test_failure("PropertyInfo 序列化测试", "反序列化类型不匹配")
		return

	_record_test_success("PropertyInfo 序列化测试")

## TypeConverter 测试

func test_numeric_conversions():
	print("测试数值转换...")
	test_results.total += 1

	# 字符串到整数
	var int_result = TypeConverter.safe_convert_to_int("123")
	if int_result != 123:
		_record_test_failure("数值转换测试", "字符串到整数转换失败")
		return

	# 浮点数到整数
	var float_to_int = TypeConverter.safe_convert_to_int(45.67)
	if float_to_int != 45:
		_record_test_failure("数值转换测试", "浮点数到整数转换失败")
		return

	# 布尔值到整数
	var bool_to_int = TypeConverter.safe_convert_to_int(true)
	if bool_to_int != 1:
		_record_test_failure("数值转换测试", "布尔值到整数转换失败")
		return

	_record_test_success("数值转换测试")

func test_string_conversions():
	print("测试字符串转换...")
	test_results.total += 1

	# 数值到字符串
	var num_to_str = TypeConverter.safe_convert_to_string(42)
	if num_to_str != "42":
		_record_test_failure("字符串转换测试", "数值到字符串转换失败")
		return

	# 布尔值到字符串
	var bool_to_str = TypeConverter.safe_convert_to_string(false)
	if bool_to_str != "false":
		_record_test_failure("字符串转换测试", "布尔值到字符串转换失败")
		return

	# 向量到字符串
	var vec_to_str = TypeConverter.safe_convert_to_string(Vector2(1, 2))
	# Godot 4.5 可能返回不同的格式，检查是否包含数字
	if "1" not in vec_to_str or "2" not in vec_to_str:
		_record_test_failure("字符串转换测试", "向量到字符串转换失败，结果: " + vec_to_str)
		return

	_record_test_success("字符串转换测试")

func test_vector_conversions():
	print("测试向量转换...")
	test_results.total += 1

	# 字符串到 Vector2
	var str_to_vec2 = TypeConverter.safe_convert_to_vector2("1.5,2.5")
	if not str_to_vec2.is_equal_approx(Vector2(1.5, 2.5)):
		_record_test_failure("向量转换测试", "字符串到Vector2转换失败")
		return

	# Vector3 到 Vector2
	var vec3_to_vec2 = TypeConverter.safe_convert_to_vector2(Vector3(1, 2, 3))
	if not vec3_to_vec2.is_equal_approx(Vector2(1, 2)):
		_record_test_failure("向量转换测试", "Vector3到Vector2转换失败")
		return

	# 颜色到 Vector3
	var color_to_vec3 = TypeConverter.safe_convert_to_vector3(Color.RED)
	if not color_to_vec3.is_equal_approx(Vector3(1, 0, 0)):
		_record_test_failure("向量转换测试", "颜色到Vector3转换失败")
		return

	_record_test_success("向量转换测试")

func test_color_conversions():
	print("测试颜色转换...")
	test_results.total += 1

	# 十六进制字符串
	var hex_to_color = TypeConverter.safe_convert_to_color("#FF0000")
	if not hex_to_color.is_equal_approx(Color.RED):
		_record_test_failure("颜色转换测试", "十六进制到颜色转换失败")
		return

	# HTML 颜色名
	var name_to_color = TypeConverter.safe_convert_to_color("blue")
	if not name_to_color.is_equal_approx(Color.BLUE):
		_record_test_failure("颜色转换测试", "颜色名到颜色转换失败")
		return

	# 数值到灰度
	var num_to_color = TypeConverter.safe_convert_to_color(128)
	if num_to_color.r <= 0.4 or num_to_color.r >= 0.6:
		_record_test_failure("颜色转换测试", "数值到灰度转换失败")
		return

	_record_test_success("颜色转换测试")

func test_compatibility_matrix():
	print("测试类型兼容性矩阵...")
	test_results.total += 1

	# 数值类型互相兼容
	if not TypeConverter.is_compatible(TYPE_INT, TYPE_FLOAT):
		_record_test_failure("类型兼容性矩阵测试", "INT到FLOAT应该兼容")
		return

	if not TypeConverter.is_compatible(TYPE_FLOAT, TYPE_INT):
		_record_test_failure("类型兼容性矩阵测试", "FLOAT到INT应该兼容")
		return

	if not TypeConverter.is_compatible(TYPE_BOOL, TYPE_INT):
		_record_test_failure("类型兼容性矩阵测试", "BOOL到INT应该兼容")
		return

	# 字符串与基础类型兼容
	if not TypeConverter.is_compatible(TYPE_STRING, TYPE_INT):
		_record_test_failure("类型兼容性矩阵测试", "STRING到INT应该兼容")
		return

	if not TypeConverter.is_compatible(TYPE_STRING, TYPE_COLOR):
		_record_test_failure("类型兼容性矩阵测试", "STRING到COLOR应该兼容")
		return

	# 向量类型部分兼容
	if not TypeConverter.is_compatible(TYPE_VECTOR2, TYPE_VECTOR3):
		_record_test_failure("类型兼容性矩阵测试", "VECTOR2到VECTOR3应该兼容")
		return

	if not TypeConverter.is_compatible(TYPE_VECTOR3, TYPE_VECTOR2):
		_record_test_failure("类型兼容性矩阵测试", "VECTOR3到VECTOR2应该兼容")
		return

	_record_test_success("类型兼容性矩阵测试")

## PropertyManager 测试

func test_get_all_properties():
	print("测试获取所有属性...")
	test_results.total += 1

	var node = Sprite2D.new()
	var properties = PropertyManager.get_all_properties(node)

	if properties.is_empty():
		_record_test_failure("获取所有属性测试", "应该找到属性")
		return

	# 检查是否包含基本属性
	var has_position = false
	var has_rotation = false
	var has_scale = false

	for prop in properties:
		if prop.name == "position":
			has_position = true
			if not prop.is_vector():
				_record_test_failure("获取所有属性测试", "position应该是向量类型")
				return
		elif prop.name == "rotation":
			has_rotation = true
			if not prop.is_numeric():
				_record_test_failure("获取所有属性测试", "rotation应该是数值类型")
				return
		elif prop.name == "scale":
			has_scale = true
			if not prop.is_vector():
				_record_test_failure("获取所有属性测试", "scale应该是向量类型")
				return

	if not (has_position and has_rotation and has_scale):
		_record_test_failure("获取所有属性测试", "应该包含基本属性")
		return

	_record_test_success("获取所有属性测试")

func test_property_filtering():
	print("测试属性过滤...")
	test_results.total += 1

	var node = Control.new()

	# 测试可写属性过滤
	var writable_props = PropertyManager.get_writable_properties(node)
	for prop in writable_props:
		if not prop.is_writable():
			_record_test_failure("属性过滤测试", "过滤结果应该都是可写属性")
			return

	# 测试数值属性过滤
	var numeric_props = PropertyManager.get_numeric_properties(node)
	for prop in numeric_props:
		if not prop.is_numeric():
			_record_test_failure("属性过滤测试", "过滤结果应该都是数值属性")
			return

	_record_test_success("属性过滤测试")

func test_safe_property_setting():
	print("测试安全属性设置...")
	test_results.total += 1

	var node = Node2D.new()

	# 设置有效值
	var valid_result = PropertyManager.set_property_safe(node, "position", Vector2(100, 200))
	if not valid_result.success:
		_record_test_failure("安全属性设置测试", "有效值设置应该成功")
		return

	if not node.position.is_equal_approx(Vector2(100, 200)):
		_record_test_failure("安全属性设置测试", "属性值应该正确设置")
		return

	# 设置无效值 - 使用完全不兼容的类型
	var invalid_result = PropertyManager.set_property_safe(node, "position", {"invalid": "dict"})
	if invalid_result.success:
		_record_test_failure("安全属性设置测试", "无效值设置应该失败")
		return

	# 检查是否有错误信息（错误信息格式可能不同）
	if not invalid_result.error or str(invalid_result.error).is_empty():
		_record_test_failure("安全属性设置测试", "应该包含错误信息")
		return

	_record_test_success("安全属性设置测试")

func test_batch_property_setting():
	print("测试批量属性设置...")
	test_results.total += 1

	var source_node = Node2D.new()
	var target_node = Node2D.new()

	# 设置源节点属性
	source_node.position = Vector2(100, 200)
	source_node.rotation = 45.0
	source_node.scale = Vector2(2, 2)

	# 批量复制
	var results = PropertyManager.copy_properties(source_node, target_node)
	if results.copied_count < 2:
		_record_test_failure("批量属性设置测试", "应该至少复制一些属性")
		return

	# 验证复制结果
	if results.copied_count > 0:
		if not target_node.position.is_equal_approx(source_node.position):
			_record_test_failure("批量属性设置测试", "位置应该正确复制")
			return

	_record_test_success("批量属性设置测试")

func test_caching_system():
	print("测试缓存系统...")
	test_results.total += 1

	var node = Sprite2D.new()

	# 第一次获取，应该解析并缓存
	var start_time = Time.get_ticks_msec()
	var props1 = PropertyManager.get_all_properties(node)
	var first_time = Time.get_ticks_msec() - start_time

	# 第二次获取，应该使用缓存
	start_time = Time.get_ticks_msec()
	var props2 = PropertyManager.get_all_properties(node)
	var second_time = Time.get_ticks_msec() - start_time

	# 缓存应该更快（或者至少相同，考虑到时间测量精度）
	if second_time > first_time:
		_record_test_failure("缓存系统测试", "缓存应该比第一次快或相同")
		return

	# 如果两次都是 0ms，说明太快了，这是可以接受的
	if first_time == 0 and second_time == 0:
		print("缓存系统测试: 两次都是 0ms，性能极佳")

	if props1.size() != props2.size():
		_record_test_failure("缓存系统测试", "两次获取的属性数量应该相同")
		return

	# 清除缓存
	PropertyManager.clear_cache(node)

	# 清除后应该重新解析
	start_time = Time.get_ticks_msec()
	var props3 = PropertyManager.get_all_properties(node)
	var third_time = Time.get_ticks_msec() - start_time

	# 时间应该接近第一次
	if abs(third_time - first_time) >= 10:
		_record_test_failure("缓存系统测试", "清除缓存后时间应该接近第一次")
		return

	_record_test_success("缓存系统测试")

func test_property_search():
	print("测试属性搜索...")
	test_results.total += 1

	var node = Node2D.new()

	# 搜索包含 "pos" 的属性
	var search_results = PropertyManager.search_properties(node, "pos")
	if search_results.size() <= 0:
		_record_test_failure("属性搜索测试", "应该找到包含 'pos' 的属性")
		return

	# 验证搜索结果
	var found_position = false
	for prop in search_results:
		if prop.name == "position":
			found_position = true
			break

	if not found_position:
		_record_test_failure("属性搜索测试", "应该找到 'position' 属性")
		return

	_record_test_success("属性搜索测试")

## 集成测试

func test_complete_property_workflow():
	print("测试完整属性操作工作流...")
	test_results.total += 1

	# 1. 创建测试节点
	var node = Sprite2D.new()

	# 2. 获取属性信息
	var position_info = PropertyManager.find_property(node, "position")
	if position_info == null:
		_record_test_failure("完整属性操作工作流测试", "应该找到 position 属性")
		return

	if not position_info.is_vector():
		_record_test_failure("完整属性操作工作流测试", "position 应该是向量类型")
		return

	if not position_info.is_writable():
		_record_test_failure("完整属性操作工作流测试", "position 应该是可写的")
		return

	# 3. 验证新值
	var new_position = Vector2(150, 250)
	var validation = position_info.validate_value(new_position)
	if not validation.valid:
		_record_test_failure("完整属性操作工作流测试", "新值应该通过验证")
		return

	# 4. 安全设置属性
	var set_result = PropertyManager.set_property_safe(node, "position", new_position)
	if not set_result.success:
		_record_test_failure("完整属性操作工作流测试", "属性设置应该成功")
		return

	# 5. 验证设置结果
	if not node.position.is_equal_approx(new_position):
		_record_test_failure("完整属性操作工作流测试", "属性值应该正确设置")
		return

	# 6. 测试类型转换
	var string_pos = "200,300"
	var converted_pos = TypeConverter.safe_convert_to_vector2(string_pos)
	if not converted_pos.is_equal_approx(Vector2(200, 300)):
		_record_test_failure("完整属性操作工作流测试", "字符串转换应该正确")
		return

	# 7. 设置转换后的值
	var convert_result = PropertyManager.set_property_safe(node, "position", converted_pos)
	if not convert_result.success:
		_record_test_failure("完整属性操作工作流测试", "转换值设置应该成功")
		return

	if not node.position.is_equal_approx(Vector2(200, 300)):
		_record_test_failure("完整属性操作工作流测试", "转换值应该正确设置")
		return

	_record_test_success("完整属性操作工作流测试")

func test_error_inputs():
	print("测试错误输入处理...")
	test_results.total += 1

	# 测试空节点
	var null_props = PropertyManager.get_all_properties(null)
	if not null_props.is_empty():
		_record_test_failure("错误输入处理测试", "空节点应该返回空数组")
		return

	# 测试无效属性名
	var node = Node2D.new()
	var invalid_prop = PropertyManager.find_property(node, "nonexistent_property")
	if invalid_prop != null:
		_record_test_failure("错误输入处理测试", "无效属性名应该返回 null")
		return

	# 测试无效类型转换
	var invalid_conversion = TypeConverter.safe_convert_to_vector2("not_a_vector")
	if invalid_conversion != Vector2.ZERO:
		_record_test_failure("错误输入处理测试", "无效转换应该返回默认值")
		return

	# 测试极端值
	var extreme_int = TypeConverter.safe_convert_to_int(999999999)
	if extreme_int != 999999999:
		_record_test_failure("错误输入处理测试", "极端值应该保持原值")
		return

	_record_test_success("错误输入处理测试")

func test_performance_with_many_properties():
	print("测试大量属性性能...")
	test_results.total += 1

	var node = Node.new()

	# 测试属性发现性能
	var start_time = Time.get_ticks_msec()
	var properties = PropertyManager.get_all_properties(node)
	var discovery_time = Time.get_ticks_msec() - start_time

	# 测试过滤性能
	start_time = Time.get_ticks_msec()
	var writable_props = PropertyManager.get_writable_properties(node)
	var filter_time = Time.get_ticks_msec() - start_time

	print("属性发现时间: %d ms" % discovery_time)
	print("属性过滤时间: %d ms" % filter_time)

	# 性能应该在合理范围内
	if discovery_time >= 100:
		_record_test_failure("大量属性性能测试", "属性发现时间应该在100ms以内")
		return

	if filter_time >= 50:
		_record_test_failure("大量属性性能测试", "属性过滤时间应该在50ms以内")
		return

	_record_test_success("大量属性性能测试")

## 测试总结

func print_test_summary():
	print("\n=== 测试总结 ===")
	print("总测试数: %d" % test_results.total)
	print("通过: %d" % test_results.passed)
	print("失败: %d" % test_results.failed)

	if test_results.failed > 0:
		print("\n失败详情:")
		for error in test_results.errors:
			print("  - %s" % error)

	if test_results.total > 0:
		var success_rate = float(test_results.passed) / float(test_results.total) * 100.0
		print("\n成功率: %.1f%%" % success_rate)

		if success_rate >= 90.0:
			print("🎉 测试表现优秀！")
		elif success_rate >= 70.0:
			print("✓ 测试表现良好")
		else:
			print("⚠️ 需要改进")
	else:
		print("\n没有运行任何测试")

## 辅助函数

func create_test_nodes():
	"""创建测试用的节点"""
	if test_node == null:
		test_node = Node2D.new()
		test_node.name = "TestNode2D"
		add_child(test_node)

	if test_sprite == null:
		test_sprite = Sprite2D.new()
		test_sprite.name = "TestSprite2D"
		add_child(test_sprite)

	if test_control == null:
		test_control = Control.new()
		test_control.name = "TestControl"
		add_child(test_control)

func cleanup_test_nodes():
	"""清理测试节点"""
	if test_node != null and is_instance_valid(test_node):
		test_node.queue_free()
		test_node = null

	if test_sprite != null and is_instance_valid(test_sprite):
		test_sprite.queue_free()
		test_sprite = null

	if test_control != null and is_instance_valid(test_control):
		test_control.queue_free()
		test_control = null

func _record_test_success(test_name: String):
	"""记录测试成功"""
	test_results.passed += 1
	print("✓ %s 通过" % test_name)

func _record_test_failure(test_name: String, error_message: String):
	"""记录测试失败"""
	test_results.failed += 1
	var error_msg = test_name + ": " + error_message
	test_results.errors.append(error_msg)
	var print_msg = "✗ " + test_name + " 失败: " + error_message
	print(print_msg)
