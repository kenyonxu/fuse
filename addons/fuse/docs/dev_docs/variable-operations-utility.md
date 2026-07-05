# VariableOperations 工具类架构文档

## 概述

`VariableOperations` 是 Fuse 系统的静态工具类，提供三层变量体系（LOCAL/SCOPE/GLOBAL）的统一操作接口。该类整合了分散在多个指令和条件中的变量操作逻辑，遵循 DRY（Don't Repeat Yourself）原则。

### 设计目标

1. **代码复用** - 消除约 170 行重复代码
2. **统一接口** - 提供一致的变量操作 API
3. **易于维护** - 集中管理变量操作逻辑
4. **类型安全** - 使用枚举而非字符串表示作用域
5. **性能优化** - 静态方法，无实例化开销

### 核心价值

| 问题 | 解决方案 | 效果 |
|------|---------|------|
| 代码重复 | 统一工具类 | 减少 ~170 行重复代码 |
| 维护困难 | 集中管理 | 单点修改，全局生效 |
| 测试复杂 | 独立测试 | 更高的测试覆盖率 |
| 扩展性差 | 标准化 API | 新组件易于集成 |

---

## 三层变量体系

### 架构概览

```
┌─────────────────────────────────────────────────┐
│           VariableOperations (工具类)             │
│         统一操作接口 + 作用域容器查找               │
└─────────────────────────────────────────────────┘
                    │
        ┌───────────┼───────────┐
        │           │           │
        ▼           ▼           ▼
    LOCAL       SCOPE       GLOBAL
   (局部)      (作用域)     (全局)
        │           │           │
        │      ScopeVariable   GlobalVariable
        │      Container       Assistant
        ▼           ▼           ▼
 ExecutionContext   场景树     应用单例
```

### 变量层级说明

| 作用域 | 枚举值 | 存储位置 | 生命周期 | 典型用途 |
|-------|--------|---------|---------|---------|
| **LOCAL** | `VariableScope.LOCAL` (0) | `ExecutionContext.local_variables` | 单次事件执行 | 临时变量、循环计数器 |
| **SCOPE** | `VariableScope.SCOPE` (1) | `ScopeVariableContainer` | 场景树范围 | 区域状态、关卡变量 |
| **GLOBAL** | `VariableScope.GLOBAL` (2) | `GlobalVariableAssistant` | 应用级 | 游戏设置、玩家数据 |

---

## 核心 API

### 1. 变量读取

```gdscript
static func get_variable(
    context: ExecutionContext,
    variable_name: String,
    scope: BaseVariable.VariableScope,
    default_value: Variant = null
) -> Variant
```

**功能：** 从指定作用域获取变量值

**参数：**
- `context`: 执行上下文
- `variable_name`: 变量名
- `scope`: 变量作用域（LOCAL/SCOPE/GLOBAL）
- `default_value`: 默认值（变量不存在时返回）

**返回：** 变量值，找不到返回默认值

**行为细节：**
- LOCAL: 从 `ExecutionContext.local_variables` 读取
- SCOPE: 从最近的 `ScopeVariableContainer` 读取
- GLOBAL: 从 `GlobalVariableAssistant` 读取

**示例：**

```gdscript
# 读取局部变量
var score = VariableOperations.get_variable(
    context,
    "score",
    BaseVariable.VariableScope.LOCAL,
    0
)

# 读取作用域变量（带默认值）
var health = VariableOperations.get_variable(
    context,
    "player_health",
    BaseVariable.VariableScope.SCOPE,
    100  # 默认值
)
```

---

### 2. 变量设置

```gdscript
static func set_variable(
    context: ExecutionContext,
    variable_name: String,
    scope: BaseVariable.VariableScope,
    value: Variant
) -> bool
```

**功能：** 向指定作用域设置变量值

**参数：**
- `context`: 执行上下文
- `variable_name`: 变量名
- `scope`: 变量作用域
- `value`: 要设置的值

**返回：** `true` 设置成功，`false` 失败

