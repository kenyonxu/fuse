# Runner Node 实现计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 创建一个可以通过方法调用和信号绑定驱动 ActionRunner 的轻量级 Node。

**Architecture:** Runner 是 Trigger 的简化版本，移除 Event 驱动部分，保留 ActionRunner 执行能力。复用 RuntimeActionRunnerInstance 管理运行时状态，ExecutionContext target 固定为 self。

**Tech Stack:** GDScript 2.0, Godot 4.6, RuntimeActionRunnerInstance, ExecutionContext

---

## Task 1: 创建 Runner 核心文件

**Files:**
- Create: `addons/bricks/core/runner.gd`

**Step 1: 创建文件骨架和属性**

```gdscript
# 文件：addons/bricks/core/runner.gd
@tool
@icon("res://addons/bricks/icons/builtin/Play.svg")
class_name Runner extends Node

## ============================================
## 导出属性
## ============================================

@export_group("Action Runner")
## 要执行的 ActionRunner 资源
@export var action_runner: ActionRunner:
	set(value):
		action_runner = value
		_clear_runtime_instance()

@export_group("Signal Binding")
## 自动绑定信号的目标节点路径
@export var target_node: NodePath = NodePath(""):
	set(value):
		target_node = value
		_disconnect_signal_binding()

## 要绑定的信号名称
@export var signal_name: String = "":
	set(value):
		signal_name = value
		_disconnect_signal_binding()

@export_group("Configuration")
## 日志级别
@export var log_level: BricksLogger.LogLevel = BricksLogger.LogLevel.NONE

## ============================================
## 信号
## ============================================

## 执行完成信号
signal execution_completed(total_time: float)

## 执行失败信号
signal execution_failed(error_message: String)

## 执行取消信号
signal execution_canceled(reason: String)

## ============================================
## 内部状态
## ============================================

## RuntimeActionRunnerInstance 实例
var _runtime_instance: RuntimeActionRunnerInstance = null

## 信号绑定的目标节点引用
var _bound_node: Node = null

## 外部信号是否已连接
var _signal_connected: bool = false

## RuntimeActionRunnerInstance 信号是否已连接
var _runtime_signals_connected: bool = false

## ============================================
## 生命周期方法
## ============================================

func _ready() -> void:
	if Engine.is_editor_hint():
		return

	# 创建 RuntimeActionRunnerInstance
	if action_runner:
		_runtime_instance = RuntimeActionRunnerInstance.new(action_runner, self)
		_connect_runtime_signals()

	# 自动绑定信号
	_setup_signal_binding()

func _exit_tree() -> void:
	_disconnect_signal_binding()
	_disconnect_runtime_signals()

	if _runtime_instance:
		_runtime_instance.cleanup()
		_runtime_instance = null
```

**Step 2: 验证文件语法**

Run: `E:\Godot\Godot_v4.6.1-stable_mono_win64\Godot_v4.6.1-stable_mono_win64.exe --headless --check-only --quit --script addons/bricks/core/runner.gd`

Expected: 无语法错误（可能有缺少方法的警告，正常）

**Step 3: Commit**

```bash
git add addons/bricks/core/runner.gd
git commit -m "feat(bricks): add Runner node skeleton with properties and lifecycle"
```

---

## Task 2: 实现信号绑定功能

**Files:**
- Modify: `addons/bricks/core/runner.gd`

**Step 1: 添加信号绑定方法**

在 `_exit_tree()` 方法后添加：

```gdscript
## ============================================
## 信号绑定
## ============================================

## 设置信号绑定
func _setup_signal_binding() -> void:
	if target_node.is_empty() or signal_name.is_empty():
		return

	_bound_node = get_node_or_null(target_node)
	if not _bound_node:
		_log_warning("Target node not found: %s" % target_node)
		return

	# 检查信号是否存在
	var signal_list = _bound_node.get_signal_list()
	var has_signal = false
	for sig in signal_list:
		if sig["name"] == signal_name:
			has_signal = true
			break

	if not has_signal:
		_log_warning("Signal '%s' not found on node '%s'" % [signal_name, _bound_node.name])
		return

	# 连接信号
	if not _bound_node.is_connected(signal_name, _on_bound_signal):
		_bound_node.connect(signal_name, _on_bound_signal)
		_signal_connected = true
		_log_debug("Signal bound: %s.%s" % [_bound_node.name, signal_name])

## 断开信号绑定
func _disconnect_signal_binding() -> void:
	if _signal_connected and _bound_node and is_instance_valid(_bound_node):
		if _bound_node.is_connected(signal_name, _on_bound_signal):
			_bound_node.disconnect(signal_name, _on_bound_signal)
	_signal_connected = false
	_bound_node = null

## 绑定信号的回调 - 直接调用 run()
func _on_bound_signal() -> void:
	run()
```

