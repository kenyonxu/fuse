# Fuse Visual Programming System - 核心架构分析报告

## 1. 概述
Fuse 是一个为 Godot 4.x 设计的可视化编程系统。通过分析 `addons/fuse` 下的核心文件，可以看出该系统采用**资源驱动 (Resource-driven)** 的架构设计，充分利用了 Godot 的 `Resource` 系统来实现序列化、编辑器集成和运行时逻辑。

系统的核心目标是将游戏逻辑解耦为可重用的**指令 (Instructions)**、**事件 (Events)** 和 **变量 (Variables)**，并通过 **执行器 (Runners)** 进行调度。

## 2. 核心架构组件

### 2.1 指令系统 (Instruction System)
指令是 Fuse 的最小执行单元。
*   **基类**: `BaseInstruction` (`addons/fuse/core/base/base_instruction.gd`)
*   **设计模式**: 命令模式 (Command Pattern)
*   **生命周期**:
    *   **初始化**: `_init` 和 `_setup_metadata` 设置元数据。
    *   **执行**: `execute(context)` 接收执行上下文。
    *   **状态管理**: 维护 `ExecutionStatus` (PENDING, RUNNING, COMPLETED, ERROR, CANCELLED)。
    *   **异步支持**: 通过 `finished` 信号支持异步操作（如等待动画播放、延迟等）。
*   **特性**:
    *   **强类型**: 内置 `InstructionMetadata` 用于编辑器描述。
    *   **错误处理**: 集成 `FuseError` 和超时机制 (`_timeout_timer`)。
    *   **验证**: `validate()` 方法用于编辑器和运行时的参数检查。

### 2.2 执行环境 (Execution Environment)
*   **类**: `ExecutionContext` (`addons/fuse/core/base/execution_context.gd`)
*   **作用**: 为指令执行提供“沙盒”环境。
*   **核心功能**:
    *   **上下文引用**: 持有 `target` (目标节点) 和 `trigger` (触发源)。
    *   **变量访问**: 统一管理 `local_variables` (局部变量) 和 `global_variables` (全局变量引用)。
    *   **状态跟踪**: 记录执行 ID、开始时间和执行历史，用于调试。
    *   **依赖注入**: 允许指令请求特定的节点或数据。

### 2.3 流程控制 (Flow Control)
*   **类**: `ActionRunner` (`addons/fuse/core/base/action_runner.gd`)
*   **作用**: 管理和执行一组指令。
*   **执行模式**:
    *   **SEQUENTIAL (顺序)**: 依次执行指令，支持 `await` 等待异步指令完成。
    *   **PARALLEL (并行)**: 同时启动所有指令，等待所有指令完成。
*   **功能**:
    *   **错误中断**: `stop_on_error` 控制是否在出错时中止序列。
    *   **超时控制**: 支持单个指令的超时设置。
    *   **批量操作**: 支持批量验证和执行。

## 3. 数据管理系统

### 3.1 变量系统
*   **基类**: `BaseVariable` (`addons/fuse/core/base/base_variable.gd`)
*   **特性**:
    *   **类型安全**: 定义了 `VariableType` 枚举，支持 Godot 基础类型及数学类型。
    *   **作用域**: `VariableScope` (LOCAL, GLOBAL)。
    *   **工厂模式**: 提供 `create_local`, `create_global` 等静态工厂方法。
    *   **类型转换**: 内置安全的类型转换和验证逻辑。

### 3.2 变量容器与全局管理（三层作用域）

> v2.0 后变量系统重构为 **local / scope / global 三层作用域**，旧的 `VariableContainer` 已标注 `@deprecated`（2026-02-08），不再推荐使用。

