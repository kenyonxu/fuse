@tool
class_name ParameterBinding
extends RefCounted

## 参数绑定框架
## 将方法/属性的参数信息转化为 Inspector 属性、序列化数据和运行时调用参数
## 替代 Instruction 中重复的 _set/_get/_get_parameter_properties 样板代码
##
## 使用方式：
##   var _binding_manager: ParameterBindingManager = ParameterBindingManager.new()
##   func _set(property, value):
##       if _binding_manager.handle_set(property, value): return true
##       return false
##   func _get(property):
##       return _binding_manager.handle_get(property)

## 作用域来源枚举
enum ScopeSource {
	ScopeSourceTarget,		## 目标节点
	ScopeSourceCustom,		## 自定义
	ScopeSourcePath,		## 节点路径
}


## 单个参数的绑定配置
class BoundParameter extends RefCounted:
	var name: String = ""				## 参数名（清理后）
	var index: int = 0					## 参数索引
	var type: int = TYPE_NIL			## 参数类型 (Variant TYPE_*)
	var hint: PropertyHint = PROPERTY_HINT_NONE
	var hint_string: String = ""		## 提示字符串
	var default_value: Variant = null	## 默认值
	var current_value: Variant = null	## 当前值

	## 变量绑定配置
	var use_variable: bool = false								## 是否使用变量代替直接值
	var variable_name: String = ""								## 变量名
	var variable_scope: int = BaseVariable.VariableScope.LOCAL	## 变量作用域
	var scope_source: int = ScopeSource.ScopeSourceTarget		## 作用域来源（仅 SCOPE 时使用）
	var custom_scope_id: String = ""							## 自定义作用域 ID（仅 SCOPE 时使用）
	var scope_target_path: NodePath = NodePath()				## 作用域目标节点路径（仅 SCOPE 时使用）

	## 属性名（增强格式 param_0___name）
	func get_property_name() -> String:
		return "param_%d___%s" % [index, name]

	## 变量绑定的属性名前缀
	func get_use_variable_property_name() -> String:
		return "param_%d_use_variable" % index

	func get_variable_name_property_name() -> String:
		return "param_%d_variable_name" % index

	func get_variable_scope_property_name() -> String:
		return "param_%d_variable_scope" % index

	## 序列化
	func to_dict() -> Dictionary:
		return {
			"index": index,
			"name": name,
			"type": type,
			"hint": hint as int,
			"hint_string": hint_string,
			"default_value": default_value,
			"current_value": current_value,
			"use_variable": use_variable,
			"variable_name": variable_name,
			"variable_scope": variable_scope,
			"scope_source": scope_source,
			"custom_scope_id": custom_scope_id,
			"scope_target_path": scope_target_path,
		}

	## 反序列化（兼容新旧两种格式）
	static func from_dict(data: Dictionary) -> BoundParameter:
		var param = BoundParameter.new()
		param.index = data.get("index", 0)
		# 兼容新旧 name 格式：旧格式 "param_0___speed"，新格式 "speed"
		var raw_name: String = data.get("name", "")
		var clean_name: String = data.get("clean_name", "")
		if not clean_name.is_empty():
			param.name = clean_name
		else:
			param.name = _extract_clean_name(raw_name, param.index)
		param.type = data.get("type", TYPE_NIL)
		param.hint = data.get("hint", PROPERTY_HINT_NONE) as PropertyHint
		param.hint_string = data.get("hint_string", "")
		# 兼容新旧默认值键名
		param.default_value = data.get("default_value", data.get("default", null))
		param.current_value = data.get("current_value", null)
		# 变量绑定字段
		param.use_variable = data.get("use_variable", false)
		param.variable_name = data.get("variable_name", "")
		param.variable_scope = data.get("variable_scope", BaseVariable.VariableScope.LOCAL)
		param.scope_source = data.get("scope_source", ScopeSource.ScopeSourceTarget)
		param.custom_scope_id = data.get("custom_scope_id", "")
		param.scope_target_path = data.get("scope_target_path", NodePath())
		return param

	## 从 FunctionInfo 的参数属性字典创建
	static func from_property_dict(prop_dict: Dictionary, index: int) -> BoundParameter:
		var property_name = prop_dict.get("name", "param_%d" % index)
		var clean_name = _extract_clean_name(property_name, index)
		var param = BoundParameter.new()
		param.index = index
		param.name = clean_name
		param.type = prop_dict.get("type", TYPE_NIL)
		param.hint = prop_dict.get("hint", PROPERTY_HINT_NONE) as PropertyHint
		param.hint_string = prop_dict.get("hint_string", "")
		param.default_value = prop_dict.get("default", null)
		param.current_value = param.default_value
		return param

	## 从增强格式属性名提取清理后的名称
	static func _extract_clean_name(property_name: String, fallback_index: int) -> String:
		var separator = property_name.find("___")
		if separator >= 0:
			return property_name.substr(separator + 3)
		return "param_%d" % fallback_index

	## 获取运行时值（支持变量绑定）
	## @param context: 执行上下文，变量绑定时需要
	## @return: 直接值或从变量系统读取的值
	func get_runtime_value(context: Variant = null) -> Variant:
		if use_variable and not variable_name.is_empty():
			if context == null:
				return current_value
			return VariableOperations.get_variable(
				context, variable_name, variable_scope as BaseVariable.VariableScope, current_value
			)
		return current_value


