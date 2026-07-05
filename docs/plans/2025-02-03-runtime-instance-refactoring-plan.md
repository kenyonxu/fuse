# RuntimeInstance 架构重构计划 - 自声明状态模式

**计划日期**: 2026-02-03
**方案类型**: 方案 4（混合方案）- Event 自声明默认状态
**目标**: 实现开闭原则，支持无缝扩展自定义 Events
**预计周期**: 2-3 周

---

## 目录

1. [背景和问题](#背景和问题)
2. [架构设计](#架构设计)
3. [实施计划](#实施计划)
4. [详细步骤](#详细步骤)
5. [测试策略](#测试策略)
6. [风险管理](#风险管理)
7. [验收标准](#验收标准)

---

## 背景和问题

### 当前架构的问题

**现状**:
```gdscript
# RuntimeEventInstance.gd
func _initialize_runtime_state():
    match event_definition.get_event_type():
        "interval":
            runtime_state["current_repeat_count"] = 0
            runtime_state["is_running"] = false
            # ...
        "mouse_button":
            runtime_state["last_click_time"] = 0.0
            runtime_state["click_count"] = 0
            # ...
        # 每个新事件都要添加这里！
```

**核心问题**:
1. ❌ **违反开闭原则** - 每次新增事件都要修改核心代码（RuntimeEventInstance）
2. ❌ **扩展性差** - 用户创建自定义事件必须修改 `RuntimeEventInstance._initialize_runtime_state()`
3. ❌ **维护成本高** - 状态初始化分散在两个地方（Event 类和 RuntimeEventInstance）
4. ❌ **容易遗漏** - 忘记添加初始化会导致运行时错误
5. ❌ **文档同步** - 迁移注释和实际初始化代码可能不一致

### 影响范围

- **内置 Events**: 每新增一个 Event 需要修改核心代码
- **用户自定义 Events**: 用户无法在不修改核心代码的情况下创建事件
- **插件系统**: 第三方插件无法定义独立的 Events
- **测试复杂度**: 每个 Event 需要测试核心代码的修改

---

## 架构设计

### 目标架构

采用 **Event 自声明状态模式**，让每个 Event 负责定义自己的默认运行时状态：

```gdscript
# BaseEvent.gd
## 获取默认运行时状态
##
## 子类重写此方法以声明初始状态
## 返回包含所有状态键和默认值的字典
##
## 示例:
## func get_default_runtime_state() -> Dictionary:
##     var base = super.get_default_runtime_state()
##     base["my_count"] = 0
##     base["is_active"] = false
##     return base
func get_default_runtime_state() -> Dictionary:
    return {
        "initialized": true,
        "trigger_count": 0,
        "last_trigger_time": 0.0
    }

# RuntimeEventInstance.gd
func _initialize_runtime_state():
    if not event_definition:
        _log_warning("没有事件定义，无法初始化运行时状态")
        return

    # 让 Event 自己提供默认状态
    runtime_state = event_definition.get_default_runtime_state().duplicate()

    _log_debug("运行时状态已初始化，事件类型: %s, 状态数量: %d" % [
        event_definition.get_event_type(),
        runtime_state.size()
    ])
```

### 设计原则

1. **开闭原则** - 对扩展开放，对修改关闭
2. **单一职责** - Event 负责定义自己的状态
3. **自描述性** - 状态定义和使用在同一位置
4. **向后兼容** - 现有 Events 逐步迁移
5. **类型安全** - 编译期检查状态键名

---

## 实施计划

### 阶段概览

| 阶段 | 任务 | 预计时间 | 优先级 |
|------|------|---------|--------|
| **Phase 0** | 基础设施准备 | 2 天 | P0 |
| **Phase 1** | BaseEvent 添加 API | 1 天 | P0 |
| **Phase 2** | RuntimeEventInstance 重构 | 1 天 | P0 |
| **Phase 3** | 迁移 10 个已迁移 Events | 3 天 | P1 |
| **Phase 4** | 迁移剩余内置 Events（可选） | 1-2 天 | P2 |
| **Phase 5** | 测试和验证 | 2 天 | P0 |
| **Phase 6** | 文档更新 | 1 天 | P1 |
| **Phase 7** | 清理和优化 | 1 天 | P2 |

**总预计时间**: 12-13 工作日（约 2.5-3 周）

---

## 详细步骤

### Phase 0: 基础设施准备（2 天）

#### 任务 0.1: 创建状态声明文档（0.5 天）

**文件**: `addons/bricks/docs/runtime-state-declaration-guide.md`

**内容**:
- 状态声明最佳实践
- 常见状态类型和默认值
- 迁移检查清单
- 示例代码

**模板**:
```markdown
# Event 运行时状态声明指南

## 声明状态

在 Event 类中重写 `get_default_runtime_state()` 方法：

```gdscript
func get_default_runtime_state() -> Dictionary:
    var base = super.get_default_runtime_state()
    base["my_state"] = default_value
    return base
```

## 常见状态类型

- 计数器: `int = 0`
- 布尔标志: `bool = false`
- 时间戳: `float = 0.0`
- 数组: `Array = []`
- 引用: `Variant = null`
```

#### 任务 0.2: 备份现有代码（0.5 天）

**操作**:
```bash
git checkout -b backup/runtime-state-before-refactor
git push origin backup/runtime-state-before-refactor
```

#### 任务 0.3: 创建测试脚本（1 天）

**文件**: `addons/bricks/tests/runtime_state_validation.gd`

**功能**:
```gdscript
## 验证 Event 是否正确声明运行时状态
func validate_event_state_declaration(event: BaseEvent) -> bool:
    # 1. 检查是否实现了 get_default_runtime_state()
    if not event.has_method("get_default_runtime_state"):
        return false

    # 2. 获取默认状态
    var default_state = event.get_default_runtime_state()

    # 3. 检查必需的基础状态
    if not default_state.has("initialized"):
        return false
    if not default_state.has("trigger_count"):
        return false
    if not default_state.has("last_trigger_time"):
        return false

    # 4. 验证状态值类型
    # ...

    return true
```

---

### Phase 1: BaseEvent 添加 API（1 天）

#### 任务 1.1: 在 BaseEvent 中添加虚方法（0.5 天）

**文件**: `addons/bricks/events/base_event.gd`

**实现**:
```gdscript
## 获取默认运行时状态
##
## 子类重写此方法以声明初始状态。
## 返回包含所有状态键和默认值的字典。
##
## 最佳实践:
## 1. 始终调用 super.get_default_runtime_state() 获取基础状态
## 2. 添加事件特定的状态
## 3. 使用有意义的键名
##
## 示例:
##     func get_default_runtime_state() -> Dictionary:
##         var base = super.get_default_runtime_state()
##         base["my_counter"] = 0
##         base["is_active"] = false
##         return base
##
## 返回:
## - Dictionary: 默认运行时状态字典
func get_default_runtime_state() -> Dictionary:
    return {
        "initialized": true,
        "trigger_count": 0,
        "last_trigger_time": 0.0
    }

## 便捷方法：获取运行时状态（带默认值）
##
## 如果状态不存在，使用提供的默认值
##
## 参数:
## - runtime_instance: RuntimeEventInstance
## - key: String - 状态键
## - default_value: Variant - 默认值
##
## 返回:
## - Variant: 状态值或默认值
func get_runtime_state(runtime_instance: RuntimeEventInstance, key: String, default_value: Variant) -> Variant:
    if runtime_instance and runtime_instance.has_runtime_state(key):
        return runtime_instance.get_runtime_state(key)
    return default_value

## 便捷方法：设置运行时状态（带可选的默认值初始化）
##
## 参数:
## - runtime_instance: RuntimeEventInstance
## - key: String - 状态键
## - value: Variant - 状态值
## - init_if_missing: bool = false - 是否在状态不存在时初始化
## - init_value: Variant = null - 初始值（仅当 init_if_missing=true 时使用）
##
## 返回:
## - bool: 是否成功设置
func set_runtime_state(runtime_instance: RuntimeEventInstance, key: String, value: Variant, init_if_missing: bool = false, init_value: Variant = null) -> bool:
    if not runtime_instance:
        return false

    if not runtime_instance.has_runtime_state(key) and init_if_missing:
        runtime_instance.set_runtime_state(key, init_value)

    runtime_instance.set_runtime_state(key, value)
    return true
```

#### 任务 1.2: 添加状态验证辅助方法（0.5 天）

**实现**:
```gdscript
## 验证运行时状态声明
##
## 在开发期间验证状态声明是否正确
##
## 返回:
## - Array[String]: 错误信息列表（空数组表示无错误）
func validate_runtime_state_declaration() -> Array[String]:
    var errors: Array[String] = []

    var default_state = get_default_runtime_state()

    # 检查必需的基础状态
    if not default_state.has("initialized"):
        errors.append("缺少必需状态: 'initialized'")

    if not default_state.has("trigger_count"):
        errors.append("缺少必需状态: 'trigger_count'")

    if not default_state.has("last_trigger_time"):
        errors.append("缺少必需状态: 'last_trigger_time'")

    # 检查状态值类型
    if default_state.has("trigger_count") and not typeof(default_state["trigger_count"]) == TYPE_INT:
        errors.append("'trigger_count' 必须是 int 类型")

    # ...

    return errors
```

---

### Phase 2: RuntimeEventInstance 重构（1 天）

#### 任务 2.1: 修改 _initialize_runtime_state() 方法（0.5 天）

**文件**: `addons/bricks/core/runtime_event_instance.gd`

**实现**:
```gdscript
## 初始化运行时状态
##
## 根据事件类型初始化特定的运行时状态
## 现在优先使用 Event 提供的默认状态
func _initialize_runtime_state():
    if not event_definition:
        _log_warning("没有事件定义，无法初始化运行时状态")
        return

    # 🔧 新架构：优先使用 Event 自声明的默认状态
    if event_definition.has_method("get_default_runtime_state"):
        runtime_state = event_definition.get_default_runtime_state().duplicate(true)
        _log_debug("使用 Event 自声明状态初始化，事件类型: %s，状态数量: %d" % [
            event_definition.get_event_type(),
            runtime_state.size()
        ])
    else:
        # ⚠️ 后备方案：使用旧的 match 语句（向后兼容）
        _initialize_runtime_state_legacy()
        _log_warning("Event %s 未实现 get_default_runtime_state()，使用旧模式初始化" % event_definition.get_event_type())

    # 🔧 确保基础状态存在
    _ensure_base_states()

    _log_debug("运行时状态已初始化，事件类型: %s" % event_definition.get_event_type())

## 确保基础状态存在
##
## 无论 Event 是否声明，都确保这些基础状态存在
func _ensure_base_states():
    if not runtime_state.has("initialized"):
        runtime_state["initialized"] = true
    if not runtime_state.has("trigger_count"):
        runtime_state["trigger_count"] = 0
    if not runtime_state.has("last_trigger_time"):
        runtime_state["last_trigger_time"] = 0.0

## 旧模式初始化（向后兼容）
##
## 保留旧的 match 语句作为后备方案
func _initialize_runtime_state_legacy():
    match event_definition.get_event_type():
        "mouse_enter":
            runtime_state["is_hovered"] = false
            runtime_state["initialized"] = true
            runtime_state["trigger_count"] = 0
            runtime_state["last_trigger_time"] = 0.0
        "mouse_exit":
            runtime_state["has_exited"] = false
            runtime_state["initialized"] = true
            runtime_state["trigger_count"] = 0
            runtime_state["last_trigger_time"] = 0.0
        # ... 保留所有现有的初始化
        _:
            # 默认状态
            runtime_state["initialized"] = true
            runtime_state["trigger_count"] = 0
            runtime_state["last_trigger_time"] = 0.0
```

#### 任务 2.2: 添加状态验证和调试方法（0.5 天）

**实现**:
```gdscript
## 验证运行时状态完整性
##
## 检查 Event 声明的状态是否与实际使用的状态一致
##
## 返回:
## - bool: 是否验证通过
func validate_runtime_state() -> bool:
    if not event_definition:
        return false

    # 如果 Event 实现了验证方法，使用它
    if event_definition.has_method("validate_runtime_state_declaration"):
        var errors = event_definition.validate_runtime_state_declaration()
        if errors.size() > 0:
            _log_error("运行时状态验证失败:")
            for error in errors:
                _log_error("  - %s" % error)
            return false

    return true

## 获取运行时状态报告
##
## 返回状态的详细信息（用于调试）
##
## 返回:
## - Dictionary: 状态报告
func get_runtime_state_report() -> Dictionary:
    return {
        "event_type": event_definition.get_event_type() if event_definition else "unknown",
        "state_count": runtime_state.size(),
        "states": runtime_state.duplicate(),
        "has_custom_declaration": event_definition.has_method("get_default_runtime_state") if event_definition else false
    }
```

---

### Phase 3: 迁移内置 Events - 第一批（已迁移 Events，3 天）

**本批目标**: 将已完成 RuntimeInstance 迁移的 10 个 Events 重构为自声明状态模式

**迁移列表**（按原迁移优先级）:

| Event | 状态变量数 | 复杂度 | 文件路径 |
|-------|----------|--------|---------|
| OnInterval | 6 | ⭐⭐⭐⭐ | `events/lifecycle/on_interval.gd` |
| OnInputKey | 2 | ⭐⭐ | `events/input/on_input_key.gd` |
| OnTimer | 1 | ⭐⭐ | `events/timing/on_timer.gd` |
| OnArea2DEnter | 1 | ⭐⭐ | `events/physics/on_area_2d_enter.gd` |
| OnArea3DEntered | 1 | ⭐⭐ | `events/physics/on_area_3d_entered.gd` |
| OnSignalFromGroup | 2 | ⭐⭐ | `events/node/on_signal_from_group.gd` |
| OnPropertyChanged | 3 | ⭐⭐⭐ | `events/node/on_property_changed.gd` |
| OnVariableChanged | 3 | ⭐⭐⭐ | `events/variable/on_variable_changed.gd` |
| OnMouseButton | 2 | ⭐⭐⭐ | `events/input/on_mouse_button.gd` |
| OnCooldownFinished | 3 | ⭐⭐⭐⭐ | `events/timing/on_cooldown_finished.gd` |
| **OnMouseEnter** | 1 | ⭐⭐ | `events/input/on_mouse_enter.gd` |
| **OnMouseExit** | 1 | ⭐⭐ | `events/input/on_mouse_exit.gd` |

**总计**: 12 个 Events（26 个状态变量）

#### 任务 3.1: 迁移 OnTimer（0.25 天）

**文件**: `addons/bricks/events/timing/on_timer.gd`

**修改**:
```gdscript
## 迁移到 RuntimeInstance: 2026-02-03
## 状态变量:
## - _current_repeat_count: int - 当前重复次数
##
## 相关文档: addons/bricks/docs/migration-guide-to-runtime-instance.md

# ... 现有代码 ...

## 获取默认运行时状态
func get_default_runtime_state() -> Dictionary:
    var base = super.get_default_runtime_state()
    base["current_repeat_count"] = 0
    return base
```

**验证**:
- [ ] 状态正确初始化
- [ ] 重复计数功能正常
- [ ] reset() 正确重置状态
- [ ] terminate() 正确清理状态

#### 任务 3.2: 迁移 OnInputKey（0.5 天）

**文件**: `addons/bricks/events/input/on_input_key.gd`

**修改**:
```gdscript
## 获取默认运行时状态
func get_default_runtime_state() -> Dictionary:
    var base = super.get_default_runtime_state()
    base["is_key_pressed"] = false
    base["has_triggered"] = false
    return base
```

**验证**:
- [ ] 按键状态正确
- [ ] 触发状态正确
- [ ] 多个 Trigger 状态隔离

#### 任务 3.3: 迁移 OnInterval（1 天）

**文件**: `addons/bricks/events/lifecycle/on_interval.gd`

**修改**:
```gdscript
## 获取默认运行时状态
func get_default_runtime_state() -> Dictionary:
    var base = super.get_default_runtime_state()
    base["current_repeat_count"] = 0
    base["is_running"] = false
    base["is_completed"] = false
    base["last_input_time"] = 0.0
    return base
```

**验证**:
- [ ] 间隔触发正常
- [ ] 重复次数正确
- [ ] 状态隔离正确
- [ ] 复杂场景测试

---

#### 任务 3.4: 迁移 OnArea2DEnter（0.25 天）

**文件**: `addons/bricks/events/physics/on_area_2d_enter.gd`

**状态变量**: `_triggered_bodies` (Array)

**修改**:
```gdscript
## 获取默认运行时状态
func get_default_runtime_state() -> Dictionary:
    var base = super.get_default_runtime_state()
    base["triggered_bodies"] = []
    return base
```

**验证**:
- [ ] 区域进入触发正常
- [ ] 已触发物体列表正确
- [ ] 状态隔离正确

---

#### 任务 3.5: 迁移 OnArea3DEntered（0.25 天）

**文件**: `addons/bricks/events/physics/on_area_3d_entered.gd`

**状态变量**: `_triggered_bodies` (Array)

**修改**:
```gdscript
## 获取默认运行时状态
func get_default_runtime_state() -> Dictionary:
    var base = super.get_default_runtime_state()
    base["triggered_bodies"] = []
    return base
```

**验证**:
- [ ] 区域进入触发正常
- [ ] 已触发物体列表正确
- [ ] 状态隔离正确

---

#### 任务 3.6: 迁移 OnSignalFromGroup（0.25 天）

**文件**: `addons/bricks/events/node/on_signal_from_group.gd`

**状态变量**: `_connected_nodes` (Array), `_is_monitoring` (bool)

**修改**:
```gdscript
## 获取默认运行时状态
func get_default_runtime_state() -> Dictionary:
    var base = super.get_default_runtime_state()
    base["connected_nodes"] = []
    base["is_monitoring"] = false
    return base
```

**验证**:
- [ ] 信号监听正常
- [ ] 已连接节点列表正确
- [ ] 状态隔离正确

---

#### 任务 3.7: 迁移 OnPropertyChanged（0.25 天）

**文件**: `addons/bricks/events/node/on_property_changed.gd`

**状态变量**: `_check_timer`, `_last_value`, `_is_monitoring` (3 个)

**修改**:
```gdscript
## 获取默认运行时状态
func get_default_runtime_state() -> Dictionary:
    var base = super.get_default_runtime_state()
    base["check_timer"] = 0.0
    base["last_value"] = null
    base["is_monitoring"] = false
    return base
```

**验证**:
- [ ] 属性变化检测正常
- [ ] 状态隔离正确
- [ ] 进度更新正常

---

#### 任务 3.8: 迁移 OnVariableChanged（0.25 天）

**文件**: `addons/bricks/events/variable/on_variable_changed.gd`

**状态变量**: `_check_timer`, `_last_value`, `_is_monitoring` (3 个)

**修改**:
```gdscript
## 获取默认运行时状态
func get_default_runtime_state() -> Dictionary:
    var base = super.get_default_runtime_state()
    base["check_timer"] = 0.0
    base["last_value"] = null
    base["is_monitoring"] = false
    return base
```

**验证**:
- [ ] 变量变化检测正常
- [ ] 状态隔离正确
- [ ] 不同作用域测试

---

#### 任务 3.9: 迁移 OnMouseButton（0.25 天）

**文件**: `addons/bricks/events/input/on_mouse_button.gd`

**状态变量**: `_last_click_time`, `_click_count` (2 个)

**修改**:
```gdscript
## 获取默认运行时状态
func get_default_runtime_state() -> Dictionary:
    var base = super.get_default_runtime_state()
    base["last_click_time"] = 0.0
    base["click_count"] = 0
    return base
```

**验证**:
- [ ] 鼠标按键检测正常
- [ ] 双击检测正确
- [ ] 状态隔离正确

---

#### 任务 3.10: 迁移 OnCooldownFinished（0.25 天）

**文件**: `addons/bricks/events/timing/on_cooldown_finished.gd`

**状态变量**: `_remaining_time`, `_is_completed`, `_is_running` (3 个)

**修改**:
```gdscript
## 获取默认运行时状态
func get_default_runtime_state() -> Dictionary:
    var base = super.get_default_runtime_state()
    base["remaining_time"] = 0.0
    base["is_completed"] = false
    base["is_running"] = false
    return base
```

**验证**:
- [ ] 冷却功能正常
- [ ] 进度更新正确
- [ ] 暂停/恢复功能正常
- [ ] 状态隔离正确

---

#### 任务 3.11: 迁移 OnMouseEnter（0.25 天）

**文件**: `addons/bricks/events/input/on_mouse_enter.gd`

**状态变量**: `is_hovered` (1 个)

**修改**:
```gdscript
## 获取默认运行时状态
func get_default_runtime_state() -> Dictionary:
    var base = super.get_default_runtime_state()
    base["is_hovered"] = false
    return base
```

**验证**:
- [ ] 鼠标进入检测正常
- [ ] 触发一次功能正常
- [ ] 状态隔离正确

---

#### 任务 3.12: 迁移 OnMouseExit（0.25 天）

**文件**: `addons/bricks/events/input/on_mouse_exit.gd`

**状态变量**: `has_exited` (1 个)

**修改**:
```gdscript
## 获取默认运行时状态
func get_default_runtime_state() -> Dictionary:
    var base = super.get_default_runtime_state()
    base["has_exited"] = false
    return base
```

**验证**:
- [ ] 鼠标离开检测正常
- [ ] 触发一次功能正常
- [ ] 状态隔离正确

---

#### 任务 3.13: 批量清理 RuntimeEventInstance（0.5 天）

**目标**: 移除所有已迁移 Events 的 match 分支

**文件**: `addons/bricks/core/runtime_event_instance.gd`

**操作**:
1. 从 `_initialize_runtime_state_legacy()` 中移除以下事件类型的分支：
   - `timer`
   - `input_key`
   - `interval`
   - `area_2d_enter`
   - `area_3d_entered`
   - `signal_from_group`
   - `property_changed`
   - `variable_changed`
   - `mouse_button`
   - `cooldown_finished`
   - `mouse_enter`
   - `mouse_exit`

2. 保留未迁移 Events 的 match 分支（如果有）

**修改**:
```gdscript
func _initialize_runtime_state_legacy():
    # 仅包含未迁移 Events 的状态初始化
    match event_definition.get_event_type():
        _:
            # 默认状态（用于未声明的 Events）
            runtime_state["initialized"] = true
            runtime_state["trigger_count"] = 0
            runtime_state["last_trigger_time"] = 0.0
```

**验证**:
- [ ] 所有已迁移 Events 使用新架构
- [ ] 未迁移 Events 仍使用后备方案
- [ ] 向后兼容性保持
- [ ] 代码行数显著减少

---

### Phase 4: 迁移剩余内置 Events（1-2 天，可选）

**剩余 Events**（按优先级）:
1. OnCollisionEnter / OnCollisionExit（如有运行时状态）
2. 其他未迁移的 Events

**注意**:
- OnMouseEnter 和 OnMouseExit 已在 Phase 3 中处理
- 如果这些 Events 没有运行时状态，无需迁移

---

### 迁移模板

**剩余 Events**:
1. OnArea2DEnter / OnArea3DEntered（0.5 天）
2. OnSignalFromGroup（0.5 天）
3. OnPropertyChanged（0.5 天）
4. OnVariableChanged（0.5 天）
5. OnMouseButton（0.5 天）
6. OnCooldownFinished（0.5 天）

#### 迁移模板

每个 Event 使用相同的迁移模式：

```gdscript
## 获取默认运行时状态
func get_default_runtime_state() -> Dictionary:
    var base = super.get_default_runtime_state()
    # 添加事件特定的状态
    base["state_key"] = default_value
    return base
```

#### 迁移后清理

每个 Event 迁移完成后，在 RuntimeEventInstance 中移除对应的 match 分支：

```gdscript
# 移除前:
match event_definition.get_event_type():
    "my_event":
        runtime_state["state"] = value
    "other_event":
        runtime_state["other_state"] = other_value

# 移除后:
match event_definition.get_event_type():
    "other_event":
        runtime_state["other_state"] = other_value
    # "my_event" 分支已移除
```

---

### Phase 5: 测试和验证（2 天）

#### 任务 5.1: 单元测试（1 天）

**测试文件**: `addons/bricks/tests/test_runtime_state_declaration.gd`

```gdscript
extends GutTest

func test_on_timer_state_declaration():
    var event = OnTimer.new()
    var default_state = event.get_default_runtime_state()

    assert_has(default_state, "current_repeat_count")
    assert_eq(default_state["current_repeat_count"], 0)
    assert_has(default_state, "trigger_count")
    assert_eq(default_state["trigger_count"], 0)

func test_on_interval_state_declaration():
    var event = OnInterval.new()
    var default_state = event.get_default_runtime_state()

    assert_has(default_state, "current_repeat_count")
    assert_has(default_state, "is_running")
    assert_has(default_state, "is_completed")
    assert_has(default_state, "last_input_time")

func test_runtime_instance_initialization():
    var event = OnTimer.new()
    var trigger = create_test_trigger()
    var instance = RuntimeEventInstance.new(event, trigger)

    var state = instance.get_all_runtime_states()
    assert_has(state, "current_repeat_count")
    assert_eq(state["current_repeat_count"], 0)

func test_state_isolation():
    var event = OnTimer.new()
    var trigger1 = create_test_trigger()
    var trigger2 = create_test_trigger()

    var instance1 = RuntimeEventInstance.new(event, trigger1)
    var instance2 = RuntimeEventInstance.new(event, trigger2)

    # 修改 instance1 的状态
    instance1.set_runtime_state("current_repeat_count", 5)

    # 验证 instance2 不受影响
    assert_eq(instance2.get_runtime_state("current_repeat_count"), 0)
```

#### 任务 5.2: 集成测试（0.5 天）

**测试场景**:
1. 多 Trigger 共享同一 Event 资源
2. Event 正常触发和工作
3. 状态正确隔离
4. Trigger 销毁后状态正确清理

#### 任务 5.3: 性能测试（0.5 天）

**测试指标**:
- 内存开销：100 个 Trigger 共享 10 个 Event 资源
- CPU 开销：状态访问延迟
- 初始化时间：RuntimeEventInstance 创建时间

---

### Phase 6: 文档更新（1 天）

#### 任务 6.1: 更新迁移指南（0.5 天）

**文件**: `addons/bricks/docs/migration-guide-to-runtime-instance.md`

**新增章节**:
```markdown
## 新架构：Event 自声明状态

### 概述

从 2026-02-03 开始，Events 采用自声明状态模式。
这意味着每个 Event 负责定义自己的默认运行时状态。

### 实现步骤

1. 在 Event 类中重写 `get_default_runtime_state()` 方法
2. 调用 `super.get_default_runtime_state()` 获取基础状态
3. 添加事件特定的状态

### 示例

```gdscript
func get_default_runtime_state() -> Dictionary:
    var base = super.get_default_runtime_state()
    base["my_counter"] = 0
    base["is_active"] = false
    return base
```
```

#### 任务 6.2: 更新开发指南（0.5 天）

**文件**: `addons/bricks/docs/development/event_creation_guide.md`

**新增内容**:
- 如何创建自定义 Event
- 如何声明运行时状态
- 最佳实践和常见陷阱

---

### Phase 7: 清理和优化（1 天）

#### 任务 7.1: 移除旧代码（0.5 天）

**操作**:
1. 移除 RuntimeEventInstance 中的 `_initialize_runtime_state_legacy()` 方法
2. 移除所有 match 分支
3. 简化 `_initialize_runtime_state()` 方法

**最终实现**:
```gdscript
func _initialize_runtime_state():
    if not event_definition:
        _log_warning("没有事件定义，无法初始化运行时状态")
        return

    runtime_state = event_definition.get_default_runtime_state().duplicate(true)
    _ensure_base_states()

    _log_debug("运行时状态已初始化，事件类型: %s" % event_definition.get_event_type())
```

#### 任务 7.2: 性能优化（0.5 天）

**优化点**:
1. 缓存 `get_default_runtime_state()` 结果（Event 资源级别）
2. 避免重复的字典复制
3. 优化状态访问路径

---

## 测试策略

### 测试金字塔

```
        /\
       /E2E\          ← 端到端测试（10%）
      /------\
     /  集成  \        ← 集成测试（30%）
    /----------\
   /    单元    \      ← 单元测试（60%）
  /--------------\
```

### 测试覆盖

**单元测试（60%）**:
- 每个 Event 的 `get_default_runtime_state()` 方法
- BaseEvent 的便捷方法
- RuntimeEventInstance 的初始化逻辑

**集成测试（30%）**:
- RuntimeEventInstance 与 Event 的交互
- 多 Trigger 状态隔离
- 生命周期管理

**端到端测试（10%）**:
- 完整的事件触发流程
- 真实场景测试

---

## 风险管理

### 风险矩阵

| 风险 | 概率 | 影响 | 缓解策略 |
|------|------|------|---------|
| 迁移遗漏状态声明 | 中 | 高 | 自动化检测 + 代码审查 |
| 性能回归 | 低 | 中 | 性能基准测试 |
| 向后兼容性破坏 | 低 | 高 | 保留后备方案 |
| 用户学习成本 | 中 | 低 | 详细文档 + 示例 |

### 缓解措施

**1. 自动化检测**
```gdscript
# 在编辑器中自动检测未声明的状态
@tool
func _validate():
    if not has_method("get_default_runtime_state"):
        push_warning("Event 必须实现 get_default_runtime_state() 方法")
```

**2. 性能基准**
```gdscript
# 迁移前后性能对比
func benchmark_initialization():
    var start = Time.get_ticks_usec()
    # 创建 1000 个 RuntimeEventInstance
    var elapsed = Time.get_ticks_usec() - start
    print("初始化时间: %d 微秒" % elapsed)
```

**3. 向后兼容**
```gdscript
# 保留旧的 match 语句作为后备
if event_definition.has_method("get_default_runtime_state"):
    # 使用新模式
else:
    # 使用旧模式
```

---

## 验收标准

### 功能验收

- [ ] 所有内置 Events 实现了 `get_default_runtime_state()`
- [ ] RuntimeEventInstance 正确使用 Event 声明的状态
- [ ] 状态隔离功能正常（多 Trigger 场景）
- [ ] 生命周期管理正确（initialize, terminate, reset）
- [ ] 向后兼容性保持（现有代码无需修改）

### 性能验收

- [ ] 内存开销无显著增加（< 5%）
- [ ] 状态访问延迟 < 1 微秒
- [ ] 初始化时间无增加（或略有减少）

### 文档验收

- [ ] 迁移指南完整
- [ ] 开发指南更新
- [ ] API 文档完整
- [ ] 示例代码清晰

### 代码质量

- [ ] 所有测试通过（单元 + 集成 + E2E）
- [ ] 代码审查通过
- [ ] 无遗留 TODO 或 FIXME
- [ ] Git 提交历史清晰

---

## 时间线

### 第 1 周
- **Day 1-2**: Phase 0（基础设施准备）
- **Day 3**: Phase 1（BaseEvent 添加 API）
- **Day 4**: Phase 2（RuntimeEventInstance 重构）
- **Day 5**: Phase 3 开始（迁移 10 个已迁移 Events - 前 4 个）

### 第 2 周
- **Day 6-7**: Phase 3 完成（迁移剩余 6 个 Events + 清理 RuntimeEventInstance）
- **Day 8-9**: Phase 4（迁移剩余内置 Events，可选）
- **Day 10**: Phase 5（测试和验证）

### 第 3 周
- **Day 11**: Phase 6（文档更新）
- **Day 12**: Phase 7（清理和优化）+ 最终验收

**总预计时间**: 12 工作日（约 2.5 周）

---

## 成功指标

### 定量指标

1. **代码减少**: RuntimeEventInstance 初始化代码减少 80%
2. **扩展性**: 新增 Event 无需修改核心代码
3. **测试覆盖率**: 单元测试覆盖率达到 90%+
4. **性能**: 内存开销增加 < 5%，CPU 开销增加 < 2%

### 定性指标

1. **开发体验**: 用户创建自定义 Event 更简单
2. **可维护性**: 状态定义和使用在同一位置
3. **文档质量**: 迁移指南清晰易懂
4. **社区反馈**: 用户反馈积极

---

## 后续工作

### 短期（1-2 个月）

1. **收集反馈**: 监控用户使用情况
2. **性能优化**: 根据实际使用优化性能
3. **文档完善**: 补充常见问题和最佳实践

### 长期（3-6 个月）

1. **工具支持**: 开发 Event 生成器（自动生成状态声明）
2. **IDE 集成**: 在编辑器中提供状态声明辅助
3. **状态序列化**: 支持保存/加载运行时状态

---

## 附录

### A. 状态声明示例

```gdscript
# 简单 Event
class_name OnSimpleEvent extends BaseEvent

func get_default_runtime_state() -> Dictionary:
    var base = super.get_default_runtime_state()
    base["has_triggered"] = false
    return base

# 复杂 Event
class_name OnComplexEvent extends BaseEvent

func get_default_runtime_state() -> Dictionary:
    var base = super.get_default_runtime_state()
    base["counter"] = 0
    base["is_active"] = false
    base["last_time"] = 0.0
    base["data_list"] = []
    return base
```

### B. 迁移检查清单

- [ ] 实现 `get_default_runtime_state()`
- [ ] 调用 `super.get_default_runtime_state()`
- [ ] 添加所有必需的状态
- [ ] 更新迁移注释
- [ ] 测试状态初始化
- [ ] 测试状态隔离
- [ ] 测试生命周期

### C. 常见问题

**Q: 如果忘记声明状态会怎样？**
A: 系统会使用旧的 match 语句作为后备，并在控制台输出警告。

**Q: 是否可以动态添加状态？**
A: 可以，使用 `set_runtime_state()` 方法。但建议在 `get_default_runtime_state()` 中声明所有状态。

**Q: 如何调试状态问题？**
A: 使用 `get_runtime_state_report()` 方法查看状态详情。

---

**文档版本**: 1.0
**最后更新**: 2026-02-03
**作者**: Claude (AI Assistant)
**项目**: Project Juicy Godot - Bricks 可视化编程系统
