# Event RuntimeInstance 架构迁移进度报告

**日期**: 2026-02-03
**计划**: [迁移计划](./2025-02-03-event-runtime-instance-migration-plan.md)
**状态**: 进行中 (2/10 已完成)

---

## 迁移进度总览

| Event | 优先级 | 状态变量数 | 状态 | 备注 |
|-------|--------|-----------|------|------|
| OnInterval | 高 | 6 | ✅ 已完成 | 最复杂的迁移之一 |
| OnInputKey | 高 | 2 | ✅ 已完成 | 包含 Timer 管理 |
| OnMouseButton | 高 | 1 | ⏳ 待迁移 | 简单迁移 |
| OnArea2DEnter | 高 | 1 | ⏳ 待迁移 | 需要处理数组状态 |
| OnArea3DEntered | 高 | 1 | ⏳ 待迁移 | 与 OnArea2DEnter 类似 |
| OnCooldownFinished | 高 | 7 | ⏳ 待迁移 | 最复杂的迁移 |
| OnTimer | 高 | 3 | ⏳ 待迁移 | 与 OnInterval 类似 |
| OnPropertyChanged | 中 | 2 | ⏳ 待迁移 | 属性监听 |
| OnSignalFromGroup | 中 | 1 | ⏳ 待迁移 | 信号监听 |
| OnVariableChanged | 中 | 2 | ⏳ 待迁移 | 变量监听 |

**进度**: 20% (2/10)

---

## 已完成迁移

### 1. OnInterval ✅

**文件**: `addons/bricks/events/lifecycle/on_interval.gd`

**状态变量迁移**:
- `_current_repeat_count: int` → `runtime_state["current_repeat_count"]`
- `_is_running: bool` → `runtime_state["is_running"]`
- `_is_completed: bool` → `runtime_state["is_completed"]`
- `_last_input_time: float` → `runtime_state["last_input_time"]`

**关键修改**:
- 实现了 `initialize_with_runtime_instance()` 方法
- 使用 `_signal_connections` 字典管理多 Trigger 的 Timer
- 所有状态访问改为 `runtime_state.get(key, default)`
- 修改了 `_on_timer_timeout()` 接受 `owner_node` 参数
- 更新了 `terminate()` 和 `reset()` 方法清理状态

**测试建议**:
- 创建两个按钮共享同一个 OnInterval Event
- 验证每个按钮的触发次数独立
- 验证销毁一个按钮后，另一个仍然正常工作

---

### 2. OnInputKey ✅

**文件**: `addons/bricks/events/input/on_input_key.gd`

**状态变量迁移**:
- `_is_key_pressed: bool` → `runtime_state["is_key_pressed"]`
- `_has_triggered: bool` → `runtime_state["has_triggered"]`

**关键修改**:
- 实现了 `initialize_with_runtime_instance()` 方法
- 使用 `_signal_connections` 字典管理多 Trigger 的 Timer
- 修改了所有处理函数接受 `owner_node` 参数
- 更新了 `handle_input()` 方法
- 创建 context 节点并设置正确的 trigger meta

**测试建议**:
- 创建两个 Trigger 监听同一个按键
- 验证每个 Trigger 的触发状态独立

---

## RuntimeEventInstance 更新

**文件**: `addons/bricks/core/runtime_event_instance.gd`

**新增事件类型初始化**:

```gdscript
"interval":
	runtime_state["current_repeat_count"] = 0
	runtime_state["is_running"] = false
	runtime_state["is_completed"] = false
	runtime_state["last_input_time"] = 0.0
	runtime_state["initialized"] = true
	runtime_state["trigger_count"] = 0
	runtime_state["last_trigger_time"] = 0.0
	_log_debug("OnInterval 状态已初始化")

"input_key":
	runtime_state["is_key_pressed"] = false
	runtime_state["has_triggered"] = false
	runtime_state["initialized"] = true
	runtime_state["trigger_count"] = 0
	runtime_state["last_trigger_time"] = 0.0
	_log_debug("OnInputKey 状态已初始化")
```

---

## 下一步工作

### 高优先级 (剩余 5 个)

1. **OnCooldownFinished** (7 个状态变量) - 最复杂
   - 需要管理多个 Timer
   - 需要跟踪剩余时间
   - 可能需要进度条更新

2. **OnTimer** (3 个状态变量)
   - 与 OnInterval 类似
   - 可以参考 OnInterval 的迁移

3. **OnMouseButton** (1 个状态变量)
   - 简单迁移
   - 只需要处理基本状态

4. **OnArea2DEnter** (1 个状态变量)
   - 需要处理数组类型状态 (`_triggered_bodies`)

5. **OnArea3DEntered** (1 个状态变量)
   - 与 OnArea2DEnter 类似

### 中优先级 (3 个)

6. **OnPropertyChanged** (2 个状态变量)
7. **OnSignalFromGroup** (1 个状态变量)
8. **OnVariableChanged** (2 个状态变量)

---

## 迁移模式总结

经过前两个 Event 的迁移，我们已经建立了标准的迁移模式：

### 标准迁移步骤

1. **添加迁移注释**
   ```gdscript
   ## 迁移到 RuntimeInstance: 2026-02-03
   ## 状态变量:
   ## - _xxx: type - 描述
   ```

2. **删除状态变量**
   - 删除所有运行时状态变量
   - 保留配置变量（`@export`）
   - 保留 Timer 对象（在 Event 类中管理）

3. **添加辅助变量**
   ```gdscript
   var _signal_connections: Dictionary = {}
   var _owner_node_ref: Node = null
   ```

4. **实现 initialize_with_runtime_instance()**
   ```gdscript
   func initialize_with_runtime_instance(owner_node: Node, runtime_instance: RuntimeEventInstance) -> void:
       if Engine.is_editor_hint():
           return
       # 验证和初始化逻辑
   ```

5. **修改状态访问**
   ```gdscript
   # 读取
   var value = _runtime_instance_ref.runtime_state.get("key", default)

   # 写入
   _runtime_instance_ref.set_runtime_state("key", value)
   ```

6. **更新 terminate() 和 reset()**
   - 清理 RuntimeEventInstance 状态
   - 断开所有连接

7. **在 RuntimeEventInstance 添加初始化**
   ```gdscript
   "event_type":
       runtime_state["key"] = default
       ...
   ```

---

## 技术改进

1. **状态隔离**: 每个 Trigger 有独立的运行时状态
2. **资源共享**: 同一个 Event 资源可以被多个节点安全使用
3. **向后兼容**: 保留 `initialize()` 方法
4. **多 Trigger 支持**: 使用 `_signal_connections` 字典管理

---

## 已知问题

暂无

---

## 提交记录

- `[8dea154] feat: 迁移 OnInterval 和 OnInputKey 到 RuntimeInstance 架构`

---

**下一步**: 继续迁移剩余 8 个 Event，建议按优先级从高到低进行。
