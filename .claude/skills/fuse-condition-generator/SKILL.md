---
name: fuse-condition-generator
description: 专门用于创建 Fuse 可视化编程系统条件（Condition）的开发技能。当需要创建新的 Fuse 条件时使用此技能，包括：添加变量检查条件、创建节点状态条件、实现数值比较条件、开发复合逻辑条件等。提供完整的条件创建工作流、代码模板、最佳实践参考和常见错误避坑指南。
---

# Fuse 条件生成器

专门用于创建 Fuse 可视化编程系统条件（Condition）的开发技能。

## 快速开始

创建新条件时，按照以下步骤操作：

1. **确定条件类型和功能**
   - 明确条件要检查的内容（变量值、节点状态、数值范围等）
   - 确定条件的分类（Variable、Node、Math、Logic 等）

2. **选择合适的模板**
   - 简单条件：参考 [简单条件模板](templates/simple_condition_template.gd)
   - 变量比较条件：参考 [变量比较条件模板](templates/variable_condition_template.gd)

3. **实现条件代码**
   - 使用模板创建条件文件
   - 实现必需方法：`_update_resource_name()`, `_evaluate_condition()`, `_compute_dependencies()`, `validate()`
   - 添加本地化翻译

4. **创建测试**
   - 创建测试场景和脚本
   - 验证条件判断逻辑

5. **验证和调试**
   - 在编辑器中测试条件
   - 检查 Inspector 显示
   - 验证本地化

## 条件类型参考

| 类型 | 说明 | 模板 |
|------|------|------|
| **变量检查** | 检查变量值、比较变量 | variable_condition_template |
| **节点检查** | 检查节点存在、属性值 | simple_condition_template |
| **数值比较** | 比较数值大小、范围 | variable_condition_template |
| **逻辑判断** | AND、OR、NOT 复合条件 | 待实现 |

## 关键开发规范

### 命名规范

- **文件名**：使用 `check_` 或 `compare_` 前缀 + snake_case
  - ✅ `check_node_exists.gd`, `compare_variable.gd`
  - ❌ `node_exists_condition.gd`, `variable_comparison.gd`

- **类名**：使用 `Check` 或 `Compare` 前缀 + PascalCase
  - ✅ `class_name CheckNodeExists`, `class_name CompareVariable`
  - ❌ `class_name NodeExistsCondition`

### 必需实现的方法

所有条件必须实现以下方法（`@abstract` 标记）：

```gdscript
## 更新资源名称（必需，@abstract）
func _update_resource_name():
    # 构建描述性资源名称
    pass

## 评估条件（必需，@abstract）
func _evaluate_condition(context: ExecutionContext) -> bool:
    # 返回条件是否满足
    return true_or_false

## 声明变量读写模式（必需，若条件含变量属性如 variable_name）
## 供静态分析（analyze_problems）精确判断变量是 read/write
## 条件通常只读变量 → 声明 read，避免被误判为 writer → 竞态误报
func get_variable_modes() -> Array[Dictionary]:
    # 示例：检查变量值（read-only）
    return [{"name": "variable_name", "mode": "read"}]

## 计算依赖（必需，@abstract）
func _compute_dependencies() -> Array[String]:
    # 返回依赖的变量名列表，无依赖返回 []
    return []

## 验证参数（推荐）
func validate() -> Array[String]:
    var errors = super.validate()
    return errors
```

### 条件评估模式

**简单条件**（使用本地化错误）：
```gdscript
func _evaluate_condition(context: ExecutionContext) -> bool:
    # 验证参数
    if parameter.is_empty():
        _log_error_localized("FUSE_ERROR_CONDITION_PARAM_EMPTY", {"param": "parameter"})
        _create_fuse_error_localized("FUSE_ERROR_CONDITION_PARAM_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {"param": "parameter"})
        return false

    # 执行检查
    var result = perform_check(context)

    # 记录日志
    _log_debug("条件检查结果: %s" % ("true" if result else "false"))

    return result
```

**变量比较条件**（使用 VariableOperations）：
```gdscript
func _evaluate_condition(context: ExecutionContext) -> bool:
    # 获取变量值（使用 VariableOperations 统一访问三层作用域）
    var actual_value = VariableOperations.get_variable(context, variable_name, variable_scope, null)

    # 检查变量是否存在（区分"不存在"和"值为null"）
    if actual_value == null and not VariableOperations.has_variable(context, variable_name, variable_scope):
        _log_error_localized("FUSE_ERROR_VAR_NOT_FOUND", {"variable": variable_name})
        _create_fuse_error_localized("FUSE_ERROR_VAR_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {"variable": variable_name})
        return false

    # 执行比较
    return _perform_comparison(actual_value, expected_value)
```

