# Event 和 Condition 选择器系统设计

**日期**: 2026-01-28
**状态**: 设计阶段
**作者**: AI + Human

## 概述

为 Bricks 系统的 Event 和 Condition 类添加类似 Instruction Selector 的选择机制和界面，提供统一的用户体验。

### 背景

- **Instruction Selector** 已经实现，支持分类树、搜索、图标等功能
- **Event 和 Condition** 目前只能通过 Godot 原生的资源选择器选择，体验不佳
- 需要统一的选择器界面，支持分类、搜索和自定义图标

### 关键差异

| 组件类型 | 使用场景 | 选择方式 |
|---------|---------|---------|
| **Instruction** | 添加到指令序列 | 多选（数组） |
| **Event** | Trigger.event_definition | 单选 |
| **Condition** | If/Else.condition | 单选 |

---

## 架构设计

### 1. 元数据系统重构

#### 1.1 BricksMetadata 基类

创建通用元数据基类，包含所有组件共享的字段：

```gdscript
# addons/bricks/editor/metadata/bricks_metadata.gd
@tool
class_name BricksMetadata extends Resource

# 本地化字段
@export var name_key: String = ""
@export var category_key: String = ""
@export var description_key: String = ""

# 向后兼容字段（已废弃）
@export var name: String = ""
@export var category: String = ""
@export var description: String = ""

# 其他通用字段
@export var keywords: Array = []
@export var builtin_icon: String = ""

# 本地化辅助方法
func get_localized_name() -> String:
    if _bricks_localization_class == null:
        _bricks_localization_class = load("res://addons/bricks/localization/bricks_localization.gd")

    if name_key and not name_key.is_empty():
        return _bricks_localization_class.translate(name_key)
    return name if name else ""

func get_localized_category() -> String:
    if _bricks_localization_class == null:
        _bricks_localization_class = load("res://addons/bricks/localization/bricks_localization.gd")

    if category_key and not category_key.is_empty():
        return _bricks_localization_class.translate(category_key)
    return category if category else "未分类"

func get_localized_description() -> String:
    if _bricks_localization_class == null:
        _bricks_localization_class = load("res://addons/bricks/localization/bricks_localization.gd")

    if description_key and not description_key.is_empty():
        return _bricks_localization_class.translate(description_key)
    return description if description else ""

func get_icon_texture() -> Texture2D:
    return BricksIconManager.get_builtin_icon(builtin_icon)

# 缓存本地化类引用
static var _bricks_localization_class: RefCounted = null
```

#### 1.2 InstructionMetadata 重构

将现有的 `InstructionMetadata` 改为继承 `BricksMetadata`：

```gdscript
# addons/bricks/editor/instruction_selector/instructions_metadata.gd
@tool
class_name InstructionMetadata extends BricksMetadata

# 只保留 Instruction 特有的字段
enum ExecutionHint {
    UNKNOWN,
    LIKELY_SYNC,
    LIKELY_ASYNC,
    FORCE_SYNC,
    FORCE_ASYNC
}

@export var execution_hint: ExecutionHint = ExecutionHint.UNKNOWN

# 所有其他字段从 BricksMetadata 继承
```

#### 1.3 EventMetadata 和 ConditionMetadata

创建新的元数据类：

```gdscript
# addons/bricks/editor/metadata/event_metadata.gd
@tool
class_name EventMetadata extends BricksMetadata
    # 目前不需要 Event 特有字段
    # 所有字段都继承自 BricksMetadata

# addons/bricks/editor/metadata/condition_metadata.gd
@tool
class_name ConditionMetadata extends BricksMetadata
    # 目前不需要 Condition 特有字段
    # 所有字段都继承自 BricksMetadata
```

---

### 2. 注册系统

#### 2.1 ComponentRegistry 通用注册器

