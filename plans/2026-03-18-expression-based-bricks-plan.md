# Expression-Based Bricks Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 创建 ExpressionCondition（通用布尔条件）、StringExpression（字符串表达式指令），并增强 MathExpression（游戏数学函数），三者共享 ExpressionHelper 公共工具类。

**Architecture:** 提取 `ExpressionHelper` 静态工具类 + `GameExprHelper` 内部类，封装变量替换、表达式求值和游戏常用数学/字符串函数。ExpressionCondition 继承 `BaseCondition`，StringExpression 继承 `BaseInstruction`，MathExpression 重构为使用共享代码。

**Tech Stack:** Godot 4.6 / GDScript 2.0 / Expression 类 / BaseCondition / BaseInstruction / ExecutionContext / BricksLogger / BricksLocalization

**Source Memo:** `plans/2026-03-18-expression-based-bricks.md`

---

## Task 1: ExpressionHelper 公共工具类

共享基础设施，所有表达式组件复用。

**Files:**
- Create: `addons/bricks/core/utils/expression_helper.gd`
- Test: `addons/bricks/tests/utils/test_expression_helper.gd`

### Step 0: 创建目录

```bash
mkdir -p addons/bricks/tests/utils
```

### Step 1: 创建 ExpressionHelper

```gdscript
# addons/bricks/core/utils/expression_helper.gd
class_name ExpressionHelper extends RefCounted

## 表达式公共工具类
##
## 提供 Bricks 表达式系统的共享功能：
## - 变量引用替换 ({local:xxx}, {scope:xxx}, {global:xxx})
## - 表达式安全求值
## - GameExprHelper 辅助函数集

## 匹配变量引用: {local:xxx}, {scope:xxx}, {global:xxx}
const VAR_PATTERN := r"\{(local|scope|global):([a-zA-Z_][a-zA-Z0-9_]*)\}"


# =============================================
# 表达式辅助类 - 提供 Expression 引擎可调用的自定义函数
# =============================================

## 游戏表达式辅助函数集
## 通过 base_instance 传递给 Expression.execute()，
## 使表达式可以使用 vec2/vec3/distance/direction 等游戏常用函数。
class GameExprHelper extends RefCounted:

	# --- 向量 ---

	func vec2(x, y) -> Variant:
		return Vector2(float(x), float(y))

	func vec3(x, y, z) -> Variant:
		return Vector3(float(x), float(y), float(z))

	func normalize(v: Variant) -> Variant:
		if v is Vector2:
			return v.normalized()
		if v is Vector3:
			return v.normalized()
		return 1.0 if float(v) != 0.0 else 0.0

	func distance(a: Variant, b: Variant) -> float:
		if a is Vector2 and b is Vector2:
			return a.distance_to(b)
		if a is Vector3 and b is Vector3:
			return a.distance_to(b)
		return absf(float(a) - float(b))

	func direction(a: Variant, b: Variant) -> Variant:
		if a is Vector2 and b is Vector2:
			var diff := (b - a) as Vector2
			return diff.normalized() if diff.length() > 0.0 else Vector2.ZERO
		if a is Vector3 and b is Vector3:
			var diff := (b - a) as Vector3
			return diff.normalized() if diff.length() > 0.0 else Vector3.ZERO
		var d := float(b) - float(a)
		if d == 0.0:
			return 0.0
		return 1.0 if d > 0.0 else -1.0

	func angle(a: Variant, b: Variant) -> float:
		if a is Vector2 and b is Vector2:
			return (b - a).angle()
		if a is Vector3 and b is Vector3:
			return atan2(b.x - a.x, b.z - a.z)
		return 0.0

	# --- 数值工具 ---

	func remap(value, istart, istop, ostart, ostop) -> float:
		return ostart + (float(value) - float(istart)) / (float(istop) - float(istart)) * (float(ostop) - float(ostart))

	func inverse_lerp(from, to, weight) -> float:
		var f := float(from)
		var t := float(to)
		if f == t:
			return 0.0
		return clampf((float(weight) - f) / (t - f), 0.0, 1.0)

	func snap(value, step) -> float:
		var s := float(step)
		if s == 0.0:
			return float(value)
		return floorf(float(value) / s + 0.5) * s

	## 使用 _val 后缀避免与 Expression 内置 move_toward 冲突
	## 同时提供自动类型转换（参数强制转 float）
	func move_toward_val(from, to, delta) -> float:
		return move_toward(float(from), float(to), float(delta))

	func is_zero(v: Variant) -> bool:
		if v is Vector2:
			return v.length() < 0.0001
		if v is Vector3:
			return v.length() < 0.0001
		return absf(float(v)) < 0.0001

	# --- 字符串工具 ---

	func format_num(value, decimals: int = 0) -> String:
		return "%.*f" % [decimals, float(value)]

	func pad_left(s: String, length: int, char: String = " ") -> String:
		while s.length() < length:
			s = char + s
		return s

	func pad_right(s: String, length: int, char: String = " ") -> String:
		while s.length() < length:
			s = s + char
		return s


# =============================================
# 静态工具方法
# =============================================

## 替换表达式中的变量引用
##
## 将 {local:xxx}, {scope:xxx}, {global:xxx} 替换为实际值。
## 成功返回处理后的字符串，失败返回 null。
## for_string=true 时使用 escape_value_for_string（保留字符串类型），
## for_string=false 时使用 escape_value（数值优先，向后兼容）。
static func replace_variables(
	expr: String,
	context: ExecutionContext,
	scope_source: VariableScopeUtils.ScopeSource = VariableScopeUtils.ScopeSource.NEAREST,
	custom_scope_id: String = "",
	target_node_path: NodePath = NodePath(""),
	log_warnings: bool = true,
	for_string: bool = false
) -> Variant:
	var regex := RegEx.new()
	if regex.compile(VAR_PATTERN) != OK:
		return null

	var result := expr
	var matches := regex.search_all(expr)

	for match_obj in matches:
		var full_match := match_obj.get_string(0)
		var scope_type := match_obj.get_string(1)
		var var_name := match_obj.get_string(2)

		var value := _get_variable_value(scope_type, var_name, context, scope_source, custom_scope_id, target_node_path)

		if value == null:
			if log_warnings:
				BricksLogger.log_warning("ExpressionHelper", BricksLogger.LogLevel.WARNING,
					"Variable {var} not found, using default value 0".format({"var": var_name}))
			value = 0

		var value_str := escape_value_for_string(value) if for_string else escape_value(value)
		result = result.replace(full_match, value_str)

	return result


## 安全求值表达式
##
## 成功返回表达式结果，失败返回 null 并通过 error_text 参数返回错误信息。
static func evaluate(expr: String, helper: RefCounted, error_text: String = "") -> Variant:
	var expression_obj := Expression.new()

	var parse_error := expression_obj.parse(expr)
	if parse_error != OK:
		error_text = expression_obj.get_error_text()
		return null

	var result = expression_obj.execute([], helper, false)

	if expression_obj.has_execute_failed():
		error_text = expression_obj.get_error_text()
		return null

	return result


## 将值转换为表达式安全字符串（数值上下文）
## 用于 MathExpression / ExpressionCondition：字符串和 bool 转为数值，保持向后兼容。
static func escape_value(value: Variant) -> String:
	if value is int or value is float:
		return str(value)

	if value is Vector2:
		return "vec2(%s, %s)" % [value.x, value.y]
	if value is Vector3:
		return "vec3(%s, %s, %s)" % [value.x, value.y, value.z]

	# 其他类型尝试转为浮点数（bool→1.0/0.0，String→尝试解析或0.0）
	var as_float := TypeConverter.safe_convert_to_float(value)
	return str(as_float)


## 将值转换为表达式安全字符串（字符串上下文）
## 用于 StringExpression：保留字符串类型，正确转义引号。
static func escape_value_for_string(value: Variant) -> String:
	if value is String:
		var escaped := value.replace("\\", "\\\\").replace('"', '\\"')
		return '"%s"' % escaped

	if value is bool:
		return "true" if value else "false"

	if value is int or value is float:
		return str(value)

	if value is Vector2:
		return "vec2(%s, %s)" % [value.x, value.y]
	if value is Vector3:
		return "vec3(%s, %s, %s)" % [value.x, value.y, value.z]

	return str(value)


## 验证表达式语法（检查变量引用格式）
static func validate_syntax(expr: String) -> Array[String]:
	var errors: Array[String] = []

	var regex := RegEx.new()
	if regex.compile(VAR_PATTERN) != OK:
		errors.append("Failed to compile variable pattern regex")
		return errors

	var valid_pattern := RegEx.new()
	valid_pattern.compile(r"^[a-zA-Z_][a-zA-Z0-9_]*$")

	for match_obj in regex.search_all(expr):
		var scope_type := match_obj.get_string(1)
		var var_name := match_obj.get_string(2)

		if scope_type not in ["local", "scope", "global"]:
			errors.append(BricksLocalization.translate_format(
				"BRICKS_ERROR_INVALID_VAR_SYNTAX",
				{"syntax": "{%s:%s}" % [scope_type, var_name]}
			))

		if not valid_pattern.search(var_name):
			errors.append(BricksLocalization.translate_format(
				"BRICKS_ERROR_INVALID_VAR_SYNTAX",
				{"syntax": "{%s:%s}" % [scope_type, var_name]}
			))

	return errors


## 从表达式中提取所有变量名（去重）
static func extract_variable_names(expr: String) -> Array[String]:
	var regex := RegEx.new()
	if regex.compile(VAR_PATTERN) != OK:
		return []

	var names: Array[String] = []
	for match_obj in regex.search_all(expr):
		var name := match_obj.get_string(2)
		if name not in names:
			names.append(name)
	return names


# =============================================
# 内部方法
# =============================================

## 获取变量值
static func _get_variable_value(
	scope_type: String,
	var_name: String,
	context: ExecutionContext,
	scope_source: VariableScopeUtils.ScopeSource,
	custom_scope_id: String,
	target_node_path: NodePath
) -> Variant:
	match scope_type:
		"local":
			return VariableOperations.get_variable(context, var_name, BaseVariable.VariableScope.LOCAL, null)
		"global":
			return VariableOperations.get_variable(context, var_name, BaseVariable.VariableScope.GLOBAL, null)
		"scope":
			if scope_source == VariableScopeUtils.ScopeSource.NEAREST:
				return VariableOperations.get_variable(context, var_name, BaseVariable.VariableScope.SCOPE, null)
			else:
				var scope_container = VariableScopeUtils.get_scope_container_by_source(
					context, scope_source, custom_scope_id, target_node_path
				)
				if scope_container != null:
					return scope_container.get_variable(var_name)
				return null
		_:
			return null
```