| 作用域 | 存储 | 涉及类 |
|--------|------|--------|
| **local（局部）** | `ExecutionContext.local_variables` 字典 | `ExecutionContext` / `VariableContext` |
| **scope（作用域）** | 挂载到节点树的 `ScopeVariableContainer`（按 `scope_id` 查找） | `ScopeVariableContainer` + `ScopeVariableManager` + `VariableContext` |
| **global（全局）** | 静态实例管理的 `BaseVariable` 字典 | `GlobalVariableAssistant`（Node 入口） + `GlobalVariableManager` + `GlobalVariableService` + `GlobalVariableResource` |

*   **VariableContainer** (`addons/fuse/core/base/variable_container.gd`)：
    *   **@deprecated（2026-02-08）**：仅作兼容保留，新代码改用上述三层结构。原职责已拆分到 `ExecutionContext.local_variables`（局部）和 `GlobalVariableAssistant`（全局）。
*   **GlobalVariableManager** (`addons/fuse/core/global_variable_manager.gd`)：
    *   **不是 autoload Node 单例**：`class_name GlobalVariableManager extends RefCounted`，通过静态字段 `static var _instance` + `static func get_instance()` 提供访问点（`global_variable_manager.gd:2/17`）。
    *   **核心服务层**：纯 RefCounted 逻辑层，不依赖场景树，提供变量 CRUD + 信号（`variable_added/removed/changed`）、持久化（`save_to_resource` / `load_from_resource` / `save_persistent_to_resource`）、线程安全的 `_mutex` 保护。
    *   **线程安全来源**：内部 Mutex 自身保护；面向用户的高层 API 由配套的 `GlobalVariableService`（RefCounted）和 `GlobalVariableAssistant`（Node，挂场景树）封装并进一步委托 Manager，`GlobalVariableResource`（Resource）负责 `.tres` 持久化格式。

## 4. 事件驱动架构 (Event-Driven Architecture)

### 4.1 触发器体系 (Trigger)
Fuse 的触发器采用**两层继承**结构（v2.0 重构后）：

*   **抽象基类** `BaseTrigger` (`addons/fuse/core/base_trigger.gd`)：
    *   `@abstract class_name BaseTrigger extends Node`
    *   集中提供公共功能：冷却检查 (`CooldownMode` 三档 NONE / COOLDOWN / THROTTLE)、执行上下文创建、事件参数同步、引擎回调转发、日志与 FuseError 集成。
    *   声明 5 个供子类实现的抽象方法，构成 Trigger 的扩展协议。
*   **具体子类 1** `Trigger` (`addons/fuse/core/trigger.gd`)：
    *   `class_name Trigger extends BaseTrigger`（注意：**不直接 `extends Node`**）
    *   单事件触发器：通过 `event_definition: BaseEvent` 与 `action_runner: ActionRunner` 两个 @export 资源字段配置一对「事件 → 动作」绑定。
*   **具体子类 2** `MultiEventTrigger` (`addons/fuse/core/multi_event_trigger.gd`)：
    *   `class_name MultiEventTrigger extends BaseTrigger`
    *   多事件触发器：使用 `EventBinding` 数组将多组 Trigger 的功能合并到单个节点，减少节点数；重载基类信号，附带 `binding_index` 标识触发来源。

**桥接作用**：触发器节点连接 **事件定义 (Resource)** 和 **动作执行 (ActionRunner / RuntimeActionRunnerInstance)**。典型流程：
    1.  在 `_ready` 中调用事件的 `initialize_with_runtime_instance(owner_node, runtime_instance)`，将事件生命周期绑定到 `RuntimeEventInstance`。
    2.  监听事件的 `triggered` 信号（信号经 Runtime 实例转发，保证多 Trigger 共享同一 Event 资源时互不干扰）。
    3.  信号触发时，由 BaseTrigger 创建 `ExecutionContext`（含冷却/节流检查）。
    4.  委派 `RuntimeActionRunnerInstance` 执行指令序列。

