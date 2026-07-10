# E4. Godot 主题图标替代 emoji — 设计规格

> 关联 roadmap：[2026-07-09-static-analysis-enhancement-roadmap.md](2026-07-09-static-analysis-enhancement-roadmap.md)
> 关联 spec：[2026-07-09-static-analysis-integration-design.md](2026-07-09-static-analysis-integration-design.md)
> 关联 spec：[2026-07-09-e1-nodepath-detection.md](2026-07-09-e1-nodepath-detection.md)
> 日期：2026-07-09
> 状态：规划中
> 前置依赖：Topology 标注流程已落地（`fuse_topology.gd` 红/黄标注 + 计数）

---

## 1. 动机

Topology 面板使用 🔴🟡 emoji 标注问题严重度。emoji 在不同平台、字体、缩放比例下渲染不一致——Windows 上 🔴 可能显示为异形圆，Linux 上 🟡 可能显示为空心框，且 emoji 与 Godot 编辑器原生图标（`StatusError` / `StatusWarning`）视觉风格不统一。

**用户感知的**：Fuse 面板的图标"不像 Godot 自带的"——与 Godot 输出面板、Script Editor 的报错/警告图标风格割裂。

**目标**：用 `EditorInterface.get_editor_theme().get_icon("StatusError" / "StatusWarning", "EditorIcons")` 替代所有 🔴🟡 文本 emoji，与编辑器原生观感一致。

---

## 2. 现状分析

### 2.1 emoji 使用全景

当前 `fuse_topology.gd` 中 🔴🟡 共出现 **7 处**，分布在 3 个语义上下文中：

| # | 位置 | 行号 | 用法 | 形态 |
|---|------|------|------|------|
| 1 | `_create_trigger_tree_item` | 179 | Trigger 汇总文本 `"  (%d🔴 %d🟡)"` | 文本拼接 |
| 2 | `_create_trigger_tree_item` | 182 | Trigger 汇总文本 `"  (%d🟡)"` | 文本拼接 |
| 3 | `_build_tree_items` | 260 | 指令文本前缀 `"🔴 " + item.get_text(0)` | 文本前缀 |
| 4 | `_build_tree_items` | 264 | 指令文本前缀 `"🟡 " + item.get_text(0)` | 文本前缀 |
| 5 | `_on_item_selected` | 412 | RichTextLabel BBCode `"问题（%d🔴 %d🟡）"` | BBCode 文本 |
| 6 | `_on_export_problems` | 745 | 导出文件 `"%d🔴 %d🟡"` | 文本文件 |
| 7 | `_on_export_problems` | 749 | 导出文件 `"%d 错误, %d 警告"` | **此条已无 emoji** |

注意第 7 条其实已使用中文文本（`"合计: %d 错误, %d 警告"`），与第 6 条（`"%d🔴 %d🟡"`）不一致——是之前遗留的手动修正。

### 2.2 当前图标系统

`_set_item_icon`（:321-342）已实现 **两层图标策略**：

```
gdscript
# 优先：metadata.builtin_icon → theme.get_icon(name, "EditorIcons")
# 回退：_category_emoji() → emoji 文本前缀
```

该方法是**指令分类图标**（按指令类别显示对应图标），与**问题严重度图标**（🔴🟡）是两条独立的视觉通道：

| 通道 | 负责方法 | 语义 | 图标源 |
|------|---------|------|--------|
| 分类 | `_set_item_icon` | 指令类型 | builtin_icon / emoji |
| 严重度 | `_build_tree_items` :258-265 | 问题级别 | 🔴🟡 emoji |

两者互不干扰——分类图标通过 `set_icon(0, texture)` 设置，严重度通过 `set_text(0, "🔴 " + text)` 文本前缀实现。**当前问题严重度无专用图标槽位**，是文本 hack。

### 2.3 Godot 主题图标 API

Godot 4.x `EditorInterface` 提供标准主题图标：

```gdscript
var theme := EditorInterface.get_editor_theme()
var error_icon: Texture2D = theme.get_icon("StatusError", "EditorIcons")
var warn_icon: Texture2D = theme.get_icon("StatusWarning", "EditorIcons")
```

