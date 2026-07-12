---
name: fuse-instruction-generator
description: 专门用于创建 Fuse 可视化编程系统指令（Instruction）的开发技能。当需要创建新的 Fuse 指令时使用此技能，包括：添加节点操作指令、创建流程控制指令、实现变量操作指令、开发系统功能指令等。提供完整的指令创建工作流、代码模板、最佳实践参考和常见错误避坑指南。
---

# Fuse 指令生成器

专门用于创建 Fuse 可视化编程系统指令（Instruction）的开发技能。

## 快速开始

创建新指令时，按照以下步骤操作：

1. **确定指令类型和功能**
   - 明确指令要实现的功能
   - 确定指令的分类（Transform、Variables、Flow Control、Audio、Animation 等）

2. **选择合适的模板**
   - 简单同步指令：参考 [同步指令模板](templates/sync_instruction_template.gd)
   - 异步指令（定时器/Tween）：参考 [异步指令模板](templates/async_instruction_template.gd)
   - 特殊类型指令：查看 [指令分类参考](references/instruction_categories.md)

3. **实现指令代码**
   - 使用模板创建指令文件
   - 实现必需方法（`execute()`, `validate()`, `get_description()`, `_update_resource_name()`）
   - 添加本地化翻译

4. **创建测试**
   - 创建测试场景和脚本
   - 验证功能和错误处理

5. **验证和调试**
   - 在编辑器中测试指令
   - 检查 Inspector 显示
   - 验证本地化

## 指令类型参考

| 类型 | 说明 | 模板 |
|------|------|------|
| **节点操作** | 移动、旋转、缩放、启用/禁用节点 | sync_instruction_template |
| **变量操作** | 创建、设置、读取变量（三层作用域） | sync + VariableOperations |
| **流程控制** | 循环、条件、等待 | async_instruction_template |
| **动画控制** | 播放、停止、混合动画 | sync/async 视情况 |
| **音频控制** | 播放音效、音乐，控制音量 | async_instruction_template |
| **场景管理** | 加载、切换、重载场景 | async_instruction_template |

## 关键开发规范

### 命名规范

- **文件名**：使用 snake_case，**不加** `_instruction` 后缀
  - ✅ `set_position.gd`, `for_loop.gd`
  - ❌ `set_position_instruction.gd`, `for_loop_instruction.gd`

- **类名**：使用 PascalCase，**不加** `Instruction` 后缀
  - ✅ `class_name SetPosition`, `class_name ForLoop`
  - ❌ `class_name SetPositionInstruction`

### 必需实现的方法

所有指令必须实现以下方法：

```gdscript
## 更新资源名称（必需）
func _update_resource_name():
    # 构建描述性资源名称
    pass

## 验证参数（必需）
func validate() -> Array[String]:
    var errors = super.validate()
    # 添加自定义验证
    return errors

## 声明变量读写模式（必需，若指令含变量属性如 *_variable）
## 供静态分析（analyze_problems）精确判断变量是 read/write/read_write
## 未声明 → fallback _infer_variable_mode（启发式，可能误判 read-only 为 writer → 竞态误报）
func get_variable_modes() -> Array[Dictionary]:
    # 示例：读变量 + 写结果
    return [
        {"name": "variable_name", "mode": "read"},  # 读取的变量
        {"name": "save_to_variable", "mode": "write"},  # 写入的结果变量
    ]

## 获取描述（必需）
func get_description() -> String:
    return "指令描述字符串"
```

### 执行流程模式

**同步指令**：
```gdscript
func execute(context: ExecutionContext):
    _start_execution(context)

    # 验证和执行逻辑...
    if error:
        _log_error_localized("FUSE_ERROR_*", {})
        set_error_localized("FUSE_ERROR_*", FuseError.ErrorType.VALIDATION_ERROR, {})
        finished.emit()
        return

    # 同步完成
    _on_execution_completed()
```

**异步指令**（定时器、Tween 等）：
```gdscript
func execute(context: ExecutionContext):
    _start_execution(context)

    # 创建定时器
    var scene_tree = Engine.get_main_loop()
    _timer = scene_tree.create_timer(delay)
    _timer.timeout.connect(_on_timer_timeout)
    # 不调用 _on_execution_completed()，等待回调

func _on_timer_timeout():
    # 完成工作
    finished.emit()
```

### 执行模式（ExecutionMode）

`BaseInstruction` 支持三种执行模式，通过 `@export var execution_mode` 控制：

```gdscript
enum ExecutionMode {
    AUTO_DETECT,   # 自动检测（推荐）- 通过源码分析判断同步/异步
    FORCE_ASYNC,   # 强制异步 - 适用于使用回调机制的指令
    FORCE_SYNC     # 强制同步 - 适用于纯计算、无外部依赖的指令
}
```

