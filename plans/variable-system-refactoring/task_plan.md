# Bricks 变量系统重构计划

**创建日期:** 2026-01-23
**目标版本:** v2.1
**优先级:** 高
**预计工作量:** 3-5 天

---

## 一、问题概述

当前 Bricks 变量系统存在以下架构不一致问题：

### 1.1 核心问题

| 问题 | 影响 | 严重程度 |
|------|------|----------|
| `get_variable()` 返回类型不一致 | 代码混乱，容易出错 | **高** |
| 局部/全局变量处理方式不同 | 学习曲线陡峭 | **高** |
| 全局变量同步到上下文导致数据重复 | 内存浪费，可能不一致 | **中** |
| 作用域命名不统一（枚举 vs 字符串） | 维护困难 | **低** |

### 1.2 具体表现

**示例 1: get_variable() 返回类型混乱**
```gdscript
// 局部变量：返回值
var local_value = context.get_variable("score")  // Variant

// 全局变量：返回对象
var global_var = context.get_variable("player_health")  // BaseVariable
var health = global_var.get_value()  // 需要额外调用
```

**示例 2: add_variable() 处理不一致**
```gdscript
// [execution_context.gd:178-189]
func add_variable(name: String, variable: BaseVariable) -> bool:
    // 局部变量：提取值，丢弃对象
    return set_variable(name, variable.value, scope_name)

    // 全局变量：保留对象
    // Assistant 直接存储 BaseVariable 对象
```

---

## 二、改进目标

### 2.1 设计原则

1. **一致性优先** - 局部和全局变量使用相同的 API
2. **向后兼容** - 现有代码无需修改即可运行
3. **性能优化** - 减少不必要的对象创建和复制
4. **类型安全** - 保持全局变量的类型检查
5. **简单明了** - API 易于理解和使用

### 2.2 目标架构

```
变量访问 API（统一接口）
├── context.get_variable(name) → Variant（总是返回值）
├── context.get_variable_object(name) → BaseVariable（返回对象，高级用法）
├── context.set_variable(name, value) → bool
└── context.has_variable(name) → bool

变量创建 API（保持不变）
├── CreateVariable 指令
└── BaseVariable.create() 工厂方法

存储层（内部实现）
├── local_variables: Dictionary[StringName, Variant]
└── GlobalVariableManager._variables: Dictionary[String, BaseVariable]
```

---

## 三、架构决策

### 决策 1: get_variable() 统一返回 Variant 值

**选项 A: 统一返回 BaseVariable 对象**
- ❌ 局部变量每次都需要包装对象（性能开销）
- ❌ 需要修改所有现有代码（破坏向后兼容）
- ✅ 类型一致

**选项 B: 统一返回 Variant 值（推荐 ✅）**
- ✅ 性能最优，无需对象创建
- ✅ 向后兼容，局部变量代码无需修改
- ✅ 简单直观
- ❌ 全局变量需要 `.get_value()` 调用（内部处理）

**决策:** 采用 **选项 B**

**实现:**
```gdscript
// ExecutionContext 中
func get_variable(name: String, default: Variant = null) -> Variant:
    // 局部变量：直接返回值
    if local_variables.has(name_key):
        return local_variables[name_key]

    // 全局变量：返回对象的值
    if global_variables:
        var var_obj = global_variables.get(name)
        if var_obj is BaseVariable:
            return var_obj.get_value()  // 自动提取值

    return default
```

### 决策 2: 添加 get_variable_object() 高级 API

**目的:** 允许高级用户访问 BaseVariable 对象的完整功能（信号、元数据等）

```gdscript
// 新增方法
func get_variable_object(name: String) -> BaseVariable:
    var name_key = _get_cached_name_key(name)

    // 局部变量：临时包装对象
    if local_variables.has(name_key):
        return _create_temporary_variable(name, local_variables[name_key])

    // 全局变量：返回实际对象
    if global_variables:
        return global_variables.get(name)

    return null
```

### 决策 3: 移除全局变量同步逻辑

