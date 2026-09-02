# ActionRunner 分析报告


> **分析时点**：2026-07-07（经同日全量文档审计逐篇核对代码；此后实现演进以源码为准，近期已核对的机制性结论见 threading / runtime_instance / preset_nested 等篇）
> **基准代码**：`addons/fuse/core/base/action_runner.gd`（1041 行）
> **关联类**：`RuntimeActionRunnerInstance`（`core/runtime_action_runner_instance.gd`，691 行）、`CompiledInstructionSequence`（`core/execution/compiled_instruction_sequence.gd`，142 行）
> **审计勘误**：旧版本审计曾误判「`core/execution`、`core/pooling`、`core/serialization` 三目录缺失 / 幽灵引用 / 运行时崩溃」。经直接核查为**误判**——三目录及 `CompiledInstructionSequence` / `InstructionInstancePool` / `InstructionSerializer` 类**均真实存在**：`action_runner.gd:9` 的 `CompiledInstructionSequenceClass` preload 生效；`InstructionSerializer` 类定义完整（`action_runner.gd:6` 的 preload 已被注释但类仍存在于 `serialization/` 目录）。本文档反映「代码引用完整」之事实，不传播误判。

## 文档概述

本报告描述 Fuse 可视化编程系统的指令执行核心——`ActionRunner`（Resource 定义）及其运行时包装器 `RuntimeActionRunnerInstance`（RefCounted）。二者构成「**资源定义 + 运行时实例**」双层架构，是 v2.0 后的标准形态。本文档采用现状描述体例（早期「批评 + 改进建议」稿中关于「超时简单 / 并行竞态 / 代码重复」的批评已被 v2.0 实现整体覆盖，不再作为待改进项列出）。

## 1. 类与继承

```gdscript
# action_runner.gd:1-3
@tool
@icon("res://addons/fuse/icons/action_runner.svg")
class_name ActionRunner extends Resource
```

```gdscript
# runtime_action_runner_instance.gd:2-3
@tool
class_name RuntimeActionRunnerInstance extends RefCounted
```

`ActionRunner` 是 `Resource`，保存可序列化的指令定义与配置；`RuntimeActionRunnerInstance` 是 `RefCounted`，由 Trigger 持有，承载每次执行的运行时状态。`RefCounted` 选择使其可被垃圾回收、避免长期持有 Node 引用。

## 2. 核心属性

### 2.1 ActionRunner（资源定义层）

| 属性 | 类型 | 位置 | 说明 |
|------|------|------|------|
| `instructions` | `Array[BaseInstruction]` | :12 | 指令序列，setter 清空 `_validation_cache` |
| `execution_mode` | `ExecutionMode` 枚举 | :18 | `SEQUENTIAL` / `PARALLEL` |
| `stop_on_error` | `bool` | :23 | 是否在首个错误后停止 |
| `log_level` | `FuseLogger.LogLevel` | :28 | 日志级别（委托 FuseLogger） |
| `enable_instruction_timeout` | `bool`（@export） | :31 | 启用自定义指令级超时（默认 `false`） |
| `instruction_timeout` | `float`（@export） | :36 | 单指令超时秒数，setter 限制最小 `0.1`（默认 `5.0`） |
| `_compiled_cache` | `RefCounted` | :64 | `CompiledInstructionSequence` 共享缓存 |
| `_validation_cache` | `Dictionary` | :50 | 验证缓存，指令数组变化时失效 |
| `_fuse_error` | `FuseError` | :49 | 最近错误实例（统一错误处理） |

### 2.2 RuntimeActionRunnerInstance（运行时层）

