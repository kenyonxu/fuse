> 🌐 [**中文版**](../../../zh_CN/system_docs/architecture/event_on_input_key_design.md) | English

# OnInputKey Event Design Document

**Document version**: 1.0
**Created**: 2024-12-10
**Status**: ✅ Implemented
**Last updated**: 2026-01-25
**Actual implementation**: `addons/fuse/events/on_input_key.gd`

## Overview

`OnInputKey` is a custom event class that listens for user keyboard input and triggers the corresponding events. It supports three key types: pressed, released, and held. Users can pick the key to listen for through the editor UI and configure the related parameters.

## Core Feature Design

### 1. Event Type Support

Three keyboard event types are supported:

- **Pressed event**: Triggered once when a key is pressed
- **Released event**: Triggered once when a key is released
- **Held event**: Triggered repeatedly at the configured interval while a key is held down

### 2. Configuration Parameters

```gdscript
## The key code to listen for
@export var key_code: int = KEY_NONE:
    set(value):
        if key_code != value:
            key_code = value
            _update_resource_name()
            notify_property_list_changed()  # Trigger inspector update

## The key event type
@export_enum("按下:0", "释放:1", "持续按下:2") var key_event_type: int = 0:
    set(value):
        if key_event_type != value:
            key_event_type = value
            _update_resource_name()
            notify_property_list_changed()  # Trigger inspector update

## Initial delay for held events (seconds)
@export var held_initial_delay: float = 1.0:
    set(value):
        if held_initial_delay != value:
            held_initial_delay = value
            _update_resource_name()
            notify_property_list_changed()  # Trigger inspector update

## Repeat interval for held events (seconds)
@export var held_repeat_interval: float = 0.2:
    set(value):
        if held_repeat_interval != value:
            held_repeat_interval = value
            _update_resource_name()
            notify_property_list_changed()  # Trigger inspector update

## Whether to trigger only once (valid only for pressed and released)
@export var trigger_once: bool = false:
    set(value):
        if trigger_once != value:
            trigger_once = value
            _update_resource_name()
            notify_property_list_changed()  # Trigger inspector update

## Custom key name (for display)
@export var custom_key_name: String = "":
    set(value):
        if custom_key_name != value:
            custom_key_name = value
            _update_resource_name()
            notify_property_list_changed()  # Trigger inspector update
```

### 3. Internal State Management

```gdscript
# Internal state variables
var _is_key_pressed: bool = false
var _has_triggered: bool = false
var _held_timer: Timer = null
var _owner_node: Node = null

# Implement conditional inspector display (using the _validate_property method)
func _validate_property(property: Dictionary) -> void:
    # When the key event type is not held, disable the held-related properties
    if key_event_type != 2:  # Not a held event
        if property.name == "held_initial_delay" or property.name == "held_repeat_interval":
            property.usage = PROPERTY_USAGE_READ_ONLY
    
    # When the key event type is held, disable the trigger_once property
    if key_event_type == 2:  # Held event
        if property.name == "trigger_once":
            property.usage = PROPERTY_USAGE_READ_ONLY
```

## Conditional Property Display Design

To provide a better user experience, OnInputKey implements conditional property display, automatically showing or hiding related parameters based on the key event type.

### 1. Design Rationale

Following the `set_with_another_variable` pattern from `SetIntVariable`, it uses Godot's `_validate_property()` method to implement dynamic property display control.

### 2. Implementation Mechanism

```gdscript
# Implement conditional inspector display (using the _validate_property method)
func _validate_property(property: Dictionary) -> void:
    # When the key event type is not held, disable the held-related properties
    if key_event_type != 2:  # Not a held event
        if property.name == "held_initial_delay" or property.name == "held_repeat_interval":
            property.usage = PROPERTY_USAGE_READ_ONLY
    
    # When the key event type is held, disable the trigger_once property
    if key_event_type == 2:  # Held event
        if property.name == "trigger_once":
            property.usage = PROPERTY_USAGE_READ_ONLY
```

### 3. Property Display Rules

| Key event type | held_initial_delay | held_repeat_interval | trigger_once |
|---------------|-------------------|---------------------|--------------|
| Pressed (0)   | Hidden            | Hidden              | Shown        |
| Released (1)  | Hidden            | Hidden              | Shown        |
| Held (2)      | Shown             | Shown               | Hidden       |

