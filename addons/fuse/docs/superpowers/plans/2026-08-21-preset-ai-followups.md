# Preset AI 闭环跟进项实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 补齐闭环的三块短板——schema dump 覆盖条件注册的动态参数、W_MISSING_PARAM 聚合降噪、attack without_skill 升入 baseline（守护动态属性复核）。

**Architecture:** SchemaExtractor 用 BFS 枚举门探测展开组件状态空间，条件参数附 `requires` 元数据（最小门控赋值路径）；validator 的 W_MISSING_PARAM 变为 requires 感知 + 按组件聚合成单条 finding；`_collect_dynamic_params` 动态复核**不动**（仍是幻觉参数判定的权威）。三项独立可测，按依赖顺序 1→2→3→4→5。

**Tech Stack:** Godot 4.7 headless GDScript；场景式测试 + 退出码；无外部框架。

**Spec:** `addons/fuse/docs/superpowers/specs/2026-08-21-preset-ai-closed-loop-design.md`（母项目，已实现；本计划是其终审跟进项，背景事实见该 spec §2/§4.2 修订记录）

## Global Constraints

- Godot（Git Bash）：`export GODOT="/e/Godot/Godot_v4.7-stable_mono_win64/Godot_v4.7-stable_mono_win64_console.exe"`；跑场景 `"$GODOT" --headless --path . res://<scene>`；类缓存错先 `"$GODOT" --headless --import --path .`。
- 仓库根 `E:\GitHub\fuse`；GDScript 风格：tab 缩进、全类型注解、snake_case、push_error/push_warning（AGENTS.md）。
- 测试场景结尾必须 `get_tree().quit(1 if _fail > 0 else 0)`；`test_preset_nested_serde.tscn` 为旧式无 quit 约定，跑它加 `--quit-after 600`。
- 重 dump 命令（AGENTS.md）：`"$GODOT" --headless --path . res://addons/fuse/editor/preset_ai/dump_context.tscn`；dump 后 `git diff` 核对：**静态参数旧条目字节不得变化**（不得给静态参数加 requires 键），schemas 只增不减。
- 已核实事实（勿再质疑）：
  - 动态属性注册是嵌套门控：`MathOperation.operand_a_variable` 需 `operand_a_source==1`；`operand_a_scope` 需再 `operand_a_scope==1`；`operand_a_custom_scope_id` 需再 `operand_a_scope_source==1`（math_operation.gd:216 起，三层）。
  - 枚举 hint_string 双格式：`"Add:0,Subtract:1"`（带值）与 `"Direct,Variable"`（隐式索引 0 起）——validator 已有同款双格式解析先例。
  - `Wait.time_scope` 在 `value_source==1`（VARIABLE）时注册（wait.gd:134-149）；默认态（DIRECT）只有 wait_time。
  - String+ENUM（如 `OnInputAction.target_input_action`，InputMap 动态建议列表）**不是**门控参数，不得作为探测门。
  - validator 现状锚点：`_load_schemas` 缓存 schemas dict；W_MISSING_PARAM 发射在 `_validate_component` 尾部（preset_validator.gd:386 区域，逐参数一条）；`_collect_dynamic_params(type_name, comp) -> Dictionary`（:278）为幻觉参数权威复核，本计划不改动其逻辑。
  - eval_baseline.json 现有 5 条应过项；attack without_skill 当前实测 pass（errors=0，动态复核后）。
  - countdown 单产物 48-54 条 W_MISSING_PARAM 的构成：7-8 条指令 × 每条缺 6-7 个参数。

---

## 文件结构总览

| 文件 | 职责 |
|------|------|
| `addons/fuse/editor/preset_ai/schema_extractor.gd`（改） | BFS 状态展开 + requires 元数据 |
| `addons/fuse/tests/preset_ai/test_schema_extractor_states.{gd,tscn}`（新） | 提取器状态展开测试 |
| `addons/fuse/editor/preset_ai/preset_validator.gd`（改） | W_MISSING_PARAM requires 感知 + 聚合 |
| `addons/fuse/tests/preset_ai/test_preset_validator.gd`（改） | 上述两行为的测试 |
| `addons/fuse/preset_ai_context/fuse_component_schemas.json`（重 dump） | 含条件参数与 requires |
| `addons/fuse/preset_ai_context/{preset_structure_cheatsheet,skill_workflow_brief}.md`、`.claude/skills/fuse-preset-generator/SKILL.md`（改） | 撤"以源码为准"警示，文档化 requires |
| `fuse-preset-generator-workspace/eval_baseline.json`、`iteration-1/report.{json,md}`（改） | baseline 升级 + 报告刷新 |

