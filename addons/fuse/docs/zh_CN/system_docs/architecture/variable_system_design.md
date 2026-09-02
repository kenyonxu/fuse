# Fuse 变量系统设计文档

## 版本信息

- **当前版本:** 3.0
- **最后更新:** 2026-02-09
- **Godot 版本:** 4.6

## 概述

Fuse 变量系统采用三层架构设计，提供灵活的变量存储和访问机制。系统通过统一的 `VariableOperations` 工具类访问不同层级的变量，简化了指令开发并提高了代码的可维护性。

## 三层变量架构

### 1. LOCAL（局部变量）

**存储位置:** `ExecutionContext.local_variables`

**生命周期:** 单次指令执行期间

**管理方式:** 由 `ExecutionContext` 自动管理

**使用场景:**
- 指令执行过程中的临时数据
- 计算中间结果
- 单次使用的数据

**特点:**
- ✅ 访问速度最快
- ✅ 自动垃圾回收
- ❌ 无法跨指令共享
- ❌ 无法持久化

**示例:**
```gdscript
# 在指令中使用局部变量
func execute(context: ExecutionContext):
    # 保存计算结果到局部变量
    VariableOperations.set_variable(context, "temp_value", BaseVariable.VariableScope.LOCAL, 42)

    # 从局部变量读取
    var value = VariableOperations.get_variable(context, "temp_value", BaseVariable.VariableScope.LOCAL, 0)
```

---

### 2. SCOPE（作用域变量）

**存储位置:** `ScopeVariableContainer.variables`

**生命周期:** 节点生命周期（随节点进入/退出场景树）

**管理方式:**
- 管理器：`ScopeVariableManager`（单例）
- 容器：`ScopeVariableContainer`（节点组件）

**使用场景:**
- 场景局部共享数据
- 节点组配置
- UI 组件状态
- 区域性游戏状态

**特点:**
- ✅ 支持作用域链继承
- ✅ 可视化编辑器支持
- ✅ 节点销毁时自动清理
- ⚠️ 需要手动添加 `ScopeVariableContainer` 节点
- ⚠️ 需要 `ScopeVariableManager` 实例

**作用域继承模式:**

```gdscript
enum InheritanceMode {
    NONE,           # 不继承父作用域
    READ_ONLY,      # 只读继承父作用域
    READ_WRITE      # 读写继承父作用域
}
```

**示例:**
```gdscript
# 场景树结构
# Main
#   ├── ScopeContainer (scope_id: "game_ui")
#   │   ├── PlayerHP
#   │   └── ScoreDisplay
#   └── EnemyContainer
#       └── ScopeContainer (scope_id: "enemy_data")

# 在指令中使用作用域变量
func execute(context: ExecutionContext):
    # 获取最近的 ScopeContainer
    var scope_container = ScopeVariableManager.get_instance().find_nearest_scope(context.target)

    if scope_container:
        # 读取作用域变量
        var player_hp = VariableOperations.get_variable(
            context,
            "hp",
            BaseVariable.VariableScope.SCOPE,
            100
        )

        # 写入作用域变量
        VariableOperations.set_variable(
            context,
            "hp",
            BaseVariable.VariableScope.SCOPE,
            player_hp - 10
        )
```

---

### 3. GLOBAL（全局变量）

**存储位置:** `GlobalVariableResource`（Resource 文件）

**生命周期:** 整个游戏运行期间

**管理方式:**
- 管理器：`GlobalVariableManager`（单例）
- 助手：`GlobalVariableAssistant`（节点组件）

**使用场景:**
- 游戏配置
- 玩家数据
- 跨场景共享数据
- 游戏进度

**特点:**
- ✅ 跨场景访问
- ✅ 支持资源文件持久化
- ✅ 可视化编辑器支持
- ⚠️ 需要手动管理内存
- ⚠️ 过度使用会导致代码耦合

**示例:**
```gdscript
# 在指令中使用全局变量
func execute(context: ExecutionContext):
    # 读取玩家分数
    var score = VariableOperations.get_variable(
        context,
        "player_score",
        BaseVariable.VariableScope.GLOBAL,
        0
    )

    # 更新玩家分数
    VariableOperations.set_variable(
        context,
        "player_score",
        BaseVariable.VariableScope.GLOBAL,
        score + 100
    )
```

---

## VariableScope 枚举

```gdscript
# addons/fuse/core/base/base_variable.gd

enum VariableScope {
    LOCAL = 0,      ## 局部变量
    SCOPE = 1,      ## 作用域变量
    GLOBAL = 2      ## 全局变量
}
```

## 核心工具类

### VariableOperations（统一变量访问接口）

**文件位置:** `addons/fuse/core/utils/variable_operations.gd`

**功能:** 提供统一的变量访问接口，自动根据作用域选择正确的存储层

**主要方法:**

#### 1. 获取变量

```gdscript
static func get_variable(
    context: ExecutionContext,
    variable_name: String,
    scope: BaseVariable.VariableScope,
    default_value: Variant = null
) -> Variant:
```

**参数说明:**
- `context`: 执行上下文
- `variable_name`: 变量名
- `scope`: 变量作用域（LOCAL/SCOPE/GLOBAL）
- `default_value`: 默认值（变量不存在时返回）

**返回值:** 变量值，如果不存在则返回默认值

**示例:**
```gdscript
# 获取局部变量（默认值为 0）
var local_value = VariableOperations.get_variable(
    context,
    "counter",
    BaseVariable.VariableScope.LOCAL,
    0
)

# 获取全局玩家分数（默认值为 0）
var score = VariableOperations.get_variable(
    context,
    "player_score",
    BaseVariable.VariableScope.GLOBAL,
    0
)
```

#### 2. 设置变量

```gdscript
static func set_variable(
    context: ExecutionContext,
    variable_name: String,
    scope: BaseVariable.VariableScope,
    value: Variant
) -> bool
```

**参数说明:**
- `context`: 执行上下文
- `variable_name`: 变量名
- `scope`: 变量作用域（LOCAL/SCOPE/GLOBAL）
- `value`: 要设置的值

**返回值:** 成功返回 `true`，失败返回 `false`

