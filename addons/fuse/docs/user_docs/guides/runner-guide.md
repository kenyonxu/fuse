# Runner 使用指南

`Runner` 是 ActionRunner 的节点封装，提供信号绑定、程序化调用和 awaitable 执行功能。适合信号驱动和代码调用的场景。

## 概述

| 特性 | 说明 |
|------|------|
| 节点名 | Runner |
| 继承 | Node |
| 图标 | Play.svg |
| 核心功能 | 封装 ActionRunner 为场景节点 |

### Runner vs Trigger

| 特性 | Trigger | Runner |
|------|---------|--------|
| 触发方式 | 事件驱动（输入、碰撞、生命周期等） | 信号绑定或程序化调用 |
| 事件配置 | 通过 BaseEvent 资源 | 通过 target_node + signal_name |
| awaitable | 不支持 | 支持 `wait_completed()` |
| 多事件 | 需要多个 Trigger 或 MultiEventTrigger | 单个 ActionRunner |
| 典型场景 | 按键触发、碰撞响应 | 按钮点击、信号监听、代码调用 |

## 创建 Runner

1. 在场景树中右键 → 添加子节点
2. 搜索 "Runner"
3. 在 Inspector 中配置：

| 属性 | 说明 |
|------|------|
| `action_runner` | 要执行的指令序列（ActionRunner 资源） |
| `target_node` | 要监听的节点路径 |
| `signal_name` | 要监听的信号名称 |
| `log_level` | 日志级别 |

## 使用方式

### 方式一：信号绑定（自动触发）

监听任意节点的任意信号，信号触发时自动执行指令：

```
场景结构：
  UI
    Button
    Runner
      action_runner: 点击后的指令序列
      target_node: ../Button
      signal_name: "pressed"

→ 用户点击按钮 → pressed 信号 → Runner 自动执行指令
```

常用信号绑定示例：

| 目标节点 | 信号名 | 说明 |
|---------|--------|------|
| Button | pressed | 按钮点击 |
| Timer | timeout | 计时器结束 |
| AnimationPlayer | animation_finished | 动画播放完成 |
| Area2D | body_entered | 物体进入区域 |
| HSlider | value_changed | 滑块值改变 |

### 方式二：代码调用（程序化触发）

```gdscript
# 获取 Runner 引用
@onready var runner: Runner = $Runner

# 手动执行
runner.run()

# 带上下文节点执行
runner.run(context_node)

# 等待执行完成
runner.run()
await runner.wait_completed()
print("指令执行完毕")

# 取消执行
runner.cancel("用户取消")
runner.stop()  # 等价于 cancel

# 检查状态
if runner.is_running():
    print("正在执行中")

# 重置（取消执行 + 断开信号 + 清理实例）
runner.reset()
```

## 信号

| 信号 | 参数 | 说明 |
|------|------|------|
| `execution_completed` | `total_time: float` | 执行完成（含耗时） |
| `execution_failed` | `error_message: String` | 执行失败 |
| `execution_canceled` | `reason: String` | 执行被取消 |

### 信号使用示例

```
场景结构：
  Player
    HealthComponent
    Runner (OnDeath)
      target_node: ../HealthComponent
      signal_name: "died"
      action_runner: 死亡处理指令序列

→ 生命值归零 → died 信号 → Runner 执行死亡指令
```

## 执行控制

### 完整的执行生命周期

```
run() → 创建 ExecutionContext → RuntimeActionRunnerInstance.run()
  → 逐条执行指令
  → 全部完成 → execution_completed.emit(total_time)
  → 执行出错 → execution_failed.emit(error_message)
  → 被取消 → execution_canceled.emit(reason)
```

### 查询执行状态

```gdscript
var status: Dictionary = runner.get_execution_status()
# 返回包含详细状态信息的字典
```

## 注意事项

- Runner 不属于事件系统，没有 Event 概念，适合简单的信号驱动场景
- 如果需要输入事件、物理碰撞等事件驱动逻辑，应使用 Trigger 或 MultiEventTrigger
- `target_node` 使用 NodePath，如果目标节点被删除，Runner 会自动清理
- 修改 `action_runner`、`target_node` 或 `signal_name` 属性会自动重建运行时实例
- `wait_completed()` 是 awaitable 方法，只能在异步函数中使用
