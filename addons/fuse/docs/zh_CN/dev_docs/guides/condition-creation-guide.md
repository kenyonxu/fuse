# 创建 Fuse 条件指南

> **目标**: 为开发者提供完整的 Fuse 条件创建指引，基于现有条件实现经验和最佳实践。
> **权威规范**: 组件生成的最终权威是 [fuse-condition-generator skill](../../../../agent_skills/fuse-condition-generator/SKILL.md)（模板、命名禁则与验证 gate）；本指南是其架构原理的详述。

**适用对象**: Fuse 系统开发者、贡献者

**最后更新**: 2026-06-17

---

## 📋 目录

1. [条件 vs 事件 vs 指令](#条件-vs-事件-vs-指令)
2. [命名规范](#命名规范)
3. [图标规范](#图标规范)
4. [必需实现的方法](#必需实现的方法)
5. [可选实现的方法](#可选实现的方法)
6. [条件特性](#条件特性)
7. [变量操作（三层变量系统）](#变量操作三层变量系统)
8. [完整条件模板](#完整条件模板)
9. [创建步骤](#创建步骤)
10. [最佳实践](#最佳实践)
11. [常见陷阱](#常见陷阱)
12. [测试规范](#测试规范)

---

## 条件 vs 事件 vs 指令

理解 Condition、Event 和 Instruction 的区别是创建条件的第一步。

| 特性 | Condition (条件) | Event (事件) | Instruction (指令) |
|------|-----------------|-------------|-------------------|
| **用途** | 判断条件是否满足 | 监听条件，触发响应 | 执行具体动作 |
| **核心方法** | `_evaluate_condition()` | `initialize()`/`terminate()` | `execute()` |
| **返回值** | `bool` | 无（发信号） | 无（发信号） |
| **调用方式** | 被动调用（被系统检查） | 被动触发 | 主动执行 |
| **生命周期** | 无状态（或可缓存） | initialize → terminate | execute → 完成/取消/错误 |
| **特性** | 支持取反、缓存、依赖追踪 | 信号管理 | 执行状态管理 |
| **典型用途** | 变量比较、节点检查、状态判断 | 输入、碰撞、信号 | 移动、播放、设置变量 |

**核心区别**:
- **Condition** 是"判断器" - 检查某个条件是否满足，返回布尔值
- **Event** 是"监听器" - 等待某事发生，然后发出 `triggered` 信号
- **Instruction** 是"执行器" - 执行某个动作，然后发出 `finished` 信号

---

## 命名规范

**重要**: 所有 Fuse 条件遵循以下命名规范，基于功能类型使用不同的前缀。

### 基于功能的命名规则

条件根据功能类型使用不同的前缀，让命名更精确、更符合语义。

#### 检查类条件（Check）

用于检查某个状态/条件是否成立。

```
文件名：   check_<描述>.gd
类名：     Check<描述>
条件类型： <描述>
```

**示例**:
```
文件名：   check_node_exists.gd
类名：     CheckNodeExists
条件类型： "node_exists"
```

**更多示例**:
- `check_node_exists.gd` → `CheckNodeExists` - 检查节点是否存在
- `check_node_property.gd` → `CheckNodeProperty` - 检查节点属性
- `check_variable_exists.gd` → `CheckVariableExists` - 检查变量是否存在
- `check_is_in_group.gd` → `CheckIsInGroup` - 检查是否在组中
- `check_is_visible.gd` → `CheckIsVisible` - 检查是否可见

#### 对比类条件（Compare）

用于对比两个值的大小/关系。

```
文件名：   compare_<描述>.gd
类名：     Compare<描述>
条件类型： <描述>
```

**示例**:
```
文件名：   compare_variable.gd
类名：     CompareVariable
条件类型： "variable_comparison"
```

**更多示例**:
- `compare_variable.gd` → `CompareVariable` - 对比变量值
- `compare_health.gd` → `CompareHealth` - 对比生命值
- `compare_score.gd` → `CompareScore` - 对比分数
- `compare_distance.gd` → `CompareDistance` - 对比距离
- `compare_node_property.gd` → `CompareNodeProperty` - 对比节点属性

### 命名规范总结

| 类型 | 前缀 | 文件名格式 | 类名格式 | 用途 |
|------|------|-----------|---------|------|
| **检查类** | `check_` | `check_<描述>.gd` | `Check<描述>` | 检查状态/条件 |
| **对比类** | `compare_` | `compare_<描述>.gd` | `Compare<描述>` | 对比值的关系 |

**命名规则**:
- 文件名必须使用功能前缀（`check_` 或 `compare_`）
- 文件名使用 `snake_case`
- 类名使用 `PascalCase`，与前缀对应（`Check` 或 `Compare`）
- 条件类型字符串使用 `snake_case`，不包含前缀

### 测试文件命名

- **测试脚本**: `test_<文件名>.gd`
  - 例如：`test_check_node_exists.gd`, `test_compare_variable.gd`
- **测试场景**: `test_<文件名>.tscn`
  - 例如：`test_check_node_exists.tscn`, `test_compare_variable.tscn`

### 统一性原则

- 文件名、类名、测试文件名保持一致的基础名称
- 必须使用功能前缀（`check_` 或 `compare_`）
- 类名前缀（`Check` 或 `Compare`）与文件名前缀对应
- 保持简洁可读

**完整示例**:
```
检查类条件：
  文件名：     check_node_exists.gd
  类名：       CheckNodeExists
  条件类型：   "node_exists"
  测试脚本：   test_check_node_exists.gd
  测试场景：   test_check_node_exists.tscn

对比类条件：
  文件名：     compare_variable.gd
  类名：       CompareVariable
  条件类型：   "variable_comparison"
  测试脚本：   test_compare_variable.gd
  测试场景：   test_compare_variable.tscn
```

---

## 图标规范

**图标选择原则**: 每个条件都应该配置图标，提升用户体验和可视化效果。

### 图标配置方式

**推荐：使用 Godot 内置图标**
```gdscript
metadata.builtin_icon = "KeyCurve"  # 使用 Godot 内置图标名称
```

**备选：使用自定义图标库**
```gdscript
metadata.custom_icon = "my_custom_icon"  # 使用导入的自定义图标
```

**向后兼容**
```gdscript
metadata.icon_name = "KeyCurve"  # 旧方式，仍然有效
metadata.icon = preload("res://icon.png")  # 直接指定纹理
```

### 内置图标命名参考

**常用图标名称**：
- **变量条件**: `KeyCurve`, `Hash`, `Array`, `Dictionary`
- **节点条件**: `Node`, `NodePath`, `HostNode`, `Circle`
- **物理条件**: `CollisionShape2D`, `CollisionShape3D`, `PhysicsBody2D`
- **状态条件**: `CheckBox`, `Toggle`, `Check`, `Switch`
- **数学条件**: `Math`, `Graph`, `Curve`, `CurveXY`
- **通用**: `Script`, `File`, `Folder`, `Search`

**完整列表**: 参考 [icon-system-guide.md](icon-system-guide.md)

### 图标配置步骤

在 `_get_condition_metadata()` 中配置图标：

```gdscript
static func _get_condition_metadata() -> ConditionMetadata:
    var metadata = ConditionMetadata.new()
    metadata.builtin_icon = "KeyCurve"  # 配置图标
    return metadata
```

---

## 必需实现的方法

所有条件**必须**实现以下方法，否则会导致编译错误。

### 1. `_update_resource_name()` - 更新资源名称

**标记**: `@abstract` - **必须实现**

```gdscript
## 更新资源名称（必需）
##
## 根据条件属性更新 resource_name，用于在编辑器检查器中显示
func _update_resource_name():
    var parts = []
    parts.append("条件类型名称")
    if not some_property.is_empty():
        parts.append("'%s'" % some_property)
    resource_name = " ".join(parts)
```

**作用**:
- 在编辑器中显示有意义的条件名称
- 方便用户识别和区分不同条件配置

**示例**:
```gdscript
# 简单条件
func _update_resource_name():
    resource_name = "变量比较: %s" % variable_name

# 复杂条件
func _update_resource_name():
    var op_symbol = _get_operator_symbol()
    resource_name = "%s %s %s" % [variable_name, op_symbol, str(threshold)]
```

---

### 2. `_evaluate_condition()` - 评估条件

**标记**: `@abstract` - **必须实现**

```gdscript
## 评估条件（必需）
##
## 评估条件是否满足的核心方法
##
## 参数：
## - context: ExecutionContext - 执行上下文
##
## 返回：
## - bool - 条件评估结果（true = 满足，false = 不满足）
func _evaluate_condition(context: ExecutionContext) -> bool:
    # 验证参数
    if some_parameter.is_empty():
        _log_error_localized("FUSE_ERROR_CONDITION_PARAM_EMPTY", {"param": "some_parameter"})
        _create_fuse_error_localized("FUSE_ERROR_CONDITION_PARAM_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {"param": "some_parameter"})
        return false

    # 执行条件检查逻辑
    var result = perform_check(context)

    _log_debug("条件评估: %s => %s" % [get_description(), result])

    return result
```

**作用**:
- 核心的条件判断逻辑
- 返回 `true` 表示条件满足，`false` 表示不满足
- 系统会自动应用 `negate_result` 取反设置
- 系统会自动处理缓存（如果启用）

**重要**:
- 必须返回布尔值
- 验证参数有效性
- 记录日志
- 不要在此处处理取反（系统自动处理）

**示例**:
```gdscript
# 简单条件
func _evaluate_condition(context: ExecutionContext) -> bool:
    if variable_name.is_empty():
        return false

    var value = VariableOperations.get_variable(context, variable_name, variable_scope, null)
    return value == expected_value

# 复杂条件
func _evaluate_condition(context: ExecutionContext) -> bool:
    var node = context.get_node(target_path)
    if not node:
        return false

    if not node has_method("get_health"):
        return false

    var health = node.get_health()
    return health > threshold
```

---

### 3. `_compute_dependencies()` - 计算依赖

**标记**: `@abstract` - **必须实现**

```gdscript
## 计算依赖（必需）
##
## 返回此条件依赖的变量名列表
## 用于缓存失效和依赖追踪
##
## 返回：
## - Array[String] - 依赖的变量名列表
func _compute_dependencies() -> Array[String]:
    var deps: Array[String] = []

    # 添加依赖的变量
    if not variable_name.is_empty():
        deps.append(variable_name)

    if not another_variable_name.is_empty():
        deps.append(another_variable_name)

    return deps
```

**作用**:
- 声明条件依赖的变量
- 用于智能缓存失效
- 用于依赖追踪和优化

**重要**:
- 如果条件不依赖任何变量，返回空数组 `[]`
- 只返回依赖的**变量名**，不是变量值
- 用于缓存失效检测

**示例**:
```gdscript
# 依赖单个变量
func _compute_dependencies() -> Array[String]:
    if not variable_name.is_empty():
        return [variable_name]
    return []

# 依赖多个变量
func _compute_dependencies() -> Array[String]:
    return [var1, var2, var3]

# 不依赖变量
func _compute_dependencies() -> Array[String]:
    return []  # 例如：节点检查、时间检查等
```

---

## 可选实现的方法

这些方法不是强制要求，但强烈建议实现以提供完整的功能。

### 0. `_compute_thread_safety()` - 计算线程安全性（推荐）

```gdscript
## 计算线程安全性（推荐）
##
## 判断条件是否可以在工作线程中并行评估。
## 只有满足特定条件的条件才能标记为线程安全。
##
## 返回：
## - bool - true 表示线程安全，可参与并行评估
func _compute_thread_safety() -> bool:
	if _thread_safety_computed:
		return _thread_safety_cached

	var is_safe := true

	# 检查是否需要访问节点
	if uses_target_node:
		is_safe = false

	# 检查是否需要访问 ExecutionContext（SCOPE 作用域）
	if variable_scope == BaseVariable.VariableScope.SCOPE:
		is_safe = false

	_thread_safety_cached = is_safe
	_thread_safety_computed = true
	return _thread_safety_cached
```

**线程安全条件**：
- ❌ **不访问节点** - 不调用 `get_node()`、`get_parent()`、`get_tree()`
- ❌ **不访问 ExecutionContext 的 trigger/target** - 只使用变量快照
- ✅ **只读取 LOCAL/GLOBAL 作用域变量** - 不依赖 SCOPE 作用域
- ✅ **只调用线程安全的 API** - 如 `Input.is_action_*()`

**线程安全检测模式**：

| 模式 | 示例 | 线程安全 |
|------|------|---------|
| **总是安全** | 输入检查、预加载状态检查 | ✅ |
| **变量作用域相关** | LOCAL/GLOBAL 安全，SCOPE 不安全 | 部分 |
| **节点访问** | 访问节点属性、子节点 | ❌ |
| **复合条件** | 取决于所有子条件 | 递归检测 |

**示例 - 输入条件（总是安全）**：
```gdscript
func _compute_thread_safety() -> bool:
	if _thread_safety_computed:
		return _thread_safety_cached

	_thread_safety_cached = true  # Input API 线程安全
	_thread_safety_computed = true
	return _thread_safety_cached
```

**示例 - 变量条件（作用域相关）**：
```gdscript
func _compute_thread_safety() -> bool:
	if _thread_safety_computed:
		return _thread_safety_cached

	var is_safe := true

	# SCOPE 作用域需要 ExecutionContext，不安全
	if variable_scope == BaseVariable.VariableScope.SCOPE:
		is_safe = false

	# 如果比较另一个变量，也要检查其作用域
	if is_safe and check_with_another_variable:
		if compare_variable_scope == BaseVariable.VariableScope.SCOPE:
			is_safe = false

	_thread_safety_cached = is_safe
	_thread_safety_computed = true
	return _thread_safety_cached
```

**示例 - 复合条件（递归检测）**：
```gdscript
func _compute_thread_safety() -> bool:
	if _thread_safety_computed:
		return _thread_safety_cached

	var is_safe := true
	for condition in conditions:
		if condition != null and not condition.is_thread_safe:
			is_safe = false
			break

	_thread_safety_cached = is_safe
	_thread_safety_computed = true
	return _thread_safety_cached
```

**重要提示**：
- `_thread_safety_cached` 和 `_thread_safety_computed` 由 `BaseCondition` 提供
- 必须使用缓存机制避免重复计算
- 不确定时返回 `false`（保守策略）
- 详见 [多线程开发者指南](multithreading-developer-guide.md)

---

### 1. `get_description()` - 获取条件描述

```gdscript
## 获取条件描述（推荐）
##
## 返回条件的描述信息，用于在日志和调试中显示
##
## 返回：
## - String - 条件的描述信息
func get_description() -> String:
    if variable_name.is_empty():
        return "变量比较 (未设置变量)"

    return "%s %s %s" % [variable_name, operator, str(compare_value)]
```

**示例**:
```gdscript
func get_description() -> String:
    match comparison_operator:
        EQUAL: return "%s == %s" % [variable_name, compare_value]
        GREATER_THAN: return "%s > %s" % [variable_name, compare_value]
        LESS_THAN: return "%s < %s" % [variable_name, compare_value]
        _: return "未知比较"
```

---

### 2. `get_condition_type()` - 获取条件类型

```gdscript
## 获取条件类型（推荐）
##
## 返回条件的唯一类型标识符
##
## 返回：
## - String - 条件类型名称
func get_condition_type() -> String:
    return "your_condition_type"
```

**命名建议**:
- 使用 `snake_case`
- 简洁且具有描述性
- 例如：`"variable_comparison"`, `"node_exists"`, `"property_check"`

---

### 3. `get_condition_category()` - 获取条件分类

```gdscript
## 获取条件分类（推荐）
##
## 返回条件的分类信息，用于在编辑器中组织条件
##
## 返回：
## - String - 条件分类名称
func get_condition_category() -> String:
    return "your_category"
```

**常用分类**:
- `"variable"` - 变量相关条件
- `"node"` - 节点相关条件
- `"property"` - 属性相关条件
- `"math"` - 数学相关条件
- `"state"` - 状态相关条件

---

### 4. `validate()` - 验证条件配置

```gdscript
## 验证条件配置（推荐）
##
## 验证条件参数的有效性
##
## 返回：
## - Array[String] - 错误信息数组，如果为空则表示验证通过
func validate() -> Array[String]:
    var errors = super.validate()

    # 添加自定义验证
    if variable_name.is_empty():
        errors.append("变量名不能为空")

    if compare_value == null:
        errors.append("比较值不能为空")

    return errors
```

---

### 5. `get_parameters()` / `set_parameters()` - 参数序列化

```gdscript
## 获取参数（可选）
##
## 返回条件的参数字典
func get_parameters() -> Dictionary:
    return {
        "variable_name": variable_name,
        "comparison_operator": comparison_operator,
        "compare_value": compare_value
    }

## 设置参数（可选）
##
## 从字典设置条件参数
func set_parameters(parameters: Dictionary):
    if parameters.has("variable_name"):
        variable_name = parameters["variable_name"]
    if parameters.has("comparison_operator"):
        comparison_operator = parameters["comparison_operator"]
    if parameters.has("compare_value"):
        compare_value = parameters["compare_value"]

    clear_dependencies_cache()  # 清除依赖缓存
```

---

### 6. `_get_condition_metadata()` - 获取条件元数据

```gdscript
## 获取条件元数据（推荐）
##
## 静态方法，返回条件的元数据信息
## 用于条件选择器和编辑器显示
##
## 返回：
## - ConditionMetadata - 条件元数据对象
static func _get_condition_metadata() -> ConditionMetadata:
    var metadata = ConditionMetadata.new()
    metadata.name_key = "FUSE_CONDITION_XXX_NAME"
    metadata.category_key = "FUSE_CATEGORY_XXX"
    metadata.description_key = "FUSE_CONDITION_XXX_DESC"
    metadata.keywords = ["keyword1", "keyword2"]
    metadata.builtin_icon = "Script"
    return metadata
```

---

## 条件特性

BaseCondition 提供了强大的内置特性，子类无需额外实现即可使用。

### 1. 结果取反

```gdscript
@export var negate_result: bool = false
```

**作用**: 自动将条件结果取反，无需在代码中手动处理。

**示例**:
```gdscript
# 条件：检查节点是否存在
# 如果 negate_result = false: 节点存在时返回 true
# 如果 negate_result = true: 节点不存在时返回 true

func _evaluate_condition(context: ExecutionContext) -> bool:
    var node = context.get_node(node_path)
    return node != null  # 系统会自动应用取反
```

### 2. 结果缓存

```gdscript
@export var enable_cache: bool = false
@export var cache_duration: float = 1.0
@export var cache_context_changes: bool = true
```

**作用**: 缓存条件评估结果，提升性能。

**使用场景**:
- 条件检查开销较大（如遍历大量节点）
- 条件在短时间内不会变化
- 需要频繁检查同一条件

**自动失效**:
- 超过 `cache_duration` 时间后失效
- 依赖的变量变化后失效（如果 `cache_context_changes = true`）

### 3. 依赖追踪

```gdscript
func get_dependencies() -> Array[String]:
    # 自动缓存，避免重复计算
    if _cached_dependencies.is_empty():
        _cached_dependencies = _compute_dependencies()
    return _cached_dependencies
```

**作用**: 自动追踪条件依赖的变量，用于缓存失效和优化。

### 4. 启用/禁用

```gdscript
@export var enabled: bool = true
```

**作用**: 禁用后，`check()` 方法始终返回 `false`。

### 5. 性能指标

```gdscript
var check_count: int = 0        # 检查次数
var last_check_time: float = 0.0 # 最后检查时间
var last_result: bool = false    # 最后检查结果
```

**作用**: 自动记录条件检查的性能指标。

---

## 变量操作（三层变量系统）

Fuse 系统使用**三层变量架构**，条件在评估时需要读取这些变量。理解如何正确访问变量是编写条件的关键。

### 三层变量架构

| 作用域 | 枚举值 | 存储位置 | 生命周期 | 用途 |
|--------|--------|----------|----------|------|
| **LOCAL** | `VariableScope.LOCAL` (0) | ExecutionContext | 单次条件评估 | 临时数据、中间值 |
| **SCOPE** | `VariableScope.SCOPE` (1) | ScopeVariableContainer | 节点生命周期 | 场景局部变量 |
| **GLOBAL** | `VariableScope.GLOBAL` (2) | GlobalVariableResource | 游戏运行时 | 全局游戏状态 |

### VariableOperations 工具类

使用 `VariableOperations` 工具类统一变量访问，**不要直接使用** `context.get_variable()` 或 `context.set_variable()`。

#### 读取变量

```gdscript
## 从指定作用域读取变量
##
## 参数：
## - context: ExecutionContext - 执行上下文
## - variable_name: String - 变量名
## - scope: VariableScope - 变量作用域
## - default_value: Variant = null - 默认值（变量不存在时返回）
##
## 返回：
## - Variant - 变量值，如果不存在则返回 default_value
var value = VariableOperations.get_variable(context, "my_var", VariableScope.LOCAL)

## 带默认值的读取
var health = VariableOperations.get_variable(context, "player_health", VariableScope.GLOBAL, 100)
```

#### 检查变量存在性

```gdscript
## 检查变量是否存在
##
## 参数：
## - context: ExecutionContext - 执行上下文
## - variable_name: String - 变量名
## - scope: VariableScope - 变量作用域
##
## 返回：
## - bool - 变量是否存在
if VariableOperations.has_variable(context, "player_health", VariableScope.GLOBAL):
    var health = VariableOperations.get_variable(context, "player_health", VariableScope.GLOBAL)
```

### 条件中的变量访问模式

#### 1. 固定作用域的条件

```gdscript
@export var variable_name: String = "":
    set(value):
        variable_name = value
        clear_dependencies_cache()

@export var scope: BaseVariable.VariableScope = BaseVariable.VariableScope.GLOBAL

@export var threshold: float = 0.0

func _evaluate_condition(context: ExecutionContext) -> bool:
    if variable_name.is_empty():
        _create_fuse_error_localized("FUSE_ERROR_VAR_NAME_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
        return false

    # 使用 VariableOperations 读取变量
    var value = VariableOperations.get_variable(context, variable_name, scope)
    if value == null:
        _create_fuse_error_localized("FUSE_ERROR_VAR_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {"variable": variable_name})
        return false

    # 执行比较
    return float(value) > threshold

func _compute_dependencies() -> Array[String]:
    if not variable_name.is_empty():
        return [variable_name]
    return []
```

#### 2. 多作用域条件（带作用域选择器）

```gdscript
@export var variable_name: String = "":
    set(value):
        variable_name = value
        clear_dependencies_cache()

@export_group("Variable Scope")
@export var use_local: bool = false
@export var use_scope: bool = false
@export var scope_id: String = ""
@export var use_global: bool = true

func _get_effective_scope() -> BaseVariable.VariableScope:
    ## 根据配置确定有效的作用域
    if use_local:
        return BaseVariable.VariableScope.LOCAL
    elif use_scope:
        return BaseVariable.VariableScope.SCOPE
    else:
        return BaseVariable.VariableScope.GLOBAL

func _evaluate_condition(context: ExecutionContext) -> bool:
    if variable_name.is_empty():
        return false

    var scope = _get_effective_scope()
    var value = VariableOperations.get_variable(context, variable_name, scope, 0)
    return value > threshold
```

### VariableScopeUtils 工具类

用于作用域枚举和字符串之间的转换：

```gdscript
## 将作用域枚举转换为小写字符串
##
## GLOBAL -> "global"
## SCOPE -> "scope"
## LOCAL -> "local"
var scope_str = VariableScopeUtils.enum_to_string(BaseVariable.VariableScope.GLOBAL)

## 获取作用域的本地化显示名称
##
## 用于在 Inspector 中显示友好的作用域名称
var display_name = VariableScopeUtils.enum_to_display_name(BaseVariable.VariableScope.SCOPE)
```

### 条件中的变量最佳实践

#### ✅ 好的做法

```gdscript
func _evaluate_condition(context: ExecutionContext) -> bool:
    # 1. 验证参数
    if variable_name.is_empty():
        _create_fuse_error_localized("FUSE_ERROR_VAR_NAME_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
        return false

    # 2. 使用 VariableOperations 读取变量
    var value = VariableOperations.get_variable(context, variable_name, scope)
    if value == null:
        _create_fuse_error_localized("FUSE_ERROR_VAR_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {"variable": variable_name})
        return false

    # 3. 类型检查
    if not (value is int or value is float):
        _log_warning("变量类型不支持数值比较: %s" % type_string(typeof(value)))
        return false

    # 4. 执行比较
    return float(value) > threshold
```

#### ❌ 不好的做法

```gdscript
func _evaluate_condition(context: ExecutionContext) -> bool:
    # ❌ 直接使用 context.get_variable()，不推荐
    var value = context.get_variable(variable_name)

    # ❌ 没有验证变量是否存在
    # ❌ 没有类型检查
    return value > threshold
```

### 条件中的变量声明依赖

当条件依赖变量时，必须在 `_compute_dependencies()` 中声明：

```gdscript
func _compute_dependencies() -> Array[String]:
    # 返回依赖的变量名列表（不带作用域前缀）
    if not variable_name.is_empty():
        return [variable_name]
    return []
```

**重要**:
- 依赖只使用**变量名**，不包含作用域
- 系统会自动追踪所有作用域中该变量的变化
- 当变量变化时，缓存的评估结果会自动失效

### 测试中的变量操作

在条件测试中，使用 VariableOperations 设置测试变量：

```gdscript
func test_evaluation():
    var condition = MyCondition.new()
    condition.variable_name = "test_var"
    condition.scope = BaseVariable.VariableScope.LOCAL

    var context = ExecutionContext.new()
    add_child(context)

    # 使用 VariableOperations 设置测试变量
    VariableOperations.set_variable(context, "test_var", 100, BaseVariable.VariableScope.LOCAL)

    # 检查条件
    var result = condition.check(context)
    assert(result == true, "Condition should be true")

    context.queue_free()
```

---

## 完整条件模板

### 检查类条件模板

```gdscript
@tool
@icon("res://addons/fuse/icons/builtin/Script.png")
extends BaseCondition
class_name CheckSimpleValue

## 简单检查条件模板

# 参数定义
@export_group("Simple Condition")
@export var target_value: int = 0:
    set(value):
        target_value = value
        clear_dependencies_cache()

## 更新资源名称（必需）
func _update_resource_name():
    resource_name = "变量值等于 %d" % target_value

## 评估条件（必需）
func _evaluate_condition(context: ExecutionContext) -> bool:
    # 验证参数
    if not context:
        _log_error_localized("FUSE_ERROR_CONTEXT_NULL_EVALUATE", {})
        _create_fuse_error_localized("FUSE_ERROR_CONTEXT_NULL_EVALUATE", FuseError.ErrorType.VALIDATION_ERROR)
        return false

    # 获取变量值（使用 VariableOperations）
    var var_name = "my_variable"
    var current_value = VariableOperations.get_variable(context, var_name, BaseVariable.VariableScope.LOCAL)

    if current_value == null:
        _log_warning("变量不存在: %s" % var_name)
        return false

    # 执行比较
    var result = current_value == target_value

    _log_debug("条件评估: %s (%d) == %d => %s" % [
        var_name, current_value, target_value, result
    ])

    return result

## 计算依赖（必需）
func _compute_dependencies() -> Array[String]:
    return ["my_variable"]

## 计算线程安全性（推荐）
##
## LOCAL 作用域是线程安全的，SCOPE 作用域不安全（需要 ExecutionContext）
func _compute_thread_safety() -> bool:
    if _thread_safety_computed:
        return _thread_safety_cached

    # LOCAL 和 GLOBAL 作用域可以并行评估
    _thread_safety_cached = true
    _thread_safety_computed = true
    return _thread_safety_cached

## 获取条件描述（推荐）
func get_description() -> String:
    return "变量值等于 %d" % target_value

## 获取条件类型（推荐）
func get_condition_type() -> String:
    return "simple_template"

## 获取条件分类（推荐）
func get_condition_category() -> String:
    return "template"

## 验证条件配置（推荐）
func validate() -> Array[String]:
    var errors = super.validate()

    # 这里可以添加额外的验证逻辑

    return errors

## 获取条件元数据（推荐）
static func _get_condition_metadata() -> ConditionMetadata:
    var metadata = ConditionMetadata.new()
    metadata.name_key = "FUSE_CONDITION_SIMPLE_TEMPLATE_NAME"
    metadata.category_key = "FUSE_CATEGORY_TEMPLATE"
    metadata.description_key = "FUSE_CONDITION_SIMPLE_TEMPLATE_DESC"
    metadata.keywords = ["template", "模板", "simple", "简单", "check", "检查"]
    metadata.builtin_icon = "Script"
    return metadata
```

---

### 对比类条件模板

```gdscript
@tool
@icon("res://addons/fuse/icons/builtin/Hash.png")
extends BaseCondition
class_name CompareVariableThreshold

## 变量阈值对比条件模板（多参数、多依赖）

# 参数定义
@export_group("Complex Condition")
@export var variable_name: String = "":
    set(value):
        variable_name = value
        clear_dependencies_cache()

@export_enum("等于:0", "大于:1", "小于:2", "大于等于:3", "小于等于:4") var comparison_operator: int = 0

@export var threshold: float = 0.0:
    set(value):
        threshold = value
        clear_dependencies_cache()

@export var check_node_path: NodePath = NodePath("")

## 更新资源名称（必需）
func _update_resource_name():
    if variable_name.is_empty():
        resource_name = "复杂条件 (未设置变量)"
        return

    var op_symbol = _get_operator_symbol()
    resource_name = "%s %s %.2f" % [variable_name, op_symbol, threshold]

## 评估条件（必需）
func _evaluate_condition(context: ExecutionContext) -> bool:
    # 1. 验证参数
    if variable_name.is_empty():
        _log_error_localized("FUSE_ERROR_VAR_NAME_EMPTY", {})
        _create_fuse_error_localized("FUSE_ERROR_VAR_NAME_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
        return false

    # 2. 获取变量值（使用 VariableOperations）
    var var_value = VariableOperations.get_variable(context, variable_name, BaseVariable.VariableScope.GLOBAL)
    if var_value == null:
        _log_error_localized("FUSE_ERROR_VAR_NOT_FOUND", {"variable": variable_name})
        _create_fuse_error_localized("FUSE_ERROR_VAR_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {"variable": variable_name})
        return false

    # 3. 检查节点（可选）
    if not check_node_path.is_empty():
        var node = context.get_node(check_node_path)
        if not node:
            _log_warning("节点不存在: %s" % check_node_path)
            return false

    # 4. 执行比较
    var result := false

    # 将值转换为 float 进行比较
    var var_float = float(var_value)
    var threshold_float = float(threshold)

    match comparison_operator:
        0:  # 等于
            result = is_equal_approx(var_float, threshold_float)
        1:  # 大于
            result = var_float > threshold_float
        2:  # 小于
            result = var_float < threshold_float
        3:  # 大于等于
            result = var_float >= threshold_float
        4:  # 小于等于
            result = var_float <= threshold_float
        _:
            _log_error_localized("FUSE_ERROR_UNKNOWN_COMPARISON_OPERATOR", {"operator": comparison_operator})
            return false

    _log_debug("条件评估: %s (%.2f) %s %.2f => %s" % [
        variable_name,
        var_float,
        _get_operator_symbol(),
        threshold_float,
        result
    ])

    return result

## 计算依赖（必需）
func _compute_dependencies() -> Array[String]:
    if not variable_name.is_empty():
        return [variable_name]
    return []

## 获取运算符符号
func _get_operator_symbol() -> String:
    match comparison_operator:
        0: return "=="
        1: return ">"
        2: return "<"
        3: return ">="
        4: return "<="
        _: return "?"

## 获取条件描述（推荐）
func get_description() -> String:
    if variable_name.is_empty():
        return "复杂条件 (未设置变量)"

    var op_symbol = _get_operator_symbol()
    var desc = "%s %s %.2f" % [variable_name, op_symbol, threshold]

    # 限制描述长度
    if desc.length() > 50:
        desc = desc.substr(0, 47) + "..."

    return desc

## 获取条件类型（推荐）
func get_condition_type() -> String:
    return "complex_template"

## 获取条件分类（推荐）
func get_condition_category() -> String:
    return "template"

## 验证条件配置（推荐）
func validate() -> Array[String]:
    var errors = super.validate()

    if variable_name.is_empty():
        errors.append("变量名不能为空")

    if comparison_operator < 0 or comparison_operator > 4:
        errors.append("无效的比较运算符")

    return errors

## 获取参数（可选）
func get_parameters() -> Dictionary:
    return {
        "variable_name": variable_name,
        "comparison_operator": comparison_operator,
        "threshold": threshold,
        "check_node_path": check_node_path
    }

## 设置参数（可选）
func set_parameters(parameters: Dictionary):
    if parameters.has("variable_name"):
        variable_name = parameters["variable_name"]
    if parameters.has("comparison_operator"):
        comparison_operator = parameters["comparison_operator"]
    if parameters.has("threshold"):
        threshold = parameters["threshold"]
    if parameters.has("check_node_path"):
        check_node_path = parameters["check_node_path"]

    clear_dependencies_cache()

## 获取条件元数据（推荐）
static func _get_condition_metadata() -> ConditionMetadata:
    var metadata = ConditionMetadata.new()
    metadata.name_key = "FUSE_CONDITION_COMPLEX_TEMPLATE_NAME"
    metadata.category_key = "FUSE_CATEGORY_TEMPLATE"
    metadata.description_key = "FUSE_CONDITION_COMPLEX_TEMPLATE_DESC"
    metadata.keywords = ["template", "模板", "complex", "复杂", "comparison", "比较", "threshold", "阈值"]
    metadata.builtin_icon = "Hash"
    return metadata
```

---

## 创建步骤

### Step 1: 创建条件类骨架

创建条件文件 `addons/fuse/conditions/<your_condition_name>_condition.gd`：

```gdscript
@tool
@icon("res://addons/fuse/icons/builtin/Script.png")
extends BaseCondition
class_name YourConditionName

## 条件描述

# 参数定义
@export_group("Your Condition")
@export var your_property: String = ""

## 更新资源名称（必需）
func _update_resource_name():
    resource_name = "你的条件: %s" % your_property

## 评估条件（必需）
func _evaluate_condition(context: ExecutionContext) -> bool:
    # TODO: 实现条件评估逻辑
    return false

## 计算依赖（必需）
func _compute_dependencies() -> Array[String]:
    return []
```

### Step 2: 实现核心方法

**2.1 实现 `_evaluate_condition()`**:
```gdscript
func _evaluate_condition(context: ExecutionContext) -> bool:
    # 1. 验证参数
    if your_property.is_empty():
        _log_error_localized("FUSE_ERROR_CONDITION_PROPERTY_EMPTY", {"property": "your_property"})
        _create_fuse_error_localized("FUSE_ERROR_CONDITION_PROPERTY_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {"property": "your_property"})
        return false

    # 2. 执行条件检查逻辑
    var result = perform_your_check(context, your_property)

    # 3. 记录日志
    _log_debug("条件评估: %s => %s" % [your_property, result])

    return result
```

**2.2 实现 `_compute_dependencies()`**:
```gdscript
func _compute_dependencies() -> Array[String]:
    # 返回依赖的变量名列表
    if not your_property.is_empty():
        return [your_property]
    return []
```

### Step 3: 添加本地化翻译

在 `addons/fuse/localization/translations.csv` 添加：

```csv
key,zh_CN,en_US
FUSE_CONDITION_YOUR_CONDITION_NAME,你的条件名称,Your Condition Name
FUSE_CATEGORY_YOUR_CATEGORY,你的分类,Your Category
FUSE_CONDITION_YOUR_CONDITION_DESC,条件描述,Condition description
FUSE_ERROR_YOUR_CONDITION_ERROR,错误消息,Error message
```

**注意**：
- 使用 `NAME` 后缀表示条件名称
- 使用 `DESC` 后缀表示条件描述
- 使用 `ERROR_` 后缀表示错误消息
- 所有占位符使用 `{variable_name}` 格式

### Step 4: 创建测试场景

**Step 4.1: 创建测试场景文件**

创建 `tests/conditions/test_<condition_name>.tscn`：

```gdscript
[gd_scene load_steps=2 format=3 uid="uid://test_xxx"]

[ext_resource type="Script" path="res://tests/conditions/test_xxx.gd" id="1"]

[node name="TestXxx" type="Node"]
script = ExtResource("1")
```

**Step 4.2: 创建测试脚本**

创建 `tests/conditions/test_<condition_name>.gd`：

```gdscript
extends Node

## YourConditionName 条件测试

func _ready():
    print("=== Testing YourConditionName ===")
    test_basic_functionality()
    test_edge_cases()
    print("=== All YourConditionName tests passed! ===")

func test_basic_functionality():
    print("Test 1: Basic functionality")

    var condition_script = load("res://addons/fuse/conditions/your_condition_name.gd")
    var condition = condition_script.new()
    condition.your_property = "test_value"

    var context = ExecutionContext.new()
    add_child(context)

    # 设置变量（使用 VariableOperations）
    VariableOperations.set_variable(context, "test_var", 100, BaseVariable.VariableScope.LOCAL)

    # 检查条件
    var result = condition.check(context)

    # 验证结果
    assert(result == expected, "Condition should return expected value")
    print("  ✓ Test 1 passed\n")

    # 清理
    context.queue_free()

func test_edge_cases():
    print("Test 2: Edge cases")
    # 测试边界情况...
    print("  ✓ Test 2 passed\n")
```

### Step 5: 测试验证

1. 在 Godot 中打开测试场景
2. 运行测试，确认所有测试用例通过
3. 检查编辑器中的 Inspector 显示是否正确
4. 验证本地化是否生效
5. 验证缓存功能是否正常工作
6. 验证取反功能是否正常工作

---

## 最佳实践

### 1. 参数验证

**原则**: 在 `_evaluate_condition()` 开始时验证所有参数。

```gdscript
# ✅ 好的做法
func _evaluate_condition(context: ExecutionContext) -> bool:
    # 验证上下文
    if not context:
        _create_fuse_error_localized("FUSE_ERROR_CONTEXT_NULL", FuseError.ErrorType.VALIDATION_ERROR, {})
        return false

    # 验证参数
    if variable_name.is_empty():
        _create_fuse_error_localized("FUSE_ERROR_VAR_NAME_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
        return false

    # 执行检查逻辑
    ...
```

```gdscript
# ❌ 不验证参数
func _evaluate_condition(context: ExecutionContext) -> bool:
    # 直接使用参数，可能导致错误
    var value = context.get_variable(variable_name)  # variable_name 可能为空
    ...
```

---

### 2. 依赖声明

**原则**: 正确声明所有依赖的变量。

```gdscript
# ✅ 好的做法
func _compute_dependencies() -> Array[String]:
    var deps: Array[String] = []

    # 添加所有依赖的变量
    if not var1.is_empty():
        deps.append(var1)
    if not var2.is_empty():
        deps.append(var2)

    return deps
```

```gdscript
# ❌ 忘记声明依赖
func _compute_dependencies() -> Array[String]:
    return []  # 实际上使用了变量，但未声明
```

---

### 3. 本地化错误

**原则**: 使用本地化错误消息。

```gdscript
# ✅ 好的做法
if variable_name.is_empty():
    _create_fuse_error_localized("FUSE_ERROR_VAR_NAME_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
    return false
```

```gdscript
# ❌ 硬编码错误消息
if variable_name.is_empty():
    _create_fuse_error("变量名不能为空", FuseError.ErrorType.VALIDATION_ERROR)
    return false
```

---

### 4. 日志记录

**原则**: 使用适当的日志级别和本地化日志。

```gdscript
# ✅ 好的做法
func _evaluate_condition(context: ExecutionContext) -> bool:
    _log_debug("开始评估条件: %s" % get_description())

    var result = perform_check()

    _log_debug("条件评估结果: %s => %s" % [get_description(), result])
    return result
```

---

### 5. 类型安全

**原则**: 使用类型注解和类型检查。

```gdscript
# ✅ 好的做法
func _evaluate_condition(context: ExecutionContext) -> bool:
    var value = VariableOperations.get_variable(context, variable_name, BaseVariable.VariableScope.GLOBAL)

    # 类型检查
    if not typeof(value) in [TYPE_INT, TYPE_FLOAT]:
        _log_warning("变量类型不支持比较: %s" % type_string(typeof(value)))
        return false

    return value > threshold
```

---

### 6. 使用取反特性

**原则**: 不要在代码中手动实现取反，使用内置的 `negate_result`。

```gdscript
# ✅ 好的做法
func _evaluate_condition(context: ExecutionContext) -> bool:
    # 只返回正向条件
    return node != null

# 用户可以在 Inspector 中设置 negate_result = true 来反转结果
```

```gdscript
# ❌ 手动实现取反
func _evaluate_condition(context: ExecutionContext) -> bool:
    # 不要这样做，应该使用 negate_result
    return not (node != null)
```

---

### 7. 缓存优化

**原则**: 对于开销较大的条件检查，启用缓存。

```gdscript
# 在 Inspector 中设置：
# enable_cache = true
# cache_duration = 1.0  # 缓存1秒
```

**适用场景**:
- 遍历大量节点
- 复杂的数学计算
- 访问远程资源

---

### 8. 描述长度限制

**原则**: 限制描述长度，避免 UI 显示问题。

```gdscript
# ✅ 好的做法
func get_description() -> String:
	var desc = "很长的描述字符串..."

	# 限制描述长度
	if desc.length() > 50:
		desc = desc.substr(0, 47) + "..."

	return desc
```

---

### 9. 线程安全实现

**原则**: 正确实现 `_compute_thread_safety()` 以支持并行评估。

```gdscript
# ✅ 好的做法 - 使用缓存机制
func _compute_thread_safety() -> bool:
	if _thread_safety_computed:
		return _thread_safety_cached

	var is_safe := true

	# 检查不安全因素
	if needs_node_access or uses_scope_variables:
		is_safe = false

	_thread_safety_cached = is_safe
	_thread_safety_computed = true
	return _thread_safety_cached
```

```gdscript
# ❌ 错误 - 不使用缓存
func _compute_thread_safety() -> bool:
	return not needs_node_access  # 每次都重新计算
```

```gdscript
# ❌ 错误 - 保守估计但实际不安全
func _compute_thread_safety() -> bool:
	return true  # 但实际上访问了节点！
```

**线程安全检查清单**：
- [ ] 不调用 `get_node()`, `get_parent()`, `get_tree()`
- [ ] 不访问 `context.trigger` 或 `context.target`
- [ ] 只使用 LOCAL/GLOBAL 作用域变量
- [ ] 不修改任何全局状态
- [ ] 使用缓存机制避免重复计算

**原则**: 限制描述长度，避免 UI 显示问题。

```gdscript
# ✅ 好的做法
func get_description() -> String:
    var desc = "很长的描述字符串..."

    # 限制描述长度
    if desc.length() > 50:
        desc = desc.substr(0, 47) + "..."

    return desc
```

---

## 常见陷阱

### 陷阱 1: 忘记实现必需方法

**问题**:
```gdscript
@tool
extends BaseCondition
class_name MyCondition

# ❌ 忘记实现 _update_resource_name()
# ❌ 忘记实现 _evaluate_condition()
# ❌ 忘记实现 _compute_dependencies()
```

**后果**:
- 编译错误（三个方法都是 `@abstract`）

**解决方案**:
```gdscript
@tool
extends BaseCondition
class_name MyCondition

# ✅ 实现所有必需方法
func _update_resource_name():
    resource_name = "My Condition"

func _evaluate_condition(context: ExecutionContext) -> bool:
    return true

func _compute_dependencies() -> Array[String]:
    return []
```

---

### 陷阱 2: 在 _evaluate_condition 中处理取反

**问题**:
```gdscript
func _evaluate_condition(context: ExecutionContext) -> bool:
    var result = check_condition()

    # ❌ 手动处理取反
    if negate_result:
        result = not result

    return result
```

**后果**: 取反被应用两次（一次在代码中，一次在基类中）。

**解决方案**:
```gdscript
func _evaluate_condition(context: ExecutionContext) -> bool:
    # ✅ 只返回正向结果，基类会自动处理取反
    return check_condition()
```

---

### 陷阱 3: 未声明依赖的变量

**问题**:
```gdscript
func _evaluate_condition(context: ExecutionContext) -> bool:
    # 使用了变量 var1 和 var2
    var val1 = VariableOperations.get_variable(context, "var1", BaseVariable.VariableScope.LOCAL)
    var val2 = VariableOperations.get_variable(context, "var2", BaseVariable.VariableScope.LOCAL)
    return val1 > val2

# ❌ 忘记在 _compute_dependencies 中声明
func _compute_dependencies() -> Array[String]:
    return []
```

**后果**: 缓存可能不会正确失效。

**解决方案**:
```gdscript
# ✅ 正确声明依赖
func _compute_dependencies() -> Array[String]:
    return ["var1", "var2"]
```

---

### 陷阱 4: 返回非布尔值

**问题**:
```gdscript
func _evaluate_condition(context: ExecutionContext) -> bool:
    var value = VariableOperations.get_variable(context, "my_var", BaseVariable.VariableScope.LOCAL)
    return value  # ❌ 可能不是布尔值
```

**后果**: 类型不匹配错误。

**解决方案**:
```gdscript
func _evaluate_condition(context: ExecutionContext) -> bool:
    var value = VariableOperations.get_variable(context, "my_var", BaseVariable.VariableScope.LOCAL)

    # ✅ 显式转换为布尔值
    if value is bool:
        return value
    elif value is int or value is float:
        return value != 0
    elif value is String:
        return not value.is_empty()
    else:
        return value != null
```

---

### 陷阱 5: 不验证参数

**问题**:
```gdscript
func _evaluate_condition(context: ExecutionContext) -> bool:
    # ❌ 直接使用参数，不验证
    var value = VariableOperations.get_variable(context, variable_name, BaseVariable.VariableScope.GLOBAL)
    return value > threshold
```

**后果**: 参数为空时运行时错误。

**解决方案**:
```gdscript
func _evaluate_condition(context: ExecutionContext) -> bool:
    # ✅ 验证参数
    if variable_name.is_empty():
        _create_fuse_error_localized("FUSE_ERROR_VAR_NAME_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
        return false

    var value = VariableOperations.get_variable(context, variable_name, BaseVariable.VariableScope.GLOBAL)
    if value == null:
        _create_fuse_error_localized("FUSE_ERROR_VAR_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {"variable": variable_name})
        return false

    return value > threshold
```

---

### 陷阱 6: 依赖缓存在设置参数后未清除

**问题**:
```gdscript
@export var variable_name: String = "":
    set(value):
        variable_name = value
        # ❌ 忘记清除依赖缓存

@export var variable_name: String = ""
```

**后果**: 依赖列表不会更新，缓存失效不正确。

**解决方案**:
```gdscript
@export var variable_name: String = "":
    set(value):
        variable_name = value
        clear_dependencies_cache()  # ✅ 清除依赖缓存
```

---

### 陷阱 7: 描述过长导致 UI 问题

**问题**:
```gdscript
func get_description() -> String:
    # ❌ 描述可能非常长
    return "这是一个非常非常非常非常非常非常非常非常非常非常长的描述..."
```

**后果**: UI 显示问题，文本被截断或重叠。

**解决方案**:
```gdscript
func get_description() -> String:
    var desc = "这是一个非常非常非常非常非常非常非常非常非常非常长的描述..."

    # ✅ 限制描述长度
    if desc.length() > 50:
        desc = desc.substr(0, 47) + "..."

    return desc
```

---

### 陷阱 8: 不处理类型不匹配

**问题**:
```gdscript
func _evaluate_condition(context: ExecutionContext) -> bool:
    var value = VariableOperations.get_variable(context, variable_name, BaseVariable.VariableScope.GLOBAL)
    # ❌ 直接比较，可能类型不匹配
    return value > threshold
```

**后果**: 类型不匹配错误或意外的比较结果。

**解决方案**:
```gdscript
func _evaluate_condition(context: ExecutionContext) -> bool:
    var value = VariableOperations.get_variable(context, variable_name, BaseVariable.VariableScope.GLOBAL)

    # ✅ 类型检查和转换
    if not (value is int or value is float):
        _log_warning("变量类型不支持数值比较: %s" % type_string(typeof(value)))
        return false

    return float(value) > float(threshold)
```

---

## 测试规范

### 测试文件结构

```gdscript
extends Node

## ConditionName 条件测试

func _ready():
    print("=== Testing ConditionName ===")
    test_evaluation()
    test_negation()
    test_caching()
    test_dependencies()
    test_edge_cases()
    print("=== All ConditionName tests passed! ===")
```

### 测试用例设计

**必需的测试**:
1. **基本评估测试** - 验证条件正确评估
2. **取反测试** - 验证 `negate_result` 功能
3. **缓存测试** - 验证缓存功能正常工作
4. **依赖测试** - 验证依赖声明正确
5. **边界值测试** - 测试极端参数值
6. **错误处理测试** - 验证错误情况被正确处理

**测试示例**:
```gdscript
func test_evaluation():
    print("Test 1: Basic evaluation")

    var condition = MyCondition.new()
    condition.variable_name = "test_var"
    condition.threshold = 100

    var context = ExecutionContext.new()
    add_child(context)

    # 测试满足条件的情况（使用 VariableOperations）
    VariableOperations.set_variable(context, "test_var", 150, BaseVariable.VariableScope.LOCAL)
    assert(condition.check(context) == true, "Should be true when value > threshold")

    # 测试不满足条件的情况
    VariableOperations.set_variable(context, "test_var", 50, BaseVariable.VariableScope.LOCAL)
    assert(condition.check(context) == false, "Should be false when value < threshold")

    print("  ✓ Test 1 passed\n")

    context.queue_free()

func test_negation():
    print("Test 2: Negation")

    var condition = MyCondition.new()
    condition.variable_name = "test_var"
    condition.threshold = 100
    condition.negate_result = true  # 启用取反

    var context = ExecutionContext.new()
    add_child(context)

    VariableOperations.set_variable(context, "test_var", 150, BaseVariable.VariableScope.LOCAL)
    # 由于取反，原本返回 true 的现在返回 false
    assert(condition.check(context) == false, "Should be false with negation")

    print("  ✓ Test 2 passed\n")

    context.queue_free()

func test_caching():
    print("Test 3: Caching")

    var condition = MyCondition.new()
    condition.variable_name = "test_var"
    condition.enable_cache = true
    condition.cache_duration = 1.0

    var context = ExecutionContext.new()
    add_child(context)

    VariableOperations.set_variable(context, "test_var", 100, BaseVariable.VariableScope.LOCAL)

    # 第一次检查
    var result1 = condition.check(context)
    assert(condition.check_count == 1, "Should increment check count")

    # 第二次检查（应该使用缓存）
    var result2 = condition.check(context)
    assert(condition.check_count == 1, "Should use cache, not increment count")

    print("  ✓ Test 3 passed\n")

    context.queue_free()

func test_dependencies():
    print("Test 4: Dependencies")

    var condition = MyCondition.new()
    condition.variable_name = "test_var"

    var deps = condition.get_dependencies()
    assert(deps.size() == 1, "Should have one dependency")
    assert(deps[0] == "test_var", "Dependency should be 'test_var'")

    print("  ✓ Test 4 passed\n")

func test_edge_cases():
    print("Test 5: Edge cases")

    var condition = MyCondition.new()
    # 不设置变量名
    condition.variable_name = ""

    var context = ExecutionContext.new()
    add_child(context)

    # 应该返回 false（参数无效）
    assert(condition.check(context) == false, "Should return false with invalid parameters")

    print("  ✓ Test 5 passed\n")

    context.queue_free()
```

### 测试断言

```gdscript
# 验证条件结果
assert(condition.check(context) == expected, "Condition should return expected value")

# 验证取反
assert(condition.check(context) == not expected, "Condition should be negated")

# 验证缓存
assert(condition.check_count == expected_count, "Check count should match")

# 验证依赖
assert(condition.get_dependencies().size() == expected_size, "Dependency count should match")
```

---

## 快速参考

### 常用代码片段

#### 变量检查
```gdscript
func _evaluate_condition(context: ExecutionContext) -> bool:
    if variable_name.is_empty():
        _create_fuse_error_localized("FUSE_ERROR_VAR_NAME_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
        return false

    var value = VariableOperations.get_variable(context, variable_name, BaseVariable.VariableScope.GLOBAL)
    if value == null:
        _create_fuse_error_localized("FUSE_ERROR_VAR_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {"variable": variable_name})
        return false

    return value == expected_value
```

#### 节点检查
```gdscript
func _evaluate_condition(context: ExecutionContext) -> bool:
    if node_path.is_empty():
        _create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
        return false

    var node = context.get_node(node_path)
    if not node:
        return false

    # 检查节点类型
    if not node is NodeType:
        _log_warning("节点类型不匹配: %s" % node.get_class())
        return false

    return true
```

#### 数值比较
```gdscript
func _evaluate_condition(context: ExecutionContext) -> bool:
    var value = VariableOperations.get_variable(context, variable_name, BaseVariable.VariableScope.GLOBAL)

    # 类型检查
    if not (value is int or value is float):
        _log_warning("变量类型不支持数值比较: %s" % type_string(typeof(value)))
        return false

    # 转换为 float
    var value_float = float(value)
    var threshold_float = float(threshold)

    # 比较
    match comparison_operator:
        0: return is_equal_approx(value_float, threshold_float)
        1: return value_float > threshold_float
        2: return value_float < threshold_float
        3: return value_float >= threshold_float
        4: return value_float <= threshold_float
        _: return false
```

#### 属性检查
```gdscript
func _evaluate_condition(context: ExecutionContext) -> bool:
    var node = context.get_node(node_path)
    if not node:
        return false

    # 检查属性是否存在
    if not "property_name" in node:
        _log_warning("节点缺少属性: property_name")
        return false

    var value = node.get("property_name")

    # 比较属性值
    return value == expected_value
```

### 常用错误键

已定义的本地化错误键（参考 `translations.csv`）：
- `FUSE_ERROR_CONTEXT_NULL` - 执行上下文为空
- `FUSE_ERROR_VAR_NAME_EMPTY` - 变量名为空
- `FUSE_ERROR_VAR_NOT_FOUND` - 变量未找到
- `FUSE_ERROR_TARGET_NODE_EMPTY` - 目标节点路径为空
- `FUSE_ERROR_TARGET_NODE_NOT_FOUND` - 目标节点未找到
- `FUSE_ERROR_INVALID_TARGET` - 目标无效
- `FUSE_ERROR_MISSING_PARAMETER` - 缺少必需参数

### 常用日志键

- `FUSE_LOG_CONDITION_CHECK` - 条件检查
- `FUSE_LOG_CONDITION_RESULT` - 条件结果
- `FUSE_LOG_CONDITION_CACHE_HIT` - 缓存命中
- `FUSE_LOG_CONDITION_CACHE_MISS` - 缓存未命中

---

## 总结

创建 Fuse 条件的关键要点：

1. ✅ **遵循命名规范** - `_condition` 后缀，类名自然以 "Condition" 结尾
2. ✅ **实现必需方法** - `_update_resource_name()`, `_evaluate_condition()`, `_compute_dependencies()`
3. ✅ **正确声明依赖** - 在 `_compute_dependencies()` 中返回所有依赖的变量
4. ✅ **验证参数有效性** - 在 `_evaluate_condition()` 开始时验证
5. ✅ **使用本地化消息** - 使用 `_create_fuse_error_localized()`
6. ✅ **不要手动取反** - 使用内置的 `negate_result` 属性
7. ✅ **添加完整测试** - 评估、取反、缓存、依赖、边界情况
8. ✅ **限制描述长度** - 避免超过 50 个字符
9. ✅ **提供元数据** - 实现 `_get_condition_metadata()` 静态方法
10. ✅ **使用 VariableOperations** - 统一使用 VariableOperations 访问三层变量系统
11. ✅ **实现线程安全检测** - 重写 `_compute_thread_safety()` 支持并行评估

**核心原则**:
- **_update_resource_name()** 更新资源显示名称
- **_evaluate_condition()** 返回布尔值
- **_compute_dependencies()** 声明依赖的变量
- **_compute_thread_safety()** 判断是否可并行评估（缓存机制）
- **VariableOperations** 统一变量访问接口（LOCAL/SCOPE/GLOBAL）
- 系统自动处理取反和缓存

**参考文档**:
- [BaseCondition API](../../../../core/base/base_condition.gd)
- [变量操作（三层变量系统）](#变量操作三层变量系统)
- [完整条件模板](#完整条件模板)
- [测试规范](#测试规范)

---

**文档维护**: Fuse 开发团队
**最后更新**: 2026-06-17
