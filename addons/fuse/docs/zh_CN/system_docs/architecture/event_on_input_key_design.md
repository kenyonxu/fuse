# OnInputKey 事件设计文档

**文档版本**: 1.0
**创建日期**: 2024-12-10
**状态**: ✅ 已实现
**最后更新**: 2026-01-25
**实际实现**: `addons/fuse/events/on_input_key.gd`

## 概述

`OnInputKey` 是一个自定义事件类，用于监听用户的键盘输入并触发相应的事件。该事件支持三种按键类型：按下（pressed）、释放（released）和持续按下（held）。用户可以通过编辑器界面选择要监听的按键，并配置相关参数。

## 核心功能设计

### 1. 事件类型支持

支持三种键盘事件类型：

- **按下事件（Pressed）**：当按键被按下时触发一次
- **释放事件（Released）**：当按键被释放时触发一次
- **持续按下事件（Held）**：按键持续按下时按配置的间隔重复触发

### 2. 配置参数

```gdscript
## 要监听的按键代码
@export var key_code: int = KEY_NONE:
    set(value):
        if key_code != value:
            key_code = value
            _update_resource_name()
            notify_property_list_changed()  # 触发检视器更新

## 按键事件类型
@export_enum("按下:0", "释放:1", "持续按下:2") var key_event_type: int = 0:
    set(value):
        if key_event_type != value:
            key_event_type = value
            _update_resource_name()
            notify_property_list_changed()  # 触发检视器更新

## 持续按下事件的初始延迟（秒）
@export var held_initial_delay: float = 1.0:
    set(value):
        if held_initial_delay != value:
            held_initial_delay = value
            _update_resource_name()
            notify_property_list_changed()  # 触发检视器更新

## 持续按下事件的重复间隔（秒）
@export var held_repeat_interval: float = 0.2:
    set(value):
        if held_repeat_interval != value:
            held_repeat_interval = value
            _update_resource_name()
            notify_property_list_changed()  # 触发检视器更新

## 是否只触发一次（仅对 pressed 和 released 有效）
@export var trigger_once: bool = false:
    set(value):
        if trigger_once != value:
            trigger_once = value
            _update_resource_name()
            notify_property_list_changed()  # 触发检视器更新

## 自定义按键名称（用于显示）
@export var custom_key_name: String = "":
    set(value):
        if custom_key_name != value:
            custom_key_name = value
            _update_resource_name()
            notify_property_list_changed()  # 触发检视器更新
```

### 3. 内部状态管理

```gdscript
# 内部状态变量
var _is_key_pressed: bool = false
var _has_triggered: bool = false
var _held_timer: Timer = null
var _owner_node: Node = null

# 实现条件化检视器显示（使用 _validate_property 方法）
func _validate_property(property: Dictionary) -> void:
    # 当按键事件类型不是持续按下时，禁用持续按下相关属性
    if key_event_type != 2:  # 不是持续按下事件
        if property.name == "held_initial_delay" or property.name == "held_repeat_interval":
            property.usage = PROPERTY_USAGE_READ_ONLY
    
    # 当按键事件类型是持续按下时，禁用 trigger_once 属性
    if key_event_type == 2:  # 持续按下事件
        if property.name == "trigger_once":
            property.usage = PROPERTY_USAGE_READ_ONLY
```

## 条件化属性显示设计

为了提供更好的用户体验，OnInputKey 实现了条件化属性显示功能，根据按键事件类型自动显示或隐藏相关参数。

### 1. 设计原理

参考 `SetIntVariable` 中的 `set_with_another_variable` 模式，使用 Godot 的 `_validate_property()` 方法来实现动态属性显示控制。

### 2. 实现机制

```gdscript
# 实现条件化检视器显示（使用 _validate_property 方法）
func _validate_property(property: Dictionary) -> void:
    # 当按键事件类型不是持续按下时，禁用持续按下相关属性
    if key_event_type != 2:  # 不是持续按下事件
        if property.name == "held_initial_delay" or property.name == "held_repeat_interval":
            property.usage = PROPERTY_USAGE_READ_ONLY
    
    # 当按键事件类型是持续按下时，禁用 trigger_once 属性
    if key_event_type == 2:  # 持续按下事件
        if property.name == "trigger_once":
            property.usage = PROPERTY_USAGE_READ_ONLY
```

### 3. 属性显示规则

| 按键事件类型 | held_initial_delay | held_repeat_interval | trigger_once |
|---------------|-------------------|---------------------|--------------|
| 按下 (0)     | 隐藏              | 隐藏                 | 显示         |
| 释放 (1)     | 隐藏              | 隐藏                 | 显示         |
| 持续按下 (2)  | 显示              | 显示                 | 隐藏         |

### 4. 用户体验优化

1. **即时反馈**：当用户切换事件类型时，相关属性立即显示或隐藏
2. **视觉提示**：隐藏的属性在检视器中显示为只读状态，提供清晰的视觉反馈
3. **状态保持**：切换事件类型时，已设置的参数值会被保留，方便用户切换回来

### 5. 技术细节

- 使用 `notify_property_list_changed()` 触发检视器更新
- 在每个属性的 setter 中调用更新，确保状态同步
- 使用 `PROPERTY_USAGE_READ_ONLY` 而非完全隐藏属性，保持界面一致性

## 专家审查和关键修复

根据专家审查，发现了以下关键问题并已修复：

### 🔴 严重问题（已修复）

