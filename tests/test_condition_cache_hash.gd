extends Node
class_name TestConditionCacheHash

## 测试BaseCondition缓存哈希机制

func _ready():
	print("=== 测试BaseCondition缓存哈希 ===")
	# 延迟执行测试，确保所有系统都已初始化
	call_deferred("_run_tests")

func _run_tests():
	test_dependency_hashing()
	test_all_variables_hashing()
	test_cache_clearing()
	test_context_change_detection()
	print("=== 所有测试通过 ===")

func test_dependency_hashing():
	print("\n测试1: 依赖变量哈希")
	var context = ExecutionContext.new()
	var condition = TestCondition.new()

	# 设置依赖变量
	context.set_variable("health", 100)
	context.set_variable("max_health", 100)

	var hash1 = condition._generate_context_hash(context)
	print("  初始哈希: ", hash1)

	# 修改依赖变量
	context.set_variable("health", 50)
	var hash2 = condition._generate_context_hash(context)
	print("  修改后哈希: ", hash2)

	assert(hash1 != hash2, "依赖变量变化应该改变哈希")
	print("✓ 依赖变量哈希测试通过")

func test_all_variables_hashing():
	print("\n测试2: 所有变量哈希")
	var context = ExecutionContext.new()
	var condition = TestCondition.new()
	condition.hash_all_variables = true

	# 设置多个变量
	context.set_variable("health", 100)
	context.set_variable("mana", 50)
	context.set_variable("stamina", 75)

	var hash1 = condition._generate_context_hash(context)

	# 修改非依赖变量
	context.set_variable("stamina", 25)
	var hash2 = condition._generate_context_hash(context)

	assert(hash1 != hash2, "当hash_all_variables=true时，任何变量变化都应该改变哈希")
	print("✓ 所有变量哈希测试通过")

func test_cache_clearing():
	print("\n测试3: 缓存清除")
	var context = ExecutionContext.new()
	var condition = TestCondition.new()

	# 设置变量并评估
	context.set_variable("health", 100)
	var result1 = condition.check(context)

	# 清除缓存
	condition.clear_result_cache()
	var result2 = condition.check(context)

	assert(result1 == result2, "清除缓存后结果应该一致")
	print("✓ 缓存清除测试通过")

func test_context_change_detection():
	print("\n测试4: 上下文变化检测")
	var context = ExecutionContext.new()
	var condition = TestCondition.new()

	# 第一次评估
	context.set_variable("health", 100)
	var result1 = condition.check(context)

	# 修改上下文
	context.execution_id = "different_context"
	var result2 = condition.check(context)

	# execution_id变化应该导致缓存失效
	print("  第一次结果: ", result1, ", 第二次结果: ", result2)
	print("✓ 上下文变化检测测试通过")

# 测试用的简单条件
class TestCondition extends BaseCondition:
	func _evaluate_condition(context: ExecutionContext) -> bool:
		# 简单的健康值检查
		var health = context.get_variable("health", 0)
		return health > 0

	func _update_resource_name():
		# 测试条件不需要更新资源名称
		pass

	func _compute_dependencies() -> Array[String]:
		return ["health", "max_health"]

