# E6. 问题过滤 — 设计规格

> 关联 roadmap：[2026-07-09-static-analysis-enhancement-roadmap.md](2026-07-09-static-analysis-enhancement-roadmap.md)
> 关联 spec：[2026-07-09-static-analysis-integration-design.md](2026-07-09-static-analysis-integration-design.md)
> 关联 spec：[2026-07-09-e4-theme-icons.md](2026-07-09-e4-theme-icons.md)
> 日期：2026-07-10
> 状态：规划中
> 前置依赖：Topology 问题标注已落地（`fuse_topology.gd` 树节点红/黄标注 + Trigger 汇总 + 详情面板问题段）

---

## 1. 动机

随着 E1（NodePath 检测）、E2（信号检测）的引入，大场景可能产生大量问题——其中 `warning` 级问题（NodePath 无法解析、竞态预警）数量可能远多于 `error`，导致用户的核心关注点淹没在黄色标注海之中。

**当前 Topology 标注无差别**：
- `error`（🔴）和 `warning`（🟡）在树节点上同时渲染
- Trigger 汇总行 `"(%d🔴 %d🟡)"` 同时显示两者
- 用户无法过滤只看 error，或在修复过程中隐藏已确认的问题

E6 在 Topology banner 增加过滤控件，允许用户按严重度筛选问题视图，减少信息噪声。

---

## 2. 现状分析

### 2.1 当前 Banner 布局

`fuse_topology.gd` 的 `_init()`（`:25-42`）定义了顶部标题栏：

```
┌──────────────────────────────────────────────┐
│  Fuse 场景拓扑                   [刷新] [导出] │
└──────────────────────────────────────────────┘
```

- `title: Label` — 标题文本 "Fuse 场景拓扑"
- `spacer` — 弹性空白
- `_refresh_btn: Button` — "刷新"
- `export_btn: Button` — "导出问题报告"

**空间约束**：banner 是 `HBoxContainer`，已有 3 个子控件 + 1 个 spacer。加过滤控件需要在标题旁或右侧新增区域。

### 2.2 当前问题标注路径

> （审阅修订：下方流程描述的是 **E4 落地前** 的源码状态（`fuse_topology.gd:258-265` 当前实际行为——`set_text + set_custom_color`，无 `set_icon`）。E4（Wave 1，先于 E6）落地后此路径变更：emoji 文本前缀被 `set_icon(0, StatusError/StatusWarning)` 覆盖分类图标替代（见 E4 §3.2/§3.3）。E6（Wave 2）在 E4 落地后的状态上加过滤——本 spec §3.4/§3.5/§4 已按 E4 落地后前提编写。）

问题标注经过以下步骤（当前无过滤介入）：

```
refresh()
  → analyze_problems() → 产生 problems[]
  → _index_problems() → by_inst + summary

_create_trigger_tree_item(report)
  → 读取 report.problems.summary
  → 有 error/warning → 文本后缀 + icon + color

_build_tree_items(tree_data, report)
  → _find_problems_for_inst(inst, report) → inst_problems[]
  → has_error → 🔴 set_text + set_custom_color
  → has_warning → 🟡 set_text + set_custom_color

_on_item_selected()
  → 读取 report.problems
  → 追加问题 BBCode 到 _detail
```

### 2.3 当前缺口

- 问题标注是**全量展示**，没有任何过滤机制
- `_build_tree_items` 和 `_create_trigger_tree_item` 中 `has_error`/`has_warning` 是硬编码逻辑
- Banner 没有 UI 控件来切换过滤模式
- 不存在"过滤状态"的概念（filter state）——当前树构建后不保留过滤上下文
- 刷新时树重建（`:98 _tree.clear()`），过滤状态丢失——过滤状态需与面板生命周期共存

---

## 3. 设计

### 3.1 总览

