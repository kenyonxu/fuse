# Bricks 变量操作统一工具类实施计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**目标:** 创建统一的 `VariableOperations` 工具类，整合 LOCAL/SCOPE/GLOBAL 三层变量体系的查找、读取、设置操作，消除当前多个指令和条件中的代码重复。

**架构:**
- 静态工具类 `VariableOperations` 提供统一的变量操作 API
- 保持现有公共 API 不变，仅重构内部实现
- 遵循 DRY 原则，提取重复代码到工具类
- 采用 TDD 方法，先写测试再实现功能

**技术栈:** Godot 4.6 GDScript, Bricks 插件架构, 单例模式, RefCounted 工具类

---

## 背景

### 当前问题

Bricks 系统中存在以下代码重复：

| 组件 | 重复代码 | 重复行数 |
|------|---------|---------|
| `SetScopeVariable._get_scope_container()` | 作用域容器查找逻辑 | ~40 行 |
| `GetScopeVariable._get_scope_container()` | 作用域容器查找逻辑 | ~40 行 |
| `CheckVariable._get_variable_value()` | 变量获取逻辑 | ~30 行 |
| `CheckVariable._get_compare_variable_value()` | 变量获取逻辑 | ~30 行 |
| `SetVariable._get_variable_value()` | 变量获取逻辑 | ~30 行 |

**总计约 170 行重复代码**，导致：
- 维护成本高：变量系统改动需要修改多处
- 测试困难：相同逻辑需要多次测试
- 扩展性差：新增变量相关组件需要重复实现

### 三层变量体系

```
LOCAL (0)   → ExecutionContext.local_variables
SCOPE (1)   → ScopeVariableContainer (场景树范围)
GLOBAL (2)  → GlobalVariableAssistant (应用级单例)
```

---

## Phase 1: 创建 VariableOperations 工具类

### Task 1.1: 创建工具类基础结构

**文件:**
- 创建: `addons/bricks/core/utils/variable_operations.gd`

**Step 1: 创建工具类文件**

```gdscript
## addons/bricks/core/utils/variable_operations.gd
@tool
class_name VariableOperations extends RefCounted

## 变量操作统一工具类
##
## 提供三层变量体系（LOCAL/SCOPE/GLOBAL）的统一操作接口。
##
## 功能：
## - 变量读取：从不同作用域获取变量值
## - 变量设置：向不同作用域设置变量值
## - 变量检查：检查变量是否存在
## - 作用域容器查找：查找 ScopeVariableContainer
##
## 设计原则：
## - 所有方法为静态方法，无状态
## - 返回值明确，使用 Variant 或 bool 表示成功/失败
## - 错误处理：使用 BricksLogger 记录日志
## - 性能优化：尽量减少重复查找

## 从指定作用域获取变量值
##
## 参数：
## - context: ExecutionContext - 执行上下文
## - variable_name: String - 变量名
## - scope: BaseVariable.VariableScope - 变量作用域
## - default_value: Variant = null - 默认值（变量不存在时返回）
##
## 返回：
## - Variant - 变量值，如果找不到则返回默认值
##
## 示例：
## ```gdscript
## var value = VariableOperations.get_variable(context, "score", BaseVariable.VariableScope.SCOPE, 0)
## ```
static func get_variable(
    context: ExecutionContext,
    variable_name: String,
    scope: BaseVariable.VariableScope,
    default_value: Variant = null
) -> Variant:
    if context == null:
        _log_error("ExecutionContext 为空")
        return default_value

    if variable_name.is_empty():
        _log_error("变量名为空")
        return default_value

    match scope:
        BaseVariable.VariableScope.LOCAL:
            return _get_local_variable(context, variable_name, default_value)

        BaseVariable.VariableScope.SCOPE:
            return _get_scope_variable(context, variable_name, default_value)

        BaseVariable.VariableScope.GLOBAL:
            return _get_global_variable(context, variable_name, default_value)

        _:
            _log_error("未知的作用域类型: %s" % BaseVariable.VariableScope.keys()[scope])
            return default_value

## 向指定作用域设置变量值
##
## 参数：
## - context: ExecutionContext - 执行上下文
## - variable_name: String - 变量名
## - scope: BaseVariable.VariableScope - 变量作用域
## - value: Variant - 要设置的值
##
## 返回：
## - bool - 是否成功设置
##
## 示例：
## ```gdscript
## var success = VariableOperations.set_variable(context, "score", BaseVariable.VariableScope.SCOPE, 100)
## ```
static func set_variable(
    context: ExecutionContext,
    variable_name: String,
    scope: BaseVariable.VariableScope,
    value: Variant
) -> bool:
    if context == null:
        _log_error("ExecutionContext 为空")
        return false

    if variable_name.is_empty():
        _log_error("变量名为空")
        return false

    match scope:
        BaseVariable.VariableScope.LOCAL:
            return _set_local_variable(context, variable_name, value)

        BaseVariable.VariableScope.SCOPE:
            return _set_scope_variable(context, variable_name, value)

        BaseVariable.VariableScope.GLOBAL:
            return _set_global_variable(context, variable_name, value)

        _:
            _log_error("未知的作用域类型: %s" % BaseVariable.VariableScope.keys()[scope])
            return false

