> 🌐 [**中文版**](../../../zh_CN/dev_docs/guides/conditional-property-display-guide.md) | English

# Implementing Conditional Property Display in Godot

## Overview

This guide describes in detail the complete approach to implementing conditional property display in Godot, with a focus on custom Instruction classes in the Fuse Visual Programming system. By using the `_validate_property()` method, you can create a dynamic editor interface that shows or disables related properties based on the user's choices.

## Table of Contents

1. [Background and Problem](#background-and-problem)
2. [Solution Overview](#solution-overview)
3. [Core Implementation](#core-implementation)
4. [Complete Implementation Example](#complete-implementation-example)
5. [Property Usage Flags in Detail](#property-usage-flags-in-detail)
6. [Advanced Usage](#advanced-usage)
7. [Performance Comparison](#performance-comparison)
8. [Common Issues and Solutions](#common-issues-and-solutions)
9. [Best Practices Summary](#best-practices-summary)

---

## Background and Problem

### Limitations of Traditional Approaches

To implement conditional property display in Godot, the traditional approaches include:

1. **Manual property management**: managing properties manually with the `_get()` and `_set()` methods
2. **Dynamic property lists**: generating the property list dynamically via `_get_property_list()`
3. **Inspector plugins**: building a dedicated editor plugin

These approaches have the following problems:
- High code complexity
- Large performance overhead
- Poor user experience (properties disappear entirely)
- Hard to maintain

### The Ideal Solution

Ideal conditional property display should:
- Gray out properties instead of hiding them
- Respond to user actions in real time
- Be performant
- Keep the code concise and maintainable

---

## Solution Overview

### Core Idea

Use Godot's `_validate_property()` method to validate and modify properties before they are displayed, achieving conditional display.

### Technical Advantages

1. **Better user experience**: properties are grayed out rather than disappearing, so users can see all available options
2. **Better performance**: no need to rebuild the whole property list; only the properties that need validation are validated
3. **Clearer logic**: each property's condition check is independent, easy to debug and maintain
4. **Standard practice**: uses Godot's recommended property validation method

---

## Core Implementation

### 1. Basic Structure

```gdscript
@tool
extends BaseInstruction
class_name ConditionalDisplayExample

# Base properties (always shown)
@export var target_variable: String = ""
@export var scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL

# Control property (with a setter that triggers property updates)
@export var set_with_another_variable: bool = false:
    set(value):
        if set_with_another_variable != value:
            set_with_another_variable = value
            _update_resource_name()
            notify_property_list_changed()  # triggers property validation

# Conditional properties (always exported, but disabled based on conditions)
@export var from_variable: String = ""
@export var from_variable_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL
@export var new_value: int = 0
```

### 2. Key Method Implementation

#### The `_validate_property()` Method

```gdscript
func _validate_property(property: Dictionary) -> void:
    # When set_with_another_variable = false, disable the source variable properties
    if not set_with_another_variable:
        if property.name == "from_variable":
            property.usage = property.usage | PROPERTY_USAGE_READ_ONLY
        elif property.name == "from_variable_scope":
            property.usage = property.usage | PROPERTY_USAGE_READ_ONLY

    # When set_with_another_variable = true, disable the new value property
    if set_with_another_variable:
        if property.name == "new_value":
            property.usage = property.usage | PROPERTY_USAGE_READ_ONLY
```

#### Trigger Mechanism

```gdscript
@export var set_with_another_variable: bool = false:
    set(value):
        if set_with_another_variable != value:
            set_with_another_variable = value
            _update_resource_name()
            notify_property_list_changed()  # key: triggers property validation
```

---

## Complete Implementation Example

### Complete SetIntVariableInstruction Implementation

```gdscript
@tool
extends BaseInstruction
class_name SetIntVariableInstruction

# Base properties (always shown)
@export var target_variable: String = ""
@export var scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL

# Control property (with a setter that triggers property updates)
@export var set_with_another_variable: bool = false:
    set(value):
        if set_with_another_variable != value:
            set_with_another_variable = value
            _update_resource_name()
            notify_property_list_changed()  # triggers the Inspector update

# Conditional properties (always exported, but disabled based on conditions)
@export var from_variable: String = ""
@export var from_variable_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL
@export var new_value: int = 0

# Implement conditional Inspector display
func _validate_property(property: Dictionary) -> void:
    # When set_with_another_variable = false, disable the source variable properties
    if not set_with_another_variable:
        if property.name == "from_variable":
            property.usage = property.usage | PROPERTY_USAGE_READ_ONLY
        elif property.name == "from_variable_scope":
            property.usage = property.usage | PROPERTY_USAGE_READ_ONLY

    # When set_with_another_variable = true, disable the new value property
    if set_with_another_variable:
        if property.name == "new_value":
            property.usage = property.usage | PROPERTY_USAGE_READ_ONLY

# Update the resource name to reflect the current configuration
func _update_resource_name():
    if target_variable.is_empty():
        resource_name = "设置变量: 未指定"
        return

    var operation_desc = ""
    if set_with_another_variable:
        if from_variable.is_empty():
            operation_desc = "从[未指定]复制"
        else:
            operation_desc = "从[%s]复制" % from_variable
    else:
        operation_desc = "设置为%d" % new_value

    resource_name = "设置 %s.%s %s" % [scope, target_variable, operation_desc]

# Other required methods...
func _setup_metadata():
    metadata.name = "设置整数变量"
    metadata.description = "为指定名称的变量设置整数值，支持从另一个变量复制或直接设置新值"
    metadata.category = "变量操作"
    metadata.version = "1.0"
    metadata.author = "Fuse System"

func execute(context: ExecutionContext):
    _start_execution(context)

    # Parameter validation
    if target_variable.is_empty():
        set_error("目标变量名称不能为空", FuseError.ErrorType.VALIDATION_ERROR)
        finished.emit()
        return

    # Determine the value to set
    var value_to_set: int
    if set_with_another_variable:
        # Get the value from another variable
        if from_variable.is_empty():
            set_error("源变量名称不能为空", FuseError.ErrorType.VALIDATION_ERROR)
            finished.emit()
            return

        value_to_set = _get_variable_value(context, from_variable, from_variable_scope)
        if value_to_set == null:
            set_error("无法找到源变量: %s" % from_variable, FuseError.ErrorType.VALIDATION_ERROR)
            finished.emit()
            return
    else:
        # Use the new value
        value_to_set = new_value

    # Set the target variable
    var success = _set_variable_value(context, target_variable, scope, value_to_set)
    if not success:
        set_error("无法设置变量: %s" % target_variable, FuseError.ErrorType.RUNTIME_ERROR)
        finished.emit()
        return

    # Log the success message
    var operation_type = "复制" if set_with_another_variable else "设置"
    _log_info("成功%s变量 %s 的值为 %d" % [operation_type, target_variable, value_to_set])

    _on_execution_completed()

# Helper methods...
func _get_variable_value(context: ExecutionContext, variable_name: String, variable_scope: BaseVariable.VariableScope) -> int:
    if not context:
        return 0

    var value = context.get_variable(variable_name, null)
    if value == null:
        return 0

    # Make sure it is an integer
    if typeof(value) != TYPE_INT:
        _log_warning("变量 %s 的类型不是整数，当前类型: %s" % [variable_name, typeof(value)])
        return 0

    return value

func _set_variable_value(context: ExecutionContext, variable_name: String, variable_scope: BaseVariable.VariableScope, value: int) -> bool:
    if not context:
        return false

    # Convert the enum to a string
    var scope_str = "local" if variable_scope == BaseVariable.VariableScope.LOCAL else "global"

    # Try to set the variable
    var success = context.set_variable(variable_name, value, scope_str)
    return success

func validate() -> Array[String]:
    var errors = []

    if target_variable.is_empty():
        errors.append("目标变量名称不能为空")

    if set_with_another_variable and from_variable.is_empty():
        errors.append("源变量名称不能为空")

    return errors

func get_description() -> String:
    var operation_type = "复制" if set_with_another_variable else "设置"
    var source_desc = from_variable if set_with_another_variable else str(new_value)

    return "%s %s变量 %s.%s 为 %s" % [
        operation_type,
        "从" if set_with_another_variable else "",
        scope,
        target_variable,
        source_desc
    ]

func _cleanup_resources():
    super._cleanup_resources()
    _log_debug("SetIntVariableInstruction 资源清理完成")

func reset():
    super.reset()
    _log_debug("SetIntVariableInstruction 状态已重置")

# Unified logging methods
func _log_debug(message: String):
    FuseLogger.log_debug("SetIntVariableInstruction", log_level, message, target_variable)

func _log_info(message: String):
    FuseLogger.log_info("SetIntVariableInstruction", log_level, message, target_variable)

func _log_warning(message: String):
    FuseLogger.log_warning("SetIntVariableInstruction", log_level, message, target_variable)

func _log_error(message: String):
    FuseLogger.log_error("SetIntVariableInstruction", log_level, message, target_variable)
```

---

## Property Usage Flags in Detail

### Common Flags

```gdscript
# Disable a property (grays it out)
property.usage = property.usage | PROPERTY_USAGE_READ_ONLY

# Hide a property (completely invisible)
property.usage = property.usage | PROPERTY_USAGE_NO_EDITOR

# Show only in the editor
property.usage = property.usage | PROPERTY_USAGE_EDITOR

# Mark as a script variable
property.usage = property.usage | PROPERTY_USAGE_SCRIPT_VARIABLE

# Mark as a category
property.usage = property.usage | PROPERTY_USAGE_CATEGORY

# Mark as a subgroup
property.usage = property.usage | PROPERTY_USAGE_SUBGROUP

# Mark as a default value
property.usage = property.usage | PROPERTY_USAGE_DEFAULT
```

### Combining Flags

```gdscript
# Disable and hide at the same time
property.usage = property.usage | PROPERTY_USAGE_READ_ONLY | PROPERTY_USAGE_NO_EDITOR

# Set as a category and show only in the editor
property.usage = property.usage | PROPERTY_USAGE_CATEGORY | PROPERTY_USAGE_EDITOR
```

---

## Advanced Usage

### 1. Multiple Condition Checks

```gdscript
func _validate_property(property: Dictionary) -> void:
    # Multiple condition checks
    var should_disable_advanced = not advanced_mode_enabled
    var should_hide_deprecated = not show_deprecated_features
    var should_require_admin = user_role != "admin"

    # Control properties based on multiple conditions
    match property.name:
        "advanced_property":
            if should_disable_advanced:
                property.usage = property.usage | PROPERTY_USAGE_READ_ONLY
        "deprecated_property":
            if should_hide_deprecated:
                property.usage = property.usage | PROPERTY_USAGE_NO_EDITOR
        "admin_only_property":
            if should_require_admin:
                property.usage = property.usage | PROPERTY_USAGE_READ_ONLY
        "conditional_property":
            if not condition_a or not condition_b:
                property.usage = property.usage | PROPERTY_USAGE_READ_ONLY
```

### 2. Dynamic Property Hints

```gdscript
func _validate_property(property: Dictionary) -> void:
    match property.name:
        "password_field":
            if not encryption_enabled:
                property.usage = property.usage | PROPERTY_USAGE_READ_ONLY
                property.hint_string = "需要启用加密才能设置密码"
        "api_key":
            if not api_mode_enabled:
                property.usage = property.usage | PROPERTY_USAGE_READ_ONLY
                property.hint_string = "需要在 API 模式下才能设置密钥"
```

### 3. Property Groups and Subgroups

```gdscript
func _validate_property(property: Dictionary) -> void:
    # Set property groups dynamically
    match property.name:
        "basic_settings":
            property.usage = property.usage | PROPERTY_USAGE_GROUP
            property.hint_string = "Basic Settings"
        "advanced_settings":
            if advanced_mode_enabled:
                property.usage = property.usage | PROPERTY_USAGE_GROUP
                property.hint_string = "Advanced Settings"
            else:
                property.usage = property.usage | PROPERTY_USAGE_NO_EDITOR
```

---

## Performance Comparison

### Method Comparison Table

| Method | Performance | User Experience | Code Complexity | Maintainability |
|------|------|----------|------------|--------|
| _validate_property() | High | Excellent | Low | Excellent |
| _get_property_list() | Medium | Fair | Medium | Fair |
| Manual _get/_set | Low | Poor | High | Poor |
| Inspector plugin | Low | Excellent | High | Poor |

### Performance Test Example

```gdscript
# Benchmark _validate_property() performance
func test_validate_property_performance():
    var instruction = SetIntVariableInstruction.new()
    var start_time = Time.get_ticks_msec()

    # Simulate 1000 property validations
    for i in range(1000):
        instruction.set_with_another_variable = i % 2 == 0
        instruction.notify_property_list_changed()

    var end_time = Time.get_ticks_msec()
    print("_validate_property() 性能测试: %d ms" % (end_time - start_time))
```

---

## Common Issues and Solutions

### 1. Property Not Properly Disabled

**Problem**: the property is not grayed out or hidden

**Solution**:
- Make sure `notify_property_list_changed()` is called in the setter
- Check that the property name is correct
- Confirm the condition check logic is correct

```gdscript
# Wrong example
@export var control_var: bool = false:
    set(value):
        control_var = value  # missing notify_property_list_changed()

# Correct example
@export var control_var: bool = false:
    set(value):
        if control_var != value:
            control_var = value
            notify_property_list_changed()  # must be called
```

### 2. Inconsistent Property State

**Problem**: the property state does not match expectations

**Solution**:
- Add debug output inside `_validate_property()`
- Check the condition check logic
- Make sure all related properties are properly exported

```gdscript
func _validate_property(property: Dictionary) -> void:
    # Debug output
    print("验证属性: ", property.name)
    print("控制变量值: ", set_with_another_variable)

    # Validation logic
    if not set_with_another_variable:
        if property.name == "from_variable":
            print("禁用 from_variable")
            property.usage = property.usage | PROPERTY_USAGE_READ_ONLY
```

### 3. Performance Issues

**Problem**: property updates are slow

**Solution**:
- Avoid heavyweight operations inside `_validate_property()`
- Use short-circuit logic to optimize condition checks
- Cache computed results

```gdscript
func _validate_property(property: Dictionary) -> void:
    # Optimization: check lightweight conditions first
    if set_with_another_variable:
        # Only check heavyweight conditions when needed
        if property.name in ["from_variable", "from_variable_scope"]:
            property.usage = property.usage | PROPERTY_USAGE_READ_ONLY
    elif property.name == "new_value":
        property.usage = property.usage | PROPERTY_USAGE_READ_ONLY
```

---

## Best Practices Summary

### 1. Implementation Essentials

1. **Export all properties with @export**: ensures the editor recognizes every property
2. **Add setters to key properties**: call `notify_property_list_changed()` inside the setter to trigger updates
3. **Implement _validate_property()**: dynamically set the `PROPERTY_USAGE_READ_ONLY` flag based on conditions
4. **Update the resource name**: update `resource_name` when properties change to reflect the current configuration

### 2. Code Organization

```gdscript
# 1. Property definition section
@export var control_property: bool = false:
    set(value):
        if control_property != value:
            control_property = value
            _update_resource_name()
            notify_property_list_changed()

@export var dependent_property: String = ""

# 2. Core validation method
func _validate_property(property: Dictionary) -> void:
    # Clear condition check logic
    if not control_property:
        if property.name == "dependent_property":
            property.usage = property.usage | PROPERTY_USAGE_READ_ONLY

# 3. Resource name update
func _update_resource_name():
    # Update the display name based on the current state
    resource_name = "配置: %s" % ("启用" if control_property else "禁用")
```

### 3. Debugging Tips

```gdscript
func _validate_property(property: Dictionary) -> void:
    # Conditional debug output
    if OS.is_debug_build():
        print("验证属性: %s, 控制变量: %s" % [property.name, control_property])

    # Validation logic
    if not control_property:
        if property.name == "dependent_property":
            property.usage = property.usage | PROPERTY_USAGE_READ_ONLY
```

### 4. Extensibility Considerations

```gdscript
# Support multiple control conditions
func _validate_property(property: Dictionary) -> void:
    var should_disable = _should_disable_property(property.name)

    if should_disable:
        property.usage = property.usage | PROPERTY_USAGE_READ_ONLY

func _should_disable_property(property_name: String) -> bool:
    match property_name:
        "advanced_feature":
            return not advanced_mode_enabled
        "debug_option":
            return not debug_mode_enabled
        "experimental_feature":
            return not allow_experimental
        _:
            return false
```

---

## Conclusion

Using the `_validate_property()` method to implement conditional property display is the best practice in Godot. It offers an excellent user experience, high performance, and a clean code structure. By following the best practices in this guide, you can create dynamic editor interfaces that are intuitive, efficient, and easy to maintain.

This approach is particularly suitable for:
- Custom Instructions in the Fuse Visual Programming system
- Plugins that need complex configuration interfaces
- Tools with multiple operation modes
- Applications whose UI needs to adapt dynamically to user choices

By using property usage flags and condition checks properly, you can create a professional-grade editor experience.