**Step 2: 验证语法**

Run: `E:\Godot\Godot_v4.6.1-stable_mono_win64\Godot_v4.6.1-stable_mono_win64.exe --headless --check-only --quit --script addons/bricks/core/runner.gd`

Expected: 无语法错误

**Step 3: Commit**

```bash
git add addons/bricks/core/runner.gd
git commit -m "feat(bricks): add signal binding support to Runner"
```

---

## Task 3: 实现核心执行方法

**Files:**
- Modify: `addons/bricks/core/runner.gd`

**Step 1: 添加执行上下文和核心方法**

在 `_on_bound_signal()` 方法后添加：

```gdscript
## ============================================
## 执行上下文
## ============================================

## 创建执行上下文（以 self 为 target）
func _create_execution_context() -> ExecutionContext:
	var context = ExecutionContext.new(self, self)
	context.log_level = log_level
	return context

## ============================================
## 公共 API - 执行方法
## ============================================

## 执行 ActionRunner
func run() -> void:
	if not action_runner:
		_log_warning("No ActionRunner assigned")
		return

	# 懒加载 RuntimeActionRunnerInstance
	if not _runtime_instance:
		_runtime_instance = RuntimeActionRunnerInstance.new(action_runner, self)
		_connect_runtime_signals()

	if _runtime_instance.is_running():
		_log_warning("Runner is already running")
		return

	# 创建执行上下文
	var context = _create_execution_context()

	_log_debug("Runner executing: %s" % action_runner.get_info())

	# 执行
	_runtime_instance.run(context)

## 停止执行
func stop() -> void:
	if _runtime_instance and _runtime_instance.is_running():
		_runtime_instance.cancel_execution("Stopped by user")
		_log_debug("Runner stopped")

## 取消执行（带原因）
func cancel(reason: String = "") -> void:
	if _runtime_instance and _runtime_instance.is_running():
		_runtime_instance.cancel_execution(reason if reason else "Canceled")
		_log_debug("Runner canceled: %s" % reason)

## 重置状态
func reset() -> void:
	# 取消正在执行的任务
	if _runtime_instance and _runtime_instance.is_running():
		_runtime_instance.cancel_execution("Reset called")

	# 断开信号绑定
	_disconnect_signal_binding()

	# 断开运行时信号
	_disconnect_runtime_signals()

	# 清理运行时实例
	if _runtime_instance:
		_runtime_instance.cleanup()
		_runtime_instance = null

	_log_debug("Runner reset")
```

**Step 2: 验证语法**

Run: `E:\Godot\Godot_v4.6.1-stable_mono_win64\Godot_v4.6.1-stable_mono_win64.exe --headless --check-only --quit --script addons/bricks/core/runner.gd`

Expected: 无语法错误

**Step 3: Commit**

```bash
git add addons/bricks/core/runner.gd
git commit -m "feat(bricks): add run/stop/cancel/reset methods to Runner"
```

---

## Task 4: 实现状态查询和等待方法

**Files:**
- Modify: `addons/bricks/core/runner.gd`

**Step 1: 添加状态查询方法**

在 `reset()` 方法后添加：

