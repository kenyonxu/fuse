> 🌐 [**中文版**](../../../zh_CN/user_docs/guides/01-variable-system-guide.md) | English

# Fuse Variable Usage Guide

> Learn to use the three-layer variable system correctly in Fuse visual programming

## Basic Concepts

The Fuse variable system has three layers: LOCAL (local), SCOPE (scope), and GLOBAL (global). In most cases you only need LOCAL and GLOBAL, but SCOPE is very useful in specific scenarios.

**Quick decision tree:**
- Temporary data for a single instruction? Use LOCAL
- Data shared across scenes? Use GLOBAL
- Data shared between nodes within a scene? Use SCOPE

## LOCAL Variables

LOCAL variables live in the execution context; they have the shortest lifetime but the fastest access. They suit intermediate results of instruction execution.

```gdscript
# Instruction: compute the distance between two points
func execute(context: ExecutionContext):
    var point_a = Vector2(0, 0)
    var point_b = Vector2(100, 100)

    # Compute the distance and save it to a LOCAL variable
    var distance = point_a.distance_to(point_b)
    VariableOperations.set_variable(
        context,
        "temp_distance",
        BaseVariable.VariableScope.LOCAL,
        distance
    )
```

**When to use LOCAL:**
- ✅ Intermediate computation results
- ✅ Temporary data for a single instruction
- ✅ Loop counters
- ❌ Data that must be shared across instructions
- ❌ Data that must persist

## GLOBAL Variables

GLOBAL variables persist for the entire game run and are shared across scenes. Use them for game configuration, player data, and other global state.

```gdscript
# Instruction: update the player's score
func execute(context: ExecutionContext):
    # Read the current score
    var current_score = VariableOperations.get_variable(
        context,
        "player_score",
        BaseVariable.VariableScope.GLOBAL,
        0
    )

    # Add to the score
    VariableOperations.set_variable(
        context,
        "player_score",
        BaseVariable.VariableScope.GLOBAL,
        current_score + 100
    )
```

**When to use GLOBAL:**
- ✅ Game configuration (volume, graphics quality)
- ✅ Player data (level, experience, inventory)
- ✅ Game progress (current level, quest state)
- ❌ Temporary data
- ❌ Scene-local data

## SCOPE Variables

SCOPE variables are data shared between nodes within a scene and are cleaned up automatically with the node lifecycle. They are the middle ground between LOCAL and GLOBAL.

### Basic Usage (NEAREST Mode)

By default, SCOPE variables use the nearest `ScopeVariableContainer` node.

```gdscript
# Instruction: update the UI health display
func execute(context: ExecutionContext):
    var hp = 80

    # Save to the nearest SCOPE container
    VariableOperations.set_variable(
        context,
        "current_hp",
        BaseVariable.VariableScope.SCOPE,
        hp
    )
```

**Scene tree example:**
```
Main
└── GameUI (ScopeVariableContainer, scope_id: "ui")
    ├── HPBar
    └── ScoreDisplay
```

The instructions of both HPBar and ScoreDisplay can access variables in the same SCOPE container.

### Specifying a Container (CUSTOM_ID Mode)

When you need precise control over which container is used, combine `save_to_scope` + `scope_source`.

```gdscript
# Instruction properties
@export var save_to_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.SCOPE
var scope_source: ScopeSource = ScopeSource.CUSTOM_ID
var custom_scope_id: String = "player_stats"

# Execution logic
func execute(context: ExecutionContext):
    if save_to_scope == BaseVariable.VariableScope.SCOPE:
        if scope_source == ScopeSource.CUSTOM_ID:
            var utils_scope_source = scope_source as VariableScopeUtils.ScopeSource
            var scope_container = VariableScopeUtils.get_scope_container_by_source(
                context,
                utils_scope_source,
                custom_scope_id,
                target_node_path
            )

            if scope_container != null:
                scope_container.set_variable("player_hp", 100)
```

**Complex scene tree example:**
```
Main
├── PlayerStats (ScopeVariableContainer, scope_id: "player_stats")
├── EnemyStats (ScopeVariableContainer, scope_id: "enemy_stats")
└── EnemyAI
    └── Instruction (needs to read the player's HP)
```