### 变量作用域

条件使用 `BaseVariable.VariableScope` 枚举（LOCAL/SCOPE/GLOBAL）：
```gdscript
@export var variable_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
    set(value):
        variable_scope = value
        _update_resource_name()
```

### 依赖计算

`_compute_dependencies()` 告诉系统哪些变量影响此条件，用于缓存失效：
```gdscript
func _compute_dependencies() -> Array[String]:
    var deps: Array[String] = []
    if not variable_name.is_empty():
        deps.append(variable_name)
    return deps
```

## 常见错误参考

| 错误 | 正确做法 |
|------|----------|
| 返回非布尔值 | `_evaluate_condition()` 必须返回 `bool` |
| 使用 `get_node()` | 使用 `context.get_node()`（支持相对路径） |
| `context.get_variable()` 直接访问 | 使用 `VariableOperations.get_variable()` |
| 忘记错误处理 | 验证失败用 `_create_fuse_error_localized()` |
| 缺少依赖计算 | 实现 `_compute_dependencies()` 返回依赖变量列表 |
| 硬编码中文错误 | 使用 `_log_error_localized()` + 翻译键 |

## 参考资料详解

### 详细开发指南
- [完整条件创建指南](references/condition_creation_guide.md) - 详细的开发步骤、最佳实践、常见陷阱

### 模板文件
- [简单条件模板](templates/simple_condition_template.gd) - 简单检查条件的完整模板
- [变量比较条件模板](templates/variable_condition_template.gd) - 变量比较条件的完整模板（含 VariableOperations）

## 工作流程

### 1. 规划条件
- 确定要检查的条件
- 选择合适的条件分类
- 确定返回值的含义

### 2. 创建代码
- 从模板开始
- 实现必需方法
- 添加参数验证
- 实现条件检查逻辑

### 3. 添加本地化
- 在 `addons/fuse/localization/translations.csv` 添加键值对
- 使用 `_log_*_localized()` 记录日志
- 使用 `_create_fuse_error_localized()` 创建错误
- 翻译键前缀：`FUSE_CONDITION_*`, `FUSE_ERROR_*`

### 4. 创建测试
- 创建测试场景
- 编写测试脚本
- 测试条件判断逻辑

### 5. 验证和调试
- 在编辑器中检查 Inspector 显示
- 运行测试场景
- 验证错误处理和本地化

## 提示和技巧

- **条件评估**：`_evaluate_condition()` 必须返回布尔值，系统自动处理 `negate_result`
  ```gdscript
  func _evaluate_condition(context: ExecutionContext) -> bool:
      return condition_is_met  # 系统会自动应用 negate_result
  ```

- **变量访问**：使用 VariableOperations 统一访问三层作用域
  ```gdscript
  var value = VariableOperations.get_variable(context, var_name, var_scope, null)
  if value == null and not VariableOperations.has_variable(context, var_name, var_scope):
      # 变量不存在（不是值为 null）
      return false
  ```

- **依赖计算**：告诉系统哪些变量影响此条件（用于智能缓存失效）
  ```gdscript
  func _compute_dependencies() -> Array[String]:
      return ["variable1", "variable2"]
  ```

- **元数据配置**：
  ```gdscript
  static func _get_condition_metadata() -> ConditionMetadata:
      var metadata = ConditionMetadata.new()
      metadata.name_key = "FUSE_CONDITION_XXX_NAME"
      metadata.category_key = "FUSE_CATEGORY_XXX"
      metadata.description_key = "FUSE_CONDITION_XXX_DESC"
      metadata.keywords = ["keyword1", "keyword2"]
      metadata.builtin_icon = "NodePath"
      return metadata
  ```

## 验证清单

创建条件后，确认以下各项：

- [ ] 文件命名符合规范（`check_` 或 `compare_` 前缀）
- [ ] 类命名符合规范（`Check` 或 `Compare` 前缀）
- [ ] 实现了所有 `@abstract` 方法
- [ ] `_evaluate_condition()` 返回布尔值
- [ ] 变量访问使用 `VariableOperations`（非 `context.get_variable()`）
- [ ] 实现了 `_compute_dependencies()` 返回依赖变量
- [ ] 错误使用 `_create_fuse_error_localized()`（非硬编码中文）
- [ ] 添加了本地化翻译（`FUSE_*` 前缀）
- [ ] 创建了测试场景和脚本
- [ ] 测试通过
- [ ] 在编辑器中验证 Inspector 显示
- [ ] 配置了图标

## 获取帮助

- 查看完整指南：[references/condition_creation_guide.md](references/condition_creation_guide.md)
- 使用模板快速开始：[templates/](templates/)
