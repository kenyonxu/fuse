# 测试：OnVariableChanged 五连修——轮询触发/SCOPE CUSTOM_ID 跨容器/args 桥接/初始化不假触发
extends Node

var _fail: int = 0
var _records: Array = []

## 记录 event_* 值的探针指令
class EventProbe:
	extends BaseInstruction
	var records: Array
	func _init(records: Array = []) -> void:
		self.records = records
	func _setup_metadata() -> void: pass
	func _update_resource_name() -> void: resource_name = "EventProbe"
	func execute(context: ExecutionContext) -> void:
		_start_execution(context)
		records.append(context.get_variable("event_new_value"))
		records.append(context.get_variable("event_old_value"))
		_on_execution_completed()
	func get_description() -> String: return "EventProbe"

func _ready() -> void:
	print("=== OnVariableChanged 修复测试开始 ===")
	await _test_full_chain()
	print("=== OnVariableChanged 修复测试完成（失败 %d 项）===" % _fail)
	get_tree().quit(1 if _fail > 0 else 0)

func _check(condition: bool, message: String) -> void:
	if condition:
		print("✓ " + message)
	else:
		_fail += 1
		push_error("✗ " + message)

## 全链路：ScopeVariableContainer(life=3) + MultiEventTrigger + OnVariableChanged(SCOPE/CUSTOM_ID) + EventProbe
func _test_full_chain() -> void:
	print("\n--- 全链路（SCOPE CUSTOM_ID 跨容器） ---")
	# 模拟 player 容器（UI 场景外的另一棵子树）
	var holder := Node.new()
	holder.name = "PlayerHolder"
	add_child(holder)
	var container := ScopeVariableContainer.new()
	container.scope_id = "player_vars"
	container.name = "PlayerVariables"
	holder.add_child(container)
	# 容器注册是 call_deferred（帧末），process_frame 信号在帧首——等两帧确保注册完成，
	# 否则 initialize 采样 null、首查读到值 → 假触发（组件本身无此问题）
	await get_tree().process_frame
	await get_tree().process_frame
	# 写入 life=3（容器 API）
	container.set_variable("life", 3)

	# UI 侧：MultiEventTrigger + 事件
	var ui_root := Node.new()
	ui_root.name = "UIRoot"
	add_child(ui_root)

	var probe_records: Array = []
	var instructions: Array[BaseInstruction] = []
	instructions.append(EventProbe.new(probe_records))
	var ar := ActionRunner.new()
	ar.instructions = instructions

	var ev := OnVariableChanged.new()
	ev.variable_name = "life"
	ev.variable_scope = BaseVariable.VariableScope.SCOPE
	ev.scope_source = 1  # CUSTOM_ID
	ev.custom_scope_id = "player_vars"
	ev.check_interval = 0.05

	var binding := EventBinding.new()
	binding.event = ev
	binding.action_runner = ar

	var multi := MultiEventTrigger.new()
	multi.name = "LifeWatcher"
	multi.event_bindings = [binding]
	ui_root.add_child(multi)
	await get_tree().process_frame

	# 1) 初始化不假触发（初始化时 last_value 已采样为 3）
	await get_tree().create_timer(0.2).timeout
	_check(probe_records.is_empty(), "初始化不假触发（ON_CHANGE 首查与初值相等）")

	# 2) 改变量 → 0.05s 轮询内触发
	container.set_variable("life", 2)
	var waited := 0.0
	while probe_records.is_empty() and waited < 1.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
	_check(probe_records.size() == 2, "变化后触发（等待 %.2fs）" % waited)
	if probe_records.size() >= 2:
		_check(probe_records[0] == 2, "event_new_value == 2（实际 %s）" % str(probe_records[0]))
		_check(probe_records[1] == 3, "event_old_value == 3（实际 %s）" % str(probe_records[1]))

	# 3) 不变化的轮询不再触发
	probe_records.clear()
	await get_tree().create_timer(0.3).timeout
	_check(probe_records.is_empty(), "值不变不重复触发")

	# 4) 重置场景：life → 3 再触发一次
	probe_records.clear()
	container.set_variable("life", 3)
	waited = 0.0
	while probe_records.is_empty() and waited < 1.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
	_check(probe_records.size() == 2 and probe_records[0] == 3 and probe_records[1] == 2,
		"重置 life=3 再触发（new=3 old=2）")

	multi.queue_free()
	holder.queue_free()