| 属性 | 类型 | 位置 | 说明 |
|------|------|------|------|
| `action_runner` | `ActionRunner` | :25 | 资源定义引用 |
| `owner_trigger` | `Node` | :27 | 拥有此实例的触发器节点 |
| `runtime_state` | `Dictionary` | :26 | 运行时状态字典（`is_running` / `cancellation_reason` / `current_instruction_index` 等） |
| `_instruction_instances` | `Array[RuntimeInstructionInstance]` | :31 | 运行时指令实例（状态隔离） |
| `_instructions_validated` / `_validated_instruction_count` | `bool` / `int` | :35-36 | 验证缓存（Phase 2.5） |
| `_batch_signals` | `bool` | :40 | 批量信号模式开关 |
| `_pending_started_instructions` / `_pending_completed_instructions` | `Array[BaseInstruction]` | :41-42 | 待批量发射的指令缓冲 |
| `_is_running_cached` / `_is_canceling_cached` / `_context_cached` | `bool` / `bool` / `ExecutionContext` | :46-48 | 状态缓存变量（Phase 1） |
| `use_instruction_pool` | `bool` | :52 | 是否启用对象池 |
| `_shared_instruction_pool` | `RefCounted`（静态） | :55 | 全局共享 `InstructionInstancePool` |

## 3. 执行模式与统一执行入口

执行模式由枚举定义（`action_runner.gd:67-70`）：

```gdscript
enum ExecutionMode {
    SEQUENTIAL,    # 顺序执行
    PARALLEL       # 并行执行
}
```

- **顺序模式**（`_run_sequential`）：依次执行指令，支持同步/异步混合。统一入口 `_execute_instruction()` 包装 `instruction.execute_sync()` 返回值判定是否需要 `await`。集成条件跳过机制（`_skip_instruction_count`）和外部停止机制（`_stop_execution`）。
- **并行模式**（`_run_parallel`）：同时启动所有指令，使用内部聚合器等待全部完成，收集错误后通过 `execution_failed` 统一报告。
- `RuntimeActionRunnerInstance` 实现相同的执行模式分发逻辑（`runtime_action_runner_instance.gd:200-206`），并经对象池调度 `RuntimeInstructionInstance`。

> **勘误**：早期版本曾将 `_execute_single_instruction` 的复用视为「代码重复缺陷」。实际该逻辑已被 `_execute_instruction()`（`runtime_action_runner_instance.gd:548-556`）统一封装，重复问题已在 v2.0 解决。

## 4. 并行信号聚合器：`_SignalAggregator` vs `_ParallelSignalAggregator`

两个内部类形态相似但分别属于不同层级，需明确区分：

| 维度 | `_SignalAggregator` | `_ParallelSignalAggregator` |
|------|---------------------|------------------------------|
| 位置 | `action_runner.gd:935`（Resource 层） | `runtime_action_runner_instance.gd:507`（运行时层） |
| 用途 | Resource 内并行等待信号 | Runtime 实例内并行等待信号 |
| 完成时序 | `_on_signal_received` **先断开所有连接，再 emit**（:955-959） | `_on_signal_received` **先 emit，再断开**（:527-531），确保接收方拿到信号 |
| 安全检查 | `_disconnect_all` 仅检查 `is_connected`（:963-964） | 额外检查 `is_instance_valid(conn.signal)`（:536），防止对象已释放 |
| `PREDELETE` | `_notification` 内 `_disconnect_all`（:967-970） | 同上但加 `is_instance_valid(self)`（:541-545） |

二者均为 `RefCounted`，使用 `_completed` 标志防止多次触发。Runtime 层版本因更接近真实运行环境（对象生命周期复杂），增加了实例有效性检查。

## 5. RuntimeActionRunnerInstance 的状态隔离价值

**问题**：早期架构中 Trigger 直接调用 `ActionRunner.run()`，导致同一资源被多个 Trigger 共享时，运行时状态（`is_running`、`cancellation_reason`、`current_instruction_index`、`current_context`）相互覆盖。

**v2.0 解决方案**：每个 Trigger 持有独立的 `RuntimeActionRunnerInstance`：

```gdscript
# runtime_action_runner_instance.gd:64-67
func _init(definition: ActionRunner, trigger: Node):
    action_runner = definition
    owner_trigger = trigger
```

- 运行时状态存入 `runtime_state` 字典与 `_instruction_instances` 数组，**不污染** Resource 定义
- 同一 ActionRunner 资源可被多 Trigger 安全共享，各自独立执行 / 取消 / 计时
- Runtime 层发射独立信号（`execution_completed` / `execution_failed` / `instruction_started` 等，:17-22），让每个 Trigger 独立接收
- `RefCounted` 选择使实例可被垃圾回收，避免长期 Node 持有