**当前问题:**
```gdscript
// [set_variable.gd:192-194]
// 同步到执行上下文（导致数据重复）
context.set_variable(variable_name, value, scope_string)
```

**改进方案:**
- ❌ 完全移除同步（破坏向后兼容）
- ✅ 添加标志位控制同步行为（推荐）
- ❌ 改为存储对象引用（复杂度高）

**决策:** 采用 **标志位方案**

```gdscript
// ExecutionContext 新增属性
@export var sync_global_to_local: bool = false  // 默认关闭同步

// set_variable 中
if scope == "global" and sync_global_to_local:
    context.set_variable(variable_name, value, "local")
```

### 决策 4: 统一作用域表示

**当前状态:**
- `BaseVariable.VariableScope` 枚举（`LOCAL`/`GLOBAL`）
- 字符串常量（`"local"`/`"global"`）

**改进方案:**
- 保留枚举（类型安全）
- 添加转换工具函数
- 统一使用枚举作为内部表示

```gdscript
// 统一工具函数
class_name VariableScopeUtils extends Object

static func to_string(scope: BaseVariable.VariableScope) -> String:
    match scope:
        BaseVariable.VariableScope.LOCAL: return "local"
        BaseVariable.VariableScope.GLOBAL: return "global"
        _: return "unknown"

static func from_string(scope_str: String) -> BaseVariable.VariableScope:
    match scope_str.to_lower():
        "local": return BaseVariable.VariableScope.LOCAL
        "global": return BaseVariable.VariableScope.GLOBAL
        _: return BaseVariable.VariableScope.LOCAL
```

---

## 四、实施步骤

### 阶段 1: 准备工作（0.5 天）

#### 1.1 创建备份和测试

```bash
# 创建特性分支
git checkout -b refactor/variable-system-v2

# 备份关键文件
cp addons/bricks/core/base/execution_context.gd \
   addons/bricks/core/base/execution_context.gd.backup

# 创建测试场景
# demos/variable_system_test/test_variable_refactoring.tscn
```

#### 1.2 编写单元测试

创建 `addons/bricks/tests/test_variable_refactoring.gd`:

```gdscript
extends Node

func test_local_variable_operations():
    var context = ExecutionContext.new()

    # 创建
    context.set_variable("score", 100, "local")
    assert(context.has_variable("score"))

    # 读取（验证返回值）
    var value = context.get_variable("score")
    assert(value == 100)
    assert(typeof(value) == TYPE_INT)

    # 设置
    context.set_variable("score", 200, "local")
    assert(context.get_variable("score") == 200)

    print("✅ 局部变量测试通过")

func test_global_variable_operations():
    var assistant = GlobalVariableAssistant.get_instance()
    var context = ExecutionContext.new()
    context.global_variables = assistant

    # 创建全局变量
    var var_obj = BaseVariable.create("health", 100, BaseVariable.VariableScope.GLOBAL)
    assistant.add_global_variable("health", var_obj)

    # 读取（验证返回值，不是对象）
    var value = context.get_variable("health")
    assert(value == 100)
    assert(typeof(value) == TYPE_INT)  # 不是 BaseVariable
    assert(not value is BaseVariable)

    # 设置
    context.set_variable("health", 80, "global")
    assert(context.get_variable("health") == 80)

    print("✅ 全局变量测试通过")

func test_mixed_variable_access():
    var assistant = GlobalVariableAssistant.get_instance()
    var context = ExecutionContext.new()
    context.global_variables = assistant

    # 创建同名局部和全局变量
    context.set_variable("score", 10, "local")
    var global_var = BaseVariable.create("score", 100, BaseVariable.VariableScope.GLOBAL)
    assistant.add_global_variable("score", global_var)

    # 验证局部变量优先
    var value = context.get_variable("score")
    assert(value == 10, "局部变量应该优先")

    print("✅ 混合变量访问测试通过")
```

---

### 阶段 2: 核心重构（1.5 天）

#### 2.1 重构 ExecutionContext.get_variable()

**文件:** `addons/bricks/core/base/execution_context.gd`