```
Banner 新增过滤控件（OptionButton / 按钮组）
  └─ 过滤模式（filter_mode）：
       ├─ "全部"（默认）— 显示所有问题标注（当前行为）
       ├─ "仅错误" — 只标 error，warning 不标
       └─ "无" — 不标注任何问题（纯数据流视图）

树构建时：
  └─ _create_trigger_tree_item / _build_tree_items
       └─ 读取 self._filter_mode
       └─ 按过滤态决定是否标注节点
       └─ 非过滤项：保留分类图标 + 正常着色（无红色/黄色覆盖）

详情面板：
  └─ 仍显示完整问题列表（不过滤——详情是"当前选中项的全部信息"）

问题计数：
  └─ Trigger 汇总文本按过滤模式显示（审阅修订：与 E4 §3.3 中文标签一致）
  └─ 全部模式："(3 错误, 5 警告)"
  └─ 仅错误模式："(3 错误)"（warning 不计入文本）
  └─ 无模式：无后缀
```

### 3.2 过滤控件 UI

**在 Banner 标题右侧添加 `OptionButton`**：

```
┌──────────────────────────────────────────────────────────┐
│  Fuse 场景拓扑     [问题过滤: ▼全部▼]    [刷新] [导出]   │
└──────────────────────────────────────────────────────────┘
```

实现方式：

```gdscript
# 在 _init() 中，title 之后、spacer 之前新增：
var filter_label := Label.new()
filter_label.text = "  问题过滤: "
banner.add_child(filter_label)

var filter_btn := OptionButton.new()
filter_btn.add_item("全部", FILTER_ALL)       # item 0
filter_btn.add_item("仅错误", FILTER_ERROR)    # item 1
filter_btn.add_item("无", FILTER_NONE)         # item 2
filter_btn.selected = 0  # 默认 "全部"
filter_btn.item_selected.connect(_on_filter_changed)
banner.add_child(filter_btn)
```

常量定义：

```gdscript
const FILTER_ALL := 0
const FILTER_ERROR := 1
const FILTER_NONE := 2
```

间隔处理：当前 banner 已有 `spacer` 将标题和按钮分隔两侧。`filter_label` + `filter_btn` 放在标题之后、spacer 之前：

```
banner: [title] [filter_label] [filter_btn] [spacer] [refresh_btn] [export_btn]
```

### 3.3 过滤状态管理

面板成员变量：

```gdscript
var _filter_mode: int = FILTER_ALL

func _on_filter_changed(item_index: int) -> void:
    _filter_mode = item_index
    refresh()  # 重建树
```

- 过滤模式改变 → 触发 `refresh()` 重建整个树
- 树重建时 `_build_tree_items` 和 `_create_trigger_tree_item` 读取 `_filter_mode`
- `_filter_mode` 面板级持久——切换场景、切出面板再返回后仍保持（fuse_topology 作为主屏 Tab，在 EditorPlugin 生命周期内常驻）

### 3.4 `_build_tree_items` 按过滤标注

> （审阅修订：本节原叙事错误——spec 原声称"对照 `_set_item_icon:335` 行为顺序：先分类图标 → 再问题图标，E6 覆盖"，但**现有 `_build_tree_items:258-265` 只 `set_text + set_custom_color`，无 `set_icon`**，问题态根本没有 StatusError/StatusWarning 图标。事实上 **E4（Wave 1）才是首次引入问题图标**——E4 §3.2 把 `🔴/🟡 ` 文本前缀改为 `set_icon(0, StatusError/StatusWarning)`；E6（Wave 2，E4 之后）在 E4 已落地的图标基础上加过滤。下文按此修正后的前提重写。）

**前置事实**（E4 落地后、E6 落地前的状态）：

- `_set_item_icon:321-342` 为每个指令节点设置**分类图标**（`metadata.builtin_icon` 或 `_category_emoji` 回退）
- E4 §3.2 在 `_build_tree_items:258-265` 追加 **`set_icon(0, StatusError/StatusWarning)`**，**覆盖**分类图标（E4 §3.7 边界 + §4 接口契约均确认此覆盖是有意设计）
- 即：E4 之后，有问题节点 = 问题图标；无问题节点 = 分类图标

**E6 在此基础上加过滤**——过滤逻辑决定"是否应用 E4 的问题图标 + 着色 + 文本前缀"：

