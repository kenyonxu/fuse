# RunTargetNodeFunction 指令实现计划

## 概述

本文档详细描述了 `RunTargetNodeFunction` 指令的实现步骤，包括所有需要创建的文件和具体实现细节。

## 实现阶段

### 阶段1: 创建 FunctionManager 通用类

**文件路径**: `addons/bricks/utils/function_manager.gd`

**功能描述**: 提供方法发现、验证和安全调用的通用功能

**核心方法**:
```gdscript
# 获取节点的可调用方法
static func get_callable_methods(node: Node) -> Array[MethodInfo]

# 获取方法的参数信息
static func get_method_parameters(method_info: MethodInfo) -> Array[PropertyInfo]

# 验证方法可调用性
static func is_method_callable(node: Node, method_name: String) -> bool

# 安全调用方法
static func call_method_safe(node: Node, method_name: String, args: Array) -> Dictionary
```

**实现要点**:
- 过滤掉私有方法和内部方法（以下划线开头）
- 只返回用户可调用的公开方法
- 提供安全的参数验证和类型转换
- 包含完整的错误处理机制

### 阶段2: 创建 FunctionInfo 通用类

**文件路径**: `addons/bricks/utils/function_info.gd`

**功能描述**: 封装方法信息，提供便捷的访问接口

**核心属性**:
```gdscript
var method_name: String
var method_info: MethodInfo
var parameter_infos: Array[PropertyInfo]
var return_type: int
var is_callable: bool
```

**核心方法**:
```gdscript
# 获取方法显示名称
func get_display_name() -> String

# 获取参数属性列表
func get_parameter_property_list() -> Array[Dictionary]

# 验证参数兼容性
func validate_arguments(args: Array) -> bool
```

### 阶段3: 实现 RunTargetNodeFunction 指令核心功能

**文件路径**: `addons/bricks/instructions/run_target_node_function.gd`

**核心属性**:
```gdscript
# 节点配置
@export var target_node: NodePath = ""

# 方法配置
@export var target_function: String = ""

# 参数配置
@export var function_args: Array = []

# 返回值处理
@export var store_result: bool = false
@export var result_variable_name: String = ""
@export var result_variable_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL
```

**运行时状态**:
```gdscript
var _target_node_instance: Node = null
var _available_functions: Array[MethodInfo] = []
var _current_function_info: MethodInfo = null
var _function_call_result: Variant = null
```

### 阶段4: 实现动态属性列表和编辑器集成

**动态属性列表生成**:
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
    
    # 方法选择（动态生成）
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
    properties.append_array(_get_return_value_properties())
    
    return properties
```

**条件化属性显示**:
```gdscript
func _validate_property(property: Dictionary) -> void:
    # 只有选择方法后才显示参数配置
    if target_function.is_empty() and property.name.begins_with("param_"):
        property.usage = PROPERTY_USAGE_NONE
    
    # 只有启用存储结果时才显示结果变量配置
    if not store_result and property.name in ["result_variable_name", "result_variable_scope"]:
        property.usage = PROPERTY_USAGE_READ_ONLY
```

### 阶段5: 实现参数验证和返回值处理

**参数验证**:
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

**返回值处理**:
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

### 阶段6: 添加错误处理和性能优化

**缓存机制**:
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

**延迟加载**:
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

### 阶段7: 测试和验证

**测试文件**: `test_run_target_node_function.gd`

**测试用例**:
- 目标节点发现测试
- 方法列表生成测试
- 参数验证测试
- 方法调用测试
- 返回值处理测试
- 错误处理测试

## 文件创建清单

### 需要创建的文件

1. **`addons/bricks/utils/function_manager.gd`** - FunctionManager 通用类
2. **`addons/bricks/utils/function_info.gd`** - FunctionInfo 通用类
3. **`addons/bricks/instructions/run_target_node_function.gd`** - 主指令类
4. **`test_run_target_node_function.gd`** - 测试脚本

### 需要更新的文件

1. **`addons/bricks/plugin.gd`** - 注册新的通用类和指令类

## 实现优先级

### 高优先级（核心功能）
1. 创建 FunctionManager 通用类
2. 创建 FunctionInfo 通用类
3. 实现 RunTargetNodeFunction 指令核心功能
4. 实现动态属性列表和编辑器集成

### 中优先级（增强功能）
1. 实现参数验证和返回值处理
2. 添加错误处理和性能优化
3. 测试和验证 RunTargetNodeFunction 指令

### 低优先级（扩展功能）
1. 异步方法调用支持
2. 批量方法调用
3. 自定义方法调用器插件系统
4. 方法调用事件钩子

## 技术考虑

### 安全性
- 只允许调用公开的非私有方法
- 严格的参数类型验证
- 安全的方法调用机制

### 性能
- 智能缓存方法信息
- 延迟加载详细信息
- 避免重复的方法发现

### 用户体验
- 渐进式配置流程
- 实时验证反馈
- 智能默认值

### 扩展性
- 插件化架构
- 事件钩子机制
- 自定义方法调用器支持

## 风险评估

### 技术风险
1. **方法调用安全性**: 需要确保只调用安全的公开方法
2. **类型转换复杂性**: 参数类型转换可能引入错误
3. **性能影响**: 方法发现可能影响编辑器性能

### 缓解策略
1. **白名单机制**: 只允许调用预定义的安全方法
2. **类型验证增强**: 多层类型检查和转换
3. **缓存优化**: 智能缓存和延迟加载

## 总结

通过分阶段实现，可以确保 `RunTargetNodeFunction` 指令的稳定性和可靠性。该指令将为 bricks 插件系统提供强大的动态方法调用能力，同时保持类型安全和错误处理的完整性。

实现完成后，用户将能够：
1. 动态选择目标节点
2. 从可用方法列表中选择要调用的方法
3. 根据方法签名自动生成参数配置界面
4. 安全地调用方法并处理返回值
5. 将返回值存储到变量中供后续使用

这将显著扩展 bricks 插件系统的灵活性和可编程性。