---

### Task 1: SchemaExtractor BFS 状态展开

**Files:**
- Modify: `addons/fuse/editor/preset_ai/schema_extractor.gd`（`get_parameter_schema`，:65-99）
- Create: `addons/fuse/tests/preset_ai/test_schema_extractor_states.gd` + `.tscn`

**Interfaces:**
- Produces（Task 2/3 依赖）:
  - `get_parameter_schema(type_name: String) -> Array[Dictionary]` 签名不变；条目新增**可选**字段 `requires: Dictionary`（`{门参数名: 枚举int值}`，仅条件参数携带；静态参数条目不带该键，保持字节不变）
  - 新增内部常量 `_MAX_PROBE_DEPTH := 4`、`_MAX_PROBE_STATES := 128`
  - schemas dump JSON 条目随之携带 `requires`（dict 键序：追加在 `is_nested_instructions` 之后）

- [ ] **Step 1: 写失败测试**

`addons/fuse/tests/preset_ai/test_schema_extractor_states.gd`：

```gdscript
# addons/fuse/tests/preset_ai/test_schema_extractor_states.gd
extends Node

const SchemaExtractor := preload("res://addons/fuse/editor/preset_ai/schema_extractor.gd")

var _fail := 0

func _check(cond: bool, msg: String) -> void:
	if cond: print("✓ " + msg)
	else:
		_fail += 1
		push_error("✗ " + msg)

func _ready():
	print("=== test_schema_extractor_states ===")
	_test_math_operation_nested_gates()
	_test_wait_time_scope()
	_test_sendevent_unchanged()
	_test_unique_names()
	print("=== 结果: %d 失败 ===" % _fail)
	get_tree().quit(1 if _fail > 0 else 0)

func _schema_of(type_name: String) -> Dictionary:
	var by_name := {}
	for p in SchemaExtractor.get_parameter_schema(type_name):
		by_name[p["name"]] = p
	return by_name

func _test_math_operation_nested_gates() -> void:
	var s := _schema_of("MathOperation")
	_check(s.has("operand_a_variable"), "operand_a_variable 已收录")
	if s.has("operand_a_variable"):
		_check(s["operand_a_variable"].get("requires", {}) == {"operand_a_source": 1},
			"operand_a_variable.requires == {operand_a_source: 1}")
	_check(s.has("operand_a_custom_scope_id"), "三层深度的 operand_a_custom_scope_id 已收录")
	if s.has("operand_a_custom_scope_id"):
		_check(s["operand_a_custom_scope_id"].get("requires", {}) ==
			{"operand_a_source": 1, "operand_a_scope": 1, "operand_a_scope_source": 1},
			"operand_a_custom_scope_id.requires 为三层最小门控")
	_check(s.has("operand_a_scope_source"), "operand_a_scope_source 已收录")
	_check(not s["operation_type"].has("requires"), "静态参数 operation_type 无 requires 键")
	_check(not s["operand_a_value"].has("requires"), "默认态即注册的 operand_a_value 无 requires 键")

func _test_wait_time_scope() -> void:
	var s := _schema_of("Wait")
	_check(s.has("time_scope"), "Wait.time_scope 已收录")
	if s.has("time_scope"):
		_check(s["time_scope"].get("requires", {}) == {"value_source": 1},
			"time_scope.requires == {value_source: 1}")
	_check(not s["wait_time"].has("requires"), "wait_time 无 requires（默认态注册）")

func _test_sendevent_unchanged() -> void:
	var params := SchemaExtractor.get_parameter_schema("SendEvent")
	_check(params.size() == 3, "SendEvent 仍为 3 参数（旧条目回归护栏，实际 %d）" % params.size())
	for p in params:
		_check(not p.has("requires"), "SendEvent.%s 无 requires" % p["name"])

func _test_unique_names() -> void:
	var names := []
	for p in SchemaExtractor.get_parameter_schema("MathOperation"):
		names.append(p["name"])
	var uniq := {}
	for n in names: uniq[n] = true
	_check(uniq.size() == names.size(), "参数名无重复（BFS 各状态去重）")
```

