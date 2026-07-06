# Event/Condition 节点/变量引用提取 — 执行计划

**日期:** 2026-06-28
**关联:** [spec](2026-06-28-event-condition-extraction-spec.md) · [Stage 6.5 执行计划](2026-06-26-stage6.5-implementation-plan.md)
**预估工时:** 0.5-1 天
**状态:** ✅ 完成（2026-06-29）。3 个扩展点（condition 深入 + event 提取 + `_is_variable_prop` 精确列表），测试 5/5 ✓ + 编辑器实机验收 ✓。

---

## 0. 目标

扩展 InstructionAnalyzer，让 Event + Condition 的节点/变量引用进 report（当前只提取指令）。复用 Stage 6.5 的 `_extract_nodepaths` / `_extract_variables`（反射 + 命名启发式），3 个扩展点。

---

## 1. 任务分解

| # | 扩展点 | 内容 | 工时 |
|---|---|---|:--:|
| A | `_analyze_instructions` 深入 condition | if/else 的 condition 属性调 `_extract_*` | 0.2 天 |
| B | `_extract_variables` 命名扩展 | 扩到 `*_variable_name` / `variable_name` / `compare_variable` 等 | 0.2 天 |
| C | `_extract_event` 加节点/变量提取 | event_definition 调 `_extract_*` | 0.1 天 |
| D | 测试 + 验收 | 扩展 test_stage65_extract.gd + 编辑器验收 | 0.3 天 |

---

## 2. 任务 A — `_analyze_instructions` 深入 condition

[instruction_analyzer.gd `_analyze_instructions`](../../editor/analysis/instruction_analyzer.gd)：在 `_extract_variables(inst, report)` 之后、递归嵌套指令之前，加 condition 提取。

```gdscript
# 现有（_analyze_instructions 内）：
_extract_nodepaths(inst, report)
_extract_variables(inst, report)

# 新增（紧接其后）：
# 条件（BaseCondition）节点/变量引用
if "condition" in inst:
    var cond = inst.get("condition")
    if cond != null:
        _extract_nodepaths(cond, report)
        _extract_variables(cond, report)

# 然后是现有的递归嵌套指令...
```

**覆盖：** if_then/if_else/run_condition_check 的 condition（~45 节点 + ~40 变量引用）。

**注意：** while_loop/wait_until/for_loop 不用 BaseCondition（扁平字段 `condition_variable`），不走此路径。但 `condition_variable` 含 `_variable`，已被 `_extract_variables(inst)` 覆盖（提取 inst 本身时命中）。

---

## 3. 任务 B — `_extract_variables` 命名扩展

当前 `_extract_variables` 只认 `ends_with("_variable")`。Condition 大量用其他命名，需扩展。

### 3.1 方案：加 `_is_variable_prop` 辅助方法

```gdscript
## 判断属性名是否为变量引用（命名启发式扩展版）
static func _is_variable_prop(pname: String) -> bool:
    # Stage 6.5 原有：*_variable（排除 *_variable_scope，因 _scope 结尾）
    if pname.ends_with("_variable"):
        return true
    # 扩展：Condition 常见的变量属性名
    if pname.ends_with("_variable_name"):
        return true
    if pname == "variable_name":
        return true
    if pname == "compare_variable":
        return true
    if pname == "source_variable":
        return true
    return false
```

`_extract_variables` 内 `if not pname.ends_with("_variable")` 改为 `if not _is_variable_prop(pname)`。

### 3.2 决策

- **精确列表**（推荐）：明确列出的属性名，避免误匹配。覆盖 ~90% Condition 变量引用。
- `contains("variable")`：更宽泛但风险高（可能匹配 `variable_scope` / `_variable_context` 等非引用属性）。

### 3.3 scope 配对

Condition 的变量属性（如 `variable_name`）可能没有配对的 `*_scope` 属性（直接是 local/global）。`_extract_variables` 的 scope 配对逻辑（`scope_prop = pname + "_scope"`）对 `variable_name` → 找 `variable_name_scope`，不存在则 scope=0（local）。这是合理的默认。

---

## 4. 任务 C — `_extract_event` 加节点/变量提取

