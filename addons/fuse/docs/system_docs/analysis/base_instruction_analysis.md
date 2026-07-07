# BaseInstruction 分析报告

> 参照代码：`addons/fuse/core/base/base_instruction.gd`（1294 行）、`addons/fuse/core/runtime_instruction_instance.gd`（548 行）
> 维护：Fuse 开发团队 | 状态：2026-07-07 大更新（对齐 v2.0+ 架构）

## 文档概述

本报告对 Fuse 可视化编程系统中的 `BaseInstruction` 核心脚本进行分析。`BaseInstruction` 是所有指令的 `@abstract` 基类（继承自 `Resource`），为指令系统提供执行框架、状态机、错误处理、日志、超时、智能同步检测、i18n 资源名同步、图标管理以及运行时实例协作等能力。

> **历史说明**：本文件原首版（v1）分析曾把 `execute()` 描述为"默认调 `_on_execution_completed()`"、并把超时/统一错误/日志/异步执行列为"待改进建议"。这些特性在 v2.0 已全部落地，旧稿结论基于错误前提，已删除。当前文档按现状描述体例重写。

## 1. 类定位与继承

```gdscript
@tool
@icon("res://addons/fuse/icons/instruction.svg")
@abstract
class_name BaseInstruction extends Resource
```

- **`@abstract`**：不可直接实例化，必须子类化。
- **`extends Resource`**：指令是数据资源，可在检查器配置、序列化、复用；同一资源可被多个 `RuntimeInstructionInstance` 共享。
- **`@tool`**：支持编辑器内预览/校验。

子类必须实现以下 `@abstract` 方法（无默认实现，缺失则编译报错）：

| 方法 | 位置 | 用途 |
|------|------|------|
| `execute(context: ExecutionContext)` | base_instruction.gd:379–380 | 执行入口，子类实现指令逻辑 |
| `_setup_metadata()` | base_instruction.gd:299–300 | 设置 name/description/category 等元数据 |
| `_update_resource_name()` | base_instruction.gd:185–186 | 根据当前状态/语言刷新 `resource_name`（用于检查器显示） |

> **纠正旧稿**：`execute()` **没有**默认实现——它仅声明为 `@abstract func execute(context: ExecutionContext)`，子类负责调用 `_start_execution(context)`、在结束时调用 `_on_execution_completed()` 或 `_on_execution_error()`/`set_error()`。

## 2. 核心枚举与字段

### 2.1 三大枚举（base_instruction.gd:66–94）

| 枚举 | 取值 | 用途 |
|------|------|------|
| `ExecutionStatus` | PENDING / RUNNING / COMPLETED / CANCELLED / ERROR | 指令生命周期状态机 |
| `CompletionSignalTiming` | ON_START / ON_FINISH | `finished` 信号发送时机 |
| `ExecutionMode` | AUTO_DETECT / FORCE_ASYNC / FORCE_SYNC | 同步/异步路径选择，配合 `can_execute_sync()` |

### 2.2 关键字段

| 字段 | 类型 | 行号 | 说明 |
|------|------|------|------|
| `metadata` | `InstructionMetadata`（static） | 101 | 通过 `_get_instruction_metadata()` 或 `_setup_metadata()` 填充 |
| `execution_status` | `ExecutionStatus` | 102 | 默认 PENDING |
| `error_message` | `String` | 103 | 错误描述 |
| `_fuse_error` | `FuseError` | 105 | 统一错误对象（v2.0+） |
| `log_level` | `FuseLogger.LogLevel` (@export) | 131 | 默认 INFO |
| `completion_timing` | `CompletionSignalTiming` (@export) | 140 | 默认 ON_FINISH |
| `execution_mode` | `ExecutionMode` (@export) | 143 | 默认 AUTO_DETECT |
| `_timeout_timer` / `_timeout_duration` / `_execution_start_time` | `SceneTreeTimer` / `float` / `float` | 146–148 | 超时管理 |
| `_is_synchronous_hint` / `_sync_capability_cached` / `_sync_capability_detected` / `_sync_hint_manually_set` | `bool` | 134–137 | 智能同步检测缓存 |
| `_last_locale` | `String` | 242 | i18n 资源名同步：上次更新 resource_name 时所用语言 |
| `_is_finished_connected` | `bool` | 104 | 防止 `finished` 重复连接 |