`.tscn`（头省略 uid，与既有测试场景同构）：

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://addons/fuse/tests/preset_ai/test_schema_extractor_states.gd" id="1"]

[node name="TestSchemaExtractorStates" type="Node"]
script = ExtResource("1")
```

- [ ] **Step 2: 跑测试确认失败**

Run: `"$GODOT" --headless --path . res://addons/fuse/tests/preset_ai/test_schema_extractor_states.tscn`
Expected: operand_a_variable / operand_a_custom_scope_id / time_scope 相关断言 ✗（当前默认态提取不到）

- [ ] **Step 3: 实现 BFS 状态展开**

替换 `get_parameter_schema` 主体（`_resolve_script` 及其余函数不动）：

```gdscript
const _MAX_PROBE_DEPTH := 4
const _MAX_PROBE_STATES := 128

static func get_parameter_schema(type_name: String) -> Array[Dictionary]:
	var script = _resolve_script(type_name)
	if script == null:
		push_warning("[SchemaExtractor] 未找到组件: %s" % type_name)
		return []

	var inst = script.new()
	# 默认态快照：每个状态探测前先复位，杜绝上一状态的门值泄漏
	var defaults := {}
	for pname in _scan_storable_props(inst):
		defaults[pname] = inst.get(pname)

	var result: Array[Dictionary] = []
	var by_name := {}
	var queue: Array = [{"assigns": {}, "depth": 0}]
	var seen_states := {"": true}
	while not queue.is_empty():
		var state: Dictionary = queue.pop_front()
		_reset_to_defaults(inst, defaults)
		_apply_assignments(inst, state.assigns)
		var props := _scan_storable_props(inst)
		for pname in props:
			if not by_name.has(pname):
				by_name[pname] = true
				var requires := _minimize_requires(inst, defaults, props[pname].get("name", pname), state.assigns)
				result.append(_build_param_entry(inst, props[pname], requires, pname in _NESTED_PROPS))
		if state.depth < _MAX_PROBE_DEPTH:
			for pname in props:
				var prop: Dictionary = props[pname]
				if not _is_enum_gate(prop):
					continue
				for value in _enum_gate_values(prop.get("hint_string", "")):
					if int(defaults.get(pname, prop.get("default", 0))) == value:
						continue  # 默认值态已由空 assigns 覆盖
					var next_assigns: Dictionary = state.assigns.duplicate()
					next_assigns[pname] = value
					var sig := _state_signature(next_assigns)
					if not seen_states.has(sig):
						if seen_states.size() >= _MAX_PROBE_STATES:
							push_warning("[SchemaExtractor] %s 状态数超上限 %d，截断探测" % [type_name, _MAX_PROBE_STATES])
							continue
						seen_states[sig] = true
						queue.append({"assigns": next_assigns, "depth": state.depth + 1})

	if inst is RefCounted == false:
		inst.free()
	return result


## 扫描当前实例的可存储属性（过滤私有/基类），返回 {name: prop_dict}
static func _scan_storable_props(inst: Object) -> Dictionary:
	var props := {}
	for prop in inst.get_property_list():
		var pname: String = prop.get("name", "")
		if pname.begins_with("_"):
			continue
		if not (prop.get("usage", 0) & PROPERTY_USAGE_STORAGE):
			continue
		if pname in _BASE_PROPS:
			continue
		props[pname] = prop
	return props


static func _reset_to_defaults(inst: Object, defaults: Dictionary) -> void:
	for pname in defaults:
		inst.set(pname, defaults[pname])


static func _apply_assignments(inst: Object, assigns: Dictionary) -> void:
	for pname in assigns:
		inst.set(pname, assigns[pname])


## int 枚举门（hint==2）；String+ENUM（InputMap 建议列表等）不是门
static func _is_enum_gate(prop: Dictionary) -> bool:
	return prop.get("type", 0) == TYPE_INT and prop.get("hint", 0) == PROPERTY_HINT_ENUM \
		and _enum_gate_values(prop.get("hint_string", "")).size() >= 2


## 双格式枚举值解析："Add:0,Subtract:1"（显式）与 "Direct,Variable"（隐式索引）
static func _enum_gate_values(hint_string: String) -> Array:
	var values: Array = []
	var implicit := 0
	for pair in hint_string.split(","):
		var kv := pair.split(":")
		if kv.size() == 2:
			values.append(int(kv[1].strip_edges()))
		else:
			values.append(implicit)
		implicit += 1
	return values


static func _state_signature(assigns: Dictionary) -> String:
	var parts: Array[String] = []
	for k in assigns:
		parts.append("%s=%d" % [k, int(assigns[k])])
	parts.sort()
	return ";".join(parts)


## requires 最小化：逐门尝试移除，移除后参数仍注册则该门非必要
static func _minimize_requires(inst: Object, defaults: Dictionary, pname: String, assigns: Dictionary) -> Dictionary:
	if assigns.is_empty():
		return {}
	var requires := assigns.duplicate()
	for gate in assigns:
		var trial := requires.duplicate()
		trial.erase(gate)
		_reset_to_defaults(inst, defaults)
		_apply_assignments(inst, trial)
		if _scan_storable_props(inst).has(pname):
			requires = trial
	_reset_to_defaults(inst, defaults)
	_apply_assignments(inst, assigns)
	return requires


static func _build_param_entry(inst: Object, prop: Dictionary, requires: Dictionary, is_nested: bool) -> Dictionary:
	var ptype: int = prop.get("type", 0)
	var entry := {
		"name": prop.get("name", ""),
		"type": ptype,
		"type_name": _type_to_string(ptype),
		"hint": prop.get("hint", 0),
		"hint_string": prop.get("hint_string", ""),
		"default": inst.get(prop.get("name", "")),
		"is_nested_instructions": is_nested,
	}
	# 仅条件参数携带 requires；静态参数条目保持与旧 dump 字节一致
	if not requires.is_empty():
		entry["requires"] = requires
	return entry
```