**示例:**
```gdscript
# 设置局部变量
VariableOperations.set_variable(
    context,
    "temp_result",
    BaseVariable.VariableScope.LOCAL,
    42
)

# 设置全局变量
VariableOperations.set_variable(
    context,
    "player_level",
    BaseVariable.VariableScope.GLOBAL,
    5
)
```

#### 3. 检查变量是否存在

```gdscript
static func has_variable(
    context: ExecutionContext,
    variable_name: String,
    scope: BaseVariable.VariableScope
) -> bool
```

**参数说明:**
- `context`: 执行上下文
- `variable_name`: 变量名
- `scope`: 变量作用域（LOCAL/SCOPE/GLOBAL）

**返回值:** 存在返回 `true`，不存在返回 `false`

**示例:**
```gdscript
# 检查全局变量是否存在
if VariableOperations.has_variable(context, "player_data", BaseVariable.VariableScope.GLOBAL):
    # 变量存在，执行逻辑
    pass
```

---

### VariableScopeUtils（作用域工具类）

**文件位置:** `addons/fuse/core/utils/variable_scope_utils.gd`

**功能:** 提供作用域枚举与字符串之间的转换功能

**主要方法:**

#### 1. 枚举转字符串

```gdscript
static func enum_to_string(scope: BaseVariable.VariableScope) -> String:
    match scope:
        BaseVariable.VariableScope.LOCAL:
            return "local"
        BaseVariable.VariableScope.SCOPE:
            return "scope"
        BaseVariable.VariableScope.GLOBAL:
            return "global"
        _:
            return "local"
```

#### 2. 字符串转枚举

```gdscript
static func string_to_enum(scope_str: String) -> BaseVariable.VariableScope:
    match scope_str.to_lower():
        "local":
            return BaseVariable.VariableScope.LOCAL
        "scope":
            return BaseVariable.VariableScope.SCOPE
        "global":
            return BaseVariable.VariableScope.GLOBAL
        _:
            return BaseVariable.VariableScope.LOCAL
```

#### 3. 获取显示名称

```gdscript
static func enum_to_display_name(scope: BaseVariable.VariableScope) -> String:
    match scope:
        BaseVariable.VariableScope.LOCAL:
            return "局部变量"
        BaseVariable.VariableScope.SCOPE:
            return "作用域变量"
        BaseVariable.VariableScope.GLOBAL:
            return "全局变量"
        _:
            return "未知"
```

#### 4. 作用域检查

```gdscript
static func is_local(scope: BaseVariable.VariableScope) -> bool
static func is_scope(scope: BaseVariable.VariableScope) -> bool
static func is_global(scope: BaseVariable.VariableScope) -> bool
```

**示例:**
```gdscript
# 在指令描述中使用
func get_description() -> String:
    var scope_str = VariableScopeUtils.enum_to_string(save_to_scope).to_upper()
    return "保存到 %s [%s]" % [variable_name, scope_str]
```

---

## 在指令中使用变量系统

### 基本步骤

#### 1. 添加作用域属性

```gdscript
# 变量名
var variable_name: String = ""

# 变量作用域
@export var variable_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
    set(value):
        variable_scope = value
        _update_resource_name()
```

#### 2. 使用 VariableOperations 访问变量

```gdscript
func execute(context: ExecutionContext):
    # 获取变量值
    var value = VariableOperations.get_variable(
        context,
        variable_name,
        variable_scope,
        null  # 默认值
    )

    # 设置变量值
    VariableOperations.set_variable(
        context,
        variable_name,
        variable_scope,
        new_value
    )
```

#### 3. 更新属性列表

```gdscript
func _get_property_list()  -> Array[Dictionary]:
    var properties := []

    # ... 其他属性 ...

    properties.append({
        name = "variable_scope",
        type = TYPE_INT,
        hint = PROPERTY_HINT_ENUM,
        hint_string = "Local,Scope,Global",
        usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
    })

    return properties
```

#### 4. 更新显示方法

```gdscript
func _update_resource_name():
    var scope_str = VariableScopeUtils.enum_to_string(variable_scope).to_upper()
    resource_name = "%s [%s]" % [variable_name, scope_str]

func get_description() -> String:
    var scope_str = VariableScopeUtils.enum_to_string(variable_scope).to_upper()
    return "操作 %s [%s]" % [variable_name, scope_str]
```

#### 5. 验证 SCOPE 作用域

```gdscript
func validate() -> Array[String]:
    var errors = super.validate()

    # 验证变量名不为空
    if variable_name.is_empty():
        errors.append("变量名不能为空")

    # 验证 SCOPE 作用域需要 ScopeVariableManager
    if variable_scope == BaseVariable.VariableScope.SCOPE:
        var manager = ScopeVariableManager.get_instance()
        if manager == null:
            errors.append("未找到 ScopeVariableManager 实例")

    return errors
```

---

## 实际应用示例

### 示例 1: MathOperation（数学运算指令）

**文件:** `addons/fuse/instructions/math/math_operation.gd`

**重构前（使用旧 API）:**
```gdscript
var is_global: bool = false

func execute(context: ExecutionContext):
    # 获取操作数
    var operand_a = float(context.get_variable(operand_a_variable, is_global, 0.0))

    # 执行运算
    var result = operand_a + operand_b

    # 保存结果
    context.set_variable(save_to_variable, is_global, result)
```

**重构后（使用新 API）:**
```gdscript
@export var operand_a_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL
@export var save_to_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL

func execute(context: ExecutionContext):
    # 获取操作数
    var operand_a = float(VariableOperations.get_variable(
        context,
        operand_a_variable,
        operand_a_scope,
        0.0
    ))

    # 执行运算
    var result = operand_a + operand_b

    # 保存结果
    VariableOperations.set_variable(
        context,
        save_to_variable,
        save_to_scope,
        result
    )
```

**优势:**
- ✅ 类型安全（枚举替代布尔值）
- ✅ 支持三层变量体系
- ✅ 统一的错误处理
- ✅ 更清晰的代码结构

---

### 示例 2: GetDeltaTime（获取时间增量）

**文件:** `addons/fuse/instructions/time/get_delta_time.gd`

**重构前:**
```gdscript
var is_global: bool = false

func execute(context: ExecutionContext):
    var delta_time = Time.get_delta_time()

    if is_global:
        var global_vars = context.global_variables
        if global_vars != null:
            var variable = global_vars.get_variable(save_to_variable)
            if variable != null:
                variable.value = delta_time
            else:
                push_error("全局变量 '%s' 不存在" % save_to_variable)
    else:
        context.local_variables[save_to_variable] = delta_time
```

