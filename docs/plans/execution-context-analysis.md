# ExecutionContext 集成作用域变量系统分析

**创建日期:** 2026-02-09
**分析阶段:** Phase 2 - 集成准备
**目标:** 理解如何在不破坏现有 local/global 变量功能的情况下集成作用域变量

---

## 1. 当前变量系统架构

### 1.1 变量作用域枚举 (BaseVariable.VariableScope)

```gdscript
enum VariableScope {
    LOCAL = 0,      ## 局部变量（ExecutionContext）
    SCOPE = 1,      ## 作用域变量（ScopeVariableContainer）
    GLOBAL = 2      ## 全局变量（GlobalVariableAssistant）
}
```

**状态:** ✅ 已完成 - SCOPE 已添加到枚举中

### 1.2 ExecutionContext 变量存储结构

#### 局部变量存储
```gdscript
var local_variables: Dictionary = {}  # 使用 StringName 作为键优化性能
```

- **生命周期:** 仅在当前指令执行期间有效
- **访问方式:** 直接通过 `set_variable(name, value)` 和 `get_variable(name)`
- **默认作用域:** "local"

#### 全局变量存储
```gdscript
var global_variables = null  # GlobalVariableAssistant 引用
var _global_variable_assistant: GlobalVariableAssistant = null  # 类型化引用
```

- **生命周期:** 整个应用程序生命周期
- **访问方式:** 通过 `GlobalVariableAssistant` 单例
- **默认作用域:** "global"

### 1.3 当前变量访问流程

#### set_variable() 方法 (第 255-336 行)

```gdscript
func set_variable(name: String, value: Variant, scope: String = "local") -> bool:
    match scope:
        "local":
            # 直接存储到 local_variables 字典
            local_variables[name_key] = value
            return true
        "global":
            # 通过 GlobalVariableAssistant 设置
            if _global_variable_assistant.has_global_variable(name):
                _global_variable_assistant.get_global_variable(name).set_value(value)
            else:
                var new_variable = BaseVariable.create(name, value, BaseVariable.VariableScope.GLOBAL)
                _global_variable_assistant.add_global_variable(name, new_variable)
            return true
        _:
            _log_error_localized("BRICKS_ERROR_UNKNOWN_VARIABLE_SCOPE", {"scope": scope})
            return false
```

**关键点:**
- 使用 `match` 语句分发到不同作用域
- Local 变量直接存储到字典
- Global 变量通过 `GlobalVariableAssistant` 管理
- 未知作用域返回错误

#### get_variable() 方法 (第 364-424 行)

```gdscript
func get_variable(name: String, default: Variant = null) -> Variant:
    # 1. 首先检查局部变量
    if local_variables.has(name_key):
        return local_variables[name_key]

    # 2. 检查全局变量（通过 GlobalVariableAssistant）
    if _global_variable_assistant != null:
        var global_var = _global_variable_assistant.get_global_variable(name)
        if global_var != null and global_var is BaseVariable:
            return global_var.get_value()

    # 3. 兼容性：检查旧的 global_variables 字典
    elif global_variables != null and global_variables.has_method("get"):
        var global_var = global_variables.get(name, null)
        if global_var != null:
            if global_var is BaseVariable:
                return global_var.get_value()
            else:
                return global_var

    # 4. 未找到，返回默认值
    return default
```

**关键点:**
- 查找顺序: local → global → default
- 使用 StringName 优化性能
- 总是返回 Variant 值，不是对象

---

## 2. Trigger 与 ExecutionContext 关系

### 2.1 ExecutionContext 创建流程 (Trigger._create_execution_context)

**位置:** `addons/bricks/core/trigger.gd` 第 198-208 行

```gdscript
func _create_execution_context(target: Node) -> RefCounted:
    # 直接创建 ExecutionContext 实例
    var context = ExecutionContext.new(target, self)

    # 添加事件数据到局部变量
    if context.has_method("set_variable"):
        context.set_variable("event_source", self)
        context.set_variable("triggered_node", target)
        context.log_level = log_level

    return context
```