**位置:** 第 303-358 行

**修改前:**
```gdscript
func get_variable(name: String, default: Variant = null) -> Variant:
    # ... 现有代码
    if local_variables.has(name_key):
        var value = local_variables[name_key]
        return value  # 直接返回

    if global_variables:
        if global_variables.has_method("get"):
            var global_value = global_variables.get(name, default)
            if global_value != default:
                return global_value  # 返回对象（问题！）
```

**修改后:**
```gdscript
func get_variable(name: String, default: Variant = null) -> Variant:
    # 仅在调试模式且日志级别为 DEBUG 时输出详细日志
    if OS.is_debug_build() and log_level >= BricksLogger.LogLevel.DEBUG:
        _log_debug("ExecutionContext.get_variable called: name='%s', default=%s" % [name, str(default)])

    if name.is_empty():
        _log_error("Variable name cannot be empty")
        return default

    # 获取 StringName 键
    var name_key = _get_cached_name_key(name)

    # 首先检查局部变量（使用 StringName 键）
    if local_variables.has(name_key):
        var value = local_variables[name_key]
        # 局部变量直接返回值
        return value

    # 检查全局变量
    if global_variables:
        if global_variables.has_method("get"):
            var global_var = global_variables.get(name, null)
            if global_var != null:
                # 统一返回值：如果存储的是对象，提取其值
                if global_var is BaseVariable:
                    return global_var.get_value()
                else:
                    # 兼容：如果存储的是值，直接返回
                    return global_var

    # 打印所有局部变量用于调试（仅在调试模式）
    if OS.is_debug_build() and log_level >= BricksLogger.LogLevel.DEBUG:
        _log_debug("All local variables:")
        for var_name in local_variables:
            var var_value = local_variables[var_name]
            _log_debug("  %s = %s (type: %s)" % [var_name, str(var_value), typeof(var_value)])

    return default
```

#### 2.2 添加 get_variable_object() 方法

**文件:** `addons/bricks/core/base/execution_context.gd`

**插入位置:** 第 358 行之后

```gdscript
## 获取变量对象（高级 API）
##
## 返回 BaseVariable 对象而不是值，允许访问对象的完整功能（信号、元数据等）
##
## 参数：
## - name: String - 变量名
##
## 返回：
## - BaseVariable - 变量对象，如果找不到则返回 null
##
## 示例：
## ```gdscript
## # 获取对象以访问高级功能
## var var_obj = context.get_variable_object("player_health")
## if var_obj:
##     var_obj.value_changed.connect(_on_health_changed)
##     print(var_obj.get_info())
## ```
func get_variable_object(name: String) -> BaseVariable:
    if name.is_empty():
        _log_error("Variable name cannot be empty")
        return null

    var name_key = _get_cached_name_key(name)

    # 检查局部变量：临时包装为对象
    if local_variables.has(name_key):
        return _create_temporary_variable(name, local_variables[name_key])

    # 检查全局变量：返回实际对象
    if global_variables:
        if global_variables.has_method("get"):
            var global_var = global_variables.get(name, null)
            if global_var is BaseVariable:
                return global_var

    return null

## 为局部变量创建临时 BaseVariable 对象
## name: String - 变量名
## value: Variant - 变量值
## returns: BaseVariable - 临时对象
func _create_temporary_variable(name: String, value: Variant) -> BaseVariable:
    var temp_var = BaseVariable.create(name, value, BaseVariable.VariableScope.LOCAL)
    return temp_var
```

#### 2.3 移除全局变量同步逻辑

**文件:** `addons/bricks/instructions/set_variable.gd`

**位置:** 第 192-194 行

**修改前:**
```gdscript
# 同时同步到执行上下文（可选，主要用于运行时访问）
if context.has_method("set_variable"):
    context.set_variable(variable_name, value, scope_string)