## 检查变量是否存在
##
## 参数：
## - context: ExecutionContext - 执行上下文
## - variable_name: String - 变量名
## - scope: BaseVariable.VariableScope - 变量作用域
##
## 返回：
## - bool - 变量是否存在
static func has_variable(
    context: ExecutionContext,
    variable_name: String,
    scope: BaseVariable.VariableScope
) -> bool:
    if context == null or variable_name.is_empty():
        return false

    match scope:
        BaseVariable.VariableScope.LOCAL:
            return context.has_variable(variable_name)

        BaseVariable.VariableScope.SCOPE:
            var container = get_scope_container(context)
            return container != null and container.has_variable(variable_name)

        BaseVariable.VariableScope.GLOBAL:
            var assistant = GlobalVariableAssistant.get_instance()
            return assistant != null and assistant.has_global_variable(variable_name)

        _:
            return false

## 获取作用域容器（用于 SCOPE 级别）
##
## 参数：
## - context: ExecutionContext - 执行上下文
## - search_node: Node = null - 搜索起点节点（null 时使用 context.trigger）
##
## 返回：
## - ScopeVariableContainer - 找到的容器，未找到返回 null
static func get_scope_container(
    context: ExecutionContext,
    search_node: Node = null
) -> ScopeVariableContainer:
    if context == null:
        return null

    # 确定搜索起点
    var node = search_node
    if node == null:
        node = context.trigger

    if node == null:
        _log_debug("没有可用的搜索节点")
        return null

    # 使用 ScopeVariableManager 查找
    var manager = ScopeVariableManager.get_instance()
    if manager == null:
        _log_debug("ScopeVariableManager 实例为空")
        return null

    return manager.find_nearest_scope(node)

## ==================== 私有辅助方法 ====================

## 获取局部变量
static func _get_local_variable(
    context: ExecutionContext,
    variable_name: String,
    default_value: Variant
) -> Variant:
    if context.has_variable(variable_name):
        return context.get_variable(variable_name, default_value)

    _log_debug("局部变量未找到: %s" % variable_name)
    return default_value

## 获取作用域变量
static func _get_scope_variable(
    context: ExecutionContext,
    variable_name: String,
    default_value: Variant
) -> Variant:
    var container = get_scope_container(context)

    if container == null:
        _log_debug("未找到作用域容器，回退到默认值: %s" % variable_name)
        return default_value

    if container.has_variable(variable_name):
        var value = container.get_variable(variable_name, default_value)
        _log_debug("从作用域 '%s' 获取变量 %s = %s" % [
            container.scope_id, variable_name, str(value)
        ])
        return value

    _log_debug("作用域变量未找到: %s" % variable_name)
    return default_value

## 获取全局变量
static func _get_global_variable(
    context: ExecutionContext,
    variable_name: String,
    default_value: Variant
) -> Variant:
    var assistant = GlobalVariableAssistant.get_instance()

    if assistant == null:
        _log_debug("GlobalVariableAssistant 实例为空")
        return default_value

    var variable = assistant.get_global_variable(variable_name)
    if variable != null:
        return variable.get_value()

    _log_debug("全局变量未找到: %s" % variable_name)
    return default_value

## 设置局部变量
static func _set_local_variable(
    context: ExecutionContext,
    variable_name: String,
    value: Variant
) -> bool:
    return context.set_variable(variable_name, value, "local")

## 设置作用域变量
static func _set_scope_variable(
    context: ExecutionContext,
    variable_name: String,
    value: Variant
) -> bool:
    var container = get_scope_container(context)

    if container == null:
        _log_debug("未找到作用域容器，回退到局部变量: %s" % variable_name)
        return _set_local_variable(context, variable_name, value)

    var success = container.set_variable(variable_name, value)
    if success:
        _log_debug("在作用域 '%s' 设置变量 %s = %s" % [
            container.scope_id, variable_name, str(value)
        ])

    return success

## 设置全局变量
static func _set_global_variable(
    context: ExecutionContext,
    variable_name: String,
    value: Variant
) -> bool:
    var assistant = GlobalVariableAssistant.get_instance()

    if assistant == null:
        _log_error("GlobalVariableAssistant 实例为空")
        return false

    # 检查变量是否存在
    if assistant.has_global_variable(variable_name):
        var variable = assistant.get_global_variable(variable_name)
        if variable != null:
            return variable.set_value(value)
    else:
        # 创建新变量
        var new_variable = BaseVariable.create(
            variable_name,
            value,
            BaseVariable.VariableScope.GLOBAL
        )
        if new_variable == null:
            _log_error("创建全局变量失败: %s" % variable_name)
            return false

        return assistant.add_global_variable(variable_name, new_variable)

    return false

