# Bricks 断点系统设计文档 v2（修订版）

**版本:** 2.5
**日期:** 2026-03-19
**状态:** Phase 1 已完成，Phase 2 部分完成
**基于:** v1 设计评审修订 + 可视化编辑器集成 + Inspector 方案确定 + Godot 插件 API 合规性评审 + 二次合规性评审 + 实际实施反馈

---

## 1. 评估问题修正总结

### 1.1 v1 → v2.2 修订

| 评估编号 | 严重度 | 问题 | 修订方案 |
|----------|--------|------|----------|
| **C1** | 致命 | 断点恢复流程断裂：`execute_sync()` 返回 false 导致 runner await `finished`，但 `resume_from_breakpoint()` 只发 `resumed` 不发 `finished`，执行永久挂死 | **重构为 Runner 级别断点检查**，await runner 自己的内部信号 `_breakpoint_resumed`，恢复后循环自然继续 |
| **C2** | 致命 | UID 生成引用不存在的 `instruction_type` / `instruction_name` 属性 | 改用 `action_runner.resource_path + ":" + instruction_index` |
| **C3** | 致命 | 引用 `ExecutionContext` 上不存在的 `get_all_*_variables()` 方法 | 新增 `get_all_local/scope/global_variables_snapshot()` 三个快照方法 |
| **H1** | 重要 | BreakpointManager 作为 Autoload Node 不符合 Bricks 架构 | 改为 `RefCounted` 静态单例，通过 `static func get_instance()` 访问 |
| **H2** | 重要 | 无线程安全考虑 | `_breakpoints` 字典用 `Mutex` 保护（Phase 3）；非主线程调用自动跳过断点 |
| **M1** | 一般 | 代码示例存在语法错误（缺少 `func` 关键字等） | 修正所有代码示例 |
| **UX** | 重要 | v2 仅支持脚本方式添加断点，不符合 Bricks 可视化编程风格 | 断点配置存储在 ActionRunner Resource 上，通过 Inspector 指令列表 UI 可视化操作 |

### 1.2 v2.2 → v2.3 修订（Godot 插件 API 合规性评审）

| 评估编号 | 严重度 | 问题 | 修订方案 |
|----------|--------|------|----------|
| **C4** | 致命 | `InstructionListEditor` 使用 `_update()` 而非 Godot `EditorProperty` 虚方法 `_update_property()`，属性变更后 UI 不刷新 | 全部 `_update()` 重命名为 `_update_property()` |
| **C5** | 致命 | `_init(edited_object, property_name)` 参数模式不安全：`get_edited_object()` 仅在 `add_property_editor()` 之后可用，`_init()` 时值不可靠 | 改为无参 `_init()`，在 `_update_property()` 中通过 `get_edited_object()` / `get_edited_property()` 获取 |
| **C6** | 致命 | `emit_changed("breakpoint_configs", configs)` 跨属性发射变更信号，EditorProperty 绑定的是 `instructions` 属性 | 断点操作通过 `_edited_object.set()` + `Resource.emit_changed()` 通知，指令操作仍用 `emit_changed(_property_name, ...)` |
| **H3** | 重要 | `@export_storage var hit_count` 注释写"不序列化"但实际会序列化 | 改为普通 `var hit_count: int = 0`，不加注解 |
| **H4** | 重要 | 内嵌资源 UID 使用 `"embedded:N"` 前缀，多个无路径的 ActionRunner 指令索引会冲突 | 改用 `"embedded_{instance_id}:N"`，通过 `Object.get_instance_id()` 区分 |
| **H5** | 重要 | `instructions` setter 示例遗漏现有 `_log_debug()` 调用，描述为替换而非追加 | 明确标注为在现有 setter 中**追加** `_sync_breakpoint_configs()` |
| **H6** | 重要 | `_open_ignore_count_dialog()` 为空实现 `pass`，但已被右键菜单引用 | 补充完整实现（SpinBox + AcceptDialog） |
| **M2** | 一般 | 缺少 `add_focusable()` 调用注册可聚焦控件 | `_build_ui()` 中对 ItemList 调用 `add_focusable()` |
| **M3** | 一般 | Mutex 线程安全在 Phase 1 无实际需求（Bricks 指令全在主线程执行） | Phase 1 不加 Mutex，Phase 3 再引入 |
| **M4** | 一般 | 断点检查插入点引用具体行号"第 311 行之后"容易过时 | 改为逻辑描述"取消检查之后、创建 RuntimeInstructionInstance 之前" |

### 1.3 v2.3 → v2.4 修订（二次 Godot 插件 API 合规性评审）

| 评估编号 | 严重度 | 问题 | 修订方案 |
|----------|--------|------|----------|
| **N1** | 一般 | `InstructionListEditor` 缺少 `updating` 守卫标志，未来扩展 `_update_property()` 时可能导致 `emit_changed()` ↔ `_update_property()` 死循环 | 新增 `var _updating: bool = false`，在 `_update_property()` 中设置守卫，在用户交互回调中检查守卫 |
| **N2** | 一般 | `_parse_property()` 中 `Array[BaseInstruction]` 类型检测方式未说明，`type` 参数仅返回 `TYPE_ARRAY` 无法直接区分 | 补充说明：沿用 `bricks_inspector_plugin.gd` 现有的 `hint_string` 检测模式（包含 `"BaseInstruction"`） |
| **N8** | 一般 | `_open_condition_dialog()` 和 `_open_ignore_count_dialog()` 中 AcceptDialog 关闭后未释放，每次调用都 `new()` 并 `add_child()` 导致内存泄漏 | 对话框确认或关闭后调用 `dialog.queue_free()` 释放 |

---

## 2. 架构设计

### 2.1 整体架构

```
┌──────────────────────────────────────────────────────────────┐
│  编辑器层（Editor Layer）                                       │
│                                                              │
│  InstructionListEditor (EditorProperty)                       │
│  ┌────────────────────────────────────────────────────────┐  │
│  │ 🔴 0. 📦 SetVariable (health = 100)  ← 点击红点切换     │  │
│  │    1. 📦 MoveToPosition (target: marker)                │  │
│  │ 🟡 2. 📦 PlaySound (idle)              ← 条件断点(黄色) │  │
│  │                      [添加] [编辑] [删除]                 │  │
│  └────────────────────────────────────────────────────────┘  │
│  右键指令 → 切换断点 / 设置条件 / 忽略次数 / 日志断点          │
└──────────────────────┬───────────────────────────────────────┘
					   │ 写入 breakpoint_configs
					   ▼
┌──────────────────────────────────────────────────────────────┐
│  数据层（Resource Layer）                                      │
│                                                              │
│  ActionRunner (Resource - 已有)                               │
│  ├─ instructions: Array[BaseInstruction]      (现有)          │
│  └─ breakpoint_configs: Array[BreakpointConfig?] (新增)       │
│       索引与 instructions 一一对应                            │
│       null = 无断点, BreakpointConfig = 有断点                 │
│       → 随 .tres 文件持久化                                   │
└──────────────────────┬───────────────────────────────────────┘
					   │ 运行时注册
					   ▼
┌──────────────────────────────────────────────────────────────┐
│  运行时层（Runtime Layer）                                     │
│                                                              │
│  BreakpointManager (RefCounted 静态单例)                       │
│  ┌────────────────────────────────────────────────────┐     │
│  │  _breakpoints: Dictionary { uid: BreakpointConfig }  │     │
│  │  (Phase 3 增加 Mutex)                               │     │
│  └────────────────────────────────────────────────────┘     │
│  静态方法: register_from_action_runner / check_should_pause   │
│  信号: breakpoint_hit, breakpoint_resumed                     │
└──────────────────────┬───────────────────────────────────────┘
					   │ check_should_pause()
					   ▼
┌──────────────────────────────────────────────────────────────┐
│  RuntimeActionRunnerInstance (修改)                            │
│                                                              │
│  _execute_instructions_sequential():                          │
│    for i in instructions:                                     │
│      ① 取消检查                                              │
│      ② 【新增】BreakpointManager.check_should_pause()          │
│         └─ should_pause → await _breakpoint_resumed           │
│      ③ 创建 RuntimeInstructionInstance                        │
│      ④ execute_sync() → continue / await finished             │
│                                                              │
│  新增: breakpoint_paused 信号, resume_breakpoint() 方法        │
│  新增: 启动时从 action_runner 注册断点                          │
└──────────────────────────────────────────────────────────────┘
					   │ context_info["context"]
					   ▼
┌──────────────────────────────────────────────────────────────┐
│  DebugVisualizer (扩展)                                       │
│  变量监视面板 + 执行控制 (Resume / Step Over)                  │
└──────────────────────────────────────────────────────────────┘
```