```

**修改后:**
```gdscript
# 注意：不再同步到执行上下文
# 全局变量应该通过 GlobalVariableAssistant 访问
# 如需在上下文中缓存，可使用 context.set_custom_data()
```

**或者保留作为可选项（向后兼容）：**
```gdscript
# 可选：同步到执行上下文用于快速访问
# 注意：这只是缓存，实际存储仍在 GlobalVariableManager
if OS.is_debug_build():
    _log_debug("全局变量已设置，未同步到上下文（避免数据重复）")
```

#### 2.4 优化 set_variable() 全局变量设置

**文件:** `addons/bricks/core/base/execution_context.gd`

**位置:** 第 251-276 行

**修改前:**
```gdscript
"global":
    # 使用 GlobalVariableAssistant 来管理全局变量
    var assistant = GlobalVariableAssistant.get_instance()
    if not assistant:
        _log_error("无法获取 GlobalVariableAssistant 单例")
        return false

    # 创建一个临时的 BaseVariable 对象来包装值
    var temp_variable = BaseVariable.new()
    temp_variable.variable_name = name
    temp_variable.scope = BaseVariable.VariableScope.GLOBAL
    temp_variable.persistent = false
    temp_variable.value = value

    # 添加到全局变量
    if not assistant.add_global_variable(name, temp_variable):
        _log_error("添加全局变量 '%s' 失败" % name)
        return false
```

**修改后:**
```gdscript
"global":
    # 使用 GlobalVariableAssistant 来管理全局变量
    var assistant = GlobalVariableAssistant.get_instance()
    if not assistant:
        _log_error("无法获取 GlobalVariableAssistant 单例")
        return false

    # 检查变量是否已存在
    var existing_var = assistant.get_global_variable(name)

    if existing_var != null:
        # 更新现有变量的值
        if not existing_var.set_value(value):
            _log_error("更新全局变量 '%s' 失败" % name)
            return false
    else:
        # 创建新的全局变量
        var new_variable = BaseVariable.create(name, value, BaseVariable.VariableScope.GLOBAL)
        new_variable.persistent = false

        if not assistant.add_global_variable(name, new_variable):
            _log_error("添加全局变量 '%s' 失败" % name)
            return false

    _log_debug("全局变量 '%s' 已添加到上下文: %s" % [name, str(value)])
    return true
```

---

### 阶段 3: 辅助工具（0.5 天）

#### 3.1 创建 VariableScopeUtils 工具类

**新建文件:** `addons/bricks/core/utils/variable_scope_utils.gd`

```gdscript
@tool
class_name VariableScopeUtils extends RefCounted

## 变量作用域工具类
## 提供作用域枚举和字符串之间的转换功能

## 将枚举转换为字符串
## scope: BaseVariable.VariableScope - 作用域枚举
## returns: String - 作用域字符串
static func to_string(scope: BaseVariable.VariableScope) -> String:
    match scope:
        BaseVariable.VariableScope.LOCAL:
            return "local"
        BaseVariable.VariableScope.GLOBAL:
            return "global"
        _:
            _log_warning("未知的作用域: %s" % scope)
            return "local"

## 将字符串转换为枚举
## scope_str: String - 作用域字符串
## returns: BaseVariable.VariableScope - 作用域枚举
static func from_string(scope_str: String) -> BaseVariable.VariableScope:
    match scope_str.to_lower():
        "local":
            return BaseVariable.VariableScope.LOCAL
        "global":
            return BaseVariable.VariableScope.GLOBAL
        _:
            _log_warning("未知的作用域字符串: %s，使用 LOCAL" % scope_str)
            return BaseVariable.VariableScope.LOCAL

## 验证作用域字符串是否有效
## scope_str: String - 作用域字符串
## returns: bool - 是否有效
static func is_valid_scope(scope_str: String) -> bool:
    var lower = scope_str.to_lower()
    return lower == "local" or lower == "global"

## 获取所有有效的作用域名称
## returns: Array[String] - 作用域名称数组
static func get_valid_scopes() -> Array[String]:
    return ["local", "global"]

## 统一日志方法
static func _log_warning(message: String):
    BricksLogger.log_warning("VariableScopeUtils", BricksLogger.LogLevel.INFO, message)
