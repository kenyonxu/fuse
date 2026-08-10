# addons/fuse/editor/serialization/fuse_preset_serializer.gd
@tool
class_name FusePresetSerializer
extends RefCounted

## 序列化管道 — 将 Godot 节点/资源序列化为预设 JSON 结构

const _BASE_PROPERTIES := ["log_level", "completion_timing", "execution_mode",
	"script", "resource_local_to_scene", "resource_name", "metadata"]


# ---- 层级检测 ----

static func detect_level(node: Object) -> String:
	if node is MultiEventTrigger:  return "L4"
	if node is Trigger:            return "L2"
	if node is Runner:             return "L3"
	if node is ActionRunner:       return "L1"
	return ""


# ---- 顶层入口 ----

static func serialize(node: Object) -> Dictionary:
	var level_str := detect_level(node)
	match level_str:
		"L1": return serialize_l1(node as ActionRunner)
		"L2": return serialize_l2(node as Trigger)
		"L3": return serialize_l3(node as Runner)
		"L4": return serialize_l4(node as MultiEventTrigger)
	return {}


static func serialize_l1(runner: ActionRunner) -> Dictionary:
	var variables := _collect_all_variables(runner.instructions)
	return {
		"level": "L1",
		"action_runner": {
			"execution_mode": runner.execution_mode,
			"instructions": _serialize_instructions(runner.instructions)
		},
		"variables": variables
	}


static func serialize_l2(trigger: Trigger) -> Dictionary:
	var variables: Dictionary = {}
	if trigger.action_runner:
		variables = _collect_all_variables(trigger.action_runner.instructions)
	var event_data: Dictionary = {}
	if trigger.event_definition:
		event_data = serialize_event(trigger.event_definition)
	return {
		"level": "L2",
		"action_runner": {
			"execution_mode": trigger.action_runner.execution_mode if trigger.action_runner else 0,
			"instructions": _serialize_instructions(
				trigger.action_runner.instructions if trigger.action_runner else []
			)
		},
		"event": event_data,
		"trigger_config": serialize_trigger_config(trigger),
		"variables": variables
	}


static func serialize_l3(runner: Runner) -> Dictionary:
	var instructions: Array[BaseInstruction] = []
	if runner.action_runner:
		instructions = runner.action_runner.instructions
	var variables := _collect_all_variables(instructions)
	return {
		"level": "L3",
		"action_runner": {
			"instructions": _serialize_instructions(instructions)
		},
		"signal_binding": serialize_signal_binding(runner),
		"variables": variables
	}


static func serialize_l4(multi: MultiEventTrigger) -> Dictionary:
	var bindings_json: Array = []
	for i in range(multi.event_bindings.size()):
		var binding: EventBinding = multi.event_bindings[i]
		bindings_json.append(serialize_binding(binding))
	return {
		"level": "L4",
		"trigger_config": {
			"use_parallel_condition_evaluation": multi.use_parallel_condition_evaluation
		},
		"event_bindings": bindings_json,
		"variables": {}  # L4 每个 binding 各自有指令，变量在 binding 级别不单独序列化
	}


# ---- 子序列化器 ----

static func serialize_action_runner(runner: ActionRunner) -> Dictionary:
	return {
		"execution_mode": runner.execution_mode,
		"instructions": _serialize_instructions(runner.instructions)
	}


static func serialize_event(event: BaseEvent) -> Dictionary:
	return _serialize_resource_properties(event)


static func serialize_condition(cond: BaseCondition) -> Dictionary:
	return _serialize_resource_properties(cond)


static func serialize_trigger_config(node: Node) -> Dictionary:
	var config: Dictionary = {}
	if node is Trigger:
		config["trigger_once"] = node.trigger_once
		config["cooldown_mode"] = node.cooldown_mode
		config["cooldown_time"] = node.cooldown_time
	elif node is MultiEventTrigger:
		config["use_parallel_condition_evaluation"] = node.use_parallel_condition_evaluation
	return config


static func serialize_signal_binding(node: Runner) -> Dictionary:
	return {
		"signal_name": node.signal_name
	}


static func serialize_binding_config(binding: EventBinding) -> Dictionary:
	return {
		"enabled": binding.enabled,
		"trigger_once": binding.trigger_once,
		"cooldown_mode": binding.cooldown_mode,
		"cooldown_time": binding.cooldown_time
	}


static func serialize_binding(binding: EventBinding) -> Dictionary:
	var data: Dictionary = {
		"binding_config": serialize_binding_config(binding)
	}

	if binding.event:
		data["event"] = serialize_event(binding.event)

	if binding.action_runner:
		data["action_runner"] = {
			"execution_mode": binding.action_runner.execution_mode,
			"instructions": _serialize_instructions(binding.action_runner.instructions)
		}

	if not binding.conditions.is_empty():
		var conds: Array = []
		for cond in binding.conditions:
			if cond != null:
				conds.append(serialize_condition(cond))
		data["conditions"] = conds

	return data


# ---- 底层序列化 ----

static func _serialize_instructions(instructions: Array[BaseInstruction]) -> Array:
	return PresetValueCodec.serialize_instructions(instructions)


static func _serialize_resource_properties(res: Resource) -> Dictionary:
	return PresetValueCodec._serialize_resource(res)


# ---- 变量收集 ----

static func _collect_all_variables(instructions: Array[BaseInstruction]) -> Dictionary:
	var result := {"local": [], "scope": [], "global": []}
	for inst in instructions:
		if "variable_name" in inst and "variable_scope" in inst:
			var name: String = inst.variable_name
			var scope: int = inst.variable_scope
			match scope:
				0:
					if name not in result["local"]:
						result["local"].append(name)
				1:
					var entry := {"name": name, "container": ""}
					if "target_node" in inst:
						entry["container"] = str(inst.target_node)
					result["scope"].append(entry)
				2:
					if name not in result["global"]:
						result["global"].append(name)
	return result
