> 🌐 [**中文版**](../../../zh_CN/system_docs/architecture/condition_system_design.md) | English

# Condition System Detailed Design

## Table of Contents
1. [Condition System Overview](#1-condition-system-overview)
2. [Core Condition Types](#2-core-condition-types)
3. [Condition Evaluation Mechanism](#3-condition-evaluation-mechanism)
4. [Condition Combination Logic](#4-condition-combination-logic)
5. [Condition Extension Framework](#5-condition-extension-framework)
6. [Built-in Condition Implementations](#6-built-in-condition-implementations)
7. [Condition Debugging and Optimization](#7-condition-debugging-and-optimization)

---

## 1. Condition System Overview

### 1.1 Design Philosophy

The condition system is the decision-making core of the visual programming system, responsible for evaluating various game states and logical conditions. The design philosophy includes:

- **Type safety**: Leverage GDScript's type system to ensure safe condition evaluation
- **High performance**: Optimize the condition evaluation pipeline, with support for short-circuit evaluation
- **Composability**: Support combining and nesting complex conditions
- **Extensibility**: Provide simple interfaces for custom conditions
- **Debuggability**: Provide detailed condition evaluation information

### 1.2 Condition Classification System

```mermaid
graph TB
    BaseCondition[BaseCondition Base Class]

    subgraph "Variable Conditions"
        VariableCondition[Variable Condition]
        VariableCompareCondition[Variable Compare Condition]
        VariableExistsCondition[Variable Exists Condition]
        VariableTypeCondition[Variable Type Condition]
    end

    subgraph "Node Conditions"
        CheckNodeExists[Node Exists Condition]
        NodeGroupCondition[Node Group Condition]
        NodePropertyCondition[Node Property Condition]
        NodeDistanceCondition[Node Distance Condition]
    end

    subgraph "Input Conditions"
        KeyPressedCondition[Key Pressed Condition]
        InputActionCondition[Input Action Condition]
        MousePositionCondition[Mouse Position Condition]
        GestureCondition[Gesture Condition]
    end

    subgraph "Physics Conditions"
        AreaOverlapCondition[Area Overlap Condition]
        CollisionCondition[Collision Condition]
        VelocityCondition[Velocity Condition]
        RaycastCondition[Raycast Condition]
    end

    subgraph "Time Conditions"
        TimeRangeCondition[Time Range Condition]
        TimerCondition[Timer Condition]
        CooldownCondition[Cooldown Condition]
        IntervalCondition[Interval Condition]
    end

    subgraph "Game State Conditions"
        SceneCondition[Scene Condition]
        GameStateCondition[Game State Condition]
        LevelCondition[Level Condition]
        QuestCondition[Quest Condition]
    end

    subgraph "Logical Conditions"
        AndCondition[AND Condition]
        OrCondition[OR Condition]
        NotCondition[NOT Condition]
        XorCondition[XOR Condition]
    end

    subgraph "Mathematical Conditions"
        CompareCondition[Compare Condition]
        RangeCondition[Range Condition]
        RandomCondition[Random Condition]
        ExpressionCondition[Expression Condition]
    end

    subgraph "Custom Conditions"
        ScriptCondition[Script Condition]
        SignalCondition[Signal Condition]
        EventCondition[Event Condition]
        NetworkCondition[Network Condition]
    end

    BaseCondition --> "Variable Conditions"
    BaseCondition --> "Node Conditions"
    BaseCondition --> "Input Conditions"
    BaseCondition --> "Physics Conditions"
    BaseCondition --> "Time Conditions"
    BaseCondition --> "Game State Conditions"
    BaseCondition --> "Logical Conditions"
    BaseCondition --> "Mathematical Conditions"
    BaseCondition --> "Custom Conditions"
```

---

## 2. Core Condition Types

### 2.1 Base Condition Class

```gdscript
@tool
class_name BaseCondition extends Resource
@icon("res://addons/visual_programming/icons/condition.svg")

## Condition configuration
@export_group("Condition Settings")
@export var enabled: bool = true
@export var debug_mode: bool = false
@export var negate_result: bool = false

## Condition state
var last_evaluation_time: float = 0.0
var last_result: bool = false
var evaluation_count: int = 0

## Condition evaluation interface
## context: ExecutionContext - execution context
## returns: bool - whether the condition is satisfied
func check(context: ExecutionContext) -> bool:
    if not enabled:
        _log_debug("Condition is disabled, returning false")
        return false

    evaluation_count += 1
    last_evaluation_time = Time.get_ticks_msec() / 1000.0

    var result = _evaluate_condition(context)

    # Apply negation
    if negate_result:
        result = not result

    last_result = result

    _log_debug("Condition evaluated: %s (negated: %s)" % [result, negate_result])

    return result

## Concrete evaluation logic implemented by subclasses
func _evaluate_condition(context: ExecutionContext) -> bool:
    return true

## Condition validation interface
func validate() -> Array[String]:
    return []

## Condition description
func get_description() -> String:
    return "Base Condition"

## Condition icon
func get_icon() -> Texture2D:
    return null

## Get condition status information
func get_status_info() -> Dictionary:
    return {
        "enabled": enabled,
        "last_evaluation_time": last_evaluation_time,
        "last_result": last_result,
        "evaluation_count": evaluation_count,
        "negate_result": negate_result
    }

## Debug logging
func _log_debug(message: String):
    if debug_mode:
        print("[DEBUG][Condition] %s: %s" % [get_description(), message])

func _log_warning(message: String):
    if debug_mode:
        push_warning("[WARNING][Condition] %s: %s" % [get_description(), message])

func _log_error(message: String):
    if debug_mode:
        push_error("[ERROR][Condition] %s: %s" % [get_description(), message])
```

### 2.2 Variable Conditions

#### 2.2.1 Variable Compare Condition

```gdscript
@tool
class_name VariableCompareCondition extends BaseCondition
@icon("res://addons/visual_programming/icons/variable_compare.svg")

@export_group("Variable Settings")
@export var variable_name: String = ""
@export_enum("Local", "Trigger", "Global") var variable_scope: int = 0
@export_group("Comparison Settings")
@export_enum("Equals", "Not Equals", "Greater Than", "Less Than", "Greater Equal", "Less Equal") var comparison_operator: int = 0
@export_group("Value Settings")
@export_enum("Literal", "Variable", "Expression") var value_source: int = 0
@export_enum("bool", "int", "float", "String", "Vector2", "Vector3", "Color") var value_type: int = 0
@export var bool_value: bool = false
@export var int_value: int = 0
@export var float_value: float = 0.0
@export var string_value: String = ""
@export var vector2_value: Vector2 = Vector2.ZERO
@export var vector3_value: Vector3 = Vector3.ZERO
@export var color_value: Color = Color.WHITE
@export var compare_variable_name: String = ""
@export var expression: String = ""

func _evaluate_condition(context: ExecutionContext) -> bool:
    if variable_name.is_empty():
        _log_error("Variable name is empty")
        return false

    var variable_value = _get_variable_value(context)
    var compare_value = _get_compare_value(context)

    var result = _compare_values(variable_value, compare_value)

    _log_debug("Variable comparison: %s %s %s = %s" % [
        variable_value,
        _get_operator_symbol(),
        compare_value,
        result
    ])

    return result

func _get_variable_value(context: ExecutionContext) -> Variant:
    match variable_scope:
        0: # Local
            return context.local_variables.get(variable_name, null)
        1: # Trigger
            if context.trigger and context.trigger.local_variables:
                return context.trigger.local_variables.get(variable_name, null)
        2: # Global
            if context.global_variables:
                return context.global_variables.get(variable_name, null)
    return null

func _get_compare_value(context: ExecutionContext) -> Variant:
    match value_source:
        0: # Literal
            match value_type:
                0: return bool_value
                1: return int_value
                2: return float_value
                3: return string_value
                4: return vector2_value
                5: return vector3_value
                6: return color_value
        1: # Variable
            return context.get_variable(compare_variable_name)
        2: # Expression
            return _evaluate_expression(context)
    return null

func _evaluate_expression(context: ExecutionContext) -> Variant:
    if expression.is_empty():
        return null

    var expr = Expression.new()
    var parse_result = expr.parse(expression)

    if parse_result != OK:
        _log_error("Failed to parse expression: %s" % expression)
        return null

    # Set up the variable context
    for var_name in context.local_variables.keys():
        expr.set_input_value(var_name, context.local_variables[var_name])

    var result = expr.execute()
    if result is String:
        _log_error("Expression execution error: %s" % result)
        return null

    return result

func _compare_values(value1: Variant, value2: Variant) -> bool:
    # Type check
    if typeof(value1) != typeof(value2):
        _log_warning("Type mismatch in comparison: %s vs %s" % [typeof(value1), typeof(value2)])
        return false

    match comparison_operator:
        0: return value1 == value2  # Equals
        1: return value1 != value2  # Not Equals
        2: return value1 > value2   # Greater Than
        3: return value1 < value2   # Less Than
        4: return value1 >= value2  # Greater Equal
        5: return value1 <= value2  # Less Equal
    return false

func _get_operator_symbol() -> String:
    match comparison_operator:
        0: return "=="
        1: return "!="
        2: return ">"
        3: return "<"
        4: return ">="
        5: return "<="
    return "?"

func get_description() -> String:
    var scope_name = ["local", "trigger", "global"][variable_scope]
    var operator_symbol = _get_operator_symbol()
    var value_desc = ""

    match value_source:
        0: # Literal
            value_desc = str(_get_compare_value(null))
        1: # Variable
            value_desc = "variable: %s" % compare_variable_name
        2: # Expression
            value_desc = "expression: %s" % expression

    return "%s variable '%s' %s %s" % [scope_name, variable_name, operator_symbol, value_desc]

func validate() -> Array[String]:
    var errors: Array[String] = []

    if variable_name.is_empty():
        errors.append("Variable name cannot be empty")

    if value_source == 1 and compare_variable_name.is_empty():
        errors.append("Compare variable name cannot be empty when using variable as value source")

    if value_source == 2 and expression.is_empty():
        errors.append("Expression cannot be empty when using expression as value source")

    return errors
```

#### 2.2.2 Variable Exists Condition

```gdscript
@tool
class_name VariableExistsCondition extends BaseCondition
@icon("res://addons/visual_programming/icons/variable_exists.svg")

@export_group("Variable Settings")
@export var variable_name: String = ""
@export_enum("Local", "Trigger", "Global") var variable_scope: int = 0
@export_group("Type Settings")
@export var check_type: bool = false
@export_enum("Any", "bool", "int", "float", "String", "Vector2", "Vector3", "Color", "Node", "Array", "Dictionary") var expected_type: int = 0

func _evaluate_condition(context: ExecutionContext) -> bool:
    if variable_name.is_empty():
        _log_error("Variable name is empty")
        return false

    var variable_value = _get_variable_value(context)
    var exists = variable_value != null

    if exists and check_type:
        var actual_type = _get_variable_type_index(variable_value)
        exists = actual_type == expected_type

    _log_debug("Variable '%s' exists: %s" % [variable_name, exists])

    return exists

func _get_variable_value(context: ExecutionContext) -> Variant:
    match variable_scope:
        0: # Local
            return context.local_variables.get(variable_name, null)
        1: # Trigger
            if context.trigger and context.trigger.local_variables:
                return context.trigger.local_variables.get(variable_name, null)
        2: # Global
            if context.global_variables:
                return context.global_variables.get(variable_name, null)
    return null

func _get_variable_type_index(value: Variant) -> int:
    if value is bool:
        return 1
    elif value is int:
        return 2
    elif value is float:
        return 3
    elif value is String:
        return 4
    elif value is Vector2:
        return 5
    elif value is Vector3:
        return 6
    elif value is Color:
        return 7
    elif value is Node:
        return 8
    elif value is Array:
        return 9
    elif value is Dictionary:
        return 10
    else:
        return 0  # Any

func get_description() -> String:
    var scope_name = ["local", "trigger", "global"][variable_scope]
    var type_desc = ""

    if check_type:
        var type_names = ["Any", "bool", "int", "float", "String", "Vector2", "Vector3", "Color", "Node", "Array", "Dictionary"]
        type_desc = " (type: %s)" % type_names[expected_type]

    return "%s variable '%s' exists%s" % [scope_name, variable_name, type_desc]

func validate() -> Array[String]:
    var errors: Array[String] = []

    if variable_name.is_empty():
        errors.append("Variable name cannot be empty")

    return errors
```

### 2.3 Node Conditions

#### 2.3.1 Node Exists Condition

```gdscript
@tool
class_name CheckNodeExists extends BaseCondition
@icon("res://addons/visual_programming/icons/node_exists.svg")

@export_group("Node Settings")
@export var node_path: NodePath
@export_enum("Relative to Trigger", "Relative to Target", "Absolute") var path_type: int = 0
@export_group("Filter Settings")
@export var check_type: bool = false
@export var expected_type: String = "Node"
@export var check_group: bool = false
@export var required_group: String = ""

func _evaluate_condition(context: ExecutionContext) -> bool:
    var node = _get_target_node(context)
    var exists = node != null

    if exists:
        if check_type:
            exists = _check_node_type(node)

        if exists and check_group:
            exists = node.is_in_group(required_group)

    _log_debug("Node '%s' exists: %s" % [node_path, exists])

    return exists

func _get_target_node(context: ExecutionContext) -> Node:
    if node_path.is_empty():
        return null

    var base_node: Node

    match path_type:
        0: # Relative to Trigger
            base_node = context.trigger
        1: # Relative to Target
            base_node = context.target
        2: # Absolute
            base_node = context.get_tree().current_scene

    if not base_node:
        return null

    return base_node.get_node_or_null(node_path)

func _check_node_type(node: Node) -> bool:
    if expected_type == "Node":
        return true

    # Check the class name
    if node.get_class() == expected_type:
        return true

    # Check the script class name
    if node.get_script():
        var script_class = node.get_script().get_global_name()
        if script_class == expected_type:
            return true

    # Check inheritance
    return ClassDB.class_exists(expected_type) and node.is_class(expected_type)

func get_description() -> String:
    var path_desc = ""

    match path_type:
        0: path_desc = "relative to trigger"
        1: path_desc = "relative to target"
        2: path_desc = "absolute"

    var filter_desc = ""

    if check_type:
        filter_desc += " (type: %s)" % expected_type

    if check_group:
        filter_desc += " (group: %s)" % required_group

    return "Node '%s' exists (%s)%s" % [node_path, path_desc, filter_desc]

func validate() -> Array[String]:
    var errors: Array[String] = []

    if node_path.is_empty():
        errors.append("Node path cannot be empty")

    if check_group and required_group.is_empty():
        errors.append("Required group cannot be empty when checking group")

    return errors
```

#### 2.3.2 Node Distance Condition

```gdscript
@tool
class_name NodeDistanceCondition extends BaseCondition
@icon("res://addons/visual_programming/icons/node_distance.svg")

@export_group("Node Settings")
@export var node_a_path: NodePath
@export var node_b_path: NodePath
@export_enum("Relative to Trigger", "Relative to Target", "Absolute") var path_type: int = 0
@export_group("Distance Settings")
@export_enum("Less Than", "Greater Than", "Equals", "Range") var comparison_type: int = 0
@export var distance_threshold: float = 10.0
@export var min_distance: float = 5.0
@export var max_distance: float = 15.0
@export_group("Advanced Settings")
@export var use_2d_distance: bool = false
@export var ignore_y_axis: bool = false

func _evaluate_condition(context: ExecutionContext) -> bool:
    var node_a = _get_node(node_a_path, context)
    var node_b = _get_node(node_b_path, context)

    if not node_a or not node_b:
        _log_error("One or both nodes not found")
        return false

    var distance = _calculate_distance(node_a, node_b)
    var result = _compare_distance(distance)

    _log_debug("Distance between nodes: %.2f, condition: %s" % [distance, result])

    return result

func _get_node(node_path: NodePath, context: ExecutionContext) -> Node:
    if node_path.is_empty():
        return null

    var base_node: Node

    match path_type:
        0: # Relative to Trigger
            base_node = context.trigger
        1: # Relative to Target
            base_node = context.target
        2: # Absolute
            base_node = context.get_tree().current_scene

    if not base_node:
        return null

    return base_node.get_node_or_null(node_path)

func _calculate_distance(node_a: Node, node_b: Node) -> float:
    var pos_a: Vector3
    var pos_b: Vector3

    if use_2d_distance:
        pos_a = Vector3((node_a as Node2D).global_position.x, (node_a as Node2D).global_position.y, 0) if node_a is Node2D else node_a.global_position
        pos_b = Vector3((node_b as Node2D).global_position.x, (node_b as Node2D).global_position.y, 0) if node_b is Node2D else node_b.global_position
    else:
        pos_a = node_a.global_position if node_a is Node3D else Vector3((node_a as Node2D).global_position.x, (node_a as Node2D).global_position.y, 0)
        pos_b = node_b.global_position if node_b is Node3D else Vector3((node_b as Node2D).global_position.x, (node_b as Node2D).global_position.y, 0)

    if ignore_y_axis:
        pos_a.y = 0
        pos_b.y = 0

    return pos_a.distance_to(pos_b)

func _compare_distance(distance: float) -> bool:
    match comparison_type:
        0: return distance < distance_threshold  # Less Than
        1: return distance > distance_threshold  # Greater Than
        2: return abs(distance - distance_threshold) < 0.001  # Equals
        3: return distance >= min_distance and distance <= max_distance  # Range
    return false

func get_description() -> String:
    var path_desc = ["relative to trigger", "relative to target", "absolute"][path_type]
    var comparison_desc = ["<", ">", "=", "range"][comparison_type]

    match comparison_type:
        0, 1, 2:
            return "Distance between nodes %s %.1f (%s)" % [comparison_desc, distance_threshold, path_desc]
        3:
            return "Distance between nodes in range [%.1f, %.1f] (%s)" % [min_distance, max_distance, path_desc]
    return ""

func validate() -> Array[String]:
    var errors: Array[String] = []

    if node_a_path.is_empty():
        errors.append("Node A path cannot be empty")

    if node_b_path.is_empty():
        errors.append("Node B path cannot be empty")

    if distance_threshold < 0:
        errors.append("Distance threshold cannot be negative")

    if min_distance < 0 or max_distance < 0:
        errors.append("Distance range values cannot be negative")

    if min_distance > max_distance:
        errors.append("Min distance cannot be greater than max distance")

    return errors
```

### 2.4 Logical Conditions

#### 2.4.1 AND Condition

```gdscript
@tool
class_name AndCondition extends BaseCondition
@icon("res://addons/visual_programming/icons/and_condition.svg")

@export_group("Condition Settings")
@export var sub_conditions: Array[BaseCondition] = []
@export var short_circuit: bool = true

func _evaluate_condition(context: ExecutionContext) -> bool:
    if sub_conditions.is_empty():
        _log_warning("No sub-conditions specified, returning true")
        return true

    for condition in sub_conditions:
        if not condition:
            continue

        var result = condition.check(context)

        if not result:
            _log_debug("Condition failed: %s" % condition.get_description())
            if short_circuit:
                return false

        _log_debug("Condition passed: %s" % condition.get_description())

    _log_debug("All conditions passed")
    return true

func get_description() -> String:
    if sub_conditions.is_empty():
        return "AND (empty)"

    var descriptions = []
    for condition in sub_conditions:
        if condition:
            descriptions.append(condition.get_description())

    return "AND [%s]" % descriptions.join(", ")

func validate() -> Array[String]:
    var errors: Array[String] = []

    if sub_conditions.is_empty():
        errors.append("AND condition requires at least one sub-condition")

    for i in range(sub_conditions.size()):
        var condition = sub_conditions[i]
        if not condition:
            errors.append("Sub-condition %d is null" % i)
        else:
            errors.append_array(condition.validate())

    return errors
```

#### 2.4.2 OR Condition

```gdscript
@tool
class_name OrCondition extends BaseCondition
@icon("res://addons/visual_programming/icons/or_condition.svg")

@export_group("Condition Settings")
@export var sub_conditions: Array[BaseCondition] = []
@export var short_circuit: bool = true

func _evaluate_condition(context: ExecutionContext) -> bool:
    if sub_conditions.is_empty():
        _log_warning("No sub-conditions specified, returning false")
        return false

    for condition in sub_conditions:
        if not condition:
            continue

        var result = condition.check(context)

        if result:
            _log_debug("Condition passed: %s" % condition.get_description())
            if short_circuit:
                return true

        _log_debug("Condition failed: %s" % condition.get_description())

    _log_debug("All conditions failed")
    return false

func get_description() -> String:
    if sub_conditions.is_empty():
        return "OR (empty)"

    var descriptions = []
    for condition in sub_conditions:
        if condition:
            descriptions.append(condition.get_description())

    return "OR [%s]" % descriptions.join(", ")

func validate() -> Array[String]:
    var errors: Array[String] = []

    if sub_conditions.is_empty():
        errors.append("OR condition requires at least one sub-condition")

    for i in range(sub_conditions.size()):
        var condition = sub_conditions[i]
        if not condition:
            errors.append("Sub-condition %d is null" % i)
        else:
            errors.append_array(condition.validate())

    return errors
```

---

## 3. Condition Evaluation Mechanism

### 3.1 Condition Evaluator

```gdscript
@tool
class_name ConditionEvaluator extends RefCounted

## Evaluation result
class EvaluationResult:
    var condition: BaseCondition
    var result: bool
    var evaluation_time: float
    var error_message: String = ""

## Evaluation configuration
class EvaluationConfig:
    var enable_short_circuit: bool = true
    var enable_caching: bool = true
    var cache_timeout: float = 0.1
    var enable_profiling: bool = false

var evaluation_cache: Dictionary = {}
var config: EvaluationConfig

func _init():
    config = EvaluationConfig.new()

## Evaluate a single condition
func evaluate_condition(condition: BaseCondition, context: ExecutionContext) -> EvaluationResult:
    var result = EvaluationResult.new()
    result.condition = condition

    if not condition:
        result.error_message = "Condition is null"
        return result

    # Check the cache
    if config.enable_caching:
        var cached_result = _get_cached_result(condition, context)
        if cached_result != null:
            result.result = cached_result
            return result

    var start_time = Time.get_ticks_msec() / 1000.0

    try:
        result.result = condition.check(context)
    except:
        result.error_message = "Exception during condition evaluation"
        result.result = false

    result.evaluation_time = Time.get_ticks_msec() / 1000.0 - start_time

    # Cache the result
    if config.enable_caching and result.error_message.is_empty():
        _cache_result(condition, context, result.result)

    return result

## Evaluate a list of conditions
func evaluate_conditions(conditions: Array[BaseCondition], context: ExecutionContext) -> Array[EvaluationResult]:
    var results: Array[EvaluationResult] = []

    for condition in conditions:
        var result = evaluate_condition(condition, context)
        results.append(result)

        # Short-circuit evaluation
        if config.enable_short_circuit and not result.result:
            break

    return results

## Get the cached result
func _get_cached_result(condition: BaseCondition, context: ExecutionContext) -> bool:
    var cache_key = _generate_cache_key(condition, context)
    var cache_entry = evaluation_cache.get(cache_key)

    if not cache_entry:
        return null

    var current_time = Time.get_ticks_msec() / 1000.0
    if current_time - cache_entry.timestamp > config.cache_timeout:
        evaluation_cache.erase(cache_key)
        return null

    return cache_entry.result

## Cache the result
func _cache_result(condition: BaseCondition, context: ExecutionContext, result: bool):
    var cache_key = _generate_cache_key(condition, context)
    var cache_entry = {
        "result": result,
        "timestamp": Time.get_ticks_msec() / 1000.0
    }

    evaluation_cache[cache_key] = cache_entry

    # Limit the cache size
    if evaluation_cache.size() > 1000:
        _cleanup_cache()

## Generate the cache key
func _generate_cache_key(condition: BaseCondition, context: ExecutionContext) -> String:
    var key_parts = [
        condition.get_instance_id(),
        str(context.trigger.get_instance_id()) if context.trigger else "null",
        str(context.target.get_instance_id()) if context.target else "null",
        str(context.local_variables.hash())
    ]
    return key_parts.join("_")

## Clean up the cache
func _cleanup_cache():
    var oldest_key = ""
    var oldest_time = INF

    for key in evaluation_cache.keys():
        var cache_entry = evaluation_cache[key]
        if cache_entry.timestamp < oldest_time:
            oldest_time = cache_entry.timestamp
            oldest_key = key

    if not oldest_key.is_empty():
        evaluation_cache.erase(oldest_key)

## Clear the cache
func clear_cache():
    evaluation_cache.clear()

## Set the evaluation configuration
func set_config(new_config: EvaluationConfig):
    config = new_config
```

### 3.2 Condition Combiner

```gdscript
@tool
class_name ConditionCombiner extends RefCounted

## Combination types
enum CombinationType {
    AND,
    OR,
    NAND,
    NOR,
    XOR,
    MAJORITY
}

## Combine conditions
func combine_conditions(
    conditions: Array[BaseCondition],
    combination_type: CombinationType,
    context: ExecutionContext
) -> bool:
    match combination_type:
        CombinationType.AND:
            return _combine_and(conditions, context)
        CombinationType.OR:
            return _combine_or(conditions, context)
        CombinationType.NAND:
            return not _combine_and(conditions, context)
        CombinationType.NOR:
            return not _combine_or(conditions, context)
        CombinationType.XOR:
            return _combine_xor(conditions, context)
        CombinationType.MAJORITY:
            return _combine_majority(conditions, context)
    return false

## AND combination
func _combine_and(conditions: Array[BaseCondition], context: ExecutionContext) -> bool:
    for condition in conditions:
        if not condition or not condition.check(context):
            return false
    return true

## OR combination
func _combine_or(conditions: Array[BaseCondition], context: ExecutionContext) -> bool:
    for condition in conditions:
        if condition and condition.check(context):
            return true
    return false

## XOR combination
func _combine_xor(conditions: Array[BaseCondition], context: ExecutionContext) -> bool:
    var true_count = 0
    for condition in conditions:
        if condition and condition.check(context):
            true_count += 1
    return true_count == 1

## Majority combination
func _combine_majority(conditions: Array[BaseCondition], context: ExecutionContext) -> bool:
    if conditions.is_empty():
        return false

    var true_count = 0
    for condition in conditions:
        if condition and condition.check(context):
            true_count += 1

    return true_count > conditions.size() / 2.0

## Complex combination
func combine_complex(
    condition_groups: Array[Array[BaseCondition]],
    group_operators: Array[CombinationType],
    context: ExecutionContext
) -> bool:
    if condition_groups.is_empty():
        return false

    var group_results = []

    # Evaluate each condition group
    for group in condition_groups:
        var group_result = true  # Default AND combination
        if group.size() > 0:
            group_result = _combine_and(group, context)
        group_results.append(group_result)

    # Combine the group results
    if group_results.size() == 1:
        return group_results[0]

    var final_result = group_results[0]

    for i in range(1, group_results.size()):
        var operator = group_operators[i - 1] if i - 1 < group_operators.size() else CombinationType.AND

        match operator:
            CombinationType.AND:
                final_result = final_result and group_results[i]
            CombinationType.OR:
                final_result = final_result or group_results[i]
            CombinationType.XOR:
                final_result = final_result != group_results[i]

    return final_result
```

---

## 4. Condition Combination Logic

### 4.1 Condition Tree

```gdscript
@tool
class_name ConditionTree extends RefCounted

## Condition node types
enum NodeType {
    LEAF,
    AND,
    OR,
    NOT,
    CUSTOM
}

## Condition node
class ConditionNode:
    var type: NodeType
    var condition: BaseCondition  # Only for LEAF nodes
    var children: Array[ConditionNode] = []
    var custom_evaluator: Callable  # For CUSTOM nodes

    func evaluate(context: ExecutionContext) -> bool:
        match type:
            NodeType.LEAF:
                return condition.check(context) if condition else false
            NodeType.AND:
                for child in children:
                    if not child.evaluate(context):
                        return false
                return true
            NodeType.OR:
                for child in children:
                    if child.evaluate(context):
                        return true
                return false
            NodeType.NOT:
                if children.size() > 0:
                    return not children[0].evaluate(context)
                return false
            NodeType.CUSTOM:
                if custom_evaluator.is_valid():
                    return custom_evaluator.call(children, context)
        return false

var root: ConditionNode = null

## Build a simple AND tree
func build_and_tree(conditions: Array[BaseCondition]) -> ConditionNode:
    if conditions.is_empty():
        return null

    var and_node = ConditionNode.new()
    and_node.type = NodeType.AND

    for condition in conditions:
        var leaf_node = ConditionNode.new()
        leaf_node.type = NodeType.LEAF
        leaf_node.condition = condition
        and_node.children.append(leaf_node)

    return and_node

## Build a simple OR tree
func build_or_tree(conditions: Array[BaseCondition]) -> ConditionNode:
    if conditions.is_empty():
        return null

    var or_node = ConditionNode.new()
    or_node.type = NodeType.OR

    for condition in conditions:
        var leaf_node = ConditionNode.new()
        leaf_node.type = NodeType.LEAF
        leaf_node.condition = condition
        or_node.children.append(leaf_node)

    return or_node

## Build a complex tree
func build_complex_tree(
    conditions: Array[BaseCondition],
    structure: String  # e.g.: "(A AND B) OR (C AND D)"
) -> ConditionNode:
    # A simple parser could be implemented here to parse the structure string
    # For simplicity, a basic implementation is provided here

    var tokens = _tokenize_structure(structure)
    return _parse_tokens(tokens, 0).node

## Tokenize the structure string
func _tokenize_structure(structure: String) -> Array:
    var tokens = []
    var current_token = ""

    for i in range(structure.length()):
        var char = structure[i]

        match char:
            "(", ")", "AND", "OR", "NOT":
                if not current_token.is_empty():
                    tokens.append(current_token.strip_edges())
                    current_token = ""
                tokens.append(char)
            " ":
                continue  # Skip spaces
            _:
                current_token += char

    if not current_token.is_empty():
        tokens.append(current_token.strip_edges())

    return tokens

## Parse the tokens
func _parse_tokens(tokens: Array, index: int) -> Dictionary:
    if index >= tokens.size():
        return {"node": null, "next_index": index}

    var token = tokens[index]

    match token:
        "(":
            var sub_result = _parse_sub_expression(tokens, index + 1)
            return sub_result
        "NOT":
            var not_result = _parse_tokens(tokens, index + 1)
            var not_node = ConditionNode.new()
            not_node.type = NodeType.NOT
            not_node.children.append(not_result.node)
            return {"node": not_node, "next_index": not_result.next_index}
        _:
            # Assume this is a condition reference
            var leaf_node = ConditionNode.new()
            leaf_node.type = NodeType.LEAF
            # The corresponding condition should be looked up by token here
            # For simplicity, we create a placeholder
            return {"node": leaf_node, "next_index": index + 1}

## Parse a sub-expression
func _parse_sub_expression(tokens: Array, start_index: int) -> Dictionary:
    var nodes = []
    var operators = []
    var i = start_index

    while i < tokens.size():
        var token = tokens[i]

        match token:
            ")":
                break
            "AND", "OR":
                operators.append(token)
            _:
                var result = _parse_tokens(tokens, i)
                nodes.append(result.node)
                i = result.next_index - 1

        i += 1

    # Build the subtree
    if nodes.size() == 1:
        return {"node": nodes[0], "next_index": i}

    # Simplified implementation: assume all operators are AND or OR with equal precedence
    var root_node = ConditionNode.new()
    root_node.type = NodeType.AND if operators[0] == "AND" else NodeType.OR
    root_node.children = nodes

    return {"node": root_node, "next_index": i}

## Evaluate the condition tree
func evaluate(context: ExecutionContext) -> bool:
    if not root:
        return false

    return root.evaluate(context)

## Set the root node
func set_root(node: ConditionNode):
    root = node

## Get the tree depth
func get_tree_depth() -> int:
    if not root:
        return 0

    return _calculate_depth(root)

## Calculate the node depth
func _calculate_depth(node: ConditionNode) -> int:
    if node.children.is_empty():
        return 1

    var max_child_depth = 0
    for child in node.children:
        var child_depth = _calculate_depth(child)
        max_child_depth = max(max_child_depth, child_depth)

    return max_child_depth + 1

## Get the node count
func get_node_count() -> int:
    if not root:
        return 0

    return _count_nodes(root)

## Count the nodes
func _count_nodes(node: ConditionNode) -> int:
    var count = 1

    for child in node.children:
        count += _count_nodes(child)

    return count
```

---

## 5. Condition Extension Framework

### 5.1 Condition Registration System

```gdscript
@tool
class_name ConditionRegistry extends RefCounted

static var _registered_conditions: Dictionary = {}
static var _condition_categories: Dictionary = {}
static var _condition_metadata: Dictionary = {}

## Condition metadata
class ConditionMetadata:
    var name: String
    var description: String
    var category: String
    var icon: Texture2D
    var version: String
    var author: String
    var dependencies: Array[String] = []

## Register a condition type
static func register_condition(
    condition_name: String,
    condition_script: Script,
    metadata: ConditionMetadata
) -> bool:
    if _registered_conditions.has(condition_name):
        print_warning("Condition '%s' is already registered" % condition_name)
        return false

    # Validate the condition script
    if not _validate_condition_script(condition_script):
        print_error("Invalid condition script for '%s'" % condition_name)
        return false

    _registered_conditions[condition_name] = condition_script
    _condition_metadata[condition_name] = metadata

    # Add to the category
    if not _condition_categories.has(metadata.category):
        _condition_categories[metadata.category] = []
    _condition_categories[metadata.category].append(condition_name)

    print("Registered condition: %s" % condition_name)
    return true

## Validate the condition script
static func _validate_condition_script(condition_script: Script) -> bool:
    # Check whether the script inherits from BaseCondition
    var base_class = condition_script.get_base_script()
    while base_class:
        if base_class.get_global_name() == "BaseCondition":
            return true
        base_class = base_class.get_base_script()
    return false

## Create a condition instance
static func create_condition(condition_name: String) -> BaseCondition:
    var condition_script = _registered_conditions.get(condition_name)
    if not condition_script:
        print_error("Condition '%s' not found" % condition_name)
        return null

    var condition = condition_script.new()
    if not condition is BaseCondition:
        print_error("Failed to create condition '%s'" % condition_name)
        return null

    return condition

## Get all registered conditions
static func get_registered_conditions() -> Dictionary:
    return _registered_conditions.duplicate()

## Get the condition categories
static func get_condition_categories() -> Dictionary:
    return _condition_categories.duplicate()

## Get the condition metadata
static func get_condition_metadata(condition_name: String) -> ConditionMetadata:
    return _condition_metadata.get(condition_name)

## Auto-discover and register conditions
static func auto_register_conditions():
    var condition_dir = "res://addons/visual_programming/conditions/"
    _scan_directory_for_conditions(condition_dir)

## Scan a directory for conditions
static func _scan_directory_for_conditions(directory_path: String):
    var dir = DirAccess.open(directory_path)
    if not dir:
        return

    dir.list_dir_begin()
    var file_name = dir.get_next()

    while file_name != "":
        if file_name.ends_with(".gd"):
            var script_path = directory_path + file_name
            _try_register_condition_from_file(script_path)
        file_name = dir.get_next()

    dir.list_dir_end()

## Try to register a condition from a file
static func _try_register_condition_from_file(script_path: String):
    var script = load(script_path)
    if not script or not script is Script:
        return

    # Check for a custom registration method
    if script.has_method("auto_register"):
        script.auto_register()
```

### 5.2 Condition Template System

```gdscript
@tool
class_name ConditionTemplate extends Resource

@export var template_name: String
@export var description: String
@export var category: String
@export var condition_type: String
@export var default_properties: Dictionary = {}
@export var required_parameters: Array[String] = []

## Create a condition from the template
func create_condition(custom_properties: Dictionary = {}) -> BaseCondition:
    var condition = ConditionRegistry.create_condition(condition_type)
    if not condition:
        return null

    # Apply default properties
    _apply_default_properties(condition)

    # Apply custom properties
    _apply_custom_properties(condition, custom_properties)

    return condition

## Apply default properties
func _apply_default_properties(condition: BaseCondition):
    for property_name in default_properties:
        var value = default_properties[property_name]
        if condition.has_method("set"):
            condition.set(property_name, value)

## Apply custom properties
func _apply_custom_properties(condition: BaseCondition, custom_properties: Dictionary):
    for property_name in custom_properties:
        var value = custom_properties[property_name]
        if condition.has_method("set"):
            condition.set(property_name, value)

## Validate the condition configuration
func validate_condition_configuration(condition: BaseCondition) -> Array[String]:
    var errors: Array[String] = []

    # Check the required parameters
    for param_name in required_parameters:
        if not condition.get(param_name):
            errors.append("Required parameter '%s' is missing" % param_name)

    # Run condition-specific validation
    if condition.has_method("validate"):
        errors.append_array(condition.validate())

    return errors

## Get the template preview information
func get_preview_info() -> Dictionary:
    return {
        "name": template_name,
        "description": description,
        "category": category,
        "condition_type": condition_type,
        "required_parameters": required_parameters,
        "property_count": default_properties.size()
    }
```

---

## 6. Built-in Condition Implementations

### 6.1 Math Conditions

#### 6.1.1 Range Condition

```gdscript
@tool
class_name RangeCondition extends BaseCondition
@icon("res://addons/visual_programming/icons/range.svg")

@export_group("Value Settings")
@export_enum("Literal", "Variable", "Expression") var value_source: int = 0
@export_enum("int", "float") var value_type: int = 0
@export var int_value: int = 0
@export var float_value: float = 0.0
@export var variable_name: String = ""
@export var expression: String = ""
@export_group("Range Settings")
@export var min_value: float = 0.0
@export var max_value: float = 100.0
@export var inclusive: bool = true

func _evaluate_condition(context: ExecutionContext) -> bool:
    var value = _get_value(context)

    if value == null:
        _log_error("Failed to get value for range comparison")
        return false

    var result = false

    if inclusive:
        result = value >= min_value and value <= max_value
    else:
        result = value > min_value and value < max_value

    _log_debug("Value %.2f in range [%.2f, %.2f]: %s" % [value, min_value, max_value, result])

    return result

func _get_value(context: ExecutionContext) -> Variant:
    match value_source:
        0: # Literal
            match value_type:
                0: return int_value
                1: return float_value
        1: # Variable
            return context.get_variable(variable_name)
        2: # Expression
            return _evaluate_expression(context)
    return null

func _evaluate_expression(context: ExecutionContext) -> Variant:
    if expression.is_empty():
        return null

    var expr = Expression.new()
    var parse_result = expr.parse(expression)

    if parse_result != OK:
        _log_error("Failed to parse expression: %s" % expression)
        return null

    var result = expr.execute()
    if result is String:
        _log_error("Expression execution error: %s" % result)
        return null

    return result

func get_description() -> String:
    var value_desc = ""

    match value_source:
        0: # Literal
            value_desc = str(_get_value(null))
        1: # Variable
            value_desc = "variable: %s" % variable_name
        2: # Expression
            value_desc = "expression: %s" % expression

    var range_desc = "[%s, %s]" % [min_value, max_value]
    if not inclusive:
        range_desc = "(%s, %s)" % [min_value, max_value]

    return "Value %s in range %s" % [value_desc, range_desc]

func validate() -> Array[String]:
    var errors: Array[String] = []

    if value_source == 1 and variable_name.is_empty():
        errors.append("Variable name cannot be empty when using variable as value source")

    if value_source == 2 and expression.is_empty():
        errors.append("Expression cannot be empty when using expression as value source")

    if min_value > max_value:
        errors.append("Min value cannot be greater than max value")

    return errors
```

### 6.2 Input Conditions

#### 6.2.1 Key Pressed Condition

```gdscript
@tool
class_name KeyPressedCondition extends BaseCondition
@icon("res://addons/visual_programming/icons/key_pressed.svg")

@export_group("Key Settings")
@export var key_code: Key = KEY_SPACE
@export var require_modifier: bool = false
@export var modifier_key: Key = KEY_CTRL
@export_group("Check Settings")
@export var check_pressed: bool = true
@export var check_just_pressed: bool = false
@export var check_just_released: bool = false

func _evaluate_condition(context: ExecutionContext) -> bool:
    var is_pressed = Input.is_key_pressed(key_code)
    var is_just_pressed = Input.is_key_just_pressed(key_code)
    var is_just_released = Input.is_key_just_released(key_code)

    # Check the modifier key
    if require_modifier:
        var modifier_pressed = Input.is_key_pressed(modifier_key)
        if not modifier_pressed:
            _log_debug("Modifier key not pressed")
            return false

    var result = false

    if check_pressed and is_pressed:
        result = true

    if check_just_pressed and is_just_pressed:
        result = true

    if check_just_released and is_just_released:
        result = true

    _log_debug("Key %s check result: %s" % [OS.get_keycode_string(key_code), result])

    return result

func get_description() -> String:
    var key_name = OS.get_keycode_string(key_code)
    var modifier_name = OS.get_keycode_string(modifier_key) if require_modifier else ""
    var check_desc = []

    if check_pressed:
        check_desc.append("pressed")
    if check_just_pressed:
        check_desc.append("just_pressed")
    if check_just_released:
        check_desc.append("just_released")

    return "Key %s %s %s" % [
        ("%s+" % modifier_name if modifier_name else "") + key_name,
        "is" if check_desc.size() == 1 else "is",
        check_desc.join(" or ")
    ]

func validate() -> Array[String]:
    var errors: Array[String] = []

    if not check_pressed and not check_just_pressed and not check_just_released:
        errors.append("At least one check type must be enabled")

    return errors
```

---

## 7. Condition Debugging and Optimization

### 7.1 Condition Debugging System

```gdscript
@tool
class_name ConditionDebugger extends RefCounted

## Debug information
class ConditionDebugInfo:
    var condition: BaseCondition
    var context: ExecutionContext
    var result: bool
    var evaluation_time: float
    var timestamp: float
    var error_message: String = ""

var debug_history: Array[ConditionDebugInfo] = []
var is_debugging: bool = false
var max_debug_history: int = 1000

## Start debugging
func start_debugging():
    is_debugging = true
    debug_history.clear()
    print("Condition debugging started")

## Stop debugging
func stop_debugging():
    is_debugging = false
    print("Condition debugging stopped")

## Record a condition evaluation
func record_condition_evaluation(
    condition: BaseCondition,
    context: ExecutionContext,
    result: bool,
    evaluation_time: float,
    error_message: String = ""
):
    if not is_debugging:
        return

    var debug_info = ConditionDebugInfo.new()
    debug_info.condition = condition
    debug_info.context = context
    debug_info.result = result
    debug_info.evaluation_time = evaluation_time
    debug_info.timestamp = Time.get_ticks_msec() / 1000.0
    debug_info.error_message = error_message

    debug_history.append(debug_info)

    # Limit the debug history size
    if debug_history.size() > max_debug_history:
        debug_history.pop_front()

    _print_debug_info(debug_info)

## Print debug information
func _print_debug_info(debug_info: ConditionDebugInfo):
    print("=== CONDITION DEBUG ===")
    print("Condition: %s" % debug_info.condition.get_description())
    print("Result: %s" % debug_info.result)
    print("Time: %.3f ms" % debug_info.evaluation_time)
    print("Timestamp: %.3f" % debug_info.timestamp)

    if not debug_info.error_message.is_empty():
        print("Error: %s" % debug_info.error_message)

    print("========================")

## Generate a debug report
func generate_debug_report() -> String:
    var report = "CONDITION DEBUG REPORT\n"
    report += "========================\n\n"

    var total_evaluations = debug_history.size()
    var true_results = 0
    var false_results = 0
    var total_time = 0.0
    var error_count = 0

    for debug_info in debug_history:
        if debug_info.result:
            true_results += 1
        else:
            false_results += 1

        total_time += debug_info.evaluation_time

        if not debug_info.error_message.is_empty():
            error_count += 1

    report += "Total Evaluations: %d\n" % total_evaluations
    report += "True Results: %d (%.1f%%)\n" % [true_results, float(true_results) / total_evaluations * 100.0]
    report += "False Results: %d (%.1f%%)\n" % [false_results, float(false_results) / total_evaluations * 100.0]
    report += "Total Time: %.3f ms\n" % total_time
    report += "Average Time: %.3f ms\n" % (total_time / total_evaluations if total_evaluations > 0 else 0)
    report += "Error Count: %d\n" % error_count

    # Group statistics by condition
    var condition_stats = {}
    for debug_info in debug_history:
        var condition_name = debug_info.condition.get_description()
        if not condition_stats.has(condition_name):
            condition_stats[condition_name] = {
                "count": 0,
                "true_count": 0,
                "total_time": 0.0
            }

        var stats = condition_stats[condition_name]
        stats["count"] += 1
        if debug_info.result:
            stats["true_count"] += 1
        stats["total_time"] += debug_info.evaluation_time

    report += "\nCONDITION STATISTICS:\n"
    for condition_name in condition_stats.keys():
        var stats = condition_stats[condition_name]
        var avg_time = stats["total_time"] / stats["count"]
        var true_rate = float(stats["true_count"]) / stats["count"] * 100.0

        report += "  %s:\n" % condition_name
        report += "    Evaluations: %d\n" % stats["count"]
        report += "    True Rate: %.1f%%\n" % true_rate
        report += "    Avg Time: %.3f ms\n" % avg_time

    return report
```

### 7.2 Condition Optimization

```gdscript
@tool
class_name ConditionOptimizer extends RefCounted

## Optimization suggestion
class OptimizationSuggestion:
    var condition: BaseCondition
    var suggestion_type: String
    var description: String
    var impact: String  # "low", "medium", "high"

## Analyze condition performance
func analyze_performance(conditions: Array[BaseCondition]) -> Array[OptimizationSuggestion]:
    var suggestions: Array[OptimizationSuggestion] = []

    for condition in conditions:
        suggestions.append_array(_analyze_condition(condition))

    # Analyze condition combinations
    suggestions.append_array(_analyze_condition_combination(conditions))

    return suggestions

## Analyze a single condition
func _analyze_condition(condition: BaseCondition) -> Array[OptimizationSuggestion]:
    var suggestions: Array[OptimizationSuggestion] = []

    # Check the number of sub-conditions on logical conditions
    if condition is AndCondition or condition is OrCondition:
        var sub_conditions = condition.sub_conditions
        if sub_conditions.size() > 10:
            suggestions.append(_create_suggestion(
                condition,
                "many_sub_conditions",
                "Large number of sub-conditions may impact performance",
                "medium"
            ))

    # Check variable conditions for caching opportunities
    if condition is VariableCompareCondition:
        var var_condition = condition as VariableCompareCondition
        if var_condition.value_source == 0:  # Literal value
            suggestions.append(_create_suggestion(
                condition,
                "cache_candidate",
                "Variable comparison with literal value can be cached",
                "low"
            ))

    return suggestions

## Analyze condition combinations
func _analyze_condition_combination(conditions: Array[BaseCondition]) -> Array[OptimizationSuggestion]:
    var suggestions: Array[OptimizationSuggestion] = []

    # Check for duplicate conditions
    var condition_descriptions = {}
    for condition in conditions:
        var desc = condition.get_description()
        if condition_descriptions.has(desc):
            condition_descriptions[desc] += 1
        else:
            condition_descriptions[desc] = 1

    for desc in condition_descriptions.keys():
        if condition_descriptions[desc] > 1:
            suggestions.append(_create_suggestion(
                null,
                "duplicate_conditions",
                "Duplicate condition found: %s" % desc,
                "medium"
            ))

    return suggestions

## Create an optimization suggestion
func _create_suggestion(
    condition: BaseCondition,
    suggestion_type: String,
    description: String,
    impact: String
) -> OptimizationSuggestion:
    var suggestion = OptimizationSuggestion.new()
    suggestion.condition = condition
    suggestion.suggestion_type = suggestion_type
    suggestion.description = description
    suggestion.impact = impact
    return suggestion

## Optimize the condition order
func optimize_condition_order(conditions: Array[BaseCondition]) -> Array[BaseCondition]:
    var optimized = conditions.duplicate()

    # Simple heuristic ordering:
    # 1. Variable conditions (usually fast)
    # 2. Node existence conditions
    # 3. Complex conditions (e.g. distance calculation)

    optimized.sort_custom(func(a, b):
        var score_a = _get_condition_score(a)
        var score_b = _get_condition_score(b)
        return score_a < score_b  # Lower scores come first
    )

    return optimized

## Get the condition score (for sorting)
func _get_condition_score(condition: BaseCondition) -> int:
    if condition is VariableCompareCondition:
        return 1  # Variable conditions are usually the fastest
    elif condition is CheckNodeExists:
        return 2  # Node existence checks are fast
    elif condition is NodeDistanceCondition:
        return 4  # Distance calculation is slow
    elif condition is AndCondition or condition is OrCondition:
        return 3  # Logical conditions are moderate
    else:
        return 3  # Default score

## Optimize the condition tree
func optimize_condition_tree(tree: ConditionTree) -> ConditionTree:
    if not tree.root:
        return tree

    var optimized_tree = ConditionTree.new()
    optimized_tree.root = _optimize_node(tree.root)

    return optimized_tree

## Optimize a node
func _optimize_node(node: ConditionTree.ConditionNode) -> ConditionTree.ConditionNode:
    var optimized_node = ConditionTree.ConditionNode.new()
    optimized_node.type = node.type
    optimized_node.condition = node.condition
    optimized_node.custom_evaluator = node.custom_evaluator

    # Optimize the child nodes
    for child in node.children:
        optimized_node.children.append(_optimize_node(child))

    # Apply type-specific optimizations
    match node.type:
        ConditionTree.NodeType.AND:
            optimized_node = _optimize_and_node(optimized_node)
        ConditionTree.NodeType.OR:
            optimized_node = _optimize_or_node(optimized_node)

    return optimized_node

## Optimize an AND node
func _optimize_and_node(node: ConditionTree.ConditionNode) -> ConditionTree.ConditionNode:
    # Sort the children by performance, fast-failing ones first
    node.children.sort_custom(func(a, b):
        var score_a = _get_condition_score(a.condition) if a.condition else 3
        var score_b = _get_condition_score(b.condition) if b.condition else 3
        return score_a < score_b
    )

    return node

## Optimize an OR node
func _optimize_or_node(node: ConditionTree.ConditionNode) -> ConditionTree.ConditionNode:
    # Sort the children by performance, fast-succeeding ones first
    node.children.sort_custom(func(a, b):
        var score_a = _get_condition_score(a.condition) if a.condition else 3
        var score_b = _get_condition_score(b.condition) if b.condition else 3
        return score_a < score_b
    )

    return node
```

---

## Summary

The condition system is the decision-making core of the visual programming system. This design provides:

1. **A complete condition classification system**: covering variables, nodes, input, physics, time, game state, logic, math, and custom conditions, among other aspects
2. **A powerful evaluation mechanism**: based on condition trees and combiners, supporting complex logical combinations
3. **A flexible extension framework**: supporting condition registration, templating, and auto-discovery
4. **Comprehensive debugging support**: providing detailed condition evaluation information and performance analysis
5. **Intelligent performance optimization**: automatically analyzing and optimizing condition order and combinations

This condition system design maintains simplicity and ease of use while delivering powerful functionality and good extensibility, providing a reliable decision-making foundation for the entire visual programming system.

---

## Architecture Updates (2026-03)

### New Condition Types
- Composite conditions: CheckAll(AND), CheckAny(OR), CheckNot(NOT), CheckComposite
- Array conditions: CheckArraySize, CheckArrayContains
- Dictionary conditions: CheckDictSize, CheckDictContainsKey
- Scope variable conditions: CheckScopeVariable
- Expression conditions: ExpressionCondition

### Directory Structure Changes
Now organized by function: animation/, arrays/, composite/, dictionaries/, distance/, input/, math/, node/, physics/, scope/, scene/, time/, variable/

### Batch Operation Optimizations
validate_batch() / check_batch() support multi-Trigger scenarios
