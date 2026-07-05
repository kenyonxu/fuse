# Condition Variable Support Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add variable-based node source support to 17 condition classes that currently only support NodePath, enabling dynamic node selection at runtime.

**Architecture:** Each condition will support a dual-mode approach: `NodeSource.NODE_PATH` (existing static path) and `NodeSource.VARIABLE` (dynamic from variable). Variable mode supports three-tier scope system (LOCAL, SCOPE, GLOBAL) with ScopeSource sub-options. Dynamic property lists provide context-aware UI.

**Tech Stack:** GDScript 2.0, Godot 4.6, Bricks Plugin System, VariableOperations utility, VariableScopeUtils

**Reference Implementation:** `addons/bricks/conditions/node/check_node_in_group.gd` (completed)

---

## Summary of Changes Per Condition

Each condition requires these modifications:
1. Add `NodeSource` and `ScopeSource` enums
2. Add node variable properties (5 new properties per node parameter)
3. Implement `_get_property_list()` for dynamic UI
4. Implement `_validate_property()` for conditional visibility
5. Add `_get_target_node()` helper methods
6. Modify `_evaluate_condition()` to use new node acquisition logic
7. Update `_update_resource_name()` for display
8. Update `validate()` for new parameters
9. Update `get_parameters()` / `set_parameters()`
10. Add localization keys

---

## Phase 1: High Priority - Single Node Conditions

### Task 1.1: CheckNodeExists

**Files:**
- Modify: `addons/bricks/conditions/node/check_node_exists.gd`
- Test: Manual testing in editor

**Step 1: Add enums and new properties**

```gdscript
## 节点来源枚举
enum NodeSource {
	NODE_PATH,   ## 通过节点路径指定
	VARIABLE     ## 从变量获取节点
}

## 作用域来源枚举（仅在 node_variable_scope == SCOPE 时使用）
enum ScopeSource {
	NEAREST,        ## 最近的作用域容器（默认）
	CUSTOM_ID,      ## 指定 scope_id
	TRIGGER_SCOPE,  ## Trigger 节点上的作用域
	TARGET_NODE     ## Target 节点上的作用域
}

## 节点来源
var node_source: NodeSource = NodeSource.NODE_PATH:
	set(value):
		node_source = value
		_update_resource_name()
		notify_property_list_changed()

## 检查的节点路径（保留原有）
var check_node_path: NodePath = NodePath(""):
	set(value):
		check_node_path = value
		_update_resource_name()

## 节点变量名（当 node_source == VARIABLE 时使用）
var node_variable_name: String = "":
	set(value):
		node_variable_name = value
		_update_resource_name()

## 节点变量作用域
var node_variable_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		node_variable_scope = value
		_update_resource_name()
		notify_property_list_changed()

## 节点变量作用域来源
var node_scope_source: ScopeSource = ScopeSource.NEAREST:
	set(value):
		node_scope_source = value
		_update_resource_name()
		notify_property_list_changed()

## 节点变量自定义作用域 ID
var node_custom_scope_id: String = "":
	set(value):
		node_custom_scope_id = value
		_update_resource_name()

## 节点变量目标节点路径
var node_target_node_path: NodePath = NodePath(""):
	set(value):
		node_target_node_path = value
		_update_resource_name()
```

**Step 2: Add `_get_property_list()` method**

Copy from reference implementation and adapt property names.

**Step 3: Add `_validate_property()` method**

Copy from reference implementation and adapt property names.

**Step 4: Add helper methods**

Add `_get_node_source_string()`, `_get_node_scope_source_string()`, `_get_target_node()`, `_get_node_by_path()`, `_get_node_by_variable()`, `_get_node_variable_value()`.

**Step 5: Modify `_evaluate_condition()`**

Replace direct node access with `_get_target_node(context)`.

**Step 6: Update `_update_resource_name()`**

Use `_get_node_source_string()` for display.

**Step 7: Update `validate()`**

Add validation for VARIABLE mode parameters.

**Step 8: Update `get_parameters()` and `set_parameters()`**

Include new properties.

**Step 9: Run Godot script check**

Run: `Godot.exe --headless --check-only --quit`
Expected: No errors

**Step 10: Commit**

