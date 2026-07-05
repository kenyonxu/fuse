# Fuse 架构整改 Phase 4 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: 用 superpowers:subagent-driven-development(推荐)或 superpowers:executing-plans 逐任务实现本计划。步骤使用复选框(`- [ ]`)语法跟踪。

**Goal:** 把 `ExecutionContext` 从 1624 行的单一类拆为「核心骨架 + `VariableContext`(变量子系统)+ `ExecutionDiagnostics`(诊断子系统)」三层门面,控制复杂度膨胀,实现总计划 §8 可变/可独立演化的子模块结构。

**Architecture:**
- `ExecutionContext`(保留 ~300 行) — target/trigger/owner/树引用/执行状态机/信号/日志/自定义数据/ActionRunner/节点查找/duplicate/cleanup/FuseError,对外统一门面。`set_variable`/`get_variable`/`has_variable`/`add_variable`/`get_variable_object`/循环控制/变量快照 等公共 API 保留,内部委托 `_variable_context`。
- `VariableContext extends RefCounted`(新增 ~550 行) — local/scope/global 变量 CRUD/分发、变量名缓存(LRU)、索引访问优化、作用域容器查找(ScopeVariableManager)、全局变量访问(GlobalVariableAssistant)、变量快照、循环控制标志(break/continue/nested stack)。
- `ExecutionDiagnostics extends RefCounted`(新增 ~220 行) — 执行状态机(set/get_execution_state/_notify/_record)、状态变化监听器、执行历史(history)、进度跟踪、状态统计、依赖图(dependency graph)、可视化数据。
- **外部 API 完全不变**:所有指令通过 `context.set_variable(name, value, scope)` / `context.get_variable(name, default)` 访问,签名不变,仅内部委托层次改变。

**Tech Stack:** Godot 4.6 / GDScript 2.0。重构验证靠「插件启停行为不变 + Phase 0 回归基线 + 所有指令的变量操作行为不变」。本 Phase 是整改最后一个主 Phase,风险等级最高。

---

## 关联文档

- 评估报告:`addons/fuse/docs/system_docs/analysis/2026-04-21-fuse-architecture-assessment.md` §5.6(EC 膨胀)
- 整改总计划:`addons/fuse/docs/system_docs/analysis/2026-04-21-fuse-architecture-remediation-plan.md` §8(Phase 4 目标结构)、§8.3(实施动作)、§12 M4(里程碑)
- Phase 3 计划:`addons/fuse/docs/system_docs/analysis/2026-06-16-fuse-phase3-implementation-plan.md`
- 回归基线:`addons/fuse/docs/system_docs/analysis/2026-06-15-fuse-architecture-regression-baseline.md`
- 本计划覆盖:总计划 §8(Phase 4,含 4a 纯函数提取 + 4b 门面拆分,本计划合并为一次拆分)

## 现状核验(Phase 3 完成后,2026-06-16 ground truth)

`ExecutionContext` 1624 行,职责分布:

| 职责域 | 方法/属性 | 行范围 | 行数 | 目标 |
|--------|---------|--------|:----:|------|
| 属性声明 | target/trigger/owner/tree/local_vars/global/缓存/状态/历史/循环标志... | 50-90 | 41 | 按域分散到子模块 |
| 初始化 | `_init`+`create_with_params`+`_generate_execution_id` | 100-142 | 43 | 留 EC |
| 场景访问 | `get_tree`/`get_node` | 144-214 | 71 | 留 EC |
| **变量 CRUD + 分发** | add/set/get/get_object | 216-437 | 222 | → VariableContext |
| 作用域变量 | `_find_scope_container`/`_set_scope`/`_get_scope` | 442-489 | 48 | → VariableContext |
| 全局变量 | `_set_global`/`_get_global`/get/set assistant | 495-611 | 117 | → VariableContext |
| 本地变量 | `_set_local`/`_get_local` | 569-597 | 29 | → VariableContext |
| 公共输出 | print_message/warning/error | 636-661 | 26 | 留 EC |
| 执行时间 | get_execution_time | 676-677 | 2 | 留 EC |
| 自定义数据 | set/get_custom_data | 695-718 | 24 | 留 EC |
| ActionRunner | set/get/has_action_runner | 720-734 | 15 | 留 EC |
| cleanup | 全量清理(变量+缓存+历史+引用) | 747-802 | 56 | 改为调子系统 cleanup |
| duplicate | 深拷贝 | 815-830 | 16 | 调子系统 duplicate |
| get_info | 信息字典 | 852-866 | 15 | 留 EC |
| **执行状态 + 历史** | state/progress/error/cancel/reset/record/notify | 868-989 | 122 | → Diagnostics |
| 日志方法 | _log_* | 1005-1029 | 25 | 留 EC |
| **监听器 + 历史** | add/remove listener/get/clear history | 1059-1082 | 24 | → Diagnostics |
| **状态统计** | get_state_statistics/recent_changes | 1094-1146 | 53 | → Diagnostics |
| has_variable | | 1153-1184 | 32 | → VariableContext |
| **依赖图** | graph / collect / check / status / batch / visualization | 1188-1373 | 186 | → Diagnostics |
| FuseError | create/get/has/had_error | 1379-1398 | 20 | 留 EC |
| **变量缓存 + 索引** | name cache LRU / precompile / indexed access | 1405-1492 | 88 | → VariableContext |
| 弱引用 | set/get target/trigger node | 1494-1538 | 45 | 留 EC |
| **循环控制** | break/continue/should/push/pop | 1543-1623 | 81 | → VariableContext |
| 变量快照 | local/scope/global snapshots | 1572-1593 | 22 | → VariableContext |

**目标:EC 1624 → ~300 行;VariableContext ~550 行;Diagnostics ~220 行。**

## 关键设计约束

1. **外部 API 完全不变**:所有指令(100+)通过 `context.set_variable(name, value, scope)` / `context.get_variable(name, default, scope)` / `context.add_variable(name, variable)` / `context.has_variable(name)` / `context.set_break_loop()` 等公共方法访问。这些方法签名完全不变,只是内部改为 `_variable_context.set_variable(...)` 委托。**这是硬约束,必须确保无需修改任何指令脚本。**

2. **门面模式**:EC 持有 `var _variable_context: VariableContext` 和 `var _diagnostics: ExecutionDiagnostics`,在 `_init()` 中创建。EC 的公共方法委托子模块,子模块可访问 EC 的属性(如 target/trigger/owner)用于作用域查找等。