### 2.3 信号

```gdscript
signal finished   # base_instruction.gd:56
```

指令完成时发出（无论成功/取消/出错）。`ON_START` 模式下在 `_start_execution()` 内立即发出；`ON_FINISH` 模式下在 `_on_execution_completed()` 内发出。`_on_execution_error()` 无论 timing 都会发出。

## 3. 执行生命周期

```
execute(context)            [子类实现，@abstract]
    └── _start_execution(context)        # :391 设状态 RUNNING + 时间戳 + 超时计时器
            └── (ON_START 模式立即 _on_execution_completed)
    └── ... 子类业务逻辑 ...
    └── _on_execution_completed()        # :694 设 COMPLETED + 清理 + (ON_FINISH 时) emit finished
    │   或 _on_execution_error(...)      # :718 set_error + 清理 + emit finished
    │   或 cancel()                      # :466 设 CANCELLED + emit finished
    │   或 _on_timeout()                 # :953 set_error(TIMEOUT_ERROR) + emit finished
    └── reset()                          # :889 复位 PENDING、清错误、断信号、清缓存
```

**状态查询方法**：`get_execution_status()` / `is_running()` / `is_completed()` / `has_error()` / `get_error_message()` / `get_execution_time()`（仅 RUNNING 有效）。

## 4. i18n 资源名同步（_set 拦截）

`_set(property, value)` 拦截 `resource_name` 写入（base_instruction.gd:256–274）：

1. 调用 `FuseLocalization.init()` 确保本地化就绪。
2. 比较 `FuseLocalization.get_locale_code()` 与 `_last_locale`。
3. 语言变化（或首次设置）→ 调用 `_update_resource_name()` 重新生成翻译名。
4. 始终返回 `false`，让 Godot 继续默认写入（写入的是我们刚刷新的值）。

**触发场景**：编辑器切换语言、从磁盘反序列化 .tres 文件后。配合 `_last_locale` 字段（:242）实现"语言变化时自动刷新检查器显示"。

## 5. 图标四级回退（get_icon）

`get_icon() -> Texture2D`（base_instruction.gd:643–666）从脚本静态方法 `_get_instruction_metadata()` 取 metadata，按以下优先级返回（与 `FuseMetadata.get_icon_texture()` 一致）：

| 优先级 | 字段 | 来源 |
|--------|------|------|
| 1 | `builtin_icon` | `FuseIconManager.get_builtin_icon()` — Godot 内置图标 |
| 2 | `custom_icon` | `FuseIconManager.get_custom_icon()` — Fuse 自定义图标库 |
| 3 | `icon_name` | 先 `has_custom_icon()` 查自定义库，命中则取自定义；否则 `get_builtin_icon()` 取内置（向后兼容） |
| 4 | `icon` | `Texture2D` 直接资源引用 |

> 注意第 3 级的"先 custom 再 builtin"二级回退——这是为了兼容旧 `icon_name` 字段，新代码推荐用 `builtin_icon`/`custom_icon`。

## 6. Codegen 静态分析钩子

供 `InstructionAnalyzer`（codegen）静态提取指令的变量/节点/信号引用，默认空实现，由 codegen 脚本自动覆写子类（base_instruction.gd:316–344）。未 codegen 的组件由分析器静默降级处理。

```gdscript
# :329 — 该指令读写的变量引用
static func _get_variable_accesses() -> Array:
    # 每项: { "prop": String, "scope_prop": String, "mode": "read"|"write"|"read_write", "condition_prop": String }
    return []

# :335 — 该指令引用的场景节点属性名（仅补充类型非 NodePath 的，如 String 存的 *_node）
static func _get_nodepath_props() -> Array:
    # Array[String]；NodePath 类型属性由反射自动覆盖，无需声明
    return []

# :343 — 该指令涉及的自定义信号信息
static func _get_signal_info() -> Dictionary:
    # { "declared": Array[String], "emitted": Array[String] }
    return {"declared": [], "emitted": []}
```

