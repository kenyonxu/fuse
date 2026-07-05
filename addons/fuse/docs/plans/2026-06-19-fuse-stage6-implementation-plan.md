# Fuse Stage 6: 多层级 Preset (L1-L4) 实现计划

**状态:** ✅ 已完成（2026-06-19）

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将预设系统从 ActionRunner (L1) 扩展到 Trigger (L2)、Runner (L3)、MultiEventTrigger (L4) 四个层级，支持导出任意 Fuse 节点为预设模板，导入时自动创建对应节点结构。

**Architecture:** 语义嵌套 JSON 格式直接映射 Godot 对象图。新增 FusePresetSerializer（导出管道）和 FusePresetDeserializer（导入管道）两个静态类，所有层级共用底层序列化函数（serialize_action_runner、serialize_event、serialize_condition）。指令始终在 action_runner.instructions 内，NodePath 不序列化，导入时由用户映射。

**Tech Stack:** Godot 4.7, GDScript 2.0, @tool scripts

**设计文档:** [2026-06-19-fuse-stage6-design.md](../specs/2026-06-19-fuse-stage6-design.md)

---

## 文件结构

```
新增文件:
├── addons/fuse/editor/serialization/
│   ├── fuse_preset_serializer.gd      # 序列化管道（export 方向，静态类）
│   └── fuse_preset_deserializer.gd    # 反序列化管道（import 方向，静态类）

修改文件:
├── addons/fuse/core/resources/fuse_preset.gd    # +level, +event_json 等字段；to_json/from_json 按 level 分派
├── addons/fuse/editor/preset_export_dialog.gd    # 构造函数改为接受 Variant；UI 展示 level 标签
├── addons/fuse/editor/preset_import_dialog.gd    # 按 level 创建节点；NodePath 扫描扩展
├── addons/fuse/editor/fuse_inspector_plugin.gd   # +导出按钮（L2/L3/L4 入口），_parse_end 检测节点类型
└── addons/fuse/editor/preset_panel.gd            # 每条显示 level 标签
```

---

### Task 1: 数据模型扩展（FusePreset）

**Files:**
- Modify: `addons/fuse/core/resources/fuse_preset.gd`

- [ ] **Step 1: 添加 level 和新字段**

在 `variables` 字段之后、`instructions` 字段之前，插入新字段：

```gdscript
## 预设层级: "L1"|"L2"|"L3"|"L4"
@export var level: String = "L1"

## L2/L4: BaseEvent 的序列化数据
@export var event_json: Dictionary = {}

## L2/L4: trigger_once, cooldown_mode, cooldown_time
@export var trigger_config: Dictionary = {}

## L3: signal_name
@export var signal_binding: Dictionary = {}

## L4: EventBinding 数组的序列化数据
@export var event_bindings_json: Array = []
```

注意：保持现有字段顺序不变 — `display_name`, `category`, `description`, `icon_name`, `version`, `variables`, [新字段], `instructions`。

- [ ] **Step 2: 扩展 to_json()**

将现有 `to_json()` 替换为按 level 分派的版本：

```gdscript
func to_json() -> Dictionary:
	var data: Dictionary = {
		"format_version": version,
		"level": level,
		"display_name": display_name,
		"category": category,
		"description": description,
		"icon_name": icon_name,
		"variables": variables,
	}

	match level:
		"L1":
			data["action_runner"] = {
				"instructions": _serialize_instructions()
			}
		"L2":
			data["action_runner"] = {
				"instructions": _serialize_instructions()
			}
			data["event"] = event_json
			data["trigger_config"] = trigger_config
		"L3":
			data["action_runner"] = {
				"instructions": _serialize_instructions()
			}
			data["signal_binding"] = signal_binding
		"L4":
			data["trigger_config"] = trigger_config
			data["event_bindings"] = event_bindings_json
		_:
			push_warning("FusePreset.to_json: 未知 level '%s'" % level)

	return data
```

- [ ] **Step 3: 扩展 from_json()**

