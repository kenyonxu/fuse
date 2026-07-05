# FlowKit 插件编辑器定制支持实现分析

## 概述

FlowKit 是一个为 Godot 引擎开发的可视化事件系统插件，提供了类似 Clickteam Fusion/Construct 3 的事件编辑功能。本文档深入分析 FlowKit 插件如何实现编辑器中的定制编辑器支持，包括其架构设计、UI 系统、工作流程、数据管理等方面。

## 1. 整体架构和编辑器集成

### 1.1 插件入口点

FlowKit 插件通过标准的 Godot 插件机制集成到编辑器中：

```gdscript
# flowkit.gd
@tool
extends EditorPlugin

func _enter_tree() -> void:
    # 加载 UI
    editor = preload("res://addons/flowkit/ui/editor.tscn").instantiate()
    
    # 加载注册表
    action_registry = preload("res://addons/flowkit/registry.gd").new()
    action_registry.load_providers()
    
    # 初始化生成器
    generator = preload("res://addons/flowkit/generator.gd").new(get_editor_interface())
    
    # 传递编辑器接口和注册表到 UI
    editor.set_editor_interface(get_editor_interface())
    editor.set_registry(action_registry)
    editor.set_generator(generator)
    
    # 添加运行时自动加载单例
    add_autoload_singleton("FlowKitSystem", "res://addons/flowkit/runtime/flowkit_system.gd")
    add_autoload_singleton("FlowKit", "res://addons/flowkit/runtime/flowkit_engine.gd")
    
    # 添加编辑器面板
    add_control_to_bottom_panel(editor, "FlowKit")
```

**关键设计特点：**
- 使用 `EditorPlugin` 作为入口点，这是 Godot 编辑器插件的标准方式
- 将编辑器 UI 作为底部面板添加，提供持久化的编辑界面
- 通过 `EditorInterface` 获取编辑器上下文，实现与编辑器的深度集成
- 注册运行时自动加载单例，确保编辑时和运行时的一致性

### 1.2 核心组件架构

FlowKit 采用了模块化的架构设计，主要组件包括：

1. **编辑器插件入口** ([`flowkit.gd`](addons/flowkit/flowkit.gd:1))：负责插件的生命周期管理
2. **注册表系统** ([`registry.gd`](addons/flowkit/registry.gd:1))：管理所有事件、条件、动作提供者
3. **UI 编辑器** ([`editor.gd`](addons/flowkit/ui/editor.gd:1))：主要的用户界面控制器
4. **代码生成器** ([`generator.gd`](addons/flowkit/generator.gd:1))：自动生成事件、条件、动作代码
5. **运行时系统** ([`flowkit_system.gd`](addons/flowkit/runtime/flowkit_system.gd:1))：运行时执行引擎

### 1.3 编辑器接口集成

FlowKit 通过 `EditorInterface` 实现与编辑器的深度集成：

```gdscript
# 获取当前编辑的场景根节点
var scene_root = editor_interface.get_edited_scene_root()

# 获取编辑器基础控件以获取主题图标
var icon = editor_interface.get_base_control().get_theme_icon(node.get_class(), "EditorIcons")

# 重启编辑器（在生成新提供者后）
editor_interface.restart_editor()
```

这种集成方式使得 FlowKit 能够：
- 实时响应场景变化
- 使用编辑器的主题和图标系统
- 访问场景树结构
- 提供编辑器级别的操作（如重启）

## 2. 编辑器 UI 系统设计和实现

### 2.1 主编辑器界面

主编辑器界面 ([`editor.tscn`](addons/flowkit/ui/editor.tscn:1) 和 [`editor.gd`](addons/flowkit/ui/editor.gd:1)) 采用了分层的布局设计：

```
Control (根容器)
├── Background (背景面板)
├── OuterVBox (垂直布局容器)
│   ├── TopMargin (顶部边距)
│   │   └── MenuBar (菜单栏)
│   ├── ScrollContainer (滚动容器)
│   │   └── MarginContainer
│   │       └── BlocksContainer (块容器，支持拖拽)
│   │           └── EmptyLabel (空状态标签)
│   └── BottomMargin (底部边距)
│       └── ButtonContainer (按钮容器)
│           ├── AddEventButton
│           ├── AddConditionButton
│           └── AddActionButton
└── 模态对话框组
    ├── SelectNodeModal
    ├── SelectEventModal
    ├── SelectConditionModal
    ├── SelectActionModal
    └── ExpressionModal
```

**设计特点：**
- 使用 `ScrollContainer` 确保内容可滚动，适应不同数量的块
- 分离菜单栏、内容区域和操作按钮，提供清晰的视觉层次
- 集成多个模态对话框，支持不同的用户交互流程

### 2.2 状态管理系统

