# Runner 分析

## 概述

`Runner` 是 Fuse 系统中的 Node 封装组件，将 ActionRunner 资源包装为场景节点，提供信号绑定、运行时实例管理和 awaitable 执行功能。

- **文件**: `addons/fuse/core/runner.gd` (430 行)
- **类名**: `Runner`
- **继承**: `Node`
- **图标**: `res://addons/fuse/icons/builtin/ViewportSpeed.png`

## 核心职责

1. 封装 `ActionRunner` 资源为场景节点
2. 自动创建和管理 `RuntimeActionRunnerInstance`
3. 支持信号绑定（监听任意节点的任意信号）
4. 提供 awaitable 执行 API（`wait_completed()`）
5. 提供执行状态查询和取消功能

## 与 Trigger 的关系

| 特性 | Trigger | Runner |
|------|--------|-------|
| 基类 | Node | Node |
| 事件驱动 | 自动监听 Event（多种输入方式） | 通过信号绑定手动触发 |
| 多事件 | MultiEventTrigger 支持多个绑定 | 单个 ActionRunner |
| 运行时实例 | 自动管理 | 自动管理 |
| awaitable | 不支持 | 支持 `wait_completed()` |
| 典型用途 | 按键触发、物理碰撞等 | 信号监听、程序化调用 |

## 核心属性

### 导出属性

| 属性 | 类型 | 说明 |
|------|------|------|
| `action_runner` | `ActionRunner` | 要执行的指令序列资源 |
| `target_node` | `NodePath` | 信号绑定的目标节点路径 |
| `signal_name` | `String` | 要绑定的信号名称 |
| `log_level` | `FuseLogger.LogLevel` | 日志级别（默认 NONE） |

> 导出属性均使用 `@export_storage`（:11–33）声明：值随场景/资源持久化，但**不**在 Inspector 默认显示——Inspector 入口由 `_get_property_list()`（见下文「编辑器集成」）动态生成，可对 `signal_name` 提供 enum 下拉、对属性分组归档。

### 内部状态

| 字段 | 类型 | 说明 |
|------|------|------|
| `_runtime_instance` | `RuntimeActionRunnerInstance` | 运行时 ActionRunner 实例 |
| `_bound_node` | `Node` | 信号绑定的目标节点引用 |
| `_signal_connected` | `bool` | 外部信号是否已连接 |
| `_runtime_signals_connected` | `bool` | 运行时实例信号是否已连接 |
| `current_execution_context` | `ExecutionContext` | 当前执行上下文（运行时由 `run()` 写入，:36；变量监视器/调试工具读取此字段以观察最新上下文） |

## 生命周期

### 初始化 (_ready)

```
1. 创建 RuntimeActionRunnerInstance
2. 连接 RuntimeActionRunnerInstance 信号
3. 自动设置信号绑定 (_setup_signal_binding)
```

### 清理 (_exit_tree)

```
1. 断开信号绑定
2. 断开运行时信号
3. 清理运行时实例
```

### 属性变更时

- `action_runner` 变更 → `_clear_runtime_instance()` → 重新创建
- `target_node` / `signal_name` 变更 → `_disconnect_signal_binding()` → 重新绑定

## 信号

| 信号 | 参数 | 说明 |
|------|------|------|
| `execution_completed` | `total_time: float` | 执行完成（含耗时） |
| `execution_failed` | `error_message: String` | 执行失败 |
| `execution_canceled` | `reason: String` | 执行被取消 |
| `_internal_completed` | 无 | 内部完成信号（用于 wait_completed） |

## 公共 API

### 执行控制

| 方法 | 说明 |
|------|------|
| `run(context_node)` | 执行 ActionRunner（可选上下文节点） |
| `cancel(reason)` | 取消当前执行 |
| `stop()` | 停止当前执行（cancel 的快捷方式） |
| `is_running()` | 检查是否正在执行 |
| `is_canceling()` | 检查是否正在取消 |
| `reset()` | 重置状态（取消执行、断开信号、清理实例） |

### 查询

