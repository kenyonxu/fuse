# 静态分析增强 E1–E6 统一实现计划

> 关联 roadmap：[2026-07-09-static-analysis-enhancement-roadmap.md](2026-07-09-static-analysis-enhancement-roadmap.md)
> 关联集成设计：[2026-07-09-static-analysis-integration-design.md](2026-07-09-static-analysis-integration-design.md)
> 日期：2026-07-10
> 状态：规划中

---

## 1. 总览

六项 E 系列增强按 Roadmap 建议顺序排列：**E1 → E4 → E2 → E6 → E3 → E5**。本计划分析每项之间的**文件冲突**和**逻辑依赖**，重新分组为三波并行，以最小化总工期。

### 各 spec 速览

| 编号 | 名称 | 核心文件 | 改动复杂度 | 预估代码行 |
|------|------|---------|-----------|-----------|
| E1 | NodePath 检测 | nodepath_resolver, instruction_analyzer, fuse_topology | ⭐⭐⭐ | ~120 |
| E2 | 信号引用检测 | instruction_analyzer | ⭐⭐ | ~80 |
| E3 | 跨 Trigger 分析 | instruction_analyzer, fuse_topology | ⭐⭐⭐⭐ | ~180 |
| E4 | 主题图标替代 emoji | fuse_topology | ⭐ | ~50 |
| E5 | Inspector 问题计数 | fuse_inspector_plugin, fuse_topology | ⭐⭐⭐ | ~100 |
| E6 | 问题过滤 | fuse_topology | ⭐⭐ | ~80 |

---

## 2. 依赖关系图

```
E3 (跨Trigger) ── 独立 ──────────┐
                                  ├── Wave 1
E4 (主题图标) ─── 独立 ──────────┤
                                  │
E1 (NodePath) ─── 独立 ──────────┘
     │
     │ resolve_or_null + 同文件 analyze_problems 区域
     ▼
E2 (信号检测) ─────────────────── Wave 2
     │
     └── analyze_problems 完整后

E4 (主题图标) ─── 同文件同区域标注 → E6 (过滤) ──── Wave 2
     │
     └── _severity_label 可选复用 → E5 (Inspector)

E3 (跨Trigger) ─── refresh_cross_references 增强 ── (独立)

                                    _index_problems 提升
                                          │
                                          ▼
E5 (Inspector) ───────────────────────── Wave 3
```

### 关键约束

| 依赖类型 | 从 → 到 | 原因 |
|---------|---------|------|
| **逻辑依赖** | E1 → E2 | E2 需要 `NodePathResolver.resolve_or_null` 解析目标节点 |
| **文件冲突** | E1 → E2 | 都修改 `instruction_analyzer.gd` 的 `analyze_problems` 方法 |
| **文件冲突** | E4 → E6 | 都修改 `fuse_topology.gd` 的 `_build_tree_items` / `_create_trigger_tree_item` 标注区域 |
| **逻辑依赖** | E1/E2 → E5 | E5 需要 `analyze_problems` 完整（含 NodePath + 信号检测）才显示完整计数 |
| **接口提升** | (E1/E2) → E5 | `_index_problems` 需从 `fuse_topology.gd` 提升到 `instruction_analyzer.gd` 供 Inspector 复用 |
| **无冲突** | E3 ↔ 其他 | `build_topology` 与 `analyze_problems` 是 `instruction_analyzer.gd` 中正交的方法；`_refresh_cross_references` 区域与 E4/E6 的标注区域不重叠 |

### 文件冲突矩阵

| 文件 | E1 | E2 | E3 | E4 | E5 | E6 | 并行限制 |
|------|:--:|:--:|:--:|:--:|:--:|:--:|---------|
| `nodepath_resolver.gd` | ✅ | | | | | | 唯一占用 |
| `instruction_analyzer.gd` | ✅ | ✅ | ✅ | | ✅* | | E1→E2 同区；E3 正交；E5 仅静态方法提升 |
| `fuse_topology.gd` | ✅ | | ✅ | ✅ | ✅ | ✅ | E4→E6 同区；E3/E5 不同区可并行 |
| `fuse_inspector_plugin.gd` | | | | | ✅ | | 唯一占用 |
| `test_instruction_analyzer_problems.gd` | ✅ | ✅ | | | ✅ | | 同一测试文件多组用例 |
| `test_build_topology.gd` | | | ✅ | | | | 唯一占用 |

✅* = E5 的 `_index_problems` 提升为 `InstructionAnalyzer` 的公开静态方法