```bash
git add addons/bricks/conditions/node/check_node_exists.gd
git commit -m "feat: add variable support to CheckNodeExists condition"
```

---

### Task 1.2: CheckNodeActive

**Files:**
- Modify: `addons/bricks/conditions/node/check_node_active.gd`

**Step 1: Add enums and properties** (same pattern as Task 1.1)

Note: This condition has an additional `check_type` enum that should be preserved.

**Step 2-10:** Same steps as Task 1.1, adapting for `check_node_path` property name.

**Commit message:** `feat: add variable support to CheckNodeActive condition`

---

### Task 1.3: CheckNodeProperty

**Files:**
- Modify: `addons/bricks/conditions/node/check_node_property.gd`

**Step 1: Add enums and properties** (same pattern, property name: `target_node_path`)

**Step 2-10:** Same steps, adapting property names.

**Commit message:** `feat: add variable support to CheckNodeProperty condition`

---

## Phase 2: High Priority - Dual Node Conditions

### Task 2.1: CheckDistance (Two Nodes)

**Files:**
- Modify: `addons/bricks/conditions/distance/check_distance.gd`

**Special Considerations:**
- Has TWO node parameters: `source_node` and `target_node`
- Each needs its own NodeSource and variable properties
- Add properties for both: `source_node_source`, `source_variable_name`, etc. AND `target_node_source`, `target_variable_name`, etc.

**Step 1: Add enums**

```gdscript
enum NodeSource { NODE_PATH, VARIABLE }
enum ScopeSource { NEAREST, CUSTOM_ID, TRIGGER_SCOPE, TARGET_NODE }
```

**Step 2: Add source node properties**

```gdscript
var source_node_source: NodeSource = NodeSource.NODE_PATH
var source_node: NodePath = NodePath("")  # existing
var source_variable_name: String = ""
var source_variable_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL
var source_scope_source: ScopeSource = ScopeSource.NEAREST
var source_custom_scope_id: String = ""
var source_target_node_path: NodePath = NodePath("")
```

**Step 3: Add target node properties**

```gdscript
var target_node_source: NodeSource = NodeSource.NODE_PATH
var target_node: NodePath = NodePath("")  # existing
var target_variable_name: String = ""
var target_variable_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL
var target_scope_source: ScopeSource = ScopeSource.NEAREST
var target_custom_scope_id: String = ""
var target_target_node_path: NodePath = NodePath("")
```

**Step 4: Implement `_get_property_list()` with dual node configuration**

Show separate configuration sections for source and target nodes.

**Step 5: Implement `_validate_property()` for both nodes**

**Step 6: Add helper methods for both nodes**

`_get_source_node()`, `_get_target_node()`, etc.

**Step 7: Modify `_evaluate_condition()` to use new helpers**

**Step 8: Run script check**

**Step 9: Commit**

```bash
git add addons/bricks/conditions/distance/check_distance.gd
git commit -m "feat: add variable support to CheckDistance condition (dual node)"
```

---

## Phase 3: Medium Priority - Physics Conditions

### Task 3.1: CheckVelocity

**Files:**
- Modify: `addons/bricks/conditions/physics/check_velocity.gd`

**Steps:** Same as Task 1.1 (single node), property name: `target_node`

**Commit message:** `feat: add variable support to CheckVelocity condition`

---

### Task 3.2: CheckOnFloor

**Files:**
- Modify: `addons/bricks/conditions/physics/check_on_floor.gd`

**Steps:** Same as Task 1.1, property name: `target_node`

**Commit message:** `feat: add variable support to CheckOnFloor condition`

---

### Task 3.3: CheckInAir

**Files:**
- Modify: `addons/bricks/conditions/physics/check_in_air.gd`

**Steps:** Same as Task 1.1, property name: `target_node`

**Commit message:** `feat: add variable support to CheckInAir condition`

---

### Task 3.4: CheckOnWall

**Files:**
- Modify: `addons/bricks/conditions/physics/check_on_wall.gd`

**Steps:** Same as Task 1.1, property name: `target_node`

**Commit message:** `feat: add variable support to CheckOnWall condition`

---

### Task 3.5: CheckIsFalling