```gdscript
func _build_tree_items(parent_item: TreeItem, tree_data: Array, report: Dictionary) -> void:
    for node_info in tree_data:
        var inst = node_info.get("inst")
        # ... 现有逻辑：创建 item、set_text、_set_item_icon（分类图标） ...

        # 按过滤模式标注问题（E6 修改，叠加在 E4 的 set_icon 之上）
        var inst_problems := _find_problems_for_inst(inst, report)
        var has_problem_color := false

        if _filter_mode != FILTER_NONE and not inst_problems.is_empty():
            var has_error := false
            var has_warning := false
            for p in inst_problems:
                if p.get("severity") == "error":
                    has_error = true
                elif p.get("severity") == "warning":
                    has_warning = true

            # 分支 1：error 优先（FILTER_ALL + FILTER_ERROR 两模式下，只要有 error 都标）
            # （审阅修订：澄清原 elif 注释易误读——has_error 分支独立，不受过滤模式约束）
            if has_error:
                # FILTER_ALL / FILTER_ERROR：都标 error（E4 提供的 StatusError 图标 + 着色）
                item.set_custom_color(0, Color(1.0, 0.3, 0.3))
                item.set_icon(0, _get_theme_icon("StatusError"))
                has_problem_color = true
            # 分支 2：warning 仅在 FILTER_ALL 且无 error 时才标
            # （审阅修订：原 elif 注释 "elif has_warning and FILTER_ALL" 易误读为 FILTER_ERROR 也走 elif）
            elif has_warning and _filter_mode == FILTER_ALL:
                item.set_custom_color(0, Color(1.0, 0.8, 0.3))
                item.set_icon(0, _get_theme_icon("StatusWarning"))
                has_problem_color = true
            # FILTER_ERROR + 仅 warning：不进 set_icon，分类图标保留（E4 的 _set_item_icon 结果不变）
            # FILTER_NONE：外层 if 已跳过

        # 分支颜色（仅当未因问题着色时）
        if is_branch and not has_problem_color:
            item.set_custom_color(0, Color(1.0, 0.65, 0.1))
        # ...
```

> 注：上面用 E4 引入的 `_get_theme_icon("StatusError")` 封装（替代直接 `EditorInterface.get_editor_theme().get_icon(...)`），与 E4 §3.6 一致。E6 不重复 emoji 文本前缀——E4 已移除 `"🔴 "/"🟡 "` 前缀，指令名完整显示。

**关键行为变化**：

| 过滤模式 | error 标注 | warning 标注（无 error） | 无问题节点 |
|---------|-----------|--------------------------|-----------|
| 全部（FILTER_ALL） | 红色 + StatusError 图标（覆盖分类） | 黄色 + StatusWarning 图标（覆盖分类） | 分类图标保留 |
| 仅错误（FILTER_ERROR） | 红色 + StatusError 图标（覆盖分类） | 不标（分类图标保留，无着色） | 分类图标保留 |
| 无（FILTER_NONE） | 不标（分类图标保留） | 不标（分类图标保留） | 分类图标保留 |

