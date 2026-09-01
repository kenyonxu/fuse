extends Node

## ExecutionContext Scope Integration Test
##
## 测试 ExecutionContext 与作用域变量系统的集成

func _ready():
	print("=== ExecutionContext Scope Integration Test ===")

	# 等待一帧，确保所有节点都准备好
	await get_tree().process_frame

	await test_scope_variable_from_context()
	await test_scope_fallback_to_local()
	await test_multiple_scopes()
	await test_scope_priority()
	await test_default_values()

	print("=== All Integration Tests Passed ===")

func test_scope_variable_from_context():
	print("Test: Scope variable from ExecutionContext")

	# 获取场景中的节点
	var scope_container = $ScopeContainer
	var test_trigger = $TestTrigger

	# 验证节点存在
	assert(scope_container != null, "ScopeContainer not found")
	assert(test_trigger != null, "TestTrigger not found")

	# 手动触发注册（因为 call_deferred 可能延迟超过一帧）
	scope_container._register_scope()

	# 再等待一帧确保注册完成
	await get_tree().process_frame

	# 创建 ExecutionContext（模拟 Trigger 中的创建过程）
	var context = ExecutionContext.new(test_trigger, test_trigger)

	# 通过 ExecutionContext 设置作用域变量
	var success = context.set_variable("test_value", 123, "scope")
	assert(success == true, "Failed to set scope variable through ExecutionContext")

	# 验证变量在 ScopeContainer 中
	var value_in_container = scope_container.get_variable("test_value")
	assert(value_in_container == 123, "Variable not found in ScopeContainer")

	# 通过 ExecutionContext 获取作用域变量
	var retrieved_value = context.get_variable("test_value", 0, "scope")
	assert(retrieved_value == 123, "Failed to retrieve scope variable through ExecutionContext")

	# 测试更新变量
	context.set_variable("test_value", 456, "scope")
	assert(scope_container.get_variable("test_value") == 456, "Failed to update scope variable")

	# 测试多个变量
	context.set_variable("string_var", "hello", "scope")
	context.set_variable("float_var", 3.14, "scope")
	context.set_variable("bool_var", true, "scope")

	assert(scope_container.get_variable("string_var") == "hello", "String variable failed")
	assert(scope_container.get_variable("float_var") == 3.14, "Float variable failed")
	assert(scope_container.get_variable("bool_var") == true, "Bool variable failed")

	print("  ✓ Scope variable integration passed")

func test_scope_fallback_to_local():
	print("Test: Fallback to local when no scope")

	# 创建一个完全独立的节点树，确保找不到 ScopeContainer
	# 使用一个脱离主场景树的临时父节点
	var temp_root = Node.new()
	temp_root.name = "TempRoot"

	# 创建临时 trigger
	var temp_trigger = Node.new()
	temp_trigger.name = "TempTrigger"

	# 注意：不要将 temp_root 添加到主场景树，这样就不会找到 ScopeContainer
	temp_root.add_child(temp_trigger)

	# 创建 ExecutionContext（此时 trigger 不在主场景树中）
	var context = ExecutionContext.new(temp_trigger, temp_trigger)

	# 在没有作用域容器的情况下，应该回退到本地变量
	var set_result = context.set_variable("local_test", "local_value", "scope")
	assert(set_result == true, "set_variable should return true")

	var retrieved = context.get_variable("local_test", "default", "scope")
	assert(retrieved == "local_value", "Local fallback failed")

	# 验证本地变量确实存在
	assert(context.has_variable("local_test"), "Local variable not found")

	# 清理（不需要 queue_free，因为节点不在场景树中）
	temp_root.queue_free()
	await get_tree().process_frame

	print("  ✓ Fallback to local passed")

func test_multiple_scopes():
	print("Test: Multiple scope containers")

	# 创建嵌套的作用域结构
	var parent_scope = ScopeVariableContainer.new()
	parent_scope.scope_id = "parent_scope"
	parent_scope.name = "ParentScope"
	add_child(parent_scope)

	await get_tree().process_frame

	# 在父作用域中设置变量
	parent_scope.set_variable("parent_var", "from_parent")

	# 创建子节点（非 ScopeVariableContainer）
	var child_node = Node.new()
	child_node.name = "ChildNode"
	parent_scope.add_child(child_node)

	# 创建以 child_node 为 trigger 的 ExecutionContext
	var context = ExecutionContext.new(child_node, child_node)

	# 验证可以访问父作用域的变量
	var parent_value = context.get_variable("parent_var", "default", "scope")
	assert(parent_value == "from_parent", "Failed to access parent scope variable")

	# 通过 context 设置变量（应该设置到最近的父作用域）
	context.set_variable("child_var", "from_child", "scope")
	var child_value = context.get_variable("child_var", "default", "scope")
	assert(child_value == "from_child", "Failed to set child scope variable")

	# 验证变量在父作用域中
	assert(parent_scope.get_variable("child_var") == "from_child", "Child variable not in parent scope")

	# 测试作用域链查找
	var manager = ScopeVariableManager.get_instance()
	var found_scope = manager.find_nearest_scope(child_node)
	assert(found_scope == parent_scope, "Should find parent scope")

	# 清理
	child_node.queue_free()
	parent_scope.queue_free()
	await get_tree().process_frame

	print("  ✓ Multiple scopes passed")

func test_scope_priority():
	print("Test: Scope variable priority over local")

	var scope_container = $ScopeContainer
	var test_trigger = $TestTrigger

	# 等待一帧，让 ScopeContainer 完成注册
	await get_tree().process_frame

	# 创建 ExecutionContext
	var context = ExecutionContext.new(test_trigger, test_trigger)

	# 在作用域中设置变量
	context.set_variable("priority_test", "scope_value", "scope")

	# 在本地也设置同名变量
	context.set_variable("priority_test", "local_value", "local")

	# 从作用域获取应该得到作用域的值
	var scope_value = context.get_variable("priority_test", "default", "scope")
	assert(scope_value == "scope_value", "Scope value should be retrieved")

	# 从本地获取应该得到本地的值
	var local_value = context.get_variable("priority_test", "default", "local")
	assert(local_value == "local_value", "Local value should be retrieved")

	# 验证作用域容器中的值
	assert(scope_container.get_variable("priority_test") == "scope_value", "Scope container value mismatch")

	print("  ✓ Scope priority passed")

func test_default_values():
	print("Test: Default values for missing variables")

	var test_trigger = $TestTrigger

	# 等待一帧，让 ScopeContainer 完成注册
	await get_tree().process_frame

	var context = ExecutionContext.new(test_trigger, test_trigger)

	# 测试不存在的变量返回默认值
	var missing_scope = context.get_variable("nonexistent_scope", "scope_default", "scope")
	assert(missing_scope == "scope_default", "Scope default value failed")

	var missing_local = context.get_variable("nonexistent_local", "local_default", "local")
	assert(missing_local == "local_default", "Local default value failed")

	print("  ✓ Default values passed")