**用途**：编辑器的依赖分析、变量作用域校验、节点引用检查、信号连线提示等——无需运行指令即可静态推断其副作用。

## 7. 与 RuntimeInstructionInstance 协作

为支持"同一指令资源 × 多运行时实例"模式（如循环、并行、调试断点），`BaseInstruction` 提供四个钩子（base_instruction.gd:1236–1294），将运行时状态从 Resource 解耦到 `RuntimeInstructionInstance`（`RefCounted`，runtime_instruction_instance.gd）：

| 方法 | 行号 | 默认行为 |
|------|------|----------|
| `get_default_runtime_state() -> Dictionary` | 1247 | 返回 `{initialized, execution_status, timer, elapsed_time, is_running}` |
| `execute_with_runtime_instance(ri) -> bool` | 1266 | 调 `execute_sync(ri.execution_context)`，把 `execution_status`/错误同步回 `ri.runtime_state` |
| `on_runtime_pause(ri) -> void` | 1284 | 空实现，子类可重写（如暂停 Tween） |
| `on_runtime_resume(ri) -> void` | 1293 | 空实现 |

**RuntimeInstructionInstance 关键字段**（runtime_instruction_instance.gd）：`runtime_state: Dictionary`（:31）、`execution_context: ExecutionContext`（:32）、`_has_error: bool`（:43）、`_error_message: String`（:44），构造函数 `_init(inst, context, runner)`（:55）通过 `_initialize_runtime_state()`（:72）从指令的 `get_default_runtime_state()` 复制初始状态。

**使用场景**：ForEachInstruction 每轮迭代独立实例、调试断点冻结/恢复、指令资源跨上下文复用。

---

## 8. 已实现特性模块（v2.0+）

以下章节按功能模块描述 v2.0 落地的能力：执行模式、完成时机、状态机、Runtime 实例协作、智能同步检测、超时管理、统一错误处理、日志、手动同步提示。这些特性已并入正式 API，不再是待改进建议。

### 2.0.1 ExecutionMode 枚举

**功能说明：** 定义指令的执行模式，用于智能执行路径优化。配合 `can_execute_sync()` 方法，使 ActionRunner 等调用方可以根据指令特征选择最优执行路径（同步/异步），从而提升整体执行效率。

**枚举定义：**

```gdscript
enum ExecutionMode {
    AUTO_DETECT,    ## 自动检测执行模式（推荐）
    FORCE_ASYNC,    ## 强制异步执行
    FORCE_SYNC      ## 强制同步执行
}
```

**相关成员：**

| 成员 | 类型 | 说明 |
|------|------|------|
| `execution_mode` | `@export var ExecutionMode` | 导出属性，默认 `AUTO_DETECT`，可在编辑器检查器中配置 |
| `can_execute_sync() -> bool` | 方法 | 根据当前 `execution_mode` 判断是否可同步执行 |

**使用场景：**

- **AUTO_DETECT**（默认）：由系统自动分析指令源码中的 `await` 关键字、`_is_synchronous()` 重写等特征来判定执行模式。适用于大多数自定义指令，无需手动配置。
- **FORCE_ASYNC**：明确要求通过异步路径执行，适用于包含 Timer 等异步机制的指令。例如 `WaitInstruction`、`TweenInstruction`。
- **FORCE_SYNC**：强制走同步快路径，跳过 await 机制。适用于性能敏感的纯计算指令，如 `MathExpression`、`VariableSetInstruction`。

### 2.0.2 CompletionSignalTiming 枚举

**功能说明：** 定义指令完成信号（`finished`）的发送时机，解决某些指令需要在执行开始时即通知调用方的场景需求。

**枚举定义：**

