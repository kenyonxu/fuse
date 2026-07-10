# E3. 跨 Trigger 变量关联标注 — 设计规格

> 关联 roadmap：[2026-07-09-static-analysis-enhancement-roadmap.md](2026-07-09-static-analysis-enhancement-roadmap.md)
> 关联 spec：[2026-07-09-static-analysis-integration-design.md](2026-07-09-static-analysis-integration-design.md)
> 日期：2026-07-10
> 状态：规划中
> 前置依赖：build_topology 已落地（全场景 Trigger 扫描 + cross_references 基础）

---

## 1. 动机

Fuse 场景中的 Trigger 通过 **global 变量** 相互通信（写-读、写-写）。单个 Trigger 的视角看不到以下风险：

1. **写-读数据流断裂**：Trigger A 写 `global_hp` 的值用于 Trigger B 控制 `IfVariable` 条件——如果 Trigger A 的写入路径意外绕过了这个变量，Trigger B 的逻辑失效。
2. **竞态条件**：Trigger C 和 Trigger D 同时写 `global_score`（无 `GlobalVariableManager` 互斥锁），执行顺序不确定导致状态不一致。
3. **孤写/孤读**：变量被写入但没有任何 Trigger 读取（孤写），或变量被读取但无 Trigger 写入（孤读——可能是初始值依赖）。

当前 Topology 面板的 `_refresh_cross_references` 已显示跨 Trigger 关联，但仅限于：
- 信号连接（`type: "signal"`）
- 全局变量共享（`type: "shared_global_variable"`）

它**不区分变量的读写方向**，也不标记竞态风险。

E3 将 `_refresh_cross_references` 从"展示谁用了同一个变量"提升为"展示变量的写入-读取关系 + 竞态预警"。

---

## 2. 现状分析

### 2.1 当前 cross_references 实现

`InstructionAnalyzer.build_topology(scene_root)`（`:334-390`）当前生成两种跨 Trigger 关联：

```gdscript
# 跨 Trigger 关联：信号连接（:358-369）
for t1_name in all_reports:
    var r1 = all_reports[t1_name]
    for signal_info in r1.signals:
        var target = signal_info.get("target", "")
        for t2_name in all_reports:
            if target.find(t2_name) != -1:
                topology.cross_references.append({
                    "from": t1_name, "to": t2_name,
                    "type": "signal", "detail": signal_info.signal
                })

# 跨 Trigger 关联：共享全局变量（:371-388）
for vname in global_vars_used:
    var users = global_vars_used[vname]
    if users.size() > 1:
        for i in range(users.size()):
            for j in range(i + 1, users.size()):
                topology.cross_references.append({
                    "from": users[i], "to": users[j],
                    "type": "shared_global_variable", "detail": vname
                })
```

### 2.2 当前 `_refresh_cross_references` 展示

`fuse_topology.gd` 的 `_refresh_cross_references(topology)`（`:640-662`）渲染为标签文本：

```
跨 Trigger 关联 (3 条):
🔗 信号  TriggerA → TriggerB  (on_player_died)
🌐 全局变量  TriggerA → TriggerC  (global_hp)
🌐 全局变量  TriggerB → TriggerC  (global_hp)
```

### 2.3 当前缺口

| 缺口 | 表现 | 影响 |
|------|------|------|
| **无读写方向** | `type: "shared_global_variable"` 只标记"谁和谁共享此变量" | 用户看不出谁是写者谁是读者 |
| **无读写模式标注** | 不知道是 `write`、`read` 还是 `read_write` | 无法判断数据流向 |
| **无竞态检测** | 多 Trigger 写同一变量无锁 | 用户无感知 |
| **无孤写/孤读检测** | 变量被写但从未被读 | 无用代码（可能表示设计错误） |
| **cross_ref_label 仅靠 Label 显示** | 纯文本无法交互 | 不能点击跳转到对应 Trigger |

---

## 3. 设计

### 3.1 总览

```
build_topology(scene_root)
  └─ 扫描 Trigger 已有逻辑（不变）
  └─ 增强 cross_references 生成：
       ├─ 全局变量关联 → 区分 read / write / read_write
       ├─ 竞态检测 → 多 Trigger 共写 + 无锁
       └─ 孤写/孤读 → 单 Trigger 维度即可判定（不需要 cross_ref）
  └─ _refresh_cross_references 增强渲染：
       ├─ 变量写-读箭头标注（Writer → Variable → Reader）
       ├─ 竞态预警行（🔥 标记）
       └─ 孤写/孤读在 Trigger 详情 panel 中显示
```