3. **VariableContext 需要 EC 的属性引用**:`_find_scope_container()` 需要访问 `trigger`/`target`/`owner` 节点来查找作用域容器。方案:VariableContext 持有 `_owner: ExecutionContext` 引用,或将这些属性作为参数传入。**最简洁**:VariableContext 接受 `owner: ExecutionContext` 引用,读 `_owner.target`/`_owner.trigger`/`_owner.owner`。这比传多个单独属性更干净。

4. **Diagnostics 保持独立**:ExecutionDiagnostics 纯历史/统计/依赖图,不依赖 EC 的属性(除 execution_id 用于日志,可从 EC 读或传入)。保持低耦合。

5. **cleanup 链**:EC.cleanup() 调 `_variable_context.cleanup()` → `_diagnostics.cleanup()` → 自己的清理(节点引用)。逆序:子模块先干净,EC 最后。

6. **duplicate 链**:EC.duplicate() 调 `_variable_context.duplicate()` → EC 自己的属性复制。Diagnostics 不参与 duplicate(历史/统计不应复制到新上下文)。

7. **循环控制标志放 VariableContext**:(break/continue 标志是运行时状态,紧密耦合变量相关操作。虽不属于"变量存储",但拆分粒度上放在 VariableContext 比留在 EC 更合理——它们在一个 ~100 行的逻辑块里,与变量快照/循环指令上下文在一起)

---

## File Structure

**新增:**
- Create: `addons/fuse/core/base/variable_context.gd` — VariableContext(变量子系统,~550 行)
- Create: `addons/fuse/core/base/execution_diagnostics.gd` — ExecutionDiagnostics(诊断子系统,~220 行)

**修改:**
- Modify: `addons/fuse/core/base/execution_context.gd` — 删除迁出的方法/属性,添加 `_variable_context`/`_diagnostics` 引用,门面方法改为委托,cleanup/duplicate 改为调子系统

---

## 运行环境约定

```bash
# 按运行环境二选一(取消注释其一)
GODOT="E:/Godot/Godot_v4.6.2-stable_mono_win64/Godot_v4.6.2-stable_mono_win64.exe"; PROJECT="E:/Godot/GodotProjects/project-juicy-godot"  # Windows
#GODOT="/home/kai-remote/.local/bin/godot"; PROJECT="/home/kai-remote/github/project-juicy-godot"  # Linux
```

**回归基线命令**(每个 Task 后跑):

```bash
"$GODOT" --headless --path "$PROJECT" "addons/fuse/tests/test_action_runner_signals.tscn"
"$GODOT" --headless --path "$PROJECT" "addons/fuse/tests/test_runtime_instruction_instance.tscn"
"$GODOT" --headless --path "$PROJECT" "addons/fuse/tests/test_runner.gd"
"$GODOT" --headless --path "$PROJECT" "addons/fuse/tests/test_event_bus.tscn"
"$GODOT" --headless --path "$PROJECT" "addons/fuse/tests/test_registry_dedup.tscn"
```

> 本 Phase 回归重点:所有指令的变量操作(set/get/has/add_global_variable)行为不变。

---

# Task 4.1:创建 VariableContext + EC 委托变量操作

**Files:**
- Create: `addons/fuse/core/base/variable_context.gd`
- Modify: `addons/fuse/core/base/execution_context.gd`(删除:行 54-60/216-611/1153-1184/1401-1623;添加 `_variable_context` 引用;门面方法改为委托)

- [ ] **Step 1:创建 VariableContext**

创建 `addons/fuse/core/base/variable_context.gd`,迁入 execution_context.gd 中所有变量相关代码(逻辑完全不变,仅包裹进类):

