# ExecutionContext 分析报告


> **分析时点**：2026-07-07（经同日全量文档审计逐篇核对代码；此后实现演进以源码为准，近期已核对的机制性结论见 threading / runtime_instance / preset_nested 等篇）
## 文档概述

本报告对 Fuse 可视化编程系统中的 `ExecutionContext` 核心脚本进行现状描述。`ExecutionContext` 是执行上下文类（`class_name ExecutionContext extends RefCounted`），提供指令执行时的环境和上下文信息，是指令与游戏世界交互的桥梁。

经过重构，`ExecutionContext` 现为**门面类**：自身只保留节点引用、自定义数据、日志、ActionRunner、FuseError 等执行环境数据；执行状态/历史/进度/依赖图、变量 CRUD/作用域/索引化访问/快照、循环 break/continue 标志栈等职责**全部委托**给两个子系统——`ExecutionDiagnostics` 与 `VariableContext`。EC 在 `_init()` 中创建这两个子系统实例，外部调用者通过 EC 暴露的门面方法访问它们。

**源文件:** [execution_context.gd](../../../../core/base/execution_context.gd)
**行数:** 773 行
**基类:** RefCounted
**子系统:** [ExecutionDiagnostics](../../../../core/base/execution_diagnostics.gd)（281 行）、[VariableContext](../../../../core/base/variable_context.gd)（463 行）

---

## 1. 类概述和职责

### 核心职责

1. **门面/委托**: 暴露统一的执行上下文接口，内部委托给 VariableContext 和 ExecutionDiagnostics
2. **执行环境数据**: 节点引用（target/trigger/owner）、场景树、custom_data、execution_id
3. **节点访问**: get_node / get_tree 多策略节点查找
4. **日志**: 基于 FuseLogger 的分级 + 本地化日志
5. **错误处理**: FuseError 实例管理（_create_fuse_error / get_fuse_error / had_error）
6. **复制**: duplicate() 深拷贝（变量子系统深拷贝，节点引用浅拷贝）
7. **静态工厂**: create_with_params() 提供参数化构造

### 设计特点

- `@tool` 注解，支持编辑器模式运行
- `extends RefCounted`：引用计数管理生命周期，避免 Node 持有负担
- `_init()` 中同时创建两个子系统并把自身（`self`）作为 `_owner` 传入，子系统通过 `_owner` 反向引用 EC 的字段
- EC 的 `local_variables` / `global_variables` 是**兼容引用**，指向 `_variable_context` 内部的字典，外部既有代码读写这两个字段等价于操作子系统

---

## 2. 委托架构

```
ExecutionContext (RefCounted, 门面)
    │
    ├── _variable_context: VariableContext ── 变量子系统
    │       ├── local_variables / global_variables
    │       ├── _global_variable_assistant
    │       ├── LRU 名称缓存 (_variable_name_cache, _cache_max_size=1000)
    │       ├── 索引访问 (_variable_index_map / _variable_array)
    │       ├── 循环标志 (_break_loop_flag / _continue_loop_flag / _loop_flag_stack)
    │       └── _owner → ExecutionContext
    │
    ├── _diagnostics: ExecutionDiagnostics ── 诊断子系统
    │       ├── _execution_state / _execution_progress
    │       ├── _error_message / _is_cancelled
    │       ├── _execution_history (max 100)
    │       ├── _state_change_listeners
    │       └── _owner → ExecutionContext
    │
    └── EC 自身保留
        ├── target / trigger / owner / tree
        ├── _target_weakref / _trigger_weakref
        ├── custom_data / execution_id / execution_start_time
        ├── log_level / action_runner / delta_time
        └── _fuse_error
```

### 委托方式

EC 上的门面方法**直接转发**到子系统，无额外逻辑（少量方法除外）。例如：

```gdscript
func set_variable(name, value, scope = "local") -> bool:
    return _variable_context.set_variable(name, value, scope)

func get_execution_state() -> ExecutionState:
    return _diagnostics.get_execution_state() as ExecutionState
```

例外：`set_error_message()` 在委托后会创建 FuseError 实例并记录日志；`get_dependency_visualization_data()` 在子系统返回值上追加 FuseError 详情。

---

## 3. 核心属性

### EC 自身属性

