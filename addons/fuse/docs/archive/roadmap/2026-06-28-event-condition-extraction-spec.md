# Event/Condition 节点/变量引用提取 — Spec

**日期:** 2026-06-28
**关联:** [roadmap Stage 7 待评估项](2026-06-16-fuse-development-roadmap.md) · [Stage 6.5](2026-06-26-stage6.5-implementation-plan.md)
**状态:** ✅ 完成（2026-06-29）。实现见 [执行计划](2026-06-28-event-condition-extraction-plan.md)，测试 5/5 ✓ + 编辑器实机验收 ✓。

---

## 1. 背景与目标

Stage 6.5 修复了 InstructionAnalyzer 的**指令**（BaseInstruction）节点/变量提取（反射 + 命名启发式，`*_variable`→变量、`*_node`→节点）。

但**事件**（BaseEvent）和**条件**（BaseCondition）的引用提取未做：
- `_extract_event` 只提取 type + resource_name，不提取节点/变量引用
- `_analyze_instructions` 不深入 if/while 的 condition 属性

**目标:** 扩展 InstructionAnalyzer，让 Event + Condition 的节点/变量引用也进 report，使 Topology/数据流卡片/GraphEdit 的数据流**完整闭环**（指令 + 事件 + 条件三类组件统一提取）。

---

## 2. 现状（agent 调研结论）

### 2.1 Events（69 个 .gd）

| 项 | 统计 |
|---|---|
| 引用节点的 Event | **~35 个**（半数以上） |
| 引用变量的 Event | **2 个**（on_variable_changed、on_interval_with_variable） |
| 典型节点属性名 | `target_node` / `target_node_path` / `agent_node` / `area_node` / `origin_node_path` / `parent_node` / `tween_node_path` / `sound_source_path` |
| 声明方式 | 混合：~10 个 `_get_property_list` 动态声明，其余 `@export var ... : NodePath` |

### 2.2 Conditions（55 个 .gd）

| 项 | 统计 |
|---|---|
| 引用节点的 Condition | **~45 个**（绝大多数） |
| 引用变量的 Condition | **~40 个** |
| 典型节点属性名 | `target_node` / `target_node_path` / `source_node` / `agent_node` / `area_node` / `check_node_path` / `child_node` / `parent_node` |
| 典型变量属性名 | `variable_name` / `*_variable_name` / `compare_variable` / `source_variable` / `array_variable` / `dict_variable` / `health_variable` |
| 声明方式 | **33/55（60%）用 `_get_property_list`** 动态声明 —— 反射必需 |

### 2.3 Condition 挂载方式

| 指令 | condition 存储 |
|---|---|
| if_then / if_else | `var condition: BaseCondition = null`（@export 存储） |
| run_condition_check | `@export var condition: BaseCondition` |
| while_loop / wait_until / for_loop | **不用 BaseCondition**，用扁平字段（`condition_variable` + 枚举）—— 内联条件语义 |

`_analyze_instructions` 递归 `_SUB_INSTRUCTIONS`（instructions/else_instructions/loop_instructions）覆盖嵌套指令，但**不深入 condition 属性**。

### 2.4 当前提取覆盖

| 组件类型 | 节点提取 | 变量提取 |
|---|:--:|:--:|
| 指令（BaseInstruction） | ✅ Stage 6.5（反射 + `*_node`） | ✅ Stage 6.5（反射 + `*_variable`） |
| 事件（BaseEvent） | ❌ `_extract_event` 只 type+name | ❌ |
| 条件（BaseCondition） | ❌ `_analyze_instructions` 不深入 condition | ❌ |

---

## 3. 扩展方案（3 个扩展点）

### 3.1 扩展点 A：`_analyze_instructions` 深入 condition

if_then/if_else/run_condition_check 的 `condition: BaseCondition` 属性，对其调 `_extract_nodepaths` + `_extract_variables`：