> **🟡 行为变更取舍：E6 过滤如何作用于 E4 引入的问题图标**
>
> （审阅修订：取舍的命题已变——不是"E6 是否首次引入问题图标"，而是"E6 过滤如何叠加在 E4 已有的图标覆盖行为之上"。）
>
> **现状**（E4 落地后）：`_set_item_icon:321-342` 已为每个指令节点设置分类图标（`metadata.builtin_icon` 或 `_category_emoji` 回退）；E4 §3.2 在此之后调用 `set_icon(0, StatusError/StatusWarning)` **覆盖**分类图标（E4 §3.7 + §4 接口契约确认此覆盖是有意设计）。
>
> **E6 的影响**：E6 决定"是否调用 E4 的覆盖逻辑"——过滤跳过的节点根本不调用 `set_icon`，分类图标自然保留。
>
> **取舍方案**（需在实现阶段决定）：
> | 方案 | FILTER_ALL | FILTER_ERROR | FILTER_NONE | 优点 | 缺点 |
> |------|-----------|--------------|-------------|------|------|
> | A（与 E4 一致） | error+warning 均覆盖 | 仅 error 覆盖，warning 跳过 | 不覆盖 | 与 E4 覆盖语义一致，实现最简（条件分支即可） | FILTER_ERROR 模式下 warning 节点"看不出有 warning" |
> | B（warning 仅着色不覆盖图标） | error 覆盖；warning 仅 set_custom_color | 仅 error 覆盖 | 不覆盖 | warning 节点保留分类信息 | FILTER_ALL 下 warning 视觉弱化（只有色，无图标），与 E4 退化 |
> | C（全部模式覆盖，但详情查分类） | 同 A | 同 A | 同 A | 同 A | 同 A |
>
> **本 spec 推荐方案 A**：（审阅修订——方案 C 的"详情可查分类"是 E4 已有的设计，A 与 C 实际等价，统一为 A）。理由：
> 1. 保持与 E4 已落地的覆盖语义一致——E6 不重新决策"是否覆盖"，只决策"是否标注"
> 2. FILTER_ERROR 模式下 warning 不标是有意为之（用户明确说"只看 error"），不应再暗示有 warning
> 3. 分类信息在详情面板（`_show_instruction_detail:499-503`）中已显示 `分类: <category_key>`，丢失树节点分类图标的损失可控
>
> 若社区反馈 FILTER_ALL 下分类信息丢失严重，可退回方案 B（warning 节点不覆盖图标），但需同步修改 E4 §3.2 保持一致。

### 3.5 `_create_trigger_tree_item` 按过滤标注

Trigger 汇总行的问题计数文本和着色也受过滤模式影响：

```gdscript
func _create_trigger_tree_item(parent_item: TreeItem, report: Dictionary) -> void:
    # ... 现有逻辑：创建 t_item、set_text ...

    var probs: Dictionary = report.get("problems", {"summary": {"errors": 0, "warnings": 0}})
    var n_err: int = probs.get("summary", {}).get("errors", 0)
    var n_warn: int = probs.get("summary", {}).get("warnings", 0)

    # 按过滤模式调整计数
    var display_err := 0
    var display_warn := 0
    if _filter_mode == FILTER_ALL:
        display_err = n_err
        display_warn = n_warn
    elif _filter_mode == FILTER_ERROR:
        display_err = n_err
        display_warn = 0  # warning 不计入
    elif _filter_mode == FILTER_NONE:
        display_err = 0
        display_warn = 0

    var has_problems := display_err > 0 or display_warn > 0
    if has_problems:
        # 构建过滤后的后缀文本（审阅修订：用 E4 §3.3 已统一的中文标签，不回退到 🔴/🟡 emoji）
        var suffix_parts := PackedStringArray()
        if display_err > 0:
            suffix_parts.append("%d 错误" % display_err)
        if display_warn > 0:
            suffix_parts.append("%d 警告" % display_warn)
        t_item.set_text(0, t_item.get_text(0) + "  (%s)" % ", ".join(suffix_parts))

        # 着色 + E4 提供的 StatusError/StatusWarning 图标（用 _get_theme_icon 封装）
        if display_err > 0:
            t_item.set_custom_color(0, Color(1.0, 0.3, 0.3))
            t_item.set_icon(0, _get_theme_icon("StatusError"))
        elif display_warn > 0:
            t_item.set_custom_color(0, Color(1.0, 0.8, 0.3))
            t_item.set_icon(0, _get_theme_icon("StatusWarning"))
```

### 3.6 详情面板问题段不过滤

`_on_item_selected`（`:407-418`）中的问题段**保持全量显示**：

```gdscript
# 详情面板始终显示该 Trigger/指令的完整问题列表
# 不过滤——用户已经定位到具体项，需要完整信息
```

设计依据：
- 过滤是导航辅助（缩小关注范围），详情是诊断信息（完整问题）
- 用户通过过滤找到有问题的 Trigger，点开详情时应该看到该 Trigger 的全部问题，而非过滤后的子集
- 避免"过滤模式下详情不完整"导致的认知混乱

