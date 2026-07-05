# SetPropertyValue 指令实现方案

## 📋 需求概述

用户需要一个新的指令 `SetPropertyValue`，用于动态设置指定节点的公开属性值。该指令需要支持两种模式：
1. **直接值模式**：直接设置指定的值
2. **变量值模式**：从变量获取值并设置到属性

## 🎯 核心功能需求

### 1. 属性配置
- **target_node**: `NodePath` - 目标节点的路径
- **target_property**: `String` - 目标属性名称（动态生成列表）
- **new_value**: `Variant` - 要设置的值（根据属性类型变化）

### 2. 变量配置
- **set_with_variable**: `bool` - 是否使用变量值
- **variable_name**: `String` - 变量名称
- **variable_scope**: `BaseVariable.VariableScope` - 变量作用域

### 3. 编辑器体验
- **动态属性列表**：根据选定节点生成可用属性列表
- **条件化显示**：根据模式显示/隐藏相关属性
- **类型适配**：根据选定属性类型调整值编辑器

## 🏗️ 技术架构设计

### 类继承结构
```
BaseInstruction
└── SetPropertyValue
```

### 核心组件设计

#### 1. 通用类组件

SetPropertyValue 指令将使用三个通用类来实现属性操作功能：

**PropertyInfo 类** - 属性信息封装
- 统一的属性信息结构，包含名称、类型、提示、使用标志等
- 支持扩展属性（分类、描述、验证规则等）
- 提供类型分析和兼容性检查功能

**TypeConverter 类** - 安全类型转换
- 支持 Godot 所有基础类型的安全转换
- 完整的类型兼容性矩阵和智能字符串解析
- 详细的错误处理和日志记录

**PropertyManager 类** - 属性发现和操作
- 多种属性过滤器（可写、导出、数值、容器等）
- 智能缓存系统提升性能
- 安全的属性设置和批量操作支持

#### 2. 通用类集成架构

```gdscript
# 使用通用类的简化实现
class SetPropertyValue extends BaseInstruction:
    # 使用 PropertyManager 获取属性列表
    func _get_available_properties() -> Array[PropertyInfo]:
        return PropertyManager.get_writable_properties(_target_node_instance)
    
    # 使用 PropertyInfo 进行属性验证
    func _validate_property() -> bool:
        var prop_info = PropertyManager.find_property(_target_node_instance, target_property)
        return prop_info != null and prop_info.is_writable()
    
    # 使用 TypeConverter 进行安全转换
    func _convert_value_safely(value: Variant) -> Variant:
        var prop_info = PropertyManager.find_property(_target_node_instance, target_property)
        return TypeConverter.safe_convert(value, prop_info.type)
    
    # 使用 PropertyManager 安全设置属性
    func _set_property_value(target: Node, value: Variant) -> bool:
        return PropertyManager.set_property_safe(target, target_property, value)
```

## 📝 详细实现方案

### 1. 基础属性定义

```gdscript
@tool
@icon("res://addons/bricks/icons/instruction.svg")
extends BaseInstruction
class_name SetPropertyValue

# 节点配置
@export_group("Node Configuration")
@export var target_node: NodePath:
    set(value):
        target_node = value
        _update_target_node_info()
        _update_resource_name()
        notify_property_list_changed()

@export var target_property: String = "":
    set(value):
        target_property = value
        _update_property_type_info()
        _update_resource_name()

# 值配置
@export_group("Value Configuration")
@export var set_with_variable: bool = false:
    set(value):
        set_with_variable = value
        _update_resource_name()
        notify_property_list_changed()

@export var new_value: Variant:
    set(value):
        new_value = value
        _update_resource_name()

# 变量配置
@export_group("Variable Configuration")
@export var variable_name: String = "":
    set(value):
        variable_name = value
        _update_resource_name()

@export var variable_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
    set(value):
        variable_scope = value
        _update_resource_name()
```

### 2. 使用通用类的动态属性列表生成