### 4. User Experience Improvements

1. **Instant feedback**: When the user switches the event type, related properties are shown or hidden immediately
2. **Visual cue**: Hidden properties appear read-only in the Inspector, providing clear visual feedback
3. **State retention**: When switching event types, already-set parameter values are preserved, making it easy to switch back

### 5. Technical Details

- Uses `notify_property_list_changed()` to trigger Inspector updates
- Calls the update from each property's setter to keep state in sync
- Uses `PROPERTY_USAGE_READ_ONLY` instead of fully hiding properties, keeping the UI consistent

## Expert Review and Key Fixes

The expert review uncovered the following key issues, all of which have been fixed:

### 🔴 Critical Issues (Fixed)

#### 1. Duplicate Input Event Handling
**Problem**: Connecting both `input` and `unhandled_key_input` caused events to be processed twice
**Fix**: Keep only `unhandled_key_input` and add event-handled marking

```gdscript
# Before the fix (buggy)
_owner_node.input.connect(_on_input)
_owner_node.unhandled_key_input.connect(_on_unhandled_key_input)

# After the fix (correct)
_owner_node.set_process_unhandled_key_input(true)
if not _owner_node.unhandled_key_input.is_connected(_on_unhandled_key_input):
    _owner_node.unhandled_key_input.connect(_on_unhandled_key_input)

func _on_unhandled_key_input(event: InputEvent):
    # Mark the event as handled to prevent other nodes from processing it
    if event is InputEventKey and event.keycode == key_code:
        get_viewport().set_input_as_handled()
    _on_input(event)
```

#### 2. Timer Bug in the Held Logic
**Problem**: The `trigger_once` parameter affected repeated triggering of held events
**Fix**: Held events are exempt from the `trigger_once` restriction, and state is reset correctly

```gdscript
# Before the fix (logic error)
if not trigger_once or not _has_triggered:
    _has_triggered = true
    triggered.emit()

# After the fix (correct)
# Held events are exempt from the trigger_once restriction
_log_info("触发持续按下事件: %s" % _get_key_name())
triggered.emit(_owner_node)
```

#### 3. Incomplete State Management
**Problem**: The `_has_triggered` state was not reset after the key was released
**Fix**: Reset the trigger state in the key-released event

```gdscript
# After the fix (state reset added)
func _handle_key_released():
    # ... existing code ...
    _has_triggered = true
    _log_info("触发按键释放事件: %s" % _get_key_name())
    triggered.emit(_owner_node)
    
    # Reset the trigger state after key release so the next press can trigger again
    _has_triggered = false
```

#### 4. Memory Leak Risk
**Problem**: The timer was not stopped before being removed
**Fix**: Call `stop()` before `queue_free()`

```gdscript
# After the fix (correct cleanup)
func _cleanup_held_timer():
    if _held_timer:
        _held_timer.stop()  # Stop the timer first
        if _held_timer.timeout.is_connected(_on_held_timer_timeout):
            _held_timer.timeout.disconnect(_on_held_timer_timeout)
        if _owner_node and is_instance_valid(_owner_node):
            _owner_node.remove_child(_held_timer)
        _held_timer.queue_free()
        _held_timer = null
```

### 🟡 Design Improvements (Recommended)

#### 1. API Design Not Idiomatic Godot Style
**Problem**: Uses a string enum instead of a type-safe enum
**Recommendation**: Use Godot 4's `enum` feature

```gdscript
# Current (not recommended)
@export_enum("按下:0", "释放:1", "持续按下:2") var key_event_type: int = 0

# Recommended (type-safe)
enum KeyEventType { PRESSED, RELEASED, HELD }
@export var key_event_type: KeyEventType = KeyEventType.PRESSED
```

#### 2. Editor Plugin Missing State Sync
**Problem**: `InputKeySelector` lacks a `_update_property` implementation
**Recommendation**: Fully implement the property sync method

```gdscript
# Suggested addition
func _update_property():
    var object = get_edited_object()
    if object and object.has_method("get"):
        current_key_code = object.get(get_edited_property())
        var key_name = OS.get_scancode_string(current_key_code)
        property_control.text = "按键: " + key_name
```

