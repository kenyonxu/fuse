# Bricks 断点系统设计文档

**版本:** 1.0
**日期:** 2026-03-18
**状态:** 设计中
**架构师:** Claude

---

## 1. 概述与目标

### 1.1 背景

Bricks 可视化编程系统目前缺乏调试能力，开发者无法在指令执行过程中暂停来检查变量状态或执行流程。现有 `ExecutionTracker` 和 `DebugVisualizer` 仅提供事后分析功能，无法满足实时调试需求。

### 1.2 设计目标

| 目标 | 描述 |
|------|------|
| **G1** | 支持在特定指令处设置断点，暂停执行 |
| **G2** | 支持条件断点（基于表达式） |
| **G3** | 提供断点管理面板（列出所有断点） |
| **G4** | 断点命中时可查看变量状态 |
| **G5** | 与现有 pause/resume 机制无缝集成 |

### 1.3 设计原则

- **最小侵入**: 断点检查开销最小化，不影响正常执行性能
- **架构契合**: 利用现有 `RuntimeInstructionInstance.pause()/resume()` 机制
- **状态驱动**: 断点配置存储在 `runtime_state` 字典中，与 Bricks 一致

---

## 2. 架构设计

### 2.1 整体架构

```
┌─────────────────────────────────────────────────────────────┐
│                    BreakpointManager (单例)                  │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              _breakpoints: Dictionary                │   │
│  │   { instruction_uid: BreakpointConfig, ... }        │   │
│  └─────────────────────────────────────────────────────┘   │
│  - add_breakpoint() / remove_breakpoint()                   │
│  - toggle_breakpoint() / is_breakpoint_enabled()           │
│  - signals: breakpoint_hit, breakpoint_resumed            │
└─────────────────────────────────────────────────────────────┘
                              │
                              │ 断点配置查询
                              ▼
┌─────────────────────────────────────────────────────────────┐
│              RuntimeInstructionInstance                       │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  runtime_state: Dictionary                          │   │
│  │    "breakpoint": {                                  │   │
│  │      "enabled": bool,                               │   │
│  │      "condition": String,                           │   │
│  │      "ignore_count": int,                           │   │
│  │      "hit_count": int                               │   │
│  │    }                                                │   │
│  └─────────────────────────────────────────────────────┘   │
│  - execute_sync(): 检查断点 → pause() → 等待 resume        │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    DebugVisualizer (扩展)                     │
│  - 断点面板: 显示/启用/禁用/删除断点                         │
│  - 变量监视面板: 断点命中时显示变量                         │
│  - 执行控制: Resume / Step Over / Step Into                 │
└─────────────────────────────────────────────────────────────┘
```

### 2.2 核心设计决策

**决策 1: 为什么复用 pause/resume？**

Bricks 已有完整的暂停/恢复机制（`RuntimeInstructionInstance.pause()/resume()`）。断点本质上是在特定位置触发"暂停"，因此断点系统只需在断点位置调用 `pause()`，由现有机制处理暂停状态。

**决策 2: 为什么用 instruction_uid 而非索引？**

断点应绑定到指令定义（`BaseInstruction` 的唯一ID），而非执行时的索引。这样：
- 编辑器修改指令顺序不影响断点
- 同一指令的多个执行实例共享断点配置

**决策 3: 为什么条件表达式独立存储？**

条件表达式存储在 `BreakpointConfig` 而非 `runtime_state`，因为：
- 条件是断点的元数据，不是运行时状态
- 可以在断点命中前预处理条件

---

## 3. 核心组件

### 3.1 BreakpointConfig (Resource)

断点配置文件，作为 Resource 独立管理。

```gdscript
class_name BreakpointConfig
extends Resource

## 是否启用
@export var enabled: bool = true

## 条件表达式（可选），使用 ExpressionHelper 解析
## 例如: "{scope:health} < 50"
@export var condition: String = ""

## 忽略次数（命中 N 次后才暂停）
@export var ignore_count: int = 0

## 命中后是否自动恢复执行
@export var auto_resume: bool = false

## 命中次数计数（运行时）
var hit_count: int = 0

## 获取唯一标识
func get_uid() -> String:
    return "%s_%s" % [instruction_type, instruction_name]
```

### 3.2 BreakpointManager (单例)

全局断点管理器，负责断点的注册、查询和信号发射。

