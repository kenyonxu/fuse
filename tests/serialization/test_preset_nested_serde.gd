# tests/serialization/test_preset_nested_serde.gd
extends Node

const PresetValueCodec := preload("res://addons/fuse/core/serialization/preset_value_codec.gd")
const FusePreset := preload("res://addons/fuse/core/resources/fuse_preset.gd")

const IfElse := preload("res://addons/fuse/instructions/flow_control/if_else.gd")
const Print := preload("res://addons/fuse/instructions/debug/print.gd")
const CheckAll := preload("res://addons/fuse/conditions/composite/check_all.gd")
const CheckScopeVariable := preload("res://addons/fuse/conditions/scope/check_scope_variable.gd")
const OnInterval := preload("res://addons/fuse/events/lifecycle/on_interval.gd")

func _ready():
	print("=== Preset nested resource serde test ===")
	test_codec_instruction_round_trip()
	test_codec_condition_array_round_trip()
	test_codec_event_with_condition_round_trip()
	test_fuse_preset_from_json_with_ifelse()
	test_fuse_preset_round_trip()
	print("=== All nested serde tests passed ===")

func test_codec_instruction_round_trip():
	var original := _make_if_else()
	var data := PresetValueCodec.serialize_instruction(original)
	assert(data is Dictionary, "serialized instruction must be dict")
	assert(data["type"] == "IfElse", "type preserved")
	assert(data["condition"] is Dictionary, "condition serialized as dict")
	assert(data["true_instructions"] is Array and data["true_instructions"].size() == 1, "true instructions serialized")
	assert(data["true_instructions"][0] is Dictionary and data["true_instructions"][0]["type"] == "Print", "nested instruction type preserved")

	var restored := PresetValueCodec.deserialize_instruction(data)
	assert(restored is IfElse, "restored is IfElse")
	assert(restored.condition is CheckScopeVariable, "condition restored")
	assert(restored.true_instructions.size() == 1 and restored.true_instructions[0] is Print, "true branch restored")
	assert(restored.false_instructions.size() == 1 and restored.false_instructions[0] is Print, "false branch restored")

	var context := ExecutionContext.new()
	context.set_variable("current_level", 1)
	restored.execute(context)
	await get_tree().process_frame
	assert(restored.is_completed(), "IfElse executed")
	print("✓ codec instruction round-trip")

func test_codec_condition_array_round_trip():
	var original := CheckAll.new()
	var cond1 := CheckScopeVariable.new()
	cond1.variable_name = "has_key"
	cond1.scope_source = CheckScopeVariable.ScopeSource.TRIGGER_SCOPE
	cond1.comparison_operator = CheckScopeVariable.ComparisonOperator.IS_TRUE
	cond1.expected_value = true
	original.conditions.append(cond1)

	var data := PresetValueCodec.serialize_condition(original)
	assert(data["conditions"] is Array and data["conditions"].size() == 1, "conditions serialized as array")
	assert(data["conditions"][0] is Dictionary and data["conditions"][0]["type"] == "CheckScopeVariable", "condition dict preserved")

	var restored := PresetValueCodec.deserialize_condition(data)
	assert(restored is CheckAll, "restored is CheckAll")
	assert(restored.conditions.size() == 1 and restored.conditions[0] is CheckScopeVariable, "nested condition restored")
	print("✓ codec condition array round-trip")

func test_codec_event_with_condition_round_trip():
	var original := OnInterval.new()
	original.interval_seconds = 1.0
	var cond := CheckScopeVariable.new()
	cond.variable_name = "stopped"
	cond.comparison_operator = CheckScopeVariable.ComparisonOperator.IS_TRUE
	cond.expected_value = true
	original.stop_condition = cond

	var data := PresetValueCodec.serialize_event(original)
	assert(data["stop_condition"] is Dictionary and data["stop_condition"]["type"] == "CheckScopeVariable", "stop condition serialized")

	var restored := PresetValueCodec.deserialize_event(data) as OnInterval
	assert(restored != null and restored.stop_condition is CheckScopeVariable, "stop condition restored")
	print("✓ codec event with condition round-trip")

func test_fuse_preset_from_json_with_ifelse():
	var json := {
		"format_version": "2.0",
		"level": "L2",
		"display_name": "test_ifelse_inline",
		"action_runner": {
			"execution_mode": 0,
			"instructions": [_make_if_else_dict()]
		},
		"variables": {"global": [], "local": [], "scope": []},
		"trigger_config": {"trigger_once": true, "cooldown_mode": 0, "cooldown_time": 1.0}
	}
	var preset := FusePreset.from_json(json)
	assert(preset.instructions.size() == 1 and preset.instructions[0] is IfElse, "preset deserializes IfElse")
	var ifelse := preset.instructions[0] as IfElse
	assert(ifelse.condition is CheckScopeVariable, "preset IfElse condition restored")
	assert(ifelse.true_instructions[0] is Print, "preset true branch restored")
	print("✓ FusePreset.from_json with inline IfElse")

func test_fuse_preset_round_trip():
	var json := {
		"format_version": "2.0",
		"level": "L2",
		"display_name": "test_ifelse_inline",
		"action_runner": {
			"execution_mode": 0,
			"instructions": [_make_if_else_dict()]
		},
		"variables": {"global": [], "local": [], "scope": []},
		"trigger_config": {"trigger_once": true, "cooldown_mode": 0, "cooldown_time": 1.0}
	}
	var preset := FusePreset.from_json(json)
	var serialized := preset.to_json()
	var preset2 := FusePreset.from_json(serialized)
	assert(preset2.instructions.size() == 1 and preset2.instructions[0] is IfElse, "round-trip IfElse")
	var ifelse2 := preset2.instructions[0] as IfElse
	assert(ifelse2.condition is CheckScopeVariable and ifelse2.condition.variable_name == "current_level", "round-trip condition data")
	assert(ifelse2.true_instructions.size() == 1, "round-trip true branch")
	print("✓ FusePreset round-trip")

func _make_if_else() -> IfElse:
	var ifelse := IfElse.new()
	var cond := CheckScopeVariable.new()
	cond.variable_name = "current_level"
	cond.scope_source = CheckScopeVariable.ScopeSource.CUSTOM_ID
	cond.custom_scope_id = "level_scope"
	cond.comparison_operator = CheckScopeVariable.ComparisonOperator.EQUALS
	cond.expected_value = 1
	ifelse.condition = cond

	var true_print := Print.new()
	true_print.message = "branch-true"
	ifelse.true_instructions.append(true_print)

	var false_print := Print.new()
	false_print.message = "branch-false"
	ifelse.false_instructions.append(false_print)
	return ifelse

func _make_if_else_dict() -> Dictionary:
	return PresetValueCodec.serialize_instruction(_make_if_else())