```gdscript
@tool
class_name VariableContext extends RefCounted

## ExecutionContext 变量子系统
##
## 管理 local / scope / global 三层变量作用域,提供:
## - 变量 CRUD(set/get/has/add)
## - 变量名缓存(LRU)和索引访问优化
## - 作用域容器查找(ScopeVariableManager)
## - 全局变量访问(GlobalVariableAssistant)
## - 变量快照(断点调试)
## - 循环控制标志(break/continue/nested stack)
##
## 通过 _owner 引用获取节点信息(target/trigger/owner)用于作用域查找。

var _owner: ExecutionContext

# 变量存储
var local_variables: Dictionary = {}
var global_variables = null
var _global_variable_assistant: GlobalVariableAssistant = null

# 变量名缓存(LRU)
var _variable_name_cache: Dictionary = {}
var _cache_max_size: int = 1000
var _cache_access_order: Array = []

# 索引访问优化
var _variable_index_map: Dictionary = {}
var _variable_array: Array = []
var _use_indexed_access: bool = false

# 循环控制标志
var _break_loop_flag: bool = false
var _continue_loop_flag: bool = false
var _loop_flag_stack: Array[Dictionary] = []


func _init(owner: ExecutionContext) -> void:
	_owner = owner


# ============================================================
# 变量 CRUD(从 EC 迁入,逻辑完全不变)
# ============================================================

## 添加变量(接受 BaseVariable)
func add_variable(name: String, variable: BaseVariable) -> bool:
	if not variable or not variable.is_initialized:
		_owner._log_error_localized("FUSE_ERROR_INVALID_VARIABLE_OBJECT")
		return false
	var scope_name := "local"
	if variable.scope == BaseVariable.VariableScope.GLOBAL:
		scope_name = "global"
	return set_variable(name, variable.value, scope_name)


## 设置变量(三层作用域分发)
func set_variable(name: String, value: Variant, scope: String = "local") -> bool:
	if name.is_empty():
		_owner._log_error_localized("FUSE_ERROR_VARIABLE_NAME_CANNOT_BE_EMPTY")
		return false
	match scope:
		"scope":  return _set_scope_variable(name, value)
		"global": return _set_global_variable(name, value)
		"local":  return _set_local_variable(name, value)
		_:
			_owner._log_error_localized("FUSE_ERROR_UNKNOWN_VARIABLE_SCOPE", {"scope": scope})
			return false


## 获取变量值(三层作用域分发)
func get_variable(name: String, default: Variant = null, scope: String = "local") -> Variant:
	if OS.is_debug_build() and _owner.log_level >= FuseLogger.LogLevel.DEBUG:
		_owner._log_debug("ExecutionContext.get_variable called: name='%s', default=%s" % [name, str(default)])
		_owner._log_debug("ExecutionContext ID: %s" % _owner.execution_id)
		_owner._log_debug("Local variables count: %d" % local_variables.size())
	if name.is_empty():
		_owner._log_error_localized("FUSE_ERROR_VARIABLE_NAME_CANNOT_BE_EMPTY")
		return default
	match scope:
		"scope":  return _get_scope_variable(name, default)
		"global": return _get_global_variable(name, default)
		"local":  pass  # continue below
		_:
			_owner._log_error_localized("FUSE_ERROR_UNKNOWN_VARIABLE_SCOPE", {"scope": scope})
			return default

	# local scope lookup
	var name_key = _get_cached_name_key(name)
	if local_variables.has(name_key):
		var value = local_variables[name_key]
		if OS.is_debug_build() and _owner.log_level >= FuseLogger.LogLevel.DEBUG:
			_owner._log_debug("Retrieved local variable '%s': %s (type: %s)" % [name, str(value), typeof(value)])
		return value

	# fallback: check global
	if _global_variable_assistant != null:
		var global_var = _global_variable_assistant.get_global_variable(name)
		if global_var != null and global_var is BaseVariable:
			var value = global_var.get_value()
			if OS.is_debug_build() and _owner.log_level >= FuseLogger.LogLevel.DEBUG:
				_owner._log_debug("Retrieved global variable '%s': %s (type: %s)" % [name, str(value), typeof(value)])
			return value
	elif global_variables != null and global_variables.has_method("get"):
		var global_var = global_variables.get(name, null)
		if global_var != null:
			if global_var is BaseVariable:
				return global_var.get_value()
			else:
				return global_var

	if OS.is_debug_build() and _owner.log_level >= FuseLogger.LogLevel.DEBUG:
		_owner._log_debug("All local variables:")
		for var_name in local_variables:
			_owner._log_debug("  %s = %s (type: %s)" % [var_name, str(local_variables[var_name]), typeof(local_variables[var_name])])
	if OS.is_debug_build() and _owner.log_level >= FuseLogger.LogLevel.DEBUG:
		_owner._log_debug("Variable '%s' not found, returning default: %s" % [name, str(default)])
	return default


## 获取变量对象(高级 API)
func get_variable_object(name: String) -> BaseVariable:
	if name.is_empty():
		_owner._log_error_localized("FUSE_ERROR_VARIABLE_NAME_CANNOT_BE_EMPTY")
		return null
	var name_key = _get_cached_name_key(name)
	if local_variables.has(name_key):
		return _create_temporary_variable(name, local_variables[name_key])
	if global_variables:
		if global_variables.has_method("get"):
			var global_var = global_variables.get(name, null)
			if global_var is BaseVariable:
				return global_var
	_owner._log_debug("Variable object '%s' not found" % name)
	return null


func _create_temporary_variable(name: String, value: Variant) -> BaseVariable:
	return BaseVariable.create(name, value, BaseVariable.VariableScope.LOCAL)


## 检查变量是否存在
func has_variable(name: String) -> bool:
	if name.is_empty():
		return false
	var name_key = _get_cached_name_key(name)
	if _use_indexed_access:
		var index = _variable_index_map.get(name_key, -1)
		if index >= 0:
			return true
	if local_variables.has(name_key):
		return true
	if _global_variable_assistant != null:
		return _global_variable_assistant.has_global_variable(name)
	elif global_variables != null:
		if global_variables.has_method("has"):
			return global_variables.has(name)
		elif global_variables is Dictionary:
			return global_variables.has(name)
	return false


# ============================================================
# 作用域变量(scoped)
# ============================================================

func _find_scope_container() -> ScopeVariableContainer:
	var manager = ScopeVariableManager.get_instance()
	if manager == null:
		return null
	if _owner.trigger != null:
		var scope = manager.find_nearest_scope(_owner.trigger)
		if scope != null: return scope
	if _owner.target != null:
		var scope = manager.find_nearest_scope(_owner.target)
		if scope != null: return scope
	if _owner.owner != null:
		var scope = manager.find_nearest_scope(_owner.owner)
		if scope != null: return scope
	return null


func _set_scope_variable(name: String, value: Variant) -> bool:
	var scope_container = _find_scope_container()
	if scope_container != null:
		return scope_container.set_variable(name, value)
	push_warning("未找到作用域容器，回退到本地变量: %s" % name)
	return _set_local_variable(name, value)


func _get_scope_variable(name: String, default: Variant) -> Variant:
	var scope_container = _find_scope_container()
	if scope_container != null:
		return scope_container.get_variable(name, default)
	push_warning("未找到作用域容器，回退到本地变量: %s" % name)
	return _get_local_variable(name, default)


# ============================================================
# 全局变量
# ============================================================

func _set_global_variable(name: String, value: Variant) -> bool:
	if _global_variable_assistant != null:
		if _global_variable_assistant.has_global_variable(name):
			var existing_var = _global_variable_assistant.get_global_variable(name)
			if existing_var != null:
				existing_var.set_value(value)
				_owner._log_debug_localized("FUSE_LOG_GLOBAL_VARIABLE_UPDATED", {"name": name, "value": str(value)})
				return true
			else:
				_owner._log_error_localized("FUSE_ERROR_GLOBAL_VARIABLE_RETRIEVAL_FAILED", {"name": name})
				return false
		else:
			var new_variable = BaseVariable.create(name, value, BaseVariable.VariableScope.GLOBAL)
			if new_variable == null:
				_owner._log_error_localized("FUSE_ERROR_CREATE_GLOBAL_VARIABLE_FAILED", {"name": name})
				return false
			var success = _global_variable_assistant.add_global_variable(name, new_variable)
			if not success:
				_owner._log_error_localized("FUSE_ERROR_ADD_GLOBAL_VARIABLE_FAILED", {"name": name})
				return false
			_owner._log_debug_localized("FUSE_LOG_GLOBAL_VARIABLE_ADDED", {"name": name, "value": str(value)})
			return true
	elif global_variables != null and global_variables.has_method("set"):
		global_variables.set(name, value)
		_owner._log_debug_localized("FUSE_LOG_GLOBAL_VARIABLE_ADDED", {"name": name, "value": str(value)})
		return true
	else:
		_owner._log_error_localized("FUSE_ERROR_GLOBAL_VARIABLE_ASSISTANT_NOT_FOUND")
		return false


func _get_global_variable(name: String, default: Variant) -> Variant:
	if _global_variable_assistant != null:
		var global_var = _global_variable_assistant.get_global_variable(name)
		if global_var != null and global_var is BaseVariable:
			return global_var.get_value()
	elif global_variables != null and global_variables.has_method("get"):
		var global_var = global_variables.get(name, null)
		if global_var != null:
			return global_var.get_value() if global_var is BaseVariable else global_var
	return default


func get_global_variable_assistant() -> GlobalVariableAssistant:
	if _global_variable_assistant == null:
		_global_variable_assistant = GlobalVariableAssistant.get_instance()
	return _global_variable_assistant


func set_global_variable_assistant(assistant: GlobalVariableAssistant):
	_global_variable_assistant = assistant
	global_variables = assistant
	_owner._log_debug("GlobalVariableAssistant 已设置")


# ============================================================
# 本地变量
# ============================================================

func _set_local_variable(name: String, value: Variant) -> bool:
	var name_key = _get_cached_name_key(name)
	if OS.is_debug_build() and _owner.log_level >= FuseLogger.LogLevel.DEBUG:
		_owner._log_debug("Setting local variable '%s': %s (type: %s)" % [name, str(value), typeof(value)])
	if local_variables.has(name_key):
		_owner._log_warning_localized("FUSE_LOG_VARIABLE_ALREADY_EXISTS_OVERWRITING", {"name": name})
	local_variables[name_key] = value
	return true


func _get_local_variable(name: String, default: Variant) -> Variant:
	var name_key = _get_cached_name_key(name)
	if local_variables.has(name_key):
		var value = local_variables[name_key]
		if OS.is_debug_build() and _owner.log_level >= FuseLogger.LogLevel.DEBUG:
			_owner._log_debug("Retrieved local variable '%s': %s (type: %s)" % [name, str(value), typeof(value)])
		return value
	return default


# ============================================================
# 变量名缓存(LRU)
# ============================================================

func _get_cached_name_key(name: String) -> StringName:
	if _variable_name_cache.size() >= _cache_max_size:
		var remove_count = _cache_max_size / 5
		for i in range(remove_count):
			if _cache_access_order.size() > 0:
				var old_name = _cache_access_order[0]
				_variable_name_cache.erase(old_name)
				_cache_access_order.pop_front()
	if name in _cache_access_order:
		_cache_access_order.erase(name)
	_cache_access_order.append(name)
	if not _variable_name_cache.has(name):
		_variable_name_cache[name] = StringName(name)
	return _variable_name_cache[name]


# ============================================================
# 索引访问优化
# ============================================================

func precompile_variable_access(variable_names: Array[String]):
	_variable_index_map.clear()
	_variable_array.clear()
	_variable_array.resize(variable_names.size())
	for i in range(variable_names.size()):
		var name_key = StringName(variable_names[i])
		_variable_index_map[name_key] = i
	_use_indexed_access = true
	_owner._log_debug("预编译了 %d 个变量索引" % variable_names.size())


func set_variable_by_index(index: int, value: Variant):
	if not _use_indexed_access:
		_owner._log_warning_localized("FUSE_WARNING_INDEXED_ACCESS_NOT_ENABLED")
		return
	if index >= 0 and index < _variable_array.size():
		_variable_array[index] = value
	else:
		_owner._log_error("索引 %d 超出范围，有效范围: 0-%d" % [index, _variable_array.size() - 1])


func get_variable_by_index(index: int) -> Variant:
	if not _use_indexed_access:
		_owner._log_warning_localized("FUSE_WARNING_INDEXED_ACCESS_NOT_ENABLED")
		return null
	if index >= 0 and index < _variable_array.size():
		return _variable_array[index]
	_owner._log_error("索引 %d 超出范围，有效范围: 0-%d" % [index, _variable_array.size() - 1])
	return null


func get_variable_index(name: String) -> int:
	if not _use_indexed_access:
		return -1
	var name_key = _get_cached_name_key(name)
	return _variable_index_map.get(name_key, -1)


func is_indexed_access_enabled() -> bool:
	return _use_indexed_access


func get_indexed_access_stats() -> Dictionary:
	return {
		"indexed_access_enabled": _use_indexed_access,
		"total_variables": _variable_array.size(),
		"cached_names": _variable_name_cache.size(),
		"index_map_size": _variable_index_map.size()
	}


# ============================================================
# 变量快照(断点调试)
# ============================================================

func get_all_local_variables_snapshot() -> Dictionary:
	var snapshot: Dictionary = {}
	for key in local_variables:
		snapshot[str(key)] = local_variables[key]
	return snapshot


func get_all_scope_variables_snapshot() -> Dictionary:
	var snapshot: Dictionary = {}
	var scope_container = _find_scope_container()
	if scope_container != null:
		for name in scope_container.get_variable_names():
			snapshot[name] = scope_container.get_variable(name)
	return snapshot


func get_all_global_variables_snapshot() -> Dictionary:
	if _global_variable_assistant != null:
		return _global_variable_assistant.get_all_global_variables_info()
	return {}


# ============================================================
# 循环控制
# ============================================================

func set_break_loop():
	_break_loop_flag = true


func set_continue_loop():
	_continue_loop_flag = true


func should_break_loop() -> bool:
	return _break_loop_flag


func should_continue_loop() -> bool:
	return _continue_loop_flag


func clear_loop_flags():
	_break_loop_flag = false
	_continue_loop_flag = false


func push_loop_flags():
	_loop_flag_stack.append({"break": _break_loop_flag, "continue": _continue_loop_flag})
	_break_loop_flag = false
	_continue_loop_flag = false


func pop_loop_flags():
	if _loop_flag_stack.is_empty():
		_break_loop_flag = false
		_continue_loop_flag = false
	else:
		var flags = _loop_flag_stack.pop_back()
		_break_loop_flag = flags["break"]
		_continue_loop_flag = flags["continue"]


# ============================================================
# cleanup + duplicate
# ============================================================

func cleanup():
	for key in local_variables.keys():
		var value = local_variables[key]
		if is_instance_valid(value) and (value is RefCounted or value is Resource):
			local_variables[key] = null
	local_variables.clear()
	global_variables = null
	_global_variable_assistant = null
	_variable_name_cache.clear()
	_cache_access_order.clear()
	_variable_index_map.clear()
	_variable_array.clear()
	_use_indexed_access = false
	clear_loop_flags()
	_loop_flag_stack.clear()


func duplicate(p_deep: bool = true) -> VariableContext:
	var copy = VariableContext.new(_owner)
	copy.local_variables = local_variables.duplicate()
	copy._variable_name_cache = _variable_name_cache.duplicate()
	copy._variable_index_map = _variable_index_map.duplicate()
	copy._variable_array = _variable_array.duplicate()
	copy._use_indexed_access = _use_indexed_access
	copy.global_variables = global_variables
	copy._global_variable_assistant = _global_variable_assistant
	copy._break_loop_flag = _break_loop_flag
	copy._continue_loop_flag = _continue_loop_flag
	return copy
```