| 方法 | 返回类型 | 说明 |
|------|---------|------|
| `get_execution_status()` | `Dictionary` | 获取详细执行状态 |
| `wait_completed()` | `void` | 等待执行完成（awaitable） |

### 执行流程

```
run() 创建 ExecutionContext → RuntimeActionRunnerInstance.run()
  → execution_completed → execution_completed.emit()
  → execution_failed → execution_failed.emit()
  → execution_canceled → execution_canceled.emit()
```

## 信号绑定机制

Runner 可以自动监听任意节点的任意信号：

```
1. 通过 target_node (NodePath) 找到目标节点
2. 通过 SignalManager.has_signal_named() 检查信号是否存在
3. 连接信号到 _on_bound_signal_triggered()
4. 信号触发后自动调用 run()
```

> 信号发现与校验统一委托 `SignalManager`：`has_signal_named(node, signal_name)`（:277）用于运行时绑定前校验；编辑器侧 `_editor_refresh_signals` 调用 `SignalManager.get_node_signals(node)`（:196）枚举目标节点全部信号用于下拉列表。

### 典型用法

```
# 在场景中添加 Runner 节点
# target_node 设置为某个按钮节点
# signal_name 设置为 "pressed"
# action_runner 配置指令序列

→ 按钮点击 → 信号触发 → Runner.run() → 执行指令
```

## 编辑器集成

`Runner` 标注 `@tool`（:2），在编辑器中提供动态 Inspector：

- **`_get_property_list()`（:92–157）** 动态生成属性列表，按组分块（`action_runner` / `signal_binding` / `configuration`）；`signal_name` 字段根据目标节点可用信号切换 hint：
  - 有信号 → `PROPERTY_HINT_ENUM` 下拉（`hint_string = ",".join(signal_names)`，:128–134）
  - 无信号 → 普通 `TYPE_STRING` 文本输入（:136–140）
- **信号列表刷新** 由三个内部字段配合（:71–73）：
  - `_editor_available_signals: Array` —— 缓存 `SignalManager.get_node_signals(target)` 的结果
  - `_editor_signals_loaded: bool` —— 标记列表是否已加载
  - `_editor_is_refreshing: bool` —— 防重入标志
- **`_editor_refresh_signals()`（:183–200）** 调用 `SignalManager.get_node_signals(target)`（:196）填充缓存，再 `notify_property_list_changed()` 通知 Inspector 重绘，最后清 `_editor_is_refreshing`。
- **`target_node` 变更触发刷新**：setter（:22–24）在 `Engine.is_editor_hint()` 下重置 `_editor_is_refreshing` 并 `call_deferred("_editor_refresh_signals")` 延迟执行，避免在属性设置中调用节点解析。
- **`_get_target_node_in_editor()`（:203–207）** 通过 `get_node_or_null(target_node)` 解析相对路径（Runner 作为场景节点直接解析自身路径）。

## 内部方法

| 方法 | 说明 |
|------|------|
| `_create_execution_context(target)`（:391–394） | 创建 `ExecutionContext`：`ExecutionContext.new(target, self)`，`target` 与 `trigger` 均指向 Runner 自身；并设置 `log_level` |
| `_on_bound_signal_triggered(_reason, _context)`（:397–398） | 绑定信号的统一回调签名 `(_reason: String = "", _context: Dictionary = {})`，**忽略参数**直接调用 `run()` |

## 与 Event 系统的关系

Runner 不是事件系统的一部分，而是 ActionRunner 的 Node 封装。它：

- 不继承 BaseTrigger（没有 Event 概念）
- 不使用 RuntimeEventInstance（只有 RuntimeActionRunnerInstance）
- 适合程序化调用和信号驱动的简单场景
- 如果需要事件驱动（输入、物理、生命周期），应使用 Trigger

## 设计决策

- **简化 API**: 只暴露 run / cancel / stop / reset 四个核心操作
- **RuntimeActionRunnerInstance 封装**: 外部不直接接触运行时实例
- **信号绑定灵活**: 可以监听任何 Node 的任何信号
- **自动清理**: 属性变更时自动重建运行时实例，防止悬空引用