#### 3. Performance Optimization Suggestions
**Problem**: Every event instance creates its own Timer
**Recommendation**: Use a singleton Timer manager or frame counting

#### 4. Missing Input Priority Control
**Problem**: Cannot handle priority when multiple events listen to the same key
**Recommendation**: Add a `priority` property

### 📋 Key Fix Checklist

✅ **Core issues fixed:**
- [x] Removed the duplicate input processing connection
- [x] Fixed the trigger_once logic for held events
- [x] Added state reset after key release
- [x] Fixed the timer memory leak
- [x] Added event-handled marking to prevent duplicate processing

### 🧪 Test Verification Points

1. **Key press event**: Triggers only once when `trigger_once=true`
2. **Held event**: Pressing again after release resets and triggers correctly
3. **Multiple listeners**: Multiple events on the same key do not interfere with each other
4. **Memory management**: Timers and signal connections are cleaned up correctly when the scene unloads
5. **Performance test**: Performance with 100 held events running simultaneously

## Key Selection UI Design

### 1. Editor Plugin Integration

Create a custom Inspector plugin to provide key selection in the editor:

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

### 2. Key Selection Dialog

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

## Key Listening and Event Triggering Mechanism

### 1. Initialization Flow

```gdscript
func initialize(owner_node: Node) -> void:
    _log_debug("初始化 OnInputKey")
    
    # Validate owner_node
    if not owner_node:
        _create_fuse_error("Owner 节点为空", FuseError.ErrorType.CONFIGURATION_ERROR)
        return
    
    _owner_node = owner_node
    
    # Validate the key code
    if key_code == KEY_NONE:
        _create_fuse_error("未指定有效的按键代码", FuseError.ErrorType.CONFIGURATION_ERROR)
        return
    
    # Connect input handling
    if not owner_node.tree_entered.is_connected(_on_tree_entered):
        owner_node.tree_entered.connect(_on_tree_entered)
    
    # If already in the scene tree, set up input processing immediately
    if owner_node.is_inside_tree():
        _setup_input_processing()
    
    _log_debug("OnInputKey 初始化完成: %s" % get_description())
```

### 2. Input Processing Setup

```gdscript
func _setup_input_processing():
    if not _owner_node:
        return
    
    # Make sure the node can process input
    _owner_node.set_process_unhandled_key_input(true)
    
    # Connect only unhandled_key_input to avoid duplicate processing
    if not _owner_node.unhandled_key_input.is_connected(_on_unhandled_key_input):
        _owner_node.unhandled_key_input.connect(_on_unhandled_key_input)

func _on_tree_entered():
    _setup_input_processing()
```

### 3. Key Event Handling

```gdscript
func _on_input(event: InputEvent):
    if not event is InputEventKey:
        return
    
    if event.keycode != key_code:
        return
    
    match key_event_type:
        0:  # Pressed
            if event.pressed and not event.is_echo():
                _handle_key_pressed()
        1:  # Released
            if not event.pressed:
                _handle_key_released()
        2:  # Held
            if event.pressed:
                if not event.is_echo():
                    _handle_key_held_start()
            else:
                _handle_key_held_end()

func _on_unhandled_key_input(event: InputEvent):
    # Mark the event as handled to prevent other nodes from processing it
    if event is InputEventKey and event.keycode == key_code:
        get_viewport().set_input_as_handled()
    _on_input(event)
```

### 4. Event Triggering Logic

