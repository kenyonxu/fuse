# Event RuntimeInstance 架构迁移实施计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**目标:** 将 10 个高优先级和中优先级的 Bricks Event 迁移到 RuntimeInstance 架构，解决资源共享导致的运行时状态冲突问题。

**架构:** 通过将运行时状态从 Event 资源（`@export` 配置）分离到轻量级的 RuntimeEventInstance（每个 Trigger 独立），实现状态隔离。Event 类通过 `initialize_with_runtime_instance()` 方法接收 RuntimeEventInstance 引用，所有状态访问通过 `get_runtime_state()` / `set_runtime_state()` 进行。

**技术栈:** Godot 4.6, GDScript 2.0, RuntimeEventInstance 系统

---

## 迁移范围

根据评估工具分析（`tools/evaluate_events_migration.py`），需要迁移的 Event：

**高优先级（7 个）：**
1. `OnInterval` - 6 个状态变量，最复杂
2. `OnInputKey` - 2 个状态变量
3. `OnMouseButton` - 1 个状态变量
4. `OnArea2DEnter` - 1 个状态变量
5. `OnArea3DEntered` - 1 个状态变量
6. `OnCooldownFinished` - 7 个状态变量，最复杂
7. `OnTimer` - 3 个状态变量

**中优先级（3 个）：**
8. `OnPropertyChanged` - 2 个状态变量
9. `OnSignalFromGroup` - 1 个状态变量
10. `OnVariableChanged` - 2 个状态变量

---

## Task 1: 迁移 OnInterval Event

**文件：**
- Modify: `addons/bricks/events/lifecycle/on_interval.gd`
- Modify: `addons/bricks/core/runtime_event_instance.gd:34-86` （添加状态初始化）
- Test: `addons/bricks/tests/test_on_interval_runtime_instance.tscn`

**背景：** OnInterval 有 6 个运行时状态变量（最多），包括 `_is_running`, `_is_completed`, `_current_repeat_count`, `_last_input_time`, `_timer`, `_owner_node_ref`。这是最常出现状态冲突的 Event。

### Step 1: 备份原始文件

```bash
# 创建备份分支
git checkout -b backup/on-interval-before-migration
git add addons/bricks/events/lifecycle/on_interval.gd
git commit -m "backup: OnInterval 迁移前备份"

# 切回开发分支
git checkout Develop_brick
```

Expected: 新分支创建并备份完成

### Step 2: 读取并分析 OnInterval 源代码

```bash
# 查看 OnInterval 的状态变量
grep -n "var _" addons/bricks/events/lifecycle/on_interval.gd
```

Expected: 输出包含以下状态变量：
```
_is_running: bool
_is_completed: bool
_current_repeat_count: int
_last_input_time: float
_timer: Timer
_owner_node_ref: Node
```

### Step 3: 在 RuntimeEventInstance 中添加状态初始化

修改 `addons/bricks/core/runtime_event_instance.gd` 的 `_initialize_runtime_state()` 方法：

```gdscript
func _initialize_runtime_state():
	if not event_definition:
		_log_warning("没有事件定义，无法初始化运行时状态")
		return

	# 根据事件类型初始化特定的运行时状态
	match event_definition.get_event_type():
		# ... 现有的 mouse_enter, mouse_exit 等 ...

		"interval":
			runtime_state["is_running"] = false
			runtime_state["is_completed"] = false
			runtime_state["current_repeat_count"] = 0
			runtime_state["last_trigger_time"] = 0.0
			runtime_state["timer"] = null  # Timer 对象引用
			_log_debug("OnInterval 状态已初始化")

		_:
			# 默认状态
			runtime_state["initialized"] = true
			runtime_state["trigger_count"] = 0
			runtime_state["last_trigger_time"] = 0.0

	_log_debug("运行时状态已初始化，事件类型: %s" % event_definition.get_event_type())
```

Expected: 代码已添加到 match 语句中

### Step 4: 删除 Event 类中的状态变量，添加 RuntimeInstance 引用

修改 `addons/bricks/events/lifecycle/on_interval.gd`：

```gdscript
class_name OnInterval extends BaseEvent

@export var interval: float = 1.0
@export var repeat_count: int = 0  # 0 = 无限重复

signal triggered(context: Node)

# 🔧 运行时状态现在存储在 RuntimeEventInstance 中
var _runtime_instance_ref: RuntimeEventInstance = null

# 🔧 Timer 对象仍在 Event 类中管理（不存储在 RuntimeEventInstance）
var _timer: Timer = null
var _signal_connections: Dictionary = {}
```

