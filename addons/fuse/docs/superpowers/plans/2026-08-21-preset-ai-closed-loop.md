# Preset AI 管线闭环实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 建立「AI 生成 preset JSON → 离线校验 → 自动评分 → 回归门禁」闭环，并把 AI 可覆盖的 preset 空间从 L1/L2 扩展到 L1-L4 + IfThen/IfElse 条件构造。

**Architecture:** 校验器与 eval runner 均为 Godot headless 场景（复用 `dump_context.tscn` 模式），校验逻辑直接调用真实运行时代码（`FusePreset.from_json` / `PresetValueCodec` / dumped schemas JSON），保证与导入行为零漂移。校验分四层：结构 → schema 比对 → codec 实测（计数比对，不拦日志）→ 语义。

**Tech Stack:** Godot 4.7 headless GDScript；无外部测试框架（场景式测试 + `assert` + 退出码）。

**Spec:** `addons/fuse/docs/superpowers/specs/2026-08-21-preset-ai-closed-loop-design.md`（本计划从 spec 论证，执行者须同时读两者）

## Global Constraints

- Godot 二进制（Git Bash 路径，每个任务执行前先 `export GODOT="/e/Godot/Godot_v4.7-stable_mono_win64/Godot_v4.7-stable_mono_win64_console.exe"`）：`"$GODOT" --headless --path <repo> res://<scene>`；首次跑任何场景前如报类缓存错误，先 `"$GODOT" --headless --import --path <repo>`（AGENTS.md 规定）。
- 仓库根：`E:\GitHub\fuse`（Git Bash 下 `/e/GitHub/fuse`），下文相对路径均基于仓库根。
- GDScript 风格：tab 缩进、全类型注解、`push_error`/`push_warning`、snake_case、信号处理器 `_on_{emitter}_{signal}`（AGENTS.md）。
- 测试：`.tscn` 场景 + 根脚本 `_ready()` 运行，`print("✓ ...")` + `assert(cond, msg)`；**测试脚本结尾必须 `get_tree().quit(fail_count > 0 ? 1 : 0)`**（本计划新增的退出码约定，服务于闭环门禁）。
- 本计划**不新增组件**（无 Event/Instruction/Condition 新类），无需重新 dump `preset_ai_context/`。
- 提交风格：`feat:`/`fix:`/`docs:`/`chore:` + 中文描述；每个任务至少一次提交。
- 运行时事实（已核实，勿再质疑，直接依赖）：
  - `PresetValueCodec.deserialize_value()`（`addons/fuse/core/serialization/preset_value_codec.gd:94`）对 Vector2 属性无特判，`Object.set()` 的 Variant 隐式转换 **String→Vector2 可转、Array→Vector2 不可转**；schema default 也是字符串 `"(0.0, 0.0)"`。
  - `FusePreset.from_json()`（`addons/fuse/core/resources/fuse_preset.gd:96`）L4 分支不反序列化指令（`event_bindings_json` 原样存 Dictionary 数组），校验器 codec 层须对 L4 手动逐 binding 调 `PresetValueCodec.deserialize_instructions/ deserialize_event`。
  - 嵌套指令字段全集：`instructions / true_instructions / false_instructions / else_instructions / loop_instructions`。
  - `game_flow.json`（L4，5 个 binding）与 `spawn_enemy.json`（L1，ForEach+loop_instructions）的嵌套指令是 2026-07-08 旧导出的字符串化产物；`hint_breath.json`（L2）的 `event.stop_condition` 是场景私有引用 `title_scene.tscn::Resource_fknqa`；`red_planet.json`（L2，Vector2 用字符串形式）当前干净。
  - iteration-1 产物预期：attack with_skill 通过 / without_skill 失败（幻觉参数 `operand_a_variable`、`operand_a_scope`、缺 `operand_a_custom_scope_id` 等）；patrol with_skill 失败（2 处 `target_position` 数组形式）/ without_skill 失败（幻觉参数 `time_scope`）；countdown 两版待实测。

---

## 文件结构总览

| 文件 | 职责 |
|------|------|
| `addons/fuse/editor/preset_ai/preset_validator.gd` | 静态校验 API：`validate_data` / `validate_preset` / `validate_path` |
| `addons/fuse/editor/preset_ai/validate_preset.tscn` (+`validate_preset_cli.gd`) | headless CLI：参数解析、报告落盘、退出码 |
| `addons/fuse/editor/preset_ai/eval_runner.gd` | 静态评测 API：`run_replay` / 断言引擎 / baseline 门禁 |
| `addons/fuse/editor/preset_ai/eval_runner.tscn` (+`eval_runner_cli.gd`) | headless CLI（回放 + live） |
| `addons/fuse/editor/preset_ai/regen_samples.tscn` (+`regen_samples.gd`) | M3 从源场景重导 3 个污染样例 |
| `addons/fuse/tests/preset_ai/*.tscn/.gd` | 校验器 / runner / codec 导出测试 |
| `fuse-preset-generator-workspace/evals/cases/*.json` | case 定义（prompt + 结构断言 + 产物映射） |
| `fuse-preset-generator-workspace/eval_baseline.json` | 回归门禁基线 |

---

## 里程碑 M1：离线校验器

### Task 1: 校验器骨架 + 结构层

**Files:**
- Create: `addons/fuse/editor/preset_ai/preset_validator.gd`
- Create: `addons/fuse/tests/preset_ai/test_preset_validator.gd`
- Create: `addons/fuse/tests/preset_ai/test_preset_validator.tscn`

**Interfaces:**
- Consumes: `fuse_component_schemas.json`（本任务只加载不使用，Task 2 用）
- Produces（后续任务依赖，签名固定）:
  - `static func validate_data(data: Dictionary, src: String = "<inline>") -> Dictionary` → `{"path": src, "errors": int, "warnings": int, "findings": Array}`
  - `static func validate_preset(path: String) -> Dictionary`（同上结构；非 preset JSON → 1 条 `info` finding `I_NOT_PRESET`）
  - `static func validate_path(target: String) -> Dictionary`（Task 6 实现目录递归）
  - finding 结构：`{"code": String, "severity": "error"|"warning"|"info", "json_path": String, "message": String}`
  - `static func _finding(code: String, severity: String, json_path: String, message: String) -> Dictionary`

- [ ] **Step 1: 写失败测试**

`addons/fuse/tests/preset_ai/test_preset_validator.gd`：

```gdscript
# addons/fuse/tests/preset_ai/test_preset_validator.gd
extends Node

const PresetValidator := preload("res://addons/fuse/editor/preset_ai/preset_validator.gd")

var _fail := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("✓ " + msg)
	else:
		_fail += 1
		push_error("✗ " + msg)

func _ready():
	print("=== test_preset_validator: 结构层 ===")
	_test_valid_l1()
	_test_parse_error()
	_test_format_version()
	_test_level_unknown()
	_test_level_mismatch()
	print("=== 结果: %d 失败 ===" % _fail)
	get_tree().quit(1 if _fail > 0 else 0)

func _valid_l1() -> Dictionary:
	return {
		"format_version": "2.0",
		"level": "L1",
		"display_name": "t",
		"variables": {"local": [], "scope": [], "global": []},
		"action_runner": {"execution_mode": 0, "instructions": []},
	}

func _test_valid_l1() -> void:
	var r := PresetValidator.validate_data(_valid_l1())
	_check(r.errors == 0, "最小合法 L1 无 error（实际 findings: %s）" % JSON.stringify(r.findings))

func _test_parse_error() -> void:
	var r := PresetValidator.validate_data({"no_format_version": 1})
	var codes := r.findings.map(func(f): return f.code)
	_check("E_FORMAT_VERSION" in codes, "缺 format_version → E_FORMAT_VERSION")

func _test_format_version() -> void:
	var d := _valid_l1()
	d["format_version"] = "1.0"
	var codes := PresetValidator.validate_data(d).findings.map(func(f): return f.code)
	_check("E_FORMAT_VERSION" in codes, "format_version != 2.0 → E_FORMAT_VERSION")

func _test_level_unknown() -> void:
	var d := _valid_l1()
	d["level"] = "L9"
	var codes := PresetValidator.validate_data(d).findings.map(func(f): return f.code)
	_check("E_LEVEL_UNKNOWN" in codes, "level=L9 → E_LEVEL_UNKNOWN")

func _test_level_mismatch() -> void:
	var d := _valid_l1()
	d["level"] = "L2"  # 声明 L2 但没有 event
	var codes := PresetValidator.validate_data(d).findings.map(func(f): return f.code)
	_check("E_LEVEL_MISMATCH" in codes, "声明 L2 无 event → E_LEVEL_MISMATCH")
```

`test_preset_validator.tscn`（纯文本创建，root 挂测试脚本）：

```
[gd_scene load_steps=2 format=3 uid="uidc000000val1"]

[ext_resource type="Script" path="res://addons/fuse/tests/preset_ai/test_preset_validator.gd" id="1"]

[node name="TestPresetValidator" type="Node"]
script = ExtResource("1")
```

- [ ] **Step 2: 跑测试确认失败**

Run: `"$GODOT" --headless --path . res://addons/freset/tests/preset_ai/test_preset_validator.tscn 2>&1 | head -5`（路径用正确的 `addons/fuse`）
Expected: 脚本加载失败或 `_check` 全 ✗（类不存在）

- [ ] **Step 3: 实现骨架 + 结构层**

`addons/fuse/editor/preset_ai/preset_validator.gd`：

```gdscript
# addons/fuse/editor/preset_ai/preset_validator.gd
@tool
class_name PresetValidator
extends RefCounted

## Preset 离线校验器（spec §4）
## 四层：结构 → schema 比对 → codec 实测 → 语义
## 只读 JSON 与真实 codec，不修改任何文件。

const SCHEMAS_PATH := "res://addons/fuse/preset_ai_context/fuse_component_schemas.json"

static func _finding(code: String, severity: String, json_path: String, message: String) -> Dictionary:
	return {"code": code, "severity": severity, "json_path": json_path, "message": message}


static func _report_for(src: String, findings: Array) -> Dictionary:
	var errors := findings.filter(func(f): return f.severity == "error").size()
	var warnings := findings.filter(func(f): return f.severity == "warning").size()
	return {"path": src, "errors": errors, "warnings": warnings, "findings": findings}


# ---- 公共入口 ----

static func validate_preset(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty() and not FileAccess.file_exists(path):
		return _report_for(path, [_finding("E_PARSE", "error", "$", "文件不存在")])
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		if parsed == null:
			return _report_for(path, [_finding("E_PARSE", "error", "$", "JSON 解析失败")])
		return _report_for(path, [_finding("I_NOT_PRESET", "info", "$", "合法 JSON 但顶层非对象，跳过")])
	var data: Dictionary = parsed
	if not data.has("format_version"):
		return _report_for(path, [_finding("I_NOT_PRESET", "info", "$", "无 format_version 字段，非 preset JSON，跳过")])
	return validate_data(data, path)


static func validate_data(data: Dictionary, src: String = "<inline>") -> Dictionary:
	var findings: Array = []
	_validate_structure(data, findings)
	if not findings.any(func(f): return f.code in ["E_PARSE"]):
		_validate_schema(data, findings)      # Task 2-3 实现
		_validate_codec(data, findings)       # Task 3 实现
	_validate_semantics(data, findings)      # Task 4 实现
	return _report_for(src, findings)


static func validate_path(target: String) -> Dictionary:
	# Task 6 实现（目录递归）；本任务先支持单文件
	return {"files": [validate_preset(target)], "summary": {}}


# ---- 第 1 层：结构 ----

static func _infer_level(data: Dictionary) -> String:
	if data.has("event_bindings"): return "L4"
	if data.has("signal_binding"): return "L3"
	if data.has("event"): return "L2"
	if data.has("action_runner"): return "L1"
	return ""


static func _validate_structure(data: Dictionary, findings: Array) -> void:
	if str(data.get("format_version", "")) != "2.0":
		findings.append(_finding("E_FORMAT_VERSION", "error", "$.format_version",
			"format_version 必须为 \"2.0\"，实际 %s" % str(data.get("format_version", "<缺失>"))))
	var declared: String = str(data.get("level", ""))
	if declared not in ["L1", "L2", "L3", "L4"]:
		findings.append(_finding("E_LEVEL_UNKNOWN", "error", "$.level", "未知 level '%s'" % declared))
		return
	var inferred := _infer_level(data)
	if inferred != declared:
		findings.append(_finding("E_LEVEL_MISMATCH", "error", "$.level",
			"声明 %s 但字段集合推断为 %s" % [declared, inferred if inferred != "" else "<无法推断>"]))


# ---- 第 2/3/4 层占位（后续任务实现）----

static func _validate_schema(data: Dictionary, findings: Array) -> void:
	pass


static func _validate_codec(data: Dictionary, findings: Array) -> void:
	pass


static func _validate_semantics(data: Dictionary, findings: Array) -> void:
	pass
```

