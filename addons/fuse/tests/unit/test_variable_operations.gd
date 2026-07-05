## addons/fuse/tests/unit/test_variable_operations.gd
extends Node

## VariableOperations 工具类单元测试
##
## 测试覆盖：
## - LOCAL 变量操作（读取/设置/检查）
## - SCOPE 变量操作（读取/设置/检查）
## - GLOBAL 变量操作（读取/设置/检查）
## - 错误处理（空值/无效参数）
## - 作用域容器查找

var test_context: ExecutionContext
var test_scope_container: ScopeVariableContainer
var test_node: Node
var global_assistant: GlobalVariableAssistant

func _ready():
	print("=== 开始 VariableOperations 单元测试 ===\n")

	# 初始化测试环境
	setup_test_environment()

	# 运行所有测试
	test_local_variable_operations()
	test_scope_variable_operations()
	test_global_variable_operations()
	test_error_handling()
	test_has_variable()
	test_get_scope_container()

	# 清理
	cleanup_test_environment()

	print("\n=== VariableOperations 测试完成 ===")

## 设置测试环境
func setup_test_environment():
	print("--- 设置测试环境 ---")

	# 创建测试节点树
	test_node = Node.new()
	test_node.name = "TestRoot"

	# 创建作用域容器
	test_scope_container = ScopeVariableContainer.new()
	test_scope_container.name = "TestScope"
	test_scope_container.scope_id = "test_scope"
	test_node.add_child(test_scope_container)

	# 获取全局变量助手
	global_assistant = GlobalVariableAssistant.get_instance()

	# 创建执行上下文
	test_context = ExecutionContext.new()
	test_context.trigger = test_scope_container
	test_context.global_variables = global_assistant

	print("✓ 测试环境设置完成\n")

## 清理测试环境
func cleanup_test_environment():
	print("\n--- 清理测试环境 ---")

	if test_context != null:
		test_context.cleanup()
		test_context = null

	if test_node != null:
		test_node.queue_free()
		test_node = null

	# 清理可能创建的全局变量
	if global_assistant != null:
		if global_assistant.has_global_variable("global_test"):
			global_assistant.remove_global_variable("global_test")
		if global_assistant.has_global_variable("new_global_var"):
			global_assistant.remove_global_variable("new_global_var")

	print("✓ 测试环境清理完成")

## ==================== LOCAL 变量测试 ====================

func test_local_variable_operations():
	print("=== 测试 LOCAL 变量操作 ===")

	test_get_local_variable()
	test_set_local_variable()
	test_local_variable_default_value()

## 测试 LOCAL 变量读取
func test_get_local_variable():
	print("\n[测试] LOCAL 变量读取")

	# 设置局部变量
	test_context.set_variable("test_var", 42, "local")

	# 使用工具类读取
	var value = VariableOperations.get_variable(
		test_context,
		"test_var",
		BaseVariable.VariableScope.LOCAL,
		0
	)

	_assert(value == 42, "应该读取到局部变量值 42，实际值: %s" % str(value))
	print("  ✓ 读取局部变量: test_var = %s" % str(value))

## 测试 LOCAL 变量设置
func test_set_local_variable():
	print("\n[测试] LOCAL 变量设置")

	var success = VariableOperations.set_variable(
		test_context,
		"new_var",
		BaseVariable.VariableScope.LOCAL,
		100
	)

	_assert(success, "设置局部变量应该成功")
	print("  ✓ 设置局部变量: new_var = 100")

	# 验证值
	var value = test_context.get_variable("new_var", 0)
	_assert(value == 100, "值应该为 100，实际值: %s" % str(value))
	print("  ✓ 验证值正确: %s" % str(value))

## 测试 LOCAL 变量默认值
func test_local_variable_default_value():
	print("\n[测试] LOCAL 变量默认值")

	var value = VariableOperations.get_variable(
		test_context,
		"non_existent_var",
		BaseVariable.VariableScope.LOCAL,
		-1
	)

	_assert(value == -1, "应该返回默认值 -1，实际值: %s" % str(value))
	print("  ✓ 不存在的变量返回默认值: %s" % str(value))

## ==================== SCOPE 变量测试 ====================

func test_scope_variable_operations():
	print("\n=== 测试 SCOPE 变量操作 ===")

	test_get_scope_variable()
	test_set_scope_variable()
	test_scope_variable_default_value()

## 测试 SCOPE 变量读取
func test_get_scope_variable():
	print("\n[测试] SCOPE 变量读取")

	# 在作用域容器中设置变量
	test_scope_container.set_variable("scope_var", 99)

	# 使用工具类读取
	var value = VariableOperations.get_variable(
		test_context,
		"scope_var",
		BaseVariable.VariableScope.SCOPE,
		0
	)

	_assert(value == 99, "应该读取到作用域变量值 99，实际值: %s" % str(value))
	print("  ✓ 读取作用域变量: scope_var = %s" % str(value))

