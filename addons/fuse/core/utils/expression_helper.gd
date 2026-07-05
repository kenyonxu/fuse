class_name ExpressionHelper extends RefCounted

## 表达式公共工具类
##
## 提供 Fuse 表达式系统的共享功能：
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
				FuseLogger.log_warning("ExpressionHelper", FuseLogger.LogLevel.WARNING,
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
		var escaped := str(value).replace("\\", "\\\\").replace('"', '\\"')
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
			errors.append(FuseLocalization.translate_format(
				"FUSE_ERROR_INVALID_VAR_SYNTAX",
				{"syntax": "{%s:%s}" % [scope_type, var_name]}
			))

		if not valid_pattern.search(var_name):
			errors.append(FuseLocalization.translate_format(
				"FUSE_ERROR_INVALID_VAR_SYNTAX",
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
