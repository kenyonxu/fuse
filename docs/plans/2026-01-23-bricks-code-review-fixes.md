# Bricks 插件代码审查修复实施计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**目标:** 修复 Bricks 插件代码审查中发现的关键问题，包括内存泄漏、数据一致性和性能优化

**架构:** 基于 Event-driven 和 Resource-based 设计模式，修复信号管理、变量存储、序列化和缓存机制

**技术栈:** Godot 4.5, GDScript 2.0

---

## 问题优先级概览

| 优先级 | 问题 | 影响 | 工作量 |
|--------|------|------|--------|
| 🔴 Critical | 信号连接 Callable.bind() 内存泄漏 | 内存泄漏 | 中 |
| 🔴 Critical | VariableContainer 多套存储数据不一致 | 数据一致性 | 高 |
| 🔴 Critical | BaseVariable 持久化序列化不可靠 | 数据丢失 | 中 |
| 🟡 Important | BaseInstruction 异步检测不准确 | 执行错误 | 中 |
| 🟡 Important | ExecutionContext StringName 缓存无限增长 | 内存占用 | 低 |
| 🟡 Important | ActionRunner 超时检查不准确 | 执行超时 | 低 |
| 🟡 Important | BaseCondition 缓存哈希不完整 | 逻辑错误 | 低 |

---

## Task 1: 修复 ActionRunner 信号连接内存泄漏