编辑器实现了完善的状态管理，根据场景状态显示不同的 UI：

```gdscript
# 空状态（无场景加载）
func _show_empty_state() -> void:
    empty_label.visible = true
    add_event_btn.visible = false
    add_condition_btn.visible = false
    add_action_btn.visible = false

# 空块状态（场景已加载但无块）
func _show_empty_blocks_state() -> void:
    empty_label.visible = false
    add_event_btn.visible = true
    add_condition_btn.visible = true
    add_action_btn.visible = true

# 内容状态（有块显示）
func _show_content_state() -> void:
    empty_label.visible = false
    add_event_btn.visible = true
    add_condition_btn.visible = true
    add_action_btn.visible = true
```

### 2.3 场景监听和自动加载

编辑器通过 `_process` 方法持续监听场景变化：

```gdscript
func _process(_delta: float) -> void:
    if not editor_interface:
        return
    
    var scene_root = editor_interface.get_edited_scene_root()
    if not scene_root:
        if current_scene_name != "":
            current_scene_name = ""
            _clear_all_blocks()
            _show_empty_state()
        return
    
    var scene_path = scene_root.scene_file_path
    if scene_path == "":
        if current_scene_name != "":
            current_scene_name = ""
            _clear_all_blocks()
            _show_empty_state()
        return
    
    var scene_name = scene_path.get_file().get_basename()
    if scene_name != current_scene_name:
        current_scene_name = scene_name
        _load_scene_sheet()
```

这种设计确保了：
- 场景切换时自动加载对应的事件表
- 新场景或未保存场景时显示适当的空状态
- 场景名称变化时自动重新加载数据

## 3. 工作流程系统的实现机制

### 3.1 工作流程状态机

FlowKit 实现了一个复杂的工作流程系统，用于处理事件、条件、动作的创建和编辑：

```gdscript
# 工作流程状态变量
var pending_block_type: String = ""  # "event", "condition", "action"
var pending_node_path: String = ""
var pending_id: String = ""
var pending_target_node = null  # 用于插入/替换操作
```

工作流程支持多种操作模式：
- **创建模式**：添加新的事件、条件或动作
- **编辑模式**：修改现有块的参数
- **替换模式**：替换现有块的类型但保持位置和子元素

### 3.2 多步骤向导式流程

工作流程采用多步骤的向导式设计：

1. **节点选择** → 2. **类型选择** → 3. **参数输入** → 4. **确认创建**

```gdscript
# 步骤1：开始添加工作流程
func _start_add_workflow(block_type: String) -> void:
    pending_block_type = block_type
    pending_target_node = null
    
    var scene_root = editor_interface.get_edited_scene_root()
    if not scene_root:
        return
    
    select_node_modal.set_editor_interface(editor_interface)
    select_node_modal.populate_from_scene(scene_root)
    select_node_modal.popup_centered()

# 步骤2：节点选择后的处理
func _on_node_selected(node_path: String, node_class: String) -> void:
    pending_node_path = node_path
    select_node_modal.hide()
    
    match pending_block_type:
        "event", "event_replace":
            select_event_modal.populate_events(node_path, node_class)
            select_event_modal.popup_centered()
        "condition", "condition_replace":
            select_condition_modal.populate_conditions(node_path, node_class)
            select_condition_modal.popup_centered()
        "action", "action_replace":
            select_action_modal.populate_actions(node_path, node_class)
            select_action_modal.popup_centered()

# 步骤3：类型选择后的处理
func _on_event_selected(node_path: String, event_id: String, inputs: Array) -> void:
    pending_id = event_id
    select_event_modal.hide()
    
    if inputs.size() > 0:
        expression_modal.populate_inputs(node_path, event_id, inputs)
        expression_modal.popup_centered()
    else:
        if pending_block_type == "event_replace":
            _replace_event({})
        else:
            _finalize_event_creation({})

# 步骤4：参数确认后的处理
func _on_expressions_confirmed(_node_path: String, _id: String, expressions: Dictionary) -> void:
    expression_modal.hide()
    
    match pending_block_type:
        "event":
            _finalize_event_creation(expressions)
        "condition":
            _finalize_condition_creation(expressions)
        "action":
            _finalize_action_creation(expressions)
        # ... 其他模式处理
```

### 3.3 工作流程重置机制

每个工作流程完成后都会调用重置函数：

```gdscript
func _reset_workflow() -> void:
    """清除工作流程状态。"""
    pending_block_type = ""
    pending_node_path = ""
    pending_id = ""
    pending_target_node = null
```

这确保了状态的一致性，避免不同操作之间的状态污染。

## 4. 拖拽功能和交互设计

### 4.1 拖拽数据结构

FlowKit 实现了完整的拖拽系统，支持块的重新排序：