### Step 2: 创建 ExpressionHelper 测试

```gdscript
# addons/bricks/tests/utils/test_expression_helper.gd
extends Node

## ExpressionHelper 工具类测试

var test_results: Array[String] = []
var test_passed: int = 0
var test_failed: int = 0

func _ready():
	print("=== ExpressionHelper 测试开始 ===")
	_run_all_tests()
	_show_test_results()
	print("=== ExpressionHelper 测试完成 ===")

func _run_all_tests():
	_test_escape_value()
	_test_escape_value_for_string()
	_test_validate_syntax()
	_test_extract_variable_names()
	_test_evaluate()
	_test_game_expr_helper_math()
	_test_game_expr_helper_vector()
	_test_game_expr_helper_string()

func _test_escape_value():
	print("\n--- escape_value 测试 ---")
	_record("数值 int", ExpressionHelper.escape_value(42) == "42")
	_record("数值 float", ExpressionHelper.escape_value(3.14) == "3.14")
	_record("bool true", ExpressionHelper.escape_value(true) == "1")  # 数值上下文 bool→1
	_record("bool false", ExpressionHelper.escape_value(false) == "0")  # 数值上下文 bool→0
	_record("Vector2", ExpressionHelper.escape_value(Vector2(1, 2)) == "vec2(1, 2)")
	_record("Vector3", ExpressionHelper.escape_value(Vector3(1, 2, 3)) == "vec3(1, 2, 3)")
	_record("字符串→float", ExpressionHelper.escape_value("hello") == "0")  # 数值上下文 String→0

func _test_escape_value_for_string():
	print("\n--- escape_value_for_string 测试 ---")
	_record("字符串", ExpressionHelper.escape_value_for_string("hello") == '"hello"')
	_record("字符串含引号", ExpressionHelper.escape_value_for_string('say "hi"') == '"say \\"hi\\""')
	_record("bool true", ExpressionHelper.escape_value_for_string(true) == "true")
	_record("数值", ExpressionHelper.escape_value_for_string(42) == "42")
	_record("Vector2", ExpressionHelper.escape_value_for_string(Vector2(1, 2)) == "vec2(1, 2)")

func _test_validate_syntax():
	print("\n--- validate_syntax 测试 ---")
	var errors: Array[String]

	errors = ExpressionHelper.validate_syntax("{local:hp}")
	_record("有效 local 引用", errors.is_empty())

	errors = ExpressionHelper.validate_syntax("{scope:x} + {global:y}")
	_record("有效多引用", errors.is_empty())

	errors = ExpressionHelper.validate_syntax("{invalid:hp}")
	_record("无效作用域类型", errors.size() > 0)

	errors = ExpressionHelper.validate_syntax("{local:123bad}")
	_record("无效变量名", errors.size() > 0)

	errors = ExpressionHelper.validate_syntax("1 + 2")
	_record("无变量引用", errors.is_empty())

func _test_extract_variable_names():
	print("\n--- extract_variable_names 测试 ---")
	var names: Array[String]

	names = ExpressionHelper.extract_variable_names("{local:hp} + {local:max_hp}")
	_record("提取两个变量", names.size() == 2 and "hp" in names and "max_hp" in names)

	names = ExpressionHelper.extract_variable_names("{local:x}")
	_record("去重", names.size() == 1)

	names = ExpressionHelper.extract_variable_names("{local:x} + {scope:x}")
	_record("不同作用域同名", names.size() == 1)

func _test_evaluate():
	print("\n--- evaluate 测试 ---")
	var helper := ExpressionHelper.GameExprHelper.new()
	var error := ""
	var result: Variant

	result = ExpressionHelper.evaluate("1 + 2", helper, error)
	_record("简单加法", result == 3)

	result = ExpressionHelper.evaluate("abs(-5)", helper, error)
	_record("内置函数 abs", result == 5.0)

	result = ExpressionHelper.evaluate("1 + + 2", helper, error)
	_record("无效语法返回 null", result == null and not error.is_empty())

func _test_game_expr_helper_math():
	print("\n--- GameExprHelper 数学函数测试 ---")
	var helper := ExpressionHelper.GameExprHelper.new()
	var error := ""

	# remap
	var result = ExpressionHelper.evaluate("remap(5, 0, 10, 0, 100)", helper, error)
	_record("remap", result == 50.0)

	# inverse_lerp
	result = ExpressionHelper.evaluate("inverse_lerp(0, 10, 5)", helper, error)
	_record("inverse_lerp", result == 0.5)

	# snap
	result = ExpressionHelper.evaluate("snap(7, 5)", helper, error)
	_record("snap", result == 5.0)

	# is_zero
	result = ExpressionHelper.evaluate("is_zero(0)", helper, error)
	_record("is_zero(0)", result == true)
	result = ExpressionHelper.evaluate("is_zero(1)", helper, error)
	_record("is_zero(1)", result == false)

	# move_toward_val
	result = ExpressionHelper.evaluate("move_toward_val(0, 100, 30)", helper, error)
	_record("move_toward_val", result == 30.0)

func _test_game_expr_helper_vector():
	print("\n--- GameExprHelper 向量函数测试 ---")
	var helper := ExpressionHelper.GameExprHelper.new()
	var error := ""
	var result: Variant

	# distance (numeric)
	result = ExpressionHelper.evaluate("distance(0, 10)", helper, error)
	_record("distance(数值)", result == 10.0)

	# distance (Vector2) - 通过 vec2 构造
	result = ExpressionHelper.evaluate("distance(vec2(0, 0), vec2(3, 4))", helper, error)
	_record("distance(Vector2)", absf(float(result) - 5.0) < 0.001)

	# direction (Vector2)
	result = ExpressionHelper.evaluate("direction(vec2(0, 0), vec2(10, 0))", helper, error)
	_record("direction(Vector2)", result is Vector2 and result.x == 1.0 and result.y == 0.0)

func _test_game_expr_helper_string():
	print("\n--- GameExprHelper 字符串函数测试 ---")
	var helper := ExpressionHelper.GameExprHelper.new()
	var error := ""
	var result: Variant

	result = ExpressionHelper.evaluate('format_num(3.14159, 2)', helper, error)
	_record("format_num", result == "3.14")

	result = ExpressionHelper.evaluate('pad_left("42", 6, "0")', helper, error)
	_record("pad_left", result == "000042")

	result = ExpressionHelper.evaluate('pad_right("hi", 5, "!")', helper, error)
	_record("pad_right", result == "hi!!!")

func _record(name: String, passed: bool, details: String = ""):
	var status = "PASS" if passed else "FAIL"
	var s = "[%s] %s" % [status, name]
	if not details.is_empty():
		s += " - " + details
	test_results.append(s)
	if passed:
		test_passed += 1
	else:
		test_failed += 1
	print(s)

func _show_test_results():
	print("\n=== 测试结果汇总 ===")
	print("通过: %d" % test_passed)
	print("失败: %d" % test_failed)
	if test_failed > 0:
		print("\n失败:")
		for r in test_results:
			if r.begins_with("[FAIL]"):
				print("  " + r)
```