- [ ] **Step 4: 跑测试确认通过**

Run: `"$GODOT" --headless --path . res://addons/fuse/tests/preset_ai/test_preset_validator.tscn`
Expected: 全部 ✓，`=== 结果: 0 失败 ===`，退出码 0

- [ ] **Step 5: Commit**

```bash
git add addons/fuse/editor/preset_ai/preset_validator.gd addons/fuse/tests/preset_ai/
git commit -m "feat: PresetValidator 骨架与结构层校验（E_PARSE/E_FORMAT_VERSION/E_LEVEL_*）"
```

### Task 2: schema 层——组件/参数/枚举/类型

**Files:**
- Modify: `addons/fuse/editor/preset_ai/preset_validator.gd`
- Modify: `addons/fuse/tests/preset_ai/test_preset_validator.gd`

**Interfaces:**
- Consumes: Task 1 的 `validate_data` / `_finding`
- Produces: `static func _load_schemas() -> Dictionary`（缓存；键 = class_name，值 = 参数 Array）；`static func _validate_schema` 真实实现；finding codes `E_UNKNOWN_COMPONENT` / `E_UNKNOWN_PARAM` / `E_ENUM_RANGE` / `E_TYPE_MISMATCH` / `W_MISSING_PARAM`

- [ ] **Step 1: 写失败测试（追加到 test_preset_validator.gd 的 `_ready()` 尾部与文件尾部）**

```gdscript
# _ready() 内追加：
	_test_unknown_component()
	_test_unknown_param()
	_test_enum_range()
	_test_type_mismatch()
	_test_missing_param_warning()

# 文件尾部追加：
func _l1_with(inst: Dictionary) -> Dictionary:
	var d := _valid_l1()
	d["action_runner"]["instructions"] = [inst]
	return d

func _codes(inst: Dictionary) -> Array:
	return PresetValidator.validate_data(_l1_with(inst)).findings.map(func(f): return f.code)

func _test_unknown_component() -> void:
	_check("E_UNKNOWN_COMPONENT" in _codes({"type": "NotAComponent", "value": 1}),
		"未知组件 → E_UNKNOWN_COMPONENT")

func _test_unknown_param() -> void:
	_check("E_UNKNOWN_PARAM" in _codes({"type": "Wait", "wait_time": 1.0, "time_scope": 0}),
		"幻觉参数 time_scope → E_UNKNOWN_PARAM")

func _test_enum_range() -> void:
	# Wait.value_source 是枚举 Direct:0,Variable:1
	_check("E_ENUM_RANGE" in _codes({"type": "Wait", "wait_time": 1.0, "value_source": 7}),
		"枚举越界 → E_ENUM_RANGE")

func _test_type_mismatch() -> void:
	_check("E_TYPE_MISMATCH" in _codes({"type": "Wait", "wait_time": "1.0"}),
		"字符串赋给 float 参数 → E_TYPE_MISMATCH")

func _test_missing_param_warning() -> void:
	var r := PresetValidator.validate_data(_l1_with({"type": "Wait"}))
	var has_w := r.findings.any(func(f): return f.code == "W_MISSING_PARAM")
	_check(has_w and r.errors == 0, "缺参数但有默认值 → 仅 W_MISSING_PARAM，无 error")
```

- [ ] **Step 2: 跑测试确认失败**（`E_UNKNOWN_COMPONENT` 等不在 findings 中）

- [ ] **Step 3: 实现 schema 层**

替换 `_validate_schema` 占位：

```gdscript
const _ENGINE_VALUE_TYPES := ["Vector2", "Vector2i", "Vector3", "Vector3i", "Vector4",
	"Color", "Rect2", "Rect2i", "Quaternion", "Transform2D", "Transform3D", "Basis",
	"AABB", "Plane", "Projection", "StringName"]

static var _schemas_cache: Dictionary = {}

static func _load_schemas() -> Dictionary:
	if _schemas_cache.is_empty():
		var text := FileAccess.get_file_as_string(SCHEMAS_PATH)
		var parsed: Variant = JSON.parse_string(text)
		_schemas_cache = parsed if parsed is Dictionary else {}
	return _schemas_cache

static func _validate_schema(data: Dictionary, findings: Array) -> void:
	var level := _infer_level(data)
	if level in ["L1", "L2", "L3"]:
		var insts: Array = data.get("action_runner", {}).get("instructions", [])
		for i in insts.size():
			_validate_component(insts[i], "instruction", "$.action_runner.instructions[%d]" % i, findings)
	elif level == "L4":
		var bindings: Array = data.get("event_bindings", [])
		for b in bindings.size():
			var binding: Dictionary = bindings[b] if bindings[b] is Dictionary else {}
			var ar: Dictionary = binding.get("action_runner", {})
			for i in ar.get("instructions", []).size():
				_validate_component(ar["instructions"][i], "instruction",
					"$.event_bindings[%d].action_runner.instructions[%d]" % [b, i], findings)
			if binding.has("event"):
				_validate_component(binding["event"], "event", "$.event_bindings[%d].event" % b, findings)
			for c in binding.get("conditions", []).size():
				_validate_component(binding["conditions"][c], "condition",
					"$.event_bindings[%d].conditions[%d]" % [b, c], findings)
	if level == "L2" and data.has("event"):
		_validate_component(data["event"], "event", "$.event", findings)

static func _validate_component(comp: Variant, kind: String, path: String, findings: Array) -> void:
	if not (comp is Dictionary):
		findings.append(_finding("E_TYPE_MISMATCH", "error", path, "应为对象，实际 %s" % typeof(comp)))
		return
	var type_name: String = str(comp.get("type", ""))
	var schemas := _load_schemas()
	if not schemas.has(type_name):
		findings.append(_finding("E_UNKNOWN_COMPONENT", "error", path + ".type",
			"未知 %s 组件 '%s'（不在 schemas dump 中）" % [kind, type_name]))
		return
	var params: Array = schemas[type_name]
	var known := {}
	for p in params:
		known[p["name"]] = p
	for key in comp:
		if key == "type": continue
		if not known.has(key):
			findings.append(_finding("E_UNKNOWN_PARAM", "error", path + "." + key,
				"组件 %s 无参数 '%s'（幻觉参数名）" % [type_name, key]))
			continue
		var p: Dictionary = known[key]
		var hint: int = int(p.get("hint", 0))
		if hint == 2:  # PROPERTY_HINT_ENUM
			var allowed := {}
			for pair in String(p.get("hint_string", "")).split(","):
				var kv := pair.split(":")
				if kv.size() == 2:
					allowed[kv[1].strip_edges()] = true
			if not allowed.has(str(comp[key])):
				findings.append(_finding("E_ENUM_RANGE", "error", path + "." + key,
					"枚举参数 %s.%s 值 %s 不在 %s 中" % [type_name, key, str(comp[key]), p.get("hint_string")]))
		else:
			_check_json_type(comp[key], p, path + "." + key, type_name, findings)
		# 递归：嵌套指令
		if p.get("is_nested_instructions", false) and comp[key] is Array:
			for i in comp[key].size():
				_validate_component(comp[key][i], "instruction", path + "." + key + "[%d]" % i, findings)
		# 递归：condition 字段（hint_string 为 BaseCondition 的 Object 参数）
		if String(p.get("type_name", "")) == "Object" and String(p.get("hint_string", "")) == "BaseCondition" and comp[key] is Dictionary:
			_validate_component(comp[key], "condition", path + "." + key, findings)
	# 缺参数提示
	for p in params:
		if not comp.has(p["name"]):
			findings.append(_finding("W_MISSING_PARAM", "warning", path,
				"缺少参数 %s.%s，将用默认值 %s" % [type_name, p["name"], str(p.get("default"))]))

static func _check_json_type(value: Variant, p: Dictionary, path: String, type_name: String, findings: Array) -> void:
	var tn: String = p.get("type_name", "")
	var ok := true
	match tn:
		"String": ok = value is String
		"int": ok = value is float and float(value) == floor(float(value))
		"float": ok = value is float
		"bool": ok = value is bool
		"NodePath": ok = value is String
		"Dictionary": ok = value is Dictionary
		"Array": ok = value is Array
		"Object": ok = value is Dictionary or value is String
		_:
			if tn in _ENGINE_VALUE_TYPES:
				if value is String: return  # 规范形式，Task 5 细化
				ok = false
			else:
				return  # 未知类型名：放行，交给 codec 实测层
	if not ok:
		findings.append(_finding("E_TYPE_MISMATCH", "error", path,
			"参数 %s.%s 期望 %s，得到 %s" % [type_name, p.get("name", ""), tn, type_string(typeof(value))]))
```

注：`Array`/`Dictionary` 内部元素校验交给 codec 实测层（Task 3），schema 层不深入。

- [ ] **Step 4: 跑测试确认通过**

Run: `"$GODOT" --headless --path . res://addons/fuse/tests/preset_ai/test_preset_validator.tscn`
Expected: 全部 ✓，0 失败

- [ ] **Step 5: Commit**

```bash
git add addons/fuse/editor/preset_ai/preset_validator.gd addons/fuse/tests/preset_ai/test_preset_validator.gd
git commit -m "feat: 校验器 schema 层（E_UNKNOWN_COMPONENT/E_UNKNOWN_PARAM/E_ENUM_RANGE/E_TYPE_MISMATCH/W_MISSING_PARAM）"
```

### Task 3: codec 实测层（roundtrip 计数 + 事件/条件还原）

**Files:**
- Modify: `addons/fuse/editor/preset_ai/preset_validator.gd`
- Modify: `addons/fuse/tests/preset_ai/test_preset_validator.gd`

**Interfaces:**
- Consumes: `FusePreset.from_json`、`PresetValueCodec.deserialize_instructions/deserialize_event`
- Produces: `_validate_codec` 真实实现；codes `E_ROUNDTRIP_LOSS` / `E_EVENT_NULL` / `E_CONDITION_NULL`；`static func _count_instruction_dicts(arr: Array) -> int`、`static func _count_instruction_objects(insts: Array) -> int`（Task 8 断言引擎复用）

- [ ] **Step 1: 写失败测试（追加）**