## 6. 批量信号模式（Phase 2.5）

高频触发场景下，per-instruction 的 `instruction_started` / `instruction_completed` 信号发射开销显著。`RuntimeActionRunnerInstance` 提供 `set_batch_signal_mode(enabled: bool)`（:212-216）：

- 启用后，`_emit_instruction_started` / `_emit_instruction_completed`（:219-230）将指令缓存到 `_pending_started_instructions` / `_pending_completed_instructions`
- 执行结束在 `_complete_execution()` 中通过 `_flush_pending_signals()`（:232-239）一次性发射
- 禁用时（`set_batch_signal_mode(false)`）会立即刷新已缓存信号（:213-215）
- 调用方：`Trigger`（`trigger.gd:104`）与 `MultiEventTrigger`（`multi_event_trigger.gd:139`）在高频场景启用

## 7. 状态缓存变量（Phase 1 性能优化）

为减少 `runtime_state` 字典的频繁访问，运行时层引入三个缓存变量（`runtime_action_runner_instance.gd:44-48`）：

```gdscript
var _is_running_cached: bool = false              ## 运行状态缓存
var _is_canceling_cached: bool = false            ## 取消状态缓存
var _context_cached: ExecutionContext = null      ## 执行上下文缓存
```

- 启动时同步：`_is_running_cached = true; _is_canceling_cached = false; _context_cached = context`（:117-119）
- 取消时：`_is_canceling_cached = true; _is_running_cached = false`（:147-148）
- 完成时清零并同步回 `runtime_state`（:566-571）
- 多处执行路径直接读缓存变量（:104、:142、:303-304、:422-423、:492、:560、:586、:638），避免字典哈希查找

## 8. 编译缓存 CompiledInstructionSequence（Phase 3）

`CompiledInstructionSequence`（`core/execution/compiled_instruction_sequence.gd`，142 行，`class_name ... extends RefCounted`）是 Phase 3 性能优化的核心。

### 8.1 缓存内容

```gdscript
var _descriptions: PackedStringArray = []         # 预缓存的描述字符串
var _execution_callables: Array[Callable] = []    # 预绑定的执行方法（Phase 3.2 预留）
var _instruction_count: int = 0                   # 编译时指令数（失效检查）
var _is_valid: bool = false
```

### 8.2 工作机制

- `compile(action_runner)`（:40-60）：遍历指令，将 `get_description()` 返回值预存入 `_descriptions`；将 `instruction.execute` 预绑定为 Callable
- `is_valid_for(action_runner)`（:71-74）：用指令数量做快速失效检查
- ActionRunner 持有 `_compiled_cache`（`action_runner.gd:64`），所有 RuntimeActionRunnerInstance **共享**同一缓存
- Runtime 层通过 `_get_or_create_compiled_cache()`（:259-273）懒加载，并在 `_get_cached_description(index)`（:284-288）等热路径上读取

### 8.3 收益

- 避免每帧重复调用 `get_description()`（涉及元数据查表与字符串拼接）
- Phase 3.2 后续可直接使用预绑定 Callable 启动轻量级执行上下文
- 缓存失效以指令数量为键，配置变化时零成本感知
- 公共 API：`compile` / `is_valid_for` / `get_cached_description` / `get_cached_callable` / `get_instruction_count` / `is_valid` / `invalidate` / `get_cache_stats` / `get_all_descriptions`

## 9. 指令级超时配置

ActionRunner 提供双 `@export` 配置（`action_runner.gd:30-39`）：

```gdscript
@export_group("Timeout Configuration")
@export var enable_instruction_timeout: bool = false  ## 是否启用自定义指令超时检查
@export var instruction_timeout: float = 5.0          ## 单个指令超时时间（秒），最小值 0.1
```

超时判定在 `_check_timeout(context)`（`action_runner.gd:395-415`）：

```gdscript
if enable_instruction_timeout and instruction_timeout > 0:
    # 总超时 = 单指令超时 × 指令数
    effective_timeout = instruction_timeout * max(1, instructions.size())
else:
    # 默认公式：基础时间 + 每指令额外 5.0 秒
    effective_timeout = DEFAULT_TIMEOUT + (instructions.size() * 5.0)
```