```gdscript
func _handle_key_pressed():
    _log_debug("按键按下: %s" % _get_key_name())
    
    # Check whether it should trigger only once
    if trigger_once and _has_triggered:
        _log_debug("已触发过，跳过")
        return
    
    _has_triggered = true
    _log_info("触发按键按下事件: %s" % _get_key_name())
    triggered.emit(_owner_node)

func _handle_key_released():
    _log_debug("按键释放: %s" % _get_key_name())
    
    # Check whether it should trigger only once
    if trigger_once and _has_triggered:
        _log_debug("已触发过，跳过")
        return
    
    _has_triggered = true
    _log_info("触发按键释放事件: %s" % _get_key_name())
    triggered.emit(_owner_node)
    
    # Reset the trigger state after key release so the next press can trigger again
    _has_triggered = false

func _handle_key_held_start():
    if _is_key_pressed:
        return  # Already in the pressed state
    
    _is_key_pressed = true
    _log_debug("开始持续按下: %s" % _get_key_name())
    
    # Create the timer
    _create_held_timer()
    
    # Trigger once immediately (held events are exempt from the trigger_once restriction)
    _log_info("触发持续按下事件: %s" % _get_key_name())
    triggered.emit(_owner_node)

func _handle_key_held_end():
    if not _is_key_pressed:
        return
    
    _is_key_pressed = false
    _log_debug("结束持续按下: %s" % _get_key_name())
    
    # Clean up the timer
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
    
    # Update the timer wait time to the repeat interval
    if _held_timer.wait_time != held_repeat_interval:
        _held_timer.wait_time = held_repeat_interval
    
    # Trigger the event
    _log_info("触发持续按下重复事件: %s" % _get_key_name())
    triggered.emit(_owner_node)

func _cleanup_held_timer():
    if _held_timer:
        # Stop the timer first
        _held_timer.stop()
        
        if _held_timer.timeout.is_connected(_on_held_timer_timeout):
            _held_timer.timeout.disconnect(_on_held_timer_timeout)
        
        if _owner_node and is_instance_valid(_owner_node):
            _owner_node.remove_child(_held_timer)
        
        _held_timer.queue_free()
        _held_timer = null
```

## Resource Name Update Logic

```gdscript
func _update_resource_name():
    var key_name = _get_key_name()
    var event_type_name = _get_event_type_name()
    var once_text = trigger_once ? " [仅一次]" : ""
    
    match key_event_type:
        0:  # Pressed
            resource_name = "按键按下: %s%s" % [key_name, once_text]
        1:  # Released
            resource_name = "按键释放: %s%s" % [key_name, once_text]
        2:  # Held
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

## Validation and Error Handling Mechanism

```gdscript
func validate() -> Array[String]:
    var errors: Array[String] = []
    
    # Validate the key code
    if key_code == KEY_NONE:
        errors.append("必须指定有效的按键代码")
    
    # Validate the held parameters
    if key_event_type == 2:  # Held
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
        0:  # Pressed
            var once_text = trigger_once ? " (仅一次)" : ""
            return "当按下 %s 键时触发%s" % [key_name, once_text]
        1:  # Released
            var once_text = trigger_once ? " (仅一次)" : ""
            return "当释放 %s 键时触发%s" % [key_name, once_text]
        2:  # Held
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

## Lifecycle Management

```gdscript
func terminate(owner_node: Node) -> void:
    _log_debug("清理 OnInputKey")
    
    # Disconnect the signal connections
    if owner_node:
        if owner_node.tree_entered.is_connected(_on_tree_entered):
            owner_node.tree_entered.disconnect(_on_tree_entered)
        
        if owner_node.input.is_connected(_on_input):
            owner_node.input.disconnect(_on_input)
        
        if owner_node.unhandled_key_input.is_connected(_on_unhandled_key_input):
            owner_node.unhandled_key_input.disconnect(_on_unhandled_key_input)
    
    # Clean up the timer
    _cleanup_held_timer()
    
    # Reset the state
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

## Editor Plugin Registration

### 1. Plugin Main File Registration

Per the project's plugin architecture, the following classes should be registered in `addons/fuse/plugin.gd`:

```gdscript
# Add inside the _enter_tree() method of addons/fuse/plugin.gd:

# Register the key-selection editor classes
add_custom_type("InputKeySelector", "EditorProperty", preload("res://addons/fuse/editor/input_key_selector.gd"), preload("res://icon.svg"))
add_custom_type("InputKeyDialog", "AcceptDialog", preload("res://addons/fuse/editor/input_key_dialog.gd"), preload("res://icon.svg"))
add_custom_type("InputKeyInspectorPlugin", "EditorInspectorPlugin", preload("res://addons/fuse/editor/input_key_inspector_plugin.gd"), preload("res://icon.svg"))