```gdscript
# _ready() 内追加：
	_test_roundtrip_loss()
	_test_event_null()
	_test_condition_null()

# 文件尾部追加：
func _test_roundtrip_loss() -> void:
	var inst := {"type": "ForEach", "loop_instructions": ["等待 2.0 秒 (res://x.tscn::Resource_a):<Resource#1>"]}
	var codes := _codes(inst)
	_check("E_ROUNDTRIP_LOSS" in codes, "字符串化嵌套指令 → E_ROUNDTRIP_LOSS")

func _test_event_null() -> void:
	var d := _valid_l1()
	d["level"] = "L2"
	d["event"] = {"type": "NoSuchEvent"}
	d["trigger_config"] = {"trigger_once": false, "cooldown_mode": 0, "cooldown_time": 1.0}
	var codes := PresetValidator.validate_data(d).findings.map(func(f): return f.code)
	_check("E_EVENT_NULL" in codes and "E_UNKNOWN_COMPONENT" in codes,
		"L2 event 未知类型 → E_EVENT_NULL + E_UNKNOWN_COMPONENT")

func _test_condition_null() -> void:
	var inst := {"type": "IfThen", "sequence_mode": 0,
		"condition": {"type": "NoSuchCondition"},
		"instructions": []}
	var codes := _codes(inst)
	_check("E_CONDITION_NULL" in codes and "E_UNKNOWN_COMPONENT" in codes,
		"condition inline dict 未知类型 → E_CONDITION_NULL + E_UNKNOWN_COMPONENT")
```

- [ ] **Step 2: 跑测试确认失败**

- [ ] **Step 3: 实现 codec 层**

```gdscript
const _NESTED_FIELDS := ["instructions", "true_instructions", "false_instructions", "else_instructions", "loop_instructions"]
const PresetValueCodecScript := preload("res://addons/fuse/core/serialization/preset_value_codec.gd")
const FusePresetScript := preload("res://addons/fuse/core/resources/fuse_preset.gd")

static func _validate_codec(data: Dictionary, findings: Array) -> void:
	var level := _infer_level(data)
	if level in ["L1", "L2", "L3"]:
		var src: Array = data.get("action_runner", {}).get("instructions", [])
		var preset := FusePresetScript.from_json(data.duplicate(true))
		var src_n := _count_instruction_dicts(src)
		var dst_n := _count_instruction_objects(preset.instructions)
		if src_n > dst_n:
			findings.append(_finding("E_ROUNDTRIP_LOSS", "error", "$.action_runner.instructions",
				"源 JSON 含 %d 条指令，反序列化仅剩 %d 条（静默丢弃）" % [src_n, dst_n]))
		_check_conditions_restore(data.get("action_runner", {}).get("instructions", []),
			"$.action_runner.instructions", findings)
		if level == "L2" and data.get("event", {}) is Dictionary and not (data["event"] as Dictionary).is_empty():
			if PresetValueCodecScript.deserialize_event(data["event"]) == null:
				findings.append(_finding("E_EVENT_NULL", "error", "$.event", "event 无法反序列化"))
	elif level == "L4":
		var bindings: Array = data.get("event_bindings", [])
		for b in bindings.size():
			var binding: Dictionary = bindings[b] if bindings[b] is Dictionary else {}
			var ar: Dictionary = binding.get("action_runner", {})
			var src: Array = ar.get("instructions", [])
			var insts := PresetValueCodecScript.deserialize_instructions(src)
			if _count_instruction_dicts(src) > _count_instruction_objects(insts):
				findings.append(_finding("E_ROUNDTRIP_LOSS", "error",
					"$.event_bindings[%d].action_runner.instructions" % b, "L4 binding 指令静默丢弃"))
			_check_conditions_restore(src, "$.event_bindings[%d].action_runner.instructions" % b, findings)
			if binding.has("event") and PresetValueCodecScript.deserialize_event(binding["event"]) == null:
				findings.append(_finding("E_EVENT_NULL", "error", "$.event_bindings[%d].event" % b,
					"L4 binding event 无法反序列化"))

static func _count_instruction_dicts(arr: Array) -> int:
	var n := 0
	for item in arr:
		if item is Dictionary and item.has("type"):
			n += 1
			for field in _NESTED_FIELDS:
				if item.get(field, null) is Array:
					n += _count_instruction_dicts(item[field])
	return n

static func _count_instruction_objects(insts: Array) -> int:
	var n := 0
	for inst in insts:
		if inst == null: continue
		n += 1
		for field in _NESTED_FIELDS:
			if field in inst:
				var sub: Variant = inst.get(field)
				if sub is Array:
					n += _count_instruction_objects(sub)
	return n

static func _check_conditions_restore(arr: Array, base_path: String, findings: Array) -> void:
	# 与 schema 层 condition 递归对齐：dict 形式的 condition 若反序列化为 null → E_CONDITION_NULL
	for i in arr.size():
		var item: Variant = arr[i]
		if not (item is Dictionary) or not item.has("type"): continue
		for field in ["condition"]:
			var cond: Variant = item.get(field, null)
			if cond is Dictionary and cond.has("type"):
				if PresetValueCodecScript.deserialize_condition(cond) == null:
					findings.append(_finding("E_CONDITION_NULL", "error",
						"%s[%d].%s" % [base_path, i, field], "condition 无法反序列化"))
		for field in _NESTED_FIELDS:
			if item.get(field, null) is Array:
				_check_conditions_restore(item[field], "%s[%d].%s" % [base_path, i, field], findings)
```

（注意：`_NESTED_FIELDS` 常量从文件顶部声明一次，Task 2 中 schema 层递归也引用它。）

- [ ] **Step 4: 跑测试确认通过**（全场景退出码 0）

- [ ] **Step 5: Commit**

```bash
git add addons/fuse/editor/preset_ai/preset_validator.gd addons/fuse/tests/preset_ai/test_preset_validator.gd
git commit -m "feat: 校验器 codec 实测层（E_ROUNDTRIP_LOSS/E_EVENT_NULL/E_CONDITION_NULL）"
```

### Task 4: 语义层（场景私有引用 / 资源存在性 / 变量声明）

**Files:**
- Modify: `addons/fuse/editor/preset_ai/preset_validator.gd`
- Modify: `addons/fuse/tests/preset_ai/test_preset_validator.gd`

**Interfaces:**
- Produces: `_validate_semantics` 实现；codes `E_SCENE_PRIVATE_REF` / `E_RESOURCE_NOT_FOUND` / `W_VARIABLE_UNDECLARED` / `W_NODEPATH_UNRESOLVED`

- [ ] **Step 1: 写失败测试（追加）**

```gdscript
# _ready() 内追加：
	_test_scene_private_ref()
	_test_variable_undeclared()

# 文件尾部追加：
func _test_scene_private_ref() -> void:
	var inst := {"type": "OnInterval", "interval_seconds": 1.0,
		"stop_condition": "res://demos/x.tscn::Resource_fknqa"}
	var d := _valid_l1()
	d["level"] = "L2"
	d["event"] = inst
	d["trigger_config"] = {"trigger_once": false, "cooldown_mode": 0, "cooldown_time": 1.0}
	var findings := PresetValidator.validate_data(d).findings
	_check(findings.any(func(f): return f.code == "E_SCENE_PRIVATE_REF"),
		"场景私有引用 → E_SCENE_PRIVATE_REF")

func _test_variable_undeclared() -> void:
	var inst := {"type": "SetVariable", "variable_name": "score", "variable_scope": 0, "value": 1}
	var d := _valid_l1()
	d["action_runner"]["instructions"] = [inst]
	var findings := PresetValidator.validate_data(d).findings
	_check(findings.any(func(f): return f.code == "W_VARIABLE_UNDECLARED"),
		"写未声明变量 → W_VARIABLE_UNDECLARED")
```

（先 `grep -n "class_name\|@export" addons/fuse/instructions/variables/set_variable.gd` 确认 `SetVariable` 的真实类名与参数名——若类名或参数名不同，用真实的；下同。）

- [ ] **Step 2: 跑测试确认失败**

- [ ] **Step 3: 实现语义层**

```gdscript
static func _validate_semantics(data: Dictionary, findings: Array) -> void:
	_scan_private_refs(data, "$", findings)
	_scan_variable_declarations(data, findings)

static func _scan_private_refs(value: Variant, path: String, findings: Array) -> void:
	if value is String:
		var s: String = value
		if s.contains("::Resource_"):
			findings.append(_finding("E_SCENE_PRIVATE_REF", "error", path,
				"场景私有资源引用离开源场景无意义: %s" % s.substr(0, 80)))
		elif (s.begins_with("res://") or s.begins_with("uid://")) and not s.contains("::"):
			if not ResourceLoader.exists(s):
				findings.append(_finding("E_RESOURCE_NOT_FOUND", "error", path, "资源不存在: %s" % s))
	elif value is Dictionary:
		for k in value:
			_scan_private_refs(value[k], path + "." + str(k), findings)
	elif value is Array:
		for i in value.size():
			_scan_private_refs(value[i], path + "[%d]" % i, findings)

static func _scan_variable_declarations(data: Dictionary, findings: Array) -> void:
	var declared := {}
	var vars: Dictionary = data.get("variables", {})
	for n in vars.get("local", []): declared[n] = true
	for n in vars.get("global", []): declared[n] = true
	for e in vars.get("scope", []):
		if e is Dictionary: declared[e.get("name", "")] = true
	var level := _infer_level(data)
	var inst_arrays: Array = []
	if level in ["L1", "L2", "L3"]:
		inst_arrays.append(data.get("action_runner", {}).get("instructions", []))
	elif level == "L4":
		for b in data.get("event_bindings", []):
			inst_arrays.append(b.get("action_runner", {}).get("instructions", []))
	for arr in inst_arrays:
		_scan_writes(arr, declared, findings)

static func _scan_writes(arr: Array, declared: Dictionary, findings: Array) -> void:
	for i in arr.size():
		var item: Variant = arr[i]
		if not (item is Dictionary) or not item.has("type"): continue
		for key in ["variable_name", "save_to_variable"]:
			var n: Variant = item.get(key, null)
			if n is String and n != "" and not declared.has(n):
				findings.append(_finding("W_VARIABLE_UNDECLARED", "warning",
					"", "变量 '%s' 被写入但未在 variables 中声明" % n))
		for field in _NESTED_FIELDS:
			if item.get(field, null) is Array:
				_scan_writes(item[field], declared, findings)
```

（`W_NODEPATH_UNRESOLVED`：离线无法验证目标存在性，格式层面任何字符串都是合法 NodePath；该 code 保留给未来的节点感知模式，本任务不实现——在 validator 头部注释说明。）

- [ ] **Step 4: 跑测试确认通过**

- [ ] **Step 5: Commit**

```bash
git add addons/fuse/editor/preset_ai/preset_validator.gd addons/fuse/tests/preset_ai/test_preset_validator.gd
git commit -m "feat: 校验器语义层（E_SCENE_PRIVATE_REF/E_RESOURCE_NOT_FOUND/W_VARIABLE_UNDECLARED）"
```

### Task 5: Vector2 表示法裁定实验 + E_REPR_NONCANONICAL

**Files:**
- Modify: `addons/fuse/editor/preset_ai/preset_validator.gd`
- Modify: `addons/fuse/tests/preset_ai/test_preset_validator.gd`

**Interfaces:**
- Produces: code `E_REPR_NONCANONICAL`（引擎值类型参数非字符串形式 → error）；规范形式 = 字符串 `"(x, y)"`（实测确认后写死）

- [ ] **Step 1: 写裁定测试（这是实验，先跑出真相再定断言——分两小步）**