```

#### 3.2 更新指令使用工具类

**文件:** `addons/bricks/instructions/set_variable.gd`

**位置:** 第 164 行

**修改前:**
```gdscript
# 将枚举转换为字符串
var scope_string = _get_scope_name(variable_scope)
```

**修改后:**
```gdscript
# 使用工具类转换作用域
var scope_string = VariableScopeUtils.to_string(variable_scope)
```

**删除旧方法:**
```gdscript
# 删除 _get_scope_name() 方法（第 304-311 行）
```

---

### 阶段 4: 更新指令（1 天）

#### 4.1 更新 SetVariable 指令

**文件:** `addons/bricks/instructions/set_variable.gd`

**关键修改点:**

1. **删除全局变量同步逻辑**（第 192-194 行）
2. **使用 VariableScopeUtils**（第 164 行）
3. **简化错误处理**

#### 4.2 更新 CreateVariable 指令

**文件:** `addons/bricks/instructions/create_variable.gd`

**关键修改点:**

1. **使用 VariableScopeUtils**（第 94 行）
2. **删除临时对象创建逻辑**（第 256-267 行）

**修改前:**
```gdscript
# [create_variable.gd:256-267]
if context.has_method("add_variable"):
    var success = context.add_variable(variable_name, variable)
    # ...
```

**修改后:**
```gdscript
# 直接使用 set_variable，简化逻辑
var scope_string = VariableScopeUtils.to_string(variable_scope)
var success = context.set_variable(variable_name, value, scope_string)
if not success:
    _log_error("变量添加失败: %s" % variable_name)
    return
```

#### 4.3 更新 PrintVariableValue 指令

**文件:** `addons/bricks/instructions/print_variable_value.gd`

**关键修改点:**

1. **使用 get_variable() 而不是直接访问**（第 102 行）
2. **简化值转换逻辑**

**修改前:**
```gdscript
# [print_variable_value.gd:148-152]
if detected_assistant:
    var variable = detected_assistant.get_global_variable(variable_name)
    if variable:
        return variable.value  # 访问 .value 属性
```

**修改后:**
```gdscript
# 统一使用 context.get_variable()
if detected_assistant:
    var value = context.get_variable(variable_name)  # 直接返回值
    return value
```

---

### 阶段 5: 文档和测试（1 天）

#### 5.1 创建迁移指南

**新建文件:** `addons/bricks/docs/user_docs/guides/variable_migration.md`

```markdown
# 变量系统 v2 迁移指南

## 概述

Bricks 变量系统在 v2.1 版本进行了重大重构，统一了局部变量和全局变量的访问 API。

## 主要变化

### 变化 1: get_variable() 现在总是返回值

**v2.0 行为:**
```gdscript
# 全局变量返回对象
var health_var = context.get_variable("health")  # BaseVariable
var health = health_var.value
```

**v2.1 行为:**
```gdscript
# 总是返回值
var health = context.get_variable("health")  # Variant
```

### 变化 2: 新增 get_variable_object() API

**用途:** 当需要访问 BaseVariable 对象的高级功能（信号、元数据等）

```gdscript
# 获取对象以监听值变化
var health_var = context.get_variable_object("health")
if health_var:
    health_var.value_changed.connect(_on_health_changed)
```

### 变化 3: 移除全局变量同步逻辑

**v2.0 行为:**
```gdscript
# 设置全局变量时自动同步到上下文（导致数据重复）
context.set_variable("score", 100, "global")
# 自动在 local_variables 中创建副本
```

**v2.1 行为:**
```gdscript
# 不再自动同步，避免数据重复
context.set_variable("score", 100, "global")
# 需要时通过 get_variable() 从 GlobalVariableManager 获取
```

## 迁移步骤

### 步骤 1: 更新 get_variable() 调用

**之前:**
```gdscript
var var_obj = context.get_variable("my_var")
if var_obj is BaseVariable:
    var value = var_obj.value
```

**之后:**
```gdscript
var value = context.get_variable("my_var")
```

### 步骤 2: 更新信号监听代码