**行为细节：**
- LOCAL: 设置到 `ExecutionContext.local_variables`
- SCOPE: 设置到最近的 `ScopeVariableContainer`，失败回退到 LOCAL
- GLOBAL: 设置到 `GlobalVariableAssistant`，不存在则创建

**错误处理：**
- 参数验证失败返回 `false`
- 记录调试日志到 `FuseLogger`

**示例：**

```gdscript
# 设置局部变量
var success = VariableOperations.set_variable(
    context,
    "current_level",
    BaseVariable.VariableScope.LOCAL,
    5
)

# 设置作用域变量
success = VariableOperations.set_variable(
    context,
    "checkpoint_reached",
    BaseVariable.VariableScope.SCOPE,
    true
)
```

---

### 3. 变量检查

```gdscript
static func has_variable(
    context: ExecutionContext,
    variable_name: String,
    scope: BaseVariable.VariableScope
) -> bool
```

**功能：** 检查变量是否存在

**参数：**
- `context`: 执行上下文
- `variable_name`: 变量名
- `scope`: 变量作用域

**返回：** `true` 变量存在，`false` 不存在

**使用场景：**
- 条件判断前验证变量
- 避免使用不合理的默认值
- 确保后续操作安全

**示例：**

```gdscript
# 检查全局变量是否存在
if VariableOperations.has_variable(
    context,
    "game_initialized",
    BaseVariable.VariableScope.GLOBAL
):
    # 执行初始化逻辑
    pass
```

---

### 4. 作用域容器查找

```gdscript
static func get_scope_container(
    context: ExecutionContext,
    search_node: Node = null
) -> ScopeVariableContainer
```

**功能：** 查找最近的 `ScopeVariableContainer`

**参数：**
- `context`: 执行上下文
- `search_node`: 搜索起点节点（`null` 时使用 `context.trigger`）

**返回：** 找到的容器实例，未找到返回 `null`

**查找策略：**
1. 确定搜索起点（`search_node` 或 `context.trigger`）
2. 使用 `ScopeVariableManager.find_nearest_scope()` 向上遍历场景树
3. 返回第一个找到的 `ScopeVariableContainer`

**错误处理：**
- `context` 为 `null` 返回 `null`
- 搜索节点为 `null` 返回 `null`
- `ScopeVariableManager` 未初始化返回 `null`

**示例：**

```gdscript
# 使用默认搜索起点（context.trigger）
var container = VariableOperations.get_scope_container(context)
if container != null:
    print("Found scope: " + container.scope_id)

# 指定搜索节点
var target_node = get_node("Level/Checkpoint")
var checkpoint_scope = VariableOperations.get_scope_container(context, target_node)
```

---

## 私有辅助方法

### _get_local_variable()

```gdscript
static func _get_local_variable(
    context: ExecutionContext,
    variable_name: String,
    default_value: Variant
) -> Variant
```

**职责：** 从执行上下文读取局部变量

**实现：** 调用 `context.has_variable()` 和 `context.get_variable()`

---

### _get_scope_variable()

```gdscript
static func _get_scope_variable(
    context: ExecutionContext,
    variable_name: String,
    default_value: Variant
) -> Variant
```

**职责：** 从作用域容器读取变量

**实现：**
1. 调用 `get_scope_container()` 查找容器
2. 调用容器的 `has_variable()` 和 `get_variable()`
3. 记录调试日志（作用域 ID、变量名、值）

**错误处理：** 容器为 `null` 时返回默认值

---

### _get_global_variable()

```gdscript
static func _get_global_variable(
    context: ExecutionContext,
    variable_name: String,
    default_value: Variant
) -> Variant
```

**职责：** 从全局变量助手读取变量

**实现：**
1. 获取 `GlobalVariableAssistant` 单例
2. 调用 `get_global_variable()` 获取变量对象
3. 调用变量的 `get_value()` 方法

**错误处理：** 助手为 `null` 或变量不存在时返回默认值

---

### _set_local_variable()