### 3.7 导出报告不受过滤影响

`_on_export_problems`（`:733-757`）导出**全量问题**，不受过滤模式影响：
- 导出是审计/离线查看场景，用户预期看到全部问题
- 过滤是交互辅助，不影响持久化报告

### 3.8 过滤模式记忆

`_filter_mode` 是面板成员变量，在当前面板生命周期内保持：
- 切换到其他 Tab（Event Graph、Variable Watcher）再切回 → `_filter_mode` 保留
- `refresh()` 被调用时（用户点刷新/过滤模式变更）→ `_filter_mode` 保留
- 编辑器重启/场景重载 → `_filter_mode` 重置为 `FILTER_ALL`（默认值）

**不持久化**到 `EditorSettings` 或 `ProjectSettings`——此功能是个人偏好，但生命周期短于编辑器设置；用户若有持久化需求可后续扩展。

---

## 4. 接口契约

### 新增常量

```gdscript
const FILTER_ALL := 0
const FILTER_ERROR := 1
const FILTER_NONE := 2
```

### 新增成员变量

```gdscript
var _filter_mode: int = FILTER_ALL
```

### 新增信号连接

```gdscript
filter_btn.item_selected.connect(_on_filter_changed)
```

### `_on_filter_changed` 新增

```gdscript
func _on_filter_changed(item_index: int) -> void:
    _filter_mode = item_index
    refresh()
```

### 无公开 API 变更

所有修改在 `fuse_topology.gd` 内部——对 `InstructionAnalyzer`、其他编辑器面板、测试框架零影响。

### 行为矩阵

（审阅修订：行为矩阵中已删除 "🔴/🟡 前缀"——E4 已移除文本前缀，改用 StatusError/StatusWarning 图标。E6 的过滤仅决定"是否标注"，标注形态沿用 E4。）

| 场景 | 全部模式 | 仅错误模式 | 无模式 |
|------|---------|-----------|-------|
| 指令有 error | 红色 + StatusError 图标（覆盖分类图标） | 红色 + StatusError 图标（覆盖分类图标） | 不标注（分类图标保留） |
| 指令有 warning（无error） | 黄色 + StatusWarning 图标（覆盖分类图标） | 不标注（分类图标保留） | 不标注（分类图标保留） |
| 指令有 error + warning | 红色 + StatusError（warning 被忽略） | 红色 + StatusError（warning 被忽略） | 不标注（分类图标保留） |
| Trigger 汇总（有 error + warning） | `"(3 错误, 5 警告)"` 红色 + StatusError 图标 | `"(3 错误)"` 红色 + StatusError 图标 | 无后缀、无图标 |
| Trigger 汇总（仅 warning） | `"(5 警告)"` 黄色 + StatusWarning 图标 | 无后缀、无图标 | 无后缀、无图标 |
| 详情面板问题段 | 完整问题列表 | 完整问题列表 | 完整问题列表 |
| 导出报告 | 全量 | 全量 | 全量 |

---

## 5. 测试策略

### 5.1 手动测试

**`test_filter_all_shows_all`**
- 场景含 error + warning
- 过滤 = 全部
- 预期：error 和 warning 均标注，Trigger 汇总显示 `"N 错误, M 警告"`（审阅修订：与 E4 §3.3 中文标签一致，不再用 emoji）

**`test_filter_error_only`**
- 场景含 error + warning
- 过滤 = 仅错误
- 预期：error 标注，warning 不标，Trigger 汇总仅显示 `"N 错误"`（无 warning 计数）

**`test_filter_error_search_by_warning`**
- 场景仅含 warning
- 过滤 = 仅错误
- 预期：全树无问题标注，Trigger 汇总无后缀

**`test_filter_none_hides_all`**
- 场景含 error + warning
- 过滤 = 无
- 预期：全树无任何问题标注

