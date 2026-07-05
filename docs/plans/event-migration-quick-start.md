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

## 快速迁移步骤（新版：自声明状态模式）

### 第一步：识别状态变量

找到你的 Event 类中的运行时状态变量：

```gdscript
class_name OnMyEvent extends BaseEvent

var _has_triggered: bool = false     # ❌ 共享状态
var _trigger_count: int = 0          # ❌ 共享状态
var _last_trigger_time: float = 0.0  # ❌ 共享状态
```

### 第二步：删除状态变量

删除这些状态变量，添加对 `RuntimeEventInstance` 的引用：

```gdscript
class_name OnMyEvent extends BaseEvent

# 🔧 运行时状态现在存储在 RuntimeEventInstance 中
var _runtime_instance_ref: RuntimeEventInstance = null
```

### 第三步：实现 get_default_runtime_state() 方法

这是**关键步骤**。在 Event 中添加 `get_default_runtime_state()` 方法来声明状态：

```gdscript
## 获取默认运行时状态
func get_default_runtime_state() -> Dictionary:
	var base = super.get_default_runtime_state()
	base["has_triggered"] = false
	base["trigger_count"] = 0
	base["last_trigger_time"] = 0.0
	return base
```

**就这么简单！** 不再需要修改 `RuntimeEventInstance._initialize_runtime_state()` 中的 match 分支。

### 第四步：修改状态访问

现在所有状态访问都通过 `RuntimeEventInstance` 进行：

**读取状态**:
```gdscript
func _on_event_triggered():
	var has_triggered: bool = false
	if _runtime_instance_ref and _runtime_instance_ref.has_runtime_state("has_triggered"):
		has_triggered = _runtime_instance_ref.get_runtime_state("has_triggered")

	if has_triggered:
		return
```

**写入状态**:
```gdscript
func _on_event_triggered():
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("has_triggered", true)
		_runtime_instance_ref.set_runtime_state("trigger_count",
			_runtime_instance_ref.get_runtime_state("trigger_count", 0) + 1
		)
```

### 第五步：清理状态

在 `terminate()` 和 `reset()` 方法中清理状态：

```gdscript
func terminate(owner_node: Node) -> void:
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("has_triggered", false)
		_runtime_instance_ref.set_runtime_state("trigger_count", 0)
	_runtime_instance_ref = null

func reset() -> void:
	super.reset()
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("has_triggered", false)
		_runtime_instance_ref.set_runtime_state("trigger_count", 0)
```

### 第六步：测试迁移结果

```bash
# 在 Godot 编辑器中测试：
# 1. 创建两个场景，使用同一个 Event
# 2. 确认两个场景都能独立触发
# 3. 确认状态不会互相影响
```

---

## 旧版 vs 新版迁移方式对比

### 旧版（已弃用）❌

需要修改 `RuntimeEventInstance._initialize_runtime_state()`，添加 match 分支：

```gdscript
# 在 RuntimeEventInstance.gd 中添加
match event_definition.get_event_type():
	"my_event":
		runtime_state["has_triggered"] = false
		runtime_state["trigger_count"] = 0
```

**缺点**:
- 每添加一个 Event 都要修改核心代码
- 违反开闭原则（Open/Closed Principle）
- 用户创建自定义 Event 不友好

### 新版（推荐）✅

在 Event 中实现 `get_default_runtime_state()` 方法：

```gdscript
# 在 Event 类中添加
func get_default_runtime_state() -> Dictionary:
	var base = super.get_default_runtime_state()
	base["has_triggered"] = false
	base["trigger_count"] = 0
	return base
```

**优点**:
- ✅ 无需修改核心代码
- ✅ 遵循开闭原则
- ✅ 用户创建自定义 Event 更方便
- ✅ 状态声明清晰明确

---

## 迁移检查清单

迁移前检查：

- [ ] 确认 Event 有运行时状态变量
- [ ] 确认 Event 可能被多个节点共享
- [ ] 备份原始 Event 文件
- [ ] 阅读 RuntimeInstance 迁移指南

迁移后验证：

- [ ] 实现了 `get_default_runtime_state()` 方法
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

**不会**。RuntimeInstance 使用轻量级字典存储状态，性能开销极小。

### Q3: 所有 Event 都需要迁移吗？

**不需要**。根据评估工具的结果：
- 12 个 Event 已迁移（使用自声明状态模式）
- 其他 Event 如果有状态共享问题才需要迁移

### Q4: 迁移需要多长时间？

单个 Event 迁移时间：**15-30 分钟**

- 识别状态变量：5 分钟
- 实现方法：5-10 分钟
- 修改状态访问：5-10 分钟
- 测试验证：5 分钟

### Q5: 迁移后如何调试？

```gdscript
# 在 Event 中添加调试输出
func get_default_runtime_state() -> Dictionary:
	print("[DEBUG] Initializing runtime state for: ", get_event_type())
	var base = super.get_default_runtime_state()
	base["my_state"] = false
	return base
```

### Q6: 如果我的 Event 有 Timer 对象怎么办？

Timer 等节点对象**不存储**在 RuntimeEventInstance 中，仍然在 Event 类中管理：

```gdscript
var _timer: Timer = null  # Timer 对象保留在 Event 类

func get_default_runtime_state() -> Dictionary:
	var base = super.get_default_runtime_state()
	base["current_count"] = 0  # 只存储计数器状态
	return base
```

---

## 相关资源

### 文档

- **完整迁移指南**: `addons/bricks/docs/migration-guide-to-runtime-instance.md`
- **状态分离方案**: `addons/bricks/docs/event-resource-sharing-solution.md`
- **工具使用指南**: `tools/README.md`

### 工具

- **评估工具**: `tools/evaluate_events_migration.py`
- **测试工具**: `tools/test_evaluation.py`

### 示例

- **已迁移的 Events**:
  - `addons/bricks/events/input/on_mouse_button.gd`
  - `addons/bricks/events/timing/on_cooldown_finished.gd`
  - `addons/bricks/events/variable/on_variable_changed.gd`
  - （共 12 个 Events）

---

## 下一步

1. **查看已迁移的示例**
   - 打开 `addons/bricks/events/input/on_mouse_button.gd`
   - 查看如何实现 `get_default_runtime_state()`

2. **开始迁移你的 Event**
   - 按照"快速迁移步骤"执行
   - 参考已迁移的 Events 示例

3. **验证迁移结果**
   - 在 Godot 编辑器中测试
   - 确认状态隔离正常

---

**文档版本**: 2.0
**最后更新**: 2026-02-03
**作者**: Bricks 开发团队

## 更新日志

**v2.0 (2026-02-03)**:
- ✨ 更新为自声明状态模式
- ✨ 添加 `get_default_runtime_state()` 方法说明
- ✨ 移除旧版 match 分支迁移方式
- 🐛 修正迁移步骤顺序

**v1.0 (2026-02-03)**:
- 🎉 初始版本
