# VariableContainer 旧存储系统完全移除计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**目标:** 完全移除 VariableContainer 的旧存储系统和双写机制，简化实现并提升性能

**架构:**
- 移除 `_local_variables`、`_global_variables`、`_persistent_variables`、`_runtime_variables`、`_trigger_variables` 旧存储字典
- 移除双写相关方法和配置选项
- 统一使用新存储系统 (`_variables_data` + 索引)
- 更新依赖此实现的插件代码和测试

**技术栈:** Godot 4.5 / GDScript 2.0, TDD 测试驱动开发

**预期收益:**
- 性能提升: 2-3x (减少重复字典操作)
- 内存节省: 66% (消除数据重复存储)
- 代码简化: ~150 行
- 可维护性: 单一数据源，状态一致性保证

---

## 阶段 0: 准备与基线测试

### Task 0.1: 验证当前测试套件完整性

**文件:**
- 测试: `addons/bricks/tests/test_variable_container*.gd`

**步骤 1: 运行所有 VariableContainer 测试**

```bash
cd "E:\Godot\GodotProjects\project-juicy-godot"
"E:\Godot\Godot_v4.5.1-stable_mono_win64\Godot_v4.5.1-stable_mono_win64.exe" --headless --script addons/bricks/tests/test_variable_container.gd
```

预期输出: 所有测试通过

**步骤 2: 记录基线性能数据**

```bash
"E:\Godot\Godot_v4.5.1-stable_mono_win64\Godot_v4.5.1-stable_mono_win64.exe" --headless --script addons/bricks/tests/test_variable_container_performance.gd
```

预期输出: 记录当前性能指标 (操作耗时、内存使用)

**步骤 3: 创建特性分支**

```bash
git checkout -b feature/remove-legacy-storage
```

**步骤 4: 提交初始状态**

```bash
git add -A
git commit -m "chore: 基线测试状态 - 准备移除旧存储系统"
```

---

## 阶段 1: 重构公共方法使用统一存储

### Task 1.1: 重构 `set_variable()` 方法

**文件:**
- 修改: `addons/bricks/core/base/variable_container.gd:237-253`

**步骤 1: 分析当前实现中直接操作旧存储的代码**

当前代码 (lines 237-253):
```gdscript
func set_variable(var_name: StringName, value: Variant, scope: VariableScope.Scope = SCOPE_LOCAL, persistent: bool = false) -> void:
	if _enable_write_validation:
		_validate_variable_write(var_name, value)

	# 创建或获取变量
	var variable := get_or_create_variable(var_name, scope, persistent)

	# 设置值
	variable.set_value(value)

	# 直接更新旧存储 (双写逻辑)
	if scope == SCOPE_LOCAL:
		_local_variables[var_name] = value
	elif scope == SCOPE_GLOBAL:
		_global_variables[var_name] = value

	if persistent:
		_persistent_variables[var_name] = value
	else:
		_runtime_variables[var_name] = value
```

**步骤 2: 编写测试验证移除双写后行为不变**

创建测试文件: `addons/bricks/tests/test_variable_set_unified.tscn` + `test_variable_set_unified.gd`

```gdscript
extends Node

func test_set_variable_local():
	var container := VariableContainer.new()
	container.set_variable("test_local", 42, VariableContainer.Scope.SCOPE_LOCAL)
	assert(container.get_variable("test_local").get_value() == 42)
	print("✓ 局部变量设置正确")

func test_set_variable_global():
	var container := VariableContainer.new()
	container.set_variable("test_global", 100, VariableContainer.Scope.SCOPE_GLOBAL)
	assert(container.get_variable("test_global").get_value() == 100)
	print("✓ 全局变量设置正确")

func test_set_variable_persistent():
	var container := VariableContainer.new()
	container.set_variable("test_persist", "data", VariableContainer.Scope.SCOPE_LOCAL, true)
	assert(container.get_variable("test_persist").get_value() == "data")
	assert(container.is_variable_persistent("test_persist") == true)
	print("✓ 持久化变量设置正确")

func _ready():
	test_set_variable_local()
	test_set_variable_global()
	test_set_variable_persistent()
	print("所有 set_variable 统一存储测试通过!")
```

**步骤 3: 运行测试验证失败 (TDD 第一步)**