```gdscript
enum CompletionSignalTiming {
    ON_START,   ## 在执行开始时发送完成信号
    ON_FINISH   ## 在执行完成时发送完成信号（默认）
}
```

**相关成员：**

| 成员 | 类型 | 说明 |
|------|------|------|
| `completion_timing` | `@export var CompletionSignalTiming` | 导出属性，默认 `ON_FINISH` |
| `_start_execution()` | 方法 | 在 `ON_START` 模式下立即调用 `_on_execution_completed()` |
| `_on_execution_completed()` | 方法 | 在 `ON_FINISH` 模式下发出信号，在 `ON_START` 模式下跳过重复发送 |

**使用场景：**

- **ON_FINISH**（默认）：指令执行完毕后才发出 `finished` 信号。适用于需要等待执行结果的指令，如 `MoveNodeInstruction`、`PlayAnimationInstruction`。
- **ON_START**：在 `_start_execution()` 中立即发出完成信号，适用于"触发即完成"的指令。例如触发事件的 `FireEventInstruction`，执行逻辑主要是通知其他系统，不需要等待自身完成。

### 2.0.3 ExecutionStatus 枚举

**功能说明：** 定义指令在执行生命周期中的完整状态机，支持状态查询和状态转换验证。

**枚举定义：**

```gdscript
enum ExecutionStatus {
    PENDING,    ## 等待执行
    RUNNING,    ## 正在执行
    COMPLETED,  ## 执行完成
    CANCELLED,  ## 已取消
    ERROR       ## 执行出错
}
```

**相关成员：**

| 方法签名 | 返回值 | 说明 |
|----------|--------|------|
| `get_execution_status() -> ExecutionStatus` | 枚举值 | 获取当前状态 |
| `is_running() -> bool` | `bool` | 等价于 `status == RUNNING` |
| `is_completed() -> bool` | `bool` | 等价于 `status == COMPLETED` |
| `has_error() -> bool` | `bool` | 等价于 `status == ERROR` |
| `reset()` | `void` | 重置状态为 `PENDING`，同时清除 `_fuse_error`、断开信号、清理超时计时器、重置同步能力缓存 |

**状态转换流程：**

```
PENDING → RUNNING → COMPLETED
                  → CANCELLED
                  → ERROR
```

**使用场景：**

- `ActionRunner` 在调度指令前检查 `PENDING` 状态，防止重复执行。
- 调试面板通过 `get_debug_info()` 输出 `ExecutionStatus.keys()[status]` 来显示可读的状态名称。
- `reset()` 方法在指令需要被复用时调用（如循环指令中的子指令重置），确保干净的初始状态。

### 2.0.4 RuntimeInstructionInstance 支持

> 协作架构与方法表见本文 §7；本节补充方法签名细节。

**功能说明：** 引入运行时实例架构，将指令的运行时状态（如计时器、已用时间、是否正在运行等）从指令资源本身解耦到独立的 `RuntimeInstructionInstance` 对象中。这使得同一个指令资源可以被多个运行时实例共享，同时各自维护独立的执行状态。

**方法签名：**

```gdscript
## 获取默认运行时状态字典（子类可重写以声明自定义状态）
func get_default_runtime_state() -> Dictionary:
    return {
        "initialized": true,
        "execution_status": ExecutionStatus.PENDING,
        "timer": null,
        "elapsed_time": 0.0,
        "is_running": false
    }

## 使用运行时实例执行指令（子类可重写）
## 返回 bool 表示是否同步完成
func execute_with_runtime_instance(runtime_instance: RuntimeInstructionInstance) -> bool

## 暂停回调，运行时实例被暂停时调用
func on_runtime_pause(runtime_instance: RuntimeInstructionInstance) -> void

## 恢复回调，运行时实例被恢复时调用
func on_runtime_resume(runtime_instance: RuntimeInstructionInstance) -> void
```

**默认实现行为：**