---

## 3. 三波并行方案

### Wave 1（可并行，预计 1 次提交）

| 项 | 文件 | 工作量 | 并行理由 |
|----|------|--------|---------|
| **E1** NodePath 检测 | nodepath_resolver + instruction_analyzer + fuse_topology | 中 | 与 E4 无文件重叠 |
| **E4** 主题图标替代 emoji | fuse_topology | 小 | 与 E1 无文件重叠，完全独立 |
| **E3** 跨 Trigger 分析 | instruction_analyzer + fuse_topology | 大 | 与 E1/E4 无重叠区域 |

**Wave 1 完成后**：`analyze_problems` 具备变量检测 + NodePath 检测；Topology UI 使用主题图标；跨 Trigger 关联具备读写方向 + 竞态预警。

---

### Wave 2（依赖 Wave 1，可并行，预计 1 次提交）

| 项 | 依赖 | 并行理由 |
|----|------|---------|
| **E2** 信号引用检测 | E1 的 `resolve_or_null` + `analyze_problems` | 与 E6 无文件重叠 |
| **E6** 问题过滤 | E4 的图标架构落地 | 与 E2 无文件重叠 |

**Wave 2 完成后**：信号检测完整；Topology 支持三态过滤。

---

### Wave 3（依赖 Wave 2，单独提交）

| 项 | 依赖 | 理由 |
|----|------|------|
| **E5** Inspector 问题计数 | `_index_problems` 提升 + `analyze_problems` 完整 | 需 E1/E2 完成才有完整问题内容 |

**Wave 3 完成后**：Inspector 数据流卡片显示问题摘要。

---

### 甘特图示意

```
Wave 1:  E1 ████████████░░░░  E4 ██████░░░░░░░░  E3 ██████████████████░░
Wave 2:                       E2 ██████████░░░░  E6 ████████░░░░░░░░
Wave 3:                                               E5 ████████████░░░░
         ────────────────────────────────────────────────────────────────►
```

三波预计共 **3 次提交**（Wave 1 可拆为 3 个子提交或 1 次合并提交，视代码审查粒度而定）。

---

## 4. 每项详细计划

### 4.1 E1 — NodePath 解析失败检测

#### 实现文件

| 文件 | 变更类型 | 变更量 |
|------|---------|--------|
| `addons/fuse/editor/serialization/nodepath_resolver.gd` | **新增方法** | ~30 行 |
| `addons/fuse/editor/analysis/instruction_analyzer.gd` | **修改** — `analyze_problems` 签名 + 新增 `_check_nodepath_targets` | ~40 行 |
| `addons/fuse/editor/topology/fuse_topology.gd` | **修改** — `refresh()` 调用处传 `scene_root` | 1 行 |
| `addons/fuse/tests/test_instruction_analyzer_problems.gd` | **新增用例** — 7 个测试 | ~100 行 |
| `addons/fuse/tests/test_instruction_analyzer_problems.tscn` | **修改** — 扩展场景节点 | ~5 行 |

#### 改动点

1. **`NodePathResolver.resolve_or_null(np_str, scene_root) → Node`** — 公开静态方法，封装三级匹配策略
2. **`InstructionAnalyzer.analyze_problems` 签名** — `(instructions, scene_root = null)`
3. **`InstructionAnalyzer._check_nodepath_targets`** — 新分支，在变量检测末尾调用
4. **`FuseTopology.refresh()`** — 传入 `EditorInterface.get_edited_scene_root()`

#### 验收标准

- [ ] `resolve_or_null("Player", scene_root)` → Player 节点；`resolve_or_null("Nonexistent", scene_root)` → null
- [ ] `analyze_problems([...], scene_root)` → 含 warning 级 problem；不传 scene_root → 0 warning
- [ ] Topology 刷新后，无效 NodePath → 🟡 标注（E4 落地前为 emoji，落地后为 StatusWarning 图标）
- [ ] 所有 7 个 E1 测试用例通过
- [ ] 现有变量检测测试回归通过

---

### 4.2 E4 — Godot 主题图标替代 emoji

#### 实现文件

| 文件 | 变更类型 | 变更量 |
|------|---------|--------|
| `addons/fuse/editor/topology/fuse_topology.gd` | **修改** — 7 处 emoji 替换 + 2 个辅助方法 | ~50 行 |

#### 改动点

