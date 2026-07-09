# 静态分析融入 Topology + Analyzer 生态 — 设计规格

> 日期：2026-07-09
> 状态：设计已批准，待写实现计划
> 范围：`editor/static_analysis/` 整合进 Fuse 编辑器生态（InstructionAnalyzer + FuseTopology）
> 决策依据：brainstorming（整合深度=中「统一引擎 + Topology 标注」；引擎方式=A1「Analyzer 加 analyze_problems，删 Validator」）

---

## 1. 背景与动机

`editor/static_analysis/static_analysis_panel.gd` 当前是**孤岛**，三个硬隔离点：

1. **面板从未注册到编辑器 UI**：`plugin.gd._enter_tree()` 只注册了 `_watcher`（bottom panel）与 `_topology`（main screen），**没有任何代码实例化或挂载 `StaticAnalysisPanel`**。`plugin.gd:124` 与 `fuse_type_registrar.gd:37` 对它的引用只是 `required_scripts` 配置检查与 class_name 类型注册，不是 UI 接入。文档（`00-editor-panels-overview.md`）声称"工具栏/Dock 打开"无代码支撑——实际打不开。
2. **双分析引擎并存且重复**：`InstructionAnalyzer`（`editor/analysis/`）是生态核心，被 Topology（`build_topology`）、Inspector（`analyze_trigger`）、VariableWatcher、NodePathResolver 共享；`InstructionValidator`（`editor/static_analysis/`）**仅**被这个孤立面板使用，却另写一套变量提取逻辑。
3. **零联动 + 假实现**：面板自行 `find_children("ActionRunner")` 取第一个，不响应选区/Topology/Inspector；结果孤立显示；进度条是 `for i in range(10): await timer` 的假模拟。

**Validator 检测质量低**：
- 变量引用检测用 `script.source_code` 正则匹配 `set_variable\("..."`——`@tool` 编译后常无 source_code，且与 Analyzer 的反射式 `_extract_variables` 重复且劣。
- 死循环检测靠类名含 `jump/goto/branch/loop/repeat/cycle` 关键词——Fuse 指令无 jump 语义，纯启发式误报源。
- 性能检测靠类名含 `large/heavy/complex/batch` + 操作计数 >10——同样类名启发式，价值低。

---

## 2. 目标

- 把有效检测（变量引用）统一到 `InstructionAnalyzer`，用其反射式 `_extract_variables` 取代 Validator 的正则。
- 在 **Topology 主屏**就地标注问题（树节点 🔴/🟡 + 选中详情），消除独立面板。
- 移除孤岛代码（面板 + Validator + 注册 + 相关测试）。
- 零回归：现有 Topology/Inspector/Analyzer 调用方不受破坏。

---

## 3. 设计

### 3.1 引擎统一 — `InstructionAnalyzer.analyze_problems`

新增静态方法（`editor/analysis/instruction_analyzer.gd`）：

```gdscript
## 静态分析：检测指令序列中的问题（未声明变量使用等）
## @param instructions: Array[BaseInstruction] - 指令序列（flat 顺序）
## @return: Dictionary - {valid: bool, problems: Array[Dictionary]}
##   每条 problem: {severity: "error"|"warning"|"suggestion",
##                  message: String, instruction_index: int, variable: String}
static func analyze_problems(instructions: Array[BaseInstruction]) -> Dictionary:
    # 1. 遍历 instructions，对每条调用自身 _extract_variables（反射式）取 used / defined
    # 2. 维护已知变量集（前序 defined 累积）
    # 3. used 变量若未在前序 defined → 记 error（severity="error"，
    #    message 经 FuseLocalization 本地化，instruction_index = 当前下标，variable = 变量名）
    # 4. 返回 {valid: problems.filter(error).is_empty(), problems: [...]}
```

**关键约束**：
- **仅做变量引用检测**（本次）。死循环/性能类名启发式**删除**（YAGNI，价值低）。
- 用 `FuseLocalization.translate_format` 本地化错误消息（与现有 FuseError 风格一致）。
- `instruction_index` 是传入数组的 flat 下标（与 Topology 的 `instructions_flat` 顺序一致）。

**不做**（未来扩展，本次 YAGNI）：NodePath 解析失败检测（用 `_extract_nodepaths`）、类型不匹配检测。

### 3.2 Topology 标注集成

修改 `editor/topology/fuse_topology.gd`：

**a) refresh()（:91-142）增强**：
- `build_topology(scene_root)` 后，对每个 trigger report，取其 `instructions_flat`（或等价 flat 指令数组），调用 `InstructionAnalyzer.analyze_problems(instructions)`。
- 结果存入 `report["problems"]`，结构：
  ```
  {
    by_index: {0: [prob, ...], 2: [prob]},   # instruction_index → problems
    summary: {errors: int, warnings: int, suggestions: int}
  }
  ```

**b) 树节点标注**：
- `_create_trigger_tree_item`（:150）/ `_build_tree_items`（:198）：节点 metadata 已含 `inst` 引用（:215），增加记录 `instruction_index`。
  - 指令节点：查 `report.problems.by_index[index]`，有 error → `set_custom_color` 红 + 文本前缀 🔴；warning → 黄 + 🟡；无 → 正常。
  - Trigger 节点：汇总子树 `summary`，有 error → 整行红 + 后缀 `(2🟡 1🔴)`。

**c) 选中详情**：
- `_on_item_selected`：详情面板（`_detail`）在原有 Trigger 概要/指令详情**之后**追加"问题"段（BBCode，分级着色），仅显示当前选中节点的问题。