#### 1. 输入事件重复处理
**问题**：同时连接 `input` 和 `unhandled_key_input` 会导致事件被处理两次
**修复**：只保留 `unhandled_key_input`，并添加事件标记处理

```gdscript
# 修复前（有问题）
_owner_node.input.connect(_on_input)
_owner_node.unhandled_key_input.connect(_on_unhandled_key_input)

# 修复后（正确）
_owner_node.set_process_unhandled_key_input(true)
if not _owner_node.unhandled_key_input.is_connected(_on_unhandled_key_input):
    _owner_node.unhandled_key_input.connect(_on_unhandled_key_input)

func _on_unhandled_key_input(event: InputEvent):
    # 标记事件已处理，避免被其他节点处理
    if event is InputEventKey and event.keycode == key_code:
        get_viewport().set_input_as_handled()
    _on_input(event)
```

#### 2. 持续按下逻辑的定时器错误
**问题**：`trigger_once` 参数影响持续按下事件的重复触发
**修复**：持续按下事件不受 `trigger_once` 限制，并正确重置状态

```gdscript
# 修复前（逻辑错误）
if not trigger_once or not _has_triggered:
    _has_triggered = true
    triggered.emit()

# 修复后（正确）
# 持续按下事件不受 trigger_once 限制
_log_info("触发持续按下事件: %s" % _get_key_name())
triggered.emit(_owner_node)
```

#### 3. 状态管理不完整
**问题**：按键释放后没有重置 `_has_triggered` 状态
**修复**：在按键释放事件中重置触发状态

```gdscript
# 修复后（添加状态重置）
func _handle_key_released():
    # ... 现有代码 ...
    _has_triggered = true
    _log_info("触发按键释放事件: %s" % _get_key_name())
    triggered.emit(_owner_node)
    
    # 按键释放后重置触发状态，允许下次按键再次触发
    _has_triggered = false
```

#### 4. 内存泄漏风险
**问题**：移除定时器前没有停止它
**修复**：在 `queue_free()` 前调用 `stop()`

```gdscript
# 修复后（正确清理）
func _cleanup_held_timer():
    if _held_timer:
        _held_timer.stop()  # 先停止定时器
        if _held_timer.timeout.is_connected(_on_held_timer_timeout):
            _held_timer.timeout.disconnect(_on_held_timer_timeout)
        if _owner_node and is_instance_valid(_owner_node):
            _owner_node.remove_child(_held_timer)
        _held_timer.queue_free()
        _held_timer = null
```

### 🟡 设计改进（建议实现）

#### 1. API 设计不够 Godot 风格
**问题**：使用字符串枚举而非类型安全的枚举
**建议**：使用 Godot 4 的 `enum` 特性

```gdscript
# 当前（不推荐）
@export_enum("按下:0", "释放:1", "持续按下:2") var key_event_type: int = 0

# 建议（类型安全）
enum KeyEventType { PRESSED, RELEASED, HELD }
@export var key_event_type: KeyEventType = KeyEventType.PRESSED
```

#### 2. Editor 插件缺少状态同步
**问题**：`InputKeySelector` 缺少 `_update_property` 实现
**建议**：完整实现属性同步方法

```gdscript
# 建议添加
func _update_property():
    var object = get_edited_object()
    if object and object.has_method("get"):
        current_key_code = object.get(get_edited_property())
        var key_name = OS.get_scancode_string(current_key_code)
        property_control.text = "按键: " + key_name
```

#### 3. 性能优化建议
**问题**：每个事件实例都创建独立 Timer
**建议**：使用单例 Timer 管理器或帧计数

#### 4. 缺少输入优先级控制
**问题**：无法处理多个事件监听同一按键时的优先级
**建议**：增加 `priority` 属性

### 📋 关键修复清单

✅ **已修复的核心问题：**
- [x] 移除重复的输入处理连接
- [x] 修复持续按下事件的 trigger_once 逻辑
- [x] 添加按键释放后的状态重置
- [x] 修复定时器内存泄漏问题
- [x] 添加事件处理标记防止重复处理

### 🧪 测试验证要点

1. **按键按下事件**：在 `trigger_once=true` 时只触发一次
2. **持续按下事件**：释放后再次按下能正确重置和触发
3. **多个事件监听**：同一按键的多个事件不会相互干扰
4. **内存管理**：场景卸载时定时器和信号正确清理
5. **性能测试**：100个持续按下事件同时运行的性能表现

## 按键选择界面设计

### 1. 编辑器插件集成

创建一个自定义的 Inspector 插件，用于在编辑器中提供按键选择功能：

```gdscript
# addons/fuse/editor/input_key_selector/input_key_selector.gd
@tool
class_name InputKeySelector extends EditorProperty

var dialog: InputKeyDialog
var property_control: Button
var current_key_code: int = KEY_NONE

func _init():
    property_control = Button.new()
    property_control.text = "选择按键"
    property_control.pressed.connect(_on_button_pressed)
    add_child(property_control)
    add_focusable(property_control)

func _on_button_pressed():
    dialog = InputKeyDialog.new()
    dialog.key_selected.connect(_on_key_selected)
    EditorInterface.popup_dialog(dialog)

func _on_key_selected(key_code: int):
    current_key_code = key_code
    var key_name = OS.get_scancode_string(key_code)
    property_control.text = "按键: " + key_name
    emit_changed(get_edited_property(), key_code)
```

### 2. 按键选择对话框

