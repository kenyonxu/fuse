# Event RuntimeInstance 迁移快速指南

本文档提供 Event 迁移到 RuntimeInstance 架构的快速入门指南。

## 什么是 RuntimeInstance 架构？

RuntimeInstance 架构将 Event 资源中的**运行时状态**与**共享资源**分离，解决以下问题：

**问题**: 当同一个 Event 资源被多个所有者节点共享时，`var` 状态变量会导致状态污染。

**示例场景**:
```
ButtonA 和 ButtonB 都使用同一个 OnMouseEnter Event 资源
→ ButtonA 触发时，_has_triggered 被设置为 true
→ ButtonB 尝试触发，但检测到 _has_triggered = true
→ ButtonB 无法触发（状态污染！）
```

**解决方案**: 使用 RuntimeInstance 为每个所有者创建独立的状态实例。

---

## 如何判断是否需要迁移？

### 需要迁移的 Event

你的 Event **需要迁移** 如果：

1. ✓ 有运行时状态变量（如 `_has_triggered`, `_timer`, `_is_active`）
2. ✓ 可能被多个场景/节点共享
3. ✗ 尚未使用 RuntimeInstance 架构

### 无需迁移的 Event

你的 Event **无需迁移** 如果：

1. ✗ 无运行时状态变量（纯响应式 Event）
2. ✗ 已经使用 RuntimeInstance 架构
3. ✗ 专用于单个场景（不会共享）

---

## 快速迁移步骤

### 1. 创建 RuntimeInstance 类（可选方案）

**注意**：这是新的可选方案，你也可以继续使用方案 2。

在 Event 同一目录下创建 `runtime/[event_name]_runtime.gd`:

```gdscript
# addons/fuse/events/input/runtime/on_interval_runtime.gd
extends RuntimeEventInstance

## 运行时状态变量（从 Event 移到这里）
var _is_running: bool = false
var _is_completed: bool = false
var _current_repeat_count: int = 0
var _last_trigger_time: float = 0.0
var _timer: Timer = null

func _init() -> void:
    super._init()

## 清理资源
func _destroy() -> void:
    if _timer:
        _timer.queue_free()
        _timer = null
    super._destroy()
```

### 2. 修改 Event 类（使用通用 RuntimeEventInstance）

这是推荐的方案，使用通用的 `RuntimeEventInstance` 而不需要创建专用子类。

在 Event 中添加以下方法：

```gdscript
# addons/fuse/events/lifecycle/on_interval.gd

## 返回 RuntimeInstance 类名（如果使用专用子类）
func _get_runtime_instance_class() -> String:
    return ""  # 留空使用通用 RuntimeEventInstance

## 初始化 RuntimeInstance
func initialize_with_runtime_instance(runtime: RuntimeEventInstance) -> void:
    super.initialize_with_runtime_instance(runtime)

    # 将状态变量访问重定向到 runtime
    # 注意：状态存储在 runtime.runtime_state 字典中

    # 连接信号到 RuntimeInstance
    # 如果使用 Timer，可以在 Event 类中保留 Timer 对象
    if _timer:
        _timer.timeout.connect(_on_timer_timeout.bind(runtime))

## 使用 RuntimeInstance 的状态
func _on_timer_timeout(runtime: RuntimeEventInstance) -> void:
    # 更新 runtime 中的状态
    runtime.set_runtime_state("is_completed", true)
    runtime.set_runtime_state("current_repeat_count",
        runtime.get_runtime_state("current_repeat_count", 0) + 1
    )

    # 触发 Event
    trigger_action_runner()
```

### 3. 测试迁移结果

```bash
# 在 Godot 编辑器中测试：
# 1. 创建两个场景，使用同一个 OnInterval Event
# 2. 确认两个场景都能独立触发
# 3. 确认状态不会互相影响
```

### 4. 更新文档

在 Event 文件顶部添加注释：

```gdscript
## Event: OnInterval
##
## 迁移到 RuntimeInstance: 2026-02-03
## 状态变量:
## - _is_running: bool - 是否正在运行
## - _is_completed: bool - 是否已完成
## - _current_repeat_count: int - 当前重复次数
##
## 相关文档: addons/fuse/docs/development/runtime-instance-migration-guide.md
class_name OnInterval
extends BaseEvent
```

---

## 迁移检查清单

迁移前检查：

- [ ] 确认 Event 有运行时状态变量
- [ ] 确认 Event 可能被多个节点共享
- [ ] 备份原始 Event 文件
- [ ] 阅读 RuntimeInstance 迁移指南

迁移后验证：

- [ ] Event 功能正常工作
- [ ] 多个节点共享 Event 时状态独立
- [ ] 没有内存泄漏
- [ ] 更新了文档和注释

---

## 常见问题

### Q1: 如何查看哪些 Event 需要迁移？

```bash
# 运行评估工具
python tools/evaluate_events_migration.py

# 查看报告
cat docs/reports/event_migration_evaluation_YYYYMMDD.md
```

### Q2: 迁移后性能会受影响吗？

**不会**。RuntimeInstance 使用对象池管理，性能开销极小。

### Q3: 所有 Event 都需要迁移吗？

**不需要**。根据评估工具的结果：
- 10 个 Event 需要迁移（高+中优先级）
- 37 个 Event 可选迁移（低优先级）
- 12 个 Event 无需迁移（无状态或已迁移）

### Q4: 迁移需要多长时间？

单个 Event 迁移时间：**30-60 分钟**

- 创建 RuntimeInstance 类：10-15 分钟
- 修改 Event 类：15-30 分钟
- 测试验证：10-15 分钟

### Q5: 迁移后如何调试？

```gdscript
# 在 Event 中添加调试输出
func initialize_with_runtime_instance(runtime: RuntimeEventInstance) -> void:
    print("[DEBUG] Event initialized with RuntimeInstance: ", runtime)
    super.initialize_with_runtime_instance(runtime)
```

---

## 相关资源

### 文档

- **完整迁移指南**: `addons/fuse/docs/development/runtime-instance-migration-guide.md`
- **状态分离方案**: `addons/fuse/docs/event-resource-sharing-solution.md`
- **工具使用指南**: `tools/README.md`

### 工具

- **评估工具**: `tools/evaluate_events_migration.py`
- **测试工具**: `tools/test_evaluation.py`

### 示例

- **已迁移的 Event**: `OnMouseEnter`, `OnMouseExit`
- **RuntimeInstance 类**: `addons/fuse/events/input/runtime/on_mouse_enter_runtime.gd`

---

## 下一步

1. **运行评估工具**
   ```bash
   python tools/evaluate_events_migration.py --verbose
   ```

2. **查看评估报告**
   ```bash
   cat docs/reports/event_migration_evaluation_20260203.md
   ```

3. **开始迁移高优先级 Event**
   - 从 `OnInterval` 开始
   - 参考 `OnMouseEnter` 的实现
   - 遵循迁移步骤

4. **验证迁移结果**
   ```bash
   python tools/test_evaluation.py
   ```

---

**文档版本**: 1.0
**最后更新**: 2026-02-03
**作者**: 开发团队