```gdscript
# _analyze_instructions 内，_extract_nodepaths(inst) / _extract_variables(inst) 之后加：
if "condition" in inst:
    var cond = inst.get("condition")
    if cond != null:
        _extract_nodepaths(cond, report)
        _extract_variables(cond, report)
```

**覆盖：** ~45 个 Condition 的节点引用 + ~40 个变量引用。

### 3.2 扩展点 B：`_extract_variables` 命名启发式扩展

当前只认 `ends_with("_variable")`。Condition 大量用其他命名，需扩展：

```gdscript
# 当前：if not pname.ends_with("_variable"): continue
# 扩展为：
func _is_variable_prop(pname: String) -> bool:
    return pname.ends_with("_variable") \
        or pname.ends_with("_variable_name") \
        or pname == "variable_name" \
        or pname == "compare_variable" \
        or pname == "source_variable"
```

**覆盖：** Condition 的 `*_variable_name` / `variable_name` / `compare_variable` 等命名家族。

### 3.3 扩展点 C：`_extract_event` 加节点/变量提取

`analyze_trigger` 中拿到 `event_definition` 后，对其调 `_extract_nodepaths` / `_extract_variables`（Event 同样是 Resource，反射通用）：

```gdscript
# _extract_event 内，return 前加：
var ed = trigger.get("event_definition")
if ed:
    _extract_nodepaths(ed, report)
    _extract_variables(ed, report)
```

**覆盖：** ~35 个 Event 的节点引用 + 2 个变量引用。

---

## 4. 覆盖率预估

| 组件 | 节点提取 | 变量提取 |
|---|:--:|:--:|
| Condition | ~95%（45 个命中，少数 node_source 枚举切换间接模式） | ~90%（扩展命名后；剩余为 node_variable_name 间接模式） |
| Event | ~90%（35 个命中，少数动态信号属性需特殊处理） | 100%（2 个，命名标准） |

---

## 5. 好处（做与不做对比）

| 场景 | 不做 | 做了 |
|---|---|---|
| **Topology 操作节点** | 只指令引用的节点 | + 事件/条件引用的节点（完整数据流） |
| **Topology 变量** | 只指令引用的变量 | + 条件/事件引用的变量 |
| **数据流卡片 / GraphEdit**（Stage 5/8） | 事件→节点、条件→变量的边缺失 | 完整节点-连线图 |
| **跨 Trigger 关联** | 多 Trigger 监听同节点的关联漏 | 发现同节点被多事件监听 |
| **变量监视器静态声明**（7c） | 只指令变量 | + 条件/事件变量（更全） |

---

## 6. 风险

| 风险 | 缓解 |
|---|---|
| `_extract_variables` 扩展命名误匹配（如 `node_variable_name` 含 `_variable`） | 精确匹配列表 + 测试验证 |
| while_loop/wait_until 不用 BaseCondition（扁平字段） | 扁平字段（`condition_variable`）已被 `_extract_variables` 的 `*_variable` 启发式覆盖 |
| Condition 的 `node_source` 枚举切换（NODE_PATH vs NODE_VARIABLE 模式） | V1 不特殊处理（枚举切换的间接模式 ~10% 漏，后续增强） |
| 性能（condition/event 提取增加反射调用） | Condition/Event 数量少（每 Trigger 1 event + 嵌套 condition），开销可忽略 |

---

## 7. 与 Stage 6.5 的关系

Stage 6.5 修了指令提取（方案 B 反射 + 命名启发式）。本 spec 是**同一思路的扩展**（反射 + 命名启发式应用到 Event/Condition），复用 `_extract_nodepaths` / `_extract_variables` 方法，零新概念。

**工作量：** ~0.5-1 天（3 个扩展点都是复用现有方法 + 1 处命名扩展）。

---

## 8. 待 plan 确认

1. `_extract_variables` 命名扩展：精确列表 vs 更宽泛的 `contains("variable")`
2. while_loop/wait_until 扁平条件字段是否已覆盖（`condition_variable` 含 `_variable`？）
3. Condition `node_source` 枚举切换模式是否 V1 处理