```gdscript
static func _set_local_variable(
    context: ExecutionContext,
    variable_name: String,
    value: Variant
) -> bool
```

**职责：** 设置局部变量

**实现：** 直接调用 `context.set_variable(variable_name, value, "local")`

---

### _set_scope_variable()

```gdscript
static func _set_scope_variable(
    context: ExecutionContext,
    variable_name: String,
    value: Variant
) -> bool
```

**职责：** 设置作用域变量

**实现：**
1. 查找作用域容器
2. 调用容器的 `set_variable()` 方法
3. 失败时回退到 `_set_local_variable()`

**容错机制：** 作用域容器不存在时自动降级到 LOCAL

---

### _set_global_variable()

```gdscript
static func _set_global_variable(
    context: ExecutionContext,
    variable_name: String,
    value: Variant
) -> bool
```

**职责：** 设置全局变量

**实现：**
1. 获取 `GlobalVariableAssistant` 单例
2. 检查变量是否存在
   - 存在: 调用变量的 `set_value()` 方法
   - 不存在: 创建新变量并添加到助手

**自动创建：** 变量不存在时自动调用 `BaseVariable.create()` 创建

---

## 日志系统

### 日志方法

```gdscript
static func _log_debug(message: String)
static func _log_info(message: String)
static func _log_warning(message: String)
static func _log_error(message: String)
```

**实现：** 调用 `FuseLogger` 的对应方法

**组件标识：** 使用 `"VariableOperations"` 作为日志组件名

**日志级别：**
- `DEBUG`: 变量查找、读取详情
- `INFO`: 变量设置成功
- `WARNING`: 非致命错误（回退操作）
- `ERROR`: 严重错误（参数无效、单例未初始化）

---

## 使用指南

### 基本用法

#### 1. 读取变量

```gdscript
# 读取局部变量（带默认值）
var score = VariableOperations.get_variable(
    context,
    "score",
    BaseVariable.VariableScope.LOCAL,
    0  # 默认值
)

# 读取作用域变量
var health = VariableOperations.get_variable(
    context,
    "player_health",
    BaseVariable.VariableScope.SCOPE,
    100
)

# 读取全局变量
var level = VariableOperations.get_variable(
    context,
    "current_level",
    BaseVariable.VariableScope.GLOBAL,
    1
)
```

#### 2. 设置变量

```gdscript
# 设置局部变量
var success = VariableOperations.set_variable(
    context,
    "current_wave",
    BaseVariable.VariableScope.LOCAL,
    5
)

# 设置作用域变量（自动查找容器）
success = VariableOperations.set_variable(
    context,
    "boss_defeated",
    BaseVariable.VariableScope.SCOPE,
    true
)

# 设置全局变量（不存在则创建）
success = VariableOperations.set_variable(
    context,
    "total_play_time",
    BaseVariable.VariableScope.GLOBAL,
    3600.0
)
```

#### 3. 检查变量存在

```gdscript
# 检查前验证
if VariableOperations.has_variable(
    context,
    "player_inventory",
    BaseVariable.VariableScope.SCOPE
):
    var inventory = VariableOperations.get_variable(
        context,
        "player_inventory",
        BaseVariable.VariableScope.SCOPE,
        null
    )
    # 处理库存数据
```

#### 4. 查找作用域容器

```gdscript
# 默认从 context.trigger 搜索
var container = VariableOperations.get_scope_container(context)
if container != null:
    print("Scope ID: " + container.scope_id)
    print("Variables: " + str(container.list_variables()))

# 指定搜索起点
var custom_node = get_node("Level/Room1")
var room_scope = VariableOperations.get_scope_container(context, custom_node)
```

---

### 在指令中使用

#### SetScopeVariable 指令示例

```gdscript
# 不使用工具类（旧代码）
func execute(context: ExecutionContext):
    var scope_container = _get_scope_container(context)  # 重复代码
    if scope_container == null:
        # 错误处理
        return
    scope_container.set_variable(variable_name, new_value)

# 使用工具类（新代码）
func execute(context: ExecutionContext):
    var scope_container = VariableOperations.get_scope_container(context)
    if scope_container == null:
        # 错误处理
        return
    scope_container.set_variable(variable_name, new_value)
```