```gdscript
static func from_json(data: Dictionary) -> FusePreset:
	var preset := FusePreset.new()
	preset.version = data.get("format_version", "1.0")
	preset.level = data.get("level", "L1")
	preset.display_name = data.get("display_name", "")
	preset.category = data.get("category", "")
	preset.description = data.get("description", "")
	preset.icon_name = data.get("icon_name", "")
	preset.variables = data.get("variables", {})

	# 按 level 解析
	var ar_data: Dictionary = data.get("action_runner", {})
	match preset.level:
		"L1", "L2", "L3":
			preset.instructions = _deserialize_instructions(ar_data.get("instructions", []))
		"L4":
			# L4 不存顶层 instructions，event_bindings 内各自包含
			pass

	if preset.level == "L2":
		preset.event_json = data.get("event", {})
		preset.trigger_config = data.get("trigger_config", {})
	elif preset.level == "L3":
		preset.signal_binding = data.get("signal_binding", {})
	elif preset.level == "L4":
		preset.trigger_config = data.get("trigger_config", {})
		preset.event_bindings_json = data.get("event_bindings", [])

	return preset
```

- [ ] **Step 4: 验证**

在 Godot 编辑器中重载插件（禁用→启用 Fuse），检查 Output 面板无报错。打开已有的 .tres 预设文件，确认 level 默认值为 "L1"，其他新字段为空字典/数组。

- [ ] **Step 5: 提交**

```bash
git add addons/fuse/core/resources/fuse_preset.gd
git commit -m "feat(fuse): FusePreset 扩展 level/L2-L4 字段，to_json/from_json 按层级分派"
```

---

### Task 2: 序列化管道（FusePresetSerializer）

**Files:**
- Create: `addons/fuse/editor/serialization/fuse_preset_serializer.gd`

- [ ] **Step 1: 创建序列化器文件**

```gdscript
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
	var result: Array = []
	for inst in instructions:
		var script = inst.get_script()
		var entry := {"type": script.get_global_name() if script else inst.get_class()}
		for prop in inst.get_property_list():
			var pname: String = prop.name
			if pname.begins_with("_") or (prop.usage & PROPERTY_USAGE_STORAGE) == 0:
				continue
			if pname in _BASE_PROPERTIES:
				continue
			var val = inst.get(pname)
			if val is NodePath:
				entry[pname] = str(val)
			elif val is Resource and val.resource_path != "":
				entry[pname] = val.resource_path
			elif not (val is Resource):
				entry[pname] = val
		result.append(entry)
	return result


static func _serialize_resource_properties(res: Resource) -> Dictionary:
	var script = res.get_script()
	var entry := {"type": script.get_global_name() if script else res.get_class()}
	for prop in res.get_property_list():
		var pname: String = prop.name
		if pname.begins_with("_") or (prop.usage & PROPERTY_USAGE_STORAGE) == 0:
			continue
		if pname in _BASE_PROPERTIES:
			continue
		var val = res.get(pname)
		if val is NodePath:
			entry[pname] = str(val)
		elif val is Resource and val.resource_path != "":
			entry[pname] = val.resource_path
		elif not (val is Resource):
			entry[pname] = val
	return entry


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
```

- [ ] **Step 2: 验证序列化器**

在 Godot 编辑器中打开一个包含 Trigger 节点的场景。在 Output 面板中手动运行以下脚本（通过 EditorScript 或临时测试节点）验证 detect_level 不报错且 serializers 返回非空 Dictionary。

- [ ] **Step 3: 提交**

```bash
git add addons/fuse/editor/serialization/fuse_preset_serializer.gd
git commit -m "feat(fuse): FusePresetSerializer — 多层级序列化管道"
```

---

### Task 3: 反序列化管道（FusePresetDeserializer）

**Files:**
- Create: `addons/fuse/editor/serialization/fuse_preset_deserializer.gd`

- [ ] **Step 1: 创建反序列化器文件**