| 属性 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| target | Node | null | 目标节点（指令操作的主要对象） |
| trigger | Variant | null | 触发器节点 |
| owner | Node | null | 拥有者节点（创建此上下文的节点） |
| tree | SceneTree | null | 场景树引用 |
| local_variables | Dictionary | {} | **兼容引用**，指向 `_variable_context.local_variables` |
| global_variables | Variant | null | **兼容引用**，指向 `_variable_context.global_variables` |
| _global_variable_assistant | GlobalVariableAssistant | null | 全局变量助手类型化引用（兼容引用） |
| _variable_context | VariableContext | null | 变量子系统 |
| _diagnostics | ExecutionDiagnostics | null | 诊断子系统 |
| custom_data | Dictionary | {} | 自定义数据，跨指令临时交换 |
| execution_start_time | float | 0.0 | 执行开始时间（毫秒，构造时记录） |
| execution_id | String | "" | 唯一执行标识符，格式 `exec_[时间戳]_[随机数]` |
| log_level | FuseLogger.LogLevel | NONE | 日志输出级别 |
| action_runner | Variant | null | ActionRunner 或 RuntimeActionRunnerInstance 引用 |
| delta_time | float | 0.0 | Delta 时间（秒），来自物理/帧回调 |
| _target_weakref | WeakRef | null | 目标节点弱引用 |
| _trigger_weakref | WeakRef | null | 触发器节点弱引用 |
| _fuse_error | FuseError | null | FuseError 实例 |

### 枚举

```
enum ExecutionState { IDLE, RUNNING, PAUSED, COMPLETED, CANCELLED, ERROR }
```

### 信号

| 信号 | 参数 | 说明 |
|------|------|------|
| cancel_requested | (无) | 取消执行请求 |
| execution_state_changed | (new_state: int) | 执行状态改变 |

> **注**：EC **只声明这两个信号**。不存在 `execution_step_completed` / `execution_progress_updated` 信号——进度更新通过 `_diagnostics.set_execution_progress()` 写入历史，不通过信号广播。

---

## 4. 初始化

### _init() 构造函数

```
_init(target_node=null, trigger_node=null, global_vars=null, scene_tree=null, owner_node=null)

执行流程:
  1. 记录 execution_start_time = Time.get_ticks_msec()
  2. 生成 execution_id = "exec_[时间戳]_[随机数]"
  3. 设置 target / trigger / global_variables / owner
  4. 解析 _global_variable_assistant:
     - global_vars is GlobalVariableAssistant → 直接用
     - global_vars is GlobalVariableManager → GlobalVariableAssistant.get_instance()
     - 其他/null → GlobalVariableAssistant.get_instance()
  5. 设置 tree / 弱引用（target/trigger）
  6. 创建 _diagnostics = ExecutionDiagnostics.new(self)
  7. 创建 _variable_context = VariableContext.new(self)
     - 同步 global_variables 与 _global_variable_assistant 到子系统
  8. 兼容引用: EC.local_variables = _variable_context.local_variables
              EC.global_variables = _variable_context.global_variables
  9. reset_execution_state() → IDLE
```

> **注**：步骤 6 / 7 在 `if trigger_node:` 块**外**——即 `ExecutionContext.new(target, null)` 仅 target 构造时也会创建 `_diagnostics` 与 `_variable_context`，保证 target-only 用法的变量/诊断 API 可用。
> 历史：曾因缩进落在 `if trigger_node:` 块内，target-only 构造时子系统未创建，`set_variable` 报 Nil（CODE_ISSUES B19），已修复（commit `1ffe707`）。

### create_with_params() 静态工厂

```
static create_with_params(target_node=null, trigger_node=null, global_vars=null, scene_tree=null) -> ExecutionContext

仅设置 target/trigger/global_variables/tree 后返回新实例。
注意：此工厂不调用 _init 之外的初始化逻辑（不重建子系统兼容引用），
适合需要快速构造后由调用方进一步配置的场景。
```

---

## 5. 节点访问

### get_tree() — 场景树获取（已实现 fallback）

```
get_tree() -> SceneTree

执行流程:
  1. 如果 tree 已设置 → 直接返回
  2. 否则从主场景取: Engine.get_main_loop().current_scene.get_tree()
  3. 缓存到 tree 字段
  4. 返回 tree（可能为 null）
```

> **现状**：旧稿将此 fallback 列为"待改进建议"——**实际已实现**。`get_tree()` 在 tree 为空时自动从主场景回退获取并缓存。