1. **`_get_theme_icon(icon_name) → Texture2D`** — 新增私有方法，封装 `EditorInterface.get_editor_theme()`
2. **`_severity_label(severity) → String`** — 新增私有静态方法，`error` → `"错误"` / `warning` → `"警告"`
3. **`_build_tree_items` :260/:264** — `"🔴 " + text` → `item.set_icon(0, StatusError/Warning)`
4. **`_create_trigger_tree_item` :179/:182** — `"%d🔴 %d🟡"` → 中文标签 + `set_icon`
5. **`_on_item_selected` :412** — RichTextLabel `'🔴'` → `'[color=red]错误[/color]'`
6. **`_on_export_problems` :745** — `"%d🔴 %d🟡"` → `"%d 错误, %d 警告"`

#### 验收标准

- [ ] `_get_theme_icon("StatusError")` → Texture2D（编辑器中）
- [ ] `git grep "🔴\|🟡" addons/fuse/editor/topology/fuse_topology.gd` → 无匹配
- [ ] 无问题节点分类图标保留（回归）
- [ ] 详情面板 BBCode 无 emoji

---

### 4.3 E3 — 跨 Trigger 变量关联标注

#### 实现文件

| 文件 | 变更类型 | 变更量 |
|------|---------|--------|
| `addons/fuse/editor/analysis/instruction_analyzer.gd` | **修改** — `build_topology` 增强 | ~80 行 |
| `addons/fuse/editor/topology/fuse_topology.gd` | **修改** — `_refresh_cross_references` + `_show_trigger_detail` | ~60 行 |
| `addons/fuse/tests/test_build_topology.gd` | **新增用例** — 7 个测试 | ~100 行 |

#### 改动点

1. **`build_topology` 全局变量收集重构** — `{vname: [{trigger_name, mode}]}` 结构
2. **新增 `variable_write_to_read` 条目** — 写者 → 变量 → 读者关联
3. **新增 `variable_write_to_write` 条目** — 竞态预警（多写 + 无互斥）
4. **新增 `topology.variable_analysis`** — 孤写/孤读标注
5. **`_has_mutex_protection(report) → bool`** — 关键词扫描 `lock` / `mutex` / `sync`
6. **`_refresh_cross_references` 渲染增强** — 📝 写-读箭头 + 🔥 竞态预警
7. **`_show_trigger_detail` 追加** — 当前 Trigger 的跨 Trigger 关联段

#### 验收标准

- [ ] `build_topology` 返回的 `cross_references` 含 `variable_write_to_read` + `variable_write_to_write` 类型
- [ ] 竞态检测：多 Trigger 写同一变量 + 无 `lock`/`mutex` → warning 条目
- [ ] `variable_analysis` 标注孤写/孤读
- [ ] `_refresh_cross_references` 渲染 `📝 T1 (写) → [var] → T2 (读)`
- [ ] 详情面板显示跨 Trigger 关联
- [ ] 信号关联零退化

#### E3 与 E1/E4 的合并说明

E3 在 Wave 1 中与 E1/E4 并行。合并时注意：
- `instruction_analyzer.gd`：E1 改 `analyze_problems` 区域，E3 改 `build_topology` 区域→**不同方法，git 自动合并无冲突**
- `fuse_topology.gd`：E4 改标注区域（`_build_tree_items` / `_create_trigger_tree_item`），E3 改跨引用区域（`_refresh_cross_references` / `_show_trigger_detail`）→**不同方法，git 自动合并无冲突**

---

### 4.4 E2 — 信号引用检测

#### 实现文件

| 文件 | 变更类型 | 变更量 |
|------|---------|--------|
| `addons/fuse/editor/analysis/instruction_analyzer.gd` | **修改** — 新增 3 个方法 | ~50 行 |
| `addons/fuse/tests/test_instruction_analyzer_problems.gd` | **新增用例** — 9 个测试 | ~120 行 |
| `addons/fuse/tests/test_instruction_analyzer_problems.tscn` | **修改** — 添加 `SignalButton` 节点 | 1 行 |

#### 改动点

1. **`_is_signal_prop(pname) → bool`** — 模式匹配 `signal_name` / `*_signal` / `emit_signal`
2. **`_extract_signal_refs(inst, report)`** — 指令级信号引用提取
3. **`_check_signal_references(instructions, scene_root, problems)`** — `has_signal` 检测
4. **`analyze_problems` 新增调用分支** — `_check_nodepath_targets` 之后插入

#### 验收标准