## ==================== 日志方法 ====================

static func _log_debug(message: String):
    BricksLogger.log_debug("VariableOperations", BricksLogger.LogLevel.DEBUG, message)

static func _log_info(message: String):
    BricksLogger.log_info("VariableOperations", BricksLogger.LogLevel.INFO, message)

static func _log_warning(message: String):
    BricksLogger.log_warning("VariableOperations", BricksLogger.LogLevel.WARNING, message)

static func _log_error(message: String):
    BricksLogger.log_error("VariableOperations", BricksLogger.LogLevel.ERROR, message)
```

**Step 2: 运行 Godot 语法检查**

运行: `E:\Godot\Godot_v4.6-stable_mono_win64\Godot_v4.6-stable_mono_win64.exe --headless --check-only --quit`

预期: 通过，无语法错误

**Step 3: 提交基础结构**

```bash
git add addons/bricks/core/utils/variable_operations.gd
git commit -m "feat(bricks): add VariableOperations utility class base structure"
```

---

## Phase 2: 更新 VariableScopeUtils 支持 SCOPE

### Task 2.1: 添加 SCOPE 枚举支持

**文件:**
- 修改: `addons/bricks/core/utils/variable_scope_utils.gd`

**Step 1: 更新 enum_to_string 方法**

在文件中找到 `enum_to_string()` 方法（约第 26 行），更新为：

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
            _log_warning("未知的作用域: %s，使用 LOCAL" % scope)
            return "local"
```

**Step 2: 更新 string_to_enum 方法**

在文件中找到 `string_to_enum()` 方法（约第 49 行），更新为：

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
            _log_warning("未知的作用域字符串: '%s'，使用 LOCAL" % scope_str)
            return BaseVariable.VariableScope.LOCAL
```

**Step 3: 更新 is_valid_scope_string 方法**

在文件中找到 `is_valid_scope_string()` 方法（约第 72 行），更新为：

```gdscript
static func is_valid_scope_string(scope_str: String) -> bool:
    var lower = scope_str.to_lower()
    return lower == "local" or lower == "scope" or lower == "global"
```

**Step 4: 更新 get_valid_scopes 方法**

在文件中找到 `get_valid_scopes()` 方法（约第 90 行），更新为：

```gdscript
static func get_valid_scopes() -> Array[String]:
    return ["local", "scope", "global"]
```

**Step 5: 更新 is_local 和 is_global 方法，添加 is_scope**

在文件中找到这些方法（约第 100-111 行），添加新方法：

```gdscript
static func is_local(scope: BaseVariable.VariableScope) -> bool:
    return scope == BaseVariable.VariableScope.LOCAL

static func is_scope(scope: BaseVariable.VariableScope) -> bool:
    return scope == BaseVariable.VariableScope.SCOPE

static func is_global(scope: BaseVariable.VariableScope) -> bool:
    return scope == BaseVariable.VariableScope.GLOBAL
```

**Step 6: 更新 enum_to_display_name 方法**

在文件中找到 `enum_to_display_name()` 方法（约第 120 行），更新为：

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

**Step 7: 运行 Godot 语法检查**

运行: `E:\Godot\Godot_v4.6-stable_mono_win64\Godot_v4.6-stable_mono_win64.exe --headless --check-only --quit`

预期: 通过

**Step 8: 提交更新**

```bash
git add addons/bricks/core/utils/variable_scope_utils.gd
git commit -m "feat(bricks): add SCOPE support to VariableScopeUtils"
```

---

## Phase 3: 创建单元测试

### Task 3.1: 创建测试文件

**文件:**
- 创建: `addons/bricks/tests/unit/test_variable_operations.gd`

**Step 1: 创建测试脚本**

```gdscript
## addons/bricks/tests/unit/test_variable_operations.gd
extends GutTest

var test_context: ExecutionContext
var test_scope_container: ScopeVariableContainer
var test_node: Node

func before_each():
    # 创建测试节点树
    test_node = Node.new()
    test_node.name = "TestRoot"

    # 创建作用域容器
    test_scope_container = ScopeVariableContainer.new()
    test_scope_container.name = "TestScope"
    test_scope_container.scope_id = "test_scope"
    test_node.add_child(test_scope_container)

    # 创建执行上下文
    var global_assistant = GlobalVariableAssistant.get_instance()
    test_context = ExecutionContext.new()
    test_context.trigger = test_scope_container
    test_context.global_variables = global_assistant

func after_each():
    if test_context != null:
        test_context.cleanup()
        test_context = null

    if test_node != null:
        test_node.queue_free()
        test_node = null