**关键关系:**
- `ExecutionContext.target` → 事件触发节点（如玩家、敌人等）
- `ExecutionContext.trigger` → Trigger 节点本身
- `ExecutionContext` 通过 `trigger` 可以访问场景树结构

### 2.2 从 ExecutionContext 访问 ScopeVariableContainer

**方案 1: 通过 Trigger 节点查找**
```gdscript
# 在 ExecutionContext 中
func _find_scope_container() -> ScopeVariableContainer:
    if trigger == null:
        return null

    # 方法 1: 查找 trigger 的父节点中的 ScopeVariableContainer
    var manager = ScopeVariableManager.get_instance()
    if manager != null:
        return manager.find_nearest_scope(trigger)

    return null
```

**方案 2: 通过 Target 节点查找**
```gdscript
# 在 ExecutionContext 中
func _find_scope_container_from_target() -> ScopeVariableContainer:
    if target == null:
        return null

    var manager = ScopeVariableManager.get_instance()
    if manager != null:
        return manager.find_nearest_scope(target)

    return null
```

**推荐查找顺序:**
1. 先从 `trigger` 节点向上查找
2. 如果未找到，从 `target` 节点向上查找
3. 如果仍未找到，返回 null

---

## 3. 集成点分析

### 3.1 需要修改的方法

#### 1. set_variable() 方法
**位置:** `execution_context.gd` 第 255-336 行

**修改内容:**
- 添加 "scope" 分支到 match 语句
- 实现作用域变量查找和设置逻辑

**修改位置:** 第 334-336 行（在 `_:` 分支之前）

```gdscript
"scope":
    # 新增：作用域变量支持
    return _set_scope_variable(name, value)
```

#### 2. get_variable() 方法
**位置:** `execution_context.gd` 第 364-424 行

**修改内容:**
- 在 local 和 global 之间添加 scope 查找
- 实现作用域链查找逻辑

**修改位置:** 第 384 行之后（local 查找之后，global 查找之前）

```gdscript
# 检查作用域变量
var scope_value = _get_scope_variable(name)
if scope_value != null:
    return scope_value
```

#### 3. has_variable() 方法
**位置:** `execution_context.gd` 第 1010-1041 行

**修改内容:**
- 添加作用域变量存在性检查

**修改位置:** 第 1025 行之后（local 检查之后）

```gdscript
# 检查作用域变量
if _has_scope_variable(name):
    return true
```

#### 4. add_variable() 方法
**位置:** `execution_context.gd` 第 223-234 行

**修改内容:**
- 更新以支持 SCOPE 作用域

**修改位置:** 第 234 行

```gdscript
# 确定作用域名称（使用 scope 属性）
var scope_name := "local"
if variable.scope == BaseVariable.VariableScope.GLOBAL:
    scope_name = "global"
elif variable.scope == BaseVariable.VariableScope.SCOPE:  # 新增
    scope_name = "scope"
```

### 3.2 需要新增的辅助方法

#### 1. _get_scope_container() - 查找作用域容器
```gdscript
func _get_scope_container() -> ScopeVariableContainer:
    ## 查找最近的作用域容器
    var manager = ScopeVariableManager.get_instance()
    if manager == null:
        return null

    # 优先从 trigger 查找
    if trigger != null:
        var scope = manager.find_nearest_scope(trigger)
        if scope != null:
            return scope

    # 其次从 target 查找
    if target != null:
        var scope = manager.find_nearest_scope(target)
        if scope != null:
            return scope

    return null
```

#### 2. _set_scope_variable() - 设置作用域变量
```gdscript
func _set_scope_variable(name: String, value: Variant) -> bool:
    ## 设置作用域变量
    var scope_container = _get_scope_container()
    if scope_container == null:
        _log_error_localized("BRICKS_ERROR_SCOPE_CONTAINER_NOT_FOUND")
        return false

    return scope_container.set_variable(name, value)
```

