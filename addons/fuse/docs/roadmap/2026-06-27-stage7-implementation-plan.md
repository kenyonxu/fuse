# Stage 7 执行计划 — 变量监视器 V2 + 静态声明融合

**创建日期:** 2026-06-27
**关联:** [可行性报告](2026-06-26-gdscript-ast-flow-integration-feasibility.md) · [Stage 6.5 执行计划](2026-06-26-stage6.5-implementation-plan.md) · [主 roadmap Stage 7](2026-06-16-fuse-development-roadmap.md)
**目标读者:** 执行方（按本计划实施）/ 审查者（Kai）
**预估工时:** 2-3 天（7a 0.5 + 7b 1 + 7c 0.5 + 7d 0.5）

---

## 0. 目标与边界

**目标:** 变量监视器 V1 升级 —— 运行时编辑变量值（7a）、数值变量历史折线图（7b）、注入指令链静态变量声明（7c）、补全快照接口为 Stage 8 录播铺路（7d）。

**Stage 6.5 关键影响:** 原计划 7c「静态声明注入」数据源是组件自描述（codegen 生成）。Stage 6.5 转方案 B（反射+命名启发式）后，**静态声明数据源改为 InstructionAnalyzer.analyze_trigger 的反射结果**（report.variables，含 name/source_prop/mode）。本计划据此调整。

**本轮范围:**
- ✅ 7a 双击编辑变量值（global 可写，local/scope 需 Runner 运行中）
- ✅ 7b 数值变量 60s 历史折线图
- ✅ 7c 指令链静态变量声明注入（InstructionAnalyzer 数据源）
- ✅ 7d get_snapshot() 补全 local/scope/runner

**本轮不做:**
- ❌ BaseEvent/BaseCondition 的节点引用覆盖评估（roadmap 待评估项，单独任务，见 §9）
- ❌ 折线图的高级功能（多变量叠加、导出 CSV）—— V1 只单变量 60s
- ❌ 变量监视器 UI 重构（保持现有 PanelContainer 三色列布局）

---

## 1. 任务分解

| 任务 | 内容 | 工时 | 依赖 |
|---|---|:--:|---|
| 7a | 双击编辑变量值 + LineEdit | 0.5 天 | V1 |
| 7b | 数值变量 60s 历史折线图 | 1 天 | 7a（共享行交互） |
| 7c | 指令链静态变量声明注入 | 0.5 天 | Stage 6.5（InstructionAnalyzer） |
| 7d | get_snapshot() 补全 | 0.5 天 | V1 |

---

## 2. 任务 7a — 双击编辑变量值

### 2.1 现状

