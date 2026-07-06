# Topology Tree 强化 — 执行计划

**日期:** 2026-07-04
**关联:** [spec](2026-07-04-topology-tree-enhance-spec.md)
**预估工时:** 1-1.5 天

---

## 0. 现状关键

- `instructions_tree` 的 `tree_node` 已含 `inst` 引用（[instruction_analyzer.gd:101](../../editor/analysis/instruction_analyzer.gd#L101)）—— 可直接读 metadata + get_description()
- Tree 指令项 `set_selectable(0, false)`（[fuse_topology.gd:130](../../editor/topology/fuse_topology.gd#L130)）—— 最大缺陷
- `_on_item_selected` 只处理 Trigger metadata（[fuse_topology.gd:137](../../editor/topology/fuse_topology.gd#L137)）—— 选中指令无响应

---

## 1. 任务分解

| # | 内容 | 工时 |
|---|---|:--:|
| A | Tree 层级重构（flat → tree 嵌套 + 指令可选 + metadata） | 0.5 天 |
| B | 指令图标（builtin icon + emoji 回退） | 0.25 天 |
| C | 参数摘要（get_description） | 0.25 天 |
| D | 右侧详情：选中指令（参数表 + 引用 + 上下文） | 0.25 天 |
| E | GraphEdit 降级 + 回归 | 0.25 天 |

---

## 2. 任务 A — Tree 层级重构

### 2.1 替换 refresh() 的指令填充（line 124-130）

```gdscript
# 当前（flat + prefix 文本缩进）:
for inst_info in report.instructions_flat:
    var i_item := _tree.create_item(t_item)
    i_item.set_text(0, "%s📦 %s" % [prefix, inst_info.name])
    i_item.set_selectable(0, false)

# 改为（tree 嵌套 + 可选 + metadata）:
var tree_data: Array = report.get("instructions_tree", [])
if tree_data.is_empty():
    # 回退 flat（兼容）
    for inst_info in report.instructions_flat:
        _create_flat_item(t_item, inst_info, report)
else:
    _build_tree_items(t_item, tree_data, report)

func _build_tree_items(parent_item: TreeItem, tree_data: Array, report: Dictionary) -> void:
    for node_info in tree_data:
        var inst = node_info.get("inst")
        var children: Dictionary = node_info.get("children", {})
        var is_branch := not children.is_empty()

        var item: TreeItem = _tree.create_item(parent_item)
        var display_name: String = node_info.get("name", "?")

        # 图标（任务 B）
        _set_item_icon(item, inst)

        # 参数摘要（任务 C）
        var summary := _get_param_summary(inst)
        item.set_text(0, display_name + summary)

        # 可选 + metadata（选中指令看详情）
        item.set_selectable(0, true)
        item.set_metadata(0, {"type": "instruction", "inst": inst, "report": report})

        # 递归子分支（then ✓ / else ✗ / loop ↻）
        for branch_label in children:
            var subtree: Array = children[branch_label]
            if subtree.is_empty():
                continue
            var branch_item: TreeItem = _tree.create_item(item)
            branch_item.set_text(0, _branch_label_display(branch_label))
            branch_item.set_selectable(0, false)
            branch_item.set_custom_color(0, _branch_color(branch_label))
            _build_tree_items(branch_item, subtree, report)
```

### 2.2 分支标签

```gdscript
func _branch_label_display(p_label: String) -> String:
    match p_label:
        "then": return "✓ then"
        "else": return "✗ else"
        "loop": return "↻ loop"
        _: return p_label

func _branch_color(p_label: String) -> Color:
    match p_label:
        "then": return Color(0.4, 0.9, 0.4)   # 绿
        "else": return Color(0.9, 0.5, 0.4)    # 红
        "loop": return Color(0.4, 0.6, 1.0)    # 蓝
        _: return Color.GRAY
```

---

## 3. 任务 B — 指令图标

```gdscript
func _set_item_icon(item: TreeItem, inst) -> void:
    if inst == null:
        return
    # 优先 builtin_icon（metadata）
    var icon_name := ""
    var script = inst.get_script()
    if script and script.has_method("_get_instruction_metadata"):
        var metadata = script._get_instruction_metadata()
        icon_name = metadata.get("builtin_icon", "")

    if not icon_name.is_empty():
        var theme := EditorInterface.get_editor_theme()
        if theme and theme.has_icon(icon_name, "EditorIcons"):
            item.set_icon(0, theme.get_icon(icon_name, "EditorIcons"))
            return

    # 回退：分类 emoji
    var emoji := _category_emoji(inst)
    if not emoji.is_empty():
        var current_text := item.get_text(0)
        item.set_text(0, emoji + " " + current_text)

func _category_emoji(inst) -> String:
    var script = inst.get_script()
    if script and script.has_method("_get_instruction_metadata"):
        var category: String = script._get_instruction_metadata().get("category_key", "")
        if category.find("VARIABLE") >= 0: return "📊"
        if category.find("NODE") >= 0 or category.find("NODE_OPERATION") >= 0: return "🔧"
        if category.find("AUDIO") >= 0: return "🎵"
        if category.find("UI") >= 0: return "🖼"
        if category.find("ANIMATION") >= 0: return "🎬"
        if category.find("PHYSICS") >= 0: return "⚙"
        if category.find("TWEEN") >= 0: return "✨"
        if category.find("CAMERA") >= 0: return "📷"
    # 流控（指令名判断）
    var name := inst.resource_name
    if name.begins_with("If") or name.begins_with("While") or name.begins_with("For"):
        return "🔀"
    return "▶"
```

---

## 4. 任务 C — 参数摘要

```gdscript
func _get_param_summary(inst) -> String:
    if inst == null:
        return ""
    # 优先 get_description()（BaseInstruction 有此方法）
    if inst.has_method("get_description"):
        var desc: String = inst.get_description()
        if not desc.is_empty() and desc.length() <= 50:
            return "  [color=gray]" + desc + "[/color]"
        if desc.length() > 50:
            return "  [color=gray]" + desc.substr(0, 47) + "...[/color]"
    return ""
```

> Tree 支持 bbcode 吗？不直接支持。改用纯文本摘要或 `set_suffix`。V1 用纯文本（去 bbcode）：

```gdscript
func _get_param_summary(inst) -> String:
    if inst == null:
        return ""
    if inst.has_method("get_description"):
        var desc: String = inst.get_description()
        if not desc.is_empty():
            if desc.length() > 50:
                desc = desc.substr(0, 47) + "..."
            return " — " + desc
    return ""
```

---

## 5. 任务 D — 右侧详情：选中指令

### 5.1 _on_item_selected 改造

```gdscript
func _on_item_selected() -> void:
    var item := _tree.get_selected()
    if item == null:
        return

    var meta = item.get_metadata(0)
    if meta == null:
        return

    # 统一 RichTextLabel（GraphEdit 不默认显示）
    _detail.visible = true
    _graph_edit.visible = false
    _detail.clear()

    var meta_type: String = meta.get("type", "trigger")

    if meta_type == "instruction":
        _show_instruction_detail(meta)
    else:
        # Trigger 概要（现有逻辑）
        _show_trigger_detail(meta)  # meta 就是 report
```

### 5.2 选中指令详情

```gdscript
func _show_instruction_detail(meta: Dictionary) -> void:
    var inst = meta.get("inst")
    var report: Dictionary = meta.get("report", {})
    if inst == null:
        return

    var name: String = inst.resource_name
    if name.is_empty(): name = inst.get_class()

    # 标题
    _detail.append_text("[b]%s[/b]\n" % name)

    # 分类
    var script = inst.get_script()
    if script and script.has_method("_get_instruction_metadata"):
        var metadata = script._get_instruction_metadata()
        _detail.append_text("[color=gray]分类: %s[/color]\n\n" % metadata.get("category_key", "?"))

    # 参数表（反射 @export 属性）
    _detail.append_text("[b]参数:[/b]\n")
    for prop in inst.get_property_list():
        var pname: String = prop.get("name", "")
        if pname.begins_with("_") or pname in ["script", "resource_name", "metadata"]:
            continue
        var usage: int = prop.get("usage", 0)
        if not (usage & PROPERTY_USAGE_EDITOR):
            continue
        var value = inst.get(pname)
        _detail.append_text("  %s: %s\n" % [pname, str(value)])

    # 引用（单指令提取）
    var inst_report := {"nodes": [], "variables": {"local": [], "scope": [], "global": []}, "signals": []}
    InstructionAnalyzer._extract_nodepaths(inst, inst_report)
    InstructionAnalyzer._extract_variables(inst, inst_report)

    if not inst_report["nodes"].is_empty():
        _detail.append_text("\n[b]节点引用:[/b] %s\n" % ", ".join(inst_report["nodes"]))
    if not inst_report["variables"]["local"].is_empty():
        var names: Array = []
        for v in inst_report["variables"]["local"]:
            names.append(v.get("name", "?"))
        _detail.append_text("[b]变量引用:[/b] %s\n" % ", ".join(names))

    # 上下文
    _detail.append_text("\n[color=gray]所属 Trigger: %s[/color]\n" % report.get("trigger_name", "?"))
```

### 5.3 Trigger 概要（现有逻辑保留）

现有 `_on_item_selected` 的 Trigger 详情逻辑（事件/节点/变量/信号/指令链）保留，封装为 `_show_trigger_detail(report)`。

---

## 6. 任务 E — GraphEdit 降级

### 6.1 移除 GraphEdit 默认初始化（_init）

```gdscript
# 删除或注释 _init 中的:
# _graph_edit = FuseGraphEdit.new()
# ...（line 71-77）
# 保留 _graph_edit 变量声明（null），代码保留但不实例化

# 或保留初始化但不默认显示（visible = false，已有）
```

### 6.2 _on_item_selected 不调 _show_graph

```gdscript
# 删除（或注释）:
# if not tree_data.is_empty():
#     _show_graph(report)
#     return
# 统一走 _show_trigger_detail / _show_instruction_detail
```

### 6.3 GraphEdit 代码保留

fuse_graph_edit.gd / fuse_graph_builder.gd / fuse_graph_node.gd 不删（将来可选启用，如加按钮切换）。

---

## 7. 验收

1. **Tree 嵌套**：Trigger 展开 → 指令按 tree 层级嵌套（非 prefix 文本缩进）
2. **if/else 分支标记**：✓ then（绿）/ ✗ else（红）/ ↻ loop（蓝）
3. **指令图标**：builtin icon 显示（无则 emoji）
4. **参数摘要**：指令名 + ` — 描述`
5. **指令可选**：点选单个指令 → 右侧显示该指令详情（参数表 + 引用 + 上下文）
6. **Trigger 可选**：点选 Trigger → 右侧显示 Trigger 概要（现有内容）
7. **GraphEdit 不默认显示**
8. **回归**：跨 Trigger 关联不受影响

---

## 8. 风险

| 风险 | 缓解 |
|---|---|
| get_description() 返回本地化文本（太长/含翻译键） | 截断 50 字符 |
| builtin_icon 不在 EditorIcons（自定义名） | get_icon 前检查 has_icon |
| instructions_tree 为空（旧 Trigger） | 回退 flat 线性构建 |
| Tree bbcode 不支持 | 参数摘要用纯文本 |

---

## 9. 执行顺序

```
Step 1: 任务 A — Tree 层级重构 + 指令可选 + metadata
Step 2: 任务 B — 图标（builtin icon + emoji 回退）
Step 3: 任务 C — 参数摘要
Step 4: 任务 D — 右侧选中指令详情
Step 5: 任务 E — GraphEdit 降级 + 回归验证
```

---

**状态:** ✅ 完成（2026-07-04）。5 任务全实施 + 验收通过。

**额外实施（plan 外）：**
- 嵌套场景分组（方案 B，`owner != scene_root` 检测，📦 蓝色标题）
- MultiEventTrigger event_bindings 展开（Tree 子项 + 选中 binding 详情）
- IfElse 分支渲染修复（`_SUB_INSTRUCTIONS` 加 `true_instructions`/`false_instructions`）
- `trigger_type` 修用 `script.get_global_name()`（替代 `get_class()` 返回 "Node"）
- 3 个缺失翻译 key 补全（IF_ELSE_MODE_ASYNC/SYNC + TEXT_UNLIMITED）
- trigger_path 用场景根相对路径