### Step 3: 验证测试文件语法

Run: `/gdscript-validate` on both files

### Step 4: Commit

```bash
git add addons/bricks/core/utils/expression_helper.gd addons/bricks/tests/utils/test_expression_helper.gd
git commit -m "feat(bricks): add ExpressionHelper shared utility with GameExprHelper"
```

---

## Task 2: 本地化键

为三个组件一次性添加所有翻译键。

**Files:**
- Modify: `addons/bricks/localization/translations.csv` (append at end, before the generator section around line 4458)

### Step 1: 添加翻译键

在 `BRICKS_LOG_MATH_EXPRESSION_RESULT` 之后、`# Instruction Generator 对话框` 之前追加：

```csv
# ExpressionHelper
BRICKS_ERROR_EXPRESSION_NOT_BOOLEAN,表达式结果不是布尔值: {result},Expression result is not boolean: {result}
BRICKS_ERROR_EXPRESSION_NOT_STRING,表达式结果不是字符串: {result},Expression result is not string: {result}

# ExpressionCondition
BRICKS_CONDITION_EXPRESSION_NAME,表达式条件,Expression Condition
BRICKS_CONDITION_EXPRESSION_DESC,使用表达式评估布尔条件，支持变量引用和逻辑运算,Evaluate a boolean condition using an expression, supports variable references and logical operations
BRICKS_CONDITION_EXPRESSION_FORMAT,表达式: {expr},Expression: {expr}
BRICKS_LOG_EXPRESSION_CONDITION_RESULT,表达式条件 "{expr}" = {result},Expression condition "{expr}" = {result}

# StringExpression
BRICKS_INSTRUCTION_STRING_EXPRESSION_NAME,字符串表达式,String Expression
BRICKS_INSTRUCTION_STRING_EXPRESSION_DESC,使用表达式拼接和格式化字符串，支持变量引用和字符串函数,"Concatenate and format strings using an expression, supports variable references and string functions"
BRICKS_LOG_STRING_EXPRESSION_RESULT,字符串表达式 "{expr}" = "{result}",String expression "{expr}" = "{result}"
```

### Step 2: Commit

```bash
git add addons/bricks/localization/translations.csv
git commit -m "feat(bricks): add localization keys for ExpressionCondition and StringExpression"
```

---

## Task 3: ExpressionCondition

通用布尔条件组件，使用 Expression 评估任意布尔表达式。

**Files:**
- Create: `addons/bricks/conditions/math/expression_condition.gd`
- Test: `addons/bricks/tests/conditions/test_expression_condition.gd`

### Step 0: 创建目录

```bash
mkdir -p addons/bricks/conditions/math
```

### Step 1: 创建 ExpressionCondition

