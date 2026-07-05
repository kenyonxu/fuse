# WhileLoop Variable Operations Refactor Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use @superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Refactor WhileLoop instruction to use VariableOperations for unified variable access across all scopes (LOCAL, SCOPE, GLOBAL).

**Architecture:** WhileLoop is a core flow control instruction that repeatedly executes nested instructions while a condition is true. Currently uses legacy `context.get_variable()` API which only supports LOCAL scope. This refactoring adds support for three-tier variable system using the centralized VariableOperations utility class.

**Tech Stack:**
- Godot 4.6 GDScript 2.0
- Bricks visual programming system
- VariableOperations utility class (preloaded in BaseInstruction)
- BaseVariable.VariableScope enum (type-safe scope selection)

**Background Context:**
- VariableOperations is already preloaded in BaseInstruction (no need to preload again)
- Similar refactoring completed for 15 components (see commit f0d0791)
- Reference implementation: [SetIntVariable](addons/bricks/instructions/variables/set_int_variable.gd)

---

## Task 1: Add Variable Scope Property

**Files:**
- Modify: `addons/bricks/instructions/flow_control/while_loop.gd:11-23`

**Step 1: Add variable_scope property after condition_variable (line 12)**

```gdscript
# Condition variable name
var condition_variable: String = ""

# Variable scope (LOCAL/SCOPE/GLOBAL)
@export var variable_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		variable_scope = value
		_update_resource_name()

# Condition check type
enum ConditionCheck {
	IS_TRUE,
	IS_FALSE,
	IS_NOT_NULL
}
var condition_check: ConditionCheck = ConditionCheck.IS_TRUE
```

**Step 2: Run syntax check**

Run: `E:\Godot\Godot_v4.6-stable_mono_win64\Godot_v4.6-stable_mono_win64.exe" --headless --check-only --quit`
Expected: No syntax errors

**Step 3: Commit property addition**

```bash
git add addons/bricks/instructions/flow_control/while_loop.gd
git commit -m "refactor(while_loop): add variable_scope property"
```

---

## Task 2: Update Variable Access to Use VariableOperations

**Files:**
- Modify: `addons/bricks/instructions/flow_control/while_loop.gd:185`

**Step 1: Replace legacy API with VariableOperations**

Find line 185:
```gdscript
# OLD CODE (remove this)
var condition_value = context.get_variable(condition_variable)
```

Replace with:
```gdscript
# NEW CODE (add this)
var condition_value = VariableOperations.get_variable(context, condition_variable, variable_scope, null)
if condition_value == null and not VariableOperations.has_variable(context, condition_variable, variable_scope):
	_log_error_localized("BRICKS_ERROR_VAR_NOT_FOUND", {"variable": condition_variable})
	set_error_localized("BRICKS_ERROR_VAR_NOT_FOUND", BricksError.ErrorType.RUNTIME_ERROR, {"variable": condition_variable})
	break
```

**Step 2: Run syntax check**

Run: `E:\Godot\Godot_v4.6-stable_mono_win64\Godot_v4.6-stable_mono_win64.exe" --headless --check-only --quit`
Expected: No syntax errors

**Step 3: Commit API update**

```bash
git add addons/bricks/instructions/flow_control/while_loop.gd
git commit -m "refactor(while_loop): use VariableOperations.get_variable()"
```

---

## Task 3: Update Resource Name Display

**Files:**
- Modify: `addons/bricks/instructions/flow_control/while_loop.gd`

**Step 1: Find or create _update_resource_name() method**

Search for `_update_resource_name` in the file. If it exists, modify it. If not, add it before the `execute()` method.

**Step 2: Update resource name to include scope information**

```gdscript
func _update_resource_name() -> void:
	var scope_str = VariableScopeUtils.enum_to_string(variable_scope).to_upper()
	resource_name = "%s [%s] '%s'" % [
		BricksLocalization.translate("BRICKS_INSTRUCTION_WHILE_LOOP_RESOURCE"),
		scope_str,
		condition_variable if not condition_variable.is_empty() else BricksLocalization.translate("BRICKS_VARIABLE_UNNAMED")
	]
```

