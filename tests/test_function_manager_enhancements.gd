## Test FunctionManager Enhancements
## 测试 FunctionManager 的继承级别过滤、getter 过滤和增强参数显示功能
extends Node

var test_node: Sprite2D
var tests_passed: int = 0
var tests_failed: int = 0

func _ready():
	print("========================================")
	print("开始测试：FunctionManager 增强功能")
	print("========================================\n")

	test_node = Sprite2D.new()
	add_child(test_node)

	# 运行所有测试
	test_inheritance_detection()
	test_method_definition_detection()
	test_inheritance_level_filtering()
	test_getter_filtering()
	test_enhanced_parameter_names()
	test_function_info_integration()
	test_backward_compatibility()

	test_node.queue_free()

	# 输出总结
	print("\n========================================")
	print("测试总结")
	print("========================================")
	print("通过: %d" % tests_passed)
	print("失败: %d" % tests_failed)
	if tests_failed == 0:
		print("✅ 所有测试通过!")
	else:
		print("❌ 有 %d 个测试失败" % tests_failed)
	print("========================================")

## 测试 1: 继承链检测
func test_inheritance_detection():
	print("\n--- 测试 1: 继承链检测 ---")

	var chain = FunctionManager.get_inheritance_chain(test_node)

	test_assert(not chain.is_empty(), "继承链不应该为空")
	tests_passed += 1
	print("✓ 继承链不为空，包含 %d 个类" % chain.size())

	test_assert(chain[0].class_name == "Sprite2D", "第一个类应该是 Sprite2D")
	tests_passed += 1
	print("✓ 第一个类是 Sprite2D")

	# 验证包含 Node2D
	var found_node2d = false
	for level_info in chain:
		if level_info.class_name == "Node2D":
			found_node2d = true
			print("✓ 找到 Node2D，级别 %d" % level_info.level)
			break

	test_assert(found_node2d, "应该找到 Node2D")
	tests_passed += 1

## 测试 2: 方法定义位置检测
func test_method_definition_detection():
	print("\n--- 测试 2: 方法定义位置检测 ---")

	var def_info = FunctionManager.detect_method_definition(test_node, "set_position")
	print("set_position 定义在: %s, 级别 %d" % [def_info.class_name, def_info.level])

	test_assert(not def_info.class_name.is_empty(), "应该找到 set_position 的定义")
	tests_passed += 1

	var def_info2 = FunctionManager.detect_method_definition(test_node, "add_child")
	print("add_child 定义在: %s, 级别 %d" % [def_info2.class_name, def_info2.level])

	test_assert(def_info2.class_name == "Node", "add_child 应该定义在 Node")
	tests_passed += 1
	print("✓ add_child 正确识别为定义在 Node 中")

## 测试 3: 继承级别过滤
func test_inheritance_level_filtering():
	print("\n--- 测试 3: 继承级别过滤 ---")

	# 获取所有方法
	var all_methods = FunctionManager.get_callable_methods(test_node, 0xFFFFFFFF, false)
	print("不过滤继承级别时获取到 %d 个方法" % all_methods.size())
	test_assert(all_methods.size() > 0, "应该获取到方法")
	tests_passed += 1

	# 只获取当前类的方法
	var current_class_methods = FunctionManager.get_callable_methods(test_node, 1 << 0, false)
	print("只获取当前类(Sprite2D)方法: %d 个" % current_class_methods.size())
	test_assert(current_class_methods.size() <= all_methods.size(), "当前类方法数量应该<=总方法数量")
	tests_passed += 1

	# 验证所有方法都有继承级别信息
	var all_have_level_info = true
	for method in current_class_methods:
		if not method.has("inheritance_level") or not method.has("defined_in_class"):
			print("⚠ 方法 %s 缺少继承级别信息" % method.get("name", ""))
			all_have_level_info = false
			break

	test_assert(all_have_level_info, "所有方法都应该包含继承级别信息")
	tests_passed += 1
	print("✓ 所有方法都包含继承级别信息")

