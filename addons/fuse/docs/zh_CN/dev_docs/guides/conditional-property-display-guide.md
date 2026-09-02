# Godot 条件化属性显示实现指南

## 概述

本指南详细介绍了在 Godot 中实现条件化属性显示的完整方法，特别针对 Fuse Visual Programming 系统中的自定义 Instruction 类。通过使用 `_validate_property()` 方法，您可以创建动态的编辑器界面，根据用户的选择显示或禁用相关属性。

## 目录

1. [背景与问题](#背景与问题)
2. [解决方案概述](#解决方案概述)
3. [核心实现方法](#核心实现方法)
4. [完整实现示例](#完整实现示例)
5. [属性使用标志详解](#属性使用标志详解)
6. [高级用法](#高级用法)
7. [性能对比](#性能对比)
8. [常见问题与解决方案](#常见问题与解决方案)
9. [最佳实践总结](#最佳实践总结)

---

## 背景与问题

### 传统方法的局限性

在 Godot 中实现条件化属性显示，传统方法包括：

1. **手动属性管理**：使用 `_get()` 和 `_set()` 方法手动管理属性
2. **动态属性列表**：通过 `_get_property_list()` 动态生成属性列表
3. **Inspector 插件**：创建专门的编辑器插件

这些方法存在以下问题：
- 代码复杂度高
- 性能开销大
- 用户体验不佳（属性完全消失）
- 维护困难

### 理想的解决方案

理想的条件化属性显示应该：
- 属性变灰而不是消失
- 实时响应用户操作
- 性能高效
- 代码简洁易维护

---

## 解决方案概述

### 核心思想

使用 Godot 的 `_validate_property()` 方法，在属性显示前对其进行验证和修改，实现条件化显示。

### 技术优势

1. **更好的用户体验**：属性变灰而不是消失，用户能看到所有可用选项
2. **性能更优**：不需要重建整个属性列表，只验证需要验证的属性
3. **逻辑更清晰**：每个属性的条件判断独立，易于调试和维护
4. **符合标准实践**：使用 Godot 推荐的属性验证方法

---

## 核心实现方法

### 1. 基本结构

```gdscript
@tool
extends BaseInstruction
class_name ConditionalDisplayExample

# 基础属性（始终显示）
@export var target_variable: String = ""
@export var scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL

# 控制属性（带 setter，触发属性更新）
@export var set_with_another_variable: bool = false:
    set(value):
        if set_with_another_variable != value:
            set_with_another_variable = value
            _update_resource_name()
            notify_property_list_changed()  # 触发属性验证

# 条件属性（始终导出，但根据条件禁用）
@export var from_variable: String = ""
@export var from_variable_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL
@export var new_value: int = 0
```

### 2. 关键方法实现

#### `_validate_property()` 方法

```gdscript
func _validate_property(property: Dictionary) -> void:
    # 当 set_with_another_variable = false 时，禁用源变量属性
    if not set_with_another_variable:
        if property.name == "from_variable":
            property.usage = property.usage | PROPERTY_USAGE_READ_ONLY
        elif property.name == "from_variable_scope":
            property.usage = property.usage | PROPERTY_USAGE_READ_ONLY
    
    # 当 set_with_another_variable = true 时，禁用新值属性
    if set_with_another_variable:
        if property.name == "new_value":
            property.usage = property.usage | PROPERTY_USAGE_READ_ONLY
```

#### 触发机制

```gdscript
@export var set_with_another_variable: bool = false:
    set(value):
        if set_with_another_variable != value:
            set_with_another_variable = value
            _update_resource_name()
            notify_property_list_changed()  # 关键：触发属性验证
```

---

## 完整实现示例

### SetIntVariableInstruction 完整实现

```gdscript
@tool
extends BaseInstruction
class_name SetIntVariableInstruction

# 基础属性（始终显示）
@export var target_variable: String = ""
@export var scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL

# 控制属性（带 setter，触发属性更新）
@export var set_with_another_variable: bool = false:
    set(value):
        if set_with_another_variable != value:
            set_with_another_variable = value
            _update_resource_name()
            notify_property_list_changed()  # 触发检视器更新

# 条件属性（始终导出，但根据条件禁用）
@export var from_variable: String = ""
@export var from_variable_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL
@export var new_value: int = 0

# 实现条件化检视器显示
func _validate_property(property: Dictionary) -> void:
    # 当 set_with_another_variable = false 时，禁用源变量属性
    if not set_with_another_variable:
        if property.name == "from_variable":
            property.usage = property.usage | PROPERTY_USAGE_READ_ONLY
        elif property.name == "from_variable_scope":
            property.usage = property.usage | PROPERTY_USAGE_READ_ONLY
    
    # 当 set_with_another_variable = true 时，禁用新值属性
    if set_with_another_variable:
        if property.name == "new_value":
            property.usage = property.usage | PROPERTY_USAGE_READ_ONLY

# 更新资源名称以反映当前配置
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

# 其他必要方法...
func _setup_metadata():
    metadata.name = "设置整数变量"
    metadata.description = "为指定名称的变量设置整数值，支持从另一个变量复制或直接设置新值"
    metadata.category = "变量操作"
    metadata.version = "1.0"
    metadata.author = "Fuse System"

func execute(context: ExecutionContext):
    _start_execution(context)
    
    # 参数验证
    if target_variable.is_empty():
        set_error("目标变量名称不能为空", FuseError.ErrorType.VALIDATION_ERROR)
        finished.emit()
        return
    
    # 确定要设置的值
    var value_to_set: int
    if set_with_another_variable:
        # 从另一个变量获取值
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
        # 使用新值
        value_to_set = new_value
    
    # 设置目标变量
    var success = _set_variable_value(context, target_variable, scope, value_to_set)
    if not success:
        set_error("无法设置变量: %s" % target_variable, FuseError.ErrorType.RUNTIME_ERROR)
        finished.emit()
        return
    
    # 记录成功信息
    var operation_type = "复制" if set_with_another_variable else "设置"
    _log_info("成功%s变量 %s 的值为 %d" % [operation_type, target_variable, value_to_set])
    
    _on_execution_completed()

# 辅助方法...
func _get_variable_value(context: ExecutionContext, variable_name: String, variable_scope: BaseVariable.VariableScope) -> int:
    if not context:
        return 0
    
    var value = context.get_variable(variable_name, null)
    if value == null:
        return 0
    
    # 确保是整数类型
    if typeof(value) != TYPE_INT:
        _log_warning("变量 %s 的类型不是整数，当前类型: %s" % [variable_name, typeof(value)])
        return 0
    
    return value

func _set_variable_value(context: ExecutionContext, variable_name: String, variable_scope: BaseVariable.VariableScope, value: int) -> bool:
    if not context:
        return false
    
    # 将枚举转换为字符串
    var scope_str = "local" if variable_scope == BaseVariable.VariableScope.LOCAL else "global"
    
    # 尝试设置变量
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

# 统一日志方法
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

## 属性使用标志详解

### 常用标志

```gdscript
# 禁用属性（变灰）
property.usage = property.usage | PROPERTY_USAGE_READ_ONLY

# 隐藏属性（完全不可见）
property.usage = property.usage | PROPERTY_USAGE_NO_EDITOR

# 只在编辑器中显示
property.usage = property.usage | PROPERTY_USAGE_EDITOR

# 标记为脚本变量
property.usage = property.usage | PROPERTY_USAGE_SCRIPT_VARIABLE

# 标记为分类
property.usage = property.usage | PROPERTY_USAGE_CATEGORY

# 标记为子组
property.usage = property.usage | PROPERTY_USAGE_SUBGROUP

# 标记为默认值
property.usage = property.usage | PROPERTY_USAGE_DEFAULT
```

### 标志组合使用

```gdscript
# 同时禁用和隐藏
property.usage = property.usage | PROPERTY_USAGE_READ_ONLY | PROPERTY_USAGE_NO_EDITOR

# 设置为分类且只在编辑器中显示
property.usage = property.usage | PROPERTY_USAGE_CATEGORY | PROPERTY_USAGE_EDITOR
```

---

## 高级用法

### 1. 多条件判断

```gdscript
func _validate_property(property: Dictionary) -> void:
    # 多条件判断
    var should_disable_advanced = not advanced_mode_enabled
    var should_hide_deprecated = not show_deprecated_features
    var should_require_admin = user_role != "admin"
    
    # 根据多个条件控制属性
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

### 2. 动态属性提示

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

### 3. 属性分组和子组

```gdscript
func _validate_property(property: Dictionary) -> void:
    # 动态设置属性分组
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

## 性能对比

### 方法对比表

| 方法 | 性能 | 用户体验 | 代码复杂度 | 维护性 |
|------|------|----------|------------|--------|
| _validate_property() | 高 | 优秀 | 低 | 优秀 |
| _get_property_list() | 中 | 一般 | 中 | 一般 |
| 手动 _get/_set | 低 | 差 | 高 | 差 |
| Inspector 插件 | 低 | 优秀 | 高 | 差 |

### 性能测试示例

```gdscript
# 测试 _validate_property() 性能
func test_validate_property_performance():
    var instruction = SetIntVariableInstruction.new()
    var start_time = Time.get_ticks_msec()
    
    # 模拟 1000 次属性验证
    for i in range(1000):
        instruction.set_with_another_variable = i % 2 == 0
        instruction.notify_property_list_changed()
    
    var end_time = Time.get_ticks_msec()
    print("_validate_property() 性能测试: %d ms" % (end_time - start_time))
```

---

## 常见问题与解决方案

### 1. 属性没有正确禁用

**问题**：属性没有变灰或隐藏

**解决方案**：
- 确保在 setter 中调用了 `notify_property_list_changed()`
- 检查属性名称是否正确
- 确认条件判断逻辑正确

```gdscript
# 错误示例
@export var control_var: bool = false:
    set(value):
        control_var = value  # 缺少 notify_property_list_changed()

# 正确示例
@export var control_var: bool = false:
    set(value):
        if control_var != value:
            control_var = value
            notify_property_list_changed()  # 必须调用
```

### 2. 属性状态不一致

**问题**：属性状态与预期不符

**解决方案**：
- 在 `_validate_property()` 中添加调试输出
- 检查条件判断的逻辑
- 确保所有相关属性都正确导出

```gdscript
func _validate_property(property: Dictionary) -> void:
    # 调试输出
    print("验证属性: ", property.name)
    print("控制变量值: ", set_with_another_variable)
    
    # 验证逻辑
    if not set_with_another_variable:
        if property.name == "from_variable":
            print("禁用 from_variable")
            property.usage = property.usage | PROPERTY_USAGE_READ_ONLY
```

### 3. 性能问题

**问题**：属性更新缓慢

**解决方案**：
- 避免在 `_validate_property()` 中执行重量级操作
- 使用短路逻辑优化条件判断
- 缓存计算结果

```gdscript
func _validate_property(property: Dictionary) -> void:
    # 优化：先检查轻量级条件
    if set_with_another_variable:
        # 只在需要时检查重量级条件
        if property.name in ["from_variable", "from_variable_scope"]:
            property.usage = property.usage | PROPERTY_USAGE_READ_ONLY
    elif property.name == "new_value":
        property.usage = property.usage | PROPERTY_USAGE_READ_ONLY
```

---

## 最佳实践总结

### 1. 实现要点

1. **使用 @export 导出所有属性**：确保所有属性都能被编辑器识别
2. **关键属性添加 setter**：在 setter 中调用 `notify_property_list_changed()` 触发更新
3. **实现 _validate_property()**：根据条件动态设置属性的 `PROPERTY_USAGE_READ_ONLY` 标志
4. **更新资源名称**：在属性变化时更新 `resource_name` 以反映当前配置

### 2. 代码组织

```gdscript
# 1. 属性定义区域
@export var control_property: bool = false:
    set(value):
        if control_property != value:
            control_property = value
            _update_resource_name()
            notify_property_list_changed()

@export var dependent_property: String = ""

# 2. 核心验证方法
func _validate_property(property: Dictionary) -> void:
    # 清晰的条件判断逻辑
    if not control_property:
        if property.name == "dependent_property":
            property.usage = property.usage | PROPERTY_USAGE_READ_ONLY

# 3. 资源名称更新
func _update_resource_name():
    # 根据当前状态更新显示名称
    resource_name = "配置: %s" % ("启用" if control_property else "禁用")
```

### 3. 调试技巧

```gdscript
func _validate_property(property: Dictionary) -> void:
    # 条件性调试输出
    if OS.is_debug_build():
        print("验证属性: %s, 控制变量: %s" % [property.name, control_property])
    
    # 验证逻辑
    if not control_property:
        if property.name == "dependent_property":
            property.usage = property.usage | PROPERTY_USAGE_READ_ONLY
```

### 4. 扩展性考虑

```gdscript
# 支持多种控制条件
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

## 结论

使用 `_validate_property()` 方法实现条件化属性显示是 Godot 中的最佳实践。它提供了优秀的用户体验、高性能和简洁的代码结构。通过遵循本指南的最佳实践，您可以创建出直观、高效且易于维护的动态编辑器界面。

这种方法特别适用于：
- Fuse Visual Programming 系统中的自定义 Instruction
- 需要复杂配置界面的插件
- 具有多种操作模式的工具
- 需要根据用户选择动态调整界面的应用

通过合理使用属性使用标志和条件判断，您可以创建出专业级的编辑器体验。