**d) 导出按钮**：
- 顶部 banner（:24-36）"刷新"旁加 **"导出问题报告"** 按钮。
- 点击：遍历全场景所有 trigger 的 `report.problems`，汇总写 `user://fuse_problems_report_{时间}.txt`（替代原面板导出）。

### 3.3 触发时机

- **手动刷新**（现有 🔄 按钮）时同步跑 `analyze_problems`。
- **不做实时**（避免编辑时反复分析的开销）。
- 移除假进度条（场景规模小，同步足够）。

### 3.4 数据流

```
用户点 🔄 刷新
  → refresh()
  → InstructionAnalyzer.build_topology(scene_root) → topology.triggers[]
  → 每 trigger: InstructionAnalyzer.analyze_problems(trigger.flat_instructions)
      → report["problems"] = {by_index, summary}
  → _create_trigger_tree_item/_build_tree_items 按 problems 标 🔴/🟡/计数
  → 选中节点 → _on_item_selected → _detail 显示该节点 problems
  → 导出按钮 → 全场景 problems 汇总 → user://fuse_problems_report_*.txt
```

### 3.5 移除清单

| 文件 / 位置 | 动作 |
|-------------|------|
| `editor/static_analysis/static_analysis_panel.gd` | 删除整个文件 |
| `editor/static_analysis/instruction_validator.gd` | 删除整个文件（逻辑迁入 analyze_problems） |
| `editor/static_analysis/` 目录 | 若空则删 |
| `editor/bootstrap/fuse_type_registrar.gd:36-37` | 删 `InstructionValidator` + `StaticAnalysisPanel` 两行注册 |
| `plugin.gd:123-124` | 删 required_scripts 两行（Validator + Panel） |
| `tests/editor_tools_test.gd:17,19,33,35,317` | 删 `instruction_validator` / `static_analysis_panel` 字段 + 初始化 + `get_panel_info` 用例 |
| `tests/test_stage2_integration.gd:61,210,233` | 删 `test_static_analysis_panel_localization` 及其调用 |

### 3.6 新增测试

- `tests/test_instruction_analyzer_problems.gd` + `.tscn`：
  - 已声明变量使用 → valid=true, 0 problems
  - 未声明变量使用 → valid=false, 1 error（instruction_index 正确）
  - 多处未声明 → 多 error
  - 空序列 → valid=true

---

## 4. 接口契约

### analyze_problems（新增）
```
InstructionAnalyzer.analyze_problems(instructions: Array[BaseInstruction]) -> Dictionary
返回：{
  valid: bool,                          # problems 中无 error
  problems: Array[{                     # 每条问题
    severity: String,                   # "error" | "warning" | "suggestion"（本次仅产生 "error"）
    message: String,                    # 本地化错误描述
    instruction_index: int,             # 在 instructions 数组中的下标
    variable: String                    # 触发问题的变量名
  }]
}
```

### report.problems（Topology 注入）
```
report["problems"] = {
  by_index: Dictionary,    # int(instruction_index) → Array[problem]
  summary: {errors: int, warnings: int, suggestions: int}
}
```

---

## 5. 测试策略

- **TDD**：analyze_problems 先写测试（RED）→ 实现（GREEN）。
- Topology 标注：手动验证（场景含未声明变量 → 刷新 → 树标红 + 选中详情显示）。
- 回归：现有 `test_stage65_extract.gd`（_extract_variables/nodepaths）、Topology 现有行为不受影响。
- gdscript-validate 改动文件（analyze_problems 新增 + fuse_topology 改动 + 移除后的引用清理）。

---

## 6. 验收标准

- [ ] `InstructionAnalyzer.analyze_problems` 实现 + 单测通过（含未声明变量检测）
- [ ] `InstructionValidator` 与 `StaticAnalysisPanel` 文件删除
- [ ] `fuse_type_registrar.gd` + `plugin.gd` 的 Validator/Panel 注册清理
- [ ] `editor_tools_test.gd` + `test_stage2_integration.gd` 的相关用例删除，其余测试仍通过
- [ ] `fuse_topology.gd` refresh 跑 analyze_problems，树节点按问题标 🔴/🟡 + Trigger 汇总计数
- [ ] 选中节点详情面板显示该节点问题（BBCode 分级着色）
- [ ] Topology banner 导出按钮产出 `user://fuse_problems_report_*.txt`
- [ ] gdscript-validate 全部改动文件通过
- [ ] `00-editor-panels-overview.md` 移除"静态分析面板"独立章节，改为 Topology 标注说明

---

## 7. 不做（YAGNI）

- 实时分析（编辑时自动跑）
- 死循环检测、性能启发式（类名关键词，低价值，删）
- 独立静态分析面板（移除，融入 Topology）
- 假进度条
- NodePath 解析失败 / 类型不匹配检测（未来扩展）
- InstructionValidator 保留为 deprecated 别名（A1 决策：直接删）

---

## 8. 风险与回滚

- **风险**：`_extract_variables` 的反射式提取可能对某些指令子类覆盖不全（依赖 `get_variable_accesses` 等 codegen 钩子）。若未 codegen，Analyzer 静默降级——此时未声明变量检测可能漏报。
  - 缓解：analyze_problems 在指令无变量访问信息时，不报 error（避免误报），仅对明确 used 而无定义的报。
- **回滚**：改动集中在新增 analyze_problems + Topology 标注 + 删 static_analysis/，git revert 单 commit 即可。

---

**下一步**：用户审 spec → 通过后 invoke writing-plans 生成实现计划。