```gdscript
# _ready() 内追加：
	_test_vector2_adjudication()

# 文件尾部追加：
func _test_vector2_adjudication() -> void:
	var forms := {
		"string": "(100.0, 0.0)",
		"array": [100.0, 0.0],
		"dict": {"x": 100.0, "y": 0.0},
	}
	var results := {}
	for form in forms:
		var d := _valid_l1()
		d["action_runner"]["instructions"] = [
			{"type": "TweenMoveTo", "target_node": "..", "target_position": forms[form], "duration": 1.0}]
		var preset := PresetValidator.FusePresetScript.from_json(d)
		var tween: Variant = preset.instructions[0]
		results[form] = str(tween.get("target_position"))
	print("Vector2 裁定结果: ", JSON.stringify(results))
	# 断言（基于 Global Constraints 已核实的运行时事实）：
	_check(results["string"] == "(100, 0)", "字符串形式可转（规范形式）")
	_check(results["array"] == "(0, 0)", "数组形式不可转，属性停留默认值")
	_check(results["dict"] == "(0, 0)", "字典形式不可转，属性停留默认值")
```

- [ ] **Step 2: 跑测试确认三个断言的现状**

Run: `"$GODOT" --headless --path . res://addons/fuse/tests/preset_ai/test_preset_validator.tscn 2>&1 | grep -A2 "裁定"`
Expected: 打印实测结果。**若与断言不符，停下修订本计划与 spec §4.5 的"规范形式"结论后再继续**（断言以实测为准改写）。

- [ ] **Step 3: 把裁定固化为校验规则**

修改 `_check_json_type` 的引擎值类型分支：

```gdscript
		_:
			if tn in _ENGINE_VALUE_TYPES:
				if value is String: return  # 唯一规范形式（Task 5 实测裁定）
				findings.append(_finding("E_REPR_NONCANONICAL", "error", path,
					"引擎值类型参数 %s.%s 必须用字符串形式（如 \"(100.0, 0.0)\"），数组/字典形式无法导入"
					% [type_name, p.get("name", "")]))
				return
			return
```

追加测试：

```gdscript
func _test_repr_noncanonical() -> void:
	var codes := _codes({"type": "TweenMoveTo", "target_node": "..",
		"target_position": [100.0, 0.0], "duration": 1.0})
	_check("E_REPR_NONCANONICAL" in codes, "Vector2 数组形式 → E_REPR_NONCANONICAL")
```

（`_ready()` 追加 `_test_repr_noncanonical()`。）

- [ ] **Step 4: 跑全部测试确认通过**

- [ ] **Step 5: Commit**

```bash
git add addons/fuse/editor/preset_ai/preset_validator.gd addons/fuse/tests/preset_ai/test_preset_validator.gd
git commit -m "feat: Vector2 等引擎值类型裁定为字符串规范形式，数组/字典 → E_REPR_NONCANONICAL"
```

### Task 6: CLI 入口场景 + 真实语料首跑

**Files:**
- Create: `addons/fuse/editor/preset_ai/validate_preset_cli.gd`
- Create: `addons/fuse/editor/preset_ai/validate_preset.tscn`
- Modify: `addons/fuse/editor/preset_ai/preset_validator.gd`（实现 `validate_path` 目录递归 + 报告）

**Interfaces:**
- Produces: CLI 契约（后续文档与 CI 引用）：
  `"$GODOT" --headless --path . res://addons/fuse/editor/preset_ai/validate_preset.tscn -- <file-or-dir> [--report <out.json>]`
  退出码 0 = 无 error；1 = 有 error finding；2 = 参数/IO 错误
  `validate_path` 返回 `{"files": [报告...], "summary": {"total": int, "passed": int, "failed": int}}`

- [ ] **Step 1: 实现 validate_path 目录递归**

```gdscript
static func validate_path(target: String, report_path := "") -> Dictionary:
	var files: Array[String] = []
	if DirAccess.dir_exists_absolute(target):
		_collect_json_files(target, files)
	elif FileAccess.file_exists(target):
		files.append(target)
	else:
		push_error("目标不存在: %s" % target)
		return {"files": [], "summary": {"total": 0, "passed": 0, "failed": 0}}
	var reports: Array = []
	for f in files:
		reports.append(validate_preset(f))
	var failed := reports.filter(func(r): return r.errors > 0).size()
	var summary := {"total": reports.size(), "passed": reports.size() - failed, "failed": failed}
	if report_path != "":
		var out := FileAccess.open(report_path, FileAccess.WRITE)
		if out:
			out.store_string(JSON.stringify({"files": reports, "summary": summary}, "\t"))
			out.close()
	return {"files": reports, "summary": summary}

static func _collect_json_files(dir_path: String, out: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null: return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		var full := dir_path.path_join(name)
		if dir.current_is_dir():
			if not name.begins_with("."):
				_collect_json_files(full, out)
		elif name.ends_with(".json"):
			out.append(full)
		name = dir.get_next()
	dir.list_dir_end()
```

（目录路径传 `res://` 形式；CLI 把用户参数中的相对路径转 `res://` 前缀。）

- [ ] **Step 2: CLI 场景**

`validate_preset_cli.gd`：

```gdscript
# addons/fuse/editor/preset_ai/validate_preset_cli.gd
extends Node

const PresetValidator := preload("res://addons/fuse/editor/preset_ai/preset_validator.gd")

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var target := ""
	var report := ""
	var i := 0
	while i < args.size():
		match args[i]:
			"--report":
				i += 1
				if i < args.size(): report = args[i]
			"--":
				pass
			_:
				if target == "": target = args[i]
		i += 1
	if target == "":
		printerr("用法: validate_preset.tscn -- <file-or-dir> [--report <out.json>]")
		get_tree().quit(2)
		return
	if not target.begins_with("res://"):
		target = "res://" + target.trim_prefix("./")
	var result: Dictionary = PresetValidator.validate_path(target, report)
	for f in result.files:
		var tag := "PASS" if f.errors == 0 else "FAIL"
		print("[%s] %s (errors=%d warnings=%d)" % [tag, f.path, f.errors, f.warnings])
		for fd in f.findings:
			if fd.severity != "info":
				print("    %-24s %-7s %s  %s" % [fd.code, fd.severity, fd.json_path, fd.message])
	print("summary: %s" % JSON.stringify(result.summary))
	if report != "":
		print("report → %s" % report)
	get_tree().quit(1 if result.summary.failed > 0 else 0)
```

`validate_preset.tscn`：

```
[gd_scene load_steps=2 format=3 uid="uidc000000val2"]

[ext_resource type="Script" path="res://addons/fuse/editor/preset_ai/validate_preset_cli.gd" id="1"]

[node name="ValidatePreset" type="Node"]
script = ExtResource("1")
```

- [ ] **Step 3: 真实语料首跑（预期结果见 Global Constraints）**

```bash
"$GODOT" --headless --path . res://addons/fuse/editor/preset_ai/validate_preset.tscn -- res://addons/fuse/presets res://fuse-preset-generator-workspace ; echo "exit=$?"
```

Expected（核对）：
- `red_planet.json` PASS
- `hint_breath.json` FAIL：`E_SCENE_PRIVATE_REF`（stop_condition）
- `game_flow.json` FAIL：多条 `E_ROUNDTRIP_LOSS`
- `spawn_enemy.json` FAIL：`E_ROUNDTRIP_LOSS`
- attack with_skill PASS；attack without_skill FAIL（`E_UNKNOWN_PARAM` ×2）
- patrol with_skill FAIL（`E_REPR_NONCANONICAL` ×2）；patrol without_skill FAIL（`E_UNKNOWN_PARAM` time_scope）
- countdown 两版结果记录下来（写入下一步的提交信息）

任何不符：停下，先调查再继续（可能推翻 spec 假设，须回报）。

- [ ] **Step 4: 产出基线报告文件（供 Task 11 参考，不入库）**

```bash
"$GODOT" --headless --path . res://addons/fuse/editor/preset_ai/validate_preset.tscn -- res://fuse-preset-generator-workspace --report user://iteration1_validation.json
cp $("$GODOT" --headless --doctext 2>/dev/null; echo ~/.local/share/godot/app_userdata/*/user://iteration1_validation.json 2>/dev/null || echo SKIP) /tmp/ 2>/dev/null || true
```

（若 user:// 路径不便取，改用 `--report res://fuse_reports/iteration1_validation.json`，该目录已存在且已入库。）

- [ ] **Step 5: Commit**

```bash
git add addons/fuse/editor/preset_ai/validate_preset_cli.gd addons/fuse/editor/preset_ai/validate_preset.tscn addons/fuse/editor/preset_ai/preset_validator.gd
git commit -m "feat: validate_preset CLI 场景（退出码 0/1/2 + JSON 报告）；首跑真实语料结论见 spec §5.4"
```

### Task 7: 真实样本断言入测试（M1 收尾）

**Files:**
- Modify: `addons/fuse/tests/preset_ai/test_preset_validator.gd`

- [ ] **Step 1: 追加真实样本断言**

```gdscript
# _ready() 内追加：
	_test_real_samples()

# 文件尾部追加：
func _codes_of_file(path: String) -> Array:
	return PresetValidator.validate_preset(path).findings.map(func(f): return f.code)

func _test_real_samples() -> void:
	_check(PresetValidator.validate_preset("res://addons/fuse/presets/gameplay/red_planet.json").errors == 0,
		"red_planet.json 0 error")
	_check("E_SCENE_PRIVATE_REF" in _codes_of_file("res://addons/fuse/presets/ui/hint_breath.json"),
		"hint_breath.json 报 E_SCENE_PRIVATE_REF（M3 重导后本断言翻转，见 Task 14）")
	_check("E_ROUNDTRIP_LOSS" in _codes_of_file("res://addons/fuse/presets/gameplay/game_flow.json"),
		"game_flow.json 报 E_ROUNDTRIP_LOSS（M3 重导后翻转）")
	_check("E_ROUNDTRIP_LOSS" in _codes_of_file("res://addons/fuse/presets/gameplay/spawn_enemy.json"),
		"spawn_enemy.json 报 E_ROUNDTRIP_LOSS（M3 重导后翻转）")
	_check("E_UNKNOWN_PARAM" in _codes_of_file("res://fuse-preset-generator-workspace/iteration-1/attack-l2/without_skill/outputs/attack.json"),
		"attack without_skill 报幻觉参数")
	_check("E_REPR_NONCANONICAL" in _codes_of_file("res://fuse-preset-generator-workspace/iteration-1/patrol-l1/with_skill/outputs/patrol_a_wait_b_wait.json"),
		"patrol with_skill 报 Vector2 数组形式")
```

- [ ] **Step 2: 跑全部测试通过；Step 3: Commit**

```bash
git add addons/fuse/tests/preset_ai/test_preset_validator.gd
git commit -m "test: 真实样本预期断言入测试（M1 收尾）"
```

---

## 里程碑 M2：eval runner + 回归门禁

### Task 8: case 文件 + 断言引擎

**Files:**
- Create: `addons/fuse/editor/preset_ai/eval_runner.gd`
- Create: `fuse-preset-generator-workspace/evals/cases/patrol-sequence-l1.json`、`attack-sequence-l2.json`、`countdown-l2.json`
- Create: `addons/fuse/tests/preset_ai/test_eval_runner.gd` + `.tscn`

**Interfaces:**
- Consumes: `PresetValidator.validate_preset`、`_count_instruction_dicts`（Task 3）
- Produces:
  - `static func load_cases(workspace: String) -> Array[Dictionary]`
  - `static func check_assertions(case_data: Dictionary, preset_data: Dictionary) -> Dictionary` → `{"passed": int, "total": int, "details": Array[String]}`
  - case 文件格式（spec §5.2）

- [ ] **Step 1: 写 3 个 case 文件（断言从 iteration-1 实际产物提取——组件名已核对）**

`fuse-preset-generator-workspace/evals/cases/patrol-sequence-l1.json`：

