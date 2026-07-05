# RunTargetNodeFunction 指令设计文档

## 概述

`RunTargetNodeFunction` 指令允许用户动态调用目标节点的公开方法，支持参数配置和返回值处理。该指令基于现有的 `SetPropertyValue` 和 `EventOnTargetSignalEmit` 的设计模式，提供类似的编辑器体验和功能完整性。

## 需求分析

### 核心功能需求

1. **目标节点选择**：使用 NodePath 选择目标节点
2. **方法发现**：自动发现目标节点的公开方法
3. **动态方法列表**：根据目标节点生成方法下拉列表
4. **参数配置**：根据选中方法动态生成参数配置界面
5. **方法调用**：安全调用目标方法并处理返回值

### 技术需求

1. **编辑器集成**：提供直观的编辑器界面
2. **类型安全**：确保参数类型匹配和方法存在性
3. **错误处理**：完善的错误检查和用户反馈
4. **性能优化**：高效的方法发现和缓存机制
5. **扩展性**：支持未来功能扩展

## 架构设计

### 类结构设计

```gdscript
@tool
@icon("res://addons/bricks/icons/instruction.svg")
extends BaseInstruction
class_name RunTargetNodeFunction
```

### 核心属性

```gdscript
## 节点配置
var target_node: NodePath = "":
    set(value):
        target_node = value
        _update_target_node_info()
        _update_resource_name()
        notify_property_list_changed()

## 方法配置
var target_function: String = "":
    set(value):
        target_function = value
        _update_function_info()
        _update_resource_name()
        notify_property_list_changed()

## 参数配置
var function_args: Array = []:
    set(value):
        function_args = value
        _update_resource_name()

## 返回值处理
var store_result: bool = false:
    set(value):
        store_result = value
        _update_resource_name()

var result_variable_name: String = "":
    set(value):
        result_variable_name = value
        _update_resource_name()

var result_variable_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
    set(value):
        result_variable_scope = value
        _update_resource_name()
```

### 运行时状态

```gdscript
var _target_node_instance: Node = null
var _available_functions: Array[MethodInfo] = []
var _current_function_info: MethodInfo = null
var _function_call_result: Variant = null
```

## 功能模块设计

### 1. 方法发现模块

#### FunctionManager 通用类

```gdscript
# 新增通用类：addons/bricks/utils/function_manager.gd
class_name FunctionManager
extends RefCounted

## 获取节点的可调用方法
static func get_callable_methods(node: Node) -> Array[MethodInfo]

## 获取方法的参数信息
static func get_method_parameters(method_info: MethodInfo) -> Array[PropertyInfo]

## 验证方法可调用性
static func is_method_callable(node: Node, method_name: String) -> bool

## 安全调用方法
static func call_method_safe(node: Node, method_name: String, args: Array) -> Dictionary
```

#### 方法信息封装

```gdscript
# 新增通用类：addons/bricks/utils/function_info.gd
class_name FunctionInfo extends RefCounted

var method_name: String
var method_info: MethodInfo
var parameter_infos: Array[PropertyInfo]
var return_type: int
var is_callable: bool

## 获取方法显示名称
func get_display_name() -> String

## 获取参数属性列表
func get_parameter_property_list() -> Array[Dictionary]

## 验证参数兼容性
func validate_arguments(args: Array) -> bool
```

### 2. 动态属性列表生成

```gdscript
func _get_property_list() -> Array[Dictionary]:
    var properties: Array[Dictionary] = []
    
    # 目标节点选择
    properties.append({
        "name": "target_node",
        "type": TYPE_NODE_PATH,
        "hint": PROPERTY_HINT_NODE_PATH_VALID_TYPES,
        "hint_string": "Node",
        "default": NodePath("")
    })
    
    # 方法选择
    var method_names = _get_method_names()
    properties.append({
        "name": "target_function",
        "type": TYPE_STRING,
        "hint": PROPERTY_HINT_ENUM,
        "hint_string": ",".join(method_names),
        "default": ""
    })
    
    # 动态参数配置
    if _current_function_info:
        var param_properties = _get_parameter_properties()
        properties.append_array(param_properties)
    
    # 返回值处理配置
    properties.append({
        "name": "store_result",
        "type": TYPE_BOOL,
        "hint": PROPERTY_HINT_NONE,
        "default": false
    })
    
    properties.append({
        "name": "result_variable_name",
        "type": TYPE_STRING,
        "hint": PROPERTY_HINT_NONE,
        "default": ""
    })
    
    properties.append({
        "name": "result_variable_scope",
        "type": TYPE_INT,
        "hint": PROPERTY_HINT_ENUM,
        "hint_string": "Local,Global",
        "default": 0
    })
    
    return properties
```

### 3. 参数动态配置