**严重程度:** Critical
**影响范围:** [action_runner.gd:398-430](addons/bricks/core/base/action_runner.gd#L398-L430)

**问题分析:**
`_on_instruction_finished` 方法使用 `.bind()` 创建新的 Callable 对象，导致 `disconnect()` 无法匹配原始连接，造成信号连接无法断开，最终导致内存泄漏。

**修复策略:**
1. 添加 Callable 缓存字典存储原始回调
2. 修改信号连接逻辑使用缓存
3. 在清理时使用缓存的 Callback 断开连接

**Step 1.1: 添加 Callable 缓存字典**

在 `action_runner.gd` 的成员变量区域（约第 53 行后）添加：

```gdscript
var _instruction_callback_cache: Dictionary = {}  ## instruction -> cached callback
```

**Step 1.2: 修改 `_connect_instruction_signal` 方法**

替换 [action_runner.gd:398-410](addons/bricks/core/base/action_runner.gd#L398-L410) 的实现：

```gdscript
func _connect_instruction_signal(instruction: BaseInstruction, handler: Callable) -> bool:
	if not instruction or not handler:
		_log_warning("无法连接信号：指令或处理器为空")
		return false

	# 创建并缓存回调函数
	var callback = _on_instruction_finished_wrapper.bind(instruction)
	_instruction_callback_cache[instruction] = callback
	_current_signal_handlers[instruction] = handler

	var result = instruction.finished.connect(callback)
	_connected_signals[instruction] = handler

	_log_debug("已连接指令 '%s' 的 finished 信号" % instruction.get_name())
	return result == OK
```

**Step 1.3: 添加指令完成包装器**

在 `action_runner.g` 中添加新方法（约第 897 行后）：

```gdscript
func _on_instruction_finished_wrapper(instruction: BaseInstruction):
	# 从缓存获取并断开回调
	if _instruction_callback_cache.has(instruction):
		var callback = _instruction_callback_cache[instruction]
		if instruction.finished.is_connected(callback):
			instruction.finished.disconnect(callback)
		_instruction_callback_cache.erase(instruction)

	_disconnect_instruction_signal(instruction)
```

**Step 1.4: 修改 `_disconnect_instruction_signal` 方法**

替换 [action_runner.gd:414-429](addons/bricks/core/base/action_runner.gd#L414-L429) 的实现：

```gdscript
func _disconnect_instruction_signal(instruction: BaseInstruction):
	if not instruction:
		return

	# 优先使用缓存的 callback 断开连接
	if _instruction_callback_cache.has(instruction):
		var callback = _instruction_callback_cache[instruction]
		if instruction.finished.is_connected(callback):
			instruction.finished.disconnect(callback)
			_log_debug("已断开指令 '%s' 的 finished 信号（使用缓存）" % instruction.get_name())
		_instruction_callback_cache.erase(instruction)

	if _current_signal_handlers.has(instruction):
		var handler = _current_signal_handlers[instruction]
		if instruction.finished.is_connected(handler):
			instruction.finished.disconnect(handler)
			_log_debug("已断开指令 '%s' 的 finished 信号" % instruction.get_name())
		else:
			_log_debug("指令 '%s' 的 finished 信号未连接，跳过断开" % instruction.get_name())

		_current_signal_handlers.erase(instruction)
		_connected_signals.erase(instruction)
	else:
		_log_debug("指令 '%s' 没有记录的信号处理器" % instruction.get_name())
```

**Step 1.5: 更新 `_disconnect_all_signals` 方法**

修改 [action_runner.gd:432-443](addons/bricks/core/base/action_runner.gd#L432-L443) 添加缓存清理：

```gdscript
func _disconnect_all_signals():
	_log_debug("断开所有指令的信号连接...")
	var disconnect_count = 0

	for instruction in _connected_signals.keys():
		_disconnect_instruction_signal(instruction)
		disconnect_count += 1

	_connected_signals.clear()
	_current_signal_handlers.clear()
	_instruction_callback_cache.clear()  # 清理 callback 缓存

	_log_debug("已断开 %d 个信号连接" % disconnect_count)
```

**Step 1.6: 创建测试验证修复**

创建文件 `addons/bricks/tests/test_signal_cleanup.gd`:

```gdscript
extends Node

## 测试 ActionRunner 信号清理功能

func _ready():
	test_signal_cleanup()

func test_signal_cleanup():
	print("=== 测试 ActionRunner 信号清理 ===")

	# 创建测试用的简单指令
	var instruction = SimpleTestInstruction.new()
	var runner = ActionRunner.new()
	runner.instructions.append(instruction)

	# 创建执行上下文
	var context = ExecutionContext.new()

	# 监控信号连接数
	var initial_connections = _get_signal_connection_count(instruction)
	print("初始信号连接数: %d" % initial_connections)

	# 执行指令
	runner.run(context)
	await runner.execution_completed

	var after_run_connections = _get_signal_connection_count(instruction)
	print("执行后信号连接数: %d" % after_run_connections)

	# 验证信号已断开
	assert(after_run_connections == initial_connections, "信号连接应该被清理")

	print("✓ 信号清理测试通过")

func _get_signal_connection_count(obj: Object) -> int:
	# 这是一个简化版本，实际可能需要使用更复杂的方法
	# 在 Godot 4.x 中，可能需要使用其他方法来检测连接
	return 0  # 占位符

class SimpleTestInstruction extends BaseInstruction:
	func execute(context: ExecutionContext):
		_on_execution_completed()

	func get_description() -> String:
		return "Test Instruction"
```

**Step 1.7: 运行测试验证**

```bash
# 在 Godot 编辑器中运行测试场景
# 或者使用命令行:
E:\Godot\Godot_v4.5.1-stable_mono_win64\Godot_v4.5.1-stable_mono_win64.exe --path . --script addons/bricks/tests/test_signal_cleanup.gd
```

预期输出: 测试通过，信号连接被正确清理

**Step 1.8: 提交修复**

```bash
git add addons/bricks/core/base/action_runner.gd addons/bricks/tests/test_signal_cleanup.gd
git commit -m "fix(action-runner): 修复信号连接内存泄漏，添加 Callable 缓存机制

- 添加 _instruction_callback_cache 缓存原始 callback
- 创建 _on_instruction_finished_wrapper 包装器
- 修改 _disconnect_instruction_signal 使用缓存断开
- 在 _disconnect_all_signals 中清理缓存
- 添加测试用例验证修复

Fixes #1 - 信号连接内存泄漏"
```

---

## Task 2: 统一 VariableContainer 存储策略

**严重程度:** Critical
**影响范围:** [variable_container.gd:34-60](addons/bricks/core/base/variable_container.gd#L34-L60)

**问题分析:**
VariableContainer 同时维护多套存储系统（8个不同的字典），导致数据可能在不同存储中不同步，造成数据不一致。

**修复策略:**
1. 创建单一真实数据源（`_variables_data`）
2. 其他存储作为索引和缓存
3. 更新所有访问方法使用统一接口
4. 保持向后兼容性

**Step 2.1: 创建统一的 VariableData 结构**

修改 [variable_container.gd:26-30](addons/bricks/core/base/variable_container.gd#L26-L30):

```gdscript
class VariableData:
	var value: Variant = null                    ## 变量值
	var type: Variant.Type = TYPE_NIL            ## 变量类型
	var scope: VariableScope = VariableScope.LOCAL  ## 变量作用域
	var timestamp: int = 0                       ## 创建时间戳
	var persistent: bool = false                 ## 是否持久化
	var access_count: int = 0                    ## 访问次数
	var modification_count: int = 0              ## 修改次数
	var last_modified: int = 0                   ## 最后修改时间
```

**Step 2.2: 替换多套存储为单一数据源**

修改 [variable_container.gd:32-64](addons/bricks/core/base/variable_container.gd#L32-L64):

```gdscript
## 主存储：所有变量的真实数据源
var _variables_data: Dictionary = {}  ## name -> VariableData

## 辅助索引（用于快速查询）
var _scope_index: Dictionary = {     ## scope -> Array[String]
	VariableScope.LOCAL: [],
	VariableScope.GLOBAL: []
}
var _persistent_index: Array[String] = []  ## 持久化变量名列表
var _runtime_index: Array[String] = []     ## 运行时变量名列表

## 缓存（性能优化）
var _access_cache: Dictionary = {}   ## name -> cached_value
var _cache_enabled: bool = true
var _cache_max_size: int = 1000

## 依赖关系管理
var _variable_dependencies: Dictionary = {}  ## 变量依赖关系

## 已弃用变量（保持向后兼容，标记为 deprecated）
var _local_variables: Dictionary = {}: setget # Deprecated: 使用 _variables_data
var _global_variables: Dictionary = {}: setget # Deprecated: 使用 _variables_data
var _trigger_variables: Dictionary = {}: setget # Deprecated: TRIGGER 作用域已移除
var _runtime_variables: Dictionary = {}: setget # Deprecated: 使用 _runtime_index
var _persistent_variables: Dictionary = {}: setget # Deprecated: 使用 _persistent_index
var _variable_name_to_index: Dictionary = {}: setget # Deprecated
var _indexed_variables: Array = []: setget    # Deprecated
var _use_indexed_storage: bool = false: setget # Deprecated
var _enable_cache: bool = false: setget       # Deprecated: 使用 _cache_enabled
var _variable_cache: Dictionary = {}: setget  # Deprecated: 使用 _access_cache
```

**Step 2.3: 添加统一的数据访问方法**

在 `variable_container.gd` 中添加新方法（约第 130 行后）:

```gdscript
## 统一的数据访问方法（内部使用）
func _get_variable_data(name: String) -> VariableData:
	"""获取变量的数据对象"""
	if not _variables_data.has(name):
		return null
	return _variables_data[name]

func _set_variable_data(name: String, data: VariableData):
	"""设置变量的数据对象（更新索引）"""
	# 从旧索引中移除
	_remove_from_indices(name)

	# 添加到主存储
	_variables_data[name] = data

	# 更新索引
	_add_to_indices(name, data)

	# 清除缓存
	_invalidate_cache(name)

func _remove_from_indices(name: String):
	"""从所有索引中移除变量名"""
	var old_data = _variables_data.get(name)
	if old_data:
		_scope_index[old_data.scope].erase(name)
		if name in _persistent_index:
			_persistent_index.erase(name)
		if name in _runtime_index:
			_runtime_index.erase(name)

func _add_to_indices(name: String, data: VariableData):
	"""将变量名添加到索引"""
	_scope_index[data.scope].append(name)
	if data.persistent:
		_persistent_index.append(name)
	else:
		_runtime_index.append(name)

func _invalidate_cache(name: String):
	"""清除变量缓存"""
	if _cache_enabled and _access_cache.has(name):
		_access_cache.erase(name)

	# LRU 缓存大小控制
	if _access_cache.size() > _cache_max_size:
		var keys = _access_cache.keys()
		for i in range(_cache_max_size / 10):
			_access_cache.erase(keys[i])
```

**Step 2.4: 重写 `add_variable` 方法**

替换 [variable_container.gd:90-128](addons/bricks/core/base/variable_container.gd#L90-L128):

```gdscript
func add_variable(name: String, value: Variant, scope: VariableScope = VariableScope.LOCAL, persistent: bool = false) -> bool:
	if name.is_empty():
		_log_error("变量名称不能为空")
		return false

	# 检查变量是否已存在
	if _variables_data.has(name):
		_log_error("变量 '%s' 已存在" % name)
		return false

	# 创建变量数据
	var var_data = VariableData.new()
	var_data.value = value
	var_data.type = typeof(value)
	var_data.scope = scope
	var_data.persistent = persistent
	var_data.timestamp = Time.get_ticks_msec()
	var_data.last_modified = var_data.timestamp

	# 使用统一的方法设置
	_set_variable_data(name, var_data)

	_log_debug("添加变量: %s (作用域: %s, 类型: %s, 持久化: %s)" % [
		name, VariableScope.keys()[scope], type_string(typeof(value)), persistent
	])

	return true
```

**Step 2.5: 重写 `get_variable` 方法**

替换 [variable_container.gd:142-174](addons/bricks/core/base/variable_container.gd#L142-L174):

```gdscript
func get_variable(name: String, default_value: Variant = null, scope: VariableScope = VariableScope.LOCAL, use_cache: bool = true) -> Variant:
	if name.is_empty():
		print("[ERROR][VariableContainer] 变量名称不能为空")
		return default_value

	# 使用缓存
	if use_cache and _cache_enabled:
		if _access_cache.has(name):
			# 增加访问计数
			var data = _variables_data.get(name)
			if data:
				data.access_count += 1
			return _access_cache[name]

	# 从主存储获取
	var data = _get_variable_data(name)
	if data:
		var value = data.value

		# 更新缓存
		if use_cache and _cache_enabled:
			_access_cache[name] = value

		# 增加访问计数
		data.access_count += 1

		return value

	# 变量不存在，返回默认值
	return default_value
```

**Step 2.6: 重写 `set_variable` 方法**

替换 [variable_container.gd:188-193](addons/bricks/core/base/variable_container.gd#L188-L193):

```gdscript
func set_variable(name: String, value: Variant, scope: VariableScope = VariableScope.LOCAL, auto_create: bool = false) -> bool:
	if name.is_empty():
		_log_error("变量名称不能为空")
		return false

	var data = _get_variable_data(name)

	if not data:
		# 变量不存在
		if auto_create:
			return add_variable(name, value, scope, false)
		else:
			_log_error("变量 '%s' 不存在" % name)
			return false

	# 更新变量值
	data.value = value
	data.type = typeof(value)
	data.modification_count += 1
	data.last_modified = Time.get_ticks_msec()

	# 清除缓存
	_invalidate_cache(name)

	_log_debug("更新变量: %s = %s" % [name, str(value)])
	return true
```

**Step 2.7: 重写 `remove_variable` 方法**

替换 [variable_container.gd:205-220](addons/bricks/core/base/variable_container.gd#L205-L220):

```gdscript
func remove_variable(name: String, scope: VariableScope = VariableScope.LOCAL) -> bool:
	if name.is_empty():
		print("[ERROR][VariableContainer] 变量名称不能为空")
		return false

	var data = _get_variable_data(name)
	if not data:
		_log_warning("变量 '%s' 不存在" % name)
		return false

	# 从索引中移除
	_remove_from_indices(name)

	# 从主存储删除
	_variables_data.erase(name)

	# 清除缓存
	_invalidate_cache(name)

	_log_debug("删除变量: %s" % name)
	return true
```

**Step 2.8: 重写 `has_variable` 方法**

替换 [variable_container.gd:232-233](addons/bricks/core/base/variable_container.gd#L232-L233):

```gdscript
func has_variable(name: String, scope: VariableScope = VariableScope.LOCAL) -> bool:
	return _variables_data.has(name)
```

**Step 2.9: 更新 `get_variable_names` 方法**

替换 [variable_container.gd:281-291](addons/bricks/core/base/variable_container.gd#L281-L291):

```gdscript
func get_variable_names(scope: VariableScope = VariableScope.LOCAL) -> Array[String]:
	if scope < 0 or scope >= VariableScope.size():
		_log_error("不支持的作用域: %s" % str(scope))
		return []

	return _scope_index[scope].duplicate()
```

**Step 2.10: 创建迁移测试**

创建文件 `addons/bricks/tests/test_variable_storage_migration.gd`:

```gdscript
extends Node

## 测试 VariableContainer 存储迁移

func _ready():
	test_unified_storage()

func test_unified_storage():
	print("=== 测试 VariableContainer 统一存储 ===")

	var container = VariableContainer.new()

	# 测试添加变量
	assert(container.add_variable("test_local", 100, VariableContainer.VariableScope.LOCAL, false), "添加局部变量失败")
	assert(container.add_variable("test_global", 200, VariableContainer.VariableScope.GLOBAL, true), "添加全局变量失败")
	print("✓ 添加变量成功")

	# 测试获取变量
	var local_value = container.get_variable("test_local")
	assert(local_value == 100, "获取局部变量失败")
	var global_value = container.get_variable("test_global")
	assert(global_value == 200, "获取全局变量失败")
	print("✓ 获取变量成功")

	# 测试变量名列表
	var local_names = container.get_variable_names(VariableContainer.VariableScope.LOCAL)
	assert("test_local" in local_names, "局部变量名列表不包含 test_local")
	var global_names = container.get_variable_names(VariableContainer.VariableScope.GLOBAL)
	assert("test_global" in global_names, "全局变量名列表不包含 test_global")
	print("✓ 变量名列表正确")

	# 测试更新变量
	assert(container.set_variable("test_local", 150), "更新局部变量失败")
	assert(container.get_variable("test_local") == 150, "更新后的值不正确")
	print("✓ 更新变量成功")

	# 测试删除变量
	assert(container.remove_variable("test_local"), "删除局部变量失败")
	assert(not container.has_variable("test_local"), "变量应该被删除")
	print("✓ 删除变量成功")

	# 测试持久化索引
	var persistent_vars = container._persistent_index
	assert("test_global" in persistent_vars, "持久化索引不包含 test_global")
	print("✓ 持久化索引正确")

	print("✓ 所有存储测试通过")
```

**Step 2.11: 运行测试验证**

```bash
# 在 Godot 编辑器中运行测试场景
```

预期输出: 所有测试通过，数据一致性良好

**Step 2.12: 提交修复**

```bash
git add addons/bricks/core/base/variable_container.gd addons/bricks/tests/test_variable_storage_migration.gd
git commit -m "refactor(variable-container): 统一变量存储策略，修复数据不一致问题

- 创建单一数据源 _variables_data
- 使用索引优化查询性能
- 实现缓存机制提高访问速度
- 保持向后兼容性
- 添加测试用例验证数据一致性

Fixes #2 - VariableContainer 多套存储数据不一致"
```

---

## Task 3: 改进 BaseVariable 持久化序列化

**严重程度:** Critical
**影响范围:** [base_variable.gd:212,256-289](addons/bricks/core/base/base_variable.gd#L212-L256-L289)

**问题分析:**
使用 `str(value)` 序列化变量值不可靠，特别是对于复杂对象、数组和字典。反序列化时使用字符串解析容易失败。

**修复策略:**
1. 使用 JSON 序列化复杂类型
2. 改进 Vector2/Vector3/Color 解析
3. 添加类型标记和验证
4. 处理序列化失败情况

**Step 3.1: 改进 `_save_to_storage` 方法**

替换 [base_variable.gd:198-222](addons/bricks/core/base/base_variable.gd#L198-L222):

```gdscript
func _save_to_storage():
	if not persistent:
		_log_debug("变量未启用持久化，跳过保存")
		return

	var config = ConfigFile.new()

	# 加载现有配置
	if FileAccess.file_exists(STORAGE_CONFIG_PATH):
		var error = config.load(STORAGE_CONFIG_PATH)
		if error != OK:
			_log_warning("加载现有配置失败: %d，将覆盖" % error)

	# 使用改进的序列化方法
	var serialize_result = _serialize_value(value)
	if not serialize_result.success:
		_log_error("序列化变量 '%s' 失败: %s" % [variable_name, serialize_result.error_message])
		return

	config.set_value(STORAGE_SECTION, variable_name, serialize_result.value)
	config.set_value(STORAGE_SECTION, "%s_type" % variable_name, serialize_result.type_name)
	config.set_value(STORAGE_SECTION, "%s_modified" % variable_name, last_modified_time)
	config.set_value(STORAGE_SECTION, "%s_count" % variable_name, modification_count)

	# 保存到文件
	var error = config.save(STORAGE_CONFIG_PATH)
	if error == OK:
		_log_debug("变量 '%s' 已保存到持久化存储" % variable_name)
	else:
		_log_error("保存变量 '%s' 失败: %d" % [variable_name, error])
```

**Step 3.2: 添加 `_serialize_value` 方法**

在 `base_variable.gd` 中添加新方法（约第 223 行后）:

```gdscript
## 序列化变量值
## returns: Dictionary - {success: bool, value: Variant, type_name: String, error_message: String}
func _serialize_value(val: Variant) -> Dictionary:
	var result = {
		"success": true,
		"value": null,
		"type_name": "",
		"error_message": ""
	}

	var type = typeof(val)
	result.type_name = type_string(type)

	match type:
		TYPE_NIL:
			result.value = "null"
		TYPE_BOOL:
			result.value = "true" if val else "false"
		TYPE_INT, TYPE_FLOAT, TYPE_STRING:
			result.value = str(val)
		TYPE_VECTOR2:
			# 格式: "(x, y)"
			result.value = "(%f, %f)" % [val.x, val.y]
		TYPE_VECTOR3:
			# 格式: "(x, y, z)"
			result.value = "(%f, %f, %f)" % [val.x, val.y, val.z]
		TYPE_VECTOR4:
			# 格式: "(x, y, z, w)"
			result.value = "(%f, %f, %f, %f)" % [val.x, val.y, val.z, val.w]
		TYPE_COLOR:
			# 格式: "(r, g, b, a)"
			result.value = "(%f, %f, %f, %f)" % [val.r, val.g, val.b, val.a]
		TYPE_ARRAY:
			# 使用 JSON 序列化数组
			var json = JSON.new()
			var error = json.stringify(val)
			if error == OK:
				result.value = json.get_data()
			else:
				result.success = false
				result.error_message = "数组 JSON 序列化失败"
		TYPE_DICTIONARY:
			# 使用 JSON 序列化字典
			var json = JSON.new()
			var error = json.stringify(val)
			if error == OK:
				result.value = json.get_data()
			else:
				result.success = false
				result.error_message = "字典 JSON 序列化失败"
		TYPE_PACKED_BYTE_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, \
		TYPE_PACKED_STRING_ARRAY, TYPE_PACKED_VECTOR2_ARRAY, TYPE_PACKED_VECTOR3_ARRAY:
			# PackedArray 使用 JSON 序列化
			var json = JSON.new()
			var error = json.stringify(Array(val))
			if error == OK:
				result.value = json.get_data()
			else:
				result.success = false
				result.error_message = "PackedArray JSON 序列化失败"
		TYPE_OBJECT:
			# 对象序列化
			if val has_method("serialize"):
				var obj_data = val.serialize()
				var json = JSON.new()
				var error = json.stringify(obj_data)
				if error == OK:
					result.value = json.get_data()
				else:
					result.success = false
					result.error_message = "对象数据 JSON 序列化失败"
			else:
				result.value = str(val)
				_log_warning("对象无 serialize 方法，使用 str() 序列化")
		_:
			# 默认使用 str()
			result.value = str(val)
			_log_warning("未知类型 %s，使用 str() 序列化" % type_string(type))

	return result
```

**Step 3.3: 改进 `_parse_value_from_string` 方法**

替换 [base_variable.gd:257-289](addons/bricks/core/base/base_variable.gd#L257-L289):

```gdscript
func _parse_value_from_string(value_str: String, type_str: String) -> Variant:
	match type_str:
		"Null":
			return null
		"Bool":
			# 改进的布尔解析
			var lower_str = value_str.to_lower()
			if lower_str == "true" or lower_str == "1":
				return true
			elif lower_str == "false" or lower_str == "0":
				return false
			else:
				_log_warning("无法解析布尔值: '%s'，使用 false" % value_str)
				return false
		"Int":
			return int(value_str)
		"Float":
			return float(value_str)
		"String":
			return value_str
		"Vector2":
			# 改进的 Vector2 解析（支持多种格式）
			return _parse_vector2(value_str)
		"Vector3":
			return _parse_vector3(value_str)
		"Vector4":
			return _parse_vector4(value_str)
		"Color":
			return _parse_color(value_str)
		"Array":
			return _parse_json_array(value_str)
		"Dictionary":
			return _parse_json_dict(value_str)
		_:
			# 尝试 JSON 解析
			var json = JSON.new()
			var error = json.parse(value_str)
			if error == OK:
				return json.get_data()
			else:
				# 默认：尝试 str_to_var
				var result = str_to_var(value_str)
				if result == null:
					_log_warning("无法解析值 '%s' (类型: %s)，使用默认值" % [value_str, type_str])
				return result
```

**Step 3.4: 添加辅助解析方法**

在 `base_variable.gd` 中添加解析辅助方法（约第 290 行后）:

```gdscript
## 解析 Vector2
func _parse_vector2(value_str: String) -> Vector2:
	# 移除括号和空格
	var cleaned = value_str.replace("(", "").replace(")", "").replace(" ", "")
	var parts = cleaned.split_floats(",")
	if parts.size() >= 2:
		return Vector2(parts[0], parts[1])
	else:
		_log_warning("Vector2 解析失败: '%s'" % value_str)
		return Vector2.ZERO

## 解析 Vector3
func _parse_vector3(value_str: String) -> Vector3:
	var cleaned = value_str.replace("(", "").replace(")", "").replace(" ", "")
	var parts = cleaned.split_floats(",")
	if parts.size() >= 3:
		return Vector3(parts[0], parts[1], parts[2])
	else:
		_log_warning("Vector3 解析失败: '%s'" % value_str)
		return Vector3.ZERO

## 解析 Vector4
func _parse_vector4(value_str: String) -> Vector4:
	var cleaned = value_str.replace("(", "").replace(")", "").replace(" ", "")
	var parts = cleaned.split_floats(",")
	if parts.size() >= 4:
		return Vector4(parts[0], parts[1], parts[2], parts[3])
	else:
		_log_warning("Vector4 解析失败: '%s'" % value_str)
		return Vector4.ZERO

## 解析 Color
func _parse_color(value_str: String) -> Color:
	var cleaned = value_str.replace("(", "").replace(")", "").replace(" ", "")
	var parts = cleaned.split_floats(",")
	if parts.size() >= 4:
		return Color(parts[0], parts[1], parts[2], parts[3])
	elif parts.size() == 3:
		return Color(parts[0], parts[1], parts[2], 1.0)
	else:
		_log_warning("Color 解析失败: '%s'" % value_str)
		return Color.WHITE

## 解析 JSON 数组
func _parse_json_array(value_str: String) -> Array:
	var json = JSON.new()
	var error = json.parse(value_str)
	if error == OK and json.get_data() is Array:
		return json.get_data()
	else:
		_log_warning("JSON 数组解析失败: '%s'" % value_str)
		return []

## 解析 JSON 字典
func _parse_json_dict(value_str: String) -> Dictionary:
	var json = JSON.new()
	var error = json.parse(value_str)
	if error == OK and json.get_data() is Dictionary:
		return json.get_data()
	else:
		_log_warning("JSON 字典解析失败: '%s'" % value_str)
		return {}
```

**Step 3.5: 更新 `_load_from_storage` 方法**

替换 [base_variable.gd:225-254](addons/bricks/core/base/base_variable.gd#L225-L254):

```gdscript
func _load_from_storage():
	if not FileAccess.file_exists(STORAGE_CONFIG_PATH):
		_log_debug("持久化存储文件不存在，跳过加载")
		return

	var config = ConfigFile.new()
	var error = config.load(STORAGE_CONFIG_PATH)

	if error != OK:
		_log_error("加载持久化存储失败: %d" % error)
		return

	# 检查变量是否存在
	if config.has_section_key(STORAGE_SECTION, variable_name):
		var value_str = config.get_value(STORAGE_SECTION, variable_name, "")
		var type_str = config.get_value(STORAGE_SECTION, "%s_type" % variable_name, "")

		# 使用改进的解析方法
		value = _parse_value_from_string(value_str, type_str)

		var modified = config.get_value(STORAGE_SECTION, "%s_modified" % variable_name, 0.0)
		last_modified_time = modified

		var count = config.get_value(STORAGE_SECTION, "%s_count" % variable_name, 0)
		modification_count = count

		is_initialized = true
		_log_debug("变量 '%s' 已从持久化存储加载: %s" % [variable_name, str(value)])
	else:
		_log_debug("变量 '%s' 不在持久化存储中" % variable_name)
```

**Step 3.6: 创建序列化测试**

创建文件 `addons/bricks/tests/test_variable_serialization.gd`:

```gdscript
extends Node

## 测试 BaseVariable 持久化序列化

func _ready():
	test_serialization()

func test_serialization():
	print("=== 测试 BaseVariable 序列化 ===")

	# 删除旧的持久化文件
	var test_storage = "user://test_variables.cfg"
	if FileAccess.file_exists(test_storage):
		DirAccess.remove_absolute(test_storage)

	# 临时覆盖存储路径
	BaseVariable.STORAGE_CONFIG_PATH = test_storage

	# 测试基本类型
	test_primitive_serialization()

	# 测试 Vector 类型
	test_vector_serialization()

	# 测试复杂类型
	test_complex_serialization()

	print("✓ 所有序列化测试通过")

func test_primitive_serialization():
	var var_bool = BaseVariable.create("test_bool", true)
	var_bool.persistent = true
	var_bool._save_to_storage()

	var var_int = BaseVariable.create("test_int", 42)
	var_int.persistent = true
	var_int._save_to_storage()

	var var_float = BaseVariable.create("test_float", 3.14)
	var_float.persistent = true
	var_float._save_to_storage()

	var var_string = BaseVariable.create("test_string", "hello")
	var_string.persistent = true
	var_string._save_to_storage()

	print("✓ 基本类型序列化测试通过")

func test_vector_serialization():
	var var_vec2 = BaseVariable.create("test_vec2", Vector2(1.5, 2.5))
	var_vec2.persistent = true
	var_vec2._save_to_storage()

	var var_vec3 = BaseVariable.create("test_vec3", Vector3(1.0, 2.0, 3.0))
	var_vec3.persistent = true
	var_vec3._save_to_storage()

	var var_color = BaseVariable.create("test_color", Color(0.5, 0.7, 0.9, 1.0))
	var_color.persistent = true
	var_color._save_to_storage()

	print("✓ Vector 类型序列化测试通过")

func test_complex_serialization():
	var var_array = BaseVariable.create("test_array", [1, 2, 3, "four"])
	var_array.persistent = true
	var_array._save_to_storage()

	var var_dict = BaseVariable.create("test_dict", {"key": "value", "number": 42})
	var_dict.persistent = true
	var_dict._save_to_storage()

	print("✓ 复杂类型序列化测试通过")
```

**Step 3.7: 运行测试验证**

```bash
# 在 Godot 编辑器中运行测试场景
```

预期输出: 所有序列化测试通过

**Step 3.8: 提交修复**

```bash
git add addons/bricks/core/base/base_variable.gd addons/bricks/tests/test_variable_serialization.gd
git commit -m "fix(base-variable): 改进持久化序列化，使用 JSON 和类型化解析

- 添加 _serialize_value 方法支持所有类型
- 使用 JSON 序列化数组和字典
- 改进 Vector2/3/4 和 Color 解析
- 添加类型验证和错误处理
- 添加序列化测试用例

Fixes #3 - BaseVariable 持久化序列化不可靠"
```

---

## Task 4: 优化 BaseInstruction 异步检测

**严重程度:** Important
**影响范围:** [base_instruction.gd:711-779](addons/bricks/core/base/base_instruction.gd#L711-L779)

**问题分析:**
使用字符串搜索检测异步指令容易误判，需要使用更可靠的执行时检测机制。

**修复策略:**
1. 添加明确的同步/异步标记接口
2. 使用执行时检测替代静态分析
3. 缓存检测结果提高性能

**Step 4.1: 添加同步能力标记**

在 `base_instruction.gd` 中添加类变量（约第 40 行后）:

```gdscript
var _is_synchronous_hint: bool = false  ## 子类可以设置此标记提示是否同步
var _sync_capability_cached: bool = false  ## 缓存的同步能力
var _sync_capability_detected: bool = false  ## 是否已检测同步能力
```

**Step 4.2: 添加 `_is_synchronous` 虚方法**

在 `base_instruction.gd` 中添加虚方法（约第 100 行后）:

```gdscript
## 子类可以重写此方法明确声明是否为同步指令
## returns: bool - true 表示同步，false 表示异步
func _is_synchronous() -> bool:
	return _is_synchronous_hint
```

**Step 4.3: 改进 `_has_async_operations` 方法**

替换 [base_instruction.gd:711-779](addons/bricks/core/base/base_instruction.gd#L711-L779) 中的异步检测逻辑:

```gdscript
func _has_async_operations() -> bool:
	# 优先使用明确的标记
	if _sync_capability_detected:
		return not _sync_capability_cached

	# 检查子类是否重写了 _is_synchronous
	var default_method = BaseInstruction.get_method("_is_synchronous")
	var current_method = get_method("_is_synchronous")

	if current_method != default_method:
		# 子类重写了方法，使用其返回值
		_sync_capability_cached = _is_synchronous()
		_sync_capability_detected = true
		return not _sync_capability_cached

	# 未重写，使用旧方法检测（向后兼容）
	var script = get_script()
	if script:
		var source = script.source_code
		if source:
			# 检查是否使用 await
			if " await " in source or "\await " in source:
				_sync_capability_cached = false
				_sync_capability_detected = true
				return true

			# 检查是否有异步信号等待模式
			if "await finished" in source or "await completed" in source:
				_sync_capability_cached = false
				_sync_capability_detected = true
				return true

	# 默认假设为同步
	_sync_capability_cached = true
	_sync_capability_detected = true
	return false
```

**Step 4.4: 添加 `set_synchronous_hint` 方法**

在 `base_instruction.gd` 中添加辅助方法（约第 780 行后）:

```gdscript
## 设置同步提示（供子类或工厂使用）
func set_synchronous_hint(is_sync: bool):
	_is_synchronous_hint = is_sync
	_sync_capability_detected = false  # 重置缓存
```

**Step 4.5: 更新文档注释**

在 `base_instruction.gd` 中添加文档说明异步检测机制（约第 50 行后）:

```gdscript
## 异步执行检测机制
##
## 子类可以通过以下方式声明异步行为：
## 1. 重写 _is_synchronous() 方法返回 true/false
## 2. 调用 set_synchronous_hint(true/false) 设置提示
## 3. 在 execute() 中使用 await（自动检测）
##
## 示例：
## ```gdscript
## class MySyncInstruction extends BaseInstruction
##     func _is_synchronous():
##         return true  # 明确声明为同步
##
## class MyAsyncInstruction extends BaseInstruction
##     func execute(context):
##         await some_async_operation()
##         _on_execution_completed()
## ```
```

**Step 4.6: 提交修复**

```bash
git add addons/bricks/core/base/base_instruction.gd
git commit -m "refactor(base-instruction): 改进异步检测机制

- 添加 _is_synchronous() 虚方法供子类重写
- 添加 set_synchronous_hint() 辅助方法
- 使用执行时检测替代静态字符串搜索
- 缓存检测结果提高性能
- 向后兼容旧代码

Fixes #4 - BaseInstruction 异步检测不准确"
```

---

## Task 5: 限制 ExecutionContext StringName 缓存大小

**严重程度:** Important
**影响范围:** [execution_context.gd:54-57,1062-1065](addons/bricks/core/base/execution_context.gd#L54-L57-L1062-L1065)

**问题分析:**
`_variable_name_cache` 无限增长，对于长期运行的 ExecutionContext 可能导致内存占用过高。

**修复策略:**
1. 添加缓存大小限制
2. 使用 LRU 策略清理旧缓存
3. 在 cleanup 时清理缓存

**Step 5.1: 添加缓存大小限制**

修改 [execution_context.gd:54-57](addons/bricks/core/base/execution_context.gd#L54-L57):

```gdscript
var _variable_name_cache: Dictionary = {}
var _cache_max_size: int = 1000  ## 缓存最大大小
var _cache_access_order: Array = []  ## LRU 访问顺序记录
```

**Step 5.2: 改进 `_get_cached_name_key` 方法**

替换 [execution_context.gd:1062-1065](addons/bricks/core/base/execution_context.gd#L1062-L1065) 的实现:

```gdscript
func _get_cached_name_key(name: String) -> StringName:
	# 检查缓存大小限制
	if _variable_name_cache.size() >= _cache_max_size:
		# LRU 清理：删除最旧的 20%
		var remove_count = _cache_max_size / 5
		for i in range(remove_count):
			if _cache_access_order.size() > 0:
				var old_name = _cache_access_order[0]
				_variable_name_cache.erase(old_name)
				_cache_access_order.pop_front()

	# 更新访问顺序
	if name in _cache_access_order:
		_cache_access_order.erase(name)
	_cache_access_order.append(name)

	# 创建或获取缓存
	if not _variable_name_cache.has(name):
		_variable_name_cache[name] = StringName(name)

	return _variable_name_cache[name]
```

**Step 5.3: 确保 cleanup 清理缓存**

验证 [execution_context.gd:471-474](addons/bricks/core/base/execution_context.gd#L471-L474) 已包含缓存清理（已存在）:

```gdscript
# 清理优化相关的缓存
_variable_name_cache.clear()
_variable_index_map.clear()
_variable_array.clear()
_use_indexed_access = false
```

**Step 5.4: 提交修复**

```bash
git add addons/bricks/core/base/execution_context.gd
git commit -m "fix(execution_context): 添加 StringName 缓存大小限制

- 添加 _cache_max_size 限制缓存大小为 1000
- 实现 LRU 缓存清理策略
- 使用 _cache_access_order 跟踪访问顺序
- 防止缓存无限增长

Fixes #5 - ExecutionContext StringName 缓存无限增长"
```

---

## Task 6: 改进 ActionRunner 超时检查

**严重程度:** Important
**影响范围:** [action_runner.gd:379-392](addons/bricks/core/base/action_runner.gd#L379-L392)

**问题分析:**
超时检查使用固定的 30 秒，没有考虑指令数量和复杂度。

**修复策略:**
1. 根据指令数量动态计算超时
2. 支持配置每个指令的超时时间
3. 改进超时日志

**Step 6.1: 改进 `_check_timeout` 方法**

替换 [action_runner.gd:382-392](addons/bricks/core/base/action_runner.gd#L382-L392):

```gdscript
func _check_timeout(context: ExecutionContext) -> bool:
	# 计算有效超时时间
	var effective_timeout: float
	if enable_instruction_timeout and instruction_timeout > 0:
		# 使用单个指令超时 * 指令数作为总超时
		effective_timeout = instruction_timeout * max(1, instructions.size())
	else:
		# 默认超时：基础时间 + 每个指令额外时间
		effective_timeout = DEFAULT_TIMEOUT + (instructions.size() * 5.0)

	var elapsed = Time.get_ticks_msec() / 1000.0 - execution_start_time
	if elapsed > effective_timeout:
		_log_error("执行超时: %.2f 秒 (限制: %.2f 秒, 指令数: %d)" % [
			elapsed, effective_timeout, instructions.size()
		])
		_create_bricks_error("执行超时 (%.2f 秒)" % effective_timeout, BricksError.ErrorType.TIMEOUT_ERROR, {
			"elapsed_time": elapsed,
			"timeout_duration": effective_timeout,
			"instruction_count": instructions.size()
		})
		execution_failed.emit("Execution timeout after %.2f seconds" % effective_timeout)
		return true
	return false
```

**Step 6.2: 提交修复**

```bash
git add addons/bricks/core/base/action_runner.gd
git commit -m "fix(action-runner): 改进超时检查逻辑

- 根据指令数量动态计算超时时间
- 支持配置单个指令超时
- 改进超时日志输出详细信息
- 默认超时 = 30秒 + 指令数 * 5秒

Fixes #6 - ActionRunner 超时检查不准确"
```

---

## Task 7: 完善 BaseCondition 缓存哈希

**严重程度:** Important
**影响范围:** [base_condition.gd:478-495](addons/bricks/core/base/base_condition.gd#L478-L495)

**问题分析:**
`_generate_context_hash()` 只依赖部分变量，可能返回错误结果。

**修复策略:**
1. 添加缓存失效配置选项
2. 改进哈希计算包含所有相关变量
3. 提供手动清除缓存方法

**Step 7.1: 添加缓存配置**

在 `base_condition.gd` 中添加成员变量（约第 40 行后）:

```gdscript
@export var cache_context_changes: bool = true  ## 是否在上下文变化时失效缓存
@export var hash_all_variables: bool = false   ## 是否包含所有变量在哈希中
```

**Step 7.2: 改进 `_generate_context_hash` 方法**

替换 [base_condition.gd:478-495](addons/bricks/core/base/base_condition.gd#L478-L495) 的实现:

```gdscript
func _generate_context_hash(context: ExecutionContext) -> int:
	if context == null:
		return 0

	var hash_value = context.execution_id.hash()

	if cache_context_changes:
		# 包含所有依赖变量
		for dep_var in _get_dependencies():
			var var_value = context.get_variable(dep_var)
			hash_value ^= (hash_value << 5) + str(var_value).hash()

		# 如果启用，包含所有上下文变量
		if hash_all_variables:
			for var_name in context.local_variables:
				var var_value = context.local_variables[var_name]
				hash_value ^= (hash_value << 3) + str(var_value).hash()

	return hash_value
```

**Step 7.3: 添加缓存清除方法**

在 `base_condition.gd` 中添加方法（约第 496 行后）:

```gdscript
## 手动清除结果缓存
func clear_result_cache():
	_result_cache.clear()
	_log_debug("条件 '%s' 结果缓存已清除" % condition_name)

## 清除特定上下文的缓存
func clear_context_cache(context: ExecutionContext):
	if context:
		var hash = _generate_context_hash(context)
		_result_cache.erase(hash)
		_log_debug("条件 '%s' 上下文缓存已清除" % condition_name)
```

**Step 7.4: 提交修复**

```bash
git add addons/bricks/core/base/base_condition.gd
git commit -m "fix(base-condition): 完善缓存哈希计算

- 添加 cache_context_changes 配置选项
- 添加 hash_all_variables 包含所有变量
- 改进 _generate_context_hash 计算逻辑
- 添加 clear_result_cache 和 clear_context_cache 方法

Fixes #7 - BaseCondition 缓存哈希计算不完整"
```

---

## 总结

### 修复完成检查清单

- [ ] Task 1: ActionRunner 信号连接内存泄漏修复
- [ ] Task 2: VariableContainer 统一存储策略
- [ ] Task 3: BaseVariable 持久化序列化改进
- [ ] Task 4: BaseInstruction 异步检测优化
- [ ] Task 5: ExecutionContext 缓存大小限制
- [ ] Task 6: ActionRunner 超时检查改进
- [ ] Task 7: BaseCondition 缓存哈希完善

### 测试要求

每个 Task 完成后必须运行相应测试：
- 信号清理测试: `test_signal_cleanup.gd`
- 存储迁移测试: `test_variable_storage_migration.gd`
- 序列化测试: `test_variable_serialization.gd`

### 提交规范

每个修复应独立提交：
```bash
git add <相关文件>
git commit -m "fix/scope: 简短描述

详细说明
- 改进点1
- 改进点2

Fixes #问题编号 - 简短标题"
```

### 验证流程

1. 运行单元测试确保功能正常
2. 在 Godot 编辑器中测试典型使用场景
3. 检查内存使用情况（特别是 Task 1 和 Task 5）
4. 验证数据持久化（Task 3）
5. 测试异步指令执行（Task 4）

---

**计划创建时间:** 2026-01-23
**预计完成时间:** 按优先级逐步完成
**Godot 版本:** 4.5
**项目分支:** Develop_brick