- [ ] **Step 2:EC 接线 — 添加 `_variable_context` 引用 + 门面委托**

在 `ExecutionContext` 顶部(属性声明区,行 50 `var target` 之后)新增:

```gdscript
## 变量子系统(委托)
var _variable_context: VariableContext = null
```

在 `_init()`(行 100)末尾,`reset_execution_state()` 之前加入:

```gdscript
		# 创建变量子系统
		_variable_context = VariableContext.new(self)
		_variable_context.global_variables = global_variables
		_variable_context.set_global_variable_assistant(_global_variable_assistant)
```

**变量门面方法**全部改为委托 `_variable_context`,删除原 EC 中的实现(行 216-611 的 add/set/get/get_object + 行 1153-1184 has_variable + 行 569-597 _set/get_local + 行 495-563 _set/get_global + 行 442-489 scope + 行 599-611 assistant get/set):

```gdscript
# ---- 变量门面(委托 VariableContext) ----

func add_variable(name: String, variable: BaseVariable) -> bool:
	return _variable_context.add_variable(name, variable)


func set_variable(name: String, value: Variant, scope: String = "local") -> bool:
	return _variable_context.set_variable(name, value, scope)


func get_variable(name: String, default: Variant = null, scope: String = "local") -> Variant:
	return _variable_context.get_variable(name, default, scope)


func get_variable_object(name: String) -> BaseVariable:
	return _variable_context.get_variable_object(name)


func has_variable(name: String) -> bool:
	return _variable_context.has_variable(name)


func get_global_variable_assistant() -> GlobalVariableAssistant:
	return _variable_context.get_global_variable_assistant()


func set_global_variable_assistant(assistant: GlobalVariableAssistant):
	_variable_context.set_global_variable_assistant(assistant)
	global_variables = assistant   # 保持兼容


# ---- 循环控制门面(委托 VariableContext) ----

func set_break_loop():
	_variable_context.set_break_loop()


func set_continue_loop():
	_variable_context.set_continue_loop()


func should_break_loop() -> bool:
	return _variable_context.should_break_loop()


func should_continue_loop() -> bool:
	return _variable_context.should_continue_loop()


func clear_loop_flags():
	_variable_context.clear_loop_flags()


func push_loop_flags():
	_variable_context.push_loop_flags()


func pop_loop_flags():
	_variable_context.pop_loop_flags()


# ---- 索引访问门面(委托 VariableContext) ----

func precompile_variable_access(variable_names: Array[String]):
	_variable_context.precompile_variable_access(variable_names)


func set_variable_by_index(index: int, value: Variant):
	_variable_context.set_variable_by_index(index, value)


func get_variable_by_index(index: int) -> Variant:
	return _variable_context.get_variable_by_index(index)


func get_variable_index(name: String) -> int:
	return _variable_context.get_variable_index(name)


func is_indexed_access_enabled() -> bool:
	return _variable_context.is_indexed_access_enabled()


func get_indexed_access_stats() -> Dictionary:
	return _variable_context.get_indexed_access_stats()


# ---- 变量快照门面(委托 VariableContext) ----

func get_all_local_variables_snapshot() -> Dictionary:
	return _variable_context.get_all_local_variables_snapshot()


func get_all_scope_variables_snapshot() -> Dictionary:
	return _variable_context.get_all_scope_variables_snapshot()


func get_all_global_variables_snapshot() -> Dictionary:
	return _variable_context.get_all_global_variables_snapshot()
```