此 API 已在本项目 `plugin.gd:92` 中用于获取 `VisualShader` 图标——验证为可用模式。

`StatusError` / `StatusWarning` 是 Godot 编辑器中错误/警告的标准图标，尺寸 16×16，在输出面板、Script Editor 问题列表中统一使用。

---

## 3. 设计

### 3.1 总览

将 7 处 emoji 用法按 UI 组件分类为三个替换策略：

| UI 组件 | 位置 | 替换方案 |
|---------|------|---------|
| **Tree item（列 0 图标）** | `_build_tree_items` :260/:264 | `set_icon(0, StatusError/Warning)` 覆盖分类图标 |
| **Tree item（列 0 文本）** | `_create_trigger_tree_item` :179/:182 | 数字计数仅保留文本（无 emoji），同时列 0 `set_icon` 附带 severity 图标 |
| **RichTextLabel BBCode** | `_on_item_selected` :412 | 用中文文本 `"错误"`/`"警告"` 替代 emoji，结合 `[color]` 标签保留色标 |
| **导出文件（纯文本）** | `_on_export_problems` :745 | 统一为 `"%d 错误, %d 警告"`（与第 749 行一致） |

**流程图**：

```
标注处（severity 判定）
  ├─ instruction item → item.set_icon(0, StatusError/Warning)
  │                      （覆盖 _set_item_icon 设的分类图标）
  ├─ trigger item     → item.set_icon(0, StatusError/Warning)
  │                      item.set_text(0, ... + "  (N errors, M warnings)")
  ├─ detail panel     → 中文文本 + [color] BBCode
  └─ export report    → 中文文本（统一为已存在的 "错误"/"警告" 格式）
```

### 3.2 `_build_tree_items` 中指令节点严重度图标

**现状**（:258-265）：

```gdscript
if has_error:
    item.set_custom_color(0, Color(1.0, 0.3, 0.3))
    item.set_text(0, "🔴 " + item.get_text(0))
    has_problem_color = true
elif has_warning:
    item.set_custom_color(0, Color(1.0, 0.8, 0.3))
    item.set_text(0, "🟡 " + item.get_text(0))
    has_problem_color = true
```

**改为**：

```gdscript
if has_error:
    item.set_custom_color(0, Color(1.0, 0.3, 0.3))
    item.set_icon(0, _get_theme_icon("StatusError"))
    has_problem_color = true
elif has_warning:
    item.set_custom_color(0, Color(1.0, 0.8, 0.3))
    item.set_icon(0, _get_theme_icon("StatusWarning"))
    has_problem_color = true
```

- `set_icon(0, texture)` 覆盖 `_set_item_icon` 在此前设置的分类图标——严重度优先级高于分类，用户应先关注问题指令
- 不再修改 `set_text`——`"🔴 "` 文本前缀消除，指令名完整显示
- `set_custom_color` 保留（着色与图标双重提示，色盲友好）

### 3.3 `_create_trigger_tree_item` 中 Trigger 汇总

**现状**（:177-182）：

```gdscript
if n_err > 0:
    t_item.set_custom_color(0, Color(1.0, 0.3, 0.3))
    t_item.set_text(0, t_item.get_text(0) + "  (%d🔴 %d🟡)" % [n_err, n_warn])
elif n_warn > 0:
    t_item.set_custom_color(0, Color(1.0, 0.8, 0.3))
    t_item.set_text(0, t_item.get_text(0) + "  (%d🟡)" % n_warn)
```

**改为**：

```gdscript
if n_err > 0:
    t_item.set_custom_color(0, Color(1.0, 0.3, 0.3))
    t_item.set_text(0, t_item.get_text(0) + "  (%d %s, %d %s)" % [n_err, _severity_label("error"), n_warn, _severity_label("warning")])
    t_item.set_icon(0, _get_theme_icon("StatusError"))
elif n_warn > 0:
    t_item.set_custom_color(0, Color(1.0, 0.8, 0.3))
    t_item.set_text(0, t_item.get_text(0) + "  (%d %s)" % [n_warn, _severity_label("warning")])
    t_item.set_icon(0, _get_theme_icon("StatusWarning"))
```

