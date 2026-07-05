# CreateLocalVariableInstruction 动态 Inspector 插件实现指南

## 1. 实现优先级和阶段规划

### 阶段 1: 核心架构 (高优先级)
1. 创建基础插件架构和接口定义
2. 实现基础类型编辑器 (BOOL, INT, FLOAT, STRING)
3. 实现动态切换机制
4. 基础测试验证

### 阶段 2: 扩展类型 (中优先级)
1. 实现数学类型编辑器 (VECTOR2/3, COLOR)
2. 实现容器类型编辑器 (ARRAY, DICTIONARY)
3. 添加类型转换逻辑
4. 用户体验优化

### 阶段 3: 高级功能 (低优先级)
1. 实现引用类型编辑器 (OBJECT, NODE_PATH)
2. 实现打包数组编辑器
3. 添加高级验证和错误处理
4. 性能优化

## 2. 核心文件实现示例

### 2.1 基础编辑器接口实现
```gdscript
# addons/fuse/editor/inspector/editors/base_value_editor.gd
@tool
class_name BaseValueEditor extends Control
signal value_changed(new_value: Variant)
signal value_committed(new_value: Variant)

# 子类必须实现的核心方法
func set_value(value: Variant) -> void:
    push_error("set_value() must be implemented by subclass")

func get_value() -> Variant:
    push_error("get_value() must be implemented by subclass")
    return null

func set_placeholder(text: String) -> void:
    # 默认实现，子类可以重写
    pass

func set_enabled(enabled: bool) -> void:
    # 默认实现，子类可以重写
    modulate.a = 1.0 if enabled else 0.5

func get_supported_types() -> Array[BaseVariable.VariableType]:
    push_error("get_supported_types() must be implemented by subclass")
    return []

func validate_value(value: Variant) -> bool:
    # 默认实现，子类应该重写
    return true

func get_validation_error() -> String:
    # 默认实现，子类可以重写
    return ""

# 可选的辅助方法
func focus_editor() -> void:
    # 默认实现，子类可以重写
    grab_focus()

func clear_value() -> void:
    # 默认实现，子类可以重写
    set_value(null)

func get_display_text() -> String:
    # 默认实现，子类可以重写
    return str(get_value())
```

### 2.2 布尔类型编辑器实现
```gdscript
# addons/fuse/editor/inspector/editors/bool_editor.gd
@tool
extends BaseValueEditor
class_name BoolValueEditor

var _checkbox: CheckBox
var _updating: bool = false

func _init():
    _checkbox = CheckBox.new()
    _checkbox.text = "启用"
    _checkbox.toggled.connect(_on_toggled)
    add_child(_checkbox)

func set_value(value: Variant) -> void:
    if _updating:
        return
    
    _updating = true
    _checkbox.button_pressed = bool(value)
    _updating = false

func get_value() -> Variant:
    return _checkbox.button_pressed

func set_placeholder(text: String) -> void:
    _checkbox.text = text

func set_enabled(enabled: bool) -> void:
    super.set_enabled(enabled)
    _checkbox.disabled = not enabled

func get_supported_types() -> Array[BaseVariable.VariableType]:
    return [BaseVariable.VariableType.BOOL]

func validate_value(value: Variant) -> bool:
    return value is bool

func get_validation_error() -> String:
    return "值必须是布尔类型 (true/false)"

func _on_toggled(pressed: bool) -> void:
    if not _updating:
        value_changed.emit(pressed)
```

### 2.3 数字类型编辑器实现
```gdscript
# addons/fuse/editor/inspector/editors/number_editor.gd
@tool
extends BaseValueEditor
class_name NumberValueEditor

var _spinbox: SpinBox
var _type: BaseVariable.VariableType
var _updating: bool = false

func _init(for_type: BaseVariable.VariableType = BaseVariable.VariableType.INT):
    _type = for_type
    _setup_spinbox()

func _setup_spinbox():
    _spinbox = SpinBox.new()
    _spinbox.value_changed.connect(_on_value_changed)
    
    match _type:
        BaseVariable.VariableType.INT:
            _spinbox.step = 1
            _spinbox.allow_greater = true
            _spinbox.allow_lesser = true
            _spinbox.min_value = -2147483648  # INT_MIN
            _spinbox.max_value = 2147483647   # INT_MAX
        BaseVariable.VariableType.FLOAT:
            _spinbox.step = 0.01
            _spinbox.allow_greater = true
            _spinbox.allow_lesser = true
            _spinbox.min_value = -3.402823e38   # 接近 FLT_MIN
            _spinbox.max_value = 3.402823e38    # 接近 FLT_MAX
    
    add_child(_spinbox)

func set_value(value: Variant) -> void:
    if _updating:
        return
    
    _updating = true
    if value is int or value is float:
        _spinbox.value = value
    _updating = false

func get_value() -> Variant:
    match _type:
        BaseVariable.VariableType.INT:
            return int(_spinbox.value)
        BaseVariable.VariableType.FLOAT:
            return _spinbox.value
    return 0

func set_placeholder(text: String) -> void:
    _spinbox.placeholder_text = text

func set_enabled(enabled: bool) -> void:
    super.set_enabled(enabled)
    _spinbox.editable = enabled

func get_supported_types() -> Array[BaseVariable.VariableType]:
    return [BaseVariable.VariableType.INT, BaseVariable.VariableType.FLOAT]

func validate_value(value: Variant) -> bool:
    return value is int or value is float

func get_validation_error() -> String:
    return "值必须是数字类型 (整数或浮点数)"

func _on_value_changed(value: float) -> void:
    if not _updating:
        value_changed.emit(get_value())
```