```gdscript
class_name BreakpointManager
extends Node

## 信号定义
signal breakpoint_hit(
    instruction: BaseInstruction,
    context: ExecutionContext,
    runtime_instance: RuntimeInstructionInstance,
    config: BreakpointConfig
)
signal breakpoint_resumed(
    instruction: BaseInstruction,
    context: ExecutionContext
)
signal breakpoint_removed(instruction_uid: String)

## 断点存储: { uid: BreakpointConfig }
var _breakpoints: Dictionary = {}
var _enabled: bool = true

## 全局断点启用状态
var is_global_enabled() -> bool:
    return _enabled

func set_global_enabled(enabled: bool) -> void:
    _enabled = enabled

## 添加断点
func add_breakpoint(instruction: BaseInstruction, config: BreakpointConfig) -> String:
    var uid = _generate_uid(instruction)
    _breakpoints[uid] = config
    return uid

## 移除断点
func remove_breakpoint(instruction_uid: String) -> bool:
    if _breakpoints.has(instruction_uid):
        _breakpoints.erase(instruction_uid)
        breakpoint_removed.emit(instruction_uid)
        return true
    return false

## 切换断点
func toggle_breakpoint(instruction_uid: String) -> bool:
    if _breakpoints.has(instruction_uid):
        _breakpoints[instruction_uid].enabled = not _breakpoints[instruction_uid].enabled
        return _breakpoints[instruction_uid].enabled
    return false

## 获取断点配置
func get_breakpoint(instruction_uid: String) -> BreakpointConfig:
    return _breakpoints.get(instruction_uid)

## 获取所有断点
func get_all_breakpoints() -> Dictionary:
    return _breakpoints.duplicate()

## 检查是否应暂停
func should_pause(
    instruction: BaseInstruction,
    context: ExecutionContext
) -> Dictionary:
    """
    返回: {
        "should_pause": bool,
        "config": BreakpointConfig,
        "reason": String
    }
    """
    if not _enabled:
        return {"should_pause": false, "config": null, "reason": "global_disabled"}

    var uid = _generate_uid(instruction)
    if not _breakpoints.has(uid):
        return {"should_pause": false, "config": null, "reason": "no_breakpoint"}

    var config: BreakpointConfig = _breakpoints[uid]

    if not config.enabled:
        return {"should_pause": false, "config": config, "reason": "disabled"}

    # 检查忽略次数
    if config.ignore_count > 0 and config.hit_count < config.ignore_count:
        config.hit_count += 1
        return {"should_pause": false, "config": config, "reason": "ignored"}

    # 检查条件表达式
    if config.condition != "":
        var eval_result = _evaluate_condition(config.condition, context)
        if not eval_result:
            return {"should_pause": false, "config": config, "reason": "condition_false"}

    return {"should_pause": true, "config": config, "reason": "breakpoint"}
```

### 3.3 RuntimeInstructionInstance 集成

在 `execute_sync()` 中添加断点检查：

```gdscript
# 在 execute_sync() 方法中，约第 102 行后添加

func execute_sync() -> bool:
    # ... 现有代码（直到执行前）...

    # 新增：断点检查
    var breakpoint_result = BreakpointManager.should_pause(instruction, execution_context)
    if breakpoint_result["should_pause"]:
        _enter_breakpoint_mode(breakpoint_result["config"])
        return false  # 暂停，等待 resume

    # ... 原有执行逻辑继续 ...
```

新增方法：

```gdscript
## 进入断点模式
func _enter_breakpoint_mode(config: BreakpointConfig) -> void:
    runtime_state["breakpoint"] = {
        "enabled": true,
        "is_breakpoint_paused": true,
        "hit_config": config,
        "hit_time": Time.get_ticks_msec()
    }

    # 通知 BreakpointManager
    BreakpointManager.breakpoint_hit.emit(instruction, execution_context, self, config)

    # 发出暂停信号（供 UI 响应）
    paused.emit()

## 恢复断点
func resume_from_breakpoint() -> void:
    if runtime_state.has("breakpoint"):
        runtime_state["breakpoint"]["is_breakpoint_paused"] = false

    BreakpointManager.breakpoint_resumed.emit(instruction, execution_context)
    resumed.emit()
```

---

## 4. 数据流

### 4.1 断点命中流程

```
1. Event.triggered
       │
       ▼
2. Trigger._on_event_fired()
       │
       ▼
3. RuntimeActionRunnerInstance.run(context)
       │
       ▼
4. _execute_instructions_sequential()
       │
       ▼
5. RuntimeInstructionInstance.execute_sync()
       │
       ▼
6. BreakpointManager.should_pause()  ← 断点检查
       │
       ├─── should_pause = false ──→ 继续正常执行
       │
       └─── should_pause = true ──→ _enter_breakpoint_mode()
                                        │
                                        ▼
                                   paused.emit()
                                        │
                                        ▼
                                   DebugVisualizer.breakpoint_hit 面板更新
                                        │
                                        ▼
                                   等待用户操作 (Resume/Step/取消)
                                        │
                                        ▼
                                   resume_from_breakpoint()
                                        │
                                        ▼
                                   继续执行下一指令
```

### 4.2 变量状态查看

断点命中时，`ExecutionContext` 提供变量访问接口：

```gdscript
# ExecutionContext 已有方法
func get_variable(name: String) -> Variant
func get_all_local_variables() -> Dictionary
func get_all_scope_variables() -> Dictionary
func get_all_global_variables() -> Dictionary
```

`DebugVisualizer` 断点面板使用这些接口显示变量：