```gdscript
## ============================================
## 公共 API - 状态查询
## ============================================

## 是否正在执行
func is_running() -> bool:
	return _runtime_instance.is_running() if _runtime_instance else false

## 是否正在取消
func is_canceling() -> bool:
	if _runtime_instance:
		return _runtime_instance.get_runtime_state("is_canceling") if _runtime_instance else false
	return false

## 获取执行状态详情
func get_execution_status() -> Dictionary:
	if not _runtime_instance:
		return {
			"is_running": false,
			"has_action_runner": action_runner != null,
			"signal_bound": _signal_connected
		}
	var status = _runtime_instance.get_runtime_state()
	status["has_action_runner"] = action_runner != null
	status["signal_bound"] = _signal_connected
	return status

## 等待执行完成（awaitable）
func wait_completed() -> void:
	if _runtime_instance and _runtime_instance.is_running():
		await _runtime_instance.execution_completed
```

**Step 2: 验证语法**

Run: `E:\Godot\Godot_v4.6.1-stable_mono_win64\Godot_v4.6.1-stable_mono_win64.exe --headless --check-only --quit --script addons/bricks/core/runner.gd`

Expected: 无语法错误

**Step 3: Commit**

```bash
git add addons/bricks/core/runner.gd
git commit -m "feat(bricks): add state query and wait_completed to Runner"
```

---

## Task 5: 实现 RuntimeActionRunnerInstance 信号连接

**Files:**
- Modify: `addons/bricks/core/runner.gd`

**Step 1: 添加信号连接方法**

在 `wait_completed()` 方法后添加：

```gdscript
## ============================================
## RuntimeActionRunnerInstance 信号连接
## ============================================

## 连接 RuntimeActionRunnerInstance 信号
func _connect_runtime_signals() -> void:
	if not _runtime_instance:
		return

	if not _runtime_instance.execution_completed.is_connected(_on_execution_completed):
		_runtime_instance.execution_completed.connect(_on_execution_completed)

	if not _runtime_instance.execution_failed.is_connected(_on_execution_failed):
		_runtime_instance.execution_failed.connect(_on_execution_failed)

	if not _runtime_instance.execution_canceled.is_connected(_on_execution_canceled):
		_runtime_instance.execution_canceled.connect(_on_execution_canceled)

	_runtime_signals_connected = true

## 断开 RuntimeActionRunnerInstance 信号
func _disconnect_runtime_signals() -> void:
	if not _runtime_instance or not _runtime_signals_connected:
		return

	if _runtime_instance.execution_completed.is_connected(_on_execution_completed):
		_runtime_instance.execution_completed.disconnect(_on_execution_completed)

	if _runtime_instance.execution_failed.is_connected(_on_execution_failed):
		_runtime_instance.execution_failed.disconnect(_on_execution_failed)

	if _runtime_instance.execution_canceled.is_connected(_on_execution_canceled):
		_runtime_instance.execution_canceled.disconnect(_on_execution_canceled)

	_runtime_signals_connected = false

## === RuntimeActionRunnerInstance 信号回调 ===

func _on_execution_completed(total_time: float) -> void:
	execution_completed.emit(total_time)
	_log_debug("Execution completed in %.3fs" % total_time)

func _on_execution_failed(error_message: String) -> void:
	execution_failed.emit(error_message)
	_log_error("Execution failed: %s" % error_message)

func _on_execution_canceled(reason: String) -> void:
	execution_canceled.emit(reason)
	_log_debug("Execution canceled: %s" % reason)

## ============================================
## 内部辅助方法
## ============================================

## 清理运行时实例（属性 setter 用）
func _clear_runtime_instance() -> void:
	if _runtime_instance:
		_disconnect_runtime_signals()
		_runtime_instance.cleanup()
		_runtime_instance = null
```

**Step 2: 验证语法**

Run: `E:\Godot\Godot_v4.6.1-stable_mono_win64\Godot_v4.6.1-stable_mono_win64.exe --headless --check-only --quit --script addons/bricks/core/runner.gd`

Expected: 无语法错误

**Step 3: Commit**

```bash
git add addons/bricks/core/runner.gd
git commit -m "feat(bricks): add RuntimeActionRunnerInstance signal handling to Runner"
```

---

## Task 6: 添加日志方法

**Files:**
- Modify: `addons/bricks/core/runner.gd`

**Step 1: 添加日志方法**

在文件末尾添加：