```gdscript
# 使用 PropertyManager 获取可用属性列表
func _get_available_properties() -> Array[PropertyInfo]:
    if _target_node_instance == null:
        return []
    
    # 使用通用类的过滤器获取可写属性
    return PropertyManager.get_writable_properties(_target_node_instance)

# 获取属性列表用于编辑器显示
func _get_property_list() -> Array[Dictionary]:
    var properties: Array[Dictionary] = []
    
    if _target_node_instance == null:
        return properties
    
    # 使用通用类获取属性信息
    var property_infos = _get_available_properties()
    
    for prop_info in property_infos:
        var property_dict = {
            "name": prop_info.name,
            "type": prop_info.type,
            "hint": prop_info.hint,
            "hint_string": prop_info.hint_string,
            "default": prop_info.default_value,
            "class_name": prop_info.class_name
        }
        properties.append(property_dict)
    
    return properties

# 使用通用类检查属性是否可写
func _is_property_writable(property_name: String) -> bool:
    if _target_node_instance == null:
        return false
    
    return PropertyManager.is_property_writable(_target_node_instance, property_name)
```

### 3. 编辑器属性控制

```gdscript
# 属性验证和显示控制
func _validate_property(property: Dictionary) -> void:
    # 当没有选择目标节点时，禁用属性选择
    if _target_node_instance == null:
        if property.name == "target_property":
            property.usage = PROPERTY_USAGE_READ_ONLY
        return
    
    # 根据模式控制属性显示
    if not set_with_variable:
        # 直接值模式：隐藏变量相关属性
        if property.name in ["variable_name", "variable_scope"]:
            property.usage = PROPERTY_USAGE_READ_ONLY
    else:
        # 变量值模式：隐藏直接值属性
        if property.name == "new_value":
            property.usage = PROPERTY_USAGE_READ_ONLY

# 更新目标节点信息
func _update_target_node_info():
    _target_node_instance = null
    _available_properties = []
    
    if target_node.is_empty():
        return
    
    # 尝试获取节点实例（编辑器模式下）
    if Engine.is_editor_hint():
        var scene_root = get_tree().current_scene
        if scene_root:
            _target_node_instance = scene_root.get_node(target_node)
    
    if _target_node_instance:
        _available_properties = _get_property_list()
        _update_property_type_info()

# 更新属性类型信息（使用通用类）
func _update_property_type_info():
    _current_property_info = null
    
    if _target_node_instance == null or target_property.is_empty():
        return
    
    # 使用 PropertyManager 获取属性信息
    _current_property_info = PropertyManager.find_property(_target_node_instance, target_property)
    
    if _current_property_info != null:
        _current_property_type = _current_property_info.type
        _current_property_hint = _current_property_info.hint
        _current_property_hint_string = _current_property_info.hint_string
    else:
        _current_property_type = TYPE_NIL
        _current_property_hint = PROPERTY_HINT_NONE
        _current_property_hint_string = ""
```

### 4. 执行逻辑实现

```gdscript
# 执行指令
func execute(context: ExecutionContext):
    _start_execution(context)
    
    # 验证参数
    var errors = _validate_parameters()
    if not errors.is_empty():
        _set_error("参数验证失败: " + ", ".join(errors))
        finished.emit()
        return
    
    # 获取目标节点
    var target = _get_target_node()
    if target == null:
        _set_error("无法找到目标节点: " + target_node)
        finished.emit()
        return
    
    # 获取要设置的值
    var value_to_set = _get_value_to_set(context)
    if value_to_set == null:
        _set_error("无法获取要设置的值")
        finished.emit()
        return
    
    # 设置属性值
    var success = _set_property_value(target, value_to_set)
    if not success:
        _set_error("无法设置属性值: " + target_property)
        finished.emit()
        return
    
    _log_info("成功设置节点 %s 的属性 %s 为 %s" % [
        target.name, target_property, str(value_to_set)
    ])
    
    _on_execution_completed()

# 获取目标节点
func _get_target_node() -> Node:
    # 运行时获取节点
    var scene_root = get_tree().current_scene
    if scene_root == null:
        return null
    
    return scene_root.get_node(target_node)

# 获取要设置的值
func _get_value_to_set(context: ExecutionContext) -> Variant:
    if set_with_variable:
        # 从变量获取值
        if variable_name.is_empty():
            _log_error("变量名称为空")
            return null
        
        return _get_variable_value(context)
    else:
        # 使用直接值
        return new_value

# 设置属性值（使用通用类）
func _set_property_value(target: Node, value: Variant) -> bool:
    # 使用 PropertyManager 的安全设置方法
    var result = PropertyManager.set_property_safe(target, target_property, value)
    
    if result.success:
        _log_info("成功设置属性 %s 为 %s" % [target_property, str(result.value)])
        return true
    else:
        _log_error("设置属性失败: " + result.error_message)
        return false

# 值类型转换（使用通用类）
func _convert_value_to_property_type(value: Variant) -> Variant:
    if _current_property_info == null:
        _log_error("属性信息未初始化")
        return null
    
    # 使用 TypeConverter 进行安全转换
    return TypeConverter.safe_convert(value, _current_property_info.type)
```