### get_node(path) — 多策略节点查找

```
get_node(path: NodePath) -> Node

执行流程（按优先级）:
  1. 空路径 → _log_error_localized("FUSE_ERROR_INVALID_NODE_PATH_EMPTY"), 返回 null
  2. trigger 节点 → FuseNodeUtils.find_node_at_runtime(trigger, path)
  3. target 节点 → FuseNodeUtils.find_node_at_runtime(target, path)
  4. current_scene → FuseNodeUtils.find_node_at_runtime(current_scene, path)
  5. 绝对路径 → 从 scene_tree.root 查找
  6. 全部失败 → _log_error_localized("FUSE_ERROR_NODE_NOT_FOUND_AT_PATH", {path}), 返回 null
```

`FuseNodeUtils.find_node_at_runtime` 封装了多策略节点查找逻辑。

---

## 6. 变量子系统门面（委托 VariableContext）

### 6.1 变量 CRUD

| 门面方法 | 委托目标 | 说明 |
|---------|---------|------|
| add_variable(name, variable: BaseVariable) -> bool | _variable_context.add_variable | 添加 BaseVariable 对象 |
| set_variable(name, value, scope="local") -> bool | _variable_context.set_variable | 设置变量（三层作用域分发） |
| get_variable(name, default=null, scope="local") -> Variant | _variable_context.get_variable | 获取变量值 |
| get_variable_object(name) -> BaseVariable | _variable_context.get_variable_object | 获取变量对象（高级 API） |
| has_variable(name) -> bool | _variable_context.has_variable | 检查变量是否存在 |
| get_global_variable_assistant() -> GlobalVariableAssistant | _variable_context.get_global_variable_assistant | 获取全局变量助手 |
| set_global_variable_assistant(assistant) | _variable_context.set_global_variable_assistant | 设置全局变量助手（同步兼容引用） |

### 6.2 字符串作用域

`set_variable` / `get_variable` 的 `scope` 参数接受字符串值：

| scope 值 | 行为 |
|---------|------|
| "local" | 读写 `local_variables`（默认） |
| "scope" | 委托给 ScopeVariableContainer（通过 `_find_scope_container` 查找） |
| "global" | 委托给 GlobalVariableAssistant / global_variables 容器 |
| 其他 | `_log_error_localized("FUSE_ERROR_UNKNOWN_VARIABLE_SCOPE", {scope})` |

### 6.3 循环控制（break/continue 标志栈）

| 门面方法 | 说明 |
|---------|------|
| set_break_loop() | 设置 break 标志 |
| set_continue_loop() | 设置 continue 标志 |
| should_break_loop() -> bool | 检查 break 标志 |
| should_continue_loop() -> bool | 检查 continue 标志 |
| clear_loop_flags() | 清空两个标志 |
| push_loop_flags() | 保存当前标志到栈，清空标志（进入内层循环） |
| pop_loop_flags() | 从栈恢复外层标志（栈空则清空） |

VariableContext 内部维护：
- `_break_loop_flag: bool`
- `_continue_loop_flag: bool`
- `_loop_flag_stack: Array[Dictionary]`（每项 `{"break": bool, "continue": bool}`）

`push/pop` 用于嵌套循环（ForEach / While 指令），保证内层循环的 break/continue 不污染外层。

### 6.4 索引化访问优化

| 门面方法 | 说明 |
|---------|------|
| precompile_variable_access(names: Array[String]) | 预编译变量名到索引的映射，开启索引访问模式 |
| set_variable_by_index(index, value) | 按索引设置变量 |
| get_variable_by_index(index) -> Variant | 按索引获取变量 |
| get_variable_index(name) -> int | 查询变量名对应的索引（-1 表示未启用/未找到） |
| is_indexed_access_enabled() -> bool | 索引访问是否开启 |
| get_indexed_access_stats() -> Dictionary | 索引访问统计 |

VariableContext 内部维护 `_variable_index_map`（StringName→int）与 `_variable_array`。预编译后高频路径可绕过字典查找。

### 6.5 LRU 名称缓存

VariableContext 维护：
- `_variable_name_cache: Dictionary`（String → StringName）
- `_cache_max_size: int = 1000`
- `_cache_access_order: Array`

`_get_cached_name_key(name) -> StringName` 在容量达上限时淘汰最旧 1/5。`local_variables` 使用 StringName 键以加速字典查找。

