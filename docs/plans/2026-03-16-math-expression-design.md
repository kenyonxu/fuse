# MathExpression 指令设计文档

**日期**: 2026-03-16
**状态**: 待实现
**系统**: Bricks 可视化编程插件

## 概述

`MathExpression` 是一个新的 Bricks 指令，用于执行包含变量引用的数学表达式。它解决了现有 `MathOperation` 指令只能执行单一运算的限制，允许用户在一个表达式中进行复杂计算，提升可用性和运行时性能。

## 核心设计决策

### 1. 变量语法

| 语法 | 说明 | 示例 |
|------|------|------|
| `{local:var_name}` | 局部变量 | `{local:damage}` |
| `{scope:var_name}` | 作用域变量 | `{scope:health}` |
| `{global:var_name}` | 全局变量 | `{global:max_hp}` |

**必须显式指定作用域**，无简写语法。

### 2. 支持的运算

| 类别 | 内容 |
|------|------|
| 基础运算 | `+ - * / %` (加减乘除取模) |
| 括号优先级 | `()` 控制运算顺序 |
| 数学函数 | `abs, min, max, round, floor, ceil, sqrt, pow, clamp` |

### 3. 类型支持

**输入类型:**
- 数值: `int`, `float`
- 向量: `Vector2`, `Vector3`

**向量字面量语法:**
- `vec2(x, y)` → 创建 Vector2
- `vec3(x, y, z)` → 创建 Vector3

**输出类型:** 用户选择
- `Float` - 浮点数
- `Int` - 整数
- `Vector2` - 2D 向量
- `Vector3` - 3D 向量

### 4. SCOPE 来源配置

SCOPE 作用域的来源在属性面板统一配置（与现有 MathOperation 一致）：
- `NEAREST` - 最近的作用域容器
- `CUSTOM_ID` - 指定 scope_id
- `TRIGGER_SCOPE` - Trigger 节点
- `TARGET_NODE` - Target 节点

### 5. 解析引擎

使用 Godot 内置 `Expression` 类进行解析和执行。

## 属性结构

```gdscript
# 表达式配置
@export var expression: String = ""

# 输出类型配置
enum OutputType { FLOAT, INT, VECTOR2, VECTOR3 }
@export var output_type: OutputType = OutputType.FLOAT

# SCOPE 来源配置（当使用 {scope:xxx} 时生效）
@export var scope_source: ScopeSource = ScopeSource.NEAREST
@export var scope_id: String = ""

# 输出配置
@export var save_to_variable: String = ""
@export var save_to_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL
@export var save_scope_source: ScopeSource = ScopeSource.NEAREST
@export var save_scope_id: String = ""

# 插入变量辅助（编辑器 UI）
@export_storage var insert_var_name: String = ""
@export_storage var insert_var_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL
```

## 执行流程

```
1. 验证表达式
   ├─ 检查表达式非空
   └─ 检查输出变量名非空

2. 解析变量引用
   ├─ 用正则匹配 {local:xxx}, {scope:xxx}, {global:xxx}
   └─ 验证变量名格式有效

3. 获取变量值
   ├─ local: 从 context.local_variables 获取
   ├─ scope: 通过 VariableOperations + scope_source 获取
   └─ global: 通过 VariableOperations 获取

4. 替换表达式
   └─ 将 {scope:hp} 替换为实际值 "100"

5. 执行表达式
   ├─ 使用 Godot Expression.parse()
   └─ 使用 Expression.execute()

6. 类型转换
   └─ 根据用户选择的输出类型转换结果

7. 保存结果
   └─ 根据输出配置保存到指定作用域

8. 完成执行
   └─ 发出 finished 信号
```

## 类型转换逻辑

```gdscript
func _convert_result(raw: Variant, type: OutputType) -> Variant:
    match type:
        OutputType.FLOAT: return float(raw)
        OutputType.INT: return int(raw)
        OutputType.VECTOR2:
            if raw is Vector3: return Vector2(raw.x, raw.y)
            return Vector2(raw)
        OutputType.VECTOR3:
            if raw is Vector2: return Vector3(raw.x, raw.y, 0)
            return Vector3(raw)
    return raw
```

## 表达式解析实现细节

### 变量引用正则表达式

```gdscript
# 匹配 {local:xxx}, {scope:xxx}, {global:xxx}
const VAR_PATTERN := r"\{(local|scope|global):([a-zA-Z_][a-zA-Z0-9_]*)\}"
```

### 向量字面量注入