```gdscript
# 事件块的拖拽数据
func _get_drag_data(at_position: Vector2):
    # 创建预览控件
    var preview_label := Label.new()
    preview_label.text = label.text if label else "Event"
    preview_label.add_theme_color_override("font_color", Color(0.9, 0.95, 0.9, 0.7))
    
    var preview_margin := MarginContainer.new()
    preview_margin.add_theme_constant_override("margin_left", 8)
    preview_margin.add_theme_constant_override("margin_top", 4)
    preview_margin.add_theme_constant_override("margin_right", 8)
    preview_margin.add_theme_constant_override("margin_bottom", 4)
    preview_margin.add_child(preview_label)
    
    set_drag_preview(preview_margin)
    
    # 返回带有类型信息的拖拽数据
    return {
        "type": "event",
        "node": self
    }
```

### 4.2 容器拖拽处理

容器 ([`blocks_container.gd`](addons/flowkit/ui/blocks_container.gd:1)) 负责处理拖拽的放置逻辑：

```gdscript
func _can_drop_data(at_position: Vector2, data) -> bool:
    if not data is Dictionary:
        return false
    if not data.has("node"):
        return false
    
    var node = data["node"]
    return is_instance_valid(node) and node.get_parent() == self

func _drop_data(at_position: Vector2, data) -> void:
    if not data is Dictionary or not data.has("node"):
        return
    
    var node = data["node"]
    if not is_instance_valid(node) or node.get_parent() != self:
        return
    
    var old_idx = node.get_index()
    var new_idx = _calculate_drop_index(at_position)
    
    if new_idx > old_idx:
        new_idx -= 1
    
    if old_idx != new_idx:
        move_child(node, new_idx)

func _calculate_drop_index(at_position: Vector2) -> int:
    for i in range(get_child_count()):
        var child = get_child(i)
        if not child.visible or child.name == "EmptyLabel":
            continue
        
        var rect = child.get_rect()
        if at_position.y < rect.position.y + rect.size.y * 0.5:
            return i
    
    return get_child_count()
```

**拖拽系统的设计特点：**
- 使用类型标识区分不同类型的块（事件、条件、动作）
- 提供视觉反馈（预览控件）
- 智能计算放置位置（基于鼠标位置和子控件的中点）
- 防止无效拖拽操作（只允许同一容器内的拖拽）

## 5. 模态对话框系统的设计

### 5.1 节点选择对话框

节点选择对话框 ([`select.gd`](addons/flowkit/ui/modals/select.gd:1)) 提供了场景树的导航功能：

```gdscript
func populate_from_scene(scene_root: Node) -> void:
    if not item_list:
        return
    
    item_list.clear()
    
    # 在顶部添加 System 选项
    item_list.add_item("System")
    var system_index = item_list.item_count - 1
    item_list.set_item_metadata(system_index, "System")
    if editor_interface:
        var icon = editor_interface.get_base_control().get_theme_icon("Node", "EditorIcons")
        if icon:
            item_list.set_item_icon(system_index, icon)
    
    if not scene_root:
        return
    
    _add_node_recursive(scene_root, "", scene_root)

func _add_node_recursive(node: Node, prefix: String, scene_root: Node) -> void:
    var node_name = node.name
    var display_name = prefix + node_name
    var node_class = node.get_class()
    
    # 添加节点到列表
    item_list.add_item(display_name)
    var index = item_list.item_count - 1
    
    # 存储相对于场景根节点的路径
    var relative_path = scene_root.get_path_to(node)
    item_list.set_item_metadata(index, str(relative_path))
    
    # 检查是否有事件支持此节点类型
    var has_compatible_event = _has_compatible_event(node_class)
    if not has_compatible_event:
        item_list.set_item_disabled(index, true)
        item_list.set_item_custom_fg_color(index, Color(0.5, 0.5, 0.5, 0.7))
    
    # 获取并设置节点的编辑器图标
    if editor_interface:
        var icon = editor_interface.get_base_control().get_theme_icon(node.get_class(), "EditorIcons")
        if icon:
            item_list.set_item_icon(index, icon)
    
    # 递归添加子节点
    for child in node.get_children():
        _add_node_recursive(child, prefix + "  ", scene_root)
```

**设计特点：**
- 递归遍历场景树，显示完整的节点层次结构
- 使用编辑器主题图标提供视觉一致性
- 检查节点兼容性，禁用不支持的节点
- 支持系统级事件（全局事件）

### 5.2 类型选择对话框

类型选择对话框（如 [`select_event.gd`](addons/flowkit/ui/modals/select_event.gd:1)）根据节点类型过滤可用选项：

