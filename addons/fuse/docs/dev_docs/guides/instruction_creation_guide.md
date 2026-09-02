# 创建 Fuse 指令指南

> **目标**: 为开发者提供完整的 Fuse 指令创建指引，基于 Phase 0B 经验总结和最佳实践。
> **权威规范**: 组件生成的最终权威是 [fuse-instruction-generator skill](../../../agent_skills/fuse-instruction-generator/SKILL.md)（模板、命名禁则与验证 gate）；本指南是其架构原理的详述。

**适用对象**: Fuse 系统开发者、贡献者

**最后更新**: 2026-06-17

**重要更新**: 添加 CompletionSignalTiming、ExecutionMode、cancel()、超时管理文档

---

## 📋 目录

1. [命名规范](#命名规范)
2. [图标规范](#图标规范)
3. [关键技术要点](#关键技术要点)
4. [RuntimeInstructionInstance 架构支持](#runtimeinstructioninstance-架构支持)
5. [完整指令模板](#完整指令模板)
6. [带变量操作的指令模板](#带变量操作的指令模板)
7. [创建步骤](#创建步骤)
8. [最佳实践](#最佳实践)
9. [常见陷阱](#常见陷阱)
10. [测试规范](#测试规范)

---

## 命名规范

**重要**: 所有 Fuse 指令遵循以下命名规范，保持简洁一致。

### 文件命名

- **指令文件**: 使用 `snake_case`，**不添加** `_instruction` 后缀
  - ✅ 正确：`set_position.gd`, `for_loop.gd`, `if_else.gd`
  - ❌ 错误：`set_position_instruction.gd`, `for_loop_instruction.gd`

### 类命名

- **类名**: 使用 `PascalCase`，**不添加** `Instruction` 后缀
  - ✅ 正确：`class_name SetPosition`, `class_name ForLoop`, `class_name IfElse`
  - ❌ 错误：`class_name SetPositionInstruction`, `class_name ForLoopInstruction`

### 测试文件命名

- **测试脚本**: `test_<instruction_name>.gd`
  - 例如：`test_set_position.gd`, `test_for_loop.gd`
- **测试场景**: `test_<instruction_name>.tscn`
  - 例如：`test_set_position.tscn`, `test_for_loop.tscn`

### 统一性原则

- 文件名、类名、测试文件名保持一致的基础名称
- 避免冗余后缀（如 `_instruction`、`Instruction`）
- 保持简洁可读

**示例**:
```
指令文件：   set_position.gd
类名：       class_name SetPosition
测试脚本：   test_set_position.gd
测试场景：   test_set_position.tscn
```

---

## 图标规范

**图标选择原则**: 每个指令都应该配置图标，提升用户体验和可视化效果。

### 图标配置方式

**推荐：使用 Godot 内置图标**
```gdscript
metadata.builtin_icon = "Script"  # 使用 Godot 内置图标名称
```

**备选：使用自定义图标库**
```gdscript
metadata.custom_icon = "my_custom_icon"  # 使用导入的自定义图标
```

**向后兼容**
```gdscript
metadata.icon_name = "Script"  # 旧方式，仍然有效
metadata.icon = preload("res://icon.png")  # 直接指定纹理
```

### 内置图标命名参考

**常用图标名称**：
- **流程控制**: `Loop`, `Branch`, `Time`
- **变量操作**: `Array`, `New`, `View`, `Print`
- **节点操作**: `Node`, `Edit`, `Call`, `Remove`
- **调试**: `Debug`, `Search`
- **通用**: `Script`, `Play`, `Stop`, `Save`, `Load`, `Add`, `File`, `Folder`
- **变换**: `Rotate`, `Scale`, `Translation`, `Move`
- **音频**: `AudioStreamPlayer`, `Play`, `Stop`, `VolumeCurve`
- **场景**: `MakePacked`, `PackedScene`

**完整列表**: 参考 [icon_system.md](icon_system.md)

### 图标配置步骤

在 `_get_instruction_metadata()` 中配置图标：

```gdscript
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.builtin_icon = "Script"  # 配置图标
	return metadata
```

---

## 关键技术要点

> **重要**: 基于 Phase 0B 开发经验总结的关键技术要点，后续指令开发必须遵循。

### 必需实现的抽象方法

所有指令必须实现以下方法，否则会产生编译错误：

```gdscript
## 1. 更新资源名称（必需）
func _update_resource_name():
	var parts = []
	# 构建描述性资源名称
	parts.append("操作名称")
	if not target_node.is_empty():
		parts.append("'%s'" % target_node)
	resource_name = " ".join(parts)

## 2. 验证参数（必需）
func validate() -> Array[String]:
	var errors = super.validate()
	# 添加自定义验证
	if target_node.is_empty():
		errors.append("目标节点路径不能为空")
	return errors

## 3. 获取描述（必需）
func get_description() -> String:
	return "指令描述字符串"
```

### 执行流程必需方法

```gdscript
func execute(context: ExecutionContext):
	# 必须首先调用
	_start_execution(context)

	# 验证逻辑
	if validation_failed:
		_log_error_localized("ERROR_KEY", {})
		set_error_localized("ERROR_KEY", FuseError.ErrorType.VALIDATION_ERROR, {})
		finished.emit()  # 同步指令直接发出信号
		return

	# 执行逻辑
	# ...

	# 同步指令完成
	_on_execution_completed()

	# 异步指令（需要定时器等）
	# 不调用 _on_execution_completed()，而是在回调中调用 finished.emit()
```

### 节点获取方法

**❌ 错误用法**:
```gdscript
var node := context.resolve_node(target_node)  # 方法不存在
var node := get_node(target_node)                 # 无法解析相对路径
```

**✅ 正确用法**:
```gdscript
var node := context.get_node(target_node)       # 正确，支持相对路径解析
```

### 异步操作（定时器）

**❌ 错误用法**:
```gdscript
_timer = get_tree().create_timer(delay)  # get_tree() 在指令中不可用
```

**✅ 正确用法**:
```gdscript
var scene_tree = Engine.get_main_loop()
if scene_tree:
	_timer = scene_tree.create_timer(delay)
	_timer.timeout.connect(_on_timer_timeout)
else:
	_log_error_localized("FUSE_ERROR_CANNOT_CREATE_TIMER", {})
	finished.emit()
```

### SceneTree 和当前场景访问

```gdscript
# 获取 SceneTree
var scene_tree = Engine.get_main_loop()
if scene_tree:
	# 获取当前场景
	var current_scene = scene_tree.current_scene
	# 创建定时器
	var timer = scene_tree.create_timer(duration)
```

### 变量操作（三层变量系统）

**重要**: Fuse 系统采用三层变量架构（LOCAL/SCOPE/GLOBAL），所有指令应使用 `VariableOperations` 工具类统一访问变量。

**三层变量架构**:
- **LOCAL** - 局部变量（ExecutionContext），单次指令执行期间有效
- **SCOPE** - 作用域变量（ScopeVariableContainer），节点生命周期内有效
- **GLOBAL** - 全局变量（GlobalVariableResource），跨场景访问

**✅ 推荐用法**（使用 VariableOperations）:
```gdscript
# 读取变量（支持三层作用域）
var value = VariableOperations.get_variable(
	context,
	var_name,
	var_scope,  # BaseVariable.VariableScope.LOCAL/SCOPE/GLOBAL
	default_value
)

# 设置变量（支持三层作用域）
VariableOperations.set_variable(
	context,
	var_name,
	var_scope,  # BaseVariable.VariableScope.LOCAL/SCOPE/GLOBAL
	new_value
)

# 检查变量是否存在（区分"不存在"和"值为null"）
if not VariableOperations.has_variable(context, var_name, var_scope):
	_log_error_localized("FUSE_ERROR_VAR_NOT_FOUND", {"variable": var_name})
	return
```

**完整示例**（指令中使用变量）:
```gdscript
# 变量作用域属性
@export var value_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		value_scope = value
		_update_resource_name()

# 执行时读取变量
func execute(context: ExecutionContext):
	_start_execution(context)

	var value = VariableOperations.get_variable(
		context,
		variable_name,
		value_scope,
		null  # 默认值
	)

	# 检查变量是否存在
	if value == null and not VariableOperations.has_variable(
		context,
		variable_name,
		value_scope
	):
		_log_error_localized("FUSE_ERROR_VAR_NOT_FOUND", {"variable": variable_name})
		set_error_localized("FUSE_ERROR_VAR_NOT_FOUND", FuseError.ErrorType.VALIDATION_ERROR, {"variable": variable_name})
		finished.emit()
		return

	# 使用变量...

	_on_execution_completed()
```

**❌ 已废弃的用法**（不推荐）:
```gdscript
# 旧 API（已废弃）
var value = context.get_variable(var_name, is_global, default_value)
context.set_variable(var_name, is_global, value)

# 或直接访问
if context.global_variables:
	context.global_variables.set_variable(var_name, value)
```

**作用域字符串显示**（使用 VariableScopeUtils）:
```gdscript
# 在描述中显示作用域
var scope_str = VariableScopeUtils.enum_to_string(value_scope).to_upper()
var description = "%s [%s]" % [variable_name, scope_str]
# 结果: "my_variable [LOCAL]", "my_variable [SCOPE]", "my_variable [GLOBAL]"
```

**SCOPE 作用域验证**:
```gdscript
func validate() -> Array[String]:
	var errors = super.validate()

	# 验证变量名
	if variable_name.is_empty():
		errors.append("变量名不能为空")

	# 验证 SCOPE 作用域需要 ScopeVariableManager
	if value_scope == BaseVariable.VariableScope.SCOPE:
		var manager = ScopeVariableManager.get_instance()
		if manager == null:
			errors.append("未找到 ScopeVariableManager 实例")

	return errors
```

### AudioServer API（Godot 4.x）

**❌ 错误用法**:
```gdscript
var bus_names = AudioServer.get_bus_names()  # 不是静态方法
```

**✅ 正确用法**:
```gdscript
var bus_names = []
for i in range(AudioServer.get_bus_count()):
	bus_names.append(AudioServer.get_bus_name(i))
```

### Tween 创建（Resource 上下文）

**❌ 错误用法**:
```gdscript
var tween = create_tween()  # 在指令中不可用
```

**✅ 正确用法**:
```gdscript
var scene_tree = Engine.get_main_loop()
if not scene_tree:
	_log_error_localized("FUSE_ERROR_CANNOT_CREATE_TWEEN", {})
	# 回退到直接设置值
	return
var tween = scene_tree.create_tween()
```

### 错误处理和信号发送

```gdscript
# 同步指令错误处理
if error:
	_log_error_localized("ERROR_KEY", {"param": value})
	set_error_localized("ERROR_KEY", FuseError.ErrorType.RUNTIME_ERROR, {"param": value})
	finished.emit()  # 直接发出完成信号
	return

# 同步指令成功完成
_on_execution_completed()

# 异步指令（定时器回调）
func _on_timer_timeout():
	# 完成工作
	finished.emit()  # 在回调中发出完成信号
```

### 变量类型推断

```gdscript
# ✅ 明确类型避免推断问题
var node: Node = context.get_node(target_node)
var parent: Node = context.get_node(parent_path)

# ✅ 使用 := 让 Godot 推断（但需要初始化）
var node := context.get_node(target_node)

# ❌ 避免未初始化的变量
var node: Node  # 未初始化，类型推断可能失败
node = context.get_node(target_node)
```

### GDScript 2.0 三元运算符

**语法**:
```gdscript
# ✅ 正确（Python 风格）
value_if_true if condition else value_if_false

# ❌ 错误（C 风格）
condition ? value_if_true : value_if_false
```

---

### 完成信号时机（CompletionSignalTiming）

**用途**: 控制 `finished` 信号的发送时机。

```gdscript
enum CompletionSignalTiming {
	ON_START,   # 在执行开始时发送完成信号
	ON_FINISH   # 在执行完成时发送完成信号（默认）
}

@export var completion_timing: CompletionSignalTiming = CompletionSignalTiming.ON_FINISH
```

**使用场景**:
- `ON_FINISH`（默认）: 指令实际执行完成后才发送 `finished` 信号 → 正常异步指令
- `ON_START`: 指令一开始就发信号，后续执行不阻塞 → 纯通知/日志类指令

---

### 执行模式（ExecutionMode）

**用途**: 控制指令的执行模式，用于智能执行路径优化。

```gdscript
enum ExecutionMode {
	AUTO_DETECT,   # 自动检测执行模式（推荐）
	FORCE_ASYNC,   # 强制异步执行
	FORCE_SYNC     # 强制同步执行
}

@export var execution_mode: ExecutionMode = ExecutionMode.AUTO_DETECT
```

**检测机制**:
- `AUTO_DETECT`: `BaseInstruction._detect_sync_capability()` 通过源码分析（检查 `await`/`finished.emit()`）自动判断
- `FORCE_ASYNC`: 强制使用异步路径（适合包含异步子指令的指令）
- `FORCE_SYNC`: 强制使用同步路径（适合纯计算、无外部依赖的指令）

**相关方法**:
- `can_execute_sync()` — 根据执行模式判断是否可同步
- `set_synchronous_hint(is_sync: bool)` — 手动设置同步提示
- `_is_synchronous()` — 子类重写以声明同步能力

---

### 指令取消（cancel）

**用途**: 取消正在执行的指令。如果指令正在运行，会设置状态为 CANCELLED 并发出 `finished` 信号。

```gdscript
## 取消指令执行
##
## 取消正在执行的指令，会：
## 1. 设置执行状态为 CANCELLED
## 2. 设置错误信息
## 3. 发出 finished 信号
## 4. 清理超时计时器
##
## 子类重写时应调用 super.cancel()
func cancel() -> void:
	if execution_status == ExecutionStatus.RUNNING:
		execution_status = ExecutionStatus.CANCELLED
		error_message = "指令被取消"
		_cleanup_timeout_timer()
		finished.emit()
```

**使用场景**:
- 用户手动取消长时间运行的异步指令
- 游戏状态变化需要中断当前操作
- 子指令在被包含指令中执行，父指令被取消时

---

### 超时管理

**用途**: 设置指令执行超时，防止指令无限等待。

```gdscript
## 设置超时时间
## - timeout_seconds: 超时时间（秒），0 表示禁用
func set_timeout(timeout_seconds: float) -> void:
	_timeout_duration = max(0.0, timeout_seconds)

## 获取超时时间
func get_timeout() -> float:
	return _timeout_duration

## 检查是否启用了超时
func has_timeout() -> bool:
	return _timeout_duration > 0.0

## 获取执行时间
func get_execution_time() -> float:
	if execution_status == ExecutionStatus.RUNNING:
		return (Time.get_ticks_msec() / 1000.0) - _execution_start_time
	return 0.0
```

**超时处理**:
- 超时时会自动调用 `_on_timeout()`，设置错误类型为 `TIMEOUT_ERROR`
- 父指令的 `_start_execution()` 会自动调用 `_setup_timeout_timer()`
- 完成/取消/错误时会自动调用 `_cleanup_timeout_timer()`

---

## RuntimeInstructionInstance 架构支持

> **重要**: 对于异步指令（特别是使用定时器的指令），应实现 `RuntimeInstructionInstance` 架构以确保状态隔离和暂停/恢复功能。

### 为什么需要 RuntimeInstructionInstance？

**问题场景**：
- 同一个指令资源被多个执行实例并发执行
- 指令执行过程中需要暂停/恢复
- 定时器回调需要正确清理和恢复

**解决方案**：
每个执行实例拥有独立的 `runtime_state` 字典，存储该实例的运行时状态。

### 必需实现的方法

#### 1. `get_default_runtime_state()` - 声明运行时状态

**所有异步指令都应实现此方法**：

```gdscript
## 获取默认运行时状态
##
## 声明指令需要的运行时状态。
## 这些状态会在 RuntimeInstructionInstance 初始化时被复制。
func get_default_runtime_state() -> Dictionary:
	var state = super.get_default_runtime_state()
	state["timer"] = null  # 每个 RuntimeInstance 有自己的 timer
	state["is_running"] = false
	state["wait_time"] = wait_time  # 复制配置值
	state["pause_remaining_time"] = 0.0  # 暂停时剩余时间
	state["current_timer_callback"] = null  # 存储回调引用（用于暂停时断开）
	return state
```

**关键要点**：
- ✅ 首先调用 `super.get_default_runtime_state()` 获取基类状态
- ✅ 声明所有运行时需要的变量（定时器、计数器、标志位等）
- ✅ 复制配置值到状态中（避免多实例共享同一配置）
- ✅ 为暂停/恢复功能预留状态字段

#### 2. `execute_with_runtime_instance()` - 运行时执行方法

**替代传统的 `execute()` 方法**：

```gdscript
## 使用运行时实例执行（推荐模式）
##
## 这种模式下，所有状态存储在 runtime_instance.runtime_state 中，
## 确保多个执行实例互不干扰。
##
## 使用 runtime_instance 管理信号连接，避免 bind 泄漏
func execute_with_runtime_instance(runtime_instance: RuntimeInstructionInstance) -> bool:
	_start_execution(runtime_instance.execution_context)

	# 获取运行时状态
	var state = runtime_instance.runtime_state

	# ... 执行逻辑，使用 state 存储状态 ...

	# 创建计时器并存储到运行时状态
	var scene_tree = Engine.get_main_loop()
	if scene_tree:
		var timer = scene_tree.create_timer(actual_wait_time)
		state["timer"] = timer  # 存储到独立的运行时状态
		state["is_running"] = true
		state["wait_start_time"] = Time.get_ticks_msec() / 1000.0

		# 使用 Callable 并注册到 runtime_instance
		var callback = _create_timer_callback(runtime_instance)
		timer.timeout.connect(callback)
		runtime_instance.register_timer_callback(callback)
		state["current_timer_callback"] = callback  # 存储引用，用于暂停时断开

		return false  # 异步执行

	return true  # 同步完成
```

**返回值说明**：
- `return true` - 指令同步完成
- `return false` - 指令异步执行中

#### 3. 回调创建方法 - 避免 bind 泄漏

**使用闭包创建回调，并存储引用**：

```gdscript
## 创建计时器回调（避免 bind）
##
## 使用 Callable 和闭包，但存储引用以便清理
func _create_timer_callback(runtime_instance: RuntimeInstructionInstance) -> Callable:
	var callback = func():
		_on_runtime_timer_timeout(runtime_instance)
	return callback

## 运行时计时器超时回调
func _on_runtime_timer_timeout(runtime_instance: RuntimeInstructionInstance):
	# 检查实例是否仍然有效
	if not runtime_instance or runtime_instance.is_completed():
		return

	var state = runtime_instance.runtime_state

	# 清理运行时状态
	state["timer"] = null
	state["is_running"] = false

	# 标记完成
	runtime_instance._complete_execution()
```

**关键要点**：
- ✅ 使用闭包而非 `bind()` 避免内存泄漏
- ✅ 回调开头检查实例有效性
- ✅ 使用 `runtime_instance._complete_execution()` 完成执行
- ❌ 不要使用 `finished.emit()`（由 `_complete_execution` 处理）

#### 4. 暂停/恢复处理（可选）

**如果指令支持暂停/恢复，实现以下方法**：

```gdscript
## 暂停处理
##
## 当运行时实例被暂停时，记录剩余时间并断开原计时器
func on_runtime_pause(runtime_instance: RuntimeInstructionInstance) -> void:
	var state = runtime_instance.runtime_state
	if state.has("timer") and state["timer"]:
		var timer = state["timer"]
		if timer is SceneTreeTimer:
			# SceneTreeTimer 无法暂停，记录剩余时间
			var elapsed = Time.get_ticks_msec() / 1000.0 - state.get("wait_start_time", 0.0)
			var remaining = state.get("actual_wait_time", 0.0) - elapsed
			state["pause_remaining_time"] = max(0.0, remaining)

			# 使用存储的回调引用断开原计时器（关键修复！）
			var callback = state.get("current_timer_callback")
			if callback and timer.timeout.is_connected(callback):
				timer.timeout.disconnect(callback)

			state["timer"] = null
			state["current_timer_callback"] = null  # 清除回调引用

## 恢复处理
##
## 当运行时实例被恢复时，为剩余时间创建新计时器
func on_runtime_resume(runtime_instance: RuntimeInstructionInstance) -> void:
	var state = runtime_instance.runtime_state
	var remaining = state.get("pause_remaining_time", 0.0)

	if remaining > 0:
		# 创建新计时器用于剩余时间
		var scene_tree = Engine.get_main_loop()
		if scene_tree:
			var timer = scene_tree.create_timer(remaining)
			state["timer"] = timer
			state["wait_start_time"] = Time.get_ticks_msec() / 1000.0
			state["actual_wait_time"] = remaining

			var callback = _create_timer_callback(runtime_instance)
			timer.timeout.connect(callback)
			runtime_instance.register_timer_callback(callback)
			state["current_timer_callback"] = callback  # 存储回调引用

	state["pause_remaining_time"] = 0.0
```

### 完整的 RuntimeInstructionInstance 模板

```gdscript
## ============================================================
## 运行时实例模式支持（RuntimeInstructionInstance 架构）
## ============================================================

## 获取默认运行时状态
func get_default_runtime_state() -> Dictionary:
	var state = super.get_default_runtime_state()
	state["timer"] = null
	state["is_running"] = false
	state["pause_remaining_time"] = 0.0
	state["current_timer_callback"] = null
	return state

## 使用运行时实例执行
func execute_with_runtime_instance(runtime_instance: RuntimeInstructionInstance) -> bool:
	_start_execution(runtime_instance.execution_context)
	var state = runtime_instance.runtime_state

	# ... 执行逻辑 ...

	# 异步返回 false，同步返回 true
	return false

## 创建计时器回调
func _create_timer_callback(runtime_instance: RuntimeInstructionInstance) -> Callable:
	var callback = func():
		_on_runtime_timer_timeout(runtime_instance)
	return callback

## 计时器超时回调
func _on_runtime_timer_timeout(runtime_instance: RuntimeInstructionInstance):
	if not runtime_instance or runtime_instance.is_completed():
		return

	var state = runtime_instance.runtime_state
	state["timer"] = null
	state["is_running"] = false

	runtime_instance._complete_execution()

## 暂停处理
func on_runtime_pause(runtime_instance: RuntimeInstructionInstance) -> void:
	var state = runtime_instance.runtime_state
	# ... 记录剩余时间，断开计时器 ...

## 恢复处理
func on_runtime_resume(runtime_instance: RuntimeInstructionInstance) -> void:
	var state = runtime_instance.runtime_state
	# ... 重新创建计时器 ...
```

### RuntimeInstructionInstance 最佳实践

#### 1. 状态隔离原则

**❌ 错误做法** - 使用类成员变量：
```gdscript
var _timer: SceneTreeTimer  # 多实例共享，会冲突！
var _count: int = 0  # 并发执行时会互相干扰
```

**✅ 正确做法** - 使用 runtime_state：
```gdscript
func get_default_runtime_state() -> Dictionary:
	var state = super.get_default_runtime_state()
	state["timer"] = null  # 每个实例独立
	state["count"] = 0  # 每个实例独立
	return state

func execute_with_runtime_instance(runtime_instance: RuntimeInstructionInstance) -> bool:
	var state = runtime_instance.runtime_state
	state["timer"] = scene_tree.create_timer(delay)
	state["count"] += 1
```

#### 2. 回调注册机制

**必须使用 `register_timer_callback()`**：
```gdscript
var callback = _create_timer_callback(runtime_instance)
timer.timeout.connect(callback)
runtime_instance.register_timer_callback(callback)  # 关键！
state["current_timer_callback"] = callback  # 存储引用
```

**原因**：
- 确保指令取消时自动断开所有回调
- 避免内存泄漏
- 支持暂停时正确断开连接

#### 3. 有效性检查

**回调开头必须检查实例有效性**：
```gdscript
func _on_runtime_timer_timeout(runtime_instance: RuntimeInstructionInstance):
	# 关键：检查实例是否仍然有效
	if not runtime_instance or runtime_instance.is_completed():
		return

	# 安全执行后续逻辑
```

#### 4. 完成执行

**使用 `_complete_execution()` 而非 `finished.emit()`**：
```gdscript
# ✅ 正确
runtime_instance._complete_execution()

# ❌ 错误（会重复发送信号）
finished.emit()
```

#### 5. 暂停时断开连接

**存储回调引用以便断开**：
```gdscript
# 创建时存储
var callback = _create_timer_callback(runtime_instance)
timer.timeout.connect(callback)
state["current_timer_callback"] = callback

# 暂停时断开
func on_runtime_pause(runtime_instance: RuntimeInstructionInstance) -> void:
	var state = runtime_instance.runtime_state
	var callback = state.get("current_timer_callback")
	if callback and timer.timeout.is_connected(callback):
		timer.timeout.disconnect(callback)
```

### 多计时器管理示例

对于需要多个计时器的指令（如 WaitUntil 的轮询计时器和超时计时器）：

```gdscript
func get_default_runtime_state() -> Dictionary:
	var state = super.get_default_runtime_state()
	state["check_timer"] = null  # 轮询计时器
	state["timeout_timer"] = null  # 超时计时器
	state["current_poll_callback"] = null
	state["current_timeout_callback"] = null
	state["pause_remaining_timeout"] = 0.0
	return state

## 清理运行时计时器
func _cleanup_runtime_timers(runtime_instance: RuntimeInstructionInstance) -> void:
	var state = runtime_instance.runtime_state

	# 清理轮询计时器
	if state.has("check_timer") and state["check_timer"]:
		var check_timer = state["check_timer"]
		var poll_callback = state.get("current_poll_callback")
		if poll_callback and check_timer.timeout.is_connected(poll_callback):
			check_timer.timeout.disconnect(poll_callback)
		state["check_timer"] = null
		state["current_poll_callback"] = null

	# 清理超时计时器
	if state.has("timeout_timer") and state["timeout_timer"]:
		var timeout_timer = state["timeout_timer"]
		var timeout_callback = state.get("current_timeout_callback")
		if timeout_callback and timeout_timer.timeout.is_connected(timeout_callback):
			timeout_timer.timeout.disconnect(timeout_callback)
		state["timeout_timer"] = null
		state["current_timeout_callback"] = null
```

### 何时使用 RuntimeInstructionInstance

**必须使用**：
- ✅ 异步指令（使用定时器、Tween 等）
- ✅ 需要暂停/恢复功能的指令
- ✅ 可能被并发执行多次的指令
- ✅ 需要跟踪执行状态的指令

**可选使用**：
- 同步指令（无状态，立即完成）
- 单次执行且不需要暂停的简单指令

### 常见陷阱

#### 陷阱 1: 忘记调用 super.get_default_runtime_state()

**❌ 错误做法**：
```gdscript
func get_default_runtime_state() -> Dictionary:
	return {
		"timer": null,
		"count": 0
	}  # 缺少基类状态！
```

**✅ 正确做法**：
```gdscript
func get_default_runtime_state() -> Dictionary:
	var state = super.get_default_runtime_state()  # 获取基类状态
	state["timer"] = null
	state["count"] = 0
	return state
```

#### 陷阱 2: 使用 bind() 创建回调

**❌ 错误做法**：
```gdscript
timer.timeout.connect(_on_timer_timeout.bind(runtime_instance))
# bind() 会导致内存泄漏！
```

**✅ 正确做法**：
```gdscript
var callback = func():
	_on_runtime_timer_timeout(runtime_instance)
timer.timeout.connect(callback)
runtime_instance.register_timer_callback(callback)
```

#### 陷阱 3: 暂停时未断开计时器

**❌ 错误做法**：
```gdscript
func on_runtime_pause(runtime_instance: RuntimeInstructionInstance) -> void:
	pass  # 计时器继续运行，恢复时会出问题
```

**✅ 正确做法**：
```gdscript
func on_runtime_pause(runtime_instance: RuntimeInstructionInstance) -> void:
	var state = runtime_instance.runtime_state
	if state["timer"]:
		var callback = state.get("current_timer_callback")
		if callback and state["timer"].timeout.is_connected(callback):
			state["timer"].timeout.disconnect(callback)
		state["timer"] = null
```

#### 陷阱 4: 忘记注册回调

**❌ 错误做法**：
```gdscript
var callback = func(): _on_timeout(runtime_instance)
timer.timeout.connect(callback)
# 忘记注册！取消时不会断开连接
```

**✅ 正确做法**：
```gdscript
var callback = func(): _on_timeout(runtime_instance)
timer.timeout.connect(callback)
runtime_instance.register_timer_callback(callback)  # 必须注册
```

---

## 完整指令模板

```gdscript
@tool
@icon("res://addons/fuse/icons/builtin/Script.png")
extends BaseInstruction
class_name TemplateInstruction

## 指令描述

# 参数定义
var target_node: NodePath = NodePath("")

## 获取指令元数据
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_XXX_NAME"
	metadata.category_key = "FUSE_CATEGORY_XXX"
	metadata.description_key = "FUSE_INSTRUCTION_XXX_DESC"
	metadata.keywords = ["keyword1", "keyword2"]
	metadata.builtin_icon = "Script"
	return metadata

## 设置指令元数据
func _setup_metadata():
	pass

## 获取属性列表
func _get_property_list()  -> Array[Dictionary]:
	var properties := []

	# 分类
	properties.append({
		name = "Category",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	# 属性
	properties.append({
		name = "target_node",
		type = TYPE_NODE_PATH,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	return properties

## 更新资源名称（必需）
func _update_resource_name():
	var parts = []
	parts.append("操作名称")
	if not target_node.is_empty():
		parts.append("'%s'" % target_node)
	resource_name = " ".join(parts)

## 执行指令
func execute(context: ExecutionContext):
	_start_execution(context)

	# 验证
	if target_node.is_empty():
		_log_error_localized("FUSE_ERROR_TARGET_NODE_EMPTY", {})
		set_error_localized("FUSE_ERROR_TARGET_NODE_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
		finished.emit()
		return

	# 获取节点
	var node := context.get_node(target_node)
	if not node:
		_log_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", {"node": str(target_node)})
		set_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {"node": str(target_node)})
		finished.emit()
		return

	# 执行逻辑
	# ...

	# 同步完成
	_on_execution_completed()

## 验证参数（必需）
func validate() -> Array[String]:
	var errors = super.validate()

	if target_node.is_empty():
		errors.append("目标节点路径不能为空")

	return errors

## 获取描述（必需）
func get_description() -> String:
	return "操作 %s" % str(target_node)

## 动态属性设置（可选）
func _set(property: StringName, value: Variant) -> bool:
	if property == "some_property":
		set(property, value)
		notify_property_list_changed()
		_update_resource_name()
		return true
	return false

## 属性验证（可选）
func _validate_property(property: Dictionary) -> void:
	if property.name == "some_property" and some_condition:
		property.usage = PROPERTY_USAGE_NO_EDITOR
```

---

## 带变量操作的指令模板

> **重要**: 当指令需要读写变量时，使用以下模板确保正确使用三层变量系统。

```gdscript
@tool
@icon("res://addons/fuse/icons/builtin/Script.png")
extends BaseInstruction
class_name VariableOperationInstruction

## 指令描述

# 输入变量名
var input_variable: String = ""

# 输入变量作用域
@export var input_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		input_scope = value
		_update_resource_name()

# 输出变量名
var output_variable: String = "result"

# 输出变量作用域
@export var output_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		output_scope = value
		_update_resource_name()

## 获取指令元数据
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_XXX_NAME"
	metadata.category_key = "FUSE_CATEGORY_XXX"
	metadata.description_key = "FUSE_INSTRUCTION_XXX_DESC"
	metadata.keywords = ["keyword1", "keyword2"]
	metadata.builtin_icon = "Script"
	return metadata

## 设置指令元数据
func _setup_metadata():
	pass

## 获取属性列表
func _get_property_list()  -> Array[Dictionary]:
	var properties := []

	# Input 分类
	properties.append({
		name = "Input",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "input_variable",
		type = TYPE_STRING,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	properties.append({
		name = "input_scope",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Local,Scope,Global",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# Output 分类
	properties.append({
		name = "Output",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "output_variable",
		type = TYPE_STRING,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	properties.append({
		name = "output_scope",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Local,Scope,Global",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	return properties

## 更新资源名称（必需）
func _update_resource_name():
	var parts = []

	parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_XXX_RESOURCE"))

	# 输入变量
	if not input_variable.is_empty():
		var input_scope_str = VariableScopeUtils.enum_to_string(input_scope).to_upper()
		parts.append("← %s [%s]" % [input_variable, input_scope_str])
	else:
		parts.append("← (%s)" % FuseLocalization.translate("FUSE_VALUE_VARIABLE_EMPTY"))

	# 输出变量
	if not output_variable.is_empty():
		var output_scope_str = VariableScopeUtils.enum_to_string(output_scope).to_upper()
		parts.append("→ %s [%s]" % [output_variable, output_scope_str])
	else:
		parts.append("→ (%s)" % FuseLocalization.translate("FUSE_VALUE_VARIABLE_EMPTY"))

	resource_name = " ".join(parts)

## 执行指令
func execute(context: ExecutionContext):
	_start_execution(context)

	# 验证输入变量名
	if input_variable.is_empty():
		_log_error_localized("FUSE_ERROR_VAR_NAME_EMPTY", {})
		set_error_localized("FUSE_ERROR_VAR_NAME_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
		finished.emit()
		return

	# 读取输入变量
	var input_value = VariableOperations.get_variable(
		context,
		input_variable,
		input_scope,
		null
	)

	# 检查变量是否存在
	if input_value == null and not VariableOperations.has_variable(
		context,
		input_variable,
		input_scope
	):
		_log_error_localized("FUSE_ERROR_VAR_NOT_FOUND", {"variable": input_variable})
		set_error_localized("FUSE_ERROR_VAR_NOT_FOUND", FuseError.ErrorType.VALIDATION_ERROR, {"variable": input_variable})
		finished.emit()
		return

	# 执行操作
	var result = _process_value(input_value)

	# 保存结果到输出变量
	if not output_variable.is_empty():
		VariableOperations.set_variable(
			context,
			output_variable,
			output_scope,
			result
		)

	_on_execution_completed()

## 内部处理方法
func _process_value(value: Variant) -> Variant:
	# 实现具体的处理逻辑
	return value

## 验证参数（必需）
func validate() -> Array[String]:
	var errors = super.validate()

	# 验证输入变量名
	if input_variable.is_empty():
		errors.append("输入变量名不能为空")

	# 验证输出变量名
	if output_variable.is_empty():
		errors.append("输出变量名不能为空")

	# 验证输入 SCOPE 作用域需要 ScopeVariableManager
	if input_scope == BaseVariable.VariableScope.SCOPE:
		var manager = ScopeVariableManager.get_instance()
		if manager == null:
			errors.append("未找到 ScopeVariableManager 实例")

	# 验证输出 SCOPE 作用域需要 ScopeVariableManager
	if output_scope == BaseVariable.VariableScope.SCOPE:
		var manager = ScopeVariableManager.get_instance()
		if manager == null:
			errors.append("未找到 ScopeVariableManager 实例")

	return errors

## 获取描述（必需）
func get_description() -> String:
	var input_scope_str = VariableScopeUtils.enum_to_string(input_scope).to_upper()
	var output_scope_str = VariableScopeUtils.enum_to_string(output_scope).to_upper()

	var input_str = input_variable if not input_variable.is_empty() else "(%s)" % FuseLocalization.translate("FUSE_VALUE_VARIABLE_EMPTY")
	var output_str = output_variable if not output_variable.is_empty() else "(%s)" % FuseLocalization.translate("FUSE_VALUE_VARIABLE_EMPTY")

	return FuseLocalization.translate_format("FUSE_INSTRUCTION_XXX_DESC_FORMAT", {
		"input": "%s [%s]" % [input_str, input_scope_str],
		"output": "%s [%s]" % [output_str, output_scope_str]
	})

## 动态属性设置
func _set(property: StringName, value: Variant) -> bool:
	if property == "input_scope" or property == "output_scope":
		set(property, value)
		notify_property_list_changed()
		_update_resource_name()
		return true
	return false
```

**关键要点**:
1. ✅ 使用 `@export var scope: BaseVariable.VariableScope` 定义作用域属性
2. ✅ 使用 `VariableOperations.get_variable()` 读取变量
3. ✅ 使用 `VariableOperations.set_variable()` 写入变量
4. ✅ 使用 `VariableOperations.has_variable()` 检查变量存在性
5. ✅ 使用 `VariableScopeUtils.enum_to_string()` 转换显示字符串
6. ✅ 在 `validate()` 中验证 SCOPE 作用域需要 ScopeVariableManager

---

## 创建步骤

### Step 1: 创建指令类骨架

创建指令文件 `addons/fuse/instructions/<instruction_name>.gd`：

```gdscript
@tool
@icon("res://addons/fuse/icons/builtin/Script.png")
extends BaseInstruction
class_name YourInstruction

## 指令描述

# 参数定义
var target_node: NodePath = NodePath("")

## 获取指令元数据
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_XXX_NAME"
	metadata.category_key = "FUSE_CATEGORY_XXX"
	metadata.description_key = "FUSE_INSTRUCTION_XXX_DESC"
	metadata.keywords = ["keyword1", "keyword2"]
	metadata.builtin_icon = "Script"
	return metadata

## 设置指令元数据
func _setup_metadata():
	pass

## 获取属性列表
func _get_property_list()  -> Array[Dictionary]:
	var properties := []
	# ...（参考模板）
	return properties

## 更新资源名称（必需）
func _update_resource_name():
	# ...

## 执行指令
func execute(context: ExecutionContext):
	# ...

## 验证参数（必需）
func validate() -> Array[String]:
	# ...

## 获取描述（必需）
func get_description() -> String:
	# ...
```

### Step 2: 添加本地化翻译

在 `addons/fuse/localization/translations.csv` 添加：

```csv
key,zh_CN,en_US
FUSE_INSTRUCTION_XXX_NAME,指令名称,Instruction Name
FUSE_CATEGORY_XXX,分类名称,Category Name
FUSE_INSTRUCTION_XXX_DESC,指令描述,Instruction description
FUSE_ERROR_XXX_ERROR,错误消息,Error message
```

**注意**：
- 使用 `NAME` 后缀表示指令名称
- 使用 `DESC` 后缀表示指令描述
- 使用 `ERROR_XXX_ERROR` 表示错误消息
- 所有占位符使用 `{variable_name}` 格式

### Step 3: 创建测试场景

**Step 3.1: 创建测试场景文件**

创建 `tests/instructions/test_<instruction_name>.tscn`：

```gdscript
[gd_scene load_steps=2 format=3 uid="uid://test_xxx"]

[ext_resource type="Script" path="res://tests/instructions/test_xxx.gd" id="1"]

[node name="TestXxx" type="Node3D"]
script = ExtResource("1")

[node name="TestNode2D" type="Node2D" parent="."]
position = Vector2(100, 100)

[node name="TestNode3D" type="Node3D" parent="."]
position = Vector3(0, 0, 0)
```

**Step 3.2: 创建测试脚本**

创建 `tests/instructions/test_<instruction_name>.gd`：

```gdscript
extends Node3D

## YourInstruction 指令测试

func _ready():
	print("=== Testing YourInstruction ===")
	test_basic_functionality()
	test_edge_cases()
	print("=== All YourInstruction tests passed! ===")

func test_basic_functionality():
	print("Test 1: Basic functionality")

	var instruction_script = load("res://addons/fuse/instructions/your_instruction.gd")
	var instruction = instruction_script.new()
	instruction.target_node = NodePath(".")
	# 设置其他参数...

	var context = ExecutionContext.new()
	add_child(context)

	# 执行前记录状态
	var initial_state = ...

	# 执行指令
	instruction.execute(context)
	await get_tree().process_frame

	# 验证结果
	assert(condition, "Verification message")
	print("  ✓ Test 1 passed\n")

func test_edge_cases():
	print("Test 2: Edge cases")
	# 测试边界情况...
	print("  ✓ Test 2 passed\n")
```


### Step 4: 测试验证

1. 在 Godot 中打开测试场景
2. 运行测试，确认所有测试用例通过
3. 检查编辑器中的 Inspector 显示是否正确
4. 验证本地化是否生效

---

## 最佳实践

### 1. 错误处理

**原则**: 所有错误都应该使用本地化错误消息。

```gdscript
# ✅ 好的做法
if target_node.is_empty():
	_log_error_localized("FUSE_ERROR_TARGET_NODE_EMPTY", {})
	set_error_localized("FUSE_ERROR_TARGET_NODE_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
	finished.emit()
	return

# ❌ 避免硬编码
if target_node.is_empty():
	_log_error("目标节点不能为空")  # 不推荐
	return
```

### 2. 资源清理

**原则**: 异步指令必须正确清理资源（定时器、Tween等）。

```gdscript
func _cleanup_resources() -> void:
	if _timer and is_instance_valid(_timer):
		if _timer.timeout.is_connected(_on_timer_timeout):
			_timer.timeout.disconnect(_on_timer_timeout)
		_timer = null
```

### 3. 类型注解

**原则**: 使用明确的类型注解，避免类型推断问题。

```gdscript
# ✅ 推荐
var node: Node = context.get_node(target_node)

# ✅ 也可以（使用 :=）
var node := context.get_node(target_node)

# ❌ 避免
var node: Node  # 未初始化
node = context.get_node(target_node)
```

### 4. 属性验证

**原则**: 使用 `_validate_property()` 动态控制属性可见性。

```gdscript
func _validate_property(property: Dictionary) -> void:
	# 条件性显示属性
	if property.name == "optional_param" and not show_optional:
		property.usage = PROPERTY_USAGE_NO_EDITOR
```

### 5. 属性刷新

**原则**: 修改影响其他属性的属性时，调用 `notify_property_list_changed()`。

```gdscript
func _set(property: StringName, value: Variant) -> bool:
	if property == "use_variable":
		set(property, value)
		notify_property_list_changed()  # 刷新属性列表
		return true
	return false
```

### 6. 代码组织

**原则**: 按功能组织代码，添加清晰的注释。

```gdscript
## 验证逻辑
func _validate_params(context: ExecutionContext) -> bool:
	# ...

## 执行核心逻辑
func _execute_core(context: ExecutionContext):
	# ...

## 清理资源
func _cleanup_resources():
	# ...
```

### 7. 变量系统最佳实践

**原则**: 使用三层变量系统时遵循统一的模式和规范。

#### 7.1 优先使用 VariableOperations

**✅ 推荐做法**:
```gdscript
# 统一使用 VariableOperations 访问变量
var value = VariableOperations.get_variable(context, var_name, var_scope, default_value)
VariableOperations.set_variable(context, var_name, var_scope, new_value)
```

**❌ 避免直接访问**:
```gdscript
# 不推荐：直接访问 context 或 global_variables
var value = context.local_variables.get(var_name, default_value)
context.global_variables.set_variable(var_name, value)
```

#### 7.2 使用类型安全的枚举

**✅ 推荐做法**:
```gdscript
# 使用类型安全的枚举
@export var value_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		value_scope = value
		_update_resource_name()
```

**❌ 避免布尔值**:
```gdscript
# 不推荐：使用布尔值表示作用域
var is_global: bool = false
```

#### 7.3 验证 SCOPE 作用域

**✅ 推荐做法**:
```gdscript
func validate() -> Array[String]:
	var errors = super.validate()

	# 验证变量名
	if variable_name.is_empty():
		errors.append("变量名不能为空")

	# 验证 SCOPE 作用域需要 ScopeVariableManager
	if value_scope == BaseVariable.VariableScope.SCOPE:
		var manager = ScopeVariableManager.get_instance()
		if manager == null:
			errors.append("未找到 ScopeVariableManager 实例")

	return errors
```

#### 7.4 区分变量不存在和值为 null

**✅ 推荐做法**:
```gdscript
# 读取变量
var value = VariableOperations.get_variable(context, var_name, var_scope, null)

# 检查变量是否存在（区分"不存在"和"值为null"）
if value == null and not VariableOperations.has_variable(context, var_name, var_scope):
	_log_error_localized("FUSE_ERROR_VAR_NOT_FOUND", {"variable": var_name})
	finished.emit()
	return

# 此时 value 为 null 是有效的（变量确实存在，但值为 null）
```

#### 7.5 使用 VariableScopeUtils 统一显示格式

**✅ 推荐做法**:
```gdscript
# 在描述中显示作用域
var scope_str = VariableScopeUtils.enum_to_string(value_scope).to_upper()
var description = "变量 %s [%s]" % [var_name, scope_str]

# 在资源名称中显示
func _update_resource_name():
	var scope_str = VariableScopeUtils.enum_to_string(save_to_scope).to_upper()
	resource_name = "Set %s → %s [%s]" % [property, var_name, scope_str]
```

**❌ 避免手动转换**:
```gdscript
# 不推荐：手动 match 转换
var scope_str = ""
match value_scope:
	BaseVariable.VariableScope.LOCAL:
		scope_str = "LOCAL"
	BaseVariable.VariableScope.SCOPE:
		scope_str = "SCOPE"
	BaseVariable.VariableScope.GLOBAL:
		scope_str = "GLOBAL"
```

#### 7.6 变量作用域选择指南

**何时使用 LOCAL**:
- ✅ 单次指令执行的临时数据
- ✅ 计算中间结果
- ✅ 循环计数器
- ❌ 需要跨指令共享的数据
- ❌ 需要持久化的数据

**何时使用 SCOPE**:
- ✅ 场景局部共享数据
- ✅ UI 组件状态
- ✅ 节点组配置
- ❌ 全局游戏配置
- ❌ 跨场景共享数据
- ⚠️ 需要添加 ScopeVariableContainer 节点

**何时使用 GLOBAL**:
- ✅ 游戏配置（音量、画质等）
- ✅ 玩家数据（等级、经验、背包）
- ✅ 游戏进度（当前关卡、任务状态）
- ✅ 跨场景共享数据
- ❌ 临时数据
- ❌ 场景局部数据

#### 7.7 完整的变量操作流程

**标准模式**:
```gdscript
# 1. 定义变量作用域属性
@export var value_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		value_scope = value
		_update_resource_name()

# 2. 在属性列表中添加作用域选择
func _get_property_list()  -> Array[Dictionary]:
	var properties := []
	properties.append({
		name = "value_scope",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Local,Scope,Global",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})
	return properties

# 3. 读取变量
func execute(context: ExecutionContext):
	var value = VariableOperations.get_variable(
		context,
		variable_name,
		value_scope,
		null
	)

	# 4. 验证变量存在性
	if value == null and not VariableOperations.has_variable(
		context,
		variable_name,
		value_scope
	):
		_log_error_localized("FUSE_ERROR_VAR_NOT_FOUND", {"variable": variable_name})
		set_error_localized("FUSE_ERROR_VAR_NOT_FOUND", FuseError.ErrorType.VALIDATION_ERROR, {"variable": variable_name})
		finished.emit()
		return

	# 5. 使用变量...

# 6. 在显示方法中使用 VariableScopeUtils
func _update_resource_name():
	var scope_str = VariableScopeUtils.enum_to_string(value_scope).to_upper()
	resource_name = "%s [%s]" % [variable_name, scope_str]

# 7. 在验证中检查 SCOPE 前提条件
func validate() -> Array[String]:
	var errors = super.validate()
	if value_scope == BaseVariable.VariableScope.SCOPE:
		var manager = ScopeVariableManager.get_instance()
		if manager == null:
			errors.append("未找到 ScopeVariableManager 实例")
	return errors
```

---

## 常见陷阱

### 陷阱 1: 在 Resource 中使用 Node 方法

**问题**:
```gdscript
var tree = get_tree()  # ❌ 在指令中不可用
```

**解决方案**:
```gdscript
var scene_tree = Engine.get_main_loop()
if scene_tree:
	# 使用 scene_tree
```

### 陷阱 2: 忘记调用 `_start_execution()`

**问题**:
```gdscript
func execute(context: ExecutionContext):
	# ❌ 忘记调用 _start_execution()
	# 执行逻辑...
```

**解决方案**:
```gdscript
func execute(context: ExecutionContext):
	_start_execution(context)  # ✅ 必须首先调用
	# 执行逻辑...
```

### 陷阱 3: 同步/异步混淆

**问题**:
```gdscript
func execute(context: ExecutionContext):
	# 同步完成
	_on_execution_completed()

	# 又发出完成信号 ❌ 冲突
	finished.emit()
```

**解决方案**:
- 同步指令: 只调用 `_on_execution_completed()`
- 异步指令: 只在回调中调用 `finished.emit()`

### 陷阱 4: 相对路径解析失败

**问题**:
```gdscript
var node = get_node(target_node)  # ❌ 无法正确解析相对路径
```

**解决方案**:
```gdscript
var node = context.get_node(target_node)  # ✅ 支持相对路径
```

### 陷阱 5: 全局变量访问

**问题**:
```gdscript
GlobalVariableAssistant.set_variable(name, value)  # ❌ 静态方法不存在
```

**解决方案**:
```gdscript
if context.global_variables:
	context.global_variables.set_variable(name, value)  # ✅ 正确
```

### 陷阱 6: 类型推断失败

**问题**:
```gdscript
var result: int
# 忘记初始化，后续赋值可能推断失败
```

**解决方案**:
```gdscript
var result: int = 0  # ✅ 初始化
var result := calculate()  # ✅ 使用 :=
```

### 陷阱 7: NaN 和 Infinity 验证

**问题**: 缺少边界值验证

**解决方案**:
```gdscript
func _is_valid_value(value: Vector3) -> bool:
	return not (is_nan(value.x) or is_inf(value.x) or
				is_nan(value.y) or is_inf(value.y) or
				is_nan(value.z) or is_inf(value.z))
```

### 陷阱 8: Godot 4.x API 变化

**问题**: 使用 Godot 3.x API

**解决方案**:
- AudioServer: 使用 `get_bus_count()` + `get_bus_name(i)`
- Tween: 使用 `scene_tree.create_tween()`
- SceneTree: 使用 `Engine.get_main_loop()`

### 陷阱 9: 使用已废弃的变量访问 API

**问题**: 使用旧版本的变量访问方法

**❌ 错误用法**:
```gdscript
# 旧 API（已废弃）
var value = context.get_variable(var_name, is_global, default_value)
context.set_variable(var_name, is_global, value)

# 或直接访问
if context.global_variables:
	context.global_variables.set_variable(var_name, value)
```

**✅ 正确用法**:
```gdscript
# 新 API（推荐）
var value = VariableOperations.get_variable(
	context,
	var_name,
	var_scope,  # BaseVariable.VariableScope
	default_value
)

VariableOperations.set_variable(
	context,
	var_name,
	var_scope,  # BaseVariable.VariableScope
	new_value
)
```

### 陷阱 10: 使用布尔值表示变量作用域

**问题**: 使用 `is_global: bool` 无法支持三层变量系统

**❌ 错误用法**:
```gdscript
var is_global: bool = false

func execute(context: ExecutionContext):
	if is_global:
		value = context.global_variables.get_variable(var_name)
	else:
		value = context.local_variables.get(var_name)
```

**✅ 正确用法**:
```gdscript
@export var var_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL

func execute(context: ExecutionContext):
	value = VariableOperations.get_variable(context, var_name, var_scope, default_value)
```

### 陷阱 11: 忘记验证 SCOPE 作用域的前提条件

**问题**: SCOPE 作用域需要 ScopeVariableManager 实例，但未验证

**❌ 错误做法**:
```gdscript
func validate() -> Array[String]:
	var errors = super.validate()

	if variable_name.is_empty():
		errors.append("变量名不能为空")

	# ❌ 缺少 SCOPE 验证
	return errors
```

**✅ 正确做法**:
```gdscript
func validate() -> Array[String]:
	var errors = super.validate()

	if variable_name.is_empty():
		errors.append("变量名不能为空")

	# ✅ 验证 SCOPE 作用域需要 ScopeVariableManager
	if var_scope == BaseVariable.VariableScope.SCOPE:
		var manager = ScopeVariableManager.get_instance()
		if manager == null:
			errors.append("未找到 ScopeVariableManager 实例")

	return errors
```

### 陷阱 12: 混淆"变量不存在"和"变量值为 null"

**问题**: 未使用 `has_variable()` 检查变量存在性

**❌ 错误做法**:
```gdscript
var value = VariableOperations.get_variable(context, var_name, var_scope, null)

if value == null:
	# ❌ 无法区分"变量不存在"和"变量值为 null"
	_log_error("变量未找到")
	return
```

**✅ 正确做法**:
```gdscript
var value = VariableOperations.get_variable(context, var_name, var_scope, null)

# ✅ 检查变量是否存在
if value == null and not VariableOperations.has_variable(context, var_name, var_scope):
	_log_error_localized("FUSE_ERROR_VAR_NOT_FOUND", {"variable": var_name})
	return

# 此时 value 为 null 是有效的（变量确实存在，但值为 null）
```

### 陷阱 13: 手动转换作用域枚举为字符串

**问题**: 重复编写作用域转换逻辑

**❌ 错误做法**:
```gdscript
var scope_str = ""
match value_scope:
	BaseVariable.VariableScope.LOCAL:
		scope_str = "LOCAL"
	BaseVariable.VariableScope.SCOPE:
		scope_str = "SCOPE"
	BaseVariable.VariableScope.GLOBAL:
		scope_str = "GLOBAL"
```

**✅ 正确做法**:
```gdscript
# 使用 VariableScopeUtils 工具类
var scope_str = VariableScopeUtils.enum_to_string(value_scope).to_upper()
```

### 陷阱 14-17: RuntimeInstructionInstance 相关陷阱

> **重要**: 对于异步指令，RuntimeInstructionInstance 架构有多个关键陷阱需要避免。
> 详见 [RuntimeInstructionInstance 架构支持 - 常见陷阱](#常见陷阱-1)

**陷阱概览**：
- **陷阱 14**: 忘记调用 `super.get_default_runtime_state()` - 缺少基类状态
- **陷阱 15**: 使用 `bind()` 创建回调 - 导致内存泄漏
- **陷阱 16**: 暂停时未断开计时器 - 恢复时会出问题
- **陷阱 17**: 忘记注册回调 - 取消时不会断开连接

---

## 测试规范

### 测试文件结构

```gdscript
extends Node3D  # 或 Node，根据指令类型选择

## InstructionName 指令测试

func _ready():
	print("=== Testing InstructionName ===")
	test_case_1()
	test_case_2()
	test_case_3()
	print("=== All InstructionName tests passed! ===")
```

### 测试用例设计

**必需的测试**:
1. **基本功能测试** - 验证指令正常工作
2. **边界值测试** - 测试 NaN、Infinity、大数值
3. **错误处理测试** - 验证错误情况被正确处理
4. **2D/3D 兼容性** - 如果适用，测试两种节点类型
5. **变量输入测试** - 测试从变量读取参数

**测试示例**:
```gdscript
func test_basic_functionality():
	var instruction = InstructionName.new()
	instruction.param = value

	var context = ExecutionContext.new()
	add_child(context)

	instruction.execute(context)
	await get_tree().process_frame

	assert(condition, "Should pass")
```

### 测试断言

```gdscript
# 验证结果
assert(actual == expected, "Error message")
assert(context.had_error() == should_error, "Should have error")
assert(abs(actual - expected) < 0.01, "Should be approximately equal")
```

---

## 快速参考

### 常用代码片段

#### 节点操作
```gdscript
var node := context.get_node(target_node)
if not node:
	_log_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", {"node": str(target_node)})
	set_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {"node": str(target_node)})
	finished.emit()
	return
```

#### SceneTree 操作
```gdscript
var scene_tree = Engine.get_main_loop()
if not scene_tree:
	_log_error_localized("FUSE_ERROR_CANNOT_GET_SCENETREE", {})
	finished.emit()
	return

var current_scene = scene_tree.current_scene
var timer = scene_tree.create_timer(duration)
```

#### 音频操作
```gdscript
var bus_names = []
for i in range(AudioServer.get_bus_count()):
	bus_names.append(AudioServer.get_bus_name(i))
```

#### 变量操作（使用 VariableOperations）

**读取变量**:
```gdscript
# 读取变量（支持三层作用域）
var value = VariableOperations.get_variable(
	context,
	var_name,
	var_scope,  # BaseVariable.VariableScope
	default_value
)

# 检查变量是否存在（区分"不存在"和"值为null"）
if value == null and not VariableOperations.has_variable(context, var_name, var_scope):
	_log_error_localized("FUSE_ERROR_VAR_NOT_FOUND", {"variable": var_name})
	set_error_localized("FUSE_ERROR_VAR_NOT_FOUND", FuseError.ErrorType.VALIDATION_ERROR, {"variable": var_name})
	finished.emit()
	return
```

**设置变量**:
```gdscript
# 设置变量（支持三层作用域）
VariableOperations.set_variable(
	context,
	var_name,
	var_scope,  # BaseVariable.VariableScope
	new_value
)
```

**完整示例**:
```gdscript
# 指令属性定义
@export var value_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		value_scope = value
		_update_resource_name()

# 读取和使用变量
func execute(context: ExecutionContext):
	var value = VariableOperations.get_variable(context, var_name, value_scope, null)

	if value == null and not VariableOperations.has_variable(context, var_name, value_scope):
		_log_error_localized("FUSE_ERROR_VAR_NOT_FOUND", {"variable": var_name})
		finished.emit()
		return

	# 使用 value...
```

**作用域字符串转换**:
```gdscript
# 枚举转字符串
var scope_str = VariableScopeUtils.enum_to_string(value_scope).to_upper()
# 结果: "LOCAL", "SCOPE", 或 "GLOBAL"

# 在描述中使用
var description = "变量 %s [%s]" % [var_name, scope_str]
```

### 常用错误键

已定义的本地化错误键（参考 `translations.csv`）：
- `FUSE_ERROR_TARGET_NODE_EMPTY` - 目标节点为空
- `FUSE_ERROR_TARGET_NODE_NOT_FOUND` - 目标节点未找到
- `FUSE_ERROR_VAR_NAME_EMPTY` - 变量名为空
- `FUSE_ERROR_VAR_NOT_FOUND` - 变量未找到
- `FUSE_ERROR_NODE_TYPE_INVALID` - 节点类型无效
- `FUSE_ERROR_INVALID_POSITION` - 位置值无效
- `FUSE_ERROR_INVALID_ROTATION` - 旋转值无效
- `FUSE_ERROR_INVALID_SCALE` - 缩放值无效
- `FUSE_ERROR_CANNOT_GET_SCENETREE` - 无法获取 SceneTree
- `FUSE_ERROR_CANNOT_GET_CURRENT_SCENE` - 无法获取当前场景
- `FUSE_ERROR_CANNOT_CREATE_TIMER` - 无法创建定时器
- `FUSE_ERROR_CANNOT_CREATE_TWEEN` - 无法创建 Tween

---

## 总结

创建 Fuse 指令的关键要点：

1. ✅ **遵循命名规范** - 简洁、一致、无冗余
2. ✅ **实现必需方法** - `_update_resource_name()`, `validate()`, `get_description()`
3. ✅ **使用正确的 API** - `context.get_node()`, `Engine.get_main_loop()`
4. ✅ **本地化错误消息** - 使用 `_log_error_localized()`
5. ✅ **正确处理同步/异步** - 同步用 `_on_execution_completed()`, 异步用 `finished.emit()`
6. ✅ **添加完整测试** - 基本功能 + 边界情况
7. ✅ **清理资源** - 异步指令必须清理定时器和 Tween
8. ✅ **使用三层变量系统** - 通过 `VariableOperations` 统一访问 LOCAL/SCOPE/GLOBAL 变量
9. ✅ **类型安全的作用域** - 使用 `BaseVariable.VariableScope` 枚举而非布尔值
10. ✅ **验证 SCOPE 前提条件** - 检查 `ScopeVariableManager` 实例是否存在
11. ✅ **实现 RuntimeInstructionInstance 支持** - 异步指令应实现 `get_default_runtime_state()` 和 `execute_with_runtime_instance()`

**变量系统核心要点**:
- 使用 `VariableOperations.get_variable/set_variable/has_variable()` 访问变量
- 使用 `VariableScopeUtils.enum_to_string()` 转换显示字符串
- 使用 `@export var scope: BaseVariable.VariableScope` 定义作用域属性
- 在 `validate()` 中验证 SCOPE 作用域需要 `ScopeVariableManager`
- 使用 `has_variable()` 区分"变量不存在"和"变量值为 null"

**RuntimeInstructionInstance 核心要点**:
- 异步指令**必须**实现 `get_default_runtime_state()` 声明运行时状态
- 使用 `runtime_state` 字典存储实例状态，**不要**使用类成员变量
- 使用闭包创建回调，并调用 `register_timer_callback()` 注册
- 存储回调引用 (`current_timer_callback`) 以便暂停时断开连接
- 回调开头检查 `runtime_instance.is_completed()` 确保有效性
- 使用 `runtime_instance._complete_execution()` 完成执行，**不要**手动 `finished.emit()`
- 实现暂停/恢复需添加 `on_runtime_pause()` 和 `on_runtime_resume()` 方法

**参考文档**:
- [完整指令模板](#完整指令模板)
- [带变量操作的指令模板](#带变量操作的指令模板)
- [RuntimeInstructionInstance 架构支持](#runtimeinstructioninstance-架构支持)
- [变量系统最佳实践](#变量系统最佳实践)
- [Phase 0B 经验总结](#关键技术要点)
- [测试规范](#测试规范)
- [变量系统设计文档](../../system_docs/architecture/variable_system_design.md)

---

**文档维护**: Fuse 开发团队
**最后更新**: 2026-06-17
**重要更新**: 添加 CompletionSignalTiming、ExecutionMode、cancel()、超时管理文档