```gdscript
# addons/bricks/conditions/math/expression_condition.gd
@tool
@icon("res://addons/bricks/icons/builtin/Code.png")
extends BaseCondition
class_name ExpressionCondition

## 表达式条件 - 使用 Expression 评估布尔条件
##
## 支持功能:
## - 变量引用: {local:xxx}, {scope:xxx}, {global:xxx}
## - 比较运算: ==, !=, >, <, >=, <=
## - 逻辑运算: and, or, not
## - 三元运算: a if b else c
## - 辅助函数: distance(), direction(), is_zero(), remap(), inverse_lerp(), snap()

# =============================================
# 作用域来源
# =============================================

## 作用域来源（当表达式中使用 {scope:xxx} 时生效）
enum ScopeSource {
	NEAREST,        ## 最近的作用域容器（默认）
	CUSTOM_ID,      ## 指定 scope_id
	TRIGGER_SCOPE,  ## Trigger 节点上的作用域
	TARGET_NODE     ## Target 节点上的作用域
}

# =============================================
# 参数定义
# =============================================

## 布尔表达式字符串
var expression: String = "":
	set(value):
		expression = value
		_update_resource_name()

## SCOPE 来源（当表达式中使用 {scope:xxx} 时生效）
var scope_source: ScopeSource = ScopeSource.NEAREST:
	set(value):
		scope_source = value
		notify_property_list_changed()
		_update_resource_name()

## 自定义作用域 ID（CUSTOM_ID 模式使用）
var custom_scope_id: String = "":
	set(value):
		custom_scope_id = value
		_update_resource_name()

## 目标节点路径（TARGET_NODE 模式使用）
var target_node_path: NodePath = NodePath(""):
	set(value):
		target_node_path = value
		_update_resource_name()

## 缓存的辅助实例
var _expr_helper: ExpressionHelper.GameExprHelper

# =============================================
# 元数据方法
# =============================================

static func _get_condition_metadata() -> ConditionMetadata:
	var metadata := ConditionMetadata.new()
	metadata.name_key = "BRICKS_CONDITION_EXPRESSION_NAME"
	metadata.category_key = "BRICKS_CATEGORY_MATH"
	metadata.description_key = "BRICKS_CONDITION_EXPRESSION_DESC"
	metadata.keywords = ["expression", "表达式", "condition", "条件", "bool", "boolean", "compare", "比较", "logic", "逻辑", "math", "数学"]
	metadata.builtin_icon = "Code"
	return metadata

# =============================================
# 属性列表
# =============================================

func _get_property_list() -> Array[Dictionary]:
	var properties := []

	properties.append({
		name = "Expression",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "expression",
		type = TYPE_STRING,
		hint = PROPERTY_HINT_MULTILINE_TEXT,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	properties.append({
		name = "Scope Source Config",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "scope_source",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Nearest,Custom ID,Trigger Scope,Target Node",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	if scope_source == ScopeSource.CUSTOM_ID:
		properties.append({
			name = "custom_scope_id",
			type = TYPE_STRING,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})
	elif scope_source == ScopeSource.TARGET_NODE:
		properties.append({
			name = "target_node_path",
			type = TYPE_NODE_PATH,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

	return properties

func _validate_property(property: Dictionary) -> void:
	_hide_scope_source_properties(property, scope_source)

func _hide_scope_source_properties(property: Dictionary, source: ScopeSource) -> void:
	if source != ScopeSource.CUSTOM_ID:
		if property.name == "custom_scope_id":
			property.usage = PROPERTY_USAGE_NO_EDITOR
	if source != ScopeSource.TARGET_NODE:
		if property.name == "target_node_path":
			property.usage = PROPERTY_USAGE_NO_EDITOR

# =============================================
# 资源名称和描述
# =============================================

func _update_resource_name():
	var display_expr := expression
	if display_expr.is_empty():
		resource_name = BricksLocalization.translate("BRICKS_CONDITION_EXPRESSION_FORMAT").format({"expr": "<empty>"})
	else:
		if display_expr.length() > 40:
			display_expr = display_expr.substr(0, 37) + "..."
		resource_name = BricksLocalization.translate("BRICKS_CONDITION_EXPRESSION_FORMAT").format({"expr": display_expr})
	_description = resource_name

func get_description() -> String:
	return expression

# =============================================
# 条件评估
# =============================================

func _evaluate_condition(context: ExecutionContext) -> bool:
	if expression.is_empty():
		_log_error("Expression is empty")
		_create_bricks_error(BricksLocalization.translate("BRICKS_ERROR_EXPRESSION_EMPTY"), BricksError.ErrorType.VALIDATION_ERROR)
		return false

	if _expr_helper == null:
		_expr_helper = ExpressionHelper.GameExprHelper.new()

	var utils_scope := scope_source as VariableScopeUtils.ScopeSource

	var processed_expr := ExpressionHelper.replace_variables(
		expression, context, utils_scope, custom_scope_id, target_node_path, true
	)
	if processed_expr == null:
		_log_error("Failed to replace variables in expression")
		_create_bricks_error(BricksLocalization.translate("BRICKS_ERROR_EXPRESSION_REGEX"), BricksError.ErrorType.RUNTIME_ERROR)
		return false

	var error_text := ""
	var result = ExpressionHelper.evaluate(String(processed_expr), _expr_helper, error_text)

	if result == null:
		_log_error("Expression evaluation failed: %s" % error_text)
		_create_bricks_error(
			BricksLocalization.translate_format("BRICKS_ERROR_EXPRESSION_PARSE", {"error": error_text}),
			BricksError.ErrorType.RUNTIME_ERROR
		)
		return false

	if not (result is bool):
		_log_error("Expression result is not boolean: %s (%s)" % [str(result), typeof(result)])
		_create_bricks_error(
			BricksLocalization.translate_format("BRICKS_ERROR_EXPRESSION_NOT_BOOLEAN", {"result": str(result)}),
			BricksError.ErrorType.RUNTIME_ERROR
		)
		return false

	_log_debug("Expression condition '%s' = %s" % [expression, result])
	return result

# =============================================
# 依赖计算
# =============================================

func _compute_dependencies() -> Array[String]:
	return ExpressionHelper.extract_variable_names(expression)

# =============================================
# 线程安全
# =============================================

func _compute_thread_safety() -> bool:
	if _thread_safety_computed:
		return _thread_safety_cached

	var is_safe := true
	match scope_source:
		ScopeSource.CUSTOM_ID, ScopeSource.TARGET_NODE, ScopeSource.TRIGGER_SCOPE:
			is_safe = false

	_thread_safety_cached = is_safe
	_thread_safety_computed = true
	return _thread_safety_cached

# =============================================
# 验证
# =============================================

func validate() -> Array[String]:
	var errors := super.validate()

	if expression.is_empty():
		errors.append(BricksLocalization.translate("BRICKS_ERROR_EXPRESSION_EMPTY"))

	errors.append_array(ExpressionHelper.validate_syntax(expression))

	if scope_source == ScopeSource.CUSTOM_ID and custom_scope_id.is_empty():
		errors.append(BricksLocalization.translate("BRICKS_ERROR_SCOPE_ID_EMPTY"))
	if scope_source == ScopeSource.TARGET_NODE and target_node_path.is_empty():
		errors.append(BricksLocalization.translate("BRICKS_ERROR_TARGET_NODE_PATH_EMPTY"))

	return errors

# =============================================
# 信息方法
# =============================================

func get_condition_type() -> String:
	return "expression_condition"

func get_condition_category() -> String:
	return "math"

func get_parameters() -> Dictionary:
	var params := {
		"expression": expression,
		"scope_source": scope_source,
	}
	if scope_source == ScopeSource.CUSTOM_ID:
		params["custom_scope_id"] = custom_scope_id
	if scope_source == ScopeSource.TARGET_NODE:
		params["target_node_path"] = target_node_path
	return params

func get_detailed_info() -> Dictionary:
	var info := super.get_detailed_info()
	info["expression"] = expression
	info["scope_source"] = ScopeSource.keys()[scope_source]
	return info

func reset():
	super.reset()
	_log_debug("ExpressionCondition reset")
```