```gdscript
# addons/bricks/editor/component_registry.gd
@tool
class_name ComponentRegistry extends RefCounted

enum ComponentType {
    INSTRUCTION,
    EVENT,
    CONDITION
}

static var _components: Dictionary = {
    ComponentType.INSTRUCTION: [],
    ComponentType.EVENT: [],
    ComponentType.CONDITION: []
}

static var _component_map: Dictionary = {}

## 通用注册方法
static func register(component_type: ComponentType, component_class: GDScript, metadata: BricksMetadata):
    var identifier = metadata.name_key if metadata.name_key else metadata.name

    if not identifier or identifier.is_empty():
        return

    if _component_map.has(identifier):
        print("警告：组件 '" + identifier + "' 已注册，将被覆盖")

    var component_info = {
        "class": component_class,
        "metadata": metadata,
        "type": component_type
    }

    _components[component_type].append(component_info)
    _component_map[identifier] = component_info

## 获取所有指定类型的组件
static func get_all(component_type: ComponentType) -> Array[Dictionary]:
    return _components.get(component_type, [])

## 根据名称获取组件
static func get_by_name(name: String) -> Dictionary:
    return _component_map.get(name, {})

## 获取组件数量
static func get_count(component_type: ComponentType) -> int:
    return _components.get(component_type, []).size()

## 清空所有注册的组件
static func clear_all():
    for type in _components.keys():
        _components[type].clear()
    _component_map.clear()

## 搜索组件
static func search(component_type: ComponentType, query: String) -> Array[Dictionary]:
    var components = get_all(component_type)
    var results = []

    if query.is_empty():
        return components

    var search_lower = query.to_lower()

    for component_info in components:
        var metadata = component_info.metadata

        # 检查名称
        var name = metadata.get_localized_name()
        if search_lower in name.to_lower():
            results.append(component_info)
            continue

        # 检查分类
        var category = metadata.get_localized_category()
        if search_lower in category.to_lower():
            results.append(component_info)
            continue

        # 检查关键词
        for keyword in metadata.keywords:
            if search_lower in keyword.to_lower():
                results.append(component_info)
                break

    return results
```

#### 2.2 EventRegistry 和 ConditionRegistry

```gdscript
# addons/bricks/editor/event_registry.gd
@tool
class_name EventRegistry extends RefCounted

## 注册事件类
static func register_event(event_class: GDScript):
    if not event_class.has_method("_get_event_metadata"):
        return

    var metadata = event_class._get_event_metadata()
    if not metadata:
        return

    ComponentRegistry.register(
        ComponentRegistry.ComponentType.EVENT,
        event_class,
        metadata
    )

# addons/bricks/editor/condition_registry.gd
@tool
class_name ConditionRegistry extends RefCounted

## 注册条件类
static func register_condition(condition_class: GDScript):
    if not condition_class.has_method("_get_condition_metadata"):
        return

    var metadata = condition_class._get_condition_metadata()
    if not metadata:
        return

    ComponentRegistry.register(
        ComponentRegistry.ComponentType.CONDITION,
        condition_class,
        metadata
    )
```

#### 2.3 修改 InstructionRegistry

```gdscript
# 修改后的 instruction_registry.gd
static func register_instruction(instruction_class: GDScript):
    if not instruction_class.has_method("_get_instruction_metadata"):
        return

    var metadata = instruction_class._get_instruction_metadata()
    if not metadata:
        return

    ComponentRegistry.register(
        ComponentRegistry.ComponentType.INSTRUCTION,
        instruction_class,
        metadata
    )

# 保持向后兼容的静态方法
static func get_all_instructions() -> Array[Dictionary]:
    return ComponentRegistry.get_all(ComponentRegistry.ComponentType.INSTRUCTION)

static func get_instruction_by_name(name: String) -> Dictionary:
    return ComponentRegistry.get_by_name(name)

static func get_instruction_count() -> int:
    return ComponentRegistry.get_count(ComponentRegistry.ComponentType.INSTRUCTION)
```

---

### 3. 选择器 UI

#### 3.1 ComponentSelector 通用选择器