# Register the Inspector plugin instance
var input_key_inspector = preload("res://addons/fuse/editor/input_key_inspector_plugin.gd").new()
add_inspector_plugin(input_key_inspector)
```

### 2. Inspector Plugin Implementation

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

### 3. Classes to Register

| Class | Type | File path | Needs registration |
|------|------|----------|--------------|
| OnInputKey | Resource | addons/fuse/events/on_input_key.gd | ✅ Yes |
| InputKeySelector | EditorProperty | addons/fuse/editor/input_key_selector.gd | ✅ Yes |
| InputKeyDialog | AcceptDialog | addons/fuse/editor/input_key_dialog.gd | ✅ Yes |
| InputKeyInspectorPlugin | EditorInspectorPlugin | addons/fuse/editor/input_key_inspector_plugin.gd | ✅ Yes |

### 4. Plugin Cleanup

Add the following in the `_exit_tree()` method of `addons/fuse/plugin.gd`:

```gdscript
# Clean up the OnInputKey-related classes
remove_custom_type("OnInputKey")
remove_custom_type("InputKeySelector")
remove_custom_type("InputKeyDialog")
remove_custom_type("InputKeyInspectorPlugin")

# Remove the Inspector plugin
if input_key_inspector:
    remove_inspector_plugin(input_key_inspector)
    input_key_inspector = null
```

## Usage Examples

```gdscript
# Create the event
var key_event = OnInputKey.new()

# Configure a pressed event for the Space key
key_event.key_code = KEY_SPACE
key_event.key_event_type = 0  # Pressed
key_event.trigger_once = true

# Configure a held event
key_event.key_code = KEY_R
key_event.key_event_type = 2  # Held
key_event.held_initial_delay = 0.5
key_event.held_repeat_interval = 0.1
```

## Best Practice Recommendations

1. **Performance**: Avoid setting a repeat interval that is too small; it can cause performance issues
2. **Key conflicts**: Avoid having multiple events listen to the same key; it can cause unexpected behavior
3. **State management**: Use the trigger_once parameter judiciously to avoid duplicate triggering
4. **Error handling**: Always check validation results to make sure the configuration is correct
5. **Resource cleanup**: Make sure to terminate events properly when no longer needed, releasing resources

## Extension Possibilities

1. **Multi-key combos**: Support combo events where multiple keys are pressed together
2. **Modifier keys**: Support modifiers such as Ctrl, Alt, and Shift
3. **Mouse events**: Extend support to mouse buttons and the scroll wheel
4. **Gamepad support**: Extend support to gamepad button events
5. **Input map integration**: Integrate with Godot's input map system

## Full Implementation Example

### 1. OnInputKey Main Class Implementation

```gdscript
# File: addons/fuse/events/on_input_key.gd
@tool
class_name OnInputKey extends BaseEvent

## The key code to listen for
@export var key_code: int = KEY_NONE:
	set(value):
		if key_code != value:
			key_code = value
			_update_resource_name()
			notify_property_list_changed()  # Trigger inspector update

## The key event type
@export_enum("按下:0", "释放:1", "持续按下:2") var key_event_type: int = 0:
	set(value):
		if key_event_type != value:
			key_event_type = value
			_update_resource_name()
			notify_property_list_changed()  # Trigger inspector update

## Initial delay for held events (seconds)
@export var held_initial_delay: float = 1.0:
	set(value):
		if held_initial_delay != value:
			held_initial_delay = value
			_update_resource_name()
			notify_property_list_changed()  # Trigger inspector update

## Repeat interval for held events (seconds)
@export var held_repeat_interval: float = 0.2:
	set(value):
		if held_repeat_interval != value:
			held_repeat_interval = value
			_update_resource_name()
			notify_property_list_changed()  # Trigger inspector update

## Whether to trigger only once (valid only for pressed and released)
@export var trigger_once: bool = false:
	set(value):
		if trigger_once != value:
			trigger_once = value
			_update_resource_name()
			notify_property_list_changed()  # Trigger inspector update

## Custom key name (for display)
@export var custom_key_name: String = "":
	set(value):
		if custom_key_name != value:
			custom_key_name = value
			_update_resource_name()
			notify_property_list_changed()  # Trigger inspector update