**重构后:**
```gdscript
@export var save_to_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL

func execute(context: ExecutionContext):
    var delta_time = Time.get_delta_time()

    # 一行代码完成所有操作
    VariableOperations.set_variable(
        context,
        save_to_variable,
        save_to_scope,
        delta_time
    )
```

**改进:**
- 代码从 11 行减少到 1 行
- 自动处理所有作用域
- 统一的错误处理机制

---

### 示例 3: SetPosition（设置节点位置）

**文件:** `addons/fuse/instructions/transform/set_position.gd`

**作用域属性定义:**
```gdscript
@export var position_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL
```

**执行逻辑:**
```gdscript
func execute(context: ExecutionContext):
    # 从变量获取位置
    if use_variable:
        var var_value = VariableOperations.get_variable(
            context,
            position_variable,
            position_scope,
            null
        )

        # 检查变量是否存在
        if var_value == null and not VariableOperations.has_variable(
            context,
            position_variable,
            position_scope
        ):
            _log_error_localized("FUSE_ERROR_VAR_NOT_FOUND", {"variable": position_variable})
            return

        # 验证类型
        if var_value is Vector2 or var_value is Vector2i or var_value is Vector3 or var_value is Vector3i:
            target_pos = var_value
        else:
            _log_error_localized("FUSE_ERROR_VAR_TYPE_INVALID", {
                "variable": position_variable,
                "actual_type": type_string(typeof(var_value))
            })
            return
    else:
        target_pos = position

    # 应用位置变换
    if node is Node2D:
        node.global_position = Vector2(target_pos.x, target_pos.y)
    elif node is Node3D:
        node.global_position = target_pos
```

---

## 作用域选择指南

### 何时使用 LOCAL（局部变量）

✅ **适用场景:**
- 单次指令执行的临时数据
- 计算中间结果
- 循环计数器
- 临时缓存数据

❌ **不适用场景:**
- 需要跨指令共享的数据
- 需要持久化的数据

**示例:**
```gdscript
# 计算两点距离的临时结果
var distance = point_a.distance_to(point_b)
VariableOperations.set_variable(context, "temp_distance", BaseVariable.VariableScope.LOCAL, distance)
```

---

### 何时使用 SCOPE（作用域变量）

✅ **适用场景:**
- 场景局部共享数据
- UI 组件状态
- 区域性游戏状态
- 节点组配置

❌ **不适用场景:**
- 全局游戏配置
- 单次使用的临时数据
- 跨场景共享数据

**前提条件:**
1. 场景中必须添加 `ScopeVariableContainer` 节点
2. 必须存在 `ScopeVariableManager` 实例

**示例:**
```gdscript
# 场景树
# Main
#   └── GameUI (ScopeVariableContainer, scope_id: "ui")
#       ├── HPBar
#       └── ScoreDisplay

# 在 HPBar 指令中更新血量
VariableOperations.set_variable(context, "current_hp", BaseVariable.VariableScope.SCOPE, 80)

# 在 ScoreDisplay 指令中读取血量
var hp = VariableOperations.get_variable(context, "current_hp", BaseVariable.VariableScope.SCOPE, 100)
```

---

### 何时使用 GLOBAL（全局变量）

✅ **适用场景:**
- 游戏配置（音量、画质等）
- 玩家数据（等级、经验、背包）
- 游戏进度（当前关卡、任务状态）
- 跨场景共享数据

❌ **不适用场景:**
- 临时数据
- 单个指令内部使用的数据
- 场景局部数据

**示例:**
```gdscript
# 读取玩家等级
var player_level = VariableOperations.get_variable(
    context,
    "player_level",
    BaseVariable.VariableScope.GLOBAL,
    1
)

# 更新玩家经验
VariableOperations.set_variable(
    context,
    "player_exp",
    BaseVariable.VariableScope.GLOBAL,
    current_exp + 100
)
```

---

## 迁移指南

### 从旧 API 迁移到新 API

#### 情况 1: 使用 `is_global: bool`

**旧代码:**
```gdscript
var is_global: bool = false

func execute(context: ExecutionContext):
    if is_global:
        var global_vars = context.global_variables
        if global_vars != null:
            var variable = global_vars.get_variable(var_name)
            if variable != null:
                value = variable.value
    else:
        value = context.local_variables.get(var_name, default_value)
```

**新代码:**
```gdscript
@export var var_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL

func execute(context: ExecutionContext):
    value = VariableOperations.get_variable(context, var_name, var_scope, default_value)
```

#### 情况 2: 使用 `variable_scope: int`

**旧代码:**
```gdscript
var variable_scope: int = 0  # 0=LOCAL, 1=GLOBAL

func execute(context: ExecutionContext):
    match variable_scope:
        0:
            value = context.local_variables.get(var_name, default_value)
        1:
            var global_vars = context.global_variables
            if global_vars != null:
                var variable = global_vars.get_variable(var_name)
                if variable != null:
                    value = variable.value
```

**新代码:**
```gdscript
@export var var_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL

func execute(context: ExecutionContext):
    value = VariableOperations.get_variable(context, var_name, var_scope, default_value)
```

#### 情况 3: 已有枚举但使用手动逻辑

**旧代码:**
```gdscript
var variable_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL

func _get_variable_value(context: ExecutionContext, name: String) -> Variant:
    match variable_scope:
        BaseVariable.VariableScope.LOCAL:
            return context.local_variables.get(name, null)
        BaseVariable.VariableScope.SCOPE:
            var manager = ScopeVariableManager.get_instance()
            if manager:
                var container = manager.find_nearest_scope(context.target)
                if container:
                    return container.get_variable(name, null)
            return null
        BaseVariable.VariableScope.GLOBAL:
            var manager = GlobalVariableManager.get_instance()
            if manager:
                var variable = manager.get_variable(name)
                if variable:
                    return variable.value
            return null
    return null
```

**新代码:**
```gdscript
var variable_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL

func _get_variable_value(context: ExecutionContext, name: String) -> Variant:
    return VariableOperations.get_variable(context, name, variable_scope, null)
```

---

## 最佳实践