### 2.4 字符串类型编辑器实现
```gdscript
# addons/fuse/editor/inspector/editors/string_editor.gd
@tool
extends BaseValueEditor
class_name StringValueEditor

var _line_edit: LineEdit
var _multiline: bool = false
var _text_edit: TextEdit
var _updating: bool = false

func _init(multiline: bool = false):
    _multiline = multiline
    _setup_editor()

func _setup_editor():
    if _multiline:
        _text_edit = TextEdit.new()
        _text_edit.custom_minimum_size = Vector2(0, 60)
        _text_edit.text_changed.connect(_on_text_changed)
        add_child(_text_edit)
    else:
        _line_edit = LineEdit.new()
        _line_edit.text_changed.connect(_on_text_changed)
        add_child(_line_edit)

func set_value(value: Variant) -> void:
    if _updating:
        return
    
    _updating = true
    var text = str(value) if value != null else ""
    
    if _multiline:
        _text_edit.text = text
    else:
        _line_edit.text = text
    
    _updating = false

func get_value() -> Variant:
    if _multiline:
        return _text_edit.text
    else:
        return _line_edit.text

func set_placeholder(text: String) -> void:
    if _multiline:
        _text_edit.placeholder_text = text
    else:
        _line_edit.placeholder_text = text

func set_enabled(enabled: bool) -> void:
    super.set_enabled(enabled)
    if _multiline:
        _text_edit.editable = enabled
    else:
        _line_edit.editable = enabled

func get_supported_types() -> Array[BaseVariable.VariableType]:
    return [BaseVariable.VariableType.STRING]

func validate_value(value: Variant) -> bool:
    return true  # 任何值都可以转换为字符串

func get_validation_error() -> String:
    return ""  # 字符串类型总是有效的

func _on_text_changed():
    if not _updating:
        value_changed.emit(get_value())
```

## 3. 类型映射系统实现

### 3.1 核心映射类
```gdscript
# addons/fuse/editor/inspector/type_mapping.gd
extends RefCounted
class_name TypeMapping

# 编辑器类映射
static var _editor_map: Dictionary = {
    BaseVariable.VariableType.NIL: preload("res://addons/fuse/editor/inspector/editors/null_editor.gd"),
    BaseVariable.VariableType.BOOL: preload("res://addons/fuse/editor/inspector/editors/bool_editor.gd"),
    BaseVariable.VariableType.INT: preload("res://addons/fuse/editor/inspector/editors/number_editor.gd"),
    BaseVariable.VariableType.FLOAT: preload("res://addons/fuse/editor/inspector/editors/number_editor.gd"),
    BaseVariable.VariableType.STRING: preload("res://addons/fuse/editor/inspector/editors/string_editor.gd"),
    # ... 其他类型映射
}

# 默认值映射
static var _default_values: Dictionary = {
    BaseVariable.VariableType.NIL: null,
    BaseVariable.VariableType.BOOL: false,
    BaseVariable.VariableType.INT: 0,
    BaseVariable.VariableType.FLOAT: 0.0,
    BaseVariable.VariableType.STRING: "",
    # ... 其他默认值
}

static func get_editor_class(variable_type: BaseVariable.VariableType) -> GDScript:
    return _editor_map.get(variable_type, null)

static func get_default_value(variable_type: BaseVariable.VariableType) -> Variant:
    return _default_values.get(variable_type, null)

static func create_editor(variable_type: BaseVariable.VariableType) -> BaseValueEditor:
    var editor_class = get_editor_class(variable_type)
    if not editor_class:
        return null
    
    # 为特殊类型的编辑器传递构造参数
    match variable_type:
        BaseVariable.VariableType.INT:
            return editor_class.new(BaseVariable.VariableType.INT)
        BaseVariable.VariableType.FLOAT:
            return editor_class.new(BaseVariable.VariableType.FLOAT)
        BaseVariable.VariableType.STRING:
            return editor_class.new(false)  # 单行模式
        _:
            return editor_class.new()
```