With `custom_scope_id = "player_stats"` you read precisely from the PlayerStats container instead of the nearest EnemyStats.

### Scope Chain Inheritance

SCOPE containers support an inheritance mode where child containers can access parent container variables.

```gdscript
# Parent container: GameSettings (scope_id: "game_settings", inheritance mode: READ_WRITE)
#   └── Child container: Level1 (scope_id: "level1", inheritance mode: READ_ONLY)

# Instructions in Level1 can read GameSettings variables
var difficulty = VariableOperations.get_variable(
    context,
    "difficulty",
    BaseVariable.VariableScope.SCOPE,
    "normal"
)
```

**Inheritance modes:**
- `NONE` - do not inherit the parent scope
- `READ_ONLY` - inherit the parent scope read-only
- `READ_WRITE` - inherit the parent scope read-write

## Scope Selection Guide

### Scenario 1: One-off Computation

```gdscript
# Wrong: using GLOBAL unnecessarily
func execute(context: ExecutionContext):
    var temp_result = calculate()
    VariableOperations.set_variable(context, "temp", BaseVariable.VariableScope.GLOBAL, temp_result)

# Correct: use LOCAL
func execute(context: ExecutionContext):
    var temp_result = calculate()
    VariableOperations.set_variable(context, "temp", BaseVariable.VariableScope.LOCAL, temp_result)
```

### Scenario 2: UI Data Sharing

```gdscript
# Wrong: UI data in GLOBAL
func execute(context: ExecutionContext):
    VariableOperations.set_variable(context, "ui_hp", BaseVariable.VariableScope.GLOBAL, 100)

# Correct: UI data in SCOPE
# Add a ScopeVariableContainer to the UI root node
func execute(context: ExecutionContext):
    VariableOperations.set_variable(context, "hp", BaseVariable.VariableScope.SCOPE, 100)
```

**Scene tree:**
```
GameUI (ScopeVariableContainer, scope_id: "ui")
├── HPBar (instruction: set hp = 100)
├── ScoreDisplay (instruction: read hp)
└── ManaBar (instruction: read hp to display the health bar)
```

### Scenario 3: Cross-Enemy Data Sharing

```gdscript
# Scene tree
Main
├── EnemyManager (ScopeVariableContainer, scope_id: "enemy_manager")
│   ├── Enemy1 (instruction: enemy_count++)
│   └── Enemy2 (instruction: enemy_count++)
└── EnemyAI
    └── Instruction (reads enemy_count)

# Instruction in Enemy1
func execute(context: ExecutionContext):
    var count = VariableOperations.get_variable(
        context,
        "enemy_count",
        BaseVariable.VariableScope.SCOPE,
        0
    )

    VariableOperations.set_variable(
        context,
        "enemy_count",
        BaseVariable.VariableScope.SCOPE,
        count + 1
    )
```

## Using the Variable System in Instructions

### Standard Pattern

```gdscript
## Variable system refactor: 2026-02-09 - use VariableOperations for unified variable access

@tool
extends BaseInstruction
class_name MyInstruction

# Variable name
var variable_name: String = ""

# Variable scope
@export var variable_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		variable_scope = value
		_update_resource_name()

func execute(context: ExecutionContext):
	# Read the variable
	var value = VariableOperations.get_variable(
		context,
		variable_name,
		variable_scope,
		null  # default value
	)

	# Check whether the variable exists
	if value == null and not VariableOperations.has_variable(
		context,
		variable_name,
		variable_scope
	):
		_log_error_localized("FUSE_ERROR_VAR_NOT_FOUND", {"variable": variable_name})
		return

	# Process the value
	var result = _process(value)

	# Write the variable
	VariableOperations.set_variable(
		context,
		variable_name,
		variable_scope,
		result
	)

func validate() -> Array[String]:
	var errors = super.validate()

	if variable_name.is_empty():
		errors.append("变量名不能为空")

	# The SCOPE scope requires ScopeVariableManager
	if variable_scope == BaseVariable.VariableScope.SCOPE:
		var manager = ScopeVariableManager.get_instance()
		if manager == null:
			errors.append("未找到 ScopeVariableManager 实例")

	return errors
```

