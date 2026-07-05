extends SceneTree

## Phase 3 统一存储测试脚本
## 测试 VariableContainer 的统一存储系统

func _init():
	print("=== Phase 3 统一存储测试 ===")

	# 创建变量容器
	var container = VariableContainer.new()

	# 测试 1: add_variable 使用统一存储
	print("\n[测试 1] add_variable 使用统一存储")
	var result1 = container.add_variable("test_var1", 100, VariableContainer.VariableScope.LOCAL, false)
	print("  添加 test_var1: %s" % ("成功" if result1 else "失败"))
	assert(result1, "添加变量应该成功")

	# 验证变量在统一存储中
	assert(container._variables_data.has("test_var1"), "变量应该在 _variables_data 中")
	print("  ✓ 变量在统一存储 _variables_data 中")

	# 验证索引已更新
	assert("test_var1" in container._scope_index[VariableContainer.VariableScope.LOCAL], "变量应该在 LOCAL 作用域索引中")
	print("  ✓ 变量在作用域索引中")

	# 测试 2: get_variable 使用统一存储
	print("\n[测试 2] get_variable 使用统一存储")
	var value1 = container.get_variable("test_var1", 0)
	print("  获取 test_var1: %s" % value1)
	assert(value1 == 100, "应该获取到正确的值")
	print("  ✓ 通过统一存储获取到值")

	# 测试缓存
	if container._unified_cache_enabled:
		assert(container._unified_cache.has("test_var1"), "值应该在缓存中")
		print("  ✓ 值已缓存")

	# 测试 3: set_variable 使用统一存储
	print("\n[测试 3] set_variable 使用统一存储")
	var result2 = container.set_variable("test_var1", 200)
	print("  更新 test_var1: %s" % ("成功" if result2 else "失败"))
	assert(result2, "更新变量应该成功")

	var value2 = container.get_variable("test_var1", 0)
	print("  获取更新后的值: %s" % value2)
	assert(value2 == 200, "应该获取到更新后的值")
	print("  ✓ 通过统一存储更新成功")

	# 验证缓存失效
	if container._unified_cache_enabled:
		var data = container._get_variable_data("test_var1")
		assert(data.modification_count > 0, "修改次数应该增加")
		print("  ✓ 修改计数已更新")

	# 测试 4: has_variable 使用统一存储
	print("\n[测试 4] has_variable 使用统一存储")
	var has1 = container.has_variable("test_var1")
	print("  检查 test_var1 是否存在: %s" % has1)
	assert(has1, "变量应该存在")
	print("  ✓ 通过统一存储检查存在性")

	var has2 = container.has_variable("nonexistent")
	assert(not has2, "不存在的变量应该返回 false")
	print("  ✓ 不存在的变量正确返回 false")

	# 测试 5: get_variable_names 使用统一存储
	print("\n[测试 5] get_variable_names 使用统一存储")
	var names = container.get_variable_names(VariableContainer.VariableScope.LOCAL)
	print("  LOCAL 作用域变量: %s" % names)
	assert("test_var1" in names, "test_var1 应该在列表中")
	print("  ✓ 通过统一索引获取变量名列表")

	# 测试 6: 添加多个变量并验证索引
	print("\n[测试 6] 多变量索引测试")
	container.add_variable("test_var2", 3.14, VariableContainer.VariableScope.LOCAL, true)
	container.add_variable("test_global1", 999, VariableContainer.VariableScope.GLOBAL, true)

	print("  添加了 3 个变量")
	print("  LOCAL 变量数量: %d" % container._scope_index[VariableContainer.VariableScope.LOCAL].size())
	print("  GLOBAL 变量数量: %d" % container._scope_index[VariableContainer.VariableScope.GLOBAL].size())

	assert(container._scope_index[VariableContainer.VariableScope.LOCAL].size() == 2, "LOCAL 应该有 2 个变量")
	assert(container._scope_index[VariableContainer.VariableScope.GLOBAL].size() == 1, "GLOBAL 应该有 1 个变量")
	print("  ✓ 索引正确维护")

	# 测试 7: remove_variable 使用统一存储
	print("\n[测试 7] remove_variable 使用统一存储")
	var result3 = container.remove_variable("test_var1")
	print("  删除 test_var1: %s" % ("成功" if result3 else "失败"))
	assert(result3, "删除变量应该成功")

	# 验证从主存储中删除
	assert(not container._variables_data.has("test_var1"), "变量不应该在 _variables_data 中")
	print("  ✓ 变量从主存储中删除")

	# 验证从索引中删除
	assert(not ("test_var1" in container._scope_index[VariableContainer.VariableScope.LOCAL]), "变量不应该在索引中")
	print("  ✓ 变量从索引中删除")

	# 验证从缓存中删除
	if container._unified_cache_enabled:
		assert(not container._unified_cache.has("test_var1"), "变量不应该在缓存中")
		print("  ✓ 变量从缓存中删除")

	# 测试 8: 持久化索引测试
	print("\n[测试 8] 持久化索引测试")
	var persistent_names = container._persistent_index
	var runtime_names = container._runtime_index

	print("  持久化变量: %s" % persistent_names)
	print("  运行时变量: %s" % runtime_names)

	assert("test_var2" in persistent_names, "test_var2 应该在持久化索引中")
	assert("test_global1" in persistent_names, "test_global1 应该在持久化索引中")
	print("  ✓ 持久化索引正确维护")

	# 最终统计
	print("\n=== 最终统计 ===")
	var stats = container.get_statistics()
	print("  LOCAL 变量数: %d" % stats.local_count)
	print("  GLOBAL 变量数: %d" % stats.global_count)
	print("  总变量数: %d" % stats.total_count)
	print("  统一存储中的变量数: %d" % container._variables_data.size())

	assert(container._variables_data.size() == 2, "统一存储中应该有 2 个变量")
	print("  ✓ 统一存储正确维护所有变量")

	print("\n✓✓✓ 所有测试通过 ✓✓✓")
	quit(0)
