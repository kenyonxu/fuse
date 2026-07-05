# 数组指令开发指南

本文档总结了开发 Fuse 数组指令时的常见问题和最佳实践。

## element_value 属性定义

### 问题

在 `_get_property_list()` 中使用 `TYPE_NIL` 定义 Variant 类型属性时，Inspector 会显示 null 且无法编辑。

```gdscript
# ❌ 这样做会导致 Inspector 显示 null
properties.append({
    name = "element_value",
    type = TYPE_NIL,
    hint = PROPERTY_HINT_TYPE_STRING,
    hint_string = "Variant",
    usage = PROPERTY_USAGE_DEFAULT
})
```

### 解决方案

使用 `@export` 声明属性，在 `_validate_property()` 中控制可见性。

```gdscript
# ✅ 使用 @export 声明
@export var element_value: Variant:
    set(value):
        element_value = value
        _update_resource_name()

# 在 _validate_property() 中控制可见性
func _validate_property(property: Dictionary) -> void:
    if use_element_from_variable:
        if property.name == "element_value":
            property.usage = PROPERTY_USAGE_NO_EDITOR
```

---

## 变量变化通知

### 问题背景

`push_back()`、`remove_at()` 等操作修改数组**内容**而非**引用**，信号不会自动触发。远程调试器无法观测到变量变化。

### GLOBAL 全局变量通知

```gdscript
## 通知全局变量已变化（用于触发自动保存等）
## 由于 push_back 修改的是数组内容而非引用，value_changed 信号不会自动触发
## 因此需要手动通知 GlobalVariableManager 变量已变化
func _notify_global_variable_changed(var_name: String) -> void:
    var manager = GlobalVariableManager.get_instance()
    if manager == null:
        _log_debug("⚠️ 无法获取全局变量管理器，跳过变化通知")
        return

    var variable = manager.get_variable(var_name)
    if variable == null:
        _log_debug("⚠️ 全局变量 '%s' 不存在，跳过变化通知" % var_name)
        return

    # 检查是否是持久化变量
    if variable.persistent:
        _log_debug("📌 持久化变量 '%s' 已修改，触发变化通知" % var_name)
        # 使用 GlobalVariableManager 提供的方法通知变量内容已变化
        manager.notify_variable_content_changed(var_name)
    else:
        _log_debug("变量 '%s' 不是持久化变量，跳过自动保存通知" % var_name)
```

### SCOPE 作用域变量通知

```gdscript
## 通知 SCOPE 作用域变量已变化
## 由于 push_back 修改的是数组内容而非引用，需要调用 notify_property_list_changed
## 让远程调试器能够观测到变量变化
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

### 调用时机

在 `execute()` 末尾调用：

```gdscript
if source_type == SourceType.VARIABLE:
    if array_scope == BaseVariable.VariableScope.GLOBAL:
        _notify_global_variable_changed(array_variable)
    elif array_scope == BaseVariable.VariableScope.SCOPE:
        _notify_scope_variable_changed(context)
```

### 变量变化通知总结

| 作用域 | 修改数组内容后需要通知 | 通知方法 |
|--------|----------------------|----------|
| LOCAL | 不需要 | - |
| SCOPE | **需要** | `scope_container.notify_property_list_changed()` |
| GLOBAL | 需要（持久化变量） | `manager.notify_variable_content_changed(var_name)` |

---

## 翻译键命名规范

每个指令使用独立的翻译键前缀：

| 指令 | 翻译键前缀 |
|------|-----------|
| ArrayAdd | `FUSE_INSTRUCTION_ARRAY_ADD_*` |
| ArrayRemove | `FUSE_INSTRUCTION_ARRAY_REMOVE_*` |
| ArraySet | `FUSE_INSTRUCTION_ARRAY_SET_*` |
| ArrayGet | `FUSE_INSTRUCTION_ARRAY_GET_*` |

### 需要翻译的函数

| 函数 | 用途 |
|------|------|
| `_update_resource_name()` | 资源名称显示 |
| `get_description()` | 指令描述文本 |
| `_get_instruction_metadata()` | 指令选择器元数据 |

### 翻译键示例

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

## 调试日志最佳实践

### 作用域信息日志

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

### 执行结果日志

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

## 指令分类

| 类型 | 指令 | 需要变化通知 |
|------|------|-------------|
| **修改数组** | ArrayAdd, ArrayRemove, ArraySet, ArrayClear, ArrayInsert, ArrayMerge, ArrayReverse, ArrayShuffle | **需要** |
| **只读操作** | ArrayGet, ArraySize, ArrayFind, ArrayContains, ArrayRandom, ArraySlice | 不需要 |

---

## 参考实现

完整的参考实现见 [array_add.gd](../../instructions/arrays/array_add.gd)。