## 测试 LOCAL 变量读取
func test_get_local_variable():
    # 设置局部变量
    test_context.set_variable("test_var", 42, "local")

    # 使用工具类读取
    var value = VariableOperations.get_variable(
        test_context,
        "test_var",
        BaseVariable.VariableScope.LOCAL,
        0
    )

    assert_eq(value, 42, "应该读取到局部变量值")

## 测试 LOCAL 变量设置
func test_set_local_variable():
    var success = VariableOperations.set_variable(
        test_context,
        "new_var",
        BaseVariable.VariableScope.LOCAL,
        100
    )

    assert_true(success, "设置局部变量应该成功")
    assert_eq(test_context.get_variable("new_var", 0), 100, "值应该正确")

## 测试 SCOPE 变量读取
func test_get_scope_variable():
    # 在作用域容器中设置变量
    test_scope_container.set_variable("scope_var", 99)

    # 使用工具类读取
    var value = VariableOperations.get_variable(
        test_context,
        "scope_var",
        BaseVariable.VariableScope.SCOPE,
        0
    )

    assert_eq(value, 99, "应该读取到作用域变量值")

## 测试 SCOPE 变量设置
func test_set_scope_variable():
    var success = VariableOperations.set_variable(
        test_context,
        "new_scope_var",
        BaseVariable.VariableScope.SCOPE,
        200
    )

    assert_true(success, "设置作用域变量应该成功")
    assert_eq(test_scope_container.get_variable("new_scope_var", 0), 200, "值应该正确")

## 测试 GLOBAL 变量读取
func test_get_global_variable():
    var assistant = GlobalVariableAssistant.get_instance()

    # 创建全局变量
    var test_var = BaseVariable.create("global_test", 777, BaseVariable.VariableScope.GLOBAL)
    assistant.add_global_variable("global_test", test_var)

    # 使用工具类读取
    var value = VariableOperations.get_variable(
        test_context,
        "global_test",
        BaseVariable.VariableScope.GLOBAL,
        0
    )

    assert_eq(value, 777, "应该读取到全局变量值")

    # 清理
    assistant.remove_global_variable("global_test")

## 测试 GLOBAL 变量设置
func test_set_global_variable():
    var assistant = GlobalVariableAssistant.get_instance()

    var success = VariableOperations.set_variable(
        test_context,
        "new_global_var",
        BaseVariable.VariableScope.GLOBAL,
        999
    )

    assert_true(success, "设置全局变量应该成功")

    var value = assistant.get_global_variable("new_global_var")
    assert_not_null(value, "全局变量应该存在")
    assert_eq(value.get_value(), 999, "值应该正确")

    # 清理
    assistant.remove_global_variable("new_global_var")

## 测试变量不存在时返回默认值
func test_get_variable_default_value():
    var value = VariableOperations.get_variable(
        test_context,
        "non_existent_var",
        BaseVariable.VariableScope.LOCAL,
        -1
    )

    assert_eq(value, -1, "应该返回默认值")

## 测试 has_variable 方法
func test_has_variable():
    # 设置局部变量
    test_context.set_variable("existing_var", 1, "local")

    # 检查存在
    assert_true(
        VariableOperations.has_variable(test_context, "existing_var", BaseVariable.VariableScope.LOCAL),
        "变量应该存在"
    )

    # 检查不存在
    assert_false(
        VariableOperations.has_variable(test_context, "non_existing", BaseVariable.VariableScope.LOCAL),
        "变量不应该存在"
    )

## 测试空变量名处理
func test_empty_variable_name():
    var value = VariableOperations.get_variable(
        test_context,
        "",
        BaseVariable.VariableScope.LOCAL,
        999
    )

    assert_eq(value, 999, "空变量名应该返回默认值")

## 测试 null context 处理
func test_null_context():
    var value = VariableOperations.get_variable(
        null,
        "test",
        BaseVariable.VariableScope.LOCAL,
        -1
    )

    assert_eq(value, -1, "null context 应该返回默认值")

## 测试作用域容器查找
func test_get_scope_container():
    var container = VariableOperations.get_scope_container(test_context)

    assert_not_null(container, "应该找到作用域容器")
    assert_eq(container.scope_id, "test_scope", "应该是正确的作用域容器")

## 测试作用域容器查找失败
func test_get_scope_container_not_found():
    # 创建没有作用域容器的节点
    var empty_node = Node.new()
    var empty_context = ExecutionContext.new()
    empty_context.trigger = empty_node

    var container = VariableOperations.get_scope_container(empty_context)

    assert_null(container, "不应该找到作用域容器")

    # 清理
    empty_context.cleanup()
    empty_node.queue_free()
```

**Step 2: 创建测试场景**

**文件:**
- 创建: `addons/bricks/tests/unit/test_variable_operations.tscn`

```
[gd_scene load_steps=2 format=3 uid="uid://test_variable_operations"]