```gdscript
## ============================================
## 日志方法
## ============================================

func _log_debug(message: String) -> void:
	BricksLogger.log_debug("Runner", log_level, message, name)

func _log_info(message: String) -> void:
	BricksLogger.log_info("Runner", log_level, message, name)

func _log_warning(message: String) -> void:
	BricksLogger.log_warning("Runner", log_level, message, name)

func _log_error(message: String) -> void:
	BricksLogger.log_error("Runner", log_level, message, name)
```

**Step 2: 验证语法**

Run: `E:\Godot\Godot_v4.6.1-stable_mono_win64\Godot_v4.6.1-stable_mono_win64.exe --headless --check-only --quit --script addons/bricks/core/runner.gd`

Expected: 无语法错误

**Step 3: Commit**

```bash
git add addons/bricks/core/runner.gd
git commit -m "feat(bricks): add logging methods to Runner"
```

---

## Task 7: 添加本地化翻译键

**Files:**
- Modify: `addons/bricks/localization/translations.csv`

**Step 1: 添加翻译键**

在 `translations.csv` 文件末尾添加：

```csv
BRICKS_RUNNER_NAME,Runner,Runner
BRICKS_RUNNER_DESC,直接驱动 ActionRunner 执行的节点,Node that directly drives ActionRunner execution
BRICKS_RUNNER_NO_ACTION_RUNNER,没有配置 ActionRunner,No ActionRunner assigned
BRICKS_RUNNER_ALREADY_RUNNING,Runner 正在执行,Runner is already running
BRICKS_RUNNER_TARGET_NODE_NOT_FOUND,目标节点未找到: {target},Target node not found: {target}
BRICKS_RUNNER_SIGNAL_NOT_FOUND,信号 '{signal}' 在节点 '{node}' 上未找到,Signal '{signal}' not found on node '{node}'
BRICKS_RUNNER_SIGNAL_BOUND,信号已绑定: {node}.{signal},Signal bound: {node}.{signal}
BRICKS_RUNNER_EXECUTION_STARTED,开始执行,Execution started
BRICKS_RUNNER_EXECUTION_COMPLETED,执行完成，耗时 {time} 秒,Execution completed in {time} seconds
BRICKS_RUNNER_EXECUTION_FAILED,执行失败: {error},Execution failed: {error}
BRICKS_RUNNER_EXECUTION_CANCELED,执行取消: {reason},Execution canceled: {reason}
BRICKS_RUNNER_STOPPED,Runner 已停止,Runner stopped
BRICKS_RUNNER_CANCELED,Runner 已取消: {reason},Runner canceled: {reason}
BRICKS_RUNNER_RESET,Runner 已重置,Runner reset
```

**Step 2: Commit**

```bash
git add addons/bricks/localization/translations.csv
git commit -m "feat(bricks): add localization keys for Runner"
```

---

## Task 8: 创建测试场景

**Files:**
- Create: `addons/bricks/tests/runner/test_runner.gd`
- Create: `addons/bricks/tests/runner/test_runner.tscn`

**Step 1: 创建测试脚本**