**Files:**
- Modify: `addons/bricks/conditions/physics/check_is_falling.gd`

**Steps:** Same as Task 1.1, property name: `target_node`

**Commit message:** `feat: add variable support to CheckIsFalling condition`

---

## Phase 4: Low Priority - Animation Conditions

### Task 4.1: CheckIsPlaying

**Files:**
- Modify: `addons/bricks/conditions/animation/check_is_playing.gd`

**Steps:** Same as Task 1.1, property name: `target_node`

**Commit message:** `feat: add variable support to CheckIsPlaying condition`

---

### Task 4.2: CheckAnimationFinished

**Files:**
- Modify: `addons/bricks/conditions/animation/check_animation_finished.gd`

**Steps:** Same as Task 1.1, property name: `target_node`

**Commit message:** `feat: add variable support to CheckAnimationFinished condition`

---

### Task 4.3: CheckAnimationTreeState

**Files:**
- Modify: `addons/bricks/conditions/animation/check_animation_tree_state.gd`

**Steps:** Same as Task 1.1, property name: `target_node`

**Commit message:** `feat: add variable support to CheckAnimationTreeState condition`

---

### Task 4.4: CheckIsAnimation

**Files:**
- Modify: `addons/bricks/conditions/animation/check_is_animation.gd`

**Steps:** Same as Task 1.1, property name: `target_node`

**Commit message:** `feat: add variable support to CheckIsAnimation condition`

---

## Phase 5: Special Cases - Multi-Node Conditions

### Task 5.1: CheckDirection (Two Nodes)

**Files:**
- Modify: `addons/bricks/conditions/node/check_direction.gd`

**Steps:** Same as Task 2.1 (dual node pattern)
Property names: `source_node`, `target_node`

**Commit message:** `feat: add variable support to CheckDirection condition (dual node)`

---

### Task 5.2: CheckFacingDirection

**Files:**
- Modify: `addons/bricks/conditions/node/check_facing_direction.gd`

**Steps:** Same as Task 1.1, property name: `target_node`

**Commit message:** `feat: add variable support to CheckFacingDirection condition`

---

### Task 5.3: CheckIsChildOf (Two Nodes)

**Files:**
- Modify: `addons/bricks/conditions/node/check_is_child_of.gd`

**Steps:** Same as Task 2.1 (dual node pattern)
Property names: `child_node`, `parent_node`

**Commit message:** `feat: add variable support to CheckIsChildOf condition (dual node)`

---

## Phase 6: Localization Updates

### Task 6.1: Add Required Translation Keys

**Files:**
- Modify: `addons/bricks/localization/translations.csv`

**Required Keys (already added for CheckNodeInGroup):**
```csv
BRICKS_ERROR_NODE_VARIABLE_IS_NULL,节点变量值为空: {name},Node variable value is null: {name}
BRICKS_ERROR_NODE_VARIABLE_INVALID_TYPE,节点变量 '{name}' 类型无效: {type},Node variable '{name}' has invalid type: {type}
BRICKS_SCOPE_UNKNOWN_STR,[未知],[Unknown]
```

**Step 1: Verify keys exist**

Run: `grep "BRICKS_ERROR_NODE_VARIABLE" translations.csv`

**Step 2: Add any missing keys**

**Step 3: Commit**

```bash
git add addons/bricks/localization/translations.csv
git commit -m "chore: add localization keys for condition variable support"
```

---

## Implementation Code Templates

### Template A: Single Node Condition

Use for conditions with ONE node parameter.

