extends Node

## B12 测试：PER_OBJECT_COOLDOWN 的 object_cooldowns 自动清理（内存泄漏修复）
##
## BaseTrigger 是 @abstract，无法直接实例化。
## 本测试构造一个最小 concrete 子类 stub（_StubTrigger），仅实现 _check_cooldown
## 调用所需的抽象方法（get_runtime_event_instance_at 等），其余为空。
##
## 验证：触发 N 个不同 object_id 后，object_cooldowns 字典增长；
## 当我们将 RuntimeEventInstance 的 object_cooldowns 中部分条目人工置为过期，
## 下一次 _check_cooldown 调用应清理这些过期条目（字典 size 减小）。

const BaseTriggerClass = preload("res://addons/fuse/core/base_trigger.gd")
const RuntimeEventInstanceClass = preload("res://addons/fuse/core/runtime_event_instance.gd")
const BaseEventClass = preload("res://addons/fuse/core/base/base_event.gd")

var _fail_count: int = 0


func _ready() -> void:
	_test_object_cooldowns_cleanup_expired_entries()
	print("\n=== 结果: %d 处失败 ===" % _fail_count)
	if _fail_count > 0:
		push_error("BaseTrigger object_cooldowns 清理测试失败: %d 处" % _fail_count)
	get_tree().quit()


func _check(condition: bool, msg: String) -> void:
	if condition:
		print("  PASS: ", msg)
	else:
		_fail_count += 1
		push_error("  FAIL: ", msg)


## ==================== 测试用例 ====================

## B12 主测试：过期 object_cooldowns 条目在下一次 _check_cooldown 调用时被清理
func _test_object_cooldowns_cleanup_expired_entries() -> void:
	print("\n[test_object_cooldowns_cleanup_expired_entries] 开始...")
	var trigger := _StubTrigger.new()
	add_child(trigger)

	# 构造 RuntimeEventInstance（需要 BaseEvent + trigger）
	var event_def := _DummyEvent.new()
	var event_instance: RuntimeEventInstance = RuntimeEventInstanceClass.new(event_def, trigger)
	trigger.set_runtime_event_instance(event_instance)

	# 准备一个 context（Node）作为触发物体
	var target1 := Node.new()
	target1.name = "Target1"
	add_child(target1)

	var cooldown_time: float = 1.0

	# 触发若干不同物体，让 object_cooldowns 增长
	# 注意：object_id 来自 context.get_instance_id()
	# 我们直接手工往 object_cooldowns 注入"过期"和"未过期"条目，以确定性测试清理逻辑
	var current_time: float = Time.get_ticks_msec() / 1000.0
	var object_cooldowns: Dictionary = {}
	# 5 个过期条目（last_time 远早于 current_time，超过 cooldown_time * TTL_MULTIPLIER）
	for i in range(5):
		# 用伪造的 id（非真实节点），避免与 target1 冲突
		object_cooldowns[10000 + i] = current_time - 1000.0  # 远过期
	# 2 个未过期条目（在冷却期内）
	object_cooldowns[20000] = current_time
	object_cooldowns[20001] = current_time
	# 1 个刚过期但未达 TTL（在 cooldown_time 之后但小于 TTL_MULTIPLIER 倍）—— 应保留（边界）
	# TTL_MULTIPLIER 默认 4：cooldown_time=1.0，TTL=4.0
	# 距 now 2.0 秒 → cooldown 已过（>1.0），但 TTL 未到（<4.0）→ 保留
	object_cooldowns[30000] = current_time - 2.0

	event_instance.runtime_state["object_cooldowns"] = object_cooldowns

	# 断言初始状态
	_check(object_cooldowns.size() == 8, "初始 object_cooldowns 应有 8 条（5 过期 + 2 未过期 + 1 边界），实际: %d" % object_cooldowns.size())

	# 调用 _check_cooldown —— 触发清理逻辑
	# 用 target1 作为 context（其 object_id 未在 object_cooldowns 中 → 不会被冷却拦截 → 返回 true）
	var can_trigger: bool = trigger._check_cooldown(0, target1, BaseTriggerClass.CooldownMode.PER_OBJECT_COOLDOWN, cooldown_time)
	_check(can_trigger == true, "_check_cooldown 对新 target 应返回 true（不在冷却中）")

	# 验证清理：5 个过期条目应被清，3 个未过期/边界应保留，外加 target1 自身新增 1 条
	# 净结果：8 - 5（清理）+ 1（target1 写入）= 4
	var cleaned: Dictionary = event_instance.runtime_state.get("object_cooldowns", {})
	var cleaned_size: int = cleaned.size()
	_check(cleaned_size == 4, "清理后 object_cooldowns 应剩 4 条（2 未过期 + 1 边界 + 1 新 target1），实际: %d" % cleaned_size)

	# 验证过期条目已删
	for i in range(5):
		_check(not cleaned.has(10000 + i), "过期条目 id=%d 应被清理" % (10000 + i))

	# 验证未过期 + 边界条目保留
	_check(cleaned.has(20000), "未过期 id=20000 应保留")
	_check(cleaned.has(20001), "未过期 id=20001 应保留")
	_check(cleaned.has(30000), "边界 id=30000（TTL 未到）应保留")

	# 清理
	target1.queue_free()
	trigger.queue_free()


## ==================== Stub 类 ====================

## 最小 concrete BaseTrigger 子类，用于测试 _check_cooldown
class _StubTrigger extends BaseTriggerClass:
	var _runtime_event_instance: RuntimeEventInstance = null

	func set_runtime_event_instance(inst: RuntimeEventInstance) -> void:
		_runtime_event_instance = inst

	# 实现抽象方法（仅 get_runtime_event_instance_at 是 _check_cooldown 实际依赖的）
	func get_event_count() -> int:
		return 1

	func get_event_at(index: int) -> BaseEvent:
		return null

	func get_runtime_event_instance_at(index: int) -> RuntimeEventInstance:
		return _runtime_event_instance

	func get_action_runner_instance_at(index: int) -> RuntimeActionRunnerInstance:
		return null

	func _on_pool_reset() -> void:
		pass


## 最小 BaseEvent 子类（RuntimeEventInstance._init 需要 BaseEvent）
## BaseEvent 是 @abstract，需实现 _update_resource_name
class _DummyEvent extends BaseEventClass:
	# 实现 @abstract _update_resource_name
	func _update_resource_name() -> void:
		pass

	func get_event_type() -> String:
		return "test"

	func get_description() -> String:
		return "DummyEvent for B12 test"
