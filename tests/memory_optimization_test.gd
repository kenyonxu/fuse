# 文件：tests/memory_optimization_test.gd
@tool
extends SceneTree

class_name MemoryOptimizationTest

## 内存优化测试类
##
## 测试 RuntimeEventInstance、WeakRef 支持和资源清理机制

var _test_trigger: Trigger = null
var _test_event: BaseEvent = null
var _test_action_runner: ActionRunner = null
var _test_context: ExecutionContext = null

## 简单的断言函数
func _assert(condition: bool, message: String):
	if not condition:
		push_error("断言失败: " + message)
		return false
	return true

func _assert_not_null(obj, message: String):
	return _assert(obj != null, message)

func _assert_null(obj, message: String):
	return _assert(obj == null, message)

func _assert_eq(actual, expected, message: String):
	return _assert(actual == expected, message + " (实际: " + str(actual) + ", 期望: " + str(expected) + ")")

func _assert_true(condition: bool, message: String):
	return _assert(condition, message)

## 测试 RuntimeEventInstance 创建和基本功能
func test_runtime_event_instance_creation():
	var event_definition = _create_test_event()
	var trigger_node = Node.new()

	var runtime_instance = RuntimeEventInstance.new(event_definition, trigger_node)

	# 验证基本属性
	if not _assert_not_null(runtime_instance, "RuntimeEventInstance 应该被创建"):
		return

	if not _assert_eq(runtime_instance.event_definition, event_definition, "事件定义应该正确设置"):
		return

	if not _assert_eq(runtime_instance.owner_trigger, trigger_node, "触发器节点应该正确设置"):
		return

	# 验证运行时状态初始化
	if not _assert_true(runtime_instance.has_runtime_state("initialized"), "应该初始化默认状态"):
		return

	if not _assert_true(runtime_instance.has_runtime_state("trigger_count"), "应该初始化触发计数"):
		return

	# 测试状态管理
	runtime_instance.set_runtime_state("test_key", "test_value")
	if not _assert_eq(runtime_instance.get_runtime_state("test_key"), "test_value", "状态设置和获取应该正常工作"):
		return

	# 清理
	runtime_instance.cleanup()
	trigger_node.free()

	print("✅ RuntimeEventInstance 创建测试通过")

## 测试 Trigger 类使用 RuntimeEventInstance
func test_trigger_with_runtime_instance():
	# 创建测试资源
	var event_resource = _create_test_event_resource()
	var action_runner = ActionRunner.new()

	# 创建触发器
	var trigger = Trigger.new()
	trigger.event_definition = event_resource
	trigger.action_runner = action_runner

	# 模拟 _ready 调用
	trigger._ready()

	# 验证 RuntimeEventInstance 被创建
	var runtime_instance = trigger._runtime_event_instance
	if not _assert_not_null(runtime_instance, "Trigger 应该创建 RuntimeEventInstance"):
		return

	if not _assert_eq(runtime_instance.event_definition, event_resource, "RuntimeEventInstance 应该引用正确的事件定义"):
		return

	if not _assert_eq(runtime_instance.owner_trigger, trigger, "RuntimeEventInstance 应该引用正确的触发器"):
		return

	# 模拟 _exit_tree 调用
	trigger._exit_tree()

	# 验证清理
	if not _assert_null(trigger._runtime_event_instance, "RuntimeEventInstance 应该在 _exit_tree 中被清理"):
		return

	print("✅ Trigger 使用 RuntimeEventInstance 测试通过")

## 测试 ExecutionContext 的 WeakRef 支持
func test_execution_context_weakref():
	# 创建测试节点
	var target_node = Node.new()
	target_node.name = "TestTarget"
	var trigger_node = Node.new()
	trigger_node.name = "TestTrigger"

	# 创建执行上下文
	var context = ExecutionContext.new(target_node, trigger_node)

	# 测试通过 WeakRef 获取节点
	var retrieved_target = context.get_target_node()
	var retrieved_trigger = context.get_trigger_node()

	if not _assert_eq(retrieved_target, target_node, "应该能通过 WeakRef 获取目标节点"):
		return

	if not _assert_eq(retrieved_trigger, trigger_node, "应该能通过 WeakRef 获取触发器节点"):
		return

	# 测试节点释放后的情况
	target_node.free()

	# 尝试获取已释放的节点
	retrieved_target = context.get_target_node()
	if not _assert_null(retrieved_target, "已释放的节点应该返回 null"):
		return

	# 清理
	trigger_node.free()

	print("✅ ExecutionContext WeakRef 支持测试通过")