```gdscript
# addons/fuse/editor/serialization/fuse_preset_deserializer.gd
@tool
class_name FusePresetDeserializer
extends RefCounted

## 反序列化管道 — 从预设 JSON 创建 Godot 节点/资源


# ---- 类型脚本缓存 ----

static var _instruction_cache: Dictionary = {}
static var _event_cache: Dictionary = {}
static var _condition_cache: Dictionary = {}


# ---- 顶层入口 ----

static func deserialize(preset: FusePreset, mapping: Dictionary) -> Node:
	match preset.level:
		"L1":
			return _import_l1(preset, mapping)
		"L2":
			return _import_l2(preset, mapping)
		"L3":
			return _import_l3(preset, mapping)
		"L4":
			return _import_l4(preset, mapping)
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

	# Step 4: 刷新属性列表
	call_deferred("_deferred_notify", runner)

	# Step 5: apply remaining NodePath mapping
	_apply_nodepath_mapping_node(runner, mapping)

	return runner


static func _deferred_notify(node: Node) -> void:
	if node is Runner:
		node.notify_property_list_changed()


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
	var type_name: String = data.get("type", "")
	var script := _cache_event_script(type_name)
	if script == null:
		push_warning("FusePresetDeserializer: 无法找到事件类型 '%s'" % type_name)
		return null
	var inst: BaseEvent = script.new()
	for key in data:
		if key == "type":
			continue
		_set_property_value(inst, key, data[key])
	return inst


static func _deserialize_condition(data: Dictionary) -> BaseCondition:
	var type_name: String = data.get("type", "")
	var script := _cache_condition_script(type_name)
	if script == null:
		push_warning("FusePresetDeserializer: 无法找到条件类型 '%s'" % type_name)
		return null
	var inst: BaseCondition = script.new()
	for key in data:
		if key == "type":
			continue
		_set_property_value(inst, key, data[key])
	return inst


static func _deserialize_binding(data: Dictionary) -> EventBinding:
	var binding := EventBinding.new()

	if data.has("event"):
		binding.event = _deserialize_event(data["event"])

	if data.has("action_runner"):
		var ar_data: Dictionary = data["action_runner"]
		var ar := ActionRunner.new()
		if ar_data.has("execution_mode"):
			ar.execution_mode = ar_data["execution_mode"]
		ar.instructions = _deserialize_instructions(ar_data.get("instructions", []))
		binding.action_runner = ar

	if data.has("conditions"):
		var conds: Array[BaseCondition] = []
		for cdata in data["conditions"]:
			var cond := _deserialize_condition(cdata)
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


# ---- 指令反序列化（复用 FusePreset 现有逻辑） ----

static func _deserialize_instructions(raw: Array) -> Array[BaseInstruction]:
	var result: Array[BaseInstruction] = []
	for entry in raw:
		var type_name: String = entry.get("type", "")
		var script: GDScript = _cache_instruction_script(type_name)
		if script == null:
			push_warning("FusePresetDeserializer: 无法找到指令类型 '%s'" % type_name)
			continue
		var inst: BaseInstruction = script.new()
		for key in entry:
			if key == "type":
				continue
			_set_property_value(inst, key, entry[key])
		result.append(inst)
	return result


# ---- 脚本缓存 ----

static func _cache_instruction_script(type_name: String) -> GDScript:
	if _instruction_cache.has(type_name):
		return _instruction_cache[type_name]
	var instructions = InstructionRegistry.get_all_instructions()
	for info in instructions:
		var cls: GDScript = info.get("class")
		if cls and cls.get_global_name() == type_name:
			_instruction_cache[type_name] = cls
			return cls
	return null


static func _cache_event_script(type_name: String) -> GDScript:
	if _event_cache.has(type_name):
		return _event_cache[type_name]
	var events = EventRegistry.get_all_events()
	for info in events:
		var cls: GDScript = info.get("class")
		if cls and cls.get_global_name() == type_name:
			_event_cache[type_name] = cls
			return cls
	return null


static func _cache_condition_script(type_name: String) -> GDScript:
	if _condition_cache.has(type_name):
		return _condition_cache[type_name]
	var conditions = ConditionRegistry.get_all_conditions()
	for info in conditions:
		var cls: GDScript = info.get("class")
		if cls and cls.get_global_name() == type_name:
			_condition_cache[type_name] = cls
			return cls
	return null


# ---- 属性设置辅助 ----

static func _set_property_value(obj: Object, key: String, val) -> void:
	if val is String and (val.begins_with("uid://") or val.begins_with("res://")):
		var res = load(val)
		if res != null:
			obj.set(key, res)
			return
	obj.set(key, val)


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
```

