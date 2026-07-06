# gdscript-ast-flow × Fuse 整合可行性报告

**创建日期:** 2026-06-26
**作者:** 技术调研（基于三路并行代码审计 + 双风险验证 + 架构落点核实）
**关联:** [2026-06-16-fuse-development-roadmap.md](2026-06-16-fuse-development-roadmap.md)（Stage 7/8）
**外部仓库:** `E:\GitHub\gdscript-ast-flow`（v2.1.0，MIT，作者 kenyonxu）
**状态:** ✅ 方案已定稿（方案 Y）— 本轮执行 Phase A+B，C/D 延后

---

## 执行摘要

调研结论：**整合可行且应做，采用「组件自描述 + 开发期 codegen」路径（方案 Y）**。

最重大的发现是 — **Fuse 现有的 `InstructionAnalyzer` 变量提取功能已 100% 失效**（硬编码属性名与实际组件命名脱节，确证见 §3）。因此整合不再是可选增强，而是修复已坏分析器 + 顺势升级的最佳手段。

**方案 Y 反转依赖方向**：gdscript-ast-flow 不进 Fuse 运行时，而是在**开发期**作为 codegen 工具，扫描 183 个组件源码，把「读写哪些变量 / 引用哪些 NodePath / 声明和 emit 哪些信号」生成为组件自描述声明（沿用现有 `_get_instruction_metadata()` 模式）。运行时 `InstructionAnalyzer` 读组件自描述替代硬编码常量。