#### 3. _get_scope_variable() - 获取作用域变量
```gdscript
func _get_scope_variable(name: String) -> Variant:
    ## 获取作用域变量（支持作用域链查找）
    var scope_container = _get_scope_container()
    if scope_container == null:
        return null

    # 检查当前作用域
    if scope_container.has_variable(name):
        return scope_container.get_variable(name)

    # 检查父作用域链（如果支持继承）
    var parent = scope_container.get_parent_scope()
    while parent != null:
        if parent.has_variable(name):
            return parent.get_variable(name)
        parent = parent.get_parent_scope()

    return null
```

#### 4. _has_scope_variable() - 检查作用域变量
```gdscript
func _has_scope_variable(name: String) -> bool:
    ## 检查作用域变量是否存在
    var scope_container = _get_scope_container()
    if scope_container == null:
        return false

    return scope_container.has_variable(name)
```

---

## 4. 潜在风险和缓解措施

### 4.1 风险 1: 性能影响 - 频繁查找 ScopeVariableContainer

**风险描述:**
每次访问作用域变量都需要查找容器，可能影响性能。

**缓解措施:**
```gdscript
# 添加缓存机制
var _cached_scope_container: ScopeVariableContainer = null
var _cached_scope_trigger_id: int = 0
var _cached_scope_target_id: int = 0

func _get_scope_container() -> ScopeVariableContainer:
    # 检查缓存是否有效
    var current_trigger_id = trigger.get_instance_id() if trigger else 0
    var current_target_id = target.get_instance_id() if target else 0

    if _cached_scope_container != null:
        if _cached_scope_trigger_id == current_trigger_id and \
           _cached_scope_target_id == current_target_id:
            return _cached_scope_container

    # 重新查找并更新缓存
    _cached_scope_container = _find_scope_container_impl()
    _cached_scope_trigger_id = current_trigger_id
    _cached_scope_target_id = current_target_id

    return _cached_scope_container
```

### 4.2 风险 2: 作用域链查找的无限递归

**风险描述:**
作用域链中可能存在循环引用，导致无限递归。

**缓解措施:**
```gdscript
func _get_scope_variable(name: String) -> Variant:
    var scope_container = _get_scope_container()
    if scope_container == null:
        return null

    # 使用访问记录防止循环
    var visited: Array = []

    var current = scope_container
    while current != null:
        # 检查是否已访问
        if current in visited:
            _log_error("检测到作用域链循环引用")
            return null

        visited.append(current)

        # 查找变量
        if current.has_variable(name):
            return current.get_variable(name)

        # 移动到父作用域
        current = current.get_parent_scope()

    return null
```

### 4.3 风险 3: 向后兼容性

**风险描述:**
现有代码依赖 "local" 和 "global" 字符串，添加 "scope" 可能破坏兼容性。

**缓解措施:**
- 使用保守的 match 语句，默认处理未知 scope
- 添加详细的错误日志
- 提供迁移指南

```gdscript
func set_variable(name: String, value: Variant, scope: String = "local") -> bool:
    match scope:
        "local":
            # 现有代码
        "global":
            # 现有代码
        "scope":
            # 新代码
        _:
            # 友好错误提示
            _log_error("未知的作用域类型: '%s'。支持的类型: local, global, scope" % scope)
            return false
```

### 4.4 风险 4: ScopeVariableContainer 未初始化

**风险描述:**
尝试访问作用域变量时，ScopeVariableContainer 可能未注册。

**缓解措施:**
```gdscript
func _get_scope_container() -> ScopeVariableContainer:
    var manager = ScopeVariableManager.get_instance()
    if manager == null:
        _log_debug("ScopeVariableManager 未初始化，作用域变量不可用")
        return null

    # ... 其余逻辑

    if scope_container == null:
        _log_debug("未找到 ScopeVariableContainer，作用域变量不可用")
        return null
```