### 1. 优先使用 LOCAL 变量

**理由:**
- 访问速度最快
- 自动垃圾回收
- 避免全局状态污染

**示例:**
```gdscript
# ✅ 推荐：使用 LOCAL 变量
var temp_result = calculate_something()
VariableOperations.set_variable(context, "temp", BaseVariable.VariableScope.LOCAL, temp_result)

# ❌ 避免：不必要地使用 GLOBAL 变量
VariableOperations.set_variable(context, "temp", BaseVariable.VariableScope.GLOBAL, temp_result)
```

---

### 2. 使用 SCOPE 变量替代部分 GLOBAL 变量

**理由:**
- 更好的封装性
- 自动清理（随节点销毁）
- 支持作用域链继承

**示例:**
```gdscript
# ❌ 不推荐：UI 数据使用全局变量
VariableOperations.set_variable(context, "ui_hp", BaseVariable.VariableScope.GLOBAL, 100)

# ✅ 推荐：UI 数据使用作用域变量
# 在 UI 根节点添加 ScopeVariableContainer
VariableOperations.set_variable(context, "hp", BaseVariable.VariableScope.SCOPE, 100)
```

---

### 3. 为变量使用清晰的前缀

**建议:**
- LOCAL 变量：`temp_` 前缀
- SCOPE 变量：按功能分组（如 `ui_`, `player_`, `enemy_`）
- GLOBAL 变量：使用描述性名称（如 `player_level`, `game_difficulty`）

**示例:**
```gdscript
# LOCAL 变量
"temp_distance"
"temp_index"
"temp_result"

# SCOPE 变量
"ui_hp"
"ui_score"
"player_current_state"
"enemy_spawn_count"

# GLOBAL 变量
"player_level"
"game_difficulty"
"audio_master_volume"
"current_scene_name"
```

---

### 4. 验证 SCOPE 作用域的前提条件

**代码模板:**
```gdscript
func validate() -> Array[String]:
    var errors = super.validate()

    # 验证变量名
    if variable_name.is_empty():
        errors.append("变量名不能为空")

    # 验证 SCOPE 作用域需要 ScopeVariableManager
    if variable_scope == BaseVariable.VariableScope.SCOPE:
        var manager = ScopeVariableManager.get_instance()
        if manager == null:
            errors.append("未找到 ScopeVariableManager 实例")

    return errors
```

---

### 5. 使用 has_variable 检查变量存在性

**场景:** 区分"变量不存在"和"变量值为 null"

**示例:**
```gdscript
var value = VariableOperations.get_variable(
    context,
    "my_variable",
    BaseVariable.VariableScope.GLOBAL,
    null
)

# 检查变量是否真的存在
if not VariableOperations.has_variable(context, "my_variable", BaseVariable.VariableScope.GLOBAL):
    _log_error("变量 '%s' 不存在" % "my_variable")
    return

# 此时 value 为 null 是有效的（变量确实存在，但值为 null）
```

---

### 6. 使用 VariableScopeUtils 统一显示格式

**推荐:**
```gdscript
func _update_resource_name():
    var scope_str = VariableScopeUtils.enum_to_string(save_to_scope).to_upper()
    resource_name = "Set %s → %s [%s]" % [target_property, variable_name, scope_str]

func get_description() -> String:
    var scope_str = VariableScopeUtils.enum_to_string(save_to_scope).to_upper()
    return "设置 %s = %s [%s]" % [target_property, value, scope_str]
```

---

## ScopeSource 架构设计

### 什么是 ScopeSource？

**ScopeSource** 是一个辅助枚举，用于在选择 SCOPE 作用域时，**指定使用哪个 SCOPE 容器**。它不是变量作用域的替代品，而是 SCOPE 作用域的补充配置。

**核心原则：**

```
第一层：选择变量作用域（LOCAL/SCOPE/GLOBAL）
    ↓
第二层：如果选择了 SCOPE，再选择使用哪个 SCOPE 容器（NEAREST/CUSTOM_ID/TRIGGER_SCOPE/TARGET_NODE）
```

### ScopeSource 枚举定义

```gdscript
# 在每个需要使用 SCOPE 作用域的组件中定义本地枚举
enum ScopeSource {
    NEAREST,        ## 最近的作用域容器（默认）
    CUSTOM_ID,      ## 指定 scope_id
    TRIGGER_SCOPE,  ## Trigger 节点上的作用域
    TARGET_NODE     ## Target 节点上的作用域
}
```

### 正确架构模式

#### 标准单作用域写入模式