```gdscript
func populate_events(node_path: String, node_class: String) -> void:
    selected_node_path = node_path
    selected_node_class = node_class
    
    if not item_list:
        return
    
    item_list.clear()
    
    # 过滤支持此节点类型的事件
    for event in available_events:
        if event.has_method("get_id"):
            # 新的 FKEvent 模式
            var supported_types = event.get_supported_types()
            if _is_node_compatible(node_class, supported_types):
                var event_name = event.get_name()
                var event_id = event.get_id()
                
                item_list.add_item(event_name)
                var index = item_list.item_count - 1
                item_list.set_item_metadata(index, event_id)
    
    if item_list.item_count == 0:
        item_list.add_item("No events available for this node type")
        item_list.set_item_disabled(0, true)

func _is_node_compatible(node_class: String, supported_types: Array) -> bool:
    if supported_types.is_empty():
        return false
    
    # 检查精确匹配
    if node_class in supported_types:
        return true
    
    # 检查 "Node"（应匹配所有节点）
    if "Node" in supported_types:
        return true
    
    # 检查继承关系
    for supported_type in supported_types:
        if ClassDB.is_parent_class(node_class, supported_type):
            return true
    
    return false
```

### 5.3 表达式编辑对话框

表达式编辑对话框 ([`expression_editor.gd`](addons/flowkit/ui/modals/expression_editor.gd:1)) 提供参数输入界面：

```gdscript
func populate_inputs(node_path: String, action_id: String, inputs: Array, current_values: Dictionary = {}) -> void:
    selected_node_path = node_path
    selected_action_id = action_id
    action_inputs = inputs
    
    if not inputs_container:
        return
    
    # 清除现有输入
    for child in inputs_container.get_children():
        child.queue_free()
    
    input_fields.clear()
    
    # 为每个参数创建输入字段
    for input_data in inputs:
        var param_name: String = input_data.get("name", "Unknown")
        var param_type: String = input_data.get("type", "string")
        
        # 创建标签
        var label: Label = Label.new()
        label.text = param_name + " (" + param_type + "):"
        inputs_container.add_child(label)
        
        # 创建输入字段
        var line_edit: LineEdit = LineEdit.new()
        line_edit.placeholder_text = "Enter expression (e.g., 100, 1+1, variable_name)"
        line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        
        # 如果是编辑模式，设置当前值
        if current_values.has(param_name):
            line_edit.text = str(current_values[param_name])
        
        inputs_container.add_child(line_edit)
        
        input_fields[param_name] = line_edit
```

## 6. 数据持久化和资源管理

### 6.1 事件表资源系统

FlowKit 使用 Godot 的资源系统进行数据持久化：

```gdscript
# event_sheet.gd
extends Resource
class_name FKEventSheet

@export var events: Array[FKEventBlock] = []
@export var standalone_conditions: Array[FKEventCondition] = []
```

### 6.2 场景关联的数据存储

每个场景都有对应的事件表文件，存储在固定路径：

```gdscript
func _get_sheet_path() -> String:
    """获取当前场景事件表的文件路径。"""
    if current_scene_name == "":
        return ""
    return "res://addons/flowkit/saved/event_sheet/%s.tres" % current_scene_name
```

### 6.3 数据序列化和反序列化

编辑器实现了完整的数据序列化和反序列化：

```gdscript
func _populate_from_sheet(sheet: FKEventSheet) -> void:
    """从事件表数据创建块节点。"""
    # 添加独立条件
    for condition_data in sheet.standalone_conditions:
        var condition_node = _create_condition_block(condition_data)
        blocks_container.add_child(condition_node)
        
        # 添加其动作
        for action_data in condition_data.actions:
            var action_node = _create_action_block(action_data)
            blocks_container.add_child(action_node)
    
    # 添加事件
    for event_data in sheet.events:
        var event_node = _create_event_block(event_data)
        blocks_container.add_child(event_node)
        
        # 添加其条件
        for condition_data in event_data.conditions:
            var condition_node = _create_condition_block(condition_data)
            blocks_container.add_child(condition_node)
        
        # 添加其动作
        for action_data in event_data.actions:
            var action_node = _create_action_block(action_data)
            blocks_container.add_child(action_node)

func _generate_sheet_from_blocks() -> FKEventSheet:
    """从块节点按顺序构建事件表。"""
    var sheet = FKEventSheet.new()
    var events: Array[FKEventBlock] = []
    var standalone_conditions: Array[FKEventCondition] = []
    
    var current_event: FKEventBlock = null
    var current_standalone: FKEventCondition = null
    
    for block in _get_blocks():
        if block.has_method("get_event_data"):
            # 保存前一个上下文
            if current_event:
                events.append(current_event)
            if current_standalone:
                standalone_conditions.append(current_standalone)
            
            # 开始新事件
            var data = block.get_event_data()
            current_event = FKEventBlock.new()
            current_event.event_id = data.event_id
            current_event.target_node = data.target_node
            current_event.inputs = data.inputs.duplicate()
            current_event.conditions = [] as Array[FKEventCondition]
            current_event.actions = [] as Array[FKEventAction]
            current_standalone = null
            
        elif block.has_method("get_condition_data"):
            # 处理条件块...
            # ... (详细实现见源码)
            
        elif block.has_method("get_action_data"):
            # 处理动作块...
            # ... (详细实现见源码)
    
    # 保存最终上下文
    if current_event:
        events.append(current_event)
    if current_standalone:
        standalone_conditions.append(current_standalone)
    
    sheet.events = events
    sheet.standalone_conditions = standalone_conditions
    return sheet
```

