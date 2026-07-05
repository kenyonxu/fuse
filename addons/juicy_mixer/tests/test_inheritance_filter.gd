## Test Inheritance Filter
## 测试方法轨道的继承级别过滤功能
##
## 此测试验证：
## 1. 继承链检测功能
## 2. 方法定义位置检测
## 3. 继承级别过滤功能
## 4. 位掩码过滤逻辑

extends Node

## 测试节点 - 继承自 Sprite2D，拥有深层继承链
var test_node: Sprite2D

## 测试结果统计
var tests_passed: int = 0
var tests_failed: int = 0

func _ready():
	print("========================================")
	print("开始测试：继承级别过滤功能")
	print("========================================\n")

	# 创建测试节点
	test_node = Sprite2D.new()
	add_child(test_node)

	# 运行所有测试
	test_basic_inheritance_detection()
	test_method_definition_detection()
	test_inheritance_level_filtering()
	test_bitmask_filtering()
	test_juicy_method_info_integration()

	# 清理
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

## 测试 1: 基础继承链检测
func test_basic_inheritance_detection():
	print("\n--- 测试 1: 基础继承链检测 ---")

	var chain = JuicyMethodReflection.get_inheritance_chain(test_node)

	# 验证继承链不为空
	test_assert(not chain.is_empty(), "继承链不应该为空")
	tests_passed += 1
	print("✓ 继承链不为空，包含 %d 个类" % chain.size())

	# 验证第一个类是 Sprite2D
	test_assert(chain[0].class_name == "Sprite2D", "第一个类应该是 Sprite2D")
	tests_passed += 1
	print("✓ 第一个类是 Sprite2D")

	# 验证继承链包含 Node2D
	var found_node2d = false
	for level_info in chain:
		if level_info.class_name == "Node2D":
			found_node2d = true
			print("✓ 找到 Node2D，级别 %d" % level_info.level)
			break

	test_assert(found_node2d, "应该找到 Node2D")
	tests_passed += 1

	# 验证继承链包含 Node
	var found_node = false
	for level_info in chain:
		if level_info.class_name == "Node":
			found_node = true
			print("✓ 找到 Node，级别 %d" % level_info.level)
			break

	test_assert(found_node, "应该找到 Node")
	tests_passed += 1

	# 验证级别信息正确
	test_assert(chain[0].level == 0, "第一个类的级别应该是 0")
	tests_passed += 1
	print("✓ 级别信息正确")

## 测试 2: 方法定义位置检测
func test_method_definition_detection():
	print("\n--- 测试 2: 方法定义位置检测 ---")

	# 测试 Node2D 的 set_position 方法（应该在 Node2D 中定义）
	var def_info = JuicyMethodReflection.detect_method_definition(test_node, "set_position")
	print("set_position 定义在: %s, 级别 %d" % [def_info.class_name, def_info.level])

	# 验证找到了方法定义
	test_assert(not def_info.class_name.is_empty(), "应该找到 set_position 的定义")
	tests_passed += 1

	# 测试 Node 的 add_child 方法（应该在 Node 中定义）
	var def_info2 = JuicyMethodReflection.detect_method_definition(test_node, "add_child")
	print("add_child 定义在: %s, 级别 %d" % [def_info2.class_name, def_info2.level])

	test_assert(def_info2.class_name == "Node", "add_child 应该定义在 Node")
	tests_passed += 1
	print("✓ add_child 正确识别为定义在 Node 中")

## 测试 3: 继承级别过滤功能
func test_inheritance_level_filtering():
	print("\n--- 测试 3: 继承级别过滤功能 ---")

	# 获取所有方法（不过滤）
	var all_methods = JuicyMethodReflection.get_callable_methods(test_node, 0xFFFFFFFF)
	print("不过滤时获取到 %d 个方法" % all_methods.size())
	test_assert(all_methods.size() > 0, "应该获取到方法")
	tests_passed += 1

	# 只获取当前类的方法（级别 0）
	var current_class_methods = JuicyMethodReflection.get_callable_methods(test_node, 1 << 0)
	print("只获取当前类(Sprite2D)方法: %d 个" % current_class_methods.size())
	test_assert(current_class_methods.size() <= all_methods.size(), "当前类方法数量应该<=总方法数量")
	tests_passed += 1

	# 验证所有返回的方法都包含继承级别信息
	var all_have_level_info = true
	for method in current_class_methods:
		if not method.has("inheritance_level") or not method.has("defined_in_class"):
			print("⚠ 方法 %s 缺少继承级别信息" % method.get("name", ""))
			all_have_level_info = false
			break

	test_assert(all_have_level_info, "所有方法都应该包含继承级别信息")
	tests_passed += 1
	print("✓ 所有方法都包含继承级别信息")