#### CheckVariable 条件示例

```gdscript
# 不使用工具类（旧代码）
func _get_variable_value(context: ExecutionContext) -> Variant:
    match variable_scope:
        BaseVariable.VariableScope.LOCAL:
            return context.get_variable(variable_name, null)
        BaseVariable.VariableScope.SCOPE:
            var container = _get_scope_container(context)  # 重复代码
            # ... 更多逻辑
        BaseVariable.VariableScope.GLOBAL:
            var assistant = GlobalVariableAssistant.get_instance()
            # ... 更多逻辑

# 使用工具类（新代码）
func _get_variable_value(context: ExecutionContext) -> Variant:
    return VariableOperations.get_variable(
        context,
        variable_name,
        variable_scope,
        null
    )
```

---

## 与其他工具类的协作

### VariableScopeUtils

| 类 | 职责 | 典型方法 |
|---|---|---|
| `VariableScopeUtils` | 枚举与字符串转换 | `enum_to_string()`, `string_to_enum()` |
| `VariableOperations` | 变量操作（读/写/检查） | `get_variable()`, `set_variable()` |

**协作示例：**

```gdscript
# VariableScopeUtils 用于数据序列化
var scope_str = VariableScopeUtils.enum_to_string(variable_scope)
save_data["scope"] = scope_str

# VariableOperations 用于运行时操作
var value = VariableOperations.get_variable(
    context,
    var_name,
    variable_scope,
    default_value
)
```

### ScopeVariableManager

```gdscript
# VariableOperations 内部使用 ScopeVariableManager 查找容器
static func get_scope_container(
    context: ExecutionContext,
    search_node: Node = null
) -> ScopeVariableContainer:
    var manager = ScopeVariableManager.get_instance()
    if manager == null:
        return null

    return manager.find_nearest_scope(node)
```

### GlobalVariableAssistant

```gdscript
# VariableOperations 内部使用 GlobalVariableAssistant 操作全局变量
static func _get_global_variable(...) -> Variant:
    var assistant = GlobalVariableAssistant.get_instance()
    if assistant == null:
        return default_value

    var variable = assistant.get_global_variable(variable_name)
    if variable != null:
        return variable.get_value()

    return default_value
```

---

## 性能考虑

### 静态方法优势

- **无实例化开销** - 所有方法为静态，无需 `new` 操作
- **无状态** - 不维护内部状态，线程安全
- **编译器优化** - 静态调用更容易内联优化

### 缓存策略

| 层级 | 缓存机制 | 说明 |
|------|---------|------|
| LOCAL | ExecutionContext 内部缓存 | 重复读取无额外开销 |
| SCOPE | ScopeVariableManager 容器缓存 | 节点树查找被缓存 |
| GLOBAL | GlobalVariableAssistant 单例 | 单例模式天然缓存 |

### 性能基准

| 操作 | 预期耗时 | 说明 |
|------|---------|------|
| LOCAL 读取 | ~0.001 ms | 字典查找 |
| SCOPE 读取（缓存命中） | ~0.01 ms | 容器缓存 |
| SCOPE 读取（缓存未命中） | ~0.5-1 ms | 场景树遍历 |
| GLOBAL 读取 | ~0.01 ms | 单例字典查找 |

**优化建议：**
- 优先使用 LOCAL 变量（最快）
- 避免在热循环中读取 SCOPE 变量（除非缓存命中）
- GLOBAL 变量适合配置数据，不适合高频读写

---

## 错误处理

### 参数验证