- `get_default_runtime_state()`：返回包含 `initialized`、`execution_status`、`timer`、`elapsed_time`、`is_running` 五个字段的默认字典。
- `execute_with_runtime_instance()`：内部调用 `execute_sync()`，并将执行状态和错误信息同步回 `runtime_instance.runtime_state`。
- `on_runtime_pause()` / `on_runtime_resume()`：空实现，子类可重写以实现暂停/恢复逻辑（如暂停 Tween 动画）。

**使用场景：**

- **循环指令（ForEachInstruction）**：每次循环迭代创建独立的 `RuntimeInstructionInstance`，确保子指令在多轮循环中状态互不干扰。
- **调试断点系统**：暂停时通过 `on_runtime_pause()` 冻结当前执行状态，恢复时通过 `on_runtime_resume()` 继续执行。
- **指令复用**：同一个 `BaseInstruction` 资源可以在不同上下文中被多次执行，每次执行使用独立的运行时实例。

### 2.0.5 智能执行模式检测

**功能说明：** 在 `AUTO_DETECT` 模式下，系统通过多层次检测策略判断指令是否适合同步执行，从而让 ActionRunner 自动选择最优执行路径，无需开发者手动标注。

**检测优先级链：**

```
1. 子类重写 _is_synchronous() → 使用其返回值
2. 手动设置 set_synchronous_hint() → 使用 hint 值
3. 源码分析 _contains_await_in_code() → 检测 await 关键字
4. 默认假设为同步
```

**方法签名：**

```gdscript
## 公开接口：根据 execution_mode 判断是否可同步执行
func can_execute_sync() -> bool

## 自动检测同步能力（内部使用）
func _detect_sync_capability() -> bool

## 检查是否包含异步操作（核心检测逻辑，带缓存）
func _has_async_operations() -> bool

## 源码级别检测 await 关键字（排除注释）
func _contains_await_in_code(source: String) -> bool

## 同步执行包装器，返回 bool 表示是否同步完成
func execute_sync(context: ExecutionContext) -> bool
```

**缓存机制：**

- `_sync_capability_cached: bool`：缓存的检测结果。
- `_sync_capability_detected: bool`：标记是否已完成检测，避免重复分析源码。
- `reset()` 方法会清除缓存，确保每次执行前重新检测。

**使用场景：**

- **ActionRunner 优化**：`execute_sync()` 包装器先调用 `can_execute_sync()`，如果可以同步执行则直接返回结果，避免不必要的 `await` 开销。
- **验证阶段警告**：`validate_async_in_sync_mode()` 静态方法用于验证同步模式下是否包含异步子指令，生成警告信息。
- **自定义指令**：对于使用回调而非 `await` 的异步指令，开发者可调用 `set_synchronous_hint(false)` 明确声明异步特性。

### 2.0.6 超时管理系统

**功能说明：** 为指令执行提供超时保护机制，防止指令因逻辑错误或外部依赖无响应而无限期阻塞。使用 Godot 的 `SceneTreeTimer` 实现，无需手动管理 Timer 节点。

**方法签名：**

```gdscript
## 设置超时时间（秒），0 表示禁用超时
func set_timeout(timeout_seconds: float)

## 获取当前超时时间
func get_timeout() -> float

## 检查是否启用了超时
func has_timeout() -> bool

## 获取当前执行已耗时（秒），仅在 RUNNING 状态下返回有效值
func get_execution_time() -> float

## 创建 SceneTreeTimer 并连接超时回调（内部方法）
func _setup_timeout_timer()

## 断开并清理超时计时器（内部方法）
func _cleanup_timeout_timer()

## 超时触发时的处理逻辑（内部方法）
func _on_timeout()
```

**执行流程：**

```
_start_execution()
    ├── 记录 _execution_start_time
    ├── _setup_timeout_timer()
    │     ├── 检查 has_timeout()
    │     ├── _cleanup_timeout_timer()（清理旧计时器）
    │     └── scene_tree.create_timer(_timeout_duration)
    │           └── timeout.connect(_on_timeout)
    └── 执行指令逻辑

_on_timeout()
    ├── 检查 execution_status == RUNNING
    ├── 计算已用时间 elapsed_time
    ├── set_error(..., TIMEOUT_ERROR, context)
    ├── _cleanup_timeout_timer()
    └── finished.emit()

_on_execution_completed() / _on_execution_error() / cancel()
    └── _cleanup_timeout_timer()
```