[ext_resource type="Script" path="res://addons/bricks/tests/unit/test_variable_operations.gd" id="1_test_var_ops"]

[node name="TestVariableOperations" type="Node"]
script = ExtResource("1_test_var_ops")
```

**Step 3: 在编辑器中运行测试**

1. 打开 Godot 编辑器
2. 运行测试场景（F5）
3. 查看 GUT 测试结果

**预期:** 所有测试通过

**Step 4: 提交测试**

```bash
git add addons/bricks/tests/unit/test_variable_operations.gd
git add addons/bricks/tests/unit/test_variable_operations.tscn
git commit -m "test(bricks): add VariableOperations unit tests"
```

---

## Phase 4: 重构 SetScopeVariable 指令

### Task 4.1: 替换作用域容器查找逻辑

**文件:**
- 修改: `addons/bricks/instructions/variables/set_scope_variable.gd`

**Step 1: 更新 execute 方法中的容器查找**

找到 `execute()` 方法（约第 66 行），修改容器获取部分：

```gdscript
func execute(context: ExecutionContext):
    _start_execution(context)

    # 参数验证
    if variable_name.is_empty():
        _log_error_localized("BRICKS_ERROR_VAR_NAME_EMPTY", {})
        set_error_localized("BRICKS_ERROR_VAR_NAME_EMPTY", BricksError.ErrorType.VALIDATION_ERROR, {})
        finished.emit()
        return

    # 使用工具类获取作用域容器
    var scope_container: ScopeVariableContainer = null

    match scope_source:
        ScopeSource.NEAREST:
            scope_container = VariableOperations.get_scope_container(context)

        ScopeSource.CUSTOM_ID:
            if custom_scope_id.is_empty():
                _log_warning_localized("BRICKS_WARNING_SCOPE_ID_EMPTY", {})
            else:
                var manager = ScopeVariableManager.get_instance()
                if manager != null:
                    scope_container = manager.get_scope_by_id(custom_scope_id)

        ScopeSource.TRIGGER_SCOPE:
            scope_container = VariableOperations.get_scope_container(context, context.trigger)

        ScopeSource.TARGET_NODE:
            if not target_node_path.is_empty():
                var node = context.get_node(target_node_path)
                if node != null:
                    scope_container = VariableOperations.get_scope_container(context, node)
            else:
                _log_warning_localized("BRICKS_WARNING_TARGET_NODE_PATH_EMPTY", {})

    if scope_container == null:
        _log_error_localized("BRICKS_ERROR_SCOPE_CONTAINER_NOT_FOUND", {})
        set_error_localized("BRICKS_ERROR_SCOPE_CONTAINER_NOT_FOUND", BricksError.ErrorType.RUNTIME_ERROR, {})
        finished.emit()
        return

    # 设置变量
    var success = scope_container.set_variable(variable_name, new_value)
    if not success:
        _log_error_localized("BRICKS_ERROR_SET_SCOPE_VARIABLE_FAILED", {"name": variable_name})
        set_error_localized("BRICKS_ERROR_SET_SCOPE_VARIABLE_FAILED", BricksError.ErrorType.RUNTIME_ERROR, {"name": variable_name})
        finished.emit()
        return

    # 记录成功信息
    _log_info_localized("BRICKS_LOG_SET_SCOPE_VARIABLE", {
        "name": variable_name,
        "value": str(new_value),
        "scope_id": scope_container.scope_id
    })

    _on_execution_completed()