---

## 5. 推荐的实现方法

### 5.1 分阶段实现策略

#### 阶段 1: 基础集成（最小改动）
1. 添加 `_get_scope_container()` 辅助方法
2. 在 `set_variable()` 添加 "scope" 分支
3. 在 `get_variable()` 添加作用域查找
4. 添加基本错误处理和日志

#### 阶段 2: 性能优化
1. 实现 ScopeVariableContainer 缓存
2. 添加作用域链查找优化
3. 添加性能监控和日志

#### 阶段 3: 高级功能
1. 支持作用域继承模式（READ_ONLY, READ_WRITE）
2. 添加作用域变量变化信号转发
3. 实现作用域变量调试工具

### 5.2 代码修改优先级

**高优先级（必须实现）:**
- ✅ `_get_scope_container()` - 核心查找逻辑
- ✅ `_set_scope_variable()` - 设置接口
- ✅ `_get_scope_variable()` - 获取接口
- ✅ `set_variable()` 添加 "scope" 分支
- ✅ `get_variable()` 添加作用域查找

**中优先级（推荐实现）:**
- 🔶 `_has_scope_variable()` - 存在性检查
- 🔶 `has_variable()` 添加作用域检查
- 🔶 容器缓存机制
- 🔶 循环引用检测

**低优先级（可选实现）:**
- 🔷 作用域链访问统计
- 🔷 作用域变量调试视图
- 🔷 性能监控

### 5.3 测试策略

#### 单元测试
```gdscript
# test_scope_variable_integration.gd

func test_set_scope_variable():
    var context = create_test_context_with_scope()
    assert(context.set_variable("test_var", 42, "scope") == true)
    assert(context.get_variable("test_var") == 42)

func test_get_scope_variable_fallback():
    var context = create_test_context_with_scope()
    context.set_variable("local_var", 10, "local")
    context.set_variable("scope_var", 20, "scope")
    assert(context.get_variable("local_var") == 10)
    assert(context.get_variable("scope_var") == 20)

func test_scope_variable_priority():
    var context = create_test_context_with_scope()
    context.set_variable("test", "local", "local")
    context.set_variable("test", "scope", "scope")
    # local 优先级应该更高
    assert(context.get_variable("test") == "local")
```

#### 集成测试
```gdscript
# test_scope_variable_full_integration.gd

func test_full_workflow():
    # 1. 创建带有 ScopeVariableContainer 的场景
    var scene = setup_test_scene()

    # 2. 创建 Trigger 并触发事件
    var trigger = scene.get_node("TestTrigger")
    trigger.trigger_manually()

    # 3. 在指令中访问作用域变量
    var context = get_execution_context()
    context.set_variable("player_health", 100, "scope")

    # 4. 验证变量在作用域容器中
    var scope_container = ScopeVariableManager.get_instance().find_nearest_scope(trigger)
    assert(scope_container.get_variable("player_health") == 100)
```

---

## 6. 依赖关系和假设

### 6.1 依赖项
- ✅ `ScopeVariableManager` 单例已实现
- ✅ `ScopeVariableContainer` 已实现
- ✅ `BaseVariable.VariableScope.SCOPE` 已添加
- ⚠️ `ScopeVariableManager.get_instance()` 必须在任何地方都能正常工作

### 6.2 假设条件
1. `ScopeVariableContainer` 已正确注册到 `ScopeVariableManager`
2. Trigger 和 Target 节点在场景树中的位置正确
3. 作用域链不会出现循环引用（或已正确处理）
4. 现有的 local 和 global 变量行为不应改变

### 6.3 需要验证的场景
- [ ] Trigger 和 Target 都没有 ScopeVariableContainer
- [ ] 只有 Trigger 有 ScopeVariableContainer
- [ ] 只有 Target 有 ScopeVariableContainer
- [ ] 两者都有 ScopeVariableContainer（应该选哪个？）
- [ ] 作用域链深度 > 3 层
- [ ] 作用域变量与 local/global 变量同名