```gdscript
## 第一步：添加 VariableScope 枚举（三层变量系统）
@export var save_to_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
    set(value):
        save_to_scope = value
        _update_resource_name()
        notify_property_list_changed()

## 第二步：添加 ScopeSource（仅当 save_to_scope == SCOPE 时使用）
var scope_source: ScopeSource = ScopeSource.NEAREST:
    set(value):
        scope_source = value
        _update_resource_name()
        notify_property_list_changed()

var custom_scope_id: String = ""
var target_node_path: NodePath = NodePath("")

## 第三步：属性列表控制（条件化 ScopeSource 显示）
func _get_property_list()  -> Array[Dictionary]:
    var properties := []

    # 始终显示 save_to_scope
    properties.append({
        name = "save_to_scope",
        type = TYPE_INT,
        hint = PROPERTY_HINT_ENUM,
        hint_string = "Local,Scope,Global"
    })

    # 只在 save_to_scope == SCOPE 时显示 ScopeSource
    if save_to_scope == BaseVariable.VariableScope.SCOPE:
        properties.append({
            name = "scope_source",
            type = TYPE_INT,
            hint = PROPERTY_HINT_ENUM,
            hint_string = "Nearest,Custom ID,Trigger Scope,Target Node"
        })

        # 根据 scope_source 添加额外属性
        if scope_source == ScopeSource.CUSTOM_ID:
            properties.append({ name = "custom_scope_id", ... })
        elif scope_source == ScopeSource.TARGET_NODE:
            properties.append({ name = "target_node_path", ... })

    return properties

## 第四步：执行逻辑（根据作用域类型分支）
func execute(context: ExecutionContext):
    var value_to_save = ... # 获取要保存的值

    match save_to_scope:
        BaseVariable.VariableScope.LOCAL:
            VariableOperations.set_variable(context, save_to_variable, BaseVariable.VariableScope.LOCAL, value_to_save)

        BaseVariable.VariableScope.SCOPE:
            if scope_source == ScopeSource.NEAREST:
                VariableOperations.set_variable(context, save_to_variable, BaseVariable.VariableScope.SCOPE, value_to_save)
            else:
                var utils_scope_source = scope_source as VariableScopeUtils.ScopeSource
                var scope_container = VariableScopeUtils.get_scope_container_by_source(
                    context, utils_scope_source, custom_scope_id, target_node_path
                )
                scope_container.set_variable(save_to_variable, value_to_save)

        BaseVariable.VariableScope.GLOBAL:
            VariableOperations.set_variable(context, save_to_variable, BaseVariable.VariableScope.GLOBAL, value_to_save)

## 第五步：属性验证（条件化 ScopeSource 属性可见性）
func _validate_property(property: Dictionary) -> void:
    if save_to_scope == BaseVariable.VariableScope.SCOPE:
        VariableScopeUtils.validate_scope_source_property(property, scope_source as VariableScopeUtils.ScopeSource)
    else:
        # 非 SCOPE 作用域时隐藏 ScopeSource 相关属性
        if property.name in ["scope_source", "custom_scope_id", "target_node_path"]:
            property.usage = PROPERTY_USAGE_NO_EDITOR

## 第六步：参数验证（只在 SCOPE 时验证 ScopeSource）
func validate() -> Array[String]:
    var errors = super.validate()

    # 基础验证
    if save_to_variable.is_empty():
        errors.append(...)

    # 只在 SCOPE 作用域时验证 ScopeSource 参数
    if save_to_scope == BaseVariable.VariableScope.SCOPE:
        var utils_scope_source = scope_source as VariableScopeUtils.ScopeSource
        errors.append_array(VariableScopeUtils.validate_scope_source_params(
            utils_scope_source, custom_scope_id, target_node_path
        ))

    return errors
```

#### 双作用域模式（SetVariable 示例）

```gdscript
# 目标变量作用域（写入）
@export var target_variable_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL
var scope_source: ScopeSource = ScopeSource.NEAREST  # 只在 target_variable_scope == SCOPE 时使用

# 源变量作用域（读取）
@export var from_variable_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL
var from_scope_source: ScopeSource = ScopeSource.NEAREST  # 只在 from_variable_scope == SCOPE 时使用

# 属性列表控制
func _get_property_list()  -> Array[Dictionary]:
    var properties := []

    # 目标作用域配置
    properties.append({ name = "target_variable_scope", ... })
    if target_variable_scope == BaseVariable.VariableScope.SCOPE:
        properties.append({ name = "scope_source", ... })
        # 根据 scope_source 添加额外属性

    # 源作用域配置
    if set_with_another_variable:
        properties.append({ name = "from_variable_scope", ... })
        if from_variable_scope == BaseVariable.VariableScope.SCOPE:
            properties.append({ name = "from_scope_source", ... })
            # 根据 from_scope_source 添加额外属性

    return properties
```

### 常见架构错误

#### ❌ 错误 1：移除 VariableScope，只使用 ScopeSource

**错误代码：**
```gdscript
# ❌ 错误：没有 VariableScope，只有 ScopeSource
var scope_source: ScopeSource = ScopeSource.NEAREST

func execute(context: ExecutionContext):
    # 无法选择 LOCAL 或 GLOBAL，只能使用 SCOPE
    if scope_source == ScopeSource.NEAREST:
        VariableOperations.set_variable(context, var_name, BaseVariable.VariableScope.SCOPE, value)
```

**问题：**
- 用户无法设置 LOCAL 或 GLOBAL 变量
- 所有变量都被强制使用 SCOPE 作用域
- ScopeSource 被滥用，应该只在选择 SCOPE 作用域时才显示

**正确做法：**
```gdscript
# ✅ 正确：保留 VariableScope，条件化 ScopeSource
@export var save_to_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL
var scope_source: ScopeSource = ScopeSource.NEAREST  # 只在 save_to_scope == SCOPE 时使用

func execute(context: ExecutionContext):
    match save_to_scope:
        BaseVariable.VariableScope.LOCAL:
            VariableOperations.set_variable(context, var_name, BaseVariable.VariableScope.LOCAL, value)
        BaseVariable.VariableScope.SCOPE:
            if scope_source == ScopeSource.NEAREST:
                VariableOperations.set_variable(context, var_name, BaseVariable.VariableScope.SCOPE, value)
        BaseVariable.VariableScope.GLOBAL:
            VariableOperations.set_variable(context, var_name, BaseVariable.VariableScope.GLOBAL, value)
```

#### ❌ 错误 2：ScopeSource 属性始终显示

**错误代码：**
```gdscript
# ❌ 错误：ScopeSource 相关属性始终显示
func _get_property_list()  -> Array[Dictionary]:
    var properties := []

    properties.append({ name = "save_to_scope", ... })
    properties.append({ name = "scope_source", ... })  # 始终显示
    properties.append({ name = "custom_scope_id", ... })  # 始终显示

    return properties
```

**问题：**
- 当用户选择 LOCAL 或 GLOBAL 时，ScopeSource 选项无意义但仍然显示
- 用户界面混乱，不知道这些选项何时有效

**正确做法：**
```gdscript
# ✅ 正确：条件化 ScopeSource 显示
func _get_property_list() -> Array[Dictionary]:
    var properties := []

    properties.append({ name = "save_to_scope", ... })

    # 只在 save_to_scope == SCOPE 时显示
    if save_to_scope == BaseVariable.VariableScope.SCOPE:
        properties.append({ name = "scope_source", ... })
        if scope_source == ScopeSource.CUSTOM_ID:
            properties.append({ name = "custom_scope_id", ... })

    return properties
```

#### ❌ 错误 3：属性验证未条件化

**错误代码：**
```gdscript
# ❌ 错误：始终验证 ScopeSource 属性
func _validate_property(property: Dictionary) -> void:
    VariableScopeUtils.validate_scope_source_property(property, scope_source as VariableScopeUtils.ScopeSource)
```

**问题：**
- 即使选择 LOCAL 或 GLOBAL，仍然验证 ScopeSource 属性
- 可能导致不必要的错误信息