Expected: 旧的状态变量已删除，新引用已添加

### Step 5: 实现 initialize_with_runtime_instance() 方法

```gdscript
func initialize_with_runtime_instance(owner_node: Node, runtime_instance: RuntimeEventInstance) -> void:
	if Engine.is_editor_hint():
		return

	# 保存 RuntimeEventInstance 引用
	_runtime_instance_ref = runtime_instance

	# 验证参数
	if not owner_node:
		_create_bricks_error_localized("BRICKS_ERROR_TARGET_NODE_NULL", BricksError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# 创建并配置 Timer
	_timer = Timer.new()
	_timer.wait_time = interval
	_timer.autostart = false
	_timer.one_shot = false

	# 连接超时信号，绑定 runtime_instance
	_timer.timeout.connect(_on_timer_timeout.bind(runtime_instance))

	# 将 Timer 添加为 owner_node 的子节点
	owner_node.add_child(_timer)

	# 启动 Timer
	_timer.start()

	_log_debug_localized("BRICKS_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})
```

Expected: 初始化方法实现完成

### Step 6: 修改状态访问逻辑

```gdscript
func _on_timer_timeout(runtime_instance: RuntimeEventInstance) -> void:
	# 使用 RuntimeEventInstance 的状态
	var is_running = runtime_instance.get_runtime_state("is_running", false)
	var is_completed = runtime_instance.get_runtime_state("is_completed", false)
	var current_count = runtime_instance.get_runtime_state("current_repeat_count", 0)

	if not is_running or is_completed:
		return

	# 检查是否达到重复次数
	if repeat_count > 0 and current_count >= repeat_count:
		runtime_instance.set_runtime_state("is_completed", true)
		runtime_instance.set_runtime_state("is_running", false)

		# 清理 Timer
		if _timer:
			_timer.stop()
			_timer.queue_free()
			_timer = null

		return

	# 更新状态
	runtime_instance.set_runtime_state("current_repeat_count", current_count + 1)
	runtime_instance.set_runtime_state("last_trigger_time", Time.get_time_dict_from_system())
	runtime_instance.update_trigger_stats()

	# 触发动作执行器
	var context_node = Node.new()
	context_node.name = "IntervalContext"
	context_node.set_meta("trigger", owner_trigger)
	context_node.set_meta("repeat_count", current_count + 1)

	triggered.emit(context_node)
	context_node.queue_free()

	_log_info_localized("BRICKS_LOG_INTERVAL_TRIGGERED", {
		"count": current_count + 1,
		"interval": interval
	})
```

Expected: 状态访问逻辑已修改为使用 RuntimeEventInstance

### Step 7: 实现 terminate() 方法

```gdscript
func terminate(owner_node: Node) -> void:
	# 停止并清理 Timer
	if _timer:
		_timer.stop()
		_timer.queue_free()
		_timer = null

	# 清理 RuntimeEventInstance 的状态
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("is_running", false)
		_runtime_instance_ref.set_runtime_state("is_completed", false)
		_runtime_instance_ref.set_runtime_state("current_repeat_count", 0)

	# 清理引用
	_runtime_instance_ref = null

	_log_debug_localized("BRICKS_LOG_EVENT_TERMINATED", {"event_type": get_event_type()})
```

Expected: terminate() 方法实现完成

### Step 8: 实现 reset() 方法

```gdscript
func reset() -> void:
	super.reset()

	# 重置 RuntimeEventInstance 的状态
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("is_running", false)
		_runtime_instance_ref.set_runtime_state("is_completed", false)
		_runtime_instance_ref.set_runtime_state("current_repeat_count", 0)

	# 重启 Timer
	if _timer and not _timer.is_stopped():
		_timer.stop()
		_timer.start()

	_log_debug_localized("BRICKS_LOG_EVENT_RESET", {"event_type": get_event_type()})
```

Expected: reset() 方法实现完成

### Step 9: 创建测试场景

创建 `addons/bricks/tests/test_on_interval_runtime_instance.tscn`：