```gdscript
# addons/bricks/editor/component_selector/component_selector.gd
@tool
class_name ComponentSelector extends AcceptDialog

var edited_object: Object
var property_name: String
var component_type: ComponentRegistry.ComponentType
var category_tree: Tree
var search_box: LineEdit
var _updating_ui: bool = false
var _bricks_localization_class: RefCounted = null

func _init(p_edited_object: Object, p_property_name: String, p_component_type: ComponentRegistry.ComponentType):
    edited_object = p_edited_object
    property_name = p_property_name
    component_type = p_component_type

func _ready() -> void:
    if _bricks_localization_class == null:
        _bricks_localization_class = load("res://addons/bricks/localization/bricks_localization.gd")

    _refresh_locale_if_needed()
    _setup_dialog()
    _create_ui()
    _update_component_list("")

func _setup_dialog() -> void:
    var title_key = ""
    match component_type:
        ComponentRegistry.ComponentType.EVENT:
            title_key = "BRICKS_UI_EVENT_SELECTOR_TITLE"
        ComponentRegistry.ComponentType.CONDITION:
            title_key = "BRICKS_UI_CONDITION_SELECTOR_TITLE"
        _:
            title_key = "BRICKS_UI_COMPONENT_SELECTOR_TITLE"

    if _bricks_localization_class and _bricks_localization_class.has_method("translate"):
        self.title = _bricks_localization_class.translate(title_key)
    else:
        self.title = "选择组件"

    self.size = Vector2i(600, 600)
    self.popup_centered()

func _create_ui() -> void:
    var main_vbox = VBoxContainer.new()

    # 搜索框
    search_box = LineEdit.new()
    if _bricks_localization_class and _bricks_localization_class.has_method("translate"):
        search_box.placeholder_text = _bricks_localization_class.translate("BRICKS_UI_SEARCH_PLACEHOLDER")
    else:
        search_box.placeholder_text = "搜索..."
    search_box.text_changed.connect(_on_search_text_changed)
    main_vbox.add_child(search_box)

    # 分类树
    category_tree = Tree.new()
    category_tree.columns = 1
    category_tree.hide_root = true
    category_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    category_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
    category_tree.item_selected.connect(_on_category_selected)

    var root = category_tree.create_item()
    root.set_text(0, "Root")

    main_vbox.add_child(category_tree)
    self.add_child(main_vbox)

func _update_component_list(search_query: String = ""):
    if _updating_ui:
        return

    _updating_ui = true
    var search_results = ComponentRegistry.search(component_type, search_query)
    call_deferred("_update_category_tree_deferred", search_results)

func _update_category_tree_deferred(components: Array[Dictionary]):
    _update_category_tree(components)
    _updating_ui = false

func _update_category_tree(components: Array[Dictionary]):
    if not category_tree or not category_tree.is_inside_tree():
        return

    category_tree.clear()
    var root = category_tree.create_item()
    root.set_text(0, "Root")

    # 按分类组织
    var categories = {}
    for component_info in components:
        if not component_info.has("metadata"):
            continue

        var metadata = component_info.metadata
        if metadata == null:
            continue

        var category = metadata.get_localized_category()
        if not categories.has(category):
            categories[category] = []
        categories[category].append(component_info)

    # 创建分类树
    for category_name in categories.keys():
        var category_item = category_tree.create_item(root)
        category_item.set_text(0, category_name)
        category_item.set_collapsed(false)

        for component_info in categories[category_name]:
            var metadata = component_info.metadata
            var localized_name = metadata.get_localized_name()
            var localized_desc = metadata.get_localized_description()

            if localized_name == null or localized_name.is_empty():
                continue

            var component_item = category_tree.create_item(category_item)
            component_item.set_text(0, localized_name)
            component_item.set_metadata(0, component_info)
            component_item.set_selectable(0, true)

            if localized_desc:
                component_item.set_tooltip_text(0, localized_desc)

            var icon = metadata.get_icon_texture()
            if icon:
                component_item.set_icon(0, icon)

func _on_category_selected():
    if _updating_ui:
        return

    var selected = category_tree.get_selected()
    if not selected:
        return

    var component_info = selected.get_metadata(0)
    if component_info:
        _select_component(component_info)

func _select_component(component_info: Dictionary):
    var component_class = component_info.class
    if not component_class:
        print("错误：组件类为空")
        return

    var component_instance = component_class.new()

    # 设置到属性
    edited_object.set(property_name, component_instance)

    # 等待一帧后验证
    await get_tree().process_frame

    # 通知编辑器更新
    if edited_object.has_method("notify_property_list_changed"):
        edited_object.notify_property_list_changed()

    if edited_object is Resource:
        edited_object.emit_changed()

    # 使用本地化名称输出日志
    var metadata = component_info.metadata
    var localized_name = metadata.get_localized_name() if metadata else "未知"
    print("成功选择组件：", localized_name)

    # 关闭对话框
    self.hide()

func _on_search_text_changed(new_text: String) -> void:
    _update_component_list(new_text)

func _refresh_locale_if_needed() -> void:
    if not _bricks_localization_class or not _bricks_localization_class.has_method("set_locale"):
        return

    if OS.has_feature("editor"):
        var editor_settings = EditorInterface.get_editor_settings()
        if editor_settings:
            var editor_locale = editor_settings.get("interface/editor/editor_language")
            if editor_locale:
                if editor_locale.begins_with("en"):
                    _bricks_localization_class.set_locale(_bricks_localization_class.Locale.EN_US)
                elif editor_locale.begins_with("zh"):
                    _bricks_localization_class.set_locale(_bricks_localization_class.Locale.ZH_CN)
```