- 文本中的 emoji 替换为中文标签（如 `"3 错误, 2 警告"`）
- Trigger item 列 0 图标设置为 severity 图标（Trigger 本身没有分类图标，`set_icon` 是空闲的）
- `set_custom_color` 保留

### 3.4 `_on_item_selected` 详情面板

**现状**（:412）：

```gdscript
_detail.append_text("\n[b]问题（%d🔴 %d🟡）:[/b]\n" % [s.get("errors", 0), s.get("warnings", 0)])
```

**改为**：

```gdscript
var err_count := s.get("errors", 0)
var warn_count := s.get("warnings", 0)
var parts := PackedStringArray()
if err_count > 0:
    parts.append("[color=red]%d 错误[/color]" % err_count)
if warn_count > 0:
    parts.append("[color=yellow]%d 警告[/color]" % warn_count)
_detail.append_text("\n[b]问题（%s）:[/b]\n" % ", ".join(parts))
```

- Godot 的 `RichTextLabel` BBCode 不支持在文本中内联 `Texture2D`——无法像 TreeItem 那样 `set_icon`
- 用中文文本 + `[color]` 标签替代 emoji，保留色标语义
- 当只有 warning 时显示 `"问题（2 警告）"`，两者都有时显示 `"问题（1 错误, 2 警告）"`
- 零错误且零 warning 时不显示（与目前的逻辑一致——`s.get("errors") > 0 or s.get("warnings") > 0` 时才 append）

### 3.5 `_on_export_problems` 导出文件

**现状**（:745）：

```gdscript
lines.append("%s (%s): %d🔴 %d🟡" % [t.get("trigger_name", "?"), ...])
```

**改为**：

```gdscript
lines.append("%s (%s): %d 错误, %d 警告" % [t.get("trigger_name", "?"), ...])
```

- 统一为中文文本，与同方法的第 749 行 `"合计: %d 错误, %d 警告"` 保持一致
- 无 icon 问题（纯文本文件）

### 3.6 辅助方法：`_get_theme_icon` 与 `_severity_label`

新增两个辅助方法，集中管理主题图标获取和严重度标签文本：

```gdscript
## 获取编辑器主题图标，不存在时返回 null
func _get_theme_icon(icon_name: String) -> Texture2D:
    var theme := EditorInterface.get_editor_theme()
    if theme and theme.has_icon(icon_name, "EditorIcons"):
        return theme.get_icon(icon_name, "EditorIcons")
    return null


## 严重度中文标签（用于替代 emoji 文本）
static func _severity_label(p_severity: String) -> String:
    match p_severity:
        "error": return "错误"
        "warning": return "警告"
        "suggestion": return "建议"
        _: return p_severity
```

- `_get_theme_icon` 封装 `has_icon` 安全检测，避免 `get_icon` 在缺失主题图标时 crash
- `_severity_label` 是 `static` 方法，可在 `_on_export_problems` 中直接调用（无实例依赖）；同时兼容未来 E6 过滤功能中的标签复用

### 3.7 边界情况处理