### Step 2: 创建 ExpressionCondition 测试

```gdscript
# addons/bricks/tests/conditions/test_expression_condition.gd
extends Node

## ExpressionCondition 条件测试

var test_results: Array[String] = []
var test_passed: int = 0
var test_failed: int = 0

func _ready():
	print("=== ExpressionCondition 测试开始 ===")
	_run_all_tests()
	_show_test_results()
	print("=== ExpressionCondition 测试完成 ===")

func _run_all_tests():
	_test_basic_comparison()
	_test_logical_operators()
	_test_variable_references()
	_test_helper_functions()
	_test_validation()
	_test_error_handling()

func _test_basic_comparison():
	print("\n--- 基础比较测试 ---")
	await _test_condition("10 > 5", {}, true, "大于")
	await _test_condition("3 >= 3", {}, true, "大于等于")
	await _test_condition("1 < 2", {}, true, "小于")
	await _test_condition("5 <= 4", {}, false, "小于等于（假）")
	await _test_condition("5 == 5", {}, true, "等于")
	await _test_condition("5 != 5", {}, false, "不等于（假）")

func _test_logical_operators():
	print("\n--- 逻辑运算测试 ---")
	await _test_condition("true and true", {}, true, "AND 真")
	await _test_condition("true and false", {}, false, "AND 假")
	await _test_condition("false or true", {}, true, "OR 真")
	await _test_condition("false or false", {}, false, "OR 假")
	await _test_condition("not false", {}, true, "NOT")
	await _test_condition("1 > 0 and 2 > 1", {}, true, "复合 AND")
	await _test_condition("1 > 0 or 0 > 1", {}, true, "复合 OR")

func _test_variable_references():
	print("\n--- 变量引用测试 ---")
	await _test_condition("{local:hp} > 0", {"hp": 50.0}, true, "LOCAL 变量（真）")
	await _test_condition("{local:hp} > 0", {"hp": 0.0}, false, "LOCAL 变量（假）")
	await _test_condition("{local:a} > {local:b}", {"a": 10, "b": 5}, true, "双变量比较")
	await _test_condition("{local:x} >= 5 and {local:x} <= 10", {"x": 7}, true, "范围检查")

func _test_helper_functions():
	print("\n--- 辅助函数测试 ---")
	await _test_condition("is_zero(0)", {}, true, "is_zero(0)")
	await _test_condition("is_zero(1)", {}, false, "is_zero(1)")
	await _test_condition("distance(vec2(0,0), vec2(3,4)) < 6", {}, true, "distance")

func _test_validation():
	print("\n--- 验证测试 ---")

	var cond := ExpressionCondition.new()
	cond.log_level = BricksLogger.LogLevel.DEBUG
	cond.expression = ""
	var errors := cond.validate()
	_record("空表达式验证", errors.size() > 0)

	cond.expression = "{local:hp} > 0"
	errors = cond.validate()
	_record("有效表达式验证", errors.is_empty())

	cond.expression = "{invalid:hp}"
	errors = cond.validate()
	_record("无效变量语法验证", errors.size() > 0)

func _test_error_handling():
	print("\n--- 错误处理测试 ---")

	# 结果不是 bool
	var cond := ExpressionCondition.new()
	cond.log_level = BricksLogger.LogLevel.DEBUG
	cond.expression = "1 + 2"  # 结果是 int 3，不是 bool

	var context := ExecutionContext.new()
	var result := cond.check(context)
	_record("非布尔结果返回 false", result == false)

	# 无效语法
	cond.expression = "1 + +"
	cond.clear_error()
	result = cond.check(context)
	_record("无效语法返回 false", result == false)

func _test_condition(expr: String, variables: Dictionary, expected: bool, name: String):
	var cond := ExpressionCondition.new()
	cond.log_level = BricksLogger.LogLevel.DEBUG
	cond.expression = expr

	var context := ExecutionContext.new()
	for key in variables:
		context.set_variable(key, variables[key])

	var result := cond.check(context)
	_record(name, result == expected)

func _record(name: String, passed: bool, details: String = ""):
	var status = "PASS" if passed else "FAIL"
	var s = "[%s] %s" % [status, name]
	if not details.is_empty():
		s += " - " + details
	test_results.append(s)
	if passed:
		test_passed += 1
	else:
		test_failed += 1
	print(s)

func _show_test_results():
	print("\n=== 测试结果汇总 ===")
	print("通过: %d" % test_passed)
	print("失败: %d" % test_failed)
	if test_failed > 0:
		print("\n失败:")
		for r in test_results:
			if r.begins_with("[FAIL]"):
				print("  " + r)
```

### Step 3: 验证语法

Run: `/gdscript-validate` on both files

### Step 4: Commit

```bash
git add addons/bricks/conditions/math/expression_condition.gd addons/bricks/tests/conditions/test_expression_condition.gd
git commit -m "feat(bricks): add ExpressionCondition for boolean expression evaluation"
```

---

## Task 4: StringExpression

字符串表达式指令，用 Expression 拼接和格式化字符串。

**Files:**
- Create: `addons/bricks/instructions/math/string_expression.gd`
- Test: `addons/bricks/tests/instructions/test_string_expression.gd`

### Step 1: 创建 StringExpression

