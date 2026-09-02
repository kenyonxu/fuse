> 🌐 [**中文版**](../../../zh_CN/dev_docs/guides/array-instructions-guide.md) | English

# Array Instructions Development Guide

This document summarizes common issues and best practices when developing Fuse array instructions.

## The element_value Property Definition

### Problem

When defining a Variant-typed property with `TYPE_NIL` in `_get_property_list()`, the Inspector shows null and the property cannot be edited.

```gdscript
# ❌ Doing this makes the Inspector show null
properties.append({
    name = "element_value",
    type = TYPE_NIL,
    hint = PROPERTY_HINT_TYPE_STRING,
    hint_string = "Variant",
    usage = PROPERTY_USAGE_DEFAULT
})
```

### Solution

Declare the property with `@export` and control its visibility in `_validate_property()`.

```gdscript
# ✅ Declare with @export
@export var element_value: Variant:
    set(value):
        element_value = value
        _update_resource_name()

# Control visibility in _validate_property()
func _validate_property(property: Dictionary) -> void:
    if use_element_from_variable:
        if property.name == "element_value":
            property.usage = PROPERTY_USAGE_NO_EDITOR
```

---

## Variable Change Notifications

### Background

Operations such as `push_back()` and `remove_at()` modify the array **contents**, not the **reference**, so the signal does not fire automatically. The remote debugger cannot observe the variable change.

### GLOBAL Variable Notification

```gdscript
## Notify that a global variable has changed (used to trigger autosave, etc.)
## Because push_back modifies the array contents rather than the reference, the value_changed
## signal does not fire automatically, so GlobalVariableManager must be notified manually
func _notify_global_variable_changed(var_name: String) -> void:
    var manager = GlobalVariableManager.get_instance()
    if manager == null:
        _log_debug("⚠️ 无法获取全局变量管理器，跳过变化通知")
        return

    var variable = manager.get_variable(var_name)
    if variable == null:
        _log_debug("⚠️ 全局变量 '%s' 不存在，跳过变化通知" % var_name)
        return

    # Check whether this is a persistent variable
    if variable.persistent:
        _log_debug("📌 持久化变量 '%s' 已修改，触发变化通知" % var_name)
        # Use the GlobalVariableManager method to notify that the variable contents changed
        manager.notify_variable_content_changed(var_name)
    else:
        _log_debug("变量 '%s' 不是持久化变量，跳过自动保存通知" % var_name)
```

### SCOPE Variable Notification

```gdscript
## Notify that a SCOPE-scope variable has changed
## Because push_back modifies the array contents rather than the reference, call
## notify_property_list_changed so the remote debugger can observe the change
func _notify_scope_variable_changed(context: ExecutionContext) -> void:
    var utils_scope_source = array_scope_source as VariableScopeUtils.ScopeSource
    var scope_container = VariableScopeUtils.get_scope_container_by_source(
        context,
        utils_scope_source,
        array_custom_scope_id,
        array_target_node_path
    )

    if scope_container == null:
        _log_debug("⚠️ 无法获取 ScopeVariableContainer，跳过变化通知")
        return

    _log_debug("📌 SCOPE 变量 '%s' 已修改，触发 notify_property_list_changed" % array_variable)
    scope_container.notify_property_list_changed()
```

### When to Call

Call at the end of `execute()`:

```gdscript
if source_type == SourceType.VARIABLE:
    if array_scope == BaseVariable.VariableScope.GLOBAL:
        _notify_global_variable_changed(array_variable)
    elif array_scope == BaseVariable.VariableScope.SCOPE:
        _notify_scope_variable_changed(context)
```

### Variable Change Notification Summary

| Scope | Notify after modifying array contents | Notification method |
|--------|----------------------|----------|
| LOCAL | Not needed | - |
| SCOPE | **Needed** | `scope_container.notify_property_list_changed()` |
| GLOBAL | Needed (persistent variables) | `manager.notify_variable_content_changed(var_name)` |

---

## Translation Key Naming Conventions

Each instruction uses its own translation key prefix:

| Instruction | Translation key prefix |
|------|-----------|
| ArrayAdd | `FUSE_INSTRUCTION_ARRAY_ADD_*` |
| ArrayRemove | `FUSE_INSTRUCTION_ARRAY_REMOVE_*` |
| ArraySet | `FUSE_INSTRUCTION_ARRAY_SET_*` |
| ArrayGet | `FUSE_INSTRUCTION_ARRAY_GET_*` |

### Functions Requiring Translation

| Function | Purpose |
|------|------|
| `_update_resource_name()` | Resource name display |
| `get_description()` | Instruction description text |
| `_get_instruction_metadata()` | Instruction picker metadata |

### Translation Key Examples

```
FUSE_INSTRUCTION_ARRAY_SET_NAME,设置数组元素,Array Set
FUSE_INSTRUCTION_ARRAY_SET_DESC,设置数组中指定索引的元素值,Set element value at specified index
FUSE_INSTRUCTION_ARRAY_SET_NO_ARRAY,<未指定数组>,<No Array Specified>
FUSE_INSTRUCTION_ARRAY_SET_ARRAY,数组 {name},Array {name}
FUSE_INSTRUCTION_ARRAY_SET_NODE_CHILDREN,子节点数组,Node Children
FUSE_INSTRUCTION_ARRAY_SET_NO_GROUP,<未指定组>,<No Group Specified>
FUSE_INSTRUCTION_ARRAY_SET_GROUP,组 '{name}',Group '{name}'
FUSE_INSTRUCTION_ARRAY_SET_NO_ELEMENT_VAR,<未指定元素变量>,<No Element Variable Specified>
FUSE_INSTRUCTION_ARRAY_SET_FROM_VAR,变量 {name},Variable {name}
```

---

## Debug Logging Best Practices

### Scope Info Logging

```gdscript
func _debug_log_array_scope_info():
    var scope_name := ""
    match array_scope:
        BaseVariable.VariableScope.LOCAL:
            scope_name = "LOCAL（本地）"
        BaseVariable.VariableScope.SCOPE:
            scope_name = "SCOPE（作用域）"
        BaseVariable.VariableScope.GLOBAL:
            scope_name = "GLOBAL（全局）"

    if array_scope == BaseVariable.VariableScope.SCOPE:
        var source_name := ""
        match array_scope_source:
            ScopeSource.NEAREST:
                source_name = "NEAREST（最近的作用域容器）"
            ScopeSource.CUSTOM_ID:
                source_name = "CUSTOM_ID（自定义ID: %s）" % array_custom_scope_id
            ScopeSource.TRIGGER_SCOPE:
                source_name = "TRIGGER_SCOPE（Trigger节点作用域）"
            ScopeSource.TARGET_NODE:
                source_name = "TARGET_NODE（目标节点: %s）" % str(array_target_node_path)
        _log_debug("📍 目标数组: '%s' | 作用域: %s | 来源: %s" % [array_variable, scope_name, source_name])
    else:
        _log_debug("📍 目标数组: '%s' | 作用域: %s" % [array_variable, scope_name])
```

### Execution Result Logging

```gdscript
var scope_name_for_log := _get_scope_name_for_log()

_log_debug("════════════════════════════════════════════════════")
_log_debug("📤 ArrayAdd 执行结果:")
_log_debug("  • 目标数组: '%s'" % array_variable)
_log_debug("  • 作用域: %s" % scope_name_for_log)
_log_debug("  • 添加元素: %s (类型: %s)" % [str(element), typeof(element)])
_log_debug("  • 数组大小: %d → %d" % [array_size_before, array_size_after])
_log_debug("  • 最终内容: %s" % str(target_array))
_log_debug("════════════════════════════════════════════════════")
```

---

## Instruction Categories

| Type | Instructions | Change notification needed |
|------|------|-------------|
| **Array-modifying** | ArrayAdd, ArrayRemove, ArraySet, ArrayClear, ArrayInsert, ArrayMerge, ArrayReverse, ArrayShuffle | **Needed** |
| **Read-only operations** | ArrayGet, ArraySize, ArrayFind, ArrayContains, ArrayRandom, ArraySlice | Not needed |

---

## Reference Implementation

See [array_add.gd](../../../../instructions/arrays/array_add.gd) for the complete reference implementation.