- [ ] **Step 2: 验证反序列化器**

在 Output 面板确认脚本无编译错误。后续 Task 5（导入）将端到端验证。

- [ ] **Step 3: 提交**

```bash
git add addons/fuse/editor/serialization/fuse_preset_deserializer.gd
git commit -m "feat(fuse): FusePresetDeserializer — 多层级反序列化管道"
```

---

### Task 4: 导出对话框改造（PresetExportDialog）

**Files:**
- Modify: `addons/fuse/editor/preset_export_dialog.gd`

- [ ] **Step 1: 构造函数改为接受 Variant**

将现有构造函数 `_init(instructions: Array[BaseInstruction])` 替换为 Variant 参数：

```gdscript
# addons/fuse/editor/preset_export_dialog.gd
@tool
class_name PresetExportDialog
extends AcceptDialog

## 导出预设对话框 — 支持 L1（传指令数组）和 L2-L4（传节点）

var _display_name_input: LineEdit
var _category_input: LineEdit
var _description_input: TextEdit
var _icon_input: LineEdit
var _info_label: Label
var _level_label: Label
var _instructions: Array[BaseInstruction] = []
var _serialized_data: Dictionary = {}
var _level: String = "L1"
var _source_node: Node = null


func _init(source: Variant) -> void:
	title = "导出为预设"
	ok_button_text = "导出"

	if source is Node:
		_source_node = source
		_level = FusePresetSerializer.detect_level(source)
		_serialized_data = FusePresetSerializer.serialize(source)
		if _level == "L1":
			var ar := source as ActionRunner
			_instructions = ar.instructions if ar else []
		else:
			# L2/L3/L4: 提取指令用于统计
			_instructions = _extract_instructions_from_data()
	elif source is Array:
		_level = "L1"
		_instructions = source
		var dummy := ActionRunner.new()
		dummy.instructions = _instructions
		_serialized_data = FusePresetSerializer.serialize_l1(dummy)

	_build_ui()
	_update_info()


func _extract_instructions_from_data() -> Array[BaseInstruction]:
	var result: Array[BaseInstruction] = []
	match _level:
		"L2", "L3":
			var ar_data: Dictionary = _serialized_data.get("action_runner", {})
			# 从序列化数据中提取原始指令引用用于统计
			if _source_node is Trigger:
				var trigger := _source_node as Trigger
				if trigger.action_runner:
					result = trigger.action_runner.instructions
			elif _source_node is Runner:
				var runner := _source_node as Runner
				if runner.action_runner:
					result = runner.action_runner.instructions
		"L4":
			for bdata in _serialized_data.get("event_bindings", []):
				var ar_data: Dictionary = bdata.get("action_runner", {})
				# 统计用 — 从节点获取实际引用
			if _source_node is MultiEventTrigger:
				var multi := _source_node as MultiEventTrigger
				for binding in multi.event_bindings:
					if binding.action_runner:
						result.append_array(binding.action_runner.instructions)
	return result
```

- [ ] **Step 2: 添加 level 标签到 UI**

在 `_build_ui()` 方法中，在 grid 最顶部添加 level 标签行：

```gdscript
func _build_ui() -> void:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(grid)

	# Level 标签（新增）
	grid.add_child(_make_label("层级:"))
	_level_label = Label.new()
	_level_label.text = _level_display_name()
	_level_label.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
	grid.add_child(_level_label)

	# display_name
	grid.add_child(_make_label("名称:"))
	_display_name_input = LineEdit.new()
	_display_name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_display_name_input.placeholder_text = _default_display_name()
	grid.add_child(_display_name_input)

	# ... 其余 UI 不变 ...


func _level_display_name() -> String:
	match _level:
		"L1": return "L1 · ActionRunner（指令序列）"
		"L2": return "L2 · Trigger（事件 + 指令）"
		"L3": return "L3 · Runner（信号 + 指令）"
		"L4": return "L4 · MultiEventTrigger（多事件绑定）"
	return _level


func _default_display_name() -> String:
	if _source_node:
		return _source_node.name
	return ""
```