| 场景 | 行为 |
|------|------|
| `EditorInterface.get_editor_theme()` 返回 `null`（编辑器初始化未完成） | `_get_theme_icon` 中 `theme` 为 `null` → 返回 `null` → `set_icon(0, null)` 清空图标但有 fallback |
| 主题缺失 `StatusError` / `StatusWarning` 图标（自定义主题） | `has_icon` 返回 false → `_get_theme_icon` 返回 `null` → `set_icon(0, null)` 相当于清除但保留了 `set_custom_color` 着色 |
| `set_icon(0, null)` 时之前已有分类图标 | `set_icon` 传入 `null` 会清空当前图标，但调用方（:260/:264）是在 `_set_item_icon`（:240）之后才设置 severity 图标——正常流程无覆盖后清空的问题 |
| 既有 error 又有 warning 的指令 | 现有逻辑 `has_error` 优先于 `has_warning`（:258 `if has_error:` → `elif has_warning:`），E4 保持此优先级 |
| TreeItem 的 column 0 宽度不足容纳图标 + 文本 | Tree 的 column 0 已设 `set_column_expand(0, true)`（:58），图标与文本共存无需额外调整 |
| 导出报告在无编辑器环境运行（CI） | `_on_export_problems` 在 `refresh` 后才会被触发，而 `refresh` 开头已检测 `ClassDB.class_exists("EditorInterface")`——导出场景不可能发生在无编辑器环境 |
| 0 个错误且 0 个警告 | Trigger 汇总不调用 severity 图标设定（`if n_err > 0` / `elif n_warn > 0` 条件不满足），`set_icon` 不会被调用 |
| 仅 warning 无 error | 158-159 行 181-182 行走 `elif n_warn > 0` 分支，`set_icon(0, StatusWarning)` + 单计数文本 |

---

## 4. 接口契约

### 无外部接口变更

E4 的修改全部在 `fuse_topology.gd` 内部：

- `_get_theme_icon(icon_name: String) -> Texture2D` — 新增私有方法
- `_severity_label(p_severity: String) -> String` — 新增私有静态方法
- 无公开签名变更，无 export 变量，无信号新增

### `_set_item_icon` 行为变化

| 方面 | 变化 |
|------|------|
| 输入参数 | 不变：`(item: TreeItem, inst)` |
| 图标优先级 | 不变：metadata.builtin_icon → emoji 回退 |
| 与 severity 的关系 | E4 新增的 severity 图标在 `_set_item_icon` **之后**设置并覆盖——`_set_item_icon` 无感知 |

### 文本格式变化

| 场景 | 旧格式 | 新格式 |
|------|--------|--------|
| Trigger 汇总（双 severity） | `"TriggerName (3🔴 2🟡)"` | `"TriggerName (3 错误, 2 警告)"` |
| Trigger 汇总（仅 warning） | `"TriggerName (2🟡)"` | `"TriggerName (2 警告)"` |
| 指令文本前缀 | `"🔴 SetPosition"` | `"SetPosition"`（文本前缀移除） |
| Detail 面板标题 | `"问题（1🔴 2🟡）"` | `"问题（[color=red]1 错误[/color], [color=yellow]2 警告[/color]）"` |
| 导出报告行 | `"Trigger: 1🔴 2🟡"` | `"Trigger: 1 错误, 2 警告"` |
| 导出报告合计行 | `"合计: 3 错误, 5 警告"` | 不变（已为中文） |

---

## 5. 测试策略

### 5.1 视觉验证（手动，Topology 刷新后观察）

**`test_theme_icon_missing`**（E4 优雅降级）
- 构造 `EditorInterface.get_editor_theme()` 返回 null 或缺失 StatusError 图标的场景
- 预期：`_get_theme_icon` 返回 null，`set_icon(0, null)` 触发但不 crash，`set_custom_color` 着色保留
- **注意**：此场景在正常编辑器中难以复现（EditorInterface 和主题图标几乎总是存在），以防御代码 review + 静态分析验证覆盖

**`test_trigger_summary_text`**
- Trigger 有 error + warning
- 预期：文本含 `"N 错误, M 警告"`，`set_icon` 被调用（图标列非空）
- 断言方法：提取 TreeItem 的 `get_text(0)` 检查子串

**`test_instruction_severity_icon`**
- 指令有 error/warning
- 预期：`item.get_icon(0)` 非 null，图标类型匹配对应 severity
- 可额外测：有 error 时，icon 替代了分类 icon（`_set_item_icon` 的图标被覆盖）

**`test_detail_panel_no_emoji`**
- 选中含问题的 Trigger 或指令
- 预期：RichTextLabel BBCode 中无 `🔴` 或 `🟡` 字符
- 断言方法：`_detail.get_parsed_text()` 或 `_detail.text` 中不包含 emoji 码点