### Advanced SCOPE Variable Usage

#### Using a Custom scope_id

```gdscript
# Property definitions
@export var save_to_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.SCOPE
var scope_source: ScopeSource = ScopeSource.CUSTOM_ID
var custom_scope_id: String = "my_custom_scope"

# Execution logic
func execute(context: ExecutionContext):
    match save_to_scope:
        BaseVariable.VariableScope.LOCAL:
            # LOCAL logic
            pass
        BaseVariable.VariableScope.SCOPE:
            if scope_source == ScopeSource.CUSTOM_ID:
                var utils_scope_source = scope_source as VariableScopeUtils.ScopeSource
                var scope_container = VariableScopeUtils.get_scope_container_by_source(
                    context,
                    utils_scope_source,
                    custom_scope_id,
                    target_node_path
                )

                if scope_container != null:
                    scope_container.set_variable("my_var", 42)
        BaseVariable.VariableScope.GLOBAL:
            # GLOBAL logic
            pass
```

#### Property List Control

```gdscript
func _get_property_list() -> Array[Dictionary]:
	var properties := []

	# Always show the scope selection
	properties.append({
		name = "save_to_scope",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Local,Scope,Global"
	})

	# Only show the ScopeSource options when SCOPE is selected
	if save_to_scope == BaseVariable.VariableScope.SCOPE:
		properties.append({
			name = "scope_source",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "Nearest,Custom ID,Trigger Scope,Target Node"
		})

		if scope_source == ScopeSource.CUSTOM_ID:
			properties.append({
				name = "custom_scope_id",
				type = TYPE_STRING,
				hint = PROPERTY_HINT_NONE
			})

	return properties

func _validate_property(property: Dictionary) -> void:
	# Only validate the ScopeSource property when the scope is SCOPE
	if save_to_scope == BaseVariable.VariableScope.SCOPE:
		VariableScopeUtils.validate_scope_source_property(
			property,
			scope_source as VariableScopeUtils.ScopeSource
		)
	else:
		# Hide the ScopeSource properties when the scope is not SCOPE
		if property.name in ["scope_source", "custom_scope_id", "target_node_path"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR
```

## Common Patterns

### Pattern 1: Read/Write Operations

```gdscript
# Read an input variable and write an output variable
@export var input_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL
@export var output_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL

func execute(context: ExecutionContext):
	var input_value = VariableOperations.get_variable(
		context, "input", input_scope, 0
	)

	var result = input_value * 2

	VariableOperations.set_variable(
		context, "output", output_scope, result
	)
```

### Pattern 2: Default Value Handling

```gdscript
# Use a default value to avoid errors when the variable does not exist
var player_level = VariableOperations.get_variable(
    context,
    "player_level",
    BaseVariable.VariableScope.GLOBAL,
    1  # default value
)
```

### Pattern 3: Existence Check

```gdscript
# Distinguish "the variable does not exist" from "the variable's value is null"
var value = VariableOperations.get_variable(
    context,
    "my_variable",
    BaseVariable.VariableScope.GLOBAL,
    null
)

# Check whether the variable really exists
if not VariableOperations.has_variable(
    context,
    "my_variable",
    BaseVariable.VariableScope.GLOBAL
):
	_log_error("变量 '%s' 不存在" % "my_variable")
	return

# At this point a null value is valid (the variable does exist, but its value is null)
```

## Performance Considerations

### Access Speed Ranking

1. **LOCAL** - direct dictionary access, fastest
2. **SCOPE** - requires looking up the container node, slightly slower
3. **GLOBAL** - goes through the manager, relatively slower

### Optimization Tips

```gdscript
# Not recommended: accessing a GLOBAL variable repeatedly inside a loop
for i in range(100):
    var config = VariableOperations.get_variable(
        context, "config", BaseVariable.VariableScope.GLOBAL, null
    )
    # Use config...

# Recommended: read once outside the loop
var config = VariableOperations.get_variable(
    context, "config", BaseVariable.VariableScope.GLOBAL, null
)
for i in range(100):
    # Use config...
```

## Best Practices

### 1. Prefer LOCAL