```gdscript
# 匹配 vec2(x, y) 和 vec3(x, y, z)
const VEC2_PATTERN := r"vec2\s*\(\s*([^,]+)\s*,\s*([^)]+)\s*\)"
const VEC3_PATTERN := r"vec3\s*\(\s*([^,]+)\s*,\s*([^,]+)\s*,\s*([^)]+)\s*\)"

func _inject_vector_functions() -> Dictionary:
    # 返回可供 Expression.execute() 使用的函数映射
    return {
        "vec2": func(x, y): return Vector2(float(x), float(y)),
        "vec3": func(x, y, z): return Vector3(float(x), float(y), float(z)),
        # 数学函数
        "abs": func(v): return abs(v),
        "min": func(a, b): return min(a, b),
        "max": func(a, b): return max(a, b),
        "round": func(v): return round(v),
        "floor": func(v): return floor(v),
        "ceil": func(v): return ceil(v),
        "sqrt": func(v): return sqrt(v),
        "pow": func(b, e): return pow(b, e),
        "clamp": func(v, lo, hi): return clamp(v, lo, hi),
    }

func _evaluate_expression(expr: String) -> Variant:
    var expression := Expression.new()
    var func_names := ["vec2", "vec3", "abs", "min", "max", "round", "floor", "ceil", "sqrt", "pow", "clamp"]

    var parse_error := expression.parse(expr, func_names)
    if parse_error != OK:
        set_error_localized("BRICKS_ERROR_EXPRESSION_PARSE", ...)
        return null

    var func_map := _inject_vector_functions()
    var func_values := func_names.map(func(name): return func_map[name])

    var result = expression.execute(func_values, null, false)
    if expression.has_execute_failed():
        set_error_localized("BRICKS_ERROR_EXPRESSION_EXECUTE", ...)
        return null

    return result
```

### 变量值特殊字符处理

```gdscript
func _escape_value_for_expression(value: Variant) -> String:
    # 数值和向量直接转换
    if value is int or value is float:
        return str(value)
    if value is Vector2:
        return "vec2(%s, %s)" % [value.x, value.y]
    if value is Vector3:
        return "vec3(%s, %s, %s)" % [value.x, value.y, value.z]

    # 其他类型尝试转为数值
    var as_float := TypeConverter.safe_convert_to_float(value)
    return str(as_float)
```

### 向量类型混合运算规则

| 运算 | 结果类型 | 说明 |
|------|----------|------|
| Vector2 + Vector2 | Vector2 | 逐分量相加 |
| Vector3 + Vector3 | Vector3 | 逐分量相加 |
| Vector2 + Vector3 | ❌ 错误 | 类型不兼容，需显式转换 |
| Vector2 * float | Vector2 | 标量乘法 |
| float * Vector2 | Vector2 | 标量乘法（交换律） |
| Vector2 * Vector2 | Vector2 | 逐分量相乘 |

**注意**: Godot Expression 不支持向量类型的隐式转换，混合类型运算会在执行时报错。用户需要确保类型一致。

## UI 设计

### 属性面板布局

```
┌─────────────────────────────────────────┐
│ Expression                              │
│ ┌─────────────────────────────────────┐ │
│ │ ({local:damage} + {scope:base}) * 0.5│ │
│ └─────────────────────────────────────┘ │
│                                         │
│ ── 插入变量 ──                          │
│ 变量名:  [damage     ]                  │
│ 作用域:  [Local ▼]                      │
│         [插入]                          │
│                                         │
│ ── 输出类型 ──                          │
│ Output Type: [Float ▼]                 │
│                                         │
│ ── Scope 来源 (当使用 {scope:xxx} 时) ── │
│ Scope Source: [Nearest ▼]              │
│                                         │
│ ── 输出配置 ──                          │
│ Save To:       [result_var    ]         │
│ Save Scope:    [Local ▼]               │
└─────────────────────────────────────────┘
```

### 插入变量交互

1. 用户在"变量名"输入框输入变量名
2. 选择作用域（Local/Scope/Global）
3. 点击"插入"按钮
4. `{scope:var_name}` 被插入到表达式光标位置

## 错误处理

| 错误场景 | 处理方式 | 本地化键 |
|----------|----------|----------|
| 表达式为空 | 验证失败，不执行 | `BRICKS_ERROR_EXPRESSION_EMPTY` |
| 输出变量名为空 | 验证失败，不执行 | `BRICKS_ERROR_VAR_NAME_EMPTY` |
| 变量语法错误 | 如 `{local:}` 或 `{xxx:var}` | `BRICKS_ERROR_INVALID_VAR_SYNTAX` |
| 变量不存在 | 返回警告，使用默认值 0 | `BRICKS_WARN_VAR_NOT_FOUND` |
| 表达式解析失败 | Expression.parse() 返回错误 | `BRICKS_ERROR_EXPRESSION_PARSE` |
| 表达式执行失败 | 如除零、类型错误 | `BRICKS_ERROR_EXPRESSION_EXECUTE` |

