# Fuse 条件创建完整指南

> **目标**: 为开发者提供完整的 Fuse 条件创建指引，基于项目开发经验总结和最佳实践。

**适用对象**: Fuse 系统开发者、贡献者

**最后更新**: 2026-01-29

---

## 目录

1. [命名规范](#命名规范)
2. [图标规范](#图标规范)
3. [条件评估核心](#条件评估核心)
4. [完整条件模板](#完整条件模板)
5. [创建步骤](#创建步骤)
6. [最佳实践](#最佳实践)
7. [常见陷阱](#常见陷阱)
8. [测试规范](#测试规范)

---

## 命名规范

**重要**: 所有 Fuse 条件遵循以下命名规范，保持简洁一致。

### 文件命名

- **条件文件**: 使用 `check_` 或 `compare_` 前缀 + snake_case
  - ✅ 正确：`check_node_exists.gd`, `compare_variable.gd`, `check_node_property.gd`
  - ❌ 错误：`node_exists_condition.gd`, `variable_comparison.gd`

### 类命名

- **类名**: 使用 `Check` 或 `Compare` 前缀 + PascalCase
  - ✅ 正确：`class_name CheckNodeExists`, `class_name CompareVariable`
  - ❌ 错误：`class_name NodeExistsCondition`, `class_name VariableComparison`

### 测试文件命名

- **测试脚本**: `test_<condition_name>.gd`
  - 例如：`test_check_node_exists.gd`, `test_compare_variable.gd`
- **测试场景**: `test_<condition_name>.tscn`
  - 例如：`test_check_node_exists.tscn`

### 统一性原则

- 文件名、类名、测试文件名保持一致的基础名称
- 使用描述性名称表示检查什么
- 保持简洁可读

**示例**:
```
条件文件：   check_node_exists.gd
类名：       class_name CheckNodeExists
测试脚本：   test_check_node_exists.gd
测试场景：   test_check_node_exists.tscn
```

---

## 图标规范

**图标选择原则**: 每个条件都应该配置图标，提升用户体验。

### 常用图标命名参考

**节点条件**:
- `NodePath` - 节点路径
- `Node` - 节点检查
- `ToolNodeInstance` - 节点实例

**变量条件**:
- `Array` - 数组变量
- `LocalVariable` - 局部变量
- `GlobalVariable` - 全局变量

**比较条件**:
- `Math` - 数学比较
- `Compare` - 比较运算

**通用图标**:
- `ArrowRight` - 条件判断
- `Check` - 检查
- `Bool` - 布尔值

### 图标配置步骤

在 `_get_condition_metadata()` 中配置图标：

```gdscript
static func _get_condition_metadata() -> ConditionMetadata:
    var metadata = ConditionMetadata.new()
    metadata.builtin_icon = "NodePath"  # 配置图标
    return metadata
```

---

## 条件评估核心

条件的核心是 `_evaluate_condition()` 方法，必须返回布尔值。

### 基本模式

```gdscript
func _evaluate_condition(context: ExecutionContext) -> bool:
    # 1. 验证参数
    if parameter.is_empty():
        _create_fuse_error("参数不能为空", FuseError.ErrorType.VALIDATION_ERROR)
        return false

    # 2. 执行检查
    var result = perform_check()

    # 3. 记录日志
    _log_debug("条件检查结果: %s" % ("true" if result else "false"))

    # 4. 返回布尔值
    return result
```

### 变量检查模式

```gdscript
func _evaluate_condition(context: ExecutionContext) -> bool:
    # 1. 验证变量名
    if variable_name.is_empty():
        _create_fuse_error("变量名称不能为空", FuseError.ErrorType.VALIDATION_ERROR)
        return false

    # 2. 获取变量值
    var value = context.get_variable(variable_name)

    # 3. 执行比较
    var result = (value == expected_value)

    # 4. 返回结果
    return result
```

### 节点检查模式

```gdscript
func _evaluate_condition(context: ExecutionContext) -> bool:
    # 1. 验证节点路径
    if node_path.is_empty():
        _create_fuse_error("节点路径不能为空", FuseError.ErrorType.VALIDATION_ERROR)
        return false

    # 2. 获取节点
    var node = context.get_node(node_path)

    # 3. 检查节点
    var result = node != null

    # 4. 返回结果
    return result
```

---

## 完整条件模板

```gdscript
@tool
@icon("res://addons/fuse/icons/builtin/NodePath.png")
extends BaseCondition
class_name CheckConditionTemplate

## 条件描述（简短说明条件的功能）

# =============================================
# 参数定义
# =============================================

## 检查参数
@export_group("Condition Check")
@export var check_parameter: String = "":
	set(value):
		check_parameter = value
		_update_resource_name()

# =============================================
# 元数据方法
# =============================================

## 获取条件元数据（必需）
static func _get_condition_metadata() -> ConditionMetadata:
	var metadata = ConditionMetadata.new()
	metadata.name_key = "FUSE_CONDITION_XXX_NAME"
	metadata.category_key = "FUSE_CATEGORY_XXX"
	metadata.description_key = "FUSE_CONDITION_XXX_DESC"
	metadata.keywords = ["keyword1", "keyword2", "keyword3"]
	metadata.builtin_icon = "NodePath"
	return metadata

# =============================================
# 资源名称和描述
# =============================================

## 更新资源名称（必需）
func _update_resource_name():
	var parts = []

	parts.append("条件检查")

	if not check_parameter.is_empty():
		parts.append("'%s'" % check_parameter)
	else:
		parts.append("(未设置)")

	resource_name = " ".join(parts)

## 获取条件类型
func get_condition_type() -> String:
	return "condition_type"

## 获取条件分类
func get_condition_category() -> String:
	return "category_name"

## 获取条件描述
func get_description() -> String:
	if check_parameter.is_empty():
		return "条件检查 (未设置参数)"

	return "条件检查: %s" % check_parameter

# =============================================
# 条件评估
# =============================================

## 评估条件（必需）
func _evaluate_condition(context: ExecutionContext) -> bool:
	# ============================================
	# 1. 验证参数
	# ============================================

	if check_parameter.is_empty():
		_log_error("检查参数不能为空")
		_create_fuse_error_localized("FUSE_ERROR_PARAMETER_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
		return false

	# ============================================
	# 2. 执行检查逻辑
	# ============================================

	var result = perform_check(context)

	# ============================================
	# 3. 记录日志
	# ============================================

	_log_debug("条件检查结果: %s => %s" % [check_parameter, "true" if result else "false"])

	# ============================================
	# 4. 返回布尔值
	# ============================================

	return result

# =============================================
# 辅助方法
# =============================================

## 执行检查逻辑（示例）
func perform_check(context: ExecutionContext) -> bool:
	# 在这里实现具体的检查逻辑
	# 返回 true 表示条件满足
	# 返回 false 表示条件不满足
	return true

## 计算依赖
func _compute_dependencies() -> Array[String]:
	# 如果条件依赖变量，返回变量名列表
	# 如果不依赖变量，返回空数组
	return []

## 获取参数
func get_parameters() -> Dictionary:
	return {
		"check_parameter": check_parameter
	}

## 设置参数
func set_parameters(parameters: Dictionary):
	if parameters.has("check_parameter"):
		check_parameter = parameters["check_parameter"]

# =============================================
# 验证
# =============================================

## 验证条件配置（必需）
func validate() -> Array[String]:
	var errors: Array[String] = super.validate()

	if check_parameter.is_empty():
		errors.append("检查参数不能为空")

	return errors
```

---

## 创建步骤

### Step 1: 创建条件类骨架

创建条件文件 `addons/fuse/conditions/<category>/check_<condition_name>.gd`

### Step 2: 添加本地化翻译

在 `addons/fuse/localization/translations.csv` 添加：

```csv
key,zh_CN,en_US
FUSE_CONDITION_XXX_NAME,条件名称,Condition Name
FUSE_CATEGORY_XXX,分类名称,Category Name
FUSE_CONDITION_XXX_DESC,条件描述,Condition description
```

### Step 3: 创建测试场景

**Step 3.1: 创建测试场景文件**

创建 `addons/fuse/tests/conditions/test_check_<condition_name>.tscn`

**Step 3.2: 创建测试脚本**

创建 `addons/fuse/tests/conditions/test_check_<condition_name>.gd`

### Step 4: 测试验证

1. 在 Godot 中打开测试场景
2. 运行测试，确认条件判断正确
3. 检查编辑器中的 Inspector 显示是否正确
4. 验证本地化

---

## 最佳实践

### 1. 布尔返回值

**原则**: `_evaluate_condition()` 必须始终返回布尔值。

```gdscript
# ✅ 好的做法
func _evaluate_condition(context: ExecutionContext) -> bool:
    var result = perform_check()
    return bool(result)  # 确保返回布尔值

# ❌ 避免返回其他类型
func _evaluate_condition(context: ExecutionContext) -> bool:
    return perform_check()  # 可能返回非布尔值
```

### 2. 错误处理

**原则**: 验证失败时创建错误并返回 `false`。

```gdscript
# ✅ 好的做法
if parameter.is_empty():
    _create_fuse_error_localized("FUSE_ERROR_PARAMETER_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
    return false

# ❌ 避免忽略错误
if parameter.is_empty():
    return false  # 没有记录错误
```

### 3. 日志记录

**原则**: 使用本地化日志记录器，记录关键检查步骤。

```gdscript
# 检查前
_log_debug("开始检查条件: %s" % condition_name)

# 检查结果
_log_debug("条件检查结果: %s => %s" % [param, "true" if result else "false"])
```

### 4. 依赖计算

**原则**: 如果条件依赖变量，实现 `_compute_dependencies()`。

```gdscript
func _compute_dependencies() -> Array[String]:
    var dependencies = []

    if not variable_name.is_empty():
        dependencies.append(variable_name)

    return dependencies
```

### 5. 参数验证

**原则**: 在 `validate()` 中验证所有必需参数。

```gdscript
func validate() -> Array[String]:
    var errors = super.validate()

    if required_parameter.is_empty():
        errors.append("必需参数不能为空")

    return errors
```

---

## 常见陷阱

### 陷阱 1: 返回非布尔值

**问题**:
```gdscript
func _evaluate_condition(context: ExecutionContext) -> bool:
    return some_value  # ❌ 可能不是布尔值
```

**解决方案**:
```gdscript
func _evaluate_condition(context: ExecutionContext) -> bool:
    return bool(some_value)  # ✅ 确保是布尔值
```

### 陷阱 2: 忘记错误处理

**问题**:
```gdscript
func _evaluate_condition(context: ExecutionContext) -> bool:
    if parameter.is_empty():
        return false  # ❌ 没有记录错误
```

**解决方案**:
```gdscript
func _evaluate_condition(context: ExecutionContext) -> bool:
    if parameter.is_empty():
        _create_fuse_error_localized("FUSE_ERROR_PARAMETER_EMPTY", ...)
        return false
```

### 陷阱 3: 使用 get_node()

**问题**:
```gdscript
var node = get_node(node_path)  # ❌ 不支持相对路径
```

**解决方案**:
```gdscript
var node = context.get_node(node_path)  # ✅ 支持相对路径
```

---

## 测试规范

### 测试用例设计

**必需的测试**:
1. **条件满足测试** - 验证条件满足时返回 `true`
2. **条件不满足测试** - 验证条件不满足时返回 `false`
3. **参数错误测试** - 验证错误参数被正确处理
4. **边界值测试** - 测试边界情况

**测试示例**:
```gdscript
func test_condition_met():
    var condition = CheckConditionTemplate.new()
    condition.check_parameter = "valid_value"

    var context = ExecutionContext.new()
    var result = condition.evaluate(context)

    assert(result == true, "Condition should be met")

func test_condition_not_met():
    var condition = CheckConditionTemplate.new()
    condition.check_parameter = "invalid_value"

    var context = ExecutionContext.new()
    var result = condition.evaluate(context)

    assert(result == false, "Condition should not be met")

func test_parameter_error():
    var condition = CheckConditionTemplate.new()
    condition.check_parameter = ""

    var context = ExecutionContext.new()
    var result = condition.evaluate(context)

    assert(result == false, "Condition should return false on error")
    assert(condition.had_error(), "Condition should have error")
```

---

## 快速参考

### 常用代码片段

#### 布尔转换
```gdscript
var bool_result = bool(value)
```

#### 变量检查
```gdscript
var value = context.get_variable(variable_name)
if value == null:
    _create_fuse_error("变量不存在", ...)
    return false
```

#### 节点检查
```gdscript
var node = context.get_node(node_path)
var exists = node != null
```

#### 数值比较
```gdscript
var result = (actual_value > expected_value)
```

---

## 总结

创建 Fuse 条件的关键要点：

1. ✅ **遵循命名规范** - `check_` 或 `compare_` 前缀
2. ✅ **实现必需方法** - `_evaluate_condition()`, `_update_resource_name()`, `validate()`
3. ✅ **返回布尔值** - `_evaluate_condition()` 必须返回 `bool`
4. ✅ **正确处理错误** - 使用 `_create_fuse_error_localized()`
5. ✅ **添加完整测试** - 满足/不满足/错误情况
6. ✅ **计算依赖** - 实现 `_compute_dependencies()`

---

**文档维护**: Fuse 开发团队
**最后更新**: 2026-01-29