---

### 4. Inspector 集成

#### 4.1 扩展 Inspector 插件

修改现有的 `instructions_array_inspector_plugin.gd`，改名为 `bricks_inspector_plugin.gd`：

```gdscript
# addons/bricks/editor/bricks_inspector_plugin.gd
@tool
extends EditorInspectorPlugin

var _bricks_localization_class: RefCounted = null

func _can_handle(object: Object) -> bool:
    return true

func _parse_property(object: Object, type: Variant.Type, name: String, hint_type: PropertyHint, hint_string: String, usage_flags: int, wide: bool) -> bool:
    # 1. 检测 Array[BaseInstruction]
    var is_instruction_array = (
        type == TYPE_ARRAY and
        (
            ("BaseInstruction" in hint_string) or
            (name == "instructions") or
            (name.ends_with("_instructions"))
        )
    )
    if is_instruction_array:
        _add_instruction_selector_button(object, name)
        return false

    # 2. 检测 BaseEvent
    var is_event = (
        type == TYPE_OBJECT and
        hint_type == PROPERTY_HINT_RESOURCE_TYPE and
        "BaseEvent" in hint_string
    )
    if is_event:
        _add_component_selector_button(object, name, ComponentSelector.ComponentType.EVENT)
        return false

    # 3. 检测 BaseCondition
    var is_condition = (
        type == TYPE_OBJECT and
        hint_type == PROPERTY_HINT_RESOURCE_TYPE and
        "BaseCondition" in hint_string
    )
    if is_condition:
        _add_component_selector_button(object, name, ComponentSelector.ComponentType.CONDITION)
        return false

    return false

func _add_instruction_selector_button(object: Object, property_name: String):
    _ensure_localization_loaded()

    var container = VBoxContainer.new()
    var hbox = HBoxContainer.new()
    hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

    var button = Button.new()
    button.icon = BricksIconManager.get_builtin_icon("Add")

    if _bricks_localization_class and _bricks_localization_class.has_method("translate"):
        button.text = _bricks_localization_class.translate("BRICKS_UI_BTN_CLICK_TO_ADD_INSTRUCTION")
        button.tooltip_text = _bricks_localization_class.translate("BRICKS_UI_BTN_CLICK_TO_ADD_INSTRUCTION_TOOLTIP")
    else:
        button.text = " 点击以添加指令..."
        button.tooltip_text = "点击以添加指令..."

    button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    button.alignment = HORIZONTAL_ALIGNMENT_CENTER
    button.custom_minimum_size.x = 200
    button.pressed.connect(_open_instruction_selector.bind(object, property_name))

    hbox.add_child(button)
    container.add_child(hbox)
    add_custom_control(container)

func _add_component_selector_button(object: Object, property_name: String, component_type: ComponentSelector.ComponentType):
    _ensure_localization_loaded()

    var container = VBoxContainer.new()
    var hbox = HBoxContainer.new()
    hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

    var button = Button.new()
    button.icon = BricksIconManager.get_builtin_icon("Edit")

    var button_text_key = ""
    var button_tooltip_key = ""

    match component_type:
        ComponentSelector.ComponentType.EVENT:
            button_text_key = "BRICKS_UI_BTN_CLICK_TO_SELECT_EVENT"
            button_tooltip_key = "BRICKS_UI_BTN_CLICK_TO_SELECT_EVENT_TOOLTIP"
        ComponentSelector.ComponentType.CONDITION:
            button_text_key = "BRICKS_UI_BTN_CLICK_TO_SELECT_CONDITION"
            button_tooltip_key = "BRICKS_UI_BTN_CLICK_TO_SELECT_CONDITION_TOOLTIP"

    if _bricks_localization_class and _bricks_localization_class.has_method("translate"):
        button.text = _bricks_localization_class.translate(button_text_key)
        button.tooltip_text = _bricks_localization_class.translate(button_tooltip_key)
    else:
        button.text = " 点击选择..."
        button.tooltip_text = "点击选择..."

    button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    button.alignment = HORIZONTAL_ALIGNMENT_CENTER
    button.custom_minimum_size.x = 200
    button.pressed.connect(_open_component_selector.bind(object, property_name, component_type))

    hbox.add_child(button)
    container.add_child(hbox)
    add_custom_control(container)

func _open_instruction_selector(object: Object, property_name: String) -> void:
    var selector = InstructionSelector.new(object, property_name)
    EditorInterface.get_base_control().add_child(selector)
    selector.popup()

func _open_component_selector(object: Object, property_name: String, component_type: ComponentSelector.ComponentType) -> void:
    var selector = ComponentSelector.new(object, property_name, component_type)
    EditorInterface.get_base_control().add_child(selector)
    selector.popup()

func _ensure_localization_loaded() -> void:
    if _bricks_localization_class == null:
        _bricks_localization_class = load("res://addons/bricks/localization/bricks_localization.gd")
```