- [ ] `_extract_signal_refs(mock_emit_signal, {})` → `signal_refs` 含 1 条 entry
- [ ] 目标节点不存在的信号 → `severity: "error"` 的 problem
- [ ] `has_signal("pressed")` 存在 → 0 error
- [ ] `scene_root = null` → 跳过
- [ ] target_node 解析失败 → 跳过（由 E1 处理）
- [ ] 所有 9 个 E2 测试用例通过

#### 对 Wave 1 的依赖

- E2 需要在 `NodePathResolver.resolve_or_null`（E1 Wave 1 产物）完成后才能编译
- E2 需要在 `analyze_problems(scene_root)` 签名（E1 Wave 1 产物）基础上新增分支
- → **必须在 E1 合并后启动 E2**

---

### 4.5 E6 — 问题过滤

#### 实现文件

| 文件 | 变更类型 | 变更量 |
|------|---------|--------|
| `addons/fuse/editor/topology/fuse_topology.gd` | **修改** — 过滤控件 + 过滤逻辑 | ~80 行 |

#### 改动点

1. **常量** `FILTER_ALL = 0` / `FILTER_ERROR = 1` / `FILTER_NONE = 2`
2. **成员变量** `_filter_mode: int = FILTER_ALL`
3. **`_init()` 中新增 UI** — `Label("问题过滤: ")` + `OptionButton`（全部/仅错误/无）
4. **`_on_filter_changed(index)`** — 更新 `_filter_mode` 并调用 `refresh()`
5. **`_build_tree_items` 过滤** — `FILTER_NONE` 跳过标注；`FILTER_ERROR` 只标 error；`FILTER_ALL` 全标
6. **`_create_trigger_tree_item` 过滤** — 按过滤模式调整 `display_err` / `display_warn`
7. **详情面板和导出不变** — 全量问题

#### 验收标准

- [ ] Banner 新增 `OptionButton`（全部/仅错误/无）
- [ ] 仅错误模式 → error 标注，warning 不标（分类图标保留）
- [ ] 无模式 → 全树无问题标注
- [ ] Trigger 汇总文本随过滤模式调整
- [ ] 详情面板显示全量问题（不受过滤影响）
- [ ] 过滤模式在面板切换/刷新后保持
- [ ] 导出报告不受过滤影响

#### 对 Wave 1 的依赖

- E6 修改 `_build_tree_items` / `_create_trigger_tree_item` 的标注分支 → 与 E4 修改同一区域
- → **必须在 E4 合并后启动 E6**，否则标注代码基线与 E4 冲突
- 但 E6 的过滤控件 UI（OptionButton）与 E4 的 emoji 替换无关，可**提前实现 Phase 1（Banner 过滤控件）**，等 E4 合并后再实现 Phase 2-3（过滤逻辑）

---

### 4.6 E5 — Inspector 问题计数集成

#### 实现文件

| 文件 | 变更类型 | 变更量 |
|------|---------|--------|
| `addons/fuse/editor/fuse_inspector_plugin.gd` | **修改** — 5 处新增/修改 | ~80 行 |
| `addons/fuse/editor/analysis/instruction_analyzer.gd` | **修改** — 新增 `index_problems` 公开方法 | ~15 行 |
| `addons/fuse/editor/topology/fuse_topology.gd` | **修改** — `_index_problems` 改为调用公开方法 | ~5 行 |
| `addons/fuse/tests/test_instruction_analyzer_problems.gd` | **新增用例** — `_collect_insts` 相关测试 | ~40 行 |

#### 改动点

1. **`InstructionAnalyzer.index_problems(problems) → Dictionary`** — 从 `fuse_topology._index_problems` 提升为公开静态方法
2. **`FuseTopology._index_problems` 改为委托** — 调用 `InstructionAnalyzer.index_problems`
3. **`FuseInspectorPlugin._parse_end`** — `analyze_trigger` 后注入 `analyze_problems` + `index_problems`
4. **`_collect_insts_from_trigger_report`** — 从 report 收集 inst
5. **`_collect_insts_from_tree`** — 递归收集嵌套 tree
6. **`_add_dataflow_ui` 按钮角标** — `🔴N 🟡M` 后缀 + 字体颜色
7. **`_add_problems_section`** — 卡片内问题详情段

#### 验收标准

- [ ] `_parse_end` 选中 Trigger 时自动调用 `analyze_problems` + `index_problems`
- [ ] 数据流按钮文本显示 `🔴N 🟡M` 角标
- [ ] 有 error 时按钮颜色变红
- [ ] 展开卡片显示 "问题: 🔴N 错误 🟡M 警告" + 去重消息列表
- [ ] 无问题 Trigger → "问题: (无)"
- [ ] `_index_problems` 提升后 Topology 零退化