**`test_filter_preserved_across_refresh`**
- 切换过滤到"仅错误"
- 点刷新按钮
- 预期：刷新后过滤模式保持为"仅错误"，标注行为对应

**`test_detail_shows_all_problems_under_filter`**
- 过滤 = 仅错误
- 选中同时有 error + warning 的指令
- 预期：详情面板显示完整的 error + warning 列表

**`test_export_unaffected_by_filter`**
- 过滤 = 无
- 导出报告
- 预期：报告内容包含全量问题

### 5.2 单元测试

**`test_filter_mode_enum_values`**
- 验证 `FILTER_ALL == 0`、`FILTER_ERROR == 1`、`FILTER_NONE == 2`

**`test_filter_on_filter_changed_triggers_refresh`**
- 验证 `_on_filter_changed(index)` 调用后 `_filter_mode` 更新 + `refresh()` 被调用

### 5.3 视觉验证

- 打开含 error + warning 的场景
- 在三个过滤模式间切换 → 树节点标注实时变化
- 确认 OptionButton 显示当前过滤模式文本
- 确认面板切 Tab 再返回后过滤模式保留

### 5.4 回归

- 默认全部模式 → 与 E4 落地后的全标注行为完全一致（审阅修订：原描述 "E4 之前" 错误——E6 的"全部"基线就是 E4 已有的图标覆盖行为）
- 无问题的场景 → 三个过滤模式下的行为一致（均无标注，分类图标保留）
- `set_selectable`、`set_metadata`、`_set_item_icon`（分类图标）不被过滤逻辑破坏
- 分支着色（`_branch_color`）在过滤模式下不受影响

---

## 6. 实现步骤

### Phase 1：Banner 过滤控件

**文件**: `addons/fuse/editor/topology/fuse_topology.gd`

1. 新增常量 `FILTER_ALL` / `FILTER_ERROR` / `FILTER_NONE`
2. 新增成员变量 `_filter_mode: int = FILTER_ALL`
3. `_init()` 中 title 之后、spacer 之前添加：
   - `Label` "问题过滤: "
   - `OptionButton` 三个选项
4. 新增 `_on_filter_changed(item_index: int) -> void`

**验收**：
- [ ] Banner 显示过滤下拉框，三个选项
- [ ] 默认选中 "全部"
- [ ] 切换选项 → `_filter_mode` 更新
- [ ] `_on_filter_changed` 调用 `refresh()`

### Phase 2：`_build_tree_items` 过滤逻辑

**文件**: `addons/fuse/editor/topology/fuse_topology.gd`

1. 修改 `_build_tree_items` 的问题标注分支：
   - `FILTER_NONE` → 跳过所有问题标注
   - `FILTER_ERROR` → 只标注 error，warning 不标
   - `FILTER_ALL` → 标注所有问题（当前行为）
2. 确保 warning 被跳过时，节点的 `_set_item_icon` 分类图标不被覆盖

**验收**：
- [ ] 全部模式 → error + warning 均标注
- [ ] 仅错误模式 → error 标注，warning 不标（分类图标保留）
- [ ] 无模式 → 全不标
- [ ] 分支颜色不受过滤影响

### Phase 3：`_create_trigger_tree_item` 过滤逻辑

**文件**: `addons/fuse/editor/topology/fuse_topology.gd`

1. 修改 Trigger 汇总计数逻辑：
   - 按 `_filter_mode` 调整 `display_err` / `display_warn`
   - 构建后缀文本时只使用 `display` 版本的数字

**验收**：
- [ ] 全部模式 → `"(N 错误, M 警告)"`（审阅修订：与 E4 §3.3 中文标签一致）
- [ ] 仅错误模式 → warning 不显示，只显示 `"(N 错误)"`
- [ ] 无模式 → 无后缀

### Phase 4：验证

1. 打开含 error + warning 的场景
2. 切换三个模式 → 观察树节点和 Trigger 汇总变化
3. 选中节点 → 确认详情面板显示完整问题（不受过滤影响）
4. 导出报告 → 确认全量问题
5. 切 Tab 再切回 → 过滤模式保持

---

## 7. 不做（YAGNI）