### 6.6 变量快照（断点调试）

| 门面方法 | 说明 |
|---------|------|
| get_all_local_variables_snapshot() -> Dictionary | 局部变量快照（StringName 键转 String） |
| get_all_scope_variables_snapshot() -> Dictionary | 作用域变量快照（通过 ScopeVariableContainer.get_variable_names） |
| get_all_global_variables_snapshot() -> Dictionary | 全局变量快照（委托 GlobalVariableAssistant.get_all_global_variables_info） |

### 6.7 作用域容器查找

VariableContext.`_find_scope_container() -> ScopeVariableContainer` 查找优先级：
1. `trigger` 节点的最近 ScopeVariableContainer
2. `target` 节点的最近 ScopeVariableContainer
3. `owner` 节点的最近 ScopeVariableContainer
4. 返回 null（`_set/_get_scope_variable` 会回退到本地变量并 push_warning）

---

## 7. 诊断子系统门面（委托 ExecutionDiagnostics）

### 7.1 执行状态

| 门面方法 | 说明 |
|---------|------|
| get_execution_state() -> ExecutionState | 当前状态 |
| set_execution_state(state) | 设置状态（变化时 emit execution_state_changed + 记录历史 + 通知监听器） |
| reset_execution_state() | 重置为 IDLE（清空进度/错误/取消标志） |
| is_running() -> bool | state == RUNNING |
| is_completed() -> bool | state == COMPLETED |
| has_error() -> bool | state == ERROR |
| is_cancelled() -> bool | _is_cancelled 或 state == CANCELLED |
| request_cancel() | 仅在 RUNNING 时设置 _is_cancelled，切到 CANCELLED，emit cancel_requested |

### 7.2 进度与错误

| 门面方法 | 说明 |
|---------|------|
| get_execution_progress() -> float | 当前进度（0.0–1.0） |
| set_execution_progress(progress) | clamp 到 [0,1]，变化 >0.01 时记录历史 |
| get_error_message() -> String | 错误消息 |
| set_error_message(msg, error_type=RUNTIME_ERROR, context={}) | **特殊**：委托后还会创建 FuseError 实例 + 写日志 |

`set_error_message` 是少数有附加逻辑的门面方法：

```gdscript
func set_error_message(message, error_type=RUNTIME_ERROR, context={}):
    _diagnostics.set_error_message(message, error_type, context)
    var error_context = context.duplicate()
    error_context["execution_id"] = execution_id
    error_context["execution_state"] = ExecutionState.keys()[_diagnostics.get_execution_state()]
    _create_fuse_error(message, error_type, error_context)
    _log_error("Execution error: %s" % message)
```

### 7.3 历史记录

| 门面方法 | 说明 |
|---------|------|
| get_execution_history(limit=0) -> Array[Dictionary] | limit<=0 或 >= size 返回全部；否则返回最后 limit 条 |
| clear_execution_history() | 清空历史 |
| _record_execution_history(state, message="", data={}) | 内部记录（每条含 timestamp/state/state_name/message/progress/execution_time/data） |

ExecutionDiagnostics 内部 `_max_history_size = 100`，超过自动 pop_front。

### 7.4 状态变化监听器

| 门面方法 | 说明 |
|---------|------|
| add_state_change_listener(listener: Callable) | 注册监听器 |
| remove_state_change_listener(listener: Callable) | 移除监听器 |
| _notify_state_change(old_state, new_state) | 内部通知（listener.call(old, new, owner)） |

### 7.5 状态统计

| 门面方法 | 说明 |
|---------|------|
| get_state_statistics() -> Dictionary | total_history_entries / state_counts / total_time_in_states / last_state_change_time / current_state_duration |
| get_recent_state_changes(count=10) -> Array[Dictionary] | 最近的实际状态变化条目 |

### 7.6 依赖关系图

| 门面方法 | 说明 |
|---------|------|
| get_dependency_graph() -> Dictionary | 节点+边+context_info（execution_id/target/trigger/execution_time） |
| _collect_all_variables() -> Dictionary | 内部收集所有 local 变量 |
| check_dependencies(deps: Array[String]) -> Dictionary | 检查依赖变量是否存在 |
| get_dependency_status() -> Dictionary | total_variables / total_conditions / variable_dependencies / condition_dependencies |
| check_dependencies_batch(deps_list: Array) -> Array | 批量检查 |
| get_dependency_visualization_data() -> Dictionary | **特殊**：合并 graph+status+context_info，并在有 _fuse_error 时追加 fuse_error 详情 |

