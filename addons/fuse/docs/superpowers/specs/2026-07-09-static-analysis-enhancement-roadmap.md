# 静态分析后续增强 Roadmap

> 关联 spec：[2026-07-09-static-analysis-integration-design.md](2026-07-09-static-analysis-integration-design.md)
> 日期：2026-07-09
> 状态：roadmap（未排期，按需启动；每项可作为独立小 spec → plan）
> 前置：当前 spec 落地后（`InstructionAnalyzer.analyze_problems` 变量检测 + Topology 标注 + 移除 Validator/Panel）

---

## 设计原则

- **复用 Analyzer 现有提取能力**（`_extract_variables` / `_extract_nodepaths`），不为单条检测新写提取逻辑
- **接入点已就绪**：`analyze_problems` 加检测分支 / Topology 标注机制 / cross_ref 扫描基础
- **实时分析不做**：Fuse 与 Godot 自身的运行时/编辑器报错已覆盖实时反馈；静态分析价值在"跨指令、跨 Trigger 的结构性问题"，与实时报错互补

---

## 一、高价值（数据现成，`analyze_problems` 加分支）

### E1. NodePath 解析失败检测
- **动机**：指令引用的节点路径（`TweenMoveTo.target_node` 等）指向不存在节点是高频配置错误，运行时才静默失败。
- **数据来源**：`InstructionAnalyzer._extract_nodepaths(inst, report)` 已提取每指令的节点路径。
- **检测**：对每条提取的 NodePath，在场景上下文（`scene_root` / 指令 owner）下 `get_node_or_null()` 解析，失败 → `warning`（severity，含路径 + 指令 index）。
- **接入点**：`analyze_problems` 新增 `_check_nodepath_targets` 分支；需传入场景上下文（Topology `refresh` 有 `scene_root`，签名扩展为 `analyze_problems(instructions, scene_root=null)`）。
- **复杂度**：低（提取已有，加一次解析检查）。
- **注意**：路径可能是相对/绝对/owner 相对，解析需复用 `NodePathResolver`（`editor/serialization/nodepath_resolver.gd`）的解析规则，避免误报。

### E2. 信号引用检测
- **动机**：`EmitSignal` 指令 emit 的信号在目标节点不存在 → 静默失效。
- **数据来源**：需扩展 Analyzer 提取信号引用（emit 的信号名 + 目标节点）。当前 `_extract` 系列是否含信号待确认——若否，新增 `_extract_signals(inst, report)`（反射式，类似 `_extract_variables`）。
- **检测**：emit 的信号名在目标节点 `has_signal(name)` 为 false → `error`。
- **接入点**：`analyze_problems` 新增 `_check_signal_references` 分支；前置：Analyzer 加 `_extract_signals`（若缺）。
- **复杂度**：中（依赖信号提取的新增/确认）。

### E3. 跨 Trigger 变量关联标注
- **动机**：多 Trigger 共享 global 变量时，写-读关系与潜在竞态（多 Trigger 共写无锁）是结构性风险，单 Trigger 视角看不出。
- **数据来源**：`FuseTopology._refresh_cross_references(topology)` 已扫描全场景变量/信号/节点关联。
- **检测/展示**：
  - 标注"变量 X：Trigger A 写 ← Trigger B 读"关系（cross_ref 面板增强）
  - 竞态预警：多 Trigger 共写同一 global 变量且未走 `GlobalVariableManager` 互斥 → `warning`
- **接入点**：Topology `_refresh_cross_references` 增强 + `analyze_problems` 的跨 Trigger 聚合（需从单 Trigger 视角升到全场景）。
- **复杂度**：中（cross_ref 基础已有，竞态分析逻辑需设计）。

---

## 二、中价值（体验提升）

### E4. Godot 主题图标替代 emoji
- **现状**：spec 设计用 🔴🟡 emoji + 文本计数标注问题。
- **增强**：改用 `EditorInterface.get_editor_theme().get_icon("StatusError" / "StatusWarning", "EditorIcons")`，与编辑器原生观感一致。
- **接入点**：`fuse_topology._set_item_icon`（:263）或标注处 `set_item_icon`。
- **复杂度**：低。

### E5. Inspector 就地问题计数
- **动机**：Topology 是主入口，但用户在 Inspector 编辑 Trigger 属性时也想直接看到该 Trigger 健康度，不必切 tab。
- **方案**：选中 Trigger 时，Inspector 数据流卡片（`FuseInspectorPlugin` 调 `InstructionAnalyzer.analyze_trigger`）角标显示该 Trigger 的 `problems.summary`（如 `⚠ 2  ✗ 1`），点击展开问题列表。
- **接入点**：`fuse_inspector_plugin.gd` 数据流卡片生成（:134 `analyze_trigger` 结果加 problems）；`analyze_trigger` 内部调 `analyze_problems` 注入 summary。
- **复杂度**：中（Inspector 集成 + analyze_trigger 联动 analyze_problems）。

### E6. 问题过滤
- **动机**：大场景问题多时，建议类噪声淹没 error。
- **方案**：Topology banner 加过滤开关（仅 error / 隐藏建议 / 全部），树构建按过滤标注（非过滤项不标或淡化）。
- **接入点**：`fuse_topology` banner（:24-36）加选项控件 + `_create_trigger_tree_item`/`_build_tree_items` 按过滤态标注。
- **复杂度**：低-中。

---

## 三、不做（本 roadmap 排除）

| 项 | 排除理由 |
|----|----------|
| **实时分析** | Fuse 运行时 + Godot 编辑器已有实时报错，静态分析价值在结构性/跨指令问题，实时重复无收益 |
| **Quick fix**（未声明变量→插入创建指令） | UI 复杂，指令插入位置/类型推断不确定，收益看场景 |
| **类型不匹配检测** | BaseVariable 当前无强类型元数据，基础不足；待变量系统加类型后再评估 |
| **CI 批量分析** | 需 CLI 入口脱离编辑器，与编辑器集成定位偏离 |

---

## 建议推进顺序

1. **E1（NodePath）** — 最低成本（提取已有），高频配置错误，立竿见影
2. **E4（主题图标）** — 低成本体验提升，可在 E1 同批
3. **E2（信号）** — 中等成本，补全引用检测闭环（变量 + 节点 + 信号）
4. **E6（过滤）** — 问题增多后必需
5. **E3（跨 Trigger 关联）** — 价值高但设计成本高，放后
6. **E5（Inspector）** — 第二入口，Topology 稳定后补

每项启动时单独走 brainstorming → spec → plan（本 roadmap 仅作 backlog 索引）。