### 4.2 事件定义
*   **类**: `BaseEvent` (`addons/fuse/core/base/base_event.gd`)
*   **继承**: `Resource`。
*   **解耦**: 事件逻辑封装在资源中，不依赖具体节点。
*   **生命周期接口**（双签名）:
    *   `initialize(owner_node)` / `terminate(owner_node)`：传统动态绑定/解绑信号入口，由子类重写。
    *   `initialize_with_runtime_instance(owner_node, runtime_instance: RuntimeEventInstance)`（v2.0 引入，`base_event.gd:137/154`）：将事件生命周期绑定到 `RuntimeEventInstance`，保存 `_runtime_instance_ref` 引用后转调 `initialize(owner_node)`，再调用 `_initialize_runtime_state(runtime_instance)` 让子类按需消费运行时状态。这是「定义-运行时分离」架构在事件侧的入口，确保多 Trigger 共享同一 Event 资源时状态隔离。

## 5. 基础设施与工具

### 5.1 序列化
*   **类**: `InstructionSerializer` (`addons/fuse/core/serialization/instruction_serializer.gd`)
*   **目的**: 将指令对象转换为字典数据，反之亦然。
*   **解耦**: 确保核心运行时不依赖编辑器的序列化逻辑，方便存档系统集成。

### 5.2 日志与错误
*   **FuseLogger**: 提供统一的日志分级 (DEBUG, INFO, WARNING, ERROR) 和格式化输出。
*   **FuseError**: 封装运行时错误，包含错误类型、上下文信息和堆栈追踪。

## 6. 编辑器集成 (Editor Integration)
Fuse 提供了深度的编辑器集成，主要通过 `addons/fuse/editor` 目录下的脚本实现。
*   **指令注册**: `InstructionRegistry` (`addons/fuse/editor/instruction_selector/instruction_registry.gd`) 负责扫描和注册所有指令。它通过调用指令类的静态方法 `_get_instruction_metadata()` 来获取元数据，实现了指令的自动发现机制。
*   **自定义属性编辑器**: 使用 `EditorInspectorPlugin` (如 `CreateVariableInspector`) 为特定类型的属性（如变量默认值）提供自定义的 GUI，增强了用户体验。
*   **指令选择器**: 提供了一个可视化的对话框，让用户通过分类和关键词搜索并添加指令。

## 7. 事件实现细节 (Event Implementation Details)
具体事件的实现（如 `OnInputKey`）展示了 Fuse 如何处理运行时逻辑。
*   **输入处理**: 事件类（如 `OnInputKey`）直接处理输入逻辑，并根据配置（按下/释放/长按）触发信号。
*   **生命周期管理**: 通过 `initialize(owner_node)` 和 `terminate(owner_node)` 方法，事件资源可以动态地挂载到 `Trigger` 节点上，并管理自身的资源（如 `Timer`）。
*   **动态配置**: 使用 `_validate_property` 动态调整 Inspector 中的属性可见性（例如根据事件类型隐藏不相关的参数），确保配置界面的简洁和正确性。

## 8. 指令实现模式 (Instruction Implementation Patterns)
通过分析 `Print` 和 `Wait` 指令，可以总结出两种主要的指令实现模式：
*   **同步指令**: 如 `Print`，在 `execute` 方法中执行逻辑后，立即调用 `_on_execution_completed()` 结束指令。
*   **异步指令**: 如 `Wait`，在 `execute` 中启动异步操作（如创建 `SceneTreeTimer`），并等待操作完成（如连接 `timeout` 信号）后再调用 `_on_execution_completed()`。这充分利用了 Godot 的 `signal` 和 `await` 机制。
*   **元数据定义**: 所有指令都通过静态方法 `_get_instruction_metadata()` 返回 `InstructionMetadata` 对象，定义了名称、分类、描述和关键词，方便编辑器识别。

