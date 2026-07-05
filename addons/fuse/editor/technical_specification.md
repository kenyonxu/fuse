# CreateLocalVariableInstruction 动态 Inspector 插件技术规格

## 1. 核心接口定义

### 1.1 基础值编辑器接口
```gdscript
# base_value_editor.gd
class_name BaseValueEditor extends Control
signal value_changed(new_value: Variant)
signal value_committed(new_value: Variant)

# 必须实现的方法
func set_value(value: Variant) -> void
func get_value() -> Variant
func set_placeholder(text: String) -> void
func set_enabled(enabled: bool) -> void
func get_supported_types() -> Array[BaseVariable.VariableType]
func validate_value(value: Variant) -> bool
func get_validation_error() -> String

# 可选实现的方法
func focus_editor() -> void
func clear_value() -> void
func get_display_text() -> String
```

### 1.2 类型映射系统接口
```gdscript
# type_mapping.gd
class_name TypeMapping extends RefCounted

# 获取类型对应的编辑器类
static func get_editor_class(variable_type: BaseVariable.VariableType) -> GDScript

# 获取类型的默认值
static func get_default_value(variable_type: BaseVariable.VariableType) -> Variant

# 尝试在类型间转换值
static func convert_value(value: Variant, from_type: BaseVariable.VariableType, to_type: BaseVariable.VariableType) -> Variant

# 检查类型是否兼容
static func are_types_compatible(from_type: BaseVariable.VariableType, to_type: BaseVariable.VariableType) -> bool
```

## 2. 主插件实现规格

### 2.1 CreateLocalVariableInspector
```gdscript
# create_local_variable_inspector.gd
@tool
extends EditorInspectorPlugin
class_name CreateLocalVariableInspector

var _current_object: CreateLocalVariableInstruction = null
var _variable_type_editor: EditorProperty = null
var _default_value_editor: DynamicValueEditor = null

func _can_handle(object: Object) -> bool:
    return object is CreateLocalVariableInstruction

func _parse_begin(object: Object) -> void:
    _current_object = object as CreateLocalVariableInstruction
    # 监听 variable_type 变化
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
    # 通知编辑器更新
    if _default_value_editor:
        _default_value_editor.update_editor_type()
```

### 2.2 DynamicValueEditor 核心逻辑
```gdscript
# dynamic_value_editor.gd
@tool
extends EditorProperty
class_name DynamicValueEditor

var _current_editor: BaseValueEditor = null
var _current_type: BaseVariable.VariableType = BaseVariable.VariableType.NIL
var _updating: bool = false

func _init():
    # 创建类型标签容器
    var container = HBoxContainer.new()
    add_child(container)
    
    # 类型图标
    var type_icon = TextureRect.new()
    type_icon.custom_minimum_size = Vector2(16, 16)
    container.add_child(type_icon)
    
    # 编辑器容器
    var editor_container = VBoxContainer.new()
    editor_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    container.add_child(editor_container)
    
    # 错误提示标签
    var error_label = Label.new()
    error_label.add_theme_color_override("font_color", Color.RED)
    error_label.visible = false
    editor_container.add_child(error_label)

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

func _switch_editor(new_type: BaseVariable.VariableType) -> void:
    # 清理旧编辑器
    if _current_editor:
        _current_editor.value_changed.disconnect(_on_editor_value_changed)
        _current_editor.queue_free()
    
    # 创建新编辑器
    var editor_class = TypeMapping.get_editor_class(new_type)
    if editor_class:
        _current_editor = editor_class.new()
        _current_editor.value_changed.connect(_on_editor_value_changed)
        
        # 添加到编辑器容器
        var editor_container = get_child(0).get_child(1)
        editor_container.add_child(_current_editor)
        
        # 设置默认值
        var default_value = TypeMapping.get_default_value(new_type)
        _current_editor.set_value(default_value)

func _on_editor_value_changed(new_value: Variant) -> void:
    if _updating:
        return
    
    var object = get_edited_object() as CreateLocalVariableInstruction
    if not object:
        return
    
    # 验证值
    if not _current_editor.validate_value(new_value):
        _show_error(_current_editor.get_validation_error())
        return
    
    _hide_error()
    emit_changed(get_edited_property(), new_value)

func update_editor_type() -> void:
    _update_property()

func _show_error(message: String) -> void:
    var error_label = get_child(0).get_child(1).get_child(1)
    error_label.text = message
    error_label.visible = true

func _hide_error() -> void:
    var error_label = get_child(0).get_child(1).get_child(1)
    error_label.visible = false
```