**Step 3: Run syntax check**

Run: `E:\Godot\Godot_v4.6-stable_mono_win64\Godot_v4.6-stable_mono_win64.exe" --headless --check-only --quit`
Expected: No syntax errors

**Step 4: Commit resource name update**

```bash
git add addons/bricks/instructions/flow_control/while_loop.gd
git commit -m "refactor(while_loop): update resource_name to show scope"
```

---

## Task 4: Update Description Method

**Files:**
- Modify: `addons/bricks/instructions/flow_control/while_loop.gd`

**Step 1: Find get_description() method**

Search for `func get_description()` in the file.

**Step 2: Update description to include scope**

```gdscript
func get_description() -> String:
	if condition_variable.is_empty():
		return BricksLocalization.translate("BRICKS_INSTRUCTION_WHILE_LOOP_DESC")

	var scope_str = VariableScopeUtils.enum_to_string(variable_scope).to_upper()
	var check_str = match condition_check:
		ConditionCheck.IS_TRUE: "== true"
		ConditionCheck.IS_FALSE: "== false"
		ConditionCheck.IS_NOT_NULL: "!= null"

	return "%s [%s] %s %s (max: %d)" % [
		condition_variable,
		scope_str,
		check_str,
		BricksLocalization.translate("BRICKS_INSTRUCTION_WHILE_LOOP_NAME"),
		max_iterations
	]
```

**Step 3: Run syntax check**

Run: `E:\Godot\Godot_v4.6-stable_mono_win64\Godot_v4.6-stable_mono_win64.exe" --headless --check-only --quit`
Expected: No syntax errors

**Step 4: Commit description update**

```bash
git add addons/bricks/instructions/flow_control/while_loop.gd
git commit -m "refactor(while_loop): update get_description() with scope info"
```

---

## Task 5: Add Validation for SCOPE

**Files:**
- Modify: `addons/bricks/instructions/flow_control/while_loop.gd`

**Step 1: Find or create validate() method**

Search for `func validate()` in the file. If it exists, add to it. If not, add it after `get_description()`.

**Step 2: Add scope validation**

```gdscript
func validate() -> Array[String]:
	var errors = super.validate()

	if condition_variable.is_empty():
		errors.append(BricksLocalization.translate("BRICKS_ERROR_CONDITION_VARIABLE_EMPTY"))

	# Validate SCOPE requires ScopeVariableManager
	if variable_scope == BaseVariable.VariableScope.SCOPE:
		var manager = ScopeVariableManager.get_instance()
		if manager == null:
			errors.append(BricksLocalization.translate("BRICKS_ERROR_SCOPE_MANAGER_NOT_FOUND"))

	return errors
```

**Step 3: Run syntax check**

Run: `E:\Godot\Godot_v4.6-stable_mono_win64\Godot_v4.6-stable_mono_win64.exe" --headless --check-only --quit`
Expected: No syntax errors

**Step 4: Commit validation addition**

```bash
git add addons/bricks/instructions/flow_control/while_loop.gd
git commit -m "refactor(while_loop): add scope validation"
```

---

## Task 6: Update Property List for Inspector

**Files:**
- Modify: `addons/bricks/instructions/flow_control/while_loop.gd:47-110`

**Step 1: Find _get_property_list() method**

Search for `func _get_property_list()` around line 47.

**Step 2: Add variable_scope property to inspector**

Add this after `condition_variable` property (around line 63):

```gdscript
properties.append({
	name = "condition_variable",
	type = TYPE_STRING,
	hint = PROPERTY_HINT_NONE,
	usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
})

# Add this new property
properties.append({
	name = "variable_scope",
	type = TYPE_INT,
	hint = PROPERTY_HINT_ENUM,
	hint_string = "Local,Scope,Global",
	usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
})

properties.append({
	name = "condition_check",
	type = TYPE_INT,
	hint = PROPERTY_HINT_ENUM,
	hint_string = "IsTrue,IsFalse,IsNotNull",
	usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
})
```