#### 4.2 更新 plugin.gd

```gdscript
# 在 plugin.gd 中更新插件注册
var bricks_inspector_plugin: EditorInspectorPlugin

func _enter_tree():
    # ... 其他初始化代码 ...

    # 修改插件注册
    bricks_inspector_plugin = preload("res://addons/bricks/editor/bricks_inspector_plugin.gd").new()
    add_inspector_plugin(bricks_inspector_plugin)
    print("Bricks Inspector 插件已注册")

    # ... 其他代码 ...

func _exit_tree():
    # ... 其他清理代码 ...

    # 清理 Inspector 插件
    remove_inspector_plugin(bricks_inspector_plugin)

    # ... 其他代码 ...
```

---

### 5. 组件元数据方法

#### 5.1 在 BaseEvent 中添加

```gdscript
# 在 BaseEvent 中添加
@abstract
static func _get_event_metadata() -> EventMetadata:
    return null
```

#### 5.2 在 BaseCondition 中添加

```gdscript
# 在 BaseCondition 中添加
@abstract
static func _get_condition_metadata() -> ConditionMetadata:
    return null
```

#### 5.3 在具体实现中示例

```gdscript
# EventOnReady 示例
class_name EventOnReady extends BaseEvent

static func _get_event_metadata() -> EventMetadata:
    var metadata = EventMetadata.new()
    metadata.name_key = "BRICKS_EVENT_ON_READY_NAME"
    metadata.category_key = "BRICKS_CATEGORY_LIFECYCLE"
    metadata.description_key = "BRICKS_EVENT_ON_READY_DESC"
    metadata.keywords = ["ready", "初始化", "启动", "start", "init"]
    metadata.builtin_icon = "HostNode"
    return metadata

# VariableComparisonCondition 示例
class_name VariableComparisonCondition extends BaseCondition

static func _get_condition_metadata() -> ConditionMetadata:
    var metadata = ConditionMetadata.new()
    metadata.name_key = "BRICKS_CONDITION_VARIABLE_COMPARISON_NAME"
    metadata.category_key = "BRICKS_CATEGORY_VARIABLE"
    metadata.description_key = "BRICKS_CONDITION_VARIABLE_COMPARISON_DESC"
    metadata.keywords = ["变量", "比较", "variable", "comparison", "等于", "大于"]
    metadata.builtin_icon = "KeyCuve"
    return metadata
```

---

### 6. 插件初始化

#### 6.1 在 plugin.gd 中注册所有组件