### 5. 变量值获取

```gdscript
# 获取变量值
func _get_variable_value(context: ExecutionContext) -> Variant:
    if context == null:
        _log_error("执行上下文为空")
        return null
    
    var value = null
    
    match variable_scope:
        BaseVariable.VariableScope.LOCAL:
            value = context.get_variable(variable_name, null)
        BaseVariable.VariableScope.GLOBAL:
            var assistant = GlobalVariableAssistant.get_instance()
            if assistant != null:
                var variable = assistant.get_global_variable(variable_name)
                if variable != null:
                    value = variable.get_value()
                else:
                    _log_debug("全局变量未找到: " + variable_name)
            else:
                _log_error("无法获取 GlobalVariableAssistant 实例")
        _:
            _log_error("未知的变量作用域: " + BaseVariable.VariableScope.keys()[variable_scope])
            return null
    
    return value
```

### 6. 验证机制

```gdscript
# 参数验证
func _validate_parameters() -> Array[String]:
    var errors: Array[String] = []
    
    # 验证目标节点路径
    if target_node.is_empty():
        errors.append("目标节点路径不能为空")
    
    # 验证目标属性
    if target_property.is_empty():
        errors.append("目标属性不能为空")
    elif _target_node_instance != null:
        if not _has_property(_target_node_instance, target_property):
            errors.append("目标节点不存在指定属性: " + target_property)
        elif not _is_property_writable_for_node(_target_node_instance, target_property):
            errors.append("目标属性不可写: " + target_property)
    
    # 验证值设置
    if set_with_variable:
        if variable_name.is_empty():
            errors.append("变量模式需要指定变量名称")
    else:
        # 验证直接值类型兼容性
        if not _is_value_compatible_with_property(new_value):
            errors.append("值类型与目标属性类型不兼容")
    
    return errors

# 检查节点是否有指定属性（使用通用类）
func _has_property(node: Node, property_name: String) -> bool:
    return PropertyManager.has_property(node, property_name)

# 检查属性是否可写（使用通用类）
func _is_property_writable_for_node(node: Node, property_name: String) -> bool:
    return PropertyManager.is_property_writable(node, property_name)

# 检查值与属性类型兼容性（使用通用类）
func _is_value_compatible_with_property(value: Variant) -> bool:
    if _current_property_info == null:
        return false
    
    return TypeConverter.is_compatible(typeof(value), _current_property_info.type)
```

### 7. 资源名称和描述

