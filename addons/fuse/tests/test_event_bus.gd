# 文件：addons/fuse/tests/test_event_bus.gd
extends Node

## Event Bus 测试脚本
##
## 测试 FuseEventBus、SendEvent 指令和 OnReceiveEvent 事件

# 测试结果
var _tests_passed: int = 0
var _tests_failed: int = 0
var _test_results: Array[String] = []

# 测试状态
var _event_received: bool = false
var _received_args: Dictionary = {}


func _ready() -> void:
	print("========================================")
	print("Fuse Event Bus 测试")
	print("========================================")

	# 运行所有测试
	await _run_all_tests()

	# 输出结果
	_print_results()


func _run_all_tests() -> void:
	# Event Bus 核心测试
	await _test_event_bus_basics()
	await _test_event_bus_subscribe_unsubscribe()
	await _test_event_bus_multiple_listeners()
	await _test_event_bus_deferred()

	# SendEvent 指令测试（需要完整场景）
	# OnReceiveEvent 事件测试（需要完整场景）


# ========================================
# 辅助方法：获取 Event Bus
# ========================================

func _get_event_bus() -> Node:
	return get_tree().root.get_node_or_null("FuseEventBus")


# ========================================
# 测试用例
# ========================================

func _test_event_bus_basics() -> void:
	_start_test("Event Bus 基础功能")

	var bus: Node = _get_event_bus()
	if bus == null:
		_fail_test("无法获取 FuseEventBus 实例")
		return

	# 测试发送事件（使用 Dictionary 存储状态，避免 lambda 捕获问题）
	var state := {"received": false}
	var sub: RefCounted = bus.subscribe("test_basic", func(args: Dictionary):
		state["received"] = true
	)

	bus.send_event("test_basic", {})

	if state["received"]:
		_pass_test()
	else:
		_fail_test("事件未被接收")

	bus.unsubscribe(sub)


func _test_event_bus_subscribe_unsubscribe() -> void:
	_start_test("Event Bus 订阅/取消订阅")

	var bus: Node = _get_event_bus()
	if bus == null:
		_fail_test("无法获取 FuseEventBus 实例")
		return

	# 检查初始状态
	var initial_count: int = bus.get_listener_count("test_sub")
	var sub: RefCounted = bus.subscribe("test_sub", func(args: Dictionary): pass)

	var after_subscribe: int = bus.get_listener_count("test_sub")

	bus.unsubscribe(sub)

	var after_unsubscribe: int = bus.get_listener_count("test_sub")

	if after_subscribe == initial_count + 1 and after_unsubscribe == initial_count:
		_pass_test()
	else:
		_fail_test("订阅/取消订阅计数不正确: %d -> %d -> %d" % [initial_count, after_subscribe, after_unsubscribe])


func _test_event_bus_multiple_listeners() -> void:
	_start_test("Event Bus 多监听器")

	var bus: Node = _get_event_bus()
	if bus == null:
		_fail_test("无法获取 FuseEventBus 实例")
		return

	# 使用 Dictionary 存储计数，避免 lambda 捕获问题
	var state := {"count": 0}

	var sub1: RefCounted = bus.subscribe("test_multi", func(args: Dictionary): state["count"] += 1)
	var sub2: RefCounted = bus.subscribe("test_multi", func(args: Dictionary): state["count"] += 1)
	var sub3: RefCounted = bus.subscribe("test_multi", func(args: Dictionary): state["count"] += 1)

	bus.send_event("test_multi", {})

	bus.unsubscribe(sub1)
	bus.unsubscribe(sub2)
	bus.unsubscribe(sub3)

	if state["count"] == 3:
		_pass_test()
	else:
		_fail_test("期望 3 个监听器响应，实际: %d" % state["count"])


func _test_event_bus_deferred() -> void:
	_start_test("Event Bus 延迟发送")

	var bus: Node = _get_event_bus()
	if bus == null:
		_fail_test("无法获取 FuseEventBus 实例")
		return

	# 使用 Dictionary 存储状态，避免 lambda 捕获问题
	var state := {"received": false}
	var sub: RefCounted = bus.subscribe("test_deferred", func(args: Dictionary):
		state["received"] = true
	)

	bus.send_event_deferred("test_deferred", {})

	# 立即检查应该是 false
	if state["received"]:
		bus.unsubscribe(sub)
		_fail_test("延迟事件被立即接收")
		return

	# 等待一帧
	await get_tree().process_frame

	bus.unsubscribe(sub)

	if state["received"]:
		_pass_test()
	else:
		_fail_test("延迟事件未被接收")


# ========================================
# 测试辅助方法
# ========================================

func _start_test(name: String) -> void:
	print("\n[测试] %s" % name)


func _pass_test() -> void:
	_tests_passed += 1
	_test_results.append("✅ 通过")
	print("  ✅ 通过")


func _fail_test(reason: String) -> void:
	_tests_failed += 1
	_test_results.append("❌ 失败: %s" % reason)
	print("  ❌ 失败: %s" % reason)


func _print_results() -> void:
	print("\n========================================")
	print("测试结果汇总")
	print("========================================")
	print("通过: %d" % _tests_passed)
	print("失败: %d" % _tests_failed)
	print("总计: %d" % (_tests_passed + _tests_failed))
	print("========================================")

	if _tests_failed == 0:
		print("🎉 所有测试通过！")
	else:
		print("⚠️ 部分测试失败")