### 3.2 变量读写方向分析

`InstructionAnalyzer._infer_variable_mode(pname)`（`:245-249`）已对变量访问模式做三元判断：

```gdscript
static func _infer_variable_mode(pname: String) -> String:
    if pname.begins_with("target_"):
        return "write"
    if pname.begins_with("from_"):
        return "read"
    return "read_write"
```

`build_topology` 中已收集每个 Trigger 的 `variables.global` 数组，每条 entry 含 `mode`（`"write"` / `"read"` / `"read_write"`）。

**增强方案**：在构建跨 Trigger 关联时，对每个全局变量按 Trigger 汇总 `mode` 信息：

```gdscript
# 增强后的 global_vars_used 结构：
# { variable_name: [{trigger_name: "A", mode: "write"}, {trigger_name: "B", mode: "read"}] }
var global_vars_usage := {}  # vname → [{trigger_name, mode}, ...]

for report in all_reports.values():
    for var_entry in report.variables.global:
        var vname: String = var_entry.name
        var mode: String = var_entry.get("mode", "read_write")
        if not global_vars_usage.has(vname):
            global_vars_usage[vname] = []
        global_vars_usage[vname].append({
            "trigger_name": report.trigger_name,
            "mode": mode
        })
```

> （审阅修订 MEDIUM#4：trigger_name 字段确认）已核对 `instruction_analyzer.gd:28-30`：`analyze_trigger` 返回的 report **含 `trigger_name` 字段**（`"trigger_name": trigger.name`），`build_topology` 用 `all_reports[trigger.name] = report`（`:354`）存入——因此 `report.trigger_name` 在 `all_reports.values()` 迭代中可直接取到。无需 `report.get("trigger_name", report.get("name", "?"))` 兜底。

### 3.3 cross_references 新条目类型

| type | 语义 | 生成条件 |
|------|------|---------|
| `variable_write_to_read` | 写者 → 变量 → 读者 | Trigger A 写，Trigger B 读同一全局变量 |
| `variable_write_to_write` | 竞态对 | 两个或多个 Trigger 都写同一全局变量（无锁） |
| `variable_write_only` | 孤写 | 全局变量被写但无 Trigger 读（单 Trigger 或跨 Trigger） |
| `variable_read_only` | 孤读 | 全局变量被读但无 Trigger 写 |

#### write_to_read 条目

```gdscript
# 对每个变量，找到 write-mode Trigger 到 read-mode Trigger 的边
for vname in global_vars_usage:
    var usages := global_vars_usage[vname]
    var writers := usages.filter(func(u): return u.mode in ["write", "read_write"])
    var readers := usages.filter(func(u): return u.mode in ["read", "read_write"])
    for writer in writers:
        for reader in readers:
            if writer.trigger_name == reader.trigger_name:
                continue
            topology.cross_references.append({
                "from": writer.trigger_name,
                "from_mode": writer.mode,  # （审阅修订 MEDIUM#3：取实际 mode，与 write_to_write 对称，不再硬编码 "write"）
                "to": reader.trigger_name,
                "to_mode": reader.mode,
                "type": "variable_write_to_read",
                "detail": vname
            })
```

> （审阅修订 MEDIUM#7：read_write 双向性澄清）`_infer_variable_mode` 对非 `target_`/`from_` 命名的变量判定为 `read_write`，会**同时**进入 `writers` 和 `readers` 集合。因此：
> - 孤写/孤读判定**主要对严格 `target_`/`from_` 命名的变量有效**；
> - 对 `read_write` 变量，仅当它独自出现且无其他指令引用时才算孤（实际几乎不会触发孤写/孤读）；
> - 写-读关系中 `read_write` 变量会与自身或其他 `read_write` 变量产生冗余边（已通过 `writer.trigger_name == reader.trigger_name` 跳过自环），跨 Trigger 时会标记为"读写 → 读写"。

#### write_to_write 条目（竞态）