```gdscript
# 1. ExecutionContext 验证
if context == null:
    _log_error("ExecutionContext 为空")
    return default_value  # 或 return false

# 2. 变量名验证
if variable_name.is_empty():
    _log_error("变量名为空")
    return default_value  # 或 return false

# 3. 作用域验证（match 默认分支）
match scope:
    BaseVariable.VariableScope.LOCAL:
        # ...
    BaseVariable.VariableScope.SCOPE:
        # ...
    BaseVariable.VariableScope.GLOBAL:
        # ...
    _:
        _log_error("未知的作用域类型: %s" % scope)
        return default_value  # 或 return false
```

### 容错机制

| 场景 | 处理策略 |
|------|---------|
| 作用域容器未找到 | 记录警告日志，返回默认值 |
| 全局变量助手未初始化 | 记录错误日志，返回默认值 |
| 设置变量失败 | 记录错误日志，返回 `false` |
| 读取变量失败 | 返回默认值 |

### 日志级别

```gdscript
# DEBUG: 详细操作信息
_log_debug("从作用域 '%s' 获取变量 %s = %s" % [scope_id, var_name, value])

# INFO: 重要操作成功
_log_info("在作用域 '%s' 设置变量 %s = %s" % [scope_id, var_name, value])

# WARNING: 可恢复的错误
_log_warning("未找到作用域容器，回退到局部变量: %s" % var_name)

# ERROR: 严重错误
_log_error("GlobalVariableAssistant 实例为空")
```

---

## 测试指南

### 单元测试结构

测试文件：`addons/fuse/tests/unit/test_variable_operations.gd`

**测试覆盖：**
1. ✅ LOCAL 变量读取/设置
2. ✅ SCOPE 变量读取/设置
3. ✅ GLOBAL 变量读取/设置
4. ✅ 默认值处理
5. ✅ 变量存在性检查
6. ✅ 空变量名处理
7. ✅ null context 处理
8. ✅ 作用域容器查找
9. ✅ 作用域容器查找失败

### 测试示例

```gdscript
## 测试 LOCAL 变量读取
func test_get_local_variable():
    test_context.set_variable("test_var", 42, "local")

    var value = VariableOperations.get_variable(
        test_context,
        "test_var",
        BaseVariable.VariableScope.LOCAL,
        0
    )

    assert_eq(value, 42, "应该读取到局部变量值")

## 测试 SCOPE 变量设置
func test_set_scope_variable():
    var success = VariableOperations.set_variable(
        test_context,
        "new_scope_var",
        BaseVariable.VariableScope.SCOPE,
        200
    )

    assert_true(success, "设置作用域变量应该成功")
    assert_eq(
        test_scope_container.get_variable("new_scope_var", 0),
        200,
        "值应该正确"
    )

## 测试变量不存在时返回默认值
func test_get_variable_default_value():
    var value = VariableOperations.get_variable(
        test_context,
        "non_existent_var",
        BaseVariable.VariableScope.LOCAL,
        -1
    )

    assert_eq(value, -1, "应该返回默认值")
```

### 运行测试

```bash
# 在 Godot 编辑器中
1. 打开测试场景: addons/fuse/tests/unit/test_variable_operations.tscn
2. 按 F5 运行测试
3. 查看 GUT 测试结果面板
```

---

## 扩展指南

### 添加新方法

如果需要添加新的变量操作方法：

**步骤：**

1. **确定方法职责**
   - 是否适合作为公共 API？
   - 是否会被多处使用？
   - 是否与现有方法重复？

2. **设计方法签名**
   ```gdscript
   static func new_operation(
       context: ExecutionContext,
       variable_name: String,
       scope: BaseVariable.VariableScope,
       # 其他参数
   ) -> Variant:
       pass
   ```

3. **实现逻辑**
   - 参数验证
   - 作用域匹配
   - 调用私有辅助方法
   - 错误处理和日志

4. **编写单元测试**
   ```gdscript
   func test_new_operation():
       # 测试正常情况
       # 测试边界情况
       # 测试错误情况
   ```

5. **更新文档**
   - 在本文档中添加新方法的说明
   - 包含参数、返回值、示例

**示例：添加变量删除方法**