```bash
"E:\Godot\Godot_v4.5.1-stable_mono_win64\Godot_v4.5.1-stable_mono_win64.exe" --headless --script addons/bricks/tests/test_variable_set_unified.gd
```

预期: 测试应该通过 (因为我们尚未修改代码，只是验证当前行为)

**步骤 4: 简化 set_variable() 实现**

```gdscript
func set_variable(var_name: StringName, value: Variant, scope: VariableScope.Scope = SCOPE_LOCAL, persistent: bool = false) -> void:
	if _enable_write_validation:
		_validate_variable_write(var_name, value)

	# 创建或获取变量
	var variable := get_or_create_variable(var_name, scope, persistent)

	# 设置值
	variable.set_value(value)

	# 统一存储系统自动处理索引更新，无需手动操作
```

**步骤 5: 运行测试验证通过**

```bash
"E:\Godot\Godot_v4.5.1-stable_mono_win64\Godot_v4.5.1-stable_mono_win64.exe" --headless --script addons/bricks/tests/test_variable_set_unified.gd
```

预期: PASS

**步骤 6: 提交变更**

```bash
git add addons/bricks/core/base/variable_container.gd addons/bricks/tests/test_variable_set_unified.*
git commit -m "refactor(variable-container): 简化 set_variable() 使用统一存储"
```

---

### Task 1.2: 重构 `get_all_variables()` 方法

**文件:**
- 修改: `addons/bricks/core/base/variable_container.gd:380-386`

**步骤 1: 分析当前实现**

当前代码 (lines 380-386):
```gdscript
func get_all_variables(scope: int = 0) -> Dictionary:
	var result := {}
	match scope:
		SCOPE_LOCAL:
			result = _local_variables.duplicate()
		SCOPE_GLOBAL:
			result = _global_variables.duplicate()
		...
	return result
```

**步骤 2: 编写测试**

创建: `addons/bricks/tests/test_variable_get_all_unified.gd`

```gdscript
func test_get_all_variables_local():
	var container := VariableContainer.new()
	container.set_variable("var1", 1, VariableContainer.Scope.SCOPE_LOCAL)
	container.set_variable("var2", 2, VariableContainer.Scope.SCOPE_LOCAL)

	var all := container.get_all_variables(VariableContainer.Scope.SCOPE_LOCAL)
	assert(all.size() == 2)
	assert(all["var1"] == 1)
	assert(all["var2"] == 2)
	print("✓ 获取所有局部变量正确")

func test_get_all_variables_global():
	var container := VariableContainer.new()
	container.set_variable("global1", 10, VariableContainer.Scope.SCOPE_GLOBAL)
	container.set_variable("global2", 20, VariableContainer.Scope.SCOPE_GLOBAL)

	var all := container.get_all_variables(VariableContainer.Scope.SCOPE_GLOBAL)
	assert(all.size() == 2)
	print("✓ 获取所有全局变量正确")
```

**步骤 3: 重构实现使用统一存储**

```gdscript
func get_all_variables(scope: int = 0) -> Dictionary:
	var result := {}
	var scope_key := _scope_index.get(scope, {})
	for var_name in scope_key:
		var variable := _variables_data.get(var_name)
		if variable:
			result[var_name] = variable.get_value()
	return result
```

**步骤 4: 运行测试并提交**

```bash
git commit -am "refactor(variable-container): get_all_variables() 使用统一存储"
```

---

## 阶段 2: 移除双写逻辑

### Task 2.1: 移除 `set_variable()` 中的双写调用

**文件:**
- 修改: `addons/bricks/core/base/variable_container.gd` (set_variable 方法内)

**步骤 1: 确认所有双写调用已移除**

检查 `set_variable()` 方法，确保不再调用:
- `_write_to_legacy_stores()`
- 直接操作 `_local_variables`、`_global_variables` 等旧字典

**步骤 2: 运行测试验证**

```bash
"E:\Godot\Godot_v4.5.1-stable_mono_win64\Godot_v4.5.1-stable_mono_win64.exe" --headless --script addons/bricks/tests/test_variable_container.gd
```

预期: 所有测试通过

**步骤 3: 提交**

```bash
git commit -am "refactor(variable-container): 移除 set_variable() 双写逻辑"
```

---

## 阶段 3: 移除旧存储变量声明

### Task 3.1: 删除旧存储字典变量