注意：`default` 取值发生在该参数注册的那个状态（`inst` 当前即为发现态）——条件参数的 default 是该状态下的脚本初始值。

- [ ] **Step 4: 跑测试确认通过**

Run: 同 Step 2。Expected: 全 ✓，0 失败，退出码 0。

- [ ] **Step 5: Commit**

```bash
git add addons/fuse/editor/preset_ai/schema_extractor.gd addons/fuse/tests/preset_ai/test_schema_extractor_states.gd addons/fuse/tests/preset_ai/test_schema_extractor_states.tscn addons/fuse/tests/preset_ai/test_schema_extractor_states.gd.uid
git commit -m "feat: SchemaExtractor BFS 状态展开——条件注册动态参数入 schema（附 requires 最小门控）"
```

### Task 2: 重 dump + 消费端 requires 感知 + 文档撤警示

**Files:**
- Regenerate: `addons/fuse/preset_ai_context/fuse_component_schemas.json`
- Modify: `addons/fuse/editor/preset_ai/preset_validator.gd`（W_MISSING_PARAM 循环，:386 区域）
- Modify: `addons/fuse/tests/preset_ai/test_preset_validator.gd`
- Modify: `addons/fuse/preset_ai_context/preset_structure_cheatsheet.md:132`、`skill_workflow_brief.md:53`、`.claude/skills/fuse-preset-generator/SKILL.md:19`

**Interfaces:**
- Consumes: Task 1 的 `requires` 字段
- Produces: validator 内 `static func _requirements_met(requires: Dictionary, comp: Dictionary, known: Dictionary) -> bool`（known = 该组件 name→param 映射，Task 3 复用）

- [ ] **Step 1: 重 dump 并核对**