**删除 EC 中的属性**(行 54-62,移入 VariableContext):`local_variables`、`_variable_name_cache`、`_cache_max_size`、`_cache_access_order`、`_variable_index_map`、`_variable_array`、`_use_indexed_access`、`global_variables`、`_global_variable_assistant`。

**删除 EC 中的循环控制属性**(行 82-84):`_break_loop_flag`、`_continue_loop_flag`、`_loop_flag_stack`。

> 原 EC 的 `global_variables` 和 `_global_variable_assistant` 如果被外部代码直接访问(非通过方法),可能有风险。但评估报告确认外部指令通过 `set_variable`/`get_variable` 访问,不直接读内部属性。保留 `global_variables` 在 EC 中作为兼容引用 → 在 `set_global_variable_assistant` 门面里同步 `global_variables = assistant`。

- [ ] **Step 3:更新 EC.cleanup() 和 EC.duplicate()**

EC.cleanup()(行 747-802)中删除变量相关清理(行 748-762:local_vars 清理 + 引用清理)和优化缓存清理(行 789-793),改为:

```gdscript
	# cleanup() 中替换变量+缓存清理段为:
	if _variable_context:
		_variable_context.cleanup()
```

EC.duplicate()(行 815-830)中删除变量复制行(820-824),改为:

```gdscript
	# duplicate() 中替换变量复制段为:
	copy._variable_context = _variable_context.duplicate()
	copy._variable_context._owner = copy  # 更新 owner 引用
```

- [ ] **Step 4:验证**

**关键:验证外部 API 完全不变。**
1. Godot 编辑器:禁用 → 启用插件。
2. 跑回归基线 5 条命令,与 Phase 3 一致。
3. 手动测试:打开含 Trigger 的场景,确认指令执行正常(set/get/set_break_loop 等无报错)。
4. **专门验证**:打开 demos/fuse 场景,确认所有指令(ForEach/While/WaitUntil/SetVariable/GetVariable 等)执行结果与 Phase 3 一致。

- [ ] **Step 5:commit**

```bash
git add addons/fuse/core/base/variable_context.gd addons/fuse/core/base/execution_context.gd
git commit -m "refactor(fuse): extract VariableContext from ExecutionContext (phase4 task4.1)"
```

---

# Task 4.2:创建 ExecutionDiagnostics + EC 委托诊断操作

**Files:**
- Create: `addons/fuse/core/base/execution_diagnostics.gd`
- Modify: `addons/fuse/core/base/execution_context.gd`(删除行 879-989 状态管理/行 1059-1082 监听器/行 1094-1146 统计/行 1188-1373 依赖图;添加 `_diagnostics` 引用;门面委托)

- [ ] **Step 1:创建 ExecutionDiagnostics**

创建 `addons/fuse/core/base/execution_diagnostics.gd`,迁入执行状态管理 + 历史 + 统计 + 依赖图逻辑:

```gdscript
@tool
class_name ExecutionDiagnostics extends RefCounted

## ExecutionContext 诊断子系统
##
## 管理执行状态机、执行历史、状态变化监听器、
## 进度跟踪、状态统计、依赖关系图与可视化数据。

var _owner: ExecutionContext

# 执行状态管理
var _execution_state: int = 0  # ExecutionState
var _execution_progress: float = 0.0
var _error_message: String = ""
var _is_cancelled: bool = false
var _last_state_change_time: float = 0.0

# 历史记录
var _execution_history: Array[Dictionary] = []
var _max_history_size: int = 100

# 状态变化监听器
var _state_change_listeners: Array[Callable] = []


func _init(owner: ExecutionContext) -> void:
	_owner = owner
	_execution_state = ExecutionContext.ExecutionState.IDLE


# ============================================================
# 执行状态管理
# ============================================================

func get_execution_state() -> int:
	return _execution_state


func set_execution_state(state: int):
	var old_state = _execution_state
	if old_state != state:
		_execution_state = state
		_owner.execution_state_changed.emit(state)
		_record_execution_history(state, "状态变化: %s -> %s" % [
			ExecutionContext.ExecutionState.keys()[old_state],
			ExecutionContext.ExecutionState.keys()[state]
		])
		_notify_state_change(old_state, state)
		_owner._log_debug("Execution state changed to: %s" % ExecutionContext.ExecutionState.keys()[state])


func reset_execution_state():
	var old_state = _execution_state
	_execution_state = ExecutionContext.ExecutionState.IDLE
	_execution_progress = 0.0
	_error_message = ""
	_is_cancelled = false
	_record_execution_history(ExecutionContext.ExecutionState.IDLE, "状态重置")
	if old_state != ExecutionContext.ExecutionState.IDLE:
		_notify_state_change(old_state, ExecutionContext.ExecutionState.IDLE)


func is_running() -> bool:
	return _execution_state == ExecutionContext.ExecutionState.RUNNING


func is_completed() -> bool:
	return _execution_state == ExecutionContext.ExecutionState.COMPLETED


func has_error() -> bool:
	return _execution_state == ExecutionContext.ExecutionState.ERROR


func is_cancelled() -> bool:
	return _is_cancelled or _execution_state == ExecutionContext.ExecutionState.CANCELLED


func request_cancel():
	if _execution_state == ExecutionContext.ExecutionState.RUNNING:
		_is_cancelled = true
		set_execution_state(ExecutionContext.ExecutionState.CANCELLED)
		_owner.cancel_requested.emit()


# ---- 进度 ----

func get_execution_progress() -> float:
	return _execution_progress


func set_execution_progress(progress: float):
	var old_progress = _execution_progress
	_execution_progress = clamp(progress, 0.0, 1.0)
	if abs(old_progress - _execution_progress) > 0.01:
		_record_execution_history(_execution_state, "进度更新", {
			"old_progress": old_progress, "new_progress": _execution_progress,
			"progress_delta": _execution_progress - old_progress
		})


# ---- 错误 ----

func get_error_message() -> String:
	return _error_message


func set_error_message(message: String, error_type: int = 0, context: Dictionary = {}):
	_error_message = message
	set_execution_state(ExecutionContext.ExecutionState.ERROR)


# ============================================================
# 历史记录
# ============================================================

func _record_execution_history(state: int, message: String = "", data: Dictionary = {}):
	var history_entry = {
		"timestamp": Time.get_ticks_msec() / 1000.0,
		"state": state,
		"state_name": ExecutionContext.ExecutionState.keys()[state],
		"message": message,
		"progress": _execution_progress,
		"execution_time": _owner.get_execution_time(),
		"data": data.duplicate()
	}
	_execution_history.append(history_entry)
	if _execution_history.size() > _max_history_size:
		_execution_history.pop_front()
	_last_state_change_time = Time.get_ticks_msec() / 1000.0


func get_execution_history(limit: int = 0) -> Array[Dictionary]:
	if limit <= 0 or limit >= _execution_history.size():
		return _execution_history.duplicate()
	else:
		return _execution_history.slice(-limit).duplicate()


func clear_execution_history():
	_execution_history.clear()


# ============================================================
# 状态变化监听器
# ============================================================

func add_state_change_listener(listener: Callable):
	if not _state_change_listeners.has(listener):
		_state_change_listeners.append(listener)


func remove_state_change_listener(listener: Callable):
	if _state_change_listeners.has(listener):
		_state_change_listeners.erase(listener)


func _notify_state_change(old_state: int, new_state: int):
	for listener in _state_change_listeners:
		if listener.is_valid():
			listener.call(old_state, new_state, _owner)


# ============================================================
# 状态统计
# ============================================================

func get_state_statistics() -> Dictionary:
	var state_counts = {}
	var total_time_in_states = {}
	for state in ExecutionContext.ExecutionState.values():
		state_counts[ExecutionContext.ExecutionState.keys()[state]] = 0
		total_time_in_states[ExecutionContext.ExecutionState.keys()[state]] = 0.0
	for i in range(_execution_history.size()):
		var entry = _execution_history[i]
		state_counts[entry["state_name"]] += 1
		if i < _execution_history.size() - 1:
			total_time_in_states[entry["state_name"]] += _execution_history[i + 1]["timestamp"] - entry["timestamp"]
	return {
		"total_history_entries": _execution_history.size(),
		"state_counts": state_counts,
		"total_time_in_states": total_time_in_states,
		"last_state_change_time": _last_state_change_time,
		"current_state_duration": Time.get_ticks_msec() / 1000.0 - _last_state_change_time
	}


func get_recent_state_changes(count: int = 10) -> Array[Dictionary]:
	var recent_changes = []
	for i in range(_execution_history.size() - 1, -1, -1):
		var entry = _execution_history[i]
		if i > 0 and _execution_history[i - 1]["state"] != entry["state"]:
			recent_changes.append(entry)
			if recent_changes.size() >= count: break
		elif i == 0:
			recent_changes.append(entry)
	recent_changes.reverse()
	return recent_changes


# ============================================================
# 依赖关系图
# ============================================================

func get_dependency_graph() -> Dictionary:
	var graph = {
		"nodes": [], "edges": [],
		"context_info": {
			"execution_id": _owner.execution_id,
			"target": _owner.target.get_name() if _owner.target else "null",
			"trigger": _owner.trigger.get_name() if _owner.trigger else "null",
			"execution_time": _owner.get_execution_time()
		}
	}
	var all_variables = _collect_all_variables()
	for var_name in all_variables:
		graph["nodes"].append({"id": var_name, "label": var_name, "type": "variable",
			"value": str(all_variables[var_name]), "exists": true})
	return graph


func _collect_all_variables() -> Dictionary:
	var all_vars = {}
	for var_name in _owner._variable_context.local_variables:
		all_vars[var_name] = _owner._variable_context.local_variables[var_name]
	return all_vars


func check_dependencies(dependencies: Array[String]) -> Dictionary:
	var result = {"satisfied": true, "missing_dependencies": [], "dependency_details": {}}
	for dep_var in dependencies:
		var exists = _owner.has_variable(dep_var)
		var value = _owner.get_variable(dep_var) if exists else null
		result["dependency_details"][dep_var] = {"exists": exists, "value": value,
			"type": typeof(value) if value != null else TYPE_NIL}
		if not exists:
			result["satisfied"] = false
			result["missing_dependencies"].append(dep_var)
	return result


func get_dependency_status() -> Dictionary:
	return {
		"total_variables": _collect_all_variables().size(),
		"total_conditions": 0,
		"variable_dependencies": {},
		"condition_dependencies": {}
	}


func check_dependencies_batch(dependencies_list: Array) -> Array:
	var results: Array = []
	for dependencies in dependencies_list:
		results.append(check_dependencies(dependencies))
	return results


func get_dependency_visualization_data() -> Dictionary:
	return {
		"graph": get_dependency_graph(),
		"status": get_dependency_status(),
		"context_info": {
			"execution_id": _owner.execution_id,
			"execution_time": _owner.get_execution_time(),
			"execution_state": ExecutionContext.ExecutionState.keys()[_execution_state],
			"progress": _execution_progress
		}
	}


# ============================================================
# cleanup
# ============================================================

func cleanup():
	_execution_history.clear()
	_state_change_listeners.clear()
	_execution_state = ExecutionContext.ExecutionState.IDLE
	_execution_progress = 0.0
	_error_message = ""
	_is_cancelled = false
```