```gdscript
# 对每个变量，找到 write-mode Trigger 之间的全连接
for vname in global_vars_usage:
    var writers := global_vars_usage[vname].filter(func(u): return u.mode in ["write", "read_write"])
    # 竞态预警条件：
    #   2+ writers，且这些 writer 没有使用 GlobalVariableManager 做互斥
    if writers.size() >= 2:
        for i in range(writers.size()):
            for j in range(i + 1, writers.size()):
                topology.cross_references.append({
                    "from": writers[i].trigger_name,
                    "from_mode": writers[i].mode,
                    "to": writers[j].trigger_name,
                    "to_mode": writers[j].mode,
                    "type": "variable_write_to_write",
                    "detail": vname,
                    "warning": true
                })
```

**互斥检测**：在 `analyze_trigger` 阶段收集 Trigger 是否使用了 `GlobalVariableManager`（可通过扫描其指令链中是否存在 `GlobalVariableSet` / `LockVariable` 等指令检测）。在 `build_topology` 中标记 `has_mutex: bool`。如果所有 writer 都使用了互斥，则降级 warning。

初始版本做简化检测：**检查 Trigger 的指令链中是否存在含 `lock` / `mutex` 关键词的指令**。若无法检测到，默认为"未使用互斥"。

#### 孤写 / 孤读

孤写 / 孤读不需要跨 Trigger 关联，而是对 `global_vars_usage` 的单一变量统计：

```gdscript
# 挂在 topology 顶层
topology["variable_analysis"] = []
for vname in global_vars_usage:
    var usages := global_vars_usage[vname]
    var writers := usages.filter(func(u): return u.mode in ["write", "read_write"])
    var readers := usages.filter(func(u): return u.mode in ["read", "read_write"])
    var entry := {"name": vname, "writers": writers, "readers": readers}
    if writers.is_empty() and not readers.is_empty():
        entry["anomaly"] = "read_only"   # 孤读
    elif not writers.is_empty() and readers.is_empty():
        entry["anomaly"] = "write_only"  # 孤写
    else:
        entry["anomaly"] = "normal"
    topology.variable_analysis.append(entry)
```

### 3.4 `_refresh_cross_references` 渲染增强

> **注意**：`_cross_ref_label` 当前是 `Label`，但 warning_lines 使用了 BBCode（`[color=yellow]`）。Label **不解析 BBCode**——必须改为 `RichTextLabel` 并启用 `bbcode_enabled = true`。
> 对照源码 `fuse_topology.gd:15,85-86`：`var _cross_ref_label: Label` → `var _cross_ref_label: RichTextLabel`；`_cross_ref_label = Label.new()` → `RichTextLabel.new()`；`_cross_ref_label.autowrap_mode = ...` → `_cross_ref_label.bbcode_enabled = true`（RichTextLabel 也支持 `autowrap_mode`）。
> `RichTextLabel.text =` 的 setter 在 `bbcode_enabled = true` 时自动解析 `[color]` 标签。

```gdscript
func _refresh_cross_references(topology: Dictionary) -> void:
    var ref_lines := PackedStringArray()
    var warning_lines := PackedStringArray()

    for ref in topology.get("cross_references", []):
        var ref_type: String = ref.get("type", "?")

        match ref_type:
            "signal":
                ref_lines.append("🔗  %s → %s  信号: %s" % [
                    ref.from, ref.to, ref.detail])
            "variable_write_to_read":
                ref_lines.append("📝  %s (%s) → [%s] → %s (%s)" % [
                    ref.from, _mode_label(ref.from_mode),
                    ref.detail,
                    ref.to, _mode_label(ref.to_mode)])
            "variable_write_to_write":
                var line := "🔥  %s ↔ %s  共享变量: %s (竞态)" % [
                    ref.from, ref.to, ref.detail]
                warning_lines.append("[color=yellow]%s[/color]" % line)
            _:
                ref_lines.append("❓  %s → %s  (%s)" % [ref.from, ref.to, ref.detail])

    # 孤写/孤读
    for entry in topology.get("variable_analysis", []):
        match entry.get("anomaly", "normal"):
            "write_only":
                warning_lines.append("[color=yellow]📤  孤写: %s → (无读者)[/color]" % entry.name)
            "read_only":
                warning_lines.append("[color=yellow]📥  孤读: %s ← (无写者)[/color]" % entry.name)

    # 组装显示
    var all_lines := PackedStringArray()
    if not ref_lines.is_empty():
        all_lines.append("跨 Trigger 关联 (%d 条):" % ref_lines.size())
        all_lines.append_array(ref_lines)
    if not warning_lines.is_empty():
        if not all_lines.is_empty():
            all_lines.append("")
        all_lines.append("⚠ 预警 (%d 条):" % warning_lines.size())
        all_lines.append_array(warning_lines)
    if all_lines.is_empty():
        _cross_ref_label.text = "跨 Trigger 关联: (无)"
    else:
        _cross_ref_label.text = "\n".join(all_lines)
```

