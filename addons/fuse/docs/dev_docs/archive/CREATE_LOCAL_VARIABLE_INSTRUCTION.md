# CreateLocalVariableInstruction 设计文档

## 概述

`CreateLocalVariableInstruction` 是一个基于 BaseInstruction 的自定义指令，用于创建指定类型的局部变量。该指令充分利用了新的 VariableType 枚举系统，提供类型安全的变量创建功能。

## 指令功能

### 核心功能
- 创建指定类型的局部变量
- 支持所有 VariableType 枚举类型
- 自动验证参数有效性
- 将变量添加到执行上下文
- 提供详细的执行反馈

### 主要特性
- **类型安全**：使用 VariableType 枚举确保类型正确性
- **参数验证**：完整的输入验证机制
- **动态资源名称**：实时显示变量配置信息
- **错误处理**：统一的错误处理和反馈
- **执行上下文集成**：自动将创建的变量添加到上下文

## 指令参数

### 必需参数

#### variable_name: String
- **描述**：变量的名称
- **要求**：不能为空，符合变量命名规范
- **示例**：`"player_health"`, `"score_counter"`, `"is_game_paused"`

#### variable_type: BaseVariable.VariableType
- **描述**：变量的类型，使用新的枚举系统
- **要求**：必须为有效的 VariableType 枚举值
- **示例**：`BaseVariable.VariableType.FLOAT`, `BaseVariable.VariableType.BOOL`

#### default_value: Variant
- **描述**：变量的默认值
- **要求**：必须与指定类型兼容
- **示例**：`100.0`, `true`, `"Hello World"`

### 可选参数

#### description: String
- **描述**：变量的描述信息
- **默认值**：空字符串
- **用途**：用于文档和调试

## 使用示例

### 基础使用

```gdscript
# 创建浮点数变量
var instruction = CreateLocalVariableInstruction.new()
instruction.variable_name = "player_speed"
instruction.variable_type = BaseVariable.VariableType.FLOAT
instruction.default_value = 5.5

# 执行指令
var context = ExecutionContext.new()
instruction.execute(context)
```

### 创建不同类型变量

```gdscript
# 创建整数变量
var int_instruction = CreateLocalVariableInstruction.new()
int_instruction.variable_name = "player_score"
int_instruction.variable_type = BaseVariable.VariableType.INT
int_instruction.default_value = 0

# 创建布尔变量
var bool_instruction = CreateLocalVariableInstruction.new()
bool_instruction.variable_name = "is_player_alive"
bool_instruction.variable_type = BaseVariable.VariableType.BOOL
bool_instruction.default_value = true

# 创建字符串变量
var string_instruction = CreateLocalVariableInstruction.new()
string_instruction.variable_name = "player_name"
string_instruction.variable_type = BaseVariable.VariableType.STRING
string_instruction.default_value = "Player"

# 创建向量变量
var vector_instruction = CreateLocalVariableInstruction.new()
vector_instruction.variable_name = "player_position"
vector_instruction.variable_type = BaseVariable.VariableType.VECTOR2
vector_instruction.default_value = Vector2(0, 0)
```

### 批量创建

```gdscript
func create_game_variables(context: ExecutionContext):
    var variables_to_create = [
        {
            "name": "player_health",
            "type": BaseVariable.VariableType.FLOAT,
            "value": 100.0,
            "description": "玩家生命值"
        },
        {
            "name": "player_score",
            "type": BaseVariable.VariableType.INT,
            "value": 0,
            "description": "玩家分数"
        },
        {
            "name": "player_level",
            "type": BaseVariable.VariableType.INT,
            "value": 1,
            "description": "玩家等级"
        }
    ]
    
    for var_data in variables_to_create:
        var instruction = CreateLocalVariableInstruction.new()
        instruction.variable_name = var_data.name
        instruction.variable_type = var_data.type
        instruction.default_value = var_data.value
        instruction.description = var_data.description
        
        instruction.execute(context)
```

## 执行流程

### 1. 参数验证
```gdscript
func validate() -> Array[String]:
    var errors = super.validate()
    
    # 验证变量名称
    if variable_name.is_empty():
        errors.append("变量名称不能为空")
    elif not _is_valid_variable_name(variable_name):
        errors.append("变量名称包含无效字符")
    
    # 验证类型和默认值兼容性
    if not _is_type_value_compatible(variable_type, default_value):
        errors.append("默认值与指定类型不兼容")
    
    return errors
```

### 2. 变量创建
```gdscript
func _create_variable() -> BaseVariable:
    var variable = BaseVariable.create_typed(
        variable_name,
        default_value,
        variable_type,
        BaseVariable.VariableScope.LOCAL
    )
    
    # 设置描述（如果提供）
    if not description.is_empty():
        # 可以通过自定义属性或元数据存储描述
        pass
    
    return variable
```

### 3. 上下文集成
```gdscript
func _add_to_context(variable: BaseVariable, context: ExecutionContext):
    if context and context.has_method("add_variable"):
        context.add_variable(variable_name, variable)
        _log_info("变量已添加到上下文: %s" % variable_name)
    else:
        _log_warning("执行上下文不支持变量添加")
```

## 错误处理

### 常见错误类型

1. **参数验证错误**
   - 变量名称为空或无效
   - 类型与默认值不兼容