```gdscript
# === ENUMS ===
enum NodeSource { NODE_PATH, VARIABLE }
enum ScopeSource { NEAREST, CUSTOM_ID, TRIGGER_SCOPE, TARGET_NODE }

# === PROPERTIES ===
var node_source: NodeSource = NodeSource.NODE_PATH:
	set(value):
		node_source = value
		_update_resource_name()
		notify_property_list_changed()

var target_node: NodePath = NodePath(""):  # existing property
	set(value):
		target_node = value
		_update_resource_name()

var node_variable_name: String = "":
	set(value):
		node_variable_name = value
		_update_resource_name()

var node_variable_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		node_variable_scope = value
		_update_resource_name()
		notify_property_list_changed()

var node_scope_source: ScopeSource = ScopeSource.NEAREST:
	set(value):
		node_scope_source = value
		_update_resource_name()
		notify_property_list_changed()

var node_custom_scope_id: String = "":
	set(value):
		node_custom_scope_id = value
		_update_resource_name()

var node_target_node_path: NodePath = NodePath(""):
	set(value):
		node_target_node_path = value
		_update_resource_name()

# === HELPER METHODS ===
func _get_target_node(context: ExecutionContext) -> Node:
	if node_source == NodeSource.NODE_PATH:
		return _get_node_by_path(context)
	else:
		return _get_node_by_variable(context)

func _get_node_by_path(context: ExecutionContext) -> Node:
	if target_node.is_empty():
		var error_msg = BricksLocalization.translate("BRICKS_ERROR_TARGET_NODE_PATH_EMPTY")
		_log_error(error_msg)
		_create_bricks_error(error_msg, BricksError.ErrorType.VALIDATION_ERROR)
		return null
	var node = context.get_node(target_node)
	if node == null:
		var error_msg = BricksLocalization.translate("BRICKS_ERROR_NODE_NOT_FOUND") % str(target_node)
		_log_error(error_msg)
		_create_bricks_error(error_msg, BricksError.ErrorType.RUNTIME_ERROR)
		return null
	return node

func _get_node_by_variable(context: ExecutionContext) -> Node:
	if node_variable_name.is_empty():
		var error_msg = BricksLocalization.translate("BRICKS_ERROR_VAR_NAME_EMPTY")
		_log_error(error_msg)
		_create_bricks_error(error_msg, BricksError.ErrorType.VALIDATION_ERROR)
		return null
	var node_value = _get_node_variable_value(context)
	if node_value == null:
		var error_msg = BricksLocalization.translate("BRICKS_ERROR_NODE_VARIABLE_IS_NULL") % node_variable_name
		_log_error(error_msg)
		_create_bricks_error(error_msg, BricksError.ErrorType.RUNTIME_ERROR)
		return null
	var node: Node = null
	if node_value is Node:
		node = node_value
	elif node_value is NodePath:
		node = context.get_node(node_value)
	elif node_value is String and not node_value.is_empty():
		node = context.get_node(NodePath(node_value))
	else:
		var error_msg = BricksLocalization.translate("BRICKS_ERROR_NODE_VARIABLE_INVALID_TYPE") % [node_variable_name, str(typeof(node_value))]
		_log_error(error_msg)
		_create_bricks_error(error_msg, BricksError.ErrorType.RUNTIME_ERROR)
		return null
	return node

func _get_node_variable_value(context: ExecutionContext) -> Variant:
	var value: Variant = null
	match node_variable_scope:
		BaseVariable.VariableScope.LOCAL:
			value = VariableOperations.get_variable(context, node_variable_name, BaseVariable.VariableScope.LOCAL, null)
		BaseVariable.VariableScope.GLOBAL:
			value = VariableOperations.get_variable(context, node_variable_name, BaseVariable.VariableScope.GLOBAL, null)
		BaseVariable.VariableScope.SCOPE:
			if node_scope_source == ScopeSource.NEAREST:
				value = VariableOperations.get_variable(context, node_variable_name, BaseVariable.VariableScope.SCOPE, null)
			else:
				var utils_scope_source = node_scope_source as VariableScopeUtils.ScopeSource
				var scope_container = VariableScopeUtils.get_scope_container_by_source(
					context, utils_scope_source, node_custom_scope_id, node_target_node_path)
				if scope_container != null and scope_container.has_variable(node_variable_name):
					value = scope_container.get_variable(node_variable_name)
	return value

func _get_node_source_string() -> String:
	if node_source == NodeSource.NODE_PATH:
		var path_str = str(target_node)
		if path_str.length() > 30:
			path_str = path_str.substr(0, 27) + "..."
		return path_str
	else:
		if node_variable_name.is_empty():
			return BricksLocalization.translate("BRICKS_CONDITION_NOT_SET")
		var scope_str = _get_node_scope_source_string()
		return "[%s] %s" % [scope_str, node_variable_name]

func _get_node_scope_source_string() -> String:
	match node_variable_scope:
		BaseVariable.VariableScope.LOCAL:
			return BricksLocalization.translate("BRICKS_SCOPE_LOCAL_STR")
		BaseVariable.VariableScope.SCOPE:
			return VariableScopeUtils.get_scope_source_string(
				node_scope_source as VariableScopeUtils.ScopeSource,
				node_custom_scope_id, node_target_node_path)
		BaseVariable.VariableScope.GLOBAL:
			return BricksLocalization.translate("BRICKS_SCOPE_GLOBAL_STR")
		_:
			return BricksLocalization.translate("BRICKS_SCOPE_UNKNOWN_STR")
```