```gdscript
func _get_parameter_properties() -> Array[Dictionary]:
    if not _current_function_info:
        return []
    
    var properties = []
    var param_infos = FunctionManager.get_method_parameters(_current_function_info)
    
    for i in range(param_infos.size()):
        var param_info = param_infos[i]
        var arg_value = function_args[i] if i < function_args.size() else param_info.get_default_value()
        
        properties.append({
            "name": "param_%d" % i,
            "type": param_info.type,
            "hint": param_info.hint,
            "hint_string": param_info.hint_string,
            "default": arg_value
        })
    
    return properties
```

### 4. 条件化属性显示

```gdscript
func _validate_property(property: Dictionary) -> void:
    # 只有选择方法后才显示参数配置
    if target_function.is_empty() and property.name.begins_with("param_"):
        property.usage = PROPERTY_USAGE_NONE
    
    # 只有启用存储结果时才显示结果变量配置
    if not store_result and property.name in ["result_variable_name", "result_variable_scope"]:
        property.usage = PROPERTY_USAGE_READ_ONLY
```

## 执行逻辑设计

### 1. 主执行流程

```gdscript
func execute(context: ExecutionContext):
    _start_execution(context)
    
    # 验证参数
    var errors = _validate_parameters()
    if not errors.is_empty():
        set_error("参数验证失败: " + ", ".join(errors))
        finished.emit()
        return
    
    # 获取目标节点
    var target = _get_target_node()
    if not target:
        set_error("无法找到目标节点: " + str(target_node))
        finished.emit()
        return
    
    # 调用方法
    var call_result = _call_target_function(target)
    if call_result.has("error"):
        set_error("方法调用失败: " + call_result.error)
        finished.emit()
        return
    
    # 处理返回值
    if store_result:
        _store_result_value(context, call_result.result)
    
    _log_info("成功调用方法: %s.%s" % [target.name, target_function])
    _on_execution_completed()
```

### 2. 安全方法调用

```gdscript
func _call_target_function(target: Node) -> Dictionary:
    if not target or target_function.is_empty():
        return {"error": "目标节点或方法名为空", "result": null}
    
    # 验证方法存在
    if not FunctionManager.is_method_callable(target, target_function):
        return {"error": "方法不存在或不可调用: " + target_function, "result": null}
    
    # 验证参数
    if not _validate_function_arguments():
        return {"error": "参数验证失败", "result": null}
    
    # 安全调用
    return FunctionManager.call_method_safe(target, target_function, function_args)
```

### 3. 返回值处理

```gdscript
func _store_result_value(context: ExecutionContext, result: Variant):
    if result_variable_name.is_empty():
        _log_warning("结果变量名为空，跳过存储")
        return
    
    # 创建或更新变量
    var result_variable = BaseVariable.create(
        result_variable_name,
        result,
        result_variable_scope
    )
    
    # 添加到上下文
    match result_variable_scope:
        BaseVariable.VariableScope.LOCAL:
            context.add_variable(result_variable_name, result_variable)
        BaseVariable.VariableScope.GLOBAL:
            var assistant = GlobalVariableAssistant.get_instance()
            if assistant:
                assistant.add_global_variable(result_variable_name, result_variable)
    
    _log_info("结果已存储到变量: %s" % result_variable_name)
```

## 编辑器体验设计

### 1. 渐进式配置流程

1. **选择目标节点** → 刷新可用方法列表
2. **选择目标方法** → 刷新参数配置界面
3. **配置参数值** → 实时验证类型兼容性
4. **配置返回值处理** → 可选存储到变量

### 2. 智能默认值

```gdscript
func _get_default_argument_value(param_info: PropertyInfo) -> Variant:
    # 根据参数类型提供智能默认值
    match param_info.type:
        TYPE_STRING:
            return ""
        TYPE_INT:
            return 0
        TYPE_FLOAT:
            return 0.0
        TYPE_BOOL:
            return false
        TYPE_VECTOR2:
            return Vector2.ZERO
        TYPE_VECTOR3:
            return Vector3.ZERO
        TYPE_COLOR:
            return Color.WHITE
        _:
            return null
```

### 3. 实时验证反馈

```gdscript
func _validate_function_arguments() -> bool:
    if not _current_function_info:
        return false
    
    var param_infos = FunctionManager.get_method_parameters(_current_function_info)
    
    # 检查参数数量
    if function_args.size() != param_infos.size():
        _log_warning("参数数量不匹配: 期望 %d，实际 %d" % [
            param_infos.size(), function_args.size()
        ])
        return false
    
    # 检查每个参数类型
    for i in range(param_infos.size()):
        var param_info = param_infos[i]
        var arg_value = function_args[i]
        
        if not TypeConverter.is_compatible(typeof(arg_value), param_info.type):
            _log_warning("参数 %d 类型不匹配: 期望 %s，实际 %s" % [
                i, type_string(param_info.type), type_string(typeof(arg_value))
            ])
            return false
    
    return true
```

## 错误处理策略

### 1. 分层错误处理