### 6.4 自动保存机制

编辑器提供了手动保存功能，通过菜单栏触发：

```gdscript
func _save_sheet() -> void:
    """从当前块生成并保存事件表。"""
    if current_scene_name == "":
        push_warning("No scene open to save event sheet.")
        return
    
    var sheet = _generate_sheet_from_blocks()
    
    var dir_path = "res://addons/flowkit/saved/event_sheet"
    DirAccess.make_dir_recursive_absolute(dir_path)
    
    var sheet_path = _get_sheet_path()
    var error = ResourceSaver.save(sheet, sheet_path)
    
    if error == OK:
        print("✓ Event sheet saved: ", sheet_path)
    else:
        push_error("Failed to save event sheet: ", error)
```

## 7. 代码生成系统的实现

### 7.1 自动代码生成器

FlowKit 包含一个强大的代码生成器 ([`generator.gd`](addons/flowkit/generator.gd:1))，可以自动为场景中的节点类型生成事件、条件和动作：

```gdscript
func generate_all() -> Dictionary:
    var result = {
        "actions": 0,
        "conditions": 0,
        "events": 0,
        "errors": []
    }
    
    var current_scene = editor_interface.get_edited_scene_root()
    if not current_scene:
        result.errors.append("No scene is currently open")
        return result
    
    # 收集场景中所有唯一的节点类型
    var node_types: Dictionary = {}
    _collect_node_types(current_scene, node_types)
    
    print("[FlowKit Generator] Found ", node_types.size(), " unique node types")
    
    # 为每种节点类型生成提供者
    for node_type in node_types.keys():
        var node_instance = node_types[node_type]
        
        # 生成动作
        var actions = _generate_actions_for_node(node_type, node_instance)
        result.actions += actions
        
        # 生成条件
        var conditions = _generate_conditions_for_node(node_type, node_instance)
        result.conditions += conditions
        
        # 生成事件（信号）
        var events = _generate_events_for_node(node_type, node_instance)
        result.events += events
    
    return result
```

### 7.2 动作代码生成

代码生成器可以为节点的可写属性和方法生成动作：

```gdscript
func _generate_actions_for_node(node_type: String, node_instance: Node) -> int:
    var count = 0
    var property_list = node_instance.get_property_list()
    var method_list = node_instance.get_method_list()
    
    # 为可写属性生成设置器
    for prop in property_list:
        if prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE or prop.usage & PROPERTY_USAGE_EDITOR:
            if not (prop.usage & PROPERTY_USAGE_READ_ONLY):
                if _is_valid_property_for_action(prop):
                    _create_setter_action(node_type, prop)
                    count += 1
    
    # 为带参数的 void 方法生成动作
    for method in method_list:
        if _is_valid_method_for_action(method):
            _create_method_action(node_type, method)
            count += 1
    
    return count

func _create_setter_action(node_type: String, prop: Dictionary) -> void:
    var prop_name = prop.name
    var action_id = "set_" + prop_name.replace("/", "_").replace(" ", "_").to_lower()
    var action_name = "Set " + _humanize_name(prop_name)
    
    var dir_path = ACTIONS_DIR + node_type
    _ensure_directory_exists(dir_path)
    
    var file_path = dir_path + "/gen_" + action_id + ".gd"
    
    # 如果文件已存在则跳过
    if FileAccess.file_exists(file_path):
        return
    
    var type_name = _get_type_name(prop.type)
    var code = """extends FKAction

func get_id() -> String:
    return "%s"

func get_name() -> String:
    return "%s"

func get_inputs() -> Array[Dictionary]:
    return [
        {"name": "Value", "type": "%s"}
    ]

func get_supported_types() -> Array[String]:
    return ["%s"]

func execute(node: Node, inputs: Dictionary) -> void:
    if not node is %s:
        return
    
    var value = inputs.get("Value", %s)
    node.%s = value
""" % [
        action_id,
        action_name,
        type_name,
        node_type,
        node_type,
        _get_default_value(prop.type),
        prop_name
    ]
    
    _write_file(file_path, code)
```