```

**Step 2: 删除旧的私有方法**

删除 `_get_scope_container()` 和 `_find_nearest_scope()` 方法（约第 101-139 行）

**Step 3: 运行 Godot 语法检查**

运行: `E:\Godot\Godot_v4.6-stable_mono_win64\Godot_v4.6-stable_mono_win64.exe --headless --check-only --quit`

预期: 通过

**Step 4: 运行测试（如果有）**

在编辑器中运行相关测试，确保功能正常

**Step 5: 提交更改**

```bash
git add addons/bricks/instructions/variables/set_scope_variable.gd
git commit -m "refactor(bricks): use VariableOperations in SetScopeVariable"
```

---

## Phase 5: 重构 GetScopeVariable 指令

### Task 5.1: 替换作用域容器查找逻辑

**文件:**
- 修改: `addons/bricks/instructions/variables/get_scope_variable.gd`

**Step 1: 更新 execute 方法中的容器查找**

找到 `execute()` 方法（约第 72 行），修改容器获取部分（与 Task 4.1 类似）：

```gdscript
func execute(context: ExecutionContext):
    _start_execution(context)

    # 参数验证
    if source_variable_name.is_empty():
        _log_error_localized("BRICKS_ERROR_VAR_NAME_EMPTY", {})
        set_error_localized("BRICKS_ERROR_VAR_NAME_EMPTY", BricksError.ErrorType.VALIDATION_ERROR, {})
        finished.emit()
        return

    if target_variable.is_empty():
        _log_error_localized("BRICKS_ERROR_TARGET_VAR_NAME_EMPTY", {})
        set_error_localized("BRICKS_ERROR_TARGET_VAR_NAME_EMPTY", BricksError.ErrorType.VALIDATION_ERROR, {})
        finished.emit()
        return

    # 使用工具类获取作用域容器
    var scope_container: ScopeVariableContainer = null

    match scope_source:
        ScopeSource.NEAREST:
            scope_container = VariableOperations.get_scope_container(context)

        ScopeSource.CUSTOM_ID:
            if custom_scope_id.is_empty():
                _log_warning_localized("BRICKS_WARNING_SCOPE_ID_EMPTY", {})
            else:
                var manager = ScopeVariableManager.get_instance()
                if manager != null:
                    scope_container = manager.get_scope_by_id(custom_scope_id)

        ScopeSource.TRIGGER_SCOPE:
            scope_container = VariableOperations.get_scope_container(context, context.trigger)

        ScopeSource.TARGET_NODE:
            if not target_node_path.is_empty():
                var node = context.get_node(target_node_path)
                if node != null:
                    scope_container = VariableOperations.get_scope_container(context, node)
            else:
                _log_warning_localized("BRICKS_WARNING_TARGET_NODE_PATH_EMPTY", {})

    var value = default_value

    if scope_container != null:
        # 从作用域容器获取变量
        if scope_container.has_variable(source_variable_name):
            value = scope_container.get_variable(source_variable_name, default_value)
            _log_debug_localized("BRICKS_LOG_SCOPE_VAR_FOUND", {
                "scope": scope_container.scope_id,
                "variable": source_variable_name,
                "value": str(value)
            })
        else:
            _log_debug_localized("BRICKS_LOG_SCOPE_VAR_NOT_FOUND", {
                "scope": scope_container.scope_id,
                "variable": source_variable_name
            })
    else:
        _log_debug_localized("BRICKS_LOG_SCOPE_VAR_NOT_FOUND", {"scope": "default"})

    # 存储到本地变量
    var success = context.set_variable(target_variable, value, "local")
    if not success:
        _log_error_localized("BRICKS_ERROR_SET_LOCAL_VARIABLE_FAILED", {"name": target_variable})
        set_error_localized("BRICKS_ERROR_SET_LOCAL_VARIABLE_FAILED", BricksError.ErrorType.RUNTIME_ERROR, {"name": target_variable})
        finished.emit()
        return

    # 记录成功信息
    _log_info_localized("BRICKS_LOG_GET_SCOPE_VARIABLE", {
        "source": source_variable_name,
        "target": target_variable,
        "value": str(value)
    })

    _on_execution_completed()
```

**Step 2: 删除旧的私有方法**

删除 `_get_scope_container()` 和 `_find_nearest_scope()` 方法（约第 126-164 行）

**Step 3: 运行 Godot 语法检查**

运行: `E:\Godot\Godot_v4.6-stable_mono_win64\Godot_v4.6-stable_mono_win64.exe --headless --check-only --quit`

预期: 通过

**Step 4: 运行测试（如果有）**

在编辑器中运行相关测试

**Step 5: 提交更改**

```bash
git add addons/bricks/instructions/variables/get_scope_variable.gd
git commit -m "refactor(bricks): use VariableOperations in GetScopeVariable"
```

---

## Phase 6: 重构 CheckVariable 条件

### Task 6.1: 替换变量获取逻辑

**文件:**
- 修改: `addons/bricks/conditions/variable/check_variable.gd`

**Step 1: 更新 _get_variable_value 方法**

找到 `_get_variable_value()` 方法（约第 187 行），简化为：

```gdscript
func _get_variable_value(context: ExecutionContext) -> Variant:
    if context == null:
        _log_error("ExecutionContext is null")
        return null

    # 使用工具类获取变量值
    var value = VariableOperations.get_variable(
        context,
        variable_name,
        variable_scope,
        null  # 不使用默认值，由调用者处理
    )

    # 处理空值情况
    if treat_empty_as_null and value is String and value.is_empty():
        return null

    return value
```

**Step 2: 更新 _get_compare_variable_value 方法**

找到 `_get_compare_variable_value()` 方法（约第 221 行），简化为：

```gdscript
func _get_compare_variable_value(context: ExecutionContext) -> Variant:
    if context == null:
        _log_error("ExecutionContext is null")
        return null

    # 使用工具类获取比较变量值
    return VariableOperations.get_variable(
        context,
        compare_variable,
        compare_variable_scope,
        null  # 不使用默认值，由调用者处理
    )