#### 对 Wave 1/Wave 2 的依赖

- 需要 `analyze_problems` 完整（含 E1 的 NodePath + E2 的信号检测）→ 至少 Wave 2 后
- `_index_problems` 提升可在 Wave 1 提前做（与 E1/E4/E3 同时），但 E5 的功能实现需等 Wave 2

---

## 5. 实施顺序建议

### 推荐合并策略

#### PR 1（Wave 1：E1 + E4 + E3）

```
分支: feat/static-analysis-wave-1
```

**三个并行修改在同一次 PR 中合并**，但开发时可分三个子分支或直接在一个分支上依次实现。

**合并顺序建议**（不分先后，互不冲突）：
1. `E4` 主题图标 — 最快见效，文件冲突最小
2. `E1` NodePath 检测 — 核心分析能力
3. `E3` 跨 Trigger 分析 — 较大改动

**同时可提前做**：将 `_index_problems` 从 `fuse_topology.gd` 提升到 `instruction_analyzer.gd` 的公开方法（E5 前置依赖），放在 Wave 1 的修改中包含。

---

#### PR 2（Wave 2：E2 + E6）

```
分支: feat/static-analysis-wave-2
```

在 Wave 1 合并后创建。

**实现顺序**：
1. `E2` 信号检测 — 在 E1 的 `analyze_problems` 基线上新增分支
2. `E6` 问题过滤 — 在 E4 的图标架构基线上新增过滤逻辑（注意标注区域与 E4 的代码对齐）

---

#### PR 3（Wave 3：E5）

```
分支: feat/static-analysis-wave-3
```

在 Wave 2 合并后创建。工作量最小，主要涉及 Inspector 插件。

---

### 可选：逐项提交（6 次 PR）

如果审查粒度要求每项独立：

```
1. feat(e4): 主题图标替代 emoji       ← 完全独立
2. feat(e1): NodePath 检测            ← 独立
3. feat(e3): 跨 Trigger 分析          ← 独立（与 E1 正交）
4. feat(e2): 信号引用检测             ← 依赖 E1
5. feat(e6): 问题过滤                 ← 依赖 E4（同区域）
6. feat(e5): Inspector 问题计数       ← 依赖 E1+E2
```

优点：每项独立 review。缺点：6 次 PR 开销较大。

---

## 6. 关键接口变更一览

以下为跨文件接口变更，需在实现时确保一致性：

### `InstructionAnalyzer.analyze_problems` 签名

```
旧: analyze_problems(instructions: Array) -> Dictionary
新: analyze_problems(instructions: Array, scene_root: Node = null) -> Dictionary
```

**调用方更新**：
- `FuseTopology.refresh()` — 传 `scene_root`
- `FuseInspectorPlugin._parse_end()` — 不传（Inspector 无 scene_root）
- 测试代码 — 选择传或不传

### `InstructionAnalyzer.index_problems` 新增

```gdscript
static func index_problems(problems: Array) -> Dictionary:
    # 返回 {by_inst: {int → Array}, summary: {errors: int, warnings: int}}
```

**调用方**：
- `FuseTopology._index_problems(problems)` → 委托给 `InstructionAnalyzer.index_problems`
- `FuseInspectorPlugin._parse_end()` → 调用 `InstructionAnalyzer.index_problems`

### `NodePathResolver.resolve_or_null` 新增

```gdscript
static func resolve_or_null(np_str: String, scene_root: Node) -> Node
```

**调用方**：
- `InstructionAnalyzer._check_nodepath_targets`（E1）
- `InstructionAnalyzer._check_signal_references`（E2）

### Problem 条目结构（最终形态）

```gdscript
{
    "severity": "error" | "warning",
    "message": String,                  # 人类可读消息
    "instruction_index": int,           # instructions 数组中的位置
    "inst": BaseInstruction,            # 指令引用（供 by_inst 索引）
    # 可选字段：
    "nodepath": String,                 # E1: 无法解析的 NodePath
    "signal_name": String,              # E2: 不存在的信号名
    "target_node_str": String,          # E2: 目标节点路径
}
```

---

## 7. 并行开发 — 分支管理方案

### 方案 A：单分支串行（推荐）

```
master
  └── feat/static-analysis-wave-1   (E1+E4+E3 → review → merge)
        └── feat/static-analysis-wave-2 (E2+E6 → review → merge)
              └── feat/static-analysis-wave-3 (E5 → review → merge)
```