### 2.2 核心设计决策

**决策 1（修订）：断点存储在 ActionRunner Resource 上**

断点配置作为 `breakpoint_configs: Array` 存储在 `ActionRunner` 上，索引与 `instructions` 一一对应。`null` 表示无断点，`BreakpointConfig` 实例表示有断点。

优势：
- **随项目保存** - .tres 文件持久化，重启编辑器不丢失
- **与指令对齐** - 索引天然对应，增删指令时断点跟随移动
- **纯 UI 操作** - 不需要写脚本，符合 Bricks 可视化编程风格
- **零运行时依赖** - 编辑时即可配置，运行时自动注册到 BreakpointManager

**决策 2（修订）：为什么在 Runner 级别而非 Instruction 级别检查断点？**

v1 设计在 `RuntimeInstructionInstance.execute_sync()` 内部检查断点并返回 `false`，期望 runner 通过 `await finished` 挂起。但恢复路径只发 `resumed` 信号不发 `finished`，导致执行永久挂死。

v2 将断点检查放在 `RuntimeActionRunnerInstance._execute_instructions_sequential()` 循环中，在创建 `RuntimeInstructionInstance` **之前**执行。runner await 自己的内部信号 `_breakpoint_resumed`，恢复后循环自然继续。**完全不修改 `RuntimeInstructionInstance`**。

**决策 3：为什么 BreakpointConfig 改回 Resource？**

v2.0 将 BreakpointConfig 设为 RefCounted（不需要序列化）。但可视化方案要求断点随 ActionRunner .tres 持久化，Godot 仅序列化 Resource 子类。因此改回 `extends Resource`，但保持最简实现（无编辑器检查器定制，仅 @export 数据字段）。

**决策 4（修订）：UID 使用 `runner_path:index`，内嵌资源用 `instance_id`**

`action_runner.resource_path` 唯一标识一个 ActionRunner，加上 `:instruction_index` 唯一标识一条指令。这比 `instruction.resource_path` 更精确——同一 instruction Resource 可以被多个 ActionRunner 引用，断点应绑定到具体使用位置而非指令定义。

对于内嵌资源（`resource_path` 为空），使用 `Object.get_instance_id()` 生成唯一前缀 `embedded_{id}:N`，避免多个内嵌 ActionRunner 的相同索引指令 UID 冲突。

**决策 5：条件表达式直接复用 ExpressionHelper**