```gdscript
# addons/bricks/instructions/math/string_expression.gd
@tool
@icon("res://addons/bricks/icons/builtin/Code.png")
extends BaseInstruction
class_name StringExpression

## 字符串表达式指令 - 使用表达式拼接和格式化字符串
##
## 支持功能:
## - 变量引用: {local:xxx}, {scope:xxx}, {global:xxx}
## - 字符串拼接: "Hello" + " " + "World"
## - 条件文本: {local:hp} > 0 ? "Alive" : "Dead"
## - 类型转换: str(), int(), float()
## - 字符串工具: format_num(), pad_left(), pad_right()

# =============================================
# 作用域来源
# =============================================

enum ScopeSource {
	NEAREST,
	CUSTOM_ID,
	TRIGGER_SCOPE,
	TARGET_NODE
}

# =============================================
# 参数定义
# =============================================

## 表达式字符串
var expression: String = "":
	set(value):
		expression = value
		_update_resource_name()

## SCOPE 来源（当表达式中使用 {scope:xxx} 时生效）
var scope_source: ScopeSource = ScopeSource.NEAREST:
	set(value):
		scope_source = value
		notify_property_list_changed()
		_update_resource_name()

## 自定义作用域 ID
var custom_scope_id: String = "":
	set(value):
		custom_scope_id = value
		_update_resource_name()

## 目标节点路径
var target_node_path: NodePath = NodePath(""):
	set(value):
		target_node_path = value
		_update_resource_name()

## 保存到变量名
var save_to_variable: String = "str_result":
	set(value):
		save_to_variable = value
		_update_resource_name()

## 保存到作用域
var save_to_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		save_to_scope = value
		notify_property_list_changed()
		_update_resource_name()

## 保存作用域来源
var save_scope_source: ScopeSource = ScopeSource.NEAREST:
	set(value):
		save_scope_source = value
		notify_property_list_changed()
		_update_resource_name()

## 保存自定义作用域 ID
var save_custom_scope_id: String = "":
	set(value):
		save_custom_scope_id = value
		_update_resource_name()

## 保存目标节点路径
var save_target_node_path: NodePath = NodePath(""):
	set(value):
		save_target_node_path = value
		_update_resource_name()

## 缓存的辅助实例
var _expr_helper: ExpressionHelper.GameExprHelper

# =============================================
# 元数据方法
# =============================================

static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata := InstructionMetadata.new()
	metadata.name_key = "BRICKS_INSTRUCTION_STRING_EXPRESSION_NAME"
	metadata.category_key = "BRICKS_CATEGORY_MATH"
	metadata.description_key = "BRICKS_INSTRUCTION_STRING_EXPRESSION_DESC"
	metadata.keywords = ["string", "字符串", "expression", "表达式", "format", "格式化", "concat", "拼接", "text", "文本"]
	metadata.builtin_icon = "Code"
	metadata.execution_hint = InstructionMetadata.ExecutionHint.LIKELY_SYNC
	return metadata

func _setup_metadata():
	pass

# =============================================
# 属性列表
# =============================================

func _get_property_list() -> Array[Dictionary]:
	var properties := []

	# Expression 分组
	properties.append({
		name = "Expression",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "expression",
		type = TYPE_STRING,
		hint = PROPERTY_HINT_MULTILINE_TEXT,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# Scope 来源配置
	properties.append({
		name = "Scope Source Config",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "scope_source",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Nearest,Custom ID,Trigger Scope,Target Node",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	if scope_source == ScopeSource.CUSTOM_ID:
		properties.append({
			name = "custom_scope_id",
			type = TYPE_STRING,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})
	elif scope_source == ScopeSource.TARGET_NODE:
		properties.append({
			name = "target_node_path",
			type = TYPE_NODE_PATH,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

	# Output 分组
	properties.append({
		name = "Output",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "save_to_variable",
		type = TYPE_STRING,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	properties.append({
		name = "save_to_scope",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Local,Scope,Global",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	if save_to_scope == BaseVariable.VariableScope.SCOPE:
		properties.append({
			name = "save_scope_source",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "Nearest,Custom ID,Trigger Scope,Target Node",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		if save_scope_source == ScopeSource.CUSTOM_ID:
			properties.append({
				name = "save_custom_scope_id",
				type = TYPE_STRING,
				hint = PROPERTY_HINT_NONE,
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})
		elif save_scope_source == ScopeSource.TARGET_NODE:
			properties.append({
				name = "save_target_node_path",
				type = TYPE_NODE_PATH,
				hint = PROPERTY_HINT_NONE,
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})

	return properties

func _validate_property(property: Dictionary) -> void:
	_hide_scope_source_properties(property, scope_source, "custom_scope_id", "target_node_path")

	if save_to_scope != BaseVariable.VariableScope.SCOPE:
		if property.name in ["save_scope_source", "save_custom_scope_id", "save_target_node_path"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR
	else:
		_hide_scope_source_properties(property, save_scope_source, "save_custom_scope_id", "save_target_node_path")

func _hide_scope_source_properties(property: Dictionary, source: ScopeSource, custom_id_prop: String, target_node_prop: String) -> void:
	if source != ScopeSource.CUSTOM_ID:
		if property.name == custom_id_prop:
			property.usage = PROPERTY_USAGE_NO_EDITOR
	if source != ScopeSource.TARGET_NODE:
		if property.name == target_node_prop:
			property.usage = PROPERTY_USAGE_NO_EDITOR

# =============================================
# 资源名称和描述
# =============================================

func _update_resource_name():
	var parts := []

	if expression.is_empty():
		parts.append(BricksLocalization.translate("BRICKS_VALUE_EXPRESSION_EMPTY"))
	else:
		var display_expr := expression
		if display_expr.length() > 30:
			display_expr = display_expr.substr(0, 27) + "..."
		parts.append("'%s'" % display_expr)

	var scope_str := _get_save_scope_string()
	parts.append("→ %s [%s]" % [save_to_variable, scope_str])

	resource_name = " ".join(parts)

func get_description() -> String:
	return "%s → %s" % [expression, save_to_variable]

func _get_save_scope_string() -> String:
	match save_to_scope:
		BaseVariable.VariableScope.LOCAL:
			return BricksLocalization.translate("BRICKS_VARIABLE_SCOPE_LOCAL_STR")
		BaseVariable.VariableScope.GLOBAL:
			return BricksLocalization.translate("BRICKS_VARIABLE_SCOPE_GLOBAL_STR")
		BaseVariable.VariableScope.SCOPE:
			return VariableScopeUtils.get_scope_source_string(
				save_scope_source as VariableScopeUtils.ScopeSource,
				save_custom_scope_id,
				save_target_node_path
			)
		_:
			return BricksLocalization.translate("BRICKS_VARIABLE_SCOPE_UNKNOWN")

# =============================================
# 执行逻辑
# =============================================

func execute(context: ExecutionContext):
	_start_execution(context)

	# 1. 验证参数
	if expression.is_empty():
		_log_error_localized("BRICKS_ERROR_EXPRESSION_EMPTY", {})
		set_error_localized("BRICKS_ERROR_EXPRESSION_EMPTY", BricksError.ErrorType.VALIDATION_ERROR, {})
		finished.emit()
		return

	if save_to_variable.is_empty():
		_log_error_localized("BRICKS_ERROR_VAR_NAME_EMPTY", {})
		set_error_localized("BRICKS_ERROR_VAR_NAME_EMPTY", BricksError.ErrorType.VALIDATION_ERROR, {})
		finished.emit()
		return

	# 2. 替换变量引用
	if _expr_helper == null:
		_expr_helper = ExpressionHelper.GameExprHelper.new()

	var utils_scope := scope_source as VariableScopeUtils.ScopeSource

	var processed_expr := ExpressionHelper.replace_variables(
		expression, context, utils_scope, custom_scope_id, target_node_path, true
	)
	if processed_expr == null:
		_log_error_localized("BRICKS_ERROR_EXPRESSION_REGEX", {})
		set_error_localized("BRICKS_ERROR_EXPRESSION_REGEX", BricksError.ErrorType.RUNTIME_ERROR, {})
		finished.emit()
		return

	# 3. 执行表达式
	var error_text := ""
	var result = ExpressionHelper.evaluate(String(processed_expr), _expr_helper, error_text)
	if result == null:
		_log_error_localized("BRICKS_ERROR_EXPRESSION_PARSE", {"error": error_text})
		set_error_localized("BRICKS_ERROR_EXPRESSION_PARSE", BricksError.ErrorType.RUNTIME_ERROR, {"error": error_text})
		finished.emit()
		return

	# 4. 验证结果类型
	var str_result: String
	if result is String:
		str_result = result
	else:
		str_result = str(result)

	# 5. 保存结果
	var save_success := _save_result(str_result, context)
	if not save_success:
		finished.emit()
		return

	_log_info_localized("BRICKS_LOG_STRING_EXPRESSION_RESULT", {
		"expr": expression,
		"result": str_result
	})

	_on_execution_completed()

# =============================================
# 结果保存
# =============================================

func _save_result(value: String, context: ExecutionContext) -> bool:
	match save_to_scope:
		BaseVariable.VariableScope.LOCAL:
			var success := VariableOperations.set_variable(context, save_to_variable, BaseVariable.VariableScope.LOCAL, value)
			if not success:
				_log_error_localized("BRICKS_ERROR_SET_LOCAL_VARIABLE_FAILED", {"name": save_to_variable})
				set_error_localized("BRICKS_ERROR_SET_LOCAL_VARIABLE_FAILED", BricksError.ErrorType.RUNTIME_ERROR, {"name": save_to_variable})
			return success

		BaseVariable.VariableScope.SCOPE:
			return _save_to_scope_variable(value, context)

		BaseVariable.VariableScope.GLOBAL:
			var success := VariableOperations.set_variable(context, save_to_variable, BaseVariable.VariableScope.GLOBAL, value)
			if not success:
				_log_error_localized("BRICKS_ERROR_SET_GLOBAL_VARIABLE_FAILED", {"name": save_to_variable})
				set_error_localized("BRICKS_ERROR_SET_GLOBAL_VARIABLE_FAILED", BricksError.ErrorType.RUNTIME_ERROR, {"name": save_to_variable})
			return success

		_:
			_log_error_localized("BRICKS_ERROR_UNKNOWN_SCOPE", {})
			set_error_localized("BRICKS_ERROR_UNKNOWN_SCOPE", BricksError.ErrorType.RUNTIME_ERROR, {})
			return false

func _save_to_scope_variable(value: String, context: ExecutionContext) -> bool:
	if save_scope_source == ScopeSource.NEAREST:
		var success := VariableOperations.set_variable(context, save_to_variable, BaseVariable.VariableScope.SCOPE, value)
		if not success:
			_log_error_localized("BRICKS_ERROR_SET_SCOPE_VARIABLE_FAILED", {"name": save_to_variable})
			set_error_localized("BRICKS_ERROR_SET_SCOPE_VARIABLE_FAILED", BricksError.ErrorType.RUNTIME_ERROR, {"name": save_to_variable})
		return success
	else:
		var utils_scope := save_scope_source as VariableScopeUtils.ScopeSource
		var scope_container := VariableScopeUtils.get_scope_container_by_source(
			context, utils_scope, save_custom_scope_id, save_target_node_path
		)
		if scope_container == null:
			_log_error_localized("BRICKS_ERROR_SCOPE_CONTAINER_NOT_FOUND", {})
			set_error_localized("BRICKS_ERROR_SCOPE_CONTAINER_NOT_FOUND", BricksError.ErrorType.RUNTIME_ERROR, {})
			return false
		var success := scope_container.set_variable(save_to_variable, value)
		if not success:
			_log_error_localized("BRICKS_ERROR_SET_SCOPE_VARIABLE_FAILED", {"name": save_to_variable})
			set_error_localized("BRICKS_ERROR_SET_SCOPE_VARIABLE_FAILED", BricksError.ErrorType.RUNTIME_ERROR, {"name": save_to_variable})
		return success

# =============================================
# 验证
# =============================================

func validate() -> Array[String]:
	var errors := super.validate()

	if expression.is_empty():
		errors.append(BricksLocalization.translate("BRICKS_ERROR_EXPRESSION_EMPTY"))

	if save_to_variable.is_empty():
		errors.append(BricksLocalization.translate("BRICKS_ERROR_VAR_NAME_EMPTY"))

	errors.append_array(ExpressionHelper.validate_syntax(expression))

	if save_to_scope == BaseVariable.VariableScope.SCOPE:
		var utils_scope := save_scope_source as VariableScopeUtils.ScopeSource
		errors.append_array(VariableScopeUtils.validate_scope_source_params(
			utils_scope, save_custom_scope_id, save_target_node_path
		))

	return errors
```

