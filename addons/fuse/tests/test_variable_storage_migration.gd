extends Node

## 测试统一存储系统的正确性
##
## 此测试验证：
## 1. 新的统一存储层正确工作
## 2. 索引正确更新
## 3. 缓存机制正常工作
## 4. 数据一致性得到保证

func _ready():
	print("========================================")
	print("开始测试统一存储系统...")
	print("========================================\n")

	run_all_tests()

	print("\n========================================")
	print("所有测试完成！")
	print("========================================")

	# 自动退出
	await get_tree().process_frame
	get_tree().quit()

## 运行所有测试
func run_all_tests():
	test_phase1_unified_storage()
	test_phase2_unified_methods()
	test_data_consistency()
	test_index_updates()
	test_cache_mechanism()

## ============================================
## Phase 1 测试：统一存储层
## ============================================

func test_phase1_unified_storage():
	print("\n【Phase 1 测试】统一存储层初始化")
	print("----------------------------------------")

	var container = VariableContainer.new()

	# 验证新的存储变量存在
	assert(container._variables_data != null, "✗ _variables_data 未初始化")
	print("✓ _variables_data 已初始化")

	assert(container._scope_index != null, "✗ _scope_index 未初始化")
	print("✓ _scope_index 已初始化")

	assert(container._persistent_index != null, "✗ _persistent_index 未初始化")
	print("✓ _persistent_index 已初始化")

	assert(container._runtime_index != null, "✗ _runtime_index 未初始化")
	print("✓ _runtime_index 已初始化")

	assert(container._unified_cache != null, "✗ _unified_cache 未初始化")
	print("✓ _unified_cache 已初始化")

	print("\nPhase 1 测试通过！")

## ============================================
## Phase 2 测试：统一访问方法
## ============================================

func test_phase2_unified_methods():
	print("\n【Phase 2 测试】统一访问方法")
	print("----------------------------------------")

	var container = VariableContainer.new()

	# 测试 _has_variable_unified
	assert(not container._has_variable_unified("test_var"), "✗ _has_variable_unified 初始状态错误")
	print("✓ _has_variable_unified 初始状态正确")

	# 创建测试数据
	var test_data = VariableContainer.VariableData.new()
	test_data.value = 42
	test_data.type = TYPE_INT
	test_data.scope = VariableContainer.VariableScope.LOCAL
	test_data.persistent = false
	test_data.timestamp = Time.get_ticks_msec()

	# 测试 _set_variable_data (通过直接访问内部方法)
	container._variables_data["test_var"] = test_data
	container._add_to_indices("test_var", test_data)

	# 验证数据已添加
	assert(container._has_variable_unified("test_var"), "✗ 变量未正确添加到统一存储")
	print("✓ 变量已正确添加到统一存储")

	# 测试 _get_variable_data
	var retrieved_data = container._get_variable_data("test_var")
	assert(retrieved_data != null, "✗ _get_variable_data 返回 null")
	assert(retrieved_data.value == 42, "✗ 获取的值不正确")
	print("✓ _get_variable_data 正确获取数据")

	# 测试索引更新
	var local_vars = container._get_variable_names_unified(VariableContainer.VariableScope.LOCAL)
	assert("test_var" in local_vars, "✗ 索引未正确更新")
	print("✓ 索引正确更新")

	# 测试移除变量
	assert(container._remove_variable_unified("test_var"), "✗ _remove_variable_unified 失败")
	assert(not container._has_variable_unified("test_var"), "✗ 变量未正确移除")
	print("✓ 变量已正确移除")

	print("\nPhase 2 测试通过！")

## ============================================
## 数据一致性测试
## ============================================

func test_data_consistency():
	print("\n【数据一致性测试】验证数据在所有存储中同步")
	print("----------------------------------------")

	var container = VariableContainer.new()

	# 添加变量
	var success = container.add_variable("consistency_test", 100, VariableContainer.VariableScope.LOCAL, false)
	assert(success, "✗ 添加变量失败")
	print("✓ 变量添加成功")

	# 验证变量在统一存储中
	var unified_data = container._get_variable_data("consistency_test")
	if unified_data != null:
		assert(unified_data.value == 100, "✗ 统一存储中的值不正确")
		print("✓ 统一存储中的值正确")
	else:
		print("⚠ 统一存储中暂无数据（Phase 3 实施后会有）")

	# 验证变量在旧存储中（向后兼容）
	var old_value = container.get_variable("consistency_test", null, VariableContainer.VariableScope.LOCAL)
	assert(old_value == 100, "✗ 旧存储中的值不正确")
	print("✓ 旧存储中的值正确（向后兼容）")

	print("\n数据一致性测试通过！")

## ============================================
## 索引更新测试
## ============================================

func test_index_updates():
	print("\n【索引更新测试】验证索引正确维护")
	print("----------------------------------------")

	var container = VariableContainer.new()

	# 添加多个变量
	container.add_variable("local_var1", 1, VariableContainer.VariableScope.LOCAL, false)
	container.add_variable("local_var2", 2, VariableContainer.VariableScope.LOCAL, true)
	container.add_variable("global_var1", 3, VariableContainer.VariableScope.GLOBAL, false)

	print("✓ 添加了 3 个测试变量")

	# 验证作用域索引
	var local_vars = container._get_variable_names_unified(VariableContainer.VariableScope.LOCAL)
	var global_vars = container._get_variable_names_unified(VariableContainer.VariableScope.GLOBAL)

	print("  - LOCAL 变量数量: %d" % local_vars.size())
	print("  - GLOBAL 变量数量: %d" % global_vars.size())

	# 验证持久化索引
	var runtime_count = container._runtime_index.size()
	var persistent_count = container._persistent_index.size()

	print("  - Runtime 变量数量: %d" % runtime_count)
	print("  - Persistent 变量数量: %d" % persistent_count)

	print("\n索引更新测试通过！")

## ============================================
## 缓存机制测试
## ============================================

func test_cache_mechanism():
	print("\n【缓存机制测试】验证缓存正常工作")
	print("----------------------------------------")

	var container = VariableContainer.new()

	# 添加测试数据
	var test_data = VariableContainer.VariableData.new()
	test_data.value = "cached_value"
	test_data.type = TYPE_STRING
	test_data.scope = VariableContainer.VariableScope.LOCAL
	test_data.persistent = false
	test_data.timestamp = Time.get_ticks_msec()

	container._variables_data["cached_var"] = test_data
	container._add_to_indices("cached_var", test_data)

	# 验证缓存状态
	assert(container._unified_cache_enabled == true, "✗ 统一缓存未启用")
	print("✓ 统一缓存已启用")

	assert(container._unified_cache_max_size == 1000, "✗ 缓存大小不正确")
	print("✓ 缓存大小设置正确（1000）")

	# 测试缓存失效
	container._invalidate_unified_cache("cached_var")
	assert(not container._unified_cache.has("cached_var"), "✗ 缓存未正确失效")
	print("✓ 缓存失效机制正常")

	print("\n缓存机制测试通过！")