辅助方法：

```gdscript
static func _mode_label(mode: String) -> String:
    match mode:
        "write": return "写"
        "read": return "读"
        "read_write": return "读写"
        _: return mode
```

### 3.5 与 `analyze_problems` 的联动

部分跨 Trigger 问题（如竞态、孤写/孤读）**不属于单指令级别**的 `analyze_problems`，而是**全场景级别**的 `build_topology` 产物。它们在 Topology 面板中显示在 cross_ref_label 区域，而不会出现在指令的 🔴/🟡 标注中。

但某些跨 Trigger 问题可以**下行到具体指令**的 problem 标注——例如：

- 竞态预警若可定位到具体写入指令（哪条 `SetVariable` 指令在无锁时写全局变量），可给该指令附加一个 `warning: "全局变量 %s 可能被多 Trigger 同时写入（无互斥锁）"` 的 problem

此联动为**可选**，Phase 1 不做，Phase 2 按需插入。

### 3.6 竞态检测的简化策略

Phase 1 的竞态检测采用**保守策略**：

```
竞态判定条件（全部满足）：
1. 同一全局变量被 >= 2 个 Trigger 写入（mode = write / read_write）
2. 写入 Trigger 的指令链中无 Lock / Mutex / GlobalVariableManager 使用
3. 变量非原子类型（默认所有变量都视为非原子——Godot 的 Variant 读写无内置原子性）

→ 生成 warning 级 cross_ref 条目
```

**锁检测方式**：对 Trigger 的指令扫描名/属性中是否含以下标志。需要从 report 收集 `inst` 对象——这里复用 `fuse_topology.gd:672` 已有的 `_collect_insts_from_report(report)` 方法（而非定义新的收集逻辑），该方法和 `:693` 的 `_collect_insts_from_tree` 已覆盖 `instructions_flat` + `instructions_tree` + `event_bindings` 三种路径：

```gdscript
static func _has_mutex_protection(report: Dictionary) -> bool:
    var insts := _collect_insts_from_report(report)
    for inst in insts:
        # （审阅修订 MEDIUM#2：_collect_insts_from_report 返回 inst 对象（Resource），
        # 非 Dictionary，去掉 Dictionary 分支，用 inst.resource_name 取脚本资源名）
        var name: String = inst.resource_name
        if name.to_lower().contains("lock") or name.to_lower().contains("mutex") \
                or name.to_lower().contains("sync"):
            return true
    # 也可扫描 variables.global 作用域中的 scope_id/mutex 属性
    return false
```

**后续增强**：若 Fuse 新增了 `GlobalVariableManager.lock_variable()` API，可直接在 `analyze_trigger` 中标记 Trigger 的锁状态。

### 3.7 Trigger 详情面板中的变量关系

`_show_trigger_detail` 中，在现有"变量"段落之后追加跨 Trigger 变量关联信息：

```gdscript
# 在 _show_trigger_detail 末尾，追加跨 Trigger 变量关联
var topology_data := _last_topology  # 保存的全局拓扑
var cross_refs: Array = topology_data.get("cross_references", [])
var this_name: String = report.get("trigger_name", "")
var related_refs := cross_refs.filter(func(r):
    return r.get("from") == this_name or r.get("to") == this_name)

if not related_refs.is_empty():
    _detail.append_text("\n[b]跨 Trigger 关联:[/b]\n")
    for r in related_refs:
        var direction := "→" if r.from == this_name else "←"
        var target := r.to if r.from == this_name else r.from
        match r.get("type", ""):
            "variable_write_to_read":
                _detail.append_text("  %s %s [color=gray]变量: %s[/color]\n" % [direction, target, r.detail])
            "variable_write_to_write":
                _detail.append_text("  [color=yellow]⚠ %s ↔ %s 竞态: %s[/color]\n" % [r.from, r.to, r.detail])
            "signal":
                _detail.append_text("  🔗 %s %s [color=gray]信号: %s[/color]\n" % [direction, target, r.detail])
```