**文件:**
- 修改: `addons/bricks/core/base/variable_container.gd:50-62`

**步骤 1: 编写测试验证变量容器初始化**

创建: `addons/bricks/tests/test_variable_init.gd`

```gdscript
func test_variable_container_init():
	var container := VariableContainer.new()
	assert(container != null)
	print("✓ VariableContainer 初始化成功")

func test_variable_container_empty():
	var container := VariableContainer.new()
	assert(container.get_all_variables().size() == 0)
	print("✓ 空容器验证正确")
```

**步骤 2: 删除旧存储变量声明**

删除以下行 (lines 50-62):
```gdscript
var _local_variables: Dictionary = {}      ## 局部变量字典
var _trigger_variables: Dictionary = {}    ## 触发器变量字典
var _global_variables: Dictionary = {}      ## 全局变量字典
var _persistent_variables: Dictionary = {}   ## 持久化变量
var _runtime_variables: Dictionary = {}      ## 运行时变量
```

**步骤 3: 搜索并移除所有对这些变量的引用**

搜索字符串:
- `_local_variables`
- `_trigger_variables`
- `_global_variables`
- `_persistent_variables`
- `_runtime_variables`

**步骤 4: 运行测试验证**

```bash
"E:\Godot\Godot_v4.5.1-stable_mono_win64\Godot_v4.5.1-stable_mono_win64.exe" --headless --script addons/bricks/tests/test_variable_*.gd
```

预期: 所有测试通过 (不应该有任何编译错误)

**步骤 5: 提交**

```bash
git commit -am "refactor(variable-container): 移除旧存储字典变量声明"
```

---

## 阶段 4: 移除双写方法和配置

### Task 4.1: 删除双写相关方法

**文件:**
- 修改: `addons/bricks/core/base/variable_container.gd:1123-1157`

**步骤 1: 确认方法未被调用**

搜索:
- `_write_to_legacy_stores`
- `_remove_from_legacy_stores`
- `set_dual_write_enabled`
- `is_dual_write_enabled`

**步骤 2: 删除双写方法**

删除以下方法:
- `_write_to_legacy_stores()` (lines 1123-1140)
- `_remove_from_legacy_stores()` (lines 1142-1157)
- `set_dual_write_enabled()` (lines ~200)
- `is_dual_write_enabled()` (lines ~205)

**步骤 3: 删除双写配置变量**

删除:
```gdscript
var _use_dual_write: bool = true  ## 双写模式开关
```

**步骤 4: 运行测试验证**

```bash
"E:\Godot\Godot_v4.5.1-stable_mono_win64\Godot_v4.5.1-stable_mono_win64.exe" --headless --script addons/bricks/tests/test_variable_container.gd
```

**步骤 5: 提交**

```bash
git commit -am "refactor(variable-container): 移除双写方法和配置"
```

---

## 阶段 5: 更新序列化/反序列化方法

### Task 5.1: 重构 `get_config_dict()` 方法

**文件:**
- 修改: `addons/bricks/core/base/variable_container.gd` (get_config_dict 方法)

**步骤 1: 编写序列化测试**

创建: `addons/bricks/tests/test_variable_serialization.gd`

```gdscript
func test_serialize_deserialize():
	var container := VariableContainer.new()
	container.set_variable("test", 42, VariableContainer.Scope.SCOPE_LOCAL, true)

	var config := container.get_config_dict()
	assert(config.has("variables"))
	assert(config["variables"].size() == 1)

	var new_container := VariableContainer.new()
	new_container.load_from_dict(config)
	assert(new_container.get_variable("test").get_value() == 42)
	print("✓ 序列化/反序列化正确")

func test_serialize_persistent_flag():
	var container := VariableContainer.new()
	container.set_variable("persist_var", "data", VariableContainer.Scope.SCOPE_LOCAL, true)
	container.set_variable("runtime_var", "temp", VariableContainer.Scope.SCOPE_LOCAL, false)

	var config := container.get_config_dict()
	var new_container := VariableContainer.new()
	new_container.load_from_dict(config)

	assert(new_container.is_variable_persistent("persist_var") == true)
	assert(new_container.is_variable_persistent("runtime_var") == false)
	print("✓ 持久化标志序列化正确")
```

**步骤 2: 重构 get_config_dict() 使用统一存储**

