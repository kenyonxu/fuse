extends Node

## MultiEventTrigger object_cooldowns 清理测试（mirror of B12）
##
## multi_event_trigger.gd 的 _check_binding_cooldown PER_OBJECT_COOLDOWN 分支
## 原先与 base_trigger.gd B12 修复前一样：只写不删，仅整体 erase，
## 长运行 + 物体频繁进出 → 字典无限增长（内存泄漏）。
##
## 本测试验证：MultiEventTrigger 通过调用继承自 BaseTrigger 的
## _cleanup_expired_object_cooldowns，在下一次 _check_binding_cooldown
## 调用时清理过期条目（与 base_trigger B12 行为一致）。

const MultiEventTriggerClass = preload("res://addons/fuse/core/multi_event_trigger.gd")
const EventBindingClass = preload("res://addons/fuse/core/event_binding.gd")
const BaseTriggerClass = preload("res://addons/fuse/core/base_trigger.gd")
const RuntimeEventInstanceClass = preload("res://addons/fuse/core/runtime_event_instance.gd")
const BaseEventClass = preload("res://addons/fuse/core/base/base_event.gd")

var _fail_count: int = 0


func _ready() -> void:
	_test_object_cooldowns_cleanup_expired_entries()
	print("\n=== 结果: %d 处失败 ===" % _fail_count)
	if _fail_count > 0:
		push_error("MultiEventTrigger object_cooldowns 清理测试失败: %d 处" % _fail_count)
	get_tree().quit()


func _check(condition: bool, msg: String) -> void:
	if condition:
		print("  PASS: ", msg)
	else:
		_fail_count += 1
		push_error("  FAIL: ", msg)


## ==================== 测试用例 ====================

## 主测试：过期 object_cooldowns 条目在下一次 _check_binding_cooldown 调用时被清理
func _test_object_cooldowns_cleanup_expired_entries() -> void:
	print("\n[test_object_cooldowns_cleanup_expired_entries] 开始...")

	var trigger := MultiEventTriggerClass.new()
	add_child(trigger)

	# 构造 RuntimeEventInstance（需要 BaseEvent + trigger）
	var event_def := _DummyEvent.new()
	var event_instance: RuntimeEventInstance = RuntimeEventInstanceClass.new(event_def, trigger)

	# 直接注入到 MultiEventTrigger._runtime_event_instances（index 0）
	trigger._runtime_event_instances.append(event_instance)

	# 构造 EventBinding：PER_OBJECT_COOLDOWN，cooldown_time = 1.0
	var binding := EventBindingClass.new()
	binding.cooldown_mode = BaseTriggerClass.CooldownMode.PER_OBJECT_COOLDOWN
	binding.cooldown_time = 1.0
	trigger.event_bindings.append(binding)
	# 对齐内部状态数组长度（_cleanup_runtime_instances 会按索引访问 _signal_connected）
	trigger._signal_connected.append(false)
	trigger._runtime_action_instances.append(null)

	# 准备一个 context（Node）作为触发物体（其 object_id 不在预设字典中）
	var target1 := Node.new()
	target1.name = "Target1"
	add_child(target1)

	var current_time: float = Time.get_ticks_msec() / 1000.0
	var object_cooldowns: Dictionary = {}
	# 5 个过期条目（last_time 远早于 current_time，超过 cooldown_time * TTL_MULTIPLIER）
	for i in range(5):
		object_cooldowns[10000 + i] = current_time - 1000.0
	# 2 个未过期条目（在冷却期内）
	object_cooldowns[20000] = current_time
	object_cooldowns[20001] = current_time
	# 1 个边界：cooldown 已过但 TTL 未到（TTL_MULTIPLIER=4，cooldown_time=1.0 → TTL=4.0）
	# 距 now 2.0 秒 → >1.0 但 <4.0 → 应保留
	object_cooldowns[30000] = current_time - 2.0

	event_instance.runtime_state["object_cooldowns"] = object_cooldowns

	# 断言初始状态
	_check(object_cooldowns.size() == 8, "初始 object_cooldowns 应有 8 条（5 过期 + 2 未过期 + 1 边界），实际: %d" % object_cooldowns.size())

	# 调用 _check_binding_cooldown —— 触发清理 + 写入 target1
	# target1.object_id 不在预设字典 → 不会被冷却拦截 → 返回 true
	var can_trigger: bool = trigger._check_binding_cooldown(0, target1)
	_check(can_trigger == true, "_check_binding_cooldown 对新 target 应返回 true（不在冷却中）")

	# 验证清理：5 过期删，3 保留（2 未过期 + 1 边界），target1 新增 1 → 净 4
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

## 最小 BaseEvent 子类（RuntimeEventInstance._init 需要 BaseEvent）
class _DummyEvent extends BaseEventClass:
	func _update_resource_name() -> void:
		pass

	func get_event_type() -> String:
		return "test"

	func get_description() -> String:
		return "DummyEvent for multi_event_trigger cooldown cleanup test"