```
┌─────────────────────────────────────────┐
│ 🔴 Breakpoint Hit: SetVariable          │
├─────────────────────────────────────────┤
│ Instruction: SetVariable                 │
│ Line: 1/5                               │
├─────────────────────────────────────────┤
│ Variables:                              │
│   local.counter = 10                     │
│   scope.health = 45                      │
│   global.score = 1250                    │
├─────────────────────────────────────────┤
│ [Resume] [Step Over] [Step Into] [Cancel]│
└─────────────────────────────────────────┘
```

---

## 5. DebugVisualizer 断点面板扩展

### 5.1 新增标签页

在 `DebugVisualizer` 中添加 "Breakpoints" 标签页：

```
┌──────────────────────────────────────────────────────────┐
│ [Execution] [Variables] [Breakpoints] [Performance]     │
├──────────────────────────────────────────────────────────┤
│ Breakpoints                            [✓ Global Enable]│
├──────────────────────────────────────────────────────────┤
│ ┌────────────────────────────────────────────────────┐  │
│ │ ● SetVariable (OnButtonPressed)    [✓] [Condition]│  │
│ │   {scope:health} < 50                              │  │
│ │   Hits: 3  |  Ignore: 0                            │  │
│ │   [Remove] [Edit]                                  │  │
│ ├────────────────────────────────────────────────────┤  │
│ │ ○ MoveToPosition (OnTimer)         [✓]             │  │
│ │   No condition                                      │  │
│ │   Hits: 0  |  Ignore: 0                            │  │
│ │   [Remove] [Edit]                                  │  │
│ └────────────────────────────────────────────────────┘  │
├──────────────────────────────────────────────────────────┤
│ Click instruction in tree to add breakpoint             │
└──────────────────────────────────────────────────────────┘
```

### 5.2 右键菜单集成

在 `execution_tree` 的指令项上添加右键菜单：

```
右键指令项 → Add Breakpoint
            ├── Toggle Breakpoint
            ├── Set Condition...
            └── Ignore Next N Hits...
```

---

## 6. 错误处理

### 6.1 断点配置错误

| 错误场景 | 处理方式 |
|----------|----------|
| 无效的条件表达式 | 记录警告，断点降级为无条件断点 |
| 断点指令已删除 | 自动移除断点，发出 `breakpoint_removed` 信号 |
| 循环引用条件 | 表达式求值超时（1秒），强制跳过 |

### 6.2 执行期错误

| 错误场景 | 处理方式 |
|----------|----------|
| 断点命中后节点被删除 | 断点自动 resume，发出警告 |
| 断点暂停时游戏暂停 | 记录警告但不断言，允许 Resume |
| 多个断点同时命中 | 按执行顺序依次暂停第一个，其余跳过 |

---

## 7. API 兼容性

### 7.1 对现有代码的影响

| 组件 | 影响 |
|------|------|
| `RuntimeInstructionInstance.execute_sync()` | 最小侵入，仅添加断点检查 |
| `RuntimeInstructionInstance.pause()/resume()` | 无修改，复用现有实现 |
| `ExecutionContext` | 无修改 |
| `ActionRunner` | 无修改 |

### 7.2 公开 API

```gdscript
# 全局断点管理器
BreakpointManager.add_breakpoint(instruction, config) -> String
BreakpointManager.remove_breakpoint(uid) -> bool
BreakpointManager.toggle_breakpoint(uid) -> bool
BreakpointManager.get_all_breakpoints() -> Dictionary
BreakpointManager.set_global_enabled(bool)

# 运行时实例控制
RuntimeInstructionInstance.resume_from_breakpoint()
```

---

## 8. 实现计划

### Phase 1: 核心机制
- [ ] `BreakpointConfig` Resource
- [ ] `BreakpointManager` 单例
- [ ] `RuntimeInstructionInstance` 断点检查集成
- [ ] 基础信号发射

### Phase 2: 条件断点
- [ ] 条件表达式解析（复用 `ExpressionHelper`）
- [ ] 忽略次数功能
- [ ] 自动恢复选项

### Phase 3: UI 集成
- [ ] `DebugVisualizer` 断点面板
- [ ] 右键菜单集成
- [ ] 变量监视显示

### Phase 4: 执行控制
- [ ] Resume / Step Over / Step Into
- [ ] 断点列表持久化（保存到项目配置）

---

## 9. 文件清单

| 文件路径 | 描述 |
|----------|------|
| `addons/bricks/core/debugging/breakpoint_config.gd` | 断点配置 Resource |
| `addons/bricks/core/debugging/breakpoint_manager.gd` | 断点管理器单例 |
| `addons/bricks/editor/debugging/debug_visualizer.gd` | 扩展断点面板 UI |
| `addons/bricks/core/runtime_instruction_instance.gd` | 集成断点检查 |

---

## 10. 参考

- [RuntimeInstructionInstance](../core/runtime_instruction_instance.gd) - 现有 pause/resume 实现
- [ExecutionContext](../core/execution/execution_context.gd) - 变量访问接口
- [ExpressionHelper](../core/utils/expression_helper.gd) - 条件表达式解析
- [DebugVisualizer](../editor/debugging/debug_visualizer.gd) - 现有调试 UI
