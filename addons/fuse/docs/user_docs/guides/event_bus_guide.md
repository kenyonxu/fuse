# Event Bus 用户指南

Event Bus（事件总线）是 Fuse 可视化编程系统的全局事件通信机制，允许不同 Trigger 之间通过自定义事件进行通信。

## 快速开始

### 基本概念

Event Bus 的工作方式类似于广播电台：

- **发送事件 (SendEvent)** - 像电台广播消息
- **接收事件 (OnReceiveEvent)** - 像收音机接收特定频道的广播

```
┌─────────────────┐                    ┌─────────────────┐
│    Trigger A    │                    │    Trigger B    │
│                 │                    │                 │
│  SendEvent      │    Event Bus       │  OnReceiveEvent │
│  "player_died"  │ ─────────────────→ │  "player_died"  │
│                 │                    │        ↓        │
└─────────────────┘                    │   执行动作序列   │
                                       └─────────────────┘
```

## 组件说明

### SendEvent 指令

发送自定义事件到事件总线。

**属性:**

| 属性 | 类型 | 说明 |
|------|------|------|
| Event Name | String | 事件名称（必填） |
| Event Args | Dictionary | 事件参数（可选） |
| Deferred | Bool | 是否延迟到帧末尾发送 |

**使用场景:**
- 通知其他系统状态变化
- 触发全局响应
- 跨场景通信

### OnReceiveEvent 事件

监听并响应自定义事件。

**属性:**

| 属性 | 类型 | 说明 |
|------|------|------|
| Event Name | String | 要监听的事件名称 |
| Trigger Once | Bool | 是否只触发一次 |
| Store Args to Local | Bool | 是否将参数存储为局部变量 |
| Local Variable Prefix | String | 局部变量前缀（默认 `event_`） |

**使用场景:**
- 响应全局事件
- 监听其他 Trigger 的状态
- 实现松耦合通信

## 使用示例

### 示例 1: 玩家死亡通知

**步骤 1: 创建发送事件的 Trigger**

1. 创建一个新 Trigger
2. 添加 `OnHealthZero` 事件
3. 添加 `SendEvent` 指令
4. 设置 Event Name 为 `player_died`
5. 设置 Event Args 为 `{ "position": "$player_position" }`

**步骤 2: 创建接收事件的 Trigger (游戏结束 UI)**

1. 创建一个新 Trigger
2. 添加 `OnReceiveEvent` 事件
3. 设置 Event Name 为 `player_died`
4. 添加显示游戏结束 UI 的指令

**步骤 3: 创建接收事件的 Trigger (敌人停止)**

1. 创建一个新 Trigger
2. 添加 `OnReceiveEvent` 事件
3. 设置 Event Name 为 `player_died`
4. 添加停止敌人 AI 的指令

### 示例 2: 带参数的事件

**发送端:**
```
Event: OnItemCollected
Actions:
  - SendEvent: "item_picked_up"
    Args: {
      "item_id": "$collected_item_id",
      "item_type": "$item_type",
      "count": 1
    }
```

**接收端:**
```
Event: OnReceiveEvent: "item_picked_up"
  Store Args to Local: true
  Local Variable Prefix: "event_"
Actions:
  - Debug: "收到物品: $event_item_id"
  - UpdateInventory: $event_item_type, $event_count
```

### 示例 3: 一次性事件

**场景: 游戏首次启动教程**

```
Event: OnReceiveEvent: "game_started"
  Trigger Once: true
Actions:
  - ShowTutorial: "welcome"
```

## 事件参数访问

当 `Store Args to Local` 启用时，事件参数会自动存储为局部变量：

| 原始参数 | 局部变量名 |
|----------|------------|
| `{ "health": 100 }` | `$event_health` |
| `{ "player_id": "p1" }` | `$event_player_id` |

可以在后续指令中使用这些变量：

```
- SetHealth: $event_health
- SetPlayer: $event_player_id
```

## 最佳实践

### 事件命名规范

建议使用模块前缀避免命名冲突：

```
✅ 好的命名:
- player:died
- quest:completed
- ui:refresh
- scene:loaded

❌ 避免的命名:
- died          (太模糊)
- event1        (无意义)
- playerDied    (风格不一致)
```

### 参数设计

- 只传递必要的数据
- 使用清晰易懂的键名
- 避免嵌套过深的结构

```
✅ 好的参数:
{
  "player_id": "p1",
  "position": { "x": 100, "y": 200 }
}

❌ 避免的参数:
{
  "data": {
    "info": {
      "player": {
        "id": "p1"
      }
    }
  }
}
```

### 性能考虑

- 避免在 `_process` 中频繁发送事件
- 使用 `Deferred` 选项避免同一帧内过多事件
- 使用 `Trigger Once` 避免重复响应

## 调试技巧

### 查看事件历史

Event Bus 会记录最近 100 个事件的历史：

1. 在场景树中找到 `FuseEventBus` 节点
2. 查看 `event_history` 属性
3. 检查事件名称、参数和时间戳

### 常见问题

**Q: 事件没有被接收？**

检查:
1. Event Name 是否完全一致（区分大小写）
2. OnReceiveEvent 是否正确初始化
3. FuseEventBus 是否正确加载

**Q: 参数值不正确？**

检查:
1. 变量引用语法是否正确（`$variable_name`）
2. Store Args to Local 是否启用
3. Local Variable Prefix 是否正确

**Q: 事件触发多次？**

解决方案:
1. 启用 Trigger Once 选项
2. 检查是否有多个相同的 Trigger
3. 使用条件指令控制执行

## 与其他通信方式对比

| 方式 | 适用场景 | 复杂度 |
|------|----------|--------|
| **Event Bus** | 跨 Trigger、全局事件 | 低 |
| OnTargetSignalEmit | 监听特定节点信号 | 低 |
| OnSignalFromGroup | 监听组内信号 | 中 |
| 全局变量 + 轮询 | 状态同步 | 高 |

---

**相关文档:**
- [SendEvent 指令参考](../reference/instructions/send_event.md)
- [OnReceiveEvent 事件参考](../reference/events/on_receive_event.md)
- [自定义事件最佳实践](../best_practices/custom_event.md)

**最后更新**: 2026-02-27