```gdscript
# ✅ Recommended: temporary data in LOCAL
var temp_distance = point_a.distance_to(point_b)
VariableOperations.set_variable(context, "temp", BaseVariable.VariableScope.LOCAL, temp_distance)

# ❌ Avoid: temporary data in GLOBAL
VariableOperations.set_variable(context, "temp", BaseVariable.VariableScope.GLOBAL, temp_distance)
```

### 2. Variable Naming Conventions

```gdscript
# LOCAL variables - use the temp_ prefix
"temp_distance"
"temp_index"
"temp_result"

# SCOPE variables - group by function
"ui_hp"
"ui_score"
"player_current_state"
"enemy_spawn_count"

# GLOBAL variables - use descriptive names
"player_level"
"game_difficulty"
"audio_master_volume"
"current_scene_name"
```

### 3. Validate Preconditions

```gdscript
func validate() -> Array[String]:
	var errors = super.validate()

	if variable_name.is_empty():
		errors.append("变量名不能为空")

	# The SCOPE scope requires ScopeVariableManager
	if variable_scope == BaseVariable.VariableScope.SCOPE:
		var manager = ScopeVariableManager.get_instance()
		if manager == null:
			errors.append("未找到 ScopeVariableManager 实例")

	return errors
```

### 4. Unified Display Format

```gdscript
func _update_resource_name():
	var scope_str = VariableScopeUtils.enum_to_string(variable_scope).to_upper()
	resource_name = "Set %s → %s [%s]" % [target_property, variable_name, scope_str]

func get_description() -> String:
	var scope_str = VariableScopeUtils.enum_to_string(variable_scope).to_upper()
	return "设置 %s = %s [%s]" % [target_property, value, scope_str]
```

## Troubleshooting

### Problem: SCOPE Variable Returns null

**Possible causes:**
1. No `ScopeVariableContainer` node was added to the scene
2. `scope_id` was not set
3. The `ScopeVariableManager` instance does not exist
4. The node is not in the scene tree

**Validation code:**
```gdscript
func validate() -> Array[String]:
	var errors = super.validate()

	if value_scope == BaseVariable.VariableScope.SCOPE:
		var manager = ScopeVariableManager.get_instance()
		if manager == null:
			errors.append("未找到 ScopeVariableManager 实例")

	return errors
```

### Problem: Variable Value Does Not Update

**Checklist:**
1. Confirm you used the correct scope
2. Confirm the variable name is spelled correctly
3. Check whether variables with the same name exist in different scopes
4. Verify that the instruction execution order is correct

**Debugging method:**
```gdscript
# Add a log instruction to inspect the variable value
PrintVariableValue:
    variable_name: "my_var"
    variable_scope: SCOPE
```

## Reference Resources

- **Full architecture document:** [Variable System Design Document](../../system_docs/architecture/variable_system_design.md)
- **Example scene:** `addons/fuse/demos/variable_system_demo.tscn`

## Quick Reference

### VariableOperations Methods

```gdscript
# Get a variable
VariableOperations.get_variable(context, name, scope, default_value) -> Variant

# Set a variable
VariableOperations.set_variable(context, name, scope, value) -> bool

# Check whether a variable exists
VariableOperations.has_variable(context, name, scope) -> bool
```

### VariableScope Enum

```gdscript
BaseVariable.VariableScope.LOCAL   # Local variable
BaseVariable.VariableScope.SCOPE   # Scope variable
BaseVariable.VariableScope.GLOBAL  # Global variable
```

### ScopeSource Enum (only used with SCOPE)

```gdscript
ScopeSource.NEAREST         # Nearest container
ScopeSource.CUSTOM_ID       # Specified scope_id
ScopeSource.TRIGGER_SCOPE   # The Trigger node's container
ScopeSource.TARGET_NODE     # The target node's container
```

That's it! Once you master the LOCAL, SCOPE, and GLOBAL three-layer variable system, you can manage data flexibly in Fuse visual programming. Remember: prefer LOCAL, use SCOPE when necessary, and use GLOBAL sparingly.

The next stop for variables is "using" them: having instruction parameters read from variables at runtime—for the direct-value/variable dual-track usage, see the [Variable Binding Usage Guide](07-variable-binding-guide.md).
