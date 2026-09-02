# ExecutionContext 与 ExecutionDiagnostics 开发指南

> **目标**: 为开发者提供 ExecutionContext 执行上下文及其诊断子系统 ExecutionDiagnostics 的完整开发指引。

**适用对象**: Fuse 系统开发者、贡献者

**最后更新**: 2026-07-07

---

## 📋 目录

1. [系统概述](#系统概述)
2. [架构设计——门面模式](#架构设计门面模式)
3. [ExecutionContext API](#executioncontext-api)
4. [ExecutionDiagnostics API](#executiondiagnostics-api)
5. [VariableContext 委托](#variablecontext-委托)
6. [状态生命周期](#状态生命周期)
7. [依赖图系统](#依赖图系统)
8. [FuseError 集成](#fuseerror-集成)
9. [最佳实践](#最佳实践)
10. [常见陷阱](#常见陷阱)

---

## 系统概述

`ExecutionContext` 是 Fuse 指令执行时的核心环境对象，是所有指令与游戏世界交互的桥梁。它采用**门面模式（Facade）**，将职责委托给两个子系统：

| 子系统 | 类 | 文件 | 职责 |
|--------|------|------|------|
| 变量子系统 | `VariableContext` | `core/base/variable_context.gd` | 变量读写、循环控制、索引访问、快照 |
| 诊断子系统 | `ExecutionDiagnostics` | `core/base/execution_diagnostics.gd` | 状态机、历史记录、依赖图、统计 |

### 核心文件

| 文件 | 行数 | 类 |
|------|------|-----|
| `core/base/execution_context.gd` | ~750 | `ExecutionContext extends RefCounted` |
| `core/base/execution_diagnostics.gd` | ~290 | `ExecutionDiagnostics extends RefCounted` |

### 设计目标

- **门面封装**: EC 提供统一 API，内部委托给 VariableContext 和 ExecutionDiagnostics
- **状态管理**: 完整的状态机（IDLE → RUNNING → COMPLETED/ERROR/CANCELLED）
- **弱引用**: 节点引用使用 `WeakRef` 避免内存泄漏
- **深拷贝**: `duplicate()` 完整复制变量和诊断状态（含 B11 修复）
- **日志统一**: 通过 `FuseLogger` 输出日志

---

## 架构设计——门面模式

```
ExecutionContext (门面)
    │
    ├── target: Node                ← 目标节点（WeakRef）
    ├── trigger: Node               ← 触发器节点（WeakRef）
    ├── owner: Node                 ← 拥有者节点
    ├── tree: SceneTree             ← 场景树
    ├── action_runner               ← ActionRunner 引用
    ├── custom_data: Dictionary     ← 自定义数据存储
    ├── execution_id: String        ← 唯一执行 ID
    │
    ├──► _variable_context: VariableContext  ← 变量子系统（委托）
    │       ├── local_variables: Dictionary
    │       ├── global_variables
    │       ├── set_variable / get_variable / has_variable
    │       ├── loop flags (break/continue)
    │       ├── indexed access
    │       └── snapshots
    │
    ├──► _diagnostics: ExecutionDiagnostics  ← 诊断子系统（委托）
    │       ├── ExecutionState 状态机
    │       ├── 执行历史记录
    │       ├── 状态变化监听器
    │       ├── 依赖图
    │       └── 统计信息
    │
    └──► _fuse_error: FuseError    ← 错误状态
```

---

## ExecutionContext API

**文件位置**: `addons/fuse/core/base/execution_context.gd`

**类定义**:
```gdscript
class_name ExecutionContext extends RefCounted
```

### 信号

```gdscript
signal cancel_requested                                ## 取消执行请求
signal execution_state_changed(new_state: int)         ## 执行状态改变
```

### 枚举

```gdscript
enum ExecutionState {
    IDLE,       # 空闲
    RUNNING,    # 运行中
    PAUSED,     # 暂停
    COMPLETED,  # 完成
    CANCELLED,  # 取消
    ERROR       # 错误
}
```

### 核心属性

```gdscript
var target: Node = null                # 目标节点（主要操作对象）
var trigger = null                     # 触发器节点
var owner: Node = null                 # 拥有者节点
var tree: SceneTree = null             # 场景树
var local_variables: Dictionary = {}   # 局部变量（兼容引用，指向 _variable_context）
var global_variables = null            # 全局变量容器
var custom_data: Dictionary = {}       # 自定义数据
var execution_start_time: float = 0.0  # 执行开始时间
var execution_id: String = ""          # 唯一执行ID（格式: "exec_时间戳_随机数"）
var log_level: FuseLogger.LogLevel = FuseLogger.LogLevel.NONE
var action_runner = null               # ActionRunner 引用
var delta_time: float = 0.0           # Delta 时间
```

### 构造函数

```gdscript
func _init(
    target_node: Node = null,
    trigger_node: Node = null,
    global_vars: Variant = null,
    scene_tree: SceneTree = null,
    owner_node: Node = null
) -> void
```

初始化时：
1. 记录执行开始时间
2. 生成唯一 `execution_id`
3. 设置节点引用（含 WeakRef）
4. 创建 `ExecutionDiagnostics` 子系统
5. 创建 `VariableContext` 子系统
6. 初始化 `local_variables` / `global_variables` 兼容引用

### 工厂方法

```gdscript
static func create_with_params(
    target_node: Node = null,
    trigger_node: Node = null,
    global_vars: Variant = null,
    scene_tree: SceneTree = null
) -> ExecutionContext
```

### 场景访问

```gdscript
func get_tree() -> SceneTree                    # 获取场景树
func get_node(path: NodePath) -> Node           # 多策略查找节点
```

`get_node()` 查找顺序：
1. 从 `trigger` 节点使用 `FuseNodeUtils.find_node_at_runtime()`
2. 从 `target` 节点查找
3. 从 `current_scene` 查找
4. 从 `tree.root` 绝对路径查找

### 变量门面（委托 VariableContext）

```gdscript
func add_variable(name: String, variable: BaseVariable) -> bool
func set_variable(name: String, value: Variant, scope: String = "local") -> bool
func get_variable(name: String, default: Variant = null, scope: String = "local") -> Variant
func get_variable_object(name: String) -> BaseVariable
func has_variable(name: String) -> bool
func get_global_variable_assistant() -> GlobalVariableAssistant
func set_global_variable_assistant(assistant: GlobalVariableAssistant) -> void
```

### 循环控制门面（委托 VariableContext）

```gdscript
func set_break_loop() -> void
func set_continue_loop() -> void
func should_break_loop() -> bool
func should_continue_loop() -> bool
func clear_loop_flags() -> void
func push_loop_flags() -> void
func pop_loop_flags() -> void
```

### 索引访问门面（委托 VariableContext）

```gdscript
func precompile_variable_access(variable_names: Array[String]) -> void
func set_variable_by_index(index: int, value: Variant) -> void
func get_variable_by_index(index: int) -> Variant
func get_variable_index(name: String) -> int
func is_indexed_access_enabled() -> bool
func get_indexed_access_stats() -> Dictionary
```

### 变量快照门面（委托 VariableContext）

```gdscript
func get_all_local_variables_snapshot() -> Dictionary
func get_all_scope_variables_snapshot() -> Dictionary
func get_all_global_variables_snapshot() -> Dictionary
```

### 日志方法

```gdscript
func set_log_level(level: FuseLogger.LogLevel) -> void
func get_log_level() -> FuseLogger.LogLevel
func print_message(message: String) -> void      # 调用 FuseLogger.log_info
func print_warning(message: String) -> void      # 调用 FuseLogger.log_warning
func print_error(message: String) -> void        # 调用 FuseLogger.log_error
```

### 自定义数据

```gdscript
func set_custom_data(key: String, value: Variant) -> void
func get_custom_data(key: String, default: Variant = null) -> Variant
```

### ActionRunner 管理

```gdscript
func set_action_runner(runner) -> void
func get_action_runner()
func has_action_runner() -> bool
```

### 状态管理门面（委托 Diagnostics）

```gdscript
func get_execution_state() -> ExecutionState
func set_execution_state(state: ExecutionState) -> void
func reset_execution_state() -> void
func is_running() -> bool
func is_completed() -> bool
func has_error() -> bool
func is_cancelled() -> bool
func request_cancel() -> void
func get_execution_progress() -> float
func set_execution_progress(progress: float) -> void
func get_error_message() -> String
func set_error_message(message: String, error_type: FuseError.ErrorType = ..., context: Dictionary = {}) -> void
```

### 历史/监听器门面（委托 Diagnostics）

```gdscript
func get_execution_history(limit: int = 0) -> Array[Dictionary]
func clear_execution_history() -> void
func add_state_change_listener(listener: Callable) -> void
func remove_state_change_listener(listener: Callable) -> void
func get_state_statistics() -> Dictionary
func get_recent_state_changes(count: int = 10) -> Array[Dictionary]
```

### 依赖图门面（委托 Diagnostics）

```gdscript
func get_dependency_graph() -> Dictionary
func check_dependencies(dependencies: Array[String]) -> Dictionary
func get_dependency_status() -> Dictionary
func check_dependencies_batch(dependencies_list: Array) -> Array
func get_dependency_visualization_data() -> Dictionary
```

### 生命周期

```gdscript
func cleanup() -> void          # 清理所有引用
func duplicate(p_deep: bool) -> ExecutionContext  # 深拷贝
func get_info() -> Dictionary   # 获取上下文信息
func get_execution_time() -> float  # 获取执行时间（毫秒）
```

### FuseError 集成

```gdscript
func get_fuse_error() -> FuseError
func has_fuse_error() -> bool
func had_error() -> bool
```

---

## ExecutionDiagnostics API

**文件位置**: `addons/fuse/core/base/execution_diagnostics.gd`

**类定义**:
```gdscript
class_name ExecutionDiagnostics extends RefCounted
```

### 构造函数

```gdscript
func _init(owner: ExecutionContext) -> void
```

### 状态管理

```gdscript
func get_execution_state() -> int
func set_execution_state(state: int) -> void       # 自动 emit + 记录历史
func reset_execution_state() -> void               # 重置为 IDLE
func is_running() -> bool
func is_completed() -> bool
func has_error() -> bool
func is_cancelled() -> bool
func request_cancel() -> void                      # 设置 CANCELLED + emit cancel_requested
```

### 进度

```gdscript
func get_execution_progress() -> float             # 返回 0.0 ~ 1.0
func set_execution_progress(progress: float) -> void  # clamp + 变化 > 0.01 时记录历史
```

### 错误

```gdscript
func get_error_message() -> String
func set_error_message(message: String, error_type: int = 0, context: Dictionary = {}) -> void  # 自动设置 ERROR 状态
```

### 历史记录

```gdscript
func _record_execution_history(state: int, message: String = "", data: Dictionary = {}) -> void
func get_execution_history(limit: int = 0) -> Array[Dictionary]
func clear_execution_history() -> void
```

历史条目格式：
```gdscript
{
    "timestamp": float,           # 时间戳（秒）
    "state": int,                 # 状态值
    "state_name": String,         # 状态名称
    "message": String,            # 描述消息
    "progress": float,            # 当前进度
    "execution_time": float,      # 执行时间
    "data": Dictionary            # 附加数据
}
```

### 状态变化监听器

```gdscript
func add_state_change_listener(listener: Callable) -> void
func remove_state_change_listener(listener: Callable) -> void
```

监听器签名：`callable(old_state: int, new_state: int, context: ExecutionContext)`

### 状态统计

```gdscript
func get_state_statistics() -> Dictionary     # 状态计数 + 各状态耗时
func get_recent_state_changes(count: int = 10) -> Array[Dictionary]
```

### 依赖关系图

```gdscript
func get_dependency_graph() -> Dictionary
func _collect_all_variables() -> Dictionary
func check_dependencies(dependencies: Array[String]) -> Dictionary
func get_dependency_status() -> Dictionary
func check_dependencies_batch(dependencies_list: Array) -> Array
func get_dependency_visualization_data() -> Dictionary
```

### 复制

```gdscript
func duplicate(p_deep: bool = true) -> ExecutionDiagnostics
```

---

## 状态生命周期

```
      ┌──────────┐
      │   IDLE   │
      └────┬─────┘
           │ run/execute
           ▼
      ┌──────────┐
      │ RUNNING  │ ◄──── PAUSED ────►  (暂停/恢复)
      └────┬─────┘
           │
    ┌──────┼──────────┐
    │      │          │
    ▼      ▼          ▼
┌──────┐ ┌────────┐ ┌──────────┐
│DONE  │ │ ERROR  │ │CANCELLED │
└──────┘ └────────┘ └──────────┘
```

- `set_execution_state()` 触发 `execution_state_changed` 信号
- `set_error_message()` 自动设置 `ERROR` 状态
- `request_cancel()` 自动设置 `CANCELLED` 状态

---

## FuseError 集成

ExecutionContext 通过 `_create_fuse_error()` 创建 FuseError 实例：

```gdscript
func _create_fuse_error(message: String, error_type: FuseError.ErrorType, context: Dictionary):
    var error_context = context.duplicate()
    error_context["execution_id"] = execution_id
    _fuse_error = FuseError.create_with_context(error_type, "ExecutionContext", message, error_context)
```

---

## 最佳实践

### 1. 创建 ExecutionContext

```gdscript
# 使用工厂方法
var context = ExecutionContext.create_with_params(
    target_node,
    trigger_node,
    global_variables,
    get_tree()
)
```

### 2. 在指令中使用

```gdscript
func execute(context: ExecutionContext):
    _start_execution(context)
    
    # 获取节点
    var node = context.get_node(target_node)
    
    # 读写变量
    context.set_variable("score", 100)
    var score = context.get_variable("score", 0)
    
    # 日志
    context.print_message("指令执行中...")
    
    # 状态检查
    if context.is_cancelled():
        finished.emit()
        return
    
    _on_execution_completed()
```

### 3. 深拷贝上下文

```gdscript
var copy = context.duplicate(true)
# 注意：B11 已修复，duplicate 完整复制 _diagnostics
```

### 4. 清理上下文

执行完成后调用 `cleanup()` 释放引用：

```gdscript
context.cleanup()
```

### 5. 使用依赖图调试

```gdscript
var graph = context.get_dependency_visualization_data()
# 包含节点列表、边列表、执行上下文信息
```

---

## 常见陷阱

### 陷阱 1：WeakRef 导致 target/trigger 意外为 null

ExecutionContext 使用 `WeakRef` 存储 target 和 trigger 引用。如果节点被释放，`target` 属性会自动变为 `null`。始终在使用前检查：

```gdscript
if not context.target:
    _log_error("目标节点已不存在")
    return
```

### 陷阱 2：duplicate 漏拷贝诊断数据（B11 历史 bug）

旧版 `duplicate()` 没有复制 `_diagnostics` 子系统，导致复制后的上下文丢失执行历史/状态。**当前版本已修复此问题**。

### 陷阱 3：变量作用域参数错误

`set_variable(name, value, scope)` 的 scope 参数是字符串而非 `VariableScope` 枚举：

```gdscript
# ✅ 正确
context.set_variable("hp", 100, "local")
context.set_variable("hp", 100, "scope")
context.set_variable("hp", 100, "global")

# ❌ 错误——不传 scope 参数默认 "local"
context.set_variable("hp", 100)
```

### 陷阱 4：在 _init 中访问节点引用

ExecutionContext 是 `RefCounted`，不是 `Node`，其 `_init` 中无法使用 `get_tree()`。在构造函数中只设置传入的值，不要调用依赖 SceneTree 的方法。

### 陷阱 5：多次调用 cleanup

`cleanup()` 是幂等的，多次调用是安全的。但调用后不应再使用该上下文。

---

## 参考文档

- [FuseLogger 日志系统指南](fuse-logger-guide.md)
- [ActionRunner 开发指南](action-runner-guide.md)
- [RuntimeBridge 开发指南](runtime-bridge-guide.md)
- [FuseEventBus 开发指南](event-bus-guide.md)
- [指令创建指南](instruction-creation-guide.md)

---

**文档维护**: Fuse 开发团队 | **最后更新**: 2026-07-07 | **Godot 版本**: 4.7