**⚠️ 关键：异步指令必须设置执行模式**。如果指令使用回调机制（`timer.timeout.connect()`、`tween.finished.connect()` 等），必须设置 `execution_mode = ExecutionMode.FORCE_ASYNC`：

```gdscript
@export var execution_mode: ExecutionMode = ExecutionMode.FORCE_ASYNC
```

不需要 `_init()` 中手动设置 `_is_synchronous_hint`（旧方式）。

### 完成信号时机（CompletionSignalTiming）

```gdscript
enum CompletionSignalTiming {
    ON_START,   # 执行开始时发信号（纯通知/日志指令）
    ON_FINISH   # 执行完成时发信号（默认，正常指令）
}
```

### 三层变量系统

Fuse 使用 `VariableOperations` 工具类统一访问三层变量（LOCAL/SCOPE/GLOBAL）：

```gdscript
# 读取变量（区分"不存在"和"值为null"）
var value = VariableOperations.get_variable(context, var_name, var_scope, default_value)
if value == null and not VariableOperations.has_variable(context, var_name, var_scope):
    _log_error_localized("FUSE_ERROR_VAR_NOT_FOUND", {"variable": var_name})
    finished.emit()
    return

# 设置变量
VariableOperations.set_variable(context, var_name, var_scope, new_value)

# 作用域转换显示
var scope_str = VariableScopeUtils.enum_to_string(var_scope).to_upper()
```

**作用域类型**：
```gdscript
@export var var_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL
# LOCAL (0) - 单次执行期间有效
# SCOPE (1) - 节点生命周期内有效（需要 ScopeVariableManager）
# GLOBAL (2) - 游戏运行时全局共享
```

### 指令取消和超时

```gdscript
# 取消正在执行的指令
func cancel() -> void:
    if execution_status == ExecutionStatus.RUNNING:
        execution_status = ExecutionStatus.CANCELLED
        error_message = "指令被取消"
        _cleanup_timeout_timer()
        finished.emit()

# 设置超时（0 表示禁用）
func set_timeout(timeout_seconds: float)
func get_timeout() -> float
func has_timeout() -> bool
```

## 常见错误参考

| 错误 | 正确做法 |
|------|----------|
| 使用 `get_node()` | 使用 `context.get_node()`（支持相对路径） |
| 使用 `get_tree()` | 使用 `Engine.get_main_loop()` |
| `context.get_variable()` 直接访问 | 使用 `VariableOperations.get_variable()` |
| `context.global_variables.set_variable()` | 使用 `VariableOperations.set_variable()` |
| 布尔值 `is_global` 表示作用域 | 使用 `BaseVariable.VariableScope` 枚举 |
| AudioServer 获取 bus 名称 | 使用循环 `for i in get_bus_count(): get_bus_name(i)` |
| 手动 match 转换作用域为字符串 | 使用 `VariableScopeUtils.enum_to_string()` |

## 运行时实例模式（RuntimeInstructionInstance）

**何时必须使用**：
- 异步指令（使用定时器、Tween 等）
- 需要暂停/恢复功能的指令
- 可能被并发执行多次的指令

**核心方法**：

```gdscript
## 声明运行时状态
func get_default_runtime_state() -> Dictionary:
    var state = super.get_default_runtime_state()
    state["timer"] = null
    state["is_running"] = false
    state["pause_remaining_time"] = 0.0
    state["current_timer_callback"] = null
    return state

## 使用运行时实例执行
func execute_with_runtime_instance(runtime_instance: RuntimeInstructionInstance) -> bool:
    _start_execution(runtime_instance.execution_context)
    var state = runtime_instance.runtime_state
    # ... 使用 state 而非成员变量存储状态 ...
    return false  # 异步返回 false，同步返回 true

## 使用闭包创建回调（避免 bind 泄漏）
func _create_timer_callback(runtime_instance: RuntimeInstructionInstance) -> Callable:
    var callback = func():
        _on_runtime_timer_timeout(runtime_instance)
    return callback

## 回调开头检查实例有效性
func _on_runtime_timer_timeout(runtime_instance: RuntimeInstructionInstance):
    if not runtime_instance or runtime_instance.is_completed():
        return
    state["timer"] = null
    runtime_instance._complete_execution()  # 不要手动 finished.emit()

## 暂停/恢复（可选）
func on_runtime_pause(runtime_instance: RuntimeInstructionInstance) -> void: ...
func on_runtime_resume(runtime_instance: RuntimeInstructionInstance) -> void: ...
```