```gdscript
# 文件：addons/bricks/tests/runner/test_runner.gd
extends Node

## Runner 测试用例

var _runner: Runner = null
var _action_runner: ActionRunner = null
var _execution_completed_count: int = 0
var _execution_failed_count: int = 0
var _execution_canceled_count: int = 0

func _ready() -> void:
	print("=== Runner 测试开始 ===")
	await _run_all_tests()
	print("=== Runner 测试完成 ===")

func _run_all_tests() -> void:
	await test_runner_creation()
	await test_runner_run_without_action_runner()
	await test_runner_run_with_action_runner()
	await test_runner_stop()
	await test_runner_cancel()
	await test_runner_reset()
	await test_runner_signal_binding()
	await test_runner_is_running()
	await test_runner_wait_completed()

func _setup() -> void:
	_execution_completed_count = 0
	_execution_failed_count = 0
	_execution_canceled_count = 0

	# 创建 Runner
	_runner = Runner.new()
	_runner.name = "TestRunner"
	_runner.log_level = BricksLogger.LogLevel.DEBUG
	add_child(_runner)

	# 连接信号
	_runner.execution_completed.connect(_on_execution_completed)
	_runner.execution_failed.connect(_on_execution_failed)
	_runner.execution_canceled.connect(_on_execution_canceled)

func _teardown() -> void:
	if _runner:
		_runner.queue_free()
		_runner = null
	if _action_runner:
		_action_runner = null

func _on_execution_completed(total_time: float) -> void:
	_execution_completed_count += 1
	print("  [信号] execution_completed: %.3fs" % total_time)

func _on_execution_failed(error_message: String) -> void:
	_execution_failed_count += 1
	print("  [信号] execution_failed: %s" % error_message)

func _on_execution_canceled(reason: String) -> void:
	_execution_canceled_count += 1
	print("  [信号] execution_canceled: %s" % reason)

## ============================================
## 测试用例
## ============================================

func test_runner_creation() -> void:
	print("\n[测试] Runner 创建...")
	_setup()

	assert(_runner != null, "Runner 应该被创建")
	assert(_runner.is_running() == false, "Runner 初始状态应该不在运行")

	_teardown()
	print("  ✓ 通过")

func test_runner_run_without_action_runner() -> void:
	print("\n[测试] Runner 无 ActionRunner 时运行...")
	_setup()

	_runner.run()
	await get_tree().process_frame

	# 应该不会有执行完成信号
	assert(_execution_completed_count == 0, "无 ActionRunner 时不应该有完成信号")

	_teardown()
	print("  ✓ 通过")

func test_runner_run_with_action_runner() -> void:
	print("\n[测试] Runner 带 ActionRunner 运行...")
	_setup()

	# 创建 ActionRunner
	_action_runner = ActionRunner.new()
	var instruction = MockInstruction.new()
	instruction.description = "测试指令"
	_action_runner.instructions.append(instruction)

	_runner.action_runner = _action_runner
	_runner.run()

	# 等待执行完成
	await _runner.wait_completed()

	assert(_execution_completed_count == 1, "应该有执行完成信号")
	assert(_runner.is_running() == false, "执行完成后不应该在运行")

	_teardown()
	print("  ✓ 通过")

func test_runner_stop() -> void:
	print("\n[测试] Runner 停止...")
	_setup()

	# 创建一个长时间运行的 ActionRunner
	_action_runner = ActionRunner.new()
	var wait_instruction = WaitInstruction.new()
	wait_instruction.duration = 5.0
	_action_runner.instructions.append(wait_instruction)

	_runner.action_runner = _action_runner
	_runner.run()

	await get_tree().process_frame
	assert(_runner.is_running() == true, "Runner 应该在运行")

	_runner.stop()

	await get_tree().process_frame
	assert(_runner.is_running() == false, "停止后 Runner 不应该在运行")

	_teardown()
	print("  ✓ 通过")

func test_runner_cancel() -> void:
	print("\n[测试] Runner 取消...")
	_setup()

	_action_runner = ActionRunner.new()
	var wait_instruction = WaitInstruction.new()
	wait_instruction.duration = 5.0
	_action_runner.instructions.append(wait_instruction)

	_runner.action_runner = _action_runner
	_runner.run()

	await get_tree().process_frame
	_runner.cancel("测试取消")

	await get_tree().process_frame
	assert(_execution_canceled_count == 1, "应该有取消信号")

	_teardown()
	print("  ✓ 通过")

func test_runner_reset() -> void:
	print("\n[测试] Runner 重置...")
	_setup()

	_action_runner = ActionRunner.new()
	_action_runner.instructions.append(MockInstruction.new())
	_runner.action_runner = _action_runner

	_runner.run()
	await get_tree().process_frame

	_runner.reset()

	assert(_runner.is_running() == false, "重置后不应该在运行")

	_teardown()
	print("  ✓ 通过")

func test_runner_signal_binding() -> void:
	print("\n[测试] Runner 信号绑定...")
	_setup()

	# 创建一个按钮节点
	var button = Button.new()
	button.name = "TestButton"
	add_child(button)

	# 创建 ActionRunner
	_action_runner = ActionRunner.new()
	_action_runner.instructions.append(MockInstruction.new())
	_runner.action_runner = _action_runner

	# 设置信号绑定
	_runner.target_node = button.get_path()
	_runner.signal_name = "pressed"

	# 重新设置信号绑定
	_runner._setup_signal_binding()

	# 模拟按钮按下
	button.emit_signal("pressed")

	await get_tree().process_frame
	await get_tree().process_frame

	assert(_execution_completed_count == 1, "信号绑定应该触发执行")

	button.queue_free()
	_teardown()
	print("  ✓ 通过")

func test_runner_is_running() -> void:
	print("\n[测试] Runner is_running 状态...")
	_setup()

	assert(_runner.is_running() == false, "初始状态不在运行")

	_action_runner = ActionRunner.new()
	var wait_instruction = WaitInstruction.new()
	wait_instruction.duration = 0.5
	_action_runner.instructions.append(wait_instruction)
	_runner.action_runner = _action_runner

	_runner.run()
	assert(_runner.is_running() == true, "执行中应该在运行")

	await _runner.wait_completed()
	assert(_runner.is_running() == false, "完成后不在运行")

	_teardown()
	print("  ✓ 通过")

func test_runner_wait_completed() -> void:
	print("\n[测试] Runner wait_completed...")
	_setup()

	_action_runner = ActionRunner.new()
	_action_runner.instructions.append(MockInstruction.new())
	_runner.action_runner = _action_runner

	_runner.run()
	await _runner.wait_completed()

	assert(_execution_completed_count == 1, "wait_completed 应该等待执行完成")

	_teardown()
	print("  ✓ 通过")

## ============================================
## Mock 指令
## ============================================

class MockInstruction extends BaseInstruction:
	var description: String = "Mock Instruction"

	func execute(context: ExecutionContext) -> void:
		complete()

	func get_description() -> String:
		return description
```

