# addons/fuse/editor/serialization/fuse_preset_deserializer.gd
@tool
class_name FusePresetDeserializer
extends RefCounted

## 反序列化管道 — 从预设 JSON 创建 Godot 节点/资源


# ---- 顶层入口 ----

static func deserialize(preset: FusePreset, mapping: Dictionary) -> Object:
	match preset.level:
		"L1":
			return _import_l1(preset, mapping)
		"L2":
			return _import_l2(preset, mapping)
		"L3":
			return _import_l3(preset, mapping)
		"L4":
			return _import_l4(preset, mapping)
	push_warning("FusePresetDeserializer: 未知 preset level '%s'" % preset.level)
	return null


# ---- L1: 创建 ActionRunner Resource ----

static func _import_l1(preset: FusePreset, _mapping: Dictionary) -> ActionRunner:
	var runner := ActionRunner.new()
	runner.instructions = preset.instructions  # 已是 Array[BaseInstruction]，由 from_json() 或 .tres 加载填充
	runner.resource_name = preset.display_name
	return runner


# ---- L2: 创建 Trigger 节点 ----

static func _import_l2(preset: FusePreset, mapping: Dictionary) -> Trigger:
	var trigger := Trigger.new()
	trigger.name = preset.display_name

	# Step 1: trigger_config（无依赖）
	if not preset.trigger_config.is_empty():
		trigger.trigger_once = preset.trigger_config.get("trigger_once", false)
		trigger.cooldown_mode = preset.trigger_config.get("cooldown_mode", 0)
		trigger.cooldown_time = preset.trigger_config.get("cooldown_time", 0.0)

	# Step 2: event_definition
	if not preset.event_json.is_empty():
		trigger.event_definition = _deserialize_event(preset.event_json)

	# Step 3: action_runner（instructions 已由 from_json() 或 .tres 加载为 Array[BaseInstruction]）
	var ar := ActionRunner.new()
	ar.instructions = preset.instructions
	trigger.action_runner = ar

	# Step 4: apply NodePath mapping
	_apply_nodepath_mapping_node(trigger, mapping)

	return trigger


# ---- L3: 创建 Runner 节点 ----

static func _import_l3(preset: FusePreset, mapping: Dictionary) -> Runner:
	var runner := Runner.new()
	runner.name = preset.display_name

	# Step 1: action_runner（instructions 已由 from_json() 或 .tres 加载）
	var ar := ActionRunner.new()
	ar.instructions = preset.instructions
	runner.action_runner = ar

	# Step 2: target_node from mapping
	if mapping.has("__target_node__"):
		runner.target_node = mapping["__target_node__"]

	# Step 3: signal_name（必须在 target_node 之后）
	if not preset.signal_binding.is_empty():
		runner.signal_name = preset.signal_binding.get("signal_name", "")

	# Step 4: 刷新属性列表（在 runner 实例上调用 call_deferred）
	runner.call_deferred("notify_property_list_changed")

	# Step 5: apply remaining NodePath mapping
	_apply_nodepath_mapping_node(runner, mapping)

	return runner



# ---- L4: 创建 MultiEventTrigger 节点 ----

static func _import_l4(preset: FusePreset, mapping: Dictionary) -> MultiEventTrigger:
	var multi := MultiEventTrigger.new()
	multi.name = preset.display_name

	# Step 1: trigger_config
	if not preset.trigger_config.is_empty():
		multi.use_parallel_condition_evaluation = preset.trigger_config.get(
			"use_parallel_condition_evaluation", true
		)

	# Step 2: 逐个构建完整 EventBinding，再一次赋值
	var bindings: Array[EventBinding] = []
	for bdata in preset.event_bindings_json:
		var binding := _deserialize_binding(bdata)
		if binding:
			bindings.append(binding)

	# Step 3: 一次性赋值（触发 setter 里的 notify_property_list_changed）
	multi.event_bindings = bindings

	# Step 4: apply NodePath mapping
	_apply_nodepath_mapping_node(multi, mapping)

	return multi


# ---- 子反序列化器 ----

static func _deserialize_event(data: Dictionary) -> BaseEvent:
	return PresetValueCodec.deserialize_event(data)


static func _deserialize_binding(data: Dictionary) -> EventBinding:
	var binding := EventBinding.new()

	if data.has("event"):
		binding.event = PresetValueCodec.deserialize_event(data["event"])

	if data.has("action_runner"):
		var ar_data: Dictionary = data["action_runner"]
		var ar := ActionRunner.new()
		if ar_data.has("execution_mode"):
			ar.execution_mode = ar_data["execution_mode"]
		ar.instructions = PresetValueCodec.deserialize_instructions(ar_data.get("instructions", []))
		binding.action_runner = ar

	if data.has("conditions"):
		var conds: Array[BaseCondition] = []
		for cdata in data["conditions"]:
			var cond := PresetValueCodec.deserialize_condition(cdata)
			if cond:
				conds.append(cond)
		binding.conditions = conds

	if data.has("binding_config"):
		var bc: Dictionary = data["binding_config"]
		binding.enabled = bc.get("enabled", true)
		binding.trigger_once = bc.get("trigger_once", false)
		binding.cooldown_mode = bc.get("cooldown_mode", 0)
		binding.cooldown_time = bc.get("cooldown_time", 0.0)

	return binding


# ---- NodePath 映射 ----

static func _apply_nodepath_mapping_node(node: Node, mapping: Dictionary) -> void:
	# 递归扫描节点下所有 Resource 属性中的 NodePath，应用映射
	_apply_mapping_recursive(node, mapping)


static func _apply_mapping_recursive(obj: Object, mapping: Dictionary) -> void:
	for prop in obj.get_property_list():
		var pname: String = prop.name
		if pname.begins_with("_"):
			continue
		if prop.type == TYPE_NODE_PATH:
			var np: NodePath = obj.get(pname)
			var np_str := str(np)
			if mapping.has(np_str):
				obj.set(pname, mapping[np_str])
		elif prop.type == TYPE_OBJECT:
			var child = obj.get(pname)
			if child is Resource:
				_apply_mapping_recursive(child, mapping)
			elif child is Array:
				for item in child:
					if item is Resource:
						_apply_mapping_recursive(item, mapping)


# ---- 导入后校验（§9.1） ----

static func validate_imported_node(node: Node, level: String) -> Array[String]:
	var warnings: Array[String] = []
	match level:
		"L2":
			var trigger := node as Trigger
			if trigger:
				if not trigger.event_definition:
					warnings.append("事件定义未能还原，请手动配置 event_definition")
				if not trigger.action_runner or trigger.action_runner.instructions.is_empty():
					warnings.append("指令列表为空，请手动添加指令")
		"L3":
			var runner := node as Runner
			if runner:
				if not runner.action_runner or runner.action_runner.instructions.is_empty():
					warnings.append("指令列表为空，请手动添加指令")
				if runner.signal_name.is_empty():
					warnings.append("信号名称为空，请手动选择信号")
		"L4":
			var multi := node as MultiEventTrigger
			if multi:
				if multi.event_bindings.is_empty():
					warnings.append("事件绑定列表为空，请手动配置 EventBinding")
	return warnings