**之前:**
```gdscript
var var_obj = context.get_variable("my_var")
var_obj.value_changed.connect(_on_changed)
```

**之后:**
```gdscript
var var_obj = context.get_variable_object("my_var")
if var_obj:
    var_obj.value_changed.connect(_on_changed)
```

### 步骤 3: 移除同步依赖

**之前:**
```gdscript
# 依赖全局变量自动同步到上下文
context.set_variable("global_var", value, "global")
var local_copy = context.get_variable("global_var")  # 从上下文读取
```

**之后:**
```gdscript
# 直接从 GlobalVariableManager 获取
context.set_variable("global_var", value, "global")
var value = context.get_variable("global_var")  # 统一 API
```

## 向后兼容性

- ✅ 现有代码无需修改即可运行
- ✅ 旧的 API 仍然可用（不推荐）
- ⚠️ 建议逐步迁移到新 API

## 新 API 参考

### ExecutionContext

```gdscript
# 获取变量值（推荐）
func get_variable(name: String, default: Variant = null) -> Variant

# 获取变量对象（高级用法）
func get_variable_object(name: String) -> BaseVariable

# 设置变量
func set_variable(name: String, value: Variant, scope: String) -> bool

# 检查变量是否存在
func has_variable(name: String) -> bool
```

### VariableScopeUtils

```gdscript
# 作用域转换
static func to_string(scope: BaseVariable.VariableScope) -> String
static func from_string(scope_str: String) -> BaseVariable.VariableScope
```
```

#### 5.2 更新代码文档

**更新文件:** `addons/bricks/core/base/execution_context.gd`

**添加详细的 API 文档:**
```gdscript
## 获取变量值（统一 API）
##
## 从不同作用域中获取变量值，总是返回 Variant 值而不是对象。
## 这确保了局部变量和全局变量的一致性。
##
## 参数：
## - name: String - 变量名
## - default: Variant - 默认值，如果变量不存在则返回此值
##
## 返回：
## - Variant - 变量值，如果找不到则返回默认值
##
## 注意：
## - 此方法总是返回值，不是 BaseVariable 对象
## - 如果需要访问对象的完整功能（信号、元数据等），使用 get_variable_object()
##
## 示例：
## ```gdscript
## # 获取变量值（推荐用法）
## var score = context.get_variable("score", 0)
##
## # 获取变量对象（高级用法）
## var score_obj = context.get_variable_object("score")
## if score_obj:
##     score_obj.value_changed.connect(_on_score_changed)
## ```
func get_variable(name: String, default: Variant = null) -> Variant:
```

#### 5.3 运行测试套件

创建 `addons/bricks/tests/test_variable_refactoring.tscn`:

```gdscript
extends Node

## 变量系统重构测试套件

func _ready():
    print("=== 开始变量系统重构测试 ===")

    test_local_variable_get_returns_value()
    test_global_variable_get_returns_value()
    test_get_variable_object_returns_object()
    test_mixed_scope_priority()
    test_backward_compatibility()

    print("=== 所有测试完成 ===")

func test_local_variable_get_returns_value():
    print("\n[测试] 局部变量 get_variable() 返回值")
    var context = ExecutionContext.new()

    context.set_variable("score", 100, "local")
    var value = context.get_variable("score")

    assert(value == 100, "值应该等于 100")
    assert(typeof(value) == TYPE_INT, "类型应该是 TYPE_INT")
    assert(not (value is BaseVariable), "不应该返回 BaseVariable 对象")

    print("  ✅ 通过")

func test_global_variable_get_returns_value():
    print("\n[测试] 全局变量 get_variable() 返回值")
    var assistant = GlobalVariableAssistant.get_instance()
    var context = ExecutionContext.new()
    context.global_variables = assistant

    # 创建全局变量
    var var_obj = BaseVariable.create("health", 100, BaseVariable.VariableScope.GLOBAL)
    assistant.add_global_variable("health", var_obj)

    var value = context.get_variable("health")

    assert(value == 100, "值应该等于 100")
    assert(typeof(value) == TYPE_INT, "类型应该是 TYPE_INT")
    assert(not (value is BaseVariable), "不应该返回 BaseVariable 对象")

    print("  ✅ 通过")