- [ ] **Step 3: 修改 get_preset()**

```gdscript
func get_preset() -> FusePreset:
	var preset := FusePreset.new()
	preset.level = _level
	preset.display_name = _display_name_input.text
	preset.category = _category_input.text
	preset.description = _description_input.text
	preset.icon_name = _icon_input.text
	preset.version = "2.0"

	match _level:
		"L1":
			preset.instructions = _instructions
			preset.variables = preset.collect_variables()
		"L2":
			preset.instructions = _serialized_data.get("action_runner", {}).get("instructions", []) if _source_node else _instructions
			preset.event_json = _serialized_data.get("event", {})
			preset.trigger_config = _serialized_data.get("trigger_config", {})
		"L3":
			preset.instructions = _serialized_data.get("action_runner", {}).get("instructions", []) if _source_node else _instructions
			preset.signal_binding = _serialized_data.get("signal_binding", {})
		"L4":
			preset.event_bindings_json = _serialized_data.get("event_bindings", [])
			preset.trigger_config = _serialized_data.get("trigger_config", {})

	preset.variables = preset.collect_variables()
	return preset
```

- [ ] **Step 4: 验证**

在编辑器中打开包含 Trigger 节点的场景，通过 `instructions_array_property.gd` 的 L1 导出按钮验证旧路径仍然工作。后续 Task 5 验证新路径。

- [ ] **Step 5: 提交**

```bash
git add addons/fuse/editor/preset_export_dialog.gd
git commit -m "feat(fuse): PresetExportDialog 支持 Variant 参数 + level 标签"
```

---

### Task 5: Inspector 导出按钮（L2/L3/L4 入口）

**Files:**
- Modify: `addons/fuse/editor/fuse_inspector_plugin.gd`

- [ ] **Step 1: 在 _parse_end 中添加导出按钮**

在现有的数据流卡片逻辑中，为 Trigger/Runner/MultiEventTrigger 添加导出按钮（在数据流按钮上方）：

```gdscript
# fuse_inspector_plugin.gd — 在 _parse_end() 中，_add_dataflow_ui 之前

var _export_btn: Button = null
var _current_node: Node = null


func _parse_end(object: Object) -> void:
	if object is BaseTrigger:
		var report = InstructionAnalyzerClass.analyze_trigger(object)
		_report_cache = report
		_current_node = object as Node
		_add_export_button(object as Node)
		_add_dataflow_ui(report)

	if object is Runner:
		_current_node = object as Runner
		_add_export_button(object as Runner)


func _add_export_button(node: Node) -> void:
	var level := FusePresetSerializer.detect_level(node)
	if level.is_empty() or level == "L1":
		return  # L1 由 instructions_array_property 处理

	# 校验（§9.3 导出前最小校验）
	var errors := _validate_before_export(node, level)
	if not errors.is_empty():
		return

	if _export_btn:
		_export_btn.text = "📦 导出为预设 (%s)" % level
		return

	_export_btn = Button.new()
	_export_btn.text = "📦 导出为预设 (%s)" % level
	_export_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_export_btn.pressed.connect(_on_export_preset_pressed)
	add_custom_control(_export_btn)


func _validate_before_export(node: Node, level: String) -> Array[String]:
	var errors: Array[String] = []
	match level:
		"L2":
			var trigger := node as Trigger
			if not trigger or not trigger.event_definition:
				errors.append("事件定义未配置，无法导出")
		"L3":
			var runner := node as Runner
			if not runner or not runner.action_runner:
				errors.append("ActionRunner 未配置，无法导出")
		"L4":
			var multi := node as MultiEventTrigger
			if not multi:
				errors.append("节点无效")
			else:
				var has_enabled := false
				for binding in multi.event_bindings:
					if binding.enabled:
						has_enabled = true
						break
				if not has_enabled:
					errors.append("没有启用的事件绑定，无法导出")
	return errors


func _on_export_preset_pressed() -> void:
	if _current_node == null:
		return
	var dialog := PresetExportDialog.new(_current_node)
	EditorInterface.get_base_control().add_child(dialog)
	dialog.confirmed.connect(_on_export_confirmed.bind(dialog))
	dialog.popup_centered()


func _on_export_confirmed(dialog: PresetExportDialog) -> void:
	var preset := dialog.get_preset()
	var dir_path := "res://addons/fuse/presets/%s" % preset.category
	DirAccess.make_dir_recursive_absolute(dir_path)
	var base_name := preset.display_name.to_snake_case()
	var tres_path := "%s/%s.tres" % [dir_path, base_name]
	ResourceSaver.save(preset, tres_path)
	var json_path := "%s/%s.json" % [dir_path, base_name]
	var file := FileAccess.open(json_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(preset.to_json(), "\t"))
		file.close()
	PresetRegistry.scan_presets()
	print("预设已导出: %s (%s)" % [tres_path, preset.level])
```