2. **上下文错误**
   - 执行上下文不可用
   - 变量名称冲突

3. **系统错误**
   - 变量创建失败
   - 内存不足

### 错误处理示例

```gdscript
func execute(context: ExecutionContext):
    _start_execution(context)
    
    # 验证参数
    var errors = validate()
    if not errors.is_empty():
        set_error("参数验证失败: " + ", ".join(errors))
        finished.emit()
        return
    
    # 尝试创建变量
    try:
        _created_variable = _create_variable()
        if not _created_variable:
            set_error("变量创建失败")
            finished.emit()
            return
        
        _add_to_context(_created_variable, context)
        _log_info("成功创建变量: %s (%s)" % [variable_name, BaseVariable._get_type_name(variable_type)])
        _on_execution_completed()
        
    except:
        set_error("变量创建过程中发生异常", FuseError.ErrorType.RUNTIME_ERROR)
        finished.emit()
```

## 资源名称更新

### 动态名称格式

指令会根据参数动态更新资源名称，提供直观的编辑器体验：

```gdscript
func _update_resource_name():
    var parts = []
    
    # 基础信息
    parts.append("创建变量")
    
    # 变量名称
    if not variable_name.is_empty():
        parts.append(variable_name)
    else:
        parts.append("未命名")
    
    # 类型信息
    parts.append("(%s)" % BaseVariable._get_type_name(variable_type))
    
    # 默认值（截断显示）
    if default_value != null:
        var value_str = str(default_value)
        if value_str.length() > 15:
            value_str = value_str.substr(0, 12) + "..."
        parts.append("= %s" % value_str)
    
    # 组合最终名称
    resource_name = " ".join(parts)
```

### 示例输出

- `创建变量 player_health (FLOAT) = 100.0`
- `创建变量 score_counter (INT) = 0`
- `创建变量 is_active (BOOL) = true`

## 性能优化

### 1. 类型缓存
```gdscript
# 缓存类型名称避免重复计算
static var _type_names: Dictionary = {}

func _get_cached_type_name(type: BaseVariable.VariableType) -> String:
    if not _type_names.has(type):
        _type_names[type] = BaseVariable._get_type_name(type)
    return _type_names[type]
```

### 2. 批量操作支持
```gdscript
# 支持批量创建变量
static func create_batch(context: ExecutionContext, variable_configs: Array) -> Array[BaseVariable]:
    var variables: Array[BaseVariable] = []
    
    for config in variable_configs:
        var instruction = CreateLocalVariableInstruction.new()
        instruction.variable_name = config.name
        instruction.variable_type = config.type
        instruction.default_value = config.value
        
        instruction.execute(context)
        if instruction.is_completed():
            variables.append(instruction._created_variable)
    
    return variables
```

## 测试和验证

### 单元测试

```gdscript
func test_instruction_creation():
    var instruction = CreateLocalVariableInstruction.new()
    
    # 测试参数设置
    instruction.variable_name = "test_var"
    instruction.variable_type = BaseVariable.VariableType.INT
    instruction.default_value = 42
    
    # 验证资源名称
    assert("test_var" in instruction.resource_name)
    assert("INT" in instruction.resource_name)
    assert("42" in instruction.resource_name)

func test_type_validation():
    var instruction = CreateLocalVariableInstruction.new()
    
    # 测试有效组合
    instruction.variable_name = "valid_var"
    instruction.variable_type = BaseVariable.VariableType.STRING
    instruction.default_value = "test"
    assert(instruction.validate().is_empty())
    
    # 测试无效组合
    instruction.variable_type = BaseVariable.VariableType.INT
    instruction.default_value = "not_a_number"
    assert(not instruction.validate().is_empty())
```

### 集成测试

```gdscript
func test_context_integration():
    var context = ExecutionContext.new()
    var instruction = CreateLocalVariableInstruction.new()
    
    instruction.variable_name = "context_test"
    instruction.variable_type = BaseVariable.VariableType.BOOL
    instruction.default_value = true
    
    # 执行指令
    instruction.execute(context)
    
    # 验证变量已添加到上下文
    assert(context.has_variable("context_test"))
    var variable = context.get_variable("context_test")
    assert(variable != null)
    assert(variable.get_value() == true)
```

## 最佳实践总结

### 使用建议

1. **命名规范**：使用清晰、描述性的变量名称
2. **类型选择**：根据实际用途选择合适的变量类型
3. **默认值**：提供合理的默认值
4. **错误处理**：始终检查指令执行结果
5. **批量操作**：对于多个变量，使用批量创建方法

### 避免的反模式

1. **硬编码类型**：避免使用数字类型，使用枚举
2. **忽略验证**：不要忽略参数验证错误
3. **重复名称**：避免在同一上下文中创建同名变量
4. **类型不匹配**：确保默认值与指定类型兼容

## 扩展可能性

### 未来增强

1. **全局变量支持**：扩展支持创建全局变量
2. **变量模板**：预定义常用变量配置
3. **自动类型推断**：根据默认值自动推断类型
4. **变量分组**：支持变量分组和批量管理
5. **持久化选项**：支持变量持久化配置

这个指令设计充分利用了新的 VariableType 枚举系统，提供了类型安全、用户友好的变量创建功能，同时遵循了 BaseInstruction 的所有最佳实践。