```gdscript
# addons/fuse/editor/input_key_selector/input_key_dialog.gd
@tool
class_name InputKeyDialog extends AcceptDialog

signal key_selected(key_code: int)

var instruction_label: Label
var waiting_for_key: bool = false

func _init():
    title = "选择按键"
    min_size = Vector2(300, 150)
    
    instruction_label = Label.new()
    instruction_label.text = "点击下方按钮，然后按下任意键"
    add_child(instruction_label)
    
    var start_button = Button.new()
    start_button.text = "开始捕获按键"
    start_button.pressed.connect(_start_capture)
    add_child(start_button)
    
    var cancel_button = Button.new()
    cancel_button.text = "取消"
    cancel_button.pressed.connect(hide)
    add_child(cancel_button)
    
    connect("gui_input", _on_gui_input)

func _start_capture():
    waiting_for_key = true
    instruction_label.text = "请按下任意键..."

func _on_gui_input(event: InputEvent):
    if not waiting_for_key:
        return
    
    if event is InputEventKey and event.pressed:
        key_selected.emit(event.keycode)
        hide()

func _notification(what):
    if what == NOTIFICATION_VISIBILITY_CHANGED:
        if not visible:
            waiting_for_key = false
```

## 按键监听和事件触发机制

### 1. 初始化流程

```gdscript
func initialize(owner_node: Node) -> void:
    _log_debug("初始化 OnInputKey")
    
    # 验证 owner_node
    if not owner_node:
        _create_fuse_error("Owner 节点为空", FuseError.ErrorType.CONFIGURATION_ERROR)
        return
    
    _owner_node = owner_node
    
    # 验证按键代码
    if key_code == KEY_NONE:
        _create_fuse_error("未指定有效的按键代码", FuseError.ErrorType.CONFIGURATION_ERROR)
        return
    
    # 连接输入处理
    if not owner_node.tree_entered.is_connected(_on_tree_entered):
        owner_node.tree_entered.connect(_on_tree_entered)
    
    # 如果已经在场景树中，立即设置输入处理
    if owner_node.is_inside_tree():
        _setup_input_processing()
    
    _log_debug("OnInputKey 初始化完成: %s" % get_description())
```

### 2. 输入处理设置

```gdscript
func _setup_input_processing():
    if not _owner_node:
        return
    
    # 确保节点可以处理输入
    _owner_node.set_process_unhandled_key_input(true)
    
    # 只连接 unhandled_key_input，避免重复处理
    if not _owner_node.unhandled_key_input.is_connected(_on_unhandled_key_input):
        _owner_node.unhandled_key_input.connect(_on_unhandled_key_input)

func _on_tree_entered():
    _setup_input_processing()
```

### 3. 按键事件处理

```gdscript
func _on_input(event: InputEvent):
    if not event is InputEventKey:
        return
    
    if event.keycode != key_code:
        return
    
    match key_event_type:
        0:  # 按下
            if event.pressed and not event.is_echo():
                _handle_key_pressed()
        1:  # 释放
            if not event.pressed:
                _handle_key_released()
        2:  # 持续按下
            if event.pressed:
                if not event.is_echo():
                    _handle_key_held_start()
            else:
                _handle_key_held_end()

func _on_unhandled_key_input(event: InputEvent):
    # 标记事件已处理，避免被其他节点处理
    if event is InputEventKey and event.keycode == key_code:
        get_viewport().set_input_as_handled()
    _on_input(event)
```

### 4. 事件触发逻辑

```gdscript
func _handle_key_pressed():
    _log_debug("按键按下: %s" % _get_key_name())
    
    # 检查是否只触发一次
    if trigger_once and _has_triggered:
        _log_debug("已触发过，跳过")
        return
    
    _has_triggered = true
    _log_info("触发按键按下事件: %s" % _get_key_name())
    triggered.emit(_owner_node)

func _handle_key_released():
    _log_debug("按键释放: %s" % _get_key_name())
    
    # 检查是否只触发一次
    if trigger_once and _has_triggered:
        _log_debug("已触发过，跳过")
        return
    
    _has_triggered = true
    _log_info("触发按键释放事件: %s" % _get_key_name())
    triggered.emit(_owner_node)
    
    # 按键释放后重置触发状态，允许下次按键再次触发
    _has_triggered = false

func _handle_key_held_start():
    if _is_key_pressed:
        return  # 已经在按下状态
    
    _is_key_pressed = true
    _log_debug("开始持续按下: %s" % _get_key_name())
    
    # 创建定时器
    _create_held_timer()
    
    # 立即触发一次（持续按下事件不受 trigger_once 限制）
    _log_info("触发持续按下事件: %s" % _get_key_name())
    triggered.emit(_owner_node)

func _handle_key_held_end():
    if not _is_key_pressed:
        return
    
    _is_key_pressed = false
    _log_debug("结束持续按下: %s" % _get_key_name())
    
    # 清理定时器
    _cleanup_held_timer()

func _create_held_timer():
    _cleanup_held_timer()
    
    _held_timer = Timer.new()
    _held_timer.wait_time = held_initial_delay
    _held_timer.one_shot = false
    _held_timer.timeout.connect(_on_held_timer_timeout)
    _owner_node.add_child(_held_timer)
    _held_timer.start()

func _on_held_timer_timeout():
    _log_debug("持续按下重复触发: %s" % _get_key_name())
    
    # 更新定时器间隔为重复间隔
    if _held_timer.wait_time != held_repeat_interval:
        _held_timer.wait_time = held_repeat_interval
    
    # 触发事件
    _log_info("触发持续按下重复事件: %s" % _get_key_name())
    triggered.emit(_owner_node)

func _cleanup_held_timer():
    if _held_timer:
        # 先停止定时器
        _held_timer.stop()
        
        if _held_timer.timeout.is_connected(_on_held_timer_timeout):
            _held_timer.timeout.disconnect(_on_held_timer_timeout)
        
        if _owner_node and is_instance_valid(_owner_node):
            _owner_node.remove_child(_held_timer)
        
        _held_timer.queue_free()
        _held_timer = null
```