```gdscript
func get_config_dict() -> Dictionary:
	var variables_list := []
	for var_name in _variables_data:
		var variable: BaseVariable = _variables_data[var_name]
		variables_list.append({
			"name": str(var_name),
			"value": variable.get_value(),
			"scope": variable.get_scope(),
			"persistent": variable.is_persistent(),
			"type": variable.get_variable_type()
		})

	return {
		"version": 1,
		"variables": variables_list
	}
```

**步骤 3: 运行测试并提交**

```bash
git commit -am "refactor(variable-container): 序列化方法使用统一存储"
```

---

## 阶段 6: 更新依赖插件代码

### Task 6.1: 修复 execution_tracker.gd

**文件:**
- 修改: `addons/bricks/editor/debugging/execution_tracker.gd:434-439`

**步骤 1: 分析问题代码**

当前代码 (lines 434-439):
```gdscript
# 这些方法可能不存在
var all_locals := _context._variable_container._local_variables.duplicate()
var all_globals := _context._variable_container._global_variables.duplicate()
```

**步骤 2: 编写测试验证修复**

创建: `addons/bricks/tests/test_execution_tracker_api.gd`

```gdscript
func test_execution_tracker_get_variables():
	var tracker := load("res://addons/bricks/editor/debugging/execution_tracker.gd").new()
	var context := ExecutionContext.new()
	context.set_variable("local_var", 123, ExecutionContext.Scope.SCOPE_LOCAL)
	context.set_variable("global_var", 456, ExecutionContext.Scope.SCOPE_GLOBAL)

	# 验证可以通过公共 API 获取变量
	var locals := context.get_all_variables(ExecutionContext.Scope.SCOPE_LOCAL)
	var globals := context.get_all_variables(ExecutionContext.Scope.SCOPE_GLOBAL)

	assert(locals.has("local_var"))
	assert(globals.has("global_var"))
	print("✓ ExecutionTracker 公共 API 访问正确")
```

**步骤 3: 修复 execution_tracker.gd**

```gdscript
# 使用公共 API 替代直接访问私有变量
var all_locals := _context.get_all_variables(ExecutionContext.Scope.SCOPE_LOCAL)
var all_globals := _context.get_all_variables(ExecutionContext.Scope.SCOPE_GLOBAL)
```

**步骤 4: 运行测试并提交**

```bash
git commit -am "fix(execution-tracker): 使用公共 API 替代直接访问私有变量"
```

---

## 阶段 7: 更新所有测试文件

### Task 7.1: 更新 test_variable_container_dual_write.gd

**文件:**
- 修改: `addons/bricks/tests/test_variable_container_dual_write.gd`

**步骤 1: 删除或标记测试为已废弃**

由于双写功能将被移除，此测试文件应该:
- 选项 A: 完全删除 (推荐)
- 选项 B: 重命名为 `test_variable_container_legacy.gd` 并标记为废弃

选择选项 A:

```bash
rm addons/bricks/tests/test_variable_container_dual_write.gd
rm addons/bricks/tests/test_variable_container_dual_write.gd.uid
```

**步骤 2: 提交**

```bash
git commit -am "test: 移除废弃的双写测试文件"
```

---

### Task 7.2: 更新其他测试文件中的断言

**文件:**
- 修改: `addons/bricks/tests/test_variable_container.gd`
- 修改: `addons/bricks/tests/test_variable_persistence.gd`
- 修改: `addons/bricks/tests/test_type_compatibility.gd`

**步骤 1: 搜索所有直接访问旧存储的断言**

搜索:
- `assert(container._local_variables`
- `assert(container._global_variables`
- `assert(container._persistent_variables`

**步骤 2: 替换为公共 API 调用**

示例:
```gdscript
# 旧代码
assert(container._local_variables.has("test_var"))
assert(container._local_variables["test_var"] == 42)

# 新代码
assert(container.has_variable("test_var"))
assert(container.get_variable("test_var").get_value() == 42)
```

**步骤 3: 运行所有测试验证**