### 7.3 条件代码生成

条件生成器为节点的可读属性生成比较条件：

```gdscript
func _create_property_comparison_condition(node_type: String, prop: Dictionary) -> void:
    var prop_name = prop.name
    var condition_id = "compare_" + prop_name.replace("/", "_").replace(" ", "_").to_lower()
    var condition_name = "Compare " + _humanize_name(prop_name)
    
    var dir_path = CONDITIONS_DIR + node_type
    _ensure_directory_exists(dir_path)
    
    var file_path = dir_path + "/gen_" + condition_id + ".gd"
    
    # 如果文件已存在则跳过
    if FileAccess.file_exists(file_path):
        return
    
    var type_name = _get_type_name(prop.type)
    
    var comparison_logic = ""
    if prop.type == TYPE_BOOL:
        comparison_logic = """    var value = inputs.get("Value", false)
    return node.%s == value""" % prop_name
    else:
        comparison_logic = """    var comparison: String = str(inputs.get("Comparison", "=="))
    var value = inputs.get("Value", %s)
    
    match comparison:
        "==": return node.%s == value
        "!=": return node.%s != value
        "<": return node.%s < value
        ">": return node.%s > value
        "<=": return node.%s <= value
        ">=": return node.%s >= value
        _: return node.%s == value""" % [
            _get_default_value(prop.type),
            prop_name, prop_name, prop_name, prop_name, prop_name, prop_name, prop_name
        ]
    
    var inputs_array = ""
    if prop.type == TYPE_BOOL:
        inputs_array = '[{"name": "Value", "type": "Bool"}]'
    else:
        inputs_array = '[{"name": "Comparison", "type": "String"}, {"name": "Value", "type": "%s"}]' % type_name
    
    var code = """extends FKCondition

func get_id() -> String:
    return "%s"

func get_name() -> String:
    return "%s"

func get_inputs() -> Array[Dictionary]:
    return %s

func get_supported_types() -> Array[String]:
    return ["%s"]

func check(node: Node, inputs: Dictionary) -> bool:
    if not node is %s:
        return false
    
%s
""" % [
        condition_id,
        condition_name,
        inputs_array,
        node_type,
        node_type,
        comparison_logic
    ]
    
    _write_file(file_path, code)
```

### 7.4 事件代码生成

事件生成器为节点的信号生成事件：

```gdscript
func _create_signal_event(node_type: String, sig: Dictionary) -> void:
    var signal_name = sig.name
    var event_id = "on_" + signal_name.to_lower()
    var event_name = "On " + _humanize_name(signal_name)
    
    var dir_path = EVENTS_DIR + node_type
    _ensure_directory_exists(dir_path)
    
    var file_path = dir_path + "/gen_" + event_id + ".gd"
    
    # 如果文件已存在则跳过
    if FileAccess.file_exists(file_path):
        return
    
    # 从信号参数构建输入
    var inputs = []
    for arg in sig.args:
        var arg_name = arg.name if arg.name != "" else "Arg"
        var type_name = _get_type_name(arg.type)
        inputs.append('{"name": "%s", "type": "%s"}' % [_humanize_name(arg_name), type_name])
    
    var inputs_str = "[" + ", ".join(inputs) + "]" if inputs.size() > 0 else "[]"
    
    # 构建信号处理器参数
    var handler_params = []
    for i in range(sig.args.size()):
        var arg = sig.args[i]
        var arg_name = arg.name if arg.name != "" else "arg" + str(i)
        handler_params.append(arg_name)
    
    if handler_params.size() > 0:
        handler_params.append("bound_node")
    else:
        handler_params.append("bound_node")
    
    var handler_params_str = ", ".join(handler_params)
    
    var code = """extends FKEvent

func get_id() -> String:
    return "%s"

func get_name() -> String:
    return "%s"

func get_supported_types() -> Array[String]:
    return ["%s"]

func get_inputs() -> Array:
    return %s

# 基于信号的事件需要连接管理
var _connected_nodes: Dictionary = {}

func poll(node: Node, inputs: Dictionary = {}) -> bool:
    if not node:
        return false
    
    # 确保节点已连接
    if not _connected_nodes.has(node):
        if node.has_signal("%s"):
            node.%s.connect(_on_signal_fired.bind(node))
            _connected_nodes[node] = {"fired": false, "args": {}}
        else:
            return false
    
    # 检查信号是否在此帧触发
    var data = _connected_nodes[node]
    if data.fired:
        data.fired = false
        return true
    
    return false

func _on_signal_fired(%s) -> void:
    if _connected_nodes.has(bound_node):
        _connected_nodes[bound_node].fired = true
""" % [
        event_id,
        event_name,
        node_type,
        inputs_str,
        signal_name,
        signal_name,
        handler_params_str
    ]
    
    _write_file(file_path, code)
```

