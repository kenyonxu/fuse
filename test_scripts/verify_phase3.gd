extends Node

## 简单验证 Phase 3 修改

func _ready():
	print("=== Phase 3 验证测试 ===\n")

	var container = VariableContainer.new()

	# 测试 1: 添加变量
	print("[测试 1] add_variable 使用统一存储")
	container.add_variable("var1", 100, VariableContainer.VariableScope.LOCAL, false)
	assert(container._variables_data.has("var1"), "变量应该在统一存储中")
	print("✓ 变量在 _variables_data 中")
	assert("var1" in container._scope_index[VariableContainer.VariableScope.LOCAL], "变量应该在索引中")
	print("✓ 变量在作用域索引中\n")

	# 测试 2: 获取变量
	print("[测试 2] get_variable 使用统一存储")
	var val = container.get_variable("var1", 0)
	assert(val == 100, "应该获取到正确的值")
	print("✓ 获取到正确值:", val, "\n")

	# 测试 3: 设置变量
	print("[测试 3] set_variable 使用统一存储")
	container.set_variable("var1", 200)
	var data = container._get_variable_data("var1")
	assert(data.value == 200, "值应该被更新")
	assert(data.modification_count > 0, "修改次数应该增加")
	print("✓ 值已更新，修改次数:", data.modification_count, "\n")

	# 测试 4: 检查变量存在
	print("[测试 4] has_variable 使用统一存储")
	assert(container.has_variable("var1"), "变量应该存在")
	assert(not container.has_variable("nonexistent"), "不存在的变量应该返回 false")
	print("✓ has_variable 工作正常\n")

	# 测试 5: 获取变量名列表
	print("[测试 5] get_variable_names 使用统一存储")
	var names = container.get_variable_names(VariableContainer.VariableScope.LOCAL)
	assert("var1" in names, "var1 应该在列表中")
	print("✓ 变量名列表:", names, "\n")

	# 测试 6: 删除变量
	print("[测试 6] remove_variable 使用统一存储")
	container.remove_variable("var1")
	assert(not container._variables_data.has("var1"), "变量应该从统一存储中删除")
	assert(not ("var1" in container._scope_index[VariableContainer.VariableScope.LOCAL]), "变量应该从索引中删除")
	print("✓ 变量已从统一存储和索引中删除\n")

	print("=== ✓✓✓ 所有验证通过 ✓✓✓ ===")

	# 退出
	await get_tree().process_frame
	get_tree().quit()