**正确做法：**
```gdscript
# ✅ 正确：条件化验证
func _validate_property(property: Dictionary) -> void:
    if save_to_scope == BaseVariable.VariableScope.SCOPE:
        VariableScopeUtils.validate_scope_source_property(property, scope_source as VariableScopeUtils.ScopeSource)
    else:
        # 非 SCOPE 作用域时隐藏 ScopeSource 相关属性
        if property.name in ["scope_source", "custom_scope_id", "target_node_path"]:
            property.usage = PROPERTY_USAGE_NO_EDITOR
```

### ScopeSource 与 VariableScope 的关系

| 概念 | VariableScope | ScopeSource |
|------|--------------|-------------|
| **作用** | 选择变量存储层级 | 指定使用哪个 SCOPE 容器 |
| **层级** | 第一层选择 | 第二层选择（仅在 SCOPE 时） |
| **必需性** | 必需（所有组件） | 可选（仅在 SCOPE 时需要） |
| **默认值** | LOCAL | NEAREST |
| **显示条件** | 始终显示 | 只在 VariableScope == SCOPE 时显示 |
| **枚举定义** | BaseVariable.VariableScope | 各组件本地定义 |

### 工具方法

VariableScopeUtils 提供了 ScopeSource 相关的工具方法：

```gdscript
# 验证 ScopeSource 属性可见性
static func validate_scope_source_property(
    property: Dictionary,
    scope_source: ScopeSource
)

# 验证 ScopeSource 参数
static func validate_scope_source_params(
    scope_source: ScopeSource,
    custom_scope_id: String,
    target_node_path: NodePath
) -> Array[String]

# 获取 ScopeSource 字符串表示
static func get_scope_source_string(
    scope_source: ScopeSource,
    custom_scope_id: String,
    target_node_path: NodePath
) -> String

# 根据 ScopeSource 获取容器
static func get_scope_container_by_source(
    context: ExecutionContext,
    scope_source: ScopeSource,
    custom_scope_id: String,
    target_node_path: NodePath
) -> ScopeVariableContainer
```

### 参考实现

**完全正确的实现：** `addons/fuse/instructions/variables/create_variable.gd`

**已修复的组件：**
1. `addons/fuse/instructions/math/random_number.gd`
2. `addons/fuse/instructions/math/clamp_value.gd`
3. `addons/fuse/instructions/math/math_operation.gd`
4. `addons/fuse/instructions/math/lerp.gd`
5. `addons/fuse/instructions/math/vector_operation.gd`
6. `addons/fuse/instructions/variables/set_variable.gd`
7. `addons/fuse/instructions/scene/get_scene_path.gd`

### 修复文档

详细的修复指南和进度报告（历史文档，已归档）：
- [修复进度报告](../../archive/archive/development/scope_source_fix_progress.md)
- [剩余修复指南](../../archive/archive/development/remaining_fixes_guide.md)
- [待办事项列表](../../archive/archive/development/scope_source_todos.md)

---

## 常见问题

### Q1: 什么时候应该使用 SCOPE 变量？

**A:** 当你需要：
1. 在场景的某个区域共享数据（如 UI 容器、敌人生成区域）
2. 数据生命周期与场景节点绑定
3. 支持作用域链继承（子作用域可访问父作用域）

**不用于:**
- 全局游戏配置（应使用 GLOBAL）
- 单次指令临时数据（应使用 LOCAL）

---

### Q2: SCOPE 变量为 null 报错怎么办？

**A:** 检查以下几点：
1. 场景中是否添加了 `ScopeVariableContainer` 节点
2. 是否设置了 `scope_id`
3. `ScopeVariableManager` 实例是否存在
4. 节点是否在场景树中

**验证代码:**
```gdscript
func validate() -> Array[String]:
    var errors = super.validate()

    if value_scope == BaseVariable.VariableScope.SCOPE:
        var manager = ScopeVariableManager.get_instance()
        if manager == null:
            errors.append("未找到 ScopeVariableManager 实例")

    return errors
```

---

### Q3: LOCAL 变量的生命周期有多长？

**A:** LOCAL 变量存储在 `ExecutionContext.local_variables` 中，生命周期与执行上下文相同：
- 事件触发时创建
- 事件执行完毕后销毁
- 无法跨事件共享

**如需跨指令共享，请使用 SCOPE 或 GLOBAL 变量。**

---

### Q4: 如何在编辑器中调试变量值？

**A:**
1. **LOCAL 变量:** 在指令中添加 `PrintVariableValue` 指令
2. **SCOPE 变量:** 选中 `ScopeVariableContainer` 节点，在 Inspector 中查看 `variables` 字典
3. **GLOBAL 变量:** 选中 `GlobalVariableAssistant` 节点，查看 `current_resource`

---

### Q5: 变量作用域会影响性能吗？

**A:** 性能排序（从快到慢）：
1. **LOCAL** - 直接字典访问，最快
2. **SCOPE** - 需要查找容器节点，稍慢
3. **GLOBAL** - 需要通过管理器访问，相对较慢

**建议:** 优先使用 LOCAL 变量，除非确实需要共享数据。

### Q6: ScopeSource 和 VariableScope 有什么区别？

**A:** 这是两个不同层级的概念：

| 层级 | 概念 | 作用 | 示例 |
|------|------|------|------|
| **第一层** | VariableScope | 选择变量存储层级 | LOCAL、SCOPE、GLOBAL |
| **第二层** | ScopeSource | 指定使用哪个 SCOPE 容器 | NEAREST、CUSTOM_ID、TRIGGER_SCOPE、TARGET_NODE |

**类比：**
- VariableScope 像"选择城市"（北京、上海、深圳）
- ScopeSource 像"选择具体区域"（只在选择某个城市后，才选择该城市的哪个区）

**示例：**
```gdscript
# 第一层：选择 SCOPE 作用域
@export var save_to_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.SCOPE

# 第二层：如果选择了 SCOPE，再选择使用哪个容器
var scope_source: ScopeSource = ScopeSource.NEAREST
```

---

### Q7: 为什么需要 ScopeSource？不能直接用 NEAREST？

**A:** ScopeSource 提供了灵活性，让用户可以精确指定使用哪个作用域容器：