---

## 4. 接口契约

### `build_topology` 返回结构增强

```diff
 {
   "scene_name": String,
   "triggers": [...],
-  "cross_references": [{from, to, type, detail}]
+  "cross_references": [{from, to, type, detail, from_mode?, to_mode?, warning?}],
+  "variable_analysis": [{name, writers, readers, anomaly}]
 }
```

### cross_references 新增条目类型

| type | 新增字段 | 语义 |
|------|---------|------|
| `variable_write_to_read` | `from_mode`, `to_mode` | 写者 → 变量 → 读者 |
| `variable_write_to_write` | `from_mode`, `to_mode`, `warning: true` | 竞态预警 |

### `_refresh_cross_references` 无签名变更

方法签名不变——仍接收 `topology: Dictionary`。增强来自新的 cross_references 类型 + variable_analysis 字段。

### `_has_mutex_protection` 新增

```
FuseTopology._has_mutex_protection(report: Dictionary) -> bool
```

- 私有静态方法
- 扫描 `report.instructions_flat` 中的指令名是否含 lock/mutex/sync
- 扫描 `report.variables.global` 是否含互斥标记
- 返回 true 表示该 Trigger 对全局变量有互斥保护

---

## 5. 测试策略

### 5.1 单元测试（`test_build_topology.gd` 新增）

**`test_cross_ref_variable_write_to_read`**
- 构造两个 Trigger：T1 写 `global_hp`（`target_global_variable = "global_hp"`），T2 读 `global_hp`（`from_global_variable = "global_hp"`）
- `build_topology` 结果应含 1 条 `type: "variable_write_to_read"` 的 cross_ref
- `from` = T1 名，`to` = T2 名，`detail` = "global_hp"

**`test_cross_ref_variable_race_condition`**
- 构造两个 Trigger：T1 写 `global_score`，T2 写 `global_score`，均无互斥标记
- 预期：含 1 条 `type: "variable_write_to_write"` 的 cross_ref，`warning: true`

**`test_cross_ref_variable_race_suppressed_by_mutex`**
- T1 写 `global_score`，T2 写 `global_score`，但 T1 指令名含 "LockVariable"
- 预期：无竞态预警（或者 `warning: false`）

**`test_variable_write_only_anomaly`**
- 全局变量 `global_orphan` 被 T1 写入，无 Trigger 读取
- 预期：`variable_analysis` 中该变量 `anomaly = "write_only"`

**`test_variable_read_only_anomaly`**
- 全局变量 `global_uninit` 被 T1 读取，无 Trigger 写入
- 预期：`variable_analysis` 中该变量 `anomaly = "read_only"`

**`test_cross_ref_render_write_to_read`**
- `_refresh_cross_references` 渲染含 variable_write_to_read 条目的 topology
- 预期：输出文本含 `📝  T1 (写) → [global_hp] → T2 (读)`

**`test_cross_ref_render_race_warning`**
- 渲染含 variable_write_to_write 的 topology
- 预期：输出文本含 `🔥` 和 `竞态`

**`test_no_cross_ref_when_single_trigger`**（审阅修订 MEDIUM#5：区分 cross_references 关联类与 variable_analysis 孤写孤读）
- 构造单个 Trigger T1：既写又读 `global_x`（`target_global_variable = "global_x"` + 另一指令 `from_global_variable = "global_x"`），即无孤写也无孤读
- 预期：
  - `cross_references.variable_write_to_read.is_empty()`（单 Trigger 无跨 Trigger 关联）
  - `cross_references.variable_write_to_write.is_empty()`
  - `variable_analysis` 中 `global_x` 的 `anomaly = "normal"`（既有写者又有读者）
- 注：若改为"单 Trigger 只写不读"，则 `cross_references` 仍为空（孤写不进 cross_ref），但 `variable_analysis` 会标记 `write_only`——测试场景需明确区分这两类断言

