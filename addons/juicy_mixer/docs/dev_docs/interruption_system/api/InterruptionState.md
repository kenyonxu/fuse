# InterruptionState API文档

## 概述

[`InterruptionState`](../../core/interruption_state.gd:6) 是中断状态数据结构，用于存储中断状态数据，管理活跃和队列中的上下文，跟踪中断历史，处理优先级队列。

## 类定义

```gdscript
class_name InterruptionState
extends RefCounted
```

## 属性

| 属性名 | 类型 | 默认值 | 描述 |
|--------|------|--------|------|
| [`target_id`](../../core/interruption_state.gd:10) | `int` | `0` | 目标节点的实例ID |
| [`active_contexts`](../../core/interruption_state.gd:11) | `Array[String]` | `[]` | 活跃上下文ID数组 |
| [`queued_contexts`](../../core/interruption_state.gd:12) | `Array[String]` | `[]` | 队列中的上下文ID数组 |
| [`current_policy`](../../core/interruption_state.gd:13) | `JuicyMixerEnms.InterruptionPolicy` | `STACK` | 当前中断策略 |
| [`transition_context`](../../core/interruption_state.gd:14) | `String` | `""` | 过渡上下文ID |
| [`transition_progress`](../../core/interruption_state.gd:15) | `float` | `0.0` | 过渡进度（0.0-1.0） |
| [`interruption_history`](../../core/interruption_state.gd:16) | `Array[Dictionary]` | `[]` | 中断历史记录数组 |
| [`priority_queue`](../../core/interruption_state.gd:17) | `Array[Dictionary]` | `[]` | 优先级队列 |

## 构造函数

### `_init(target: Node = null)`

创建新的中断状态实例。

**参数:**
- `target` (Node, 可选): 目标节点，用于获取实例ID

**示例:**
```gdscript
# 创建状态
var state = InterruptionState.new(target_node)

# 创建空状态
var empty_state = InterruptionState.new()
```

## 活跃上下文管理

### `add_active_context(context_id: String) -> void`

添加活跃上下文。

**参数:**
- `context_id` (String): 上下文ID

**示例:**
```gdscript
state.add_active_context("effect_001")
```

### `remove_active_context(context_id: String) -> void`

移除活跃上下文。

**参数:**
- `context_id` (String): 上下文ID

**示例:**
```gdscript
state.remove_active_context("effect_001")
```

### `has_active_context(context_id: String) -> bool`

检查是否有指定的活跃上下文。

**参数:**
- `context_id` (String): 上下文ID

**返回值:**
- `bool`: 是否存在该上下文

**示例:**
```gdscript
if state.has_active_context("effect_001"):
    print("上下文正在活跃")
```

### `get_active_context_count() -> int`

获取活跃上下文数量。

**返回值:**
- `int`: 活跃上下文数量

**示例:**
```gdscript
var count = state.get_active_context_count()
print("活跃上下文数量: ", count)
```

### `clear_active_contexts() -> void`

清空所有活跃上下文。

**示例:**
```gdscript
state.clear_active_contexts()
```

## 队列上下文管理

### `add_queued_context(context_id: String) -> void`

添加队列上下文。

**参数:**
- `context_id` (String): 上下文ID

**示例:**
```gdscript
state.add_queued_context("effect_002")
```

### `remove_queued_context(context_id: String) -> void`

移除队列上下文。

**参数:**
- `context_id` (String): 上下文ID

**示例:**
```gdscript
state.remove_queued_context("effect_002")
```

### `has_queued_context(context_id: String) -> bool`

检查是否有指定的队列上下文。

**参数:**
- `context_id` (String): 上下文ID

**返回值:**
- `bool`: 是否存在该上下文

**示例:**
```gdscript
if state.has_queued_context("effect_002"):
    print("上下文在队列中")
```

### `get_next_queued_context() -> String`

获取下一个队列上下文（不移除）。

**返回值:**
- `String`: 上下文ID，如果队列为空则返回空字符串

**示例:**
```gdscript
var next_context = state.get_next_queued_context()
if not next_context.is_empty():
    print("下一个上下文: ", next_context)
```