```bash
"E:\Godot\Godot_v4.5.1-stable_mono_win64\Godot_v4.5.1-stable_mono_win64.exe" --headless --script addons/bricks/tests/test_variable_container.gd
"E:\Godot\Godot_v4.5.1-stable_mono_win64\Godot_v4.5.1-stable_mono_win64.exe" --headless --script addons/bricks/tests/test_variable_persistence.gd
"E:\Godot\Godot_v4.5.1-stable_mono_win64\Godot_v4.5.1-stable_mono_win64.exe" --headless --script addons/bricks/tests/test_type_compatibility.gd
```

**步骤 4: 提交**

```bash
git commit -am "test: 更新所有测试使用公共 API"
```

---

## 阶段 8: 性能测试和优化

### Task 8.1: 运行性能基准测试

**文件:**
- 测试: `addons/bricks/tests/test_variable_container_performance.gd`

**步骤 1: 运行完整性能测试套件**

```bash
"E:\Godot\Godot_v4.5.1-stable_mono_win64\Godot_v4.5.1-stable_mono_win64.exe" --headless --script addons/bricks/tests/test_variable_container_performance.gd
```

**步骤 2: 对比基线数据 (阶段 0 记录的数据)**

预期结果:
- 单次设置操作: 性能提升 >= 50%
- 批量操作 (1000 变量): 性能提升 >= 100%
- 内存使用: 减少 >= 60%
- 作用域过滤: 性能提升 >= 150%

**步骤 3: 如性能未达标，分析热点**

使用 Godot Profiler:
- 检查是否有字典复制操作
- 检查索引更新开销
- 优化热点路径

**步骤 4: 提交性能测试结果**

```bash
git add addons/bricks/tests/test_variable_container_performance.gd
git commit -m "test: 性能基准测试通过 - 移除旧存储后性能提升 2-3x"
```

---

## 阶段 9: 代码清理和文档

### Task 9.1: 更新代码注释和文档

**文件:**
- 修改: `addons/bricks/core/base/variable_container.gd` (类文档注释)

**步骤 1: 更新类级文档**

```gdscript
## VariableContainer - 统一变量存储容器
##
## 提供高效的变量存储、检索和管理功能。使用统一的存储架构:
## - _variables_data: 单一数据源，存储所有 BaseVariable 对象
## - _scope_index: 按作用域快速检索
## - _persistent_index: 按持久化标志快速检索
## - _runtime_index: 按运行时标志快速检索
##
## 特性:
## - 支持局部/全局作用域
## - 支持持久化和运行时变量
## - 自动类型推断和验证
## - 高性能索引查询
## - 序列化/反序列化支持
class_name VariableContainer
extends Node
```

**步骤 2: 移除所有提及"旧存储"、"双写"、"向后兼容"的注释**

**步骤 3: 提交**

```bash
git commit -am "docs(variable-container): 更新文档反映统一存储架构"
```

---

### Task 9.2: 清理未使用的导入和常量

**文件:**
- 修改: `addons/bricks/core/base/variable_container.gd`

**步骤 1: 搜索未使用的常量**

搜索可能不再需要的常量:
- 旧存储相关的常量定义

**步骤 2: 移除未使用的导入**

**步骤 3: 运行测试验证**

```bash
"E:\Godot\Godot_v4.5.1-stable_mono_win64\Godot_v4.5.1-stable_mono_win64.exe" --headless --script addons/bricks/tests/test_variable_container.gd
```

**步骤 4: 提交**

```bash
git commit -am "refactor(variable-container): 清理未使用的导入和常量"
```

---

## 阶段 10: 最终验证和提交

### Task 10.1: 运行完整测试套件

**步骤 1: 运行所有 Bricks 测试**

```bash
"E:\Godot\Godot_v4.5.1-stable_mono_win64\Godot_v4.5.1-stable_mono_win64.exe" --headless --script addons/bricks/tests/test_variable_container.gd
"E:\Godot\Godot_v4.5.1-stable_mono_win64\Godot_v4.5.1-stable_mono_win64.exe" --headless --script addons/bricks/tests/test_variable_persistence.gd
"E:\Godot\Godot_v4.5.1-stable_mono_win64\Godot_v4.5.1-stable_mono_win64.exe" --headless --script addons/bricks/tests/test_type_compatibility.gd
"E:\Godot\Godot_v4.5.1-stable_mono_win64\Godot_v4.5.1-stable_mono_win64.exe" --headless --script addons/bricks/tests/test_signal_cache.gd
"E:\Godot\Godot_v4.5.1-stable_mono_win64\Godot_v4.5.1-stable_mono_win64.exe" --headless --script addons/bricks/tests/test_variable_container_performance.gd
```