## 资源名称更新逻辑

```gdscript
func _update_resource_name():
    var key_name = _get_key_name()
    var event_type_name = _get_event_type_name()
    var once_text = trigger_once ? " [仅一次]" : ""
    
    match key_event_type:
        0:  # 按下
            resource_name = "按键按下: %s%s" % [key_name, once_text]
        1:  # 释放
            resource_name = "按键释放: %s%s" % [key_name, once_text]
        2:  # 持续按下
            var delay_text = " (延迟:%.1fs, 间隔:%.1fs)" % [held_initial_delay, held_repeat_interval]
            resource_name = "按键持续按下: %s%s" % [key_name, delay_text]

func _get_key_name() -> String:
    if not custom_key_name.is_empty():
        return custom_key_name
    
    if key_code == KEY_NONE:
        return "未设置"
    
    return OS.get_scancode_string(key_code)

func _get_event_type_name() -> String:
    match key_event_type:
        0: return "按下"
        1: return "释放"
        2: return "持续按下"
        _: return "未知"
```

## 验证和错误处理机制

```gdscript
func validate() -> Array[String]:
    var errors: Array[String] = []
    
    # 验证按键代码
    if key_code == KEY_NONE:
        errors.append("必须指定有效的按键代码")
    
    # 验证持续按下参数
    if key_event_type == 2:  # 持续按下
        if held_initial_delay < 0:
            errors.append("初始延迟不能为负数")
        
        if held_repeat_interval <= 0:
            errors.append("重复间隔必须大于0")
        
        if held_initial_delay < 0.1:
            errors.append("警告：初始延迟过小可能导致性能问题")
        
        if held_repeat_interval < 0.05:
            errors.append("警告：重复间隔过小可能导致性能问题")
    
    return errors

func get_description() -> String:
    var key_name = _get_key_name()
    var event_type_name = _get_event_type_name()
    
    match key_event_type:
        0:  # 按下
            var once_text = trigger_once ? " (仅一次)" : ""
            return "当按下 %s 键时触发%s" % [key_name, once_text]
        1:  # 释放
            var once_text = trigger_once ? " (仅一次)" : ""
            return "当释放 %s 键时触发%s" % [key_name, once_text]
        2:  # 持续按下
            return "当持续按下 %s 键时触发 (延迟%.1fs, 间隔%.1fs)" % [
                key_name, held_initial_delay, held_repeat_interval
            ]
        _:
            return "未知按键事件类型"

func get_event_type() -> String:
    return "input_key"

func get_event_category() -> String:
    return "input"
```

## 生命周期管理

```gdscript
func terminate(owner_node: Node) -> void:
    _log_debug("清理 OnInputKey")
    
    # 断开信号连接
    if owner_node:
        if owner_node.tree_entered.is_connected(_on_tree_entered):
            owner_node.tree_entered.disconnect(_on_tree_entered)
        
        if owner_node.input.is_connected(_on_input):
            owner_node.input.disconnect(_on_input)
        
        if owner_node.unhandled_key_input.is_connected(_on_unhandled_key_input):
            owner_node.unhandled_key_input.disconnect(_on_unhandled_key_input)
    
    # 清理定时器
    _cleanup_held_timer()
    
    # 重置状态
    _is_key_pressed = false
    _has_triggered = false
    _owner_node = null
    
    _log_debug("OnInputKey 清理完成")

func reset() -> void:
    super.reset()
    _is_key_pressed = false
    _has_triggered = false
    _cleanup_held_timer()
    _log_debug("OnInputKey 状态已重置")
```

## 编辑器插件注册

### 1. 插件主文件注册

根据项目的插件架构，以下类应该注册到 `addons/fuse/plugin.gd` 中：

```gdscript
# 在 addons/fuse/plugin.gd 的 _enter_tree() 方法中添加：

# 注册按键选择相关编辑器类
add_custom_type("InputKeySelector", "EditorProperty", preload("res://addons/fuse/editor/input_key_selector.gd"), preload("res://icon.svg"))
add_custom_type("InputKeyDialog", "AcceptDialog", preload("res://addons/fuse/editor/input_key_dialog.gd"), preload("res://icon.svg"))
add_custom_type("InputKeyInspectorPlugin", "EditorInspectorPlugin", preload("res://addons/fuse/editor/input_key_inspector_plugin.gd"), preload("res://icon.svg"))

# 注册 Inspector 插件实例
var input_key_inspector = preload("res://addons/fuse/editor/input_key_inspector_plugin.gd").new()
add_inspector_plugin(input_key_inspector)
```

### 2. Inspector 插件实现

```gdscript
# addons/fuse/editor/input_key_selector/input_key_inspector_plugin.gd
@tool
extends EditorInspectorPlugin

func _can_handle(object):
    return object is OnInputKey

func _parse_property(object, type, name, hint_type, hint_string, usage_flags, wide):
    if name == "key_code" and object is OnInputKey:
        var selector = InputKeySelector.new()
        add_property_editor(name, selector)
        return true
    return false
```