**Step 3: Run syntax check**

Run: `E:\Godot\Godot_v4.6-stable_mono_win64\Godot_v4.6-stable_mono_win64.exe" --headless --check-only --quit`
Expected: No syntax errors

**Step 4: Commit property list update**

```bash
git add addons/bricks/instructions/flow_control/while_loop.gd
git commit -m "refactor(while_loop): add variable_scope to property list"
```

---

## Task 7: Add Refactoring Comment

**Files:**
- Modify: `addons/bricks/instructions/flow_control/while_loop.gd:6-10`

**Step 1: Add refactoring note after class declaration**

Find line 6-10 (the comment block after class declaration):

```gdscript
## While Loop 指令
##
## 当条件为真时重复执行（支持最大迭代次数限制）。
## 支持嵌套循环、break/continue 控制。
##
## 重构变量系统: 2026-02-09 - 使用 VariableOperations 统一变量访问
```

**Step 2: Run syntax check**

Run: `E:\Godot\Godot_v4.6-stable_mono_win64\Godot_v4.6-stable_mono_win64.exe" --headless --check-only --quit`
Expected: No syntax errors

**Step 3: Final commit with all changes**

```bash
git add addons/bricks/instructions/flow_control/while_loop.gd
git commit -m "refactor(while_loop): complete VariableOperations integration

- Add variable_scope property (LOCAL/SCOPE/GLOBAL)
- Replace context.get_variable() with VariableOperations.get_variable()
- Update resource_name and get_description() to show scope
- Add validation for SCOPE scope
- Update property list for editor

This enables WhileLoop to work with all three variable scopes.
Refactoring date: 2026-02-09
Related: BaseInstruction preload improvement (commit f0d0791)"
```

---

## Task 8: Create Test Scene

**Files:**
- Create: `addons/bricks/tests/instructions/test_while_loop_scope.tscn`
- Create: `addons/bricks/tests/instructions/test_while_loop_scope.gd`

**Step 1: Create test script**

```gdscript
extends Node

## Test WhileLoop with different variable scopes

func _ready():
	test_while_loop_local_scope()
	test_while_loop_scope_scope()
	test_while_loop_global_scope()
	print("All WhileLoop scope tests passed!")

func test_while_loop_local_scope():
	print("Testing WhileLoop with LOCAL scope...")
	var trigger = $Trigger_Local
	var context = ExecutionContext.new()
	context.trigger = trigger

	# Set up loop condition variable
	context.set_variable("loop_count", 0, "local")
	context.set_variable("max_count", 3, "local")

	var while_loop = trigger.get_action_runner().actions[0]
	assert(while_loop != null, "WhileLoop instruction not found")

	# Execute
	while_loop.execute(context)

	# Verify
	var loop_count = context.get_variable("loop_count")
	assert(loop_count == 3, "Expected loop_count=3, got %d" % loop_count)
	print("✓ LOCAL scope test passed")

func test_while_loop_scope_scope():
	print("Testing WhileLoop with SCOPE scope...")
	# Similar test with scope container
	var scope_container = $ScopeContainer
	var manager = ScopeVariableManager.get_instance()
	manager.register_scope_container(scope_container)

	scope_container.set_variable("loop_count", 0)
	scope_container.set_variable("max_count", 2)

	var trigger = $Trigger_Scope
	var context = ExecutionContext.new()
	context.trigger = trigger

	var while_loop = trigger.get_action_runner().actions[0]
	while_loop.execute(context)

	var loop_count = scope_container.get_variable("loop_count")
	assert(loop_count == 2, "Expected loop_count=2, got %d" % loop_count)
	print("✓ SCOPE scope test passed")

func test_while_loop_global_scope():
	print("Testing WhileLoop with GLOBAL scope...")
	var assistant = GlobalVariableAssistant.get_instance()
	assistant.set_variable("loop_count", 0)
	assistant.set_variable("max_count", 1)

	var trigger = $Trigger_Global
	var context = ExecutionContext.new()
	context.trigger = trigger

	var while_loop = trigger.get_action_runner().actions[0]
	while_loop.execute(context)

	var loop_count = assistant.get_variable("loop_count").value
	assert(loop_count == 1, "Expected loop_count=1, got %d" % loop_count)
	print("✓ GLOBAL scope test passed")
```