## 本地化

### 文件位置

`addons/bricks/localization/translations.csv`

### 新增条目

```csv
# 指令元数据
BRICKS_INSTRUCTION_MATH_EXPRESSION_NAME,数学表达式,Math Expression
BRICKS_INSTRUCTION_MATH_EXPRESSION_DESC,执行数学表达式并保存结果，支持数值和向量运算,Execute a math expression and save the result, supports numeric and vector operations

# 错误消息
BRICKS_ERROR_EXPRESSION_EMPTY,表达式不能为空,Expression cannot be empty
BRICKS_ERROR_INVALID_VAR_SYNTAX,无效的变量语法: {syntax},Invalid variable syntax: {syntax}
BRICKS_ERROR_EXPRESSION_PARSE,表达式解析失败: {error},Expression parsing failed: {error}
BRICKS_ERROR_EXPRESSION_EXECUTE,表达式执行失败: {error},Expression execution failed: {error}

# 警告消息
BRICKS_WARN_VAR_NOT_FOUND,变量 {var} 不存在，使用默认值 0,Variable {var} not found, using default value 0
```

## 示例表达式

```
# 数值运算
{local:damage} * 2 + {scope:bonus}

# 使用函数
clamp({local:hp} - {local:damage}, 0, {global:max_hp})

# 向量运算
{local:position} + vec2(10, 0) * {local:speed}

# 复杂表达式
({local:a} + {local:b}) / max({local:c}, 1) * {global:multiplier}
```

## 文件清单

| 操作 | 文件路径 |
|------|----------|
| 新增 | `addons/bricks/instructions/math/math_expression.gd` |
| 修改 | `addons/bricks/localization/translations.csv` |

## 实现步骤

| 步骤 | 任务 | 复杂度 |
|------|------|--------|
| 1 | 创建 `math_expression.gd` 基础结构 | 低 |
| 2 | 实现变量正则解析与替换 | 中 |
| 3 | 实现表达式执行与错误处理 | 中 |
| 4 | 实现类型转换逻辑 | 低 |
| 5 | 实现结果保存逻辑 | 低 |
| 6 | 添加编辑器 UI（插入变量区域） | 中 |
| 7 | 添加本地化字符串 | 低 |
| 8 | 编写单元测试 | 中 |

### 编辑器 UI 实现说明

插入变量功能通过 `EditorInspectorPlugin` 实现：

```gdscript
# 在 BricksEditorPlugin 中注册
func _init():
    _inspector_plugin = MathExpressionInspectorPlugin.new()
    add_inspector_plugin(_inspector_plugin)

# MathExpressionInspectorPlugin
class MathExpressionInspectorPlugin extends EditorInspectorPlugin:
    func _can_handle(object: Object) -> bool:
        return object is MathExpression

    func _parse_begin(object: Object) -> void:
        var math_expr := object as MathExpression
        var hbox := HBoxContainer.new()

        var name_edit := LineEdit.new()
        name_edit.placeholder_text = "变量名"

        var scope_opt := OptionButton.new()
        scope_opt.add_item("Local", BaseVariable.VariableScope.LOCAL)
        scope_opt.add_item("Scope", BaseVariable.VariableScope.SCOPE)
        scope_opt.add_item("Global", BaseVariable.VariableScope.GLOBAL)

        var insert_btn := Button.new()
        insert_btn.text = "插入"

        insert_btn.pressed.connect(func():
            var var_name := name_edit.text
            if var_name.is_empty():
                return
            var scope_idx := scope_opt.get_selected_id()
            var prefix := ["local", "scope", "global"][scope_idx]
            var var_ref := "{%s:%s}" % [prefix, var_name]
            # 追加到表达式末尾（完整实现需要光标位置追踪）
            math_expr.expression += var_ref
            name_edit.text = ""
        )

        hbox.add_child(name_edit)
        hbox.add_child(scope_opt)
        hbox.add_child(insert_btn)
        add_custom_control(hbox)
```

**注意**: 完整的光标位置插入需要自定义 TextEdit 控件，初始版本可简化为追加到末尾。

## 与现有 MathOperation 的对比

| 特性 | MathOperation | MathExpression |
|------|---------------|----------------|
| 运算数量 | 单一运算 | 复杂表达式 |
| 变量数量 | 2 个操作数 | 任意数量 |
| 性能 | 多次执行开销 | 单次执行 |
| 可读性 | 需要链式指令 | 一行表达式 |
| 调试 | 每步可见 | 整体执行 |

---

**最后更新**: 2026-03-16
