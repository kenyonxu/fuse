# analyze_problems 条件递归扩展 — 设计规格

> 日期：2026-07-09
> 状态：设计已批准，待实现
> 关联：[静态分析整合 spec](2026-07-09-static-analysis-integration-design.md)（本 spec 是其 §3.1 的扩展）
> 触发：`demos/fuse/test/test_topology_warning.tscn` 场景的 CheckVariable 读未声明变量未被检测，暴露 analyze_problems 不递归 condition

---

## 1. 问题

`InstructionAnalyzer.analyze_problems` 只遍历 instructions 顶层数组的变量引用，**不递归 `inst.condition`**（BaseCondition）。6 个条件容器指令的 condition 内变量引用漏检：

- `instructions/debug/breakpoint_instruction.gd`
- `instructions/flow_control/if_else.gd`
- `instructions/flow_control/if_then.gd`
- `instructions/flow_control/run_condition_check.gd`
- `instructions/flow_control/wait_until.gd`
- `instructions/flow_control/while_loop.gd`

根因：`_extract_variables(inst, report)`（instruction_analyzer.gd:211）只反射 `inst` 自身属性，不递归 SubResource（condition 是 BaseCondition 资源）。

**表现**：`test_topology_warning.tscn` 的 `RunConditionCheck.condition`（CheckVariable 读 `variable_name="int"`，全 Trigger 无 SetVariable 定义）→ analyze_problems 返 0 problems → Topology 无 🔴。

---

## 2. 方案

`analyze_problems` 遍历每条指令时，额外递归其 condition：

```gdscript
for i in range(instructions.size()):
    var inst = instructions[i]
    # 1. 指令自身变量（现有逻辑）
    _extract_variables(inst, tmp)
    # process tmp.variables.local（write/read_write → 定义累积；read → 检测未声明）
    
    # 2. 递归 condition（新增）
    var cond = inst.get("condition") if inst != null else null
    if cond is BaseCondition:
        var cond_tmp := {"variables": {"local": [], ...}, ...}
        _extract_variables(cond, cond_tmp)
        # 条件变量全部视为 read（条件只读不写），不进 defined_locals
        for entry in cond_tmp.variables.local:
            var vname = entry.get("name", "")
            if not vname.is_empty() and not defined_locals.has(vname):
                problems.append({severity: "error", message: "未声明的局部变量被使用（条件）: %s（指令 %d）" % [vname, i], instruction_index: i, variable: vname, inst: inst})
```

### 检测语义

| 变量来源 | mode 处理 | 进 defined_locals？ | 检测 |
|---------|-----------|-------------------|------|
| 指令自身（write/read_write） | 累积定义 | 是 | — |
| 指令自身（read） | 检测 | 否 | 未声明 → error |
| **条件（新增）** | **全部 read** | **否** | **未声明 → error** |

条件只读不写，故条件变量一律视为 read，不进定义集。

### 顺序语义（单遍）

单遍顺序扫描：condition 读变量时，`defined_locals` 含**前序指令**的 write。body 内 write（在条件容器之后）**不满足**条件的 read。

例：`if_then(condition=CheckVariable 读 X, body=[SetVariable X])` → condition 读 X 时 X 未定义 → error（即使 body 写了 X）。这符合"条件读变量需在外层先定义"语义。

---

## 3. 范围

### 做
- 覆盖 6 个条件容器的单层 `condition` 属性
- 嵌套 instructions body（if_then/while_loop 等）—— 已由 `_collect_insts_from_report` 递归收集进 flat 数组，analyze_problems 顺序遍历
- 条件变量仅检测 **local**（scope/global 假定外部定义，与指令一致）

### 不做（YAGNI）
- 复合条件递归（condition 内嵌套 conditions，如 CompositeCondition 的子条件）——单层先覆盖常见场景
- 条件变量的 scope/global 检测
- 重新扫描"同 Trigger 任意位置 write"（两遍扫描）——保持单遍顺序语义

---

## 4. 测试策略

扩展 `tests/test_instruction_analyzer_problems.gd`：

1. **MockInst 加 condition 支持**：MockInst 加 `condition` 属性（MockCondition，含 variable_name）
2. **新增用例**：
   - 条件读未声明 local 变量 → 1 error（inst=容器指令, variable=未声明名）
   - 条件读已声明变量（前序 SetVariable 定义）→ 0 problem
   - 条件 + 指令混合：指令 write X → 条件 read X → valid

TDD：RED（加测试，condition 不递归 → FAIL）→ GREEN（实现递归）。

---

## 5. 验收标准

- [ ] analyze_problems 递归 inst.condition，条件读未声明 local 变量 → error
- [ ] 条件变量不进 defined_locals（条件只读）
- [ ] 单遍顺序语义（body write 不满足 condition read）
- [ ] 测试用例覆盖：条件未声明 / 条件已声明 / 混合
- [ ] test_topology_warning.tscn 跑 analyze_problems → CheckVariable 读 "int" 报 error（需场景验证）
- [ ] gdscript-validate instruction_analyzer.gd 通过
- [ ] 现有 4 用例不回归

---

## 6. 改动量

- `instruction_analyzer.gd` analyze_problems：+ condition 递归分支（~10 行）
- `test_instruction_analyzer_problems.gd`：+ MockCondition + 3 用例
- 小改，无破坏性（analyze_problems 输出扩展，Topology 标注自动承接）

---

## 7. 附：Topology resource_name 陈旧修复（选项 C）

`test_topology_warning.tscn` 的"未指定变量名"经核实是 **RunConditionCheck.resource_name 陈旧**（嵌套资源同步问题：容器不监听 condition 内部属性变化），**非 CheckVariable bug**（CheckVariable `get_description`/`_update_resource_name` 都正确显示 variable_name）。

**修复（选项 C，绕过陈旧）**：Topology 树节点显示改用 `inst.get_description()`（实时）而非 resource_name（静态陈旧）。

- **改动**：`fuse_topology._build_tree_items` / `_create_flat_item` 的 `display_name` 优先 `inst.get_description()`，回退 `node_info["name"]`（resource_name）
- **范围**：Topology 显示层小改，不动 resource_name 同步机制（选项 A/B 留 future）
- **效果**：嵌套条件容器的显示实时反映 condition 内部变量名变化

---

**下一步**：用户审 spec → writing-plans。