---

## 8. FuseError 集成

| 方法 | 说明 |
|------|------|
| _create_fuse_error(message, error_type=RUNTIME_ERROR, context={}) | 创建 FuseError 实例（注入 execution_id），存储到 _fuse_error |
| get_fuse_error() -> FuseError | 获取当前 FuseError（无则 null） |
| has_fuse_error() -> bool | 是否有 FuseError |
| had_error() -> bool | has_fuse_error 的别名（向后兼容） |

`_create_fuse_error` 通过 `FuseError.create_with_context(error_type, "ExecutionContext", message, error_context)` 创建实例。`set_error_message` 是触发 FuseError 创建的主要路径。

---

## 9. 日志系统

### 分级日志（基于 FuseLogger）

| 方法 | 委托 |
|------|------|
| print_message(message) | FuseLogger.log_info("ExecutionContext", log_level, message, execution_id) |
| print_warning(message) | FuseLogger.log_warning(...) |
| print_error(message) | FuseLogger.log_error(...) |
| _log_debug(message) | FuseLogger.log_debug(...) |
| _log_info(message) | FuseLogger.log_info(...) |
| _log_warning(message) | FuseLogger.log_warning(...) |
| _log_error(message) | FuseLogger.log_error(...) |

### 本地化日志

| 方法 | 委托 |
|------|------|
| _log_debug_localized(message_key, args={}) | FuseLogger.log_debug_localized(...) |
| _log_info_localized(message_key, args={}) | FuseLogger.log_info_localized(...) |
| _log_warning_localized(message_key, args={}) | FuseLogger.log_warning_localized(...) |
| _log_error_localized(message_key, args={}) | FuseLogger.log_error_localized(...) |

所有日志方法均传入 `execution_id` 作为关联标识。message_key 走 FuseLocalization 翻译，args 用于占位符替换。

### 日志级别控制

- `set_log_level(level)` 设置并打印变更日志
- `get_log_level() -> FuseLogger.LogLevel`

---

## 10. ActionRunner 集成

| 方法 | 说明 |
|------|------|
| set_action_runner(runner) | 设置 ActionRunner 或 RuntimeActionRunnerInstance 引用 |
| get_action_runner() | 获取引用（未设置返回 null） |
| has_action_runner() -> bool | 是否已设置 |

`action_runner` 字段类型为 Variant，可容纳两种 runner 类型。

---

## 11. WeakRef 节点引用管理

为降低内存泄漏风险（节点先于 EC 释放），EC 维护目标/触发器节点的弱引用。

| 方法 | 说明 |
|------|------|
| set_target_node(node) | 设置 target 与 _target_weakref |
| get_target_node() -> Node | 优先检查弱引用；失效则警告并清理，回退到 target |
| set_trigger_node(node) | 设置 trigger 与 _trigger_weakref |
| get_trigger_node() -> Node | 优先检查弱引用；失效则警告并清理，回退到 trigger |

弱引用失效时调用 `_log_warning_localized("FUSE_WARNING_TARGET_NODE_RELEASED" / "FUSE_WARNING_TRIGGER_NODE_RELEASED")`，并清理字段。

---

## 12. 复制与清理

### duplicate(p_deep=true) -> ExecutionContext

```
执行流程:
  1. 创建新 EC（不带参数 → _init 走默认路径）
  2. 复制 target / trigger / tree（浅拷贝，共享节点）
  3. _variable_context.duplicate() 深拷贝变量子系统
     - 更新 _owner 指向新 EC
     - 同步 EC.local_variables 到新 VariableContext 的字典
  4. 复制 global_variables / _global_variable_assistant（共享容器）
  5. custom_data.duplicate()（浅拷贝字典）
  6. 复制 execution_start_time / execution_id / action_runner（共享 runner）
  7. _diagnostics 深拷贝（保留执行历史 / 状态 / 监听器）
```

> **注**：duplicate 复制 `_diagnostics`（深拷贝，独立实例），不复制 WeakRef。变量子系统与诊断子系统均为深拷贝目标。
> 历史：曾遗漏 `_diagnostics` 复制（CODE_ISSUES B11），已修复（commit `1ffe707`，测试 `test_execution_context_init.tscn`）。

### cleanup()