- [ ] **Step 2: 验证**

在编辑器中分别选中 Trigger、Runner、MultiEventTrigger 节点，检查 Inspector 底部是否出现"📦 导出为预设"按钮。选中无 event_definition 的 Trigger 时按钮不应出现。

- [ ] **Step 3: 提交**

```bash
git add addons/fuse/editor/fuse_inspector_plugin.gd
git commit -m "feat(fuse): Inspector 导出按钮 — L2/L3/L4 入口 + 导出前校验"
```

---

### Task 6: 导入对话框改造 + 节点创建

**Files:**
- Modify: `addons/fuse/editor/preset_import_dialog.gd`

- [ ] **Step 1: 添加 level 标签和节点创建逻辑**

将现有 `_build_ui()` 扩展，在描述之后显示 level 信息，确认按钮触发节点创建：

```gdscript
# addons/fuse/editor/preset_import_dialog.gd
@tool
class_name PresetImportDialog
extends AcceptDialog

## 导入映射对话框 — 按 level 创建对应节点，含 NodePath 映射 + 变量依赖检查

var _preset: FusePreset
var _mapping: Dictionary = {}  # old_nodepath_str → new_nodepath_str
var _created_node: Node = null


func _init(preset: FusePreset) -> void:
	_preset = preset
	title = "应用预设: %s [%s]" % [preset.display_name, preset.level]
	ok_button_text = "创建节点"
	_build_ui()


func _build_ui() -> void:
	var vbox := VBoxContainer.new()
	add_child(vbox)

	# Level 信息
	var level_label := Label.new()
	level_label.text = _level_display()
	level_label.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
	vbox.add_child(level_label)

	# 描述
	var desc_label := Label.new()
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_label.text = "%s · %s\n%s" % [_preset.category, _preset.display_name, _preset.description]
	vbox.add_child(desc_label)

	# NodePath 映射
	var nodepaths := _collect_all_nodepaths()
	if not nodepaths.is_empty():
		vbox.add_child(_make_section("NodePath 映射"))
		for np_str in nodepaths:
			var hbox := HBoxContainer.new()
			var lbl := Label.new()
			lbl.text = np_str
			lbl.custom_minimum_size.x = 120
			hbox.add_child(lbl)
			var arrow := Label.new()
			arrow.text = " → "
			hbox.add_child(arrow)
			var matched := _auto_match_nodepath_str(np_str)
			var option := OptionButton.new()
			option.add_item("自动: %s" % matched if matched != "" else "⚠ 手动选择...")
			option.custom_minimum_size.x = 200
			hbox.add_child(option)
			vbox.add_child(hbox)
			_mapping[np_str] = matched if matched != "" else ""

	# L3 特殊：信号源节点
	if _preset.level == "L3":
		vbox.add_child(_make_section("信号源节点"))
		var hbox := HBoxContainer.new()
		var lbl := Label.new()
		lbl.text = "信号源:"
		hbox.add_child(lbl)
		var option := OptionButton.new()
		option.add_item("选择节点...")
		option.custom_minimum_size.x = 200
		hbox.add_child(option)
		vbox.add_child(hbox)

	# 变量检查
	_build_variable_section(vbox)


func _level_display() -> String:
	match _preset.level:
		"L1": return "L1 · ActionRunner（将创建 Resource，不创建节点）"
		"L2": return "L2 · Trigger（将创建 Trigger 节点）"
		"L3": return "L3 · Runner（将创建 Runner 节点）"
		"L4": return "L4 · MultiEventTrigger（将创建 MultiEventTrigger 节点）"
	return _preset.level


func _build_variable_section(vbox: VBoxContainer) -> void:
	var vars := _preset.collect_variables()
	if vars.local.is_empty() and vars.scope.is_empty() and vars.global.is_empty():
		return
	vbox.add_child(_make_section("变量依赖"))
	if not vars.local.is_empty():
		vbox.add_child(_make_var_line("[local] %s — 运行时自动创建" % ", ".join(vars.local)))
	for sv in vars.scope:
		var exists := sv.container in _mapping
		var status := "✅" if exists else "⚠ 容器不在映射表中"
		vbox.add_child(_make_var_line("[scope] %s — 容器: %s %s" % [sv.name, sv.container, status]))
	if not vars.global.is_empty():
		vbox.add_child(_make_var_line("[global] %s — 项目级存在" % ", ".join(vars.global)))
```