```bash
"$GODOT" --headless --path . res://addons/fuse/editor/preset_ai/dump_context.tscn
git diff --stat addons/fuse/preset_ai_context/
python -c "
import json
s = json.load(open('addons/fuse/preset_ai_context/fuse_component_schemas.json', encoding='utf-8'))
mo = s['MathOperation']
dyn = {p['name']: p.get('requires') for p in mo if 'requires' in p}
print('MathOperation 条件参数:', dyn)
se = s['SendEvent']
print('SendEvent 参数数:', len(se), '| 带 requires 的:', sum(1 for p in se if 'requires' in p))
"
```

Expected: `fuse_components.json`/`fuse_enums.json` **零 diff**（内容未变）；schemas diff 只增不减；`operand_a_variable` 带 requires；SendEvent 3 参数 0 requires。若 components/enums 出现无关 diff，停下调查（JSON 键序/空格），不得带病提交。

- [ ] **Step 2: 写失败测试（requires 感知的 W_MISSING_PARAM）**

在 `test_preset_validator.gd` 追加（`_ready()` 注册 `_test_missing_param_requires_aware()`）：

```gdscript
func _test_missing_param_requires_aware() -> void:
	# operand_a_source=1（VARIABLE）时：operand_a_scope_source 应报缺；operand_a_value（需 source=0）不应报缺
	var inst := {"type": "MathOperation", "operation_type": 1, "operand_a_source": 1,
		"operand_a_variable": "hp", "operand_a_scope": 1}
	var findings := PresetValidator.validate_data(_l1_with(inst)).findings
	var missing := findings.filter(func(f): return f.code == "W_MISSING_PARAM")
	var names := []
	for f in missing:
		names.append(str(f.message))
	_check(missing.size() >= 1, "仍报缺参（operand_a_scope_source 等）")
	_check(not names.any(func(m): return m.contains("operand_a_value")),
		"门控未满足的 operand_a_value 不报缺")

# _ready() 内追加注册行：
	_test_missing_param_requires_aware()
```

- [ ] **Step 3: 跑测试确认失败**（当前无条件感知，operand_a_value 会进 missing 列表）

- [ ] **Step 4: 实现 requires 感知**

`_validate_component` 的缺参循环改为（找到现有 `W_MISSING_PARAM` 发射处替换）：

```gdscript
	var missing: Array[String] = []
	for p in params:
		var pname: String = p["name"]
		if comp.has(pname):
			continue
		if p.has("requires") and not _requirements_met(p["requires"], comp, known):
			continue  # 该状态下本就不注册，缺是正常的
		missing.append(pname)
```

（W_MISSING_PARAM 的发射方式本任务暂保持逐参数一条——Task 3 改聚合；本步只改变"哪些参数进 missing"。）

新增：

```gdscript
## 条件参数的门控判定：requires 的每个门在 comp 实际值（缺省回退 schema 默认）下满足
static func _requirements_met(requires: Dictionary, comp: Dictionary, known: Dictionary) -> bool:
	for gate in requires:
		var actual: Variant = comp.get(gate, null)
		if actual == null and known.has(gate):
			actual = known[gate].get("default", null)
		if actual == null:
			return false
		if actual is float and actual == floor(actual):
			actual = int(actual)
		if int(actual) != int(requires[gate]):
			return false
	return true
```

- [ ] **Step 5: 跑全部测试确认通过**（`test_preset_validator` 53+1 项 + `test_schema_extractor_states` + `test_eval_runner` + CLI 样例 10/10——schemas 重 dump 后 `_load_schemas` 读到新 JSON，全套回归必须绿）

- [ ] **Step 6: 文档撤警示（三处 + 字段表）**

1. cheatsheet:132 整行替换为：
   `> 参数清单以 schemas JSON 为准（含条件注册的动态参数，其 \`requires\` 字段标注生效门控，如 \`operand_a_variable\` 需 \`operand_a_source: 1\`）。门控不满足时不要写该参数。`
2. cheatsheet 参数字段说明表（:124-129 区域）在 `is_nested_instructions` 行后追加：
   `| \`requires\` | （仅条件参数）生效门控 {参数名: 枚举值}，如 \`{"operand_a_source": 1}\` |`