[instruction_analyzer.gd `_extract_event`](../../editor/analysis/instruction_analyzer.gd)：`analyze_trigger` 内 `_extract_event(trigger)` 调用后，对 event_definition 调 `_extract_*`。

### 4.1 方案

两种实现位置：

**选项 1（推荐）：`_extract_event` 内提取**

```gdscript
static func _extract_event(trigger: Node) -> Dictionary:
    var ed = trigger.get("event_definition")
    if ed == null:
        return {}
    # 新增：提取事件引用的节点/变量（加到 report）
    # 但 _extract_event 返回 Dictionary，不传 report...
```

问题：`_extract_event` 返回 event 信息 Dictionary，不接收 report。需要改签名或换位置。

**选项 2（更简）：`analyze_trigger` 内提取**

```gdscript
# analyze_trigger 内，_extract_event(trigger) 之后：
var event_def = trigger.get("event_definition")
if event_def:
    _extract_nodepaths(event_def, report)
    _extract_variables(event_def, report)
```

**选选项 2**（不改 `_extract_event` 签名，直接在 `analyze_trigger` 对 event_definition 调 `_extract_*`）。

**覆盖：** ~35 个 Event 的节点引用 + 2 个变量引用。

---

## 5. 任务 D — 测试 + 验收

### 5.1 扩展 test_stage65_extract.gd

加 3 个测试：

```gdscript
# 测试 1：Condition 节点提取
# 构造 if_then + condition（CheckNodeExists, target_node="Player"）
# → _extract_nodepaths 提取 condition 的 target_node

# 测试 2：Condition 变量提取
# 构造 if_then + condition（CheckVariable, variable_name="health"）
# → _extract_variables 提取 condition 的 variable_name

# 测试 3：Event 节点提取
# 构造 Trigger + event_definition（OnNavigationTargetReached, agent_node="Agent"）
# → _extract_nodepaths 提取 event 的 agent_node
```

### 5.2 编辑器验收

- Topology：选含 if（CheckVariable health）的 Trigger → 变量区显示 health（来自 condition）
- Topology：选含 OnNavigationTargetReached 的 Trigger → 操作节点显示 agent_node
- 数据流卡片：事件/条件的节点/变量引用出现
- 回归：现有指令提取不受影响

---

## 6. 端到端验收

1. **Condition 节点提取**：if + CheckNodeExists(target_node) → Topology 操作节点显示
2. **Condition 变量提取**：if + CheckVariable(variable_name) → Topology 变量显示
3. **Event 节点提取**：OnNavigationTargetReached(agent_node) → Topology 操作节点显示
4. **Event 变量提取**：OnVariableChanged(variable_name) → Topology 变量显示
5. **回归**：现有指令提取 + Stage 6.5 测试不破坏

---

## 7. 风险与回滚

| 风险 | 应对 |
|---|---|
| 命名扩展误匹配 | 精确列表 + 测试验证 |
| condition 为 null | null 检查（`if cond != null`） |
| event_definition 为 null | null 检查 |
| 性能 | Condition/Event 数量少（每 Trigger 1 event + 嵌套 condition），反射开销可忽略 |

**回滚：** 3 个扩展点独立，可单独 revert。

---

## 8. 执行顺序

```
Step 1: 任务 A（_analyze_instructions 深入 condition）
Step 2: 任务 B（_extract_variables 命名扩展）
Step 3: 任务 C（_extract_event / analyze_trigger 加 event 提取）
Step 4: 任务 D（测试 + 编辑器验收）
```

**关键检查点：**
- A+B 后：if + CheckVariable 的 Topology 显示变量（condition 提取生效）
- C 后：OnNavigationTargetReached 的 Topology 显示 agent_node（event 提取生效）

---

## 9. 决策记录

| 项 | 决策 |
|---|---|
| 命名扩展方式 | **精确列表**（`_is_variable_prop`，避免误匹配） |
| event 提取位置 | `analyze_trigger` 内对 event_definition 调 `_extract_*`（不改 `_extract_event` 签名） |
| while_loop 扁平条件 | 已覆盖（`condition_variable` 含 `_variable`，inst 本身提取命中） |
| node_source 枚举切换 | V1 不处理（~10% 漏，后续增强） |

---

**状态:** 计划待 Kai 审查。审查后可执行（~0.5-1 天）。
