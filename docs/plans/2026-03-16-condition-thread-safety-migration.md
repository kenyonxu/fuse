# Condition Thread Safety Migration Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 为 Bricks 条件系统添加线程安全支持，使更多条件能够参与并行评估。

**Architecture:** 在每个条件类中重写 `_compute_thread_safety()` 方法，根据条件的使用模式判断是否线程安全。安全的条件（不访问节点、只读取全局状态或变量）返回 `true`，参与并行评估。

**Tech Stack:** GDScript 2.0, BaseCondition 线程安全接口, Godot 4.6

---

## Phase 1: 输入条件优化 (P1)

输入条件只调用 `Input.is_action_*` API，100% 线程安全。

### Task 1.1: CheckInputPressed 线程安全

**Files:**
- Modify: `addons/bricks/conditions/input/check_input_pressed.gd`

**Step 1: 添加 `_compute_thread_safety()` 方法**

在 `_get_condition_metadata()` 方法之后添加：

```gdscript
## 计算线程安全性
## CheckInputPressed 只调用 Input.is_action_just_pressed()
## Input API 是线程安全的，不访问节点或 ExecutionContext
func _compute_thread_safety() -> bool:
	if _thread_safety_computed:
		return _thread_safety_cached

	_thread_safety_cached = true  # Input API 线程安全
	_thread_safety_computed = true
	return _thread_safety_cached
```

**Step 2: 验证语法**

Run: `E:\Godot\Godot_v4.6.1-stable_mono_win64\Godot_v4.6.1-stable_mono_win64.exe --headless --check-only --quit`
Expected: 无错误输出

**Step 3: Commit**

```bash
git add addons/bricks/conditions/input/check_input_pressed.gd
git commit -m "feat(bricks): mark CheckInputPressed as thread-safe for parallel evaluation"
```

### Task 1.2: CheckInputHeld 线程安全

**Files:**
- Modify: `addons/bricks/conditions/input/check_input_held.gd`

**Step 1: 添加 `_compute_thread_safety()` 方法**

在文件末尾（`_get_condition_metadata()` 之前）添加：

```gdscript
## 计算线程安全性
## CheckInputHeld 只调用 Input.is_action_pressed()
## Input API 是线程安全的，不访问节点或 ExecutionContext
func _compute_thread_safety() -> bool:
	if _thread_safety_computed:
		return _thread_safety_cached

	_thread_safety_cached = true  # Input API 线程安全
	_thread_safety_computed = true
	return _thread_safety_cached
```

**Step 2: 验证语法**

Run: `E:\Godot\Godot_v4.6.1-stable_mono_win64\Godot_v4.6.1-stable_mono_win64.exe --headless --check-only --quit`
Expected: 无错误输出

**Step 3: Commit**

```bash
git add addons/bricks/conditions/input/check_input_held.gd
git commit -m "feat(bricks): mark CheckInputHeld as thread-safe for parallel evaluation"
```

### Task 1.3: CheckInputReleased 线程安全

**Files:**
- Modify: `addons/bricks/conditions/input/check_input_released.gd`

**Step 1: 添加 `_compute_thread_safety()` 方法**

在文件末尾添加：

```gdscript
## 计算线程安全性
## CheckInputReleased 只调用 Input.is_action_just_released()
## Input API 是线程安全的，不访问节点或 ExecutionContext
func _compute_thread_safety() -> bool:
	if _thread_safety_computed:
		return _thread_safety_cached

	_thread_safety_cached = true  # Input API 线程安全
	_thread_safety_computed = true
	return _thread_safety_cached
```

**Step 2: 验证语法**

Run: `E:\Godot\Godot_v4.6.1-stable_mono_win64\Godot_v4.6.1-stable_mono_win64.exe --headless --check-only --quit`
Expected: 无错误输出

**Step 3: Commit**

```bash
git add addons/bricks/conditions/input/check_input_released.gd
git commit -m "feat(bricks): mark CheckInputReleased as thread-safe for parallel evaluation"
```

---

## Phase 2: 复合条件优化 (P2)