# Internal state variables
var _is_key_pressed: bool = false
var _has_triggered: bool = false
var _held_timer: Timer = null
var _owner_node: Node = null

# Implement conditional inspector display (using the _validate_property method)
func _validate_property(property: Dictionary) -> void:
	# When the key event type is not held, disable the held-related properties
	if key_event_type != 2:  # Not a held event
		if property.name == "held_initial_delay" or property.name == "held_repeat_interval":
			property.usage = PROPERTY_USAGE_READ_ONLY
	
	# When the key event type is held, disable the trigger_once property
	if key_event_type == 2:  # Held event
		if property.name == "trigger_once":
			property.usage = PROPERTY_USAGE_READ_ONLY

# Update the name shown in the list based on the property settings
func _update_resource_name():
	var key_name = _get_key_name()
	
	match key_event_type:
		0:  # Pressed
			var once_text = trigger_once ? " [仅一次]" : ""
			resource_name = "按键按下: %s%s" % [key_name, once_text]
		1:  # Released
			var once_text = trigger_once ? " [仅一次]" : ""
			resource_name = "按键释放: %s%s" % [key_name, once_text]
		2:  # Held
			var delay_text = " (延迟:%.1fs, 间隔:%.1fs)" % [held_initial_delay, held_repeat_interval]
			resource_name = "按键持续按下: %s%s" % [key_name, delay_text]

func initialize(owner_node: Node) -> void:
	_log_debug("初始化 OnInputKey")
	
	# Validate owner_node
	if not owner_node:
		_create_fuse_error("Owner 节点为空", FuseError.ErrorType.CONFIGURATION_ERROR)
		return
	
	_owner_node = owner_node
	
	# Validate the key code
	if key_code == KEY_NONE:
		_create_fuse_error("未指定有效的按键代码", FuseError.ErrorType.CONFIGURATION_ERROR)
		return
	
	# Connect input handling
	if not owner_node.tree_entered.is_connected(_on_tree_entered):
		owner_node.tree_entered.connect(_on_tree_entered)
	
	# If already in the scene tree, set up input processing immediately
	if owner_node.is_inside_tree():
		_setup_input_processing()
	
	_log_debug("OnInputKey 初始化完成: %s" % get_description())

func terminate(owner_node: Node) -> void:
	_log_debug("清理 OnInputKey")
	
	# Disconnect the signal connections
	if owner_node:
		if owner_node.tree_entered.is_connected(_on_tree_entered):
			owner_node.tree_entered.disconnect(_on_tree_entered)
		
		if owner_node.unhandled_key_input.is_connected(_on_unhandled_key_input):
			owner_node.unhandled_key_input.disconnect(_on_unhandled_key_input)
	
	# Clean up the timer
	_cleanup_held_timer()
	
	# Reset the state
	_is_key_pressed = false
	_has_triggered = false
	_owner_node = null
	
	_log_debug("OnInputKey 清理完成")

func _setup_input_processing():
	if not _owner_node:
		return
	
	# Make sure the node can process unhandled key input
	_owner_node.set_process_unhandled_key_input(true)
	
	# Connect only unhandled_key_input to avoid duplicate processing
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
		0:  # Pressed
			if event.pressed and not event.is_echo():
				_handle_key_pressed()
		1:  # Released
			if not event.pressed:
				_handle_key_released()
		2:  # Held
			if event.pressed:
				if not event.is_echo():
					_handle_key_held_start()
			else:
				_handle_key_held_end()

func _on_unhandled_key_input(event: InputEvent):
	# Mark the event as handled to prevent other nodes from processing it
	if event is InputEventKey and event.keycode == key_code:
		get_viewport().set_input_as_handled()
	_on_input(event)

func _handle_key_pressed():
	_log_debug("按键按下: %s" % _get_key_name())
	
	# Check whether it should trigger only once
	if trigger_once and _has_triggered:
		_log_debug("已触发过，跳过")
		return
	
	_has_triggered = true
	_log_info("触发按键按下事件: %s" % _get_key_name())
	triggered.emit(_owner_node)