**`test_export_report_format`**
- 调用 `_on_export_problems` 导出
- 预期：导出文件内容行格式为 `"TriggerName: N 错误, M 警告"`
- 断言方法：`FileAccess.get_file_as_string(path)` 后正则匹配

### 5.2 回归验证

- 无问题的 Trigger/指令 → `set_icon(0, ...)` 不被调用，分类图标通过 `_set_item_icon` 正常显示
- 只有 `warning` 的 Trigger → `StatusWarning` 图标 + 单计数文本
- 导出无问题的场景 → 导出文件跳过该 Trigger（当前行为不变）

---

## 6. 实现步骤

### Phase 1：辅助方法

**文件**: `addons/fuse/editor/topology/fuse_topology.gd`

1. 在 `_set_item_icon` 附近新增 `_get_theme_icon(icon_name: String) -> Texture2D` 方法：
   ```gdscript
   func _get_theme_icon(icon_name: String) -> Texture2D:
       var theme := EditorInterface.get_editor_theme()
       if theme and theme.has_icon(icon_name, "EditorIcons"):
           return theme.get_icon(icon_name, "EditorIcons")
       return null
   ```
2. 新增 `_severity_label(p_severity: String) -> String` 静态方法。

**验收**：
- [ ] `_get_theme_icon("StatusError")` → `Texture2D` 实例（编辑器中）
- [ ] `_get_theme_icon("NonExistentIcon")` → `null`
- [ ] `_severity_label("error")` → `"错误"`
- [ ] `_severity_label("warning")` → `"警告"`

### Phase 2：Tree item 图标替换

**文件**: `addons/fuse/editor/topology/fuse_topology.gd`

1. `_build_tree_items` :258-264：
   - `"🔴 " + item.get_text(0)` → `item.set_icon(0, _get_theme_icon("StatusError"))`
   - `"🟡 " + item.get_text(0)` → `item.set_icon(0, _get_theme_icon("StatusWarning"))`
2. `_create_trigger_tree_item` :177-182：
   - 文本中的 `"%d🔴 %d🟡"` 替换为 `"%d 错误, %d 警告"`（用 `_severity_label`）
   - `"%d🟡"` 替换为 `"%d 警告"`
   - 增加 `t_item.set_icon(0, _get_theme_icon("StatusError"))` / `set_icon(0, _get_theme_icon("StatusWarning"))`

**验收**：
- [ ] instruction item 有 error → Tree 中 item 的 icon 是 `StatusError` 纹理
- [ ] instruction item 有 warning → icon 是 `StatusWarning` 纹理
- [ ] instruction item 无问题 → icon 仍然是 `_set_item_icon` 设的分类图标
- [ ] Trigger 有 error → icon 是 `StatusError`，文本计数为 `"N 错误, M 警告"`
- [ ] Trigger 仅 warning → icon 是 `StatusWarning`，文本计数为 `"N 警告"`
- [ ] Trigger 无问题 → icon 为 `null`（无 `set_icon` 调用）

### Phase 3：Detail 面板 + 导出报告

**文件**: `addons/fuse/editor/topology/fuse_topology.gd`

1. `_on_item_selected` :412：用 `[color=red]N 错误[/color]` + `[color=yellow]M 警告[/color]` BBCode 替换 `🔴🟡`
2. `_on_export_problems` :745：`"%d🔴 %d🟡"` → `"%d 错误, %d 警告"`

**验收**：
- [ ] Detail 面板问题标题显示 `"问题（1 错误, 2 警告）"`，无 emoji
- [ ] 导出报告行格式为 `"Trigger (...): N 错误, M 警告"`
- [ ] 与第 749 行的合计行格式一致

### Phase 4：验证

1. 打开含问题的场景 → 刷新 Topology → 目视确认图标正确
2. 打开不含问题的场景 → 确认无回归
3. 导出问题报告 → 检查文本中无 emoji 残余
4. `git grep "🔴\|🟡" addons/fuse/editor/topology/fuse_topology.gd` → 无匹配（确认所有 emoji 已替换）