### Step 2: 创建 StringExpression 测试

```gdscript
# addons/bricks/tests/instructions/test_string_expression.gd
extends Node

## StringExpression 指令测试

var test_results: Array[String] = []
var test_passed: int = 0
var test_failed: int = 0

func _ready():
	print("=== StringExpression 指令测试开始 ===")
	_run_all_tests()
	_show_test_results()
	print("=== StringExpression 指令测试完成 ===")

func _run_all_tests():
	_test_basic_concat()
	_test_variable_interpolation()
	_test_type_conversion()
	_test_helper_functions()
	_test_validation()

func _test_basic_concat():
	print("\n--- 基础拼接测试 ---")
	await _test_string_expression('"Hello" + " " + "World"', "Hello World", "字符串拼接")
	await _test_string_expression('str(42)', "42", "str() 转换")
	await _test_string_expression('"Score: " + str(100)', "Score: 100", "字符串+数值")

func _test_variable_interpolation():
	print("\n--- 变量插值测试 ---")
	await _test_string_expression_with_vars(
		'"Player " + str({local:id}) + " HP:" + str({local:hp})',
		{"id": 1, "hp": 80},
		"Player 1 HP:80",
		"多变量插值"
	)

func _test_type_conversion():
	print("\n--- 类型转换测试 ---")
	await _test_string_expression_with_vars(
		'{local:hp} > 0 ? "Alive" : "Dead"',
		{"hp": 50},
		"Alive",
		"三元运算（真）"
	)
	await _test_string_expression_with_vars(
		'{local:hp} > 0 ? "Alive" : "Dead"',
		{"hp": 0},
		"Dead",
		"三元运算（假）"
	)
	# 非字符串结果自动 str()
	await _test_string_expression_with_vars(
		'{local:a} + {local:b}',
		{"a": 10, "b": 20},
		"30",
		"数值表达式自动转字符串"
	)

func _test_helper_functions():
	print("\n--- 辅助函数测试 ---")
	await _test_string_expression('format_num(3.14159, 2)', "3.14", "format_num")
	await _test_string_expression('pad_left("42", 6, "0")', "000042", "pad_left")
	await _test_string_expression('pad_right("hi", 5, "!")', "hi!!!", "pad_right")

func _test_validation():
	print("\n--- 验证测试 ---")

	var instr := StringExpression.new()
	instr.log_level = BricksLogger.LogLevel.DEBUG
	instr.expression = ""
	instr.save_to_variable = "result"
	var errors := instr.validate()
	_record("空表达式", errors.size() > 0)

	instr.expression = '"hello"'
	instr.save_to_variable = ""
	errors = instr.validate()
	_record("空变量名", errors.size() > 0)

	instr.save_to_variable = "result"
	errors = instr.validate()
	_record("有效配置", errors.is_empty())

func _test_string_expression(expr: String, expected: String, name: String):
	await _test_string_expression_with_vars(expr, {}, expected, name)

func _test_string_expression_with_vars(expr: String, variables: Dictionary, expected: String, name: String):
	var instr := StringExpression.new()
	instr.log_level = BricksLogger.LogLevel.DEBUG
	instr.expression = expr
	instr.save_to_variable = "str_result"

	var context := ExecutionContext.new()
	for key in variables:
		context.set_variable(key, variables[key])

	var execution_result := {"executed": false}
	instr.finished.connect(func(): execution_result.executed = true)
	instr.execute(context)

	await get_tree().create_timer(0.1).timeout

	if execution_result.executed and context.has_variable("str_result"):
		var val = context.get_variable("str_result") as String
		_record(name, val == expected, "期望 '%s', 实际 '%s'" % [expected, val])
	else:
		_record(name, false, "执行失败或变量未设置")

func _record(name: String, passed: bool, details: String = ""):
	var status = "PASS" if passed else "FAIL"
	var s = "[%s] %s" % [status, name]
	if not details.is_empty():
		s += " - " + details
	test_results.append(s)
	if passed:
		test_passed += 1
	else:
		test_failed += 1
	print(s)

func _show_test_results():
	print("\n=== 测试结果汇总 ===")
	print("通过: %d" % test_passed)
	print("失败: %d" % test_failed)
	if test_failed > 0:
		print("\n失败:")
		for r in test_results:
			if r.begins_with("[FAIL]"):
				print("  " + r)
```