### 3. 需要注册的类清单

| 类名 | 类型 | 文件路径 | 是否需要注册 |
|------|------|----------|--------------|
| OnInputKey | Resource | addons/fuse/events/on_input_key.gd | ✅ 是 |
| InputKeySelector | EditorProperty | addons/fuse/editor/input_key_selector.gd | ✅ 是 |
| InputKeyDialog | AcceptDialog | addons/fuse/editor/input_key_dialog.gd | ✅ 是 |
| InputKeyInspectorPlugin | EditorInspectorPlugin | addons/fuse/editor/input_key_inspector_plugin.gd | ✅ 是 |

### 4. 插件清理

在 `addons/fuse/plugin.gd` 的 `_exit_tree()` 方法中添加：

```gdscript
# 清理 OnInputKey 相关类
remove_custom_type("OnInputKey")
remove_custom_type("InputKeySelector")
remove_custom_type("InputKeyDialog")
remove_custom_type("InputKeyInspectorPlugin")

# 移除 Inspector 插件
if input_key_inspector:
    remove_inspector_plugin(input_key_inspector)
    input_key_inspector = null
```

## 使用示例

```gdscript
# 创建事件
var key_event = OnInputKey.new()

# 配置按键为空格键的按下事件
key_event.key_code = KEY_SPACE
key_event.key_event_type = 0  # 按下
key_event.trigger_once = true

# 配置持续按下事件
key_event.key_code = KEY_R
key_event.key_event_type = 2  # 持续按下
key_event.held_initial_delay = 0.5
key_event.held_repeat_interval = 0.1
```

## 最佳实践建议

1. **性能考虑**：避免设置过小的重复间隔，可能导致性能问题
2. **按键冲突**：避免多个事件监听同一个按键，可能导致意外行为
3. **状态管理**：合理使用 trigger_once 参数，避免重复触发
4. **错误处理**：始终检查验证结果，确保配置正确
5. **资源清理**：确保在不需要时正确终止事件，释放资源

## 扩展可能性

1. **多键组合**：支持同时按下多个按键的组合事件
2. **修饰键支持**：支持 Ctrl、Alt、Shift 等修饰键
3. **鼠标事件**：扩展支持鼠标按键和滚轮事件
4. **手柄支持**：扩展支持游戏手柄按键事件
5. **输入映射集成**：与 Godot 的输入映射系统集成

## 完整实现示例

### 1. OnInputKey 主类实现