---

## 7. 不做（YAGNI）

| 项 | 原因 |
|----|------|
| **分类图标 emoji 替换**（📦📊🔧🎵 等） | E4 仅处理问题严重度 🔴🟡。分类 emoji 替代属于 `_category_emoji` 范围，需为每类分配一个 Godot 主题图标，范围明确区分——另外排期 |
| **所有 emoji 全部消除**（✓✗↻） | 分支标签 `✓ then` / `✗ else` / `↻ loop` 是语义标记而非问题标注，非 E4 目标 |
| **banner 标题栏加图标** | 顶栏当前只显示 "Fuse 场景拓扑" 文本，未显示问题计数；增加全场景计数汇总的 Icon Banner 需额外设计（建议放入 E6 过滤功能） |
| **RichTextLabel 内联 Texture2D** | Godot BBCode `[img]` 需要资源路径，无法直接引用主题内 Texture2D——用中文文本 + `[color]` 标签替代 |
| **过度防御：为 TreeItem 加额外的图标槽位** | `set_icon` 覆盖是现有 TreeItem 设计的一部分，按优先级覆盖是预期行为 |
| **图标缓存**（`_get_theme_icon` 结果存成员变量） | `_get_theme_icon` 单次调用 O(1)，缓存增加成员复杂度无实质收益 |

---

## 8. 风险

| 风险 | 影响 | 缓解 |
|------|------|------|
| `EditorInterface.get_editor_theme()` 返回 `null`（编辑器快速退出 / 非编辑线程） | `_get_theme_icon` 返回 `null`，`set_icon(0, null)` 清空图标，文本着色保留 | 方法内 `if theme == null: return null` 已防御 |
| 自定义主题删除 `StatusError` / `StatusWarning` 图标 | `has_icon` 返回 false，回退同上 | 着色保留，无 crash 风险 |
| `set_text(0, ...)` 移除了 `"🔴 "` 前缀但用户习惯找 emoji | 视觉过渡平缓（图标 + 着色 + 红色文本三重提示足以补偿） | 文本空格对齐：原 `"🔴 SetPosition"` → `"SetPosition"`，位置偏移极小 |
| `_set_item_icon` 设了 icon，severity 覆盖后用户看不到指令分类 | 严重度优先级高于分类——有问题的指令先看问题，修复后自动恢复分类图标 | 有意设计 |
| `_severity_label` 是中文硬编码 | 未来多语言时需将 label 提取到全局字符串表 | 当前阶段中文化无语言切换需求；提取成本低（一处 static 方法） |

---

## 9. 验收标准

- [ ] 所有指令节点 problem 用 `StatusError` / `StatusWarning` 主题图标替代 🔴🟡 文本前缀
- [ ] Trigger 汇总用主题图标 + 中文计数文本替代 emoji 计数文本
- [ ] Detail 面板 BBCode 用中文 + `[color]` 标签替代 🔴🟡
- [ ] 导出报告用中文文本 `"错误"/"警告"` 替代 emoji
- [ ] `_get_theme_icon` 安全封装 `EditorInterface.get_editor_theme()` 空值和缺失 icon 场景
- [ ] 无问题指令的 `_set_item_icon` 分类图标正常工作（回归）
- [ ] `git grep "🔴\|🟡" addons/fuse/editor/topology/fuse_topology.gd` 输出为空
- [ ] godot 控制台无相关错误（`get_icon` missing icon 等）
- [ ] roadmap 中 E4 标记为 "spec 完成"

---

## 10. 修改文件清单

| 文件 | 变更类型 | 说明 |
|------|---------|------|
| `addons/fuse/editor/topology/fuse_topology.gd` | 修改 | 7 处 emoji 替换 + 新增 `_get_theme_icon` + `_severity_label` 辅助方法 |

仅修改一个文件。所有改动在 `fuse_topology.gd` 内部——对 `InstructionAnalyzer`、`NodePathResolver`、测试场景等零影响。

---

*本 spec 批准后，下一步：invoke writing-plans 生成实现计划。*