```json
{
	"name": "patrol-sequence-l1",
	"level": "L1",
	"prompt": "帮我做一个巡逻 preset：移动到点 A (0,0)，等待 2 秒，移动到点 B (100,0)，再等待 2 秒，循环往复",
	"must_include": [
		{"kind": "component", "type": "TweenMoveTo"},
		{"kind": "param", "component": "Wait", "key": "wait_time"}
	],
	"must_not_include": [
		{"kind": "component", "type": "SendEvent"}
	],
	"variables_required": [],
	"outputs": {
		"iteration-1": [
			"patrol-l1/with_skill/outputs/patrol_a_wait_b_wait.json",
			"patrol-l1/without_skill/outputs/patrol.json"
		]
	}
}
```

`attack-sequence-l2.json`：

```json
{
	"name": "attack-sequence-l2",
	"level": "L2",
	"prompt": "按键攻击 preset：按 attack 键时对 ../Target 扣 25 血（scope 变量 hp），播放攻击动画，发送 Hit 事件",
	"must_include": [
		{"kind": "component", "type": "MathOperation"},
		{"kind": "component", "type": "PlayAnimation"},
		{"kind": "component", "type": "SendEvent"},
		{"kind": "event", "type": "OnInputAction"}
	],
	"must_not_include": [],
	"variables_required": [
		{"name": "hp", "scope": "scope"}
	],
	"outputs": {
		"iteration-1": [
			"attack-l2/with_skill/outputs/attack.json",
			"attack-l2/without_skill/outputs/attack.json"
		]
	}
}
```

`countdown-l2.json`：

```json
{
	"name": "countdown-l2",
	"level": "L2",
	"prompt": "3-2-1 倒计时 preset：节点 ready 后每秒依次显示 3、2、1，最后隐藏 UI",
	"must_include": [
		{"kind": "component", "type": "SetUIText"},
		{"kind": "component", "type": "Wait"},
		{"kind": "component", "type": "ShowHideUI"},
		{"kind": "event", "type": "OnReady"}
	],
	"must_not_include": [],
	"variables_required": [],
	"outputs": {
		"iteration-1": [
			"countdown-l2/with_skill/outputs/countdown.json",
			"countdown-l2/without_skill/outputs/countdown.json"
		]
	}
}
```

- [ ] **Step 2: 写失败测试**

`addons/fuse/tests/preset_ai/test_eval_runner.gd`：

```gdscript
# addons/fuse/tests/preset_ai/test_eval_runner.gd
extends Node

const EvalRunner := preload("res://addons/fuse/editor/preset_ai/eval_runner.gd")

var _fail := 0

func _check(cond: bool, msg: String) -> void:
	if cond: print("✓ " + msg)
	else:
		_fail += 1
		push_error("✗ " + msg)

func _ready():
	print("=== test_eval_runner: 断言引擎 ===")
	_test_component_assertion()
	_test_param_assertion()
	_test_event_assertion()
	_test_variable_assertion()
	_test_must_not()
	print("=== 结果: %d 失败 ===" % _fail)
	get_tree().quit(1 if _fail > 0 else 0)

func _preset(insts: Array) -> Dictionary:
	return {"level": "L2", "variables": {"local": [], "scope": [{"name": "hp", "container": "../Target"}], "global": []},
		"action_runner": {"instructions": insts},
		"event": {"type": "OnInputAction", "target_input_action": "attack"}}

func _test_component_assertion() -> void:
	var case := {"must_include": [{"kind": "component", "type": "SendEvent"}], "must_not_include": [], "variables_required": []}
	var r := EvalRunner.check_assertions(case, _preset([{"type": "SendEvent", "event_name": "Hit"}]))
	_check(r.passed == 1 and r.total == 1, "component 断言命中")

func _test_param_assertion() -> void:
	var case := {"must_include": [{"kind": "param", "component": "Wait", "key": "wait_time"}], "must_not_include": [], "variables_required": []}
	var r := EvalRunner.check_assertions(case, _preset([{"type": "Wait", "wait_time": 2.0}]))
	_check(r.passed == 1 and r.total == 1, "param 断言命中")

func _test_event_assertion() -> void:
	var case := {"must_include": [{"kind": "event", "type": "OnReady"}], "must_not_include": [], "variables_required": []}
	var r := EvalRunner.check_assertions(case, _preset([]))
	_check(r.passed == 0 and r.total == 1, "event 断言未命中（实际是 OnInputAction）")

func _test_variable_assertion() -> void:
	var case := {"must_include": [], "must_not_include": [], "variables_required": [{"name": "hp", "scope": "scope"}]}
	var r := EvalRunner.check_assertions(case, _preset([]))
	_check(r.passed == 1 and r.total == 1, "variables_required 断言命中")

func _test_must_not() -> void:
	var case := {"must_include": [], "must_not_include": [{"kind": "component", "type": "SendEvent"}], "variables_required": []}
	var r := EvalRunner.check_assertions(case, _preset([{"type": "SendEvent"}]))
	_check(r.passed == 0 and r.total == 1, "must_not_include 违规被抓住")
```

`.tscn` 同 Task 1 模式（改脚本路径与 uid 尾数 `val3`）。

- [ ] **Step 3: 跑测试确认失败**

- [ ] **Step 4: 实现断言引擎**

`addons/fuse/editor/preset_ai/eval_runner.gd`：

```gdscript
# addons/fuse/editor/preset_ai/eval_runner.gd
@tool
class_name PresetEvalRunner
extends RefCounted

## Eval runner：回放评分 + baseline 门禁（spec §5）

const PresetValidator := preload("res://addons/fuse/editor/preset_ai/preset_validator.gd")
const _NESTED_FIELDS := ["instructions", "true_instructions", "false_instructions", "else_instructions", "loop_instructions"]

static func load_cases(workspace: String) -> Array[Dictionary]:
	var dir_path := workspace.path_join("evals/cases")
	var cases: Array[Dictionary] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_error("eval cases 目录不存在: %s" % dir_path)
		return cases
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name.ends_with(".json"):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir_path.path_join(name)))
			if parsed is Dictionary:
				cases.append(parsed)
		name = dir.get_next()
	dir.list_dir_end()
	cases.sort_custom(func(a, b): return str(a.get("name", "")) < str(b.get("name", "")))
	return cases

static func check_assertions(case_data: Dictionary, preset_data: Dictionary) -> Dictionary:
	var details: Array[String] = []
	var passed := 0
	var total := 0
	for a in case_data.get("must_include", []):
		total += 1
		if _assertion_holds(a, preset_data):
			passed += 1
		else:
			details.append("未满足 must_include: %s" % JSON.stringify(a))
	for a in case_data.get("must_not_include", []):
		total += 1
		if not _assertion_holds(a, preset_data):
			passed += 1
		else:
			details.append("违反 must_not_include: %s" % JSON.stringify(a))
	for v in case_data.get("variables_required", []):
		total += 1
		var scope: String = v.get("scope", "")
		var bucket: Array = preset_data.get("variables", {}).get(scope, [])
		var hit := bucket.any(func(e): return (e if e is String else e.get("name", "")) == v.get("name", ""))
		if hit: passed += 1
		else: details.append("缺少变量声明: %s" % JSON.stringify(v))
	return {"passed": passed, "total": total, "details": details}

static func _assertion_holds(a: Dictionary, preset_data: Dictionary) -> bool:
	match String(a.get("kind", "")):
		"component":
			return _collect_types(_root_arrays(preset_data), []).has(a.get("type", ""))
		"event":
			if preset_data.get("event", {}) is Dictionary:
				if preset_data["event"].get("type", "") == a.get("type", ""): return true
			for b in preset_data.get("event_bindings", []):
				if b.get("event", {}).get("type", "") == a.get("type", ""): return true
			return false
		"param":
			for arr in _root_arrays(preset_data):
				if _has_param(arr, a.get("component", ""), a.get("key", "")): return true
			return false
	return false

static func _root_arrays(preset_data: Dictionary) -> Array:
	var arrays: Array = []
	var ar: Dictionary = preset_data.get("action_runner", {})
	if ar.get("instructions", null) is Array: arrays.append(ar["instructions"])
	for b in preset_data.get("event_bindings", []):
		var bar: Dictionary = b.get("action_runner", {})
		if bar.get("instructions", null) is Array: arrays.append(bar["instructions"])
	return arrays

static func _collect_types(arr: Array, out: Array) -> Array:
	for item in arr:
		if item is Dictionary and item.has("type"):
			out.append(item["type"])
			for field in _NESTED_FIELDS:
				if item.get(field, null) is Array:
					_collect_types(item[field], out)
	return out

static func _has_param(arr: Array, component: String, key: String) -> bool:
	for item in arr:
		if item is Dictionary and item.get("type", "") == component and item.has(key):
			return true
		if item is Dictionary:
			for field in _NESTED_FIELDS:
				if item.get(field, null) is Array and _has_param(item[field], component, key):
					return true
	return false
```

- [ ] **Step 5: 跑测试通过；Step 6: Commit**

```bash
git add addons/fuse/editor/preset_ai/eval_runner.gd addons/fuse/tests/preset_ai/ fuse-preset-generator-workspace/evals/
git commit -m "feat: eval 断言引擎 + 3 个 seed case（断言取自 iteration-1 实际产物）"
```

### Task 9: 回放编排 + 报告生成 + CLI

**Files:**
- Modify: `addons/fuse/editor/preset_ai/eval_runner.gd`
- Create: `addons/fuse/editor/preset_ai/eval_runner_cli.gd` + `eval_runner.tscn`
- Modify: `addons/fuse/tests/preset_ai/test_eval_runner.gd`

**Interfaces:**
- Produces: `static func run_replay(workspace: String, iteration: String, report_dir := "") -> Dictionary` → `{"results": [...], "summary": {...}, "regressions": [...]}`；CLI：`eval_runner.tscn -- --workspace <path> --iteration <name> [--report <dir>] [--live]`

- [ ] **Step 1: 写失败测试（迷你 fixture：1 case + 2 产物，一过一败）**

在 `test_eval_runner.gd` 的 `_ready()` 追加 `_test_replay()`，文件尾部：

```gdscript
const _FIXTURE_CASE := {
	"name": "mini", "level": "L1",
	"must_include": [{"kind": "component", "type": "Print"}],
	"must_not_include": [], "variables_required": [],
	"outputs": {"iter-x": ["mini/good/outputs/a.json", "mini/bad/outputs/b.json"]},
}

func _make_fixture_workspace(root: String) -> void:
	DirAccess.make_dir_recursive_absolute(root + "/evals/cases")
	DirAccess.make_dir_recursive_absolute(root + "/iter-x/mini/good/outputs")
	DirAccess.make_dir_recursive_absolute(root + "/iter-x/mini/bad/outputs")
	var f := FileAccess.open(root + "/evals/cases/mini.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(_FIXTURE_CASE)); f.close()
	f = FileAccess.open(root + "/iter-x/mini/good/outputs/a.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"format_version": "2.0", "level": "L1",
		"action_runner": {"instructions": [{"type": "Print", "message": "hi"}]}})); f.close()
	f = FileAccess.open(root + "/iter-x/mini/bad/outputs/b.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"format_version": "2.0", "level": "L1",
		"action_runner": {"instructions": [{"type": "Nope"}]}})); f.close()

func _test_replay() -> void:
	var root := "res://addons/fuse/tests/preset_ai/fixtures/mini_ws"
	_make_fixture_workspace(root)
	var r: Dictionary = EvalRunner.run_replay(root, "iter-x")
	_check(r.results.size() == 2, "回放产出 2 条结果")
	var good := r.results.filter(func(x): return x.path.contains("good"))
	var bad := r.results.filter(func(x): return x.path.contains("bad"))
	_check(good.size() == 1 and good[0].pass_after_validation if false else good.size() == 1, "fixture 占位")
```