### Step 3: 验证语法

Run: `/gdscript-validate` on both files

### Step 4: Commit

```bash
git add addons/bricks/instructions/math/string_expression.gd addons/bricks/tests/instructions/test_string_expression.gd
git commit -m "feat(bricks): add StringExpression instruction for string formatting"
```

---

## Task 5: 重构 MathExpression 使用 ExpressionHelper

将 MathExpression 内部逻辑替换为 ExpressionHelper 调用，保持行为完全一致。

**Files:**
- Modify: `addons/bricks/instructions/math/math_expression.gd`

### Step 1: 替换内部实现

在 `math_expression.gd` 中进行以下修改：

**1a.** 删除内部的 `_ExprHelper` 类（第 33-43 行）和 `_expr_helper` 变量（第 46 行），替换为：

```gdscript
## 缓存的辅助实例
var _expr_helper: ExpressionHelper.GameExprHelper
```

**1b.** 替换 `_replace_variables` 方法（第 390-418 行）为委托调用：

```gdscript
func _replace_variables(expr: String, context: ExecutionContext) -> Variant:
	return ExpressionHelper.replace_variables(
		expr, context,
		scope_source as VariableScopeUtils.ScopeSource,
		custom_scope_id,
		target_node_path,
		true
	)
```

**1c.** 删除 `_get_variable_value`（第 421-430 行）和 `_get_scope_variable`（第 433-448 行）方法（已移入 ExpressionHelper）。

**1d.** 替换 `_escape_value_for_expression` 方法（第 451-464 行）为委托调用：

```gdscript
func _escape_value_for_expression(value: Variant) -> String:
	return ExpressionHelper.escape_value(value)
```

**1e.** 替换 `_evaluate_expression` 方法（第 471-495 行）为委托调用：

```gdscript
func _evaluate_expression(expr: String) -> Variant:
	if _expr_helper == null:
		_expr_helper = ExpressionHelper.GameExprHelper.new()

	var error_text := ""
	var result = ExpressionHelper.evaluate(expr, _expr_helper, error_text)

	if result == null:
		_log_error_localized("BRICKS_ERROR_EXPRESSION_PARSE", {"error": error_text})
		set_error_localized("BRICKS_ERROR_EXPRESSION_PARSE", BricksError.ErrorType.RUNTIME_ERROR, {"error": error_text})

	return result
```

**1f.** 替换 `_validate_expression_syntax` 方法（第 612-644 行）为委托调用：

```gdscript
func _validate_expression_syntax() -> Array[String]:
	return ExpressionHelper.validate_syntax(expression)
```

### Step 2: 验证重构未破坏行为

Run: 在 Godot 中运行 `addons/bricks/tests/instructions/test_math_expression.gd`，确认全部通过。

### Step 3: Commit

```bash
git add addons/bricks/instructions/math/math_expression.gd
git commit -m "refactor(bricks): MathExpression uses ExpressionHelper shared utility"
```

---

## Task 6: 集成验证

在 Godot 中运行全部相关测试，确保三个组件都正常工作。

### Step 1: 运行所有测试

在 Godot 中依次运行以下测试场景（需挂载到场景树中执行）：

1. `addons/bricks/tests/utils/test_expression_helper.gd`
2. `addons/bricks/tests/conditions/test_expression_condition.gd`
3. `addons/bricks/tests/instructions/test_string_expression.gd`
4. `addons/bricks/tests/instructions/test_math_expression.gd`（回归测试）

### Step 2: 检查本地化

确认所有新翻译键在编辑器中正确显示。

### Step 3: 最终 Commit（如有修复）

```bash
git commit -m "fix(bricks): address integration test findings"
```

---

## 文件清单

| 操作 | 文件路径 |
|:---:|----------|
| CREATE | `addons/bricks/core/utils/expression_helper.gd` |
| CREATE | `addons/bricks/conditions/math/expression_condition.gd` |
| CREATE | `addons/bricks/instructions/math/string_expression.gd` |
| CREATE | `addons/bricks/tests/utils/test_expression_helper.gd` |
| CREATE | `addons/bricks/tests/conditions/test_expression_condition.gd` |
| CREATE | `addons/bricks/tests/instructions/test_string_expression.gd` |
| MODIFY | `addons/bricks/instructions/math/math_expression.gd` |
| MODIFY | `addons/bricks/localization/translations.csv` |