### `pop_next_queued_context() -> String`

弹出下一个队列上下文（移除）。

**返回值:**
- `String`: 上下文ID，如果队列为空则返回空字符串

**示例:**
```gdscript
var next_context = state.pop_next_queued_context()
if not next_context.is_empty():
    print("处理上下文: ", next_context)
```

### `get_queued_context_count() -> int`

获取队列上下文数量。

**返回值:**
- `int`: 队列上下文数量

**示例:**
```gdscript
var count = state.get_queued_context_count()
print("队列上下文数量: ", count)
```

### `clear_queued_contexts() -> void`

清空所有队列上下文。

**示例:**
```gdscript
state.clear_queued_contexts()
```

## 优先级队列管理

### `add_priority_queue_item(context_id: String, priority: int) -> void`

添加优先级队列项。

**参数:**
- `context_id` (String): 上下文ID
- `priority` (int): 优先级（数值越大优先级越高）

**示例:**
```gdscript
state.add_priority_queue_item("effect_003", 10)
```

### `get_next_priority_item() -> Dictionary`

获取下一个优先级队列项（不移除）。

**返回值:**
- `Dictionary`: 队列项字典，如果队列为空则返回空字典

**示例:**
```gdscript
var item = state.get_next_priority_item()
if not item.is_empty():
    print("下一个优先级项: ", item.context_id, " 优先级: ", item.priority)
```

### `pop_next_priority_item() -> Dictionary`

弹出下一个优先级队列项（移除）。

**返回值:**
- `Dictionary`: 队列项字典，如果队列为空则返回空字典

**示例:**
```gdscript
var item = state.pop_next_priority_item()
if not item.is_empty():
    print("处理优先级项: ", item.context_id)
```

### `get_priority_queue_count() -> int`

获取优先级队列项数量。

**返回值:**
- `int`: 优先级队列项数量

**示例:**
```gdscript
var count = state.get_priority_queue_count()
print("优先级队列项数量: ", count)
```

### `clear_priority_queue() -> void`

清空优先级队列。

**示例:**
```gdscript
state.clear_priority_queue()
```

## 中断历史管理

### `add_interruption_record(record: Dictionary) -> void`

添加中断记录。

**参数:**
- `record` (Dictionary): 中断记录字典，应包含：
  - `timestamp`: 时间戳
  - `new_context`: 新上下文ID
  - `existing_context`: 现有上下文ID
  - `policy`: 中断策略
  - `target_id`: 目标ID

**示例:**
```gdscript
var record = {
    "timestamp": Time.get_ticks_msec() / 1000.0,
    "new_context": "effect_004",
    "existing_context": "effect_001",
    "policy": JuicyMixerEnms.InterruptionPolicy.STACK,
    "target_id": target_node.get_instance_id()
}
state.add_interruption_record(record)
```

### `get_interruption_history() -> Array[Dictionary]`

获取中断历史记录。

**返回值:**
- `Array[Dictionary]`: 中断历史记录数组

**示例:**
```gdscript
var history = state.get_interruption_history()
for record in history:
    print("中断记录: ", record.new_context, " -> ", record.existing_context)
```

### `clear_interruption_history() -> void`

清空中断历史记录。

**示例:**
```gdscript
state.clear_interruption_history()
```

## 过渡状态管理

### `is_transitioning() -> bool`

检查是否正在过渡。

**返回值:**
- `bool`: 是否正在过渡

**示例:**
```gdscript
if state.is_transitioning():
    print("正在进行过渡")
```

### `set_transition(context_id: String) -> void`

设置过渡状态。

**参数:**
- `context_id` (String): 过渡上下文ID

**示例:**
```gdscript
state.set_transition("transition_001")
```

### `clear_transition() -> void`

清除过渡状态。

**示例:**
```gdscript
state.clear_transition()
```

### `update_transition_progress(delta: float) -> void`

更新过渡进度。

**参数:**
- `delta` (float): 时间增量

**示例:**
```gdscript
state.update_transition_progress(get_process_delta_time())
```

### `is_transition_complete() -> bool`

检查过渡是否完成。