复合条件的线程安全性取决于其子条件。

### Task 2.1: CheckAll 线程安全

**Files:**
- Modify: `addons/bricks/conditions/composite/check_all.gd`

**Step 1: 添加 `_compute_thread_safety()` 方法**

在 `reset()` 方法之后添加：

```gdscript
## 计算线程安全性
## CheckAll 只有在所有子条件都线程安全时才安全
func _compute_thread_safety() -> bool:
	if _thread_safety_computed:
		return _thread_safety_cached

	var is_safe := true
	for condition in conditions:
		if condition != null and not condition.is_thread_safe:
			is_safe = false
			break

	_thread_safety_cached = is_safe
	_thread_safety_computed = true
	return _thread_safety_cached
```

**Step 2: 验证语法**

Run: `E:\Godot\Godot_v4.6.1-stable_mono_win64\Godot_v4.6.1-stable_mono_win64.exe --headless --check-only --quit`
Expected: 无错误输出

**Step 3: Commit**

```bash
git add addons/bricks/conditions/composite/check_all.gd
git commit -m "feat(bricks): add thread safety detection to CheckAll based on child conditions"
```

### Task 2.2: CheckAny 线程安全

**Files:**
- Modify: `addons/bricks/conditions/composite/check_any.gd`

**Step 1: 读取文件了解结构**

读取文件，找到 `reset()` 方法位置

**Step 2: 添加 `_compute_thread_safety()` 方法**

在适当位置添加（与 CheckAll 相同的逻辑）：

```gdscript
## 计算线程安全性
## CheckAny 只有在所有子条件都线程安全时才安全
func _compute_thread_safety() -> bool:
	if _thread_safety_computed:
		return _thread_safety_cached

	var is_safe := true
	for condition in conditions:
		if condition != null and not condition.is_thread_safe:
			is_safe = false
			break

	_thread_safety_cached = is_safe
	_thread_safety_computed = true
	return _thread_safety_cached
```

**Step 3: 验证语法**

Run: `E:\Godot\Godot_v4.6.1-stable_mono_win64\Godot_v4.6.1-stable_mono_win64.exe --headless --check-only --quit`
Expected: 无错误输出

**Step 4: Commit**

```bash
git add addons/bricks/conditions/composite/check_any.gd
git commit -m "feat(bricks): add thread safety detection to CheckAny based on child conditions"
```

### Task 2.3: CheckNot 线程安全

**Files:**
- Modify: `addons/bricks/conditions/composite/check_not.gd`

**Step 1: 读取文件了解结构**

读取文件，找到 `reset()` 方法位置

**Step 2: 添加 `_compute_thread_safety()` 方法**

```gdscript
## 计算线程安全性
## CheckNot 只有在子条件线程安全时才安全
func _compute_thread_safety() -> bool:
	if _thread_safety_computed:
		return _thread_safety_cached

	var is_safe := true
	if condition != null and not condition.is_thread_safe:
		is_safe = false

	_thread_safety_cached = is_safe
	_thread_safety_computed = true
	return _thread_safety_cached
```

**Step 3: 验证语法**

Run: `E:\Godot\Godot_v4.6.1-stable_mono_win64\Godot_v4.6.1-stable_mono_win64.exe --headless --check-only --quit`
Expected: 无错误输出

**Step 4: Commit**

```bash
git add addons/bricks/conditions/composite/check_not.gd
git commit -m "feat(bricks): add thread safety detection to CheckNot based on child condition"
```

---

## Phase 3: 集合条件优化 (P2)

集合条件的线程安全性取决于数据来源。

### Task 3.1: CheckArraySize 线程安全

**Files:**
- Modify: `addons/bricks/conditions/arrays/check_array_size.gd`

**Step 1: 添加 `_compute_thread_safety()` 方法**

在 `reset()` 方法之后添加：