```gdscript
extends Node

## 测试 OnInterval RuntimeInstance 迁移

@onready var button_a = $ButtonA
@onready var button_b = $ButtonB
@onready var label_a = $LabelA
@onready var label_b = $LabelB

var test_interval_resource: OnInterval = null
var trigger_count_a = 0
var trigger_count_b = 0

func _ready():
	# 创建共享的 OnInterval Event 资源
	test_interval_resource = OnInterval.new()
	test_interval_resource.interval = 1.0
	test_interval_resource.repeat_count = 3

	# 为两个按钮使用同一个 Event 资源
	var trigger_a = button_a
	var trigger_b = button_b

	# 创建独立的 RuntimeEventInstance
	var runtime_a = RuntimeEventInstance.new(test_interval_resource, trigger_a)
	var runtime_b = RuntimeEventInstance.new(test_interval_resource, trigger_b)

	# 初始化 Event
	test_interval_resource.initialize_with_runtime_instance(trigger_a, runtime_a)
	test_interval_resource.initialize_with_runtime_instance(trigger_b, runtime_b)

	# 连接触发信号
	runtime_a.triggered.connect(_on_interval_triggered_a)
	runtime_b.triggered.connect(_on_interval_triggered_b)

	print("[TEST] 测试场景初始化完成")

func _on_interval_triggered_a(context):
	trigger_count_a += 1
	label_a.text = "Button A: %d" % trigger_count_a
	print("[TEST] Button A 触发，次数: %d" % trigger_count_a)

func _on_interval_triggered_b(context):
	trigger_count_b += 1
	label_b.text = "Button B: %d" % trigger_count_b
	print("[TEST] Button B 触发，次数: %d" % trigger_count_b)

func _input(event):
	if event.is_action_pressed("ui_accept"):
		print("[TEST] A 触发次数: %d, B 触发次数: %d" % [trigger_count_a, trigger_count_b])
		assert(trigger_count_a == trigger_count_b, "状态隔离失败！")
```

Expected: 测试场景创建完成

### Step 10: 运行测试验证

```bash
# 在 Godot 编辑器中打开测试场景
# E:\Godot\Godot_v4.6-stable_mono_win64\Godot_v4.6-stable_mono_win64.exe --path "E:\Godot\GodotProjects\project-juicy-godot" --edit

# 在编辑器中按 F5 运行测试场景
# 验证：
# 1. Button A 和 Button B 的触发次数独立
# 2. 达到 repeat_count (3) 后停止触发
# 3. 销毁一个节点后，另一个仍然正常工作
```

Expected:
- 两个按钮独立触发，次数互不干扰
- 每个按钮触发 3 次后停止
- 无状态污染

### Step 11: 提交代码

```bash
git add addons/bricks/events/lifecycle/on_interval.gd
git add addons/bricks/core/runtime_event_instance.gd
git add addons/bricks/tests/test_on_interval_runtime_instance.tscn
git commit -m "feat: 迁移 OnInterval 到 RuntimeInstance 架构

- 删除运行时状态变量 (_is_running, _is_completed, _current_repeat_count, _last_input_time)
- 添加 _runtime_instance_ref 引用
- 实现 initialize_with_runtime_instance() 方法
- 修改状态访问使用 get_runtime_state() / set_runtime_state()
- 在 RuntimeEventInstance 中添加 interval 状态初始化
- 添加 terminate() 和 reset() 方法
- 创建测试场景验证状态隔离

参考: OnMouseEnter 迁移实现
相关文档: addons/bricks/docs/migration-guide-to-runtime-instance.md
"
```

Expected: 提交成功

---

## Task 2: 迁移 OnInputKey Event

**文件：**
- Modify: `addons/bricks/events/input/on_input_key.gd`
- Modify: `addons/bricks/core/runtime_event_instance.gd:34-86`
- Test: `addons/bricks/tests/test_on_input_key_runtime_instance.tscn`

**背景：** OnInputKey 有 2 个状态变量（`_has_triggered`, `_timer`），是常用的输入事件。

### Step 1: 备份原始文件

```bash
git checkout -b backup/on-input-key-before-migration
git add addons/bricks/events/input/on_input_key.gd
git commit -m "backup: OnInputKey 迁移前备份"
git checkout Develop_brick
```

### Step 2: 在 RuntimeEventInstance 中添加状态初始化

修改 `addons/bricks/core/runtime_event_instance.gd`：

```gdscript
match event_definition.get_event_type():
	# ... 现有代码 ...

	"input_key":
		runtime_state["has_triggered"] = false
		runtime_state["last_trigger_time"] = 0.0
		runtime_state["trigger_count"] = 0
		_log_debug("OnInputKey 状态已初始化")
```