```gdscript
# 更新资源名称
func _update_resource_name():
    var parts = []
    
    parts.append("设置属性")
    
    # 目标节点信息
    if not target_node.is_empty():
        parts.append("[" + target_node.get_file() + "]")
    else:
        parts.append("[未选择节点]")
    
    # 属性信息
    if not target_property.is_empty():
        parts.append("." + target_property)
    else:
        parts.append(".[未选择属性]")
    
    # 值信息
    if set_with_variable:
        if not variable_name.is_empty():
            parts.append("= [" + variable_name + "]")
        else:
            parts.append("= [未指定变量]")
    else:
        var value_str = str(new_value)
        if value_str.length() > 15:
            value_str = value_str.substr(0, 12) + "..."
        parts.append("= " + value_str)
    
    resource_name = " ".join(parts)

# 获取指令描述
func get_description() -> String:
    var target_desc = target_node.get_file() if not target_node.is_empty() else "未选择节点"
    var prop_desc = target_property if not target_property.is_empty() else "未选择属性"
    
    if set_with_variable:
        var var_desc = variable_name if not variable_name.is_empty() else "未指定变量"
        return "设置节点 %s 的属性 %s 为变量 %s 的值" % [target_desc, prop_desc, var_desc]
    else:
        return "设置节点 %s 的属性 %s 为 %s" % [target_desc, prop_desc, str(new_value)]
```

## 🔧 使用通用类的类型转换

TypeConverter 类提供了完整的类型转换支持，SetPropertyValue 指令直接使用这些功能：

### 基础类型转换
- **BOOL**: 字符串 "true"/"false"、数字 0/1 转换
- **INT**: 浮点数截断、字符串解析、布尔值转换
- **FLOAT**: 整数转换、字符串解析、布尔值转换
- **STRING**: 所有类型转为字符串表示

### 引用类型转换
- **NODE_PATH**: 字符串路径验证和转换
- **COLOR**: 十六进制字符串、HTML颜色名转换
- **VECTOR2/3**: 字符串解析、数组转换

### 容器类型转换
- **ARRAY**: 可迭代对象转换
- **DICTIONARY**: 字符串 JSON 解析

### 转换使用示例
```gdscript
# 在 SetPropertyValue 中使用 TypeConverter
func _convert_value_to_property_type(value: Variant) -> Variant:
    if _current_property_info == null:
        return null
    
    # 自动处理所有类型转换
    return TypeConverter.safe_convert(value, _current_property_info.type)

# 检查转换兼容性
func _validate_value_compatibility(value: Variant) -> bool:
    if _current_property_info == null:
        return false
    
    return TypeConverter.is_compatible(typeof(value), _current_property_info.type)
```

## 🧪 测试策略

### 1. 单元测试
- 属性列表生成测试
- 类型转换测试
- 验证逻辑测试
- 错误处理测试

### 2. 集成测试
- 与 ExecutionContext 集成
- 与 GlobalVariableAssistant 集成
- 跨作用域变量访问测试

### 3. 编辑器测试
- 属性显示/隐藏测试
- 动态列表更新测试
- 类型适配测试

## 📊 使用通用类的性能优势

### 1. 智能缓存系统
PropertyManager 提供了内置的缓存机制：
- **节点级缓存**：自动缓存节点的属性列表
- **增量更新**：只在节点结构变化时更新缓存
- **内存管理**：自动清理无效节点的缓存

```gdscript
# PropertyManager 自动处理缓存
var properties = PropertyManager.get_writable_properties(node)
# 第一次调用会解析并缓存，后续调用直接返回缓存结果
```

### 2. 优化的类型转换
TypeConverter 提供了高性能的类型转换：
- **预编译转换逻辑**：避免运行时类型判断开销
- **兼容性矩阵**：快速查找类型兼容性
- **边界检查优化**：高效的数值范围验证

### 3. 批量操作支持
PropertyManager 支持批量属性操作：
```gdscript
# 批量设置属性，减少节点访问次数
var properties_to_set = {"health": 100, "mana": 50, "level": 5}
var results = PropertyManager.set_properties_batch(node, properties_to_set)
```

### 4. 内存管理优化
- **RefCounted 设计**：自动内存管理
- **智能缓存清理**：防止内存泄漏
- **延迟计算**：按需计算复杂信息

## 🛡️ 使用通用类的安全保障

### 1. 属性访问控制
PropertyManager 提供了完善的访问控制：
- **严格验证**：自动验证属性可写性和访问权限
- **私有属性保护**：防止访问内部和私有属性
- **节点有效性检查**：确保目标节点有效且可访问

```gdscript
# PropertyManager 自动处理访问控制
var is_writable = PropertyManager.is_property_writable(node, "internal_property")
# 自动检查属性是否可访问和可写
```

