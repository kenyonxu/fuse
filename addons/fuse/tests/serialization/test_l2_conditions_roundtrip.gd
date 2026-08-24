# 测试：L2 preset 的 Trigger conditions 序列化/反序列化 round-trip
extends Node

var _fail: int = 0

func _ready() -> void:
	print("=== L2 conditions round-trip 测试开始 ===")
	_test_roundtrip()
	_test_validator()
	print("=== L2 conditions round-trip 测试完成（失败 %d 项）===" % _fail)
	get_tree().quit(1 if _fail > 0 else 0)

func _check(condition: bool, message: String) -> void:
	if condition:
		print("✓ " + message)
	else:
		_fail += 1
		push_error("✗ " + message)

func _build_trigger() -> Trigger:
	var trigger := Trigger.new()

	var cond := CompareVariable.new()
	cond.variable_name = "event_value"
	cond.comparison_operator = CompareVariable.ComparisonOperator.GREATER_THAN
	cond.compare_value = 10
	trigger.conditions = [cond]

	# 最小占位（serialize_l2 对空 action_runner/event 有保护）
	var event := OnTargetSignalEmit.new()
	event.target_node = NodePath("Emitter")
	event.target_signal = "custom_signal"
	trigger.event_definition = event
	return trigger

func _test_roundtrip() -> void:
	var trigger := _build_trigger()

	var data := FusePresetSerializer.serialize(trigger)
	_check(data.get("level") == "L2", "Trigger 序列化为 L2")
	_check(data.has("conditions") and data["conditions"].size() == 1,
		"序列化应包含 conditions 数组")
	if data.has("conditions") and not data["conditions"].is_empty():
		_check(data["conditions"][0].get("type") == "CompareVariable",
			"conditions[0].type 应为 CompareVariable")

	# JSON 往返（模拟落盘/读盘）
	var json_text := JSON.stringify(data)
	var parsed = JSON.parse_string(json_text)

	var preset := FusePreset.from_json(parsed)
	var restored_obj := FusePresetDeserializer.deserialize(preset, {})
	var restored := restored_obj as Trigger
	_check(restored != null, "反序列化应还原 Trigger 节点")
	if restored:
		_check(restored.conditions.size() == 1, "conditions 应还原 1 条")
		if restored.conditions.size() == 1:
			var cond := restored.conditions[0] as CompareVariable
			_check(cond != null, "还原项应为 CompareVariable")
			if cond:
				_check(cond.variable_name == "event_value"
					and cond.comparison_operator == CompareVariable.ComparisonOperator.GREATER_THAN
					and cond.compare_value == 10,
					"条件参数应完整还原")

func _test_validator() -> void:
	var data := FusePresetSerializer.serialize(_build_trigger())
	var findings: Array = []
	PresetValidator._validate_schema(data, findings)
	var has_error := false
	for f in findings:
		if str(f.get("severity", "")) == "error":
			has_error = true
	_check(not has_error, "合法 L2 conditions JSON 不应产生 error finding")