```gdscript
# 文件：addons/fuse/events/on_input_key.gd
@tool
class_name OnInputKey extends BaseEvent

## 要监听的按键代码
@export var key_code: int = KEY_NONE:
	set(value):
		if key_code != value:
			key_code = value
			_update_resource_name()
			notify_property_list_changed()  # 触发检视器更新

## 按键事件类型
@export_enum("按下:0", "释放:1", "持续按下:2") var key_event_type: int = 0:
	set(value):
		if key_event_type != value:
			key_event_type = value
			_update_resource_name()
			notify_property_list_changed()  # 触发检视器更新

## 持续按下事件的初始延迟（秒）
@export var held_initial_delay: float = 1.0:
	set(value):
		if held_initial_delay != value:
			held_initial_delay = value
			_update_resource_name()
			notify_property_list_changed()  # 触发检视器更新

## 持续按下事件的重复间隔（秒）
@export var held_repeat_interval: float = 0.2:
	set(value):
		if held_repeat_interval != value:
			held_repeat_interval = value
			_update_resource_name()
			notify_property_list_changed()  # 触发检视器更新

## 是否只触发一次（仅对 pressed 和 released 有效）
@export var trigger_once: bool = false:
	set(value):
		if trigger_once != value:
			trigger_once = value
			_update_resource_name()
			notify_property_list_changed()  # 触发检视器更新

## 自定义按键名称（用于显示）
@export var custom_key_name: String = "":
	set(value):
		if custom_key_name != value:
			custom_key_name = value
			_update_resource_name()
			notify_property_list_changed()  # 触发检视器更新

# 内部状态变量
var _is_key_pressed: bool = false
var _has_triggered: bool = false
var _held_timer: Timer = null
var _owner_node: Node = null

# 实现条件化检视器显示（使用 _validate_property 方法）
func _validate_property(property: Dictionary) -> void:
	# 当按键事件类型不是持续按下时，禁用持续按下相关属性
	if key_event_type != 2:  # 不是持续按下事件
		if property.name == "held_initial_delay" or property.name == "held_repeat_interval":
			property.usage = PROPERTY_USAGE_READ_ONLY
	
	# 当按键事件类型是持续按下时，禁用 trigger_once 属性
	if key_event_type == 2:  # 持续按下事件
		if property.name == "trigger_once":
			property.usage = PROPERTY_USAGE_READ_ONLY

# 根据属性设置更新在列表中的名称
func _update_resource_name():
	var key_name = _get_key_name()
	
	match key_event_type:
		0:  # 按下
			var once_text = trigger_once ? " [仅一次]" : ""
			resource_name = "按键按下: %s%s" % [key_name, once_text]
		1:  # 释放
			var once_text = trigger_once ? " [仅一次]" : ""
			resource_name = "按键释放: %s%s" % [key_name, once_text]
		2:  # 持续按下
			var delay_text = " (延迟:%.1fs, 间隔:%.1fs)" % [held_initial_delay, held_repeat_interval]
			resource_name = "按键持续按下: %s%s" % [key_name, delay_text]

func initialize(owner_node: Node) -> void:
	_log_debug("初始化 OnInputKey")
	
	# 验证 owner_node
	if not owner_node:
		_create_fuse_error("Owner 节点为空", FuseError.ErrorType.CONFIGURATION_ERROR)
		return
	
	_owner_node = owner_node
	
	# 验证按键代码
	if key_code == KEY_NONE:
		_create_fuse_error("未指定有效的按键代码", FuseError.ErrorType.CONFIGURATION_ERROR)
		return
	
	# 连接输入处理
	if not owner_node.tree_entered.is_connected(_on_tree_entered):
		owner_node.tree_entered.connect(_on_tree_entered)
	
	# 如果已经在场景树中，立即设置输入处理
	if owner_node.is_inside_tree():
		_setup_input_processing()
	
	_log_debug("OnInputKey 初始化完成: %s" % get_description())

func terminate(owner_node: Node) -> void:
	_log_debug("清理 OnInputKey")
	
	# 断开信号连接
	if owner_node:
		if owner_node.tree_entered.is_connected(_on_tree_entered):
			owner_node.tree_entered.disconnect(_on_tree_entered)
		
		if owner_node.unhandled_key_input.is_connected(_on_unhandled_key_input):
			owner_node.unhandled_key_input.disconnect(_on_unhandled_key_input)
	
	# 清理定时器
	_cleanup_held_timer()
	
	# 重置状态
	_is_key_pressed = false
	_has_triggered = false
	_owner_node = null
	
	_log_debug("OnInputKey 清理完成")

func _setup_input_processing():
	if not _owner_node:
		return
	
	# 确保节点可以处理未处理的按键输入
	_owner_node.set_process_unhandled_key_input(true)
	
	# 只连接 unhandled_key_input，避免重复处理
	if not _owner_node.unhandled_key_input.is_connected(_on_unhandled_key_input):
		_owner_node.unhandled_key_input.connect(_on_unhandled_key_input)

func _on_tree_entered():
	_setup_input_processing()

func _on_input(event: InputEvent):
	if not event is InputEventKey:
		return
	
	if event.keycode != key_code:
		return
	
	match key_event_type:
		0:  # 按下
			if event.pressed and not event.is_echo():
				_handle_key_pressed()
		1:  # 释放
			if not event.pressed:
				_handle_key_released()
		2:  # 持续按下
			if event.pressed:
				if not event.is_echo():
					_handle_key_held_start()
			else:
				_handle_key_held_end()

func _on_unhandled_key_input(event: InputEvent):
	# 标记事件已处理，避免被其他节点处理
	if event is InputEventKey and event.keycode == key_code:
		get_viewport().set_input_as_handled()
	_on_input(event)

func _handle_key_pressed():
	_log_debug("按键按下: %s" % _get_key_name())
	
	# 检查是否只触发一次
	if trigger_once and _has_triggered:
		_log_debug("已触发过，跳过")
		return
	
	_has_triggered = true
	_log_info("触发按键按下事件: %s" % _get_key_name())
	triggered.emit(_owner_node)

func _handle_key_released():
	_log_debug("按键释放: %s" % _get_key_name())
	
	# 检查是否只触发一次
	if trigger_once and _has_triggered:
		_log_debug("已触发过，跳过")
		return
	
	_has_triggered = true
	_log_info("触发按键释放事件: %s" % _get_key_name())
	triggered.emit(_owner_node)
	
	# 按键释放后重置触发状态，允许下次按键再次触发
	_has_triggered = false

func _handle_key_held_start():
	if _is_key_pressed:
		return  # 已经在按下状态
	
	_is_key_pressed = true
	_log_debug("开始持续按下: %s" % _get_key_name())
	
	# 创建定时器
	_create_held_timer()
	
	# 立即触发一次（持续按下事件不受 trigger_once 限制）
	_log_info("触发持续按下事件: %s" % _get_key_name())
	triggered.emit(_owner_node)

func _handle_key_held_end():
	if not _is_key_pressed:
		return
	
	_is_key_pressed = false
	_log_debug("结束持续按下: %s" % _get_key_name())
	
	# 清理定时器
	_cleanup_held_timer()

func _create_held_timer():
	_cleanup_held_timer()
	
	_held_timer = Timer.new()
	_held_timer.wait_time = held_initial_delay
	_held_timer.one_shot = false
	_held_timer.timeout.connect(_on_held_timer_timeout)
	_owner_node.add_child(_held_timer)
	_held_timer.start()

func _on_held_timer_timeout():
	_log_debug("持续按下重复触发: %s" % _get_key_name())
	
	# 更新定时器间隔为重复间隔
	if _held_timer.wait_time != held_repeat_interval:
		_held_timer.wait_time = held_repeat_interval
	
	# 触发事件
	_log_info("触发持续按下重复事件: %s" % _get_key_name())
	triggered.emit(_owner_node)

func _cleanup_held_timer():
	if _held_timer:
		# 先停止定时器
		_held_timer.stop()
		
		if _held_timer.timeout.is_connected(_on_held_timer_timeout):
			_held_timer.timeout.disconnect(_on_held_timer_timeout)
		
		if _owner_node and is_instance_valid(_owner_node):
			_owner_node.remove_child(_held_timer)
		
		_held_timer.queue_free()
		_held_timer = null

func _get_key_name() -> String:
	if not custom_key_name.is_empty():
		return custom_key_name
	
	if key_code == KEY_NONE:
		return "未设置"
	
	return OS.get_scancode_string(key_code)

func get_description() -> String:
	var key_name = _get_key_name()
	
	match key_event_type:
		0:  # 按下
			var once_text = trigger_once ? " (仅一次)" : ""
			return "当按下 %s 键时触发%s" % [key_name, once_text]
		1:  # 释放
			var once_text = trigger_once ? " (仅一次)" : ""
			return "当释放 %s 键时触发%s" % [key_name, once_text]
		2:  # 持续按下
			return "当持续按下 %s 键时触发 (延迟%.1fs, 间隔%.1fs)" % [
				key_name, held_initial_delay, held_repeat_interval
			]
		_:
			return "未知按键事件类型"

func get_event_type() -> String:
	return "input_key"

func get_event_category() -> String:
	return "input"

func validate() -> Array[String]:
	var errors: Array[String] = []
	
	# 验证按键代码
	if key_code == KEY_NONE:
		errors.append("必须指定有效的按键代码")
	
	# 验证持续按下参数
	if key_event_type == 2:  # 持续按下
		if held_initial_delay < 0:
			errors.append("初始延迟不能为负数")
		
		if held_repeat_interval <= 0:
			errors.append("重复间隔必须大于0")
		
		if held_initial_delay < 0.1:
			errors.append("警告：初始延迟过小可能导致性能问题")
		
		if held_repeat_interval < 0.05:
			errors.append("警告：重复间隔过小可能导致性能问题")
	
	return errors

func reset() -> void:
	super.reset()
	_is_key_pressed = false
	_has_triggered = false
	_cleanup_held_timer()
	_log_debug("OnInputKey 状态已重置")

## 统一日志方法
func _log_debug(message: String) -> void:
	FuseLogger.log_debug("OnInputKey", log_level, message)

func _log_info(message: String) -> void:
	FuseLogger.log_info("OnInputKey", log_level, message)

func _log_warning(message: String) -> void:
	FuseLogger.log_warning("OnInputKey", log_level, message)

func _log_error(message: String) -> void:
	FuseLogger.log_error("OnInputKey", log_level, message)
```