func test_get_variable_object_returns_object():
    print("\n[测试] get_variable_object() 返回对象")
    var assistant = GlobalVariableAssistant.get_instance()
    var context = ExecutionContext.new()
    context.global_variables = assistant

    # 创建全局变量
    assistant.add_global_variable("stamina", BaseVariable.create("stamina", 50, BaseVariable.VariableScope.GLOBAL))

    var var_obj = context.get_variable_object("stamina")

    assert(var_obj != null, "应该返回对象")
    assert(var_obj is BaseVariable, "应该返回 BaseVariable 类型")
    assert(var_obj.get_value() == 50, "对象的值应该是 50")

    print("  ✅ 通过")

func test_mixed_scope_priority():
    print("\n[测试] 混合作用域优先级")
    var assistant = GlobalVariableAssistant.get_instance()
    var context = ExecutionContext.new()
    context.global_variables = assistant

    # 创建同名局部和全局变量
    context.set_variable("score", 10, "local")
    assistant.add_global_variable("score", BaseVariable.create("score", 100, BaseVariable.VariableScope.GLOBAL))

    var value = context.get_variable("score")
    assert(value == 10, "局部变量应该优先")

    print("  ✅ 通过")

func test_backward_compatibility():
    print("\n[测试] 向后兼容性")
    var context = ExecutionContext.new()

    # 旧式用法：直接设置值
    context.set_variable("old_style", 42, "local")
    var value = context.get_variable("old_style")

    assert(value == 42, "旧式用法应该仍然有效")

    print("  ✅ 通过")
```

---

### 阶段 6: 代码审查和发布（0.5 天）

#### 6.1 代码审查清单

- [ ] 所有 `get_variable()` 调用已更新
- [ ] 所有 `get_variable_object()` 调用已添加
- [ ] 全局变量同步逻辑已移除或标记为可选
- [ ] 作用域转换统一使用 `VariableScopeUtils`
- [ ] 所有单元测试通过
- [ ] 文档已更新
- [ ] 迁移指南已创建

#### 6.2 发布检查

- [ ] 创建 git tag: `v2.1.0-variable-system-refactor`
- [ ] 更新 CHANGELOG.md
- [ ] 在论坛/社区发布公告
- [ ] 收集用户反馈

---

## 五、风险评估

### 5.1 破坏性变更风险

**风险:** 现有代码依赖 `get_variable()` 返回 BaseVariable 对象

**缓解措施:**
1. 提供清晰的迁移指南
2. 保留 `get_variable_object()` 用于高级用法
3. 在文档中明确标注变化
4. 提供过渡期，两个版本 API 同时支持

### 5.2 性能风险

**风险:** 频繁调用 `get_value()` 可能影响性能

**缓解措施:**
1. `_get_cached_name_key()` 已缓存 StringName，减少哈希计算
2. 全局变量是 RefCounted，访问 `.value` 开销很小
3. 提供 `get_variable_object()` 用于需要多次访问的场景

### 5.3 向后兼容性风险

**风险:** 旧代码可能无法正常工作

**缓解措施:**
1. 运行完整的测试套件
2. 在演示场景中验证所有现有功能
3. 提供 Beta 版本收集反馈
4. 准备回滚方案

---

## 六、测试策略

### 6.1 单元测试

| 测试用例 | 描述 | 优先级 |
|---------|------|--------|
| `test_local_variable_get_returns_value` | 验证局部变量返回值 | P0 |
| `test_global_variable_get_returns_value` | 验证全局变量返回值 | P0 |
| `test_get_variable_object_returns_object` | 验证对象 API | P0 |
| `test_mixed_scope_priority` | 验证作用域优先级 | P1 |
| `test_backward_compatibility` | 验证向后兼容性 | P0 |
| `test_variable_scope_utils` | 验证工具类 | P1 |

### 6.2 集成测试

1. **CreateVariable 指令测试**
   - 创建局部变量
   - 创建全局变量
   - 验证变量是否正确创建

2. **SetVariable 指令测试**
   - 设置局部变量
   - 设置全局变量
   - 验证值是否正确更新

3. **PrintVariableValue 指令测试**
   - 打印局部变量
   - 打印全局变量
   - 验证输出格式

### 6.3 性能测试

```gdscript
func test_performance():
    var context = ExecutionContext.new()
    var start = Time.get_ticks_msec()

    # 创建 1000 个局部变量
    for i in range(1000):
        context.set_variable("var_%d" % i, i, "local")

    # 读取 1000 次
    for i in range(1000):
        var value = context.get_variable("var_%d" % i)

    var elapsed = Time.get_ticks_msec() - start
    print("性能测试: %d ms" % elapsed)
    assert(elapsed < 100, "性能应该优于 100ms")