func _handle_key_released():
	_log_debug("按键释放: %s" % _get_key_name())
	
	# Check whether it should trigger only once
	if trigger_once and _has_triggered:
		_log_debug("已触发过，跳过")
		return
	
	_has_triggered = true
	_log_info("触发按键释放事件: %s" % _get_key_name())
	triggered.emit(_owner_node)
	
	# Reset the trigger state after key release so the next press can trigger again
	_has_triggered = false

func _handle_key_held_start():
	if _is_key_pressed:
		return  # Already in the pressed state
	
	_is_key_pressed = true
	_log_debug("开始持续按下: %s" % _get_key_name())
	
	# Create the timer
	_create_held_timer()
	
	# Trigger once immediately (held events are exempt from the trigger_once restriction)
	_log_info("触发持续按下事件: %s" % _get_key_name())
	triggered.emit(_owner_node)

func _handle_key_held_end():
	if not _is_key_pressed:
		return
	
	_is_key_pressed = false
	_log_debug("结束持续按下: %s" % _get_key_name())
	
	# Clean up the timer
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
	
	# Update the timer wait time to the repeat interval
	if _held_timer.wait_time != held_repeat_interval:
		_held_timer.wait_time = held_repeat_interval
	
	# Trigger the event
	_log_info("触发持续按下重复事件: %s" % _get_key_name())
	triggered.emit(_owner_node)

func _cleanup_held_timer():
	if _held_timer:
		# Stop the timer first
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
		0:  # Pressed
			var once_text = trigger_once ? " (仅一次)" : ""
			return "当按下 %s 键时触发%s" % [key_name, once_text]
		1:  # Released
			var once_text = trigger_once ? " (仅一次)" : ""
			return "当释放 %s 键时触发%s" % [key_name, once_text]
		2:  # Held
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
	
	# Validate the key code
	if key_code == KEY_NONE:
		errors.append("必须指定有效的按键代码")
	
	# Validate the held parameters
	if key_event_type == 2:  # Held
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

## Unified logging methods
func _log_debug(message: String) -> void:
	FuseLogger.log_debug("OnInputKey", log_level, message)

func _log_info(message: String) -> void:
	FuseLogger.log_info("OnInputKey", log_level, message)

func _log_warning(message: String) -> void:
	FuseLogger.log_warning("OnInputKey", log_level, message)

func _log_error(message: String) -> void:
	FuseLogger.log_error("OnInputKey", log_level, message)
```

### 2. Editor Plugin Implementation

```gdscript
# File: addons/fuse/editor/input_key_selector/input_key_inspector_plugin.gd
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
# File: addons/fuse/editor/input_key_selector/input_key_selector.gd
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
# File: addons/fuse/editor/input_key_selector/input_key_dialog.gd
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

### 3. Plugin Registration

```gdscript
# File: addons/fuse/plugin.gd (modify the existing file)
@tool
extends EditorPlugin


var input_key_inspector_plugin

func _enter_tree():
	# Existing code...
	
	# Add the input key selector plugin
	input_key_inspector_plugin = InputKeyInspectorPlugin.new()
	add_inspector_plugin(input_key_inspector_plugin)

func _exit_tree():
	# Existing code...
	
	# Remove the input key selector plugin
	if input_key_inspector_plugin:
		remove_inspector_plugin(input_key_inspector_plugin)
		input_key_inspector_plugin = null
```

## Usage Examples

### 1. Creating Events in Code

```gdscript
# Create a key press event
var key_press_event = OnInputKey.new()
key_press_event.key_code = KEY_SPACE
key_press_event.key_event_type = 0  # Pressed
key_press_event.trigger_once = true

# Create a key release event
var key_release_event = OnInputKey.new()
key_release_event.key_code = KEY_ESCAPE
key_release_event.key_event_type = 1  # Released
key_release_event.trigger_once = false

# Create a held event
var key_held_event = OnInputKey.new()
key_held_event.key_code = KEY_R
key_held_event.key_event_type = 2  # Held
key_held_event.held_initial_delay = 0.5
key_held_event.held_repeat_interval = 0.1
```

### 2. Configuring Events in the Editor

1. Create or select a Trigger node
2. Add an OnInputKey event in the Inspector
3. Click the "Select Key" button to open the key selection dialog
4. Press any key to select it
5. Configure the event type and related parameters
6. Save the scene; the event will be initialized automatically at runtime