## 9. 总结
Fuse 的核心架构展现了高度的模块化和 Godot 原生亲和力：
1.  **Resource-First**: 几乎所有配置（指令、变量、事件）都是 Resource，这使得它们易于在 Godot 编辑器中保存、复用和检查。
2.  **运行时独立**: 核心逻辑 (`core/`) 与编辑器逻辑 (`editor/`) 分离，确保打包后的游戏包体精简且高效。
3.  **可扩展性**: 通过继承 `BaseInstruction` 或 `BaseEvent` 即可轻松扩展新功能，且通过元数据机制自动注册。
4.  **健壮性**: 内置了完善的错误处理、超时机制和类型验证。

## v2.0 新增特性（2026-03 更新）

以下内容总结 Fuse 系统在 v2.0 版本中引入的跨组件架构改进和新基础设施。

### FuseError 统一错误处理系统

v2.0 引入了 `FuseError`（`addons/fuse/core/logging/fuse_error.gd`）作为全系统的统一错误处理基础设施：

- **错误类型枚举**：`ErrorType` 包含 `RUNTIME_ERROR`、`VALIDATION_ERROR`、`EXECUTION_ERROR`、`TIMEOUT_ERROR`、`CONFIGURATION_ERROR` 等
- **上下文信息**：每个 FuseError 实例包含错误类型、来源组件、消息、堆栈追踪和自定义上下文字典
- **工厂方法**：`FuseError.create_with_context()` 一步创建带完整上下文的错误对象
- **集成范围**：ActionRunner、ExecutionContext、BaseTrigger、RuntimeActionRunnerInstance、RuntimeEventInstance、GlobalVariableAssistant、BaseVariable 等核心类均已集成 `_fuse_error` 字段
- **查询接口**：`get_fuse_error()` / `has_fuse_error()` 提供统一的错误查询
- **本地化支持**：配合 `_create_fuse_error_localized()` 方法，错误消息支持多语言翻译键

### FuseLogger 统一日志系统

v2.0 引入了 `FuseLogger`（`addons/fuse/core/logging/fuse_logger.gd`）作为全系统的统一日志输出层：

- **日志级别**：`LogLevel` 枚举包含 `NONE`、`DEBUG`、`INFO`、`WARNING`、`ERROR`
- **统一接口**：`log_debug()`、`log_info()`、`log_warning()`、`log_error()` 以及本地化版本 `log_*_localized()`
- **组件标识**：每个日志条目包含组件名称（如 `"ActionRunner"`、`ExecutionContext"`），便于日志过滤
- **级别过滤**：通过组件级的 `log_level` 属性控制，只有当日志级别达到阈值时才实际输出
- **全系统集成**：所有核心类均使用 FuseLogger 替代了之前的直接 `print()` / `push_warning()` / `push_error()` 调用

### Runtime*Instance 三件套

v2.0 引入了三个运行时实例类，构成了「定义-运行时分离」的核心架构模式：

1. **RuntimeEventInstance**（`addons/fuse/core/runtime_event_instance.gd`）
   - 继承 `RefCounted`，包装 `BaseEvent` 资源
   - 为每个 Trigger 提供独立的运行时状态（`runtime_state`）
   - 信号转发机制确保多 Trigger 共享同一 Event 资源时互不干扰
   - 支持自声明状态模式（`get_default_runtime_state()`）和遗留 match 分支模式

2. **RuntimeActionRunnerInstance**（`addons/fuse/core/runtime_action_runner_instance.gd`）
   - 继承 `RefCounted`，包装 `ActionRunner` 资源
   - 为每个 Trigger 提供独立的执行状态和信号
   - 对象池支持（`InstructionInstancePool`），高频触发场景下复用 RuntimeInstructionInstance
   - 批量信号模式减少 per-instruction 信号开销
   - 验证缓存避免重复验证

3. **RuntimeInstructionInstance**（从对象池获取）
   - 包装 `BaseInstruction`，为每次执行提供独立状态
   - 支持 `execute_sync()` 统一执行接口
   - 通过 `InstructionInstancePool` 管理，池化大小可配置（32~128）

这套架构解决了 Resource 共享导致的运行时状态冲突问题，同时通过对象池降低了高频触发时的 GC 压力。