### Template B: Dynamic Property List

```gdscript
func _get_property_list() -> Array[Dictionary]:
	var properties := []

	# Node Configuration
	properties.append({
		name = "Node Configuration",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "node_source",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Node Path,Variable",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	if node_source == NodeSource.NODE_PATH:
		properties.append({
			name = "target_node",  # adapt to actual property name
			type = TYPE_NODE_PATH,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})
	else:
		properties.append({
			name = "node_variable_name",
			type = TYPE_STRING,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})
		properties.append({
			name = "node_variable_scope",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "Local,Scope,Global",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})
		if node_variable_scope == BaseVariable.VariableScope.SCOPE:
			properties.append({
				name = "node_scope_source",
				type = TYPE_INT,
				hint = PROPERTY_HINT_ENUM,
				hint_string = "Nearest,Custom ID,Trigger Scope,Target Node",
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})
			if node_scope_source == ScopeSource.CUSTOM_ID:
				properties.append({
					name = "node_custom_scope_id",
					type = TYPE_STRING,
					hint = PROPERTY_HINT_NONE,
					usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
				})
			elif node_scope_source == ScopeSource.TARGET_NODE:
				properties.append({
					name = "node_target_node_path",
					type = TYPE_NODE_PATH,
					hint = PROPERTY_HINT_NONE,
					usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
				})

	# Add other existing property groups here...

	return properties

func _validate_property(property: Dictionary) -> void:
	if node_source == NodeSource.NODE_PATH:
		if property.name in ["node_variable_name", "node_variable_scope", "node_scope_source", "node_custom_scope_id", "node_target_node_path"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR
	else:
		if property.name == "target_node":  # adapt to actual property name
			property.usage = PROPERTY_USAGE_NO_EDITOR
		if node_variable_scope == BaseVariable.VariableScope.SCOPE:
			VariableScopeUtils.validate_scope_source_property(property, node_scope_source as VariableScopeUtils.ScopeSource)
		else:
			if property.name in ["node_scope_source", "node_custom_scope_id", "node_target_node_path"]:
				property.usage = PROPERTY_USAGE_NO_EDITOR
```

---

## Verification Checklist

After completing each condition:

- [ ] Script check passes: `Godot --headless --check-only --quit`
- [ ] Inspector shows Node Source dropdown
- [ ] Node Path mode shows original property
- [ ] Variable mode shows variable name and scope
- [ ] SCOPE scope shows ScopeSource options
- [ ] Resource name updates correctly
- [ ] Validation catches missing parameters
- [ ] Committed with descriptive message

---

## Risk Assessment

| Risk | Level | Mitigation |
|------|-------|------------|
| Breaking existing scenes | LOW | Properties are additive, defaults preserve existing behavior |
| Performance impact | LOW | Variable lookup adds minimal overhead |
| UI complexity | MEDIUM | Dynamic property lists keep UI clean |
| Testing coverage | MEDIUM | Manual testing required for each condition |

---

## Estimated Complexity

**Per Single-Node Condition:** 30-45 minutes
**Per Dual-Node Condition:** 45-60 minutes

**Total Estimate:**
- Phase 1 (3 conditions): ~2 hours
- Phase 2 (1 condition): ~1 hour
- Phase 3 (5 conditions): ~3 hours
- Phase 4 (4 conditions): ~2.5 hours
- Phase 5 (3 conditions): ~2 hours
- Phase 6 (localization): ~15 minutes

**Grand Total:** ~10-11 hours

---

**WAITING FOR CONFIRMATION**: Proceed with this plan? (yes/no/modify)
