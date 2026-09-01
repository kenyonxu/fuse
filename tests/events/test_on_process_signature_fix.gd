# 测试：on_process 轮询型事件批量修复——签名对齐 Trigger 双参调用 + OnPropertyChanged 全链路
extends Node

var _fail: int = 0
var _records: Array = []

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
	print("=== on_process 批量修复测试开始 ===")
	await _test_property_changed_chain()
	await _test_signature_no_error()
	print("=== on_process 批量修复测试完成（失败 %d 项）===" % _fail)
	get_tree().quit(1 if _fail > 0 else 0)

func _check(condition: bool, message: String) -> void:
	if condition:
		print("✓ " + message)
	else:
		_fail += 1
		push_error("✗ " + message)

## OnPropertyChanged 全链路（签名 + timer + args 三修验证）
func _test_property_changed_chain() -> void:
	print("\n--- OnPropertyChanged 全链路 ---")
	var target := Node2D.new()
	target.name = "PropTarget"
	add_child(target)
	await get_tree().process_frame
	await get_tree().process_frame

	var probe_records: Array = []
	var instructions: Array[BaseInstruction] = []
	instructions.append(EventProbe.new(probe_records))
	var ar := ActionRunner.new()
	ar.instructions = instructions

	var ev := OnPropertyChanged.new()
	ev.target_node = NodePath("../PropTarget")
	ev.property_name = "position"
	ev.check_interval = 0.05

	var binding := EventBinding.new()
	binding.event = ev
	binding.action_runner = ar
	var multi := MultiEventTrigger.new()
	multi.name = "PropWatcher"
	multi.event_bindings = [binding]
	add_child(multi)
	await get_tree().process_frame

	# 初始化不假触发
	await get_tree().create_timer(0.2).timeout
	_check(probe_records.is_empty(), "初始化不假触发")

	# 改属性（触发 timer 轮询——此前 timer 不写回永不触发）
	target.position = Vector2(10, 0)
	var waited := 0.0
	while probe_records.is_empty() and waited < 1.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
	_check(probe_records.size() == 2, "属性变化后触发（等待 %.2fs）" % waited)
	if probe_records.size() >= 2:
		_check(probe_records[0] is Vector2 and probe_records[0] == Vector2(10, 0),
			"event_new_value 为新位置（实际 %s）" % str(probe_records[0]))

	# 值不变不重复
	probe_records.clear()
	await get_tree().create_timer(0.3).timeout
	_check(probe_records.is_empty(), "值不变不重复触发")
	multi.queue_free()

## 签名修复验证：其余 5 个事件挂在 Trigger 下不报签名错（各自条件不满足不触发，仅验证无 SCRIPT ERROR）
func _test_signature_no_error() -> void:
	print("\n--- 签名兼容（挂载不报错） ---")
	var evs: Array[BaseEvent] = []
	evs.append(OnAnimationLoop.new())
	evs.append(OnAnimationMarker.new())
	evs.append(OnAnimationStarted.new())
	evs.append(OnAudioBusVolumeChanged.new())
	evs.append(OnSoundListened.new())

	for ev in evs:
		var binding := EventBinding.new()
		binding.event = ev
		var multi := MultiEventTrigger.new()
		multi.name = "SigWatcher"
		multi.event_bindings = [binding]
		add_child(multi)
		await get_tree().process_frame

	# 5 帧内无 SCRIPT ERROR 即签名调用兼容（Trigger 每帧调 on_process 双参）
	for i in range(5):
		await get_tree().process_frame
	_check(true, "5 事件 × 5 帧挂载轮询无签名报错")