（注意：最后一条断言在实现后改成真实字段：`good[0]["pass"] == true and bad[0]["pass"] == false`——写实现前先把这行写成 `_check(good[0].get("pass", null) == true and bad[0].get("pass", null) == false, "good 过 bad 败")`，`results` 元素字段：`{case, variant, path, errors, warnings, passed, total, pass, details}`。）

- [ ] **Step 2: 跑测试确认失败**

- [ ] **Step 3: 实现编排 + 报告**

`eval_runner.gd` 追加：

```gdscript
static func run_replay(workspace: String, iteration: String, report_dir := "") -> Dictionary:
	var results: Array = []
	for case_data in load_cases(workspace):
		for rel in case_data.get("outputs", {}).get(iteration, []):
			var full := workspace.path_join(iteration).path_join(rel)
			var entry := _evaluate_output(case_data, full, rel)
			results.append(entry)
	var regressions := _check_baseline(workspace, results)
	var summary := {
		"total": results.size(),
		"pass": results.filter(func(x): return x["pass"]).size(),
		"fail": results.filter(func(x): return not x["pass"]).size(),
		"regressions": regressions.size(),
	}
	if report_dir != "":
		_write_reports(report_dir, iteration, results, summary, regressions)
	return {"results": results, "summary": summary, "regressions": regressions}

static func _evaluate_output(case_data: Dictionary, full_path: String, rel_path: String) -> Dictionary:
	var variant := "unknown"
	var parts := rel_path.split("/")
	if parts.size() >= 2: variant = parts[parts.size() - 3]  # <case>/<variant>/outputs/x.json
	var validation: Dictionary = PresetValidator.validate_preset(full_path)
	var assertions := {"passed": 0, "total": 0, "details": []}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(full_path))
	if parsed is Dictionary:
		assertions = check_assertions(case_data, parsed)
	var pass: bool = validation.errors == 0 and assertions.passed == assertions.total and validation.errors != -1
	return {
		"case": case_data.get("name", ""), "variant": variant, "path": rel_path,
		"errors": validation.errors, "warnings": validation.warnings,
		"passed": assertions.passed, "total": assertions.total,
		"pass": pass, "details": assertions.details,
		"findings": validation.findings,
	}

static func _check_baseline(workspace: String, results: Array) -> Array:
	var path := workspace.path_join("eval_baseline.json")
	if not FileAccess.file_exists(path): return []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary): return []
	var regressions: Array = []
	for r in results:
		var expected: Variant = parsed.get(r["case"], {}).get(r["path"], null)
		if expected is Dictionary and expected.get("pass", false) and not r["pass"]:
			regressions.append(r)
	return regressions

static func _write_reports(dir: String, iteration: String, results: Array, summary: Dictionary, regressions: Array) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open(dir.path_join("report.json"), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"iteration": iteration, "results": results,
			"summary": summary, "regressions": regressions}, "\t"))
		f.close()
	var lines: Array[String] = []
	lines.append("# Eval report — %s" % iteration)
	lines.append("")
	lines.append("| case | variant | errors | warnings | assertions | pass |")
	lines.append("|------|---------|--------|----------|------------|------|")
	for r in results:
		lines.append("| %s | %s | %d | %d | %d/%d | %s |" % [r["case"], r["variant"],
			r["errors"], r["warnings"], r["passed"], r["total"], "✅" if r["pass"] else "❌"])
	lines.append("")
	lines.append("regressions: %d" % regressions.size())
	var m := FileAccess.open(dir.path_join("report.md"), FileAccess.WRITE)
	if m:
		m.store_string("\n".join(lines))
		m.close()
```

`eval_runner_cli.gd`：

```gdscript
# addons/fuse/editor/preset_ai/eval_runner_cli.gd
extends Node

const EvalRunner := preload("res://addons/fuse/editor/preset_ai/eval_runner.gd")

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var workspace := ""
	var iteration := ""
	var report := ""
	var live := false
	var i := 0
	while i < args.size():
		match args[i]:
			"--workspace": i += 1; if i < args.size(): workspace = args[i]
			"--iteration": i += 1; if i < args.size(): iteration = args[i]
			"--report": i += 1; if i < args.size(): report = args[i]
			"--live": live = true
		i += 1
	if workspace == "" or iteration == "":
		printerr("用法: eval_runner.tscn -- --workspace <dir> --iteration <name> [--report <dir>] [--live]")
		get_tree().quit(2)
		return
	var result: Dictionary
	if live:
		result = await EvalRunner.run_live(workspace, iteration, report)  # Task 12
	else:
		result = EvalRunner.run_replay(workspace, iteration, report)
	print("summary: %s" % JSON.stringify(result.summary))
	for r in result.regressions:
		printerr("REGRESSION: %s / %s" % [r["case"], r["path"]])
	get_tree().quit(1 if result.summary.regressions > 0 or (result.summary.total > 0 and result.summary.pass == 0 and result.regressions.size() > 0) else 0)
```

（退出码语义：**只有回归（baseline 应过实败）才 1**；产物本来就不过但基线没要求过 → 0，允许「飘红但不回归」的状态存在于早期。）

`eval_runner.tscn` 同模式（uid 尾数 `val4`，root 挂 eval_runner_cli.gd）。

- [ ] **Step 4: 跑测试通过（先按 Step 1 括号内说明修正断言字段）；Step 5: Commit**

```bash
git add addons/fuse/editor/preset_ai/ addons/fuse/tests/preset_ai/
git commit -m "feat: eval 回放编排 + report.json/md + 回归退出码"
```

### Task 10-11: baseline 门禁 + iteration-1 实测录入

**Files:**
- Create: `fuse-preset-generator-workspace/eval_baseline.json`
- Create（运行产出）: `fuse-preset-generator-workspace/iteration-1/report.json`、`report.md`

- [ ] **Step 1: 跑 iteration-1 回放**

```bash
"$GODOT" --headless --path . res://addons/fuse/editor/preset_ai/eval_runner.tscn -- \
  --workspace res://fuse-preset-generator-workspace --iteration iteration-1 \
  --report res://fuse-preset-generator-workspace/iteration-1 ; echo "exit=$?"
```

Expected: exit=0（尚无 baseline）；report.md 与 Task 6 首跑结论一致（attack with ✅ / without ❌、patrol 双 ❌、countdown 实测）。

- [ ] **Step 2: 按实测结果录入 baseline（只录「应过」项）**

`fuse-preset-generator-workspace/eval_baseline.json`（以下为预判内容，**以实测 report 为准**）：

```json
{
	"attack-sequence-l2": {
		"attack-l2/with_skill/outputs/attack.json": {"pass": true}
	},
	"countdown-l2": {
		"countdown-l2/with_skill/outputs/countdown.json": {"pass": true}
	},
	"patrol-sequence-l1": {}
}
```

（countdown/attack 的 with_skill 若实测失败则相应移除；patrol 两版当前都不过，基线留空，待 skill 文档修复 + 新 iteration 后再升。）

- [ ] **Step 3: 验证门禁触发（临时抬高 baseline → 期待 exit=1）**

```bash
python - <<'EOF'
import json
p = "fuse-preset-generator-workspace/eval_baseline.json"
d = json.load(open(p, encoding="utf-8"))
d["patrol-sequence-l1"] = {"patrol-l1/with_skill/outputs/patrol_a_wait_b_wait.json": {"pass": true}}
json.dump(d, open(p, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
EOF
"$GODOT" --headless --path . res://addons/fuse/editor/preset_ai/eval_runner.tscn -- \
  --workspace res://fuse-preset-generator-workspace --iteration iteration-1 ; echo "exit=$?"
# 期待 exit=1 且 stderr 出现 REGRESSION: patrol-sequence-l1
# 然后还原 baseline（去掉 patrol 行）再跑一次确认 exit=0
```

- [ ] **Step 4: 提交（baseline + 报告入库）**

```bash
git add fuse-preset-generator-workspace/eval_baseline.json fuse-preset-generator-workspace/iteration-1/report.json fuse-preset-generator-workspace/iteration-1/report.md
git commit -m "chore: iteration-1 实测基线与首份 eval 报告入库"
```

### Task 12: live 模式（experimental）

**Files:**
- Modify: `addons/fuse/editor/preset_ai/eval_runner.gd`

- [ ] **Step 1: 实现 `run_live`（追加到 eval_runner.gd）**

```gdscript
const _PROMPT_FILES := [
	"res://.claude/skills/fuse-preset-generator/SKILL.md",
	"res://addons/fuse/preset_ai_context/preset_structure_cheatsheet.md",
	"res://addons/fuse/preset_ai_context/skill_workflow_brief.md",
	"res://addons/fuse/preset_ai_context/fuse_components.json",
	"res://addons/fuse/preset_ai_context/fuse_component_schemas.json",
	"res://addons/fuse/preset_ai_context/fuse_enums.json",
]

static func run_live(workspace: String, iteration: String, report_dir := "") -> Dictionary:
	var base := OS.get_environment("FUSE_EVAL_API_BASE")
	var key := OS.get_environment("FUSE_EVAL_API_KEY")
	var model := OS.get_environment("FUSE_EVAL_MODEL")
	if base == "" or key == "" or model == "":
		push_error("live 模式需要 FUSE_EVAL_API_BASE / FUSE_EVAL_API_KEY / FUSE_EVAL_MODEL 环境变量")
		return {"results": [], "summary": {"total": 0, "pass": 0, "fail": 0, "regressions": 0}, "regressions": []}
	var system_prompt := ""
	for p in _PROMPT_FILES:
		system_prompt += FileAccess.get_file_as_string(p) + "\n\n"
	var results: Array = []
	for case_data in load_cases(workspace):
		var http := HTTPRequest.new()
		Engine.get_main_loop().root.add_child(http)
		var body := JSON.stringify({
			"model": model,
			"messages": [
				{"role": "system", "content": system_prompt},
				{"role": "user", "content": str(case_data.get("prompt", ""))},
			],
			"temperature": 0.2,
		})
		var headers := PackedStringArray(["Content-Type: application/json",
			"Authorization: Bearer " + key])
		http.request(base.trim_suffix("/") + "/chat/completions", headers, HTTPClient.METHOD_POST, body)
		var response: Array = await http.request_completed
		http.queue_free()
		var variant_dir := workspace.path_join(iteration).path_join(str(case_data.get("name", ""))).path_join("live/outputs")
		DirAccess.make_dir_recursive_absolute(variant_dir)
		var out_path := variant_dir.path_join(str(case_data.get("name", "")) + ".json")
		var parsed_preset: Variant = null
		if response[1] == 200:
			var resp: Dictionary = JSON.parse_string(response[3].get_string_from_utf8())
			var content := str(resp.get("choices", [{}])[0].get("message", {}).get("content", ""))
			var start := content.find("{")
			var end := content.rfind("}")
			if start >= 0 and end > start:
				parsed_preset = JSON.parse_string(content.substr(start, end - start + 1))
		if parsed_preset is Dictionary:
			var f := FileAccess.open(out_path, FileAccess.WRITE)
			f.store_string(JSON.stringify(parsed_preset, "\t")); f.close()
			results.append(_evaluate_output(case_data, out_path,
				str(case_data.get("name", "")) + "/live/outputs/" + out_path.get_file()))
		else:
			results.append({"case": case_data.get("name", ""), "variant": "live",
				"path": out_path, "errors": -1, "warnings": 0, "passed": 0, "total": 0,
				"pass": false, "details": ["live 生成/解析失败"], "findings": []})
	var summary := {"total": results.size(),
		"pass": results.filter(func(x): return x["pass"]).size(),
		"fail": results.filter(func(x): return not x["pass"]).size(),
		"regressions": 0}
	if report_dir != "":
		_write_reports(report_dir, iteration, results, summary, [])
	return {"results": results, "summary": summary, "regressions": []}
```