## 参数绑定管理器
class ParameterBindingManager extends RefCounted:
	var parameters: Array[BoundParameter] = []

	## 从 FunctionInfo 创建参数绑定
	## @param preserve_values: 为 true 时保留已有参数的非空值（用于参数数量不变的场景）
	func build_from_function_info(function_info: FunctionInfo, preserve_values: bool = false) -> void:
		var old_values: Dictionary = {}
		if preserve_values:
			for param in parameters:
				if param.current_value != null:
					old_values[param.index] = param.current_value

		parameters.clear()
		if not function_info:
			return
		var param_properties = function_info.get_parameter_property_list()
		for i in range(param_properties.size()):
			var bound = BoundParameter.from_property_dict(param_properties[i], i)
			if preserve_values and old_values.has(i):
				bound.current_value = old_values[i]
			parameters.append(bound)

	## 序列化为字典数组
	func serialize() -> Array[Dictionary]:
		var result: Array[Dictionary] = []
		for param in parameters:
			result.append(param.to_dict())
		return result

	## 从字典数组反序列化
	func deserialize(data: Array) -> void:
		parameters.clear()
		for item in data:
			if item is Dictionary:
				parameters.append(BoundParameter.from_dict(item))

	## 生成 Inspector 属性列表（_get_parameter_properties 使用）
	## @param include_variable_bindings: 是否包含变量绑定相关属性
	func get_inspector_properties(include_variable_bindings: bool = false) -> Array[Dictionary]:
		var properties: Array[Dictionary] = []
		for param in parameters:
			# 直接值属性
			properties.append({
				"name": param.get_property_name(),
				"type": param.type,
				"hint": param.hint as int,
				"hint_string": param.hint_string,
				"default": param.default_value,
				"usage": PROPERTY_USAGE_DEFAULT
			})
			# 变量绑定属性
			if include_variable_bindings:
				properties.append({
					"name": param.get_use_variable_property_name(),
					"type": TYPE_BOOL,
					"hint": PROPERTY_HINT_NONE,
					"usage": PROPERTY_USAGE_DEFAULT
				})
		return properties

	## 获取运行时参数数组
	## @param context: 执行上下文，支持变量绑定时传入
	func get_runtime_args(context: Variant = null) -> Array:
		var args: Array = []
		for param in parameters:
			args.append(param.get_runtime_value(context))
		return args

	## 获取参数数量
	func get_param_count() -> int:
		return parameters.size()

	## _set 虚函数处理 — 在 Instruction._set 中调用
	## 自动创建缺失的 BoundParameter 条目（资源加载时 _binding_manager 可能还未初始化）
	## @return: true 如果属性被处理
	func handle_set(property: StringName, value: Variant) -> bool:
		var str_prop = str(property)

		# 处理参数值
		if str_prop.begins_with("param_") and not str_prop.contains("variable"):
			var param_index = _parse_param_index(str_prop)
			if param_index < 0:
				return false

			# 自动扩展：资源加载时 _binding_manager 可能还没有条目
			while parameters.size() <= param_index:
				var bp = BoundParameter.new()
				bp.index = parameters.size()
				parameters.append(bp)

			parameters[param_index].current_value = value
			return true

		# 处理变量绑定属性
		var var_match = _parse_variable_binding_property(str_prop)
		if var_match.index >= 0:
			var param_index = var_match.index
			var field = var_match.field
			# 自动扩展
			while parameters.size() <= param_index:
				var bp = BoundParameter.new()
				bp.index = parameters.size()
				parameters.append(bp)

			match field:
				"use_variable":
					parameters[param_index].use_variable = value
				"variable_name":
					parameters[param_index].variable_name = value
				"variable_scope":
					parameters[param_index].variable_scope = value
			return true

		return false

	## _get 虚函数处理 — 在 Instruction._get 中调用
	## @return: 属性值，未匹配返回 null
	func handle_get(property: StringName) -> Variant:
		var str_prop = str(property)

		# 处理参数值
		if str_prop.begins_with("param_") and not str_prop.contains("variable"):
			var param_index = _parse_param_index(str_prop)
			if param_index < 0 or param_index >= parameters.size():
				return null
			return parameters[param_index].current_value

		# 处理变量绑定属性
		var var_match = _parse_variable_binding_property(str_prop)
		if var_match.index >= 0 and var_match.index < parameters.size():
			var param = parameters[var_match.index]
			match var_match.field:
				"use_variable":
					return param.use_variable
				"variable_name":
					return param.variable_name
				"variable_scope":
					return param.variable_scope
		return null

	## 从 param_N___xxx 格式解析索引
	func _parse_param_index(str_prop: String) -> int:
		if not str_prop.begins_with("param_"):
			return -1
		var param_part = str_prop.substr(6)
		var separator = param_part.find("___")
		var index_str: String
		if separator >= 0:
			index_str = param_part.substr(0, separator)
		else:
			index_str = param_part
		if not index_str.is_valid_int():
			return -1
		return index_str.to_int()

	## 从 param_N_variable_xxx 格式解析变量绑定字段
	## @return: Dictionary {index: int, field: String}
	func _parse_variable_binding_property(str_prop: String) -> Dictionary:
		if not str_prop.begins_with("param_"):
			return {"index": -1, "field": ""}
		# 格式: param_N_use_variable / param_N_variable_name / param_N_variable_scope
		var rest = str_prop.substr(6)
		var first_underscore = rest.find("_")
		if first_underscore < 0:
			return {"index": -1, "field": ""}
		var index_str = rest.substr(0, first_underscore)
		if not index_str.is_valid_int():
			return {"index": -1, "field": ""}
		var field_part = rest.substr(first_underscore + 1)
		# 确认是变量绑定字段
		if not field_part.begins_with("use_variable") and not field_part.begins_with("variable_"):
			return {"index": -1, "field": ""}
		# 提取字段名
		var field: String
		if field_part.begins_with("use_variable"):
			field = "use_variable"
		elif field_part.begins_with("variable_name"):
			field = "variable_name"
		elif field_part.begins_with("variable_scope"):
			field = "variable_scope"
		else:
			return {"index": -1, "field": ""}
		return {"index": index_str.to_int(), "field": field}

	## 清空所有参数
	func clear() -> void:
		parameters.clear()

	## 获取指定索引的参数
	func get_parameter(index: int) -> BoundParameter:
		if index < 0 or index >= parameters.size():
			return null
		return parameters[index]