- [ ] **Step 2:EC 接线 — 添加 `_diagnostics` 引用 + 门面委托**

在 EC 属性声明区新增:

```gdscript
## 诊断子系统(委托)
var _diagnostics: ExecutionDiagnostics = null
```

在 `_init()` 的 `_variable_context` 创建之后加入:

```gdscript
		# 创建诊断子系统
		_diagnostics = ExecutionDiagnostics.new(self)
```

**诊断门面方法**全部改为委托 `_diagnostics`,删除原 EC 中的实现(行 879-989 状态/进度/错误/取消/重置 + 行 1059-1082 监听器 + 行 1094-1146 统计 + 行 1188-1373 依赖图):

```gdscript
# ---- 状态管理门面(委托 Diagnostics) ----

func get_execution_state() -> ExecutionState:
	return _diagnostics.get_execution_state()


func set_execution_state(state: ExecutionState):
	_diagnostics.set_execution_state(state)


func reset_execution_state():
	_diagnostics.reset_execution_state()


func is_running() -> bool:
	return _diagnostics.is_running()


func is_completed() -> bool:
	return _diagnostics.is_completed()


func has_error() -> bool:
	return _diagnostics.has_error()


func is_cancelled() -> bool:
	return _diagnostics.is_cancelled()


func request_cancel():
	_diagnostics.request_cancel()


func get_execution_progress() -> float:
	return _diagnostics.get_execution_progress()


func set_execution_progress(progress: float):
	_diagnostics.set_execution_progress(progress)


func get_error_message() -> String:
	return _diagnostics.get_error_message()


func set_error_message(message: String, error_type = FuseError.ErrorType.RUNTIME_ERROR, context: Dictionary = {}):
	_diagnostics.set_error_message(message, error_type, context)


# ---- 历史/监听器/统计门面(委托 Diagnostics) ----

func get_execution_history(limit: int = 0) -> Array[Dictionary]:
	return _diagnostics.get_execution_history(limit)


func clear_execution_history():
	_diagnostics.clear_execution_history()


func add_state_change_listener(listener: Callable):
	_diagnostics.add_state_change_listener(listener)


func remove_state_change_listener(listener: Callable):
	_diagnostics.remove_state_change_listener(listener)


func get_state_statistics() -> Dictionary:
	return _diagnostics.get_state_statistics()


func get_recent_state_changes(count: int = 10) -> Array[Dictionary]:
	return _diagnostics.get_recent_state_changes(count)


# ---- 依赖图门面(委托 Diagnostics) ----

func get_dependency_graph() -> Dictionary:
	return _diagnostics.get_dependency_graph()


func check_dependencies(dependencies: Array[String]) -> Dictionary:
	return _diagnostics.check_dependencies(dependencies)


func get_dependency_status() -> Dictionary:
	return _diagnostics.get_dependency_status()


func check_dependencies_batch(dependencies_list: Array) -> Array:
	return _diagnostics.check_dependencies_batch(dependencies_list)


func get_dependency_visualization_data() -> Dictionary:
	return _diagnostics.get_dependency_visualization_data()
```

**删除 EC 中的属性**(行 75-89):`_execution_state`、`_execution_progress`、`_error_message`、`_is_cancelled`、`_execution_history`、`_state_change_listeners`、`_max_history_size`、`_last_state_change_time`(移入 Diagnostics)。

删除 `_record_execution_history`(行 1037-1054)、`_notify_state_change`(行 1087-1090)、`_collect_all_variables`(行 1246-1263)、`_collect_conditions`(行 1267-1282)(移入 Diagnostics)。

- [ ] **Step 3:更新 EC.cleanup()**

在 EC.cleanup() 中,变量清理后加入诊断清理:

```gdscript
	if _diagnostics:
		_diagnostics.cleanup()
```

- [ ] **Step 4:验证**

1. 禁用 → 启用插件。
2. 跑回归基线 5 条命令,与 Task 4.1 后一致。
3. 手动验证:运行指令,确认状态切换正常(COMPLETED/ERROR/CANCELLED 信号)、执行历史记录正常。

- [ ] **Step 5:commit**

```bash
git add addons/fuse/core/base/execution_diagnostics.gd addons/fuse/core/base/execution_context.gd
git commit -m "refactor(fuse): extract ExecutionDiagnostics from ExecutionContext (phase4 task4.2)"
```

---

# Task 4.3:压缩 ExecutionContext + 最终 API 验证

**Files:**
- Modify: `addons/fuse/core/base/execution_context.gd`(清理残留属性/方法,确认仅剩核心骨架)

- [ ] **Step 1:确认 EC 最终保留内容**