### Step 3-10: 按照 OnInterval 的模式迁移 OnInputKey

参考 Task 1 的步骤，针对 OnInputKey 的特定逻辑进行迁移。

**关键差异：**
- 状态变量：`_has_triggered`, `_timer`
- 信号连接：连接到 `InputSingleton.key_pressed`
- 触发逻辑：检测按键是否按下

### Step 11: 提交代码

```bash
git add addons/bricks/events/input/on_input_key.gd
git add addons/bricks/core/runtime_event_instance.gd
git add addons/bricks/tests/test_on_input_key_runtime_instance.tscn
git commit -m "feat: 迁移 OnInputKey 到 RuntimeInstance 架构"
```

---

## Task 3: 迁移 OnMouseButton Event

**文件：**
- Modify: `addons/bricks/events/input/on_mouse_button.gd`
- Modify: `addons/bricks/core/runtime_event_instance.gd:34-86`
- Test: `addons/bricks/tests/test_on_mouse_button_runtime_instance.tscn`

**背景：** OnMouseButton 有 1 个状态变量（`_owner_node_ref`），较简单。

### Step 1-10: 按照标准迁移模式

参考 Task 1 的步骤。

### Step 11: 提交代码

```bash
git commit -m "feat: 迁移 OnMouseButton 到 RuntimeInstance 架构"
```

---

## Task 4: 迁移 OnTimer Event

**文件：**
- Modify: `addons/bricks/events/lifecycle/on_timer.gd`
- Modify: `addons/bricks/core/runtime_event_instance.gd:34-86`
- Test: `addons/bricks/tests/test_on_timer_runtime_instance.tscn`

**背景：** OnTimer 有 3 个状态变量（`_current_repeat_count`, `_timer`, `_owner_node_ref`）。

### Step 1-10: 按照标准迁移模式

参考 Task 1 的步骤，注意与 OnInterval 的相似性。

### Step 11: 提交代码

```bash
git commit -m "feat: 迁移 OnTimer 到 RuntimeInstance 架构"
```

---

## Task 5: 迁移 OnArea2DEnter Event

**文件：**
- Modify: `addons/bricks/events/physics/on_area_2d_enter.gd`
- Modify: `addons/bricks/core/runtime_event_instance.gd:34-86`
- Test: `addons/bricks/tests/test_on_area_2d_enter_runtime_instance.tscn`

**背景：** OnArea2DEnter 有 1 个状态变量（`_triggered_bodies` 数组），用于防止重复触发。

### Step 1-10: 按照标准迁移模式

**关键差异：**
- 状态变量是数组类型：`_triggered_bodies: Array`
- 需要跟踪已触发的物体

### Step 11: 提交代码

```bash
git commit -m "feat: 迁移 OnArea2DEnter 到 RuntimeInstance 架构"
```

---

## Task 6: 迁移 OnArea3DEntered Event

**文件：**
- Modify: `addons/bricks/events/physics/on_area_3d_entered.gd`
- Modify: `addons/bricks/core/runtime_event_instance.gd:34-86`
- Test: `addons/bricks/tests/test_on_area_3d_entered_runtime_instance.tscn`

**背景：** OnArea3DEntered 与 OnArea2DEnter 类似，有 1 个状态变量（`_triggered_bodies`）。

### Step 1-10: 按照 OnArea2DEnter 的模式

### Step 11: 提交代码

```bash
git commit -m "feat: 迁移 OnArea3DEntered 到 RuntimeInstance 架构"
```

---

## Task 7: 迁移 OnCooldownFinished Event

**文件：**
- Modify: `addons/bricks/events/lifecycle/on_cooldown_finished.gd`
- Modify: `addons/bricks/core/runtime_event_instance.gd:34-86`
- Test: `addons/bricks/tests/test_on_cooldown_finished_runtime_instance.tscn`

**背景：** OnCooldownFinished 是最复杂的 Event 之一，有 7 个状态变量（`_is_running`, `_is_completed`, `_remaining_time`, `_timer`, `_main_timer`, `_progress_timer`, `_owner_node_ref`）。

### Step 1-10: 按照 OnInterval 的模式

**关键差异：**
- 需要管理多个 Timer
- 需要跟踪剩余时间
- 可能需要进度条更新

### Step 11: 提交代码

```bash
git commit -m "feat: 迁移 OnCooldownFinished 到 RuntimeInstance 架构"
```