---

## 7. 推荐的下一步行动

### 7.1 立即行动
1. ✅ 创建本分析文档（已完成）
2. 🔲 实现阶段 1 基础集成
   - 🔲 添加辅助方法（`_get_scope_container`, `_set_scope_variable`, `_get_scope_variable`）
   - 🔲 修改 `set_variable()` 添加 "scope" 分支
   - 🔲 修改 `get_variable()` 添加作用域查找
3. 🔲 编写单元测试

### 7.2 短期行动（1-2 天）
1. 🔲 实现阶段 2 性能优化
2. 🔲 编写集成测试
3. 🔲 更新文档

### 7.3 长期行动（1 周）
1. 🔲 实现阶段 3 高级功能
2. 🔲 性能基准测试
3. 🔲 编写迁移指南
4. 🔲 代码审查和优化

---

## 8. 关键代码位置总结

### 8.1 ExecutionContext 关键方法
| 方法名 | 行号 | 修改类型 | 优先级 |
|--------|------|----------|--------|
| `set_variable()` | 255-336 | 修改（添加 "scope" 分支） | 高 |
| `get_variable()` | 364-424 | 修改（添加作用域查找） | 高 |
| `has_variable()` | 1010-1041 | 修改（添加作用域检查） | 中 |
| `add_variable()` | 223-234 | 修改（支持 SCOPE 作用域） | 中 |

### 8.2 需要新增的方法
| 方法名 | 位置 | 优先级 |
|--------|------|--------|
| `_get_scope_container()` | ExecutionContext | 高 |
| `_set_scope_variable()` | ExecutionContext | 高 |
| `_get_scope_variable()` | ExecutionContext | 高 |
| `_has_scope_variable()` | ExecutionContext | 中 |

### 8.3 相关文件
| 文件路径 | 作用 | 修改需求 |
|----------|------|----------|
| `addons/bricks/core/base/execution_context.gd` | 主要修改文件 | ✅ 需要修改 |
| `addons/bricks/core/trigger.gd` | 创建 ExecutionContext | ⚠️ 可能需要微调 |
| `addons/bricks/core/base/scope_variable_container.gd` | 作用域容器 | ❌ 无需修改 |
| `addons/bricks/core/scope_variable_manager.gd` | 作用域管理器 | ❌ 无需修改 |
| `addons/bricks/core/base/base_variable.gd` | 变量基类 | ✅ 已修改（SCOPE 枚举） |

---

## 9. 总结

### 9.1 核心发现
1. ✅ **架构清晰:** ExecutionContext 的 `set_variable()` 和 `get_variable()` 方法使用 match 语句，便于扩展
2. ✅ **集成点明确:** 只需在两个方法中添加作用域支持
3. ✅ **访问路径可靠:** 通过 `trigger` 和 `target` 节点可以找到 ScopeVariableContainer
4. ⚠️ **需要缓存:** 频繁查找容器可能影响性能，建议实现缓存机制
5. ⚠️ **需要防护:** 作用域链查找需要防止循环引用

### 9.2 风险评估
- **整体风险:** 🟡 中等
- **破坏现有功能风险:** 🟢 低（使用保守的 match 语句）
- **性能风险:** 🟡 中等（可通过缓存缓解）
- **复杂性风险:** 🟡 中等（需要处理作用域链）

### 9.3 推荐方案
采用**分阶段实现策略**：
1. **阶段 1:** 基础集成（最小改动，快速验证）
2. **阶段 2:** 性能优化（添加缓存和监控）
3. **阶段 3:** 高级功能（作用域继承、调试工具）

每个阶段完成后进行测试和审查，确保稳定性。

---

**文档版本:** 1.0
**最后更新:** 2026-02-09
**下一步:** 开始实施阶段 1 基础集成