**相关字段：**

| 字段 | 类型 | 说明 |
|------|------|------|
| `_timeout_timer` | `SceneTreeTimer` | Godot 场景树计时器引用 |
| `_timeout_duration` | `float` | 超时时间（秒），0 表示无超时 |
| `_execution_start_time` | `float` | 执行开始时间戳（秒） |

**使用场景：**

- **网络请求指令**：设置合理超时防止网络阻塞。
- **玩家交互等待**：设置超时后自动跳过等待状态。
- **调试模式**：为可疑指令临时设置较短超时，快速定位无限循环问题。

### 2.0.7 统一错误处理

**功能说明：** 通过 `_fuse_error` 字段和 `FuseError` 类实现结构化错误处理，替代简单的字符串错误消息，支持错误类型分类、上下文信息收集和日志系统集成。

**方法签名：**

```gdscript
## 设置错误（支持翻译键自动翻译）
func set_error(
    message: String,
    error_type: FuseError.ErrorType = FuseError.ErrorType.EXECUTION_ERROR,
    context: Dictionary = {}
)

## 创建本地化错误（通过翻译键+参数）
func set_error_localized(
    message_key: String,
    error_type: FuseError.ErrorType = FuseError.ErrorType.EXECUTION_ERROR,
    args: Dictionary = {},
    context: Dictionary = {}
)

## 内部错误处理方法（设置错误 + 发出 finished 信号）
func _on_execution_error(
    error: String,
    error_type: FuseError.ErrorType = FuseError.ErrorType.EXECUTION_ERROR,
    context: Dictionary = {}
)
```

**FuseError.ErrorType 枚举值：**

| 值 | 说明 |
|------|------|
| `VALIDATION_ERROR` | 验证错误 |
| `EXECUTION_ERROR` | 执行错误（默认） |
| `CONFIGURATION_ERROR` | 配置错误 |
| `RUNTIME_ERROR` | 运行时错误 |
| `TIMEOUT_ERROR` | 超时错误 |

**`_fuse_error` 字段行为：**

- 类型为 `FuseError`，通过 `FuseError.create_with_context()` 工厂方法创建。
- 自动附加 `instruction_name` 和 `instruction_description` 到错误上下文。
- `get_debug_info()` 方法在有 `_fuse_error` 时会附加 `fuse_error` 详细信息。
- `reset()` 方法会将 `_fuse_error` 置为 `null`。

**`set_error()` 与 `set_error_localized()` 的区别：**

- `set_error(message)`：直接使用传入的消息字符串。如果 `message` 以 `FUSE_ERROR_` 开头，会自动调用翻译系统进行本地化。
- `set_error_localized(message_key, args)`：强制通过翻译键 + 参数字典进行本地化，适用于需要参数化错误消息的场景。

**使用场景：**

- `set_error("找不到目标节点: %s" % target_path)`：简单的格式化错误消息。
- `set_error_localized("FUSE_ERROR_NODE_NOT_FOUND", {"node": target_path})`：支持多语言的参数化错误。
- `_on_execution_error(error_msg, FuseError.ErrorType.TIMEOUT_ERROR, {"timeout": 5.0})`：在超时回调中使用，明确标记错误类型。

### 2.0.8 日志系统

**功能说明：** 集成 `FuseLogger` 统一日志系统，支持分级日志输出（DEBUG/INFO/WARNING/ERROR/NONE），所有日志方法均带有源标识（`"BaseInstruction"`）和指令名称上下文。

**导出属性：**

```gdscript
@export var log_level: FuseLogger.LogLevel = FuseLogger.LogLevel.INFO
```

**FuseLogger.LogLevel 枚举值：**