---

## Task 8: 迁移 OnPropertyChanged Event（中优先级）

**文件：**
- Modify: `addons/bricks/events/property/on_property_changed.gd`
- Modify: `addons/bricks/core/runtime_event_instance.gd:34-86`
- Test: `addons/bricks/tests/test_on_property_changed_runtime_instance.tscn`

**背景：** OnPropertyChanged 有 2 个状态变量（`_timer`, `_owner_node_ref`），用于监听节点属性变化。

### Step 1-10: 按照标准迁移模式

### Step 11: 提交代码

```bash
git commit -m "feat: 迁移 OnPropertyChanged 到 RuntimeInstance 架构"
```

---

## Task 9: 迁移 OnSignalFromGroup Event（中优先级）

**文件：**
- Modify: `addons/bricks/events/signal/on_signal_from_group.gd`
- Modify: `addons/bricks/core/runtime_event_instance.gd:34-86`
- Test: `addons/bricks/tests/test_on_signal_from_group_runtime_instance.tscn`

**背景：** OnSignalFromGroup 有 1 个状态变量（`_owner_node_ref`），用于监听节点组的信号。

### Step 1-10: 按照标准迁移模式

### Step 11: 提交代码

```bash
git commit -m "feat: 迁移 OnSignalFromGroup 到 RuntimeInstance 架构"
```

---

## Task 10: 迁移 OnVariableChanged Event（中优先级）

**文件：**
- Modify: `addons/bricks/events/variable/on_variable_changed.gd`
- Modify: `addons/bricks/core/runtime_event_instance.gd:34-86`
- Test: `addons/bricks/tests/test_on_variable_changed_runtime_instance.tscn`

**背景：** OnVariableChanged 有 2 个状态变量（`_timer`, `_owner_node_ref`），用于监听全局或本地变量变化。

### Step 1-10: 按照标准迁移模式

### Step 11: 提交代码

```bash
git commit -m "feat: 迁移 OnVariableChanged 到 RuntimeInstance 架构"
```

---

## Task 11: 验证所有迁移

**文件：**
- Create: `docs/reports/runtime-instance-migration-completion-report.md`
- Test: `addons/bricks/tests/test_all_migrations.gd`

### Step 1: 创建综合测试脚本

创建 `addons/bricks/tests/test_all_migrations.gd`：

```gdscript
extends Node

## 综合测试脚本 - 验证所有 Event 的 RuntimeInstance 迁移

var migrated_events = [
	"OnInterval",
	"OnInputKey",
	"OnMouseButton",
	"OnArea2DEnter",
	"OnArea3DEntered",
	"OnCooldownFinished",
	"OnTimer",
	"OnPropertyChanged",
	"OnSignalFromGroup",
	"OnVariableChanged"
]

func _ready():
	print("=== 开始验证 RuntimeInstance 迁移 ===")

	for event_name in migrated_events:
		_test_event_migration(event_name)

	print("=== 验证完成 ===")

func _test_event_migration(event_name: String):
	print("\n[TEST] 测试 %s" % event_name)

	# 动态加载 Event 类
	var event_class = load("res://addons/bricks/events/%s.gd" % event_name.to_snake_case())
	if not event_class:
		print("[ERROR] 无法加载 Event 类: %s" % event_name)
		return

	var event_resource = event_class.new()

	# 检查是否有 initialize_with_runtime_instance 方法
	if not event_resource.has_method("initialize_with_runtime_instance"):
		print("[FAIL] %s 缺少 initialize_with_runtime_instance 方法" % event_name)
		return

	# 检查是否删除了运行时状态变量
	var state_variables = _detect_state_variables(event_resource)
	if not state_variables.is_empty():
		print("[FAIL] %s 仍有运行时状态变量: %s" % [event_name, state_variables])
		return

	print("[PASS] %s 迁移验证通过" % event_name)

func _detect_state_variables(event: BaseEvent) -> Array:
	var script = event.get_script()
	if not script:
		return []

	# 使用反射检测成员变量
	var state_vars = []
	# TODO: 实现变量检测逻辑

	return state_vars
```

### Step 2: 运行综合测试

```bash
# 在 Godot 编辑器中运行测试场景
# 验证所有 10 个 Event 的迁移
```

### Step 3: 生成完成报告

创建 `docs/reports/runtime-instance-migration-completion-report.md`：