| 项 | 原因 |
|----|------|
| **三级过滤（error / warning / suggestion）** | 当前 `analyze_problems` 只产出 `error` 和 `warning`，suggestion 尚未推出。`FILTER_ALL / FILTER_ERROR / FILTER_NONE` 足够了——未来有 suggestion 时再加一个 OptionButton item 即可 |
| **多选过滤（同时显示 error + suggestion 但不显示 warning）** | UI 复杂度高（需要 CheckBox 组），无明确用户需求 |
| **按指令类别过滤** | 分类过滤偏离"问题过滤"目标——那是"指令过滤"的独立功能 |
| **过滤状态持久化到 EditorSettings** | 值太小、生命周期不对——过滤器是个人的临时偏好 |
| **搜索/模糊匹配问题消息** | 问题数量不多（通常 < 50），用户可目视扫描 |
| **过滤后淡化而非隐藏** | Godot TreeItem 没有"淡化"效果（`set_custom_color` 的 alpha）——且淡化的视觉与"无问题"状态区别不清 |
| **过滤时树节点折叠** | Trigger 的问题只是节点属性，折叠操作方向相反（用户展开/折叠看详情），与过滤正交 |

---

## 8. 风险

| 风险 | 影响 | 缓解 |
|------|------|------|
| Banner 空间不足（标题 + 过滤 + spacer + 两个按钮） | 窗口窄时过滤控件可能被截断 | `HBoxContainer` 的 `size_flags_horizontal` 自动压缩控件——过滤控件至少保留 "过滤: ▼" 的宽度；若太窄，spacer 空间被压缩 |
| `OptionButton` 的 `item_selected` 信号在选中相同 item 时不触发 | 用户选择当前已选的选项不会刷新树 | 这是正确行为——同一过滤模式不重复刷新 |
| `refresh()` 被过滤切换频繁调用（用户快速连击） | 树重建频繁 | `refresh()` 完全同步 O(N)，大场景 N ≤ 200 节点，单次重建 < 10ms，无性能问题 |
| `_filter_mode` 被其他代码意外修改 | 标注行为不一致 | 只有 `_on_filter_changed` 和 `_init` 写入 `_filter_mode`，其余地方只读——封装在面板内部 |
| 详情面板显示全量问题与过滤状态不一致（用户困惑"明明过滤了怎么还有 warning"） | 用户误以为过滤失效 | 在详情段可选加一行 `[color=gray](过滤模式: 仅错误)[/color]` 提示当前过滤态——降低认知摩擦 |

---

## 9. 验收标准

- [ ] Banner 新增 `OptionButton` 过滤控件（全部 / 仅错误 / 无）
- [ ] 全部模式 → 所有问题标注（审阅修订：与 E4 落地后的行为一致——error/warning 节点显示 StatusError/StatusWarning 图标 + 着色）
- [ ] 仅错误模式 → error 标注，warning 不标（分类图标保留）
- [ ] 无模式 → 整个树无问题标注
- [ ] Trigger 汇总文本随过滤模式调整（warning 计数对应增减）
- [ ] 详情面板完整显示全量问题（不受过滤影响）
- [ ] 导出报告完整导出全量问题
- [ ] 过滤模式在面板切换/刷新后保持
- [ ] 回归：全部模式下行为与 E4 落地后一致
- [ ] Roadmap 中 E6 标记为 "spec 完成"

---

## 10. 修改文件清单

| 文件 | 变更类型 | 说明 |
|------|---------|------|
| `addons/fuse/editor/topology/fuse_topology.gd` | 修改 | Banner 新增 `OptionButton` 过滤控件 + 常量 + `_filter_mode` 成员 + `_on_filter_changed`；`_build_tree_items` + `_create_trigger_tree_item` 按过滤态标注 |

仅修改一个文件。所有改动在 `fuse_topology.gd` 内部——对 `InstructionAnalyzer`、`fuse_inspector_plugin`、测试等零影响。

---

*本 spec 批准后，下一步：invoke writing-plans 生成实现计划。*