### 2. 类型安全保障
TypeConverter 提供了类型安全的转换：
- **安全转换**：所有转换都有边界检查和错误处理
- **类型注入防护**：防止恶意类型注入
- **值范围验证**：确保转换后的值在有效范围内

### 3. 统一错误处理
通用类提供了统一的错误处理机制：
- **详细错误信息**：包含具体的错误原因和修复建议
- **优雅降级**：转换失败时的安全回退策略
- **日志集成**：与 BricksLogger 完全集成

```gdscript
# 统一的错误处理
var result = PropertyManager.set_property_safe(node, property, value)
if not result.success:
    _log_error("设置失败: " + result.error_message)
    # result 包含详细的错误信息和修复建议
```

## 📈 使用通用类的扩展性设计

### 1. 插件化架构
通用类采用了插件化设计，支持轻松扩展：

**自定义类型转换器**
```gdscript
# 扩展 TypeConverter 支持自定义类型
TypeConverter.register_custom_converter(MyCustomType, func(value):
    return custom_conversion_logic(value)
)
```

**自定义属性过滤器**
```gdscript
# 扩展 PropertyManager 支持自定义过滤器
PropertyManager.register_filter("my_filter", func(prop_info):
    return prop_info.name.begins_with("my_")
)
```

**自定义属性验证器**
```gdscript
# 扩展 PropertyInfo 支持自定义验证
PropertyInfo.register_validator("my_validator", func(value, prop_info):
    return custom_validation_logic(value, prop_info)
)
```

### 2. 未来功能扩展
基于通用类架构，可以轻松添加新功能：

**批量属性设置**（已内置支持）
```gdscript
# PropertyManager 已支持批量操作
var results = PropertyManager.set_properties_batch(node, properties)
```

**属性动画支持**
```gdscript
# 基于 PropertyInfo 的动画系统
var prop_info = PropertyManager.find_property(node, "position")
AnimationSystem.animate_property(node, prop_info, target_value, duration)
```

**属性绑定系统**
```gdscript
# 基于通用类的属性绑定
PropertyBindingSystem.bind(source_node, "health", target_node, "health_bar.value")
```

### 3. 向后兼容性
通用类设计保证了向后兼容性：
- **版本管理**：内置版本检查和兼容性处理
- **渐进式升级**：支持旧代码的平滑迁移
- **弃用警告**：为过时的功能提供清晰的迁移路径

## 🎯 基于通用类的实现优先级

### 高优先级（核心功能）
1. **集成通用类**：将 PropertyInfo、TypeConverter、PropertyManager 集成到 SetPropertyValue
2. **基础属性操作**：使用 PropertyManager 实现属性发现和设置
3. **类型安全转换**：使用 TypeConverter 实现安全的类型转换

### 中优先级（增强功能）
1. **编辑器集成**：使用通用类实现动态属性列表和类型适配
2. **变量值模式**：集成变量系统与通用类的属性操作
3. **错误处理优化**：使用通用类的统一错误处理机制

### 低优先级（优化功能）
1. **性能优化**：利用通用类的缓存和批量操作功能
2. **扩展功能**：基于通用类架构添加高级特性
3. **测试覆盖**：为通用类集成编写完整的测试用例

## 🚀 实现优势总结

使用通用类架构的 SetPropertyValue 指令具有以下优势：

### 1. 代码复用
- **减少重复**：属性操作逻辑可在多个指令中复用
- **一致性**：统一的属性操作接口和行为
- **维护性**：集中管理属性相关功能

### 2. 功能完整性
- **全面支持**：支持所有 Godot 属性类型
- **安全保障**：内置的类型安全和访问控制
- **性能优化**：智能缓存和批量操作

### 3. 扩展性
- **插件化**：支持自定义扩展和插件
- **未来兼容**：为未来功能扩展预留接口
- **向后兼容**：保证现有代码的平滑迁移

这个基于通用类的实现方案提供了一个完整、安全、高效且高度可扩展的节点属性设置解决方案，充分发挥了 Bricks 插件系统的架构优势。