### 3. Combining with the Action System

```gdscript
# In the Trigger's configuration
@onready var trigger = $Trigger

func _ready():
	# Create the key event
	var jump_event = OnInputKey.new()
	jump_event.key_code = KEY_SPACE
	jump_event.key_event_type = 0  # Pressed
	
	# Create the action
	var jump_action = JumpAction.new()
	
	# Configure the trigger
	trigger.events = [jump_event]
	trigger.action_runner = ActionRunner.new()
	trigger.action_runner.actions = [jump_action]
```

## Testing and Validation

### 1. Unit Tests

```gdscript
# Test event initialization
func test_event_initialization():
	var event = OnInputKey.new()
	var test_node = Node.new()
	
	# Test normal initialization
	event.key_code = KEY_SPACE
	event.initialize(test_node)
	assert(event._owner_node != null)
	
	# Test cleanup
	event.terminate(test_node)
	assert(event._owner_node == null)

# Test event triggering
func test_event_triggering():
	var event = OnInputKey.new()
	var test_node = Node.new()
	
	event.key_code = KEY_SPACE
	event.key_event_type = 0
	event.initialize(test_node)
	
	# Simulate a key event
	var input_event = InputEventKey.new()
	input_event.keycode = KEY_SPACE
	input_event.pressed = true
	
	# Verify that the event is triggered
	# Connect the triggered signal here for verification
	
	event.terminate(test_node)
```

### 2. Integration Tests

```gdscript
# Test the key event in a real scene
func test_key_event_in_scene():
	# Create the test scene
	var scene = PackedScene.new()
	# Add the required nodes and event configuration
	
	# Run the scene and verify the key event behavior
```

## Performance Considerations

1. **Input processing frequency**: The repeat interval of held events should not be too small; the recommended minimum is 0.05 seconds
2. **Memory management**: Make sure timers and signal connections are cleaned up correctly when no longer needed
3. **Event filtering**: Filter out irrelevant events early in the input handling functions to reduce unnecessary processing
4. **State caching**: Cache the key state to avoid repeated computation

## Troubleshooting

### Common Issues

1. **Key event does not trigger**
   - Check that the key code is set correctly
   - Confirm the event type is configured correctly
   - Verify that the Trigger node is initialized correctly

2. **Held event repeats too fast**
   - Check whether held_repeat_interval is too small
   - Consider increasing held_initial_delay

3. **Key selection does not work in the editor**
   - Confirm the editor plugin is registered correctly
   - Check that the plugin file paths are correct

4. **Runtime errors**
   - Check the log output to identify the error type
   - Verify the event configuration passes the validate() check

## Summary

The OnInputKey event design provides a complete keyboard input listening solution with the following characteristics:

### Core Strengths

1. **Three event types**: Pressed, released, and held, covering different gameplay needs
2. **Intuitive editor UI**: Through the key selection dialog, users can easily configure the key to listen for
3. **Conditional property display**: Related parameters are shown or hidden automatically based on the event type, for a clear user experience
4. **Robust state management**: Key state is handled correctly, avoiding duplicate triggering and memory leaks
5. **Complete lifecycle management**: The whole flow from initialization to cleanup is properly handled

### Technical Highlights

1. **Optimized input handling**: Uses `unhandled_key_input` to avoid duplicate processing and `set_input_as_handled()` to prevent event conflicts
2. **Timer management**: Safe timer creation and cleanup to avoid memory leaks
3. **State reset mechanism**: The trigger state is reset correctly after key release, ensuring the next press triggers normally
4. **Parameter validation**: A complete configuration validation system helps users catch issues before running

### Extensibility

The design accounts for future extension needs:
- Multi-key combo support
- Modifier key support
- Mouse and gamepad event extensions
- Integration with the Godot input map system

### Best Practices Followed

The design fully follows the best practices of the Fuse event system:
- Correctly implements the `initialize()` and `terminate()` methods
- Uses the unified error handling mechanism
- Provides clear logging
- Implements intuitive resource name updates
- Includes complete validation

With this design, developers can easily create gameplay logic that responds to keyboard input without dealing with complex input management details. The event system's modular design ensures the code remains maintainable and extensible.