**Step 2: Create test scene structure**

Create scene with:
- 3 Trigger nodes (Trigger_Local, Trigger_Scope, Trigger_Global)
- 1 ScopeContainer node
- Each Trigger has ActionRunner with WhileLoop instruction

**Step 3: Run test in editor**

Run: Open scene in Godot editor, press F6 to run scene
Expected: All tests print "passed" messages

**Step 4: Commit test files**

```bash
git add addons/bricks/tests/instructions/test_while_loop_scope.*
git commit -m "test(while_loop): add scope integration tests"
```

---

## Task 9: Verify and Document

**Files:**
- Update: `addons/bricks/docs/refactoring-progress.md` (if exists)

**Step 1: Run global syntax check**

Run: `E:\Godot\Godot_v4.6-stable_mono_win64\Godot_v4.6-stable_mono_win64.exe" --headless --check-only --quit`
Expected: No syntax errors across entire project

**Step 2: Manual verification**

1. Open Godot Editor
2. Create a test scene with Trigger node
3. Add WhileLoop instruction to ActionRunner
4. Verify variable_scope dropdown appears in Inspector
5. Test with LOCAL scope (existing behavior)
6. Test with SCOPE scope (new feature)
7. Test with GLOBAL scope (new feature)

**Step 3: Update refactoring documentation**

Add entry to refactoring progress:

```markdown
### Flow Control Instructions

| Component | Status | Commit | Notes |
|-----------|--------|--------|-------|
| WhileLoop | ✅ Complete | YYYY-MM-DD | Supports all 3 scopes |
| ForLoop | ⏳ Pending | - | Next priority |
| ForEach | ⏳ Pending | - | - |
| WaitUntil | ⏳ Pending | - | - |
```

**Step 4: Final verification commit**

```bash
git add docs/plans/2026-02-09-refactor-while-loop-variable-operations.md
git add addons/bricks/docs/refactoring-progress.md
git commit -m "docs(while_loop): complete refactoring documentation"
```

---

## Success Criteria

✅ **All tasks completed**
✅ **Global syntax check passes**
✅ **Test scene runs successfully**
✅ **VariableOperations API used consistently**
✅ **All three scopes (LOCAL, SCOPE, GLOBAL) supported**
✅ **Editor Inspector shows variable_scope dropdown**
✅ **Documentation updated**

---

## Rollback Plan

If critical issues are found:

```bash
# Revert to before refactoring
git revert <commit-hash>
# Or reset to working state
git reset --hard HEAD~9
```

---

## Related References

- **VariableOperations Utility**: [addons/bricks/core/utils/variable_operations.gd](addons/bricks/core/utils/variable_operations.gd)
- **BaseInstruction**: [addons/bricks/core/base/base_instruction.gd](addons/bricks/core/base/base_instruction.gd) (preloaded VariableOperations)
- **Reference Implementation**: [SetIntVariable](addons/bricks/instructions/variables/set_int_variable.gd)
- **Previous Refactoring**: Commit f0d0791 (BaseInstruction preload improvement)
- **Component List**: docs/plans/2025-02-09-bricks-variable-operations-unified-utility.md

---

## Estimated Time

**Total**: ~45 minutes
- Tasks 1-6 (code changes): 30 minutes
- Task 7 (documentation): 5 minutes
- Task 8 (testing): 8 minutes
- Task 9 (verification): 2 minutes

---

## Next Steps After WhileLoop

1. **ForLoop** (similar pattern, 2 API calls)
2. **ForEach** (similar pattern, 2 API calls)
3. **WaitUntil** (similar pattern, 3 API calls)

All flow control instructions can use this same refactoring pattern.
