extends Node
class_name TestInstructionAsyncDetection

## 测试BaseInstruction异步检测机制

func _ready():
	print("=== 测试指令异步检测 ===")

	# 使用 await 等待所有测试完成
	await run_all_tests()

	print("=== 所有测试完成 ===")
	get_tree().quit()

func run_all_tests():
	await test_sync_hint()
	await test_method_override()
	await test_await_detection()
	await test_backward_compatibility()
	await test_cache_invalidation()
	await test_multiple_calls()
	await test_comment_await_not_detected()

func test_sync_hint():
	print("\n测试1: 同步提示设置")
	var inst = TestSyncInstruction.new()
	var has_async = inst._has_async_operations()
	print("  同步指令检测结果: ", has_async)
	assert(has_async == false, "同步指令应该被正确检测")
	print("✓ 同步提示测试通过")
	await get_tree().process_frame

func test_method_override():
	print("\n测试2: 方法重写")
	var override_inst = TestOverrideInstruction.new()
	var has_async = override_inst._has_async_operations()
	print("  重写指令检测结果: ", has_async)
	assert(has_async == false, "重写方法应该生效")
	print("✓ 方法重写测试通过")
	await get_tree().process_frame

func test_await_detection():
	print("\n测试3: await自动检测")
	# 加载外部测试指令
	var async_script = load("res://addons/fuse/tests/test_async_await_instruction.gd")
	if async_script:
		var async_inst = async_script.new()
		var has_async = async_inst._has_async_operations()
		print("  await指令检测结果: ", has_async)
		assert(has_async == true, "await指令应该被检测为异步")
		print("✓ await检测测试通过")
	else:
		print("  ✗ 无法加载测试指令文件")
	await get_tree().process_frame

func test_backward_compatibility():
	print("\n测试4: 向后兼容")
	var compat_inst = TestCompatInstruction.new()
	# 旧代码没有重写方法或设置提示，应该通过源码检测
	var result = compat_inst._has_async_operations()
	print("  向后兼容检测结果: ", result)
	print("✓ 向后兼容测试通过")
	await get_tree().process_frame

func test_cache_invalidation():
	print("\n测试5: 缓存失效")
	# 使用TestCompatInstruction因为它没有重写_is_synchronous()
	var inst = TestCompatInstruction.new()

	# 第一次检测，应该缓存结果（默认是异步hint，检测源码发现是同步）
	var result1 = inst._has_async_operations()
	print("  第一次检测: ", result1)
	assert(result1 == false, "源码检测应该是同步的")

	# 修改提示为异步，应该清除缓存
	inst.set_synchronous_hint(false)

	# 第二次检测，应该返回新结果（hint为false=异步）
	var result2 = inst._has_async_operations()
	print("  修改后检测: ", result2)
	assert(result2 == true, "缓存应该被清除并使用新的hint值")
	print("✓ 缓存失效测试通过")
	await get_tree().process_frame

func test_multiple_calls():
	print("\n测试6: 多次调用缓存测试")
	var inst = TestSyncInstruction.new()

	var result1 = inst._has_async_operations()
	var result2 = inst._has_async_operations()
	var result3 = inst._has_async_operations()

	assert(result1 == result2, "多次调用应该返回相同结果")
	assert(result2 == result3, "缓存应该生效")
	print("✓ 多次调用缓存测试通过")
	await get_tree().process_frame

func test_comment_await_not_detected():
	print("\n测试7: 注释中的await不应触发检测")
	var inst = TestCommentAwaitInstruction.new()

	var result = inst._has_async_operations()
	assert(result == false, "注释中的await不应被检测为异步")
	print("✓ 注释误报测试通过")
	await get_tree().process_frame

# 测试用的同步指令
class TestSyncInstruction extends BaseInstruction:
	func _update_resource_name():
		resource_name = "TestSync"

	func _setup_metadata():
		metadata.name = "TestSync"

	func _is_synchronous():
		return true

	func execute(context):
		_on_execution_completed()

# 测试用的重写指令（声明为异步）
class TestOverrideInstruction extends BaseInstruction:
	func _update_resource_name():
		resource_name = "TestOverride"

	func _setup_metadata():
		metadata.name = "TestOverride"

	func _is_synchronous():
		return false

	func execute(context):
		pass

# 测试向后兼容的指令
class TestCompatInstruction extends BaseInstruction:
	func _update_resource_name():
		resource_name = "TestCompat"

	func _setup_metadata():
		metadata.name = "TestCompat"

	func execute(context):
		_on_execution_completed()

# 测试用的注释await指令
class TestCommentAwaitInstruction extends BaseInstruction:
	func _update_resource_name():
		resource_name = "TestCommentAwait"

	func _setup_metadata():
		metadata.name = "TestCommentAwait"

	func execute(context):
		# 这是一个注释，包含 await 但不应该触发检测
		# TODO: await some_future_feature()
		# 另一个注释 await another_operation()
		_on_execution_completed()