- [ ] **Step 2: 扩展 NodePath 收集**

```gdscript
func _collect_all_nodepaths() -> Array[String]:
	var result: Array[String] = []

	# 扫描 instructions（所有层级）
	for inst in _preset.instructions:
		_collect_nodepaths_from_object(inst, result)

	# L2/L4: 扫描 event
	if not _preset.event_json.is_empty():
		_collect_nodepaths_from_dict(_preset.event_json, result)

	# L4: 扫描每个 binding 的 conditions
	for bdata in _preset.event_bindings_json:
		if bdata.has("conditions"):
			for cdata in bdata["conditions"]:
				_collect_nodepaths_from_dict(cdata, result)

	# 去重
	var unique: Array[String] = []
	for np in result:
		if np not in unique:
			unique.append(np)
	return unique


func _collect_nodepaths_from_object(obj: Object, result: Array[String]) -> void:
	if obj == null:
		return
	for prop in obj.get_property_list():
		if prop.type == TYPE_NODE_PATH:
			var np: NodePath = obj.get(prop.name)
			var np_str := str(np)
			if not np_str.is_empty() and np_str not in result:
				result.append(np_str)


func _collect_nodepaths_from_dict(data: Dictionary, result: Array[String]) -> void:
	for key in data:
		var val = data[key]
		if val is String and ("/" in val or ".." in val):
			if val not in result:
				result.append(val)
```

- [ ] **Step 3: 确认按钮创建节点**

覆盖 `_confirmed` 回调：

```gdscript
func _confirmed() -> void:
	# 获取挂载父节点
	var parent := _get_target_parent()
	if parent == null:
		push_warning("无法确定挂载点，取消导入")
		return

	# 反序列化
	_created_node = FusePresetDeserializer.deserialize(_preset, _mapping)

	if _created_node == null:
		push_error("节点创建失败")
		return

	# L1 不需要挂到场景
	if _preset.level == "L1":
		print("ActionRunner Resource 已创建: %s" % _created_node.resource_name)
		return

	# 挂到场景
	parent.add_child(_created_node)
	_created_node.owner = parent.owner if parent.owner else parent

	# 导入后校验（§9.1）
	var warnings := FusePresetDeserializer.validate_imported_node(_created_node, _preset.level)
	if not warnings.is_empty():
		_show_import_warnings(warnings)

	print("节点已创建: %s (%s)" % [_created_node.name, _preset.level])


func _get_target_parent() -> Node:
	var selection := EditorInterface.get_selection()
	if selection:
		var selected_nodes := selection.get_selected_nodes()
		if not selected_nodes.is_empty():
			return selected_nodes[0]
	var scene_root := EditorInterface.get_edited_scene_root()
	return scene_root


func _show_import_warnings(warnings: Array[String]) -> void:
	var msg := "导入完成，但有以下警告:\n\n" + "\n".join(warnings)
	var dialog := AcceptDialog.new()
	dialog.title = "导入警告"
	dialog.dialog_text = msg
	EditorInterface.get_base_control().add_child(dialog)
	dialog.popup_centered()
```