优点：简单、无跨分支协调开销。适合单人开发。

### 方案 B：Git worktree 并行

```
master
  ├── feat/e1-nodepath (worktree 1)
  ├── feat/e3-cross-trigger (worktree 2)
  ├── feat/e4-theme-icons (worktree 3)
  └── (Wave 1 三项同步开发，完成后合并到 master)
```

优点：Wave 1 三项可并行写代码。适合多人协作或想完全独立时。E2 和 E6 同理。

---

## 8. 风险与对策

| 风险 | 影响 | 缓解 |
|------|------|------|
| E1 的 `analyze_problems` 签名变更影响 E3 的调用方 | E3 在 Wave 1 中也调用 `analyze_problems`？否—`build_topology` 不调 `analyze_problems`，零影响 | 确认调用关系 |
| E3 的 `_refresh_cross_references` 使用 emoji（📝🔥📤📥）与 E4 的 emoji 替换策略不一致 | E4 spec 明确只替换 🔴🟡（问题严重度），数据流箭头 emoji 保留，无冲突 | spec 边界清晰 |
| E6 的 `_build_tree_items` 修改时 E4 的图标代码已被覆盖 | E6 在 E4 之后实现，标注代码已使用主题图标，E6 直接在其上叠加过滤逻辑 | 实现顺序控制 |
| E5 的 `_index_problems` 提升后，Topology 原有行为变化 | 仅将私有方法改为委托调用，返回值格式不变，Topology 行为零变化 | 接口兼容 |
| 同一测试文件 `test_instruction_analyzer_problems.gd` 被 E1/E2/E5 多次修改 | 多组用例累加在同一文件中，git 合并可能冲突 | 按测试功能分组组织用例，每组用独立 `test_` 函数 |
| Wave 1 三项并行开发时，`fuse_topology.gd` 被 E3/E4 同时修改不同区域 | git 自动合并可处理（不同方法区域），预计无冲突 | 若担心，可在 `fuse_topology.gd` 中按方法物理顺序排列：`_build_tree_items` / `_create_trigger_tree_item`（E4+E6）在上，`_refresh_cross_references`（E3）在下 |

---

## 9. 测试策略总表

| 测试范围 | 测试文件 | 负责 spec | 用例数 | 类型 |
|---------|---------|----------|--------|------|
| NodePath 分辨率 | `test_instruction_analyzer_problems.gd` | E1 | 7 | 单元 |
| NodePath 检测 | `test_instruction_analyzer_problems.gd` | E1 | 3 | 单元 |
| 信号提取 + 检测 | `test_instruction_analyzer_problems.gd` | E2 | 9 | 单元 |
| 跨 Trigger 关联 | `test_build_topology.gd` | E3 | 7 | 单元 |
| 主题图标渲染 | 手动视觉验证 | E4 | 4 | 手动 |
| Inspector 集成 | 手动 + `test_instruction_analyzer_problems.gd` | E5 | 4 | 手动 + 单元 |
| 问题过滤 | 手动 | E6 | 7 | 手动 |

**回归测试**：每次 PR 需运行：
- `test_instruction_analyzer_problems.gd` — 全部
- `test_build_topology.gd` — 全部
- Topology 面板手动验证 — 含问题和无问题的场景各一个

---

## 10. 总结

| 波次 | 包含 | 预计 PR | 预计行数 | 是否可并行开发 |
|------|------|---------|---------|-------------|
| Wave 1 | E1 + E4 + E3 | 1 次合并 PR | ~450 | ✅ 三项互不冲突 |
| Wave 2 | E2 + E6 | 1 次合并 PR | ~250 | ✅ 两项互不冲突 |
| Wave 3 | E5 | 1 次合并 PR | ~150 | 单独 |
| **合计** | **6 项** | **3 次 PR** | **~850** | |

**核心建议**：
1. **先做 E4（主题图标）** — 改动最小、最独立、最易验证，立刻提升 UI 一致性
2. **E1 和 E3 可与 E4 并行** — 利用 Wave 1 的并行性
3. **E2 和 E6 依赖 Wave 1** — 必须在 E1/E4 落地后启动
4. **E5 最后做** — 依赖前面全部完成后才有完整内容
5. **提前提升 `_index_problems`** — 可在 Wave 1 中包含此接口重构，降低 E5 的耦合风险

---

*本计划批准后，按 Wave 1 → Wave 2 → Wave 3 顺序分三次 PR 实现。每项详细实现步骤见对应 spec。*