**返回值:**
- `bool`: 过渡是否完成

**示例:**
```gdscript
if state.is_transition_complete():
    print("过渡已完成")
```

## 实用函数

### `to_string() -> String`

获取状态字符串表示。

**返回值:**
- `String`: 状态字符串

**示例:**
```gdscript
print(state.to_string())
# 输出: InterruptionState[target_id=12345, active=2, queued=1, policy=0]
```

### `get_state_summary() -> Dictionary`

获取状态摘要信息。

**返回值:**
- `Dictionary`: 状态摘要字典

**示例:**
```gdscript
var summary = state.get_state_summary()
print("活跃上下文: ", summary.active_contexts)
print("队列上下文: ", summary.queued_contexts)
print("当前策略: ", summary.current_policy)
```

### `clear_all() -> void`

清空所有状态数据。

**示例:**
```gdscript
state.clear_all()
```

## 序列化支持

### `serialize() -> Dictionary`

序列化中断状态。

**返回值:**
- `Dictionary`: 序列化后的字典

**示例:**
```gdscript
var data = state.serialize()
# 保存到文件或网络传输
```

### `deserialize(data: Dictionary) -> bool`

从序列化数据恢复中断状态。

**参数:**
- `data` (Dictionary): 序列化数据

**返回值:**
- `bool`: 是否成功恢复

**示例:**
```gdscript
var success = state.deserialize(data)
if success:
    print("状态恢复成功")
else:
    print("状态恢复失败")
```

### `get_serialization_size() -> int`

获取序列化数据的大小（估算）。

**返回值:**
- `int`: 数据大小（字节）

**示例:**
```gdscript
var size = state.get_serialization_size()
print("序列化数据大小: ", size, " 字节")
```

### `validate_serialization_data(data: Dictionary) -> Dictionary`

验证序列化数据的有效性。

**参数:**
- `data` (Dictionary): 要验证的序列化数据

**返回值:**
- `Dictionary`: 验证结果字典 {valid: bool, issues: Array[String]}

**示例:**
```gdscript
var result = state.validate_serialization_data(data)
if result.valid:
    print("数据有效")
else:
    print("数据无效: ", result.issues)
```

## 使用示例

### 基本使用

```gdscript
# 创建状态
var state = InterruptionState.new(target_node)

# 添加活跃上下文
state.add_active_context("effect_001")

# 添加队列上下文
state.add_queued_context("effect_002")

# 添加优先级项
state.add_priority_queue_item("effect_003", 10)

# 检查状态
print("活跃上下文数量: ", state.get_active_context_count())
print("队列上下文数量: ", state.get_queued_context_count())
print("优先级队列数量: ", state.get_priority_queue_count())

# 获取状态摘要
var summary = state.get_state_summary()
print("状态摘要: ", summary)
```

### 过渡管理

```gdscript
# 设置过渡
state.set_transition("transition_001")

# 更新过渡进度
while not state.is_transition_complete():
    state.update_transition_progress(0.016)  # 60fps
    await get_tree().process_frame

# 清除过渡
state.clear_transition()
```

### 序列化和恢复

```gdscript
# 序列化状态
var data = state.serialize()
print("序列化数据: ", data)

# 验证数据
var validation = state.validate_serialization_data(data)
if validation.valid:
    # 创建新状态并恢复
    var new_state = InterruptionState.new()
    var success = new_state.deserialize(data)
    if success:
        print("状态恢复成功")
```

## 注意事项

1. **内存管理**: 中断历史记录会自动限制在100条以内，防止内存泄漏
2. **线程安全**: 此类不是线程安全的，应在主线程中使用
3. **性能考虑**: 大量上下文时，优先级队列操作可能影响性能
4. **数据验证**: 反序列化时建议先验证数据有效性

## 相关类

- [`JuicyInterruptionManager`](JuicyInterruptionManager.md) - 中断管理器
- [`ChannelInterruptionConfig`](ChannelInterruptionConfig.md) - 通道中断配置
- [`JuicyMixerEnms.InterruptionPolicy`](JuicyMixerEnums.md) - 中断策略枚举