- [ ] **Step 4: 保留现有辅助方法**

保留 `_make_section`、`_make_var_line`、`_auto_match_nodepath(str)` 等方法不变。将 `_auto_match_nodepath` 改为接受 String 参数：

```gdscript
func _auto_match_nodepath_str(np_str: String) -> String:
	var scene_root := EditorInterface.get_edited_scene_root()
	if scene_root == null:
		return ""
	var target_name := np_str.get_file()
	var found: Array[Node] = scene_root.find_children(target_name, "", true, false)
	if not found.is_empty():
		return str(found[0].get_path())
	return ""
```

- [ ] **Step 5: 更新预设面板的"应用"按钮**

在 `preset_panel.gd` 的 `_on_apply_pressed` 中，已创建 `PresetImportDialog.new(_selected_preset)`，此调用兼容新构造函数。

在 `preset_panel.gd` 中为每条预设项添加 level 标签：

```gdscript
# preset_panel.gd — 在 refresh() 中修改
p_item.set_text(0, "[%s] %s" % [preset.level, preset.display_name])
```

- [ ] **Step 6: 验证**

1. 在编辑器中打开场景，选中一个普通 Node
2. 从预设面板选择一个 L2 预设 → 点击"应用预设" → 映射 NodePath → "创建节点"
3. 检查场景树中是否出现新的 Trigger 节点，event_definition 和 action_runner 是否正确填充
4. 对 L3、L4 重复验证
5. 检查 L1 预设在无场景选中时能否创建 ActionRunner Resource

- [ ] **Step 7: 提交**

```bash
git add addons/fuse/editor/preset_import_dialog.gd addons/fuse/editor/preset_panel.gd
git commit -m "feat(fuse): PresetImportDialog 按 level 创建节点 + NodePath 扩展扫描 + 导入后校验"
```

---

### Task 7: 端到端集成验证

- [ ] **Step 1: L1 回归测试**

1. 在场景中创建 ActionRunner Resource，添加几个指令
2. 在 `instructions_array_property.gd` 中点击"导出为预设"
3. 验证 `.tres` 和 `.json` 生成，JSON 中 `level` 为 "L1"，指令在 `action_runner.instructions` 内
4. 从预设面板导入 → 验证 ActionRunner Resource 正确创建

- [ ] **Step 2: L2 导出导入测试**

1. 在场景中创建一个 Trigger 节点，配置 event_definition 和 action_runner
2. Inspector 中出现"📦 导出为预设 (L2)"按钮 → 点击导出
3. 检查 JSON 包含 `level: "L2"`、`event`、`action_runner`、`trigger_config`
4. 新场景中导入 → 验证 Trigger 节点创建，所有属性正确

- [ ] **Step 3: L3 导出导入测试**

1. 创建 Runner 节点，配置 action_runner 和 signal_name
2. 导出 → 检查 JSON 包含 `signal_binding.signal_name`
3. 新场景中导入 → 选择信号源节点 → 验证 Runner 创建，signal_name 未丢失

- [ ] **Step 4: L4 导出导入测试**

1. 创建 MultiEventTrigger 节点，添加 2 个 EventBinding（含 conditions）
2. 导出 → 检查 JSON 中 `event_bindings` 数组完整
3. 新场景中导入 → 验证 MultiEventTrigger 创建，event_bindings 在 Inspector 中可见

- [ ] **Step 5: 边界情况测试**

- 空 event_definition 的 Trigger → 不显示导出按钮
- 空 action_runner 的 Runner → 不显示导出按钮
- 全部 binding 禁用的 MultiEventTrigger → 不显示导出按钮
- 导入含 scope 变量的预设 → 变量检查显示容器状态
- 导入含 event/conditions 中 NodePath 的预设 → 映射对话框包含这些路径

- [ ] **Step 6: 提交**

```bash
git commit -m "test(fuse): Stage 6 L1-L4 端到端集成验证完成"
```

---

**文档版本:** 1.0
**创建日期:** 2026-06-19
**关联设计:** [2026-06-19-fuse-stage6-design.md](../specs/2026-06-19-fuse-stage6-design.md)