### CompiledInstructionSequence 编译指令序列

v2.0 引入了 `CompiledInstructionSequence`（`addons/fuse/core/execution/compiled_instruction_sequence.gd`）作为 Phase 3 性能优化：

- **预缓存描述字符串**：`compile()` 时遍历所有指令，预生成 `get_description()` 返回值存入 `PackedStringArray`，避免运行时重复调用
- **预绑定执行方法**：将指令的 `execute` 方法引用存入 `Array[Callable]`（为 Phase 3.2 预留）
- **缓存失效检查**：使用指令数量进行快速失效判断（`is_valid_for(action_runner)`），避免不必要的重新编译
- **共享缓存**：存储在 ActionRunner 的 `_compiled_cache` 字段中，所有 RuntimeActionRunnerInstance 共享

### 表达式系统 (ExpressionHelper)

v2.0 引入了 `ExpressionHelper`（`addons/fuse/core/utils/expression_helper.gd`）作为表达式计算的统一工具类：

- **MathExpression 指令支持**：为 `MathExpression` 等表达式指令提供底层计算能力
- **共享实用逻辑**：多个表达式类（如 MathExpression、StringExpression）共享 ExpressionHelper 中的通用方法
- **类型安全的求值**：封装 Godot 的 `Expression` 类，提供类型检查和错误处理

### 架构改进总结

| 改进领域 | 解决的问题 | 核心类 |
|---------|-----------|--------|
| 错误处理 | 分散的错误处理方式，缺乏统一上下文 | FuseError |
| 日志输出 | 不可控的日志级别，格式不统一 | FuseLogger |
| 状态隔离 | Resource 共享导致运行时状态冲突 | Runtime*Instance 三件套 |
| 性能优化 | 高频触发时的重复计算和 GC 压力 | CompiledInstructionSequence + `core/pooling/` 对象池体系 |
| 变量作用域 | 只有 LOCAL/GLOBAL 两种粒度 | `ScopeVariableContainer` + `ScopeVariableManager` + `VariableContext`（旧 `VariableContainer` 已 @deprecated） |
| 全局变量 | 持久化方案不完善，非线程安全 | `GlobalVariableManager`（RefCounted + 静态 `get_instance()`） + `GlobalVariableAssistant` + `GlobalVariableService` + `GlobalVariableResource` |
| 条件评估 | 多条件串行检查影响性能 | `core/threading/ParallelConditionEvaluator` |
| 多事件支持 | 需要多个 Trigger 节点 | MultiEventTrigger |

### v2.0 附录：基础设施路径速查

*   **`core/pooling/`（对象池体系，5 类）**：
    *   `FuseObjectPool`（泛型池基类）、`FusePoolItem`（池化项协议）、`FusePoolManager`（多池统一管理）、`FuseRecycleTimer`（周期回收）、`InstructionInstancePool`（专门复用 `RuntimeInstructionInstance`，池大小 32~128 可配置）。
    *   服务于 RuntimeActionRunnerInstance 高频触发场景，降低 GC 压力。
*   **`core/threading/`（线程系统，4 类）**：
    *   `FuseTaskManager`（`extends RefCounted`，统一异步任务调度）、`ParallelConditionEvaluator`（`extends RefCounted`，多条件并行评估，配合 `BaseCondition.is_thread_safe` 标志）、`FuseThreadSafe`（线程安全 mixin / 工具）、`FuseThreadingConfig`（线程行为配置）。
*   **`ScopeVariableManager`** (`core/scope_variable_manager.gd`)：`extends Node`，挂载到节点树，按 `scope_id` 查找并管理场景中的 `ScopeVariableContainer`，为 `VariableContext` 的作用域层提供后端。
*   **`CompiledInstructionSequence`** (`core/execution/compiled_instruction_sequence.gd`)：`extends RefCounted`，详见上文「编译指令序列」小节。