```

---

## 七、回滚计划

### 触发条件

- 测试失败率 > 20%
- 性能下降 > 50%
- 用户报告严重破坏性变更

### 回滚步骤

1. 恢复备份文件：
   ```bash
   git checkout master
   git checkout -b hotfix/rollback-variable-system
   cp addons/bricks/core/base/execution_context.gd.backup \
      addons/bricks/core/base/execution_context.gd
   ```

2. 发布补丁版本：`v2.1.1`

3. 分析失败原因并修复

---

## 八、后续优化

### 短期（v2.2）

1. 添加变量监听系统（观察者模式）
2. 支持变量依赖关系追踪
3. 添加变量变更历史记录

### 中期（v2.3）

1. 支持变量表达式（如 `score * 2 + bonus`）
2. 添加变量类型推断
3. 支持变量模板和预设

### 长期（v3.0）

1. 完全的类型系统支持
2. 变量命名空间
3. 分布式变量同步（多人游戏）

---

## 九、时间表

| 阶段 | 任务 | 预计时间 | 负责人 |
|------|------|---------|--------|
| 阶段 1 | 准备工作和测试 | 0.5 天 | - |
| 阶段 2 | 核心重构 | 1.5 天 | - |
| 阶段 3 | 辅助工具 | 0.5 天 | - |
| 阶段 4 | 更新指令 | 1 天 | - |
| 阶段 5 | 文档和测试 | 1 天 | - |
| 阶段 6 | 代码审查和发布 | 0.5 天 | - |
| **总计** | - | **5 天** | - |

---

## 十、成功标准

### 技术指标

- ✅ 所有单元测试通过（100%）
- ✅ 性能下降 < 10%
- ✅ 代码覆盖率 > 80%

### 用户体验

- ✅ API 简单直观
- ✅ 文档清晰完整
- ✅ 迁移过程顺畅
- ✅ 破坏性变更最小化

### 代码质量

- ✅ 通过静态分析
- ✅ 符合 GDScript 编码规范
- ✅ 通过同行评审

---

## 附录

### A. 相关文件清单

```
需要修改的文件：
- addons/bricks/core/base/execution_context.gd
- addons/bricks/instructions/set_variable.gd
- addons/bricks/instructions/create_variable.gd
- addons/bricks/instructions/print_variable_value.gd

需要新增的文件：
- addons/bricks/core/utils/variable_scope_utils.gd
- addons/bricks/tests/test_variable_refactoring.gd
- addons/bricks/tests/test_variable_refactoring.tscn
- addons/bricks/docs/user_docs/guides/variable_migration.md

参考文档：
- addons/bricks/docs/system_docs/architecture/variable_system_design.md
- addons/bricks/core/base/base_variable.gd
- addons/bricks/core/global_variable_manager.gd
```

### B. 相关 Issue 和 PR

- Issue #123: 变量系统 API 不一致
- PR #456: 变量系统重构 v2

### C. 参考资料

- [Godot 4 GDScript 文档](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_basics.html)
- [项目编码规范](../../CLAUDE.md)
- [Bricks 系统文档](../../addons/bricks/docs/)

---

**文档版本:** 1.0
**最后更新:** 2026-01-23
**状态:** 待审核