```gdscript
enum ErrorType {
    CONFIGURATION_ERROR,    # 配置错误
    VALIDATION_ERROR,       # 验证错误
    RUNTIME_ERROR,          # 运行时错误
    PERMISSION_ERROR        # 权限错误
}
```

### 2. 详细错误信息

```gdscript
func _get_detailed_error_message() -> String:
    var errors = []
    
    if target_node.is_empty():
        errors.append("目标节点路径不能为空")
    
    if target_function.is_empty():
        errors.append("目标方法名不能为空")
    elif _target_node_instance and not FunctionManager.is_method_callable(_target_node_instance, target_function):
        errors.append("方法 '%s' 在节点 '%s' 中不存在或不可调用" % [
            target_function, _target_node_instance.get_class()
        ])
    
    if not _validate_function_arguments():
        errors.append("函数参数验证失败")
    
    return "\n".join(errors) if not errors.is_empty() else ""
```

## 性能优化策略

### 1. 缓存机制

```gdscript
var _method_cache: Dictionary = {}
var _cache_valid: bool = false

func _get_available_methods() -> Array[MethodInfo]:
    if _cache_valid and not _method_cache.is_empty():
        return _method_cache.values()
    
    _refresh_method_cache()
    return _method_cache.values()

func _refresh_method_cache():
    if not _target_node_instance:
        return
    
    _method_cache.clear()
    var methods = FunctionManager.get_callable_methods(_target_node_instance)
    
    for method in methods:
        _method_cache[method.name] = method
    
    _cache_valid = true
```

### 2. 延迟加载

```gdscript
func _update_function_info():
    _current_function_info = null
    
    if target_function.is_empty() or _method_cache.is_empty():
        return
    
    # 延迟加载详细信息
    if _method_cache.has(target_function):
        _current_function_info = _method_cache[target_function]
        _update_parameter_defaults()
```

## 扩展性设计

### 1. 插件化架构

```gdscript
# 支持自定义方法调用器
var custom_method_callers: Array[Callable] = []

func register_custom_caller(callable: Callable):
    custom_method_callers.append(callable)

func _call_with_custom_callers(target: Node, method: String, args: Array) -> Dictionary:
    for caller in custom_method_callers:
        var result = caller.call(target, method, args)
        if result.has("success") and result.success:
            return result
    
    # 回退到默认调用
    return FunctionManager.call_method_safe(target, method, args)
```

### 2. 事件钩子

```gdscript
# 方法调用前后的事件钩子
signal before_method_call(target: Node, method: String, args: Array)
signal after_method_call(target: Node, method: String, args: Array, result: Variant)

func _call_target_function(target: Node) -> Dictionary:
    before_method_call.emit(target, target_function, function_args)
    
    var result = FunctionManager.call_method_safe(target, target_function, function_args)
    
    after_method_call.emit(target, target_function, function_args, result.result)
    
    return result
```

## 测试策略

### 1. 单元测试

```gdscript
# 测试用例覆盖
- 目标节点发现测试
- 方法列表生成测试
- 参数验证测试
- 方法调用测试
- 返回值处理测试
- 错误处理测试
```

### 2. 集成测试

```gdscript
# 与现有系统集成测试
- 与 BaseVariable 系统集成
- 与 ExecutionContext 集成
- 与 GlobalVariableAssistant 集成
- 与 PropertyManager 集成
```

## 实现优先级

### 高优先级（核心功能）
1. **基础架构搭建**：创建指令类和基础属性
2. **方法发现实现**：实现 FunctionManager 和 FunctionInfo
3. **动态属性列表**：实现编辑器界面生成
4. **基础执行逻辑**：实现安全方法调用

### 中优先级（增强功能）
1. **参数验证**：实现类型安全的参数验证
2. **返回值处理**：实现结果存储到变量
3. **错误处理**：实现完善的错误检查和反馈
4. **性能优化**：实现缓存和延迟加载

### 低优先级（扩展功能）
1. **高级特性**：异步调用、批量调用等
2. **插件系统**：支持自定义方法调用器
3. **事件钩子**：方法调用前后的事件处理
4. **调试工具**：方法调用日志和性能监控

## 风险评估

### 技术风险
1. **方法调用安全性**：需要确保只调用安全的公开方法
2. **类型转换复杂性**：参数类型转换可能引入错误
3. **性能影响**：方法发现可能影响编辑器性能

### 缓解策略
1. **白名单机制**：只允许调用预定义的安全方法
2. **类型验证增强**：多层类型检查和转换
3. **缓存优化**：智能缓存和延迟加载

## 总结

`RunTargetNodeFunction` 指令将为 bricks 插件系统提供强大的动态方法调用能力，通过借鉴现有成功的设计模式，确保一致的用户体验和代码质量。该指令将显著扩展系统的灵活性和可编程性，同时保持类型安全和错误处理的完整性。

通过分阶段实现，可以确保核心功能的稳定性和扩展功能的可靠性，为用户提供强大而易用的节点方法调用解决方案。