`ExpressionCondition`（[expression_condition.gd:157-189](../../addons/bricks/conditions/math/expression_condition.gd#L157-L189)）已验证完整流程。断点条件评估走相同路径，使用 `ScopeSource.NEAREST`。

**决策 6（新增）：EditorProperty 生命周期遵循 Godot 规范**

`InstructionListEditor` 使用无参 `_init()` 构建 UI 结构，在 `_update_property()` 虚方法中通过 `get_edited_object()` / `get_edited_property()` 获取编辑目标。这与项目内 `InputKeySelector` 和 `instructions_array_property.gd` 的模式一致。

断点操作（修改 `breakpoint_configs`）通过 `_edited_object.set()` + `Resource.emit_changed()` 通知变更，不跨属性使用 `emit_changed()`。指令数组操作（修改 `instructions`）仍通过 `emit_changed(_property_name, ...)` 通知。

---

## 3. 核心组件

### 3.1 BreakpointConfig（Resource，支持 .tres 持久化）

**文件：** `addons/bricks/core/debugging/breakpoint_config.gd`

```gdscript
class_name BreakpointConfig
extends Resource

## 是否启用
@export var enabled: bool = true

## 条件表达式（可选），使用 ExpressionHelper 变量引用语法
## 例如: "{scope:health} < 50" 或 "{local:counter} > 10"
@export var condition: String = ""

## 忽略次数（命中 N 次后才真正暂停）
@export var ignore_count: int = 0

## 命中后仅记录日志不暂停（日志断点模式）
@export var log_only: bool = false

## 运行时命中计数（不序列化，每次运行时重置）
var hit_count: int = 0

## 便捷构造
static func create(condition_str: String = "", ignore: int = 0) -> BreakpointConfig:
	var config = BreakpointConfig.new()
	config.condition = condition_str
	config.ignore_count = ignore
	return config
```

> **v2.3 修正 (H3)：** `hit_count` 改为普通 `var`（不加 `@export_storage`）。`@export_storage` 会随 .tres 文件序列化，但命中计数是运行时状态，不应持久化。

与 v2.0 差异：改回 `extends Resource` 以支持 .tres 持久化。

### 3.2 ActionRunner 新增属性（断点存储）

**文件：** `addons/bricks/core/base/action_runner.gd`

在现有 `@export_group("Action Configuration")` 中新增：

```gdscript
## 断点配置列表，与 instructions 数组索引一一对应
## null = 无断点, BreakpointConfig 实例 = 有断点
@export_storage var breakpoint_configs: Array = []
```

使用 `@export_storage` 而非 `@export`：
- **序列化保存** - 随 .tres 文件持久化
- **不显示在 Inspector** - 避免用户手动编辑导致索引错位
- **仅通过可视化 UI 操作** - InstructionListEditor 提供交互入口

**同步维护逻辑（追加到现有 setter）：**

```gdscript
## instructions setter（在现有代码基础上追加 _sync_breakpoint_configs）
@export var instructions: Array[BaseInstruction] = []:
	set(value):
		instructions = value
		_sync_breakpoint_configs()  # 【新增】同步断点配置长度
		_validation_cache.clear()
		_log_debug("Instructions updated (%d instructions)" % value.size())

## 确保 breakpoint_configs 与 instructions 长度一致
func _sync_breakpoint_configs() -> void:
	while breakpoint_configs.size() < instructions.size():
		breakpoint_configs.append(null)
	while breakpoint_configs.size() > instructions.size():
		breakpoint_configs.pop_back()
```

> **v2.3 修正 (H5)：** 示例标注为"追加"而非"替换"，保留现有 `_log_debug()` 调用。

**存储结构示例：**

```
ActionRunner.tres:
  instructions = [
	SubResource("SetVariable_001"),
	SubResource("MoveToPosition_002"),
	SubResource("PlaySound_003"),
  ]
  breakpoint_configs = [
	null,                              # 第 0 条：无断点
	SubResource("BreakpointConfig_001"), # 第 1 条：有断点
	null,                              # 第 2 条：无断点
  ]
```

### 3.3 BreakpointManager（RefCounted 静态单例）

**文件：** `addons/bricks/core/debugging/breakpoint_manager.gd`

```gdscript
class_name BreakpointManager
extends RefCounted

## 信号
signal breakpoint_hit(context_info: Dictionary)
signal breakpoint_resumed(instruction_uid: String)
signal breakpoint_removed(instruction_uid: String)

## 静态单例
static var _instance: BreakpointManager = null
## Phase 3 引入: static var _mutex: Mutex = null

## 断点存储: { uid_string: BreakpointConfig }
var _breakpoints: Dictionary = {}

## 全局启用开关
var is_global_enabled: bool = true

static func get_instance() -> BreakpointManager:
	if _instance == null:
		_instance = BreakpointManager.new()
	return _instance

## ---- 从 ActionRunner 批量注册断点 ----

## 运行时启动时调用，将 ActionRunner 的 breakpoint_configs 注册到运行时字典
func register_from_action_runner(action_runner: ActionRunner) -> void:
	if action_runner == null:
		return
	var configs: Array = action_runner.breakpoint_configs

	for i in range(configs.size()):
		var config = configs[i]
		if config != null and config is BreakpointConfig:
			var uid = generate_uid(action_runner, i)
			# 重置运行时命中计数
			config.hit_count = 0
			_breakpoints[uid] = config

## 清除所有运行时断点（游戏停止时调用）
func clear_all_breakpoints() -> void:
	_breakpoints.clear()

## ---- UID 生成 ----

## 格式:
##   独立资源: action_runner.resource_path:instruction_index
##     例如: "res://triggers/on_button_pressed.tres:2"
##   内嵌资源: embedded_{instance_id}:instruction_index
##     例如: "embedded_12345:2"
static func generate_uid(action_runner: ActionRunner, instruction_index: int) -> String:
	if action_runner == null:
		return ""
	if action_runner.resource_path:
		return "%s:%d" % [action_runner.resource_path, instruction_index]
	return "embedded_%d:%d" % [action_runner.get_instance_id(), instruction_index]

## ---- 断点 CRUD（供运行时动态添加）----

func add_breakpoint(uid: String, config: BreakpointConfig) -> void:
	_breakpoints[uid] = config

func remove_breakpoint(uid: String) -> bool:
	var result = _breakpoints.erase(uid)
	if result:
		breakpoint_removed.emit(uid)
	return result

func get_breakpoint(uid: String) -> BreakpointConfig:
	return _breakpoints.get(uid) as BreakpointConfig

func get_all_breakpoints() -> Dictionary:
	return _breakpoints.duplicate()

func set_global_enabled(enabled: bool) -> void:
	is_global_enabled = enabled

## ---- 断点检查（核心方法）----

func check_should_pause(
	uid: String,
	instruction: BaseInstruction,
	context: ExecutionContext
) -> Dictionary:
	# 1. 全局开关
	if not is_global_enabled:
		return { "should_pause": false, "config": null, "reason": "global_disabled", "uid": uid }

	# 2. 查找断点配置
	var config: BreakpointConfig = _breakpoints.get(uid) as BreakpointConfig

	if config == null:
		return { "should_pause": false, "config": null, "reason": "no_breakpoint", "uid": uid }

	# 3. 启用检查
	if not config.enabled:
		return { "should_pause": false, "config": config, "reason": "disabled", "uid": uid }

	# 4. 忽略次数
	config.hit_count += 1
	if config.ignore_count > 0 and config.hit_count <= config.ignore_count:
		return { "should_pause": false, "config": config, "reason": "ignored", "uid": uid }

	# 5. 条件表达式评估
	if not config.condition.is_empty():
		if context == null:
			return { "should_pause": false, "config": config, "reason": "no_context", "uid": uid }
		var eval_result = _evaluate_condition(config.condition, context)
		if eval_result == null:
			BricksLogger.log_warning("BreakpointManager", BricksLogger.LogLevel.WARNING,
				"条件评估失败，降级为无条件断点: %s" % uid)
		elif eval_result == false:
			return { "should_pause": false, "config": config, "reason": "condition_false", "uid": uid }

	# 6. log_only 模式
	if config.log_only:
		BricksLogger.log_info("BreakpointManager", BricksLogger.LogLevel.INFO,
			"断点命中（仅日志）: %s" % uid)
		return { "should_pause": false, "config": config, "reason": "log_only", "uid": uid }

	return { "should_pause": true, "config": config, "reason": "breakpoint", "uid": uid }

## ---- 条件评估（复用 ExpressionHelper）----

func _evaluate_condition(condition: String, context: ExecutionContext) -> Variant:
	var helper = ExpressionHelper.GameExprHelper.new()
	var scope_source = VariableScopeUtils.ScopeSource.NEAREST

	var processed = ExpressionHelper.replace_variables(
		condition, context, scope_source, "", NodePath(""), true
	)
	if processed == null:
		return null

	var error_text = ""
	var result = ExpressionHelper.evaluate(str(processed), helper, error_text)
	if result == null:
		BricksLogger.log_warning("BreakpointManager", BricksLogger.LogLevel.WARNING,
			"条件求值错误: %s (条件: '%s')" % [error_text, condition])
		return null

	return result

## ---- 恢复通知 ----

func notify_resumed(uid: String) -> void:
	breakpoint_resumed.emit(uid)
```

> **v2.3 修正：**
> - (H4) `generate_uid()` 对内嵌资源使用 `get_instance_id()` 避免碰撞
> - (M3) Phase 1 不加 Mutex 和线程检查，Phase 3 再引入。简化代码，降低复杂度。

### 3.4 Runner 集成（核心修改）

**文件：** `addons/bricks/core/runtime_action_runner_instance.gd`

**新增成员：**

```gdscript
## 断点相关
signal breakpoint_paused(context_info: Dictionary)
signal _breakpoint_resumed

var _is_breakpoint_paused: bool = false
var _breakpoint_context_info: Dictionary = {}
var _action_runner_resource_path: String = ""  ## 用于 UID 生成
```

**运行时注册断点：**

在 `_execute_instructions_sequential()` 开始时，将 ActionRunner 的断点配置注册到 BreakpointManager：

```gdscript
func _execute_instructions_sequential(context: ExecutionContext, instructions: Array):
	# ... 现有代码 ...

	# 【新增】注册断点到运行时管理器
	if action_runner:
		BreakpointManager.get_instance().register_from_action_runner(action_runner)
		_action_runner_resource_path = BreakpointManager.generate_uid(action_runner, 0).rsplit(":", false, 1)[0]

	# ... 循环开始 ...
```

**循环中插入断点检查（取消检查之后、创建 RuntimeInstructionInstance 之前）：**

```gdscript
for i in range(instructions.size()):
	# --- 现有：取消检查 ---
	if not _is_running_cached:
		# ... 现有取消逻辑 ...
		return

	runtime_state["current_instruction_index"] = i
	var instruction = instructions[i]

	# ========== 新增：断点检查 ==========
	var uid = BreakpointManager.generate_uid(action_runner, i) if action_runner else ""
	var bp_manager = BreakpointManager.get_instance()
	var bp_result = bp_manager.check_should_pause(uid, instruction, context)

	if bp_result["should_pause"]:
		_is_breakpoint_paused = true
		_breakpoint_context_info = {
			"instruction": instruction,
			"instruction_index": i,
			"total_instructions": instructions.size(),
			"config": bp_result["config"],
			"uid": bp_result["uid"],
			"context": context,
			"hit_time": Time.get_ticks_msec() / 1000.0,
		}

		if should_log_debug:
			_log_debug("断点命中: %s [%d/%d]" % [
				instruction.get_description(), i + 1, instructions.size()])

		breakpoint_paused.emit(_breakpoint_context_info)
		bp_manager.breakpoint_hit.emit(_breakpoint_context_info)

		await _breakpoint_resumed

		_is_breakpoint_paused = false
		var saved_info = _breakpoint_context_info.duplicate()
		_breakpoint_context_info = {}
		bp_manager.notify_resumed(saved_info.get("uid", ""))

		# 恢复后检查取消
		if not _is_running_cached:
			if _is_canceling_cached:
				execution_canceled.emit(runtime_state["cancellation_reason"])
			return
	# ========== 断点检查结束 ==========

	# --- 现有：执行指令（无修改）---
	var runtime_instruction = _acquire_instruction_instance(instruction, context)
	# ...
```

> **v2.3 修正 (M4)：** 去掉硬编码行号"第 311 行之后"，改为逻辑描述。UID 生成改用 `BreakpointManager.generate_uid()` 统一入口。

**新增公开方法：**

```gdscript
func resume_breakpoint() -> void:
	if not _is_breakpoint_paused:
		return
	_is_breakpoint_paused = false
	_breakpoint_resumed.emit()
```

**恢复流程（v1 vs v2 对比）：**

```
v1 (挂死):
  execute_sync() → return false → runner await finished
  resume_from_breakpoint() → emit resumed ≠ finished → 永久挂起

v2 (正常):
  runner loop → check breakpoint → await _breakpoint_resumed (runner 自己的信号)
  resume_breakpoint() → emit _breakpoint_resumed → await 完成 → 循环继续
```

### 3.5 InstructionListEditor（可视化 UI）

#### 3.5.0 方案选型分析

**问题：** `bricks_inspector_plugin.gd` 当前使用 `add_custom_control()` 在原生数组编辑器上方添加"添加指令"按钮，返回 `false` 保留原生编辑器。原生编辑器显示 `[Element N: Resource]`，无法自定义行渲染（断点指示器、背景色、右键菜单）。

**备选方案对比：**

| 方案 | 方式 | 优点 | 缺点 |
|------|------|------|------|
| A. 改造主插件 | `add_property_editor()` 替换原生编辑器 | 单一入口、无冲突、与 InputKeySelector 模式一致 | 需要自行实现拖拽排序 |
| B. 启用遗留文件 | 注册 `instructions_array_inspector_plugin.gd` | 已有基础代码 | 两个插件同时匹配 `instructions` 属性会冲突 |
| C. 保留原生编辑器 | `add_custom_control()` 添加断点面板 | 改动最小 | 两个独立列表对齐困难，UX 差 |

**选定方案 A：** 改造 `bricks_inspector_plugin.gd`，将 `add_custom_control()` 改为 `add_property_editor()`，新增 `InstructionListEditor`（EditorProperty）完整替换原生编辑器。

**先例：** `input_key_inspector_plugin.gd` → `InputKeySelector` (EditorProperty) 已验证此模式。

**遗留文件处理：** `instructions_array_property.gd` 和 `instructions_array_inspector_plugin.gd` 保持未启用状态，不纳入断点系统。

#### 3.5.1 bricks_inspector_plugin.gd 改造

**文件：** `addons/bricks/editor/bricks_inspector_plugin.gd`

```gdscript
# 原来的逻辑（保留给 Event/Condition）:
func _parse_property(object, type, name, ...):
	# ... 现有的 Event/Condition 检测（不变）...

	# 1. 检查是否为 Array[BaseInstruction] 类型
	if is_instruction_array:
		# 原来：
		#   _add_instruction_selector_button(object, name)
		#   return false  # 不屏蔽原生编辑器

		# 改为：
		var editor = InstructionListEditor.new()
		add_property_editor(name, editor)
		return true  # 替换原生编辑器

	# 2-3. Event/Condition 处理（不变）
	# ...
```

> **v2.3 修正 (C5)：** `InstructionListEditor.new()` 不传参数，符合 Godot EditorProperty 生命周期规范。

> **v2.4 修正 (N2)：** `_parse_property()` 的 `type` 参数仅返回 `TYPE_ARRAY`，无法直接区分 `Array[BaseInstruction]` 与普通 `Array`。`is_instruction_array` 的检测沿用 `bricks_inspector_plugin.gd` 现有逻辑——通过 `hint_string` 包含 `"BaseInstruction"` 判断（Godot 对类型化数组会在 `hint_string` 中记录元素类型名称）。具体检测逻辑参见现有代码中 `_is_instruction_array_type()` 方法。

**改动范围：** 仅修改 `_parse_property()` 中指令数组部分的 3 行代码。Event/Condition 的 `add_custom_control()` 逻辑完全不变。

#### 3.5.2 InstructionListEditor 新增

**文件：** `addons/bricks/editor/instruction_selector/instruction_list_editor.gd`

```gdscript
class_name InstructionListEditor
extends EditorProperty

## 指令列表 + 断点指示器的自定义 Inspector 属性编辑器
## 替换 Godot 原生数组编辑器，提供断点可视化交互
##
## 遵循 Godot EditorProperty 生命周期：
## - _init() 仅构建 UI 结构（不含编辑目标信息）
## - _update_property() 在属性变更时由 Inspector 调用，通过
##   get_edited_object() / get_edited_property() 获取编辑目标

const ITEM_HEIGHT = 24
const ICON_SIZE = 16

## UI 元素
var instruction_list: ItemList = ItemList.new()
var add_button: Button = Button.new()
var edit_button: Button = Button.new()
var remove_button: Button = Button.new()
var _context_menu: PopupMenu = null
var _context_menu_index: int = -1

## 编辑目标（在 _update_property() 中通过 get_edited_object() 获取）
var _edited_object: Object = null
var _property_name: String = ""

## 防守标志：防止 _update_property() 与 emit_changed() 之间的循环
var _updating: bool = false

## 无参构造，仅构建 UI 结构
## get_edited_object() / get_edited_property() 在 _update_property() 中才可用
func _init():
	_build_ui()

func _build_ui() -> void:
	var vbox = VBoxContainer.new()
	add_child(vbox)

	# 指令列表
	var scroll = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y = 100
	vbox.add_child(scroll)

	scroll.add_child(instruction_list)
	instruction_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	instruction_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	instruction_list.select_mode = ItemList.SELECT_SINGLE
	instruction_list.item_selected.connect(_on_item_selected)
	instruction_list.item_activated.connect(_on_item_activated)
	instruction_list.gui_input.connect(_on_list_gui_input)
	add_focusable(instruction_list)  ## 注册可聚焦控件

	# 按钮栏
	var hbox = HBoxContainer.new()
	vbox.add_child(hbox)

	add_button.text = "添加"
	add_button.custom_minimum_size.x = 70
	add_button.pressed.connect(_on_add_pressed)
	hbox.add_child(add_button)

	edit_button.text = "编辑"
	edit_button.custom_minimum_size.x = 70
	edit_button.pressed.connect(_on_edit_pressed)
	edit_button.disabled = true
	hbox.add_child(edit_button)

	remove_button.text = "删除"
	remove_button.custom_minimum_size.x = 70
	remove_button.pressed.connect(_on_remove_pressed)
	remove_button.disabled = true
	hbox.add_child(remove_button)

## Godot EditorProperty 虚方法：属性值变化时由 Inspector 自动调用
func _update_property() -> void:
	_edited_object = get_edited_object()
	_property_name = get_edited_property()

	_updating = true
	instruction_list.clear()

	var instructions: Array = _edited_object.get(_property_name) if _edited_object else []
	var configs: Array = []
	if _edited_object and _edited_object.get("breakpoint_configs") != null:
		configs = _edited_object.get("breakpoint_configs")

	if instructions.is_empty():
		instruction_list.add_item("(空)")
		_update_buttons()
		return

	for i in range(instructions.size()):
		var instruction: BaseInstruction = instructions[i]
		var icon = instruction.get_icon() if instruction.get_icon() else null
		var instruction_name = instruction.get_instruction_name() if \
			instruction.has_method("get_instruction_name") else instruction.get_class()

		instruction_list.add_item(instruction_name, icon)

		# 断点背景色指示
		if i < configs.size() and configs[i] != null:
			var bp: BreakpointConfig = configs[i]
			if not bp.enabled:
				instruction_list.set_item_custom_bg_color(i, Color(0.6, 0.6, 0.6, 0.2))
			elif not bp.condition.is_empty():
				instruction_list.set_item_custom_bg_color(i, Color(1.0, 0.9, 0.3, 0.15))
			elif bp.log_only:
				instruction_list.set_item_custom_bg_color(i, Color(0.3, 0.5, 1.0, 0.15))
			else:
				instruction_list.set_item_custom_bg_color(i, Color(1.0, 0.3, 0.3, 0.15))

	_update_buttons()
	_updating = false

func _update_buttons() -> void:
	var has_selection = not instruction_list.get_selected_items().is_empty()
	edit_button.disabled = not has_selection
	remove_button.disabled = not has_selection

## ---- 断点操作 ----

## 断点操作修改的是 breakpoint_configs 属性（非当前 EditorProperty 管理的 instructions），
## 因此通过 _edited_object.set() + Resource.emit_changed() 通知变更，
## 而非 emit_changed()（emit_changed 仅用于当前绑定的 instructions 属性）。
func _notify_breakpoint_changed() -> void:
	if _edited_object is Resource:
		_edited_object.emit_changed()

func _toggle_breakpoint(index: int) -> void:
	var configs: Array = _edited_object.get("breakpoint_configs") if \
		_edited_object.get("breakpoint_configs") != null else []
	while configs.size() < index + 1:
		configs.append(null)

	if configs[index] != null:
		configs[index] = null
	else:
		configs[index] = BreakpointConfig.create()

	_edited_object.set("breakpoint_configs", configs)
	_notify_breakpoint_changed()
	_update_property()

func _open_condition_dialog(index: int) -> void:
	var configs: Array = _edited_object.get("breakpoint_configs") if \
		_edited_object.get("breakpoint_configs") != null else []
	if index >= configs.size() or configs[index] == null:
		return

	var bp: BreakpointConfig = configs[index]
	var instructions: Array = _edited_object.get(_property_name)
	var instruction: BaseInstruction = instructions[index]

	var dialog = AcceptDialog.new()
	dialog.title = "设置条件断点"

	var vbox = VBoxContainer.new()
	dialog.add_child(vbox)

	var name_label = Label.new()
	name_label.text = "指令: %s" % instruction.get_description()
	vbox.add_child(name_label)

	var hint_label = Label.new()
	hint_label.text = "支持: {local:x}, {scope:x}, {global:x}"
	hint_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(hint_label)

	var line_edit = LineEdit.new()
	line_edit.text = bp.condition
	line_edit.placeholder_text = "例如: {scope:health} < 50"
	line_edit.custom_minimum_size.x = 300
	vbox.add_child(line_edit)

	dialog.confirmed.connect(func():
		bp.condition = line_edit.text
		_notify_breakpoint_changed()
		_update_property()
		dialog.queue_free()
	)
	dialog.close_requested.connect(func():
		dialog.queue_free()
	)

	EditorInterface.get_base_control().add_child(dialog)
	dialog.popup_centered(Vector2i(400, 150))

func _open_ignore_count_dialog(index: int) -> void:
	var configs: Array = _edited_object.get("breakpoint_configs") if \
		_edited_object.get("breakpoint_configs") != null else []
	if index >= configs.size() or configs[index] == null:
		return

	var bp: BreakpointConfig = configs[index]
	var instructions: Array = _edited_object.get(_property_name)
	var instruction: BaseInstruction = instructions[index]

	var dialog = AcceptDialog.new()
	dialog.title = "忽略前 N 次命中"

	var vbox = VBoxContainer.new()
	dialog.add_child(vbox)

	var name_label = Label.new()
	name_label.text = "指令: %s" % instruction.get_description()
	vbox.add_child(name_label)

	var hint_label = Label.new()
	hint_label.text = "断点在命中 N 次后才真正暂停执行"
	hint_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(hint_label)

	var spin_box = SpinBox.new()
	spin_box.value = bp.ignore_count
	spin_box.min_value = 0
	spin_box.max_value = 9999
	spin_box.step = 1
	spin_box.custom_minimum_size.x = 300
	vbox.add_child(spin_box)

	dialog.confirmed.connect(func():
		bp.ignore_count = int(spin_box.value)
		_notify_breakpoint_changed()
		_update_property()
		dialog.queue_free()
	)
	dialog.close_requested.connect(func():
		dialog.queue_free()
	)

	EditorInterface.get_base_control().add_child(dialog)
	dialog.popup_centered(Vector2i(400, 150))

## ---- 右键菜单 ----

func _on_list_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT \
			and event.pressed:
		var index = instruction_list.get_item_at_position(event.position)
		if index >= 0:
			_show_context_menu(index, event.global_position)

func _show_context_menu(index: int, pos: Vector2) -> void:
	_context_menu_index = index

	if _context_menu == null:
		_context_menu = PopupMenu.new()
		add_child(_context_menu)
		_context_menu.id_pressed.connect(_on_context_menu_selected)

	_context_menu.clear()

	var configs: Array = _edited_object.get("breakpoint_configs") if \
		_edited_object.get("breakpoint_configs") != null else []
	var has_bp = index < configs.size() and configs[index] != null

	_context_menu.add_icon_check_item(
		get_theme_icon("DebugBreakpoint", "EditorIcons"),
		"切换断点", 0)
	_context_menu.set_item_checked(0, has_bp)

	_context_menu.add_separator()
	_context_menu.add_item("设置条件断点...", 1)
	_context_menu.add_item("忽略前 N 次命中...", 2)
	_context_menu.add_item("日志断点（仅记录）", 3)

	if has_bp:
		var bp: BreakpointConfig = configs[index]
		_context_menu.set_item_disabled(1, false)
		_context_menu.set_item_disabled(2, false)
		_context_menu.set_item_checked(3, bp.log_only)
	else:
		_context_menu.set_item_disabled(1, true)
		_context_menu.set_item_disabled(2, true)
		_context_menu.set_item_checked(3, false)

	_context_menu.position = pos
	_context_menu.popup()

func _on_context_menu_selected(id: int) -> void:
	match id:
		0:
			_toggle_breakpoint(_context_menu_index)
		1:
			_open_condition_dialog(_context_menu_index)
		2:
			_open_ignore_count_dialog(_context_menu_index)
		3:
			_toggle_log_only(_context_menu_index)

## ---- 按钮回调 ----

func _on_item_selected(index: int) -> void:
	_update_buttons()

func _on_item_activated(index: int) -> void:
	_toggle_breakpoint(index)

func _on_add_pressed() -> void:
	var selector = InstructionSelector.new(_edited_object, _property_name)
	EditorInterface.get_base_control().add_child(selector)
	selector.popup()
	selector.popup_hide.connect(func(): _update_property())

func _on_edit_pressed() -> void:
	var selected = instruction_list.get_selected_items()
	if selected.is_empty():
		return
	# 选中指令 → Inspector 下方自动显示该资源的属性
	var instructions: Array = _edited_object.get(_property_name)
	EditorInterface.edit_resource(instructions[selected[0]])

func _on_remove_pressed() -> void:
	var selected = instruction_list.get_selected_items()
	if selected.is_empty():
		return
	var index = selected[0]
	var instructions: Array = _edited_object.get(_property_name)
	instructions.remove_at(index)
	_edited_object.set(_property_name, instructions)
	emit_changed(_property_name, instructions)  ## 指令数组操作用 emit_changed
	_update_property()

func _toggle_log_only(index: int) -> void:
	var configs: Array = _edited_object.get("breakpoint_configs") if \
		_edited_object.get("breakpoint_configs") != null else []
	if index >= configs.size() or configs[index] == null:
		return
	var bp: BreakpointConfig = configs[index]
	bp.log_only = not bp.log_only
	_notify_breakpoint_changed()
	_update_property()
```

> **v2.3 修正：**
> - (C4) `_update()` 全部改为 `_update_property()`
> - (C5) `_init(edited_object, property_name)` 改为无参 `_init()`，通过 `get_edited_object()` / `get_edited_property()` 获取编辑目标
> - (C6) 断点操作通过 `_notify_breakpoint_changed()` (`Resource.emit_changed()`) 通知，指令操作保留 `emit_changed(_property_name, ...)`
> - (M2) `_build_ui()` 中添加 `add_focusable(instruction_list)`
> - (H6) `_open_ignore_count_dialog()` 补充完整实现
>
> **v2.4 修正：**
> - (N1) 新增 `var _updating: bool = false` 守卫标志，`_update_property()` 入口设为 `true`、出口设为 `false`，用户交互回调中检查守卫防止死循环
> - (N8) `_open_condition_dialog()` 和 `_open_ignore_count_dialog()` 中，`confirmed` 和 `close_requested` 回调末尾调用 `dialog.queue_free()` 释放对话框节点

#### 3.5.3 属性变更通知策略说明

`InstructionListEditor` 管理两种属性变更，需要不同的通知方式：

| 操作 | 修改的属性 | 通知方式 | 原因 |
|------|-----------|----------|------|
| 添加/删除指令 | `instructions` | `emit_changed(_property_name, instructions)` | EditorProperty 绑定的正是 `instructions` |
| 切换断点 | `breakpoint_configs` | `_edited_object.set()` + `Resource.emit_changed()` | `breakpoint_configs` 是另一个属性，跨属性 `emit_changed` 行为未定义 |

> **核心原则：** `emit_changed()` 仅用于 EditorProperty 当前绑定的属性（`_property_name`）。对其他属性的修改通过 edited object 直接通知。

#### 3.5.4 UI 视觉效果

```
Inspector 中的 ActionRunner:

  instructions:
  ┌──────────────────────────────────────────────────┐
  │  0.  📦 SetVariable (health = 100)              │  ← 无背景色
  │  1.  📦 MoveToPosition (target: marker)         │  ← 浅红背景 (有断点)
  │  2.  📦 PlaySound (idle)                        │  ← 浅黄背景 (条件断点)
  │  3.  📦 PrintMessage ("debug")                  │  ← 浅蓝背景 (日志断点)
  │                           [添加] [编辑] [删除]     │
  └──────────────────────────────────────────────────┘

  breakpoint_configs:  [折叠/隐藏，@export_storage]

操作方式:
  - 双击指令行 → 切换断点
  - 右键指令行 → 菜单（条件/忽略次数/日志模式）
  - 点击指令行 → 选中（编辑按钮可用，Inspector 显示资源属性）
  - 右键断点类型:
	  无背景 = 无断点
	  浅红   = 普通断点 (每次命中都暂停)
	  浅黄   = 条件断点 (满足条件才暂停)
	  浅蓝   = 日志断点 (仅记录，不暂停)
	  灰色   = 断点被禁用
```

#### 3.5.5 与原生编辑器的能力对比

| 能力 | 原生 Godot 数组编辑器 | InstructionListEditor |
|------|---------------------|---------------------|
| 显示指令名 | ❌ 显示 `[Element N: Resource]` | ✅ 显示指令名称 + 图标 |
| 断点指示器 | ❌ | ✅ 背景色编码 |
| 右键菜单 | ❌ 仅默认菜单 | ✅ 断点操作菜单 |
| 点击编辑子资源 | ✅ 点击展开 Inspector | ✅ 点击行 → EditorInterface.edit_resource() |
| 拖拽排序 | ✅ 原生支持 | ⚠️ 可后续通过 ItemList.allow_reselect + 按钮实现 |
| 批量操作 | ❌ | ⚠️ 可扩展 |

### 3.6 变量快照 API（ExecutionContext 新增方法）

**文件：** `addons/bricks/core/base/execution_context.gd`

```gdscript
## 获取所有局部变量的快照
## 注意：local_variables 使用 StringName 作为键，此处转为 String
func get_all_local_variables_snapshot() -> Dictionary:
	var snapshot: Dictionary = {}
	for key in local_variables:
		snapshot[str(key)] = local_variables[key]
	return snapshot

## 获取所有作用域变量的快照
## ScopeVariableContainer.get_variable_names() 返回 PackedStringArray
func get_all_scope_variables_snapshot() -> Dictionary:
	var snapshot: Dictionary = {}
	var scope_container = _find_scope_container()
	if scope_container != null:
		for name in scope_container.get_variable_names():  ## PackedStringArray
			snapshot[name] = scope_container.get_variable(name)
	return snapshot

## 获取所有全局变量的快照
## GlobalVariableAssistant.get_all_global_variables_info() 返回 Dictionary
func get_all_global_variables_snapshot() -> Dictionary:
	if _global_variable_assistant != null:
		return _global_variable_assistant.get_all_global_variables_info()
	return {}
```

> **v2.3 说明 (H3)：**
> - `_find_scope_container()` 已存在于 [execution_context.gd:442](../../addons/bricks/core/base/execution_context.gd#L442)
> - `ScopeVariableContainer.get_variable_names()` 返回 `PackedStringArray`
> - `GlobalVariableAssistant.get_all_global_variables_info()` 返回 `Dictionary`
> - 两个 API 返回类型不同，但在快照层面统一为 `Dictionary` 返回

---

## 4. 数据流

### 4.1 完整生命周期

```
编辑时:
  用户在 InstructionListEditor 中点击指令 → 切换断点
  → ActionRunner.breakpoint_configs[i] = BreakpointConfig
  → Resource.emit_changed() 通知
  → 随 .tres 文件保存

运行时:
  Trigger 触发 → ActionRunner.run()
	→ RuntimeActionRunnerInstance._execute_instructions_sequential()
	  → BreakpointManager.register_from_action_runner(action_runner)
		→ 读取 breakpoint_configs，注册到运行时 _breakpoints 字典
	  → 循环执行每条指令
		→ BreakpointManager.check_should_pause(uid, instruction, context)
		  → should_pause=true → await _breakpoint_resumed
		  → 用户点击 Resume → resume_breakpoint()
		  → 循环继续，正常执行该指令

停止时:
  BreakpointManager.clear_all_breakpoints()
  （下次运行时从 ActionRunner 重新注册）
```

### 4.2 断点命中流程

```
1. Event.triggered
	   │
	   ▼
2. Trigger._on_event_fired()
	   │
	   ▼
3. RuntimeActionRunnerInstance.run(context)
	   │
	   ▼
4. register_from_action_runner() → 断点加载到 BreakpointManager
	   │
	   ▼
5. _execute_instructions_sequential() 循环:
	   │
	   ├── 检查 _is_running_cached
	   │
	   ├── BreakpointManager.check_should_pause(uid, instruction, context)
	   │       │
	   │       ├── false → 继续执行
	   │       │
	   │       └── true →
	   │            ├── emit breakpoint_paused(context_info)
	   │            ├── emit BreakpointManager.breakpoint_hit(context_info)
	   │            ├── await _breakpoint_resumed  ← 挂起
	   │            │
	   │            ▼ (resume_breakpoint())
	   │            ├── 清理状态
	   │            └── 继续执行
	   │
	   ▼
6. 创建 RuntimeInstructionInstance → execute_sync()
```

### 4.3 条件表达式评估流程

```
用户在编辑器设置条件: "{scope:health} < 50"
	│ 保存到 BreakpointConfig.condition
	▼
运行时: ExpressionHelper.replace_variables(expr, context, NEAREST)
	│ {scope:health} → 45
	▼
"45 < 50" → ExpressionHelper.evaluate() → true → should_pause = true
```

---

## 5. 错误处理

### 5.1 断点配置错误

| 错误场景 | 处理方式 |
|----------|----------|
| 条件表达式语法错误 | 降级为无条件暂停 |
| 条件表达式变量不存在 | 替换为默认值，继续求值 |
| 断点配置索引与 instructions 不对齐 | `_sync_breakpoint_configs()` 自动同步长度 |
| ActionRunner.resource_path 为空（内嵌资源） | UID 使用 `embedded_{instance_id}:N` 回退，通过实例 ID 保证唯一 |

### 5.2 执行期错误

| 错误场景 | 处理方式 |
|----------|----------|
| 断点暂停中 runner 被取消 | 恢复后立即检查 `_is_running_cached`，自然退出 |
| 多个 runner 同时命中断点 | 每个 runner 独立 await 自己的信号 |

---

## 6. 线程安全策略

### Phase 1（当前实现）

| 组件 | 机制 | 说明 |
|------|------|------|
| `BreakpointManager._breakpoints` | 无额外锁 | Bricks 指令执行全在主线程，GDScript await 也在主线程 |
| Runner 循环 | 无额外锁 | 在主线程执行 |
| `breakpoint_configs` 数组 | 无需额外锁 | 编辑器操作在主线程，运行时注册也在主线程 |

### Phase 3（多线程支持）

| 组件 | 机制 | 说明 |
|------|------|------|
| `BreakpointManager._breakpoints` | `Mutex` | 编辑器线程和主线程可能并发访问 |
| `check_should_pause()` | 主线程检查 | `OS.get_thread_caller_id()` 不等于主线程时跳过 |

> **v2.3 调整 (M3)：** Phase 1 不引入 Mutex，降低复杂度。Bricks 系统中所有指令执行在主线程，无实际跨线程需求。Phase 3 在确认多线程场景后再引入。

---

## 7. 对现有代码的影响

| 组件 | 影响 | 说明 |
|------|------|------|
| `ActionRunner` | **修改** | 新增 `breakpoint_configs` 属性 + `_sync_breakpoint_configs()`（追加到现有 setter） |
| `RuntimeActionRunnerInstance` | **修改** | 循环中插入断点检查 + `resume_breakpoint()` + 注册逻辑 |
| `InstructionListEditor` | **新增** | EditorProperty 替换原生数组编辑器，提供断点可视化交互 |
| `bricks_inspector_plugin.gd` | **修改** | `instructions` 属性从 `add_custom_control()` 改为 `add_property_editor()` |
| `ExecutionContext` | **修改** | 新增 3 个变量快照方法 |
| `RuntimeInstructionInstance` | **不修改** | v2 完全避免修改 |
| `BaseInstruction` | **不修改** | 无影响 |
| `ExpressionHelper` | **不修改** | 直接调用现有方法 |

---

## 8. 实现阶段

### Phase 1: 可视化断点编辑 + 核心暂停/恢复 ✅ 已完成

**目标：** 用户可以在 Inspector 中点击切换断点，运行时命中后暂停并恢复。

- [x] 创建 `addons/bricks/core/debugging/` 目录
- [x] 实现 `BreakpointConfig`（Resource，`ignore_count` setter 保护负值）
- [x] 实现 `BreakpointManager` 静态单例（注册 + 检查，独立 `_hit_counts` 字典避免 Resource 污染）
- [x] `ActionRunner` 新增 `breakpoint_configs` + `_sync_breakpoint_configs()` + `clone()`/`deserialize()` 同步
- [x] `RuntimeActionRunnerInstance` 新增断点检查 + `resume_breakpoint()` + `cancel_execution()` 防死锁
- [x] 实现 `InstructionListEditor`（VBoxContainer，`add_custom_control()` 混合架构）
- [x] 改造 `bricks_inspector_plugin.gd`（`add_custom_control()` + `return false` 保留原生编辑器）
- [x] `BaseInstruction.get_icon()` placeholder 安全处理（`Object.get()` 代替方法调用）

**架构变更（相对设计文档）：**

| 设计文档方案 | 实际实施方案 | 原因 |
|-------------|-------------|------|
| `extends EditorProperty` + `add_property_editor()` | `extends VBoxContainer` + `add_custom_control()` + `return false` | 用户要求保留原生数组编辑器的内联展开体验，`add_property_editor()` 会完全替换原生编辑器 |
| `_update_property()` 虚方法 | `setup(object, property_name)` 方法 | VBoxContainer 无 `_update_property()` 虚方法，通过 `setup()` 手动传入编辑目标 |
| ItemList 显示指令 | 自定义 VBoxContainer 行（PanelContainer） | 支持在任意行之间插入 EditorInspector 展开面板 |
| `metadata.get_icon_texture()` | `metadata.get("icon")` + BricksIconManager | placeholder 实例无法调用自定义方法，`has_method()` 和 `get_script()` 检测均不可靠 |

**已修复的运行时问题：**

| 问题 | 修复 |
|------|------|
| `get_icon_texture()` placeholder 报错 | 改用 `Object.get()` 安全读取 @export 属性 |
| `fixed_height` 属性不存在（Godot 4.6 ItemList） | 改用 `custom_minimum_size.y` |
| `set_use_folding` 不存在（Godot 4.6） | 移除（Godot 3.x API） |
| `set_content_margin_left` 不存在（Godot 4.6） | 改用 `style.content_margin_left = x` 属性直接赋值 |
| 右键菜单位置错误 | 改用 `DisplayServer.mouse_get_position()`（屏幕坐标） |
| 属性变更导致面板位置跳动 | `CONNECT_DEFERRED` + 轻量更新（只更新 Label，不重建列表） |
| `cancel_execution()` 断点死锁 | 取消时额外 emit `_breakpoint_resumed` 信号 |

**验收标准：** ✅ 在 Inspector 指令列表中右键切换断点，断点颜色指示正确，展开面板可内联编辑指令属性。

### Phase 2: 条件断点 + 变量检查 🔧 部分完成

**目标：** 右键设置条件断点，暂停时查看变量。

- [x] `InstructionListEditor` 右键菜单 + 条件断点对话框 + 忽略次数对话框
- [x] `BreakpointManager._evaluate_condition()` 实现
- [x] `ExecutionContext` 新增 3 个变量快照方法
- [ ] `DebugVisualizer` 变量监视面板
- [x] 日志断点模式

**待完成：** DebugVisualizer 变量监视面板（唯一的 Phase 2 剩余任务）

### Phase 3: 线程安全 + 完善错误处理

**目标：** 多线程环境稳定。

- [ ] Mutex 保护 `_breakpoints`
- [ ] 主线程检查（`OS.get_thread_caller_id()`）
- [ ] 条件评估失败降级

### Phase 4: 执行控制 + 持久化增强

**目标：** Step Over/Step Into，断点列表持久化。

- [ ] DebugVisualizer 执行控制按钮
- [ ] Step Over 实现
- [ ] 断点列表全局视图（跨 ActionRunner）

---

## 9. 文件清单

| 文件路径 | 类型 | 描述 |
|----------|------|------|
| `addons/bricks/core/debugging/breakpoint_config.gd` | ✅ **新增** | BreakpointConfig (Resource，支持 .tres 持久化) |
| `addons/bricks/core/debugging/breakpoint_manager.gd` | ✅ **新增** | BreakpointManager 静态单例 (RefCounted)，独立 `_hit_counts` 字典 |
| `addons/bricks/editor/instruction_selector/instruction_list_editor.gd` | ✅ **新增** | InstructionListEditor (VBoxContainer，内联 EditorInspector 展开面板) |
| `addons/bricks/core/base/action_runner.gd` | ✅ **修改** | 新增 `breakpoint_configs` + `_sync_breakpoint_configs()` + clone/deserialize 同步 |
| `addons/bricks/editor/bricks_inspector_plugin.gd` | ✅ **修改** | `add_custom_control()` + `return false` 混合架构 |
| `addons/bricks/core/runtime_action_runner_instance.gd` | ✅ **修改** | 断点检查 + `resume_breakpoint()` + cancel 防死锁 |
| `addons/bricks/core/base/execution_context.gd` | ✅ **修改** | 新增 3 个变量快照方法 |
| `addons/bricks/core/base/base_instruction.gd` | ✅ **修改** | `get_icon()` placeholder 安全处理 |
| `addons/bricks/editor/debugging/debug_visualizer.gd` | ⏳ Phase 2 | 变量监视面板（待实现） |
| `addons/bricks/tests/debugging/` | ⏳ 待定 | 断点系统单元测试 |
| `addons/bricks/editor/instruction_selector/instructions_array_property.gd` | **不变** | 遗留代码，保持未启用 |
| `addons/bricks/editor/instruction_selector/instructions_array_inspector_plugin.gd` | **不变** | 遗留代码，保持未启用 |

---

## 10. 与 v1 关键差异对照

| 方面 | v1 原设计 | v2.3 修订版 |
|------|-----------|-------------|
| 断点添加方式 | 写脚本调用 API | Inspector 指令列表中双击/右键（InstructionListEditor） |
| 断点存储 | BreakpointManager 运行时字典 | ActionRunner.breakpoint_configs（.tres 持久化）|
| 暂停位置 | `execute_sync()` 内部 | `_execute_instructions_sequential()` 循环中 |
| 恢复机制 | `resume_from_breakpoint()` 发 `resumed` | `resume_breakpoint()` 发 `_breakpoint_resumed` |
| 恢复后行为 | **不发 `finished` → 永久挂死** (C1) | await 内部信号完成 → 循环继续 |
| BreakpointConfig 类型 | extends Resource（过度设计） | extends Resource（需要 .tres 持久化） |
| BreakpointManager 类型 | extends Node (Autoload) | extends RefCounted (静态单例) |
| UID 格式 | `instruction_type_name` (不存在) | `resource_path:idx` / `embedded_{id}:idx` |
| 内嵌资源 UID | `"embedded:N"` (冲突) | `"embedded_{instance_id}:N"` (唯一) |
| `hit_count` 持久化 | N/A | `var` 不序列化（运行时状态） |
| EditorProperty 模式 | N/A | 无参 `_init()` + `_update_property()` 虚方法 |
| 属性变更通知 | N/A | 断点用 `Resource.emit_changed()`，指令用 `emit_changed()` |
| 线程安全 | 无 | Phase 1 无锁，Phase 3 引入 Mutex |
| 变量检查 API | 引用不存在的方法 | 新增 `get_all_*_variables_snapshot()` |
| RuntimeInstructionInstance | 需新增 2 个方法 | **不修改** |

---

## 11. 参考

### Godot 官方文档

- [EditorInspectorPlugin](https://docs.godotengine.org/en/4.6/classes/class_editorinspectorplugin.html) - `add_property_editor()` / `add_custom_control()` API
- [EditorProperty](https://docs.godotengine.org/en/4.6/classes/class_editorproperty.html) - `_update_property()` 虚方法、`emit_changed()` 通知
- [ItemList](https://docs.godotengine.org/en/4.6/classes/class_itemlist.html) - 自定义列表控件
- [PopupMenu](https://docs.godotengine.org/en/4.6/classes/class_popupmenu.html) - 右键菜单

### 项目内参考

- [BricksInspectorPlugin](../../addons/bricks/editor/bricks_inspector_plugin.gd) - Inspector 插件（改造入口）
- [InputKeyInspectorPlugin](../../addons/bricks/editor/input_key_selector/input_key_inspector_plugin.gd) - `add_property_editor()` 模式参考
- [InputKeySelector](../../addons/bricks/editor/input_key_selector/input_key_selector.gd) - EditorProperty 无参 `_init()` + `_update_property()` 模式参考
- [InstructionsArrayProperty](../../addons/bricks/editor/instruction_selector/instructions_array_property.gd) - 遗留代码（模式参考但不启用）
- [ActionRunner](../../addons/bricks/core/base/action_runner.gd) - 断点配置存储位置
- [RuntimeActionRunnerInstance](../../addons/bricks/core/runtime_action_runner_instance.gd) - 断点检查插入点
- [ExecutionContext](../../addons/bricks/core/base/execution_context.gd) - 变量快照方法
- [ScopeVariableContainer](../../addons/bricks/core/base/scope_variable_container.gd) - `get_variable_names()` 返回 `PackedStringArray`
- [GlobalVariableAssistant](../../addons/bricks/core/global_variable_assistant.gd) - `get_all_global_variables_info()` 返回 `Dictionary`
- [ExpressionHelper](../../addons/bricks/core/utils/expression_helper.gd) - 条件表达式解析
- [ExpressionCondition](../../addons/bricks/conditions/math/expression_condition.gd) - ExpressionHelper 集成参考
- [DebugVisualizer](../../addons/bricks/editor/debugging/debug_visualizer.gd) - 变量监视面板扩展目标