### 3.2 类型转换实现
```gdscript
# 在 TypeMapping 类中添加转换方法
static func convert_value(value: Variant, from_type: BaseVariable.VariableType, to_type: BaseVariable.VariableType) -> Variant:
    # 如果类型相同，直接返回
    if from_type == to_type:
        return value
    
    # NIL 类型特殊处理
    if to_type == BaseVariable.VariableType.NIL:
        return null
    
    # 尝试类型转换
    match to_type:
        BaseVariable.VariableType.INT:
            if value is float:
                return int(value)
            elif value is bool:
                return 1 if value else 0
            elif value is String:
                if value.is_valid_int():
                    return value.to_int()
                elif value.is_valid_float():
                    return int(value.to_float())
        BaseVariable.VariableType.FLOAT:
            if value is int:
                return float(value)
            elif value is bool:
                return 1.0 if value else 0.0
            elif value is String:
                if value.is_valid_float():
                    return value.to_float()
        BaseVariable.VariableType.BOOL:
            if value is int or value is float:
                return value != 0
            elif value is String:
                return not value.is_empty() and value.to_lower() != "false"
        BaseVariable.VariableType.STRING:
            return str(value)
        BaseVariable.VariableType.VECTOR2:
            if value is Vector2i:
                return Vector2(float(value.x), float(value.y))
            elif value is Vector3:
                return Vector2(value.x, value.y)
            elif value is Vector3i:
                return Vector2(float(value.x), float(value.y))
            elif value is String:
                # 尝试解析 "x,y" 格式
                var parts = value.split(",")
                if parts.size() == 2:
                    var x = parts[0].strip_edges().to_float()
                    var y = parts[1].strip_edges().to_float()
                    return Vector2(x, y)
        # ... 其他类型转换
    
    # 无法转换时返回默认值
    return get_default_value(to_type)
```

## 4. 主插件实现

### 4.1 Inspector 插件主文件
```gdscript
# addons/fuse/editor/inspector/create_local_variable_inspector.gd
@tool
extends EditorInspectorPlugin
class_name CreateLocalVariableInspector

var _current_object: CreateLocalVariableInstruction = null
var _default_value_editor: DynamicValueEditor = null

func _can_handle(object: Object) -> bool:
    return object is CreateLocalVariableInstruction

func _parse_begin(object: Object) -> void:
    _current_object = object as CreateLocalVariableInstruction
    if _current_object:
        # 监听属性变化
        _current_object.notify_property_list_changed.connect(_on_property_list_changed)

func _parse_property(object: Object, type: int, name: String, hint_type: PropertyHint, hint_string: String, usage_flags: PropertyUsageFlags, wide: bool) -> bool:
    if name == "default_value":
        # 创建自定义编辑器
        _default_value_editor = DynamicValueEditor.new()
        _default_value_editor.set_edited_object(object)
        _default_value_editor.set_edited_property(name)
        add_property_editor(name, _default_value_editor)
        return true
    return false

func _parse_end() -> void:
    if _current_object and _current_object.notify_property_list_changed.is_connected(_on_property_list_changed):
        _current_object.notify_property_list_changed.disconnect(_on_property_list_changed)
    _current_object = null
    _default_value_editor = null

func _on_property_list_changed() -> void:
    # 当属性列表发生变化时，通知编辑器更新
    if _default_value_editor:
        _default_value_editor.update_editor_type()
```

