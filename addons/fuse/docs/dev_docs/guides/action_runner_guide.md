# Fuse ActionRunner 开发指南

> **目标**: 为开发者提供 ActionRunner 执行器的完整开发指引，包括执行模式、指令编排、运行时实例和性能优化。

**适用对象**: Fuse 系统开发者、贡献者

**最后更新**: 2026-07-07

---

## 📋 目录

1. [系统概述](#系统概述)
2. [架构设计](#架构设计)
3. [ActionRunner API 参考](#actionrunner-api-参考)
4. [RuntimeActionRunnerInstance API](#runtimeactionrunnerinstance-api)
5. [执行模式](#执行模式)
6. [指令编排](#指令编排)
7. [信号与事件](#信号与事件)
8. [性能优化](#性能优化)
9. [最佳实践](#最佳实践)
10. [常见陷阱](#常见陷阱)

---

## 系统概述

`ActionRunner` 是 Fuse 可视化编程系统的核心执行引擎，负责管理指令序列的编排和执行。它有两种形态：

| 形态 | 类名 | 文件 | 说明 |
|------|------|------|------|
| **定义资源** | `ActionRunner` | `core/base/action_runner.gd` | Resource 子类，存储指令序列和配置 |
| **运行时实例** | `RuntimeActionRunnerInstance` | `core/runtime_action_runner_instance.gd` | RefCounted，包装 ActionRunner 提供独立运行时状态 |

### 设计目标

- **Resource 化**: ActionRunner 是 Resource，可复用、可序列化、可共享
- **双模式执行**: 支持 SEQUENTIAL（顺序）和 PARALLEL（并行）执行
- **指令编排**: 支持条件跳过（`skip_instruction`）和条件停止（`stop_execution`）
- **运行时隔离**: `RuntimeActionRunnerInstance` 为每个触发器提供独立的执行环境
- **性能优化**: 编译缓存（Phase 3）、信号批量模式（Phase 2.5）、对象池（Phase 2）

---

## 架构设计

```
                        ┌─────────────────┐
                        │   ActionRunner   │  ← Resource，可复用
                        │  (Resource)      │
                        └────────┬────────┘
                                 │ 包装
                                 ▼
                  ┌──────────────────────────┐
                  │ RuntimeActionRunnerInstance│  ← RefCounted，独立状态
                  │ (RefCounted)               │
                  └────────┬─────────────────┘
                           │ 执行
                           ▼
                  ┌──────────────────┐
                  │ ExecutionContext │  ← 执行上下文
                  │ (RefCounted)     │
                  └──────────────────┘
                           │
            ┌──────────────┼──────────────┐
            ▼              ▼              ▼
      [Instruction 1] [Instruction 2] [Instruction 3 ...]
            │              │
            ▼              ▼
     FuseLogger ──── 日志输出
     FuseError  ──── 错误处理
```

---

## ActionRunner API 参考

**文件位置**: `addons/fuse/core/base/action_runner.gd`

**类定义**:
```gdscript
@tool
@icon("res://addons/fuse/icons/action_runner.svg")
class_name ActionRunner extends Resource
```

### 导出属性

```gdscript
## 指令数组
@export var instructions: Array[BaseInstruction] = []

## 执行模式：SEQUENTIAL（顺序）或 PARALLEL（并行）
@export var execution_mode: ExecutionMode = ExecutionMode.SEQUENTIAL

## 是否在指令出错时停止
@export var stop_on_error: bool = true

## 日志级别
@export var log_level: FuseLogger.LogLevel = FuseLogger.LogLevel.INFO

## 超时配置组
@export var enable_instruction_timeout: bool = false   # 启用指令超时
@export var instruction_timeout: float = 5.0           # 单指令超时(秒)
```

### 执行状态属性

```gdscript
var is_running: bool = false                  # 是否正在执行
var is_canceling: bool = false                # 是否正在取消
var cancellation_reason: String = ""          # 取消原因
var current_context: ExecutionContext = null  # 当前执行上下文
var current_instruction_index: int = 0        # 当前指令索引
var execution_start_time: float = 0.0         # 执行开始时间
var execution_end_time: float = 0.0           # 执行结束时间
```

### 核心执行方法

```gdscript
## 执行指令序列
## 参数: context - 执行上下文
func run(context: ExecutionContext) -> void

## 停止执行（设置运行状态为 false）
func stop() -> void

## 取消执行序列
## 参数: reason - 取消原因
func cancel_execution(reason: String = "") -> void

## 获取取消状态
func get_is_canceling() -> bool

## 获取执行状态字典（含进度信息）
func get_execution_status() -> Dictionary
```

### 指令管理方法

```gdscript
## 验证所有指令
func validate_instructions() -> bool

## 添加指令（position = -1 表示末尾）
func add_instruction(instruction: BaseInstruction, position: int = -1) -> void

## 移除指令
func remove_instruction(position: int) -> void

## 清空所有指令
func clear_instructions() -> void

## 获取指定位置的指令
func get_instruction(position: int) -> BaseInstruction

## 获取指令数量
func get_instruction_count() -> int

## 检查是否包含指定指令
func has_instruction(instruction: BaseInstruction) -> bool

## 获取指令索引
func get_instruction_index(instruction: BaseInstruction) -> int
```

### 执行控制方法

```gdscript
## 设置跳过指令数量
func set_skip_instruction_count(count: int) -> void

## 设置停止执行
func set_stop_execution(stop: bool, reason: String = "") -> void

## 重置执行器状态
func reset() -> void

## 清除验证缓存
func clear_validation_cache() -> void
```

### 批量操作方法

```gdscript
## 批量执行（多个上下文）
func run_batch(contexts: Array[ExecutionContext]) -> Dictionary

## 批量验证指令
func validate_instructions_batch() -> Dictionary

## 批量获取指令信息
func get_instructions_info_batch() -> Array[Dictionary]

## 批量添加指令
func add_instructions_batch(new_instructions: Array[BaseInstruction], position: int = -1) -> Dictionary
```

### 序列化与克隆

```gdscript
## 序列化执行器
func serialize() -> Dictionary

## 反序列化执行器
func deserialize(data: Dictionary) -> void

## 克隆执行器（深拷贝指令）
func clone() -> ActionRunner
```

### 调试支持

```gdscript
func enable_debug() -> void                    # 启用调试模式
func disable_debug() -> void                   # 禁用调试模式
func is_debug_enabled() -> bool                # 检查调试状态
func get_execution_tracker()                   # 获取执行跟踪器
```

---

## RuntimeActionRunnerInstance API

**文件位置**: `addons/fuse/core/runtime_action_runner_instance.gd`

**类定义**:
```gdscript
class_name RuntimeActionRunnerInstance extends RefCounted
```

### 属性

```gdscript
var action_runner: ActionRunner                    # ActionRunner 定义资源
var runtime_state: Dictionary = {}                 # 运行时状态字典
var owner_trigger: Node                           # 拥有此实例的触发器节点
var log_level: FuseLogger.LogLevel = FuseLogger.LogLevel.INFO
var use_instruction_pool: bool = true             # 是否启用对象池
```

### 信号

```gdscript
signal execution_completed(total_time: float)
signal execution_failed(error_message: String)
signal execution_canceled(reason: String)
signal instruction_started(instruction: BaseInstruction)
signal instruction_completed(instruction: BaseInstruction)
signal all_instructions_completed()
```

### 构造函数

```gdscript
func _init(definition: ActionRunner, trigger: Node) -> void
```

### 静态对象池

```gdscript
## 共享的 InstructionInstancePool 实例
static var _shared_instruction_pool: RefCounted = null

## 获取共享池
static func get_shared_pool() -> RefCounted
```

### 性能优化特性

| 特性 | Phase | 说明 |
|------|-------|------|
| 验证缓存 | 2.5 | 避免每帧重复验证指令数组 |
| 信号批量模式 | 2.5 | 减少 per-instruction 信号发射开销 |
| 状态缓存变量 | 1 | 避免频繁的字典访问 |
| InstructionInstancePool | 2 | 共享对象池减少实例化开销 |
| CompiledInstructionSequence | 3 | 预缓存描述字符串和方法绑定 |

---

## 执行模式

### 顺序执行（SEQUENTIAL）

```gdscript
ExecutionMode.SEQUENTIAL
```

流程：
1. 遍历 `instructions` 数组
2. 检查 `_skip_instruction_count` —— 跳过指定数量的指令
3. 检查 `_stop_execution` —— 条件停止
4. 检查 `is_running` / `is_canceling`
5. 调用 `_execute_instruction(instruction, context)` 执行指令
   - 同步完成 → 检查错误和超时 → 继续下一个
   - 异步完成 → `await instruction.finished` → 继续下一个
6. 发出 `instruction_completed` 信号

### 并行执行（PARALLEL）

```gdscript
ExecutionMode.PARALLEL
```

流程：
1. 启动所有指令（不 await）
2. 使用 `_wait_for_all_tasks()` 等待全部完成
3. 使用 `_SignalAggregator` 内部类聚合多个信号的完成事件
4. 检查错误，发出 `execution_failed`（如有失败）

### 超时机制

```gdscript
# 总超时计算：
# 启用指令超时 → timeout = instruction_timeout * max(1, instructions.size())
# 未启用        → timeout = DEFAULT_TIMEOUT(30) + instructions.size() * 5.0

# 超时 → 发出 execution_failed(TIMEOUT_ERROR)
```

---

## 信号与事件

```gdscript
# ActionRunner 信号
signal execution_started                                    # 执行开始
signal instruction_started(instruction: BaseInstruction)     # 指令开始
signal instruction_completed(instruction: BaseInstruction)   # 指令完成
signal execution_completed                                   # 执行完成
signal execution_failed(error_message: String)               # 执行失败
signal execution_canceled(reason: String)                    # 执行取消
```

**信号连接管理**:

使用 `_instruction_callback_cache: Dictionary` 缓存每个指令的 callback，确保：

- 执行结束时通过 `_disconnect_all_signals()` 断开所有连接
- `_disconnect_instruction_signal()` 使用缓存的 callback 断开
- **防止内存泄漏**: `_SignalAggregator` 有 `_disconnect_all()` 机制

---

## 性能优化

### Phase 1：状态缓存变量

```gdscript
# RuntimeActionRunnerInstance 中的缓存变量
var _is_running_cached: bool = false
var _is_canceling_cached: bool = false
var _context_cached: ExecutionContext = null
```

避免频繁的 `runtime_state` 字典访问，直接使用成员变量。

### Phase 2：对象池

```gdscript
# 共享的 InstructionInstancePool
var use_instruction_pool: bool = true
static var _shared_instruction_pool: RefCounted = null

# 获取共享池
static func get_shared_pool() -> RefCounted:
    if not _shared_instruction_pool:
        _shared_instruction_pool = InstructionInstancePool.new(32, 128)
    return _shared_instruction_pool
```

### Phase 2.5：信号批量模式

```gdscript
var _batch_signals: bool = false
var _pending_started_instructions: Array[BaseInstruction] = []
var _pending_completed_instructions: Array[BaseInstruction] = []
```

批量缓冲信号，减少高频发射开销（适合每帧多次触发的场景）。

### Phase 3：编译缓存

```gdscript
var _compiled_cache: RefCounted = null  # CompiledInstructionSequence
```

所有 `RuntimeActionRunnerInstance` 共享同一编译缓存，预缓存描述字符串和方法绑定。

---

## 最佳实践

### 1. 创建 ActionRunner

```gdscript
var runner = ActionRunner.new()
runner.execution_mode = ActionRunner.ExecutionMode.SEQUENTIAL
runner.stop_on_error = true

# 添加指令
var instruction = PrintMessage.new()
instruction.message = "Hello"
runner.add_instruction(instruction)
```

### 2. 使用 RuntimeActionRunnerInstance

```gdscript
var runtime_instance = RuntimeActionRunnerInstance.new(runner, trigger_node)
runtime_instance.execution_completed.connect(_on_completed)
```

### 3. 克隆 ActionRunner

```gdscript
var cloned = original_runner.clone()  # 深拷贝
```

### 4. 条件跳过与停止

```gdscript
# 在 Condition 内部：
# 跳过后续 N 条指令
context.action_runner.set_skip_instruction_count(2)

# 停止整个执行
context.action_runner.set_stop_execution(true, "条件未满足")
```

---

## 常见陷阱

### 陷阱 1：同时多次调用 run()

ActionRunner 在执行时不允许重复调用：

```gdscript
func run(context: ExecutionContext):
    if is_running:
        context.print_warning("ActionRunner is already running")
        return
```

**解决方案**: 每次执行创建新的 `ExecutionContext`，或执行完后调用 `reset()`。

### 陷阱 2：验证缓存导致旧指令状态残留

修改 `instructions` 数组后，验证缓存不会自动清除。

**解决方案**: 调用 `clear_validation_cache()` 强制重新验证。

### 陷阱 3：信号泄漏

异步指令的 `finished` 信号连接到 ActionRunner，如果执行中途退出但未断开，会持续收到信号。

**解决方案**: ActionRunner 内部已通过 `_instruction_callback_cache` 管理信号生命周期，确保 `_complete_execution()` 中调用 `_disconnect_all_signals()`。

### 陷阱 4：并行模式中的竞态条件

并行执行时多个指令共享同一个 `ExecutionContext`，如果指令同时修改变量会导致竞态。

**解决方案**: 并行模式下使用 `VariableOperations` 的 `LOCAL` 作用域变量隔离状态，或在指令内部使用 `register_timer_callback()` 管理信号。

---

## 参考文档

- [ExecutionContext 与 Diagnostics 指南](execution_context_diagnostics_guide.md)
- [FuseLogger 日志系统指南](fuse_logger_guide.md)
- [对象池系统指南](object_pool_guide.md)
- [指令创建指南](instruction_creation_guide.md)
- [RuntimeInstructionInstance 指南](runtime_instruction_instance_guide.md)

---

**文档维护**: Fuse 开发团队 | **最后更新**: 2026-07-07 | **Godot 版本**: 4.7