```gdscript
## 计算线程安全性
## CheckArraySize 只有在 VARIABLE + LOCAL/GLOBAL 模式下才安全
## NODE_CHILDREN 和 NODE_GROUP 模式需要访问节点或 SceneTree
func _compute_thread_safety() -> bool:
	if _thread_safety_computed:
		return _thread_safety_cached

	var is_safe := false

	if source_type == SourceType.VARIABLE:
		# 只有 LOCAL 和 GLOBAL 作用域是线程安全的
		match array_scope:
			BaseVariable.VariableScope.LOCAL, BaseVariable.VariableScope.GLOBAL:
				is_safe = true
			BaseVariable.VariableScope.SCOPE:
				is_safe = false  # SCOPE 需要 ExecutionContext

	_thread_safety_cached = is_safe
	_thread_safety_computed = true
	return _thread_safety_cached
```

**Step 2: 验证语法**

Run: `E:\Godot\Godot_v4.6.1-stable_mono_win64\Godot_v4.6.1-stable_mono_win64.exe --headless --check-only --quit`
Expected: 无错误输出

**Step 3: Commit**

```bash
git add addons/bricks/conditions/arrays/check_array_size.gd
git commit -m "feat(bricks): add thread safety detection to CheckArraySize for VARIABLE mode"
```

### Task 3.2: CheckArrayContains 线程安全

**Files:**
- Modify: `addons/bricks/conditions/arrays/check_array_contains.gd`

**Step 1: 读取文件了解结构**

读取文件，找到适当位置

**Step 2: 添加 `_compute_thread_safety()` 方法**

```gdscript
## 计算线程安全性
## CheckArrayContains 只有在 VARIABLE + LOCAL/GLOBAL 模式下才安全
func _compute_thread_safety() -> bool:
	if _thread_safety_computed:
		return _thread_safety_cached

	var is_safe := false

	if source_type == SourceType.VARIABLE:
		match array_scope:
			BaseVariable.VariableScope.LOCAL, BaseVariable.VariableScope.GLOBAL:
				is_safe = true
			BaseVariable.VariableScope.SCOPE:
				is_safe = false

	_thread_safety_cached = is_safe
	_thread_safety_computed = true
	return _thread_safety_cached
```

**Step 3: 验证语法**

Run: `E:\Godot\Godot_v4.6.1-stable_mono_win64\Godot_v4.6.1-stable_mono_win64.exe --headless --check-only --quit`
Expected: 无错误输出

**Step 4: Commit**

```bash
git add addons/bricks/conditions/arrays/check_array_contains.gd
git commit -m "feat(bricks): add thread safety detection to CheckArrayContains for VARIABLE mode"
```

### Task 3.3: CheckDictSize 线程安全

**Files:**
- Modify: `addons/bricks/conditions/dictionaries/check_dict_size.gd`

**Step 1: 读取文件了解结构**

**Step 2: 添加 `_compute_thread_safety()` 方法**

```gdscript
## 计算线程安全性
## CheckDictSize 只有在 VARIABLE + LOCAL/GLOBAL 模式下才安全
func _compute_thread_safety() -> bool:
	if _thread_safety_computed:
		return _thread_safety_cached

	var is_safe := false

	if source_type == SourceType.VARIABLE:
		match dict_scope:
			BaseVariable.VariableScope.LOCAL, BaseVariable.VariableScope.GLOBAL:
				is_safe = true
			BaseVariable.VariableScope.SCOPE:
				is_safe = false

	_thread_safety_cached = is_safe
	_thread_safety_computed = true
	return _thread_safety_cached
```

**Step 3: 验证语法**

Run: `E:\Godot\Godot_v4.6.1-stable_mono_win64\Godot_v4.6.1-stable_mono_win64.exe --headless --check-only --quit`
Expected: 无错误输出

**Step 4: Commit**

```bash
git add addons/bricks/conditions/dictionaries/check_dict_size.gd
git commit -m "feat(bricks): add thread safety detection to CheckDictSize for VARIABLE mode"
```

### Task 3.4: CheckDictContainsKey 线程安全

**Files:**
- Modify: `addons/bricks/conditions/dictionaries/check_dict_contains_key.gd`

**Step 1: 读取文件了解结构**