## 测试 SCOPE 变量设置
func test_set_scope_variable():
	print("\n[测试] SCOPE 变量设置")

	var success = VariableOperations.set_variable(
		test_context,
		"new_scope_var",
		BaseVariable.VariableScope.SCOPE,
		200
	)

	_assert(success, "设置作用域变量应该成功")
	print("  ✓ 设置作用域变量: new_scope_var = 200")

	# 验证值
	var value = test_scope_container.get_variable("new_scope_var", 0)
	_assert(value == 200, "值应该为 200，实际值: %s" % str(value))
	print("  ✓ 验证值正确: %s" % str(value))

## 测试 SCOPE 变量默认值
func test_scope_variable_default_value():
	print("\n[测试] SCOPE 变量默认值")

	var value = VariableOperations.get_variable(
		test_context,
		"non_existent_scope_var",
		BaseVariable.VariableScope.SCOPE,
		-999
	)

	_assert(value == -999, "应该返回默认值 -999，实际值: %s" % str(value))
	print("  ✓ 不存在的作用域变量返回默认值: %s" % str(value))

## ==================== GLOBAL 变量测试 ====================

func test_global_variable_operations():
	print("\n=== 测试 GLOBAL 变量操作 ===")

	test_get_global_variable()
	test_set_global_variable()
	test_global_variable_default_value()

## 测试 GLOBAL 变量读取
func test_get_global_variable():
	print("\n[测试] GLOBAL 变量读取")

	# 创建全局变量
	var test_var = BaseVariable.create("global_test", 777, BaseVariable.VariableScope.GLOBAL)
	global_assistant.add_global_variable("global_test", test_var)

	# 使用工具类读取
	var value = VariableOperations.get_variable(
		test_context,
		"global_test",
		BaseVariable.VariableScope.GLOBAL,
		0
	)

	_assert(value == 777, "应该读取到全局变量值 777，实际值: %s" % str(value))
	print("  ✓ 读取全局变量: global_test = %s" % str(value))

## 测试 GLOBAL 变量设置
func test_set_global_variable():
	print("\n[测试] GLOBAL 变量设置")

	var success = VariableOperations.set_variable(
		test_context,
		"new_global_var",
		BaseVariable.VariableScope.GLOBAL,
		999
	)

	_assert(success, "设置全局变量应该成功")
	print("  ✓ 设置全局变量: new_global_var = 999")

	# 验证值
	var variable = global_assistant.get_global_variable("new_global_var")
	_assert(variable != null, "全局变量应该存在")
	_assert(variable.get_value() == 999, "值应该为 999，实际值: %s" % str(variable.get_value()))
	print("  ✓ 验证值正确: %s" % str(variable.get_value()))

## 测试 GLOBAL 变量默认值
func test_global_variable_default_value():
	print("\n[测试] GLOBAL 变量默认值")

	var value = VariableOperations.get_variable(
		test_context,
		"non_existent_global_var",
		BaseVariable.VariableScope.GLOBAL,
		-777
	)

	_assert(value == -777, "应该返回默认值 -777，实际值: %s" % str(value))
	print("  ✓ 不存在的全局变量返回默认值: %s" % str(value))

## ==================== 错误处理测试 ====================

func test_error_handling():
	print("\n=== 测试错误处理 ===")

	test_empty_variable_name()
	test_null_context()

## 测试空变量名处理
func test_empty_variable_name():
	print("\n[测试] 空变量名处理")

	var value = VariableOperations.get_variable(
		test_context,
		"",
		BaseVariable.VariableScope.LOCAL,
		999
	)

	_assert(value == 999, "空变量名应该返回默认值 999，实际值: %s" % str(value))
	print("  ✓ 空变量名返回默认值: %s" % str(value))

## 测试 null context 处理
func test_null_context():
	print("\n[测试] null context 处理")

	var value = VariableOperations.get_variable(
		null,
		"test",
		BaseVariable.VariableScope.LOCAL,
		-1
	)

	_assert(value == -1, "null context 应该返回默认值 -1，实际值: %s" % str(value))
	print("  ✓ null context 返回默认值: %s" % str(value))

## ==================== has_variable 测试 ====================

func test_has_variable():
	print("\n=== 测试 has_variable 方法 ===")

	test_has_variable_local()
	test_has_variable_scope()
	test_has_variable_global()
	test_has_variable_non_existent()