（注意：`run_live` 是 `static` + `await`，GDScript 4.x 中 static 函数不能直接 `await self`，但 `await http.request_completed`（信号）在 static 上下文合法；`_evaluate_output` 无 await，安全。若编译器拒绝 static+await 组合，把 `run_live` 改为实例方法并在 CLI 里 `EvalRunner.new()` 调用——保留此 fallback。）

- [ ] **Step 2: 无 key 冒烟测试（期待优雅失败，exit 0 无 crash）**

```bash
"$GODOT" --headless --path . res://addons/fuse/editor/preset_ai/eval_runner.tscn -- \
  --workspace res://fuse-preset-generator-workspace --iteration iteration-live --live --report res://tmp_live ; echo "exit=$?"
```

Expected: `push_error` 提示环境变量缺失，summary total=0，不 crash。（有 key 时真实跑一轮为可选人工验证，不入库。）

- [ ] **Step 3: Commit**

```bash
git add addons/fuse/editor/preset_ai/eval_runner.gd
git commit -m "feat: eval live 模式（OpenAI 兼容端点，experimental，env 配置）"
```

---

## 里程碑 M3：覆盖扩展 + 样例修复

### Task 13: codec 内联序列化修复（场景内嵌资源 → inline dict）

**Files:**
- Modify: `addons/fuse/core/serialization/preset_value_codec.gd`（`_serialize_value`，约 160 行）
- Create: `addons/fuse/tests/preset_ai/test_codec_inline_export.gd` + `.tscn`

- [ ] **Step 1: 写失败测试**

```gdscript
# addons/fuse/tests/preset_ai/test_codec_inline_export.gd
extends Node

const PresetValueCodec := preload("res://addons/fuse/core/serialization/preset_value_codec.gd")
const OnInterval := preload("res://addons/fuse/events/lifecycle/on_interval.gd")
const CheckScopeVariable := preload("res://addons/fuse/conditions/scope/check_scope_variable.gd")

var _fail := 0

func _ready():
	var event := OnInterval.new()
	event.interval_seconds = 1.0
	var cond := CheckScopeVariable.new()
	cond.variable_name = "stopped"
	# 模拟场景内嵌 sub-resource：resource_path 含 ::
	cond.resource_path = "res://demos/fuse/brickian/title_scene.tscn::Resource_fknqa"
	event.stop_condition = cond
	var data := PresetValueCodec.serialize_event(event)
	var ok := data.get("stop_condition", null) is Dictionary and data["stop_condition"].get("type", "") == "CheckScopeVariable"
	if ok:
		print("✓ 场景内嵌 condition 序列化为 inline dict")
	else:
		_fail += 1
		push_error("✗ 期望 inline dict，实际: %s" % str(data.get("stop_condition")))
	# 无 :: 的外部资源仍走路径引用
	var ext := CheckScopeVariable.new()
	ext.resource_path = "res://addons/fuse/presets/conditions/my_cond.tres"
	var data2 := PresetValueCodec.serialize_condition(ext)
	var ok2 := data2 is Dictionary and data2.get("type", "") == "CheckScopeVariable"
	if ok2: print("✓ 外部 .tres condition 仍为完整 dict（顶层恒为 dict，路径引用仅出现在嵌套字段）")
	get_tree().quit(1 if _fail > 0 else 0)
```

（`.tscn` 同模式，uid 尾数 `val5`。）

- [ ] **Step 2: 跑测试确认失败**（stop_condition 输出 `"res://...::Resource_fknqa"` 字符串）

- [ ] **Step 3: 修改 `_serialize_value`（preset_value_codec.gd:160-163）**

```gdscript
	if value is Resource:
		# 场景内嵌 sub-resource（resource_path 含 ::）的引用离开源场景无意义，序列化为 inline dict
		if value.resource_path != "" and not value.resource_path.contains("::"):
			return value.resource_path
		return _serialize_resource(value)
```

- [ ] **Step 4: 跑新测试 + 全部既有测试（回归）**

```bash
"$GODOT" --headless --path . res://addons/fuse/tests/preset_ai/test_codec_inline_export.tscn ; echo exit=$?
"$GODOT" --headless --path . res://addons/fuse/tests/serialization/test_preset_nested_serde.tscn ; echo exit=$?
```

Expected: 双双 0。

- [ ] **Step 5: Commit**

```bash
git add addons/fuse/core/serialization/preset_value_codec.gd addons/fuse/tests/preset_ai/test_codec_inline_export.gd addons/fuse/tests/preset_ai/test_codec_inline_export.tscn
git commit -m "fix: PresetValueCodec 场景内嵌资源序列化为 inline dict（替代无意义的 :: 私有引用）"
```

### Task 14: 样例重导 + 测试翻转

**Files:**
- Create: `addons/fuse/editor/preset_ai/regen_samples.gd` + `regen_samples.tscn`
- Modify: `addons/fuse/presets/gameplay/game_flow.json`、`spawn_enemy.json`、`addons/fuse/presets/ui/hint_breath.json`、`preset_ai_context/sample_presets/` 对应副本
- Modify: `addons/fuse/tests/preset_ai/test_preset_validator.gd`（Task 7 的三条断言翻转）

- [ ] **Step 1: 写重导脚本**

```gdscript
# addons/fuse/editor/preset_ai/regen_samples.gd
extends Node

## 从源场景重导污染样例（M3，spec §6.1）
## 用当前（已修复的）序列化管线替代 2026-07-08 的过期导出产物。

const CASES := [
	{"json": "res://addons/fuse/presets/gameplay/game_flow.json",
	 "scene": "res://demos/fuse/brickian/game_scene.tscn", "node": "GameManager/GameFlow"},
	{"json": "res://addons/fuse/presets/gameplay/spawn_enemy.json",
	 "scene": "res://demos/fuse/brickian/game_scene.tscn", "node": "GameManager/SpawnEnemy"},
	{"json": "res://addons/fuse/presets/ui/hint_breath.json",
	 "scene": "res://demos/fuse/brickian/title_scene.tscn", "node": "Control/TitleHint/HintBreath"},
]

func _ready() -> void:
	for c in CASES:
		_regen(c)
	print("[regen_samples] 完成")
	get_tree().quit(0)

func _regen(c: Dictionary) -> void:
	var old_text := FileAccess.get_file_as_string(c["json"])
	var old: Dictionary = JSON.parse_string(old_text) if old_text != "" else {}
	var scene: PackedScene = load(c["scene"])
	if scene == null:
		push_error("场景加载失败: %s" % c["scene"]); return
	var node := scene.instantiate().get_node_or_null(NodePath(c["node"]))
	if node == null:
		push_error("节点不存在: %s" % c["node"]); return
	var level: String = FusePresetSerializer.detect_level(node)
	if level == "":
		# spawn_enemy 是 L1：从 Runner 的 action_runner 取指令数组
		var ar: Variant = node.get("action_runner") if node.get("action_runner") != null else null
		if ar == null and node.get_child_count() > 0:
			for ch in node.get_children():
				if ch is ActionRunner: ar = ch; break
		if ar == null:
			push_error("无法从 %s 提取指令" % c["node"]); return
		var dummy := FusePreset.new()
		dummy.instructions = ar.instructions
		_write(c["json"], old, dummy)
	else:
		var data: Dictionary = FusePresetSerializer.serialize(node)
		var preset := FusePreset.new()
		preset.level = level
		preset.display_name = old.get("display_name", node.name)
		preset.category = old.get("category", "")
		preset.description = old.get("description", "")
		preset.icon_name = old.get("icon_name", "")
		preset.version = "2.0"
		match level:
			"L1", "L2", "L3":
				var ar_data: Dictionary = data.get("action_runner", {})
				preset.instructions = PresetValueCodec.deserialize_instructions(ar_data.get("instructions", []))
				if level == "L2":
					preset.event_json = data.get("event", {})
					preset.trigger_config = data.get("trigger_config", {})
				elif level == "L3":
					preset.signal_binding = data.get("signal_binding", {})
			"L4":
				preset.trigger_config = data.get("trigger_config", {})
				preset.event_bindings_json = data.get("event_bindings", [])
		preset.variables = old.get("variables", preset.collect_variables())
		_write(c["json"], old, preset)

func _write(json_path: String, old: Dictionary, preset: FusePreset) -> void:
	# 保序字段：display_name 等在构造 preset 时已从 old 继承
	var f := FileAccess.open(json_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(preset.to_json(), "\t"))
	f.close()
	# 同步 sample_presets 副本（若存在）
	var copy := json_path.replace("res://addons/fuse/presets/", "res://addons/fuse/preset_ai_context/sample_presets/")
	if FileAccess.file_exists(copy):
		var fc := FileAccess.open(copy, FileAccess.WRITE)
		fc.store_string(FileAccess.get_file_as_string(json_path))
		fc.close()
	print("[regen] %s" % json_path)
```

（`regen_samples.tscn` 同模式，uid 尾数 `val6`。注意 L1 分支：`FusePreset.to_json()` 对 L1 输出 `action_runner.instructions`，variables 用 `collect_variables()`。）

- [ ] **Step 2: 跑重导 + 校验**

```bash
"$GODOT" --headless --path . res://addons/fuse/editor/preset_ai/regen_samples.tscn
"$GODOT" --headless --path . res://addons/fuse/editor/preset_ai/validate_preset.tscn -- res://addons/fuse/presets res://addons/fuse/preset_ai_context/sample_presets ; echo exit=$?
```

Expected: 4 个样例 + 副本全部 PASS（exit=0）。若 `hint_breath` 的 `variables` 丢失或 `game_flow` 的 binding 字段缺失，检查 `_regen` 的 match 分支并修复。

- [ ] **Step 3: 翻转 Task 7 的三条断言**

`test_preset_validator.gd` 中：
- `hint_breath.json 报 E_SCENE_PRIVATE_REF` → `validate_preset(...).errors == 0, "hint_breath.json 重导后 0 error"`
- `game_flow.json 报 E_ROUNDTRIP_LOSS` → `errors == 0`
- `spawn_enemy.json 报 E_ROUNDTRIP_LOSS` → `errors == 0`
- 工作区产物（attack/patrol iteration-1）断言**保持不变**（历史产物不动）

- [ ] **Step 4: 跑全部测试通过；Step 5: Commit**

```bash
git add addons/fuse/editor/preset_ai/regen_samples.gd addons/fuse/editor/preset_ai/regen_samples.tscn addons/fuse/presets/ addons/fuse/preset_ai_context/sample_presets/ addons/fuse/tests/preset_ai/test_preset_validator.gd
git commit -m "fix: 从源场景重导 3 个过期样例（内嵌 condition 转为 inline dict），校验全绿"
```

### Task 15: cheatsheet + brief 文档更新

**Files:**
- Modify: `addons/fuse/preset_ai_context/preset_structure_cheatsheet.md`
- Modify: `addons/fuse/preset_ai_context/skill_workflow_brief.md`

- [ ] **Step 1: cheatsheet 六处编辑**

1. 第 4 行 `> L3/L4 暂不在 MVP skill 范围内，仅末尾附简要说明。` → `> L1-L4 均在 skill 支持范围内；L3/L4 结构见末尾专节。`
2. 第 126 行类型清单行后新增一行：
   `> **引擎值类型（Vector2/Color 等）唯一规范表示为字符串**，如 "(100.0, 0.0)"。数组 [100.0, 0.0] 与字典 {"x":..} 形式无法导入，校验器报 E_REPR_NONCANONICAL。`