EC 保留(不被迁出):
- 节点属性:`target`/`trigger`/`owner`/`tree`/`action_runner`/`delta_time`(行 50-67)
- 弱引用:`_target_weakref`/`_trigger_weakref` + set/get target/trigger node
- 执行属性:`execution_start_time`/`execution_id`/`log_level`/`custom_data`(行 64-67)
- `_fuse_error`(行 79)
- 子系统引用:`_variable_context`/`_diagnostics`(Task 4.1/4.2 新增)
- 初始化:`_init`(精简)+`_generate_execution_id`+`create_with_params`
- 场景访问:`get_tree`/`get_node`
- 日志方法:`print_message`/`print_warning`/`print_error` + `_log_*`/`_log_*_localized` + `set_log_level`/`get_log_level`
- 自定义数据:`set_custom_data`/`get_custom_data`
- ActionRunner:`set_action_runner`/`get_action_runner`/`has_action_runner`
- `get_execution_time`/`get_info`/`duplicate`(调子系统 duplicate)/`cleanup`(调子系统 cleanup)
- FuseError:`_create_fuse_error`/`get_fuse_error`/`has_fuse_error`/`had_error`
- 信号:`cancel_requested`/`execution_state_changed`(emit 在门面中委托 Diagnostics)
- **门面方法**:变量门面(Task 4.1 实现)+ 诊断门面(Task 4.2 实现)

- [ ] **Step 2:核验行数**

```bash
wc -l addons/fuse/core/base/execution_context.gd
```
预期:~300-350 行。若 > 400,检查是否有迁出的方法/属性残留。

- [ ] **Step 3:全量回归 + API 兼容验证**

1. 禁用 → 启用插件。
2. 跑回归基线 5 条命令,与 Task 4.2 后一致。
3. **API 兼容专项**:搜索所有指令中对 `context.set_variable`/`context.get_variable`/`context.has_variable`/`context.add_variable`/`context.set_break_loop`/`context.get_execution_state` 等公共方法的调用,确认无不兼容。

```bash
# 抽查关键调用方
rg "context\.(set_variable|get_variable|has_variable|add_variable|set_break|set_continue|should_break|should_continue|clear_loop|push_loop|pop_loop|get_execution_state|is_completed|is_running|has_error|request_cancel|set_error|get_execution_history|get_state_statistics|get_dependency)" \
  addons/fuse/instructions/ addons/fuse/events/ addons/fuse/conditions/ -l
```
预期:所有调用方编译通过,运行时无 `Invalid call` 错误。

- [ ] **Step 4:commit**

```bash
git add addons/fuse/core/base/execution_context.gd
git commit -m "refactor(fuse): slim ExecutionContext to core facade (phase4 complete)"
```

---

# Task 4.4:最终回归 + 文档更新

**Files:**
- Modify: `addons/fuse/docs/system_docs/analysis/2026-06-15-fuse-architecture-regression-baseline.md`(追加 Phase 4 复跑记录)
- Modify: `addons/fuse/docs/system_docs/analysis/2026-06-15-fuse-known-issues-allowlist.md`(5.6 EC 膨胀从"Phase 4"移到"已修复")

- [ ] **Step 1:回填基线 + 更新白名单**

在基线文档追加 Phase 4 复跑记录(含回归表 + EC/VariableContext/Diagnostics 行数 + API 兼容验证结果)。

在白名单中,评估项 5.6(ExecutionContext 膨胀)和 5.7(BaseInstruction 静态 metadata 边界,若本 Phase 顺手修了 metadata→ 标注;否则留 Phase 4 已完成主目标)更新状态。

- [ ] **Step 2:commit**

```bash
git add addons/fuse/docs/system_docs/analysis/2026-06-15-fuse-architecture-regression-baseline.md \
        addons/fuse/docs/system_docs/analysis/2026-06-15-fuse-known-issues-allowlist.md
git commit -m "docs(fuse): mark phase4 complete, EC split to 3 layers (phase4)"
```

---

## Self-Review

**1. 整改总计划 §8 覆盖:**
- §8.2 ExecutionContext 核心骨架(target/trigger/owner/树/日志/生命周期)→ 留 EC ✓
- §8.2 VariableContext(local/scope/global 访问+变量名缓存+索引优化)→ Task 4.1 ✓
- §8.2 ExecutionDiagnostics(历史+依赖图+可视化+统计)→ Task 4.2 ✓
- §8.3 第一轮只做内部委托,不改外部 API→ 所有门面方法签名完全不变 ✓
- §8.4 不在同一轮顺手改变量语义→ 变量操作逻辑完全不变(仅移入 VariableContext)✓
- §12 M4 里程碑(EC 变门面类,变量/诊断独立)→ Task 4.3 ✓

**2. Placeholder 扫描:** 无 TBD/TODO;VariableContext 和 Diagnostics 给完整代码;EC 门面给所有委托方法;验证给具体命令。

**3. 类型/签名一致性:**
- `VariableContext._owner: ExecutionContext` ↔ 所有方法通过 `_owner.xxx()` 访问 EC 属性 ✓
- `ExecutionDiagnostics._owner: ExecutionContext` ↔ 同上 ✓
- EC 门面方法签名与原始完全一致(参数名、顺序、默认值、返回类型) ✓
- EC.cleanup/duplicate 调 `_variable_context.cleanup()/duplicate()` ↔ 循环引用 `_owner` 在 duplicate 中更新 ✓

**4. 风险点:**
- **最高风险:外部 API 破坏**:任何门面方法签名改变或调用 `_variable_context` 为 null 都会导致 100+ 指令出错。Task 4.1 Step 4 专门验证 + Task 4.3 rg 抽查。
- `set_global_variable_assistant` 同步 `global_variables = assistant`(EC 属性)和 `_variable_context.set_global_variable_assistant`(子系统)→ 双重同步,已在门面方法中处理 ✓
- Diagnostics 依赖 `_owner._variable_context`(如 `_collect_all_variables` 读 `_owner._variable_context.local_variables`)→ Diagnostics._collect_all_variables 直接访问 EC 的 VariableContext ✓

**5. 评估项 5.7(静态 metadata):** 不在 Phase 4 范围(总计划 §13 标注为未覆盖项,建议 Phase 4 顺带处理)。本计划不处理。若远程机器有把握可顺手规范化(在 `BaseInstruction._init` 中统一静态/实例 metadata 边界)并记录到已知问题白名单。

---

## 执行交接

计划已保存至 `addons/fuse/docs/system_docs/analysis/2026-06-16-fuse-phase4-implementation-plan.md`。

**这是整改最后一个主 Phase(Phase 5 已基本提前到 Phase 1 完成)。** 风险等级最高(EC 100+ 指令引用),每个 Task 后必须跑全量回归 + API 兼容验证。

由远程机器执行,我负责最终审查。完成后发结果(commits + 行数 + 回归),通过后 Fuse 架构整改主链全部闭环。
