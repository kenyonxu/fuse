extends Node

## ExecutionContext 内存清理测试
##
## 测试 ExecutionContext 是否正确释放 RefCounted 对象，防止内存泄漏

class TestRefCountedObject extends RefCounted:
	var value: int = 0

	func _init(p_value: int = 0):
		value = p_value

	func get_value() -> int:
		return value

class TestResource extends Resource:
	var data: String = ""

	func _init(p_data: String = ""):
		data = p_data

func test_cleanup_releases_refcounted_objects():
	print("=== 开始内存清理测试 ===")

	var context = ExecutionContext.new()

	# 创建 RefCounted 对象并添加到上下文
	var ref_obj = TestRefCountedObject.new(42)
	var initial_ref_count = ref_obj.get_reference_count()
	print("RefCounted 对象初始引用计数: %d" % initial_ref_count)

	context.set_variable("test_ref", ref_obj)

	# 添加更多 RefCounted 对象
	var ref_obj2 = TestRefCountedObject.new(100)
	context.set_variable("test_ref2", ref_obj2)

	# 添加 Resource 对象
	var res_obj = TestResource.new("test_data")
	context.set_variable("test_res", res_obj)

	# 清理上下文
	context.cleanup()

	# 验证：cleanup 后引用应该被释放
	var final_ref_count = ref_obj.get_reference_count()
	var final_ref_count2 = ref_obj2.get_reference_count()

	print("RefCounted 对象 1 最终引用计数: %d" % final_ref_count)
	print("RefCounted 对象 2 最终引用计数: %d" % final_ref_count2)

	# 引用计数应该减少（至少减少 1，因为上下文不再持有引用）
	if final_ref_count < initial_ref_count and final_ref_count2 < initial_ref_count:
		print("✓ RefCounted 对象引用计数正确降低")
	else:
		push_error("✗ RefCounted 对象引用计数未降低")
		push_error("  对象 1: %d -> %d" % [initial_ref_count, final_ref_count])
		push_error("  对象 2: %d -> %d" % [initial_ref_count, final_ref_count2])

	assert(final_ref_count < initial_ref_count,
		"RefCounted 对象 1 引用计数未降低: %d -> %d" % [initial_ref_count, final_ref_count])
	assert(final_ref_count2 < initial_ref_count,
		"RefCounted 对象 2 引用计数未降低: %d -> %d" % [initial_ref_count, final_ref_count2])

	print("=== 内存清理测试完成 ===")

func test_cleanup_clears_dictionaries():
	print("\n=== 开始字典清理测试 ===")

	var context = ExecutionContext.new()

	# 添加多个变量
	for i in range(50):
		context.set_variable("var_%d" % i, i)

	print("添加 50 个变量后:")
	print("  local_variables 大小: %d" % context.local_variables.size())

	# 添加自定义数据
	for i in range(20):
		context.set_custom_data("key_%d" % i, "value_%d" % i)

	print("添加 20 个自定义数据后:")
	print("  custom_data 大小: %d" % context.custom_data.size())

	# 清理上下文
	context.cleanup()

	print("清理后:")
	print("  local_variables 大小: %d" % context.local_variables.size())
	print("  custom_data 大小: %d" % context.custom_data.size())

	# 验证：字典应该被清空
	if context.local_variables.size() == 0 and context.custom_data.size() == 0:
		print("✓ 字典正确清空")
	else:
		push_error("✗ 字典未完全清空")
		push_error("  local_variables 大小: %d" % context.local_variables.size())
		push_error("  custom_data 大小: %d" % context.custom_data.size())

	assert(context.local_variables.size() == 0,
		"local_variables 应该为空，大小: %d" % context.local_variables.size())
	assert(context.custom_data.size() == 0,
		"custom_data 应该为空，大小: %d" % context.custom_data.size())

	print("=== 字典清理测试完成 ===")

func test_cleanup_clears_caches():
	print("\n=== 开始缓存清理测试 ===")

	var context = ExecutionContext.new()

	# 启用索引访问并预编译变量
	var var_names = []
	for i in range(10):
		var_names.append("var_%d" % i)
		context.set_variable("var_%d" % i, i)

	context.precompile_variable_access(var_names)

	print("预编译前:")
	print("  _variable_name_cache 大小: %d" % context._variable_name_cache.size())
	print("  _variable_index_map 大小: %d" % context._variable_index_map.size())
	print("  _variable_array 大小: %d" % context._variable_array.size())

	# 清理上下文
	context.cleanup()

	print("清理后:")
	print("  _variable_name_cache 大小: %d" % context._variable_name_cache.size())
	print("  _variable_index_map 大小: %d" % context._variable_index_map.size())
	print("  _variable_array 大小: %d" % context._variable_array.size())

	# 验证：缓存应该被清空
	if context._variable_name_cache.size() == 0 and context._variable_index_map.size() == 0:
		print("✓ 缓存正确清空")
	else:
		push_error("✗ 缓存未完全清空")

	assert(context._variable_name_cache.size() == 0,
		"_variable_name_cache 应该为空，大小: %d" % context._variable_name_cache.size())
	assert(context._variable_index_map.size() == 0,
		"_variable_index_map 应该为空，大小: %d" % context._variable_index_map.size())

	print("=== 缓存清理测试完成 ===")

func test_cleanup_clears_references():
	print("\n=== 开始引用清理测试 ===")

	var node = Node.new()
	node.name = "TestNode"

	var context = ExecutionContext.new()
	context.target = node

	print("清理前:")
	print("  target: %s" % str(context.target))
	print("  _target_weakref: %s" % str(context._target_weakref))

	# 清理上下文
	context.cleanup()

	print("清理后:")
	print("  target: %s" % str(context.target))
	print("  _target_weakref: %s" % str(context._target_weakref))
	print("  global_variables: %s" % str(context.global_variables))
	print("  tree: %s" % str(context.tree))

	# 验证：引用应该被释放
	if context.target == null and context._target_weakref == null:
		print("✓ 节点引用正确释放")
	else:
		push_error("✗ 节点引用未完全释放")

	assert(context.target == null, "target 应该为 null")
	assert(context._target_weakref == null, "_target_weakref 应该为 null")

	node.queue_free()

	print("=== 引用清理测试完成 ===")