```

**Step 3: 运行 Godot 语法检查**

运行: `E:\Godot\Godot_v4.6-stable_mono_win64\Godot_v4.6-stable_mono_win64.exe --headless --check-only --quit`

预期: 通过

**Step 4: 运行测试（如果有）**

在编辑器中运行相关测试

**Step 5: 提交更改**

```bash
git add addons/bricks/conditions/variable/check_variable.gd
git commit -m "refactor(bricks): use VariableOperations in CheckVariable"
```

---

## Phase 7: 重构 SetVariable 指令

### Task 7.1: 替换变量操作逻辑

**文件:**
- 修改: `addons/bricks/instructions/variables/set_variable.gd`

**Step 1: 更新 _get_variable_value 方法**

找到 `_get_variable_value()` 方法（约第 133 行），简化为：

```gdscript
func _get_variable_value(context: ExecutionContext, variable_name: String, variable_scope: BaseVariable.VariableScope) -> Variant:
    if not context:
        return null

    # 使用工具类获取变量值
    return VariableOperations.get_variable(
        context,
        variable_name,
        variable_scope,
        null  # 不使用默认值
    )
```

**Step 2: 更新 _set_variable_value 方法**

找到 `_set_variable_value()` 方法（约第 166 行），简化为：

```gdscript
func _set_variable_value(context: ExecutionContext, variable_name: String, variable_scope: BaseVariable.VariableScope, value: Variant) -> bool:
    if not context:
        _log_error("执行上下文为空")
        return false

    # 使用工具类设置变量值
    return VariableOperations.set_variable(
        context,
        variable_name,
        variable_scope,
        value
    )
```

**Step 3: 删除不再需要的辅助方法**

删除 `_set_local_variable_value()` 和 `_check_type_compatibility()` 等方法（如果不再需要）

**Step 4: 运行 Godot 语法检查**

运行: `E:\Godot\Godot_v4.6-stable_mono_win64\Godot_v4.6-stable_mono_win64.exe --headless --check-only --quit`

预期: 通过

**Step 5: 运行测试（如果有）**

在编辑器中运行相关测试

**Step 6: 提交更改**

```bash
git add addons/bricks/instructions/variables/set_variable.gd
git commit -m "refactor(bricks): use VariableOperations in SetVariable"
```

---

## Phase 8: 更新其他组件（可选）

### Task 8.1: 检查并更新其他变量相关组件

**检查文件:**
- `addons/bricks/instructions/variables/set_int_variable.gd`
- `addons/bricks/instructions/variables/create_variable.gd`
- `addons/bricks/conditions/variable/compare_variable.gd`
- 其他变量相关的指令和条件

**Step 1: 搜索重复的变量操作代码**

```bash
grep -r "context.get_variable" addons/bricks/instructions addons/bricks/conditions
grep -r "GlobalVariableAssistant.get_instance" addons/bricks/instructions addons/bricks/conditions
grep -r "ScopeVariableManager.get_instance" addons/bricks/instructions addons/bricks/conditions
```

**Step 2: 评估是否需要重构**

对于找到的重复代码：
- 如果逻辑简单且只在一处使用，可以不重构
- 如果逻辑复杂或在多处重复，考虑重构

**Step 3: 执行重构（如果需要）**

参照 Phase 4-7 的模式进行重构

**Step 4: 提交更改**

```bash
git add -A
git commit -m "refactor(bricks): use VariableOperations in remaining components"
```

---

## Phase 9: 编写文档

### Task 9.1: 更新架构文档

**文件:**
- 创建: `addons/bricks/docs/dev_docs/variable-operations-utility.md`

**Step 1: 创建架构文档**

```markdown
# 变量操作工具类架构文档

## 概述

`VariableOperations` 是一个静态工具类，提供 Bricks 三层变量体系（LOCAL/SCOPE/GLOBAL）的统一操作接口。

## 设计目标

1. **代码复用** - 消除多个组件中的重复代码
2. **统一接口** - 提供一致的变量操作 API
3. **易于维护** - 集中管理变量操作逻辑
4. **类型安全** - 使用枚举而非字符串表示作用域

## 核心方法

### get_variable()

从指定作用域获取变量值。

```gdscript
static func get_variable(
    context: ExecutionContext,
    variable_name: String,
    scope: BaseVariable.VariableScope,
    default_value: Variant = null
) -> Variant
```

### set_variable()

向指定作用域设置变量值。

```gdscript
static func set_variable(
    context: ExecutionContext,
    variable_name: String,
    scope: BaseVariable.VariableScope,
    value: Variant
) -> bool
```

### has_variable()

检查变量是否存在。

```gdscript
static func has_variable(
    context: ExecutionContext,
    variable_name: String,
    scope: BaseVariable.VariableScope
) -> bool
```

### get_scope_container()

查找作用域容器。

```gdscript
static func get_scope_container(
    context: ExecutionContext,
    search_node: Node = null
) -> ScopeVariableContainer
```