## 3. 具体类型编辑器实现规格

### 3.1 基础类型编辑器
```gdscript
# bool_editor.gd
@tool
extends BaseValueEditor
class_name BoolValueEditor

var _checkbox: CheckBox

func _init():
    _checkbox = CheckBox.new()
    _checkbox.toggled.connect(_on_toggled)
    add_child(_checkbox)

func set_value(value: Variant) -> void:
    _checkbox.button_pressed = bool(value)

func get_value() -> Variant:
    return _checkbox.button_pressed

func _on_toggled(pressed: bool) -> void:
    value_changed.emit(pressed)

func get_supported_types() -> Array[BaseVariable.VariableType]:
    return [BaseVariable.VariableType.BOOL]

func validate_value(value: Variant) -> bool:
    return value is bool

func get_validation_error() -> String:
    return "值必须是布尔类型"

# number_editor.gd
@tool
extends BaseValueEditor
class_name NumberValueEditor

var _spinbox: SpinBox
var _type: BaseVariable.VariableType = BaseVariable.VariableType.INT

func _init(for_type: BaseVariable.VariableType = BaseVariable.VariableType.INT):
    _type = for_type
    _spinbox = SpinBox.new()
    _spinbox.value_changed.connect(_on_value_changed)
    
    match _type:
        BaseVariable.VariableType.INT:
            _spinbox.step = 1
            _spinbox.allow_greater = true
            _spinbox.allow_lesser = true
        BaseVariable.VariableType.FLOAT:
            _spinbox.step = 0.01
            _spinbox.allow_greater = true
            _spinbox.allow_lesser = true
    
    add_child(_spinbox)

func set_value(value: Variant) -> void:
    if value is int or value is float:
        _spinbox.value = value

func get_value() -> Variant:
    return _spinbox.value if _type == BaseVariable.VariableType.FLOAT else int(_spinbox.value)

func _on_value_changed(value: float) -> void:
    value_changed.emit(get_value())

func get_supported_types() -> Array[BaseVariable.VariableType]:
    return [BaseVariable.VariableType.INT, BaseVariable.VariableType.FLOAT]

func validate_value(value: Variant) -> bool:
    return value is int or value is float

func get_validation_error() -> String:
    return "值必须是数字类型"
```

### 3.2 向量类型编辑器
```gdscript
# vector_editor.gd
@tool
extends BaseValueEditor
class_name VectorValueEditor

var _container: HBoxContainer
var _x_spinbox: SpinBox
var _y_spinbox: SpinBox
var _z_spinbox: SpinBox
var _type: BaseVariable.VariableType
var _is_3d: bool = false

func _init(for_type: BaseVariable.VariableType):
    _type = for_type
    _is_3d = for_type in [BaseVariable.VariableType.VECTOR3, BaseVariable.VariableType.VECTOR3I]
    
    _container = HBoxContainer.new()
    add_child(_container)
    
    # X 分量
    _container.add_child(Label.new("X:"))
    _x_spinbox = _create_spinbox()
    _container.add_child(_x_spinbox)
    
    # Y 分量
    _container.add_child(Label.new("Y:"))
    _y_spinbox = _create_spinbox()
    _container.add_child(_y_spinbox)
    
    # Z 分量 (仅 3D)
    if _is_3d:
        _container.add_child(Label.new("Z:"))
        _z_spinbox = _create_spinbox()
        _container.add_child(_z_spinbox)

func _create_spinbox() -> SpinBox:
    var spinbox = SpinBox.new()
    spinbox.step = 1.0 if _type in [BaseVariable.VariableType.VECTOR2I, BaseVariable.VariableType.VECTOR3I] else 0.01
    spinbox.allow_greater = true
    spinbox.allow_lesser = true
    spinbox.value_changed.connect(_on_value_changed)
    return spinbox

func set_value(value: Variant) -> void:
    if value is Vector2:
        _x_spinbox.value = value.x
        _y_spinbox.value = value.y
    elif value is Vector2i:
        _x_spinbox.value = value.x
        _y_spinbox.value = value.y
    elif value is Vector3:
        _x_spinbox.value = value.x
        _y_spinbox.value = value.y
        _z_spinbox.value = value.z
    elif value is Vector3i:
        _x_spinbox.value = value.x
        _y_spinbox.value = value.y
        _z_spinbox.value = value.z

func get_value() -> Variant:
    match _type:
        BaseVariable.VariableType.VECTOR2:
            return Vector2(_x_spinbox.value, _y_spinbox.value)
        BaseVariable.VariableType.VECTOR2I:
            return Vector2i(int(_x_spinbox.value), int(_y_spinbox.value))
        BaseVariable.VariableType.VECTOR3:
            return Vector3(_x_spinbox.value, _y_spinbox.value, _z_spinbox.value)
        BaseVariable.VariableType.VECTOR3I:
            return Vector3i(int(_x_spinbox.value), int(_y_spinbox.value), int(_z_spinbox.value))
    return null

func _on_value_changed(_value: float) -> void:
    value_changed.emit(get_value())

func get_supported_types() -> Array[BaseVariable.VariableType]:
    return [BaseVariable.VariableType.VECTOR2, BaseVariable.VariableType.VECTOR2I, 
            BaseVariable.VariableType.VECTOR3, BaseVariable.VariableType.VECTOR3I]

func validate_value(value: Variant) -> bool:
    return value is Vector2 or value is Vector2i or value is Vector3 or value is Vector3i

func get_validation_error() -> String:
    return "值必须是向量类型"
```