## 测试 4: Getter 方法过滤
func test_getter_filtering():
	print("\n--- 测试 4: Getter 方法过滤 ---")

	# 不过滤 getter
	var methods_with_getters = FunctionManager.get_callable_methods(test_node, 0xFFFFFFFF, false)
	print("不过滤 getter 时获取到 %d 个方法" % methods_with_getters.size())

	# 过滤 getter
	var methods_without_getters = FunctionManager.get_callable_methods(test_node, 0xFFFFFFFF, true)
	print("过滤 getter 后获取到 %d 个方法" % methods_without_getters.size())

	test_assert(methods_without_getters.size() < methods_with_getters.size(), "过滤后方法数应该减少")
	tests_passed += 1

	# 验证过滤后的方法不包含 getter 前缀
	var has_getter_method = false
	for method in methods_without_getters:
		var method_name = method.get("name", "")
		if method_name.begins_with("get_") or method_name.begins_with("is_") or method_name.begins_with("has_"):
			has_getter_method = true
			print("⚠ 发现 getter 方法: %s" % method_name)
			break

	test_assert(not has_getter_method, "过滤后不应该包含 getter 方法")
	tests_passed += 1
	print("✓ Getter 方法过滤正确")

## 测试 5: 增强参数名称
func test_enhanced_parameter_names():
	print("\n--- 测试 5: 增强参数名称 ---")

	# 创建一个带参数的方法信息
	var method_info_dict = {
		"name": "set_position",
		"args": [
			{"name": "p_position", "type": TYPE_VECTOR2},
			{"name": "arg_value", "type": TYPE_FLOAT}
		],
		"return": {"type": TYPE_NIL}
	}

	var function_info = FunctionInfo.new(method_info_dict)
	var param_properties = function_info.get_parameter_property_list()

	print("参数属性数量: %d" % param_properties.size())
	test_assert(param_properties.size() == 2, "应该有 2 个参数属性")
	tests_passed += 1

	# 验证增强格式
	var param0_name = param_properties[0].get("name", "")
	print("参数 0 属性名: %s" % param0_name)
	test_assert(param0_name == "param_0___position", "参数 0 应该使用增强格式")
	tests_passed += 1

	var param1_name = param_properties[1].get("name", "")
	print("参数 1 属性名: %s" % param1_name)
	test_assert(param1_name == "param_1___value", "参数 1 应该使用增强格式")
	tests_passed += 1

	print("✓ 增强参数名称格式正确")

## 测试 6: FunctionInfo 集成
func test_function_info_integration():
	print("\n--- 测试 6: FunctionInfo 集成 ---")

	var methods = FunctionManager.get_callable_methods(test_node, 0xFFFFFFFF, true)
	test_assert(methods.size() > 0, "应该获取到方法")
	tests_passed += 1

	# 创建第一个方法的 FunctionInfo 对象
	var first_method_dict = methods[0]
	var function_info = FunctionInfo.new(first_method_dict)

	# 验证继承级别方法存在
	test_assert(function_info.has_method("get_defined_class"), "FunctionInfo 应该有 get_defined_class 方法")
	test_assert(function_info.has_method("get_inheritance_level"), "FunctionInfo 应该有 get_inheritance_level 方法")
	tests_passed += 1
	print("✓ FunctionInfo 包含继承级别方法")

	# 验证返回值
	var defined_class = function_info.get_defined_class()
	print("方法 %s 定义在: %s" % [function_info.method_name, defined_class])
	test_assert(not defined_class.is_empty(), "defined_in_class 不应该为空")
	tests_passed += 1

	var level = function_info.get_inheritance_level()
	print("方法 %s 继承级别: %d" % [function_info.method_name, level])
	test_assert(level >= 0, "inheritance_level 应该 >= 0")
	tests_passed += 1

	# 验证 get_method_details 包含新字段
	var details = function_info.get_method_details()
	test_assert(details.has("defined_in_class"), "get_method_details 应该包含 defined_in_class")
	test_assert(details.has("inheritance_level"), "get_method_details 应该包含 inheritance_level")
	tests_passed += 1
	print("✓ get_method_details 包含继承级别字段")

## 测试 7: 向后兼容性
func test_backward_compatibility():
	print("\n--- 测试 7: 向后兼容性 ---")

	# 测试不带新参数的调用
	var methods_old = FunctionManager.get_callable_methods(test_node)
	var methods_new = FunctionManager.get_callable_methods(test_node, 0xFFFFFFFF, true)

	print("旧方式调用: %d 个方法" % methods_old.size())
	print("新方式调用: %d 个方法" % methods_new.size())

	test_assert(methods_old.size() == methods_new.size(), "新旧调用方式应该返回相同数量（默认行为）")
	tests_passed += 1
	print("✓ 向后兼容性保持")

## 自定义断言函数
func test_assert(condition: bool, message: String):
	if not condition:
		print("❌ 断言失败: %s" % message)
		tests_failed += 1
		if OS.is_debug_build():
			push_error(message)
	else:
		print("✓ 断言通过: %s" % message)