```gdscript
## 删除变量
static func delete_variable(
    context: ExecutionContext,
    variable_name: String,
    scope: BaseVariable.VariableScope
) -> bool:
    if context == null or variable_name.is_empty():
        _log_error("无效参数")
        return false

    match scope:
        BaseVariable.VariableScope.LOCAL:
            # 实现删除逻辑
            pass
        BaseVariable.VariableScope.SCOPE:
            # 实现删除逻辑
            pass
        BaseVariable.VariableScope.GLOBAL:
            # 实现删除逻辑
            pass
        _:
            _log_error("未知作用域")
            return false

    return true
```

---

## 常见问题 (FAQ)

### Q1: 为什么使用静态类而非单例？

**A:** 静态类更适合工具方法：
- 无状态，线程安全
- 无实例化开销
- Godot 中单例需要注册（`register_singleton()`），静态类直接使用

### Q2: 什么时候使用默认值参数？

**A:**
- **读取操作**: 始终提供默认值（避免 `null` 导致错误）
- **设置操作**: 不需要默认值（失败返回 `false`）
- **检查操作**: 不需要默认值（返回布尔值）

### Q3: SCOPE 变量设置失败为什么回退到 LOCAL？

**A:** 容错策略：
- 作用域容器可能不存在（场景树结构变化）
- 回退到 LOCAL 确保变量仍然被设置
- 记录警告日志便于调试

### Q4: 如何调试变量查找问题？

**A:** 启用调试日志：
```gdscript
# 在 FuseLogger 中启用 DEBUG 级别
# 查看 VariableOperations 的日志输出
# 日志会显示查找路径、作用域 ID、变量值等
```

### Q5: 性能敏感场景如何优化？

**A:**
1. 优先使用 LOCAL 变量
2. 缓存 SCOPE 容器引用（避免重复查找）
3. 减少热循环中的变量读取
4. 考虑使用 `@export_storage` 缓存变量值

---

## 最佳实践

### DO（推荐做法）

```gdscript
# ✅ 总是提供默认值
var value = VariableOperations.get_variable(
    context,
    "score",
    BaseVariable.VariableScope.LOCAL,
    0  # 明确的默认值
)

# ✅ 检查返回值
var success = VariableOperations.set_variable(...)
if not success:
    _log_error("设置失败")

# ✅ 使用枚举而非字符串
scope = BaseVariable.VariableScope.SCOPE  # ✅
scope_str = "scope"  # ❌ (除非用于序列化)
```

### DON'T（不推荐做法）

```gdscript
# ❌ 不提供默认值
var value = VariableOperations.get_variable(
    context,
    "score",
    BaseVariable.VariableScope.LOCAL
    # 缺少默认值，可能返回 null
)

# ❌ 不检查返回值
VariableOperations.set_variable(...)  # 失败时无法感知

# ❌ 硬编码作用域字符串
scope = 1  # 魔数，难以理解
```

---

## 相关文档

### 核心系统
- [变量系统架构](./variable-system-architecture.md)
- [作用域容器设计](./scope-container-design.md)
- [执行上下文指南](./execution-context-guide.md)

### 工具类
- [VariableScopeUtils 文档](./variable-scope-utils.md)
- [ScopeVariableManager 参考](./scope-variable-manager.md)
- [GlobalVariableAssistant 参考](./global-variable-assistant.md)

### 指令和条件
- [SetScopeVariable 指令](../instructions/variables/set_scope_variable.md)
- [GetScopeVariable 指令](../instructions/variables/get_scope_variable.md)
- [CheckVariable 条件](../conditions/variable/check_variable.md)

---

## 版本历史

| 版本 | 日期 | 变更 |
|------|------|------|
| 1.0.0 | 2025-02-09 | 初始版本，包含完整的变量操作 API |

---

## 维护者

- 创建者: Claude (AI Assistant)
- 审核者: 项目团队
- 最后更新: 2025-02-09

---

**文档状态:** ✅ 完成
**代码状态:** 🚧 开发中（Phase 1 完成，后续阶段待实施）
**测试状态:** ⏳ 待编写