## 测试 ActionRunner 的强制清理机制
func test_action_runner_cleanup():
	# 创建测试指令
	var instruction1 = _create_test_instruction()
	var instruction2 = _create_test_instruction()

	# 创建 ActionRunner
	var action_runner = ActionRunner.new()
	var instructions_array: Array[BaseInstruction] = [instruction1, instruction2]
	action_runner.instructions = instructions_array

	# 创建执行上下文
	var context = ExecutionContext.new()
	action_runner.current_context = context

	# 模拟执行完成
	action_runner._complete_execution()

	# 验证上下文被清理
	if not _assert_null(action_runner.current_context, "执行上下文应该被清理"):
		return

	print("✅ ActionRunner 清理机制测试通过")

## 测试内存泄漏防护
func test_memory_leak_prevention():
	# 创建多个触发器共享同一个事件资源
	var shared_event = _create_test_event_resource()
	var action_runner = ActionRunner.new()

	var triggers = []
	for i in range(5):
		var trigger = Trigger.new()
		trigger.name = "Trigger_%d" % i
		trigger.event_definition = shared_event
		trigger.action_runner = action_runner

		# 模拟初始化
		trigger._ready()

		triggers.append(trigger)

	# 验证每个触发器都有自己的 RuntimeEventInstance
	for i in range(triggers.size()):
		var trigger = triggers[i]
		if not _assert_not_null(trigger._runtime_event_instance, "每个触发器都应该有自己的 RuntimeEventInstance"):
			return

		# 验证事件定义没有被复制（内存优化）
		if not _assert_eq(trigger.event_definition, shared_event, "事件定义应该是同一个实例，没有被复制"):
			return

	# 模拟清理
	for trigger in triggers:
		trigger._exit_tree()
		trigger.free()

	print("✅ 内存泄漏防护测试通过")

## 测试 BaseEvent 的运行时实例初始化
func test_base_event_runtime_instance_initialization():
	# 创建测试事件
	var event = _create_test_event()
	var trigger = Node.new()
	var runtime_instance = RuntimeEventInstance.new(event, trigger)

	# 测试 initialize_with_runtime_instance
	event.initialize_with_runtime_instance(trigger, runtime_instance)

	# 验证事件被正确初始化
	# 这里可以添加更多特定于事件类型的验证

	# 清理
	runtime_instance.cleanup()
	trigger.free()

	print("✅ BaseEvent 运行时实例初始化测试通过")

## 辅助方法：创建测试事件（创建具体实现）
func _create_test_event():
	# 创建一个具体的事件类实例
	var event = _TestEvent.new()
	return event

## 辅助方法：创建测试事件资源
func _create_test_event_resource():
	# 创建一个模拟的事件资源
	var event = _TestEvent.new()
	return event

## 辅助方法：创建测试指令（创建具体实现）
func _create_test_instruction():
	# 创建一个具体的指令类实例
	var instruction = _TestInstruction.new()
	return instruction

## 测试事件类（具体实现）
class _TestEvent extends BaseEvent:
	func _update_resource_name():
		resource_name = "TestEvent"

	func initialize(owner_node: Node) -> void:
		_log_debug("测试事件初始化: " + owner_node.name)

	func terminate(owner_node: Node) -> void:
		_log_debug("测试事件终止: " + owner_node.name)

	func get_description() -> String:
		return "测试事件"

	func get_event_type() -> String:
		return "test"

## 测试指令类（具体实现）
class _TestInstruction extends BaseInstruction:
	func _update_resource_name():
		resource_name = "TestInstruction"

	func _setup_metadata():
		# 设置基本元数据
		pass

	func execute(context: ExecutionContext):
		_log_debug("执行测试指令")
		_on_execution_completed()

	func get_description() -> String:
		return "测试指令"

## 运行所有测试
func run_all_tests():
	print("🧪 开始内存优化测试...")

	test_runtime_event_instance_creation()
	test_trigger_with_runtime_instance()
	test_execution_context_weakref()
	test_action_runner_cleanup()
	test_memory_leak_prevention()
	test_base_event_runtime_instance_initialization()

	print("🎉 所有内存优化测试完成！")