```
执行流程:
  1. _variable_context.cleanup()（清空变量/缓存/索引/标志栈）
  2. 遍历 custom_data，RefCounted/Resource 项置 null 后 clear()
  3. target/trigger：未 queued_for_deletion 时记日志并置 null
  4. 清空 _target_weakref / _trigger_weakref
  5. global_variables / tree / action_runner 置 null
  6. _diagnostics.cleanup()（清空历史/监听器/状态）
  7. _fuse_error 置 null
  8. reset_execution_state()
  9. _log_debug_localized("FUSE_LOG_EXECUTION_CONTEXT_CLEANED")
```

---

## 13. 调试信息

### get_info() -> Dictionary

返回执行上下文快照，用于调试和日志：

```gdscript
{
    "execution_id": ...,
    "execution_time": get_execution_time(),
    "target": ...,
    "trigger": ...,
    "local_variables_count": local_variables.size(),
    "has_global_variables": global_variables != null,
    "custom_data_count": custom_data.size(),
    "execution_state": ExecutionState.keys()[...],
    "execution_progress": ...,
    "is_cancelled": ...,
    "error_message": ...,
    "has_action_runner": action_runner != null
}
```

`get_execution_time() -> float` 返回自构造以来的毫秒数（`Time.get_ticks_msec() - execution_start_time`）。

---

## 14. 自定义数据

| 方法 | 说明 |
|------|------|
| set_custom_data(key, value) | 存入 custom_data 字典 |
| get_custom_data(key, default=null) -> Variant | 读取，不存在返回 default |

`custom_data` 用于跨指令的临时信息交换（不参与变量作用域系统）。

---

## 15. 兼容性设计

EC 在多处保留**兼容引用**以维持旧代码的访问路径：

| 字段/方法 | 兼容目标 |
|----------|---------|
| `local_variables` | 指向 `_variable_context.local_variables` 的同一字典 |
| `global_variables` | 指向 `_variable_context.global_variables` |
| `_global_variable_assistant` | 与 `_variable_context._global_variable_assistant` 同步 |
| `had_error()` | `has_fuse_error()` 的别名 |
| `print_message/warning/error` | 与 `_log_info/warning/error` 等价的旧接口 |

`set_global_variable_assistant(assistant)` 同时更新 EC 与 VariableContext 的引用，保持一致性。

---

## 16. 总体评估

### 优点

1. **门面架构清晰**：EC 是对外接口，VariableContext / ExecutionDiagnostics 各司其职，可独立演化
2. **RefCounted 生命周期**：避免 Node 持有负担，适合对象池和 Runtime 实例场景
3. **三层变量作用域**：local / scope / global 字符串分发，配合 ScopeVariableContainer 实现节点级作用域
4. **索引化访问优化**：预编译后绕过字典查找，适合高频循环
5. **LRU 名称缓存**：StringName 键 + 1000 上限的 LRU，平衡命中率与内存
6. **循环标志栈**：push/pop 支持嵌套循环的 break/continue 隔离
7. **WeakRef 节点管理**：降低节点先于 EC 释放的悬挂引用风险
8. **FuseError 统一错误**：与 BaseEvent / BaseInstruction 错误模型一致
9. **本地化日志**：_log_*_localized 系列接入 FuseLocalization
10. **get_tree fallback 已实现**：tree 为空时自动从主场景回退（旧稿曾误列为待改进）

### 不足与注意点

1. **create_with_params 不走完整 _init 路径**：未同步子系统兼容引用，使用前需明确语义
2. **`_global_variable_assistant` 同步点多**：EC、VariableContext、set_global_variable_assistant 三处需保持一致，易遗漏
3. **get_dependency_graph 仅收集 local 变量**：`_collect_all_variables` 不包含 scope/global，依赖图视图有限
4. **进度更新无信号**：旧稿设想的 `execution_progress_updated` 信号不存在，进度变化只入历史，外部需轮询 `get_execution_progress()`

> 历史 B11（duplicate 不复制 _diagnostics）、B19（_init 缩进导致 target-only 时子系统 nil）已修复（commit `1ffe707`，测试 `test_execution_context_init.tscn`），从注意点列表移除。

---

**文档维护**: Fuse 开发团队
**最后更新**: 2026-07-07
**版本**: 2.0（重写，对齐 execution_context.gd 773 行 + ExecutionDiagnostics 281 行 + VariableContext 463 行）