```gdscript
# 在 plugin.gd 中修改 _register_all_instructions 为 _register_all_components
func _register_all_components():
    # 1. 注册指令
    _register_instructions()

    # 2. 注册事件
    _register_events()

    # 3. 注册条件
    _register_conditions()

func _register_instructions():
    var instruction_folders = ["res://addons/bricks/instructions/", "res://addons/bricks/integration/"]
    var all_instruction_files: Array[String] = []

    for folder in instruction_folders:
        var instruction_files = _scan_components_recursive(folder)
        all_instruction_files.append_array(instruction_files)

    var registered_count = 0
    for file_path in all_instruction_files:
        var script = load(file_path) as GDScript
        if not script:
            continue

        if not script.has_method("_get_instruction_metadata"):
            continue

        var metadata = script._get_instruction_metadata()
        if not metadata:
            continue

        var has_identifier = false
        if metadata.name_key and not metadata.name_key.is_empty():
            has_identifier = true
        elif metadata.name and not metadata.name.is_empty():
            has_identifier = true

        if not has_identifier:
            continue

        InstructionRegistry.register_instruction(script)
        registered_count += 1

    print("Bricks: 注册完成 - 指令 %d 个" % registered_count)

func _register_events():
    var event_folders = ["res://addons/bricks/events/"]
    var all_event_files: Array[String] = []

    for folder in event_folders:
        var event_files = _scan_components_recursive(folder)
        all_event_files.append_array(event_files)

    var registered_count = 0
    for file_path in all_event_files:
        var script = load(file_path) as GDScript
        if not script:
            continue

        if not script.has_method("_get_event_metadata"):
            continue

        var metadata = script._get_event_metadata()
        if not metadata:
            continue

        var has_identifier = false
        if metadata.name_key and not metadata.name_key.is_empty():
            has_identifier = true
        elif metadata.name and not metadata.name.is_empty():
            has_identifier = true

        if not has_identifier:
            continue

        EventRegistry.register_event(script)
        registered_count += 1

    print("Bricks: 注册完成 - 事件 %d 个" % registered_count)

func _register_conditions():
    var condition_folders = ["res://addons/bricks/conditions/"]
    var all_condition_files: Array[String] = []

    for folder in condition_folders:
        var condition_files = _scan_components_recursive(folder)
        all_condition_files.append_array(condition_files)

    var registered_count = 0
    for file_path in all_condition_files:
        var script = load(file_path) as GDScript
        if not script:
            continue

        if not script.has_method("_get_condition_metadata"):
            continue

        var metadata = script._get_condition_metadata()
        if not metadata:
            continue

        var has_identifier = false
        if metadata.name_key and not metadata.name_key.is_empty():
            has_identifier = true
        elif metadata.name and not metadata.name.is_empty():
            has_identifier = true

        if not has_identifier:
            continue

        ConditionRegistry.register_condition(script)
        registered_count += 1

    print("Bricks: 注册完成 - 条件 %d 个" % registered_count)

func _scan_components_recursive(folder: String) -> Array[String]:
    var files: Array[String] = []
    var dir = DirAccess.open(folder)
    if not dir:
        return files

    dir.list_dir_begin()
    var file_name = dir.get_next()
    while file_name != "":
        var full_path = folder.path_join(file_name)

        if dir.current_is_dir():
            if not file_name.begins_with("."):
                var sub_files = _scan_components_recursive(full_path)
                files.append_array(sub_files)
        elif file_name.ends_with(".gd"):
            if not file_name.begins_with("base_"):  # 跳过基类
                files.append(full_path)

        file_name = dir.get_next()

    return files
```

---

## 文件结构

```
addons/bricks/editor/
├── metadata/
│   ├── bricks_metadata.gd          (新建)
│   ├── event_metadata.gd           (新建)
│   └── condition_metadata.gd       (新建)
├── component_selector/
│   └── component_selector.gd        (新建)
├── component_registry.gd           (新建)
├── event_registry.gd               (新建)
├── condition_registry.gd           (新建)
├── bricks_inspector_plugin.gd      (重命名自 instructions_array_inspector_plugin.gd)
├── instruction_selector/
│   ├── instructions_metadata.gd    (修改 - 继承 BricksMetadata)
│   ├── instruction_registry.gd     (修改 - 使用 ComponentRegistry)
│   └── instructions_selector.gd    (保持不变)
└── instructions_search.gd          (保持不变)

addons/bricks/core/base/
├── base_event.gd                   (修改 - 添加 _get_event_metadata)
└── base_condition.gd               (修改 - 添加 _get_condition_metadata)

addons/bricks/events/
└── event_*.gd                      (修改 - 添加 _get_event_metadata)

addons/bricks/conditions/
└── *_condition.gd                  (修改 - 添加 _get_condition_metadata)

addons/bricks/plugin.gd             (修改 - 更新注册逻辑)
```