## 4. 类型映射系统实现

```gdscript
# type_mapping.gd
extends RefCounted
class_name TypeMapping

# 类型到编辑器类的映射
static var _editor_map: Dictionary = {
    BaseVariable.VariableType.NIL: preload("res://addons/fuse/editor/inspector/editors/null_editor.gd"),
    BaseVariable.VariableType.BOOL: preload("res://addons/fuse/editor/inspector/editors/bool_editor.gd"),
    BaseVariable.VariableType.INT: preload("res://addons/fuse/editor/inspector/editors/number_editor.gd"),
    BaseVariable.VariableType.FLOAT: preload("res://addons/fuse/editor/inspector/editors/number_editor.gd"),
    BaseVariable.VariableType.STRING: preload("res://addons/fuse/editor/inspector/editors/string_editor.gd"),
    BaseVariable.VariableType.VECTOR2: preload("res://addons/fuse/editor/inspector/editors/vector_editor.gd"),
    BaseVariable.VariableType.VECTOR2I: preload("res://addons/fuse/editor/inspector/editors/vector_editor.gd"),
    BaseVariable.VariableType.VECTOR3: preload("res://addons/fuse/editor/inspector/editors/vector_editor.gd"),
    BaseVariable.VariableType.VECTOR3I: preload("res://addons/fuse/editor/inspector/editors/vector_editor.gd"),
    BaseVariable.VariableType.COLOR: preload("res://addons/fuse/editor/inspector/editors/color_editor.gd"),
    BaseVariable.VariableType.ARRAY: preload("res://addons/fuse/editor/inspector/editors/array_editor.gd"),
    BaseVariable.VariableType.DICTIONARY: preload("res://addons/fuse/editor/inspector/editors/dictionary_editor.gd"),
    BaseVariable.VariableType.OBJECT: preload("res://addons/fuse/editor/inspector/editors/resource_editor.gd"),
    BaseVariable.VariableType.NODE_PATH: preload("res://addons/fuse/editor/inspector/editors/node_path_editor.gd"),
    BaseVariable.VariableType.RID: preload("res://addons/fuse/editor/inspector/editors/rid_editor.gd"),
    BaseVariable.VariableType.SIGNAL: preload("res://addons/fuse/editor/inspector/editors/signal_editor.gd"),
    BaseVariable.VariableType.CALLABLE: preload("res://addons/fuse/editor/inspector/editors/callable_editor.gd"),
    BaseVariable.VariableType.PACKED_BYTE_ARRAY: preload("res://addons/fuse/editor/inspector/editors/packed_array_editor.gd"),
    BaseVariable.VariableType.PACKED_INT_ARRAY: preload("res://addons/fuse/editor/inspector/editors/packed_array_editor.gd"),
    BaseVariable.VariableType.PACKED_FLOAT_ARRAY: preload("res://addons/fuse/editor/inspector/editors/packed_array_editor.gd"),
    BaseVariable.VariableType.PACKED_STRING_ARRAY: preload("res://addons/fuse/editor/inspector/editors/packed_array_editor.gd"),
    BaseVariable.VariableType.PACKED_VECTOR2_ARRAY: preload("res://addons/fuse/editor/inspector/editors/packed_array_editor.gd"),
    BaseVariable.VariableType.PACKED_VECTOR3_ARRAY: preload("res://addons/fuse/editor/inspector/editors/packed_array_editor.gd"),
    BaseVariable.VariableType.PACKED_COLOR_ARRAY: preload("res://addons/fuse/editor/inspector/editors/packed_array_editor.gd")
}

# 类型默认值映射
static var _default_values: Dictionary = {
    BaseVariable.VariableType.NIL: null,
    BaseVariable.VariableType.BOOL: false,
    BaseVariable.VariableType.INT: 0,
    BaseVariable.VariableType.FLOAT: 0.0,
    BaseVariable.VariableType.STRING: "",
    BaseVariable.VariableType.VECTOR2: Vector2.ZERO,
    BaseVariable.VariableType.VECTOR2I: Vector2i.ZERO,
    BaseVariable.VariableType.VECTOR3: Vector3.ZERO,
    BaseVariable.VariableType.VECTOR3I: Vector3i.ZERO,
    BaseVariable.VariableType.COLOR: Color.WHITE,
    BaseVariable.VariableType.ARRAY: [],
    BaseVariable.VariableType.DICTIONARY: {},
    BaseVariable.VariableType.OBJECT: null,
    BaseVariable.VariableType.NODE_PATH: NodePath(""),
    BaseVariable.VariableType.RID: RID(),
    BaseVariable.VariableType.SIGNAL: Signal(),
    BaseVariable.VariableType.CALLABLE: Callable(),
    BaseVariable.VariableType.PACKED_BYTE_ARRAY: PackedByteArray(),
    BaseVariable.VariableType.PACKED_INT_ARRAY: PackedInt32Array(),
    BaseVariable.VariableType.PACKED_FLOAT_ARRAY: PackedFloat32Array(),
    BaseVariable.VariableType.PACKED_STRING_ARRAY: PackedStringArray(),
    BaseVariable.VariableType.PACKED_VECTOR2_ARRAY: PackedVector2Array(),
    BaseVariable.VariableType.PACKED_VECTOR3_ARRAY: PackedVector3Array(),
    BaseVariable.VariableType.PACKED_COLOR_ARRAY: PackedColorArray()
}

static func get_editor_class(variable_type: BaseVariable.VariableType) -> GDScript:
    return _editor_map.get(variable_type, null)

static func get_default_value(variable_type: BaseVariable.VariableType) -> Variant:
    return _default_values.get(variable_type, null)

static func convert_value(value: Variant, from_type: BaseVariable.VariableType, to_type: BaseVariable.VariableType) -> Variant:
    # 如果类型相同，直接返回
    if from_type == to_type:
        return value
    
    # 尝试类型转换
    match to_type:
        BaseVariable.VariableType.INT:
            return int(value)
        BaseVariable.VariableType.FLOAT:
            return float(value)
        BaseVariable.VariableType.STRING:
            return str(value)
        BaseVariable.VariableType.BOOL:
            return bool(value)
        BaseVariable.VariableType.VECTOR2:
            if value is Vector2i:
                return Vector2(value.x, value.y)
            elif value is Vector3:
                return Vector2(value.x, value.y)
            elif value is Vector3i:
                return Vector2(float(value.x), float(value.y))
        BaseVariable.VariableType.VECTOR2I:
            if value is Vector2:
                return Vector2i(int(value.x), int(value.y))
            elif value is Vector3:
                return Vector2i(int(value.x), int(value.y))
            elif value is Vector3i:
                return Vector2i(value.x, value.y)
        # ... 其他类型转换
    
    # 无法转换时返回默认值
    return get_default_value(to_type)

static func are_types_compatible(from_type: BaseVariable.VariableType, to_type: BaseVariable.VariableType) -> bool:
    # 完全兼容的类型组
    var compatible_groups: Dictionary = {
        BaseVariable.VariableType.INT: [BaseVariable.VariableType.FLOAT, BaseVariable.VariableType.STRING, BaseVariable.VariableType.BOOL],
        BaseVariable.VariableType.FLOAT: [BaseVariable.VariableType.INT, BaseVariable.VariableType.STRING, BaseVariable.VariableType.BOOL],
        BaseVariable.VariableType.STRING: [],  # 字符串可以接受任何类型
        BaseVariable.VariableType.BOOL: [BaseVariable.VariableType.INT, BaseVariable.VariableType.FLOAT, BaseVariable.VariableType.STRING],
        BaseVariable.VariableType.VECTOR2: [BaseVariable.VariableType.VECTOR2I, BaseVariable.VariableType.VECTOR3, BaseVariable.VariableType.VECTOR3I],
        BaseVariable.VariableType.VECTOR2I: [BaseVariable.VariableType.VECTOR2, BaseVariable.VariableType.VECTOR3, BaseVariable.VariableType.VECTOR3I],
        BaseVariable.VariableType.VECTOR3: [BaseVariable.VariableType.VECTOR3I, BaseVariable.VariableType.VECTOR2, BaseVariable.VariableType.VECTOR2I],
        BaseVariable.VariableType.VECTOR3I: [BaseVariable.VariableType.VECTOR3, BaseVariable.VariableType.VECTOR2, BaseVariable.VariableType.VECTOR2I]
    }
    
    if to_type == BaseVariable.VariableType.STRING:
        return true  # 任何类型都可以转换为字符串
    
    if from_type == to_type:
        return true
    
    var compatible = compatible_groups.get(from_type, [])
    return to_type in compatible
```