**为何选方案 Y 而非运行时依赖**：
- Godot `class_name` 全局唯一 —— 若 gdscript-ast-flow 也独立发布，原样拷贝会导致用户同装两插件时「class already registered」崩溃（硬约束）。
- 方案 Y 让 Fuse 发布包**零外部依赖**，发布独立性满分，且组件自描述比 AST 外部推导更精确（组件知道自己 `target_variable` 是写、`from_variable` 是读）。
- 已验证 `BaseInstruction`（1260 行）有成熟静态元数据钩子 [_get_instruction_metadata()](../../core/base/base_instruction.gd#L309)，方案 Y 是其自然延伸。

**本轮范围**：Phase A（组件自描述 + InstructionAnalyzer 改造，~2 天）+ Phase B（变量监视器升级，~1-1.5 天）。Phase C（逻辑流 GraphEdit）/ Phase D（离线扫描 + AI/MCP）延后。

---

## 1. 两边能力对照

| 维度 | Fuse `InstructionAnalyzer`（249 行） | gdscript-ast-flow（核心 ~2000 行） |
|---|---|---|
| 分析对象 | 运行时已加载的 **Resource 对象**（反射） | **`.gd` 源码文本** + `.tscn`/`.tres` 文本 |
| 方法 | 属性名硬编码 + `get_property_list()` 反射 | Tokenizer → Parser(AST) → SymbolResolver |
| 节点引用 | 硬编码 6 个属性名（漏带前缀的） | AST 解析 `@export var ...: NodePath` 全集 |
| 变量 | 硬编码 `variable_name`（**已失效**） | 完整 Def-Use 链（def/read/write site） |
| 信号 | 仅扫 Runner 节点反射 | emit → connect 全链路 + 跨文件 |
| 调用关系 | 无 | 8 种调用模式调用图 |
| 可独立调用 | —（Fuse 内部静态方法） | ✅ 纯 RefCounted、零编辑器耦合、`class_name` 全局注册 |

**关键不对称**：gdscript-ast-flow 懂 GDScript 语法，但不懂 Fuse 的 `.tres` 配置语义；Fuse 懂配置语义，但提取策略已过时。两者天然互补 —— 方案 Y 让前者在开发期为后者服务，运行时解耦。

---

## 2. gdscript-ast-flow 可复用能力清单

### 2.1 三阶段管道（开发期 codegen 用）

`GDScriptTokenizer` → `GDScriptParser` → `GDScriptSymbolResolver`，全部 `extends RefCounted`、零 EditorPlugin 依赖、零文件写入。三阶段**完全解耦**。

最小调用（给 `.gd` 文本拿 Def-Use）：
```gdscript
var tokens := GDScriptTokenizer.new().tokenize(source)
var ast := GDScriptParser.new().parse(tokens)
var result := GDScriptSymbolResolver.new().resolve(ast, "")
var info := result.get_variable_usages("my_var")  # → def_site / read_sites / write_sites
```

> ⚠️ 方案 Y 下，该管道**只在开发期 codegen 脚本里运行**，不进 Fuse 发布包。

### 2.2 查询 API

| 能力 | 入口 | 返回 |
|---|---|---|
| Def-Use 链 | `result.get_variable_usages(name)` | `GDScriptDefUseInfo{def_site, read_sites, write_sites}` |
| 调用图（8 种模式） | `call_graph.get_callers_of(callee)` / `get_callees_of` | `Array[GDScriptCallEdge]` |
| 信号流（单文件） | `result.signal_graph.get_signal_flow(name)` | emit/connect sites |
| 信号流（跨文件） | `project_result.get_signal_flow_across_files(name)` | 跨文件边 |
| CodeGraph JSON | `project_result.to_dict()` | v2 schema |

### 2.3 CodeGraph JSON v2 Schema（Phase D / AI 消费用）

```
schema_version=2, project, summary{...},
files: { path → {class_name, extends, functions[], signals[], call_edges[], errors[]} },
cross_file: [{source_file, target_file, target_class, target_symbol, kind, line}],
hub_functions[], coupled_files[], scenes{}, resources{},
script_associations[], scene_signal_connections[]
```
`call_edge.type` ∈ 8 枚举（SELF/SUPER/EXTERNAL/CONNECT/SIGNAL_CONNECT/LAMBDA/STATIC/EMIT）。Def-Use 链**未序列化进 JSON**，若 AI 需要 D-U 数据要自行扩展。

### 2.4 GraphEdit 渲染层（Phase C 用）

`GDSVirtualGraphEdit.set_graph(nodes: Dictionary, edges: Array)` 接受**通用图数据**，零耦合、含成熟视口虚拟化（>50 节点裁剪、0.05s 节流、MAX_NODES=500、port cache 时序坑已修复）。`GDSGraphNode` / `GDSGraphLayout` 同样零耦合，可直接拷贝。

**不可复用**：`GDSCallGraphView`/`GDSSignalGraphView` 等 builder 层强耦合 `GDScriptAnalysisResult`，Fuse 需自写 `FuseGraphBuilder`（~150 行）。

### 2.5 `.tres`/`.tscn` 解析器（Phase D 用，有边界）

`GDScriptTresParser` / `GDScriptTscnParser` 独立、纯文本输入。但：
- **`.tres` 不支持数组属性** — `instructions = [SubResource("A"), SubResource("B")]` 整体留为原始字符串。对 Fuse ActionRunner 是 showstopper，需补 ~30 行数组分支递归展开。
- `.tscn` 信号连接能提取，但 instance 子场景的信号**不合并**。

> 方案 Y 本轮不触及 .tres/.tscn 解析器（走运行时反射 + 组件自描述），Phase D 才需要。

---

## 3. 🔴 重磅发现：InstructionAnalyzer 变量提取已 100% 失效

### 确证证据

| 项 | 实际值 | 来源 |
|---|---|---|
| InstructionAnalyzer 硬编码 | `_VARIABLE_PROP := "variable_name"` / `_SCOPE_PROP := "variable_scope"` | [instruction_analyzer.gd:22-23](../../editor/analysis/instruction_analyzer.gd#L22-L23) |
| 实际变量指令用的属性名 | `target_variable` / `target_variable_scope` / `from_variable` / `from_variable_scope` | [set_int_variable.gd:36,43,81,88](../../instructions/variables/set_int_variable.gd#L36) |
| 用 `target_variable` 的组件数 | **24 个** | `grep -rln target_variable instructions/` |
| 用 `variable_name` 的组件数 | **0 个** | `grep -rln '"variable_name"' instructions/` |

**结论**：[instruction_analyzer.gd:120](../../editor/analysis/instruction_analyzer.gd#L120) 的 `_extract_variables()` 对全部 24 个变量指令**一个都识别不了**。这是现存 bug。Topology 面板和变量监视器的「指令引用了哪些变量」功能因此长期失真。

### 同时受影响的硬编码

- [instruction_analyzer.gd:16-19](../../editor/analysis/instruction_analyzer.gd#L16-L19) `_NODE_PATH_PATTERNS`：6 个固定名字，漏掉 `target_target_node_path`、`from_target_node_path` 等带前缀属性。
- [instruction_analyzer.gd:161](../../editor/analysis/instruction_analyzer.gd#L161) `_extract_signals`：仅扫场景里 Runner 节点的 `signal_name`，无法静态追踪。
- [instruction_analyzer.gd:82](../../editor/analysis/instruction_analyzer.gd#L82) `_analyze_instructions`：嵌套指令**仅扁平 prefix 列表，不保留父子树结构**（Stage 8 GraphEdit 要用树结构）。

**这构成整合的最强动因**：组件自描述能一次性解决 NodePath/变量/信号三类提取的覆盖度问题。

---

## 4. Fuse 侧接入钩子点清单

| 钩子位置 | 当前实现 | 整合能力（方案 Y） | 改动 | 风险 |
|---|---|---|---|---|
| `_extract_variables` :120 | `variable_name`（失效） | 读组件 `_get_variable_accesses()` 自描述 | **替换** | 低（修 bug） |
| `_VARIABLE_PROP/_SCOPE_PROP` :22 | 字符串常量 | 删除，改调组件自描述 | **替换** | 低 |
| `_extract_nodepaths` :108 | 6 个硬编码 | 读组件 `_get_nodepath_props()` 自描述 | **替换** | 低 |
| `_extract_signals` :161 | 仅扫 Runner | 读组件 `_get_signal_info()` 自描述（声明/emit） | **增强** | 中 |
| `_analyze_instructions` :82 | 扁平 prefix | 保留真实父子树结构 | **增强** | 中 |
| `build_topology` :201 | signal + shared_global | 合并组件自描述信号 + 共享变量 | **增强** | 中 |
| `FuseVariableWatcher.get_snapshot` :234 | runners 永空、缺 local/scope | 补全数据 + 注入组件自描述静态声明 | **增强** | 低（接口已预留） |
| `FuseTopology._tree` :43 | Tree 列表 | （Phase C）可选叠加 GraphEdit 视图 | **新增(可选)** | 高 |
| `FusePresetSerializer` :166 | 走 Resource 对象 | **不改** | 不动 | 无 |

### 组件源码可达性（codegen 扫描用）

- **文件系统层**：[fuse_component_scanner.gd:30](../../editor/bootstrap/fuse_component_scanner.gd#L30) 扫 `instructions/` + `integration/` + `fuse_generated/instructions/`，递归逻辑可复用。
- **class_name 关联**：组件 `extends BaseInstruction` + `class_name SetIntVariable`，按 class_name ↔ `.gd` 路径双向映射可行。

### Preset 序列化不要碰

[fuse_preset_serializer.gd](../../editor/serialization/fuse_preset_serializer.gd) 走 `ResourceLoader` 加载对象。本轮不改 preset 管道。

---

## 5. 方案 Y：组件自描述 + 开发期 codegen

### 核心思想：反转依赖方向

```
开发期（一次性 codegen + CI 校验）：
  gdscript-ast-flow 三阶段管道扫 183 个组件 .gd
    → 提取每个组件的：变量读写属性、NodePath 属性、声明/emit 的信号
    → 生成自描述声明，写进组件文件（沿用 _get_instruction_metadata 模式）

运行时（Fuse 发布包，零外部依赖）：
  InstructionAnalyzer 调用 inst.script._get_variable_accesses() 等自描述方法
    → 替代硬编码常量，修好变量 bug + 补全 NodePath/信号覆盖
```

### BaseInstruction 扩展（已验证可行）

[base_instruction.gd](../../core/base/base_instruction.gd) 已有静态元数据钩子 `_get_instruction_metadata()`（:309），组件已在用（[set_int_variable.gd:24](../../instructions/variables/set_int_variable.gd#L24)）。方案 Y 新增同模式虚方法：

```gdscript
# BaseInstruction 新增（默认实现返回空，子类由 codegen 覆写）
static func _get_variable_accesses() -> Array:
    # 返回 [{prop: "target_variable", scope_prop: "target_variable_scope", mode: "write"}, ...]
    return []

static func _get_nodepath_props() -> Array:
    # 返回 ["target_node", "agent_node", ...]（该组件所有 NodePath 引用属性）
    return []

static func _get_signal_info() -> Dictionary:
    # 返回 {"declared": [...], "emitted": [...]}
    return {}
```

### 方案 Y 优势

1. **发布独立性满分** — Fuse 发布包不含任何 gdscript-ast-flow 代码，可任意独立发布。
2. **零 class_name 冲突** — 不引入任何外部 class_name。
3. **更精确** — 组件自描述「我写 target_variable、读 from_variable」，比 AST 外部靠赋值模式推导更准。
4. **符合现有架构** — `_get_instruction_metadata()` 模式的自然延伸，无新概念。
5. **防漂移** — codegen 脚本可在 CI 反向校验「组件声明 vs 实际源码」一致性，比现在「运行时反射硬猜」更稳。
6. **gdscript-ast-flow 独立性也保全** — 它爱怎么发布都不影响 Fuse。

### 代价（诚实说明）

- 183 个组件文件被 codegen 改动（每个加 ~5-15 行自描述声明）。
- 新组件要按模板补声明（可复用 `fuse-localization-fixer` 同款批量 skill 机制，或把 codegen 纳入 pre-commit）。
- codegen 脚本本身依赖 gdscript-ast-flow（仅开发期，不发布）。

---

## 6. 落地路径

### Phase A — 组件自描述 + InstructionAnalyzer 改造（本轮，~2 天）🎯 治本修 bug

1. **BaseInstruction 加 3 个自描述虚方法**（默认空实现）：`_get_variable_accesses()` / `_get_nodepath_props()` / `_get_signal_info()` — 0.5 天
2. **写 codegen 脚本**（开发期工具，放 `addons/fuse/tools/` 或独立 repo）：用 gdscript-ast-flow 扫 183 个组件源码，生成自描述声明写进各组件文件 — 1 天
3. **改造 InstructionAnalyzer**：删 3 个硬编码常量（[`:16-23`](../../editor/analysis/instruction_analyzer.gd#L16)），`_extract_*` 改调 `inst.script._get_*()` — 0.5 天
4. **即刻收益**：修好变量提取 bug，NodePath/信号覆盖度补全，Topology 面板数据变真实。

### Phase B — 变量监视器升级（本轮，~1-1.5 天）🎯 Stage 7 升级 / 变量检测

1. `get_snapshot()`（[:234](../../editor/debugging/variable_watcher.gd#L234)）补全 runners/local/scope 数据（接口已预留，仅缺填充）。
2. 注入组件自描述的变量声明：即使变量未运行，也能列出「指令链里出现过的变量及其读/写点」。
3. 监视器从「纯运行时轮询」→「静态声明 + 运行时值」双视图。

### Phase C — 逻辑流 GraphEdit（延后，~3-4 天）🎯 Stage 8

1. 拷贝 `GDSVirtualGraphEdit` + `GDSGraphNode`（零耦合渲染层，~200 行）。
2. 自写 `FuseGraphBuilder`：Trigger → Instruction 树转 `{nodes, edges}`（~150 行），保留父子结构（依赖 Phase A 改造后的 `_analyze_instructions`）。
3. `FuseTopology` 从 Tree 升级为 GraphEdit（Tree 作为降级视图保留）。

### Phase D — 离线扫描 + AI/MCP（延后，~2-3 天）🎯 价值点 4

1. `tres_parser` 补数组分支递归展开（~30 行）。
2. 新建 `tres_static_scanner`：不加载场景批量扫描项目所有 `.tres`（CI/AI 消费）。
3. CodeGraph JSON 导出 → 喂 `godot_mcp_editor`。

**本轮工时**：Phase A + B = **3-3.5 天**。

---

## 7. 风险清单

| 风险 | 验证状态 | 缓解 |
|---|---|---|
| ~~`GDScript*` class_name 全局冲突~~ | ✅ 方案 Y 规避 — 不引入任何外部 class_name | 无需缓解 |
| ~~`.tres` 数组属性 showstopper~~ | ✅ 方案 Y 本轮不触及 | Phase D 才需补 30 行 |
| 183 组件被 codegen 改动 | 可控 | codegen 幂等可重跑；纳入 pre-commit/CI 防漂移 |
| 组件自描述与实际源码漂移 | 中 | CI 反向校验「声明 vs 源码」一致性 |
| codegen 脚本依赖 gdscript-ast-flow | 仅开发期 | 不进发布包；gdscript-ast-flow 本地即可运行 |
| GDScript 语法覆盖（`%Node`/后缀/UID） | ✅ v2.1 已支持 | 真实项目验证过（limboai 等） |
| 两仓库长期同步 | 低 | 方案 Y 仅在 codegen 期依赖稳定的 AST 管道（Phase 1-3 已完成） |

---

## 8. 对 roadmap Stage 7/8 的改写建议

### Stage 6.5（新增）：组件自描述 + 分析器修复 = Phase A
**插入 Stage 7 前**。Stage 7/8 的正确性基础（修好分析器）。~2 天。

### Stage 7（改写）：变量监视器 V2 + 静态声明融合 = Phase B + 原 7a/7b
- 7a 双击编辑变量值（原计划）
- 7b 折线图（原计划）
- **7c（新）静态变量声明注入** — 来自 Phase A 的组件自描述
- **7d（新）`get_snapshot()` 补全** — 治 Stage 8 录播的 Pre-mortem #4 担忧

### Stage 8（改写）：高级调试 + GraphEdit = Phase C + 原 8a/8b（延后）
- 8a 录播 V1（原计划，依赖补全的 snapshot）
- **8b（改）GraphEdit 复用 GDSVirtualGraphEdit** — 替代原"自写 GraphEdit"，工期 2-3 天 → 1-2 天

### Stage 9（新增，延后）：离线扫描 + AI/MCP = Phase D
按需启用。

---

## 9. 决策记录（已定稿）

| 决策点 | 结论 | 日期 |
|---|---|---|
| 整合深度 | 先做 Phase A+B，Phase C/D 延后 | 2026-06-26 |
| 引入策略 | **方案 Y — 组件自描述 + 开发期 codegen**（非运行时依赖） | 2026-06-26 |
| gdscript-ast-flow 引入方式 | 开发期 codegen 工具，**不进 Fuse 发布包** | 2026-06-26 |
| 首要目标 | 变量检测 + 逻辑流并行（本轮聚焦变量检测） | 2026-06-26 |

**下一步**：制定 Phase A 详细实现计划（BaseInstruction 扩展接口契约 + codegen 脚本规格 + InstructionAnalyzer 改造 diff 范围），供执行。

---

**调研方法说明**：本报告基于三路并行代码审计（gdscript-ast-flow 分析 API / 解析器+渲染层 / Fuse 对接面）+ 三个关键风险点的验证（class_name 冲突 / 变量 bug 确证 / BaseInstruction 扩展点可行性）。所有结论带 file:line 引用可复核。