### 2. 编辑器插件实现

```gdscript
# 文件：addons/fuse/editor/input_key_selector/input_key_inspector_plugin.gd
@tool
extends EditorInspectorPlugin


func _can_handle(object):
	return object is OnInputKey

func _parse_property(object, type, name, hint_type, hint_string, usage_flags, wide):
	if name == "key_code" and object is OnInputKey:
		var selector = InputKeySelector.new()
		add_property_editor(name, selector)
		return true
	return false
```

```gdscript
# 文件：addons/fuse/editor/input_key_selector/input_key_selector.gd
@tool
class_name InputKeySelector extends EditorProperty


var dialog: InputKeyDialog
var property_control: Button
var current_key_code: int = KEY_NONE

func _init():
	property_control = Button.new()
	property_control.text = "选择按键"
	property_control.pressed.connect(_on_button_pressed)
	add_child(property_control)
	add_focusable(property_control)

func _on_button_pressed():
	dialog = InputKeyDialog.new()
	dialog.key_selected.connect(_on_key_selected)
	EditorInterface.popup_dialog(dialog)

func _on_key_selected(key_code: int):
	current_key_code = key_code
	var key_name = OS.get_scancode_string(key_code)
	property_control.text = "按键: " + key_name
	emit_changed(get_edited_property(), key_code)

func _update_property():
	var object = get_edited_object()
	if object and object.has_method("get"):
		current_key_code = object.get(get_edited_property())
		var key_name = OS.get_scancode_string(current_key_code)
		property_control.text = "按键: " + key_name
```

```gdscript
# 文件：addons/fuse/editor/input_key_selector/input_key_dialog.gd
@tool
class_name InputKeyDialog extends AcceptDialog

signal key_selected(key_code: int)

var instruction_label: Label
var waiting_for_key: bool = false

func _init():
	title = "选择按键"
	min_size = Vector2(300, 150)
	
	instruction_label = Label.new()
	instruction_label.text = "点击下方按钮，然后按下任意键"
	add_child(instruction_label)
	
	var start_button = Button.new()
	start_button.text = "开始捕获按键"
	start_button.pressed.connect(_start_capture)
	add_child(start_button)
	
	var cancel_button = Button.new()
	cancel_button.text = "取消"
	cancel_button.pressed.connect(hide)
	add_child(cancel_button)
	
	connect("gui_input", _on_gui_input)

func _start_capture():
	waiting_for_key = true
	instruction_label.text = "请按下任意键..."

func _on_gui_input(event: InputEvent):
	if not waiting_for_key:
		return
	
	if event is InputEventKey and event.pressed:
		key_selected.emit(event.keycode)
		hide()

func _notification(what):
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		if not visible:
			waiting_for_key = false
```

### 3. 插件注册

```gdscript
# 文件：addons/fuse/plugin.gd（修改现有文件）
@tool
extends EditorPlugin


var input_key_inspector_plugin

func _enter_tree():
	# 现有代码...
	
	# 添加输入按键选择器插件
	input_key_inspector_plugin = InputKeyInspectorPlugin.new()
	add_inspector_plugin(input_key_inspector_plugin)

func _exit_tree():
	# 现有代码...
	
	# 移除输入按键选择器插件
	if input_key_inspector_plugin:
		remove_inspector_plugin(input_key_inspector_plugin)
		input_key_inspector_plugin = null
```

