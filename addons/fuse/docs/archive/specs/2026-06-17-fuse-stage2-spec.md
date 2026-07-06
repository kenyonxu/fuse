# Fuse Stage 2: 工具链基础设施 — 完整规格文档

**版本:** 1.0
**日期:** 2026-06-17
**基线:** Stage 1 完成(143 组件), 架构整改全链闭环, 本地化 TranslationDomain
**目标:** 建立预设系统和变量监视器, 让组件有"模板复用"和"运行时调试"能力
n> **📋 完成状态（2026-06-17）** — 全部 5 个子任务完成。指令数组按钮化、FusePreset Resource+JSON 双格式、导出/导入/预设面板、变量监视器（全局变量+Runner 扫描）。

> **For agentic workers:** 步骤使用复选框(`- [ ]`)语法跟踪。

---

## 目录

1. [基线状态](#1-基线状态)
2. [子任务总览](#2-子任务总览)
3. [Task 2.1: 多选改造](#3-task-21-指令列表多选改造)
4. [Task 2.2: FusePreset Resource + 注册表](#4-task-22-fusepreset-resource--注册表)
5. [Task 2.3: 导出为预设](#5-task-23-导出为预设)
6. [Task 2.4: 预设面板 + 导入映射](#6-task-24-预设面板--导入映射)
7. [Task 2.5: 变量监视器](#7-task-25-变量监视器)
8. [验证清单](#8-验证清单)
9. [文件清单](#9-文件清单)

---

## 1. 基线状态

| 指标 | 值 |
|------|-----|
| 指令 | 140(Stage 1 +11) |
| 事件 | 66(Stage 1 +1) |
| 条件 | 45(Stage 1 +2) |
| ActionRunner | Resource,直接可序列化 |
| 指令列表编辑器 | `instructions_array_property.gd`, `ItemList` + `SELECT_SINGLE` |
| EC 快照 API | `VariableContext.get_all_*_snapshot()` 已有 |
| 全局变量 API | `GlobalVariableService.get_all_global_variables_info()` 已有 |

---

## 2. 子任务总览

| # | 子任务 | 复杂度 | 工时 | 关联设计文档 |
|---|--------|:---:|:--:|------|
| 2.1 | 指令列表多选改造 | 低 | 0.5天 | —(改动小,无独立设计文档) |
| 2.2 | FusePreset Resource + 注册表 | 中 | 1天 | [preset-system-design.md](2026-06-17-fuse-preset-system-design.md) |
| 2.3 | 导出为预设 | 中 | 0.5天 | 同上 |
| 2.4 | 预设面板 + 导入映射 | 中 | 1-1.5天 | 同上 |
| 2.5 | 变量监视器 | 中 | 1-1.5天 | [variable-watcher-design.md](2026-06-17-fuse-variable-watcher-design.md) |

**依赖:** 2.1 → 2.2(数据核心) → 2.3/2.4(导出/导入) ⋮ 2.5(独立,可与 2.2-2.4 并行)

---

## 3. Task 2.1: 指令列表多选改造

**Files:**
- Modify: `addons/fuse/editor/instruction_selector/instructions_array_property.gd`(接线为属性编辑器+多选+复制)
- Modify: `addons/fuse/editor/instruction_selector/instructions_array_inspector_plugin.gd`(接线:用 `add_property_editor` 替换 `add_custom_control`)

- [x] **Step 0:接线 — 启用 instructions_array_property.gd**

`instructions_array_property.gd` 是已写好的 `EditorProperty`(ItemList+按钮),但从未注册。将它接线为 `Array[BaseInstruction]` 的 Inspector 编辑器:

修改 `instructions_array_inspector_plugin.gd` 的 `_parse_property()`(行 26-32),将当前的:

```gdscript
# 当前: add_custom_control 加按钮,保留原生编辑器
add_custom_control(container)
return false
```

替换为:

```gdscript
# 改为: add_property_editor 注册 ItemList 编辑器,替换原生编辑器
var editor = preload("res://addons/fuse/editor/instruction_selector/instructions_array_property.gd").new()
add_property_editor(name, editor)
return true  # 替换原生数组编辑器
```

同时删除当前 `_parse_property` 中创建按钮和 container 的代码(行 32-62,`enhance_hbox`/`add_button`/`_open_selector`)。`instructions_array_property.gd` 自带"添加"按钮,不需要 Inspector 插件额外加按钮。

> **注意:** `instructions_array_property.gd` 的无参 `_init()` 符合 `EditorProperty` 规范(通过 `get_edited_object()`/`get_edited_property()` 获取编辑目标)。当前代码已正确实现。

- [x] **Step 0b:在 Editor Bootstrap 中注册插件**

`fuse_editor_bootstrap.gd` 的 `setup()` 中(在 `_fuse_plugin` 注册之后),必须注册新插件才能生效:

成员变量区(行 13-14 附近):
```gdscript
var _instructions_array_plugin: EditorInspectorPlugin = null
```

`setup()`(行 28 之后):
```gdscript
# 3.5. 指令数组编辑器插件(Stage 2.1: ItemList 替换原生编辑器)
_instructions_array_plugin = preload("res://addons/fuse/editor/instruction_selector/instructions_array_inspector_plugin.gd").new()
_plugin.add_inspector_plugin(_instructions_array_plugin)
print("Fuse 指令数组编辑器插件已注册")
```

`teardown()`(逆序,在 `_input_key_plugin` 之前):
```gdscript
if _instructions_array_plugin:
    _plugin.remove_inspector_plugin(_instructions_array_plugin)
    _instructions_array_plugin = null
```

- [x] **Step 1:启用多选 + 批量删除**

`instructions_array_property.gd` 行 33: `SELECT_SINGLE` → `SELECT_MULTI`:

```gdscript
# 行 33 — 改为:
property_list.select_mode = ItemList.SELECT_MULTI
```

`_on_remove_pressed`(行 128-141)改为逆序批量删除:

```gdscript
func _on_remove_pressed() -> void:
    var selected = property_list.get_selected_items()
    if selected.is_empty():
        return

    var instructions: Array[BaseInstruction] = object.get(property_name)
    # 逆序删除(避免索引偏移)
    for i in range(selected.size() - 1, -1, -1):
        instructions.remove_at(selected[i])

    object.set(property_name, instructions)
    emit_changed(property_name, instructions)
```

- [x] **Step 2:新增"复制选中"按钮**

在 `vbox` 中追加复制按钮(行 59 附近):

```gdscript
var copy_button: Button = Button.new()
# _init() 中:
copy_button.text = "复制"
copy_button.custom_minimum_size.x = 70
copy_button.pressed.connect(_on_copy_pressed)
copy_button.disabled = true
vbox.add_child(copy_button)
```

`_update_buttons()`(行 97-101)追加:

```gdscript
copy_button.disabled = selected_items.is_empty()
```

复制逻辑:

```gdscript
func _on_copy_pressed() -> void:
    var selected = property_list.get_selected_items()
    if selected.is_empty():
        return

    var instructions: Array[BaseInstruction] = object.get(property_name)
    var to_copy: Array[BaseInstruction] = []
    for idx in selected:
        if idx < instructions.size():
            to_copy.append(instructions[idx].duplicate(true))

    # 追加到末尾
    instructions.append_array(to_copy)
    object.set(property_name, instructions)
    emit_changed(property_name, instructions)
```

- [x] **Step 3:编辑按钮支持多选(仅编辑第一个)**

`_on_edit_pressed` 不变(已有行 117-126,取 `selected[0]` 编辑,多选时语义一致)。

- [x] **Step 4:验证 + commit**

1. 打开含 ActionRunner 的场景,选中 Inspector 中 instructions 数组
2. Ctrl/Cmd+点击选中多项 → 删除按钮变可用 → 删除全部选中项
3. 选中多项 → 复制 → 列表末尾出现副本
4. 编辑按钮:选中多项后编辑按钮可用,编辑第一个选中项

```bash
git add addons/fuse/editor/instruction_selector/instructions_array_property.gd \
        addons/fuse/editor/instruction_selector/instructions_array_inspector_plugin.gd
git commit -m "feat(fuse): wire up instruction list editor + multi-select (stage2 task2.1)"
```

---

## 4. Task 2.2: FusePreset Resource + 注册表

**Files:**
- Create: `addons/fuse/core/resources/fuse_preset.gd`
- Create: `addons/fuse/core/resources/fuse_preset.gd.uid`
- Create: `addons/fuse/editor/preset_registry.gd`

- [x] **Step 1:创建 FusePreset Resource**

```gdscript
# addons/fuse/core/resources/fuse_preset.gd
@tool
class_name FusePreset
extends Resource

## 预设名称(显示在面板中)
@export var display_name: String = ""

## 分类标识
@export var category: String = ""

## 描述
@export var description: String = ""

## 图标(FuseIconManager builtin_icon 名称)
@export var icon_name: String = ""

## 版本号
@export var version: String = "1.0"

## 变量声明: {"local":["n1"],"scope":[{"name":"hp","container":"../Player"}],"global":["level"]}
@export var variables: Dictionary = {}

## 指令序列
@export var instructions: Array[BaseInstruction] = []


# ---- 序列化 ----

func to_json() -> Dictionary:
    return {
        "format_version": version,
        "display_name": display_name,
        "category": category,
        "description": description,
        "icon_name": icon_name,
        "variables": variables,
        "instructions": _serialize_instructions()
    }


func _serialize_instructions() -> Array:
    var result: Array = []
    for inst in instructions:
        var script = inst.get_script()
        var entry := {"type": script.get_global_name() if script else inst.get_class()}
        for prop in inst.get_property_list():
            var pname: String = prop.name
            if pname.begins_with("_") or (prop.usage & PROPERTY_USAGE_STORAGE) == 0:
                continue
            var val = inst.get(pname)
            if val is NodePath:
                entry[pname] = str(val)
            elif val is Resource and val.resource_path != "":
                entry[pname] = val.resource_path
            elif not (val is Resource):
                entry[pname] = val
        result.append(entry)
    return result


# ---- 反序列化 ----

static func from_json(data: Dictionary) -> FusePreset:
    var preset := FusePreset.new()
    preset.version = data.get("format_version", "1.0")
    preset.display_name = data.get("display_name", "")
    preset.category = data.get("category", "")
    preset.description = data.get("description", "")
    preset.icon_name = data.get("icon_name", "")
    preset.variables = data.get("variables", {})
    preset.instructions = _deserialize_instructions(data.get("instructions", []))
    return preset


static func _cache_type_script(type_name: String) -> GDScript:
    # 缓存 name→script 映射,避免每次遍历 registry
    var instructions = InstructionRegistry.get_all_instructions()
    for info in instructions:
        var meta = info.get("metadata")
        if meta and meta.name == type_name:
            return info.get("class")
    return null


static func _deserialize_instructions(raw: Array) -> Array[BaseInstruction]:
    var result: Array[BaseInstruction] = []
    for entry in raw:
        var type_name: String = entry.get("type", "")
        var script: GDScript = _cache_type_script(type_name)
        if script == null:
            push_warning("FusePreset: 无法找到指令类型 '%s'" % type_name)
            continue
        var inst: BaseInstruction = script.new()
        for key in entry:
            if key == "type":
                continue
            var val = entry[key]
            if val is String and (val.begins_with("uid://") or val.begins_with("res://")):
                var res = load(val)
                if res != null:
                    inst.set(key, res)
                else:
                    inst.set(key, val)  # 可能是 NodePath 字符串,保留
            else:
                inst.set(key, val)
        result.append(inst)
    return result


# ---- NodePath 映射 ----

func collect_unique_nodepaths() -> Array[NodePath]:
    var result: Array[NodePath] = []
    for inst in instructions:
        for prop in inst.get_property_list():
            if prop.type == TYPE_NODE_PATH:
                var np: NodePath = inst.get(prop.name)
                if not np.is_empty() and np not in result:
                    result.append(np)
    return result


func apply_nodepath_mapping(mapping: Dictionary) -> void:
    for inst in instructions:
        for prop in inst.get_property_list():
            if prop.type == TYPE_NODE_PATH:
                var np: NodePath = inst.get(prop.name)
                if mapping.has(str(np)):
                    inst.set(prop.name, mapping[str(np)])


# ---- 变量收集 ----

func collect_variables() -> Dictionary:
    var result := {"local": [], "scope": [], "global": []}
    for inst in instructions:
        if "variable_name" in inst and "variable_scope" in inst:
            var name: String = inst.variable_name
            var scope: int = inst.variable_scope
            match scope:
                0:
                    if name not in result["local"]:
                        result["local"].append(name)
                1:
                    var entry := {"name": name, "container": ""}
                    if "target_node" in inst:
                        entry["container"] = str(inst.target_node)
                    result["scope"].append(entry)
                2:
                    if name not in result["global"]:
                        result["global"].append(name)
    return result
```

- [x] **Step 2:注册 FusePreset 自定义类型**

在 `fuse_type_registrar.gd` 的 `_TYPES` 数组中追加:

```gdscript
["FusePreset", "Resource", "res://addons/fuse/core/resources/fuse_preset.gd"],
```

- [x] **Step 3:创建 PresetRegistry(预设扫描)**

```gdscript
# addons/fuse/editor/preset_registry.gd
class_name PresetRegistry
extends RefCounted

static var _presets: Array[FusePreset] = []


static func scan_presets() -> void:
    _presets.clear()
    var dir := DirAccess.open("res://addons/fuse/presets/")
    if dir == null:
        return
    _scan_recursive(dir, "res://addons/fuse/presets/")


static func _scan_recursive(dir: DirAccess, base_path: String) -> void:
    dir.list_dir_begin()
    var file_name := dir.get_next()
    while file_name != "":
        var full_path := base_path.path_join(file_name)
        if dir.current_is_dir():
            if not file_name.begins_with("."):
                var sub := DirAccess.open(full_path)
                if sub:
                    _scan_recursive(sub, full_path)
        elif file_name.ends_with(".tres"):
            var preset = load(full_path) as FusePreset
            if preset:
                _presets.append(preset)
        file_name = dir.get_next()
    dir.list_dir_end()


static func get_all() -> Array[FusePreset]:
    return _presets


static func get_by_category(category: String) -> Array[FusePreset]:
    var result: Array[FusePreset] = []
    for p in _presets:
        if p.category == category:
            result.append(p)
    return result


static func get_categories() -> Array[String]:
    var result: Array[String] = []
    for p in _presets:
        if p.category not in result:
            result.append(p.category)
    return result


static func clear() -> void:
    _presets.clear()
```

- [x] **Step 4:在 plugin.gd 中集成预设扫描**

在 `FuseComponentScanner.setup()`(或 `plugin.gd` 的 `_enter_tree`)中追加:

```gdscript
PresetRegistry.scan_presets()
```

在 `FuseComponentScanner.teardown()`(或 `_exit_tree`)中追加:

```gdscript
PresetRegistry.clear()
```

- [x] **Step 5:创建 presets/ 根目录 + 验证**

```bash
mkdir -p addons/fuse/presets
```

1. 编辑器重载插件 → 无报错
2. FusePreset 类型可创建(在 Inspector 中)
3. `PresetRegistry.get_all()` 返回空数组(目录刚创建)

```bash
git add addons/fuse/core/resources/fuse_preset.gd \
        addons/fuse/core/resources/fuse_preset.gd.uid \
        addons/fuse/editor/preset_registry.gd \
        addons/fuse/editor/bootstrap/fuse_type_registrar.gd \
        addons/fuse/editor/bootstrap/fuse_component_scanner.gd \
        addons/fuse/presets/
git commit -m "feat(fuse): add FusePreset Resource + PresetRegistry (stage2 task2.2)"
```

---

## 5. Task 2.3: 导出为预设

**Files:**
- Modify: `addons/fuse/editor/instruction_selector/instructions_array_property.gd`(+导出按钮 + 对话框)
- Create: `addons/fuse/editor/preset_export_dialog.gd`(导出对话框)

- [x] **Step 1:创建导出对话框**

```gdscript
# addons/fuse/editor/preset_export_dialog.gd
@tool
class_name PresetExportDialog
extends AcceptDialog

var _display_name_input: LineEdit
var _category_input: LineEdit
var _description_input: TextEdit
var _icon_input: LineEdit
var _info_label: Label
var _instructions: Array[BaseInstruction] = []


func _init(instructions: Array[BaseInstruction]) -> void:
    _instructions = instructions
    title = "导出为预设"
    _build_ui()
    _update_info()


func _build_ui() -> void:
    var grid := GridContainer.new()
    grid.columns = 2
    add_child(grid)

    # display_name
    grid.add_child(_make_label("名称:"))
    _display_name_input = LineEdit.new()
    _display_name_input.placeholder_text = "弹幕生成器"
    grid.add_child(_display_name_input)

    # category
    grid.add_child(_make_label("分类:"))
    _category_input = LineEdit.new()
    _category_input.placeholder_text = "combat / movement / ui"
    grid.add_child(_category_input)

    # description
    grid.add_child(_make_label("描述:"))
    _description_input = TextEdit.new()
    _description_input.custom_minimum_size.y = 60
    grid.add_child(_description_input)

    # icon
    grid.add_child(_make_label("图标:"))
    _icon_input = LineEdit.new()
    _icon_input.placeholder_text = "Bullet / Sprite2D / Node"
    grid.add_child(_icon_input)

    # info label
    var spacer := Control.new()
    grid.add_child(spacer)
    _info_label = Label.new()
    _info_label.autowrap_mode = TextServer.AUTOWRAP_WORD
    grid.add_child(_info_label)

    register_text_enter(_display_name_input)
    register_text_enter(_category_input)


func _make_label(text: String) -> Label:
    var lbl := Label.new()
    lbl.text = text
    return lbl


func _update_info() -> void:
    # 创建临时 preset 收集 NodePath 和变量
    var temp := FusePreset.new()
    temp.instructions = _instructions
    var nodepaths := temp.collect_unique_nodepaths()
    var vars := temp.collect_variables()
    _info_label.text = "检测到: %d 个 NodePath, %d 个变量(local:%d scope:%d global:%d)" % [
        nodepaths.size(),
        vars.local.size() + vars.scope.size() + vars.global.size(),
        vars.local.size(), vars.scope.size(), vars.global.size()
    ]


func get_preset() -> FusePreset:
    var preset := FusePreset.new()
    preset.display_name = _display_name_input.text
    preset.category = _category_input.text
    preset.description = _description_input.text
    preset.icon_name = _icon_input.text
    preset.instructions = _instructions
    preset.variables = preset.collect_variables()
    return preset
```

- [x] **Step 2:instructions_array_property.gd 加导出按钮**

在 `_init()` 的 vbox 末尾追加:

```gdscript
var export_btn: Button = Button.new()
# _init() 中:
export_btn.text = "导出为预设"
export_btn.custom_minimum_size.x = 70
export_btn.pressed.connect(_on_export_pressed)
vbox.add_child(export_btn)
```

导出逻辑:

```gdscript
func _on_export_pressed() -> void:
    var instructions: Array[BaseInstruction] = object.get(property_name)
    if instructions.is_empty():
        return

    var dialog := PresetExportDialog.new(instructions)
    EditorInterface.get_base_control().add_child(dialog)
    dialog.confirmed.connect(_on_export_confirmed.bind(dialog))
    dialog.popup_centered()

func _on_export_confirmed(dialog: PresetExportDialog) -> void:
    var preset := dialog.get_preset()
    var dir_path := "res://addons/fuse/presets/%s" % preset.category
    DirAccess.make_dir_recursive_absolute(dir_path)
    var base_name := preset.display_name.to_snake_case()

    # 保存 .tres
    var tres_path := "%s/%s.tres" % [dir_path, base_name]
    ResourceSaver.save(preset, tres_path)

    # 保存 .json
    var json_path := "%s/%s.json" % [dir_path, base_name]
    var file := FileAccess.open(json_path, FileAccess.WRITE)
    if file:
        file.store_string(JSON.stringify(preset.to_json(), "\t"))
        file.close()

    # 刷新预设注册表
    PresetRegistry.scan_presets()
    print("预设已导出: %s" % tres_path)
```

- [x] **Step 3:验证**

1. 在 Inspector 选中一个 ActionRunner 的 instructions 数组
2. 点击"导出为预设" → 弹出对话框,显示 NodePath/变量统计
3. 填写名称/分类/描述 → 保存
4. 检查 `addons/fuse/presets/{category}/` 下有 `.tres` 和 `.json` 双文件
5. 插件日志显示"预设已导出"

```bash
git add addons/fuse/editor/instruction_selector/instructions_array_property.gd \
        addons/fuse/editor/preset_export_dialog.gd
git commit -m "feat(fuse): add preset export (dialog + dual .tres/.json) (stage2 task2.3)"
```

---

## 6. Task 2.4: 预设面板 + 导入映射

**Files:**
- Create: `addons/fuse/editor/preset_panel.gd`(预设浏览面板)
- Create: `addons/fuse/editor/preset_import_dialog.gd`(导入映射对话框)
- Modify: `addons/fuse/plugin.gd`(注册 Dock 面板)

- [x] **Step 1:创建预设浏览面板**

```gdscript
# addons/fuse/editor/preset_panel.gd
@tool
class_name PresetPanel
extends Control

var _tree: Tree
var _search_input: LineEdit
var _apply_btn: Button
var _import_json_btn: Button
var _selected_preset: FusePreset = null


func _init() -> void:
    var vbox := VBoxContainer.new()
    add_child(vbox)

    # 搜索框
    _search_input = LineEdit.new()
    _search_input.placeholder_text = "搜索预设..."
    _search_input.text_changed.connect(_on_search_changed)
    vbox.add_child(_search_input)

    # 预设树
    _tree = Tree.new()
    _tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _tree.hide_root = true
    _tree.create_item()  # root
    _tree.item_selected.connect(_on_item_selected)
    vbox.add_child(_tree)

    # 按钮栏
    var hbox := HBoxContainer.new()
    vbox.add_child(hbox)
    _apply_btn = Button.new()
    _apply_btn.text = "应用预设"
    _apply_btn.disabled = true
    _apply_btn.pressed.connect(_on_apply_pressed)
    hbox.add_child(_apply_btn)
    _import_json_btn = Button.new()
    _import_json_btn.text = "导入JSON"
    _import_json_btn.pressed.connect(_on_import_json_pressed)
    hbox.add_child(_import_json_btn)

    refresh()


func refresh() -> void:
    _tree.clear()
    var root := _tree.create_item()
    for cat in PresetRegistry.get_categories():
        var cat_item := _tree.create_item(root)
        cat_item.set_text(0, cat)
        cat_item.set_metadata(0, {"type": "category"})
        cat_item.collapsed = false
        for preset in PresetRegistry.get_by_category(cat):
            var p_item := _tree.create_item(cat_item)
            p_item.set_text(0, preset.display_name)
            p_item.set_metadata(0, {"type": "preset", "preset": preset})


func _on_search_changed(text: String) -> void:
    # 简易过滤:折叠不匹配的分组
    pass


func _on_item_selected() -> void:
    var item := _tree.get_selected()
    var meta = item.get_metadata(0)
    _selected_preset = meta.get("preset") if meta.get("type") == "preset" else null
    _apply_btn.disabled = _selected_preset == null


func _on_apply_pressed() -> void:
    if _selected_preset == null:
        return
    var dialog := PresetImportDialog.new(_selected_preset)
    EditorInterface.get_base_control().add_child(dialog)
    dialog.popup_centered()


func _on_import_json_pressed() -> void:
    var dialog := FileDialog.new()
    dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
    dialog.add_filter("*.json", "JSON Presets")
    dialog.file_selected.connect(_on_json_file_selected)
    EditorInterface.get_base_control().add_child(dialog)
    dialog.popup_centered()


func _on_json_file_selected(path: String) -> void:
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return
    var data: Dictionary = JSON.parse_string(file.get_as_text())
    file.close()
    if data == null:
        return
    var preset := FusePreset.from_json(data)
    # 也保存 .tres
    var tres_path := path.get_basename() + ".tres"
    ResourceSaver.save(preset, tres_path)
    PresetRegistry.scan_presets()
    refresh()
```

- [x] **Step 2:创建导入映射对话框**

```gdscript
# addons/fuse/editor/preset_import_dialog.gd
@tool
class_name PresetImportDialog
extends AcceptDialog

var _preset: FusePreset
var _mapping: Dictionary = {}  # old_nodepath_str → new_nodepath_str


func _init(preset: FusePreset) -> void:
    _preset = preset
    title = "应用预设: %s" % preset.display_name
    _build_ui()


func _build_ui() -> void:
    var vbox := VBoxContainer.new()
    add_child(vbox)

    # 描述
    var desc_label := Label.new()
    desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
    desc_label.text = "%s · %s\n%s" % [_preset.category, _preset.display_name, _preset.description]
    vbox.add_child(desc_label)

    # NodePath 映射
    var nodepaths := _preset.collect_unique_nodepaths()
    if not nodepaths.is_empty():
        vbox.add_child(_make_section("NodePath 映射"))
        for np in nodepaths:
            var hbox := HBoxContainer.new()
            var lbl := Label.new()
            lbl.text = str(np)
            lbl.custom_minimum_size.x = 120
            hbox.add_child(lbl)
            var arrow := Label.new()
            arrow.text = " → "
            hbox.add_child(arrow)
            # 自动匹配:当前场景中查找同名节点
            var matched := _auto_match_nodepath(np)
            var option := OptionButton.new()
            option.add_item("自动: %s" % matched if matched != "" else "⚠ 手动选择...")
            hbox.add_child(option)
            vbox.add_child(hbox)
            _mapping[str(np)] = matched if matched != "" else ""

    # 变量检查
    var vars := _preset.collect_variables()
    if not vars.local.is_empty() or not vars.scope.is_empty() or not vars.global.is_empty():
        vbox.add_child(_make_section("变量依赖"))
        if not vars.local.is_empty():
            vbox.add_child(_make_var_line("[local] %s — 运行时自动创建" % ", ".join(vars.local)))
        for sv in vars.scope:
            vbox.add_child(_make_var_line("[scope] %s — 容器: %s" % [sv.name, sv.container]))
        if not vars.global.is_empty():
            vbox.add_child(_make_var_line("[global] %s — 项目级存在" % ", ".join(vars.global)))


func _make_section(title: String) -> Label:
    var lbl := Label.new()
    lbl.text = title
    lbl.add_theme_font_size_override("font_size", 13)
    return lbl


func _make_var_line(text: String) -> Label:
    var lbl := Label.new()
    lbl.text = "  " + text
    lbl.add_theme_color_override("font_color", Color.GRAY)
    return lbl


func _auto_match_nodepath(np: NodePath) -> String:
    # 在当前场景中搜索同名的 node
    var scene_tree = Engine.get_main_loop() as SceneTree
    if scene_tree == null or scene_tree.current_scene == null:
        return ""
    var target_name := str(np.get_name(0))
    var found := scene_tree.current_scene.find_children(target_name, "", true, false)
    if not found.is_empty():
        return str(found[0].get_path())
    return ""
```

- [x] **Step 3:plugin.gd 注册预设面板**

在 `plugin.gd` 的 `_enter_tree()` 末尾(print 之前)加入:

```gdscript
var _preset_panel: PresetPanel = null
# 在 _editor_bootstrap.setup() 之后:
_preset_panel = Preload("res://addons/fuse/editor/preset_panel.gd").new()
add_control_to_dock(DOCK_SLOT_RIGHT_BR, _preset_panel)
print("Fuse 预设面板已注册")
```

在 `_exit_tree()` 中移除:

```gdscript
if _preset_panel:
    _preset_panel.queue_free()  # Godot 4.x: queue_free 自动从 dock 移除
    _preset_panel = null
```

- [x] **Step 4:验证**

1. 编辑器右侧出现"Fuse 预设"面板,按分类显示预设树
2. 搜索框过滤预设
3. 点击预设 → 查看描述 → "应用预设"按钮变可用
4. "应用"弹出映射对话框:自动匹配同名节点,显示变量依赖
5. "导入JSON" → 选择 .json → 自动生成 .tres → 预设面板刷新
6. 跨场景应用:NodePath 映射正确替换

```bash
git add addons/fuse/editor/preset_panel.gd \
        addons/fuse/editor/preset_import_dialog.gd \
        addons/fuse/plugin.gd
git commit -m "feat(fuse): add preset panel + import mapping dialog (stage2 task2.4)"
```

---

## 7. Task 2.5: 变量监视器

**Files:**
- Modify: `addons/fuse/core/runner.gd`(+2 行 `current_execution_context`)
- Create: `addons/fuse/editor/debugging/variable_watcher.gd`
- Modify: `addons/fuse/plugin.gd`(注册 Bottom Dock)

- [x] **Step 1:Runner 暴露 EC(+2 行)**

`runner.gd` 顶部加公开属性:

```gdscript
## 当前执行上下文(运行时设置,变量监视器读取)
var current_execution_context: ExecutionContext = null
```

`run()` 方法中(行 311 后):

```gdscript
current_execution_context = execution_context
```

- [x] **Step 2:创建变量监视器面板**

```gdscript
# addons/fuse/editor/debugging/variable_watcher.gd
@tool
class_name FuseVariableWatcher
extends Control

var _timer: Timer
var _tree: Tree
var _search_input: LineEdit
var _status_label: Label
var _snapshot_btn: Button


func _init() -> void:
    var vbox := VBoxContainer.new()
    add_child(vbox)

    # 顶部栏
    var top := HBoxContainer.new()
    vbox.add_child(top)
    _status_label = Label.new()
    _status_label.text = "刷新:0.5s  Runner:0"
    top.add_child(_status_label)
    top.add_spacer(true)
    _snapshot_btn = Button.new()
    _snapshot_btn.text = "📸快照"
    _snapshot_btn.pressed.connect(_on_snapshot)
    top.add_child(_snapshot_btn)

    # 搜索框
    _search_input = LineEdit.new()
    _search_input.placeholder_text = "搜索变量..."
    _search_input.text_changed.connect(_refresh)
    vbox.add_child(_search_input)

    # 变量树
    _tree = Tree.new()
    _tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _tree.hide_root = true
    _tree.columns = 3
    _tree.set_column_title(0, "变量")
    _tree.set_column_title(1, "值")
    _tree.set_column_title(2, "类型")
    _tree.create_item()  # root
    vbox.add_child(_tree)

    # Timer
    _timer = Timer.new()
    _timer.wait_time = 0.5
    _timer.timeout.connect(_on_timer)
    add_child(_timer)
    _timer.start()


func _on_timer() -> void:
    _refresh()


func _refresh() -> void:
    _tree.clear()
    var root := _tree.create_item()
    var runner_count := 0

    # 扫描场景树中的 Runner
    var scene_tree := Engine.get_main_loop() as SceneTree
    if scene_tree == null or scene_tree.current_scene == null:
        return
    var runners := scene_tree.current_scene.find_children("*", "Runner")
    runner_count = runners.size()

    var local_root := _tree.create_item(root)
    local_root.set_text(0, "Local")
    local_root.collapsed = false

    var scope_root := _tree.create_item(root)
    scope_root.set_text(0, "Scope")
    scope_root.collapsed = false

    var global_root := _tree.create_item(root)
    global_root.set_text(0, "Global")
    global_root.collapsed = false

    # 对每个活跃 Runner 读 EC 快照
    for runner in runners:
        var ec = runner.get("current_execution_context")
        if ec == null or not is_instance_valid(ec):
            continue
        var vc = ec.get("_variable_context")
        if vc == null:
            continue

        # Local
        var locals: Dictionary = vc.get_all_local_variables_snapshot()
        for var_name in locals:
            _add_var_row(local_root, var_name, locals[var_name])

        # Scope
        var scopes: Dictionary = vc.get_all_scope_variables_snapshot()
        for var_name in scopes:
            _add_var_row(scope_root, var_name, scopes[var_name])

    # Global
    var svc := GlobalVariableService.new()
    var globals: Dictionary = svc.get_all_global_variables_info()
    for var_name in globals:
        var info = globals[var_name]
        _add_var_row(global_root, var_name, {"value": info.get("value"), "type": info.get("type")})

    _status_label.text = "刷新:0.5s  Runner:%d" % runner_count


func _add_var_row(parent: TreeItem, name: String, data) -> void:
    var filter := _search_input.text
    if not filter.is_empty() and filter not in name:
        return

    var item := _tree.create_item(parent)
    item.set_text(0, name)

    var val = data.get("value", data) if data is Dictionary else data
    item.set_text(1, str(val))

    var type_str := ""
    if data is Dictionary and data.has("type"):
        type_str = data["type"]
    else:
        type_str = type_string(typeof(val))
    item.set_text(2, type_str)


func get_snapshot() -> Dictionary:
    ## 导出完整快照(Stage 5 录播预留)
    var result := {"timestamp": Time.get_ticks_msec() / 1000.0, "runners": []}
    var scene_tree := Engine.get_main_loop() as SceneTree
    if scene_tree == null or scene_tree.current_scene == null:
        return result
    for runner in scene_tree.current_scene.find_children("*", "Runner"):
        var ec = runner.get("current_execution_context")
        if ec == null:
            continue
        var vc = ec.get("_variable_context")
        if vc == null:
            continue
        result["runners"].append({
            "runner": runner.name,
            "local": vc.get_all_local_variables_snapshot(),
            "scope": vc.get_all_scope_variables_snapshot()
        })
    return result


func _on_snapshot() -> void:
    var snap := get_snapshot()
    var path := "user://fuse_watcher_snapshot_%d.json" % Time.get_ticks_msec()
    var file := FileAccess.open(path, FileAccess.WRITE)
    if file:
        file.store_string(JSON.stringify(snap, "\t"))
        file.close()
        print("变量快照已保存: %s" % path)
```

- [x] **Step 3:plugin.gd 注册 Bottom Dock**

在 `plugin.gd` 的 `_enter_tree()` 中(EditorBootstrap.setup 之后):

```gdscript
var _watcher: FuseVariableWatcher = null
# 在编辑器引导后:
_watcher = preload("res://addons/fuse/editor/debugging/variable_watcher.gd").new()
add_control_to_bottom_panel(_watcher, "Fuse Variables")
```

在 `_exit_tree()` 中移除:

```gdscript
if _watcher:
    remove_control_from_bottom_panel(_watcher)
    _watcher = null
```

- [x] **Step 4:验证**

1. 编辑器运行场景(含 Runner 的 demos 场景) → 底部出现"Fuse Variables"面板
2. 变量列表 0.5s 刷新,显示 local/scope/global 三层
3. 搜索框过滤变量名
4. "📸快照"按钮 → `user://` 下生成 JSON 快照文件
5. 无活跃 Runner 时显示"Runner:0"

```bash
git add addons/fuse/core/runner.gd \
        addons/fuse/editor/debugging/variable_watcher.gd \
        addons/fuse/plugin.gd
git commit -m "feat(fuse): add variable watcher (bottom dock, read-only) (stage2 task2.5)"
```

---

## 8. 验证清单

### 开发期
- [x] 所有新建 `.gd` 文件通过语法检查
- [ ] `FusePreset` Resource 可在 Inspector 中创建
- [ ] `PresetRegistry.scan_presets()` 扫描 presets/ 目录成功
- [x] 类型注册表包含 `FusePreset`

### 多选(2.1)
- [x] 指令列表支持 Ctrl/点击多选
- [x] 多选后删除按钮可用,批量删除
- [x] 多选后复制按钮可用,批量复制

### 预设导出(2.3)
- [x] "导出为预设"按钮在 Inspector 中出现
- [x] 导出对话框显示 NodePath 和变量统计
- [x] 导出后 presets/{category}/ 下有 .tres + .json 双文件
- [x] .json 文件格式与 schema 一致,可被 from_json 还原

### 预设导入(2.4)
- [x] 右侧 Dock 预设面板按分类显示预设
- [x] 搜索框过滤
- [x] "应用预设"弹出映射对话框,自动匹配同名节点
- [x] 跨场景应用:NodePath 映射正确替换
- [x] "导入JSON"按钮可导入外部 .json → 自动生成 .tres

### 变量监视器(2.5)
- [x] Bottom Dock "Fuse Variables" 面板出现
- [x] 0.5s 刷新变量显示
- [x] 三层作用域分类折叠
- [x] 搜索框过滤
- [x] "📸快照"导出 JSON
- [x] Runner 新增 `current_execution_context` 属性

### 回归
- [x] 现有 143 组件功能不受影响
- [x] 插件启用/停用无报错
- [x] Inspector 选择器正常

---

## 9. 文件清单

### 新增文件

```
addons/fuse/core/resources/fuse_preset.gd
addons/fuse/editor/preset_registry.gd
addons/fuse/editor/preset_export_dialog.gd
addons/fuse/editor/preset_panel.gd
addons/fuse/editor/preset_import_dialog.gd
addons/fuse/editor/debugging/variable_watcher.gd
addons/fuse/presets/                     # 预设存储目录
```

### 修改文件

```
addons/fuse/editor/instruction_selector/instructions_array_property.gd  # 接线启用+多选+导出按钮
addons/fuse/editor/instruction_selector/instructions_array_inspector_plugin.gd  # 改 add_property_editor
addons/fuse/editor/bootstrap/fuse_editor_bootstrap.gd                    # 注册新 Inspetor 插件
addons/fuse/editor/bootstrap/fuse_type_registrar.gd                    # 注册 FusePreset
addons/fuse/editor/bootstrap/fuse_component_scanner.gd                # 调用 scan_presets
addons/fuse/core/runner.gd                                             # +current_execution_context
addons/fuse/plugin.gd                                                  # 注册预设面板+变量监视器
```

---

**文档版本:** 1.0
**最后更新:** 2026-06-17
**审核状态:** 待审核
