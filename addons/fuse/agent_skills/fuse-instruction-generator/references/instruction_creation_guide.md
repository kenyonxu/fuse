# Fuse 指令创建完整指南

> **目标**: 为开发者提供完整的 Fuse 指令创建指引，基于项目开发经验总结和最佳实践。

**适用对象**: Fuse 系统开发者、贡献者

**最后更新**: 2026-01-28

---

## 目录

1. [命名规范](#命名规范)
2. [图标规范](#图标规范)
3. [关键技术要点](#关键技术要点)
4. [完整指令模板](#完整指令模板)
5. [创建步骤](#创建步骤)
6. [最佳实践](#最佳实践)
7. [常见陷阱](#常见陷阱)
8. [测试规范](#测试规范)

---

## 命名规范

**重要**: 所有 Fuse 指令遵循以下命名规范，保持简洁一致。

### 文件命名

- **指令文件**: 使用 `snake_case`，**不添加** `_instruction` 后缀
  - ✅ 正确：`set_position.gd`, `for_loop.gd`, `if_else.gd`
  - ❌ 错误：`set_position_instruction.gd`, `for_loop_instruction.gd`

### 类命名

- **类名**: 使用 `PascalCase`，**不添加** `Instruction` 后缀
  - ✅ 正确：`class_name SetPosition`, `class_name ForLoop`, `class_name IfElse`
  - ❌ 错误：`class_name SetPositionInstruction`, `class_name ForLoopInstruction`

### 测试文件命名

- **测试脚本**: `test_<instruction_name>.gd`
  - 例如：`test_set_position.gd`, `test_for_loop.gd`
- **测试场景**: `test_<instruction_name>.tscn`
  - 例如：`test_set_position.tscn`, `test_for_loop.tscn`

### 统一性原则

- 文件名、类名、测试文件名保持一致的基础名称
- 避免冗余后缀（如 `_instruction`、`Instruction`）
- 保持简洁可读

**示例**:
```
指令文件：   set_position.gd
类名：       class_name SetPosition
测试脚本：   test_set_position.gd
测试场景：   test_set_position.tscn
```

---

## 图标规范

**图标选择原则**: 每个指令都应该配置图标，提升用户体验和可视化效果。

### 图标配置方式

**推荐：使用 Godot 内置图标**
```gdscript
metadata.builtin_icon = "Script"  # 使用 Godot 内置图标名称
```

**备选：使用自定义图标库**
```gdscript
metadata.custom_icon = "my_custom_icon"  # 使用导入的自定义图标
```

**向后兼容**
```gdscript
metadata.icon_name = "Script"  # 旧方式，仍然有效
metadata.icon = preload("res://icon.png")  # 直接指定纹理
```

### 内置图标命名参考

**常用图标名称**：
- **流程控制**: `Loop`, `Branch`, `Time`, `Wait`
- **变量操作**: `Array`, `New`, `View`, `Print`, `LocalVariable`, `GlobalVariable`
- **节点操作**: `Node`, `Edit`, `Call`, `Remove`, `ToolMove`, `Rotate`, `Scale`
- **调试**: `Debug`, `Search`
- **通用**: `Script`, `Play`, `Stop`, `Save`, `Load`, `Add`, `File`, `Folder`
- **变换**: `Rotate`, `Scale`, `Translation`, `Move`, `ToolMove`
- **音频**: `AudioStreamPlayer`, `Play`, `Stop`, `VolumeCurve`
- **场景**: `MakePacked`, `PackedScene`

### 图标配置步骤

在 `_get_instruction_metadata()` 中配置图标：

```gdscript
static func _get_instruction_metadata() -> InstructionMetadata:
    var metadata = InstructionMetadata.new()
    metadata.builtin_icon = "Script"  # 配置图标
    return metadata
```

---

## 关键技术要点

> **重要**: 基于项目开发经验总结的关键技术要点，后续指令开发必须遵循。

### 必需实现的抽象方法

所有指令必须实现以下方法，否则会产生编译错误：

```gdscript
## 1. 更新资源名称（必需）
func _update_resource_name():
    var parts = []
    # 构建描述性资源名称
    parts.append("操作名称")
    if not target_node.is_empty():
        parts.append("'%s'" % target_node)
    resource_name = " ".join(parts)

## 2. 验证参数（必需）
func validate() -> Array[String]:
    var errors = super.validate()
    # 添加自定义验证
    if target_node.is_empty():
        errors.append("目标节点路径不能为空")
    return errors

## 3. 获取描述（必需）
func get_description() -> String:
    return "指令描述字符串"
```

### 执行流程必需方法

```gdscript
func execute(context: ExecutionContext):
    # 必须首先调用
    _start_execution(context)

    # 验证逻辑
    if validation_failed:
        _log_error_localized("ERROR_KEY", {})
        set_error_localized("ERROR_KEY", FuseError.ErrorType.VALIDATION_ERROR, {})
        finished.emit()  # 同步指令直接发出信号
        return

    # 执行逻辑
    # ...

    # 同步指令完成
    _on_execution_completed()

    # 异步指令（需要定时器等）
    # 不调用 _on_execution_completed()，而是在回调中调用 finished.emit()
```

### 节点获取方法

**❌ 错误用法**:
```gdscript
var node := context.resolve_node(target_node)  # 方法不存在
var node := get_node(target_node)                 # 无法解析相对路径
```

**✅ 正确用法**:
```gdscript
var node := context.get_node(target_node)       # 正确，支持相对路径解析
```

### 异步操作（定时器）

**❌ 错误用法**:
```gdscript
_timer = get_tree().create_timer(delay)  # get_tree() 在指令中不可用
```

**✅ 正确用法**:
```gdscript
var scene_tree = Engine.get_main_loop()
if scene_tree:
    _timer = scene_tree.create_timer(delay)
    _timer.timeout.connect(_on_timer_timeout)
else:
    _log_error_localized("FUSE_ERROR_CANNOT_CREATE_TIMER", {})
    finished.emit()
```

### SceneTree 和当前场景访问

```gdscript
# 获取 SceneTree
var scene_tree = Engine.get_main_loop()
if scene_tree:
    # 获取当前场景
    var current_scene = scene_tree.current_scene
    # 创建定时器
    var timer = scene_tree.create_timer(duration)
```

### 全局变量保存

**❌ 错误用法**:
```gdscript
GlobalVariableAssistant.set_variable(var_name, value)  # 静态方法不存在
```

**✅ 正确用法**:
```gdscript
if context.global_variables:
    context.global_variables.set_variable(var_name, value)
else:
    _log_warning("全局变量管理器未初始化")
```

### AudioServer API（Godot 4.x）

**❌ 错误用法**:
```gdscript
var bus_names = AudioServer.get_bus_names()  # 不是静态方法
```

**✅ 正确用法**:
```gdscript
var bus_names = []
for i in range(AudioServer.get_bus_count()):
    bus_names.append(AudioServer.get_bus_name(i))
```

### Tween 创建（Resource 上下文）

**❌ 错误用法**:
```gdscript
var tween = create_tween()  # 在指令中不可用
```

**✅ 正确用法**:
```gdscript
var scene_tree = Engine.get_main_loop()
if not scene_tree:
    _log_error_localized("FUSE_ERROR_CANNOT_CREATE_TWEEN", {})
    # 回退到直接设置值
    return
var tween = scene_tree.create_tween()
```

### 错误处理和信号发送

```gdscript
# 同步指令错误处理
if error:
    _log_error_localized("ERROR_KEY", {"param": value})
    set_error_localized("ERROR_KEY", FuseError.ErrorType.RUNTIME_ERROR, {"param": value})
    finished.emit()  # 直接发出完成信号
    return

# 同步指令成功完成
_on_execution_completed()

# 异步指令（定时器回调）
func _on_timer_timeout():
    # 完成工作
    finished.emit()  # 在回调中发出完成信号
```

### 变量类型推断

```gdscript
# ✅ 明确类型避免推断问题
var node: Node = context.get_node(target_node)
var parent: Node = context.get_node(parent_path)

# ✅ 使用 := 让 Godot 推断（但需要初始化）
var node := context.get_node(target_node)

# ❌ 避免未初始化的变量
var node: Node  # 未初始化，类型推断可能失败
node = context.get_node(target_node)
```

### GDScript 2.0 三元运算符

**语法**:
```gdscript
# ✅ 正确（Python 风格）
value_if_true if condition else value_if_false

# ❌ 错误（C 风格）
condition ? value_if_true : value_if_false
```

---

## 完整指令模板

```gdscript
@tool
@icon("res://addons/fuse/icons/builtin/Script.png")
extends BaseInstruction
class_name TemplateInstruction

## 指令描述

# 参数定义
var target_node: NodePath = NodePath("")

## 获取指令元数据
static func _get_instruction_metadata() -> InstructionMetadata:
    var metadata = InstructionMetadata.new()
    metadata.name_key = "FUSE_INSTRUCTION_XXX_NAME"
    metadata.category_key = "FUSE_CATEGORY_XXX"
    metadata.description_key = "FUSE_INSTRUCTION_XXX_DESC"
    metadata.keywords = ["keyword1", "keyword2"]
    metadata.builtin_icon = "Script"
    return metadata

## 设置指令元数据
func _setup_metadata():
    pass

## 获取属性列表
##
## 必须使用 Array[Dictionary] 类型声明 properties，避免 Godot 4.7 触发
## "_get_property_list() should return Array[Dictionary]" 兼容性警告。
func _get_property_list() -> Array[Dictionary]:
    var properties: Array[Dictionary] = []

    # 分类
    properties.append({
        name = "Category",
        type = TYPE_NIL,
        hint = PROPERTY_HINT_NONE,
        usage = PROPERTY_USAGE_CATEGORY
    })

    # 属性
    properties.append({
        name = "target_node",
        type = TYPE_NODE_PATH,
        hint = PROPERTY_HINT_NONE,
        usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
    })

    return properties

## 更新资源名称（必需）
func _update_resource_name():
    var parts = []
    parts.append("操作名称")
    if not target_node.is_empty():
        parts.append("'%s'" % target_node)
    resource_name = " ".join(parts)

## 执行指令
func execute(context: ExecutionContext):
    _start_execution(context)

    # 验证
    if target_node.is_empty():
        _log_error_localized("FUSE_ERROR_TARGET_NODE_EMPTY", {})
        set_error_localized("FUSE_ERROR_TARGET_NODE_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
        finished.emit()
        return

    # 获取节点
    var node := context.get_node(target_node)
    if not node:
        _log_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", {"node": str(target_node)})
        set_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {"node": str(target_node)})
        finished.emit()
        return

    # 执行逻辑
    # ...

    # 同步完成
    _on_execution_completed()

## 验证参数（必需）
func validate() -> Array[String]:
    var errors = super.validate()

    if target_node.is_empty():
        errors.append("目标节点路径不能为空")

    return errors

## 获取描述（必需）
func get_description() -> String:
    return "操作 %s" % str(target_node)

## 动态属性设置（可选）
func _set(property: StringName, value: Variant) -> bool:
    if property == "some_property":
        set(property, value)
        notify_property_list_changed()
        _update_resource_name()
        return true
    return false

## 属性验证（可选）
func _validate_property(property: Dictionary) -> void:
    if property.name == "some_property" and some_condition:
        property.usage = PROPERTY_USAGE_NO_EDITOR
```

---

## 创建步骤

### Step 1: 创建指令类骨架

创建指令文件 `addons/fuse/instructions/<instruction_name>.gd`

### Step 2: 添加本地化翻译

在 `addons/fuse/localization/translations.csv` 添加：

```csv
key,zh_CN,en_US
FUSE_INSTRUCTION_XXX_NAME,指令名称,Instruction Name
FUSE_CATEGORY_XXX,分类名称,Category Name
FUSE_INSTRUCTION_XXX_DESC,指令描述,Instruction description
FUSE_ERROR_XXX_ERROR,错误消息,Error message
```

**注意**：
- 使用 `NAME` 后缀表示指令名称
- 使用 `DESC` 后缀表示指令描述
- 使用 `ERROR_XXX_ERROR` 表示错误消息
- 所有占位符使用 `{variable_name}` 格式

### Step 3: 创建测试场景

**Step 3.1: 创建测试场景文件**

创建 `tests/instructions/test_<instruction_name>.tscn`

**Step 3.2: 创建测试脚本**

创建 `tests/instructions/test_<instruction_name>.gd`

### Step 4: 测试验证

1. 在 Godot 中打开测试场景
2. 运行测试，确认所有测试用例通过
3. 检查编辑器中的 Inspector 显示是否正确
4. 验证本地化是否生效

---

## 最佳实践

### 1. 错误处理

**原则**: 所有错误都应该使用本地化错误消息。

```gdscript
# ✅ 好的做法
if target_node.is_empty():
    _log_error_localized("FUSE_ERROR_TARGET_NODE_EMPTY", {})
    set_error_localized("FUSE_ERROR_TARGET_NODE_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
    finished.emit()
    return

# ❌ 避免硬编码
if target_node.is_empty():
    _log_error("目标节点不能为空")  # 不推荐
    return
```

### 2. 资源清理

**原则**: 异步指令必须正确清理资源（定时器、Tween等）。

```gdscript
func _cleanup_resources() -> void:
    if _timer and is_instance_valid(_timer):
        if _timer.timeout.is_connected(_on_timer_timeout):
            _timer.timeout.disconnect(_on_timer_timeout)
        _timer = null
```

### 3. 类型注解

**原则**: 使用明确的类型注解，避免类型推断问题。

```gdscript
# ✅ 推荐
var node: Node = context.get_node(target_node)

# ✅ 也可以（使用 :=）
var node := context.get_node(target_node)

# ❌ 避免
var node: Node  # 未初始化
node = context.get_node(target_node)
```

### 4. 属性验证

**原则**: 使用 `_validate_property()` 动态控制属性可见性。

```gdscript
func _validate_property(property: Dictionary) -> void:
    # 条件性显示属性
    if property.name == "optional_param" and not show_optional:
        property.usage = PROPERTY_USAGE_NO_EDITOR
```

### 5. 属性刷新

**原则**: 修改影响其他属性的属性时，调用 `notify_property_list_changed()`。

```gdscript
func _set(property: StringName, value: Variant) -> bool:
    if property == "use_variable":
        set(property, value)
        notify_property_list_changed()  # 刷新属性列表
        return true
    return false
```

### 6. 代码组织

**原则**: 按功能组织代码，添加清晰的注释。

```gdscript
## 验证逻辑
func _validate_params(context: ExecutionContext) -> bool:
    # ...

## 执行核心逻辑
func _execute_core(context: ExecutionContext):
    # ...

## 清理资源
func _cleanup_resources():
    # ...
```

---

## 常见陷阱

### 陷阱 1: 在 Resource 中使用 Node 方法

**问题**:
```gdscript
var tree = get_tree()  # ❌ 在指令中不可用
```

**解决方案**:
```gdscript
var scene_tree = Engine.get_main_loop()
if scene_tree:
    # 使用 scene_tree
```

### 陷阱 2: 忘记调用 `_start_execution()`

**问题**:
```gdscript
func execute(context: ExecutionContext):
    # ❌ 忘记调用 _start_execution()
    # 执行逻辑...
```

**解决方案**:
```gdscript
func execute(context: ExecutionContext):
    _start_execution(context)  # ✅ 必须首先调用
    # 执行逻辑...
```

### 陷阱 3: 同步/异步混淆

**问题**:
```gdscript
func execute(context: ExecutionContext):
    # 同步完成
    _on_execution_completed()

    # 又发出完成信号 ❌ 冲突
    finished.emit()
```

**解决方案**:
- 同步指令: 只调用 `_on_execution_completed()`
- 异步指令: 只在回调中调用 `finished.emit()`

### 陷阱 4: 相对路径解析失败

**问题**:
```gdscript
var node = get_node(target_node)  # ❌ 无法正确解析相对路径
```

**解决方案**:
```gdscript
var node = context.get_node(target_node)  # ✅ 支持相对路径
```

### 陷阱 5: 全局变量访问

**问题**:
```gdscript
GlobalVariableAssistant.set_variable(name, value)  # ❌ 静态方法不存在
```

**解决方案**:
```gdscript
if context.global_variables:
    context.global_variables.set_variable(name, value)  # ✅ 正确
```

### 陷阱 6: 类型推断失败

**问题**:
```gdscript
var result: int
# 忘记初始化，后续赋值可能推断失败
```

**解决方案**:
```gdscript
var result: int = 0  # ✅ 初始化
var result := calculate()  # ✅ 使用 :=
```

### 陷阱 7: NaN 和 Infinity 验证

**问题**: 缺少边界值验证

**解决方案**:
```gdscript
func _is_valid_value(value: Vector3) -> bool:
    return not (is_nan(value.x) or is_inf(value.x) or
                is_nan(value.y) or is_inf(value.y) or
                is_nan(value.z) or is_inf(value.z))
```

### 陷阱 8: Godot 4.x API 变化

**问题**: 使用 Godot 3.x API

**解决方案**:
- AudioServer: 使用 `get_bus_count()` + `get_bus_name(i)`
- Tween: 使用 `scene_tree.create_tween()`
- SceneTree: 使用 `Engine.get_main_loop()`

---

## 测试规范

### 测试文件结构

```gdscript
extends Node3D  # 或 Node，根据指令类型选择

## InstructionName 指令测试

func _ready():
    print("=== Testing InstructionName ===")
    test_case_1()
    test_case_2()
    test_case_3()
    print("=== All InstructionName tests passed! ===")
```

### 测试用例设计

**必需的测试**:
1. **基本功能测试** - 验证指令正常工作
2. **边界值测试** - 测试 NaN、Infinity、大数值
3. **错误处理测试** - 验证错误情况被正确处理
4. **2D/3D 兼容性** - 如果适用，测试两种节点类型
5. **变量输入测试** - 测试从变量读取参数

**测试示例**:
```gdscript
func test_basic_functionality():
    var instruction = InstructionName.new()
    instruction.param = value

    var context = ExecutionContext.new()
    add_child(context)

    instruction.execute(context)
    await get_tree().process_frame

    assert(condition, "Should pass")
```

### 测试断言

```gdscript
# 验证结果
assert(actual == expected, "Error message")
assert(context.had_error() == should_error, "Should have error")
assert(abs(actual - expected) < 0.01, "Should be approximately equal")
```

---

## 快速参考

### 常用代码片段

#### 节点操作
```gdscript
var node := context.get_node(target_node)
if not node:
    _log_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", {"node": str(target_node)})
    set_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {"node": str(target_node)})
    finished.emit()
    return
```

#### SceneTree 操作
```gdscript
var scene_tree = Engine.get_main_loop()
if not scene_tree:
    _log_error_localized("FUSE_ERROR_CANNOT_GET_SCENETREE", {})
    finished.emit()
    return

var current_scene = scene_tree.current_scene
var timer = scene_tree.create_timer(duration)
```

#### 音频操作
```gdscript
var bus_names = []
for i in range(AudioServer.get_bus_count()):
    bus_names.append(AudioServer.get_bus_name(i))
```

#### 变量操作
```gdscript
var value = context.get_variable(var_name)
if value == null:
    _log_error_localized("FUSE_ERROR_VAR_NOT_FOUND", {"variable": var_name})
    return

if context.global_variables:
    context.global_variables.set_variable(var_name, new_value)
```

### 常用错误键

已定义的本地化错误键（参考 `translations.csv`）：
- `FUSE_ERROR_TARGET_NODE_EMPTY` - 目标节点为空
- `FUSE_ERROR_TARGET_NODE_NOT_FOUND` - 目标节点未找到
- `FUSE_ERROR_VAR_NAME_EMPTY` - 变量名为空
- `FUSE_ERROR_VAR_NOT_FOUND` - 变量未找到
- `FUSE_ERROR_NODE_TYPE_INVALID` - 节点类型无效
- `FUSE_ERROR_INVALID_POSITION` - 位置值无效
- `FUSE_ERROR_INVALID_ROTATION` - 旋转值无效
- `FUSE_ERROR_INVALID_SCALE` - 缩放值无效
- `FUSE_ERROR_CANNOT_GET_SCENETREE` - 无法获取 SceneTree
- `FUSE_ERROR_CANNOT_GET_CURRENT_SCENE` - 无法获取当前场景
- `FUSE_ERROR_CANNOT_CREATE_TIMER` - 无法创建定时器
- `FUSE_ERROR_CANNOT_CREATE_TWEEN` - 无法创建 Tween

---

## 总结

创建 Fuse 指令的关键要点：

1. ✅ **遵循命名规范** - 简洁、一致、无冗余
2. ✅ **实现必需方法** - `_update_resource_name()`, `validate()`, `get_description()`
3. ✅ **使用正确的 API** - `context.get_node()`, `Engine.get_main_loop()`
4. ✅ **本地化错误消息** - 使用 `_log_error_localized()`
5. ✅ **正确处理同步/异步** - 同步用 `_on_execution_completed()`, 异步用 `finished.emit()`
6. ✅ **添加完整测试** - 基本功能 + 边界情况
7. ✅ **清理资源** - 异步指令必须清理定时器和 Tween

---

**文档维护**: Fuse 开发团队
**最后更新**: 2026-01-28