### 4.2 动态值编辑器实现
```gdscript
# addons/fuse/editor/inspector/dynamic_value_editor.gd
@tool
extends EditorProperty
class_name DynamicValueEditor

var _current_editor: BaseValueEditor = null
var _current_type: BaseVariable.VariableType = BaseVariable.VariableType.NIL
var _updating: bool = false
var _container: HBoxContainer
var _type_label: Label
var _editor_container: VBoxContainer
var _error_label: Label

func _init():
    _setup_ui()

func _setup_ui():
    _container = HBoxContainer.new()
    add_child(_container)
    
    # 类型标签
    _type_label = Label.new()
    _type_label.custom_minimum_size = Vector2(80, 0)
    _type_label.add_theme_color_override("font_color", Color.GRAY)
    _container.add_child(_type_label)
    
    # 编辑器容器
    _editor_container = VBoxContainer.new()
    _editor_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _container.add_child(_editor_container)
    
    # 错误标签
    _error_label = Label.new()
    _error_label.add_theme_color_override("font_color", Color.RED)
    _error_label.visible = false
    _editor_container.add_child(_error_label)

func _update_property() -> void:
    if _updating:
        return
    
    var object = get_edited_object() as CreateLocalVariableInstruction
    if not object:
        return
    
    var new_type = object.variable_type
    var new_value = object.default_value
    
    if new_type != _current_type:
        _switch_editor(new_type)
        _current_type = new_type
    
    if _current_editor:
        _current_editor.set_value(new_value)
    
    # 更新类型标签
    _type_label.text = _get_type_display_name(new_type)

func _get_type_display_name(variable_type: BaseVariable.VariableType) -> String:
    match variable_type:
        BaseVariable.VariableType.NIL: return "空值"
        BaseVariable.VariableType.BOOL: return "布尔"
        BaseVariable.VariableType.INT: return "整数"
        BaseVariable.VariableType.FLOAT: return "浮点数"
        BaseVariable.VariableType.STRING: return "字符串"
        BaseVariable.VariableType.VECTOR2: return "Vector2"
        BaseVariable.VariableType.VECTOR2I: return "Vector2i"
        BaseVariable.VariableType.VECTOR3: return "Vector3"
        BaseVariable.VariableType.VECTOR3I: return "Vector3i"
        BaseVariable.VariableType.COLOR: return "颜色"
        BaseVariable.VariableType.ARRAY: return "数组"
        BaseVariable.VariableType.DICTIONARY: return "字典"
        _: return BaseVariable._get_type_name(variable_type)

func _switch_editor(new_type: BaseVariable.VariableType) -> void:
    # 清理旧编辑器
    if _current_editor:
        _current_editor.value_changed.disconnect(_on_editor_value_changed)
        _current_editor.queue_free()
        _current_editor = null
    
    # 创建新编辑器
    _current_editor = TypeMapping.create_editor(new_type)
    if _current_editor:
        _current_editor.value_changed.connect(_on_editor_value_changed)
        _editor_container.add_child(_current_editor)
        _current_editor.move_to_front()  # 移到错误标签前面

func _on_editor_value_changed(new_value: Variant) -> void:
    if _updating:
        return
    
    var object = get_edited_object() as CreateLocalVariableInstruction
    if not object:
        return
    
    # 验证值
    if _current_editor and not _current_editor.validate_value(new_value):
        _show_error(_current_editor.get_validation_error())
        return
    
    _hide_error()
    emit_changed(get_edited_property(), new_value)

func update_editor_type() -> void:
    _update_property()

func _show_error(message: String) -> void:
    _error_label.text = message
    _error_label.visible = true

func _hide_error() -> void:
    _error_label.visible = false
```

## 5. 集成步骤

### 5.1 修改主插件文件
在 `addons/fuse/plugin.gd` 中添加 Inspector 插件注册：

```gdscript
# 在 _enter_tree() 方法末尾添加:
func _enter_tree():
    # ... 现有代码 ...
    
    # 注册 Inspector 插件
    var inspector_plugin = preload("res://addons/fuse/editor/inspector/create_local_variable_inspector.gd").new()
    add_inspector_plugin(inspector_plugin)
    
    print("Fuse Visual Programming 插件已激活")
```

### 5.2 创建目录结构
确保以下目录结构存在：
```
addons/fuse/editor/
├── inspector/
│   ├── create_local_variable_inspector.gd
│   ├── dynamic_value_editor.gd
│   ├── type_mapping.gd
│   └── editors/
│       ├── base_value_editor.gd
│       ├── bool_editor.gd
│       ├── number_editor.gd
│       ├── string_editor.gd
│       └── null_editor.gd
```

## 6. 测试和验证

### 6.1 基础功能测试
1. 创建 CreateLocalVariableInstruction 实例
2. 切换 variable_type 属性
3. 验证 default_value 编辑器是否正确切换
4. 测试值输入和验证

### 6.2 类型转换测试
1. 设置一个类型的值
2. 切换到兼容类型
3. 验证值是否正确转换
4. 测试不兼容类型的处理

### 6.3 错误处理测试
1. 输入无效值
2. 验证错误提示是否显示
3. 测试错误恢复机制

这个实现指南提供了详细的代码示例和步骤，确保开发团队能够按照统一的标准实现动态 Inspector 插件。