| 值 | 级别 | 说明 |
|------|------|------|
| `NONE` | -- | 不输出任何日志 |
| `INFO` | 常规 | 只输出 info 级别（默认） |
| `WARNING` | 警告 | 输出 info + warning |
| `ERROR` | 错误 | 输出 info + warning + error |
| `DEBUG` | 调试 | 输出所有级别（debug + info + warning + error） |

**日志方法（共 8 个）：**

| 方法 | 说明 |
|------|------|
| `_log_debug(message)` | 调试级别日志 |
| `_log_info(message)` | 信息级别日志 |
| `_log_warning(message)` | 警告级别日志 |
| `_log_error(message)` | 错误级别日志 |
| `_log_debug_localized(message_key, args)` | 本地化调试日志 |
| `_log_info_localized(message_key, args)` | 本地化信息日志 |
| `_log_warning_localized(message_key, args)` | 本地化警告日志 |
| `_log_error_localized(message_key, args)` | 本地化错误日志 |

所有日志方法统一调用 `FuseLogger` 对应方法，传入三个固定参数：`source = "BaseInstruction"`、`level = self.log_level`、`context = get_name()`。

**使用场景：**

- 在编辑器检查器中通过 `log_level` 属性为特定指令调整日志级别，如调试时将某个指令设为 `DEBUG`。
- 本地化日志方法（`_log_*_localized`）用于输出可翻译的日志消息，确保多语言环境下日志信息的一致性。
- `FuseLogger` 内部根据 `log_level` 过滤输出，避免在生产环境中产生过多调试日志。

### 2.0.9 手动同步提示

**功能说明：** 提供编程接口让子类或工厂方法在运行时明确声明指令的同步/异步特性，作为智能检测的补充手段。主要适用于使用回调机制而非 `await` 关键字的异步指令，这类指令无法通过源码分析检测到异步特征。

**字段：**

| 字段 | 类型 | 说明 |
|------|------|------|
| `_is_synchronous_hint` | `bool` | 同步能力提示值，默认 `false` |
| `_sync_hint_manually_set` | `bool` | 标记 hint 是否被 `set_synchronous_hint()` 手动设置 |

**方法签名：**

```gdscript
## 设置同步提示（供子类或工厂使用）
func set_synchronous_hint(is_sync: bool)
```

**方法行为：**

1. 设置 `_is_synchronous_hint` 为传入的 `is_sync` 值。
2. 标记 `_sync_hint_manually_set = true`，表示此值是手动设置的。
3. 重置 `_sync_capability_detected = false`，清除缓存使下次 `_has_async_operations()` 调用时重新检测。

**与 `_is_synchronous()` 的关系：**

```gdscript
func _is_synchronous() -> bool:
    return _is_synchronous_hint
```

`_is_synchronous()` 的默认实现直接返回 `_is_synchronous_hint`。子类可以重写此方法提供自定义的同步判断逻辑，此时 `set_synchronous_hint()` 的值将不再生效。

**使用场景：**

- **回调型异步指令**：指令在 `execute()` 中启动一个异步操作并通过回调完成（不使用 `await`），此时 `_contains_await_in_code()` 无法检测到异步特征。开发者应调用 `set_synchronous_hint(false)` 来声明。
- **指令工厂**：在动态创建指令实例时，工厂方法可以根据配置参数设置同步提示，而无需修改指令源码。
- **动态配置**：在运行时根据条件改变指令的同步特性（如切换在线/离线模式时改变网络请求指令的执行模式）。
---

## 9. 相关文档

- [action_runner_analysis.md](action_runner_analysis.md) — ActionRunner 如何调度 BaseInstruction（含 `execute_sync()` / `execute_with_runtime_instance()` 调用路径）
- [execution_context_analysis.md](execution_context_analysis.md) — `ExecutionContext` 门面 + `VariableContext` + `ExecutionDiagnostics`
- `addons/fuse/core/runtime_instruction_instance.gd` — RuntimeInstructionInstance 实现
- `addons/fuse/core/base/base_instruction.gd` — 本类源码