## 5. 插件集成规格

### 5.1 主插件文件修改
```gdscript
# 在 addons/fuse/plugin.gd 的 _enter_tree() 方法中添加:
func _enter_tree():
    # ... 现有代码 ...
    
    # 注册 Inspector 插件
    var inspector_plugin = preload("res://addons/fuse/editor/inspector/create_local_variable_inspector.gd").new()
    add_inspector_plugin(inspector_plugin)
    
    # ... 现有代码 ...

# 在 _exit_tree() 方法中添加:
func _exit_tree():
    # ... 现有代码 ...
    
    # 清理 Inspector 插件
    # 注意: Godot 会自动清理 Inspector 插件，但为了完整性可以显式移除
    
    # ... 现有代码 ...
```

## 6. 测试规格

### 6.1 单元测试结构
```gdscript
# test_type_mapping.gd
extends "res://addons/gut/test.gd"

func test_type_mapping_basic():
    assert_eq(TypeMapping.get_default_value(BaseVariable.VariableType.INT), 0)
    assert_eq(TypeMapping.get_default_value(BaseVariable.VariableType.BOOL), false)

func test_type_conversion():
    var result = TypeMapping.convert_value(42, BaseVariable.VariableType.INT, BaseVariable.VariableType.FLOAT)
    assert_eq(result, 42.0)

func test_type_compatibility():
    assert_true(TypeMapping.are_types_compatible(BaseVariable.VariableType.INT, BaseVariable.VariableType.FLOAT))
    assert_false(TypeMapping.are_types_compatible(BaseVariable.VariableType.VECTOR2, BaseVariable.VariableType.COLOR))
```