[variable_watcher.gd:191 `_make_data_row`](../../editor/debugging/variable_watcher.gd#L191)：值列是 `Label`（只读）。变量监视器只能看不能改。

### 2.2 改造

值列 `Label` 改为**双击进入编辑**（`gui_input` 检测双击 → 替换为 `LineEdit`），回车提交：

```gdscript
func _make_data_row(data: Dictionary) -> HBoxContainer:
	# ... name 列同前 ...
	var val_panel := _make_value_panel(data)  # 双击可编辑
	# ... type 列同前 ...

func _make_value_panel(data: Dictionary) -> PanelContainer:
	var p := _make_label_panel(data["value"], COL_VALUE)  # 默认 Label
	p.gui_input.connect(func(ev): _on_value_gui_input(ev, p, data))
	return p

func _on_value_gui_input(ev: InputEvent, panel: PanelContainer, data: Dictionary) -> void:
	if ev is InputEventMouseButton and ev.double_click:
		_enter_edit_mode(panel, data)

func _enter_edit_mode(panel: PanelContainer, data: Dictionary) -> void:
	# Label → LineEdit，预填当前值
	var line := LineEdit.new()
	line.text = data["value"]
	panel.get_child(0).queue_free()  # 移除 Label
	panel.add_child(line)
	line.text_submitted.connect(func(new_text): _on_value_submitted(new_text, data, panel, line))
	line.text_submitted.connect(line.queue_free)  # 提交后恢复 Label
	line.grab_focus()
```

### 2.3 写回逻辑（按来源分派）

```gdscript
func _on_value_submitted(new_text: String, data: Dictionary, panel, line) -> void:
	var coerced = _coerce_value(new_text, data["type"])  # String → 类型
	if data.get("scope") == "global":
		GlobalVariableService.new().set_variable_value(data["name"], coerced)
	elif data.has("context"):  # local/scope 运行时
		data["context"].set_variable(data["name"], coerced)  # 需 Runner context
	# 下次 _refresh 自然刷新显示
```

### 2.4 类型转换 `_coerce_value`

按 `data["type"]`（type_string 结果，如 "int"/"float"/"bool"/"String"）转换：
- int/float → `int(text)` / `float(text)`
- bool → text in ["true","1","是"] → true
- String → 原样
- 转换失败 → push_warning + 不写回

### 2.5 限制（诚实说明）

- **global** 可编辑写回（GlobalVariableService 随时可用）
- **local/scope** 仅 Runner 运行中（有 context）可写回；编辑模式无 context → 显示但禁用编辑（或提示"场景运行后可编辑"）
- Vector2/Color 等复合类型 V1 不支持编辑（只标量）

### 2.6 验收

- 双击 global 变量值 → LineEdit → 改值回车 → 值更新（GlobalVariableService 写回）
- 场景运行中双击 local 变量 → 可改
- 类型转换正确（int 不接受非数字）

---

## 3. 任务 7b — 数值变量 60s 历史折线图

### 3.1 历史记录

每 0.5s（`_refresh` 时）为每个数值变量追加当前值，保留最近 120 点（60s）：

```gdscript
const HISTORY_MAX := 120  # 60s / 0.5s
var _history: Dictionary = {}  # var_key (scope+name) → Array[float]

func _record_history(scope: String, name: String, value, type_str: String) -> void:
	if type_str not in ["int", "float"]:  # 只数值变量
		return
	var key := "%s/%s" % [scope, name]
	if not _history.has(key):
		_history[key] = []
	_history[key].append(float(value))
	if _history[key].size() > HISTORY_MAX:
		_history[key].pop_front()
```

`_refresh` 收集变量时调 `_record_history`（global + 运行时 local/scope）。

### 3.2 折线图渲染

选中一个数值变量行 → 底部显示该变量折线图（自定义 `_draw`）：

```gdscript
class HistoryGraph extends Control:
	var points: Array[float] = []
	func _draw() -> void:
		if points.size() < 2: return
		var max_v := points.max(); var min_v := points.min()
		var range_v := max(0.001, max_v - min_v)
		var w := size.x; var h := size.y
		var prev := Vector2.ZERO
		for i in points.size():
			var x := w * i / float(points.size() - 1)
			var y := h - h * (points[i] - min_v) / range_v
			if i > 0:
				draw_line(prev, Vector2(x, y), Color(0.4, 0.8, 1.0), 1.5)
			prev = Vector2(x, y)
```

### 3.3 交互

- 数值变量行**可选中**（点击 → 高亮 + 底部折线图区显示该变量 60s 曲线）
- 非数值变量行选中 → 折线图区显示"(无数值历史)"
- 折线图区放监视器底部（_content 下方），高度 ~80px

### 3.4 验收

- 运行场景，数值变量（如 global "score"）随时间变化 → 选中 → 看到折线
- 折线含最近 60s（120 点），超出截断
- 切换选中变量 → 折线更新

### 3.5 内存/性能

- 120 点 × N 变量（float）—— N=50 约 24KB，可忽略
- _draw 只画选中变量 1 条线，开销低

---

## 4. 任务 7c — 指令链静态变量声明注入

### 4.1 动机（B 方案调整）

V1 只显示**运行时**变量（Runner context 的 local/scope + global）。但场景未运行时，local/scope 为空，监视器信息匮乏。

7c 注入**静态声明**：InstructionAnalyzer 分析场景 Trigger 指令链引用的变量（反射+命名启发式，Stage 6.5 成果），即使变量未运行也显示"指令链引用了哪些变量 + read/write 模式"。

### 4.2 数据源

[InstructionAnalyzer.build_topology(scene_root)](../../editor/analysis/instruction_analyzer.gd) → 遍历所有 Trigger → analyze_trigger → report.variables：

```
report.variables = {
  local: [{name, source_prop, mode}, ...],   # mode: write/read/read_write
  scope: [{name, source_prop, mode, source?, scope_id?}, ...],
  global: [{name, source_prop, mode}, ...]
}
```

汇总所有 Trigger 的 report.variables → 得到"场景指令链引用的变量全集"（静态声明）。

### 4.3 改造

`_refresh()` 编辑器模式下，调 build_topology 拿静态声明，渲染新分区「指令引用」：

```gdscript
func _refresh() -> void:
	# ... V1 运行时变量收集（local/scope/global）...
	
	# 7c: 静态声明（指令链引用）
	var static_rows: Array[Dictionary] = []
	if Engine.is_editor_hint():
		var ei = Engine.get_singleton("EditorInterface") if ClassDB.class_exists("EditorInterface") else null
		if ei and ei.get_edited_scene_root():
			var topology = InstructionAnalyzer.build_topology(ei.get_edited_scene_root())
			static_rows = _collect_static_var_rows(topology)  # 汇总所有 trigger 的 variables
	
	# 渲染分区
	_render_section(_content, "Local", local_rows, filter, runner_count > 0)
	_render_section(_content, "Scope", scope_rows, filter, false)
	_render_section(_content, "Global", global_rows, filter, false)
	_render_section(_content, "指令引用(静态)", static_rows, filter, false)  # 新分区
```

### 4.4 静态行数据

`_collect_static_var_rows` 汇总 + 去重（同名变量合并，标注被哪些 Trigger 引用 + mode）：

```gdscript
func _collect_static_var_rows(topology: Dictionary) -> Array[Dictionary]:
	var by_name: Dictionary = {}  # name → {scopes: {}, triggers: [], modes: {}}
	for trigger_report in topology.triggers:
		var tname: String = trigger_report.trigger_name
		for scope in ["local", "scope", "global"]:
			for entry in trigger_report.variables[scope]:
				var vname: String = entry.name
				if not by_name.has(vname):
					by_name[vname] = {"scopes": {}, "triggers": [], "modes": {}}
				by_name[vname].scopes[scope] = true
				by_name[vname].triggers.append(tname)
				by_name[vname].modes[entry.get("mode", "rw")] = true
	# 转 row
	var rows: Array[Dictionary] = []
	for vname in by_name:
		var info = by_name[vname]
		var scopes := ", ".join(info.scopes.keys())
		var modes := "/".join(info.modes.keys())  # 如 "write/read"
		rows.append({
			"name": vname,
			"value": "(静态)",  # 无运行时值
			"type": "%s · %s · %d处" % [scopes, modes, info.triggers.size()]
		})
	return rows
```

### 4.5 与运行时变量的关系

静态声明分区**独立显示**（不合并到 local/scope/global），让用户对比：
- 运行时有 + 静态有 = 正常运行的变量
- 静态有 + 运行时无 = 指令引用了但未运行/未创建
- 运行时有 + 静态无 = 动态创建的变量（非指令链引用）

### 4.6 验收

- 编辑模式（未运行）下，监视器显示「指令引用(静态)」分区，列出场景 Trigger 指令链引用的变量
- 每行显示：变量名 + scope(local/scope/global) + mode(read/write) + 引用处数量
- 含 SetIntVariable 的场景 → 静态声明含 target_variable 引用的变量名（如 "health"）

---

## 5. 任务 7d — get_snapshot() 补全

### 5.1 现状

[variable_watcher.gd:234 `get_snapshot`](../../editor/debugging/variable_watcher.gd#L234)：
```
{timestamp, runners: [], global: {...}}  # runners 永空，缺 local/scope
```
Pre-mortem #4 担忧的"录播缺序列化层" —— 接口已开但数据未填。

### 5.2 补全

复用 `_refresh` 的 Runner 扫描逻辑，填 runners/local/scope：

```gdscript
func get_snapshot() -> Dictionary:
	var result := {
		"timestamp": Time.get_ticks_msec() / 1000.0,
		"runners": [],   # [{runner_name, local:{name:val}, scope:{name:val}}]
		"global": {}
	}
	# global
	result["global"] = GlobalVariableService.new().get_all_global_variables_info()
	# runners + local/scope（复用 _refresh 的扫描）
	if Engine.is_editor_hint():
		var ei = Engine.get_singleton("EditorInterface") if ClassDB.class_exists("EditorInterface") else null
		if ei and ei.get_edited_scene_root():
			for runner in ei.get_edited_scene_root().find_children("*", "Runner"):
				var ec = runner.get("current_execution_context")
				if ec == null or not is_instance_valid(ec):
					continue
				var vc = ec.get("_variable_context")
				if vc == null:
					continue
				result.runners.append({
					"runner_name": runner.name,
					"local": vc.get_all_local_variables_snapshot(),
					"scope": vc.get_all_scope_variables_snapshot()
				})
	return result
```

### 5.3 重构建议

`_refresh` 和 `get_snapshot` 都扫 Runner context。抽公共方法 `_collect_runtime_variables()` 返回 `{local, scope, runners_count}`，两者复用，避免逻辑重复。

### 5.4 验收

- `get_snapshot()` 返回含 runners 数组（每个 Runner 的 local/scope）
- JSON 序列化完整（_on_snapshot 存的文件含 local/scope/runner）
- 为 Stage 8 录播提供可重放的变量快照

---

## 6. 端到端验收标准（Stage 7 完成判定）

1. **双击编辑**（7a）：global 变量双击改值生效；运行中 local 变量可改；类型校验
2. **折线图**（7b）：选中数值变量显示 60s 折线；切换变量更新
3. **静态声明**（7c）：编辑模式下「指令引用(静态)」分区显示指令链引用的变量 + mode + 引用处
4. **快照完整**（7d）：get_snapshot() 含 runners/local/scope/global，JSON 可序列化
5. **回归**：V1 功能（0.5s 轮询、三色列、搜索过滤）不破坏
6. **零 SCRIPT ERROR**：编译通过

---

## 7. 风险与回滚

| 风险 | 应对 |
|---|---|
| 7a local/scope 编辑依赖运行时 context，编辑模式不可用 | 标量 global 必可编辑；local/scope 标"运行时可编辑"，不强求编辑模式 |
| 7b 折线图自定义 _draw 性能 | 只画选中变量 1 条线；历史限 120 点 |
| 7c 静态声明变量名和运行时重名显示混乱 | 独立分区（不合并），靠 scope/mode 标记区分 |
| 7c build_topology 性能（扫所有 Trigger） | 0.5s 轮询调 build_topology 可能重；可加缓存（场景未变则复用） |
| 7d Runner context API 变动 | _collect_runtime_variables 抽象层隔离 |

**回滚**：各任务独立（7a 改 _make_data_row、7b 加 HistoryGraph、7c 加静态分区、7d 改 get_snapshot），可单独 revert。

---

## 8. 执行顺序建议

```
Day 1 上午：7a 双击编辑（global 先通，local/scope 运行时验证）
Day 1 下午：7b 历史记录 + 折线图（HistoryGraph _draw）
Day 2 上午：7c 静态声明注入（build_topology + 静态分区）
Day 2 下午：7d get_snapshot 补全 + 抽 _collect_runtime_variables + 端到端验收
```

**关键检查点（建议 Kai 审查）：**
- 7a 后：global 双击编辑体验
- 7c 后：静态声明分区是否准确反映指令链引用（含 mode）
- 7d 后：get_snapshot JSON 完整性（为 Stage 8 铺路）

---

## 9. 决策记录

| 项 | 决策 | 说明 |
|---|---|---|
| 7c 数据源 | **InstructionAnalyzer 反射结果**（非组件自描述/codegen） | Stage 6.5 转方案 B 的连带调整。report.variables 含 name/source_prop/mode |
| 7a 编辑范围 | global 必可；local/scope 需 Runner 运行中 | 编辑模式无 context，不强求 |
| 7b 折线图 | 选中变量单曲线，60s/120 点 | 避免多变量叠加复杂度（V2 再做） |
| 静态 vs 运行时显示 | 独立分区，不合并 | 便于对比"引用了 vs 有值了" |
| 7c build_topology 性能 | 可加场景未变缓存 | 若 0.5s 轮询卡顿 |

## 10. 待评估项（来自 roadmap，单独任务，不在本轮）

BaseEvent/BaseCondition 的节点引用覆盖（InstructionAnalyzer._extract_event）—— roadmap Stage 7 待评估段。Stage 7 期间观察，若需修复单开子任务（类比 Stage 6.5 的指令变量 bug）。**本轮不涉及**。

---

**状态:** 计划待 Kai 审查。审查后可交付执行方（或本机执行）。