3. 第 166 行 `└─ L3 / L4 不在 MVP skill 范围（见末尾"超出范围"）` → `└─ L3（信号绑定）/ L4（多事件绑定）→ 生成对应结构`
4. 第 278 行整段 `> ⚠️ **条件字段注意**：…` 替换为：
   `> **条件字段写法**：IfThen.condition / IfElse.condition 支持 inline dict —— "condition": {"type": "CheckScopeVariable", …按 fuse_component_schemas.json 中该条件的参数填…}。复合条件的 conditions 数组同法嵌套。禁止输出 ".tscn::Resource_*" 形式的引用字符串（校验器报 E_SCENE_PRIVATE_REF）。`
5. 第 282 行 `## 超出 MVP 范围（L3 / L4）` → `## L3 / L4 结构（skill 支持范围）`，并在表格后补全字段说明：
   - L3：`"signal_binding": {"signal_name": "<信号名>"}`；导入时通过 `__target_node__` 映射挂载信号源节点
   - L4：`"trigger_config": {"use_parallel_condition_evaluation": <bool>}` + `"event_bindings": [{event, binding_config: {enabled, trigger_once, cooldown_mode, cooldown_time}, action_runner, conditions?}]`
   - 示例：`sample_presets/game_flow.json`（重导后为干净 L4 样例）
6. 若文中有 Vector2 示例用数组形式的（搜索 `[0.0, 0.0]`），全部改为字符串形式。

- [ ] **Step 2: brief 四处编辑**

1. 第 14 行 `**MVP 范围**：仅 L1（纯指令序列）和 L2（事件 + 指令）。L3/L4 不在范围内。` → `**支持范围**：L1（指令序列）/ L2（事件触发）/ L3（信号绑定）/ L4（多事件绑定）。`
2. 第 107-108 行两处 `296 组件` → `306 组件`，并在行尾加 `（以 fuse_components.json 实际条目数为准，dump 后同步本文件）`
3. 第 152-153 行表：`"用 L4 多事件触发器..." | 超 MVP 范围 | 告知仅支持 L1/L2` → `"用 L4 多事件触发器..." | 支持 | 按 cheatsheet L4 结构生成`
4. 第 153 行 `condition 字段是 .tscn 内嵌资源引用，AI 无法直接构造` → `condition 用 inline dict 构造（见 cheatsheet 条件字段写法）`

- [ ] **Step 3: Commit**

```bash
git add addons/fuse/preset_ai_context/
git commit -m "docs: cheatsheet/brief 解禁 condition inline dict、纳入 L3/L4、Vector2 字符串规范、296→306"
```

### Task 16: SKILL.md 更新

**Files:**
- Modify: `.claude/skills/fuse-preset-generator/SKILL.md`

- [ ] **Step 1: 六处编辑**

1. 第 3 行 description：`(L1 指令序列 / L2 事件触发器)` → `(L1-L4)`
2. 第 17 行 level 决策补两个分支：`需要挂信号触发 → L3（+ signal_binding）；多事件绑定 → L4（trigger_config + event_bindings）`
3. 第 43 行 L2 说明后追加一行：`**L3** = L1 + "signal_binding": {"signal_name": "..."}；**L4** = "trigger_config" + "event_bindings": [...]（结构见 cheatsheet L3/L4 节）`
4. 第 73 行表 `"用 L4 多事件触发器" | 超 MVP（仅 L1/L2），告知限制` → `"用 L4 多事件触发器" | 按 cheatsheet L4 结构生成`
5. 第 79-83 行 MVP 范围块 → `## 支持范围\n- ✅ L1 / L2 / L3 / L4\n- ⚠️ Vector2 等引擎值类型必须写字符串形式 "(x, y)"，数组形式无法导入\n- ⚠️ IfThen/IfElse 的 condition 用 inline dict 构造（勿输出 .tscn::Resource_* 引用）`
6. 若骨架/反例部分有数组形式 Vector2 示例，改为字符串形式。

- [ ] **Step 2: Commit**

```bash
git add .claude/skills/fuse-preset-generator/SKILL.md
git commit -m "docs: preset-generator skill 扩展至 L1-L4 + Vector2/condition 生成规范"
```

### Task 17: L3/L4 手工样例 + eval case 扩充

**Files:**
- Create: `addons/fuse/preset_ai_context/sample_presets/sample_l3_runner.json`、`sample_l4_multi.json`
- Create: `fuse-preset-generator-workspace/evals/cases/l3-runner-sample.json`、`l4-multi-sample.json`
- Create: `fuse-preset-generator-workspace/iteration-2/handcrafted/outputs/` 下两份副本

- [ ] **Step 1: 写两个样例（先查 Print 参数名：`grep -n "@export" addons/fuse/instructions/debug/print.gd`）**

`sample_l3_runner.json`（以真实 Print 参数名为准，下例假定 `message`）：

```json
{
	"format_version": "2.0",
	"level": "L3",
	"display_name": "SampleL3Runner",
	"category": "gameplay",
	"description": "L3 结构样例：信号触发时打印消息",
	"icon_name": "",
	"variables": {"local": [], "scope": [], "global": []},
	"action_runner": {"execution_mode": 0, "instructions": [{"type": "Print", "message": "runner fired"}]},
	"signal_binding": {"signal_name": "player_died"}
}
```

`sample_l4_multi.json`：

```json
{
	"format_version": "2.0",
	"level": "L4",
	"display_name": "SampleL4Multi",
	"category": "gameplay",
	"description": "L4 结构样例：就绪打印一次 + 每秒打印心跳",
	"icon_name": "",
	"trigger_config": {"use_parallel_condition_evaluation": false},
	"event_bindings": [
		{
			"event": {"type": "OnReady"},
			"binding_config": {"enabled": true, "trigger_once": true, "cooldown_mode": 0, "cooldown_time": 1.0},
			"action_runner": {"execution_mode": 0, "instructions": [{"type": "Print", "message": "ready"}]}
		},
		{
			"event": {"type": "OnInterval", "interval_seconds": 1.0, "trigger_on_start": false, "auto_start": true},
			"binding_config": {"enabled": true, "trigger_once": false, "cooldown_mode": 0, "cooldown_time": 1.0},
			"action_runner": {"execution_mode": 0, "instructions": [{"type": "Print", "message": "tick"}]}
		}
	]
}
```

- [ ] **Step 2: 校验两个样例通过**

```bash
"$GODOT" --headless --path . res://addons/fuse/editor/preset_ai/validate_preset.tscn -- res://addons/fuse/preset_ai_context/sample_presets ; echo exit=$?
```

Expected: exit=0（OnReady/OnInterval/Print 的必填参数以校验器反馈为准补全——warning 可接受，error 必须清零）。

- [ ] **Step 3: 复制到工作区 + 写 2 个 eval case**

```bash
mkdir -p fuse-preset-generator-workspace/iteration-2/handcrafted/outputs
cp addons/fuse/preset_ai_context/sample_presets/sample_l3_runner.json fuse-preset-generator-workspace/iteration-2/handcrafted/outputs/
cp addons/fuse/preset_ai_context/sample_presets/sample_l4_multi.json fuse-preset-generator-workspace/iteration-2/handcrafted/outputs/
```

`evals/cases/l3-runner-sample.json`：

```json
{
	"name": "l3-runner-sample",
	"level": "L3",
	"prompt": "样例：信号 player_died 触发时打印 runner fired（L3 Runner）",
	"must_include": [{"kind": "component", "type": "Print"}],
	"must_not_include": [],
	"variables_required": [],
	"outputs": {"iteration-2": ["handcrafted/outputs/sample_l3_runner.json"]}
}
```

`l4-multi-sample.json`：

```json
{
	"name": "l4-multi-sample",
	"level": "L4",
	"prompt": "样例：就绪打印 ready + 每秒打印 tick（L4 MultiEventTrigger）",
	"must_include": [{"kind": "event", "type": "OnReady"}, {"kind": "event", "type": "OnInterval"}],
	"must_not_include": [],
	"variables_required": [],
	"outputs": {"iteration-2": ["handcrafted/outputs/sample_l4_multi.json"]}
}
```

- [ ] **Step 4: 跑 iteration-2 回放并录入 baseline（两份样例应 pass）**

```bash
"$GODOT" --headless --path . res://addons/fuse/editor/preset_ai/eval_runner.tscn -- \
  --workspace res://fuse-preset-generator-workspace --iteration iteration-2 \
  --report res://fuse-preset-generator-workspace/iteration-2 ; echo exit=$?
```

把两条 pass 写入 `eval_baseline.json` 对应 case。

- [ ] **Step 5: Commit**

```bash
git add addons/fuse/preset_ai_context/sample_presets/ fuse-preset-generator-workspace/
git commit -m "feat: L3/L4 手工样例 + eval case 扩充（闭环覆盖 L1-L4）"
```

### Task 18: 全量回归收尾

**Files:** 无新文件

- [ ] **Step 1: 全量跑**

```bash
"$GODOT" --headless --path . res://addons/fuse/tests/preset_ai/test_preset_validator.tscn ; echo v=$?
"$GODOT" --headless --path . res://addons/fuse/tests/preset_ai/test_eval_runner.tscn ; echo v=$?
"$GODOT" --headless --path . res://addons/fuse/tests/preset_ai/test_codec_inline_export.tscn ; echo v=$?
"$GODOT" --headless --path . res://addons/fuse/tests/serialization/test_preset_nested_serde.tscn ; echo v=$?
"$GODOT" --headless --path . res://addons/fuse/editor/preset_ai/validate_preset.tscn -- res://addons/fuse/presets res://addons/fuse/preset_ai_context/sample_presets ; echo v=$?
"$GODOT" --headless --path . res://addons/fuse/editor/preset_ai/eval_runner.tscn -- --workspace res://fuse-preset-generator-workspace --iteration iteration-1 ; echo v=$?
"$GODOT" --headless --path . res://addons/fuse/editor/preset_ai/eval_runner.tscn -- --workspace res://fuse-preset-generator-workspace --iteration iteration-2 ; echo v=$?
```

Expected: 全部 0。

- [ ] **Step 2: spec 状态行更新**

`addons/fuse/docs/superpowers/specs/2026-08-21-preset-ai-closed-loop-design.md` 头部 `**状态：** 设计已批准，待实现` → `**状态：** 已实现（2026-08-2X），M1-M3 验收达标`。

- [ ] **Step 3: 最终提交**

```bash
git add -A
git commit -m "chore: preset AI 闭环 M1-M3 全量回归通过，收尾"
```

---

## Self-Review 记录

- **Spec 覆盖**：§4 四层校验 → Task 1-5；§4.1 CLI → Task 6；§4.4 报告 → Task 6/9；§4.5 裁定 → Task 5；§5.1-5.2 case → Task 8；§5.3 回放 → Task 9；§5.4 门禁 → Task 10-11；§5.5 live → Task 12；§6.1 codec+重导 → Task 13-14；§6.2-6.3 文档 → Task 15-16；§6.3 L3/L4 样例 → Task 17；§6.4 校验规则 → Task 2/3（L4 字段已含）；§6.5 296→306 → Task 15；§8 测试 → 各任务内嵌；§9 验收 → Task 18。无缺口。
- **占位符**：Task 9 Step 1 的 fixture 断言有一处「先占位后改」的显式说明（改法已给出），Task 17 的 Print 参数名标注「以 grep 为准」——均为对未知量的显式处理指令，非 TBD。
- **类型一致性**：`validate_data/validate_preset/validate_path`、finding 四字段、`run_replay/check_assertions/load_cases`、`_NESTED_FIELDS` 在 Task 2/3/8/9 间签名一致；Task 9 引用 Task 8 的 `check_assertions` 返回 `{passed,total,details}`。