### 6.2 集成测试结构
```gdscript
# test_inspector_integration.gd
extends "res://addons/gut/test.gd"

func test_create_local_variable_inspector():
    var instruction = CreateLocalVariableInstruction.new()
    instruction.variable_type = BaseVariable.VariableType.INT
    
    # 模拟 Inspector 插件行为
    var inspector = CreateLocalVariableInspector.new()
    assert_true(inspector._can_handle(instruction))
```

## 7. 性能优化规格

### 7.1 编辑器实例缓存
```gdscript
# 在 TypeMapping 中添加编辑器实例缓存
static var _editor_cache: Dictionary = {}

static func get_editor_instance(variable_type: BaseVariable.VariableType) -> BaseValueEditor:
    if not _editor_cache.has(variable_type):
        var editor_class = get_editor_class(variable_type)
        if editor_class:
            _editor_cache[variable_type] = editor_class.new()
    return _editor_cache.get(variable_type, null)
```

### 7.2 延迟加载复杂编辑器
```gdscript
# 为复杂编辑器 (如 ArrayEditor) 实现延迟加载
class_name ArrayEditor extends BaseValueEditor

var _editor_loaded: bool = false
var _placeholder: Label

func _init():
    _placeholder = Label.new("点击编辑数组...")
    _placeholder.gui_input.connect(_on_placeholder_input)
    add_child(_placeholder)

func _on_placeholder_input(event: InputEvent):
    if event is InputEventMouseButton and event.pressed:
        _load_full_editor()

func _load_full_editor():
    if _editor_loaded:
        return
    
    _editor_loaded = true
    _placeholder.queue_free()
    # 创建完整的数组编辑器 UI
```

这个技术规格提供了实现动态 Inspector 插件所需的所有核心组件和接口定义，确保了系统的可扩展性和维护性。