**NEAREST（默认）：** 使用最近的 ScopeVariableContainer
- **适用场景：** 大多数情况
- **优点：** 简单方便
- **缺点：** 可能不是预期的容器

**CUSTOM_ID：** 使用指定 scope_id 的容器
- **适用场景：** 明确知道要使用哪个容器
- **优点：** 精确控制
- **缺点：** 需要手动配置 scope_id

**TRIGGER_SCOPE：** 使用 Trigger 节点上的容器
- **适用场景：** 事件触发器相关的变量
- **优点：** 与事件系统紧密结合
- **缺点：** 需要 Trigger 节点有 ScopeVariableContainer

**TARGET_NODE：** 使用目标节点上的容器
- **适用场景：** 需要操作目标对象的变量
- **优点：** 灵活指定
- **缺点：** 需要手动配置节点路径

**示例场景：**
```
场景树：
├── GameUI (ScopeVariableContainer, scope_id: "ui")
├── Player (ScopeVariableContainer, scope_id: "player")
└── Enemy (ScopeVariableContainer, scope_id: "enemy")
    └── EnemyAI
        └── Trigger (触发器)
            └── Instruction (需要读取玩家血量)
```

在 EnemyAI 的指令中读取玩家血量：
- **NEAREST：** 会读取 Enemy 的作用域（错误）
- **CUSTOM_ID：** 指定 scope_id="player"（正确）
- **TARGET_NODE：** 指定节点路径指向 Player（正确）

---

### Q8: 如何判断组件是否需要 ScopeSource？

**A:** 只有当组件需要支持 SCOPE 作用域时，才需要添加 ScopeSource。

**判断流程：**

```
1. 组件需要读写变量吗？
   ├─ 否 → 不需要 ScopeSource
   └─ 是 → 继续

2. 组件需要支持 SCOPE 作用域吗？
   ├─ 否 → 只需要 LOCAL/GLOBAL，不需要 ScopeSource
   └─ 是 → 继续

3. 组件需要指定使用哪个 SCOPE 容器吗？
   ├─ 否 → 只使用 NEAREST，可以简化不需要 ScopeSource
   └─ 是 → 需要添加 ScopeSource 支持
```

**示例：**

**不需要 ScopeSource：**
```gdscript
# 只支持 LOCAL 和 GLOBAL
@export var save_to_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL
# 不需要 ScopeSource
```

**需要 ScopeSource：**
```gdscript
# 支持 LOCAL/SCOPE/GLOBAL 三层
@export var save_to_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL

# SCOPE 时需要指定容器
var scope_source: ScopeSource = ScopeSource.NEAREST
var custom_scope_id: String = ""
var target_node_path: NodePath = NodePath("")
```

---

## 已重构的指令列表

### Math 指令（5个）
- ✅ `MathOperation` - 数学运算（2026-02-10 添加 save_to_scope）
- ✅ `Lerp` - 线性插值（2026-02-10 添加 save_to_scope）
- ✅ `ClampValue` - 数值限制（2026-02-10 添加 save_to_scope）
- ✅ `RandomNumber` - 随机数（2026-02-10 添加 save_to_scope）
- ✅ `VectorOperation` - 向量运算（2026-02-10 添加 save_to_scope）

### Transform 指令（6个）
- ✅ `SetPosition` - 设置位置
- ✅ `SetRotation` - 设置旋转
- ✅ `SetScale` - 设置缩放
- ✅ `RotateBy` - 旋转偏移
- ✅ `MoveBy` - 移动偏移
- ✅ `LookAt` - 朝向目标

### UI 指令（3个）
- ✅ `SetUIText` - 设置文本
- ✅ `SetUITexture` - 设置纹理
- ✅ `SetUIProgress` - 设置进度条

### Camera 指令（1个）
- ✅ `SetCameraZoom` - 设置相机缩放

### Animation 指令（1个）
- ✅ `BlendAnimation` - 混合动画

### Time 指令（1个）
- ✅ `GetDeltaTime` - 获取时间增量

### Scene 指令（2个）
- ✅ `GetScenePath` - 获取场景路径（2026-02-10 添加 save_to_scope）
- ✅ `LoadSceneBackground` - 后台加载场景

### Variables 指令（2个）
- ✅ `SetVariable` - 设置变量（2026-02-10 添加双作用域枚举）
- ✅ `CreateVariable` - 创建变量（参考实现，完全正确）

### Node Operations 指令（3个）
- ✅ `FindNode` - 查找节点
- ✅ `InstantiateScene` - 实例化场景
- ✅ `SetPropertyValue` - 设置属性值

### Physics 指令（1个）
- ✅ `Raycast` - 射线检测

### Debug 指令（1个）
- ✅ `PrintVariableValue` - 打印变量值（修复了资源名称显示bug）

**总计:** 27 个指令已重构 ✅

**2026-02-10 更新：** 7 个组件添加了完整的 ScopeSource 支持（条件化显示）

---

## 参考资源

### 核心类文件
- `addons/fuse/core/utils/variable_operations.gd` - 统一变量访问接口
- `addons/fuse/core/utils/variable_scope_utils.gd` - 作用域工具类
- `addons/fuse/core/base/base_variable.gd` - VariableScope 枚举定义
- `addons/fuse/core/base/execution_context.gd` - 执行上下文
- `addons/fuse/core/scope_variable_manager.gd` - 作用域变量管理器
- `addons/fuse/core/base/scope_variable_container.gd` - 作用域变量容器
- `addons/fuse/core/global_variable_manager.gd` - 全局变量管理器
- `addons/fuse/core/global_variable_assistant.gd` - 全局变量助手

### 示例指令
- `addons/fuse/instructions/math/math_operation.gd`
- `addons/fuse/instructions/math/lerp.gd`
- `addons/fuse/instructions/math/vector_operation.gd`
- `addons/fuse/instructions/transform/set_position.gd`
- `addons/fuse/instructions/time/get_delta_time.gd`

### 文档
- `addons/fuse/docs/system_docs/execution_system.md` - 执行系统文档
- `addons/fuse/docs/user_docs/instruction_development_guide.md` - 指令开发指南

---

## 版本历史