## 使用示例

### 读取局部变量

```gdscript
var score = VariableOperations.get_variable(
    context,
    "score",
    BaseVariable.VariableScope.LOCAL,
    0
)
```

### 设置作用域变量

```gdscript
var success = VariableOperations.set_variable(
    context,
    "player_health",
    BaseVariable.VariableScope.SCOPE,
    100
)
```

### 检查全局变量

```gdscript
if VariableOperations.has_variable(
    context,
    "game_level",
    BaseVariable.VariableScope.GLOBAL
):
    # 变量存在
```

## 与 VariableScopeUtils 的区别

| 类 | 职责 |
|---|---|
| `VariableScopeUtils` | 枚举与字符串转换 |
| `VariableOperations` | 变量操作（读/写/检查） |

## 性能考虑

- 所有方法为静态方法，无实例化开销
- 作用域容器查找使用缓存（ExecutionContext 级别）
- 避免频繁的字符串比较

## 扩展指南

如果需要添加新的变量操作方法：

1. 确定方法是否适合作为公共 API
2. 使用明确的参数和返回值
3. 添加完整的错误处理和日志
4. 编写单元测试
5. 更新此文档
```

**Step 2: 提交文档**

```bash
git add addons/bricks/docs/dev_docs/variable-operations-utility.md
git commit -m "docs(bricks): add VariableOperations architecture documentation"
```

---

## Phase 10: 最终验证

### Task 10.1: 运行完整测试套件

**Step 1: 运行所有单元测试**

在编辑器中运行 GUT 测试套件，确保所有测试通过

**Step 2: 手动测试关键场景**

1. 创建测试场景，包含三层变量操作
2. 测试 SetScopeVariable 指令
3. 测试 GetScopeVariable 指令
4. 测试 CheckVariable 条件
5. 测试 SetVariable 指令

**Step 3: 检查代码覆盖率**

确保重构的代码路径都被测试覆盖

**Step 4: 性能基准测试**

运行性能测试，确保重构后性能无下降

**Step 5: 提交完成**

```bash
git add -A
git commit -m "feat(bricks): complete VariableOperations utility implementation

- 创建 VariableOperations 工具类，提供统一的变量操作接口
- 更新 VariableScopeUtils 支持 SCOPE 枚举
- 重构 SetScopeVariable、GetScopeVariable、CheckVariable、SetVariable
- 添加完整的单元测试
- 更新架构文档
```

---

## 验收标准

### 功能完整性
- [x] Phase 1: VariableOperations 工具类创建完成
- [ ] Phase 2: VariableScopeUtils 更新完成
- [ ] Phase 3: 单元测试通过
- [ ] Phase 4-7: 组件重构完成
- [ ] Phase 8: 其他组件更新（可选）
- [ ] Phase 9: 文档完整
- [ ] Phase 10: 最终验证通过

### 质量标准
- [ ] 所有测试通过
- [ ] 无回归错误
- [ ] 代码符合项目规范
- [ ] 性能无明显下降

### 文档完整性
- [ ] 架构文档完整
- [ ] 代码注释清晰
- [ ] 使用示例完整

---

## 附录

### 文件清单

**新增文件:**
- `addons/bricks/core/utils/variable_operations.gd`
- `addons/bricks/tests/unit/test_variable_operations.gd`
- `addons/bricks/tests/unit/test_variable_operations.tscn`
- `addons/bricks/docs/dev_docs/variable-operations-utility.md`

**修改文件:**
- `addons/bricks/core/utils/variable_scope_utils.gd`
- `addons/bricks/instructions/variables/set_scope_variable.gd`
- `addons/bricks/instructions/variables/get_scope_variable.gd`
- `addons/bricks/conditions/variable/check_variable.gd`
- `addons/bricks/instructions/variables/set_variable.gd`

### 预估工时

| Phase | 描述 | 预估时间 |
|-------|------|---------|
| Phase 1 | 创建工具类 | 2-3 小时 |
| Phase 2 | 更新枚举工具 | 30 分钟 |
| Phase 3 | 单元测试 | 2-3 小时 |
| Phase 4-7 | 组件重构 | 3-4 小时 |
| Phase 8 | 其他组件 | 1-2 小时 |
| Phase 9 | 文档 | 1-2 小时 |
| Phase 10 | 验证 | 1-2 小时 |
| **总计** | | **11-17 小时** |

### 风险回顾

| 风险 | 级别 | 缓解措施 |
|------|------|----------|
| 破坏现有功能 | 高 | 保持公共 API 不变，逐步迁移 |
| 性能下降 | 低 | 静态方法无性能损耗 |
| 测试覆盖不足 | 中 | TDD 方法，先写测试 |

---

**计划创建日期:** 2025-02-09
**预计完成日期:** 待定
**总工时估计:** 11-17 小时