### 5.2 视觉验证（手动）

- 打开含多个 Trigger 的场景（确认 Topology 面板打开）
- 存在全局变量写-读关系 → cross_ref_label 显示 `📝 T1 (写) → [varname] → T2 (读)`
- 存在竞态 → `🔥` 行 + 黄色着色
- 孤写/孤读 → `📤` / `📥` 行

### 5.3 回归

- 现有信号连接的 cross_ref 渲染不变
- 现有 `_show_trigger_detail` 不破坏（追加内容在末尾）
- 旧版 `shared_global_variable` 类型不再生成（由新类型替代）

---

## 6. 实现步骤

### Phase 1：`build_topology` 增强

**文件**: `addons/fuse/editor/analysis/instruction_analyzer.gd`

1. 重构 `build_topology` 中全局变量的收集逻辑（`:371-388`）：
   - 从 `{vname: [trigger_names]}` 改为 `{vname: [{trigger_name, mode}, ...]}`
   - 利用现有 `report.variables.global[i].mode`（`_infer_variable_mode` 已产出）
2. 新增 `variable_write_to_read` 条目生成（写者 → 变量 → 读者）
3. 新增 `variable_write_to_write` 条目生成（竞态预警）
   - 辅助方法：`_check_mutex_protection(global_vars, all_reports)` 扫描指令名
4. 新增 `topology.variable_analysis` 孤写/孤读标注

**验收**：
- [ ] build_topology 返回的 cross_references 包含 writer→reader 条目
- [ ] build_topology 返回的 cross_references 包含竞态条目
- [ ] build_topology 返回的 variable_analysis 含孤写/孤读标注
- [ ] 原有信号关联条目保留

### Phase 2：`_refresh_cross_references` 渲染增强

**文件**: `addons/fuse/editor/topology/fuse_topology.gd`

1. **（审阅修订 HIGH#1：将 `_cross_ref_label` 从 `Label` 改为 `RichTextLabel`，bbcode_enabled=true）**：当前 `fuse_topology.gd:15` 声明 `var _cross_ref_label: Label`，`:85` 实例化 `Label.new()`，纯文本不解析 BBCode。warning_lines 使用了 `[color=yellow]...[/color]` 标签，必须改造为 `RichTextLabel`：
   - `:15` → `var _cross_ref_label: RichTextLabel`
   - `:85` → `_cross_ref_label = RichTextLabel.new()`
   - `:86` 之后追加 `_cross_ref_label.bbcode_enabled = true`（保留 `autowrap_mode = TextServer.AUTOWRAP_WORD_SMART`，RichTextLabel 兼容此属性）
2. `_refresh_cross_references` 新增 `variable_write_to_read` 和 `variable_write_to_write` 渲染分支
3. 新增 `_mode_label` 辅助方法
4. 新增孤写/孤读渲染（读取 `topology.variable_analysis`）
5. `_show_trigger_detail` 追加跨 Trigger 关联信息段（可选，Phase 2）

**验收**：
- [ ] `_cross_ref_label` 已改为 `RichTextLabel`，`bbcode_enabled = true`
- [ ] 写-读关系正确渲染为 `📝 T1 (写) → [var] → T2 (读)`
- [ ] 竞态预警行含 `🔥` + 黄色着色（BBCode `[color=yellow]` 被正常解析，非原始文本显示）
- [ ] 孤写/孤读在底部预警区显示（BBCode 着色正常）
- [ ] 信号关联无退化

### Phase 3：测试

**文件**: `addons/fuse/tests/test_build_topology.gd`

1. 实现 Phase 5.1 所有测试用例
2. 确认回归测试通过

---

## 7. 不做（YAGNI）