### v3.1 (2026-02-10) - ScopeSource 架构修复
- ✅ **修复关键架构错误** - ScopeSource 不能替代三层变量系统
- ✅ **明确架构原则** - VariableScope（三层）+ ScopeSource（仅在 SCOPE 时显示）
- ✅ **修复 7 个组件** - random_number, set_variable, get_scene_path, clamp_value, math_operation, lerp, vector_operation
- ✅ **建立标准模式** - 条件化 ScopeSource 显示的 6 步修复模式
- ⚠️ **重要教训** - ScopeSource 只用于指定"哪个 SCOPE 容器"，不能替代 VariableScope 枚举

**架构错误回顾：**
- **错误做法**：移除 VariableScope 枚举，只使用 ScopeSource
- **正确做法**：保留 VariableScope（LOCAL/SCOPE/GLOBAL），ScopeSource 仅在 SCOPE 时显示

### v3.0 (2026-02-09)
- ✅ 添加三层变量架构（LOCAL/SCOPE/GLOBAL）
- ✅ 引入 `VariableOperations` 统一访问接口
- ✅ 引入 `VariableScopeUtils` 工具类
- ✅ 重构 25 个指令使用新 API
- ✅ 移除 `is_global: bool` 属性
- ✅ 使用类型安全的 `VariableScope` 枚举

### v2.0 (2026-01-25)
- 移除了 TRIGGER 作用域
- 仅保留 LOCAL 和 GLOBAL（此版本文档有误，实际上 SCOPE 已添加）

### v1.0 (初始版本)
- 基础的 LOCAL/GLOBAL 二层变量系统

---

## 附录：完整的指令重构模板

```gdscript
## 重构变量系统: 2026-02-09 - 使用 VariableOperations 统一变量访问

@tool
extends BaseInstruction
class_name MyInstruction

## 输入变量名
var input_variable: String = ""

## 输入变量作用域
@export var input_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
    set(value):
        input_scope = value
        _update_resource_name()

## 输出变量名
var output_variable: String = "result"

## 输出变量作用域
@export var output_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
    set(value):
        output_scope = value
        _update_resource_name()

## 执行指令
func execute(context: ExecutionContext):
    _start_execution(context)

    # 读取输入变量
    var input_value = VariableOperations.get_variable(
        context,
        input_variable,
        input_scope,
        null
    )

    # 检查变量是否存在
    if input_value == null and not VariableOperations.has_variable(
        context,
        input_variable,
        input_scope
    ):
        _log_error_localized("FUSE_ERROR_VAR_NOT_FOUND", {"variable": input_variable})
        set_error_localized("FUSE_ERROR_VAR_NOT_FOUND", FuseError.ErrorType.VALIDATION_ERROR, {"variable": input_variable})
        finished.emit()
        return

    # 执行操作
    var result = _process_value(input_value)

    # 保存结果
    VariableOperations.set_variable(
        context,
        output_variable,
        output_scope,
        result
    )

    _on_execution_completed()

## 更新资源名称
func _update_resource_name():
    var parts := []

    parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_MY_INSTRUCTION_RESOURCE"))

    if not input_variable.is_empty():
        var input_scope_str = VariableScopeUtils.enum_to_string(input_scope).to_upper()
        parts.append("← %s [%s]" % [input_variable, input_scope_str])
    else:
        parts.append("← (%s)" % FuseLocalization.translate("FUSE_VALUE_VARIABLE_EMPTY"))

    parts.append("→")

    if not output_variable.is_empty():
        var output_scope_str = VariableScopeUtils.enum_to_string(output_scope).to_upper()
        parts.append("%s [%s]" % [output_variable, output_scope_str])
    else:
        parts.append("(%s)" % FuseLocalization.translate("FUSE_VALUE_VARIABLE_EMPTY"))

    resource_name = " ".join(parts)

## 验证指令参数
func validate() -> Array[String]:
    var errors = super.validate()

    # 验证输入变量名
    if input_variable.is_empty():
        errors.append(FuseLocalization.translate("FUSE_ERROR_INPUT_VAR_NAME_EMPTY"))

    # 验证输出变量名
    if output_variable.is_empty():
        errors.append(FuseLocalization.translate("FUSE_ERROR_OUTPUT_VAR_NAME_EMPTY"))

    # 验证 SCOPE 作用域需要 ScopeVariableManager
    if input_scope == BaseVariable.VariableScope.SCOPE:
        var manager = ScopeVariableManager.get_instance()
        if manager == null:
            errors.append(FuseLocalization.translate("FUSE_ERROR_SCOPE_MANAGER_NOT_FOUND"))

    if output_scope == BaseVariable.VariableScope.SCOPE:
        var manager = ScopeVariableManager.get_instance()
        if manager == null:
            errors.append(FuseLocalization.translate("FUSE_ERROR_SCOPE_MANAGER_NOT_FOUND"))

    return errors

## 获取指令描述
func get_description() -> String:
    var input_scope_str = VariableScopeUtils.enum_to_string(input_scope).to_upper()
    var output_scope_str = VariableScopeUtils.enum_to_string(output_scope).to_upper()

    var input_str = input_variable if not input_variable.is_empty() else "(%s)" % FuseLocalization.translate("FUSE_VALUE_VARIABLE_EMPTY")
    var output_str = output_variable if not output_variable.is_empty() else "(%s)" % FuseLocalization.translate("FUSE_VALUE_VARIABLE_EMPTY")

    return FuseLocalization.translate_format("FUSE_INSTRUCTION_MY_INSTRUCTION_DESC_FORMAT", {
        "input": "%s [%s]" % [input_str, input_scope_str],
        "output": "%s [%s]" % [output_str, output_scope_str]
    })

## 动态属性设置
func _set(property: StringName, value: Variant) -> bool:
    if property == "input_scope" or property == "output_scope":
        set(property, value)
        notify_property_list_changed()
        _update_resource_name()
        return true
    return false

## 内部处理方法
func _process_value(value: Variant) -> Variant:
    # 实现具体的处理逻辑
    return value
```

---

**文档结束**

## 架构更新（2026-03）

- VariableContainer 已标记 @deprecated
- 新增 ScopeVariableContainer / ScopeVariableManager 作用域变量系统
- 新增 GlobalVariableAssistant / GlobalVariableManager 全局变量系统
- 新增 VariableOperations / VariableScopeUtils 统一访问工具类
- VariableScope 枚举扩展：LOCAL / GLOBAL / SCOPE