**Step 2: 创建测试场景**

```gdscript
; 文件：addons/bricks/tests/runner/test_runner.tscn
[gd_scene load_steps=2 format=3 uid="uid://testrunner001"]

[ext_resource type="Script" path="res://addons/bricks/tests/runner/test_runner.gd" id="1"]

[node name="TestRunner" type="Node"]
script = ExtResource("1")
```

**Step 3: 运行测试**

Run: `E:\Godot\Godot_v4.6.1-stable_mono_win64\Godot_v4.6.1-stable_mono_win64.exe --headless --quit addons/bricks/tests/runner/test_runner.tscn`

Expected: 所有测试通过，输出 "✓ 通过"

**Step 4: Commit**

```bash
git add addons/bricks/tests/runner/test_runner.gd addons/bricks/tests/runner/test_runner.tscn
git commit -m "test(bricks): add Runner test cases"
```

---

## Task 9: 更新设计文档状态

**Files:**
- Modify: `addons/bricks/docs/proposals/pending/2026-03-09-runner-node-design.md`

**Step 1: 更新状态为已实现**

将文档末尾的 `状态: 待实现` 改为 `状态: 已实现`

**Step 2: 移动到 completed 目录（如果存在）或保持原位置**

```bash
git add addons/bricks/docs/proposals/pending/2026-03-09-runner-node-design.md
git commit -m "docs(bricks): mark Runner design as implemented"
```

---

## 最终验证

**Step 1: 运行 Godot 脚本检查**

Run: `E:\Godot\Godot_v4.6.1-stable_mono_win64\Godot_v4.6.1-stable_mono_win64.exe --headless --check-only --quit`

Expected: 无错误

**Step 2: 运行测试场景**

Run: `E:\Godot\Godot_v4.6.1-stable_mono_win64\Godot_v4.6.1-stable_mono_win64.exe --headless --quit addons/bricks/tests/runner/test_runner.tscn`

Expected: 所有测试通过

---

## 文件清单

| 文件 | 操作 |
|------|------|
| `addons/bricks/core/runner.gd` | 创建 |
| `addons/bricks/localization/translations.csv` | 修改 |
| `addons/bricks/tests/runner/test_runner.gd` | 创建 |
| `addons/bricks/tests/runner/test_runner.tscn` | 创建 |
| `addons/bricks/docs/proposals/pending/2026-03-09-runner-node-design.md` | 修改 |