**关键陷阱**：
- ✅ 使用 `runtime_state` 字典，**不要**用类成员变量存储运行时状态
- ✅ 回调必须通过 `runtime_instance.register_timer_callback()` 注册
- ✅ 必须存储回调引用（`current_timer_callback`）以便暂停时断开
- ✅ 使用 `runtime_instance._complete_execution()` 而非 `finished.emit()`
- ❌ 不要用 `bind()` —— 会导致内存泄漏
- ❌ 忘记调用 `super.get_default_runtime_state()` 会丢失基类状态

## 参考资料详解

### 详细开发指南
- [完整指令创建指南](references/instruction_creation_guide.md) - 详细的开发步骤、最佳实践、常见陷阱
- [指令分类参考](references/instruction_categories.md) - 各种指令类型的实现细节

### 模板文件
- [同步指令模板](templates/sync_instruction_template.gd) - 简单同步指令的完整模板
- [异步指令模板](templates/async_instruction_template.gd) - 带定时器/RuntimeInstance 的异步指令模板
- [测试脚本模板](templates/test_script_template.gd) - 测试脚本模板

## 工作流程

### 1. 规划指令
- 确定功能需求和参数
- 选择合适的指令分类
- 确定是同步还是异步执行（设置 `ExecutionMode`）
- 确定是否需要 `RuntimeInstructionInstance` 支持

### 2. 创建代码
- 从模板开始
- 实现必需方法
- 添加参数验证
- 实现错误处理

### 3. 添加本地化
- 在 `addons/fuse/localization/translations.csv` 添加键值对
- 使用 `_log_error_localized()` 记录错误
- 使用 `set_error_localized()` 设置错误状态
- 错误键前缀：`FUSE_ERROR_*`

### 4. 创建测试
- 创建测试场景
- 编写测试脚本
- 测试基本功能和边界情况

### 5. 验证和调试
- 在编辑器中检查 Inspector 显示
- 运行测试场景
- 验证错误处理和本地化

## 提示和技巧

- **使用类型注解**：避免类型推断问题
  ```gdscript
  var node: Node = context.get_node(target_node)
  ```

- **条件属性显示**：使用 `_validate_property()` 控制属性可见性
  ```gdscript
  func _validate_property(property: Dictionary):
      if property.name == "optional_param" and not show_optional:
          property.usage = PROPERTY_USAGE_NO_EDITOR
  ```

- **属性刷新**：修改影响其他属性的属性时调用 `notify_property_list_changed()`
  ```gdscript
  func _set(property: StringName, value: Variant) -> bool:
      if property == "use_variable":
          set(property, value)
          notify_property_list_changed()
          return true
      return false
  ```

- **图标选择**：使用 Godot 内置图标
  ```gdscript
  metadata.builtin_icon = "Script"  # 或其他图标名称
  ```

- **元数据模式**：
  ```gdscript
  static func _get_instruction_metadata() -> InstructionMetadata:
      var metadata = InstructionMetadata.new()
      metadata.name_key = "FUSE_INSTRUCTION_XXX_NAME"
      metadata.category_key = "FUSE_CATEGORY_XXX"
      metadata.description_key = "FUSE_INSTRUCTION_XXX_DESC"
      metadata.keywords = ["keyword1", "keyword2"]
      metadata.builtin_icon = "Script"
      return metadata
  ```

## 验证清单

创建指令后，确认以下各项：

- [ ] 文件命名符合规范（无 `_instruction` 后缀）
- [ ] 类命名符合规范（无 `Instruction` 后缀）
- [ ] 实现了所有必需方法（`execute`, `validate`, `get_description`, `_update_resource_name`）
- [ ] 使用正确的 API（`context.get_node()`, `Engine.get_main_loop()`）
- [ ] 变量访问使用 `VariableOperations`（非直接 `context.get_variable()`）
- [ ] 使用 `BaseVariable.VariableScope` 枚举（非布尔 `is_global`）
- [ ] 异步指令设置了 `ExecutionMode.FORCE_ASYNC`
- [ ] 异步指令实现了 `RuntimeInstructionInstance` 支持
- [ ] 添加了本地化翻译（`FUSE_*` 前缀）
- [ ] 错误使用 `_log_error_localized()` + `set_error_localized()`
- [ ] 创建了测试场景和脚本
- [ ] 测试通过
- [ ] 在编辑器中验证 Inspector 显示
- [ ] 配置了图标
- [ ] 处理了错误情况

## 获取帮助

- 查看完整指南：[references/instruction_creation_guide.md](references/instruction_creation_guide.md)
- 查看指令分类：[references/instruction_categories.md](references/instruction_categories.md)
- 使用模板快速开始：[templates/](templates/)