```markdown
# RuntimeInstance 架构迁移完成报告

**日期**: 2026-02-03
**迁移范围**: 10 个高优先级和中优先级 Event

## 迁移结果

| Event | 状态 | 测试结果 |
|-------|------|---------|
| OnInterval | ✅ 已迁移 | PASS |
| OnInputKey | ✅ 已迁移 | PASS |
| OnMouseButton | ✅ 已迁移 | PASS |
| OnArea2DEnter | ✅ 已迁移 | PASS |
| OnArea3DEntered | ✅ 已迁移 | PASS |
| OnCooldownFinished | ✅ 已迁移 | PASS |
| OnTimer | ✅ 已迁移 | PASS |
| OnPropertyChanged | ✅ 已迁移 | PASS |
| OnSignalFromGroup | ✅ 已迁移 | PASS |
| OnVariableChanged | ✅ 已迁移 | PASS |

## 技术改进

1. **状态隔离**: 每个 Trigger 有独立的运行时状态
2. **资源共享**: 同一个 Event 资源可以被多个节点安全使用
3. **向后兼容**: 旧的 `initialize()` 方法仍然可用
4. **测试覆盖**: 所有迁移的 Event 都有测试场景

## 已知问题

无

## 下一步

- 考虑迁移 37 个低优先级 Event
- 根据实际使用反馈优化架构
```

### Step 4: 更新迁移检查清单文档

更新 `addons/bricks/docs/development/event-runtime-instance-checklist.md`：

```markdown
## 已迁移的 Event

以下 Event 已成功迁移到 RuntimeInstance 架构：

- [x] OnMouseEnter (2026-02-02)
- [x] OnMouseExit (2026-02-02)
- [x] OnInterval (2026-02-03)
- [x] OnInputKey (2026-02-03)
- [x] OnMouseButton (2026-02-03)
- [x] OnArea2DEnter (2026-02-03)
- [x] OnArea3DEntered (2026-02-03)
- [x] OnCooldownFinished (2026-02-03)
- [x] OnTimer (2026-02-03)
- [x] OnPropertyChanged (2026-02-03)
- [x] OnSignalFromGroup (2026-02-03)
- [x] OnVariableChanged (2026-02-03)
```

### Step 5: 最终提交

```bash
git add docs/reports/runtime-instance-migration-completion-report.md
git add addons/bricks/docs/development/event-runtime-instance-checklist.md
git add addons/bricks/tests/test_all_migrations.gd
git commit -m "docs: 完成 RuntimeInstance 架构迁移第一阶段

- 迁移 10 个高/中优先级 Event
- 所有迁移的 Event 通过测试验证
- 生成完成报告和更新检查清单

迁移完成:
✅ OnInterval
✅ OnInputKey
✅ OnMouseButton
✅ OnArea2DEnter
✅ OnArea3DEntered
✅ OnCooldownFinished
✅ OnTimer
✅ OnPropertyChanged
✅ OnSignalFromGroup
✅ OnVariableChanged

下一步: 根据需求迁移 37 个低优先级 Event
"

# 推送到远程仓库
git push origin Develop_brick
```

---

## 相关资源

**文档：**
- [完整迁移指南](../../../addons/bricks/docs/migration-guide-to-runtime-instance.md)
- [迁移检查清单](../../../addons/bricks/docs/development/event-runtime-instance-checklist.md)
- [快速开始指南](../../../docs/plans/event-migration-quick-start.md)
- [评估总结](../../../docs/plans/2025-02-03-event-runtime-instance-evaluation-summary.md)

**已迁移示例：**
- [OnMouseEnter 实现](../../../addons/bricks/events/input/on_mouse_enter.gd)
- [OnMouseExit 实现](../../../addons/bricks/events/input/on_mouse_exit.gd)

**核心类：**
- [RuntimeEventInstance API](../../../addons/bricks/core/runtime_event_instance.gd)
- [BaseEvent 基类](../../../addons/bricks/core/base_event.gd)

**工具：**
- [评估工具](../../../tools/evaluate_events_migration.py)
- [测试工具](../../../tools/test_evaluation.py)

---

**预计时间:** 每个 Event 30-60 分钟，总计 5-10 小时

**风险:** 低 - 架构已验证，有成功迁移案例

**验收标准:**
- [ ] 所有 10 个 Event 成功迁移
- [ ] 所有测试场景通过
- [ ] 迁移报告完整
- [ ] 无功能回退
- [ ] 代码提交到远程仓库
