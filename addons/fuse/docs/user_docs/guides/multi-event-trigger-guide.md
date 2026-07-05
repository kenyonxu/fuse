# MultiEventTrigger 使用指南

`MultiEventTrigger` 是一个复合触发器节点，将多个事件-动作绑定合并到单个节点中，减少场景中的节点数量。

## 概述

| 特性 | 说明 |
|------|------|
| 节点名 | MultiEventTrigger |
| 继承 | BaseTrigger extends Node |
| 图标 | Signal.svg |
| 核心功能 | 在一个节点中管理多个事件绑定 |

### 与普通 Trigger 的对比

| 特性 | Trigger | MultiEventTrigger |
|------|---------|-------------------|
| 事件数量 | 1 个 | 多个（通过 EventBinding） |
| 条件检查 | 单独配置 | 每个绑定可独立配置 |
| 冷却控制 | 节点级 | 每个绑定独立冷却 |
| 并行评估 | 不支持 | 支持（WorkerThreadPool） |
| 场景节点数 | 多个节点 | 1 个节点 |

## 创建 MultiEventTrigger

### 方式一：直接添加

1. 在场景树中右键 → 添加子节点
2. 搜索 "MultiEventTrigger"
3. 添加后在 Inspector 中配置 `event_bindings`

### 方式二：合并现有 Trigger（推荐）

1. 在场景树中选中 2 个以上的 Trigger 节点
2. 右键点击 → **合并为 MultiEventTrigger**
3. 系统自动创建 MultiEventTrigger 并迁移所有绑定
4. 支持撤销（Ctrl+Z）恢复原始节点

## 配置 EventBinding

每个 EventBinding 包含以下可配置项：

| 属性 | 说明 |
|------|------|
| `event` | 触发事件（BaseEvent 资源） |
| `action_runner` | 触发后执行的指令序列 |
| `conditions` | 条件检查（可选，支持复合条件） |
| `enabled` | 是否启用此绑定 |
| `trigger_once` | 是否只触发一次 |
| `cooldown_mode` | 冷却模式 |
| `cooldown_time` | 冷却时间（秒） |

### 配置示例

```
EventBinding[0]:
  event: OnSceneReady          # 场景就绪时
  action_runner: 初始化指令序列
  trigger_once: true           # 只执行一次

EventBinding[1]:
  event: OnInputKey (空格键)   # 按空格键时
  action_runner: 跳跃指令序列
  conditions:
    - CheckAll:                # 必须：
      - 生命值 > 0             #   存活
      - 不在冷却中             #   冷却结束

EventBinding[2]:
  event: OnPhysicsBodyEnter   # 碰撞时
  action_runner: 受伤指令序列
  cooldown_mode: GLOBAL_COOLDOWN
  cooldown_time: 1.0           # 1 秒冷却
```

## 冷却模式

| 模式 | 说明 | 适用场景 |
|------|------|----------|
| `GLOBAL_COOLDOWN` | 上次触发后全局等待 | 防止短时间内重复触发（如受伤） |
| `PER_OBJECT_COOLDOWN` | 按触发源独立冷却 | 同一物体重复触发有冷却，不同物体无影响 |

## 运行时控制

### 手动触发

```
# 通过代码手动触发指定绑定
multi_event_trigger.trigger_binding(0)
multi_event_trigger.trigger_binding(1)
```

### 动态启用/禁用

```
# 禁用第 2 个绑定
multi_event_trigger.set_binding_enabled(1, false)

# 重新启用
multi_event_trigger.set_binding_enabled(1, true)
```

### 重置状态

```
# 重置所有触发状态和冷却计时
multi_event_trigger.reset()
```

## 拆分 MultiEventTrigger

如果需要将 MultiEventTrigger 恢复为多个独立 Trigger：

1. 在场景树中选中 MultiEventTrigger 节点
2. 右键 → **拆分为多个 Trigger**
3. 每个 EventBinding 变为独立的 Trigger 节点
4. 自动使用事件名称命名（如 OnInputKey、OnSceneReady）
5. 支持撤销（Ctrl+Z）恢复

## 信号

| 信号 | 说明 |
|------|------|
| `event_completed(context)` | 任意绑定执行完成 |
| `event_stopped(reason, context)` | 任意绑定执行停止 |
| `event_completed_with_index(index, context)` | 指定绑定执行完成 |
| `event_stopped_with_index(index, reason, context)` | 指定绑定执行停止 |

## 性能优化

MultiEventTrigger 内置了多项性能优化：

- **并行条件评估**：多个条件在 WorkerThreadPool 中并行检查
- **批量信号模式**：高频触发时减少信号开销
- **短路检查**：跳过已触发的 trigger_once、冷却中的绑定
- **状态数组预分配**：避免运行时动态查找

## 注意事项

- 合并操作要求所有 Trigger 必须在同一父节点下
- 拆分时 `enabled` 属性不会迁移（Trigger 节点没有此属性）
- 多个绑定可以引用同一个 Event 资源，各自拥有独立的运行时状态
- 如果只需要简单的单一事件触发，使用普通 Trigger 更直观