## 测试 LOCAL 变量存在检查
func test_has_variable_local():
	print("\n[测试] LOCAL 变量存在检查")

	# 设置局部变量
	test_context.set_variable("existing_var", 1, "local")

	# 检查存在
	var exists = VariableOperations.has_variable(
		test_context,
		"existing_var",
		BaseVariable.VariableScope.LOCAL
	)
	_assert(exists, "变量应该存在")
	print("  ✓ 存在的变量检查通过")

	# 检查不存在
	var not_exists = VariableOperations.has_variable(
		test_context,
		"non_existing",
		BaseVariable.VariableScope.LOCAL
	)
	_assert(not not_exists, "变量不应该存在")
	print("  ✓ 不存在的变量检查通过")

## 测试 SCOPE 变量存在检查
func test_has_variable_scope():
	print("\n[测试] SCOPE 变量存在检查")

	# 设置作用域变量
	test_scope_container.set_variable("scope_existing", "test")

	# 检查存在
	var exists = VariableOperations.has_variable(
		test_context,
		"scope_existing",
		BaseVariable.VariableScope.SCOPE
	)
	_assert(exists, "作用域变量应该存在")
	print("  ✓ 存在的作用域变量检查通过")

	# 检查不存在
	var not_exists = VariableOperations.has_variable(
		test_context,
		"scope_non_existing",
		BaseVariable.VariableScope.SCOPE
	)
	_assert(not not_exists, "作用域变量不应该存在")
	print("  ✓ 不存在的作用域变量检查通过")

## 测试 GLOBAL 变量存在检查
func test_has_variable_global():
	print("\n[测试] GLOBAL 变量存在检查")

	# 创建全局变量
	var test_var = BaseVariable.create("global_existing", 123, BaseVariable.VariableScope.GLOBAL)
	global_assistant.add_global_variable("global_existing", test_var)

	# 检查存在
	var exists = VariableOperations.has_variable(
		test_context,
		"global_existing",
		BaseVariable.VariableScope.GLOBAL
	)
	_assert(exists, "全局变量应该存在")
	print("  ✓ 存在的全局变量检查通过")

	# 检查不存在
	var not_exists = VariableOperations.has_variable(
		test_context,
		"global_non_existing",
		BaseVariable.VariableScope.GLOBAL
	)
	_assert(not not_exists, "全局变量不应该存在")
	print("  ✓ 不存在的全局变量检查通过")

## 测试不存在的变量检查
func test_has_variable_non_existent():
	print("\n[测试] 不存在的变量检查")

	var exists = VariableOperations.has_variable(
		test_context,
		"definitely_not_existing_var",
		BaseVariable.VariableScope.LOCAL
	)
	_assert(not exists, "不存在的变量应该返回 false")
	print("  ✓ 不存在的变量返回 false")

## ==================== get_scope_container 测试 ====================

func test_get_scope_container():
	print("\n=== 测试 get_scope_container 方法 ===")

	test_get_scope_container_success()
	test_get_scope_container_not_found()
	test_get_scope_container_custom_node()

## 测试成功查找作用域容器
func test_get_scope_container_success():
	print("\n[测试] 成功查找作用域容器")

	var container = VariableOperations.get_scope_container(test_context)

	_assert(container != null, "应该找到作用域容器")
	_assert(container.scope_id == "test_scope", "应该是正确的作用域容器")
	print("  ✓ 找到作用域容器: %s" % container.scope_id)

## 测试查找失败的情况
func test_get_scope_container_not_found():
	print("\n[测试] 查找失败的情况")

	# 创建没有作用域容器的节点
	var empty_node = Node.new()
	var empty_context = ExecutionContext.new()
	empty_context.trigger = empty_node

	var container = VariableOperations.get_scope_container(empty_context)

	_assert(container == null, "不应该找到作用域容器")
	print("  ✓ 正确返回 null：未找到作用域容器")

	# 清理
	empty_context.cleanup()
	empty_node.queue_free()

## 测试自定义搜索节点
func test_get_scope_container_custom_node():
	print("\n[测试] 自定义搜索节点")

	var container = VariableOperations.get_scope_container(
		test_context,
		test_scope_container
	)

	_assert(container != null, "应该找到作用域容器")
	_assert(container.scope_id == "test_scope", "应该是正确的作用域容器")
	print("  ✓ 使用自定义节点找到作用域容器: %s" % container.scope_id)

## ==================== 辅助方法 ====================

## 断言辅助方法
func _assert(condition: bool, message: String):
	if not condition:
		print("  ✗ 断言失败: %s" % message)
		push_error(message)
	else:
		if not message.is_empty():
			print("  ✓ %s" % message)