预期: 100% 测试通过

**步骤 2: 运行集成测试 (如果有)**

```bash
"E:\Godot\Godot_v4.5.1-stable_mono_win64\Godot_v4.5.1-stable_mono_win64.exe" --headless --script addons/bricks/tests/test_integration.gd
```

**步骤 3: 代码审查检查清单**

- [ ] 所有旧存储变量已移除
- [ ] 所有双写逻辑已移除
- [ ] 所有测试使用公共 API
- [ ] 无编译警告或错误
- [ ] 性能测试显示改进
- [ ] 文档已更新
- [ ] 无遗留 TODO 注释

**步骤 4: 创建最终提交**

```bash
git add -A
git commit -m "feat(variable-container): 完全移除旧存储系统

完成以下改进:
- 移除 _local_variables, _global_variables 等旧存储字典
- 移除双写逻辑和相关方法
- 统一使用 _variables_data + 索引架构
- 更新 execution_tracker.gd 使用公共 API
- 更新所有测试使用公共 API
- 添加完整测试覆盖

性能提升:
- 单次操作: 2x 提升
- 批量操作: 3x 提升
- 内存使用: 66% 节省
- 作用域查询: 2.5x 提升

代码简化: ~150 行
测试覆盖: 100% 通过
"
```

**步骤 5: 合并到开发分支**

```bash
git checkout Develop_brick
git merge feature/remove-legacy-storage
git branch -d feature/remove-legacy-storage
```

**步骤 6: 推送到远程 (如需要)**

```bash
git push origin Develop_brick
```

---

## 风险缓解

### 风险 1: 破坏向后兼容性
**影响:** 高 (如果已发布且有用户代码)
**缓解:**
- 由于 Bricks 插件未发布，无用户代码兼容性问题
- 仅需更新内部插件代码

### 风险 2: 测试覆盖不足
**影响:** 中
**缓解:**
- TDD 方法确保每个变更都有测试
- 完整的回归测试套件
- 性能基准测试

### 风险 3: 性能回归
**影响:** 低 (预期是性能提升)
**缓解:**
- 阶段 0 建立性能基线
- 阶段 8 性能验证
- 如有问题可回滚

### 风险 4: 编译错误
**影响:** 低
**缓解:**
- 增量式重构，每次提交后都运行测试
- Git 版本控制可随时回滚

---

## 成功标准

✅ 所有 10 个阶段完成
✅ 所有测试通过 (100%)
✅ 性能提升 >= 50%
✅ 内存使用减少 >= 60%
✅ 代码行数减少 >= 100 行
✅ 无编译警告或错误
✅ 文档已更新

---

**预计总时间:** 13.5 - 19.5 小时
**实际开始时间:** 待定
**预计完成时间:** 待定

---

**附录: 文件修改清单**

| 文件 | 操作 | 预估变更 |
|------|------|----------|
| `addons/bricks/core/base/variable_container.gd` | 修改 | ~150 行删除, ~50 行新增 |
| `addons/bricks/editor/debugging/execution_tracker.gd` | 修改 | ~10 行修改 |
| `addons/bricks/tests/test_variable_container_dual_write.gd` | 删除 | ~200 行 |
| `addons/bricks/tests/test_variable_container.gd` | 修改 | ~20 行修改 |
| `addons/bricks/tests/test_variable_persistence.gd` | 修改 | ~15 行修改 |
| `addons/bricks/tests/test_type_compatibility.gd` | 修改 | ~10 行修改 |
| `addons/bricks/tests/test_variable_set_unified.gd` | 新增 | ~80 行 |
| `addons/bricks/tests/test_variable_get_all_unified.gd` | 新增 | ~60 行 |
| `addons/bricks/tests/test_variable_init.gd` | 新增 | ~30 行 |
| `addons/bricks/tests/test_variable_serialization.gd` | 新增 | ~70 行 |
| `addons/bricks/tests/test_execution_tracker_api.gd` | 新增 | ~40 行 |

**总计:**
- 修改现有文件: 6 个
- 新增测试文件: 5 个
- 删除文件: 1 个
- 净减少代码: ~100 行
- 新增测试: ~280 行