超时触发时：通过 `_create_fuse_error_localized(...)` 创建 `TIMEOUT_ERROR` 类型 `FuseError`，发射本地化 `execution_failed` 信号（:407-413）。

此外，启用指令超时时，执行路径还会调用 `instruction.set_timeout(instruction_timeout)`（:321, :358）将超时值下发到单条指令——这是真正意义上的「单指令超时」。

## 10. FuseError 统一错误处理

v2.0 已全面集成 `FuseError`：

- `_fuse_error` 字段存储最近错误（`action_runner.gd:49`）
- `_create_fuse_error()` / `_create_fuse_error_localized()` 工厂方法，附加执行模式、指令数等上下文
- 错误类型覆盖：`VALIDATION_ERROR`（验证失败）、`EXECUTION_ERROR`（执行失败）、`TIMEOUT_ERROR`（超时）
- 触发点：验证阶段、单指令执行失败、并行执行失败、超时检查
- 外部查询接口：`get_fuse_error()` / `has_fuse_error()`

## 11. 对象池支持

`RuntimeActionRunnerInstance` 通过静态方法 `get_shared_pool()`（:58-61）懒初始化全局 `InstructionInstancePool`（`core/pooling/instruction_instance_pool.gd`，185 行）：

```gdscript
static func get_shared_pool() -> RefCounted:
    if not _shared_instruction_pool:
        _shared_instruction_pool = InstructionInstancePool.new(32, 128)
    return _shared_instruction_pool
```

池化 `RuntimeInstructionInstance`，减少高频触发下的 GC 压力。可通过 `use_instruction_pool = false` 回滚。

## 12. 验证缓存

- **ActionRunner**：`_validation_cache`（:50），指令数组 setter（:13-16）变化时清空
- **RuntimeActionRunnerInstance**：`_instructions_validated` + `_validated_instruction_count`（:35-36），指令数未变时跳过重复验证；`invalidate_validation_cache()`（:244-246）外部失效入口

## 13. 执行跟踪：`_execution_tracker`

`ActionRunner` 持有 `_execution_tracker`（:51），通过 `enable_debug()` / `disable_debug()` 动态控制 `ExecutionTracker` 实例（位于 `editor/debugging/`）：

- 顺序执行中每个指令前后调用 `record_instruction_start()` / `record_instruction_complete()`
- 序列开始时 `start_tracking()`，结束时 `stop_tracking()`
- `_debug_enabled`（:52）标志控制是否启用，避免生产环境性能损耗

## 总体评估

`ActionRunner` + `RuntimeActionRunnerInstance` 双层架构在 v2.0 已完成以下演进：

1. **状态隔离**：Resource 定义与运行时状态解耦，多 Trigger 共享安全
2. **性能优化**：编译缓存、对象池、批量信号、状态缓存变量、验证缓存五重组合
3. **错误标准化**：FuseError 统一错误对象 + 本地化错误键
4. **并行稳健**：Runtime 层 `_ParallelSignalAggregator` 加实例有效性检查，缓解早期竞态担忧

本文档反映 v2.0 后现状。早期版本「超时简单 / 并行竞态 / 代码重复」等批评已被上述实现整体覆盖，不再作为待改进项列出。

## 附录：v2.0 演进时间线

- **Phase 1**：状态缓存变量（`_is_running_cached` 等），减少 `runtime_state` 字典访问
- **Phase 2**：对象池（`InstructionInstancePool`），池化 `RuntimeInstructionInstance`
- **Phase 2.5**：验证缓存 + 批量信号模式（`set_batch_signal_mode`）
- **Phase 3**：编译缓存 `CompiledInstructionSequence`，预缓存描述字符串与执行 Callable
- **统一基础设施**：FuseLogger 日志、FuseError 错误、FuseLocalization 本地化错误键

---

**最后更新**：2026-07-07 | **基准版本**：v2.0 | **审计依据**：[AUDIT_REPORT_2026-07-07.md](AUDIT_REPORT_2026-07-07.md) §3.2 | **更新规格**：[UPDATE_SPEC.md](UPDATE_SPEC.md) §4.2.2