| 项 | 原因 |
|----|------|
| **跨嵌套场景变量关联** | 当前 `build_topology` 在处理嵌套场景的 `scene_source` 标记，但跨场景的变量命名空间不统一——先保持聚焦单场景 |
| **交互式 cross_ref（点击跳转）** | `_cross_ref_label` 是 `Label` 不是 `RichTextLabel`，不支持点击交互。若需点击跳转到对应 Trigger，需改用 `RichTextLabel` + `meta_clicked`——可另开 spec |
| **局部变量共享检测** | Scope 变量有 `scope_id` 作用域隔离，在多 Trigger 间不共享。跨 Trigger 分析只关注 `global` 作用域 |
| **数据流图替代文本** | GraphEdit 已在 fuse_topology.gd 中保留但非默认显示；在 GraphEdit 中绘制变量流图是另一独立特性 |
| **自动修复**（"建议添加 LockVariable 指令"） | 属于 Quick fix，单一指令插入逻辑不复杂但在 cross_ref 层级定位插入点更复杂——YAGNI |
| **精确的锁范围分析** | Phase 1 仅做指令名关键词匹配（`lock`/`mutex`/`sync`），不做精确的锁-变量配对。后者要求分析 `LockVariable` 的参数锁定哪个变量 |

---

## 8. 风险

| 风险 | 影响 | 缓解 |
|------|------|------|
| 指令名中不含 `lock`/`mutex` 关键词但使用了互斥同步 | 竞态漏报（false negative） | 默认为无锁，宁可误报不可漏报。未来可通过 `_has_mutex_protection` 扩展检查逻辑 |
| 指令名含 `lock` 但锁定的是不同变量（锁不保护目标变量） | 竞态预警被错误抑制 | Phase 1 不做精确锁分析，此场景当前视为"有锁"。Phase 2 可精确化 |
| `_infer_variable_mode` 对 `read_write` 的双向性判断不准确 | 写-读关系中可能错误标记写者/读者 | `read_write` 同时出现在 writers 和 readers 集合中，不会遗漏但可能产生冗余条目——文本渲染中会标记为"读写" |
| build_topology 中 variable_analysis 影响 topology 体积 | 大场景下 cross_ref 条目数膨胀（N 个变量 × M² 个 Trigger） | 每个变量的竞态全连接只对 `writers.size() >= 2` 的变量做 O(W²) 生成，W 通常 ≤ 3。variable_analysis 是 O(V) 的线性数组 |
| `_refresh_cross_references` 输出文本过长 | Label 可能超出可见区域 | 已有 `autowrap_mode = WORD_SMART`（`:86`），长文本自动换行 |
| `trigger.name` 跨场景同名碰撞（审阅修订 MEDIUM#6） | `build_topology` 用 `trigger.name` 作 `all_reports` 的 key（`:354`），跨场景（如多个场景各有一个名为 "TriggerA" 的节点）合并扫描时后者覆盖前者，cross_ref 关联到错误 Trigger | Phase 1 不引入跨场景合并扫描（`build_topology` 仅扫描单 scene_root 子树）。若未来做跨场景拓扑，需改用 `node_path` 或 `instance_id` 作唯一 key，并在 cross_ref 渲染中带上场景前缀去重 |

---

## 9. 验收标准

- [ ] `build_topology` 产出含 `variable_write_to_read` + `variable_write_to_write` 类型的新型 cross_references
- [ ] 竞态检测触发条件正确：多写 + 无互斥 → warning
- [ ] `variable_analysis` 标注孤写/孤读
- [ ] `_refresh_cross_references` 正确渲染所有新条目类型
- [ ] `_has_mutex_protection` 检测关键词 lock/mutex/sync
- [ ] 详情面板显示当前 Trigger 的跨 Trigger 关联
- [ ] 回归：信号关联显示不受影响
- [ ] 所有 E3 测试用例通过
- [ ] Roadmap 中 E3 标记为 "spec 完成"

---

## 10. 修改文件清单

| 文件 | 变更类型 | 说明 |
|------|---------|------|
| `addons/fuse/editor/analysis/instruction_analyzer.gd` | 修改 | `build_topology` 中全局变量收集逻辑重构 + 新增竞态检测 + `variable_analysis` |
| `addons/fuse/editor/topology/fuse_topology.gd` | 修改 | `_cross_ref_label` 由 `Label` 改为 `RichTextLabel`（bbcode_enabled=true）（审阅修订 HIGH#1）+ `_refresh_cross_references` 渲染增强 + `_mode_label` + `_show_trigger_detail` 追加跨 Trigger 段 |
| `addons/fuse/tests/test_build_topology.gd` | 新增用例 | Phase 5.1 全部测试 |

---

*本 spec 批准后，下一步：invoke writing-plans 生成实现计划。*