## 测试 4: 位掩码过滤逻辑
func test_bitmask_filtering():
	print("\n--- 测试 4: 位掩码过滤逻辑 ---")

	# 测试级别 0 是否被包含（位掩码 1）
	test_assert(JuicyMethodReflection._is_level_included(0, 1), "级别 0 应该被位掩码 1 包含")
	tests_passed += 1
	print("✓ 位掩码 1 包含级别 0")

	# 测试级别 1 是否被包含（位掩码 2）
	test_assert(JuicyMethodReflection._is_level_included(1, 2), "级别 1 应该被位掩码 2 包含")
	tests_passed += 1
	print("✓ 位掩码 2 包含级别 1")

	# 测试级别 0 和 1 都被包含（位掩码 3）
	test_assert(JuicyMethodReflection._is_level_included(0, 3), "级别 0 应该被位掩码 3 包含")
	test_assert(JuicyMethodReflection._is_level_included(1, 3), "级别 1 应该被位掩码 3 包含")
	tests_passed += 1
	print("✓ 位掩码 3 包含级别 0 和 1")

	# 测试级别 2 不被包含（位掩码 3）
	test_assert(not JuicyMethodReflection._is_level_included(2, 3), "级别 2 不应该被位掩码 3 包含")
	tests_passed += 1
	print("✓ 位掩码 3 不包含级别 2")

## 测试 5: JuicyMethodInfo 集成
func test_juicy_method_info_integration():
	print("\n--- 测试 5: JuicyMethodInfo 集成 ---")

	# 获取方法信息
	var all_methods = JuicyMethodReflection.get_callable_methods(test_node, 0xFFFFFFFF)
	test_assert(all_methods.size() > 0, "应该获取到方法")
	tests_passed += 1

	# 创建第一个方法的 JuicyMethodInfo 对象
	var first_method_dict = all_methods[0]
	var method_info = JuicyMethodInfo.new(first_method_dict)

	# 验证继承级别字段存在
	test_assert(method_info.has_method("get_defined_class"), "JuicyMethodInfo 应该有 get_defined_class 方法")
	test_assert(method_info.has_method("get_inheritance_level"), "JuicyMethodInfo 应该有 get_inheritance_level 方法")
	tests_passed += 1
	print("✓ JuicyMethodInfo 包含继承级别方法")

	# 验证 get_defined_class 返回值
	var defined_class = method_info.get_defined_class()
	print("方法 %s 定义在: %s" % [method_info.method_name, defined_class])
	test_assert(not defined_class.is_empty(), "defined_in_class 不应该为空")
	tests_passed += 1

	# 验证 get_inheritance_level 返回值
	var level = method_info.get_inheritance_level()
	print("方法 %s 继承级别: %d" % [method_info.method_name, level])
	test_assert(level >= 0, "inheritance_level 应该 >= 0")
	tests_passed += 1

	# 验证 get_method_details 包含新字段
	var details = method_info.get_method_details()
	test_assert(details.has("defined_in_class"), "get_method_details 应该包含 defined_in_class")
	test_assert(details.has("inheritance_level"), "get_method_details 应该包含 inheritance_level")
	tests_passed += 1
	print("✓ get_method_details 包含继承级别字段")

## 自定义断言函数
func test_assert(condition: bool, message: String):
	if not condition:
		print("❌ 断言失败: %s" % message)
		tests_failed += 1
		# 在编辑器中暂停以便调试
		if OS.is_debug_build():
			push_error(message)
	else:
		print("✓ 断言通过: %s" % message)