---

## 本地化键

需要添加的本地化键（参考现有的指令本地化）：

```csv
# UI 文本
BRICKS_UI_EVENT_SELECTOR_TITLE,选择事件,Select Event
BRICKS_UI_CONDITION_SELECTOR_TITLE,选择条件,Select Condition
BRICKS_UI_BTN_CLICK_TO_SELECT_EVENT, 点击选择事件...,Click to select event...
BRICKS_UI_BTN_CLICK_TO_SELECT_EVENT_TOOLTIP,点击选择事件,Click to select event
BRICKS_UI_BTN_CLICK_TO_SELECT_CONDITION, 点击选择条件...,Click to select condition...
BRICKS_UI_BTN_CLICK_TO_SELECT_CONDITION_TOOLTIP,点击选择条件,Click to select condition

# 事件分类
BRICKS_CATEGORY_LIFECYCLE,生命周期,Lifecycle
BRICKS_CATEGORY_INPUT,输入,Input
BRICKS_CATEGORY_SIGNAL,信号,Signal

# 条件分类
BRICKS_CATEGORY_VARIABLE,变量,Variable
BRICKS_CATEGORY_NODE,节点,Node
BRICKS_CATEGORY_LOGIC,逻辑,Logic

# 具体事件（示例）
BRICKS_EVENT_ON_READY_NAME,On Ready,On Ready
BRICKS_EVENT_ON_READY_DESC,场景就绪时触发,Triggered when scene is ready

# 具体条件（示例）
BRICKS_CONDITION_VARIABLE_COMPARISON_NAME,变量比较,Variable Comparison
BRICKS_CONDITION_VARIABLE_COMPARISON_DESC,比较变量值与给定值,Compare variable value with given value
```

---

## 实施步骤

### 阶段 1：元数据系统（1-2小时）
1. 创建 `BricksMetadata` 基类
2. 重构 `InstructionMetadata` 继承 `BricksMetadata`
3. 创建 `EventMetadata` 和 `ConditionMetadata`
4. 测试 Instruction 元数据是否正常工作

### 阶段 2：注册系统（1-2小时）
1. 创建 `ComponentRegistry`
2. 创建 `EventRegistry` 和 `ConditionRegistry`
3. 修改 `InstructionRegistry` 使用 `ComponentRegistry`
4. 在 `plugin.gd` 中添加事件和条件注册逻辑

### 阶段 3：选择器 UI（2-3小时）
1. 创建 `ComponentSelector`
2. 重命名并修改 `bricks_inspector_plugin.gd`
3. 添加 Event 和 Condition 的选择按钮
4. 测试选择器功能

### 阶段 4：组件元数据（2-3小时）
1. 在 `BaseEvent` 和 `BaseCondition` 添加元数据方法
2. 为所有现有 Event 添加 `_get_event_metadata()`
3. 为所有现有 Condition 添加 `_get_condition_metadata()`
4. 添加本地化键

### 阶段 5：测试和优化（1-2小时）
1. 测试 Event 选择器
2. 测试 Condition 选择器
3. 修复发现的问题
4. 性能优化

**总计：7-12 小时**

---

## 优势

1. **代码复用** - 元数据和注册系统高度复用，减少维护成本
2. **一致性** - 三种组件使用相同的架构和 UI 模式
3. **可扩展** - 未来添加新组件类型（如 Variable）很容易
4. **向后兼容** - Instruction 系统保持向后兼容
5. **用户体验** - 统一的选择器界面，支持搜索和分类

---

## 风险和注意事项

1. **破坏性更改** - 需要确保 `InstructionMetadata` 重构后向后兼容
2. **性能** - 大量组件时搜索可能需要优化
3. **本地化** - 需要为所有 Event 和 Condition 添加翻译键
4. **测试覆盖** - 需要确保所有现有功能不受影响

---

## 后续优化

1. **预览功能** - 在选择器中显示组件的详细说明
2. **收藏夹** - 允许用户收藏常用组件
3. **历史记录** - 记录最近使用的组件
4. **筛选器** - 添加更高级的筛选选项
5. **组件创建** - 在选择器中直接创建新组件