3. brief:53 括注替换为：`（schemas 已含条件注册的动态参数，requires 字段标注生效条件）`
4. SKILL.md:19 括号说明替换为：`（含条件动态参数，requires 标注生效门控；门控不满足时勿写该参数）`

grep 验证：`以组件源码为准\|未收录进 schema` 三文件零命中。

- [ ] **Step 7: Commit**

```bash
git add addons/fuse/preset_ai_context/ addons/fuse/editor/preset_ai/preset_validator.gd addons/fuse/tests/preset_ai/test_preset_validator.gd
git commit -m "feat: 重 dump 含条件参数 + W_MISSING_PARAM requires 感知 + 文档撤源码警示"
```

### Task 3: W_MISSING_PARAM 按组件聚合

**Files:**
- Modify: `addons/fuse/editor/preset_ai/preset_validator.gd`（Task 2 的 missing 循环尾部）
- Modify: `addons/fuse/tests/preset_ai/test_preset_validator.gd`
- Modify（运行产出）: `fuse-preset-generator-workspace/iteration-1/report.json`、`report.md`

**Interfaces:**
- Consumes: Task 2 的 `missing: Array[String]` 与 `_requirements_met`
- Produces: W_MISSING_PARAM 每组件**一条** finding，message 格式 `"缺少 %d 个参数（将用默认值）：<p1>、<p2>、..."`

- [ ] **Step 1: 写失败测试（追加）**

```gdscript
func _test_missing_param_aggregated() -> void:
	var findings := PresetValidator.validate_data(_l1_with({"type": "Wait"})).findings
	var w := findings.filter(func(f): return f.code == "W_MISSING_PARAM")
	_check(w.size() == 1, "缺参聚合为单条 finding（实际 %d）" % w.size())
	if w.size() == 1:
		_check(str(w[0].message).contains("、") and str(w[0].message).begins_with("缺少"),
			"聚合 message 列出参数名")

# _ready() 内追加注册行：
	_test_missing_param_aggregated()
```

- [ ] **Step 2: 跑测试确认失败**（当前逐参数多条）

- [ ] **Step 3: 实现聚合**

Task 2 的 missing 循环后，把逐参数发射替换为：

```gdscript
	if not missing.is_empty():
		findings.append(_finding("W_MISSING_PARAM", "warning", path,
			"缺少 %d 个参数（将用默认值）：%s" % [missing.size(), "、".join(missing)]))
```

同时核对既有 `_test_missing_param_warning`（断言 `has_w and r.errors == 0`——聚合后仍有单条 W_MISSING_PARAM，应继续通过；若其断言了条数需同步）。

- [ ] **Step 4: 跑全部测试 + 刷新 iteration-1 报告**

```bash
"$GODOT" --headless --path . res://addons/fuse/tests/preset_ai/test_preset_validator.tscn
"$GODOT" --headless --path . res://addons/fuse/editor/preset_ai/eval_runner.tscn -- \
  --workspace res://fuse-preset-generator-workspace --iteration iteration-1 \
  --report res://fuse-preset-generator-workspace/iteration-1
python -c "
import json
r = json.load(open('fuse-preset-generator-workspace/iteration-1/report.json', encoding='utf-8'))
for x in r['results']: print(x['path'], 'warnings:', x['warnings'])
"
```

Expected: countdown 产物 warnings 从 48-54 降到 ≈7-8（每指令一条）；patrol/attack 亦按比例下降；`regressions: 0`，退出码 0。

- [ ] **Step 5: Commit**

```bash
git add addons/fuse/editor/preset_ai/preset_validator.gd addons/fuse/tests/preset_ai/test_preset_validator.gd fuse-preset-generator-workspace/iteration-1/report.json fuse-preset-generator-workspace/iteration-1/report.md
git commit -m "feat: W_MISSING_PARAM 按组件聚合，countdown 警告 48→7 量级"
```

### Task 4: attack without_skill 升入 baseline

**Files:**
- Modify: `fuse-preset-generator-workspace/eval_baseline.json`

- [ ] **Step 1: 录入并验证**

`attack-sequence-l2` 条目增加：

```json
		"attack-l2/without_skill/outputs/attack.json": {
			"pass": true
		}
```