**Step 2: 添加 `_compute_thread_safety()` 方法**

```gdscript
## 计算线程安全性
## CheckDictContainsKey 只有在 VARIABLE + LOCAL/GLOBAL 模式下才安全
func _compute_thread_safety() -> bool:
	if _thread_safety_computed:
		return _thread_safety_cached

	var is_safe := false

	if source_type == SourceType.VARIABLE:
		match dict_scope:
			BaseVariable.VariableScope.LOCAL, BaseVariable.VariableScope.GLOBAL:
				is_safe = true
			BaseVariable.VariableScope.SCOPE:
				is_safe = false

	_thread_safety_cached = is_safe
	_thread_safety_computed = true
	return _thread_safety_cached
```

**Step 3: 验证语法**

Run: `E:\Godot\Godot_v4.6.1-stable_mono_win64\Godot_v4.6.1-stable_mono_win64.exe --headless --check-only --quit`
Expected: 无错误输出

**Step 4: Commit**

```bash
git add addons/bricks/conditions/dictionaries/check_dict_contains_key.gd
git commit -m "feat(bricks): add thread safety detection to CheckDictContainsKey for VARIABLE mode"
```

---

## Phase 4: 验证和文档

### Task 4.1: 更新开发者文档

**Files:**
- Modify: `addons/bricks/docs/dev/multithreading-developer-guide.md`

**Step 1: 在文档中添加已优化的条件列表**

在 "已迁移的条件" 部分更新：

```markdown
## 已优化的条件

| 条件 | 线程安全条件 | 优先级 |
|------|-------------|--------|
| CheckVariable | LOCAL/GLOBAL 作用域 | P0 ✅ |
| CheckPreloadStatus | 总是安全 | P0 ✅ |
| CheckInputPressed | 总是安全 | P1 ✅ |
| CheckInputHeld | 总是安全 | P1 ✅ |
| CheckInputReleased | 总是安全 | P1 ✅ |
| CheckAll | 所有子条件安全 | P2 |
| CheckAny | 所有子条件安全 | P2 |
| CheckNot | 子条件安全 | P2 |
| CheckArraySize | VARIABLE + LOCAL/GLOBAL | P2 |
| CheckArrayContains | VARIABLE + LOCAL/GLOBAL | P2 |
| CheckDictSize | VARIABLE + LOCAL/GLOBAL | P2 |
| CheckDictContainsKey | VARIABLE + LOCAL/GLOBAL | P2 |
```

**Step 2: Commit**

```bash
git add addons/bricks/docs/dev/multithreading-developer-guide.md
git commit -m "docs(bricks): update developer guide with optimized conditions list"
```

### Task 4.2: 最终验证

**Step 1: 运行完整语法检查**

Run: `E:\Godot\Godot_v4.6.1-stable_mono_win64\Godot_v4.6.1-stable_mono_win64.exe --headless --check-only --quit`
Expected: 无错误输出

**Step 2: 查看修改的文件**

Run: `git status`
Expected: 所有修改已提交

**Step 3: 查看 commit 历史**

Run: `git log --oneline -15`
Expected: 包含所有迁移的 commit

---

## 预期收益

| 阶段 | 并行评估覆盖率 | 新增条件 |
|------|----------------|----------|
| 基线 | ~15% | CheckVariable |
| Phase 1 后 | ~40% | +3 个输入条件 |
| Phase 2 后 | ~50% | +3 个复合条件 |
| Phase 3 后 | ~60% | +4 个集合条件 |

## 不优化的条件（保持串行）

以下条件需要访问节点或 ExecutionContext，无法优化：

- `CheckNodeProperty` - 需要访问节点属性
- `CheckNodeActive` - 需要访问节点
- `CheckNodeExists` - 需要访问节点
- `CheckChildCount` - 需要访问节点子节点
- `CheckGroupCount` - 需要访问 SceneTree
- `CheckAnimationFinished` - 需要访问动画状态
- `CheckArraySize` (NODE_CHILDREN/NODE_GROUP 模式) - 需要访问节点