## 8. 块组件系统

### 8.1 事件块组件

事件块 ([`event.gd`](addons/flowkit/ui/workspace/event.gd:1)) 提供事件的显示和交互：

```gdscript
func _update_label() -> void:
    if label and event_data:
        var display_name = event_data.event_id
        
        # 尝试获取提供者的显示名称
        if registry:
            for provider in registry.event_providers:
                if provider.has_method("get_id") and provider.get_id() == event_data.event_id:
                    if provider.has_method("get_name"):
                        display_name = provider.get_name()
                    break
        
        var params_text = ""
        if not event_data.inputs.is_empty():
            var param_pairs = []
            for key in event_data.inputs:
                param_pairs.append("%s: %s" % [key, event_data.inputs[key]])
            params_text = " (" + ", ".join(param_pairs) + ")"
        
        var node_name = String(event_data.target_node).get_file()
        label.text = "%s on %s%s" % [display_name, node_name, params_text]
```

### 8.2 条件块组件

条件块 ([`condition.gd`](addons/flowkit/ui/workspace/condition.gd:1)) 支持条件特有的功能，如取反：

```gdscript
func _update_label() -> void:
    if label and condition_data:
        var display_name = condition_data.condition_id
        
        # 尝试获取提供者的显示名称
        if registry:
            for provider in registry.condition_providers:
                if provider.has_method("get_id") and provider.get_id() == condition_data.condition_id:
                    if provider.has_method("get_name"):
                        display_name = provider.get_name()
                    break
        
        var params_text = ""
        if not condition_data.inputs.is_empty():
            var param_pairs = []
            for key in condition_data.inputs:
                param_pairs.append("%s: %s" % [key, condition_data.inputs[key]])
            params_text = " (" + ", ".join(param_pairs) + ")"
        
        var negation_prefix = "NOT " if condition_data.negated else ""
        label.text = "%s%s%s" % [negation_prefix, display_name, params_text]
    
    # 更新上下文菜单检查标记
    if context_menu:
        context_menu.set_item_checked(4, condition_data.negated if condition_data else false)
```

### 8.3 动作块组件

动作块 ([`action.gd`](addons/flowkit/ui/workspace/action.gd:1)) 提供动作的显示和编辑功能：

```gdscript
func _update_label() -> void:
    if label and action_data:
        var display_name = action_data.action_id
        
        # 尝试获取提供者的显示名称
        if registry:
            for provider in registry.action_providers:
                if provider.has_method("get_id") and provider.get_id() == action_data.action_id:
                    if provider.has_method("get_name"):
                        display_name = provider.get_name()
                    break
        
        var params_text = ""
        if not action_data.inputs.is_empty():
            var param_pairs = []
            for key in action_data.inputs:
                param_pairs.append("%s: %s" % [key, action_data.inputs[key]])
            params_text = " (" + ", ".join(param_pairs) + ")"
        
        var node_name = String(action_data.target_node).get_file()
        label.text = "%s on %s%s" % [display_name, node_name, params_text]
```

## 9. 上下文菜单系统

所有块组件都实现了上下文菜单系统，提供常用的操作：

```gdscript
func _on_gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
            # 尝试获取上下文菜单（如果还没有）
            if not context_menu:
                context_menu = get_node_or_null("ContextMenu")
                if context_menu and not context_menu.id_pressed.is_connected(_on_context_menu_id_pressed):
                    context_menu.id_pressed.connect(_on_context_menu_id_pressed)
            
            if context_menu:
                context_menu.position = get_global_mouse_position()
                context_menu.popup()

func _on_context_menu_id_pressed(id: int) -> void:
    match id:
        0: # 插入条件/动作
            insert_requested.emit(self)
        1: # 替换
            replace_requested.emit(self)
        2: # 编辑
            edit_requested.emit(self)
        3: # 删除
            delete_requested.emit(self)
        4: # 取反（仅条件）
            negate_requested.emit(self)
```

## 10. 注册表系统

### 10.1 提供者注册和加载

注册表 ([`registry.gd`](addons/flowkit/registry.gd:1)) 负责管理所有的事件、条件和动作提供者：