（保持文件字母序与既有缩进风格：tab、UTF-8 无 BOM。）

```bash
"$GODOT" --headless --path . res://addons/fuse/editor/preset_ai/eval_runner.tscn -- \
  --workspace res://fuse-preset-generator-workspace --iteration iteration-1 ; echo exit=$?
```

Expected: `regressions: 0`，exit=0——attack without_skill 实测 pass（errors=0），基线升级后无回归。此条基线的意义：动态属性复核逻辑若回归（attack without 重新误报幻觉参数），门禁立即 exit 1。

- [ ] **Step 2: Commit**

```bash
git add fuse-preset-generator-workspace/eval_baseline.json
git commit -m "chore: attack without_skill 升入 baseline（守护动态属性复核不回归）"
```

### Task 5: 全量回归收尾

**Files:** 无新文件

- [ ] **Step 1: 全量清单（8 项全 0）**

```bash
export GODOT="/e/Godot/Godot_v4.7-stable_mono_win64/Godot_v4.7-stable_mono_win64_console.exe"
P=res://addons/fuse
"$GODOT" --headless --path . $P/tests/preset_ai/test_preset_validator.tscn; echo v=$?
"$GODOT" --headless --path . $P/tests/preset_ai/test_eval_runner.tscn; echo v=$?
"$GODOT" --headless --path . $P/tests/preset_ai/test_codec_inline_export.tscn; echo v=$?
"$GODOT" --headless --path . $P/tests/preset_ai/test_schema_extractor_states.tscn; echo v=$?
"$GODOT" --headless --path . --quit-after 600 $P/tests/serialization/test_preset_nested_serde.tscn >/dev/null 2>&1; echo v=$?
"$GODOT" --headless --path . $P/editor/preset_ai/validate_preset.tscn -- res://addons/fuse/presets res://addons/fuse/preset_ai_context/sample_presets >/dev/null 2>&1; echo v=$?
"$GODOT" --headless --path . $P/editor/preset_ai/eval_runner.tscn -- --workspace res://fuse-preset-generator-workspace --iteration iteration-1 >/dev/null 2>&1; echo v=$?
"$GODOT" --headless --path . $P/editor/preset_ai/eval_runner.tscn -- --workspace res://fuse-preset-generator-workspace --iteration iteration-2 >/dev/null 2>&1; echo v=$?
```

任何非 0 → 停下调查，不修不提交。

- [ ] **Step 2: schemas diff 终核**

```bash
git diff master -- addons/fuse/preset_ai_context/fuse_components.json addons/fuse/preset_ai_context/fuse_enums.json | wc -l   # 应为 0
git diff master --stat addons/fuse/preset_ai_context/fuse_component_schemas.json
```

- [ ] **Step 3: Commit（如有零散收尾）+ 汇报**

```bash
git add -A && git commit -m "chore: 跟进项三件套全量回归通过" || echo "无收尾改动"
```

---

## Self-Review 记录

- **覆盖核查**：跟进项 1（SchemaExtractor 状态展开）→ Task 1+2；跟进项 2（W_MISSING_PARAM 信噪比：requires 感知防误报 + 聚合降噪）→ Task 2+3；跟进项 3（attack without_skill 升 baseline）→ Task 4；回归 → Task 5。无缺口。
- **占位符扫描**：所有代码步骤含完整代码；文档编辑给出逐字替换文案；无 TBD。
- **类型一致性**：`requires: Dictionary`（{String: int}）在 Task 1 产出、Task 2 `_requirements_met(requires: Dictionary, comp: Dictionary, known: Dictionary) -> bool` 消费、Task 3 复用 missing 数组——签名一致。`_scan_storable_props/_reset_to_defaults/_apply_assignments/_is_enum_gate/_enum_gate_values/_state_signature/_minimize_requires/_build_param_entry` 全部在 Task 1 定义。
- **风险预埋**：Task 1 的状态泄漏问题（实例复用）已用 defaults 复位解决；String+ENUM 误当门控已用 `_is_enum_gate` 排除；重 dump 的旧条目字节稳定性有 SendEvent 护栏测试 + Task 2/5 双重 git diff 核对。