## 使用示例

### 1. 在代码中创建事件

```gdscript
# 创建按键按下事件
var key_press_event = OnInputKey.new()
key_press_event.key_code = KEY_SPACE
key_press_event.key_event_type = 0  # 按下
key_press_event.trigger_once = true

# 创建按键释放事件
var key_release_event = OnInputKey.new()
key_release_event.key_code = KEY_ESCAPE
key_release_event.key_event_type = 1  # 释放
key_release_event.trigger_once = false

# 创建持续按下事件
var key_held_event = OnInputKey.new()
key_held_event.key_code = KEY_R
key_held_event.key_event_type = 2  # 持续按下
key_held_event.held_initial_delay = 0.5
key_held_event.held_repeat_interval = 0.1
```

### 2. 在编辑器中配置事件

1. 创建或选择一个 Trigger 节点
2. 在 Inspector 中添加 OnInputKey 事件
3. 点击"选择按键"按钮，打开按键选择对话框
4. 按下任意键进行选择
5. 配置事件类型和相关参数
6. 保存场景，事件将在运行时自动初始化

### 3. 与动作系统结合使用

```gdscript
# 在 Trigger 的配置中
@onready var trigger = $Trigger

func _ready():
	# 创建按键事件
	var jump_event = OnInputKey.new()
	jump_event.key_code = KEY_SPACE
	jump_event.key_event_type = 0  # 按下
	
	# 创建动作
	var jump_action = JumpAction.new()
	
	# 配置触发器
	trigger.events = [jump_event]
	trigger.action_runner = ActionRunner.new()
	trigger.action_runner.actions = [jump_action]
```

## 测试和验证

### 1. 单元测试

```gdscript
# 测试按键事件初始化
func test_event_initialization():
	var event = OnInputKey.new()
	var test_node = Node.new()
	
	# 测试正常初始化
	event.key_code = KEY_SPACE
	event.initialize(test_node)
	assert(event._owner_node != null)
	
	# 测试清理
	event.terminate(test_node)
	assert(event._owner_node == null)

# 测试按键事件触发
func test_event_triggering():
	var event = OnInputKey.new()
	var test_node = Node.new()
	
	event.key_code = KEY_SPACE
	event.key_event_type = 0
	event.initialize(test_node)
	
	# 模拟按键事件
	var input_event = InputEventKey.new()
	input_event.keycode = KEY_SPACE
	input_event.pressed = true
	
	# 验证事件是否触发
	# 这里需要连接 triggered 信号进行验证
	
	event.terminate(test_node)
```

### 2. 集成测试

```gdscript
# 在实际场景中测试按键事件
func test_key_event_in_scene():
	# 创建测试场景
	var scene = PackedScene.new()
	# 添加必要的节点和事件配置
	
	# 运行场景并验证按键事件行为
```

## 性能考虑

1. **输入处理频率**：持续按下事件的重复间隔不应设置过小，建议最小值为 0.05 秒
2. **内存管理**：确保在不需要时正确清理定时器和信号连接
3. **事件过滤**：在输入处理函数中尽早过滤不相关的事件，减少不必要的处理
4. **状态缓存**：缓存按键状态，避免重复计算

## 故障排除

### 常见问题

1. **按键事件不触发**
   - 检查按键代码是否正确设置
   - 确认事件类型配置正确
   - 验证 Trigger 节点是否正确初始化

2. **持续按下事件重复过快**
   - 检查 held_repeat_interval 值是否过小
   - 考虑增加 held_initial_delay 值

3. **编辑器中按键选择不工作**
   - 确认编辑器插件正确注册
   - 检查插件文件路径是否正确

4. **运行时错误**
   - 检查日志输出，确认错误类型
   - 验证事件配置是否通过 validate() 检查

## 总结

OnInputKey 事件设计提供了一个完整的键盘输入监听解决方案，具有以下特点：

### 核心优势

1. **三种事件类型支持**：按下、释放和持续按下，满足不同的游戏需求
2. **直观的编辑器界面**：通过按键选择对话框，用户可以轻松配置要监听的按键
3. **条件化属性显示**：根据事件类型自动显示或隐藏相关参数，提供清晰的用户体验
4. **健壮的状态管理**：正确处理按键状态，避免重复触发和内存泄漏
5. **完整的生命周期管理**：从初始化到清理的全过程都有适当的处理

### 技术亮点

1. **输入处理优化**：使用 `unhandled_key_input` 避免重复处理，并通过 `set_input_as_handled()` 防止事件冲突
2. **定时器管理**：安全的定时器创建和清理机制，避免内存泄漏
3. **状态重置机制**：按键释放后正确重置触发状态，确保下次按键能正常触发
4. **参数验证**：完整的配置验证系统，帮助用户在运行前发现问题

### 扩展性

设计考虑了未来的扩展需求：
- 多键组合支持
- 修饰键支持
- 鼠标和手柄事件扩展
- 与 Godot 输入映射系统集成

### 最佳实践遵循

该设计完全遵循了 Fuse 事件系统的最佳实践：
- 正确实现 `initialize()` 和 `terminate()` 方法
- 使用统一的错误处理机制
- 提供清晰的日志记录
- 实现直观的资源名称更新
- 包含完整的验证机制

通过这个设计，开发者可以轻松创建响应键盘输入的游戏逻辑，而无需处理复杂的输入管理细节。事件系统的模块化设计确保了代码的可维护性和可扩展性。