```gdscript
func load_all() -> void:
    _load_folder("actions", action_providers)
    _load_folder("conditions", condition_providers)
    _load_folder("events", event_providers)
    
    print("[FlowKit Registry] Loaded %d actions, %d conditions, %d events" % [
        action_providers.size(),
        condition_providers.size(),
        event_providers.size()
    ])

func _load_folder(subpath: String, array: Array) -> void:
    var path: String = "res://addons/flowkit/" + subpath
    _scan_directory_recursive(path, array)

func _scan_directory_recursive(path: String, array: Array) -> void:
    var dir: DirAccess = DirAccess.open(path)
    if not dir:
        return
    
    dir.list_dir_begin()
    var file_name: String = dir.get_next()
    
    while file_name != "":
        var file_path: String = path + "/" + file_name
        
        if dir.current_is_dir():
            # 递归扫描子目录
            _scan_directory_recursive(file_path, array)
        elif file_name.ends_with(".gd") and not file_name.ends_with(".uid"):
            # 加载脚本并实例化
            var script: GDScript = load(file_path)
            if script:
                var instance: Variant = script.new()
                array.append(instance)
        
        file_name = dir.get_next()
    
    dir.list_dir_end()
```

### 10.2 运行时执行

注册表还负责运行时的执行逻辑：

```gdscript
func poll_event(event_id: String, node: Node, inputs: Dictionary = {}) -> bool:
    for provider in event_providers:
        if provider.has_method("get_id") and provider.get_id() == event_id:
            if provider.has_method("poll"):
                # 在轮询前评估输入中的表达式
                var evaluated_inputs: Dictionary = FKExpressionEvaluator.evaluate_inputs(inputs, node)
                return provider.poll(node, evaluated_inputs)
    return false

func check_condition(condition_id: String, node: Node, inputs: Dictionary, negated: bool = false) -> bool:
    for provider in condition_providers:
        if provider.has_method("get_id") and provider.get_id() == condition_id:
            if provider.has_method("check"):
                # 在检查前评估输入中的表达式
                var evaluated_inputs: Dictionary = FKExpressionEvaluator.evaluate_inputs(inputs, node)
                var result = provider.check(node, evaluated_inputs)
                return not result if negated else result
    return false

func execute_action(action_id: String, node: Node, inputs: Dictionary) -> void:
    for provider in action_providers:
        if provider.has_method("get_id") and provider.get_id() == action_id:
            if provider.has_method("execute"):
                # 在执行前评估输入中的表达式
                var evaluated_inputs: Dictionary = FKExpressionEvaluator.evaluate_inputs(inputs, node)
                provider.execute(node, evaluated_inputs)
                return
```

## 11. 菜单栏集成

FlowKit 通过菜单栏 ([`menu_bar.gd`](addons/flowkit/ui/menu_bar.gd:1)) 提供编辑器级别的操作：

```gdscript
func _on_file_id_pressed(id: int) -> void:
    match id:
        0: # 新建事件表
            emit_signal("new_sheet")
        1: # 保存事件表
            emit_signal("save_sheet")

func _on_edit_id_pressed(id: int) -> void:
    match id:
        0: # 生成
            emit_signal("generate_providers")
```

菜单栏提供了以下功能：
- 新建事件表：清空当前编辑器内容
- 保存事件表：将当前编辑器内容保存到文件
- 生成提供者：自动为当前场景中的节点类型生成事件、条件和动作

## 12. 总结

FlowKit 插件通过以下关键技术和设计模式实现了强大的编辑器定制支持：

### 12.1 核心设计原则

1. **模块化架构**：将功能分解为独立的组件，每个组件负责特定的职责
2. **事件驱动**：使用信号和回调实现组件间的松耦合通信
3. **资源管理**：利用 Godot 的资源系统进行数据持久化
4. **自动化**：通过代码生成器减少手动编写重复代码的需要

### 12.2 编辑器集成技术

1. **EditorPlugin 扩展**：使用标准的插件机制集成到编辑器
2. **EditorInterface 访问**：深度集成编辑器功能和上下文
3. **底部面板集成**：提供持久化的编辑界面
4. **主题和图标一致性**：使用编辑器主题保持视觉一致性

### 12.3 用户体验设计

1. **多步骤向导**：通过分步骤的向导简化复杂的操作流程
2. **拖拽支持**：提供直观的块重排序功能
3. **上下文菜单**：为常用操作提供快速访问
4. **实时反馈**：提供即时的视觉反馈和状态更新

### 12.4 数据管理策略

1. **场景关联存储**：每个场景有独立的事件表文件
2. **层次化数据结构**：使用嵌套的资源类表示复杂的关系
3. **自动序列化**：简化数据的保存和加载过程
4. **类型安全**：使用强类型资源类确保数据一致性

### 12.5 扩展性设计

1. **插件式架构**：支持动态加载事件、条件和动作提供者
2. **代码生成**：自动为新节点类型生成支持代码
3. **继承兼容性**：支持基于类继承的类型匹配
4. **表达式系统**：支持复杂的参数表达式计算

FlowKit 的实现展示了如何在 Godot 中创建一个功能完整、用户友好的可视化编辑系统。其模块化的设计、强大的代码生成能力和深度的编辑器集成，为其他类似插件提供了宝贵的参考和借鉴价值。