# Fuse Stage 1: P0 组件扩展 — 完整规格文档

**版本:** 1.0
**日期:** 2026-06-17
**基线:** 整改后架构 (129 指令 / 65 事件 / 43 条件, 组件扫描自动注册, EC 770 行, TranslationDomain 3797 条)
**目标:** 验证整改后架构的组件开发吞吐量, 建立标准化组件开发工作流

---

## 目录

1. [基线状态](#1-基线状态)
2. [组件总览](#2-组件总览)
3. [开发模板](#3-开发模板)
4. [组件详细规格](#4-组件详细规格)
   - [4.1 批量 A: 首批模板组件 (3 个)](#41-批量-a-首批模板组件)
   - [4.2 批量 B: 物理组件 (3 个)](#42-批量-b-物理组件)
   - [4.3 批量 C: 动画/UI 组件 (3 个)](#43-批量-c-动画ui-组件)
   - [4.4 批量 D: 变量/系统组件 (3 个)](#44-批量-d-变量系统组件)
   - [4.5 批量 E: 渲染/导航/输入组件 (3 个)](#45-批量-e-渲染导航输入组件)
5. [新目录规划](#5-新目录规划)
6. [翻译键设计](#6-翻译键设计)
7. [验证清单](#7-验证清单)
8. [文件清单](#8-文件清单)

---

## 1. 基线状态

### 1.1 架构基线

| 指标 | 值 |
|------|-----|
| 指令总数 | 129 |
| 事件总数 | 65 |
| 条件总数 | 43 |
| plugin.gd | 130 行 (编排器) |
| ExecutionContext | 770 行 (三层门面) |
| 组件注册 | 扫描自动注册, upsert 去重, 重复统计 |
| 本地化 | Godot TranslationDomain, 3797 条目 |
| 翻译格式 | CSV 键值对 → `.translation` 二进制 |

### 1.2 关键架构决策

- **组件自动注册:** 新指令只需在 `instructions/<category>/` 放置 `.gd` 文件 → 插件重载 → `FuseComponentScanner` 自动扫描注册
- **翻译系统:** `FuseLocalization.translate(key)` / `FuseLocalization.translate_format(key, args)` → Godot TranslationDomain
- **变量服务:** `GlobalVariableService` (RefCounted) + `VariableOperations` (统一 API) + `VariableScopeUtils` (作用域工具)
- **元数据系统:** `InstructionMetadata` / `EventMetadata` / `ConditionMetadata` 统一管理 name/category/description/keywords/icon
- **运行时实例:** `RuntimeInstructionInstance` / `RuntimeEventInstance` 支持暂停/恢复/多实例隔离

### 1.3 组件开发标准流程

```
创建 .gd 文件 → 继承基类 → 实现元数据方法 → 实现核心方法 → 添加翻译条目 → 重载插件 → 自动注册
```

---

## 2. 组件总览

### 2.1 15 个 P0 组件

| # | 组件名 | 类型 | 分类目录 | 基类 | 复杂度 | 工时 |
|---|--------|------|----------|------|:---:|:---:|
| 1 | **SetGravityScale** | Instruction | physics/ | BaseInstruction | 低 | 0.5h |
| 2 | **EnableDisableCollision** | Instruction | physics/ | BaseInstruction | 低 | 0.5h |
| 3 | **SetCollisionMask** | Instruction | physics/ | BaseInstruction | 低 | 0.5h |
| 4 | **CheckOverlapArea** | Condition | physics/ | BaseCondition | 中 | 0.5h |
| 5 | **SetAnimationTreeParameter** | Instruction | animation/ | BaseInstruction | 中 | 1h |
| 6 | **SetSpriteFlip** | Instruction | animation/ | BaseInstruction | 低 | 0.5h |
| 7 | **AddVariable** | Instruction | variables/ | BaseInstruction | 低 | 0.5h |
| 8 | **ToggleVariable** | Instruction | variables/ | BaseInstruction | 低 | 0.5h |
| 9 | **SetUIColor** | Instruction | ui/ | BaseInstruction | 低 | 0.5h |
| 10 | **SetMaterialProperty** | Instruction | rendering/ | BaseInstruction | 中 | 1h |
| 11 | **CheckIsOnScreen** | Condition | rendering/ | BaseCondition | 低 | 0.5h |
| 12 | **NavigateToPosition** | Instruction | navigation/ | BaseInstruction | 高 | 1.5h |
| 13 | **OnInputBuffered** | Event | input/ | BaseEvent | 中 | 1h |
| 14 | **SetProcessMode** | Instruction | node_operations/ | BaseInstruction | 低 | 0.5h |
| 15 | **MouseWorldPosition** | Instruction | system/ | BaseInstruction | 低 | 0.5h |

> **总计:** 11 指令 + 2 条件 + 2 事件 = 15 组件, 约 9.5h

### 2.2 依赖关系

```
批量 A (模板组件: SetSpriteFlip, ToggleVariable, SetProcessMode)
  └─→ 提供开发模板和验证流程
        └─→ 批量 B (物理: SetGravityScale, EnableDisableCollision, CheckOverlapArea)
              └─→ 批量 C (动画/UI: SetAnimationTreeParameter, SetUIColor, SetCollisionMask)
                    └─→ 批量 D (变量/系统: AddVariable, MouseWorldPosition, CheckIsOnScreen)
                          └─→ 批量 E (复杂组件: SetMaterialProperty, NavigateToPosition, OnInputBuffered)
```

---

## 3. 开发模板

从首批 3 个简单组件 (`SetSpriteFlip`, `ToggleVariable`, `SetProcessMode`) 提炼的标准开发模板。

### 3.1 指令模板

```gdscript
@tool
@icon("res://addons/fuse/icons/builtin/<IconName>.png")
extends BaseInstruction
class_name <ClassName>

## <一句话描述>

# =============================================
# 枚举定义（如有）
# =============================================
enum <EnumName> {
    <OPTION_A>,  # <描述>
    <OPTION_B>   # <描述>
}

# =============================================
# 属性定义
# =============================================
var <param_1>: <Type> = <default>:
    set(value):
        <param_1> = value
        _update_resource_name()
        notify_property_list_changed()  # 如需动态属性列表

var <param_2>: <Type> = <default>:
    set(value):
        <param_2> = value
        _update_resource_name()

# =============================================
# 元数据（必需）
# =============================================
static func _get_instruction_metadata() -> InstructionMetadata:
    var metadata = InstructionMetadata.new()
    metadata.name_key = "FUSE_INSTRUCTION_<CLASS>_NAME"
    metadata.category_key = "FUSE_CATEGORY_<CATEGORY>"
    metadata.description_key = "FUSE_INSTRUCTION_<CLASS>_DESC"
    metadata.keywords = ["<中文>", "<english>", ...]
    metadata.builtin_icon = "<IconName>"
    return metadata

func _setup_metadata():
    pass

# =============================================
# 动态属性列表（如有条件显示）
# =============================================
func _get_property_list()  -> Array[Dictionary]:
    var properties := []

    properties.append({
        name = "<Category Label>",
        type = TYPE_NIL,
        hint = PROPERTY_HINT_NONE,
        usage = PROPERTY_USAGE_CATEGORY
    })

    properties.append({
        name = "<param_name>",
        type = <TYPE_XXX>,
        hint = <PROPERTY_HINT_XXX>,
        hint_string = "<hint>",
        usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
    })

    return properties

# =============================================
# 资源名称（必需）
# =============================================
func _update_resource_name():
    resource_name = FuseLocalization.translate_format(
        "FUSE_INSTRUCTION_<CLASS>_RESOURCE_NAME",
        {"param": <value>}
    )

# =============================================
# 条件属性可见性（如需要）
# =============================================
func _validate_property(property: Dictionary) -> void:
    if <condition> and property.name == "<hidden_prop>":
        property.usage = PROPERTY_USAGE_NO_EDITOR

# =============================================
# 执行（必需）
# =============================================
func execute(context: ExecutionContext):
    _start_execution(context)

    # 1. 验证参数
    if <invalid_condition>:
        set_error_localized("FUSE_ERROR_<DESC>", FuseError.ErrorType.VALIDATION_ERROR, {})
        finished.emit()
        return

    # 2. 获取目标节点（如需要）
    var node := context.get_node(<target_path>)
    if not node:
        set_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {"node": str(<target_path>)})
        finished.emit()
        return

    # 3. 执行核心逻辑
    <核心逻辑>

    # 4. 日志
    _log_info_localized("FUSE_LOG_<CLASS>_DONE", {"param": <value>})

    # 5. 完成
    _on_execution_completed()

# =============================================
# 验证（必需）
# =============================================
func validate() -> Array[String]:
    var errors = super.validate()
    if <invalid_condition>:
        errors.append(FuseLocalization.translate("FUSE_ERROR_<DESC>"))
    return errors

# =============================================
# 描述（必需）
# =============================================
func get_description() -> String:
    return FuseLocalization.translate_format(
        "FUSE_INSTRUCTION_<CLASS>_DESCRIPTION",
        {"param": <value>}
    )

# =============================================
# _set 拦截（如需要 notify_property_list_changed）
# =============================================
func _set(property: StringName, value: Variant) -> bool:
    if property == "<dynamic_prop>":
        set(property, value)
        notify_property_list_changed()
        _update_resource_name()
        return true
    return false
```

### 3.2 条件模板

```gdscript
@tool
@icon("res://addons/fuse/icons/builtin/<IconName>.png")
extends BaseCondition
class_name Check<Condition>

## <一句话描述>

# =============================================
# 枚举定义（如有）
# =============================================
enum <EnumName> {
    <OPTION_A>,
    <OPTION_B>
}

# =============================================
# 属性定义
# =============================================
var <param_1>: <Type> = <default>:
    set(value):
        <param_1> = value
        _update_resource_name()
        notify_property_list_changed()

# =============================================
# 元数据（必需）
# =============================================
static func _get_condition_metadata() -> ConditionMetadata:
    var metadata = ConditionMetadata.new()
    metadata.name_key = "FUSE_CONDITION_<CLASS>_NAME"
    metadata.category_key = "FUSE_CATEGORY_<CATEGORY>"
    metadata.description_key = "FUSE_CONDITION_<CLASS>_DESC"
    metadata.keywords = ["<中文>", "<english>", ...]
    metadata.builtin_icon = "<IconName>"
    return metadata

# =============================================
# 动态属性列表
# =============================================
func _get_property_list()  -> Array[Dictionary]:
    var properties := []
    # ...（同指令模板）
    return properties

# =============================================
# 资源名称（必需）
# =============================================
func _update_resource_name() -> void:
    resource_name = FuseLocalization.translate_format(
        "FUSE_CONDITION_<CLASS>_FORMAT",
        {"param": <value>}
    )

# =============================================
# 条件评估（必需 — 核心逻辑）
# =============================================
func _evaluate_condition(context: ExecutionContext) -> bool:
    # 验证参数
    if <invalid_condition>:
        _create_fuse_error_localized("FUSE_ERROR_<DESC>", FuseError.ErrorType.VALIDATION_ERROR)
        return false

    # 获取数据
    var data = <获取数据>

    # 评估
    var result = <评估逻辑>
    return result

# =============================================
# 依赖计算（必需）
# =============================================
func _compute_dependencies() -> Array[String]:
    var deps: Array[String] = []
    if not <variable_name>.is_empty():
        deps.append(<variable_name>)
    return deps

# =============================================
# 线程安全（如有需要）
# =============================================
func _compute_thread_safety() -> bool:
    if _thread_safety_computed:
        return _thread_safety_cached
    _thread_safety_cached = <true/false>
    _thread_safety_computed = true
    return _thread_safety_cached

# =============================================
# 类型信息（必需）
# =============================================
func get_condition_type() -> String:
    return "<snake_case_type>"

func get_condition_category() -> String:
    return "<category>"

# =============================================
# 描述（必需）
# =============================================
func get_description() -> String:
    return FuseLocalization.translate_format(
        "FUSE_CONDITION_<CLASS>_DESCRIPTION",
        {"param": <value>}
    )

# =============================================
# 验证（必需）
# =============================================
func validate() -> Array[String]:
    var errors = super.validate()
    if <invalid>:
        errors.append(FuseLocalization.translate("FUSE_ERROR_<DESC>"))
    return errors
```

### 3.3 事件模板

```gdscript
@tool
@icon("res://addons/fuse/icons/builtin/<IconName>.png")
extends BaseEvent
class_name On<Event>

## <一句话描述>

# =============================================
# 属性定义
# =============================================
@export var <param_1>: <Type> = <default>:
    set(value):
        if <param_1> != value:
            <param_1> = value
            _update_resource_name()
            notify_property_list_changed()

# =============================================
# 运行时状态
# =============================================
var _owner_node_ref: Node = null

# =============================================
# 元数据（必需）
# =============================================
static func _get_event_metadata() -> EventMetadata:
    var metadata = EventMetadata.new()
    metadata.name_key = "FUSE_EVENT_<CLASS>_NAME"
    metadata.category_key = "FUSE_EVENT_CATEGORY_<CATEGORY>"
    metadata.description_key = "FUSE_EVENT_<CLASS>_DESC"
    metadata.keywords = ["<中文>", "<english>", ...]
    metadata.builtin_icon = "<IconName>"
    return metadata

# =============================================
# 资源名称（必需）
# =============================================
func _update_resource_name():
    resource_name = FuseLocalization.translate_format(
        "FUSE_EVENT_<CLASS>_RESOURCE_NAME",
        {"param": <value>}
    )

# =============================================
# 初始化（必需）
# =============================================
func initialize(owner_node: Node) -> void:
    if not owner_node:
        _create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NULL", FuseError.ErrorType.CONFIGURATION_ERROR, {})
        return
    _owner_node_ref = owner_node
    # 连接信号 / 设置监听
    _log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

# =============================================
# 运行时实例初始化（推荐实现）
# =============================================
func initialize_with_runtime_instance(owner_node: Node, runtime_instance: RuntimeEventInstance) -> void:
    if Engine.is_editor_hint():
        return
    _runtime_instance_ref = runtime_instance
    initialize(owner_node)

# =============================================
# 清理（必需）
# =============================================
func terminate(owner_node: Node) -> void:
    # 断开信号 / 清理资源
    if _runtime_instance_ref:
        <重置运行时状态>
    _owner_node_ref = null
    _log_debug_localized("FUSE_LOG_EVENT_TERMINATED", {"event_type": get_event_type()})

# =============================================
# 默认运行时状态
# =============================================
func get_default_runtime_state() -> Dictionary:
    var base = super.get_default_runtime_state()
    base["<custom_state>"] = <default>
    return base

# =============================================
# 类型信息（必需）
# =============================================
func get_event_type() -> String:
    return "<snake_case_type>"

func get_event_category() -> String:
    return "<category>"

# =============================================
# 验证（必需）
# =============================================
func validate() -> Array[String]:
    var errors: Array[String] = []
    if <invalid>:
        errors.append(FuseLocalization.translate("FUSE_ERROR_<DESC>"))
    return errors

# =============================================
# 重置
# =============================================
func reset() -> void:
    super.reset()
    if _runtime_instance_ref:
        <重置运行时状态>
```

---

## 4. 组件详细规格

### 4.1 批量 A: 首批模板组件

首批 3 个最简单的组件, 用于建立开发流程和验证模板。

---

#### 4.1.1 SetSpriteFlip (指令)

**文件:** `addons/fuse/instructions/animation/set_sprite_flip.gd`
**类名:** `SetSpriteFlip`
**基类:** `BaseInstruction`
**分类:** animation
**复杂度:** 低 (0.5h)

##### 功能描述
设置 Sprite2D / AnimatedSprite2D 的水平/垂直翻转。

##### 参数定义

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `target_node` | NodePath | `NodePath("")` | 目标 Sprite2D/AnimatedSprite2D 节点 |
| `flip_h` | bool | `false` | 是否水平翻转 |
| `flip_v` | bool | `false` | 是否垂直翻转 |
| `flip_mode` | enum (FlipMode) | `BOTH` | 翻转模式: `HORIZONTAL`, `VERTICAL`, `BOTH` |

##### 方法签名

```gdscript
static func _get_instruction_metadata() -> InstructionMetadata
func execute(context: ExecutionContext)
func validate() -> Array[String]
func get_description() -> String
```

##### 核心逻辑

```gdscript
func execute(context: ExecutionContext):
    _start_execution(context)

    if target_node.is_empty():
        set_error_localized("FUSE_ERROR_TARGET_NODE_EMPTY", ...)
        finished.emit(); return

    var node := context.get_node(target_node)
    if not node:
        set_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", ...)
        finished.emit(); return

    # 根据节点类型设置 flip
    if node is Sprite2D:
        var sprite := node as Sprite2D
        if flip_mode == FlipMode.HORIZONTAL or flip_mode == FlipMode.BOTH:
            sprite.flip_h = flip_h
        if flip_mode == FlipMode.VERTICAL or flip_mode == FlipMode.BOTH:
            sprite.flip_v = flip_v
    elif node is AnimatedSprite2D:
        var anim := node as AnimatedSprite2D
        if flip_mode == FlipMode.HORIZONTAL or flip_mode == FlipMode.BOTH:
            anim.flip_h = flip_h
        if flip_mode == FlipMode.VERTICAL or flip_mode == FlipMode.BOTH:
            anim.flip_v = flip_v
    else:
        set_error_localized("FUSE_ERROR_NODE_TYPE_INVALID", ...)
        finished.emit(); return

    _on_execution_completed()
```

##### 验证逻辑

- `target_node` 不能为空
- 编辑期不验证节点类型（运行时动态检查）

##### 翻译键设计

| 键 | zh_CN | en_US |
|----|-------|-------|
| `FUSE_INSTRUCTION_SET_SPRITE_FLIP_NAME` | 设置精灵翻转 | Set Sprite Flip |
| `FUSE_INSTRUCTION_SET_SPRITE_FLIP_DESC` | 设置 Sprite2D 或 AnimatedSprite2D 的水平/垂直翻转 | Sets horizontal/vertical flip of Sprite2D or AnimatedSprite2D |
| `FUSE_INSTRUCTION_SET_SPRITE_FLIP_RESOURCE_NAME` | 翻转 {target}: H={h} V={v} | Flip {target}: H={h} V={v} |
| `FUSE_INSTRUCTION_SET_SPRITE_FLIP_DESCRIPTION` | 翻转 "{target}" [H:{h}, V:{v}] | Flip "{target}" [H:{h}, V:{v}] |
| `FUSE_INSTRUCTION_SET_SPRITE_FLIP_HORIZONTAL` | 水平 | Horizontal |
| `FUSE_INSTRUCTION_SET_SPRITE_FLIP_VERTICAL` | 垂直 | Vertical |
| `FUSE_INSTRUCTION_SET_SPRITE_FLIP_BOTH` | 双方向 | Both |
| `FUSE_LOG_SPRITE_FLIP_SET` | 已设置 {node} 翻转: H={h}, V={v} | Set {node} flip: H={h}, V={v} |

##### 图标

`builtin_icon`: `"Sprite2D"`

---

#### 4.1.2 ToggleVariable (指令)

**文件:** `addons/fuse/instructions/variables/toggle_variable.gd`
**类名:** `ToggleVariable`
**基类:** `BaseInstruction`
**分类:** variables
**复杂度:** 低 (0.5h)

##### 功能描述
切换布尔变量的值 (true ↔ false)。使用 `VariableOperations` 统一 API, 直接委托给 `GlobalVariableService`。

##### 参数定义

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `variable_name` | String | `""` | 变量名 |
| `variable_scope` | enum (VariableScope) | `LOCAL` | 变量作用域: `LOCAL`, `SCOPE`, `GLOBAL` |

##### 方法签名

```gdscript
static func _get_instruction_metadata() -> InstructionMetadata
func execute(context: ExecutionContext)
func validate() -> Array[String]
func get_description() -> String
```

##### 核心逻辑

```gdscript
func execute(context: ExecutionContext):
    _start_execution(context)

    if variable_name.is_empty():
        set_error_localized("FUSE_ERROR_VAR_NAME_EMPTY", ...)
        finished.emit(); return

    # 使用 VariableOperations 获取当前值
    var current = VariableOperations.get_variable(context, variable_name, variable_scope, null)
    if current == null:
        set_error_localized("FUSE_ERROR_VAR_NOT_FOUND", ...)
        finished.emit(); return

    # 切换布尔值
    var new_value: bool
    if current is bool:
        new_value = not current
    else:
        # 尝试类型转换
        new_value = not (current != null and current != false and current != 0 and current != 0.0 and current != "")

    # 使用 VariableOperations 设置新值
    VariableOperations.set_variable(context, variable_name, new_value, variable_scope)

    _log_info_localized("FUSE_LOG_VARIABLE_TOGGLED", {"name": variable_name, "value": str(new_value)})
    _on_execution_completed()
```

##### 验证逻辑

- `variable_name` 不能为空
- 变量作用域有效

##### 翻译键设计

| 键 | zh_CN | en_US |
|----|-------|-------|
| `FUSE_INSTRUCTION_TOGGLE_VARIABLE_NAME` | 切换变量 | Toggle Variable |
| `FUSE_INSTRUCTION_TOGGLE_VARIABLE_DESC` | 切换布尔变量的值 (true ↔ false) | Toggles a boolean variable value |
| `FUSE_INSTRUCTION_TOGGLE_VARIABLE_RESOURCE_NAME` | 切换: [{scope}] {name} | Toggle: [{scope}] {name} |
| `FUSE_INSTRUCTION_TOGGLE_VARIABLE_DESCRIPTION` | 切换 [{scope}] {name} | Toggle [{scope}] {name} |
| `FUSE_LOG_VARIABLE_TOGGLED` | 已切换变量 {name} → {value} | Toggled variable {name} → {value} |

##### 图标

`builtin_icon`: `"Boolean"`

---

#### 4.1.3 SetProcessMode (指令)

**文件:** `addons/fuse/instructions/node_operations/set_process_mode.gd`
**类名:** `SetProcessMode`
**基类:** `BaseInstruction`
**分类:** node_operations
**复杂度:** 低 (0.5h)

##### 功能描述
设置节点的 `process_mode` 属性, 控制节点的处理行为 (继承/始终/空闲时/禁用)。

##### 参数定义

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `target_node` | NodePath | `NodePath("")` | 目标节点 |
| `process_mode` | enum (int) | `PROCESS_MODE_INHERIT (0)` | 处理模式枚举: 0=Inherit, 1=Pausable, 2=WhenPaused, 3=Always, 4=Disabled |

##### 方法签名

```gdscript
static func _get_instruction_metadata() -> InstructionMetadata
func execute(context: ExecutionContext)
func validate() -> Array[String]
func get_description() -> String
```

##### 核心逻辑

```gdscript
func execute(context: ExecutionContext):
    _start_execution(context)

    if target_node.is_empty():
        set_error_localized("FUSE_ERROR_TARGET_NODE_EMPTY", ...)
        finished.emit(); return

    var node := context.get_node(target_node)
    if not node:
        set_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", ...)
        finished.emit(); return

    node.process_mode = process_mode as Node.ProcessMode

    _log_info_localized("FUSE_LOG_PROCESS_MODE_SET", {
        "node": node.name,
        "mode": _get_mode_name()
    })
    _on_execution_completed()
```

##### 验证逻辑

- `target_node` 不能为空

##### 翻译键设计

| 键 | zh_CN | en_US |
|----|-------|-------|
| `FUSE_INSTRUCTION_SET_PROCESS_MODE_NAME` | 设置处理模式 | Set Process Mode |
| `FUSE_INSTRUCTION_SET_PROCESS_MODE_DESC` | 设置节点的 process_mode 属性 | Sets the process_mode property of a node |
| `FUSE_INSTRUCTION_SET_PROCESS_MODE_RESOURCE_NAME` | 处理模式: {target} → {mode} | Process: {target} → {mode} |
| `FUSE_INSTRUCTION_SET_PROCESS_MODE_DESCRIPTION` | 设置 {target} 处理模式为 {mode} | Set {target} process mode to {mode} |
| `FUSE_ENUM_PROCESS_MODE_INHERIT` | 继承 | Inherit |
| `FUSE_ENUM_PROCESS_MODE_PAUSABLE` | 可暂停 | Pausable |
| `FUSE_ENUM_PROCESS_MODE_WHEN_PAUSED` | 暂停时 | When Paused |
| `FUSE_ENUM_PROCESS_MODE_ALWAYS` | 始终 | Always |
| `FUSE_ENUM_PROCESS_MODE_DISABLED` | 禁用 | Disabled |
| `FUSE_LOG_PROCESS_MODE_SET` | 设置 {node} 处理模式 → {mode} | Set {node} process mode → {mode} |

##### 图标

`builtin_icon`: `"Node"`

---

### 4.2 批量 B: 物理组件

#### 4.2.1 SetGravityScale (指令)

**文件:** `addons/fuse/instructions/physics/set_gravity_scale.gd`
**类名:** `SetGravityScale`
**基类:** `BaseInstruction`
**分类:** physics
**复杂度:** 低 (0.5h)

##### 功能描述
设置 CharacterBody2D / CharacterBody3D / RigidBody2D / RigidBody3D 的重力缩放值。

##### 参数定义

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `target_node` | NodePath | `NodePath("")` | 目标物理体节点 |
| `gravity_scale` | float | `1.0` | 重力缩放值 (0 = 无重力) |

##### 方法签名

```gdscript
static func _get_instruction_metadata() -> InstructionMetadata
func execute(context: ExecutionContext)
func validate() -> Array[String]
func get_description() -> String
```

##### 核心逻辑

```gdscript
func execute(context: ExecutionContext):
    _start_execution(context)

    if target_node.is_empty():
        set_error_localized("FUSE_ERROR_TARGET_NODE_EMPTY", ...)
        finished.emit(); return

    var node := context.get_node(target_node)
    if not node:
        set_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", ...)
        finished.emit(); return

    # 支持多种物理体类型
    if node is CharacterBody2D:
        (node as CharacterBody2D).gravity_scale = gravity_scale
    elif node is CharacterBody3D:
        (node as CharacterBody3D).gravity_scale = gravity_scale
    elif node is RigidBody2D:
        (node as RigidBody2D).gravity_scale = gravity_scale
    elif node is RigidBody3D:
        (node as RigidBody3D).gravity_scale = gravity_scale
    else:
        set_error_localized("FUSE_ERROR_NODE_TYPE_INVALID", ...)
        finished.emit(); return

    _log_info_localized("FUSE_LOG_GRAVITY_SCALE_SET", {"node": node.name, "scale": gravity_scale})
    _on_execution_completed()
```

##### 验证逻辑

- `target_node` 不能为空
- `gravity_scale` 可以是任意 float (包括负值)

##### 翻译键设计

| 键 | zh_CN | en_US |
|----|-------|-------|
| `FUSE_INSTRUCTION_SET_GRAVITY_SCALE_NAME` | 设置重力缩放 | Set Gravity Scale |
| `FUSE_INSTRUCTION_SET_GRAVITY_SCALE_DESC` | 设置物理体的重力缩放值 | Sets the gravity scale of a physics body |
| `FUSE_INSTRUCTION_SET_GRAVITY_SCALE_RESOURCE_NAME` | 重力缩放: {target} = {scale} | Gravity: {target} = {scale} |
| `FUSE_INSTRUCTION_SET_GRAVITY_SCALE_DESCRIPTION` | 设置 {target} 重力缩放 = {scale} | Set {target} gravity scale = {scale} |
| `FUSE_LOG_GRAVITY_SCALE_SET` | 设置 {node} 重力缩放 = {scale} | Set {node} gravity scale = {scale} |

##### 图标

`builtin_icon`: `"RigidBody2D"`

---

#### 4.2.2 EnableDisableCollision (指令)

**文件:** `addons/fuse/instructions/physics/enable_disable_collision.gd`
**类名:** `EnableDisableCollision`
**基类:** `BaseInstruction`
**分类:** physics
**复杂度:** 低 (0.5h)

##### 功能描述
启用或禁用 CollisionObject2D / CollisionObject3D 的碰撞检测 (通过设置 `collision_layer` 和/或 `collision_mask` 的 `disable_mode` 属性, 或直接禁用碰撞体)。

> **设计决策:** 采用 `collision_enabled` 属性方式 — 对于 CollisionObject2D/3D 直接设置 `set_deferred("disabled", ...)`, 对于 Area2D/3D 通过 `monitoring` + `monitorable` 控制。

##### 参数定义

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `target_node` | NodePath | `NodePath("")` | 目标碰撞对象节点 |
| `enable` | bool | `true` | 是否启用碰撞 |

##### 方法签名

```gdscript
static func _get_instruction_metadata() -> InstructionMetadata
func execute(context: ExecutionContext)
func validate() -> Array[String]
func get_description() -> String
```

##### 核心逻辑

```gdscript
func execute(context: ExecutionContext):
    _start_execution(context)

    if target_node.is_empty():
        set_error_localized("FUSE_ERROR_TARGET_NODE_EMPTY", ...)
        finished.emit(); return

    var node := context.get_node(target_node)
    if not node:
        set_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", ...)
        finished.emit(); return

    var handled := false

    # CollisionShape2D/3D
    if node is CollisionShape2D or node is CollisionShape3D:
        node.set_deferred("disabled", not enable)
        handled = true
    # CollisionPolygon2D/3D
    elif node is CollisionPolygon2D or node is CollisionPolygon3D:
        node.set_deferred("disabled", not enable)
        handled = true
    # Area2D/3D — 控制 monitoring 和 monitorable
    elif node is Area2D:
        var area := node as Area2D
        area.set_deferred("monitoring", enable)
        area.set_deferred("monitorable", enable)
        handled = true
    elif node is Area3D:
        var area := node as Area3D
        area.set_deferred("monitoring", enable)
        area.set_deferred("monitorable", enable)
        handled = true
    else:
        set_error_localized("FUSE_ERROR_NODE_TYPE_INVALID", ...)
        finished.emit(); return

    var action_key = "FUSE_LOG_COLLISION_ENABLED" if enable else "FUSE_LOG_COLLISION_DISABLED"
    _log_info_localized(action_key, {"node": node.name})
    _on_execution_completed()
```

##### 验证逻辑

- `target_node` 不能为空

##### 翻译键设计

| 键 | zh_CN | en_US |
|----|-------|-------|
| `FUSE_INSTRUCTION_ENABLE_DISABLE_COLLISION_NAME` | 启用/禁用碰撞 | Enable/Disable Collision |
| `FUSE_INSTRUCTION_ENABLE_DISABLE_COLLISION_DESC` | 启用或禁用碰撞对象的碰撞检测 | Enables or disables collision detection for a collision object |
| `FUSE_INSTRUCTION_ENABLE_DISABLE_COLLISION_RESOURCE_NAME` | {action}: {target} | {action}: {target} |
| `FUSE_INSTRUCTION_ENABLE_DISABLE_COLLISION_DESCRIPTION` | {action} {target} 的碰撞 | {action} collision of {target} |
| `FUSE_INSTRUCTION_ENABLE_DISABLE_COLLISION_ENABLE` | 启用 | Enable |
| `FUSE_INSTRUCTION_ENABLE_DISABLE_COLLISION_DISABLE` | 禁用 | Disable |
| `FUSE_LOG_COLLISION_ENABLED` | 已启用 {node} 碰撞 | Enabled collision for {node} |
| `FUSE_LOG_COLLISION_DISABLED` | 已禁用 {node} 碰撞 | Disabled collision for {node} |

##### 图标

`builtin_icon`: `"CollisionShape2D"`

---

#### 4.2.3 CheckOverlapArea (条件)

**文件:** `addons/fuse/conditions/physics/check_overlap_area.gd`
**类名:** `CheckOverlapArea`
**基类:** `BaseCondition`
**分类:** physics
**复杂度:** 中 (0.5h)

##### 功能描述
检查 Area2D / Area3D 是否与其他碰撞体重叠。支持按组过滤和返回重叠体列表。

##### 参数定义

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `area_node` | NodePath | `NodePath("")` | 要检查的 Area2D/Area3D 节点 |
| `check_group` | String | `""` | 过滤重叠体所属组 (空 = 不过滤) |
| `save_to_variable` | String | `""` | 将重叠体列表保存到变量 (空 = 不保存) |

##### 方法签名

```gdscript
static func _get_condition_metadata() -> ConditionMetadata
func _evaluate_condition(context: ExecutionContext) -> bool
func _compute_dependencies() -> Array[String]
func validate() -> Array[String]
func get_description() -> String
```

##### 核心逻辑

```gdscript
func _evaluate_condition(context: ExecutionContext) -> bool:
    if area_node.is_empty():
        _create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_EMPTY", ...)
        return false

    var node := context.get_node(area_node)
    if not node:
        return false

    var overlapping_bodies: Array[Node2D] = []
    var overlapping_areas: Array[Area2D] = []

    if node is Area2D:
        overlapping_bodies = (node as Area2D).get_overlapping_bodies()
        overlapping_areas = (node as Area2D).get_overlapping_areas()
    elif node is Area3D:
        overlapping_bodies = (node as Area3D).get_overlapping_bodies()
        overlapping_areas = (node as Area3D).get_overlapping_areas()
    else:
        _create_fuse_error_localized("FUSE_ERROR_NODE_TYPE_INVALID", ...)
        return false

    # 按组过滤
    if not check_group.is_empty():
        overlapping_bodies = overlapping_bodies.filter(func(b): return b.is_in_group(check_group))
        overlapping_areas = overlapping_areas.filter(func(a): return a.is_in_group(check_group))

    var has_overlap = not overlapping_bodies.is_empty() or not overlapping_areas.is_empty()

    # 保存到变量
    if has_overlap and not save_to_variable.is_empty():
        var all_overlaps = overlapping_bodies + overlapping_areas
        VariableOperations.set_variable(context, save_to_variable, all_overlaps, BaseVariable.VariableScope.LOCAL)

    return has_overlap
```

##### 验证逻辑

- `area_node` 不能为空
- 编辑期不验证节点类型

##### 翻译键设计

| 键 | zh_CN | en_US |
|----|-------|-------|
| `FUSE_CONDITION_CHECK_OVERLAP_AREA_NAME` | 检查区域重叠 | Check Overlap Area |
| `FUSE_CONDITION_CHECK_OVERLAP_AREA_DESC` | 检查 Area2D/Area3D 是否有重叠体 | Checks if an Area2D/Area3D has overlapping bodies |
| `FUSE_CONDITION_CHECK_OVERLAP_AREA_FORMAT` | 重叠: {area} | Overlap: {area} |
| `FUSE_CONDITION_CHECK_OVERLAP_AREA_DESCRIPTION` | {area} 有重叠体 | {area} has overlapping bodies |
| `FUSE_CONDITION_CHECK_OVERLAP_AREA_DESC_GROUP` | {area} 有组 "{group}" 中的重叠体 | {area} has overlapping bodies in group "{group}" |
| `FUSE_LOG_OVERLAP_CHECK` | 检查 {area} 重叠: {result} | Check {area} overlap: {result} |

##### 图标

`builtin_icon`: `"Area2D"`

---

### 4.3 批量 C: 动画/UI 组件

#### 4.3.1 SetAnimationTreeParameter (指令)

**文件:** `addons/fuse/instructions/animation/set_animation_tree_parameter.gd`
**类名:** `SetAnimationTreeParameter`
**基类:** `BaseInstruction`
**分类:** animation
**复杂度:** 中 (1h)

##### 功能描述
设置 AnimationTree 的参数值。支持多种参数类型: float/blend/boolean/string (condition)。

##### 参数定义

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `target_node` | NodePath | `NodePath("")` | 目标 AnimationTree 节点 |
| `parameter_name` | String | `""` | AnimationTree 参数名 |
| `parameter_type` | enum (ParamType) | `FLOAT` | 参数类型: `FLOAT`, `INT`, `BOOL`, `STRING` (condition) |
| `float_value` | float | `0.0` | 浮点值 (ParamType=FLOAT 时使用) |
| `int_value` | int | `0` | 整数值 (ParamType=INT 时使用) |
| `bool_value` | bool | `false` | 布尔值 (ParamType=BOOL 时使用) |
| `string_value` | String | `""` | 字符串值 (ParamType=STRING 时使用) |

##### 方法签名

```gdscript
static func _get_instruction_metadata() -> InstructionMetadata
func execute(context: ExecutionContext)
func validate() -> Array[String]
func get_description() -> String
```

##### 核心逻辑

```gdscript
func execute(context: ExecutionContext):
    _start_execution(context)

    if target_node.is_empty() or parameter_name.is_empty():
        set_error_localized("FUSE_ERROR_MISSING_PARAMETER", ...)
        finished.emit(); return

    var anim_tree := context.get_node(target_node)
    if not anim_tree or not (anim_tree is AnimationTree):
        set_error_localized("FUSE_ERROR_NODE_TYPE_INVALID", ...)
        finished.emit(); return

    var tree := anim_tree as AnimationTree
    match parameter_type:
        ParamType.FLOAT:
            tree.set("parameters/%s" % parameter_name, float_value)
        ParamType.INT:
            tree.set("parameters/%s" % parameter_name, int_value)
        ParamType.BOOL:
            tree.set("parameters/%s" % parameter_name, bool_value)
        ParamType.STRING:
            tree.set("parameters/%s" % parameter_name, string_value)

    _log_info_localized("FUSE_LOG_ANIM_TREE_PARAM_SET", {"param": parameter_name, "value": _get_value_str()})
    _on_execution_completed()
```

##### 验证逻辑

- `target_node` 不能为空
- `parameter_name` 不能为空

##### 翻译键设计

| 键 | zh_CN | en_US |
|----|-------|-------|
| `FUSE_INSTRUCTION_SET_ANIM_TREE_PARAM_NAME` | 设置动画树参数 | Set AnimTree Parameter |
| `FUSE_INSTRUCTION_SET_ANIM_TREE_PARAM_DESC` | 设置 AnimationTree 节点的参数值 | Sets a parameter value on an AnimationTree node |
| `FUSE_INSTRUCTION_SET_ANIM_TREE_PARAM_RESOURCE_NAME` | 动画参数: {param} = {value} | Anim Param: {param} = {value} |
| `FUSE_INSTRUCTION_SET_ANIM_TREE_PARAM_DESCRIPTION` | 设置 {target}.{param} = {value} | Set {target}.{param} = {value} |
| `FUSE_LOG_ANIM_TREE_PARAM_SET` | 已设置动画树参数 {param} = {value} | Set AnimTree param {param} = {value} |

##### 图标

`builtin_icon`: `"AnimationTree"`

---

#### 4.3.2 SetUIColor (指令)

**文件:** `addons/fuse/instructions/ui/set_ui_color.gd`
**类名:** `SetUIColor`
**基类:** `BaseInstruction`
**分类:** ui
**复杂度:** 低 (0.5h)

##### 功能描述
设置 Control 节点的 modulate / self_modulate 颜色。支持目标类型选择。

##### 参数定义

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `target_node` | NodePath | `NodePath("")` | 目标 Control 节点 |
| `color_target` | enum (ColorTarget) | `MODULATE` | 颜色目标: `MODULATE`, `SELF_MODULATE` |
| `color` | Color | `Color.WHITE` | 目标颜色 |
| `use_variable` | bool | `false` | 是否从变量读取颜色 |
| `color_variable` | String | `""` | 颜色变量名 |

##### 方法签名

```gdscript
static func _get_instruction_metadata() -> InstructionMetadata
func execute(context: ExecutionContext)
func validate() -> Array[String]
func get_description() -> String
```

##### 核心逻辑

```gdscript
func execute(context: ExecutionContext):
    _start_execution(context)

    if target_node.is_empty():
        set_error_localized("FUSE_ERROR_TARGET_NODE_EMPTY", ...)
        finished.emit(); return

    var node := context.get_node(target_node)
    if not node or not (node is Control):
        set_error_localized("FUSE_ERROR_NODE_TYPE_INVALID", ...)
        finished.emit(); return

    var ctrl := node as Control
    var final_color: Color = color

    # 从变量读取颜色
    if use_variable and not color_variable.is_empty():
        var var_color = VariableOperations.get_variable(context, color_variable, BaseVariable.VariableScope.LOCAL, null)
        if var_color is Color:
            final_color = var_color

    match color_target:
        ColorTarget.MODULATE:
            ctrl.modulate = final_color
        ColorTarget.SELF_MODULATE:
            ctrl.self_modulate = final_color

    _log_info_localized("FUSE_LOG_UI_COLOR_SET", {"node": node.name, "color": str(final_color)})
    _on_execution_completed()
```

##### 翻译键设计

| 键 | zh_CN | en_US |
|----|-------|-------|
| `FUSE_INSTRUCTION_SET_UI_COLOR_NAME` | 设置 UI 颜色 | Set UI Color |
| `FUSE_INSTRUCTION_SET_UI_COLOR_DESC` | 设置 Control 节点的 modulate/self_modulate 颜色 | Sets modulate/self_modulate color of a Control node |
| `FUSE_INSTRUCTION_SET_UI_COLOR_RESOURCE_NAME` | UI 颜色: {target} → {color} | UI Color: {target} → {color} |
| `FUSE_INSTRUCTION_SET_UI_COLOR_DESCRIPTION` | 设置 {target} 颜色为 {color} | Set {target} color to {color} |
| `FUSE_LOG_UI_COLOR_SET` | 设置 {node} 颜色 = {color} | Set {node} color = {color} |

##### 图标

`builtin_icon`: `"ColorRect"`

---

#### 4.3.3 SetCollisionMask (指令)

**文件:** `addons/fuse/instructions/physics/set_collision_mask.gd`
**类名:** `SetCollisionMask`
**基类:** `BaseInstruction`
**分类:** physics
**复杂度:** 低 (0.5h)

##### 功能描述
设置 CollisionObject2D / CollisionObject3D 的碰撞掩码 (collision_mask)。

> **设计决策:** 与已有的 `SetCollisionLayer` 互补, `SetCollisionLayer` 设置碰撞层 (自己属于哪些层), `SetCollisionMask` 设置碰撞掩码 (检测哪些层)。用户常需单独设置 mask。

##### 参数定义

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `target_node` | NodePath | `NodePath("")` | 目标 CollisionObject2D/3D |
| `collision_mask` | int | `1` | 碰撞掩码位值 |

##### 验证逻辑

- `target_node` 不能为空
- 编辑期不验证节点类型（运行时自动适配 2D/3D）

> **注意:** 此组件逻辑与 `SetCollisionLayer` 高度一致但更简单（仅设置 mask）。参照 `instructions/physics/set_collision_layer.gd` 实现即可。

##### 翻译键设计

| 键 | zh_CN | en_US |
|----|-------|-------|
| `FUSE_INSTRUCTION_SET_COLLISION_MASK_ONLY_NAME` | 设置碰撞掩码 | Set Collision Mask |
| `FUSE_INSTRUCTION_SET_COLLISION_MASK_ONLY_DESC` | 设置 CollisionObject 的碰撞掩码 | Sets the collision mask of a CollisionObject |
| `FUSE_INSTRUCTION_SET_COLLISION_MASK_ONLY_RESOURCE_NAME` | 掩码: {target} = {mask} | Mask: {target} = {mask} |
| `FUSE_INSTRUCTION_SET_COLLISION_MASK_ONLY_DESCRIPTION` | 设置 {target} 碰撞掩码 = {mask} | Set {target} collision mask = {mask} |
| `FUSE_LOG_COLLISION_MASK_SET` | 设置 {node} 碰撞掩码 = {mask} | Set {node} collision mask = {mask} |

##### 图标

`builtin_icon`: `"CollisionShape2D"`

---

### 4.4 批量 D: 变量/系统组件

#### 4.4.1 AddVariable (指令)

**文件:** `addons/fuse/instructions/variables/add_variable.gd`
**类名:** `AddVariable`
**基类:** `BaseInstruction`
**分类:** variables
**复杂度:** 低 (0.5h)

##### 功能描述
对数值变量执行加法运算。支持整数和浮点数加法, 也支持 Vector2/Vector3 分量加法。使用 `VariableOperations` 统一 API。

##### 参数定义

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `variable_name` | String | `""` | 变量名 |
| `variable_scope` | enum (VariableScope) | `LOCAL` | 变量作用域 |
| `add_value` | float | `1.0` | 加数值 |
| `use_variable` | bool | `false` | 从另一个变量读取加数 |
| `add_variable` | String | `""` | 加数变量名 |

##### 核心逻辑

```gdscript
func execute(context: ExecutionContext):
    _start_execution(context)

    if variable_name.is_empty():
        set_error_localized("FUSE_ERROR_VAR_NAME_EMPTY", ...)
        finished.emit(); return

    var current = VariableOperations.get_variable(context, variable_name, variable_scope, null)
    if current == null:
        # 如果不存在，初始化为 0 然后加
        current = 0

    var increment: Variant = add_value
    if use_variable and not add_variable.is_empty():
        increment = VariableOperations.get_variable(context, add_variable, BaseVariable.VariableScope.LOCAL, 0)

    var new_value: Variant
    if current is int and increment is int:
        new_value = current + increment
    elif current is float or increment is float:
        new_value = float(current) + float(increment)
    elif current is Vector2:
        if increment is Vector2:
            new_value = current + increment
        else:
            new_value = current + Vector2(float(increment), float(increment))
    elif current is Vector3:
        if increment is Vector3:
            new_value = current + increment
        else:
            new_value = current + Vector3(float(increment), float(increment), float(increment))
    else:
        new_value = float(current) + float(increment)

    VariableOperations.set_variable(context, variable_name, new_value, variable_scope)
    _log_info_localized("FUSE_LOG_VARIABLE_ADDED", {"name": variable_name, "amount": str(increment), "result": str(new_value)})
    _on_execution_completed()
```

##### 翻译键设计

| 键 | zh_CN | en_US |
|----|-------|-------|
| `FUSE_INSTRUCTION_ADD_VARIABLE_NAME` | 增加变量 | Add Variable |
| `FUSE_INSTRUCTION_ADD_VARIABLE_DESC` | 对变量执行加法运算 | Performs addition on a variable |
| `FUSE_INSTRUCTION_ADD_VARIABLE_RESOURCE_NAME` | 增加: [{scope}] {name} + {amount} | Add: [{scope}] {name} + {amount} |
| `FUSE_INSTRUCTION_ADD_VARIABLE_DESCRIPTION` | [{scope}] {name} + {amount} = {result} | [{scope}] {name} + {amount} = {result} |
| `FUSE_LOG_VARIABLE_ADDED` | {name} + {amount} = {result} | {name} + {amount} = {result} |

##### 图标

`builtin_icon`: `"Add"`

---

#### 4.4.2 MouseWorldPosition (指令)

**文件:** `addons/fuse/instructions/system/mouse_world_position.gd`
**类名:** `MouseWorldPosition`
**基类:** `BaseInstruction`
**分类:** system
**复杂度:** 低 (0.5h)

##### 功能描述
获取鼠标在 2D 世界中的位置并保存到变量。

##### 参数定义

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `camera_node` | NodePath | `NodePath("")` | Camera2D 节点 (空 = 使用当前 viewport camera) |
| `save_to_variable` | String | `""` | 保存鼠标世界坐标到变量 |

##### 核心逻辑

```gdscript
func execute(context: ExecutionContext):
    _start_execution(context)

    if save_to_variable.is_empty():
        set_error_localized("FUSE_ERROR_VAR_NAME_EMPTY", ...)
        finished.emit(); return

    var viewport: Viewport
    if context.has_node("."):
        var root = context.get_node(".")
        if root:
            viewport = root.get_viewport()

    if not viewport:
        set_error_localized("FUSE_ERROR_VIEWPORT_NOT_FOUND", ...)
        finished.emit(); return

    var camera: Camera2D
    if not camera_node.is_empty():
        camera = context.get_node(camera_node) as Camera2D

    var mouse_pos = viewport.get_mouse_position()
    var world_pos: Vector2 = mouse_pos

    if camera:
        world_pos = camera.get_screen_center() + (mouse_pos - viewport.get_visible_rect().size / 2.0) / camera.zoom
    else:
        var canvas_transform = viewport.canvas_transform
        world_pos = canvas_transform.affine_inverse() * mouse_pos

    VariableOperations.set_variable(context, save_to_variable, world_pos, BaseVariable.VariableScope.LOCAL)
    _log_info_localized("FUSE_LOG_MOUSE_WORLD_POS", {"pos": str(world_pos), "var": save_to_variable})
    _on_execution_completed()
```

##### 翻译键设计

| 键 | zh_CN | en_US |
|----|-------|-------|
| `FUSE_INSTRUCTION_MOUSE_WORLD_POS_NAME` | 鼠标世界坐标 | Mouse World Position |
| `FUSE_INSTRUCTION_MOUSE_WORLD_POS_DESC` | 获取鼠标在 2D 世界中的坐标并保存到变量 | Gets the mouse position in 2D world coordinates and saves to a variable |
| `FUSE_INSTRUCTION_MOUSE_WORLD_POS_RESOURCE_NAME` | 鼠标坐标 → {var} | Mouse Pos → {var} |
| `FUSE_INSTRUCTION_MOUSE_WORLD_POS_DESCRIPTION` | 保存鼠标世界坐标到 {var} | Save mouse world position to {var} |
| `FUSE_LOG_MOUSE_WORLD_POS` | 鼠标世界坐标 = {pos} → {var} | Mouse world pos = {pos} → {var} |

##### 图标

`builtin_icon`: `"Mouse"`

---

#### 4.4.3 CheckIsOnScreen (条件)

**文件:** `addons/fuse/conditions/rendering/check_is_on_screen.gd`
**类名:** `CheckIsOnScreen`
**基类:** `BaseCondition`
**分类:** rendering
**复杂度:** 低 (0.5h)

##### 功能描述
检查节点是否在屏幕视口内可见。基于 VisibleOnScreenNotifier2D/3D 或手动计算。

##### 参数定义

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `target_node` | NodePath | `NodePath("")` | 要检查的节点 |
| `use_notifier` | bool | `true` | 是否使用 VisibleOnScreenNotifier (true) 或手动计算 (false) |
| `margin` | float | `0.0` | 视口边缘余量 (手动模式, 正值为向内收缩) |

##### 核心逻辑

```gdscript
func _evaluate_condition(context: ExecutionContext) -> bool:
    if target_node.is_empty():
        return false

    var node := context.get_node(target_node)
    if not node:
        return false

    # 方式 1: 使用 VisibleOnScreenNotifier
    if use_notifier:
        if node is VisibleOnScreenNotifier2D:
            return (node as VisibleOnScreenNotifier2D).is_on_screen()
        elif node is VisibleOnScreenNotifier3D:
            return (node as VisibleOnScreenNotifier3D).is_on_screen()
        elif node is CanvasItem:
            # CanvasItem 的 visible 属性基本对应
            return (node as CanvasItem).visible and (node as CanvasItem).is_visible_in_tree()
        return false

    # 方式 2: 手动计算 (基于 viewport bounds)
    var viewport = node.get_viewport()
    if not viewport:
        return false

    var transform = viewport.get_final_transform()
    var screen_size = viewport.get_visible_rect().size

    var pos: Vector2
    if node is Node2D:
        pos = transform * (node as Node2D).global_position
    elif node is Node3D:
        var cam = viewport.get_camera_3d()
        if cam:
            pos = cam.unproject_position((node as Node3D).global_position)
        else:
            return false
    elif node is Control:
        pos = (node as Control).global_position
    else:
        return false

    return pos.x >= -margin and pos.x <= screen_size.x + margin and \
           pos.y >= -margin and pos.y <= screen_size.y + margin
```

##### 翻译键设计

| 键 | zh_CN | en_US |
|----|-------|-------|
| `FUSE_CONDITION_CHECK_IS_ON_SCREEN_NAME` | 检查是否在屏幕上 | Check Is On Screen |
| `FUSE_CONDITION_CHECK_IS_ON_SCREEN_DESC` | 检查节点是否在屏幕视口内可见 | Checks if a node is visible within the screen viewport |
| `FUSE_CONDITION_CHECK_IS_ON_SCREEN_FORMAT` | 屏幕可见: {node} | On Screen: {node} |
| `FUSE_CONDITION_CHECK_IS_ON_SCREEN_DESCRIPTION` | {node} 在屏幕上 | {node} is on screen |
| `FUSE_CONDITION_CHECK_IS_ON_SCREEN_NOT` | {node} 不在屏幕上 | {node} is not on screen |

##### 图标

`builtin_icon`: `"VisibleOnScreenNotifier2D"`

---

### 4.5 批量 E: 渲染/导航/输入组件

#### 4.5.1 SetMaterialProperty (指令)

**文件:** `addons/fuse/instructions/rendering/set_material_property.gd`
**类名:** `SetMaterialProperty`
**基类:** `BaseInstruction`
**分类:** rendering
**复杂度:** 中 (1h)

##### 功能描述
设置节点材质的 shader 参数。支持 CanvasItem 和 MeshInstance3D。

##### 参数定义

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `target_node` | NodePath | `NodePath("")` | 目标节点 (CanvasItem 或 MeshInstance3D) |
| `material_slot` | enum (MaterialSlot) | `MATERIAL_0` | 材质槽位 |
| `parameter_name` | String | `""` | shader 参数名 |
| `parameter_type` | enum (ParamType) | `FLOAT` | 参数类型: `FLOAT`, `COLOR`, `VEC2`, `VEC3`, `BOOL`, `INT` |
| `float_value` | float | `0.0` | 浮点值 |
| `color_value` | Color | `Color.WHITE` | 颜色值 |
| `vec2_value` | Vector2 | `Vector2.ZERO` | Vector2 值 |
| `vec3_value` | Vector3 | `Vector3.ZERO` | Vector3 值 |
| `bool_value` | bool | `false` | 布尔值 |
| `int_value` | int | `0` | 整数值 |

##### 核心逻辑

```gdscript
func execute(context: ExecutionContext):
    _start_execution(context)

    if target_node.is_empty() or parameter_name.is_empty():
        set_error_localized("FUSE_ERROR_MISSING_PARAMETER", ...)
        finished.emit(); return

    var node := context.get_node(target_node)
    if not node:
        set_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", ...)
        finished.emit(); return

    var material: Material
    if node is CanvasItem:
        var canvas := node as CanvasItem
        material = canvas.material
    elif node is MeshInstance3D:
        var mesh := node as MeshInstance3D
        match material_slot:
            MaterialSlot.SURFACE_0:
                material = mesh.get_surface_override_material(0)
            MaterialSlot.SURFACE_1:
                material = mesh.get_surface_override_material(1)
            _:
                material = mesh.material_override
    else:
        set_error_localized("FUSE_ERROR_NODE_TYPE_INVALID", ...)
        finished.emit(); return

    if not material or not (material is ShaderMaterial):
        set_error_localized("FUSE_ERROR_NO_SHADER_MATERIAL", ...)
        finished.emit(); return

    var shader_mat := material as ShaderMaterial
    var value: Variant
    match parameter_type:
        ParamType.FLOAT: value = float_value
        ParamType.COLOR: value = color_value
        ParamType.VEC2:  value = vec2_value
        ParamType.VEC3:  value = vec3_value
        ParamType.BOOL:  value = bool_value
        ParamType.INT:   value = int_value

    shader_mat.set_shader_parameter(parameter_name, value)
    _log_info_localized("FUSE_LOG_MATERIAL_PARAM_SET", {"param": parameter_name, "value": str(value)})
    _on_execution_completed()
```

##### 翻译键设计

| 键 | zh_CN | en_US |
|----|-------|-------|
| `FUSE_INSTRUCTION_SET_MATERIAL_PROPERTY_NAME` | 设置材质属性 | Set Material Property |
| `FUSE_INSTRUCTION_SET_MATERIAL_PROPERTY_DESC` | 设置节点材质的 shader 参数 | Sets a shader parameter on a node's material |
| `FUSE_INSTRUCTION_SET_MATERIAL_PROPERTY_RESOURCE_NAME` | 材质: {target}.{param} = {value} | Material: {target}.{param} = {value} |
| `FUSE_INSTRUCTION_SET_MATERIAL_PROPERTY_DESCRIPTION` | 设置 {target} 材质参数 {param} = {value} | Set {target} material param {param} = {value} |
| `FUSE_LOG_MATERIAL_PARAM_SET` | 设置材质参数 {param} = {value} | Set material param {param} = {value} |
| `FUSE_ERROR_NO_SHADER_MATERIAL` | 目标节点没有 ShaderMaterial | Target node has no ShaderMaterial |

##### 图标

`builtin_icon`: `"ShaderMaterial"`

---

#### 4.5.2 NavigateToPosition (指令)

**文件:** `addons/fuse/instructions/navigation/navigate_to_position.gd`
**类名:** `NavigateToPosition`
**基类:** `BaseInstruction`
**分类:** navigation
**复杂度:** 高 (1.5h)

##### 功能描述
使用 NavigationAgent2D / NavigationAgent3D 将节点导航到目标位置。异步操作 — 监听 navigation_finished 信号。

##### 参数定义

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `agent_node` | NodePath | `NodePath("")` | NavigationAgent2D/3D 节点 |
| `target_position` | Vector2 | `Vector2.ZERO` | 目标位置 (2D) |
| `target_position_3d` | Vector3 | `Vector3.ZERO` | 目标位置 (3D) |
| `use_3d` | bool | `false` | 是否使用 3D 导航 |
| `target_from_variable` | bool | `false` | 从变量读取目标位置 |
| `target_variable` | String | `""` | 目标位置变量名 |

##### 方法签名

```gdscript
static func _get_instruction_metadata() -> InstructionMetadata
func execute(context: ExecutionContext)
func validate() -> Array[String]
func get_description() -> String
func cancel()
func _cleanup_resources()
```

##### 核心逻辑

```gdscript
# 异步执行 — 需要在 _init 声明
func _init():
    _is_synchronous_hint = false
    _sync_hint_manually_set = true

func execute(context: ExecutionContext):
    _start_execution(context)

    if agent_node.is_empty():
        set_error_localized("FUSE_ERROR_TARGET_NODE_EMPTY", ...)
        finished.emit(); return

    var agent := context.get_node(agent_node)
    if not agent:
        set_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", ...)
        finished.emit(); return

    var target: Variant
    if target_from_variable and not target_variable.is_empty():
        target = VariableOperations.get_variable(context, target_variable, BaseVariable.VariableScope.LOCAL, null)
    else:
        target = target_position_3d if use_3d else target_position

    # 设置目标并导航
    if use_3d and agent is NavigationAgent3D:
        var ag := agent as NavigationAgent3D
        ag.target_position = target as Vector3
        ag.navigation_finished.connect(_on_navigation_finished, CONNECT_ONE_SHOT)
    elif agent is NavigationAgent2D:
        var ag := agent as NavigationAgent2D
        ag.target_position = target as Vector2
        ag.navigation_finished.connect(_on_navigation_finished, CONNECT_ONE_SHOT)
    else:
        set_error_localized("FUSE_ERROR_NODE_TYPE_INVALID", ...)
        finished.emit(); return

    _log_info_localized("FUSE_LOG_NAVIGATION_STARTED", {"target": str(target)})

func _on_navigation_finished():
    _log_info_localized("FUSE_LOG_NAVIGATION_FINISHED", {})
    _on_execution_completed()
```

##### 运行时实例支持

```gdscript
func get_default_runtime_state() -> Dictionary:
    var state = super.get_default_runtime_state()
    state["agent_node"] = agent_node
    state["is_navigating"] = false
    return state
```

##### 翻译键设计

| 键 | zh_CN | en_US |
|----|-------|-------|
| `FUSE_INSTRUCTION_NAVIGATE_TO_POS_NAME` | 导航到位置 | Navigate to Position |
| `FUSE_INSTRUCTION_NAVIGATE_TO_POS_DESC` | 使用 NavigationAgent 导航到目标位置 | Navigates to a target position using NavigationAgent |
| `FUSE_INSTRUCTION_NAVIGATE_TO_POS_RESOURCE_NAME` | 导航: {agent} → {target} | Navigate: {agent} → {target} |
| `FUSE_INSTRUCTION_NAVIGATE_TO_POS_DESCRIPTION` | 导航 {agent} 到 {target} | Navigate {agent} to {target} |
| `FUSE_LOG_NAVIGATION_STARTED` | 开始导航到 {target} | Started navigating to {target} |
| `FUSE_LOG_NAVIGATION_FINISHED` | 导航已完成 | Navigation finished |

##### 图标

`builtin_icon`: `"NavigationAgent2D"`

---

#### 4.5.3 OnInputBuffered (事件)

**文件:** `addons/fuse/events/input/on_input_buffered.gd`
**类名:** `OnInputBuffered`
**基类:** `BaseEvent`
**分类:** input
**复杂度:** 中 (1h)

##### 功能描述
监听输入动作并在输入缓冲窗口内触发。支持多个输入动作、缓冲时间窗口、优先级排序。

##### 参数定义

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `input_actions` | Array[String] | `[]` | 要监听的输入动作名列表 |
| `buffer_window` | float | `0.15` | 缓冲时间窗口 (秒) |
| `consume_input` | bool | `true` | 是否消耗输入事件 |
| `priority` | int | `0` | 优先级 (越高越先处理) |

##### 方法签名

```gdscript
static func _get_event_metadata() -> EventMetadata
func initialize(owner_node: Node) -> void
func initialize_with_runtime_instance(owner_node: Node, runtime_instance: RuntimeEventInstance) -> void
func terminate(owner_node: Node) -> void
func handle_input(event: InputEvent) -> void
func get_default_runtime_state() -> Dictionary
func validate() -> Array[String]
```

##### 核心逻辑

```gdscript
func initialize(owner_node: Node) -> void:
    if not owner_node:
        _create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NULL", ...)
        return
    _owner_node_ref = owner_node

    # 验证输入动作
    if input_actions.is_empty():
        _create_fuse_error_localized("FUSE_ERROR_MISSING_PARAMETER", {"parameter": "input_actions"}, ...)
        return

    for action in input_actions:
        if not InputMap.has_action(action):
            _create_fuse_error_localized("FUSE_ERROR_INPUT_ACTION_NOT_FOUND", {"action": action})

    _log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

func initialize_with_runtime_instance(owner_node: Node, runtime_instance: RuntimeEventInstance) -> void:
    if Engine.is_editor_hint():
        return
    _runtime_instance_ref = runtime_instance
    initialize(owner_node)

func terminate(owner_node: Node) -> void:
    if _runtime_instance_ref:
        _runtime_instance_ref.set_runtime_state("buffered_inputs", [])
    _owner_node_ref = null

func handle_input(event: InputEvent) -> void:
    if not event is InputEventAction and not event is InputEventKey:
        return

    var action_name = ""
    if event is InputEventAction:
        action_name = (event as InputEventAction).action
    elif event is InputEventKey:
        # 查找关联的动作
        for action in input_actions:
            if InputMap.event_is_action(event, action):
                action_name = action
                break

    if action_name.is_empty() or not action_name in input_actions:
        return

    # 获取运行时状态中的缓冲列表
    var buffered_inputs: Array
    if _runtime_instance_ref:
        buffered_inputs = _runtime_instance_ref.runtime_state.get("buffered_inputs", [])

    # 记录输入时间戳
    buffered_inputs.append({
        "action": action_name,
        "timestamp": Time.get_ticks_msec() / 1000.0,
        "pressed": event.is_pressed()
    })

    if _runtime_instance_ref:
        _runtime_instance_ref.runtime_state["buffered_inputs"] = buffered_inputs

    # 在下一帧/定时检查时处理缓冲
    _process_buffer()

func _process_buffer() -> void:
    var buffered_inputs: Array
    if _runtime_instance_ref:
        buffered_inputs = _runtime_instance_ref.runtime_state.get("buffered_inputs", [])

    var current_time = Time.get_ticks_msec() / 1000.0
    var valid_inputs: Array = []
    var triggered := false

    for entry in buffered_inputs:
        if current_time - entry.timestamp <= buffer_window:
            valid_inputs.append(entry)
            if entry.pressed and not triggered:
                triggered = true
                # 触发事件
                if _runtime_instance_ref:
                    _runtime_instance_ref.update_trigger_stats()

                if _owner_node_ref:
                    var context_node = Node.new()
                    context_node.name = "InputBufferedContext"
                    context_node.set_meta("trigger", _owner_node_ref)
                    context_node.set_meta("input_action", entry.action)
                    triggered.emit(context_node)
                    context_node.queue_free()

    # 更新缓冲（移除过期的）
    if _runtime_instance_ref:
        _runtime_instance_ref.runtime_state["buffered_inputs"] = valid_inputs
```

##### 运行时状态

```gdscript
func get_default_runtime_state() -> Dictionary:
    var base = super.get_default_runtime_state()
    base["buffered_inputs"] = []  # Array[Dictionary]
    base["last_processed_time"] = 0.0
    return base
```

##### 翻译键设计

| 键 | zh_CN | en_US |
|----|-------|-------|
| `FUSE_EVENT_ON_INPUT_BUFFERED_NAME` | 输入缓冲 | Input Buffered |
| `FUSE_EVENT_ON_INPUT_BUFFERED_DESC` | 在缓冲窗口内检测输入动作并触发事件 | Detects input actions within a buffer window and triggers |
| `FUSE_EVENT_ON_INPUT_BUFFERED_RESOURCE_NAME` | 输入缓冲: {actions} ({window}s) | Input Buffer: {actions} ({window}s) |
| `FUSE_EVENT_ON_INPUT_BUFFERED_DESCRIPTION` | 缓冲检测 {actions} (窗口={window}s) | Buffered {actions} (window={window}s) |
| `FUSE_ERROR_INPUT_ACTION_NOT_FOUND` | 输入动作 "{action}" 不在 InputMap 中 | Input action "{action}" not found in InputMap |

##### 图标

`builtin_icon`: `"InputEventAction"`

---

## 5. 新目录规划

### 5.1 需创建的目录

| 目录 | 用途 | 包含组件 |
|------|------|----------|
| `instructions/rendering/` | 渲染相关指令 | `SetMaterialProperty` |
| `instructions/navigation/` | 导航相关指令 | `NavigateToPosition` |
| `conditions/rendering/` | 渲染相关条件 | `CheckIsOnScreen` |

### 5.2 现有目录中新增

| 目录 | 新增组件 |
|------|----------|
| `instructions/physics/` | `SetGravityScale`, `EnableDisableCollision`, `SetCollisionMask` |
| `instructions/animation/` | `SetAnimationTreeParameter`, `SetSpriteFlip` |
| `instructions/variables/` | `AddVariable`, `ToggleVariable` |
| `instructions/ui/` | `SetUIColor` |
| `instructions/node_operations/` | `SetProcessMode` |
| `instructions/system/` | `MouseWorldPosition` |
| `conditions/physics/` | `CheckOverlapArea` |
| `events/input/` | `OnInputBuffered` |

### 5.3 组件扫描验证

`FuseComponentScanner` 对 `instructions/` 目录递归扫描, 新目录 (`rendering/`, `navigation/`) 会自动被发现。无需修改扫描器代码。

**验证方法:**
1. 创建新目录和 `.gd` 文件
2. 重载插件 → 检查输出日志: `FuseComponentScanner` 应报告扫描到的组件数增加
3. 在编辑器指令/事件/条件选择器中验证新组件可见

---

## 6. 翻译键设计

### 6.1 命名规范

```
FUSE_{TYPE}_{COMPONENT}_{PURPOSE}
```

| 段 | 说明 | 示例 |
|----|------|------|
| `FUSE_` | 统一前缀 | `FUSE_` |
| `{TYPE}` | 组件类型 | `INSTRUCTION`, `EVENT`, `CONDITION`, `CATEGORY`, `ERROR`, `LOG`, `ENUM` |
| `{COMPONENT}` | 组件标识 (大写下划线) | `SET_GRAVITY_SCALE`, `CHECK_OVERLAP_AREA` |
| `{PURPOSE}` | 用途标识 | `NAME`, `DESC`, `RESOURCE_NAME`, `DESCRIPTION`, `FORMAT` |

### 6.2 新增翻译条目统计

| 组件 | 翻译条目数 |
|------|:--:|
| SetGravityScale | 6 |
| EnableDisableCollision | 8 |
| SetCollisionMask | 6 |
| CheckOverlapArea | 7 |
| SetAnimationTreeParameter | 6 |
| SetSpriteFlip | 8 |
| AddVariable | 6 |
| ToggleVariable | 6 |
| SetUIColor | 6 |
| SetMaterialProperty | 7 |
| CheckIsOnScreen | 6 |
| NavigateToPosition | 7 |
| OnInputBuffered | 7 |
| SetProcessMode | 10 |
| MouseWorldPosition | 6 |
| **总计** | **~102** |

### 6.3 新增分类键

| 键 | zh_CN | en_US |
|----|-------|-------|
| `FUSE_CATEGORY_RENDERING` | 渲染 | Rendering |
| `FUSE_CATEGORY_NAVIGATION` | 导航 | Navigation |
| `FUSE_EVENT_CATEGORY_INPUT` | 输入 | Input (已存在,验证) |

### 6.4 CSV 追加位置

在 `addons/fuse/localization/translations.csv` 末尾追加新条目, 格式:

```csv
FUSE_INSTRUCTION_SET_GRAVITY_SCALE_NAME,设置重力缩放,Set Gravity Scale
FUSE_INSTRUCTION_SET_GRAVITY_SCALE_DESC,设置物理体的重力缩放值,Sets the gravity scale of a physics body
...
```

追加后运行 Godot 编辑器重新导入 `.translation` 文件:
1. 打开 Godot 编辑器
2. `translations.csv` → 重新导入 (或使用 CLI: `godot --import`)
3. 验证: `FuseLocalization.translate("FUSE_INSTRUCTION_SET_GRAVITY_SCALE_NAME")` 返回预期值

---

## 7. 验证清单

### 7.1 开发期验证

- [ ] 每个 `.gd` 文件通过 `gdscript-validate` (语法/类型检查)
- [ ] `_get_*_metadata()` 返回有效元数据 (name_key 非空, category_key 指向已注册分类)
- [ ] 文件命名规范: `snake_case.gd`, class_name 使用 `PascalCase`
- [ ] icon 设置正确 (`metadata.builtin_icon` 或 `@icon()`)
- [ ] `_update_resource_name()` 使用 FuseLocalization 设置 resource_name
- [ ] 验证方法 `validate()` 返回 `Array[String]`
- [ ] 核心方法参数类型注解完整
- [ ] 错误处理使用 `set_error_localized()` + `finished.emit()`
- [ ] 成功路径调用 `_on_execution_completed()`

### 7.2 注册验证

- [ ] 插件重载后 `FuseComponentScanner` 日志显示 15 个新组件成功注册
- [ ] `ComponentRegistry` 无重复名称冲突 (检查 "Duplicate" 日志)
- [ ] 指令选择器 (Inspector) 中可搜索到所有新指令
- [ ] 事件选择器中可搜索到新事件
- [ ] 条件选择器中可搜索到新条件

### 7.3 功能验证

- [ ] `SetGravityScale`: 设置 CharacterBody2D gravity_scale
- [ ] `EnableDisableCollision`: 启用/禁用 CollisionShape2D
- [ ] `SetCollisionMask`: 设置 CollisionObject2D collision_mask
- [ ] `CheckOverlapArea`: Area2D 有重叠体时返回 true
- [ ] `SetAnimationTreeParameter`: 设置 AnimationTree 参数
- [ ] `SetSpriteFlip`: 翻转 Sprite2D h/v
- [ ] `AddVariable`: 给变量加值
- [ ] `ToggleVariable`: 切换布尔变量
- [ ] `SetUIColor`: 设置 Control.modulate
- [ ] `SetMaterialProperty`: 设置 ShaderMaterial 参数
- [ ] `CheckIsOnScreen`: 节点在屏幕内返回 true
- [ ] `NavigateToPosition`: NavigationAgent 导航到目标
- [ ] `OnInputBuffered`: 缓冲窗口内检测输入
- [ ] `SetProcessMode`: 设置 node.process_mode
- [ ] `MouseWorldPosition`: 获取鼠标世界坐标

### 7.4 翻译验证

- [ ] 所有 `FUSE_INSTRUCTION_*`, `FUSE_EVENT_*`, `FUSE_CONDITION_*` 键在 CSV 中有对应条目
- [ ] zh_CN 和 en_US 翻译均完整
- [ ] `FuseLocalization.translate()` 返回非键值 (即翻译成功)
- [ ] 在编辑器中切换语言后 resource_name 自动更新

### 7.5 回归验证

- [ ] 现有 129 指令 / 65 事件 / 43 条件功能不受影响
- [ ] `ExecutionContext` 三层门面稳定
- [ ] 组件扫描器仍正确注册所有已有组件
- [ ] `GlobalVariableService` 在 `AddVariable`/`ToggleVariable` 中正常工作

---

## 8. 文件清单

### 8.1 新增文件 (18 个 .gd + 2 个 .uid)

```
addons/fuse/instructions/physics/set_gravity_scale.gd
addons/fuse/instructions/physics/set_gravity_scale.gd.uid
addons/fuse/instructions/physics/enable_disable_collision.gd
addons/fuse/instructions/physics/enable_disable_collision.gd.uid
addons/fuse/instructions/physics/set_collision_mask.gd
addons/fuse/instructions/physics/set_collision_mask.gd.uid
addons/fuse/instructions/animation/set_animation_tree_parameter.gd
addons/fuse/instructions/animation/set_animation_tree_parameter.gd.uid
addons/fuse/instructions/animation/set_sprite_flip.gd
addons/fuse/instructions/animation/set_sprite_flip.gd.uid
addons/fuse/instructions/variables/add_variable.gd
addons/fuse/instructions/variables/add_variable.gd.uid
addons/fuse/instructions/variables/toggle_variable.gd
addons/fuse/instructions/variables/toggle_variable.gd.uid
addons/fuse/instructions/ui/set_ui_color.gd
addons/fuse/instructions/ui/set_ui_color.gd.uid
addons/fuse/instructions/rendering/set_material_property.gd
addons/fuse/instructions/rendering/set_material_property.gd.uid
addons/fuse/instructions/navigation/navigate_to_position.gd
addons/fuse/instructions/navigation/navigate_to_position.gd.uid
addons/fuse/instructions/node_operations/set_process_mode.gd
addons/fuse/instructions/node_operations/set_process_mode.gd.uid
addons/fuse/instructions/system/mouse_world_position.gd
addons/fuse/instructions/system/mouse_world_position.gd.uid
addons/fuse/conditions/physics/check_overlap_area.gd
addons/fuse/conditions/physics/check_overlap_area.gd.uid
addons/fuse/conditions/rendering/check_is_on_screen.gd
addons/fuse/conditions/rendering/check_is_on_screen.gd.uid
addons/fuse/events/input/on_input_buffered.gd
addons/fuse/events/input/on_input_buffered.gd.uid
```

### 8.2 需创建的新目录 (2 个)

```
addons/fuse/instructions/rendering/
addons/fuse/instructions/navigation/
addons/fuse/conditions/rendering/
```

### 8.3 需修改的文件 (1 个)

```
addons/fuse/localization/translations.csv  — 追加约 102 条翻译
```

> `.translation` 文件通过 CSV 重新导入生成, 不需要手动编辑。

---

## 附录 A: 组件复杂度分级

| 复杂度 | 特征 | 本批次组件 |
|:---:|------|------|
| **低** | 单一节点操作, 1-2 个参数, 同步执行, < 80 行 | SetGravityScale, EnableDisableCollision, SetCollisionMask, SetSpriteFlip, AddVariable, ToggleVariable, SetUIColor, CheckIsOnScreen, SetProcessMode, MouseWorldPosition (10 个) |
| **中** | 多参数/条件显示, 50-150 行 | SetAnimationTreeParameter, CheckOverlapArea, SetMaterialProperty, OnInputBuffered (4 个) |
| **高** | 异步执行, 信号回调, > 150 行 | NavigateToPosition (1 个) |

## 附录 B: 关键 Godot API 引用

| 组件 | 关键 API |
|------|----------|
| SetGravityScale | `CharacterBody2D.gravity_scale`, `RigidBody2D.gravity_scale` |
| EnableDisableCollision | `CollisionShape2D.set_deferred("disabled", ...)`, `Area2D.monitoring` |
| SetCollisionMask | `CollisionObject2D.collision_mask` |
| CheckOverlapArea | `Area2D.get_overlapping_bodies()`, `Area2D.get_overlapping_areas()` |
| SetAnimationTreeParameter | `AnimationTree.set("parameters/...", value)` |
| SetSpriteFlip | `Sprite2D.flip_h`, `Sprite2D.flip_v`, `AnimatedSprite2D.flip_h` |
| AddVariable | `VariableOperations.get_variable()` / `set_variable()` |
| ToggleVariable | `VariableOperations.get_variable()` / `set_variable()` |
| SetUIColor | `Control.modulate`, `Control.self_modulate` |
| SetMaterialProperty | `ShaderMaterial.set_shader_parameter()` |
| CheckIsOnScreen | `VisibleOnScreenNotifier2D.is_on_screen()`, viewport transform |
| NavigateToPosition | `NavigationAgent2D.target_position`, `NavigationAgent2D.navigation_finished` |
| OnInputBuffered | `InputMap.has_action()`, `InputMap.event_is_action()` |
| SetProcessMode | `Node.process_mode` (Node.ProcessMode enum) |
| MouseWorldPosition | `Viewport.get_mouse_position()`, `Viewport.canvas_transform` |

## 附录 C: 图标资源映射

| 组件 | builtin_icon | 图标含义 |
|------|-------------|----------|
| SetGravityScale | `RigidBody2D` | 物理体 |
| EnableDisableCollision | `CollisionShape2D` | 碰撞形状 |
| SetCollisionMask | `CollisionShape2D` | 碰撞形状 |
| CheckOverlapArea | `Area2D` | 区域 |
| SetAnimationTreeParameter | `AnimationTree` | 动画树 |
| SetSpriteFlip | `Sprite2D` | 精灵 |
| AddVariable | `Add` | 加法 |
| ToggleVariable | `Boolean` | 布尔值 |
| SetUIColor | `ColorRect` | 颜色矩形 |
| SetMaterialProperty | `ShaderMaterial` | 着色器材质 |
| CheckIsOnScreen | `VisibleOnScreenNotifier2D` | 屏幕可见 |
| NavigateToPosition | `NavigationAgent2D` | 导航代理 |
| OnInputBuffered | `InputEventAction` | 输入动作 |
| SetProcessMode | `Node` | 节点 |
| MouseWorldPosition | `Mouse` | 鼠标 |

> 所有图标使用 Fuse 内置图标系统 (`FuseIconManager.get_builtin_icon()`), 指向 `res://addons/fuse/icons/builtin/` 下的 `.svg/.png` 文件。

---

**文档版本:** 1.0
**最后更新:** 2026-06-17
**作者:** Fuse Spec Team
**审核状态:** 待审核
